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

-- The writ for an accepted master writ quest's condition (the sealed writ is used up when it's
-- accepted), built from the quest's own details, or nil. GetQuestConditionMasterWritInfo returns
-- the sealed writ's fields: item ID (glyph, food or potion; 0 for gear), material (enchanting level,
-- alchemy solvent), craft, quality, item template, set, trait, style, and the alchemy effects
-- packed one per byte. required is the quest's own count.
function Master.ReadInfo(questIndex, stepIndex, conditionIndex)
    local itemId, materialId, craft, quality, templateId, setId, trait, style, encodedEffects =
        GetQuestConditionMasterWritInfo(questIndex, stepIndex, conditionIndex)
    return {
        itemId = itemId or 0, materialId = materialId or 0, craft = craft or 0, quality = quality or 0,
        templateId = templateId or 0, setId = setId or 0, trait = trait or 0, style = style or 0,
        effects = encodedEffects or 0,
    }
end

-- Whether the game gave master writ details for a condition at all (a craft, or an item). Also
-- true for writs WritCrafter can't craft (e.g. holiday writs), whose tasks aren't daily ones.
function Master.IsWritInfo(info)
    return info.itemId ~= 0 or info.craft ~= 0
end

local function FromInfo(info, required)
    local itemId, materialId, craft, quality = info.itemId, info.materialId, info.craft, info.quality
    local templateId, setId, trait, style = info.templateId, info.setId, info.trait, info.style
    local encodedEffects = info.effects
    local kind = KIND_BY_CRAFT[craft]
    if not kind then
        return nil
    end
    -- Smithing writs name a template and no item; the others name the item.
    if kind == Master.KIND_SMITHING then
        if not templateId or templateId == 0 then
            return nil
        end
    elseif not itemId or itemId == 0 then
        return nil
    end
    local writ = { craft = craft, kind = kind, required = required, vouchers = 0 }
    if kind == Master.KIND_SMITHING then
        writ.templateId = templateId
        writ.template   = WC.Data.Smithing.TEMPLATES[templateId]
        writ.quality    = quality
        writ.setId      = setId
        writ.trait      = trait
        writ.style      = style
    elseif kind == Master.KIND_ENCHANTING then
        writ.glyphId = itemId
        writ.glyph   = WC.Data.Enchanting.GLYPHS[itemId]
        writ.level   = WC.Data.Enchanting.LEVELS[materialId]
        writ.quality = quality
    elseif kind == Master.KIND_ALCHEMY then
        local Alchemy = WC.Data.Alchemy
        local packed = encodedEffects or 0
        writ.solvent = Alchemy.SOLVENTS[materialId]
        writ.effects = {
            Alchemy.Normalize(zo_floor(packed / 65536) % 64),
            Alchemy.Normalize(zo_floor(packed / 256) % 64),
            Alchemy.Normalize(packed % 64),
        }
    else
        writ.resultId = itemId
    end
    return writ
end

Master.FromInfo = FromInfo

-- Accepted master writ quests in the journal: { quest, writ, condition }, where condition is the
-- craft task while it's still to do (as in WC.Daily.Conditions) and nil once the quest has moved
-- on to delivery. That task leaves the journal when it's done, so each writ's details are
-- remembered per character (by quest name: only one master writ of each kind can be accepted)
-- and its items keep their badge until it's turned in. Worked out once per journal read.
local acceptedList, acceptedGeneration
local searched = {}   -- [quest] = true: no remembered details, and its hidden tasks had none

function Master.Accepted()
    local generation = WC.Daily.Generation()
    if acceptedList and acceptedGeneration == generation then
        return acceptedList
    end
    local saved = WC.character.acceptedWrits or {}
    WC.character.acceptedWrits = saved
    local craftTasks = {}
    for _, condition in ipairs(WC.Daily.Conditions(true)) do
        if condition.writ then
            craftTasks[condition.quest] = condition
        end
    end
    local list, added = {}, false
    for _, entry in ipairs(WC.Daily.Quests()) do
        local quest, questIndex = entry.quest, entry.questIndex
        local condition = craftTasks[quest]
        if condition then
            added = added or not saved[quest]
            saved[quest] = { info = condition.info, required = condition.max }
        elseif not saved[quest] and not searched[quest] then
            -- Accepted before WritCrafter remembered it: a finished task may still carry the
            -- details even though it's no longer shown. Looked for once per quest.
            searched[quest] = true
            for stepIndex = 1, GetJournalQuestNumSteps(questIndex) do
                for conditionIndex = 1, GetJournalQuestNumConditions(questIndex, stepIndex) do
                    if not saved[quest] then
                        local info = Master.ReadInfo(questIndex, stepIndex, conditionIndex)
                        local _, _, max = GetJournalQuestConditionInfo(questIndex, stepIndex, conditionIndex)
                        local required = (max and max > 0) and max or 1
                        if FromInfo(info, required) then
                            saved[quest] = { info = info, required = required }
                            added = true
                        end
                    end
                end
            end
        end
        local record = saved[quest]
        local writ = condition and condition.writ or (record and FromInfo(record.info, record.required))
        if writ then
            list[#list + 1] = { quest = quest, writ = writ, condition = condition }
        end
    end
    if added then
        WC.Daily.MasterQuestsChanged()
    end
    acceptedList, acceptedGeneration = list, generation
    return list
end

-- Turned in or abandoned: forget it. A new quest may be looked for again.
function Master.OnJournalChanged(event, ...)
    if event == EVENT_QUEST_REMOVED then
        local questName = select(3, ...)
        if WC.character.acceptedWrits then
            WC.character.acceptedWrits[questName] = nil
        end
        searched[questName] = nil
    elseif event == EVENT_QUEST_ADDED then
        ZO_ClearTable(searched)
    end
end

-- Stable per-item key, so state survives the writ moving between bag and bank.
function Master.UniqueId(bagId, slotIndex)
    return Id64ToString(GetItemUniqueId(bagId, slotIndex))
end
