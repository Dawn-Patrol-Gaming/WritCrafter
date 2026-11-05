local WC = WritCrafter

-- Provisioning: one call crafts as many batches as the writ still needs (the game's
-- multi-craft), capped by what the station can make from your craft bag, backpack and bank;
-- the game's own reason is shown when nothing can be made.
local function CraftProvisioning(writ, status)
    local _, listIndex, recipeIndex = GetRecipeInfoFromItemId(writ.resultId)
    if not (listIndex and recipeIndex) then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.resultId)
    end
    local resultLink = GetRecipeResultItemLink(listIndex, recipeIndex)
    if not WC.Reservations.Matches(resultLink, writ) then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end
    local remaining = status.required - status.have
    local perCraft = zo_max(GetRecipeResultQuantity(listIndex, recipeIndex, 1) or 1, 1)
    local maxIterations, result = GetMaxIterationsPossibleForRecipe(listIndex, recipeIndex)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local iterations = zo_min(zo_ceil(remaining / perCraft), maxIterations)
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CRAFTING, iterations * perCraft, GetItemLinkName(resultLink)))
    CraftProvisionerItem(listIndex, recipeIndex, iterations)
    return true
end

WC.Engine.RegisterCrafter(WC.Master.KIND_PROVISIONING, CraftProvisioning)
