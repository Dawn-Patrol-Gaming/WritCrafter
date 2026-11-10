local WC = WritCrafter

-- Smithing (blacksmithing, clothing, woodworking, jewelry): a gear writ takes several crafts,
-- one per engine step:
--   1. create the white piece: at a Grand Master station first switch to the writ's set, then
--      find the pattern and CP150 material whose predicted result is exactly the writ's piece
--      (set, trait, style, weight, robe or jerkin), with the style material or a mimic stone;
--   2. improve it one quality tier per step until it matches the writ, only ever at a 100%
--      chance.
-- Everything is checked against the writ before anything is spent.

local CREATE_GLOW = {
    [CRAFTING_TYPE_BLACKSMITHING]   = SOUNDS.BLACKSMITH_CREATE_TOOLTIP_GLOW,
    [CRAFTING_TYPE_CLOTHIER]        = SOUNDS.CLOTHIER_CREATE_TOOLTIP_GLOW,
    [CRAFTING_TYPE_WOODWORKING]     = SOUNDS.WOODWORKER_CREATE_TOOLTIP_GLOW,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = SOUNDS.JEWELRYCRAFTER_CREATE_TOOLTIP_GLOW,
}
local IMPROVE_GLOW = {
    [CRAFTING_TYPE_BLACKSMITHING]   = SOUNDS.BLACKSMITH_IMPROVE_TOOLTIP_GLOW_SUCCESS,
    [CRAFTING_TYPE_CLOTHIER]        = SOUNDS.CLOTHIER_IMPROVE_TOOLTIP_GLOW_SUCCESS,
    [CRAFTING_TYPE_WOODWORKING]     = SOUNDS.WOODWORKER_IMPROVE_TOOLTIP_GLOW_SUCCESS,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = SOUNDS.JEWELRYCRAFTER_IMPROVE_TOOLTIP_GLOW_SUCCESS,
}

local function ItemName(link)
    return zo_strformat("<<t:1>>", GetItemLinkName(link))
end

-- The writ's piece below the writ's quality, crafted, in the backpack, not locked or
-- FCO ItemSaver-marked and not already set aside for another writ: the piece to improve.
-- Returns bag, slot, quality (the highest-quality such piece).
local function FindBasePiece(writ)
    local bestSlot, bestQuality
    local slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK)
    while slotIndex do
        local itemType = GetItemType(BAG_BACKPACK, slotIndex)
        if (itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR)
            and not IsItemPlayerLocked(BAG_BACKPACK, slotIndex) then
            local link = GetItemLink(BAG_BACKPACK, slotIndex)
            local quality = GetItemLinkFunctionalQuality(link)
            if quality < writ.quality and WC.Reservations.MatchesBase(link, writ, false)
                and not WC.Inventory.IsProtected(BAG_BACKPACK, slotIndex)
                and WC.Reservations.GetReserved(BAG_BACKPACK, slotIndex) == 0
                and (not bestQuality or quality > bestQuality) then
                bestSlot, bestQuality = slotIndex, quality
            end
        end
        slotIndex = ZO_GetNextBagSlotIndex(BAG_BACKPACK, slotIndex)
    end
    if bestSlot then
        return BAG_BACKPACK, bestSlot, bestQuality
    end
end

-- Progress for the engine's "did that craft do anything" check: finished pieces count most,
-- then the quality of the piece being worked on.
local function SmithingProgress(writ, status)
    local _, _, quality = FindBasePiece(writ)
    return status.have * 10 + (quality or 0)
end

