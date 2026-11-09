local WC = WritCrafter

-- Items made for (or taken out of storage for) daily writs, remembered by unique ID with their
-- quest's name, so they keep a badge after the quest moves on to "deliver" and its craft
-- conditions leave the journal. Forgotten when the quest is turned in or abandoned.
-- Per character, kept across reloads.
local DailyItems = {}
WC.DailyItems = DailyItems

local RECORD_MS = 10000   -- longest a craft's new items can take to land

local items                 -- WC.character.dailyItems: [unique ID] = quest name
local recording, recordUntil

local function UniqueId(bagId, slotIndex)
    return Id64ToString(GetItemUniqueId(bagId, slotIndex))
end

-- [bagId][slotIndex] = quest, or false for "none": answers remembered until that slot changes,
-- so drawing rows doesn't build an item ID string per slot every time.
local bySlot = {}

function DailyItems.Add(bagId, slotIndex, quest)
    items[UniqueId(bagId, slotIndex)] = quest
    ZO_ClearTable(bySlot)
    WC.InventoryIcons.OnWritItemsChanged()
end

-- The daily quest an item was made for, or nil.
function DailyItems.QuestFor(bagId, slotIndex)
    if next(items) == nil then
        return nil
    end
    local bag = bySlot[bagId]
    if not bag then
        bag = {}
        bySlot[bagId] = bag
    end
    local quest = bag[slotIndex]
    if quest == nil then
        quest = items[UniqueId(bagId, slotIndex)] or false
        bag[slotIndex] = quest
    end
    return quest or nil
end

-- Called by the engine before each craft: quest for a daily writ's craft, nil for anything else
-- (which also ends the previous recording, so a master writ's items are never taken for daily ones).
function DailyItems.Begin(quest)
    recording = quest
    recordUntil = GetGameTimeMilliseconds() + RECORD_MS
end

-- New writ-type items landing in the backpack while a daily craft is recording.
local function OnSlotUpdate(_, bagId, slotIndex, _, _, _, stackCountChange)
    if not recording or (stackCountChange or 0) <= 0 then
        return
    end
    if GetGameTimeMilliseconds() > recordUntil then
        recording = nil
        return
    end
    if WC.Reservations.IsCandidateType(GetItemType(bagId, slotIndex)) then
        DailyItems.Add(bagId, slotIndex, recording)
    end
end

local function Forget(quest)
    local changed = false
    for uid, name in pairs(items) do
        if name == quest then
            items[uid] = nil
            changed = true
        end
    end
    if changed then
        ZO_ClearTable(bySlot)
        WC.InventoryIcons.OnWritItemsChanged()
    end
end

-- Forgets items whose quest was finished or abandoned while WritCrafter wasn't running. Runs once
-- the character is in the world: on a fresh login the journal may still be empty when add-ons
-- load (a reload already has it), which would forget everything. An empty journal is also
-- taken as not loaded yet, so nothing is forgotten then.
local function Prune()
    local open, any = {}, false
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) then
            open[GetJournalQuestName(questIndex)] = true
            any = true
        end
    end
    if not any then
        return
    end
    for uid, quest in pairs(items) do
        if not open[quest] then
            items[uid] = nil
        end
    end
    ZO_ClearTable(bySlot)
    WC.InventoryIcons.OnWritItemsChanged()
end

function DailyItems.Init()
    WC.character.dailyItems = WC.character.dailyItems or {}
    items = WC.character.dailyItems

    -- A slot that changed may hold a different item now.
    WC.Inventory.AddListener(function(bagId, slotIndex)
        if not bagId then
            ZO_ClearTable(bySlot)
        elseif bySlot[bagId] then
            bySlot[bagId][slotIndex] = nil
        end
    end)

    local namespace = WC.name .. "DailyItems"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_ACTIVATED)
        Prune()
    end)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    EVENT_MANAGER:AddFilterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
        REGISTER_FILTER_BAG_ID, BAG_BACKPACK)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_REMOVED, function(_, _, _, questName)
        Forget(questName)
    end)
end
