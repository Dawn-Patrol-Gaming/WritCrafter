local WC = WritCrafter

-- Daily writ dialogs (PLAN milestone 4, finished in milestone 6):
--   Writ boards: every daily writ the board offers for a craft you've ticked is picked and
--   accepted, one after another; the board is closed once none are left.
--   Delivery crates: "Place the goods" / "Sign the Manifest" is picked and the writ completed,
--   for crafts you've ticked. A writ that would hand over a reagent you've excluded (an alchemy
--   "acquire" task) is never turned in for you.
-- Language: the game names writs only in text, so WritCrafter learns each daily writ's quest name
-- (in the game's own language) the first time one of its stations claims that quest, and matches
-- board options and turn-ins against those. A crate's turn-in option is recognised by the quest it
-- belongs to when the game says so. The English wording in Strings/en.lua is only the fallback
-- until a writ has been seen once.
local Dialogs = {}
WC.Dialogs = Dialogs

local CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_ALCHEMY, CRAFTING_TYPE_ENCHANTING,
    CRAFTING_TYPE_PROVISIONING,
}
Dialogs.CRAFTS = CRAFTS

local WRIT_NAMES = {
    [CRAFTING_TYPE_BLACKSMITHING]   = SI_WRITCRAFTER_WRIT_BLACKSMITHING,
    [CRAFTING_TYPE_CLOTHIER]        = SI_WRITCRAFTER_WRIT_CLOTHIER,
    [CRAFTING_TYPE_WOODWORKING]     = SI_WRITCRAFTER_WRIT_WOODWORKING,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = SI_WRITCRAFTER_WRIT_JEWELRY,
    [CRAFTING_TYPE_ALCHEMY]         = SI_WRITCRAFTER_WRIT_ALCHEMY,
    [CRAFTING_TYPE_ENCHANTING]      = SI_WRITCRAFTER_WRIT_ENCHANTING,
    [CRAFTING_TYPE_PROVISIONING]    = SI_WRITCRAFTER_WRIT_PROVISIONING,
}

local OFFER_TIMEOUT_MS = 3000

local function Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

-- Daily writ quest names learned from the journal, account-wide: [lower-case name] = craft.
local function Learned()
    WC.sv.writQuests = WC.sv.writQuests or {}
    return WC.sv.writQuests
end

-- A station claimed this daily quest for its craft: remember the quest's name.
function Dialogs.LearnWritQuest(questName, craft)
    if questName and questName ~= "" and craft then
        Learned()[zo_strformat("<<1>>", questName):lower()] = craft
    end
end

-- The craft a daily quest name was learned for (exact name only), or nil.
function Dialogs.LearnedCraft(questName)
    if not questName or questName == "" then
        return nil
    end
    return Learned()[zo_strformat("<<1>>", questName):lower()]
end

-- The craft of a daily writ, from its quest name or a board option ("Blacksmith Writ"), or nil.
-- Learned names first (any language); then, as a fallback, the word "Writ" and a craft word, each
-- anywhere in the text (as Dolgubon's matches them).
function Dialogs.WritCraft(text)
    local lower = zo_strformat("<<1>>", text or ""):lower()
    if lower == "" then
        return nil
    end
    for name, craft in pairs(Learned()) do
        if lower:find(name, 1, true) then
            return craft
        end
    end
    if not lower:find(GetString(SI_WRITCRAFTER_WRIT_WORD):lower(), 1, true) then
        return nil
    end
    for _, craft in ipairs(CRAFTS) do
        local name = GetString(WRIT_NAMES[craft]):lower()
        if name ~= "" and lower:find(name, 1, true) then
            return craft
        end
    end
end

local function Enabled(settingKey, craft)
    local flags = WC.settings[settingKey]
    return flags ~= nil and flags[craft] == true
end

-- Reagents daily alchemy writs ask you to acquire, remembered per quest: that task leaves the
-- journal once the quest moves on to delivery, but the reagent is still handed over then.
local function AcquireItems()
    WC.character.dailyAcquire = WC.character.dailyAcquire or {}
    return WC.character.dailyAcquire
end

local function RememberAcquireItems()
    local items = AcquireItems()
    local present = {}
    for _, entry in ipairs(WC.Daily.Quests()) do
        present[entry.quest] = true
    end
    for _, condition in ipairs(WC.Daily.Conditions()) do
        local itemId = WC.Daily.AcquireItem(condition)
        if itemId then
            items[condition.quest] = itemId
        end
    end
    for quest in pairs(items) do
        if not present[quest] then
            items[quest] = nil
        end
    end
end

-- Writ boards ----------------------------------------------------------------------------------

-- pending: waiting for the offer of the writ just picked; token: which pick that was, so an old
-- pick's timeout can't cancel a newer one.
local accepting = { pending = false, token = 0, accepted = 0, lastAt = 0, pulled = false }

local Page = {}   -- Page.Schedule: defined with the dialog page handling below

-- After accepting, the board doesn't always announce its next page (seen 2026-11-11: it went back
-- to its front page with no event), so look at whatever page is up a moment later either way.
local AFTER_ACCEPT_MS = 500
local function OnQuestOffered()
    if accepting.pending then
        accepting.pending = false
        AcceptOfferedQuest()
        Page.Schedule("after accept", AFTER_ACCEPT_MS)
    end
