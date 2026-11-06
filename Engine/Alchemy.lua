local WC = WritCrafter

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

local function StationStock(itemId)
    local _, _, total = WC.Inventory.FindForStation(itemId)
    return total
end

-- Alchemy: the writ's solvent plus the allowed three-reagent combination you have the most of
-- at the station. The resulting potion is checked against the writ before anything is spent.
-- The game only multi-crafts potions whose effects you already know; otherwise it's one batch
-- (which teaches them) and the engine comes back for the rest.
local function CraftAlchemy(writ, status)
    if not writ.solvent then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, 0)
    end
    local solventBag, solventSlot = WC.Inventory.FindForStation(writ.solvent.itemId)
    if not solventBag then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(writ.solvent.itemId))
    end
    local combo = WC.AlchemySolver.Choose(writ.effects, StationStock)
    if not combo then
        return false, GetString(SI_WRITCRAFTER_REASON_NO_COMBO)
    end
    local slots = {}
    for _, itemId in ipairs(combo) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if not bagId then
            return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(itemId))
        end
        slots[#slots + 1] = bagId
        slots[#slots + 1] = slotIndex
    end
    local r1Bag, r1Slot, r2Bag, r2Slot, r3Bag, r3Slot = unpack(slots)

    local resultLink, prospective = GetAlchemyResultingItemLink(solventBag, solventSlot,
        r1Bag, r1Slot, r2Bag, r2Slot, r3Bag, r3Slot)
    if not resultLink or resultLink == "" or not WC.Reservations.Matches(resultLink, writ) then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end

    local perCraft = zo_max(GetAlchemyResultQuantity(solventBag, solventSlot, 1) or 1, 1)
    local iterations = zo_ceil((status.required - status.have) / perCraft)
    local maxIterations, result = GetMaxIterationsPossibleForAlchemyItem(solventBag, solventSlot,
        r1Bag, r1Slot, r2Bag, r2Slot, r3Bag, r3Slot)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    iterations = zo_min(iterations, maxIterations)
    if prospective ~= PROSPECTIVE_ALCHEMY_RESULT_KNOWN then
        iterations = 1
    end

    local materials = { { itemId = writ.solvent.itemId, count = iterations } }
    for _, itemId in ipairs(combo) do
        materials[#materials + 1] = { itemId = itemId, count = iterations }
    end
    WC.Engine.SayCrafting(iterations * perCraft, resultLink, materials)
    WC.Engine.CraftSounds({ SOUNDS.ALCHEMY_SOLVENT_PLACED, SOUNDS.ALCHEMY_REAGENT_PLACED,
        SOUNDS.ALCHEMY_REAGENT_PLACED, SOUNDS.ALCHEMY_REAGENT_PLACED }, SOUNDS.ALCHEMY_CREATE_TOOLTIP_GLOW_SUCCESS)
    CraftAlchemyItem(solventBag, solventSlot, r1Bag, r1Slot, r2Bag, r2Slot, r3Bag, r3Slot, iterations)
    return true
end

WC.Engine.RegisterCrafter(WC.Master.KIND_ALCHEMY, CraftAlchemy)

-- Daily alchemy writs -------------------------------------------------------------------------
-- Two kinds of condition: craft a potion or poison (any solvent and reagents that make it), and
-- acquire a reagent (have it in the backpack). The game says which candidate fulfils each.

local REAGENTS = WC.Data.Alchemy.REAGENTS
local SOLVENT_TYPES = { [ITEMTYPE_POTION_BASE] = true, [ITEMTYPE_POISON_BASE] = true }
local SOLVENT_BAGS = { BAG_VIRTUAL, BAG_BACKPACK, BAG_BANK, BAG_SUBSCRIBER_BANK }

-- Solvent item IDs you own anywhere a station can use.
local function OwnedSolvents()
    local ids, seen = {}, {}
    for _, bagId in ipairs(SOLVENT_BAGS) do
        local slotIndex = ZO_GetNextBagSlotIndex(bagId)
        while slotIndex do
            if SOLVENT_TYPES[GetItemType(bagId, slotIndex)] then
                local itemId = GetItemId(bagId, slotIndex)
                if not seen[itemId] then
                    seen[itemId] = true
                    ids[#ids + 1] = itemId
                end
            end
            slotIndex = ZO_GetNextBagSlotIndex(bagId, slotIndex)
        end
    end
    return ids
end

-- Where each item is right now (bag, slot), looked up once per search.
local function Locations(itemIds)
    local where = {}
    for _, itemId in ipairs(itemIds) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if bagId then
            where[itemId] = { bagId, slotIndex }
        end
    end
    return where
end

-- Bag/slot arguments for a solvent and reagents from a location table, or nil.
local function Args(where, solventId, reagents)
    local args = {}
    for _, itemId in ipairs({ solventId, unpack(reagents) }) do
        local loc = where[itemId]
        if not loc then
            return nil
        end
        args[#args + 1] = loc[1]
        args[#args + 1] = loc[2]
    end
    return args
end

-- Pairs of the given reagents that both carry an effect (and so produce it), by effect.
local function PairsByEffect(reagents)
    local byEffect = {}
    for i = 1, #reagents - 1 do
        for j = i + 1, #reagents do
            local a, b = reagents[i], reagents[j]
            for _, ea in ipairs(REAGENTS[a].effects) do
                for _, eb in ipairs(REAGENTS[b].effects) do
                    if ea == eb then
                        byEffect[ea] = byEffect[ea] or {}
                        table.insert(byEffect[ea], { a, b })
                    end
                end
            end
        end
    end
    return byEffect
end

-- Effects both reagents of a pair carry.
local function SharedEffects(pair)
    local shared = {}
    for _, ea in ipairs(REAGENTS[pair[1]].effects) do
        for _, eb in ipairs(REAGENTS[pair[2]].effects) do
            if ea == eb then
                shared[#shared + 1] = ea
            end
        end
    end
    return shared
end

-- Every pair of the given reagents that shares any of these effects, each pair once.
local function PairsForEffects(reagents, effects)
    local byEffect = PairsByEffect(reagents)
    local list, seen = {}, {}
    for _, effect in ipairs(effects) do
        for _, pair in ipairs(byEffect[effect] or {}) do
            local key = pair[1] .. ":" .. pair[2]
            if not seen[key] then
                seen[key] = true
                list[#list + 1] = pair
            end
        end
    end
    return list
end

local function OwnedReagents()
    local owned = {}
    for itemId in pairs(REAGENTS) do
        if StationStock(itemId) > 0 then
            owned[#owned + 1] = itemId
        end
    end
    table.sort(owned)
    return owned
end

local function ResolveDaily(condition)
    -- Acquire a reagent?
    for itemId in pairs(REAGENTS) do
        if WC.Daily.Fulfils(WC.Inventory.GetLink(itemId), condition) then
            return { acquire = itemId }
        end
    end
    -- Craft a potion or poison: one test per effect and owned solvent, using any owned pair
    -- that makes the effect. The pair actually used is chosen at craft time.
    local owned = OwnedReagents()
    local solvents = OwnedSolvents()
    local all = {}
    for _, id in ipairs(owned) do all[#all + 1] = id end
    for _, id in ipairs(solvents) do all[#all + 1] = id end
    local where = Locations(all)
    for effect, effectPairs in pairs(PairsByEffect(owned)) do
        for _, solventId in ipairs(solvents) do
            local args = Args(where, solventId, effectPairs[1])
            if args and WC.Daily.Fulfils(GetAlchemyResultingItemLink(unpack(args)), condition) then
                -- Remember every effect the working pair shares: the potion's defining
                -- effect may be any of them, so other pairs are searched by all of them.
                return { solvent = solventId, effects = SharedEffects(effectPairs[1]) }
            end
        end
    end
    -- Nothing you have makes it. Report it, but only for an alchemy quest's condition: other
    -- crafts' conditions are none of this station's business.
    if WC.Daily.IsAlchemyQuest(condition) then
        if #solvents == 0 then
            return { problem = GetString(SI_WRITCRAFTER_DAILY_NO_SOLVENT) }
        end
        return { problem = GetString(SI_WRITCRAFTER_DAILY_NO_POTION) }
    end
end

local function MoveToBackpack(itemId, quantity)
    local count = GetSlotStackSize(BAG_VIRTUAL, itemId) or 0
    if count == 0 then
        return false
    end
    local emptySlot = FindFirstEmptySlotInBag(BAG_BACKPACK)
    if not emptySlot then
        return false, GetString(SI_WRITCRAFTER_CRAFT_BACKPACK_FULL)
    end
    quantity = zo_min(quantity, count)
    if IsProtectedFunction("RequestMoveItem") then
        CallSecureProtected("RequestMoveItem", BAG_VIRTUAL, itemId, BAG_BACKPACK, emptySlot, quantity)
    else
        RequestMoveItem(BAG_VIRTUAL, itemId, BAG_BACKPACK, emptySlot, quantity)
    end
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_MOVING, quantity, ItemName(itemId)))
    return true
end

local function CraftDaily(condition, plan)
    local remaining = condition.max - condition.current
    if plan.acquire then
        local itemId = plan.acquire
        if not WC.Policy.IsReagentAllowed(itemId) then
            return false, zo_strformat(SI_WRITCRAFTER_CRAFT_EXCLUDED_REAGENT, ItemName(itemId))
        end
        local moved, reason = MoveToBackpack(itemId, remaining)
        if moved then
            return "moved"
        end
        return false, reason or zo_strformat(SI_WRITCRAFTER_CRAFT_WITHDRAW, ItemName(itemId))
    end

    -- Allowed pairs that make the effect, most stock first; the first whose result the game
    -- accepts for this condition is used.
    local owned = OwnedReagents()
    local allowed = {}
    for _, itemId in ipairs(owned) do
        if WC.Policy.IsReagentAllowed(itemId) then
            allowed[#allowed + 1] = itemId
        end
    end
    local where = Locations({ plan.solvent, unpack(owned) })
    if not where[plan.solvent] then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(plan.solvent))
    end
    -- What a pair would make, and whether the game accepts it for this condition. With chat
    -- messages on Debug, every pair tried is printed, to show why a reagent isn't used.
    local function TestPair(pair)
        local candidate = Args(where, plan.solvent, pair)
        if not candidate then
            return nil
        end
        local link, known = GetAlchemyResultingItemLink(unpack(candidate))
        local fits = WC.Daily.Fulfils(link, condition) and true or false
        if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
            WC.Log.Debug(string.format("Alchemy daily: %s + %s -> %s%s: %s", ItemName(pair[1]), ItemName(pair[2]),
                (link and link ~= "") and zo_strformat("<<t:1>>", GetItemLinkName(link)) or "no result",
                known == PROSPECTIVE_ALCHEMY_RESULT_KNOWN and "" or " (undiscovered traits)",
                fits and "fits the writ" or "doesn't fit"))
        end
        return candidate, link, known, fits
    end

    -- The first pair (most stock first) whose result the game accepts for this condition.
    local function FirstFulfilling(reagents)
        local effectPairs = PairsForEffects(reagents, plan.effects)
        table.sort(effectPairs, function(x, y)
            return zo_min(StationStock(x[1]), StationStock(x[2])) > zo_min(StationStock(y[1]), StationStock(y[2]))
        end)
        for _, pair in ipairs(effectPairs) do
            local candidate, link, known, fits = TestPair(pair)
            if fits then
                return candidate, link, known, pair
            end
        end
    end
    local args, resultLink, prospective, usedPair = FirstFulfilling(allowed)
    if not args then
        -- Would excluded reagents have done it? List every option, so you can pick which to
        -- allow: "A or B", or "A + B" when a pair needs both.
        local options, seen = {}, {}
        for _, pair in ipairs(PairsForEffects(owned, plan.effects)) do
            local excluded = {}
            for _, itemId in ipairs(pair) do
                if not WC.Policy.IsReagentAllowed(itemId) then
                    excluded[#excluded + 1] = ItemName(itemId)
                end
            end
            local option = table.concat(excluded, " + ")
            if #excluded > 0 and not seen[option] then
                local _, _, _, fits = TestPair(pair)
                if fits then
                    seen[option] = true
                    options[#options + 1] = option
                end
            end
        end
        if #options > 0 then
            -- At most a handful in chat; the rest as a count.
            local MAX_SHOWN = 5
            local shown = {}
            for i = 1, zo_min(#options, MAX_SHOWN) do
                shown[i] = options[i]
            end
            local text = table.concat(shown, GetString(SI_WRITCRAFTER_OR))
            if #options > MAX_SHOWN then
                text = text .. zo_strformat(SI_WRITCRAFTER_AND_MORE, #options - MAX_SHOWN)
            end
            return false, zo_strformat(SI_WRITCRAFTER_REASON_REAGENTS, text)
        end
        return false, GetString(SI_WRITCRAFTER_CRAFT_NO_REAGENTS)
    end
    local perCraft = zo_max(GetAlchemyResultQuantity(args[1], args[2], 1) or 1, 1)
    local maxIterations, result = GetMaxIterationsPossibleForAlchemyItem(unpack(args))
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local iterations = zo_min(zo_ceil(remaining / perCraft), maxIterations)
    if prospective ~= PROSPECTIVE_ALCHEMY_RESULT_KNOWN then
        iterations = 1
    end
    WC.Engine.SayCrafting(iterations * perCraft, resultLink, {
        { itemId = plan.solvent, count = iterations },
        { itemId = usedPair[1], count = iterations },
        { itemId = usedPair[2], count = iterations },
    })
    -- Like the game's own UI: only the slotted reagents' bag/slot pairs, then the batch count.
    args[#args + 1] = iterations
    WC.Engine.CraftSounds({ SOUNDS.ALCHEMY_SOLVENT_PLACED, SOUNDS.ALCHEMY_REAGENT_PLACED,
        SOUNDS.ALCHEMY_REAGENT_PLACED }, SOUNDS.ALCHEMY_CREATE_TOOLTIP_GLOW_SUCCESS)
    CraftAlchemyItem(unpack(args, 1, #args))
    return true
end

WC.Daily.RegisterCraft(CRAFTING_TYPE_ALCHEMY, ResolveDaily, CraftDaily)
