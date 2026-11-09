local WC = WritCrafter

-- The master writ queue window (PLAN §2.6.1): every sealed writ in your backpack and bank, with
-- what it pays and costs and whether it's queued, crafted or can't be. Click a writ to queue it
-- (queued writs are crafted the next time you open their station) or to take it off the queue.
-- It shares its queue with the right-click menu. Opened with /wc queue or a keybind.
local Window = {}
WC.QueueWindow = Window

local ROW_TYPE   = 1
local ROW_HEIGHT = 32
local CHECKED    = "EsoUI/Art/Cadwell/checkboxicon_checked.dds"
local UNCHECKED  = "EsoUI/Art/Cadwell/checkboxicon_unchecked.dds"
local DONE       = "/esoui/art/buttons/accept_up.dds"
local CANNOT     = "/esoui/art/buttons/decline_up.dds"

local BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Station order: the order you'd walk the stations in (and the exclusions window's order).
local CRAFT_ORDER = {
    [CRAFTING_TYPE_BLACKSMITHING] = 1, [CRAFTING_TYPE_CLOTHIER] = 2, [CRAFTING_TYPE_WOODWORKING] = 3,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = 4, [CRAFTING_TYPE_ALCHEMY] = 5, [CRAFTING_TYPE_ENCHANTING] = 6,
    [CRAFTING_TYPE_PROVISIONING] = 7,
}

-- Row states.
local STATE_DONE     = "done"       -- an item for it is already made (checked by the inventory scan)
local STATE_QUEUED   = "queued"
local STATE_OPEN     = "open"       -- can be queued
local STATE_REJECTED = "rejected"   -- your settings say no; can still be queued by hand, after a confirm
local STATE_CANNOT   = "cannot"     -- this character can't craft it

-- In the Show menu's order (the value is the menu index).
local FILTER_ALL, FILTER_QUEUED, FILTER_NOT_QUEUED, FILTER_DONE, FILTER_CANNOT = 1, 2, 3, 4, 5

local control, list, showCombo, sortHeaders
local filter = FILTER_ALL
local sortKey, sortUp   -- nil: station order
local entries = {}      -- every sealed writ found when the window was last filled
local shown = {}        -- the entries the list shows now (filter and sort applied)
local refreshPending = false

local function StateOf(entry)
    local status = WC.Reservations.GetWritStatus(entry.uid)
    if status and status.crafted then
        return STATE_DONE
    end
    if WC.Queue.Has(entry.uid) then
        return STATE_QUEUED
    end
    if entry.verdict.status == WC.Rules.CANNOT then
        return STATE_CANNOT
    end
    if entry.verdict.status == WC.Rules.REJECTED then
        return STATE_REJECTED
    end
    return STATE_OPEN
end

-- Every sealed writ WritCrafter understands, with its full verdict (materials, cost, reasons).
local function BuildEntries()
    local result = {}
    for _, bagId in ipairs(BAGS) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            if GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
                local link = GetItemLink(bagId, slotIndex)
                local writ = WC.Master.Parse(link)
                if writ then
                    -- The game's own one-line description ("Craft a Rubedo Leather Jack; Quality: …").
                    local text = (GenerateMasterWritBaseText(link) or ""):gsub("%s*\n%s*", " ")
                    if text == "" then
                        text = zo_strformat("<<t:1>>", GetItemLinkName(link))
                    end
                    result[#result + 1] = {
                        uid       = WC.Master.UniqueId(bagId, slotIndex),
                        bagId     = bagId,
                        slotIndex = slotIndex,
                        link      = link,
                        writ      = writ,
                        verdict   = WC.Rules.Evaluate(writ),
                        text      = text,
                        lower     = text:lower(),
                        inBank    = bagId ~= BAG_BACKPACK,
                    }
                end
            end
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end
    return result
end

local function StationOrder(a, b)
    local oa, ob = CRAFT_ORDER[a.writ.craft] or 99, CRAFT_ORDER[b.writ.craft] or 99
    if oa ~= ob then
        return oa < ob
    end
    return a.lower < b.lower
end