end

-- Picks the first offered daily writ for a ticked craft. Returns true when it picked one.
local function AcceptFromBoard(optionCount)
    for optionIndex = 1, optionCount do
        local text, optionType = GetChatterOption(optionIndex)
        if optionType == CHATTER_START_NEW_QUEST_BESTOWAL then
            local craft = Dialogs.WritCraft(text)
            if craft and Enabled("dailyAccept", craft) then
                accepting.pending = true
                accepting.token = accepting.token + 1
                accepting.lastAt = GetFrameTimeMilliseconds()
                local token = accepting.token
                zo_callLater(function()
                    if accepting.token == token then
                        accepting.pending = false
                    end
                end, OFFER_TIMEOUT_MS)
                SelectChatterOption(optionIndex)
                return true
            end
        end
    end
    return false
end

-- Delivery crates ------------------------------------------------------------------------------

local DELIVER_OPTIONS = {
    [CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS] = true,
    [CHATTER_START_COMPLETE_QUEST] = true,
}

-- The daily writ an option's extra number points to, when it's a journal quest index: the game may
-- pass the quest a turn-in option belongs to. Returns its craft, or nil.
local function OptionWrit(optionalArgument)
    if type(optionalArgument) ~= "number" or not IsValidQuestIndex(optionalArgument) then
        return nil
    end
    if GetJournalQuestType(optionalArgument) ~= QUEST_TYPE_CRAFTING then
        return nil
    end
    return Dialogs.WritCraft(GetJournalQuestName(optionalArgument))
end

-- Whether you're talking to an object (a crate) rather than a person.
local function TalkingToObject()
    local unitType = GetUnitType("interact")
    return unitType ~= nil and (unitType == UNIT_TYPE_INTERACTOBJ or unitType == UNIT_TYPE_INTERACTFIXTURE)
end

-- Whether a daily writ (not a master writ) is in the journal.
local function HaveDailyWrit()
    for _, entry in ipairs(WC.Daily.Quests()) do
        if Dialogs.WritCraft(entry.quest) and not (WC.character.acceptedWrits or {})[entry.quest] then
            return true
        end
    end
    return false
end

-- Picks a delivery crate's turn-in option. A crate is an object, not a person: an object offering
-- a quest turn-in while you have a daily writ is taken as a delivery crate (any language). The game
-- attaches no quest to the option (its number is 0, seen 2026-11-10), so the wording "Place the
-- goods" / "Sign the Manifest" stays as a fallback. Only daily writs are completed either way
-- (OnQuestCompleteDialog).
local function DeliverAtCrate(optionCount)
    local place = GetString(SI_WRITCRAFTER_DELIVER_PLACE):lower()
    local sign = GetString(SI_WRITCRAFTER_DELIVER_SIGN):lower()
    local crate = TalkingToObject() and HaveDailyWrit()
    for optionIndex = 1, optionCount do
        local text, optionType, optionalArgument = GetChatterOption(optionIndex)
        if DELIVER_OPTIONS[optionType] then
            local lower = zo_strformat("<<1>>", text or ""):lower()
            if crate or OptionWrit(optionalArgument) or lower:find(place, 1, true) or lower:find(sign, 1, true) then
                SelectChatterOption(optionIndex)
                return true
            end
        end
    end
    return false
end

-- Debug chat: every quest-related option a dialog offers, with the extra number the game passes.
local DEBUG_OPTION_TYPES = {
    [CHATTER_START_NEW_QUEST_BESTOWAL] = "new quest",
    [CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS] = "advance",
    [CHATTER_START_COMPLETE_QUEST] = "complete",
}
local function DebugOptions(optionCount, source)
    if WC.settings.logLevel < WC.Log.LEVEL_DEBUG then
        return
    end
    WC.Log.Debug(string.format("Talking to %s (%s): unit type %s, an object: %s", tostring(GetUnitName("interact")),
        source, tostring(GetUnitType("interact")), tostring(TalkingToObject())))
    for optionIndex = 1, optionCount do
        local text, optionType, optionalArgument = GetChatterOption(optionIndex)
        if DEBUG_OPTION_TYPES[optionType] then
            local questName = (type(optionalArgument) == "number" and IsValidQuestIndex(optionalArgument))
                and GetJournalQuestName(optionalArgument) or "-"
            WC.Log.Debug(string.format("Dialog option %d: %s, number %s (journal quest: %s): %s", optionIndex,
                DEBUG_OPTION_TYPES[optionType], tostring(optionalArgument), questName, tostring(text)))
        end
    end
