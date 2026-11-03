local WC = WritCrafter

local Inventory = {}
WC.Inventory = Inventory

-- Stock counts everything you can reach without a trip: backpack, bank, ESO+ bank, craft bag.
-- House storage is deliberately left out (plan §9).
local STOCK_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK, BAG_VIRTUAL }

local GENERIC_LINK = "|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h"

-- [itemId] = { backpack, bank, craftBag, locked, link, stackable }
local stock = {}
local dirty = true

-- The game only lets players lock equippable gear, so for materials, consumables and glyphs
-- this is only ever true through an FCO ItemSaver mark.
local function IsSlotLocked(bagId, slotIndex)
    if bagId == BAG_VIRTUAL then
        return false
    end
    if IsItemPlayerLocked(bagId, slotIndex) then
        return true
    end
    -- -1 asks FCO ItemSaver about every marker icon at once.
    if FCOIS and FCOIS.IsMarked then
        return FCOIS.IsMarked(bagId, slotIndex, -1) == true
    end
    return false
end

local function Rebuild()
    ZO_ClearTable(stock)
    local linkCache = WC.linkCache
    for _, bagId in ipairs(STOCK_BAGS) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            local itemId = GetItemId(bagId, slotIndex)
            if itemId and itemId ~= 0 then
                local count, maxCount = GetSlotStackSize(bagId, slotIndex)
                local entry = stock[itemId]
                if not entry then
                    entry = {
                        backpack  = 0,
                        bank      = 0,
                        craftBag  = 0,
                        locked    = 0,
                        link      = GetItemLink(bagId, slotIndex),
                        stackable = maxCount > 1,
                    }
                    stock[itemId] = entry
                elseif not entry.mixedLinks and GetItemLink(bagId, slotIndex) ~= entry.link then
                    -- Same ID, different link (e.g. potions of different levels).
                    entry.mixedLinks = true
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
                end
                -- Only stackables (materials, consumables) are worth remembering for price lookups.
                if entry.stackable and not linkCache[itemId] then
                    linkCache[itemId] = entry.link
                end
            end
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end
    dirty = false
end

local function OnInventoryChanged()
    dirty = true
end

function Inventory.Init()
    local namespace = WC.name .. "Inventory"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnInventoryChanged)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_FULL_UPDATE, OnInventoryChanged)
end

-- Bag events don't fire when FCO ItemSaver marks change, so callers that are about to plan
-- crafts call this first to get a fresh scan.
function Inventory.Invalidate()
    dirty = true
end

-- Returns { backpack, bank, craftBag, locked, total, usable } for one item ID.
-- "locked" is only subtracted from "usable" when the Don't use locked items setting is on.
function Inventory.GetStock(itemId)
    if dirty then
        Rebuild()
    end
    local entry = stock[itemId]
    local backpack = entry and entry.backpack or 0
    local bank     = entry and entry.bank or 0
    local craftBag = entry and entry.craftBag or 0
    local locked   = (entry and WC.settings.respectLocks) and entry.locked or 0
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

-- Best link we know for an item ID: a real one seen in the inventory, else a bare one.
function Inventory.GetLink(itemId)
    if dirty then
        Rebuild()
    end
    return WC.linkCache[itemId] or string.format(GENERIC_LINK, itemId)
end

-- Compares our per-bag counts with the game's own GetItemLinkStacks totals for every
-- stackable item owned. The game counts per exact link and we count per item ID, so gear
-- and IDs seen with more than one link are skipped. Returns checked, skipped, mismatches.
function Inventory.SelfTest()
    Rebuild()
    local checked, skipped, mismatches = 0, 0, {}
    for itemId, entry in pairs(stock) do
        if not entry.stackable or entry.mixedLinks then
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
