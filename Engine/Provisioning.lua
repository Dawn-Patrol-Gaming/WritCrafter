local WC = WritCrafter

-- Provisioning: one call crafts as many batches as still needed (the game's multi-craft),
-- capped by what the station can make from your craft bag, backpack and bank; the game's own
-- reason is shown when nothing can be made. Batches come from this character's real yield.
local function CraftRecipe(listIndex, recipeIndex, remaining)
    local known = GetRecipeInfo(listIndex, recipeIndex)
    if not known then
        return false, GetString(SI_WRITCRAFTER_REASON_RECIPE_UNKNOWN)
    end
    local perCraft = zo_max(GetRecipeResultQuantity(listIndex, recipeIndex, 1) or 1, 1)
    local maxIterations, result = GetMaxIterationsPossibleForRecipe(listIndex, recipeIndex)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local iterations = zo_min(zo_ceil(remaining / perCraft), maxIterations)
    local _, _, numIngredients = GetRecipeInfo(listIndex, recipeIndex)
    local materials = {}
    for ingredientIndex = 1, numIngredients or 0 do
        local _, _, perRecipe = GetRecipeIngredientItemInfo(listIndex, recipeIndex, ingredientIndex)
        local link = GetRecipeIngredientItemLink(listIndex, recipeIndex, ingredientIndex)
        materials[#materials + 1] = { itemId = GetItemLinkItemId(link), count = (perRecipe or 1) * iterations }
    end
    WC.Engine.SayCrafting(iterations * perCraft, GetRecipeResultItemLink(listIndex, recipeIndex), materials, remaining)
    WC.Engine.CraftSounds(nil, nil)
    CraftProvisionerItem(listIndex, recipeIndex, iterations)
    return true
end

-- Master writs: the writ names the dish; its result is checked against the writ first.
local function CraftMaster(writ, status)
    local _, listIndex, recipeIndex = GetRecipeInfoFromItemId(writ.resultId)
    if not (listIndex and recipeIndex) then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.resultId)
    end
    if not WC.Reservations.Matches(GetRecipeResultItemLink(listIndex, recipeIndex), writ) then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end
    return CraftRecipe(listIndex, recipeIndex, status.required - status.have)
end

WC.Engine.RegisterCrafter(WC.Master.KIND_PROVISIONING, CraftMaster)

-- Daily writs: the recipe whose result the game says fulfils the condition.
local function ResolveDaily(condition)
    for listIndex = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(listIndex)
        for recipeIndex = 1, numRecipes or 0 do
            local _, _, _, _, _, _, station = GetRecipeInfo(listIndex, recipeIndex)
            if station == CRAFTING_TYPE_PROVISIONING
                and WC.Daily.Fulfils(GetRecipeResultItemLink(listIndex, recipeIndex), condition) then
                return { listIndex = listIndex, recipeIndex = recipeIndex }
            end
        end
    end
end

local function CraftDaily(condition, plan)
    return CraftRecipe(plan.listIndex, plan.recipeIndex, condition.max - condition.current)
end

WC.Daily.RegisterCraft(CRAFTING_TYPE_PROVISIONING, ResolveDaily, CraftDaily)
