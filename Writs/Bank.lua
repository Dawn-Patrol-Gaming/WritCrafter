local WC = WritCrafter

-- Bank withdrawal for daily writs. "Acquire a reagent" conditions count the backpack and craft
-- bag but not the bank, and a crafting station can't take items out of the bank. So when you
-- open your bank with daily writs in your journal, the reagents those conditions still need are
-- moved to your backpack: only the missing amount, only reagents you allow, never stacks marked
-- with FCO ItemSaver. (Crafting materials don't need this: stations use the bank directly.)
local Bank = {}
WC.Bank = Bank

local BANK_BAGS = { BAG_BANK, BAG_SUBSCRIBER_BANK }

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

local function OnOpenBank(_, bankBag)
    if bankBag ~= BAG_BANK or not WC.settings.bankWithdraw or not WC.Daily.HasAny() then
        return
    end
    local empties, nextEmpty = EmptySlots(), 1
    for _, condition in ipairs(WC.Daily.Conditions()) do
        local need = condition.max - condition.current
        local itemId = need > 0 and WC.Daily.AcquireItem(condition)
        if itemId then
            if not WC.Policy.IsReagentAllowed(itemId) then
                Say(SI_WRITCRAFTER_BANK_EXCLUDED, ItemName(itemId))
            else
                local moved = 0
                for _, bagId in ipairs(BANK_BAGS) do
                    local slotIndex = ZO_GetNextBagSlotIndex(bagId)
                    while slotIndex and need > 0 do
                        if GetItemId(bagId, slotIndex) == itemId and not WC.Inventory.IsProtected(bagId, slotIndex) then
                            local destSlot = empties[nextEmpty]
                            if not destSlot then
                                Say(SI_WRITCRAFTER_BANK_FULL)
                                return
                            end
                            nextEmpty = nextEmpty + 1
                            local quantity = zo_min(GetSlotStackSize(bagId, slotIndex), need)
                            Move(bagId, slotIndex, destSlot, quantity)
                            need = need - quantity
                            moved = moved + quantity
                        end
                        slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
                    end
                end
                if moved > 0 then
                    Say(SI_WRITCRAFTER_BANK_TOOK, moved, ItemName(itemId))
                end
            end
        end
    end
end

function Bank.Init()
    EVENT_MANAGER:RegisterForEvent(WC.name .. "Bank", EVENT_OPEN_BANK, OnOpenBank)
end
