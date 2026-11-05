local WC = WritCrafter

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

-- Enchanting: the writ's potency rune (additive or subtractive for its level), essence rune
-- and aspect rune (from the quality). One glyph per batch. The resulting glyph is checked
-- against the writ before anything is spent, and runes you haven't translated yet are crafted
-- one batch at a time (the game's rule; the first craft translates them).
local function CraftEnchanting(writ, status)
    local glyph, level = writ.glyph, writ.level
    local aspect = WC.Data.Enchanting.ASPECTS[writ.quality]
    if not (glyph and level and aspect) then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.glyphId or 0)
    end
    local potency = glyph.additive and level.additive or level.subtractive
    local slots = {}
    for _, itemId in ipairs({ potency, glyph.essence, aspect }) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if not bagId then
            return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(itemId))
        end
        slots[#slots + 1] = bagId
        slots[#slots + 1] = slotIndex
    end
    local pBag, pSlot, eBag, eSlot, aBag, aSlot = unpack(slots)

    local resultLink = GetEnchantingResultingItemLink(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    if not resultLink or resultLink == "" or not WC.Reservations.Matches(resultLink, writ) then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end

    local iterations = status.required - status.have
    local maxIterations, result = GetMaxIterationsPossibleForEnchantingItem(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    iterations = zo_min(iterations, maxIterations)
    if not AreAllEnchantingRunesKnown(pBag, pSlot, eBag, eSlot, aBag, aSlot) then
        iterations = 1
    end

    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CRAFTING, iterations, GetItemLinkName(resultLink)))
    CraftEnchantingItem(pBag, pSlot, eBag, eSlot, aBag, aSlot, iterations)
    return true
end

WC.Engine.RegisterCrafter(WC.Master.KIND_ENCHANTING, CraftEnchanting)
