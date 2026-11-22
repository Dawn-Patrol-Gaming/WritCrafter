local WC = WritCrafter

-- Sealed master writs the player has asked WritCrafter to craft, per character, kept across
-- reloads. Each entry is keyed by the writ's unique ID and keeps its link, so the writ can be
-- decoded without finding the item. Shared by the right-click menu and the queue window.
local Queue = {}
WC.Queue = Queue

local entries   -- WC.character.queue: [uid] = { link = writLink, override = true when queued despite your settings }

function Queue.Init()
    WC.character.queue = WC.character.queue or {}
    entries = WC.character.queue
end

-- Queued writs claim matching items before unqueued ones (see Reservations), so re-match.
local function Changed()
    WC.Reservations.Invalidate()
    WC.InventoryIcons.Refresh()
    WC.QueueWindow.OnQueueChanged()
    WC.Markers.RefreshSoon()
end

-- override: queued by hand although your settings reject it (the queue window asks first);
-- stations then craft it anyway.
function Queue.Add(uid, link, override)
    entries[uid] = { link = link, override = override or nil }
    Changed()
end

function Queue.Remove(uid)
    entries[uid] = nil
    Changed()
end

-- Several writs at once ({ { uid, link }, ... }), with one change notice for the lot: each
-- notice re-matches items and redraws badges, so a bulk action shouldn't send one per writ.
-- Writs already queued are left as they are. Returns how many were added.
function Queue.AddAll(list)
    local count = 0
    for _, writ in ipairs(list) do
        if not entries[writ.uid] then
            entries[writ.uid] = { link = writ.link }
            count = count + 1
        end
    end
    if count > 0 then
        Changed()
    end
    return count
end

-- Several unique IDs at once, one change notice. Returns how many were queued.
function Queue.RemoveAll(uids)
    local count = 0
    for _, uid in ipairs(uids) do
        if entries[uid] then
            entries[uid] = nil
            count = count + 1
        end
    end
    if count > 0 then
        Changed()
    end
    return count
end

-- Empties the queue; returns how many writs were in it.
function Queue.Clear()
    local count = NonContiguousCount(entries)
    if count > 0 then
        ZO_ClearTable(entries)
        Changed()
    end
    return count
end

function Queue.Has(uid)
    return entries ~= nil and entries[uid] ~= nil
end

function Queue.IsOverride(uid)
    local entry = entries[uid]
    return entry ~= nil and entry.override == true
end

function Queue.HasAny()
    return next(entries) ~= nil
end

-- Queued writs as a list of { uid, writ }, in a stable order.
function Queue.List()
    local list = {}
    for uid, entry in pairs(entries) do
        local writ = WC.Master.Parse(entry.link)
        if writ then
            list[#list + 1] = { uid = uid, writ = writ }
        else
            entries[uid] = nil   -- no longer a writ we understand
        end
    end
    table.sort(list, function(a, b) return a.uid < b.uid end)
    return list
end
