local WC = WritCrafter

-- Smithing (blacksmithing, clothing, woodworking, jewelry): a gear writ takes several crafts,
-- one per engine step:
--   1. create the white piece: at a Grand Master station first switch to the writ's set, then
--      find the pattern and CP150 material whose predicted result is exactly the writ's piece
--      (set, trait, style, weight, robe or jerkin), with the style material or a mimic stone;
--   2. improve it one quality tier per step until it matches the writ, only ever at a 100%
--      chance.
-- Everything is checked against the writ before anything is spent.

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
    if (have or 0) < boosters then
        return false, zo_strformat(SI_WRITCRAFTER_CRAFT_BOOSTERS, boosters, boosterName or "", have or 0)
    end
    local link = GetItemLink(bagId, slotIndex)
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_IMPROVING, ItemName(link),
        GetString("SI_ITEMDISPLAYQUALITY", quality + 1)))
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
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CRAFTING, 1, GetItemLinkName(resultLink)))
    CraftSmithingItem(patternIndex, materialIndex, quantity, styleId, traitIndex, useMimic, 1)
    return true
end

for _, kind in ipairs({ WC.Master.KIND_SMITHING }) do
    WC.Engine.RegisterCrafter(kind, CraftSmithing, SmithingProgress)
end
