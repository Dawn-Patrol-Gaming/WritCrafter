local WC = WritCrafter

local Slash = {}
WC.Slash = Slash

local function ItemName(link)
    return zo_strformat("<<t:1>>", GetItemLinkName(link))
end

local function ShowStock(rest)
    local itemId, link = WC.Inventory.ParseItemArg(rest)
    if not itemId then
        WC.Log.Say(GetString(SI_WRITCRAFTER_NEED_ITEM))
        return
    end
    WC.Inventory.Invalidate()
    local s = WC.Inventory.GetStock(itemId)
    if s.locked > 0 then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_STOCK_LOCKED, ItemName(link), s.backpack, s.bank, s.craftBag, s.usable, s.locked))
    else
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_STOCK, ItemName(link), s.backpack, s.bank, s.craftBag, s.usable))
    end
end

local function ShowPrice(rest)
    local itemId, link = WC.Inventory.ParseItemArg(rest)
    if not itemId then
        WC.Log.Say(GetString(SI_WRITCRAFTER_NEED_ITEM))
        return
    end
    local gold, source = WC.Price.Get(link)
    if gold then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PRICE, ItemName(link), WC.Price.Format(gold), WC.Price.SourceName(source)))
    else
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PRICE_NONE, ItemName(link)))
    end
end

local SELFTEST_SHOWN = 10

local function SelfTest()
    local checked, skipped, mismatches = WC.Inventory.SelfTest()
    if #mismatches == 0 then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_OK, checked, skipped))
        return
    end
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_FAIL, #mismatches, checked))
    local showAll = WC.settings.logLevel >= WC.Log.LEVEL_DEBUG
    for i, m in ipairs(mismatches) do
        if i > SELFTEST_SHOWN and not showAll then
            WC.Log.Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_MORE, #mismatches - SELFTEST_SHOWN))
            break
        end
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_ROW, ItemName(m.link), m.itemId,
            m.ours[1], m.ours[2], m.ours[3], m.game[1], m.game[2], m.game[3]))
    end
end

local function ToggleDebug()
    if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
        WC.settings.logLevel = WC.Log.LEVEL_NORMAL
        WC.Log.Say(GetString(SI_WRITCRAFTER_DEBUG_OFF))
    else
        WC.settings.logLevel = WC.Log.LEVEL_DEBUG
        WC.Log.Say(GetString(SI_WRITCRAFTER_DEBUG_ON))
    end
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
    help     = function() WC.Log.Say(GetString(SI_WRITCRAFTER_HELP)) end,
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
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_UNKNOWN_COMMAND, command))
    end
end

function Slash.Init()
    SLASH_COMMANDS["/wc"] = OnSlash
    SLASH_COMMANDS["/writcrafter"] = OnSlash
end