-- Value of a sortable column for one entry. Unpriced writs sort as nil and always go last.
local SORT_VALUES = {
    name       = function(entry) return entry.lower end,
    where      = function(entry) return entry.inBank and 1 or 0 end,
    vouchers   = function(entry) return entry.writ.vouchers end,
    cost       = function(entry) return entry.verdict.cost > 0 and entry.verdict.cost or nil end,
    perVoucher = function(entry) return entry.verdict.perVoucher end,
}

local function SortRows(rows)
    if not sortKey then
        table.sort(rows, StationOrder)
        return
    end
    local valueOf = SORT_VALUES[sortKey]
    local values = {}
    for _, entry in ipairs(rows) do
        values[entry] = valueOf(entry)
    end
    table.sort(rows, function(a, b)
        local va, vb = values[a], values[b]
        if va == vb then
            return StationOrder(a, b)
        elseif va == nil then
            return false
        elseif vb == nil then
            return true
        elseif sortUp then
            return va < vb
        end
        return va > vb
    end)
end

local function UpdateSummary()
    local queued, queuedVouchers, queuedCost = 0, 0, 0
    local done, doneVouchers = 0, 0
    for _, entry in ipairs(entries) do
        local state = StateOf(entry)
        if state == STATE_QUEUED then
            queued = queued + 1
            queuedVouchers = queuedVouchers + entry.writ.vouchers
            queuedCost = queuedCost + entry.verdict.cost
        elseif state == STATE_DONE then
            done = done + 1
            doneVouchers = doneVouchers + entry.writ.vouchers
        end
    end
    local perVoucher = queuedVouchers > 0 and WC.Price.Format(queuedCost / queuedVouchers) or "-"
    control:GetNamedChild("Summary"):SetText(zo_strformat(SI_WRITCRAFTER_QUEUE_SUMMARY,
        queued, queuedVouchers, WC.Price.Format(queuedCost), perVoucher, done, doneVouchers))
end

local FILTERS = {
    [FILTER_ALL]        = function() return true end,
    [FILTER_QUEUED]     = function(state) return state == STATE_QUEUED end,
    [FILTER_NOT_QUEUED] = function(state) return state == STATE_OPEN or state == STATE_REJECTED end,
    [FILTER_DONE]       = function(state) return state == STATE_DONE end,
    [FILTER_CANNOT]     = function(state) return state == STATE_CANNOT end,
}

