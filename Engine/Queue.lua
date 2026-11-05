local WC = WritCrafter

-- Sealed master writs the player has asked WritCrafter to craft, per character, kept across
-- reloads. Each entry is keyed by the writ's unique ID and keeps its link, so the writ can be
-- decoded without finding the item. The milestone 5 queue window will build on this.
local Queue = {}
WC.Queue = Queue

local entries   -- WC.character.queue: [uid] = { link = writLink }

function Queue.Init()
    WC.character.queue = WC.character.queue or {}
    entries = WC.character.queue
end

function Queue.Add(uid, link)
    entries[uid] = { link = link }
end

function Queue.Remove(uid)
    entries[uid] = nil
end

function Queue.Has(uid)
    return entries[uid] ~= nil
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
