local WC = WritCrafter

local Master = {}
WC.Master = Master

Master.KIND_SMITHING     = "smithing"
Master.KIND_ENCHANTING   = "enchanting"
Master.KIND_ALCHEMY      = "alchemy"
Master.KIND_PROVISIONING = "provisioning"

Master.PROVISIONING_REQUIRED = 8

-- The sealed writ's icon is the most reliable way to tell the seven crafts apart.
local CRAFT_BY_ICON = {
    ["/esoui/art/icons/master_writ_blacksmithing.dds"] = CRAFTING_TYPE_BLACKSMITHING,
    ["/esoui/art/icons/master_writ_clothier.dds"]      = CRAFTING_TYPE_CLOTHIER,
    ["/esoui/art/icons/master_writ_woodworking.dds"]   = CRAFTING_TYPE_WOODWORKING,
    ["/esoui/art/icons/master_writ_jewelry.dds"]       = CRAFTING_TYPE_JEWELRYCRAFTING,
    ["/esoui/art/icons/master_writ_enchanting.dds"]    = CRAFTING_TYPE_ENCHANTING,
    ["/esoui/art/icons/master_writ_alchemy.dds"]       = CRAFTING_TYPE_ALCHEMY,
    ["/esoui/art/icons/master_writ_provisioning.dds"]  = CRAFTING_TYPE_PROVISIONING,
}

local KIND_BY_CRAFT = {
    [CRAFTING_TYPE_BLACKSMITHING]   = Master.KIND_SMITHING,
    [CRAFTING_TYPE_CLOTHIER]        = Master.KIND_SMITHING,
    [CRAFTING_TYPE_WOODWORKING]     = Master.KIND_SMITHING,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = Master.KIND_SMITHING,
    [CRAFTING_TYPE_ENCHANTING]      = Master.KIND_ENCHANTING,
    [CRAFTING_TYPE_ALCHEMY]         = Master.KIND_ALCHEMY,
    [CRAFTING_TYPE_PROVISIONING]    = Master.KIND_PROVISIONING,
}

-- [link] = parsed writ, or false for "not a master writ we understand"
local cache = {}

-- The game's own writ text says how many to make ("Craft 1 Rubedite Axe"). Language
-- independent because only the digits are read.
local function RequiredCount(link, fallback)
    local text = GenerateMasterWritBaseText(link) or ""
    for digits in text:gmatch("%d+") do
        local n = tonumber(digits)
        if n and n > 0 and n <= 100 then
            return n
        end
    end
    return fallback
end

local function ParseFields(link)
    -- Fields after the link type: 4 = item ID, 10-15 = the six writ fields, 24 = reward.
    local f = { ZO_LinkHandler_ParseLink(link) }
    return {
        f10 = tonumber(f[10]) or 0,
        f11 = tonumber(f[11]) or 0,
        f12 = tonumber(f[12]) or 0,
        f13 = tonumber(f[13]) or 0,
        f14 = tonumber(f[14]) or 0,
        f15 = tonumber(f[15]) or 0,
        reward = tonumber(f[24]) or 0,
    }
end

local function Build(link)
    if GetItemLinkItemType(link) ~= ITEMTYPE_MASTER_WRIT then
        return nil
    end
    local craft = CRAFT_BY_ICON[GetItemLinkInfo(link)]
    if not craft then
        return nil   -- holiday writs and anything new
    end
    local f = ParseFields(link)
    local writ = {
        link     = link,
        craft    = craft,
        kind     = KIND_BY_CRAFT[craft],
        vouchers = zo_round(f.reward / 10000),
    }
    if writ.kind == Master.KIND_SMITHING then
        writ.templateId = f.f10
        writ.template   = WC.Data.Smithing.TEMPLATES[f.f10]
        writ.quality    = f.f12
        writ.setId      = f.f13
        writ.trait      = f.f14
        writ.style      = f.f15
        writ.required   = RequiredCount(link, 1)
    elseif writ.kind == Master.KIND_ENCHANTING then
        writ.glyphId  = f.f10
        writ.glyph    = WC.Data.Enchanting.GLYPHS[f.f10]
        writ.level    = WC.Data.Enchanting.LEVELS[f.f11]
        writ.quality  = f.f12
        writ.required = RequiredCount(link, 1)
    elseif writ.kind == Master.KIND_ALCHEMY then
        local Alchemy = WC.Data.Alchemy
        writ.solvent  = Alchemy.SOLVENTS[f.f10]
        writ.effects  = { Alchemy.Normalize(f.f11), Alchemy.Normalize(f.f12), Alchemy.Normalize(f.f13) }
        writ.required = RequiredCount(link, Alchemy.MASTER_REQUIRED)
    else
        writ.resultId = f.f10
        -- The sealed text ("Craft a Longfin Pasty…") gives no number, but the quest asks for 8,
        -- two batches of four with the provisioning quantity passives (as WritWorthy and
        -- Dolgubon's craft it).
        writ.required = RequiredCount(link, Master.PROVISIONING_REQUIRED)
    end
    return writ
end

-- Returns the parsed writ for a sealed master writ link, or nil.
function Master.Parse(link)
    if not link or link == "" then
        return nil
    end
    local hit = cache[link]
    if hit == nil then
        hit = Build(link) or false
        cache[link] = hit
    end
    return hit or nil
end

-- Stable per-item key, so state survives the writ moving between bag and bank.
function Master.UniqueId(bagId, slotIndex)
    return Id64ToString(GetItemUniqueId(bagId, slotIndex))
end
