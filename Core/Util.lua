local WC = WritCrafter

-- Small helpers used across WritCrafter, kept in one place instead of a copy per file.
local Util = {}
WC.Util = Util

-- An item's name for chat and windows, from an item ID or an item link.
function Util.ItemName(item)
    local link = type(item) == "number" and WC.Inventory.GetLink(item) or item
    return zo_strformat("<<t:1>>", GetItemLinkName(link or ""))
end

-- A craft's name ("Blacksmithing"), from its CRAFTING_TYPE_x.
function Util.CraftName(craft)
    return zo_strformat("<<1>>", GetCraftingSkillName(craft))
end

-- A chat line from one of WritCrafter's strings and its arguments.
function Util.Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

-- An item's unique ID as a string, stable while it moves between bags.
function Util.UniqueId(bagId, slotIndex)
    return Id64ToString(GetItemUniqueId(bagId, slotIndex))
end

-- Using and moving items are protected game functions: called through the game's secure call
-- when they are, directly otherwise.
local function CallProtected(name, ...)
    if IsProtectedFunction(name) then
        CallSecureProtected(name, ...)
    else
        _G[name](...)
    end
end

-- true while a Util.UseItem call is in progress: lets other code (the master writ accept guard)
-- tell WritCrafter's own item use apart from the player's, since both end up calling the same
-- protected UseItem.
local automatedUse = false

function Util.IsAutomatedUse()
    return automatedUse
end

function Util.UseItem(bagId, slotIndex)
    automatedUse = true
    CallProtected("UseItem", bagId, slotIndex)
    automatedUse = false
end

function Util.MoveItem(fromBag, fromSlot, toBag, toSlot, quantity)
    CallProtected("RequestMoveItem", fromBag, fromSlot, toBag, toSlot, quantity)
end

-- House storage chests, as bags (their contents can only be read inside your own house).
Util.HOUSE_BAGS = {}
if BAG_HOUSE_BANK_ONE and BAG_HOUSE_BANK_TEN then
    for bagId = BAG_HOUSE_BANK_ONE, BAG_HOUSE_BANK_TEN do
        Util.HOUSE_BAGS[#Util.HOUSE_BAGS + 1] = bagId
    end
end

function Util.IsHouseBag(bagId)
    return BAG_HOUSE_BANK_ONE ~= nil and BAG_HOUSE_BANK_TEN ~= nil
        and bagId >= BAG_HOUSE_BANK_ONE and bagId <= BAG_HOUSE_BANK_TEN
end

-- Whether you're inside a house you own (so its storage chests can be read).
function Util.InOwnHouse()
    return #Util.HOUSE_BAGS > 0 and IsOwnerOfCurrentHouse ~= nil and IsOwnerOfCurrentHouse()
end

-- List windows ----------------------------------------------------------------------------------

-- Sorts rows by valueOf(row), ascending or not; rows without a value go last, ties by tieBreak.
-- Each value is worked out once, not once per comparison.
function Util.SortRows(rows, valueOf, ascending, tieBreak)
    local values = {}
    for _, row in ipairs(rows) do
        values[row] = valueOf(row)
    end
    table.sort(rows, function(a, b)
        local va, vb = values[a], values[b]
        if va == vb then
            return tieBreak(a, b)
        elseif va == nil then
            return false
        elseif vb == nil then
            return true
        elseif ascending then
            return va < vb
        end
        return va > vb
    end)
end

-- Fills a dropdown with { name, value } items; picking one calls onSelect(value).
function Util.FillCombo(combo, items, onSelect)
    combo:SetSortsItems(false)
    combo:ClearItems()
    for _, item in ipairs(items) do
        combo:AddItem(combo:CreateItemEntry(item.name, function() onSelect(item.value) end))
    end
end

-- Replaces a scroll list's rows.
function Util.FillScrollList(list, rowType, rows)
    ZO_ScrollList_Clear(list)
    local dataList = ZO_ScrollList_GetDataList(list)
    for _, row in ipairs(rows) do
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(rowType, row)
    end
    ZO_ScrollList_Commit(list)
end

-- Runs fn once things have settled: each call within ms of the last pushes it back, so a burst
-- of events (bag changes, journal updates) does the work once. name keeps separate jobs apart.
function Util.Later(name, ms, fn)
    local updateName = WC.name .. name
    EVENT_MANAGER:UnregisterForUpdate(updateName)
    EVENT_MANAGER:RegisterForUpdate(updateName, ms, function()
        EVENT_MANAGER:UnregisterForUpdate(updateName)
        fn()
    end)
end
