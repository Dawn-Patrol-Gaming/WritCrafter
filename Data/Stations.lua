local WC = WritCrafter
WC.Data = WC.Data or {}

-- Crafting-station furnishings, by item ID, from UESP's "Furnishings by Behavior/Crafting Station"
-- list (checked 2026-11-10). Their names often don't say the craft ("Maormer Cookfire", "Solitude
-- Grill", "Hagraven Altar, Alchemical"), so in a house each placed station is looked up here by
-- its furniture ID first (worked out from these item IDs in game; the same in every language),
-- then by name, then by what you've used. Attuned set stations aren't listed: their names carry
-- the set ("Blacksmithing Station (Law of Julianos)"). New furnishings: add their item ID here.
local Stations = {}
WC.Data.Stations = Stations

local BS, CL, WW, JW = CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING, CRAFTING_TYPE_JEWELRYCRAFTING
local AL, EN, PR = CRAFTING_TYPE_ALCHEMY, CRAFTING_TYPE_ENCHANTING, CRAFTING_TYPE_PROVISIONING

-- [itemId] = { craft, gm = true for a Grand Master station }
Stations.FURNISHINGS = {
    -- Alchemy
    [118328] = { craft = AL },   -- Alchemy Station
    [134278] = { craft = AL },   -- Clockwork Alchemy Station
    [130220] = { craft = AL },   -- Hagraven Altar, Alchemical
    [197705] = { craft = AL },   -- Telvanni Alchemy Station
    -- Enchanting
    [118330] = { craft = EN },   -- Enchanting Station
    [134280] = { craft = EN },   -- Clockwork Enchanting Station
    [182302] = { craft = EN },   -- Daedric Enchanting Station
    -- Provisioning
    [118327] = { craft = PR },   -- Provisioning Station
    [134277] = { craft = PR },   -- Clockwork Provisioning Station
    [184102] = { craft = PR },   -- Blackwood Provisioning Station
    [187802] = { craft = PR },   -- Druidic Provisioning Station
    [193809] = { craft = PR },   -- Druidic Oven, Stone
    [226743] = { craft = PR },   -- Firepit Provisioning Station
    [192409] = { craft = PR },   -- Maormer Cookfire
    [223131] = { craft = PR },   -- New Life Provisioning Station
    [153656] = { craft = PR },   -- Provisioning Station, Elsweyr Grill
    [171409] = { craft = PR },   -- Provisioning Station, Solitude Grill
    [204456] = { craft = PR },   -- Redguard Oven, Clay
    [146050] = { craft = PR },   -- Winter Festival Hearthfire
    [130215] = { craft = PR },   -- Witches' Cauldron, Provisioning
    -- Grand Master stations (their sets come from WC.GrandMaster)
    [203555] = { craft = BS, gm = true },   -- Grand Master Blacksmithing Station
    [203553] = { craft = CL, gm = true },   -- Grand Master Clothing Station
    [203554] = { craft = WW, gm = true },   -- Grand Master Woodworking Station
    [203556] = { craft = JW, gm = true },   -- Grand Master Jewelry Crafting Station
    -- Plain smithing stations (no set: daily writs only, which the game marks itself)
    [119781] = { craft = BS },   -- Blacksmithing Station
    [134279] = { craft = BS },   -- Clockwork Blacksmithing Station
    [204420] = { craft = BS },   -- Ayleid Blacksmithing Station
    [219871] = { craft = BS },   -- Cult Blacksmithing Station
    [161204] = { craft = BS },   -- Anvil of Old Orsinium
    [119707] = { craft = CL },   -- Clothing Station
    [134281] = { craft = CL },   -- Clockwork Clothing Station
    [199118] = { craft = CL },   -- Apocryphal Clothier Station
    [119744] = { craft = WW },   -- Woodworking Station
    [134282] = { craft = WW },   -- Clockwork Woodworking Station
    [192432] = { craft = WW },   -- Shipbuilder's Crafting Station
    [137870] = { craft = JW },   -- Jewelry Crafting Station
    [208128] = { craft = JW },   -- Apocrypha Jewelry Crafting Station
}

-- The same, keyed by furniture ID (what a placed furnishing reports), worked out once.
local byFurniture
function Stations.ByFurnitureId(furnitureDataId)
    if not byFurniture then
        byFurniture = {}
        for itemId, info in pairs(Stations.FURNISHINGS) do
            local link = string.format("|H0:item:%d:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0:0|h|h", itemId)
            local dataId = GetItemLinkFurnitureDataId(link)
            if dataId and dataId ~= 0 then
                byFurniture[dataId] = info
            end
        end
    end
    return byFurniture[furnitureDataId]
end