end

-- The game's "complete quest" dialog at a crate: only daily writs of ticked crafts, and never one
-- that would hand over an excluded reagent.
local function OnQuestCompleteDialog(_, journalIndex)
    local quest = GetJournalQuestName(journalIndex)
    if GetJournalQuestType(journalIndex) ~= QUEST_TYPE_CRAFTING then
        return
    end
    local craft = Dialogs.WritCraft(quest)
    if not craft or not Enabled("dailyTurnIn", craft) then
        return
    end
    local itemId = AcquireItems()[quest]
    if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
        local name = itemId and zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId))) or "none"
        WC.Log.Debug(string.format("Turn-in of %s (craft %s): acquire item %s, excluded: %s, reagent: %s", quest,
            tostring(craft), name, tostring(itemId and WC.Policy.IsExcluded(itemId)),
            tostring(itemId and WC.Data.Alchemy.REAGENTS[itemId] ~= nil)))
    end
    if itemId and WC.Policy.IsExcluded(itemId) then
        Say(SI_WRITCRAFTER_DELIVER_EXCLUDED, quest,
            zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId))))
        return
    end
    -- The reward box needs a free slot: with none, the game doesn't finish the writ (it stays at
    -- "Sign the Manifest"), so say so instead of leaving the crate waiting silently.
    if GetNumBagFreeSlots(BAG_BACKPACK) == 0 then
        Say(SI_WRITCRAFTER_DELIVER_FULL, quest)
        return
    end
    CompleteQuest()
end

-- Answers the dialog page that's up now.
local function HandlePage(source)
    local optionCount = GetChatterOptionCount() or 0
    if optionCount == 0 or accepting.pending or GetUnitName("interact") == "" then
        return
    end
    DebugOptions(optionCount, source)
    if AcceptFromBoard(optionCount) then
        accepting.accepted = accepting.accepted + 1
        accepting.pulled = false
        return
    end
    if accepting.accepted > 0 and GetFrameTimeMilliseconds() - accepting.lastAt < OFFER_TIMEOUT_MS * 2 then
        -- Mid-way through a board, it sometimes falls back to its front page ("Pull a Writ from the
        -- Board" / "Goodbye") instead of the remaining writs: pick the first option that isn't
        -- Goodbye (by its type, not its wording), once after each accept.
        if not accepting.pulled then
            for optionIndex = 1, optionCount do
                local _, optionType = GetChatterOption(optionIndex)
                if optionType ~= CHATTER_GOODBYE then
                    accepting.pulled = true
                    accepting.lastAt = GetFrameTimeMilliseconds()
                    SelectChatterOption(optionIndex)
                    Page.Schedule("after pull", AFTER_ACCEPT_MS)
                    return
                end
            end
        end
        -- Still nothing to accept: the board is done; close it.
        accepting.accepted = 0
        accepting.pulled = false
        EndInteraction(INTERACTION_CONVERSATION)
        return
    end
    accepting.accepted = 0
    DeliverAtCrate(optionCount)
end

-- A dialog page with options. The first page comes with EVENT_CHATTER_BEGIN; later pages of the
-- same conversation (a writ board going back to its front page after an accept, seen 2026-11-11)
-- may come with EVENT_CONVERSATION_UPDATED instead, so both lead here. Each page is answered after
-- a short pause, so the game's own dialog window has settled first; events that arrive during
-- the pause (both events for one page) become a single answer to whatever page is up by then.
local PAGE_PAUSE_MS = 200
local PAGE_UPDATE = WC.name .. "DialogPage"
-- The option count is read when the page is answered, not taken from the event.
function Page.Schedule(source, delayMs)
    EVENT_MANAGER:UnregisterForUpdate(PAGE_UPDATE)
    EVENT_MANAGER:RegisterForUpdate(PAGE_UPDATE, delayMs or PAGE_PAUSE_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(PAGE_UPDATE)
        HandlePage(source)
    end)
end

local function OnChatterBegin()
    Page.Schedule("begin")
end

local function OnConversationUpdated()
    Page.Schedule("page")
end

function Dialogs.Init()
    local namespace = WC.name .. "Dialogs"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CHATTER_BEGIN, OnChatterBegin)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CONVERSATION_UPDATED, OnConversationUpdated)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_OFFERED, OnQuestOffered)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    WC.Daily.OnJournalChanged(RememberAcquireItems)
end
