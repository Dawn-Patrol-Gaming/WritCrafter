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
        corner:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 60)
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
    if WC.settings.soundSlot then
        for i, sound in ipairs(placed or {}) do
            zo_callLater(function() PlaySound(sound) end, (i - 1) * SLOT_SOUND_GAP_MS)
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
                        Notice("soundStart", SOUNDS.QUEST_OBJECTIVE_STARTED, SI_WRITCRAFTER_ALERT_START,
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
                OnGone = function() WC.Queue.Remove(uid) end,
            }
        end
    end
    return jobs
end

local function OnStationOpened(_, skill)
    if running then
        return
    end
    -- Idle unless there's writ work for this craft.
    WC.Daily.ForgetFailures()
    local jobs = CollectJobs(skill)
    if #jobs == 0 then
        return
    end
    running, craftSkill, waiting, finished, announced, problems = true, skill, nil, 0, false, 0
    firstProblem = nil
    ZO_ClearTable(skipped)
    ZO_ClearTable(waits)
    ZO_ClearTable(worked)
    WC.Reservations.EnsureFresh()
    Later(SETTLE_MS)   -- let the station's own UI finish opening
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
    local namespace = WC.name .. "Engine"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFTING_STATION_INTERACT, OnStationOpened)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_END_CRAFTING_STATION_INTERACT, Stop)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_FAILED, OnCraftFailed)
end

function Engine.IsRunning()
    return running
end
