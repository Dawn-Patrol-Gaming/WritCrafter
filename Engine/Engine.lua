local WC = WritCrafter

-- Crafts writ items when you open a crafting station. Work comes as jobs from job sources:
-- queued sealed master writs (below) and daily writ quests (Writs/Daily.lua). One craft call at
-- a time: each waits for the game to finish, then the next step is planned again from the
-- current state of bags and quests, so nothing is ever crafted twice. If a finished craft made
-- no progress on its job, that job is dropped for this station visit rather than crafted
-- again, so a mismatch can never loop and burn materials.
--
-- A job is a table with:
--   id           unique per job
--   label        name for chat messages
--   State()      "active", "done" or "gone" (the writ or quest no longer exists)
--   Progress()   number that grows with every successful craft
--   Check()      optional: true, or false, reason (e.g. the writ's verdict changed)
--   Craft()      true (a craft call was issued), "moved" (items were moved, not crafted),
--                "wait" (the station needs a moment, call again), or false, reason (can't
--                craft it now; reason nil = not this station's)
--   OnDone()     optional, called once when it's finished
--   OnGone()     optional
--   source       "daily" or "master", for the start notice
local Engine = {}
WC.Engine = Engine

local SETTLE_MS = 300     -- after a craft completes, let the bag updates land before re-planning
local BUSY_RETRY_MS = 200
local WAIT_MS = 300
local MAX_WAITS = 10      -- per job and visit, so a station that never becomes ready can't loop
local REWARDS_TIMEOUT_MS = 8000   -- longest a batch of writ rewards takes to come apart

-- Master writ crafters, by writ kind: function(writ, status) -> as Job.Craft; and optional
-- progress functions (writ, status) -> number (default: items made).
local crafters = {}
local progressOf = {}

function Engine.RegisterCrafter(kind, crafter, progress)
    crafters[kind] = crafter
    progressOf[kind] = progress
end

-- Job sources: function(craftSkill) -> list of jobs for this station.
local sources = {}

function Engine.AddJobSource(source)
    sources[#sources + 1] = source
end

local running = false
local craftSkill
local waiting        -- { id, progress } for the craft in progress
local waits = {}     -- [id] = times this job asked to wait during this visit
local skipped = {}   -- [id] = true: not crafted again during this station visit
local worked = {}    -- [id] = true: crafted for during this visit
local finished = 0   -- jobs finished during this visit
local announced = false  -- the "crafting started" notice was shown this visit
local startPlayed = false  -- its sound was played (just before the first craft call)
local dailyQuests = {}   -- [quest] = true: daily writs crafted for during this visit
local problems = 0       -- jobs that couldn't be crafted this visit
local firstProblem       -- the first problem's text, for the banner

local function Problem(text)
    problems = problems + 1
    firstProblem = firstProblem or text
end

local LEAVE_DELAY_MS = 800   -- let the "done" sound and alert play before leaving

local Corner = WC.Notices.Corner
local Banner = WC.Notices.Banner

-- A notice: its sound (if that sound's setting is on) and, with stringId, a short top-right
-- message (if on-screen notices are on). soundSetting names the setting for this sound.
local function Notice(soundSetting, sound, stringId, ...)
    if WC.settings[soundSetting] and sound then
        PlaySound(sound)
    end
    if stringId and WC.settings.craftNotice then
        Corner(zo_strformat(stringId, ...))
    end
end

-- Banner for problems: the first one, plus how many more are in chat.
local function ProblemBanner()
    local detail = firstProblem or ""
    if problems > 1 then
        detail = detail .. zo_strformat(SI_WRITCRAFTER_BANNER_MORE, problems - 1)
    end
    Banner(GetString(SI_WRITCRAFTER_BANNER_PROBLEM), detail)
end

local Say = WC.Util.Say

-- Station sounds for a craft WritCrafter starts. Crafting through the API skips the station
-- screen, so the sounds of slotting items never play; these stand in for them. placed: sounds
-- played in quick succession now (e.g. solvent, then reagents); done: played when the craft
-- completes (e.g. the success glow).
local SLOT_SOUND_GAP_MS = 180
local doneSound

function Engine.CraftSounds(placed, done)
    doneSound = nil
    -- The start sound goes before the craft call: played after it, smithing's own create sound
    -- drowns it out.
    local delay = 0
    if not startPlayed then
        startPlayed = true
        if WC.settings.soundStart then
            PlaySound(SOUNDS.QUEST_OBJECTIVE_STARTED)
            delay = SLOT_SOUND_GAP_MS
        end
    end
    if WC.settings.soundSlot then
        for i, sound in ipairs(placed or {}) do
            zo_callLater(function() PlaySound(sound) end, delay + (i - 1) * SLOT_SOUND_GAP_MS)
        end
    end
    if WC.settings.soundSuccess then
        doneSound = done
    end
end

-- How many batches a craft call makes: what's wanted, capped by what the materials allow; one
-- batch while the result is still unknown to you (the game's rule: the first craft teaches it).
-- Returns the count, or nil and the game's reason when nothing can be made.
function Engine.Batches(wanted, maxIterations, result, known)
    if not maxIterations or maxIterations == 0 then
        return nil, GetString("SI_TRADESKILLRESULT", result)
    end
    if known == false then
        return 1
    end
    return zo_min(wanted, maxIterations)
end

-- "Crafting 16 x Damage Stamina Poison IX with Alkahest, Stinkhorn, Imp Stool". materials is
-- a list of { itemId = id } or { name = text }, each with an optional total count.
-- needed (optional): how many the writ still needed; anything above it is extra (skills make
-- several potions or dishes per craft), handed to the Extra Crafted Items reward action.
function Engine.SayCrafting(count, resultLink, materials, needed)
    if needed and count > needed then
        WC.Rewards.ExpectExtra(resultLink, count - needed)
    end
    local parts = {}
    for _, material in ipairs(materials or {}) do
        local name = material.name
            or WC.Util.ItemName(material.itemId)
        if material.count and material.count > 1 then
            name = material.count .. " x " .. name
        end
        parts[#parts + 1] = name
    end
    if #parts > 0 then
        Say(SI_WRITCRAFTER_CRAFTING_WITH, count, GetItemLinkName(resultLink), table.concat(parts, ", "))
    else
        Say(SI_WRITCRAFTER_CRAFTING, count, GetItemLinkName(resultLink))
    end
end

local CraftName = WC.Util.CraftName

local function Stop()
    running = false
    waiting = nil
end

-- Called when every job for this station has been worked through. Leaves the station only if
-- WritCrafter crafted writ items on this visit and nothing failed, so it never closes after
-- your own crafting, and stays open when there's something to read in chat.
local function Finish()
    WC.DailyItems.Begin(nil)   -- every craft's items have landed by now
    -- Daily writs crafted for here with nothing left for this craft: ready to deliver.
    for quest in pairs(dailyQuests) do
        if not WC.Daily.HasCraftWork(craftSkill, quest) then
            WC.WritStatus.MarkReady(quest)
        end
    end
    ZO_ClearTable(dailyQuests)
    local crafted = finished > 0
    if crafted then
        Say(SI_WRITCRAFTER_CRAFT_DONE, finished, CraftName(craftSkill))
    end
    if problems > 0 then
        Notice("soundProblem", SOUNDS.GENERAL_ALERT_ERROR)   -- the banner carries the message
        ProblemBanner()
    elseif crafted then
        Notice("soundDone", SOUNDS.QUEST_OBJECTIVE_COMPLETE, SI_WRITCRAFTER_ALERT_DONE, finished, CraftName(craftSkill))
        if WC.settings.leaveStation then
            local skill = craftSkill
            local tries = 0
            local function TryLeave()
                tries = tries + 1
                if GetCraftingInteractionType() ~= skill then
                    WC.Log.Debug("Leave station: already left")
                    return
                end
                -- Still finishing the craft animation (or crafting by hand): try again shortly.
                if ZO_CraftingUtils_IsPerformingCraftProcess() then
                    if tries < 10 then
                        zo_callLater(TryLeave, 300)
                    else
                        WC.Log.Debug("Leave station: still crafting, stayed")
                    end
                    return
                end
                WC.Log.Debug("Leave station: leaving")
                SCENE_MANAGER:ShowBaseScene()
            end
            zo_callLater(TryLeave, LEAVE_DELAY_MS)
        end
    end
    Stop()
end

-- "daily", "master" or "daily and master": which kinds of writ this visit is working on.
local function WritKinds(jobs)
    local daily, master = false, false
    for _, job in ipairs(jobs) do
        if job.State() == "active" then   -- (reward jobs are neither)
            daily = daily or job.source == "daily"
            master = master or job.source == "master"
        end
    end
    if daily and master then
        return GetString(SI_WRITCRAFTER_KIND_BOTH)
    end
    return GetString(master and SI_WRITCRAFTER_KIND_MASTER or SI_WRITCRAFTER_KIND_DAILY)
end

local function CollectJobs(skill)
    local jobs = {}
    for _, source in ipairs(sources) do
        for _, job in ipairs(source(skill)) do
            jobs[#jobs + 1] = job
        end
    end
    return jobs
end

local Step

local function Later(ms)
    zo_callLater(function() Step() end, ms)
end

function Step()
    if not running then
        return
    end
    if GetCraftingInteractionType() ~= craftSkill then
        Stop()
        return
    end
    if ZO_CraftingUtils_IsPerformingCraftProcess() then
        Later(BUSY_RETRY_MS)
        return
    end
    if waiting then
        WC.Reservations.Invalidate()   -- read the bags as they are now, not as last matched
    end

    local jobs = CollectJobs(craftSkill)
    -- A job crafted for this visit that no longer shows up has finished: a daily condition
    -- vanishes from the journal once complete (the quest moves on to "deliver").
    local present = {}
    for _, job in ipairs(jobs) do
        present[job.id] = true
    end
    for id, kind in pairs(worked) do
        if not present[id] then
            worked[id] = nil
            if kind ~= "rewards" then
                finished = finished + 1
            end
            if waiting and waiting.id == id then
                waiting = nil
            end
        end
    end
    for _, job in ipairs(jobs) do
        local id = job.id
        if not skipped[id] then
            local state = job.State()
            if state == "gone" then
                if job.OnGone then
                    job.OnGone()
                end
            elseif waiting and waiting.id == id and job.Progress() <= waiting.progress then
                if not waiting.retried then
                    waiting.retried = true   -- the new items may not have reached the bag yet
                    Later(SETTLE_MS * 3)
                    return
                end
                -- The last craft for this job made no progress: stop, don't repeat.
                waiting = nil
                skipped[id] = true
                Say(SI_WRITCRAFTER_CRAFT_UNRECOGNIZED, job.label)
                Problem(zo_strformat(SI_WRITCRAFTER_CRAFT_UNRECOGNIZED, job.label))
            elseif state == "done" then
                if waiting and waiting.id == id then
                    waiting = nil
                end
                if worked[id] then
                    if worked[id] ~= "rewards" then
                        finished = finished + 1   -- writ items only: deconstructing rewards isn't one
                    end
                    worked[id] = nil
                end
                if job.OnDone then
                    job.OnDone()
                end
            else
                local ok, reason = true, nil
                if job.Check then
                    ok, reason = job.Check()
                end
                if not ok then
                    skipped[id] = true
                    Say(SI_WRITCRAFTER_CRAFT_SKIPPED, reason or "")
                    Problem(reason or "")
                else
                    local issued
                    WC.DailyItems.Begin(job.quest)   -- badges what a daily craft makes
                    issued, reason = job.Craft()
                    if issued == "wait" then
                        waits[id] = (waits[id] or 0) + 1
                        if waits[id] <= MAX_WAITS then
                            Later(WAIT_MS)
                            return
                        end
                        issued, reason = false, GetString(SI_WRITCRAFTER_CRAFT_STATION_NOT_READY)
                    end
                    if issued and not announced and job.source ~= "rewards" then
                        announced = true
                        -- The sound is normally already played by CraftSounds; not for a move.
                        local sound = not startPlayed and SOUNDS.QUEST_OBJECTIVE_STARTED or nil
                        startPlayed = true
                        Notice("soundStart", sound, SI_WRITCRAFTER_ALERT_START,
                            WritKinds(jobs), CraftName(craftSkill))
                    end
                    if issued and job.source == "daily" and job.quest then
                        dailyQuests[job.quest] = true
                    end
                    if issued == "moved" then
                        -- Not a craft (e.g. a reagent moved into the backpack): no craft event
                        -- follows, so check the progress again after a short pause.
                        worked[id] = true
                        waiting = { id = id, progress = job.Progress() }
                        Later(SETTLE_MS * 2)
                        return
                    end
                    if issued then
                        worked[id] = job.source == "rewards" and "rewards" or true
                        waiting = { id = id, progress = job.Progress() }
                        if job.source == "rewards" then
                            -- In case taking things apart doesn't report like a craft does, look
                            -- again after a while rather than waiting for ever.
                            local thisWait = waiting
                            zo_callLater(function()
                                if running and waiting == thisWait then
                                    Step()
                                end
                            end, REWARDS_TIMEOUT_MS)
                        end
                        return   -- EVENT_CRAFT_COMPLETED continues the run
                    end
                    skipped[id] = true
                    if reason then
                        Say(SI_WRITCRAFTER_CRAFT_CANT, reason)
                        Problem(reason)
                    end
                end
            end
        end
    end
    Finish()
end

-- A master writ's progress number, and its craft call, shared by sealed and accepted writs.
local function WritProgress(writ, status)
    local progress = progressOf[writ.kind]
    return progress and progress(writ, status) or status.have
end

local function CraftWrit(writ, status, skill)
    local crafter = crafters[writ.kind]
    if not crafter then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_NOT_YET, CraftName(skill))
    end
    if not status then
        return false
    end
    return crafter(writ, status)
end

-- Built-in job source: queued sealed master writs for this station's craft.
local function MasterJobs(skill)
    local jobs = {}
    for _, entry in ipairs(WC.Queue.List()) do
        local writ, uid = entry.writ, entry.uid
        if writ.craft == skill then
            local function Status()
                return WC.Reservations.GetWritStatus(uid)
            end
            jobs[#jobs + 1] = {
                id = "master:" .. uid,
                source = "master",
                label = WC.Util.ItemName(writ.link),
                State = function()
                    local status = Status()
                    if not status then
                        return "gone"
                    end
                    return status.crafted and "done" or "active"
                end,
                Progress = function()
                    local status = Status()
                    return status and WritProgress(writ, status) or 0
                end,
                Check = function()
                    local verdict = WC.Rules.Evaluate(writ)
                    -- Queued by hand despite your settings: only "can't craft" stops it.
                    if verdict.status == WC.Rules.REJECTED and WC.Queue.IsOverride(uid) then
                        return true
                    end
                    if verdict.status ~= WC.Rules.OK then
                        return false, verdict.reasons[1]
                    end
                    return true
                end,
                Craft = function()
                    return CraftWrit(writ, Status(), skill)
                end,
                OnDone = function() WC.Queue.Remove(uid) end,
                OnGone = function()
                    -- Accepting the writ uses it up; its quest is then crafted as an accepted writ.
                    local accepted = false
                    for _, entry in ipairs(WC.Master.Accepted()) do
                        if entry.writ.craft == writ.craft then
                            accepted = true
                            break
                        end
                    end
                    if not accepted then
                        Say(SI_WRITCRAFTER_QUEUE_GONE, GetItemLinkName(writ.link))
                    end
                    WC.Queue.Remove(uid)
                end,
            }
        end
    end
    return jobs
end

-- Accepted master writ quest conditions for this craft: { condition, writ }.
local function AcceptedWrits(skill)
    local list = {}
    for _, entry in ipairs(WC.Master.Accepted()) do
        if entry.condition and entry.writ.craft == skill then   -- still to craft
            list[#list + 1] = entry
        end
    end
    return list
end

-- Built-in job source: accepted master writs (quests in the journal) for this station's craft.
-- The quest counts finished items in the backpack, so that's the progress; one already made and
-- left in storage is taken out at the bank instead of crafting another.
local function AcceptedJobs(skill)
    local jobs = {}
    for _, entry in ipairs(AcceptedWrits(skill)) do
        local writ, quest = entry.writ, entry.condition.quest
        local function Now()
            for _, condition in ipairs(WC.Daily.Conditions(true)) do
                if condition.master and condition.quest == quest then
                    return condition
                end
            end
        end
        local function Status()
            local now = Now()
            if not now then
                return nil
            end
            return { required = now.max, have = now.current, crafted = now.current >= now.max }
        end
        jobs[#jobs + 1] = {
            id = "accepted:" .. quest,
            source = "master",
            label = quest,
            State = function()
                local now = Now()
                if not now then
                    return "done"   -- turned in, or the step moved on
                end
                return now.current >= now.max and "done" or "active"
            end,
            Progress = function()
                local status = Status()
                return status and WritProgress(writ, status) or math.huge
            end,
            -- Matched like the badge and the bank pickup (the game's own condition check
            -- didn't count a bank item for an accepted master writ).
            Check = function()
                if not WC.settings.bankWithdrawMaster then
                    return true
                end
                local stored, name = 0, nil
                for _, item in ipairs(WC.Reservations.BankItemsForAcceptedWrits()) do
                    if item.quest == quest then
                        stored = stored + item.quantity
                        name = name or zo_strformat("<<t:1>>", GetItemName(item.bagId, item.slotIndex))
                    end
                end
                if stored > 0 then
                    return false, zo_strformat(SI_WRITCRAFTER_DAILY_IN_STORAGE, stored, name)
                end
                return true
            end,
            Craft = function()
                return CraftWrit(writ, Status(), skill)
            end,
        }
    end
    return jobs
end

-- For Debug chat: what kind of station this is, e.g. "Clothing station (2)", "Grand Master
-- Blacksmithing station (1)", "Deconstruction assistant or station (0)".
local function StationName(skill)
    local mode = GetCraftingInteractionMode()
    if CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION and mode == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION then
        return string.format("Deconstruction assistant or station (%d)", skill)
    end
    if skill == 0 then
        return string.format("Station with no craft (0, mode %s)", tostring(mode))
    end
    local grandMaster = mode == CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION and "Grand Master " or ""
    return string.format("%s%s station (%d)", grandMaster, CraftName(skill), skill)
end

local function OnStationOpened(_, skill)
    if running then
        return
    end
    -- Let the station's own UI finish opening first: smithing patterns (which daily writs are
    -- searched in) aren't readable the moment the station opens.
    zo_callLater(function()
        if running or GetCraftingInteractionType() ~= skill then
            return
        end
        -- Idle unless there's writ work for this craft.
        WC.Inventory.Invalidate()   -- FCO ItemSaver marks change without a bag event
        WC.Daily.ForgetFailures(skill)
        local jobs = CollectJobs(skill)
        if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
            local queued = {}
            for _, entry in ipairs(WC.Queue.List()) do
                local status = WC.Reservations.GetWritStatus(entry.uid)
                queued[#queued + 1] = string.format("%s (craft %d, %s)", GetItemLinkName(entry.writ.link),
                    entry.writ.craft or 0, status and (status.crafted and "crafted" or "found") or "not in backpack/bank")
            end
            local accepted = {}
            for _, entry in ipairs(AcceptedWrits(skill)) do
                accepted[#accepted + 1] = string.format("%s (%d/%d)", entry.condition.quest,
                    entry.condition.current, entry.condition.max)
            end
            WC.Log.Debug(string.format("%s opened: %d job(s); auto-craft %s; queued: %s; accepted: %s", StationName(skill), #jobs,
                tostring(WC.settings.autoCraft), #queued > 0 and table.concat(queued, ", ") or "none",
                #accepted > 0 and table.concat(accepted, ", ") or "none"))
        end
        if #jobs == 0 then
            return
        end
        running, craftSkill, waiting, finished, announced, problems = true, skill, nil, 0, false, 0
        startPlayed = false
        firstProblem = nil
        ZO_ClearTable(skipped)
        ZO_ClearTable(waits)
        ZO_ClearTable(worked)
        ZO_ClearTable(dailyQuests)
        WC.Reservations.EnsureFresh()
        Step()
    end, SETTLE_MS)
end

local function OnCraftCompleted()
    if running and waiting then
        if doneSound then
            PlaySound(doneSound)
            doneSound = nil
        end
        Later(SETTLE_MS)
    end
end

local function OnCraftFailed(_, result)
    if running then
        Say(SI_WRITCRAFTER_CRAFT_FAILED, GetString("SI_TRADESKILLRESULT", result))
        Problem(GetString("SI_TRADESKILLRESULT", result))
        Notice("soundProblem", SOUNDS.GENERAL_ALERT_ERROR)   -- the banner carries the message
        ProblemBanner()
        Stop()
    end
end

function Engine.Init()
    Engine.AddJobSource(function(skill)
        if not WC.settings.autoCraft or not WC.Queue.HasAny() then
            return {}
        end
        return MasterJobs(skill)
    end)
    Engine.AddJobSource(function(skill)
        if not WC.settings.autoCraft or not WC.Daily.HasAny() then
            return {}
        end
        return AcceptedJobs(skill)
    end)
    local namespace = WC.name .. "Engine"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFTING_STATION_INTERACT, OnStationOpened)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_END_CRAFTING_STATION_INTERACT, Stop)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_FAILED, OnCraftFailed)
end

function Engine.IsRunning()
    return running
end
