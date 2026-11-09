local WC = WritCrafter

-- /wc perf: times the work behind bag and bank windows, so changes can be compared before and
-- after. Everything runs in one go, so expect a short hitch while it measures.
local Perf = {}
WC.Perf = Perf

local REPEAT = 5
local SCANNED_BAGS = { BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Average milliseconds over REPEAT runs, plus whatever the last run returned.
local function Time(fn)
    local start = GetGameTimeMilliseconds()
    local a, b
    for _ = 1, REPEAT do
        a, b = fn()
    end
    return (GetGameTimeMilliseconds() - start) / REPEAT, a, b
end

local function Ms(value)
    return string.format("%.1f", value)
end

local function ForEachSlot(fn)
    for _, bagId in ipairs(SCANNED_BAGS) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            fn(bagId, slotIndex)
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end
end

function Perf.Run()
    -- Already-crafted matching: the full scan and match after a bag change.
    local matchMs, writCount, candidateCount = Time(WC.Reservations.Rebuild)

    -- Stock scan: backpack, bank and craft bag.
    local stockMs, stacks = Time(WC.Inventory.Rescan)

    -- Writ verdicts for badges: first time in a session (no cached prices or verdicts),
    -- then cached.
    local writs = {}
    ForEachSlot(function(bagId, slotIndex)
        if GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
            local writ = WC.Master.Parse(GetItemLink(bagId, slotIndex))
            if writ then
                writs[#writs + 1] = writ
            end
        end
    end)
    local coldMs = Time(function()
        WC.Price.ClearCache()
        WC.Rules.ClearCache()
        for _, writ in ipairs(writs) do
            WC.Rules.GetStatus(writ)
        end
    end)
    local warmMs = Time(function()
        for _, writ in ipairs(writs) do
            WC.Rules.GetStatus(writ)
        end
    end)

    -- Material shortages (the yellow badge): worked out fresh, as after a bag change.
    local shortMs = Time(function()
        WC.Rules.ClearCache()
        for _, writ in ipairs(writs) do
            WC.Rules.Shortages(writ)
        end
    end)

    -- Badge decision for every bag and bank slot: what drawing every row would cost.
    local badgeMs, slots = Time(function()
        local count = 0
        ForEachSlot(function(bagId, slotIndex)
            WC.InventoryIcons.BadgeFor(bagId, slotIndex)
            count = count + 1
        end)
        return count
    end)

    -- Writ quests: reading the journal (what each station step and storage check used to do
    -- every time), then reading it again while it's remembered.
    local journalMs, conditions = Time(function()
        WC.Daily.Invalidate()
        return #WC.Daily.Conditions(true)
    end)
    local quests = #WC.Daily.Quests()
    local journalWarmMs = Time(function()
        return #WC.Daily.Conditions(true)
    end)
    local acceptedMs, accepted = Time(function()
        WC.Daily.Invalidate()
        return #WC.Master.Accepted()
    end)

    -- Storage check for every daily task (whether one is already made and in storage).
    local daily = WC.Daily.Conditions()
    local function CheckStored()
        for _, condition in ipairs(daily) do
            WC.Bank.Stored(condition)
        end
    end
    local storedMs = Time(function()
        WC.Bank.ClearStored()
        CheckStored()
    end)
    local storedWarmMs = Time(CheckStored)

    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_HEADER, REPEAT))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_MATCH, Ms(matchMs), writCount or 0, candidateCount or 0))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_STOCK, Ms(stockMs), stacks or 0))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_VERDICTS, Ms(coldMs), Ms(warmMs), #writs))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_SHORT, Ms(shortMs), #writs))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_BADGES, Ms(badgeMs), slots or 0))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_JOURNAL, Ms(journalMs), quests, conditions or 0, Ms(journalWarmMs)))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_ACCEPTED, Ms(acceptedMs), accepted or 0))
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_PERF_STORED, Ms(storedMs), Ms(storedWarmMs), #daily))
end
