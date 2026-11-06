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

function Daily.RegisterCraft(craftSkill, resolver, crafter)
    resolvers[craftSkill] = resolver
    crafters[craftSkill] = crafter
end

-- [craftSkill] = { [conditionText] = plan or false }
local resolved = {}

local function IsMasterCondition(questIndex, stepIndex, conditionIndex)
    local itemId = GetQuestConditionMasterWritInfo(questIndex, stepIndex, conditionIndex)
    return itemId ~= nil and itemId ~= 0
end

-- Unfinished daily crafting conditions in the journal: { questIndex, stepIndex,
-- conditionIndex, text, current, max }. Master writ quests are left for milestone 5.
function Daily.Conditions()
    local list = {}
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING then
            for stepIndex = 1, GetJournalQuestNumSteps(questIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                    local text, current, max, _, _, _, isVisible = GetJournalQuestConditionInfo(questIndex, stepIndex, conditionIndex)
                    if isVisible and text and text ~= "" and max and max > 0
                        and not IsMasterCondition(questIndex, stepIndex, conditionIndex) then
                        list[#list + 1] = {
                            questIndex = questIndex, stepIndex = stepIndex, conditionIndex = conditionIndex,
                            text = text, current = current, max = max,
                        }
                    end
                end
            end
        end
    end
    return list
end

function Daily.HasAny()
    for questIndex = 1, MAX_JOURNAL_QUESTS do
        if IsValidQuestIndex(questIndex) and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING then
            return true
        end
    end
    return false
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

-- The reagent an "acquire" condition asks for, or nil (remembered per condition text).
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
        acquireCache[condition.text] = hit
    end
    return hit or nil
end

-- Whether another condition of the same quest asks you to acquire a reagent: only alchemy
-- dailies do, so this tells an alchemy quest apart in any game language.
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
    resolved[skill] = resolved[skill] or {}
    local hit = resolved[skill][condition.text]
    if hit == nil then
        local resolver = resolvers[skill]
        hit = resolver and resolver(condition) or false
        resolved[skill][condition.text] = hit
    end
    return hit or nil
end

-- Called as a station opens: answers that depend on what you had last time (nothing found, or
-- a material missing) are worked out again, since you may have fetched it since.
function Daily.ForgetFailures()
    for _, answers in pairs(resolved) do
        for text, plan in pairs(answers) do
            if plan == false or plan.problem then
                answers[text] = nil
            end
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
    -- A new day brings new conditions; forget old answers when quests change.
    local function Forget()
        ZO_ClearTable(resolved)
        ZO_ClearTable(acquireCache)
    end
    EVENT_MANAGER:RegisterForEvent(WC.name .. "Daily", EVENT_QUEST_ADDED, Forget)
end
