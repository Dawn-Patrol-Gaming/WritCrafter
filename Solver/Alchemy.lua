local WC = WritCrafter

local Solver = {}
WC.AlchemySolver = Solver

-- [effect key] = list of { r1, r2, r3 } reagent triples whose result has every effect.
-- Depends only on game data, so it's computed once per effect combination.
local combosByKey = {}

local function EffectKey(effects)
    local sorted = { unpack(effects) }
    table.sort(sorted)
    return table.concat(sorted, ",")
end

-- [itemId] = { [effect] = true }, built once, for the quick pre-check below.
local hasEffect

local function AllCombos(effects)
    local key = EffectKey(effects)
    local combos = combosByKey[key]
    if combos then
        return combos
    end
    combos = {}
    local REAGENTS = WC.Data.Alchemy.REAGENTS
    if not hasEffect then
        hasEffect = {}
        for itemId, reagent in pairs(REAGENTS) do
            local set = {}
            for _, effect in ipairs(reagent.effects) do
                set[effect] = true
            end
            hasEffect[itemId] = set
        end
    end
    local ids = {}
    for itemId in pairs(REAGENTS) do
        ids[#ids + 1] = itemId
    end
    table.sort(ids)
    local Combine = WC.Data.Alchemy.Combine
    -- Quick pre-check before the full combine: each wanted effect needs at least two of the
    -- three reagents to carry it (counter-effects can only take it away). That rules out
    -- nearly all of the 8,436 triples with a few table lookups each.
    local function Possible(ha, hb, hc)
        for _, effect in ipairs(effects) do
            local n = (ha[effect] and 1 or 0) + (hb[effect] and 1 or 0) + (hc[effect] and 1 or 0)
            if n < 2 then
                return false
            end
        end
        return true
    end
    for a = 1, #ids - 2 do
        local ha = hasEffect[ids[a]]
        for b = a + 1, #ids - 1 do
            local hb = hasEffect[ids[b]]
            for c = b + 1, #ids do
                if Possible(ha, hb, hasEffect[ids[c]]) then
                    local result = Combine(ids[a], ids[b], ids[c])
                    local ok = true
                    for _, effect in ipairs(effects) do
                        if not result[effect] then
                            ok = false
                            break
                        end
                    end
                    if ok then
                        combos[#combos + 1] = { ids[a], ids[b], ids[c] }
                    end
                end
            end
        end
    end
    combosByKey[key] = combos
    return combos
end

local function ComboPrice(combo)
    local total = 0
    for _, itemId in ipairs(combo) do
        total = total + (WC.Price.GetById(itemId) or 0)
    end
    return total
end

-- Picks the combination for a set of effects.
-- Returns:
--   best:        allowed combo with the most stock (lowest stock of its three reagents is
--                highest), cheaper first on ties; nil when none is allowed
--   blocked:     when best is nil, the possible combo needing the fewest disallowed reagents
--   disallowed:  the disallowed reagents in that blocked combo
--   anyPossible: whether any combination makes these effects at all
function Solver.Choose(effects)
    local combos = AllCombos(effects)
    if #combos == 0 then
        return nil, nil, nil, false
    end
    local Policy, Inventory = WC.Policy, WC.Inventory
    local allowed, stock = {}, {}
    for itemId in pairs(WC.Data.Alchemy.REAGENTS) do
        allowed[itemId] = Policy.IsReagentAllowed(itemId)
        stock[itemId] = Inventory.GetStock(itemId).usable
    end
    -- Prices are only looked up to break ties.
    local best, bestStock, bestPrice
    local blocked, blockedCount, blockedPrice, blockedList
    for _, combo in ipairs(combos) do
        local disallowed = {}
        local minStock = math.huge
        for _, itemId in ipairs(combo) do
            if not allowed[itemId] then
                disallowed[#disallowed + 1] = itemId
            end
            minStock = zo_min(minStock, stock[itemId])
        end
        if #disallowed == 0 then
            if not best or minStock > bestStock then
                best, bestStock, bestPrice = combo, minStock, nil
            elseif minStock == bestStock then
                bestPrice = bestPrice or ComboPrice(best)
                local price = ComboPrice(combo)
                if price < bestPrice then
                    best, bestPrice = combo, price
                end
            end
        elseif not best then
            if not blocked or #disallowed < blockedCount then
                blocked, blockedCount, blockedPrice, blockedList = combo, #disallowed, nil, disallowed
            elseif #disallowed == blockedCount then
                blockedPrice = blockedPrice or ComboPrice(blocked)
                local price = ComboPrice(combo)
                if price < blockedPrice then
                    blocked, blockedPrice, blockedList = combo, price, disallowed
                end
            end
        end
    end
    if best then
        return best, nil, nil, true
    end
    return nil, blocked, blockedList, true
end

-- For badges: whether any combination makes these effects, and whether any of those uses only
-- allowed reagents. No stock or prices needed.
function Solver.AnyAllowed(effects)
    local combos = AllCombos(effects)
    if #combos == 0 then
        return false, false
    end
    local Policy = WC.Policy
    for _, combo in ipairs(combos) do
        if Policy.IsReagentAllowed(combo[1]) and Policy.IsReagentAllowed(combo[2])
            and Policy.IsReagentAllowed(combo[3]) then
            return true, true
        end
    end
    return true, false
end
