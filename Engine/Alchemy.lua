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

    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CRAFTING, iterations * perCraft, GetItemLinkName(resultLink)))
    CraftAlchemyItem(solventBag, solventSlot, r1Bag, r1Slot, r2Bag, r2Slot, r3Bag, r3Slot, iterations)
    return true
end

WC.Engine.RegisterCrafter(WC.Master.KIND_ALCHEMY, CraftAlchemy)
