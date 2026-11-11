local WC = WritCrafter

-- Accept & Turn In (PLAN §2.6.1), like WritWorthy's: the writs you've crafted are accepted with a
-- button (or keybind), you talk to Rolis Hlaalu yourself (the game never lets an addon start a
-- conversation), and the turn-in dialog is then stepped through for you.
--   Accept: uses each crafted sealed writ in the backpack whose items are in the backpack too,
--           and accepts the quest it offers. The game allows only one quest of each kind, and
--           refuses a writ whose quest you already have: no offer comes, so that writ and its
--           craft are skipped for this round.
--   Turn in: at Rolis, picks the turn-in options by their type (not their text), and completes
--           a quest only when it's one of your accepted master writs. Optionally ends the
--           conversation after the last one, and accepts the next batch.
local Rolis = {}
WC.Rolis = Rolis

local OFFER_TIMEOUT_MS = 3000   -- no offer by then: the game refused the writ
local NEXT_WRIT_MS     = 300    -- pause between writs, so the journal settles

local function Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

-- Accepting ------------------------------------------------------------------------------------

local run   -- { accepted, skipped = {uid}, skippedCraft = {craft}, waiting = {uid, craft}, manual }

-- Crafted writs in the backpack ready to accept: { bagId, slotIndex, uid, craft }, and how many
-- crafted writs still have their items in the bank (turning in needs them in the backpack).
local function Candidates()
    local list, banked = {}, 0
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        if GetItemType(BAG_BACKPACK, slotIndex) == ITEMTYPE_MASTER_WRIT
            and not WC.Inventory.IsProtected(BAG_BACKPACK, slotIndex) then
            local writ = WC.Master.Parse(GetItemLink(BAG_BACKPACK, slotIndex))
            local uid = WC.Master.UniqueId(BAG_BACKPACK, slotIndex)
            local status = writ and WC.Reservations.GetWritStatus(uid)
            if status and status.crafted then
                if status.inBackpack >= status.required then
                    list[#list + 1] = { bagId = BAG_BACKPACK, slotIndex = slotIndex, uid = uid, craft = writ.craft }
                else
                    banked = banked + 1
                end
            end
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end
    return list, banked
end

local function FinishAccepting()
    local _, banked = Candidates()
    if run.accepted > 0 then
        Say(SI_WRITCRAFTER_ROLIS_ACCEPTED, run.accepted)
    elseif run.manual then
        Say(SI_WRITCRAFTER_ROLIS_NONE)
    end
    if banked > 0 and (run.manual or run.accepted > 0) then
        Say(SI_WRITCRAFTER_ROLIS_BANKED, banked)
    end
    run = nil
end

local function AcceptNext()
    if not run then
        return
    end
    if IsUnitInCombat("player") then
        Say(SI_WRITCRAFTER_ROLIS_COMBAT)
        run = nil
        return
    end
    if GetNumJournalQuests() >= MAX_JOURNAL_QUESTS then
        Say(SI_WRITCRAFTER_ROLIS_JOURNAL_FULL)
        FinishAccepting()
        return
    end
    -- Crafts that already have an accepted master writ quest: the game would refuse another, so
    -- none of their writs is tried (no waiting on refusals through a bag full of writs).
    local active = {}
    for _, entry in ipairs(WC.Master.Accepted()) do
        active[entry.writ.craft] = true
    end
    for _, candidate in ipairs((Candidates())) do
        if not run.skipped[candidate.uid] and not run.skippedCraft[candidate.craft] and not active[candidate.craft] then
            run.waiting = { uid = candidate.uid, craft = candidate.craft }
            if IsProtectedFunction("UseItem") then
                CallSecureProtected("UseItem", candidate.bagId, candidate.slotIndex)
            else
                UseItem(candidate.bagId, candidate.slotIndex)
            end
            local uid = candidate.uid
            zo_callLater(function() Rolis.OfferTimeout(uid) end, OFFER_TIMEOUT_MS)
            return
        end
    end
    FinishAccepting()
end

-- No offer came for the writ just used: the game refused it (most likely you already have its
-- quest). Skip it, and its craft, for this round.
function Rolis.OfferTimeout(uid)
    if run and run.waiting and run.waiting.uid == uid then
        run.skipped[uid] = true
        run.skippedCraft[run.waiting.craft] = true
        run.waiting = nil
        AcceptNext()
    end
end

-- Accepts the crafted writs in your backpack. manual: from the button or keybind (says so when
-- there's nothing to do); otherwise the next batch after a turn-in.
function Rolis.AcceptCrafted(manual)
    if run then
        return
    end
    run = { accepted = 0, skipped = {}, skippedCraft = {}, manual = manual ~= false }
    AcceptNext()
end

-- The writ's "Sealed ... Writ" offer: accept it after a moment (as WritWorthy did; the dialog
-- needs to be up), then clear the dialog so it doesn't block the next writ.
local OFFER_ACCEPT_MS = 300
local function OnQuestOffered()
    if run and run.waiting then
        zo_callLater(function()
            if run and run.waiting then
                AcceptOfferedQuest()
                ResetChatter()
            end
        end, OFFER_ACCEPT_MS)
    end
end

local function OnQuestAdded()
    if run and run.waiting then
        run.accepted = run.accepted + 1
        run.skippedCraft[run.waiting.craft] = true   -- one of each craft per batch
        run.waiting = nil
        zo_callLater(AcceptNext, NEXT_WRIT_MS)
    end
end

-- Turning in -----------------------------------------------------------------------------------

local turnIn = { count = 0, lastAt = 0, acceptAfter = false }
local CONVERSATION_GAP_MS = 15000   -- a turn-in this long ago belongs to an earlier conversation

local function AtRolis()
    local name = zo_strformat("<<1>>", GetUnitName("interact"))
    return name ~= "" and name == GetString(SI_WRITCRAFTER_ROLIS_NAME)
end

-- Your accepted master writ quests, by quest name, and whether any is ready to hand in.
local function AcceptedQuests()
    local byName, anyReady = {}, false
    for _, entry in ipairs(WC.Master.Accepted()) do
        byName[entry.quest] = true
        anyReady = anyReady or entry.condition == nil
    end
    return byName, anyReady
end

local TURN_IN_OPTIONS = {
    [CHATTER_START_ADVANCE_COMPLETABLE_QUEST_CONDITIONS] = true,   -- "I've finished the ... job."
    [CHATTER_START_COMPLETE_QUEST] = true,                         -- "<Finish the job.>"
}

-- Nothing left to hand in this conversation.
local function FinishTurnIn()
    Say(SI_WRITCRAFTER_ROLIS_TURNED_IN, turnIn.count)
    turnIn.count = 0
    turnIn.acceptAfter = WC.settings.rolisAcceptNext and #(Candidates()) > 0
    if WC.settings.rolisClose then
        EndInteraction(INTERACTION_CONVERSATION)
    end
end

local function OnChatterBegin(_, optionCount)
    if not WC.settings.rolisTurnIn or not AtRolis() then
        return
    end
    if GetFrameTimeMilliseconds() - turnIn.lastAt > CONVERSATION_GAP_MS then
        turnIn.count = 0
    end
    local _, anyReady = AcceptedQuests()
    if anyReady then
        for optionIndex = 1, optionCount or 0 do
            local _, optionType = GetChatterOption(optionIndex)
            if TURN_IN_OPTIONS[optionType] then
                SelectChatterOption(optionIndex)
                return
            end
        end
    end
    if turnIn.count > 0 then
        FinishTurnIn()
    end
end

-- The game's "complete quest" dialog: only your accepted master writs are completed.
local function OnQuestCompleteDialog(_, journalIndex)
    if not WC.settings.rolisTurnIn or not AtRolis() then
        return
    end
    local byName = AcceptedQuests()
    if byName[GetJournalQuestName(journalIndex)] then
        CompleteQuest()
        turnIn.count = turnIn.count + 1
        turnIn.lastAt = GetFrameTimeMilliseconds()
    end
end

-- The conversation closed: accept the next batch, if that's on and writs are left.
local function OnChatterEnd()
    if turnIn.acceptAfter then
        turnIn.acceptAfter = false
        zo_callLater(function() Rolis.AcceptCrafted(false) end, 500)
    end
end

function Rolis.Init()
    local namespace = WC.name .. "Rolis"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_OFFERED, OnQuestOffered)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_ADDED, OnQuestAdded)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CHATTER_BEGIN, OnChatterBegin)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_COMPLETE_DIALOG, OnQuestCompleteDialog)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CHATTER_END, OnChatterEnd)
end
