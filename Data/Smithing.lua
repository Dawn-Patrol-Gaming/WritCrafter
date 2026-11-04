local WC = WritCrafter
WC.Data = WC.Data or {}

local Smithing = {}
WC.Data.Smithing = Smithing

local BS, CL, WW, JW = CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING

-- CP150 base materials (master writs are always CP150).
local RUBEDITE, ANCESTOR_SILK, RUBEDO_LEATHER, RUBY_ASH, PLATINUM = 64489, 64504, 64506, 64502, 135146

Smithing.TRAITS_WEAPON  = "weapon"
Smithing.TRAITS_ARMOR   = "armor"
Smithing.TRAITS_JEWELRY = "jewelry"
local WEAPON, ARMOR, JEWELRY = Smithing.TRAITS_WEAPON, Smithing.TRAITS_ARMOR, Smithing.TRAITS_JEWELRY

local C = {
    AXES = ITEM_STYLE_CHAPTER_AXES,         BELTS = ITEM_STYLE_CHAPTER_BELTS,
    BOOTS = ITEM_STYLE_CHAPTER_BOOTS,       BOWS = ITEM_STYLE_CHAPTER_BOWS,
    CHESTS = ITEM_STYLE_CHAPTER_CHESTS,     DAGGERS = ITEM_STYLE_CHAPTER_DAGGERS,
    GLOVES = ITEM_STYLE_CHAPTER_GLOVES,     HELMETS = ITEM_STYLE_CHAPTER_HELMETS,
    LEGS = ITEM_STYLE_CHAPTER_LEGS,         MACES = ITEM_STYLE_CHAPTER_MACES,
    SHIELDS = ITEM_STYLE_CHAPTER_SHIELDS,   SHOULDERS = ITEM_STYLE_CHAPTER_SHOULDERS,
    STAVES = ITEM_STYLE_CHAPTER_STAVES,     SWORDS = ITEM_STYLE_CHAPTER_SWORDS,
}