local function Improve(writ, bagId, slotIndex, quality)
    local craft = GetCraftingInteractionType()
    local boosters, chance = 0, 0
    repeat
        boosters = boosters + 1
        chance = GetSmithingImprovementChance(bagId, slotIndex, boosters, craft)
    until chance >= 100 or boosters >= 100
    if chance < 100 then
        return false, GetString(SI_WRITCRAFTER_CRAFT_CANT_IMPROVE)
    end
    local boosterName, _, have = GetSmithingImprovementItemInfo(craft, quality)
    local boosterId = GetItemLinkItemId(GetSmithingImprovementItemLink(craft, quality))
    if boosterId ~= 0 and WC.Policy.IsExcluded(boosterId) then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_EXPENSIVE, zo_strformat("<<t:1>>", boosterName or ""))
    end
    if (have or 0) < boosters then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_BOOSTERS, boosters, boosterName or "", have or 0)
    end
    local link = GetItemLink(bagId, slotIndex)
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_IMPROVING, ItemName(link),
        GetString("SI_ITEMDISPLAYQUALITY", quality + 1),
        (boosters > 1 and (boosters .. " x ") or "") .. zo_strformat("<<t:1>>", boosterName or "")))
    WC.Engine.CraftSounds({ SOUNDS.SMITHING_ITEM_TO_IMPROVE_PLACED }, IMPROVE_GLOW[craft])
    ImproveSmithingItem(bagId, slotIndex, boosters)
    return true
end

-- At a Grand Master station, make the writ's set the active one. Returns true when it's
-- active, "wait" right after switching, or false, reason.
local function SelectSet(writ)
    if not ZO_Smithing_IsConsolidatedStationCraftingMode() then
        return true
    end
    if GetActiveConsolidatedSmithingItemSetId() == writ.setId then
        return true
    end
    local setName = zo_strformat("<<1>>", GetItemSetName(writ.setId))
    for setIndex = 1, GetNumConsolidatedSmithingSets() do
        if GetConsolidatedSmithingItemSetIdByIndex(setIndex) == writ.setId then
            if not IsConsolidatedSmithingSetIndexUnlocked(setIndex) then
                return false, zo_strformat(SI_WRITCRAFTER_CRAFT_SET_LOCKED, setName)
            end
            SetActiveConsolidatedSmithingSetByIndex(setIndex)
            return "wait"
        end
    end
    return false, zo_strformat(SI_WRITCRAFTER_CRAFT_SET_LOCKED, setName)
end

-- The pattern and CP150 material whose predicted result is the writ's piece (any quality).
local function FindPattern(writ, styleId, traitIndex)
    for patternIndex = 1, GetNumSmithingPatterns() do
        local _, _, _, numMaterials = GetSmithingPatternInfo(patternIndex)
        for materialIndex = 1, numMaterials or 0 do
            local _, _, quantity, _, _, _, _, _, _, _, level, isChampion =
                GetSmithingPatternMaterialItemInfo(patternIndex, materialIndex)
            if isChampion and level == 150 then
                local link = GetSmithingPatternResultLink(patternIndex, materialIndex, quantity, styleId, traitIndex)
                if link and link ~= "" and WC.Reservations.MatchesBase(link, writ, true) then
                    return patternIndex, materialIndex, quantity, link
                end
            end
        end
    end
end

local function UseMimic(writ, styleId)
    if not styleId then
        return false
    end
    -- A choice made for this writ in the queue window wins over the setting.
    local choice = WC.Policy.MimicChoice(writ.link)
    if choice ~= nil then
        return choice
    end
    local mode = WC.settings.mimic
    if mode == WC.Policy.MIMIC_ALWAYS then
        return true
    elseif mode == WC.Policy.MIMIC_NEEDED then
        local styleItemId = GetItemLinkItemId(GetItemStyleMaterialLink(styleId))
        return WC.Policy.IsExpensive(styleItemId) or GetCurrentSmithingStyleItemCount(styleId) == 0
    end
    return false
end

