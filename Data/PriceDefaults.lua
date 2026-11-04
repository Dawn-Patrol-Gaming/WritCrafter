local WC = WritCrafter
WC.Data = WC.Data or {}

local PriceDefaults = {}
WC.Data.PriceDefaults = PriceDefaults

-- Per-category "too expensive" ceilings (gold per unit), used when "Re-check against live
-- prices" is on. Each sits in a natural gap in NA prices on 2026-11-02 (plan §5).
PriceDefaults.CEILINGS = {
    reagent    = 300,   -- Bugloss ~185 | Violet Coprinus ~480
    rune       = 500,   -- Oko ~225 | Indeko ~860
    trait      = 1000,  -- Cobalt ~370 | Titanium ~2,030
    ingredient = 300,   -- Bervez Juice ~45 | Cyrodiil Citrus ~650
}

local CATEGORY_BY_ITEMTYPE = {
    [ITEMTYPE_REAGENT]                 = "reagent",
    [ITEMTYPE_ENCHANTING_RUNE_ASPECT]  = "rune",
    [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = "rune",
    [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = "rune",
    [ITEMTYPE_WEAPON_TRAIT]            = "trait",
    [ITEMTYPE_ARMOR_TRAIT]             = "trait",
    [ITEMTYPE_JEWELRY_TRAIT]           = "trait",
    [ITEMTYPE_INGREDIENT]              = "ingredient",
    [ITEMTYPE_STYLE_MATERIAL]          = "style",
}

-- nil for categories that aren't price-filtered (base and improvement materials, solvents).
function PriceDefaults.Category(itemLink)
    return CATEGORY_BY_ITEMTYPE[GetItemLinkItemType(itemLink)]
end

-- Items marked too expensive out of the box, from the user's MasterMerchant history and
-- ESO-Hub NA prices on 2026-11-02. Only the item IDs are kept here, no price data.
PriceDefaults.EXPENSIVE = {
    -- Alchemy reagents that are overland plants but pricey (non-plants are rejected by source)
    [30164]  = true,  -- Columbine
    [30152]  = true,  -- Violet Coprinus
    -- Enchanting runes
    [68342]  = true,  -- Hakeijo (Prismatic Defense / Onslaught)
    [45854]  = true,  -- Kuta (gold aspect)
    [166045] = true,  -- Indeko
    -- Trait materials
    [139411] = true,  -- Aurbic Amber (jewelry Infused)
    [56863]  = true,  -- Potent Nirncrux (weapon Nirnhoned)
    [139413] = true,  -- Dibellium (jewelry Harmony)
    [139409] = true,  -- Dawn-Prism (jewelry Triune)
    [56862]  = true,  -- Fortified Nirncrux (armor Nirnhoned)
    [139412] = true,  -- Gilding Wax (jewelry Swift)
    [139414] = true,  -- Slaughterstone (jewelry Bloodthirsty)
    [139410] = true,  -- Titanium (jewelry Protective)
    -- Provisioning ingredients
    [115026] = true,  -- Aetherial Dust
    [171328] = true,  -- Rubyblossom Extract
    [64222]  = true,  -- Perfect Roe
    [120078] = true,  -- Diminished Aetherial Dust
    [225210] = true,  -- Red Lichen
    [171326] = true,  -- Cyrodiil Citrus
    -- Style materials aren't listed: see IsVendorStyleMaterial.
}

-- Style materials NPC Stylemasters sell: the ten basic racial styles' materials (15g each)
-- and Desecrated Grave Soil (Hollowjack, 150g). Every other style material is excluded by
-- default, and writs get a mimic stone instead. Looked up by style ID, so no item IDs to go
-- stale.
local VENDOR_STYLES = {
    ITEMSTYLE_RACIAL_BRETON, ITEMSTYLE_RACIAL_REDGUARD, ITEMSTYLE_RACIAL_ORC,
    ITEMSTYLE_RACIAL_DARK_ELF, ITEMSTYLE_RACIAL_NORD, ITEMSTYLE_RACIAL_ARGONIAN,
    ITEMSTYLE_RACIAL_HIGH_ELF, ITEMSTYLE_RACIAL_WOOD_ELF, ITEMSTYLE_RACIAL_KHAJIIT,
    ITEMSTYLE_RACIAL_IMPERIAL,
}
local DESECRATED_GRAVE_SOIL = 134798
local vendorStyleItems

function PriceDefaults.IsVendorStyleMaterial(itemId)
    if not vendorStyleItems then
        vendorStyleItems = { [DESECRATED_GRAVE_SOIL] = true }
        for _, styleId in ipairs(VENDOR_STYLES) do
            local id = GetItemLinkItemId(GetItemStyleMaterialLink(styleId))
            if id ~= 0 then
                vendorStyleItems[id] = true
            end
        end
    end
    return vendorStyleItems[itemId] == true
end
