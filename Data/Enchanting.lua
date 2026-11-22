local WC = WritCrafter
WC.Data = WC.Data or {}

local Enchanting = {}
WC.Data.Enchanting = Enchanting

-- Essence runes, by item ID
local OKO, MAKKO, DENI, OKOMA, MAKKOMA, DENIMA = 45831, 45832, 45833, 45834, 45835, 45836
local KUOKO, RAKEIPA, DEKEIPA, MEIP, HAOKO, DETERI = 45837, 45838, 45839, 45840, 45841, 45842
local OKORI, ORU, TADERI, MAKDERI, KADERI, HAKEIJO = 45843, 45846, 45847, 45848, 45849, 68342

-- Game facts first gathered from WritWorthy's enchanting data (ziggr, Sharlikran; credited in
-- README), written in WritCrafter's own format and order (by glyph item ID) and checked against
-- the game by /wc checkdata.
-- Master writ field 10 is the glyph's item ID. Each glyph uses one essence rune and an
-- additive (Rejera/Repora) or subtractive (Jehade/Itade) potency rune.
Enchanting.GLYPHS = {
    [5364]  = { essence = DEKEIPA, additive = false }, -- Frost Resist
    [5365]  = { essence = DEKEIPA, additive = true  }, -- Frost
    [5366]  = { essence = DETERI,  additive = true  }, -- Hardening
    [26580] = { essence = OKO,     additive = true  }, -- Health
    [26581] = { essence = OKOMA,   additive = true  }, -- Health Recovery
    [26582] = { essence = MAKKO,   additive = true  }, -- Magicka
    [26583] = { essence = MAKKOMA, additive = true  }, -- Magicka Recovery
    [26586] = { essence = KUOKO,   additive = false }, -- Poison Resist
    [26587] = { essence = KUOKO,   additive = true  }, -- Poison
    [26588] = { essence = DENI,    additive = true  }, -- Stamina
    [26589] = { essence = DENIMA,  additive = true  }, -- Stamina Recovery
    [26591] = { essence = OKORI,   additive = false }, -- Weakening
    [26841] = { essence = HAOKO,   additive = true  }, -- Foulness
    [26844] = { essence = MEIP,    additive = true  }, -- Shock
    [26845] = { essence = DETERI,  additive = false }, -- Crushing
    [26847] = { essence = HAOKO,   additive = false }, -- Disease Resist
    [26848] = { essence = RAKEIPA, additive = true  }, -- Flame
    [26849] = { essence = RAKEIPA, additive = false }, -- Flame Resist
    [43570] = { essence = MEIP,    additive = false }, -- Shock Resist
    [43573] = { essence = OKO,     additive = false }, -- Absorb Health
    [45867] = { essence = DENI,    additive = false }, -- Absorb Stamina
    [45868] = { essence = MAKKO,   additive = false }, -- Absorb Magicka
    [45869] = { essence = OKOMA,   additive = false }, -- Decrease Health
    [45870] = { essence = MAKKOMA, additive = false }, -- Reduce Spell Cost
    [45871] = { essence = DENIMA,  additive = false }, -- Reduce Feat Cost
    [45872] = { essence = KADERI,  additive = true  }, -- Bashing
    [45873] = { essence = KADERI,  additive = false }, -- Shielding
    [45874] = { essence = ORU,     additive = true  }, -- Potion Boost
    [45875] = { essence = ORU,     additive = false }, -- Potion Speed
    [45883] = { essence = TADERI,  additive = true  }, -- Increase Physical Harm
    [45884] = { essence = MAKDERI, additive = true  }, -- Increase Magical Harm
    [45885] = { essence = TADERI,  additive = false }, -- Decrease Physical Harm
    [45886] = { essence = MAKDERI, additive = false }, -- Decrease Spell Harm
    [54484] = { essence = OKORI,   additive = true  }, -- Weapon Damage
    [68343] = { essence = HAKEIJO, additive = true  }, -- Prismatic Defense
    [68344] = { essence = HAKEIJO, additive = false }, -- Prismatic Onslaught
}

-- Master writ field 11 is a level code.
Enchanting.LEVELS = {
    [207] = { cp = 150, additive = 64509, subtractive = 64508 },  -- Rejera / Jehade
    [225] = { cp = 160, additive = 68341, subtractive = 68340 },  -- Repora / Itade
}

-- Every enchanting rune, owned or not, for the exclusions window. The game has no "all runes"
-- list, but runes sit in a few item-ID ranges; each ID in them is checked against the game and
-- kept if it's a rune: potency 45806-45830 and 45855-45857, essences 45831-45849, aspects
-- 45850-45854, CP150 64508/64509, CP160 68340/68341, Hakeijo 68342, Indeko 166045.
local RUNE_ID_RANGES = { { 45800, 45900 }, { 64500, 64520 }, { 68330, 68350 }, { 166030, 166060 } }
local RUNE_TYPES = {
    [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = true,
    [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = true,
    [ITEMTYPE_ENCHANTING_RUNE_ASPECT]  = true,
}
local allRunes

function Enchanting.AllRunes()
    if not allRunes then
        allRunes = {}
        for _, range in ipairs(RUNE_ID_RANGES) do
            for itemId = range[1], range[2] do
                local link = string.format("|H1:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
                if RUNE_TYPES[GetItemLinkItemType(link)] and GetItemLinkName(link) ~= "" then
                    allRunes[#allRunes + 1] = itemId
                end
            end
        end
    end
    return allRunes
end

-- Master writ field 12 is the glyph quality; it picks the aspect rune.
Enchanting.ASPECTS = {
    [4] = 45853,  -- Rekuta (purple)
    [5] = 45854,  -- Kuta (gold)
}
