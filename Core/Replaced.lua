local WC = WritCrafter

-- Warns, once each time the UI loads, when an add-on WritCrafter replaces is still running: it
-- answers the same dialogs and crafts at the same stations, so the two get in each other's way.
-- Libraries those add-ons used (LibLazyCrafting, LibMarify, LibRecipe) do nothing on their own
-- and other add-ons may need them, so they're left out. Only warns; disabling is left to you.
local Replaced = {}
WC.Replaced = Replaced

local DIALOG_NAME = "WRITCRAFTER_REPLACED_ADDONS"
local CHECK_DELAY_MS = 3000   -- after the UI is up, so the dialog isn't lost among login screens

-- Folder name (what the add-on manager reports) = the name players know it by.
local REPLACED = {
    DolgubonsLazyWritCreator = "Dolgubon's Lazy Writ Crafter",
    WritWorthy               = "WritWorthy",
    DailyAlchemy             = "DailyAlchemy",
    DailyProvisioning        = "DailyProvisioning",
}

-- The replaced add-ons that loaded this session (not just ticked: one that failed to load,
-- e.g. for a missing library, does nothing), by the name players know, sorted.
function Replaced.Running()
    local running = {}
    local manager = GetAddOnManager()
    for index = 1, manager:GetNumAddOns() do
        local name, _, _, _, _, state = manager:GetAddOnInfo(index)
        if REPLACED[name] and state == ADDON_STATE_ENABLED then
            running[#running + 1] = REPLACED[name]
        end
    end
    table.sort(running)
    return running
end

local function Check()
    if not WC.settings.warnReplaced then
        return
    end
    local running = Replaced.Running()
    if #running == 0 then
        return
    end
    WC.Log.Debug("Replaced add-ons still running: %s", table.concat(running, ", "))
    ZO_Dialogs_ShowDialog(DIALOG_NAME, nil, { mainTextParams = { table.concat(running, ", ") } })
end

local function StopWarning()
    WC.settings.warnReplaced = false
    WC.Log.Say(GetString(WRITCRAFTER_REPLACED_STOPPED))
end

function Replaced.Init()
    ESO_Dialogs[DIALOG_NAME] = {
        title = { text = WRITCRAFTER_REPLACED_TITLE },
        mainText = { text = WRITCRAFTER_REPLACED_TEXT },
        buttons = {
            { text = SI_OK },
            { text = WRITCRAFTER_REPLACED_STOP, callback = StopWarning },
        },
    }
    local namespace = WC.name .. "Replaced"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
        EVENT_MANAGER:UnregisterForEvent(namespace, EVENT_PLAYER_ACTIVATED)
        zo_callLater(Check, CHECK_DELAY_MS)
    end)
end
