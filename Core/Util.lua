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

-- Server requests, one at a time -----------------------------------------------------------------
-- Bank moves and merchant sales are queued and sent one by one: each waits until the server has
-- changed the item it asked about (or REQUEST_TIMEOUT_MS passes) before the next goes out. Sending
-- dozens in one frame risks being kicked for flooding the server, and a timer guessed from your
-- ping (Dolgubon's way) misfires whenever the server is slower than usual. Closing the bank or
-- merchant drops the requests still waiting for it.
-- Added 2026-11-21. If it turns out slow or unreliable, set REQUEST_ONE_AT_A_TIME to false: every
-- request is then sent at once, as before.
local REQUEST_ONE_AT_A_TIME = true
local REQUEST_MIN_GAP_MS    = 50     -- never faster than this, even when the server answers sooner
local REQUEST_TIMEOUT_MS    = 1500   -- no change by then: carry on with the next one

local requests = {}   -- waiting to be sent: { bagId, slotIndex, interaction, send, onDone }
local current         -- sent, waiting for the server: { request, uid, count, sentMs }
local REQUEST_NAME = "WritCrafterRequest"

local function SlotState(bagId, slotIndex)
    return Util.UniqueId(bagId, slotIndex), GetSlotStackSize(bagId, slotIndex)
end

local Requests = {}   -- Requests.Pump, so Finish can call it before it is defined

local function Finish(ok)
    EVENT_MANAGER:UnregisterForEvent(REQUEST_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE)
    EVENT_MANAGER:UnregisterForUpdate(REQUEST_NAME .. "Timeout")
    local request, sentMs = current.request, current.sentMs
    current = nil
    if request.onDone then
        request.onDone(ok)
    end
    local wait = REQUEST_MIN_GAP_MS - (GetFrameTimeMilliseconds() - sentMs)
    if wait > 0 then
        Util.Later("RequestNext", wait, Requests.Pump)
    else
        Requests.Pump()
    end
end

local function OnRequestSlotUpdate(_, bagId, slotIndex)
    if current and bagId == current.request.bagId and slotIndex == current.request.slotIndex then
        local uid, count = SlotState(bagId, slotIndex)
        if uid ~= current.uid or count ~= current.count then
            Finish(true)
        end
    end
end

function Requests.Pump()
    while not current and #requests > 0 do
        local request = table.remove(requests, 1)
        local uid, count = SlotState(request.bagId, request.slotIndex)
        if count == 0 then
            if request.onDone then request.onDone(false) end   -- already gone
        elseif not REQUEST_ONE_AT_A_TIME then
            request.send()
            if request.onDone then request.onDone(true) end
        else
            current = { request = request, uid = uid, count = count, sentMs = GetFrameTimeMilliseconds() }
            EVENT_MANAGER:RegisterForEvent(REQUEST_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnRequestSlotUpdate)
            -- Only the bag the request is about, ordinary changes only (Finish unregisters, which
            -- also drops this filter, so each request gets its own).
            EVENT_MANAGER:AddFilterForEvent(REQUEST_NAME, EVENT_INVENTORY_SINGLE_SLOT_UPDATE,
                REGISTER_FILTER_BAG_ID, request.bagId,
                REGISTER_FILTER_INVENTORY_UPDATE_REASON, INVENTORY_UPDATE_REASON_DEFAULT)
            EVENT_MANAGER:RegisterForUpdate(REQUEST_NAME .. "Timeout", REQUEST_TIMEOUT_MS, function()
                if current then
                    Finish(false)
                end
            end)
            request.send()
        end
    end
end

-- Drops the requests still waiting for an interaction that has just closed.
local function Cancel(interaction)
    for i = #requests, 1, -1 do
        local request = requests[i]
        if request.interaction == interaction then
            table.remove(requests, i)
            if request.onDone then request.onDone(false) end
        end
    end
end

local requestEventsRegistered = false

local function Queue(request)
    if not requestEventsRegistered then
        requestEventsRegistered = true
        EVENT_MANAGER:RegisterForEvent(REQUEST_NAME .. "Bank", EVENT_CLOSE_BANK, function() Cancel("bank") end)
        EVENT_MANAGER:RegisterForEvent(REQUEST_NAME .. "Store", EVENT_CLOSE_STORE, function() Cancel("store") end)
    end
    requests[#requests + 1] = request
    Requests.Pump()
end

-- Moves an item to or from the open bank or storage chest, after the requests already queued.
-- onDone(ok), optional: ok is false when it was dropped or the server didn't answer in time.
function Util.QueueMove(fromBag, fromSlot, toBag, toSlot, quantity, onDone)
    Queue({
        bagId = fromBag, slotIndex = fromSlot, interaction = "bank", onDone = onDone,
        send = function() Util.MoveItem(fromBag, fromSlot, toBag, toSlot, quantity) end,
    })
end

-- Sells part or all of a backpack stack at the open merchant, after the requests already queued.
function Util.QueueSell(slotIndex, quantity, onDone)
    Queue({
        bagId = BAG_BACKPACK, slotIndex = slotIndex, interaction = "store", onDone = onDone,
        send = function() SellInventoryItem(BAG_BACKPACK, slotIndex, quantity) end,
    })
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
