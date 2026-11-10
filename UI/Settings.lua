local WC = WritCrafter

local Settings = {}
WC.Settings = Settings

local LAM = LibAddonMenu2

local function SourceChoices()
    local names, values = {}, {}
    local stringIds = {
        auto   = SI_WRITCRAFTER_SOURCE_AUTO,
        esohub = SI_WRITCRAFTER_SOURCE_ESOHUB,
        mm     = SI_WRITCRAFTER_SOURCE_MM,
        ttc    = SI_WRITCRAFTER_SOURCE_TTC,
        att    = SI_WRITCRAFTER_SOURCE_ATT,
    }
    for _, key in ipairs(WC.Price.SOURCES) do
        names[#names + 1] = GetString(stringIds[key])
        values[#values + 1] = key
    end
    return names, values
end

local CEILINGS = {
    { key = "reagent",    name = SI_WRITCRAFTER_CEILING_REAGENT,    max = 3000 },
    { key = "rune",       name = SI_WRITCRAFTER_CEILING_RUNE,       max = 5000 },
    { key = "trait",      name = SI_WRITCRAFTER_CEILING_TRAIT,      max = 10000 },
    { key = "ingredient", name = SI_WRITCRAFTER_CEILING_INGREDIENT, max = 3000 },
}

local function CeilingControls()
    local controls = {
        {
            type    = "checkbox",
            name    = GetString(SI_WRITCRAFTER_LIVE_CEILINGS),
            tooltip = GetString(SI_WRITCRAFTER_LIVE_CEILINGS_TOOLTIP),
            getFunc = function() return WC.settings.liveCeilings end,
            setFunc = function(value)
                WC.settings.liveCeilings = value
                WC.Policy.Changed()
            end,
            default = WC.DEFAULTS.liveCeilings,
        },
    }
    for _, ceiling in ipairs(CEILINGS) do
        controls[#controls + 1] = {
            type     = "slider",
            name     = GetString(ceiling.name),
            min      = 0,
            max      = ceiling.max,
            step     = 25,
            getFunc  = function() return WC.settings.ceilings[ceiling.key] end,
            setFunc  = function(value)
                WC.settings.ceilings[ceiling.key] = value
                WC.Policy.Changed()
            end,
            default  = WC.DEFAULTS.ceilings[ceiling.key],
            disabled = function() return not WC.settings.liveCeilings end,
        }
    end
    return controls
end

local GOLD_CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_ENCHANTING, CRAFTING_TYPE_ALCHEMY,
    CRAFTING_TYPE_PROVISIONING,
}

local function GoldControls()
    local controls = {}
    for _, craft in ipairs(GOLD_CRAFTS) do
        controls[#controls + 1] = {
            type    = "checkbox",
            name    = zo_strformat("<<1>>", GetCraftingSkillName(craft)),
            getFunc = function() return WC.settings.excludeGold[craft] == true end,
            setFunc = function(value)
                WC.settings.excludeGold[craft] = value or nil
                WC.Policy.Changed()
            end,
            default = false,
        }
    end
    return controls
end

local function Checkbox(key, nameId, tooltipId)
    return {
        type    = "checkbox",
        name    = GetString(nameId),
        tooltip = GetString(tooltipId),
        getFunc = function() return WC.settings[key] end,
        setFunc = function(value)
            WC.settings[key] = value
            WC.Policy.Changed()
        end,
        default = WC.DEFAULTS[key],
    }
end

local function OffsetSlider(key, nameId)
    return {
        type    = "slider",
        name    = GetString(nameId),
        tooltip = GetString(SI_WRITCRAFTER_ICON_OFFSET_TOOLTIP),
        min     = -40,
        max     = 40,
        step    = 1,
        getFunc = function() return WC.settings[key] end,
        setFunc = function(value)
            WC.settings[key] = value
            WC.InventoryIcons.Refresh()
        end,
        default = WC.DEFAULTS[key],
    }
end

-- At the station, for every writ (sounds last).
local function CraftingControls()
    return {
        { type = "header", name = GetString(SI_WRITCRAFTER_HEADER_CRAFTING) },
        Checkbox("craftNotice", SI_WRITCRAFTER_CRAFT_NOTICE, SI_WRITCRAFTER_CRAFT_NOTICE_TOOLTIP),
        Checkbox("leaveStation", SI_WRITCRAFTER_LEAVE_STATION, SI_WRITCRAFTER_LEAVE_STATION_TOOLTIP),
        {
            type     = "submenu",
            name     = GetString(SI_WRITCRAFTER_SOUNDS_SUBMENU),
            controls = {
                Checkbox("soundStart", SI_WRITCRAFTER_SOUND_START, SI_WRITCRAFTER_SOUND_START_TOOLTIP),
                Checkbox("soundDone", SI_WRITCRAFTER_SOUND_DONE, SI_WRITCRAFTER_SOUND_DONE_TOOLTIP),
                Checkbox("soundProblem", SI_WRITCRAFTER_SOUND_PROBLEM, SI_WRITCRAFTER_SOUND_PROBLEM_TOOLTIP),
                Checkbox("soundSlot", SI_WRITCRAFTER_SOUND_SLOT, SI_WRITCRAFTER_SOUND_SLOT_TOOLTIP),
                Checkbox("soundRunes", SI_WRITCRAFTER_SOUND_RUNES, SI_WRITCRAFTER_SOUND_RUNES_TOOLTIP),
                Checkbox("soundSuccess", SI_WRITCRAFTER_SOUND_SUCCESS, SI_WRITCRAFTER_SOUND_SUCCESS_TOOLTIP),
            },
        },
    }
end

local function DailyWritControls()
    return {
        { type = "header", name = GetString(SI_WRITCRAFTER_HEADER_DAILY) },
        Checkbox("autoCraftDaily", SI_WRITCRAFTER_AUTOCRAFT_DAILY, SI_WRITCRAFTER_AUTOCRAFT_DAILY_TOOLTIP),
        Checkbox("bankWithdrawDaily", SI_WRITCRAFTER_BANK_WITHDRAW_DAILY, SI_WRITCRAFTER_BANK_WITHDRAW_DAILY_TOOLTIP),
    }
end

-- Everything about master writs: crafting and storage, turning in at Rolis, tooltips, and the
-- rules that decide which writs are worth doing.
local function MasterWritControls()
    return {
        { type = "header", name = GetString(SI_WRITCRAFTER_HEADER_MASTER) },
        Checkbox("autoCraft", SI_WRITCRAFTER_AUTOCRAFT, SI_WRITCRAFTER_AUTOCRAFT_TOOLTIP),
        Checkbox("bankWithdrawMaster", SI_WRITCRAFTER_BANK_WITHDRAW_MASTER, SI_WRITCRAFTER_BANK_WITHDRAW_MASTER_TOOLTIP),
        Checkbox("rolisTurnIn", SI_WRITCRAFTER_ROLIS_TURN_IN, SI_WRITCRAFTER_ROLIS_TURN_IN_TOOLTIP),
        Checkbox("rolisClose", SI_WRITCRAFTER_ROLIS_CLOSE, SI_WRITCRAFTER_ROLIS_CLOSE_TOOLTIP),
        Checkbox("rolisAcceptNext", SI_WRITCRAFTER_ROLIS_ACCEPT_NEXT, SI_WRITCRAFTER_ROLIS_ACCEPT_NEXT_TOOLTIP),
        Checkbox("tooltip", SI_WRITCRAFTER_TOOLTIP_SHOW, SI_WRITCRAFTER_TOOLTIP_SHOW_TOOLTIP),
        Checkbox("tooltipMaterials", SI_WRITCRAFTER_TOOLTIP_MATS, SI_WRITCRAFTER_TOOLTIP_MATS_TOOLTIP),
        {
            type          = "dropdown",
            name          = GetString(SI_WRITCRAFTER_MIMIC),
            tooltip       = GetString(SI_WRITCRAFTER_MIMIC_TOOLTIP),
            choices       = {
                GetString(SI_WRITCRAFTER_MIMIC_NEVER),
                GetString(SI_WRITCRAFTER_MIMIC_NEEDED),
                GetString(SI_WRITCRAFTER_MIMIC_ALWAYS),
            },
            choicesValues = { WC.Policy.MIMIC_NEVER, WC.Policy.MIMIC_NEEDED, WC.Policy.MIMIC_ALWAYS },
            getFunc       = function() return WC.settings.mimic end,
            setFunc       = function(value)
                WC.settings.mimic = value
                WC.Policy.Changed()
            end,
            default       = WC.DEFAULTS.mimic,
        },
        {
            type    = "slider",
            name    = GetString(SI_WRITCRAFTER_MAX_GPV),
            tooltip = GetString(SI_WRITCRAFTER_MAX_GPV_TOOLTIP),
            min     = 0,
            max     = 5000,
            step    = 50,
            getFunc = function() return WC.settings.maxGoldPerVoucher end,
            setFunc = function(value)
                WC.settings.maxGoldPerVoucher = value
                WC.Policy.Changed()
            end,
            default = WC.DEFAULTS.maxGoldPerVoucher,
        },
        {
            type     = "submenu",
            name     = GetString(SI_WRITCRAFTER_GOLD_SUBMENU),
            tooltip  = GetString(SI_WRITCRAFTER_GOLD_SUBMENU_TOOLTIP),
            controls = GoldControls(),
        },
    }
end

-- Material exclusions: what On/Off means, one button that opens the exclusions window (it has
-- its own category menu and rebuilds its lists each time it opens), then the live price
-- ceilings that feed the defaults.
local function ExclusionSection()
    return {
        { type = "header", name = GetString(SI_WRITCRAFTER_EXPENSIVE_SUBMENU) },
        { type = "description", text = GetString(SI_WRITCRAFTER_EXPENSIVE_TEXT) },
        {
            type = "button",
            name = GetString(SI_WRITCRAFTER_EXCL_OPEN),
            func = function() WC.ExclusionsWindow.Open() end,
        },
        { type = "submenu", name = GetString(SI_WRITCRAFTER_CEILINGS_SUBMENU), controls = CeilingControls() },
    }
end

local function IconControls()
    return {
        { type = "header", name = GetString(SI_WRITCRAFTER_HEADER_ICONS) },
        Checkbox("iconCrafted", SI_WRITCRAFTER_ICON_CRAFTED, SI_WRITCRAFTER_ICON_CRAFTED_TOOLTIP),
        Checkbox("iconRejected", SI_WRITCRAFTER_ICON_REJECTED, SI_WRITCRAFTER_ICON_REJECTED_TOOLTIP),
        Checkbox("iconMissing", SI_WRITCRAFTER_ICON_MISSING, SI_WRITCRAFTER_ICON_MISSING_TOOLTIP),
        Checkbox("iconQueued", SI_WRITCRAFTER_ICON_QUEUED, SI_WRITCRAFTER_ICON_QUEUED_TOOLTIP),
        Checkbox("iconReserved", SI_WRITCRAFTER_ICON_RESERVED, SI_WRITCRAFTER_ICON_RESERVED_TOOLTIP),
        OffsetSlider("iconOffsetX", SI_WRITCRAFTER_ICON_OFFSET_X),
        OffsetSlider("iconOffsetY", SI_WRITCRAFTER_ICON_OFFSET_Y),
    }
end

function Settings.Init()
    local panelData = {
        type                = "panel",
        name                = WC.displayName,
        displayName         = WC.displayName,
        author              = WC.author,
        version             = WC.version,
        registerForRefresh  = true,
        registerForDefaults = true,
    }
    Settings.panel = LAM:RegisterAddonPanel(WC.name .. "Panel", panelData)

    local sourceNames, sourceValues = SourceChoices()

    local options = {
        {
            type = "header",
            name = GetString(SI_WRITCRAFTER_HEADER_GENERAL),
        },
        {
            type          = "dropdown",
            name          = GetString(SI_WRITCRAFTER_SCOPE),
            tooltip       = GetString(SI_WRITCRAFTER_SCOPE_TOOLTIP),
            choices       = {
                GetString(SI_WRITCRAFTER_SCOPE_SERVER),
                GetString(SI_WRITCRAFTER_SCOPE_CHARACTER),
            },
            choicesValues = { WC.SavedVars.SCOPE_SERVER, WC.SavedVars.SCOPE_CHARACTER },
            getFunc       = function() return WC.character.scope end,
            setFunc       = function(value)
                WC.SavedVars.SetScope(value)
                WC.Inventory.Invalidate()
                WC.Policy.Changed()
            end,
            default       = WC.SavedVars.SCOPE_SERVER,
        },
        {
            type          = "dropdown",
            name          = GetString(SI_WRITCRAFTER_PRICE_SOURCE),
            tooltip       = GetString(SI_WRITCRAFTER_PRICE_SOURCE_TOOLTIP),
            choices       = sourceNames,
            choicesValues = sourceValues,
            getFunc       = function() return WC.settings.priceSource end,
            setFunc       = function(value)
                WC.settings.priceSource = value
                WC.Policy.Changed()
            end,
            default       = WC.DEFAULTS.priceSource,
        },
        {
            type          = "dropdown",
            name          = GetString(SI_WRITCRAFTER_LOG_LEVEL),
            tooltip       = GetString(SI_WRITCRAFTER_LOG_LEVEL_TOOLTIP),
            choices       = {
                GetString(SI_WRITCRAFTER_LOG_ERRORS),
                GetString(SI_WRITCRAFTER_LOG_NORMAL),
                GetString(SI_WRITCRAFTER_LOG_DEBUG),
            },
            choicesValues = { WC.Log.LEVEL_ERROR, WC.Log.LEVEL_NORMAL, WC.Log.LEVEL_DEBUG },
            getFunc       = function() return WC.settings.logLevel end,
            setFunc       = function(value) WC.settings.logLevel = value end,
            default       = WC.DEFAULTS.logLevel,
        },
    }
    for _, section in ipairs({ CraftingControls(), DailyWritControls(), MasterWritControls(),
                                ExclusionSection(), IconControls() }) do
        for _, control in ipairs(section) do
            options[#options + 1] = control
        end
    end
    options[#options + 1] = { type = "header", name = GetString(SI_WRITCRAFTER_HEADER_DIAGNOSTICS) }
    options[#options + 1] = { type = "description", text = GetString(SI_WRITCRAFTER_DIAGNOSTICS_TEXT) }
    LAM:RegisterOptionControls(WC.name .. "Panel", options)
end

function Settings.Open()
    LAM:OpenToPanel(Settings.panel)
end
