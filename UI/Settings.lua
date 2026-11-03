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
            type = "description",
            text = zo_strformat(SI_WRITCRAFTER_SAVED_FOR, GetWorldName(), GetDisplayName(), WC.character.name),
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
                WC.Price.ClearCache()
                WC.Inventory.Invalidate()
            end,
            default       = WC.SavedVars.SCOPE_SERVER,
        },
        {
            type    = "checkbox",
            name    = GetString(SI_WRITCRAFTER_RESPECT_LOCKS),
            tooltip = GetString(SI_WRITCRAFTER_RESPECT_LOCKS_TOOLTIP),
            getFunc = function() return WC.settings.respectLocks end,
            setFunc = function(value) WC.settings.respectLocks = value end,
            default = WC.DEFAULTS.respectLocks,
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
                WC.Price.ClearCache()
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
        {
            type = "header",
            name = GetString(SI_WRITCRAFTER_HEADER_DIAGNOSTICS),
        },
        {
            type = "description",
            text = GetString(SI_WRITCRAFTER_DIAGNOSTICS_TEXT),
        },
    }
    LAM:RegisterOptionControls(WC.name .. "Panel", options)
end

function Settings.Open()
    LAM:OpenToPanel(Settings.panel)
end
