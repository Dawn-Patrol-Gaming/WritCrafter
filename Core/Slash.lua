local WC = WritCrafter

local Slash = {}
WC.Slash = Slash

local ItemName = WC.Util.ItemName

local function ShowStock(rest)
    local itemId, link = WC.Inventory.ParseItemArg(rest)
    if not itemId then
        WC.Log.Say(GetString(WRITCRAFTER_NEED_ITEM))
        return
    end
    WC.Inventory.Invalidate()
    local s = WC.Inventory.GetStock(itemId)
    if s.locked > 0 then
        WC.Log.Say(zo_strformat(WRITCRAFTER_STOCK_LOCKED, ItemName(link), s.backpack, s.bank, s.craftBag, s.usable, s.locked))
    else
        WC.Log.Say(zo_strformat(WRITCRAFTER_STOCK, ItemName(link), s.backpack, s.bank, s.craftBag, s.usable))
    end
end

local function ShowPrice(rest)
    local itemId, link = WC.Inventory.ParseItemArg(rest)
    if not itemId then
        WC.Log.Say(GetString(WRITCRAFTER_NEED_ITEM))
        return
    end
    local gold, source = WC.Price.Get(link)
    if gold then
        WC.Log.Say(zo_strformat(WRITCRAFTER_PRICE, ItemName(link), WC.Price.Format(gold), WC.Price.SourceName(source)))
    else
        WC.Log.Say(zo_strformat(WRITCRAFTER_PRICE_NONE, ItemName(link)))
    end
end

local SELFTEST_SHOWN = 10

