local WC = WritCrafter
WC.Data = WC.Data or {}

local Enchanting = {}
WC.Data.Enchanting = Enchanting

-- Essence runes
local DEKEIPA, DENI, DENIMA, DETERI, HAKEIJO, HAOKO = 45839, 45833, 45836, 45842, 68342, 45841
local KADERI, KUOKO, MAKDERI, MAKKO, MAKKOMA, MEIP = 45849, 45837, 45848, 45832, 45835, 45840
local OKO, OKOMA, OKORI, ORU, RAKEIPA, TADERI = 45831, 45834, 45843, 45846, 45838, 45847

-- Master writ field 10 is the glyph's item ID. Each glyph uses one essence rune and an
-- additive (Rejera/Repora) or subtractive (Jehade/Itade) potency rune.
Enchanting.GLYPHS = {
    [26580] = { essence = OKO,     additive = true  }, -- Health
    [26582] = { essence = MAKKO,   additive = true  }, -- Magicka
    [26588] = { essence = DENI,    additive = true  }, -- Stamina
    [68343] = { essence = HAKEIJO, additive = true  }, -- Prismatic Defense
    [26848] = { essence = RAKEIPA, additive = true  }, -- Flame
    [45869] = { essence = OKOMA,   additive = false }, -- Decrease Health
    [54484] = { essence = OKORI,   additive = true  }, -- Weapon Damage
    [26841] = { essence = HAOKO,   additive = true  }, -- Foulness
    [26587] = { essence = KUOKO,   additive = true  }, -- Poison
    [5365]  = { essence = DEKEIPA, additive = true  }, -- Frost
    [26844] = { essence = MEIP,    additive = true  }, -- Shock
    [5366]  = { essence = DETERI,  additive = true  }, -- Hardening
    [26845] = { essence = DETERI,  additive = false }, -- Crushing
    [26591] = { essence = OKORI,   additive = false }, -- Weakening
    [43573] = { essence = OKO,     additive = false }, -- Absorb Health
    [45867] = { essence = DENI,    additive = false }, -- Absorb Stamina
    [45868] = { essence = MAKKO,   additive = false }, -- Absorb Magicka
    [68344] = { essence = HAKEIJO, additive = false }, -- Prismatic Onslaught
    [5364]  = { essence = DEKEIPA, additive = false }, -- Frost Resist
    [26589] = { essence = DENIMA,  additive = true  }, -- Stamina Recovery
    [45871] = { essence = DENIMA,  additive = false }, -- Reduce Feat Cost
    [26847] = { essence = HAOKO,   additive = false }, -- Disease Resist
    [45872] = { essence = KADERI,  additive = true  }, -- Bashing
    [45873] = { essence = KADERI,  additive = false }, -- Shielding
    [26586] = { essence = KUOKO,   additive = false }, -- Poison Resist
    [45884] = { essence = MAKDERI, additive = true  }, -- Increase Magical Harm
    [45886] = { essence = MAKDERI, additive = false }, -- Decrease Spell Harm
    [26583] = { essence = MAKKOMA, additive = true  }, -- Magicka Recovery
    [45870] = { essence = MAKKOMA, additive = false }, -- Reduce Spell Cost
    [43570] = { essence = MEIP,    additive = false }, -- Shock Resist
    [26581] = { essence = OKOMA,   additive = true  }, -- Health Recovery
    [45874] = { essence = ORU,     additive = true  }, -- Potion Boost
    [45875] = { essence = ORU,     additive = false }, -- Potion Speed
    [26849] = { essence = RAKEIPA, additive = false }, -- Flame Resist
    [45883] = { essence = TADERI,  additive = true  }, -- Increase Physical Harm
    [45885] = { essence = TADERI,  additive = false }, -- Decrease Physical Harm
}

-- Master writ field 11 is a level code.
Enchanting.LEVELS = {
    [207] = { cp = 150, additive = 64509, subtractive = 64508 },  -- Rejera / Jehade
    [225] = { cp = 160, additive = 68341, subtractive = 68340 },  -- Repora / Itade
}

-- Master writ field 12 is the glyph quality; it picks the aspect rune.
Enchanting.ASPECTS = {
    [4] = 45853,  -- Rekuta (purple)
    [5] = 45854,  -- Kuta (gold)
}
