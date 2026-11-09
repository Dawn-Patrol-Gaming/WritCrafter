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
local problems = 0       -- jobs that couldn't be crafted this visit
local firstProblem       -- the first problem's text, for the banner

local function Problem(text)
    problems = problems + 1
    firstProblem = firstProblem or text
end


local LEAVE_DELAY_MS = 800   -- let the "done" sound and alert play before leaving

-- A short message in the top-right corner, drawn above the crafting window. Its right edge stays
-- put, so longer text grows to the left. WritCrafter's own label rather than the game's alert
-- list, whose layout isn't ours to change.
local CORNER_MS = 4000
local corner

local function Corner(text)
    if not corner then
        corner = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "Corner")
        corner:SetDrawTier(DT_HIGH)
        corner:SetDrawLayer(DL_OVERLAY)
        corner:SetMouseEnabled(false)
        corner:SetDimensions(10, 10)
        corner:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 4)   -- above the station's tab icons
        corner.label = WINDOW_MANAGER:CreateControl(WC.name .. "CornerText", corner, CT_LABEL)
        corner.label:SetFont("ZoFontWinH2")
        corner.label:SetColor(1, 0.9, 0.6, 1)
        corner.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        corner.label:SetAnchor(TOPRIGHT, corner, TOPRIGHT, 0, 0)
    end
    corner.label:SetText(text)
    corner:SetHidden(false)
    corner.shownAt = GetGameTimeMilliseconds()
    zo_callLater(function()
        if GetGameTimeMilliseconds() - corner.shownAt >= CORNER_MS - 50 then
            corner:SetHidden(true)
        end
    end, CORNER_MS)
end

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

-- A large message in the middle of the screen, drawn above the crafting window: the game's own
-- centre-screen announcements are part of the HUD, which is hidden at a station, and chat is
-- rolled up there too, so the banner carries the reason itself.
local BANNER_MS = 6000
local banner

local function BannerLabel(name, font, offsetY)
    local label = WINDOW_MANAGER:CreateControl(WC.name .. name, banner, CT_LABEL)
    label:SetFont(font)
    label:SetColor(1, 0.45, 0.3, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDimensionConstraints(0, 0, 1100, 0)
    label:SetAnchor(TOP, banner, TOP, 0, offsetY)
    return label
end

local function Banner(title, detail)
    if not WC.settings.craftNotice then
        return
    end
    if not banner then
        banner = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "Banner")
        banner:SetDrawTier(DT_HIGH)
        banner:SetDrawLayer(DL_OVERLAY)
        banner:SetMouseEnabled(false)
        banner:SetDimensions(1100, 200)
        banner:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
        banner.title = BannerLabel("BannerTitle", "ZoFontCallout3", 0)
        banner.detail = BannerLabel("BannerDetail", "ZoFontWinH1", 70)
        banner.detail:SetColor(1, 0.8, 0.6, 1)
    end
    banner.title:SetText(title)
    banner.detail:SetText(detail or "")
    banner:SetHidden(false)
    banner.shownAt = GetGameTimeMilliseconds()
    zo_callLater(function()
        if GetGameTimeMilliseconds() - banner.shownAt >= BANNER_MS - 50 then
            banner:SetHidden(true)
        end
    end, BANNER_MS)
end

-- Banner for problems: the first one, plus how many more are in chat.
local function ProblemBanner()
    local detail = firstProblem or ""
    if problems > 1 then
        detail = detail .. zo_strformat(SI_WRITCRAFTER_BANNER_MORE, problems - 1)
    end
    Banner(GetString(SI_WRITCRAFTER_BANNER_PROBLEM), detail)
end

local function Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

-- "Crafting 16 x Damage Stamina Poison IX with Alkahest, Stinkhorn, Imp Stool". materials is
-- a list of { itemId = id } or { name = text }, each with an optional total count.
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

function Engine.SayCrafting(count, resultLink, materials)
    local parts = {}
    for _, material in ipairs(materials or {}) do
        local name = material.name
            or zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(material.itemId)))
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

local function CraftName(skill)
    return zo_strformat("<<1>>", GetCraftingSkillName(skill))
end

local function Stop()
    running = false
    waiting = nil
end

-- Called when every job for this station has been worked through. Leaves the station only if
-- WritCrafter crafted writ items on this visit and nothing failed, so it never closes after
-- your own crafting, and stays open when there's something to read in chat.
local function Finish()
    WC.DailyItems.Begin(nil)   -- every craft's items have landed by now
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
        if job.State() == "active" then
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
    for id in pairs(worked) do
        if not present[id] then
            worked[id] = nil
            finished = finished + 1
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
                    finished = finished + 1
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
                    if issued and not announced then
                        announced = true
                        -- The sound is normally already played by CraftSounds; not for a move.
                        local sound = not startPlayed and SOUNDS.QUEST_OBJECTIVE_STARTED or nil
                        startPlayed = true
                        Notice("soundStart", sound, SI_WRITCRAFTER_ALERT_START,
                            WritKinds(jobs), CraftName(craftSkill))
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
                        worked[id] = true
                        waiting = { id = id, progress = job.Progress() }
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
                label = zo_strformat("<<t:1>>", GetItemLinkName(writ.link)),
                State = function()
                    local status = Status()
                    if not status then
                        return "gone"
                    end
                    return status.crafted and "done" or "active"
                end,
                Progress = function()
                    local status = Status()
                    if not status then
                        return 0
                    end
                    local progress = progressOf[writ.kind]
                    return progress and progress(writ, status) or status.have
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
                    local crafter = crafters[writ.kind]
                    if not crafter then
                        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_NOT_YET, CraftName(skill))
                    end
                    return crafter(writ, Status())
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
                if not status then
                    return math.huge
                end
                local progress = progressOf[writ.kind]
                return progress and progress(writ, status) or status.have
            end,
            -- Matched like the badge and the bank pickup (the game's own condition check
            -- didn't count a bank item for an accepted master writ).
            Check = function()
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
                local crafter = crafters[writ.kind]
                local status = Status()
                if not crafter then
                    return false, zo_strformat(SI_WRITCRAFTER_CRAFT_NOT_YET, CraftName(skill))
                end
                if not status then
                    return false
                end
                return crafter(writ, status)
            end,
        }
    end
    return jobs
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
            WC.Log.Debug(string.format("Station %d opened: %d job(s); auto-craft %s; queued: %s; accepted: %s", skill, #jobs,
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
