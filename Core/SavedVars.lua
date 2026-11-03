local WC = WritCrafter

local SavedVars = {}
WC.SavedVars = SavedVars

local SV_NAME    = "WritCrafterVars"
local SV_VERSION = 2    -- 1 was a pre-release layout; a version change makes ZO_SavedVars start fresh

SavedVars.SCOPE_SERVER    = "server"      -- shared by all of this account's characters on this server
SavedVars.SCOPE_CHARACTER = "character"   -- this character only

-- Settings that exist both server-wide and per character. Flat scalars only.
WC.DEFAULTS = {
    respectLocks = true,
    priceSource  = "auto",
    logLevel     = 2,       -- WC.Log.LEVEL_NORMAL (Log isn't loaded yet when this file runs)
}

-- One account-wide table per megaserver, the same layout CharacterHomes uses:
-- WritCrafterVars[GetWorldName()]["@account"]["$AccountWide"] = {
--   settings   = { ... },                   -- shared by every character on this server
--   characters = { [characterId] = {
--       name            = "Character Name", -- kept current, for display and renames
--       scope           = "server" | "character",
--       characterSeeded = bool,             -- settings were copied from the shared ones
--       settings        = { ... },          -- used when scope is "character"
--   } },
--   linkCache  = { [itemId] = itemLink },   -- real links seen in the inventory, for price lookups
-- }

local function FillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = value
        end
    end
end

function SavedVars.Init()
    WC.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, {}, GetWorldName())
    local sv = WC.sv
    sv.settings   = sv.settings or {}
    sv.characters = sv.characters or {}
    sv.linkCache  = sv.linkCache or {}
    FillDefaults(sv.settings, WC.DEFAULTS)

    local characterId = GetCurrentCharacterId()
    local character = sv.characters[characterId]
    if not character then
        character = { scope = SavedVars.SCOPE_SERVER, characterSeeded = false, settings = {} }
        sv.characters[characterId] = character
    end
    character.name = zo_strformat("<<1>>", GetUnitName("player"))
    character.settings = character.settings or {}
    FillDefaults(character.settings, WC.DEFAULTS)

    WC.character         = character
    WC.serverSettings    = sv.settings
    WC.characterSettings = character.settings
    -- Price addons key their data by link fields (subtype, level), so a bare
    -- "item:<id>:0:0..." link often finds nothing. Real links are remembered here.
    WC.linkCache         = sv.linkCache

    SavedVars.SelectProfile()
end

function SavedVars.SelectProfile()
    if WC.character.scope == SavedVars.SCOPE_CHARACTER then
        WC.settings = WC.characterSettings
    else
        WC.settings = WC.serverSettings
    end
end

function SavedVars.SetScope(scope)
    -- The first switch to "this character only" starts from a copy of the shared settings
    -- instead of defaults, so nothing has to be set up again.
    if scope == SavedVars.SCOPE_CHARACTER and not WC.character.characterSeeded then
        for key in pairs(WC.DEFAULTS) do
            WC.characterSettings[key] = WC.serverSettings[key]
        end
        WC.character.characterSeeded = true
    end
    WC.character.scope = scope
    SavedVars.SelectProfile()
end
