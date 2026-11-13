local WC = WritCrafter

local Inventory = {}
WC.Inventory = Inventory

-- Stock counts everything you can reach without a trip: backpack, bank, ESO+ bank, craft bag.
-- House storage is deliberately left out (plan §9).
local STOCK_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL }

local GENERIC_LINK = "|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

-- Every filled slot of a bag: for slotIndex in Inventory.Slots(bagId) do ... end
local function Slots(bagId)
    return function(_, slotIndex)
        return ZO_GetNextBagSlotIndex(bagId, slotIndex)
    end, nil, nil
end
Inventory.Slots = Slots

-- An item's bare link (no level, quality or crafter): what the item ID alone says.
function Inventory.GenericLink(itemId)
    return string.format(GENERIC_LINK, itemId)
end

-- [itemId] = { backpack, bank, craftBag, locked, link, stackable, and for crafting stations:
-- stationBag, stationSlot, stationCount, stationRank, stationTotal (see FindForStation) }
local stock = {}
local dirty = true

-- Whether the player has protected this item: locked in game, or marked with any FCO
-- ItemSaver icon. Protected items are never handed in, deconstructed, junked, destroyed or
-- spent, with no setting to turn that off. The game enforces its own lock, but FCO ItemSaver
-- only guards the game's windows, so an addon calling the API directly has to check itself.
-- The game only lets players lock equippable gear, so for materials, consumables and glyphs
-- this is only ever true through an FCO ItemSaver mark.
function Inventory.IsProtected(bagId, slotIndex)
    if bagId == BAG_VIRTUAL then
        return false
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return true
    end
    -- -1 asks FCO ItemSaver about every marker icon at once.
    if FCOIS and FCOIS.IsMarked then
        local ok, marked = pcall(FCOIS.IsMarked, bagId, slotIndex, -1)
        return ok and marked == true
    end
    return false
end
local IsSlotLocked = Inventory.IsProtected

local stackCount = 0

local function Rebuild()
    ZO_ClearTable(stock)
    stackCount = 0
    local linkCache = WC.linkCache
    for _, bagId in ipairs(STOCK_BAGS) do
        for slotIndex in Slots(bagId) do
            local itemId = GetItemId(bagId, slotIndex)
            if itemId and itemId ~= 0 then
                stackCount = stackCount + 1
                local count, maxCount = GetSlotStackSize(bagId, slotIndex)
                local entry = stock[itemId]
                if not entry then
                    -- The link is read once per item, not once per stack.
                    entry = {
                        backpack  = 0,
                        bank      = 0,
                        craftBag  = 0,
                        locked    = 0,
                        link      = GetItemLink(bagId, slotIndex),
                        stackable = maxCount > 1,
                    }
                    stock[itemId] = entry
                end
                if bagId == BAG_BACKPACK then
                    entry.backpack = entry.backpack + count
                elseif bagId == BAG_VIRTUAL then
                    entry.craftBag = entry.craftBag + count
                else
                    entry.bank = entry.bank + count
                end
                if IsSlotLocked(bagId, slotIndex) then
                    entry.locked = entry.locked + count
                else
                    -- Where a station would take it from: craft bag, else the largest backpack
                    -- stack, else the largest bank stack.
                    local rank = bagId == BAG_VIRTUAL and 0 or (bagId == BAG_BACKPACK and 1 or 2)
                    entry.stationTotal = (entry.stationTotal or 0) + count
                    if not entry.stationRank or rank < entry.stationRank
                        or (rank == entry.stationRank and count > entry.stationCount) then
                        entry.stationBag, entry.stationSlot = bagId, slotIndex
                        entry.stationCount, entry.stationRank = count, rank
                    end
                end
                -- Only stackables (materials, consumables) are worth remembering for price lookups.
                if entry.stackable and not linkCache[itemId] then
                    linkCache[itemId] = entry.link
                end
            end
        end
    end
    dirty = false
end

-- Forces a full stock scan now; returns the number of stacks read (for /wc perf).
function Inventory.Rescan()
    Rebuild()
    return stackCount
end

local listeners = {}

-- Single-slot updates pass the bag and slot on; a full update passes nothing.
local function OnSlotChanged(_, bagId, slotIndex)
    dirty = true
    for _, listener in ipairs(listeners) do
        listener(bagId, slotIndex)
    end
end

local function OnFullUpdate()
    dirty = true
    for _, listener in ipairs(listeners) do
        listener()
    end
end

-- Called on every bag change with (bagId, slotIndex), or with nothing for a full update.
-- Listeners should only mark themselves dirty; real work happens later, when something asks.
function Inventory.AddListener(listener)
    listeners[#listeners + 1] = listener
end

function Inventory.Init()
    local namespace = WC.name .. "Inventory"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_FULL_UPDATE, OnFullUpdate)
end

-- Bag events don't fire when FCO ItemSaver marks change, so callers that are about to plan
-- crafts call this first to get a fresh scan.
function Inventory.Invalidate()
    dirty = true
end

