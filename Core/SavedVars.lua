local WC = WritCrafter

local SavedVars = {}
WC.SavedVars = SavedVars

local SV_NAME    = "WritCrafterVars"
local SV_VERSION = 2    -- 1 was a pre-release layout; a version change makes ZO_SavedVars start fresh

SavedVars.SCOPE_SERVER    = "server"      -- shared by all of this account's characters on this server
SavedVars.SCOPE_CHARACTER = "character"   -- this character only

-- Settings that exist both server-wide and per character.
WC.DEFAULTS = {
    priceSource       = "auto",
    logLevel          = 2,          -- WC.Log.LEVEL_NORMAL (Log isn't loaded yet when this file runs)
    expensive         = {},         -- [itemId] = true/false, the player's own marks
    reagents          = {},         -- [itemId] = true/false, overrides the plants-only default
    excludeGold       = {},         -- [craftingType] = true
    liveCeilings      = false,
    ceilings          = { reagent = 300, rune = 500, trait = 1000, ingredient = 300 },
    mimic             = "needed",   -- WC.Policy.MIMIC_*
    maxGoldPerVoucher = 0,          -- 0 = off
    autoCraft         = true,       -- craft queued master writs at stations
    autoCraftDaily    = true,       -- craft daily writ quests at stations
    bankWithdrawDaily = false,      -- daily writs: use finished items in storage (take out, don't craft)
    dailyAcquireExcluded = true,    -- daily writs: hand over excluded reagents an acquire task asks for
    bankWithdrawMaster = true,      -- master writs: take their crafted items out of storage
    acceptGuard       = true,       -- ask before accepting a sealed master writ you can't craft
    craftNotice       = true,       -- on-screen alerts and the failure banner
    soundStart        = false,      -- sound when writ crafting starts at a station
    soundDone         = false,      -- sound when it's done
    soundProblem      = true,       -- sound when something couldn't be crafted
    soundSlot         = false,      -- slotting sounds (solvent/reagents, runes, item placed)
    soundRunes        = true,       -- enchanting's spoken rune names
    soundSuccess      = true,       -- the station's success sound as each item is made
    leaveStation      = true,       -- leave the station once writ crafting there is done
    rolisTurnIn       = true,       -- step through the turn-in dialog when you talk to Rolis Hlaalu
    rolisClose        = true,       -- end the conversation after the last master writ is handed in
    rolisAcceptNext   = true,       -- then accept the next batch of crafted writs
    -- Daily writ dialogs, per craft: accept at writ boards, turn in at delivery crates.
    dailyAccept       = {
        [CRAFTING_TYPE_BLACKSMITHING] = true, [CRAFTING_TYPE_CLOTHIER] = true, [CRAFTING_TYPE_WOODWORKING] = true,
        [CRAFTING_TYPE_JEWELRYCRAFTING] = true, [CRAFTING_TYPE_ALCHEMY] = true, [CRAFTING_TYPE_ENCHANTING] = true,
        [CRAFTING_TYPE_PROVISIONING] = true,
    },
    dailyTurnIn       = {
        [CRAFTING_TYPE_BLACKSMITHING] = true, [CRAFTING_TYPE_CLOTHIER] = true, [CRAFTING_TYPE_WOODWORKING] = true,
        [CRAFTING_TYPE_JEWELRYCRAFTING] = true, [CRAFTING_TYPE_ALCHEMY] = true, [CRAFTING_TYPE_ENCHANTING] = true,
        [CRAFTING_TYPE_PROVISIONING] = true,
    },
    writStatus        = true,       -- the daily writ status strip
    writStatusX       = false,      -- its position, once you've moved it (false = default)
    writStatusY       = false,
    rewardOpenBoxes   = true,       -- open writ reward boxes as they arrive
    rewardSummary     = true,       -- list what each box gave in chat
    rewardActions     = {},         -- [reward kind] = WC.Rewards.* action; missing = the kind's default (Rewards.KINDS)
    stationMarkers    = "queued",   -- WC.Markers.OFF / ALL / QUEUED: markers over stations for master writs
    tooltip           = true,
    tooltipMaterials  = true,
    iconCrafted       = true,
    iconRejected      = true,
    iconQueued        = true,
    iconMissing       = true,
    iconReserved      = true,
    iconOffsetX       = -25,
    iconOffsetY       = 0,
}

-- One account-wide table per megaserver, the same layout CharacterHomes uses:
-- WritCrafterVars[GetWorldName()]["@account"]["$AccountWide"] = {
--   settings   = { ... },                   -- shared by every character on this server
--   characters = { [characterId] = {
--       name            = "Character Name", -- kept current, for display and renames
--       scope           = "server" | "character",
--       characterSeeded = bool,             -- settings were copied from the shared ones
--       settings        = { ... },          -- only once the character has used "character"
--   } },
--   linkCache  = { [itemId] = itemLink },   -- real links seen in the inventory, for price lookups
-- }

-- Tables are copied, never shared, so one character's changes can't leak into the defaults.
local function FillDefaults(target, defaults)
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
        elseif type(value) == "table" and type(target[key]) == "table" then
            FillDefaults(target[key], value)
        end
    end
end

-- Drops settings that no longer exist so they don't linger in the file: removed options,
-- keys removed from fixed-key tables (e.g. the style price ceiling), and too-expensive marks
-- on reagents, which now use their own allow list.
local function PruneKeys(target, defaults)
    for key, value in pairs(target) do
        local default = defaults[key]
        if default == nil then
            target[key] = nil
        elseif type(default) == "table" and next(default) ~= nil and type(value) == "table" then
            PruneKeys(value, default)   -- only fixed-key tables; item-ID tables default to {}
        end
    end
end

local function PruneRemoved(target)
    -- 2026-11-09: "Take writ items out of storage" was split by writ type. Someone who had it
    -- off keeps master writs off too (dailies start off anyway).
    if target.bankWithdraw == false and target.bankWithdrawMaster == nil then
        target.bankWithdrawMaster = false
    end
    PruneKeys(target, WC.DEFAULTS)
    if type(target.expensive) == "table" then
        for itemId in pairs(WC.Data.Alchemy.REAGENTS) do
            target.expensive[itemId] = nil
        end
    end
end

function SavedVars.Init()
    WC.sv = ZO_SavedVars:NewAccountWide(SV_NAME, SV_VERSION, nil, {}, GetWorldName())
    local sv = WC.sv
    sv.settings   = sv.settings or {}
    sv.characters = sv.characters or {}
    sv.linkCache  = sv.linkCache or {}
    PruneRemoved(sv.settings)
    FillDefaults(sv.settings, WC.DEFAULTS)

    local characterId = GetCurrentCharacterId()
    local character = sv.characters[characterId]
    if not character then
        character = { scope = SavedVars.SCOPE_SERVER, characterSeeded = false }
        sv.characters[characterId] = character
    end
    character.name = zo_strformat("<<1>>", GetUnitName("player"))
    -- Characters that have only ever used Account Wide keep no settings of their own in the
    -- file; they get a working table that's saved only once they switch (SetScope).
    if character.characterSeeded then
        character.settings = character.settings or {}
        PruneRemoved(character.settings)
        FillDefaults(character.settings, WC.DEFAULTS)
        WC.characterSettings = character.settings
    else
        character.settings = nil
        WC.characterSettings = {}
        FillDefaults(WC.characterSettings, WC.DEFAULTS)
    end

    WC.character         = character
    WC.serverSettings    = sv.settings
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
            local value = WC.serverSettings[key]
            WC.characterSettings[key] = type(value) == "table" and ZO_DeepTableCopy(value) or value
        end
        WC.character.settings = WC.characterSettings
        WC.character.characterSeeded = true
    end
    WC.character.scope = scope
    SavedVars.SelectProfile()
end
