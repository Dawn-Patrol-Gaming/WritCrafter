local WC = WritCrafter

local Tooltip = {}
WC.Tooltip = Tooltip

local GREEN, ORANGE, RED, GREY, GOLD = "40C040", "FF9933", "FF5050", "A0A0A0", "E0B060"

local function Color(hex, text)
    return string.format("|c%s%s|r", hex, text)
end

local function ItemName(itemId)
    return zo_strformat("<<t:1>>", GetItemLinkName(WC.Inventory.GetLink(itemId)))
end

-- uid is known only for writs in your bags; it adds the "already crafted" line.
local function AddWritLines(control, link, uid)
    if not WC.settings.tooltip then
        return
    end
    local writ = WC.Master.Parse(link)
    if not writ then
        return
    end
    local verdict = WC.Rules.Evaluate(writ)
    local Rules = WC.Rules

    local status
    local crafted = uid and WC.Reservations.GetWritStatus(uid)
    if crafted and crafted.crafted then
        status = Color(GREEN, GetString(SI_WRITCRAFTER_TT_CRAFTED))
    elseif verdict.status == Rules.OK then
        status = Color(GREEN, GetString(SI_WRITCRAFTER_TT_OK))
    elseif verdict.status == Rules.REJECTED then
        status = Color(ORANGE, GetString(SI_WRITCRAFTER_TT_REJECTED))
    else
        status = Color(RED, GetString(SI_WRITCRAFTER_TT_CANNOT))
    end
    -- Writs that need several items (alchemy, provisioning) always say how many.
    if not (crafted and crafted.crafted) and writ.required > 1 then
        local have = crafted and crafted.have or 0
        if have > 0 then
            status = status .. Color(GREY, zo_strformat(SI_WRITCRAFTER_TT_PARTIAL, have, writ.required))
        else
            status = status .. Color(GREY, zo_strformat(SI_WRITCRAFTER_TT_NEEDED, writ.required))
        end
    end

    ZO_Tooltip_AddDivider(control)
    control:AddLine(Color(GOLD, WC.displayName) .. ": " .. status)
    -- Where the items set aside for this writ are, e.g. "Set aside: 12 in bank, 4 in backpack".
    if crafted and crafted.have > 0 then
        local places = {}
        if crafted.inBackpack > 0 then
            places[#places + 1] = zo_strformat(SI_WRITCRAFTER_TT_IN_BACKPACK, crafted.inBackpack)
        end
        if crafted.inBank > 0 then
            places[#places + 1] = zo_strformat(SI_WRITCRAFTER_TT_IN_BANK, crafted.inBank)
        end
        control:AddLine(Color(GREY, zo_strformat(SI_WRITCRAFTER_TT_SET_ASIDE, table.concat(places, ", "))))
    end
    if uid and WC.Queue.Has(uid) then
        control:AddLine(Color(GOLD, zo_strformat(SI_WRITCRAFTER_TT_QUEUED,
            zo_strformat("<<1>>", GetCraftingSkillName(writ.craft)))))
    end
    local reasonColor = verdict.status == Rules.CANNOT and RED or ORANGE
    for _, reason in ipairs(verdict.reasons) do
        control:AddLine(Color(reasonColor, reason))
    end
    if verdict.status == Rules.OK and not (crafted and crafted.have > 0) then
        local short = {}
        for _, mat in ipairs(Rules.Shortages(writ)) do
            short[#short + 1] = zo_strformat(SI_WRITCRAFTER_TT_SHORT_ITEM, ItemName(mat.itemId), mat.have, mat.need)
        end
        if #short > 0 then
            control:AddLine(Color(ORANGE, zo_strformat(SI_WRITCRAFTER_TT_SHORT, table.concat(short, ", "))))
        end
    end
    for _, note in ipairs(verdict.notes) do
        control:AddLine(Color(GREY, note))
    end

    if WC.settings.tooltipMaterials and #verdict.materials > 0 then
        local lines = {}
        for _, mat in ipairs(verdict.materials) do
            local have = WC.Inventory.GetStock(mat.itemId).usable
            local color = have >= mat.count and GREY or ORANGE
            local line = Color(color, zo_strformat(SI_WRITCRAFTER_TT_MATERIAL, mat.count, ItemName(mat.itemId), have))
            local unknown = WC.Data.Alchemy.UndiscoveredTraits(mat.itemId)
            if unknown > 0 then
                line = line .. Color(ORANGE, zo_strformat(SI_WRITCRAFTER_TT_UNDISCOVERED, unknown))
            end
            lines[#lines + 1] = line
        end
        control:AddLine(table.concat(lines, "\n"))
    end

    if verdict.cost > 0 then
        local stringId = verdict.costComplete and SI_WRITCRAFTER_TT_COST or SI_WRITCRAFTER_TT_COST_PARTIAL
        local line = zo_strformat(stringId, WC.Price.Format(verdict.cost), writ.vouchers)
        if verdict.perVoucher then
            line = line .. zo_strformat(SI_WRITCRAFTER_TT_PER_VOUCHER, WC.Price.Format(verdict.perVoucher))
        end
        control:AddLine(Color(GREY, line))
    end
end

local function HookTradingHouse()
    ZO_PostHook(ItemTooltip, "SetTradingHouseItem", function(control, index)
        AddWritLines(control, GetTradingHouseSearchResultItemLink(index))
    end)
end

function Tooltip.Init()
    ZO_PostHook(ItemTooltip, "SetBagItem", function(control, bagId, slotIndex)
        local link = GetItemLink(bagId, slotIndex)
        if WC.Master.Parse(link) then
            AddWritLines(control, link, WC.Master.UniqueId(bagId, slotIndex))
            return
        end
        local quest = WC.DailyItems.QuestFor(bagId, slotIndex)
        if quest then
            control:AddLine(Color(GOLD, WC.displayName) .. ": " .. zo_strformat(SI_WRITCRAFTER_TT_DAILY_ITEM, quest))
            return
        end
        quest = WC.Reservations.AcceptedQuestFor(bagId, slotIndex)
        if quest then
            control:AddLine(Color(GOLD, WC.displayName) .. ": " .. zo_strformat(SI_WRITCRAFTER_TT_ACCEPTED_ITEM, quest))
        end
    end)
    ZO_PostHook(ItemTooltip, "SetLootItem", function(control, lootId)
        AddWritLines(control, GetLootItemLink(lootId))
    end)
    ZO_PostHook(PopupTooltip, "SetLink", function(control, link)
        AddWritLines(control, link)
    end)
    -- AwesomeGuildStore replaces the guild store tooltip during its own setup, which would
    -- drop a hook installed earlier.
    if AwesomeGuildStore then
        AwesomeGuildStore:RegisterCallback(AwesomeGuildStore.callback.AFTER_INITIAL_SETUP, HookTradingHouse)
    else
        HookTradingHouse()
    end
end