local function SelfTest()
    local checked, skipped, mismatches = WC.Inventory.SelfTest()
    if #mismatches == 0 then
        WC.Log.Say(zo_strformat(WRITCRAFTER_SELFTEST_OK, checked, skipped))
        return
    end
    WC.Log.Say(zo_strformat(WRITCRAFTER_SELFTEST_FAIL, #mismatches, checked))
    local showAll = WC.settings.logLevel >= WC.Log.LEVEL_DEBUG
    for i, m in ipairs(mismatches) do
        if i > SELFTEST_SHOWN and not showAll then
            WC.Log.Say(zo_strformat(WRITCRAFTER_SELFTEST_MORE, #mismatches - SELFTEST_SHOWN))
            break
        end
        WC.Log.Say(zo_strformat(WRITCRAFTER_SELFTEST_ROW, ItemName(m.link), m.itemId,
            m.ours[1], m.ours[2], m.ours[3], m.game[1], m.game[2], m.game[3]))
    end
end

local function ToggleDebug()
    if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
        WC.settings.logLevel = WC.Log.LEVEL_NORMAL
        WC.Log.Say(GetString(WRITCRAFTER_DEBUG_OFF))
    else
        WC.settings.logLevel = WC.Log.LEVEL_DEBUG
        WC.Log.Say(GetString(WRITCRAFTER_DEBUG_ON))
    end
end

local Say = WC.Log.Say

local handlers = {}   -- [command] = the function WritCrafter registered for it
local typed           -- the command being answered ("/wc" or "/writcrafter"), so replies repeat it

-- The command to mention outside a reply (settings text): /wc, unless another add-on has it.
function Slash.Primary()
    local current = SLASH_COMMANDS["/wc"]
    if current == nil or current == handlers["/wc"] then
        return "/wc"
    end
    return "/writcrafter"
end

local function Typed()
    return typed or Slash.Primary()
end

local function QueueCommand(rest)
    local word = rest:lower()
    if word == "" then
        WC.QueueWindow.Toggle()
    elseif word == "all" then
        Say(zo_strformat(WRITCRAFTER_SLASH_QUEUED_ALL, WC.QueueWindow.EnqueueAllWrits()))
    elseif word == "clear" or word == "none" then
        Say(zo_strformat(WRITCRAFTER_SLASH_QUEUE_CLEARED, WC.Queue.Clear()))
    else
        Say(zo_strformat(WRITCRAFTER_SLASH_QUEUE_USAGE, Typed()))
    end
end

local MARKER_MODES = {
    [WC.Markers.OFF]    = WRITCRAFTER_MARKERS_OFF,
    [WC.Markers.ALL]    = WRITCRAFTER_MARKERS_ALL,
    [WC.Markers.QUEUED] = WRITCRAFTER_MARKERS_QUEUED,
}

-- No word: says the current setting.
local function MarkersCommand(rest)
    local mode = rest:lower()
    -- Other words people naturally type for the same settings.
    if mode == "none" then
        mode = WC.Markers.OFF
    elseif mode == "queue" then
        mode = WC.Markers.QUEUED
    end
    if mode ~= "" then
        if not MARKER_MODES[mode] then
            Say(zo_strformat(WRITCRAFTER_SLASH_MARKERS_USAGE, Typed()))
            return
        end
        WC.settings.stationMarkers = mode
        WC.Markers.Refresh()
    end
    local current = WC.settings.stationMarkers or WC.Markers.OFF
    Say(zo_strformat(WRITCRAFTER_SLASH_MARKERS, GetString(MARKER_MODES[current] or WRITCRAFTER_MARKERS_OFF)))
    if WC.Markers.EhtMarking() then
        Say(GetString(WRITCRAFTER_SLASH_MARKERS_EHT))
    end
end

-- No word: says the current setting.
local function GuardCommand(rest)
    local word = rest:lower()
    if word == "on" or word == "off" then
        WC.settings.acceptGuard = word == "on"
        WC.Policy.Changed()
    elseif word ~= "" then
        Say(zo_strformat(WRITCRAFTER_SLASH_GUARD_USAGE, Typed()))
        return
    end
    Say(GetString(WC.settings.acceptGuard and WRITCRAFTER_SLASH_GUARD_ON or WRITCRAFTER_SLASH_GUARD_OFF))
end

local RESET_DIALOG = "WRITCRAFTER_RESET"

-- Drops this account's WritCrafter data on this megaserver (the whole ZO_SavedVars table: see
-- SavedVars.lua), then reloads so everything starts from the defaults.
local function ResetEverything()
    local world = WritCrafterVars and WritCrafterVars[GetWorldName()]
    if world then
        world[GetDisplayName()] = nil
    end
    ReloadUI("ingame")
end

local COMMANDS = {
    settings   = function() WC.Settings.Open() end,
    exclusions = function() WC.ExclusionsWindow.Open() end,
    stock    = ShowStock,
    price    = ShowPrice,
    selftest = SelfTest,
    debug    = ToggleDebug,
    perf     = function() WC.Perf.Run() end,
    checkdata = function() WC.CheckData.Run() end,
    stations = function() WC.Markers.Diagnose() end,
    reagents = function() WC.AlchemyDaily.List() end,
    quests   = function() WC.Daily.ListQuests() end,
    queue    = QueueCommand,
    accept   = function() WC.Rolis.AcceptCrafted(true) end,
    markers  = MarkersCommand,
    guard    = GuardCommand,
    reset    = function() ZO_Dialogs_ShowDialog(RESET_DIALOG) end,
    help     = function()
        -- The list in the command you typed; the header names the other one when it's ours too.
        local other = typed == "/wc" and "/writcrafter" or "/wc"
        if SLASH_COMMANDS[other] ~= nil and SLASH_COMMANDS[other] == handlers[other] then
            Say(zo_strformat(WRITCRAFTER_HELP_HEADER_BOTH, other))
        else
            Say(GetString(WRITCRAFTER_HELP_HEADER))
        end
        Say(zo_strformat(WRITCRAFTER_HELP, Typed()))
    end,
}

local function OnSlash(args)
    local command, rest = (args or ""):match("^%s*(%S*)%s*(.-)%s*$")
    command = command:lower()
    if command == "" then
        command = "help"
    end
    local handler = COMMANDS[command]
    if handler then
        handler(rest)
    else
        WC.Log.Say(zo_strformat(WRITCRAFTER_UNKNOWN_COMMAND, command, Typed()))
    end
end

function Slash.Init()
    -- Never take over another add-on's command: /wc is short and could already be in use
    -- (/writcrafter then still works).
    for _, command in ipairs({ "/writcrafter", "/wc" }) do
        if SLASH_COMMANDS[command] == nil then
            handlers[command] = function(args)
                typed = command
                OnSlash(args)
            end
            SLASH_COMMANDS[command] = handlers[command]
        else
            WC.Log.Debug(string.format("%s is already used by another add-on; WritCrafter left it alone", command))
        end
    end
    ESO_Dialogs[RESET_DIALOG] = {
        title = { text = WRITCRAFTER_RESET_TITLE },
        mainText = { text = WRITCRAFTER_RESET_TEXT },
        buttons = {
            { text = WRITCRAFTER_RESET_CONFIRM, callback = ResetEverything },
            { text = SI_DIALOG_CANCEL },
        },
    }
end
