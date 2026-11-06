local WC = WritCrafter

-- /wc checkdata: compares WritCrafter's shipped tables with what the game itself says, so a
-- game update that changes reagent effects, rune or glyph IDs, or smithing items shows up in one
-- command instead of as failed writs. Run it after every major update.
local CheckData = {}
WC.CheckData = CheckData

local SHOWN = 10   -- problems listed per area unless debug chat messages are on

local function Name(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

local function Effects(set)
    local list = {}
    for effect in pairs(set) do
        list[#list + 1] = effect
    end
    table.sort(list)
    return list
end

local function Same(a, b)
    if #a ~= #b then
        return false
    end
    for i = 1, #a do
        if a[i] ~= b[i] then
            return false
        end
    end
    return true
end

local function Report(area, checked, skipped, problems)
    if #problems == 0 then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_OK, area, checked, skipped))
        return
    end
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_FAIL, area, #problems, checked))
    local showAll = WC.settings.logLevel >= WC.Log.LEVEL_DEBUG
    for i, text in ipairs(problems) do
        if i > SHOWN and not showAll then
            WC.Log.Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_MORE, #problems - SHOWN))
            break
        end
        WC.Log.Say("  " .. text)
    end
end

-- Alchemy: every pair of reagents you own, mixed with a solvent you own. The game predicts the
-- potion; its effects must be the ones the reagent table gives.
local function CheckAlchemy()
    local area = GetString(SI_WRITCRAFTER_CHECK_ALCHEMY)
    local solvents = WC.Inventory.OwnedItemIds({ [ITEMTYPE_POTION_BASE] = true, [ITEMTYPE_POISON_BASE] = true })
    local solventBag, solventSlot
    if solvents[1] then
        solventBag, solventSlot = WC.Inventory.FindForStation(solvents[1])
    end
    if not (solventBag and solventSlot) then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_NO_SOLVENT, area))
        return
    end
    local REAGENTS = WC.Data.Alchemy.REAGENTS
    local owned, missing = {}, 0
    for itemId in pairs(REAGENTS) do
        local bagId, slotIndex = WC.Inventory.FindForStation(itemId)
        if bagId then
            owned[#owned + 1] = { itemId = itemId, bag = bagId, slot = slotIndex }
        else
            missing = missing + 1
        end
    end
    table.sort(owned, function(a, b) return a.itemId < b.itemId end)

    -- Every pair is asked; "no potion" and "the game won't answer here" look the same (an empty
    -- link), so the results only count if the game made at least one potion.
    local results, answered = {}, false
    for i = 1, #owned do
        for j = i + 1, #owned do
            local a, b = owned[i], owned[j]
            local expected = Effects(WC.Data.Alchemy.Combine(a.itemId, b.itemId))
            if #expected <= 3 then   -- a potion holds at most three effects
                local link = GetAlchemyResultingItemLink(solventBag, solventSlot, a.bag, a.slot, b.bag, b.slot)
                local actual = (link and link ~= "") and WC.Reservations.PotionEffects(link) or {}
                answered = answered or #actual > 0
                results[#results + 1] = { a = a.itemId, b = b.itemId, expected = expected, actual = actual,
                    unknown = WC.Data.Alchemy.UndiscoveredTraits(a.itemId) + WC.Data.Alchemy.UndiscoveredTraits(b.itemId) > 0 }
            end
        end
    end
    if not answered then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_AT_STATION, area))
        return
    end
    -- Only pairs where something is made (by the table or the game) count as checks; pairs that
    -- share nothing on both sides prove nothing.
    -- The game won't predict a potion from a trait you haven't discovered (the station shows "?"),
    -- so an empty answer for a pair with an undiscovered trait is skipped, not a mismatch.
    local checked, problems, blame = 0, {}, {}
    local hidden, hiddenReagents = 0, {}
    local confirmed = {}
    for _, o in ipairs(owned) do
        confirmed[o.itemId] = {}
    end
    for _, r in ipairs(results) do
        if #r.actual == 0 and #r.expected > 0 and r.unknown then
            hidden = hidden + 1
            for _, itemId in ipairs({ r.a, r.b }) do
                if WC.Data.Alchemy.UndiscoveredTraits(itemId) > 0 then
                    hiddenReagents[itemId] = WC.Data.Alchemy.UndiscoveredTraits(itemId)
                end
            end
        elseif #r.expected > 0 or #r.actual > 0 then
            checked = checked + 1
            if Same(r.expected, r.actual) then
                -- With two reagents an effect only appears when both carry it: the game has now
                -- confirmed that effect for both.
                for _, effect in ipairs(r.expected) do
                    confirmed[r.a][effect] = true
                    confirmed[r.b][effect] = true
                end
            else
                problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_PAIR, Name(r.a), Name(r.b),
                    table.concat(r.expected, ", "), #r.actual > 0 and table.concat(r.actual, ", ") or "-")
                blame[r.a] = (blame[r.a] or 0) + 1
                blame[r.b] = (blame[r.b] or 0) + 1
            end
        end
    end
    -- The reagent in the most bad pairs is most likely the one whose effects changed.
    if #problems > 0 then
        local worst = {}
        for itemId, count in pairs(blame) do
            worst[#worst + 1] = { itemId = itemId, count = count }
        end
        table.sort(worst, function(x, y) return x.count > y.count end)
        local names = {}
        for k = 1, zo_min(3, #worst) do
            names[#names + 1] = zo_strformat("<<1>> (<<2>>)", Name(worst[k].itemId), worst[k].count)
        end
        table.insert(problems, 1, zo_strformat(SI_WRITCRAFTER_CHECK_SUSPECTS, table.concat(names, ", ")))
    end
    Report(area, checked, missing + hidden, problems)
    if hidden > 0 then
        local names = {}
        for itemId, count in pairs(hiddenReagents) do
            names[#names + 1] = zo_strformat("<<1>> (<<2>>)", Name(itemId), count)
        end
        table.sort(names)
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_UNDISCOVERED, hidden, table.concat(names, ", ")))
    end
    -- Coverage: how many of the table's reagent effects the game itself has confirmed. The rest
    -- are taken on trust: reagents you don't have, undiscovered traits, or effects no other
    -- reagent you own shares.
    local total, sure, unsure = 0, 0, {}
    local all = {}
    for itemId in pairs(REAGENTS) do
        all[#all + 1] = itemId
    end
    table.sort(all, function(x, y) return Name(x) < Name(y) end)
    for _, itemId in ipairs(all) do
        local open = 0
        for _, effect in ipairs(REAGENTS[itemId].effects) do
            total = total + 1
            if confirmed[itemId] and confirmed[itemId][effect] then
                sure = sure + 1
            else
                open = open + 1
            end
        end
        if open > 0 then
            unsure[#unsure + 1] = zo_strformat("<<1>> (<<2>>)", Name(itemId), open)
        end
    end
    WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_COVERAGE, sure, total))
    if #unsure > 0 then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_UNCONFIRMED, table.concat(unsure, ", ")))
    end
end

local RUNE_CLASS = {
    potency = ENCHANTING_RUNE_POTENCY, essence = ENCHANTING_RUNE_ESSENCE, aspect = ENCHANTING_RUNE_ASPECT,
}
local GLYPH_TYPES = {
    [ITEMTYPE_GLYPH_ARMOR] = true, [ITEMTYPE_GLYPH_WEAPON] = true, [ITEMTYPE_GLYPH_JEWELRY] = true,
}

-- Enchanting: every rune is still a rune of the right kind, every glyph a glyph, and where you
-- own the runes, the game makes exactly that glyph from them.
local function CheckEnchanting()
    local area = GetString(SI_WRITCRAFTER_CHECK_ENCHANTING)
    local E = WC.Data.Enchanting
    local problems, checked, skipped, made, unanswered = {}, 0, 0, 0, 0
    local function Rune(itemId, kind)
        checked = checked + 1
        if GetItemLinkEnchantingRuneClassification(WC.Inventory.GetLink(itemId)) ~= RUNE_CLASS[kind] then
            problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_NOT_RUNE, itemId, Name(itemId), kind)
        end
    end
    for _, level in pairs(E.LEVELS) do
        Rune(level.additive, "potency")
        Rune(level.subtractive, "potency")
    end
    for _, aspect in pairs(E.ASPECTS) do
        Rune(aspect, "aspect")
    end
    local aspect = E.ASPECTS[4]
    local level = E.LEVELS[207]
    for glyphId, glyph in pairs(E.GLYPHS) do
        Rune(glyph.essence, "essence")
        checked = checked + 1
        if not GLYPH_TYPES[GetItemLinkItemType(WC.Inventory.GetLink(glyphId))] then
            problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_NOT_GLYPH, glyphId, Name(glyphId))
        else
            local potency = glyph.additive and level.additive or level.subtractive
            local p = { WC.Inventory.FindForStation(potency) }
            local e = { WC.Inventory.FindForStation(glyph.essence) }
            local a = { WC.Inventory.FindForStation(aspect) }
            if p[1] and e[1] and a[1] then
                local link = GetEnchantingResultingItemLink(p[1], p[2], e[1], e[2], a[1], a[2])
                local resultId = link and link ~= "" and GetItemLinkItemId(link) or 0
                if resultId == 0 then
                    unanswered = unanswered + 1
                else
                    made = made + 1
                    checked = checked + 1
                    if resultId ~= glyphId then
                        problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_GLYPH_RESULT, Name(potency),
                            Name(glyph.essence), Name(glyphId), Name(resultId))
                    end
                end
            else
                skipped = skipped + 1
            end
        end
    end
    Report(area, checked, skipped + unanswered, problems)
    if unanswered > 0 and made == 0 then
        WC.Log.Say(zo_strformat(SI_WRITCRAFTER_CHECK_GLYPH_STATION, unanswered))
    end