-- Returns { backpack, bank, craftBag, locked, total, usable } for one item ID.
-- "locked" counts protected items (see IsProtected) and is never part of "usable".
function Inventory.GetStock(itemId)
    if dirty then
        Rebuild()
    end
    local entry = stock[itemId]
    local backpack = entry and entry.backpack or 0
    local bank     = entry and entry.bank or 0
    local craftBag = entry and entry.craftBag or 0
    local locked   = entry and entry.locked or 0
    local total    = backpack + bank + craftBag
    return {
        backpack = backpack,
        bank     = bank,
        craftBag = craftBag,
        locked   = locked,
        total    = total,
        usable   = zo_max(total - locked, 0),
    }
end

-- Where a material can be used from at a crafting station: the craft bag, the backpack and the
-- bank (stations have always drawn on all three; the game uses the craft bag first, then the
-- backpack, then the bank). Skips FCO ItemSaver-marked stacks. Returns the bag and slot to use,
-- in that same order (the craft bag, else the largest backpack stack, else the largest bank
-- stack), and the total usable at a station; nil when there's none. Craft bag items stay
-- usable after ESO Plus lapses, so its count is read whatever the subscription.
-- Read from the stock scan, so a search over many materials (alchemy tries every reagent)
-- doesn't walk the bags once per material. The slot is checked before it's handed out, in case
-- a bag change hasn't been reported yet; a stale one forces a fresh scan.
local function StationEntry(itemId)
    if dirty then
        Rebuild()
    end
    return stock[itemId]
end

-- Where each item would be taken from at a station, looked up once: [itemId] = { bag, slot }
-- (items you have none of are left out).
function Inventory.Locations(itemIds)
    local where = {}
    for _, itemId in ipairs(itemIds) do
        local bagId, slotIndex = Inventory.FindForStation(itemId)
        if bagId then
            where[itemId] = { bagId, slotIndex }
        end
    end
    return where
end

function Inventory.FindForStation(itemId)
    local entry = StationEntry(itemId)
    if entry and entry.stationBag and GetItemId(entry.stationBag, entry.stationSlot) ~= itemId then
        Rebuild()
        entry = stock[itemId]
    end
    if not (entry and entry.stationBag) then
        return nil, nil, 0
    end
    return entry.stationBag, entry.stationSlot, entry.stationTotal
end

-- Item IDs you own of the given item types ({ [ITEMTYPE_x] = true }), anywhere a crafting
-- station can use them (craft bag, backpack, bank). Each ID once.
function Inventory.OwnedItemIds(itemTypes)
    local ids, seen = {}, {}
    for _, bagId in ipairs({ BAG_VIRTUAL, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }) do
        for slotIndex in Slots(bagId) do
            if itemTypes[GetItemType(bagId, slotIndex)] then
                local itemId = GetItemId(bagId, slotIndex)
                if itemId ~= 0 and not seen[itemId] then
                    seen[itemId] = true
                    ids[#ids + 1] = itemId
                end
            end
        end
    end
    table.sort(ids)
    return ids
end

-- Best link we know for an item ID: a real one seen in the inventory, else a bare one. The
-- link cache is saved between sessions, so this never forces a scan; new items join it at the
-- next stock scan.
function Inventory.GetLink(itemId)
    return WC.linkCache[itemId] or Inventory.GenericLink(itemId)
end

-- Compares our per-bag counts with the game's own GetItemLinkStacks totals for every
-- stackable item owned. The game counts per exact link and we count per item ID, so gear
-- and IDs seen with more than one link are skipped. Returns checked, skipped, mismatches.
function Inventory.SelfTest()
    Rebuild()
    -- Same ID, different link (e.g. potions of different levels): the game counts those apart.
    -- Only the self-test needs this, so the normal scan doesn't pay for it.
    local mixed = {}
    for _, bagId in ipairs(STOCK_BAGS) do
        for slotIndex in Slots(bagId) do
            local entry = stock[GetItemId(bagId, slotIndex)]
            if entry and GetItemLink(bagId, slotIndex) ~= entry.link then
                mixed[entry] = true
            end
        end
    end
    local checked, skipped, mismatches = 0, 0, {}
    for itemId, entry in pairs(stock) do
        if not entry.stackable or mixed[entry] then
            skipped = skipped + 1
        else
            checked = checked + 1
            local gameBag, gameBank, gameCraftBag = GetItemLinkStacks(entry.link)
            if gameBag ~= entry.backpack or gameBank ~= entry.bank or gameCraftBag ~= entry.craftBag then
                mismatches[#mismatches + 1] = {
                    itemId = itemId,
                    link   = entry.link,
                    ours   = { entry.backpack, entry.bank, entry.craftBag },
                    game   = { gameBag, gameBank, gameCraftBag },
                }
            end
        end
    end
    return checked, skipped, mismatches
end

-- Accepts an item link anywhere in the text, or a bare item ID. Returns itemId, link.
function Inventory.ParseItemArg(text)
    local link = text and text:match("|H%d:item:[^|]+|h[^|]*|h")
    if link then
        return GetItemLinkItemId(link), link
    end
    local itemId = tonumber(text)
    if itemId and itemId > 0 then
        return itemId, Inventory.GetLink(itemId)
    end
    return nil
end