-- Rebuilds the visible rows for the current filter and sort.
local function FillList()
    local rows, keep = {}, FILTERS[filter]
    for _, entry in ipairs(entries) do
        if keep(StateOf(entry)) then
            rows[#rows + 1] = entry
        end
    end
    SortRows(rows)
    shown = rows

    ZO_ScrollList_Clear(list)
    local dataList = ZO_ScrollList_GetDataList(list)
    for _, entry in ipairs(rows) do
        dataList[#dataList + 1] = ZO_ScrollList_CreateDataEntry(ROW_TYPE, entry)
    end
    ZO_ScrollList_Commit(list)
    control:GetNamedChild("Empty"):SetHidden(#entries > 0)
    UpdateSummary()
end

local STATE_TEXTURE = {
    [STATE_DONE]     = DONE,
    [STATE_QUEUED]   = CHECKED,
    [STATE_OPEN]     = UNCHECKED,
    [STATE_REJECTED] = UNCHECKED,
    [STATE_CANNOT]   = CANNOT,
}

local function SetupRow(row, entry)
    local state = StateOf(entry)
    local check = row:GetNamedChild("Check")
    check:SetTexture(STATE_TEXTURE[state])
    -- Rejected rows are dimmed: they're only queued by hand.
    check:SetAlpha(state == STATE_REJECTED and 0.4 or 1)
    row:GetNamedChild("Icon"):SetTexture(GetItemLinkIcon(entry.link))
    local name = GetItemQualityColor(GetItemLinkDisplayQuality(entry.link)):Colorize(entry.text)
    if state == STATE_REJECTED or state == STATE_CANNOT then
        name = "|c808080" .. entry.text .. "|r"
    end
    row:GetNamedChild("Name"):SetText(name)
    row:GetNamedChild("Where"):SetText(GetString(entry.inBank and SI_WRITCRAFTER_QUEUE_WHERE_BANK
        or SI_WRITCRAFTER_QUEUE_WHERE_BAG))
    row:GetNamedChild("Vouchers"):SetText(entry.writ.vouchers)
    local verdict = entry.verdict
    row:GetNamedChild("Cost"):SetText(verdict.cost > 0 and WC.Price.Format(verdict.cost) or "-")
    row:GetNamedChild("PerVoucher"):SetText(verdict.perVoucher and verdict.cost > 0
        and WC.Price.Format(verdict.perVoucher) or "-")
end

-- Queue or state changed somewhere (here, right-click, a station): redraw rows in place.
function Window.OnQueueChanged()
    if control and not control:IsHidden() then
        if filter == FILTER_ALL then
            ZO_ScrollList_RefreshVisible(list)
            UpdateSummary()
        else
            FillList()   -- a row may no longer belong under the filter
        end
    end
end

-- Bags changed while the window is open (a writ moved, used up or crafted for): rebuild once
-- things settle.
local function OnBagChanged(bagId)
    if refreshPending or not control or control:IsHidden() then
        return
    end
    if bagId and bagId ~= BAG_BACKPACK and bagId ~= BAG_BANK and bagId ~= BAG_SUBSCRIBER_BANK then
        return
    end
    refreshPending = true
    zo_callLater(function()
        refreshPending = false
        if not control:IsHidden() then
            entries = BuildEntries()
            FillList()
        end
    end, 500)
end

function Window.OnRowEnter(row)
    ZO_ScrollList_MouseEnter(list, row)
    local entry = ZO_ScrollList_GetData(row)
    if not entry then
        return
    end
    -- The writ's own tooltip, with WritCrafter's lines (verdict, reasons, materials, cost).
    InitializeTooltip(ItemTooltip, control, RIGHT, -8, 0, LEFT)
    ItemTooltip:SetBagItem(entry.bagId, entry.slotIndex)
end

function Window.OnRowExit(row)
    ZO_ScrollList_MouseExit(list, row)
    ClearTooltip(ItemTooltip)
end

function Window.OnRowMouseUp(row, button, upInside)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
        return
    end
    local entry = ZO_ScrollList_GetData(row)
    if not entry then
        return
    end
    local state = StateOf(entry)
    if state == STATE_QUEUED then
        WC.Queue.Remove(entry.uid)
    elseif state == STATE_OPEN then
        WC.Queue.Add(entry.uid, entry.link)
    elseif state == STATE_REJECTED then
        -- Rejected only by your own settings: queue it anyway, after a confirm.
        ZO_Dialogs_ShowDialog("WRITCRAFTER_QUEUE_OVERRIDE", { uid = entry.uid, link = entry.link },
            { mainTextParams = { entry.text, entry.verdict.reasons[1] or "" } })
    elseif state == STATE_CANNOT then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_QUEUE_CANT, entry.text, entry.verdict.reasons[1] or ""))
    end
end

-- Queues every writ the list shows that passes every rule (never rejected or uncraftable ones).
function Window.EnqueueAll()
    for _, entry in ipairs(shown) do
        if StateOf(entry) == STATE_OPEN then
            WC.Queue.Add(entry.uid, entry.link)
        end
    end
end

function Window.DequeueAll()
    for _, entry in ipairs(shown) do
        if WC.Queue.Has(entry.uid) then
            WC.Queue.Remove(entry.uid)
        end
    end
end

-- Back to station order (the order you'd walk the stations in), clearing any column sort.
function Window.SortByStation()
    sortKey, sortUp = nil, nil
    if sortHeaders.DeselectHeader then
        sortHeaders:DeselectHeader()   -- clears the heading's sort arrow
    end
    FillList()
end

function Window.Open()
    entries = BuildEntries()
    FillList()
    SCENE_MANAGER:ShowTopLevel(control)
end

function Window.Close()
    SCENE_MANAGER:HideTopLevel(control)
end

function Window.Toggle()
    if control:IsHidden() then
        Window.Open()
    else
        Window.Close()
    end
end

local function FillCombo(combo, items, onSelect)
    combo:SetSortsItems(false)
    combo:ClearItems()
    for _, item in ipairs(items) do
        combo:AddItem(combo:CreateItemEntry(item.name, function() onSelect(item.value) end))
    end
end

function Window.Init()
    control = WritCrafterQueueWindow
    control:SetDrawLayer(DL_OVERLAY)
    SCENE_MANAGER:RegisterTopLevel(control, false)

    control:GetNamedChild("Title"):SetText(GetString(SI_WRITCRAFTER_QUEUE_TITLE))
    control:GetNamedChild("Hint"):SetText(GetString(SI_WRITCRAFTER_QUEUE_HINT))
    control:GetNamedChild("ShowLabel"):SetText(GetString(SI_WRITCRAFTER_EXCL_SHOW))
    control:GetNamedChild("Empty"):SetText(GetString(SI_WRITCRAFTER_QUEUE_EMPTY))
    control:GetNamedChild("ByStation"):SetText(GetString(SI_WRITCRAFTER_QUEUE_BY_STATION))
    control:GetNamedChild("EnqueueAll"):SetText(GetString(SI_WRITCRAFTER_QUEUE_ENQUEUE_ALL))
    control:GetNamedChild("DequeueAll"):SetText(GetString(SI_WRITCRAFTER_QUEUE_DEQUEUE_ALL))

    -- Click a heading to sort by it, click again to reverse. Text starts A to Z; numbers start
    -- highest first. "Sort by station" goes back to station order.
    local headers = control:GetNamedChild("Headers")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Name"), GetString(SI_WRITCRAFTER_QUEUE_COL_WRIT),
        "name", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Where"), GetString(SI_WRITCRAFTER_QUEUE_COL_WHERE),
        "where", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Vouchers"), GetString(SI_WRITCRAFTER_QUEUE_COL_VOUCHERS),
        "vouchers", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Cost"), GetString(SI_WRITCRAFTER_QUEUE_COL_COST),
        "cost", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("PerVoucher"), GetString(SI_WRITCRAFTER_QUEUE_COL_PER_VOUCHER),
        "perVoucher", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    sortHeaders = ZO_SortHeaderGroup:New(headers, true)
    sortHeaders:AddHeadersFromContainer()
    sortHeaders:RegisterCallback(ZO_SortHeaderGroup.HEADER_CLICKED, function(key, order)
        sortKey, sortUp = key, order == ZO_SORT_ORDER_UP
        FillList()
    end)

    list = control:GetNamedChild("List")
    ZO_ScrollList_AddDataType(list, ROW_TYPE, "WritCrafterQueueRow", ROW_HEIGHT, SetupRow)
    ZO_ScrollList_EnableHighlight(list, "ZO_ThinListHighlight")

    showCombo = ZO_ComboBox_ObjectFromContainer(control:GetNamedChild("Show"))
    FillCombo(showCombo, {
        { name = GetString(SI_WRITCRAFTER_QUEUE_SHOW_ALL),        value = FILTER_ALL },
        { name = GetString(SI_WRITCRAFTER_QUEUE_SHOW_QUEUED),     value = FILTER_QUEUED },
        { name = GetString(SI_WRITCRAFTER_QUEUE_SHOW_NOT_QUEUED), value = FILTER_NOT_QUEUED },
        { name = GetString(SI_WRITCRAFTER_QUEUE_SHOW_DONE),       value = FILTER_DONE },
        { name = GetString(SI_WRITCRAFTER_QUEUE_SHOW_CANNOT),     value = FILTER_CANNOT },
    }, function(value)
        filter = value
        FillList()
    end)
    showCombo:SelectItemByIndex(FILTER_ALL, true)

    ESO_Dialogs["WRITCRAFTER_QUEUE_OVERRIDE"] = {
        title = { text = SI_WRITCRAFTER_QUEUE_OVERRIDE_TITLE },
        mainText = { text = SI_WRITCRAFTER_QUEUE_OVERRIDE_TEXT },
        buttons = {
            {
                text = SI_DIALOG_CONFIRM,
                callback = function(dialog)
                    WC.Queue.Add(dialog.data.uid, dialog.data.link, true)
                end,
            },
            { text = SI_DIALOG_CANCEL },
        },
    }

    WC.Inventory.AddListener(OnBagChanged)
end
