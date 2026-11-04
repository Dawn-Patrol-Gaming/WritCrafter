local WC = WritCrafter

local Rules = {}
WC.Rules = Rules

-- Verdicts, worst first.
Rules.CANNOT   = "cannot"     -- can't be crafted by this character (knowledge, unknown data, game bug)
Rules.REJECTED = "rejected"   -- could be crafted, but your settings say no
Rules.OK       = "ok"

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

local function NameList(itemIds)
    local names = {}
    for _, itemId in ipairs(itemIds) do
        names[#names + 1] = ItemName(itemId)
    end
    return table.concat(names, ", ")
end

local function NewVerdict(writ)
    return { writ = writ, status = Rules.OK, reasons = {}, notes = {}, materials = {} }
end

local function Fail(verdict, status, stringId, ...)
    if status == Rules.CANNOT or verdict.status == Rules.OK then
        verdict.status = status
    end
    verdict.reasons[#verdict.reasons + 1] = zo_strformat(stringId, ...)
end

local function Note(verdict, stringId, ...)
    verdict.notes[#verdict.notes + 1] = zo_strformat(stringId, ...)
end

local function AddMaterial(verdict, itemId, count)
    if itemId and itemId ~= 0 and count > 0 then
        verdict.materials[#verdict.materials + 1] = { itemId = itemId, count = count }
    end
end

local function CheckExpensive(verdict, itemId)
    if WC.Policy.IsExpensive(itemId) then
        Fail(verdict, Rules.REJECTED, SI_WRITCRAFTER_REASON_EXPENSIVE, ItemName(itemId))
    end
end

local function CheckGold(verdict, writ)
    if writ.quality == ITEM_FUNCTIONAL_QUALITY_LEGENDARY and WC.Policy.IsGoldExcluded(writ.craft) then
        Fail(verdict, Rules.REJECTED, SI_WRITCRAFTER_REASON_GOLD, GetCraftingSkillName(writ.craft))
    end
end

local function EvaluateSmithing(verdict, writ, statusOnly)
    local t = writ.template
    if not t then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.templateId)
        return
    end
    CheckGold(verdict, writ)

    -- Trait: the material, and whether this character has researched it on this item line.
    local traitLink = GetSmithingTraitItemLink(writ.trait + 1)
    local traitItemId = GetItemLinkItemId(traitLink)
    local lineName = GetSmithingResearchLineInfo(t.craft, t.line)
    local knownCount, traitKnown = 0, false
    for traitIndex = 1, 9 do
        local traitType, _, known = GetSmithingResearchLineTraitInfo(t.craft, t.line, traitIndex)
        if known then
            knownCount = knownCount + 1
        end
        if traitType == writ.trait then
            traitKnown = known
        end
    end
    if writ.trait ~= ITEM_TRAIT_TYPE_NONE then
        if not traitKnown then
            Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_TRAIT_UNKNOWN,
                GetString("SI_ITEMTRAITTYPE", writ.trait), lineName)
        end
        CheckExpensive(verdict, traitItemId)
    end

    -- Set: enough traits researched on this line.
    local setName = zo_strformat("<<1>>", GetItemSetName(writ.setId))
    local needed = LibSets.GetTraitsNeeded(writ.setId)
    if needed and knownCount < needed then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_SET_TRAITS, needed, setName, knownCount)
    end

    -- Motif: must be known. A mimic stone only replaces the style material of a known style.
    local useMimic = false
    local styleItemId
    if t.chapter then
        local LCK = LibCharacterKnowledge
        local motifKnown = LCK.GetMotifKnowledgeForCharacter(writ.style, t.chapter) == LCK.KNOWLEDGE_KNOWN
        styleItemId = GetItemLinkItemId(GetItemStyleMaterialLink(writ.style))
        local styleName = zo_strformat("<<1>>", GetItemStyleName(writ.style))
        if not motifKnown then
            Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_MOTIF_UNKNOWN, styleName)
        else
            useMimic = WC.Policy.UseMimic(styleItemId, statusOnly)
        end
        if useMimic then
            Note(verdict, SI_WRITCRAFTER_NOTE_MIMIC, ItemName(styleItemId))
        else
            CheckExpensive(verdict, styleItemId)
        end
    end

    AddMaterial(verdict, t.mat, t.count)
    if writ.trait ~= ITEM_TRAIT_TYPE_NONE then
        AddMaterial(verdict, traitItemId, 1)
    end
    if useMimic then
        AddMaterial(verdict, WC.Policy.MIMIC_STONE_ID, 1)
        verdict.materials[#verdict.materials].unpriced = true   -- a Crown Store item, not traded
    elseif styleItemId then
        AddMaterial(verdict, styleItemId, 1)
    end
    for _, mat in ipairs(WC.Data.Smithing.ImprovementMaterials(t.craft, writ.quality)) do
        AddMaterial(verdict, mat.itemId, mat.count)
    end
    verdict.setName = setName
end

local function EvaluateEnchanting(verdict, writ)
    if not (writ.glyph and writ.level and WC.Data.Enchanting.ASPECTS[writ.quality]) then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.glyphId)
        return
    end
    CheckGold(verdict, writ)
    local potency = writ.glyph.additive and writ.level.additive or writ.level.subtractive
    local aspect = WC.Data.Enchanting.ASPECTS[writ.quality]
    for _, itemId in ipairs({ potency, writ.glyph.essence, aspect }) do
        CheckExpensive(verdict, itemId)
        AddMaterial(verdict, itemId, 1)
    end