local function CraftSmithing(writ, status)
    if not writ.template then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.templateId or 0)
    end

    -- 1. A piece already made but not yet at the writ's quality: improve it.
    local bagId, slotIndex, quality = FindBasePiece(writ)
    if bagId then
        return Improve(writ, bagId, slotIndex, quality)
    end

    -- 2. Otherwise create it.
    local selected, reason = SelectSet(writ)
    if selected ~= true then
        return selected, reason
    end
    local craft = GetCraftingInteractionType()
    local styleId = not DoesSmithingTypeIgnoreStyleItems(craft) and writ.style or nil
    local traitIndex = writ.trait + 1
    local patternIndex, materialIndex, quantity, resultLink = FindPattern(writ, styleId, traitIndex)
    if not patternIndex then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_WRONG_STATION,
            zo_strformat("<<1>>", GetItemSetName(writ.setId)))
    end
    local useMimic = UseMimic(writ, styleId)
    local maxIterations, result = GetMaxIterationsPossibleForSmithingItem(patternIndex, materialIndex,
        quantity, styleId, traitIndex, useMimic)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local materials = {
        { itemId = GetItemLinkItemId(GetSmithingPatternMaterialItemLink(patternIndex, materialIndex)), count = quantity },
    }
    if writ.trait ~= ITEM_TRAIT_TYPE_NONE then
        materials[#materials + 1] = { itemId = GetItemLinkItemId(GetSmithingTraitItemLink(traitIndex)) }
    end
    if useMimic then
        materials[#materials + 1] = { itemId = WC.Policy.MIMIC_STONE_ID }
    elseif styleId then
        materials[#materials + 1] = { itemId = GetItemLinkItemId(GetItemStyleMaterialLink(styleId)) }
    end
    WC.Engine.SayCrafting(1, resultLink, materials)
    WC.Engine.CraftSounds(nil, CREATE_GLOW[craft])
    CraftSmithingItem(patternIndex, materialIndex, quantity, styleId, traitIndex, useMimic, 1)
    return true
end

for _, kind in ipairs({ WC.Master.KIND_SMITHING }) do
    WC.Engine.RegisterCrafter(kind, CraftSmithing, SmithingProgress)
end

-- Daily writs: a plain piece (no trait, normal quality) in any material and style. The game says
-- which pattern and material fulfil the condition; the style is the allowed style material you
-- know for that pattern and have the most of. At a Grand Master station the active set's piece is
-- made, if the game accepts it for the condition.
local NO_TRAIT = ITEM_TRAIT_TYPE_NONE + 1

-- Allowed styles known for a pattern that you have material for, most material first.
local function DailyStyles(patternIndex)
    local styles = {}
    for index = 1, GetNumValidItemStyles() do
        local styleId = GetValidItemStyleId(index)
        if styleId and styleId > 0 and IsSmithingStyleKnown(styleId, patternIndex) then
            local count = GetCurrentSmithingStyleItemCount(styleId) or 0
            local styleItemId = GetItemLinkItemId(GetItemStyleMaterialLink(styleId))
            if count > 0 and not WC.Policy.IsExpensive(styleItemId) then
                styles[#styles + 1] = { id = styleId, count = count }
            end
        end
    end
    table.sort(styles, function(a, b) return a.count > b.count end)
    return styles
end

-- Any style this character knows for a pattern: enough to ask the game about the piece.
local function AnyKnownStyle(patternIndex)
    for index = 1, GetNumValidItemStyles() do
        local styleId = GetValidItemStyleId(index)
        if styleId and styleId > 0 and IsSmithingStyleKnown(styleId, patternIndex) then
            return styleId
        end
    end
end

-- The pattern and material whose piece the game accepts for the condition, with the style to use
-- (nil when the craft ignores styles, false when no allowed style material is available).
local function FindDaily(condition)
    local ignoresStyle = DoesSmithingTypeIgnoreStyleItems(GetCraftingInteractionType())
    for patternIndex = 1, GetNumSmithingPatterns() do
        local _, _, _, numMaterials = GetSmithingPatternInfo(patternIndex)
        local testStyle = not ignoresStyle and AnyKnownStyle(patternIndex) or nil
        if ignoresStyle or testStyle then
            for materialIndex = 1, numMaterials or 0 do
                local _, _, quantity = GetSmithingPatternMaterialItemInfo(patternIndex, materialIndex)
                local link = GetSmithingPatternResultLink(patternIndex, materialIndex, quantity, testStyle, NO_TRAIT)
                if WC.Daily.Fulfils(link, condition) then
                    local style
                    if not ignoresStyle then
                        local usable = DailyStyles(patternIndex)
                        style = usable[1] and usable[1].id or false
                    end
                    return { pattern = patternIndex, material = materialIndex, quantity = quantity,
                        style = style, link = link }
                end
            end
        end
    end
end

local function ResolveDaily(condition)
    local plan = FindDaily(condition)
    if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
        local firstLink = ""
        if GetNumSmithingPatterns() > 0 then
            local _, _, quantity = GetSmithingPatternMaterialItemInfo(1, 1)
            firstLink = GetSmithingPatternResultLink(1, 1, quantity, AnyKnownStyle(1), NO_TRAIT) or ""
        end
        WC.Log.Debug(string.format("Smithing daily '%s': %d patterns, style for pattern 1: %s, pattern 1 makes %s, consolidated %s, active set %s -> %s",
            condition.text, GetNumSmithingPatterns(), tostring(AnyKnownStyle(1)), firstLink,
            tostring(ZO_Smithing_IsConsolidatedStationCraftingMode()), tostring(GetActiveConsolidatedSmithingItemSetId()),
            plan and plan.link or "no match"))
    end
    return plan
end

local function CraftDaily(condition)
    -- Searched again: the cached answer may be from another station (e.g. a Grand Master one).
    local plan = FindDaily(condition)
    if not plan then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end
    if plan.style == false then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_NO_STYLE, ItemName(plan.link))
    end
    local remaining = condition.max - condition.current
    local maxIterations, result = GetMaxIterationsPossibleForSmithingItem(plan.pattern, plan.material,
        plan.quantity, plan.style, NO_TRAIT, false)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local iterations = zo_min(remaining, maxIterations)
    local materials = {
        { itemId = GetItemLinkItemId(GetSmithingPatternMaterialItemLink(plan.pattern, plan.material)),
          count = plan.quantity * iterations },
    }
    if plan.style then
        materials[#materials + 1] = { itemId = GetItemLinkItemId(GetItemStyleMaterialLink(plan.style)), count = iterations }
    end
    local craft = GetCraftingInteractionType()
    WC.Engine.SayCrafting(iterations, plan.link, materials)
    WC.Engine.CraftSounds(nil, CREATE_GLOW[craft])
    CraftSmithingItem(plan.pattern, plan.material, plan.quantity, plan.style, NO_TRAIT, false, iterations)
    return true
end

for _, craft in ipairs({ CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER,
                         CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING }) do
    WC.Daily.RegisterCraft(craft, ResolveDaily, CraftDaily)
end

-- Grand Master stations -----------------------------------------------------------------------
-- The sets your Grand Master stations can craft, remembered per craft for the whole account
-- (on this server) each time you use one, so the queue window knows them anywhere. Sets are
-- only ever added: a station never forgets an attuned set, and you may have several stations.
local GrandMaster = {}
WC.GrandMaster = GrandMaster

local function Known()
    WC.sv.grandMaster = WC.sv.grandMaster or {}
    return WC.sv.grandMaster
end

-- true when one of your Grand Master stations for this craft has the set.
function GrandMaster.HasSet(craft, setId)
    local sets = Known()[craft]
    return sets ~= nil and sets[setId] == true
end

-- Whether a Grand Master station for this craft has been seen at all.
function GrandMaster.Seen(craft)
    return Known()[craft] ~= nil
end

EVENT_MANAGER:RegisterForEvent(WC.name .. "GrandMaster", EVENT_CRAFTING_STATION_INTERACT, function(_, craft)
    if GetCraftingInteractionMode() ~= CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION then
        return
    end
    local known = Known()
    known[craft] = known[craft] or {}
    for setIndex = 1, GetNumConsolidatedSmithingSets() do
        if IsConsolidatedSmithingSetIndexUnlocked(setIndex) then
            known[craft][GetConsolidatedSmithingItemSetIdByIndex(setIndex)] = true
        end
    end
    WC.QueueWindow.OnPolicyChanged()
end)
