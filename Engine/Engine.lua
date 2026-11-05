local WC = WritCrafter

-- Crafts queued writs when you open a crafting station. One craft call at a time: each waits
-- for the game to finish, then the next step is planned again from what's actually in your
-- bags (via the already-crafted matching), so nothing is ever crafted twice. If a finished
-- craft didn't add anything the writ recognizes, that writ is dropped from this session's run
-- rather than crafted again, so a mismatch can never loop and burn materials.
local Engine = {}
WC.Engine = Engine

local SETTLE_MS = 300     -- after a craft completes, let the bag updates land before re-planning
local BUSY_RETRY_MS = 200

-- [kind] = function(writ, status) returning:
--   true            a craft call was issued; EVENT_CRAFT_COMPLETED continues the run
--   "wait"          the station needs a moment (e.g. a Grand Master set switch); call again
--   false, reason   can't craft this writ now
local crafters = {}
-- [kind] = function(writ, status) -> number that grows with every successful craft. Default:
-- items made. Multi-step crafts (smithing: create, then improve) count their steps too.
local progressOf = {}
local WAIT_MS = 300
local MAX_WAITS = 10   -- per writ and visit, so a station that never becomes ready can't loop

function Engine.RegisterCrafter(kind, crafter, progress)
    crafters[kind] = crafter
    progressOf[kind] = progress
end

local function Progress(writ, status)
    local progress = progressOf[writ.kind]
    return progress and progress(writ, status) or status.have
end

local running = false
local craftSkill
local waiting       -- { uid, progress } for the craft in progress
local waits = {}    -- [uid] = times this writ asked to wait during this visit
local skipped = {}  -- [uid] = true: not crafted again during this station visit
local crafted = 0   -- writs finished during this visit

local function Say(stringId, ...)
    WC.Log.Say(zo_strformat(stringId, ...))
end

local function CraftName(skill)
    return zo_strformat("<<1>>", GetCraftingSkillName(skill))
end

local function Stop()
    running = false
    waiting = nil
end

local function Finish()
    if crafted > 0 then
        Say(SI_WRITCRAFTER_CRAFT_DONE, crafted, CraftName(craftSkill))
    end
    Stop()
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

    for _, entry in ipairs(WC.Queue.List()) do
        local writ, uid = entry.writ, entry.uid
        if writ.craft == craftSkill and not skipped[uid] then
            local status = WC.Reservations.GetWritStatus(uid)
            if not status then
                WC.Queue.Remove(uid)   -- the writ isn't in your bag or bank any more
            elseif waiting and waiting.uid == uid and Progress(writ, status) <= waiting.progress then
                if not waiting.retried then
                    waiting.retried = true   -- the new items may not have reached the bag yet
                    Later(SETTLE_MS * 3)
                    return
                end
                -- The last craft for this writ added nothing it recognizes: stop, don't repeat.
                waiting = nil
                skipped[uid] = true
                Say(SI_WRITCRAFTER_CRAFT_UNRECOGNIZED, GetItemLinkName(writ.link))
            elseif status.crafted then
                waiting = nil
                WC.Queue.Remove(uid)
                crafted = crafted + 1
            else
                local verdict = WC.Rules.Evaluate(writ)
                local crafter = crafters[writ.kind]
                if verdict.status ~= WC.Rules.OK then
                    skipped[uid] = true
                    Say(SI_WRITCRAFTER_CRAFT_SKIPPED, verdict.reasons[1] or "")
                elseif not crafter then
                    skipped[uid] = true
                    Say(SI_WRITCRAFTER_CRAFT_NOT_YET, CraftName(craftSkill))
                else
                    local issued, reason = crafter(writ, status)
                    if issued == "wait" then
                        waits[uid] = (waits[uid] or 0) + 1
                        if waits[uid] <= MAX_WAITS then
                            Later(WAIT_MS)
                            return
                        end
                        issued, reason = false, GetString(SI_WRITCRAFTER_CRAFT_STATION_NOT_READY)
                    end
                    if issued then
                        waiting = { uid = uid, progress = Progress(writ, status) }
                        return   -- EVENT_CRAFT_COMPLETED continues the run
                    end
                    skipped[uid] = true
                    Say(SI_WRITCRAFTER_CRAFT_CANT, reason or "")
                end
            end
        end
    end
    Finish()
end

local function OnStationOpened(_, skill)
    -- Idle unless something is queued for this craft.
    if running or not WC.settings.autoCraft or not WC.Queue.HasAny() then
        return
    end
    local any = false
    for _, entry in ipairs(WC.Queue.List()) do
        if entry.writ.craft == skill then
            any = true
            break
        end
    end
    if not any then
        return
    end
    running, craftSkill, waiting, crafted = true, skill, nil, 0
    ZO_ClearTable(skipped)
    ZO_ClearTable(waits)
    WC.Reservations.EnsureFresh()
    Later(SETTLE_MS)   -- let the station's own UI finish opening
end

local function OnCraftCompleted()
    if running and waiting then
        Later(SETTLE_MS)
    end
end

local function OnCraftFailed(_, result)
    if running then
        Say(SI_WRITCRAFTER_CRAFT_FAILED, GetString("SI_TRADESKILLRESULT", result))
        Stop()
    end
end

function Engine.Init()
    local namespace = WC.name .. "Engine"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFTING_STATION_INTERACT, OnStationOpened)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_END_CRAFTING_STATION_INTERACT, Stop)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_COMPLETED, OnCraftCompleted)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFT_FAILED, OnCraftFailed)
end

function Engine.IsRunning()
    return running
end