-- Master writ field 10 is an item template number. For each one:
--   craft, research line (also the trait research line), motif chapter, base material + count
--   at CP150, trait group, and a sample item ID for names and equip/armor/weapon type.
-- robe = true/false separates the two light chest pieces, which share every other attribute.
Smithing.TEMPLATES = {
    [53] = { craft = BS, line = 1,  chapter = C.AXES,      mat = RUBEDITE,       count = 11, traits = WEAPON,  sample = 43529 }, -- Axe
    [56] = { craft = BS, line = 2,  chapter = C.MACES,     mat = RUBEDITE,       count = 11, traits = WEAPON,  sample = 43530 }, -- Mace
    [59] = { craft = BS, line = 3,  chapter = C.SWORDS,    mat = RUBEDITE,       count = 11, traits = WEAPON,  sample = 43531 }, -- Sword
    [68] = { craft = BS, line = 4,  chapter = C.AXES,      mat = RUBEDITE,       count = 14, traits = WEAPON,  sample = 43532 }, -- Greataxe
    [69] = { craft = BS, line = 5,  chapter = C.MACES,     mat = RUBEDITE,       count = 14, traits = WEAPON,  sample = 43533 }, -- Maul
    [67] = { craft = BS, line = 6,  chapter = C.SWORDS,    mat = RUBEDITE,       count = 14, traits = WEAPON,  sample = 43534 }, -- Greatsword
    [62] = { craft = BS, line = 7,  chapter = C.DAGGERS,   mat = RUBEDITE,       count = 10, traits = WEAPON,  sample = 43535 }, -- Dagger
    [46] = { craft = BS, line = 8,  chapter = C.CHESTS,    mat = RUBEDITE,       count = 15, traits = ARMOR,   sample = 43537 }, -- Cuirass
    [50] = { craft = BS, line = 9,  chapter = C.BOOTS,     mat = RUBEDITE,       count = 13, traits = ARMOR,   sample = 43538 }, -- Sabatons
    [52] = { craft = BS, line = 10, chapter = C.GLOVES,    mat = RUBEDITE,       count = 13, traits = ARMOR,   sample = 43539 }, -- Gauntlets
    [44] = { craft = BS, line = 11, chapter = C.HELMETS,   mat = RUBEDITE,       count = 13, traits = ARMOR,   sample = 43562 }, -- Helm
    [49] = { craft = BS, line = 12, chapter = C.LEGS,      mat = RUBEDITE,       count = 14, traits = ARMOR,   sample = 43540 }, -- Greaves
    [47] = { craft = BS, line = 13, chapter = C.SHOULDERS, mat = RUBEDITE,       count = 13, traits = ARMOR,   sample = 43541 }, -- Pauldron
    [48] = { craft = BS, line = 14, chapter = C.BELTS,     mat = RUBEDITE,       count = 13, traits = ARMOR,   sample = 43542 }, -- Girdle
    [28] = { craft = CL, line = 1,  chapter = C.CHESTS,    mat = ANCESTOR_SILK,  count = 15, traits = ARMOR,   sample = 43543, robe = true  }, -- Robe
    [75] = { craft = CL, line = 1,  chapter = C.CHESTS,    mat = ANCESTOR_SILK,  count = 15, traits = ARMOR,   sample = 44241, robe = false }, -- Jerkin
    [32] = { craft = CL, line = 2,  chapter = C.BOOTS,     mat = ANCESTOR_SILK,  count = 13, traits = ARMOR,   sample = 43544 }, -- Shoes
    [34] = { craft = CL, line = 3,  chapter = C.GLOVES,    mat = ANCESTOR_SILK,  count = 13, traits = ARMOR,   sample = 43545 }, -- Gloves
    [26] = { craft = CL, line = 4,  chapter = C.HELMETS,   mat = ANCESTOR_SILK,  count = 13, traits = ARMOR,   sample = 43564 }, -- Hat
    [31] = { craft = CL, line = 5,  chapter = C.LEGS,      mat = ANCESTOR_SILK,  count = 14, traits = ARMOR,   sample = 43546 }, -- Breeches
    [29] = { craft = CL, line = 6,  chapter = C.SHOULDERS, mat = ANCESTOR_SILK,  count = 13, traits = ARMOR,   sample = 43547 }, -- Epaulets
    [30] = { craft = CL, line = 7,  chapter = C.BELTS,     mat = ANCESTOR_SILK,  count = 13, traits = ARMOR,   sample = 43548 }, -- Sash
    [37] = { craft = CL, line = 8,  chapter = C.CHESTS,    mat = RUBEDO_LEATHER, count = 15, traits = ARMOR,   sample = 43550 }, -- Jack
    [41] = { craft = CL, line = 9,  chapter = C.BOOTS,     mat = RUBEDO_LEATHER, count = 13, traits = ARMOR,   sample = 43551 }, -- Boots
    [43] = { craft = CL, line = 10, chapter = C.GLOVES,    mat = RUBEDO_LEATHER, count = 13, traits = ARMOR,   sample = 43552 }, -- Bracers
    [35] = { craft = CL, line = 11, chapter = C.HELMETS,   mat = RUBEDO_LEATHER, count = 13, traits = ARMOR,   sample = 43563 }, -- Helmet
    [40] = { craft = CL, line = 12, chapter = C.LEGS,      mat = RUBEDO_LEATHER, count = 14, traits = ARMOR,   sample = 43553 }, -- Guards
    [38] = { craft = CL, line = 13, chapter = C.SHOULDERS, mat = RUBEDO_LEATHER, count = 13, traits = ARMOR,   sample = 43554 }, -- Arm Cops
    [39] = { craft = CL, line = 14, chapter = C.BELTS,     mat = RUBEDO_LEATHER, count = 13, traits = ARMOR,   sample = 43555 }, -- Belt
    [70] = { craft = WW, line = 1,  chapter = C.BOWS,      mat = RUBY_ASH,       count = 12, traits = WEAPON,  sample = 43549 }, -- Bow
    [72] = { craft = WW, line = 2,  chapter = C.STAVES,    mat = RUBY_ASH,       count = 12, traits = WEAPON,  sample = 43557 }, -- Inferno Staff
    [73] = { craft = WW, line = 3,  chapter = C.STAVES,    mat = RUBY_ASH,       count = 12, traits = WEAPON,  sample = 43558 }, -- Frost Staff
    [74] = { craft = WW, line = 4,  chapter = C.STAVES,    mat = RUBY_ASH,       count = 12, traits = WEAPON,  sample = 43559 }, -- Lightning Staff
    [71] = { craft = WW, line = 5,  chapter = C.STAVES,    mat = RUBY_ASH,       count = 12, traits = WEAPON,  sample = 43560 }, -- Healing Staff
    [65] = { craft = WW, line = 6,  chapter = C.SHIELDS,   mat = RUBY_ASH,       count = 14, traits = ARMOR,   sample = 43556 }, -- Shield
    [24] = { craft = JW, line = 1,  chapter = nil,         mat = PLATINUM,       count = 10, traits = JEWELRY, sample = 43536 }, -- Ring
    [18] = { craft = JW, line = 2,  chapter = nil,         mat = PLATINUM,       count = 15, traits = JEWELRY, sample = 43561 }, -- Necklace
}

-- Improvement materials, green → blue → purple → gold, and how many of each a CP150 item
-- needs with the improvement passives maxed.
Smithing.IMPROVE_MATS = {
    [BS] = { 54170, 54171, 54172, 54173 },     -- Honing Stone, Dwarven Oil, Grain Solvent, Tempering Alloy
    [CL] = { 54174, 54175, 54176, 54177 },     -- Hemming, Embroidery, Elegant Lining, Dreugh Wax
    [WW] = { 54178, 54179, 54180, 54181 },     -- Pitch, Turpen, Mastic, Rosin
    [JW] = { 203631, 203632, 203633, 203634 }, -- Terne, Iridium, Zircon, Chromium Plating
}
Smithing.IMPROVE_COUNTS = { 2, 3, 4, 8 }

-- Required master writ quality (field 12) is a functional quality: 2 green .. 5 gold.
-- Returns { {itemId, count}, ... } of improvement materials to reach it from white.
function Smithing.ImprovementMaterials(craft, quality)
    local mats = {}
    local ids = Smithing.IMPROVE_MATS[craft]
    for tier = 1, (quality or 1) - 1 do
        mats[#mats + 1] = { itemId = ids[tier], count = Smithing.IMPROVE_COUNTS[tier] }
    end
    return mats
end
