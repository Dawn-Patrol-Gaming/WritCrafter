local WC = WritCrafter

-- Station sounds: the three rune-placed sounds, then the glow on completion, plus the three
-- spoken rune names. The game only speaks the runes slotted in its own Creation screen (it
-- re-reads them when a craft starts, so setting them on the station doesn't stick), and
-- WritCrafter crafts without slotting anything, so it always plays the names itself through
-- its own queued player, one after another, on any tab.
local runeVoices = ZO_QueuedSoundPlayer:New()

local function RuneSounds(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    WC.Engine.CraftSounds({ SOUNDS.ENCHANTING_POTENCY_RUNE_PLACED, SOUNDS.ENCHANTING_ESSENCE_RUNE_PLACED,
        SOUNDS.ENCHANTING_ASPECT_RUNE_PLACED }, SOUNDS.ENCHANTING_CREATE_TOOLTIP_GLOW)
    if not WC.settings.soundRunes then
        return
    end
    local sounds = {}
    for _, slot in ipairs({ { pBag, pSlot }, { eBag, eSlot }, { aBag, aSlot } }) do
        local sound, length = GetRunestoneSoundInfo(slot[1], slot[2])
        if sound and sound ~= "" and length then
            sounds[#sounds + 1] = { sound, length }
        end
    end
    if #sounds < 3 then
        WC.Log.Debug("Rune names: the game gave no sound for one of the runes")
        return
    end
    runeVoices:ForceStop()
    for _, entry in ipairs(sounds) do
        runeVoices:PlaySound(entry[1], entry[2])
    end
end

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

-- Enchanting: the writ's potency rune (additive or subtractive for its level), essence rune
-- and aspect rune (from the quality). One glyph per batch. The resulting glyph is checked
-- against the writ before anything is spent, and runes you haven't translated yet are crafted
-- one batch at a time (the game's rule; the first craft translates them).
local function CraftEnchanting(writ, status)
    local glyph, level = writ.glyph, writ.level
    local aspect = WC.Data.Enchanting.ASPECTS[writ.quality]
    if not (glyph and level and aspect) then
        return false, zo_strformat(SI_WRITCRAFTER_REASON_UNKNOWN_ITEM, writ.glyphId or 0)
    end
    local potency = glyph.additive and level.additive or level.subtractive
    local slots = {}
    for _, itemId in ipairs({ potency, glyph.essence, aspect }) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if not bagId then
            return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(itemId))
        end
        slots[#slots + 1] = bagId
        slots[#slots + 1] = slotIndex
    end
    local pBag, pSlot, eBag, eSlot, aBag, aSlot = unpack(slots)

    local resultLink = GetEnchantingResultingItemLink(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    if not resultLink or resultLink == "" or not WC.Reservations.Matches(resultLink, writ) then
        return false, GetString(SI_WRITCRAFTER_CRAFT_WRONG_RESULT)
    end

    local iterations = status.required - status.have
    local maxIterations, result = GetMaxIterationsPossibleForEnchantingItem(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    iterations = zo_min(iterations, maxIterations)
    if not AreAllEnchantingRunesKnown(pBag, pSlot, eBag, eSlot, aBag, aSlot) then
        iterations = 1
    end

    WC.Engine.SayCrafting(iterations, resultLink, {
        { itemId = potency, count = iterations },
        { itemId = glyph.essence, count = iterations },
        { itemId = aspect, count = iterations },
    })
    RuneSounds(pBag, pSlot, eBag, eSlot, aBag, aSlot)
    CraftEnchantingItem(pBag, pSlot, eBag, eSlot, aBag, aSlot, iterations)
    return true
end

WC.Engine.RegisterCrafter(WC.Master.KIND_ENCHANTING, CraftEnchanting)

-- Daily enchanting writs ---------------------------------------------------------------------
-- A condition names a glyph ("Craft a Glyph of Health"); the game says which rune combination
-- makes one that fulfils it. Found once per condition with your cheapest aspect; at craft time
-- the cheapest allowed aspect that still satisfies the quest is used.

local ASPECT_ORDER = { 45850, 45851, 45852, 45853, 45854 }   -- Ta, Jejota, Denata, Rekuta, Kuta

local function Locations(itemIds)
    local where = {}
    for _, itemId in ipairs(itemIds) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if bagId then
            where[itemId] = { bagId, slotIndex }
        end
    end
    return where
end

local function GlyphLink(where, potency, essence, aspect)
    local p, e, a = where[potency], where[essence], where[aspect]
    if p and e and a then
        return (GetEnchantingResultingItemLink(p[1], p[2], e[1], e[2], a[1], a[2]))
    end
end

local function OwnedAspects()
    local owned = {}
    for _, aspect in ipairs(ASPECT_ORDER) do
        local _, _, total = WC.Inventory.FindForStation(aspect)
        if total > 0 then
            owned[#owned + 1] = aspect
        end
    end
    return owned
end

-- The aspect rune a condition names ("... With Ta"), or nil. Aspect names are Daedric words, the
-- same in every game language, so this also tells enchanting conditions apart from other crafts'.
local function AspectNamed(text)
    for _, aspect in ipairs(ASPECT_ORDER) do
        local name = zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(aspect)))
        if name ~= "" and text:find("%f[%w]" .. name .. "%f[%W]") then
            return aspect
        end
    end
end

-- The essence rune of the glyph a condition names, from the glyph names the game gives (the
-- longest match wins, so "Glyph of Health Recovery" isn't taken for "Glyph of Health").
local function EssenceNamed(text)
    local best, bestLength
    for glyphId, glyph in pairs(WC.Data.Enchanting.GLYPHS) do
        local name = zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(glyphId)))
        -- Base glyph names may carry a potency word ("Trifling Glyph of ..."); try without it too.
        for _, candidate in ipairs({ name, (name:gsub("^%S+%s+", "", 1)) }) do
            if #candidate > 0 and text:find(candidate, 1, true) and (not bestLength or #candidate > bestLength) then
                best, bestLength = glyph.essence, #candidate
            end
        end
    end
    return best
end

-- Why no rune combination you have makes the glyph: names the missing aspect or essence rune
-- when it can tell, otherwise points at the potency rune.
local function MissingRune(condition, aspect)
    local missing = {}
    if aspect and not WC.Inventory.FindForStation(aspect) then
        missing[#missing + 1] = ItemName(aspect)
    end
    local essence = EssenceNamed(condition.text)
    if essence and not WC.Inventory.FindForStation(essence) then
        missing[#missing + 1] = ItemName(essence)
    end
    if #missing > 0 then
        return { problem = zo_strformat(SI_WRITCRAFTER_DAILY_RUNE_MISSING, table.concat(missing, ", ")) }
    end
    return { problem = GetString(SI_WRITCRAFTER_DAILY_RUNE_UNKNOWN) }
end

local function ResolveDaily(condition)
    local wanted = AspectNamed(condition.text)
    local aspects = OwnedAspects()
    -- Search with the aspect the condition names when you have it, else your cheapest.
    local aspect = (wanted and WC.Inventory.FindForStation(wanted)) and wanted or aspects[1]
    if aspect then
        local potencies = WC.Inventory.OwnedItemIds({ [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = true })
        local essences = WC.Inventory.OwnedItemIds({ [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = true })
        local all = { aspect }
        for _, id in ipairs(potencies) do all[#all + 1] = id end
        for _, id in ipairs(essences) do all[#all + 1] = id end
        local where = Locations(all)
        for _, potency in ipairs(potencies) do
            for _, essence in ipairs(essences) do
                if WC.Daily.Fulfils(GlyphLink(where, potency, essence, aspect), condition) then
                    return { potency = potency, essence = essence }
                end
            end
        end
    end
    -- Nothing you have makes it. Only an enchanting condition (one naming an aspect) is reported;
    -- other crafts' conditions are none of this station's business.
    if wanted then
        return MissingRune(condition, wanted)
    end
end

local function CraftDaily(condition, plan)
    local Policy = WC.Policy
    for _, itemId in ipairs({ plan.potency, plan.essence }) do
        if Policy.IsExpensive(itemId) then
            return false, zo_strformat(SI_WRITCRAFTER_REASON_EXPENSIVE, ItemName(itemId))
        end
    end
    local where = Locations({ plan.potency, plan.essence, unpack(ASPECT_ORDER) })
    for _, itemId in ipairs({ plan.potency, plan.essence }) do
        if not where[itemId] then
            return false, zo_strformat(SI_WRITCRAFTER_CRAFT_MISSING, ItemName(itemId))
        end
    end
    -- Cheapest allowed aspect whose glyph the quest accepts.
    local aspect, resultLink
    local excludedAspect
    for _, candidate in ipairs(ASPECT_ORDER) do
        local link = GlyphLink(where, plan.potency, plan.essence, candidate)
        if WC.Daily.Fulfils(link, condition) then
            if Policy.IsExpensive(candidate) then
                excludedAspect = excludedAspect or candidate
            else
                aspect, resultLink = candidate, link
                break
            end
        end
    end
    if not aspect then
        if excludedAspect then
            return false, zo_strformat(SI_WRITCRAFTER_REASON_EXPENSIVE, ItemName(excludedAspect))
        end
        return false, GetString(SI_WRITCRAFTER_CRAFT_NO_RUNES)
    end
    local p, e, a = where[plan.potency], where[plan.essence], where[aspect]
    local maxIterations, result = GetMaxIterationsPossibleForEnchantingItem(p[1], p[2], e[1], e[2], a[1], a[2])
    if not maxIterations or maxIterations == 0 then
        return false, GetString("SI_TRADESKILLRESULT", result)
    end
    local iterations = zo_min(condition.max - condition.current, maxIterations)
    if not AreAllEnchantingRunesKnown(p[1], p[2], e[1], e[2], a[1], a[2]) then
        iterations = 1
    end
    WC.Engine.SayCrafting(iterations, resultLink, {
        { itemId = plan.potency, count = iterations },
        { itemId = plan.essence, count = iterations },
        { itemId = aspect, count = iterations },
    })
    RuneSounds(p[1], p[2], e[1], e[2], a[1], a[2])
    CraftEnchantingItem(p[1], p[2], e[1], e[2], a[1], a[2], iterations)
    return true
end

WC.Daily.RegisterCraft(CRAFTING_TYPE_ENCHANTING, ResolveDaily, CraftDaily, true)
