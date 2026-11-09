local WC = WritCrafter

-- Daily writ quests. A daily condition is only text ("Craft Garlic Cod with Potato"), so instead
-- of parsing it (which would depend on the game's language), each craft's resolver generates the
-- items that station can make and asks the game which one fulfils the condition
-- (DoesItemLinkFulfillJournalQuestCondition). Answers are remembered for the session, keyed by
-- the condition text, so the search runs once per condition.
local Daily = {}
WC.Daily = Daily

-- [craftSkill] = function(condition) -> plan table, or nil when this craft can't fulfil it
local resolvers = {}
-- [craftSkill] = function(condition, plan) -> as an engine job's Craft()
local crafters = {}
-- [craftSkill] = true when the resolver's answer depends on what you own (alchemy, enchanting),
-- so a failed search is worth repeating at the next visit.
local retryFailures = {}

function Daily.RegisterCraft(craftSkill, resolver, crafter, stockDependent)
    resolvers[craftSkill] = resolver
    crafters[craftSkill] = crafter
    retryFailures[craftSkill] = stockDependent or nil
end

-- [craftSkill] = { [conditionText] = plan or false }
local resolved = {}
-- [quest name] = the craft whose resolver matched one of the quest's conditions. Each daily quest
-- is for one craft, so other crafts skip its conditions instead of searching them.
local claims = {}

-- The crafting quests in the journal, read once and kept until something can change them:
-- a quest event, or a backpack change (conditions count what's in the backpack). Everything
-- that asks about writ quests (jobs at each station step, storage, badges) shares one read.
-- Read-only: callers must not change the tables.
--   quests     { questIndex, quest } for every crafting quest
--   conditions every visible condition: { questIndex, stepIndex, conditionIndex, quest, text,
--              current, max, master, writ, info }. master: the game gives master writ details
--              for it (a craft, or an item); writ and info: those details, when WritCrafter can
--              craft that writ (see WC.Master.FromInfo).
--   daily      conditions that aren't master writs', nor any task of a master writ quest
--              WritCrafter knows (its delivery tasks are never daily crafting tasks)
local snapshot
local generation = 0
local journalListeners = {}

local function Snapshot()
    if snapshot then
        return snapshot
    end
    local quests, conditions = {}, {}
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING then
            local quest = GetJournalQuestName(questIndex)
            quests[#quests + 1] = { questIndex = questIndex, quest = quest }
            for stepIndex = 1, GetJournalQuestNumSteps(questIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                    local text, current, max, _, _, _, isVisible = GetJournalQuestConditionInfo(questIndex, stepIndex, conditionIndex)
                    if isVisible and text and text ~= "" and max and max > 0 then
                        local info = WC.Master.ReadInfo(questIndex, stepIndex, conditionIndex)
                        conditions[#conditions + 1] = {
                            questIndex = questIndex, stepIndex = stepIndex, conditionIndex = conditionIndex,
                            quest = quest, text = text, current = current, max = max,
                            master = WC.Master.IsWritInfo(info),
                            writ = WC.Master.FromInfo(info, max), info = info,
                        }
                    end
                end
            end
        end
    end
    snapshot = { quests = quests, conditions = conditions }
    return snapshot
end

-- Changes with every new read of the journal, for callers that cache what they work out from it.
function Daily.Generation()
    Snapshot()
    return generation
end

-- Forgets the read; the next question reads the journal again.
function Daily.Invalidate()
    if snapshot then
        snapshot = nil
        generation = generation + 1
    end
end

-- A master writ quest was newly remembered: its tasks stop counting as daily ones.
function Daily.MasterQuestsChanged()
    if snapshot then
        snapshot.daily = nil
    end
end

-- Called with (event, ...) after the journal changed (quest added, removed, advanced or its
-- progress changed, or the character entering the world), once the read has been forgotten.
function Daily.OnJournalChanged(listener)
    journalListeners[#journalListeners + 1] = listener
end

-- Crafting quests in the journal: { questIndex, quest }.
function Daily.Quests()
    return Snapshot().quests
end

-- Visible crafting conditions (see Snapshot), finished ones included: daily ones, or with
-- includeMaster every one, master writs' too.
function Daily.Conditions(includeMaster)
    local s = Snapshot()
    if includeMaster then
        return s.conditions
    end
    if not s.daily then
        local masterQuests = WC.character.acceptedWrits or {}
        local daily = {}
        for _, condition in ipairs(s.conditions) do
            if not condition.master and not masterQuests[condition.quest] then
                daily[#daily + 1] = condition
            end
        end
        s.daily = daily
    end
    return s.daily
end

-- /wc quests: every crafting quest condition, whether it reads as a master writ, and the raw
-- master writ details the game gives for it (for checking what WritCrafter works from).
function Daily.ListQuests()
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING then
            WC.Log.Say(zo_strformat("<<1>>:", GetJournalQuestName(questIndex)))
            for stepIndex = 1, GetJournalQuestNumSteps(questIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                    local text, current, max, _, _, _, isVisible = GetJournalQuestConditionInfo(questIndex, stepIndex, conditionIndex)
                    local info = { GetQuestConditionMasterWritInfo(questIndex, stepIndex, conditionIndex) }
                    for i = 1, 9 do
                        info[i] = tostring(info[i])
                    end
                    WC.Log.Say(string.format("  %d.%d %s (%s/%s)%s master=%s [%s]", stepIndex, conditionIndex,
                        (text and text ~= "") and text or "(no text)", tostring(current), tostring(max),
                        isVisible and "" or " hidden",
                        tostring(WC.Master.IsWritInfo(WC.Master.ReadInfo(questIndex, stepIndex, conditionIndex))),
                        table.concat(info, ", ")))
                end
            end
        end
    end
end

function Daily.HasAny()
    return #Snapshot().quests > 0
end

-- Re-reads one condition by its text (quest indexes can shift as quests are finished).
local function Reread(text)
    for _, condition in ipairs(Daily.Conditions()) do
        if condition.text == text then
            return condition
        end
    end
end

function Daily.Fulfils(link, condition)
    return link and link ~= "" and DoesItemLinkFulfillJournalQuestCondition(link,
        condition.questIndex, condition.stepIndex, condition.conditionIndex)
end

-- The reagent or solvent an "acquire" condition asks for, or nil (remembered per condition text).
local acquireCache = {}
function Daily.AcquireItem(condition)
    local hit = acquireCache[condition.text]
    if hit == nil then
        hit = false
        for itemId in pairs(WC.Data.Alchemy.REAGENTS) do
            if Daily.Fulfils(WC.Inventory.GetLink(itemId), condition) then
                hit = itemId
                break
            end
        end
        if not hit then
            for _, itemId in ipairs(WC.Data.Alchemy.SOLVENT_ITEMS) do
                if Daily.Fulfils(WC.Inventory.GetLink(itemId), condition) then
                    hit = itemId
                    break
                end
            end
        end
        acquireCache[condition.text] = hit
    end
    return hit or nil
end

-- Whether another condition of the same quest asks you to acquire a reagent or solvent: only
-- alchemy dailies do, so this tells an alchemy quest apart in any game language.
function Daily.IsAlchemyQuest(condition)
    for _, other in ipairs(Daily.Conditions()) do
        if other.questIndex == condition.questIndex and other.text ~= condition.text
            and Daily.AcquireItem(other) then
            return true
        end
    end
    return false
end

local function Resolve(skill, condition)
    local owner = claims[condition.quest]
    if owner and owner ~= skill then
        return nil
    end
    resolved[skill] = resolved[skill] or {}
    local hit = resolved[skill][condition.text]
    if hit == nil then
        local resolver = resolvers[skill]
        hit = resolver and resolver(condition) or false
        resolved[skill][condition.text] = hit
        if hit then
            claims[condition.quest] = skill
        end
    end
    return hit or nil
end

-- Called as a station opens: for crafts whose answers depend on what you own, answers from last
-- time that failed (nothing found, or a material missing) are worked out again, since you may
-- have fetched it since. Other crafts' answers, and searches that can't change, are kept.
function Daily.ForgetFailures(skill)
    local answers = resolved[skill]
    if not (answers and retryFailures[skill]) then
        return
    end
    for text, plan in pairs(answers) do
        if plan == false or plan.problem then
            answers[text] = nil
        end
    end
end

local function DailyJobs(skill)
    local jobs = {}
    if not WC.settings.autoCraftDaily or not crafters[skill] or not Daily.HasAny() then
        return jobs
    end
    for _, condition in ipairs(Daily.Conditions()) do
        if condition.current < condition.max and Resolve(skill, condition) then
            local text = condition.text
            jobs[#jobs + 1] = {
                id = "daily:" .. text,
                source = "daily",
                label = text,
                quest = condition.quest,
                State = function()
                    local now = Reread(text)
                    if not now then
                        return "done"   -- the step moved on (e.g. to "deliver")
                    end
                    return now.current >= now.max and "done" or "active"
                end,
                Progress = function()
                    local now = Reread(text)
                    return now and now.current or math.huge
                end,
                -- One made earlier and left in storage: take that instead of crafting another
                -- (only with "Daily writs: use items already in storage" on).
                Check = function()
                    if not WC.settings.bankWithdrawDaily then
                        return true
                    end
                    local now = Reread(text)
                    local stored, name = 0, nil
                    if now then
                        stored, name = WC.Bank.Stored(now)
                    end
                    if stored > 0 then
                        return false, zo_strformat(SI_WRITCRAFTER_DAILY_IN_STORAGE, stored, name)
                    end
                    return true
                end,
                Craft = function()
                    local now = Reread(text)
                    if not now then
                        return false
                    end
                    -- A resolver can answer "this craft's condition, but it can't be made" with
                    -- { problem = reason }, which is reported like any other craft problem.
                    local plan = Resolve(skill, now)
                    if plan and plan.problem then
                        return false, plan.problem
                    end
                    return crafters[skill](now, plan)
                end,
            }
        end
    end
    return jobs
end

function Daily.Init()
    WC.Engine.AddJobSource(DailyJobs)

    -- Journal changes: forget the read, then tell the listeners (in that order, so none of them
    -- sees the old one). Backpack changes only forget it.
    local function OnJournalEvent(event, ...)
        Daily.Invalidate()
        for _, listener in ipairs(journalListeners) do
            listener(event, ...)
        end
    end
    for _, event in ipairs({ EVENT_QUEST_ADDED, EVENT_QUEST_REMOVED, EVENT_QUEST_ADVANCED,
        EVENT_QUEST_CONDITION_COUNTER_CHANGED, EVENT_QUEST_LIST_UPDATED, EVENT_PLAYER_ACTIVATED }) do
        if event then
            EVENT_MANAGER:RegisterForEvent(WC.name .. "Journal" .. event, event, OnJournalEvent)
        end
    end
    WC.Inventory.AddListener(function(bagId)
        if not bagId or bagId == BAG_BACKPACK then
            Daily.Invalidate()
        end
    end)

    -- A new day brings new conditions; forget old answers when quests change.
    local function Forget()
        ZO_ClearTable(resolved)
        ZO_ClearTable(acquireCache)
        ZO_ClearTable(claims)
    end
    EVENT_MANAGER:RegisterForEvent(WC.name .. "Daily", EVENT_QUEST_ADDED, Forget)
    -- A new recipe or style can make a writ item that wasn't found before: search again.
    local function ForgetAllFailures()
        for _, answers in pairs(resolved) do
            for text, plan in pairs(answers) do
                if plan == false or plan.problem then
                    answers[text] = nil
                end
            end
        end
    end
    for _, event in ipairs({ EVENT_RECIPE_LEARNED, EVENT_MULTIPLE_RECIPES_LEARNED, EVENT_STYLE_LEARNED }) do
        if event then
            EVENT_MANAGER:RegisterForEvent(WC.name .. "DailyLearned" .. event, event, ForgetAllFailures)
        end
    end
end
