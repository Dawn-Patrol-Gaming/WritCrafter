local WC = WritCrafter

local Reservations = {}
WC.Reservations = Reservations

-- Writs and crafted items are matched across the backpack and bank, and, inside your own house,
-- its storage chests too (their contents can only be read there). Scan order matters: items
-- closest to hand are assigned first.
local BASE_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }
local HOUSE_BAGS = {}
if BAG_HOUSE_BANK_ONE and BAG_HOUSE_BANK_TEN then
    for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        HOUSE_BAGS[#HOUSE_BAGS + 1] = bagId
    end
end

local SCANNED = {}
for _, list in ipairs({ BASE_BAGS, HOUSE_BAGS }) do
    for _, bagId in ipairs(list) do
        SCANNED[bagId] = true
    end
end

local function ScannedBags()
    if #HOUSE_BAGS == 0 or not (IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse()) then
        return BASE_BAGS
    end
    local bags = { unpack(BASE_BAGS) }
    for _, bagId in ipairs(HOUSE_BAGS) do
        bags[#bags + 1] = bagId
    end
    return bags
end

local dirty = true
local writCount            -- sealed writs found by the last scan; nil until the first one
local statusByUid = {}     -- [writ unique ID] = { have, required, crafted, inBackpack, inBank, writBag, assigned }
local reservedBySlot = {}  -- [bagId][slotIndex] = units assigned to writs
local acceptedBySlot = {}  -- [bagId][slotIndex] = quest name of the accepted master writ it's for
local acceptedCount = 0    -- accepted master writs found by the last scan
local acceptedInBank = {}  -- { bagId, slotIndex, quantity } of bank items claimed by accepted writs

local CANDIDATE_TYPES = {
    [ITEMTYPE_WEAPON]        = WC.Master.KIND_SMITHING,
    [ITEMTYPE_ARMOR]         = WC.Master.KIND_SMITHING,
    [ITEMTYPE_GLYPH_ARMOR]   = WC.Master.KIND_ENCHANTING,
    [ITEMTYPE_GLYPH_WEAPON]  = WC.Master.KIND_ENCHANTING,
    [ITEMTYPE_GLYPH_JEWELRY] = WC.Master.KIND_ENCHANTING,
    [ITEMTYPE_POTION]        = WC.Master.KIND_ALCHEMY,
    [ITEMTYPE_POISON]        = WC.Master.KIND_ALCHEMY,
    [ITEMTYPE_FOOD]          = WC.Master.KIND_PROVISIONING,
    [ITEMTYPE_DRINK]         = WC.Master.KIND_PROVISIONING,
}

-- Whether items of this type can ever be set aside for a writ (cheap row check).
function Reservations.IsCandidateType(itemType)
    return CANDIDATE_TYPES[itemType] ~= nil
end

local GENERIC_LINK = "|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

-- Shape of a template's sample item: equip slot, armor weight, weapon type.
local shapeCache = {}
local function TemplateShape(template)
    local shape = shapeCache[template.sample]
    if not shape then
        local link = string.format(GENERIC_LINK, template.sample)
        shape = {
            equip  = GetItemLinkEquipType(link),
            armor  = GetItemLinkArmorType(link),
            weapon = GetItemLinkWeaponType(link),
        }
        shapeCache[template.sample] = shape
    end
    return shape
end

-- Crafted potions pack three effect IDs into link field 24, one per byte; the high bit of
-- a byte marks a lingering effect. Returns them normalized and sorted.
local function PotionEffects(link)
    -- Through a table: select() past the last field returns no value, which tonumber() rejects.
    local fields = { ZO_LinkHandler_ParseLink(link) }
    local packed = tonumber(fields[24]) or 0
    local effects = {}
    for _, shift in ipairs({ 65536, 256, 1 }) do
        local byte = zo_floor(packed / shift) % 256
        if byte > 127 then
            byte = byte - 128
        end
        if byte > 0 then
            effects[#effects + 1] = WC.Data.Alchemy.Normalize(byte)
        end
    end
    table.sort(effects)
    return effects
end
Reservations.PotionEffects = PotionEffects   -- for /wc checkdata

-- Match keys. An item satisfies a writ when both produce the same key, so each writ finds its
-- items with one table lookup instead of being tested against every item. Item key builders
-- also filter: anything that can't be a master-writ item returns nil.
local function Key(...)
    local parts = { ... }
    for i = 1, select("#", ...) do
        parts[i] = tostring(parts[i])
    end
    return table.concat(parts, ":")
end

local function IsJewelry(equip)
    return equip == EQUIP_TYPE_NECK or equip == EQUIP_TYPE_RING
end

-- Robe and jerkin are both light chest pieces; only the icon tells them apart.
local function ChestCut(equip, armor, icon)
    if equip ~= EQUIP_TYPE_CHEST or armor ~= ARMORTYPE_LIGHT then
        return "-"
    end
    return (icon or ""):find("robe", 1, true) and "robe" or "jerkin"
end

-- Gear key. anyQuality leaves the quality out (a freshly crafted piece is white and is then
-- improved); prospective accepts the link a craft would produce, which isn't flagged crafted.
local function GearItemKey(link, anyQuality, prospective)
    -- Gear writs accept CP150 or CP160 (the writ names only the material tier, and both
    -- tiers use it); WritCrafter crafts CP150, which costs a tenth of the material.
    local cp = GetItemLinkRequiredChampionPoints(link)
    if (not prospective and not IsItemLinkCrafted(link)) or (cp ~= 150 and cp ~= 160) then
        return nil
    end
    local equip, armor = GetItemLinkEquipType(link), GetItemLinkArmorType(link)
    local style = IsJewelry(equip) and 0 or GetItemLinkItemStyle(link)
    return Key("gear", select(6, GetItemLinkSetInfo(link, false)), GetItemLinkTraitInfo(link),
        anyQuality and "*" or GetItemLinkFunctionalQuality(link), style, equip, armor,
        GetItemLinkWeaponType(link), ChestCut(equip, armor, GetItemLinkInfo(link)))
end

local function GearWritKey(writ, anyQuality)
    local t = writ.template
    if not t then
        return nil
    end
    local shape = TemplateShape(t)
    local style = t.chapter and writ.style or 0
    local cut = "-"
    if t.robe ~= nil then
        cut = t.robe and "robe" or "jerkin"
    end
    return Key("gear", writ.setId, writ.trait, anyQuality and "*" or writ.quality, style,
        shape.equip, shape.armor, shape.weapon, cut)
end

local ITEM_KEYS = {
    [WC.Master.KIND_SMITHING] = function(link)
        return GearItemKey(link, false, false)
    end,
    [WC.Master.KIND_ENCHANTING] = function(link)
        local cp = GetItemLinkRequiredChampionPoints(link)
        if cp ~= 150 and cp ~= 160 then
            return nil
        end
        return Key("glyph", GetItemLinkItemId(link), cp, GetItemLinkFunctionalQuality(link))
    end,
    [WC.Master.KIND_ALCHEMY] = function(link, itemType)
        if GetItemLinkRequiredChampionPoints(link) ~= 150 then
            return nil
        end
        return Key("potion", itemType, unpack(PotionEffects(link)))
    end,
    [WC.Master.KIND_PROVISIONING] = function(link)
        -- No quality filter: master writs also ask for blue food and drink (e.g. Orzorga's
        -- Red Frothgar). The key is the exact item, so only the right dish ever matches.
        return Key("food", GetItemLinkItemId(link))
    end,
}

local WRIT_KEYS = {
    [WC.Master.KIND_SMITHING] = function(writ)
        return GearWritKey(writ, false)
    end,
    [WC.Master.KIND_ENCHANTING] = function(writ)
        if not writ.level then
            return nil
        end
        return Key("glyph", writ.glyphId, writ.level.cp, writ.quality)
    end,
    [WC.Master.KIND_ALCHEMY] = function(writ)
        if not writ.solvent then
            return nil
        end
        local effects = { unpack(writ.effects) }
        table.sort(effects)
        return Key("potion", writ.solvent.poison and ITEMTYPE_POISON or ITEMTYPE_POTION, unpack(effects))
    end,
    [WC.Master.KIND_PROVISIONING] = function(writ)
        return Key("food", writ.resultId)
    end,
}

-- Writ objects are cached per link by WC.Master, so their key is worked out once.
local function WritKey(writ)
    if writ.matchKey == nil then
        writ.matchKey = WRIT_KEYS[writ.kind](writ) or false
    end
    return writ.matchKey
end

-- Per-slot tables are [bagId][slotIndex] = value, so looking a slot up while drawing rows builds
-- no strings.
local function GetSlot(map, bagId, slotIndex)
    local bag = map[bagId]
    return bag and bag[slotIndex]
end

local function SetSlot(map, bagId, slotIndex, value)
    local bag = map[bagId]
    if not bag then
        bag = {}
        map[bagId] = bag
    end
    bag[slotIndex] = value
end

local candidateCount = 0

local function Rebuild()
    ZO_ClearTable(statusByUid)
    ZO_ClearTable(reservedBySlot)
    ZO_ClearTable(acceptedBySlot)
    ZO_ClearTable(acceptedInBank)

    -- One pass over backpack and bank, cheapest checks first: item type (no link needed),
    -- then the game lock, then the link-based filters, and the FCO ItemSaver mark last.
    local writs, byKey = {}, {}
    candidateCount = 0
    for _, bagId in ipairs(ScannedBags()) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            local itemType = GetItemType(bagId, slotIndex)
            if itemType == ITEMTYPE_MASTER_WRIT then
                local writ = WC.Master.Parse(GetItemLink(bagId, slotIndex))
                if writ then
                    writs[#writs + 1] = { uid = WC.Master.UniqueId(bagId, slotIndex), writ = writ, bagId = bagId }
                end
            else
                local kind = CANDIDATE_TYPES[itemType]
                -- Locked or FCO ItemSaver-marked items are the player's own, never a writ item.
                if kind and not IsItemPlayerLocked(bagId, slotIndex) then
                    local link = GetItemLink(bagId, slotIndex)
                    local key = ITEM_KEYS[kind](link, itemType)
                    if key and not WC.Inventory.IsProtected(bagId, slotIndex) then
                        local list = byKey[key]
                        if not list then
                            list = {}
                            byKey[key] = list
                        end
                        list[#list + 1] = {
                            bagId     = bagId,
                            slotIndex = slotIndex,
                            remaining = GetSlotStackSize(bagId, slotIndex),
                            cp        = GetItemLinkRequiredChampionPoints(link),
                            order     = candidateCount,
                        }
                        candidateCount = candidateCount + 1
                    end
                end
            end
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end

    -- Lowest level first, so a CP150 piece is set aside before a CP160 one (the CP160 piece
    -- took ten times the material and is more likely to be kept); then in bag order, backpack
    -- first, so the items closest to hand are assigned.
    for _, list in pairs(byKey) do
        if #list > 1 then
            table.sort(list, function(a, b)
                if a.cp ~= b.cp then
                    return a.cp < b.cp
                end
                return a.order < b.order
            end)
        end
    end

    -- Accepted master writs (the sealed writ is used up when you accept it) claim items first,
    -- since they're the ones being turned in, matched like sealed writs. Their full amount is
    -- claimed, including what's already in the backpack, so those items keep their badge until
    -- turn-in, also once the quest has moved on to delivery. These aren't reservedBySlot:
    -- storage withdrawal hands them to the quest.
    local accepted = WC.Master.Accepted()
    acceptedCount = #accepted
    for _, entry in ipairs(accepted) do
        local need = entry.writ.required
        local key = WritKey(entry.writ)
        for _, candidate in ipairs(key and byKey[key] or {}) do
            if need == 0 then
                break
            end
            if candidate.remaining > 0 then
                local take = zo_min(candidate.remaining, need)
                candidate.remaining = candidate.remaining - take
                need = need - take
                SetSlot(acceptedBySlot, candidate.bagId, candidate.slotIndex, entry.quest)
                if candidate.bagId ~= BAG_BACKPACK then
                    acceptedInBank[#acceptedInBank + 1] = { bagId = candidate.bagId, slotIndex = candidate.slotIndex,
                        quantity = take, quest = entry.quest }
                end
            end
        end
    end

    -- Sealed writs: queued ones first, so when two writs ask for the same thing the items go to
    -- the one being crafted for (otherwise a station crafts for the queued writ, the items land
    -- on its unqueued twin, and the queued one never shows progress); then those in the backpack
    -- before the bank, in bag order.
    for index, entry in ipairs(writs) do
        entry.order = index
        entry.queued = WC.Queue.Has(entry.uid)
    end
    table.sort(writs, function(a, b)
        if a.queued ~= b.queued then
            return a.queued
        end
        return a.order < b.order
    end)
    for _, entry in ipairs(writs) do
        local writ = entry.writ
        local need = writ.required
        local inBackpack, inBank = 0, 0
        local assigned = {}
        local key = WritKey(writ)
        for _, candidate in ipairs(key and byKey[key] or {}) do
            if need == 0 then
                break
            end
            if candidate.remaining > 0 then
                local take = zo_min(candidate.remaining, need)
                candidate.remaining = candidate.remaining - take
                need = need - take
                SetSlot(reservedBySlot, candidate.bagId, candidate.slotIndex,
                    (GetSlot(reservedBySlot, candidate.bagId, candidate.slotIndex) or 0) + take)
                assigned[#assigned + 1] = { bagId = candidate.bagId, slotIndex = candidate.slotIndex, quantity = take }
                if candidate.bagId == BAG_BACKPACK then
                    inBackpack = inBackpack + take
                else
                    inBank = inBank + take   -- bank and ESO Plus bank together
                end
            end
        end
        statusByUid[entry.uid] = {
            required   = writ.required,
            have       = writ.required - need,
            crafted    = need == 0,
            inBackpack = inBackpack,
            inBank     = inBank,
            writBag    = entry.bagId,
            assigned   = assigned,
        }
    end
    writCount = #writs
    dirty = false
end

-- Bank stacks set aside for sealed writs in the backpack, as { bagId, slotIndex, quantity }:
-- what to take out so those writs can be turned in.
function Reservations.BankItemsForBackpackWrits()
    if dirty then
        Rebuild()
    end
    local list = {}
    for _, status in pairs(statusByUid) do
        if status.writBag == BAG_BACKPACK then
            for _, item in ipairs(status.assigned) do
                if item.bagId ~= BAG_BACKPACK then
                    list[#list + 1] = item
                end
            end
        end
    end
    return list
end

-- Bank stacks claimed by accepted master writs (what the backpack doesn't already hold), as
-- { bagId, slotIndex, quantity }: taken out so the quest can be turned in.
function Reservations.BankItemsForAcceptedWrits()
    if dirty then
        Rebuild()
    end
    return acceptedInBank
end

-- Whether an item link (e.g. the result a craft would produce) satisfies a writ. The crafting
-- engine checks this before spending anything.
function Reservations.Matches(link, writ)
    local itemType = GetItemLinkItemType(link)
    local kind = CANDIDATE_TYPES[itemType]
    if kind ~= writ.kind then
        return false
    end
    local key = ITEM_KEYS[kind](link, itemType)
    return key ~= nil and key == WritKey(writ)
end

-- Gear only: whether a piece is the writ's item apart from its quality, i.e. the base piece to
-- improve. prospective: the link is a craft's predicted result (not yet flagged crafted).
function Reservations.MatchesBase(link, writ, prospective)
    if writ.kind ~= WC.Master.KIND_SMITHING then
        return false
    end
    local key = GearItemKey(link, true, prospective)
    return key ~= nil and key == GearWritKey(writ, true)
end

-- Forces a full re-match now; returns the writ and candidate counts (for /wc perf).
function Reservations.Rebuild()
    Rebuild()
    return writCount, candidateCount
end

-- Re-matches only if something changed. Called once bag changes settle, so drawing rows
-- normally just reads finished results.
function Reservations.EnsureFresh()
    if dirty then
        Rebuild()
    end
end

-- Writ matching is only worth redoing when it can change. With no sealed writs, the only bag
-- change that matters is one that brings a sealed writ in; anything else (and every craft bag
-- change, since materials are never writ items) is ignored without rescanning or redrawing.
local function OnBagChanged(bagId, slotIndex)
    if bagId and not SCANNED[bagId] then
        return
    end
    if writCount == 0 and acceptedCount == 0 and bagId and GetItemType(bagId, slotIndex) ~= ITEMTYPE_MASTER_WRIT then
        return
    end
    dirty = true
    WC.InventoryIcons.OnWritItemsChanged()
end

function Reservations.Init()
    WC.Inventory.AddListener(OnBagChanged)
    -- Accepting, turning in or abandoning a master writ changes which items are claimed.
    -- The craft task leaves the journal once done, so its details are read (and remembered by
    -- WC.Master.Accepted) as soon as the quest is accepted or its progress changes.
    -- Items are only re-matched when the set of accepted writs changes (progress alone doesn't
    -- change which items are claimed), or on entering the world: on a fresh login the journal
    -- may not be loaded until then, and entering or leaving your house changes which storage
    -- can be read.
    local lastAccepted
    WC.Daily.OnJournalChanged(function(event, ...)
        WC.Master.OnJournalChanged(event, ...)
        local names = {}
        for _, entry in ipairs(WC.Master.Accepted()) do
            names[#names + 1] = entry.quest
        end
        local accepted = table.concat(names, "\n")
        if event == EVENT_PLAYER_ACTIVATED or accepted ~= lastAccepted then
            lastAccepted = accepted
            OnBagChanged()
        end
    end)
end

-- The accepted master writ quest an item is claimed for, or nil.
function Reservations.AcceptedQuestFor(bagId, slotIndex)
    if dirty then
        Rebuild()
    end
    if acceptedCount == 0 then
        return nil
    end
    return GetSlot(acceptedBySlot, bagId, slotIndex)
end

-- Settings and knowledge changes: always re-match.
function Reservations.Invalidate()
    dirty = true
end

-- Crafting status of one sealed writ, or nil if it isn't in a scanned bag.
function Reservations.GetWritStatus(uid)
    if dirty then
        Rebuild()
    end
    return statusByUid[uid]
end

-- Units in this slot that are assigned to writs (0 when none).
function Reservations.GetReserved(bagId, slotIndex)
    if dirty then
        Rebuild()
    end
    if writCount == 0 then
        return 0
    end
    return GetSlot(reservedBySlot, bagId, slotIndex) or 0
end
