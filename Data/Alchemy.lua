local WC = WritCrafter
WC.Data = WC.Data or {}

local Alchemy = {}
WC.Data.Alchemy = Alchemy

-- Effect IDs, as used in master writ links (fields 11-13) and crafted potion links.
-- Odd = an effect, the next even number = its counter. Names live in Strings (SI_WRITCRAFTER_EFFECT_<id>).
Alchemy.EFFECT_MAX = 38

-- Pre-Update 51 IDs that older writs and potions still carry.
Alchemy.LEGACY_EFFECTS = {
    [13] = 11,  -- Increase Weapon Power -> Increase Power
    [14] = 12,  -- Maim -> Cowardice
    [17] = 15,  -- Weapon Critical -> Critical
    [18] = 36,  -- old Enervation -> Enervation (now Force's counter)
}

function Alchemy.Normalize(effect)
    return Alchemy.LEGACY_EFFECTS[effect] or effect
end

function Alchemy.Counter(effect)
    if effect % 2 == 1 then
        return effect + 1
    end
    return effect - 1
end

Alchemy.SOURCE_PLANT   = "plant"     -- harvested from overland plant/fungus nodes
Alchemy.SOURCE_CRITTER = "critter"   -- animal parts from critters and containers
Alchemy.SOURCE_ZONE    = "zone"      -- zone-specific creatures (clams, dragons, chaurus)
Alchemy.SOURCE_SPECIAL = "special"   -- Update 51 sources: solo dungeons, IC sewers, treasure maps, icy zones

local SOURCE_PLANT, SOURCE_CRITTER, SOURCE_ZONE, SOURCE_SPECIAL =
    Alchemy.SOURCE_PLANT, Alchemy.SOURCE_CRITTER, Alchemy.SOURCE_ZONE, Alchemy.SOURCE_SPECIAL

-- Update 51 traits, cross-checked against Dolgubon's, WritWorthy, LibAlchemy and UESP's patch notes.
Alchemy.REAGENTS = {
    [30157] = { source = SOURCE_PLANT,   effects = {  5, 11, 23, 34 } }, -- Blessed Thistle
    [30148] = { source = SOURCE_PLANT,   effects = {  1,  4, 22, 34 } }, -- Blue Entoloma
    [30160] = { source = SOURCE_PLANT,   effects = {  1,  3,  7, 37 } }, -- Bugloss
    [30164] = { source = SOURCE_PLANT,   effects = {  1,  3,  5, 19 } }, -- Columbine
    [30161] = { source = SOURCE_PLANT,   effects = {  2,  3, 11, 21 } }, -- Corn Flower
    [150672] = { source = SOURCE_PLANT,  effects = {  1, 28, 32, 35 } }, -- Crimson Nirnroot
    [30162] = { source = SOURCE_PLANT,   effects = {  5, 10, 11, 15 } }, -- Dragonthorn
    [30151] = { source = SOURCE_PLANT,   effects = {  2,  4,  6, 20 } }, -- Emetic Russula
    [30156] = { source = SOURCE_PLANT,   effects = {  6,  9, 12, 36 } }, -- Imp Stool
    [30158] = { source = SOURCE_PLANT,   effects = {  3,  8, 15, 35 } }, -- Lady's Smock
    [30155] = { source = SOURCE_PLANT,   effects = {  1,  6, 12, 24 } }, -- Luminous Russula
    [30163] = { source = SOURCE_PLANT,   effects = {  1,  5,  9, 12 } }, -- Mountain Flower
    [30153] = { source = SOURCE_PLANT,   effects = { 19, 22, 23, 36 } }, -- Namira's Rot
    [77590] = { source = SOURCE_PLANT,   effects = {  2, 25, 28, 30 } }, -- Nightshade
    [30165] = { source = SOURCE_PLANT,   effects = {  2, 16, 22, 34 } }, -- Nirnroot
    [30149] = { source = SOURCE_PLANT,   effects = {  2,  6, 10, 35 } }, -- Stinkhorn
    [30152] = { source = SOURCE_PLANT,   effects = {  2,  4,  8, 11 } }, -- Violet Coprinus
    [30166] = { source = SOURCE_PLANT,   effects = {  1, 15, 20, 33 } }, -- Water Hyacinth
    [30154] = { source = SOURCE_PLANT,   effects = {  4,  7, 21, 36 } }, -- White Cap
    [30159] = { source = SOURCE_PLANT,   effects = { 15, 19, 21, 24 } }, -- Wormwood
    [77583] = { source = SOURCE_CRITTER, effects = {  8,  9, 25, 29 } }, -- Beetle Scuttle
    [77585] = { source = SOURCE_CRITTER, effects = {  1, 27, 29, 33 } }, -- Butterfly Wing
    [77587] = { source = SOURCE_CRITTER, effects = {  6, 26, 28, 29 } }, -- Fleshfly Larva
    [77591] = { source = SOURCE_CRITTER, effects = {  7,  9, 25, 30 } }, -- Mudcrab Chitin
    [77589] = { source = SOURCE_CRITTER, effects = { 23, 26, 27, 38 } }, -- Scrib Jelly
    [77584] = { source = SOURCE_CRITTER, effects = { 22, 24, 30, 33 } }, -- Spider Egg
    [77581] = { source = SOURCE_CRITTER, effects = { 10, 16, 21, 37 } }, -- Torchbug Thorax
    [150669] = { source = SOURCE_ZONE,   effects = {  4, 21, 32, 38 } }, -- Chaurus Egg
    [139020] = { source = SOURCE_ZONE,   effects = {  7, 24, 26, 30 } }, -- Clam Gall
    [150671] = { source = SOURCE_ZONE,   effects = {  3, 16, 23, 31 } }, -- Dragon Rheum
    [150789] = { source = SOURCE_ZONE,   effects = { 22, 26, 29, 31 } }, -- Dragon's Bile
    [150731] = { source = SOURCE_ZONE,   effects = {  5, 27, 30, 31 } }, -- Dragon's Blood
    [139019] = { source = SOURCE_ZONE,   effects = { 23, 25, 29, 37 } }, -- Powdered Mother of Pearl
    [150670] = { source = SOURCE_ZONE,   effects = {  2,  3, 25, 32 } }, -- Vile Coagulant
    [224357] = { source = SOURCE_SPECIAL, effects = { 11, 31, 33, 37 } }, -- Cultivated Cryptpods
    [224358] = { source = SOURCE_SPECIAL, effects = { 12, 20, 30, 34 } }, -- Daedra-Blood Maggots
    [224359] = { source = SOURCE_SPECIAL, effects = {  5, 21, 31, 35 } }, -- Fossilized Verminous Bones
    [224360] = { source = SOURCE_SPECIAL, effects = {  8, 30, 34, 38 } }, -- Winter's Grave Tongue
}

-- Master writ field 10 is a solvent code, not an item ID. Master writs are CP150 and ask for 16.
Alchemy.MASTER_REQUIRED = 16
Alchemy.SOLVENTS = {
    [199] = { itemId = 64501, poison = false, crafts = 4 },  -- Lorkhan's Tears: 4 potions per craft
    [239] = { itemId = 75365, poison = true,  crafts = 1 },  -- Alkahest: 16 poisons per craft
}

-- Every solvent, lowest level first. Daily writs can ask you to acquire one (e.g. Lorkhan's Tears).
Alchemy.SOLVENT_ITEMS = {
    883, 1187, 4570, 23265, 23266, 23267, 23268, 64500, 64501,       -- Natural Water .. Lorkhan's Tears
    75357, 75358, 75359, 75360, 75361, 75362, 75363, 75364, 75365,   -- Grease .. Alkahest
}

-- Known Update 51 bug: this combination can't be crafted. Hold such writs until ZOS fixes it.
Alchemy.IMPOSSIBLE = { [12] = true, [21] = true, [24] = true }  -- Cowardice + Detection + Hindrance

-- How many of a reagent's four traits this character hasn't discovered yet (0 for anything
-- that isn't a reagent). Crafting with an undiscovered trait is limited to one batch at a time.
function Alchemy.UndiscoveredTraits(itemId)
    if not Alchemy.REAGENTS[itemId] then
        return 0
    end
    local link = WC.Inventory.GetLink(itemId)
    local unknown = 0
    for index = 1, GetMaxTraits() do
        local known = GetItemLinkReagentTraitInfo(link, index)
        if not known then
            unknown = unknown + 1
        end
    end
    return unknown
end

-- Which effects three reagents produce. Each effect pair is summed (+1 effect, -1 counter);
-- 2 or more on one side gives that effect, so opposing reagents cancel out.
function Alchemy.Combine(r1, r2, r3)
    local sums = {}
    for _, itemId in ipairs({ r1, r2, r3 }) do
        for _, effect in ipairs(Alchemy.REAGENTS[itemId].effects) do
            local base = effect % 2 == 1 and effect or effect - 1
            sums[base] = (sums[base] or 0) + (effect == base and 1 or -1)
        end
    end
    local result = {}
    for base, sum in pairs(sums) do
        if sum >= 2 then
            result[base] = true
        elseif sum <= -2 then
            result[base + 1] = true
        end
    end
    return result
end