end

local MATERIAL_TYPE = {
    [CRAFTING_TYPE_BLACKSMITHING]   = ITEMTYPE_BLACKSMITHING_MATERIAL,
    [CRAFTING_TYPE_CLOTHIER]        = ITEMTYPE_CLOTHIER_MATERIAL,
    [CRAFTING_TYPE_WOODWORKING]     = ITEMTYPE_WOODWORKING_MATERIAL,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = ITEMTYPE_JEWELRYCRAFTING_MATERIAL,
}
local BOOSTER_TYPE = {
    [CRAFTING_TYPE_BLACKSMITHING]   = ITEMTYPE_BLACKSMITHING_BOOSTER,
    [CRAFTING_TYPE_CLOTHIER]        = ITEMTYPE_CLOTHIER_BOOSTER,
    [CRAFTING_TYPE_WOODWORKING]     = ITEMTYPE_WOODWORKING_BOOSTER,
    [CRAFTING_TYPE_JEWELRYCRAFTING] = ITEMTYPE_JEWELRYCRAFTING_BOOSTER,
}

-- Smithing: each master writ item's sample is made by the right craft, its base material is
-- that craft's material, and the improvement materials are that craft's, in order.
local function CheckSmithing()
    local area = GetString(SI_WRITCRAFTER_CHECK_SMITHING)
    local S = WC.Data.Smithing
    local problems, checked = {}, 0
    for templateId, t in pairs(S.TEMPLATES) do
        checked = checked + 1
        local sample = WC.Inventory.GetLink(t.sample)
        local mat = WC.Inventory.GetLink(t.mat)
        local craftName = zo_strformat("<<1>>", GetCraftingSkillName(t.craft))
        if GetItemLinkCraftingSkillType(sample) ~= t.craft then
            problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_TEMPLATE, templateId, Name(t.sample), craftName)
        elseif GetItemLinkItemType(mat) ~= MATERIAL_TYPE[t.craft] then
            problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_TEMPLATE_MAT, templateId, Name(t.mat), craftName)
        end
    end
    for craft, ids in pairs(S.IMPROVE_MATS) do
        for tier, itemId in ipairs(ids) do
            checked = checked + 1
            local link = WC.Inventory.GetLink(itemId)
            if GetItemLinkItemType(link) ~= BOOSTER_TYPE[craft]
                or GetItemLinkFunctionalQuality(link) ~= tier + 1 then
                problems[#problems + 1] = zo_strformat(SI_WRITCRAFTER_CHECK_BOOSTER, itemId, Name(itemId),
                    zo_strformat("<<1>>", GetCraftingSkillName(craft)), tier)
            end
        end
    end
    Report(area, checked, 0, problems)
end

function CheckData.Run()
    WC.Log.Say(GetString(SI_WRITCRAFTER_CHECK_HEADER))
    CheckAlchemy()
    CheckEnchanting()
    CheckSmithing()
end
