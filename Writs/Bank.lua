local WC = WritCrafter

-- Storage withdrawal for writs. Writ quest conditions only count what's in the backpack (and,
-- for "acquire" conditions, the craft bag), and a crafting station can't take finished items out
-- of storage. So when you open your bank, or a storage chest in a house, with writ quests in your
-- journal (daily, or accepted master writs), what those conditions still need is moved to your
-- backpack:
--   - "acquire" conditions: the reagent or solvent;
--   - "craft" conditions: finished items you already have (potions, poisons, food, drink,
--     glyphs, gear), so nothing is crafted twice;
--   - sealed master writs in the backpack: the crafted items set aside for them, so they can be
--     accepted and turned in one after another. Writs in the bank are left for you to take.
--   - accepted master writs: their crafted items, until the quest is turned in.
-- Only the missing amount; never excluded materials, locked or FCO ItemSaver-marked items, or
-- items set aside for sealed master writs. For daily writs gear must also be plain (no trait,
-- normal quality), since any such piece counts and real gear shouldn't be handed in; a master
-- writ only accepts its exact piece.
-- (Crafting materials don't need this: stations use the bank directly.)
local Bank = {}
WC.Bank = Bank

local BANK_BAGS = { BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Finished item types a daily "craft" condition can accept.
local FINISHED_TYPES = {
    [ITEMTYPE_POTION] = true, [ITEMTYPE_POISON] = true, [ITEMTYPE_FOOD] = true, [ITEMTYPE_DRINK] = true,
    [ITEMTYPE_GLYPH_ARMOR] = true, [ITEMTYPE_GLYPH_WEAPON] = true, [ITEMTYPE_GLYPH_JEWELRY] = true,
    [ITEMTYPE_WEAPON] = true, [ITEMTYPE_ARMOR] = true,
}

local function Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

-- Empty backpack slots, so each move gets its own destination (moves land asynchronously).
local function EmptySlots()
    local slots = {}
    for slotIndex = 0, GetBagSize(BAG_BACKPACK) - 1 do
        if GetItemId(BAG_BACKPACK, slotIndex) == 0 then
            slots[#slots + 1] = slotIndex
        end
    end
    return slots
end

local function Move(bagId, slotIndex, destSlot, quantity)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", bagId, slotIndex, BAG_BACKPACK, destSlot, quantity)
    else
        RequestMoveItem(bagId, slotIndex, BAG_BACKPACK, destSlot, quantity)
    end
end

-- A finished item WritCrafter may hand to a daily writ: gear only when plain (no trait, normal
-- quality), since any such piece counts and real gear shouldn't be handed in.
local function MayTake(bagId, slotIndex)
    if WC.Inventory.IsProtected(bagId, slotIndex) or WC.Reservations.GetReserved(bagId, slotIndex) > 0 then
        return false
    end
    local itemType = GetItemType(bagId, slotIndex)
    if itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
        if IsItemPlayerLocked(bagId, slotIndex) then
            return false
        end
        return GetItemTrait(bagId, slotIndex) == ITEM_TRAIT_TYPE_NONE
            and GetItemLinkFunctionalQuality(GetItemLink(bagId, slotIndex)) == ITEM_FUNCTIONAL_QUALITY_NORMAL
    end
    return true
end

-- A stored finished item a daily condition accepts and WritCrafter may hand to it.
local function Fits(condition, bagId, slotIndex)
    return FINISHED_TYPES[GetItemType(bagId, slotIndex)]
        and DoesItemFulfillJournalQuestCondition(bagId, slotIndex,
            condition.questIndex, condition.stepIndex, condition.conditionIndex)
        and MayTake(bagId, slotIndex)
end

-- How many finished items in storage a daily condition would take (and the first one's name),
-- so a station doesn't craft another one. The bank is readable anywhere; house storage chests
-- only inside your own house. Remembered per condition until a bag or the journal changes.
local storedCache = {}   -- [condition text] = { count, name }
local storedItems        -- { bagId, slotIndex } of finished items in storage MayTake allows; nil until scanned

-- One pass over storage for all daily tasks: only the finished items WritCrafter may hand over
-- are kept, so each task then asks the game about a short list instead of every slot.
local function StoredItems()
    if storedItems then
        return storedItems
    end
    local bags = { BAG_BANK, BAG_SUBSCRIBER_BANK }
    if BAG_HOUSE_BANK_ONE and BAG_HOUSE_BANK_TEN and IsOwnerOfCurrentHouse and IsOwnerOfCurrentHouse() then
        for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
            bags[#bags + 1] = bagId
        end
    end
    storedItems = {}
    for _, bagId in ipairs(bags) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            if FINISHED_TYPES[GetItemType(bagId, slotIndex)] and MayTake(bagId, slotIndex) then
                storedItems[#storedItems + 1] = { bagId = bagId, slotIndex = slotIndex }
            end
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end
    return storedItems
end

local function StoredNow(condition)
    local count, name = 0, nil
    for _, item in ipairs(StoredItems()) do
        if DoesItemFulfillJournalQuestCondition(item.bagId, item.slotIndex,
            condition.questIndex, condition.stepIndex, condition.conditionIndex) then
            count = count + GetSlotStackSize(item.bagId, item.slotIndex)
            name = name or zo_strformat("<<t:1>>", GetItemName(item.bagId, item.slotIndex))
        end
    end
    return count, name
end

function Bank.Stored(condition)
    local hit = storedCache[condition.text]
    if not hit then
        hit = { StoredNow(condition) }
        storedCache[condition.text] = hit
    end
    return hit[1], hit[2]
end

function Bank.ClearStored()
    ZO_ClearTable(storedCache)
    storedItems = nil
end

-- The storage bags an open bank event gives access to: the bank, or one house storage chest.
local function OpenedBags(bankBag)
    if bankBag == BAG_BANK then
        return BANK_BAGS
    end
    if BAG_HOUSE_BANK_ONE and BAG_HOUSE_BANK_TEN and bankBag >= BAG_HOUSE_BANK_ONE and bankBag <= BAG_HOUSE_BANK_TEN then
        return { bankBag }
    end
end

local function OnOpenBank(_, bankBag)
    local bags = OpenedBags(bankBag)
    if not bags then
        return
    end
    local empties, nextEmpty = EmptySlots(), 1
    -- Moves up to need from slots that match, returns what's still needed, or nil when the
    -- backpack is full. dailyQuest: remember each item taken as made for that daily writ.
    local function Take(match, need, dailyQuest)
        local moved, name = 0, nil
        for _, bagId in ipairs(bags) do
            local slotIndex = ZO_GetNextBagSlotIndex(bagId)
            while slotIndex and need > 0 do
                if match(bagId, slotIndex) then
                    local destSlot = empties[nextEmpty]
                    if not destSlot then
                        Say(SI_WRITCRAFTER_BANK_FULL)
                        return nil
                    end
                    nextEmpty = nextEmpty + 1
                    local quantity = zo_min(GetSlotStackSize(bagId, slotIndex), need)
                    name = name or zo_strformat("<<t:1>>", GetItemName(bagId, slotIndex))
                    if dailyQuest then
                        WC.DailyItems.Add(bagId, slotIndex, dailyQuest)   -- unique ID moves with it
                    end
                    Move(bagId, slotIndex, destSlot, quantity)
                    need = need - quantity
                    moved = moved + quantity
                end
                slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
            end
        end
        if moved > 0 then
            Say(SI_WRITCRAFTER_BANK_TOOK, moved, name)
        end
        return need
    end

    -- Master writs: the crafted items of sealed writs in the backpack (the writs themselves are
    -- left where you put them), and of accepted writs, also once the quest has moved on to
    -- delivery. Only from the storage just opened (the bank, or this house chest). Re-matched
    -- first, in case that storage's contents only just became readable.
    if WC.settings.bankWithdrawMaster then
        WC.Reservations.Invalidate()
        local opened = {}
        for _, bagId in ipairs(bags) do
            opened[bagId] = true
        end
        local items = {}
        for _, list in ipairs({ WC.Reservations.BankItemsForBackpackWrits(), WC.Reservations.BankItemsForAcceptedWrits() }) do
            for _, item in ipairs(list) do
                if opened[item.bagId] then
                    items[#items + 1] = item
                end
            end
        end
        for _, item in ipairs(items) do
            local destSlot = empties[nextEmpty]
            if not destSlot then
                Say(SI_WRITCRAFTER_BANK_FULL)
                return
            end
            nextEmpty = nextEmpty + 1
            Say(SI_WRITCRAFTER_BANK_TOOK, item.quantity, zo_strformat("<<t:1>>", GetItemName(item.bagId, item.slotIndex)))
            Move(item.bagId, item.slotIndex, destSlot, item.quantity)
        end
    end

    if not WC.Daily.HasAny() then
        return
    end
    -- Daily writs. (Accepted master writs were handled above.)
    for _, condition in ipairs(WC.Daily.Conditions()) do
        local need = condition.max - condition.current
        if need > 0 then
            local itemId = WC.Daily.AcquireItem(condition)
            local left
            if itemId then
                if WC.Policy.IsExcluded(itemId) then
                    Say(SI_WRITCRAFTER_BANK_EXCLUDED, ItemName(itemId))
                    left = need
                else
                    left = Take(function(bagId, slotIndex)
                        return GetItemId(bagId, slotIndex) == itemId and not WC.Inventory.IsProtected(bagId, slotIndex)
                    end, need)
                end
            elseif WC.settings.bankWithdrawDaily then
                left = Take(function(bagId, slotIndex)
                    return Fits(condition, bagId, slotIndex)
                end, need, condition.quest)
            else
                left = need   -- finished daily items stay in storage (setting off)
            end
            if left == nil then
                return   -- backpack full
            end
        end
    end
end

function Bank.Init()
    EVENT_MANAGER:RegisterForEvent(WC.name .. "Bank", EVENT_OPEN_BANK, OnOpenBank)
    WC.Inventory.AddListener(Bank.ClearStored)
    WC.Daily.OnJournalChanged(Bank.ClearStored)
end