end

local function EvaluateAlchemy(verdict, writ, statusOnly)
    local Alchemy = WC.Data.Alchemy
    if not writ.solvent then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, 0)
        return
    end
    local impossible = true
    for _, effect in ipairs(writ.effects) do
        if not Alchemy.IMPOSSIBLE[effect] then
            impossible = false
        end
    end
    if impossible then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_GAME_BUG)
        return
    end
    if statusOnly then
        -- Badges only need to know whether an allowed combination exists.
        local anyPossible, anyAllowed = WC.AlchemySolver.AnyAllowed(writ.effects)
        if not anyPossible then
            Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_NO_COMBO)
        elseif not anyAllowed then
            Fail(verdict, Rules.REJECTED, SI_WRITCRAFTER_REASON_REAGENTS, "")
        end
        return
    end
    local best, blocked, disallowed, anyPossible = WC.AlchemySolver.Choose(writ.effects)
    if not anyPossible then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_NO_COMBO)
        return
    end
    local crafts = writ.solvent.crafts
    local combo = best or blocked
    if not best then
        Fail(verdict, Rules.REJECTED, SI_WRITCRAFTER_REASON_REAGENTS, NameList(disallowed))
    end
    AddMaterial(verdict, writ.solvent.itemId, crafts)
    for _, itemId in ipairs(combo) do
        AddMaterial(verdict, itemId, crafts)
    end
    verdict.combo = combo
end

local function EvaluateProvisioning(verdict, writ)
    local _, listIndex, recipeIndex = GetRecipeInfoFromItemId(writ.resultId)
    if not (listIndex and recipeIndex) then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.resultId)
        return
    end
    local known, _, numIngredients = GetRecipeInfo(listIndex, recipeIndex)
    if not known then
        Fail(verdict, Rules.CANNOT, SI_WRITCRAFTER_REASON_RECIPE_UNKNOWN)
    end
    local perCraft = zo_max(GetRecipeResultQuantity(listIndex, recipeIndex) or 1, 1)
    local crafts = zo_ceil(writ.required / perCraft)
    for ingredientIndex = 1, numIngredients or 0 do
        local _, _, perRecipe = GetRecipeIngredientItemInfo(listIndex, recipeIndex, ingredientIndex)
        local itemId = GetItemLinkItemId(GetRecipeIngredientItemLink(listIndex, recipeIndex, ingredientIndex))
        CheckExpensive(verdict, itemId)
        AddMaterial(verdict, itemId, (perRecipe or 1) * crafts)
    end
end

local EVALUATORS = {
    [WC.Master.KIND_SMITHING]     = EvaluateSmithing,
    [WC.Master.KIND_ENCHANTING]   = EvaluateEnchanting,
    [WC.Master.KIND_ALCHEMY]      = EvaluateAlchemy,
    [WC.Master.KIND_PROVISIONING] = EvaluateProvisioning,
}

-- Status-only cache for inventory icons, which redraw constantly while scrolling. A status
-- depends on settings and character knowledge, not stock, so it's cleared on those changes.
local statusCache = {}

function Rules.ClearCache()
    ZO_ClearTable(statusCache)
end

function Rules.GetStatus(writ)
    local status = statusCache[writ.link]
    if not status then
        status = Rules.Evaluate(writ, true).status
        statusCache[writ.link] = status
    end
    return status
end

function Rules.Init()
    local namespace = WC.name .. "Rules"
    for _, event in ipairs({
        EVENT_SMITHING_TRAIT_RESEARCH_COMPLETED,
        EVENT_STYLE_LEARNED,
        EVENT_RECIPE_LEARNED,
    }) do
        EVENT_MANAGER:RegisterForEvent(namespace, event, Rules.ClearCache)
    end
end

-- Full verdict for one sealed master writ: status, reasons, notes, materials and cost.
-- statusOnly (badges): skips what only the tooltip shows (prices, stock, the full alchemy
-- solve). When the max gold per voucher rule is on, the status depends on the cost, so the
-- full verdict runs instead.
function Rules.Evaluate(writ, statusOnly)
    local verdict = NewVerdict(writ)
    local ceiling = WC.settings.maxGoldPerVoucher
    local light = statusOnly and ceiling <= 0
    EVALUATORS[writ.kind](verdict, writ, light)
    if light then
        verdict.cost, verdict.costComplete = 0, false
        return verdict
    end

    local cost, priced = 0, true
    for _, mat in ipairs(verdict.materials) do
        if not mat.unpriced then
            local gold = WC.Price.GetById(mat.itemId)
            if gold then
                cost = cost + gold * mat.count
            else
                priced = false
            end
        end
    end
    verdict.cost = cost
    verdict.costComplete = priced
    if writ.vouchers > 0 then
        verdict.perVoucher = cost / writ.vouchers
        if ceiling > 0 and verdict.perVoucher > ceiling then
            Fail(verdict, Rules.REJECTED, SI_WRITCRAFTER_REASON_PER_VOUCHER, WC.Price.Format(ceiling))
        end
    end
    return verdict
end
