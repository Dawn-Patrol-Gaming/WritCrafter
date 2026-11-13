local WC = WritCrafter

-- The material exclusions window. Its lists are built each time it opens, so materials
-- excluded by right-click show up straight away, and the scroll list only creates controls
-- for the rows on screen, so complete lists (every style material, every master-writ
-- ingredient) cost no more than short ones. Opened from the settings panel's category
-- buttons or with /wc exclusions.
local Window = {}
WC.ExclusionsWindow = Window

local ROW_TYPE   = 1
local ROW_HEIGHT = 36
local CHECKED    = "EsoUI/Art/Cadwell/checkboxicon_checked.dds"
local UNCHECKED  = "EsoUI/Art/Cadwell/checkboxicon_unchecked.dds"

Window.STYLE = "style"
-- In the game's crafting order. Trait materials are shared: weapon traits go on
-- blacksmithing and woodworking weapons, armor traits on blacksmithing, clothing and
-- woodworking (shields), so those items appear under each craft that uses them.
Window.CATEGORIES = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_ALCHEMY, CRAFTING_TYPE_ENCHANTING,
    CRAFTING_TYPE_PROVISIONING, Window.STYLE,
}

local CATEGORIES_BY_ITEMTYPE = {
    [ITEMTYPE_REAGENT]                 = { CRAFTING_TYPE_ALCHEMY },
    [ITEMTYPE_ENCHANTING_RUNE_ASPECT]  = { CRAFTING_TYPE_ENCHANTING },
    [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = { CRAFTING_TYPE_ENCHANTING },
    [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = { CRAFTING_TYPE_ENCHANTING },
    [ITEMTYPE_WEAPON_TRAIT]            = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_WOODWORKING },
    [ITEMTYPE_ARMOR_TRAIT]             = { CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING },
    [ITEMTYPE_JEWELRY_TRAIT]           = { CRAFTING_TYPE_JEWELRYCRAFTING },
    [ITEMTYPE_INGREDIENT]              = { CRAFTING_TYPE_PROVISIONING },
    [ITEMTYPE_STYLE_MATERIAL]          = { Window.STYLE },
    [ITEMTYPE_BLACKSMITHING_BOOSTER]   = { CRAFTING_TYPE_BLACKSMITHING },
    [ITEMTYPE_CLOTHIER_BOOSTER]        = { CRAFTING_TYPE_CLOTHIER },
    [ITEMTYPE_WOODWORKING_BOOSTER]     = { CRAFTING_TYPE_WOODWORKING },
    [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = { CRAFTING_TYPE_JEWELRYCRAFTING },
}

local ORIGIN_TEXT = {
    plant   = SI_WRITCRAFTER_ORIGIN_PLANT,
    critter = SI_WRITCRAFTER_ORIGIN_CRITTER,
    zone    = SI_WRITCRAFTER_ORIGIN_ZONE,
    special = SI_WRITCRAFTER_ORIGIN_SPECIAL,
}
local ORIGIN_ORDER = { plant = 1, critter = 2, zone = 3, special = 4 }

-- In the Show menu's order (the value is the menu index).
local FILTER_ALL, FILTER_EXCLUDED, FILTER_NOT_EXCLUDED, FILTER_OWNED = 1, 2, 3, 4

function Window.CategoryName(category)
    if category == Window.STYLE then
        return GetString(SI_WRITCRAFTER_EXPENSIVE_STYLE)
    end
    return WC.Util.CraftName(category)
end

local control, list, categoryCombo, showCombo, searchBox, sortHeaders
local current = CRAFTING_TYPE_BLACKSMITHING
local filter  = FILTER_ALL
local search  = ""
local sortKey, sortUp     -- nil until a column heading is clicked: natural order (plants first, then name)
local members = {}   -- [category] = { { itemId, name, lower, origin }, ... }, rebuilt on open
local shown = {}     -- the entries the list shows now (category, filter and search applied)

-- Everything a master writ can ask for in each category, plus the shipped defaults and the
-- player's own marks (on either profile), so nothing that's excluded is ever hidden.
local function BuildMembers()
    local result, seen = {}, {}
    for _, category in ipairs(Window.CATEGORIES) do
        result[category], seen[category] = {}, {}
    end
    local REAGENTS = WC.Data.Alchemy.REAGENTS
    -- Only items of the category's own types get in (no furnishing materials under
    -- Provisioning, no style materials under a craft).
    local function Belongs(category, link)
        for _, allowed in ipairs(CATEGORIES_BY_ITEMTYPE[GetItemLinkItemType(link)] or {}) do
            if allowed == category then
                return true
            end
        end
        return false
    end
    local function Add(category, itemId)
        if not itemId or itemId == 0 or seen[category][itemId] then
            return
        end
        local link = WC.Inventory.GetLink(itemId)
        if not Belongs(category, link) then
            return
        end
        local name = WC.Util.ItemName(link)
        if name == "" then
            return
        end
        seen[category][itemId] = true
        local reagent = REAGENTS[itemId]
        table.insert(result[category], {
            itemId = itemId,
            name   = name,
            lower  = name:lower(),
            origin = reagent and reagent.source or nil,
        })
    end
    local function AddByType(itemId)
        local link = WC.Inventory.GetLink(itemId)
        for _, category in ipairs(CATEGORIES_BY_ITEMTYPE[GetItemLinkItemType(link)] or {}) do
            Add(category, itemId)
        end
    end

    -- Trait materials (index 1 is "no trait", which has no item).
    for index = 1, GetNumSmithingTraitItems() do
        local itemId = GetItemLinkItemId(GetSmithingTraitItemLink(index))
        if itemId ~= 0 then
            AddByType(itemId)
        end
    end
    -- Improvement materials, green to gold, for each smithing craft.
    for craft, ids in pairs(WC.Data.Smithing.IMPROVE_MATS) do
        for _, itemId in ipairs(ids) do
            Add(craft, itemId)
        end
    end
    -- Alchemy: all reagents.
    for itemId in pairs(REAGENTS) do
        Add(CRAFTING_TYPE_ALCHEMY, itemId)
    end
    -- Enchanting: every rune, owned or not (daily writs use runes of every level and every
    -- aspect from Ta up), plus anything owned the ID ranges might miss.
    for _, itemId in ipairs(WC.Data.Enchanting.AllRunes()) do
        Add(CRAFTING_TYPE_ENCHANTING, itemId)
    end
    for _, itemId in ipairs(WC.Inventory.OwnedItemIds({
        [ITEMTYPE_ENCHANTING_RUNE_POTENCY] = true,
        [ITEMTYPE_ENCHANTING_RUNE_ESSENCE] = true,
        [ITEMTYPE_ENCHANTING_RUNE_ASPECT]  = true,
    })) do
        Add(CRAFTING_TYPE_ENCHANTING, itemId)
    end
    local Enchanting = WC.Data.Enchanting
    for _, level in pairs(Enchanting.LEVELS) do
        Add(CRAFTING_TYPE_ENCHANTING, level.additive)
        Add(CRAFTING_TYPE_ENCHANTING, level.subtractive)
    end
    for _, glyph in pairs(Enchanting.GLYPHS) do
        Add(CRAFTING_TYPE_ENCHANTING, glyph.essence)
    end
    for _, aspect in pairs(Enchanting.ASPECTS) do
        Add(CRAFTING_TYPE_ENCHANTING, aspect)
    end
    -- Provisioning: ingredients of every food and drink recipe, since master writs can ask for
    -- any quality. Recipe lists also hold furnishing plans, so only provisioning-station
    -- recipes count.
    for listIndex = 1, GetNumRecipeLists() do
        local _, numRecipes = GetRecipeListInfo(listIndex)
        for recipeIndex = 1, numRecipes or 0 do
            local _, _, numIngredients, _, _, _, station = GetRecipeInfo(listIndex, recipeIndex)
            if station == CRAFTING_TYPE_PROVISIONING then
                for ingredientIndex = 1, numIngredients or 0 do
                    local link = GetRecipeIngredientItemLink(listIndex, recipeIndex, ingredientIndex)
                    Add(CRAFTING_TYPE_PROVISIONING, GetItemLinkItemId(link))
                end
            end
        end
    end
    -- Style materials: every style's material, except the mimic stone itself.
    local universal = GetUniversalStyleId()
    for styleId = 1, GetHighestItemStyleId() do
        if styleId ~= universal then
            Add(Window.STYLE, GetItemLinkItemId(GetItemStyleMaterialLink(styleId)))
        end
    end
    -- Defaults and marks, in case any fall outside the lists above.
    for itemId in pairs(WC.Data.PriceDefaults.EXPENSIVE) do AddByType(itemId) end
    for itemId in pairs(WC.serverSettings.expensive) do AddByType(itemId) end
    for itemId in pairs(WC.characterSettings.expensive) do AddByType(itemId) end

    for _, entries in pairs(result) do
        table.sort(entries, function(a, b)
            local oa, ob = ORIGIN_ORDER[a.origin] or 0, ORIGIN_ORDER[b.origin] or 0
            if oa ~= ob then
                return oa < ob
            end
            return a.lower < b.lower
        end)
    end
    return result
end

local function UpdateSummary()
    local excluded, total = 0, 0
    for _, entry in ipairs(members[current] or {}) do
        total = total + 1
        if WC.Policy.IsExcluded(entry.itemId) then
            excluded = excluded + 1
        end
    end
    control:GetNamedChild("Summary"):SetText(zo_strformat(SI_WRITCRAFTER_EXCL_SUMMARY, excluded, total))
end

-- Value of a sortable column for one entry. Unpriced items sort as nil and always go last.
local SORT_VALUES = {
    name  = function(entry) return entry.lower end,
    count = function(entry) return WC.Inventory.GetStock(entry.itemId).total end,
    price = function(entry) return WC.Price.Get(WC.Inventory.GetLink(entry.itemId)) end,
}

local function ByName(a, b)
    return a.lower < b.lower
end

local function SortRows(rows)
    if not sortKey then
        return   -- members are already in natural order
    end
    WC.Util.SortRows(rows, SORT_VALUES[sortKey], sortUp, ByName)
end

-- Rebuilds the visible rows for the current category, filter, search and sort.
local function FillList()
    local rows = {}
    for _, entry in ipairs(members[current] or {}) do
        local show = true
        if filter == FILTER_EXCLUDED then
            show = WC.Policy.IsExcluded(entry.itemId)
        elseif filter == FILTER_NOT_EXCLUDED then
            show = not WC.Policy.IsExcluded(entry.itemId)
        elseif filter == FILTER_OWNED then
            show = WC.Inventory.GetStock(entry.itemId).total > 0
        end
        if show and search ~= "" then
            show = entry.lower:find(search, 1, true) ~= nil
        end
        if show then
            rows[#rows + 1] = entry
        end
    end
    SortRows(rows)
    shown = rows

    WC.Util.FillScrollList(list, ROW_TYPE, rows)
    UpdateSummary()
end

local function SetupRow(row, entry)
    local link = WC.Inventory.GetLink(entry.itemId)
    row:GetNamedChild("Check"):SetTexture(WC.Policy.IsExcluded(entry.itemId) and CHECKED or UNCHECKED)
    row:GetNamedChild("Icon"):SetTexture(GetItemLinkIcon(link))
    local name = GetItemQualityColor(GetItemLinkDisplayQuality(link)):Colorize(entry.name)
    local unknown = WC.Data.Alchemy.UndiscoveredTraits(entry.itemId)
    if unknown > 0 then
        name = name .. "|cFF9933" .. zo_strformat(SI_WRITCRAFTER_TT_UNDISCOVERED, unknown) .. "|r"
    end
    row:GetNamedChild("Name"):SetText(name)
    row:GetNamedChild("Count"):SetText(ZO_CommaDelimitNumber(WC.Inventory.GetStock(entry.itemId).total))
    local gold = WC.Price.Get(link)
    row:GetNamedChild("Price"):SetText(gold and WC.Price.Format(gold) or "-")
end

function Window.OnRowEnter(row)
    ZO_ScrollList_MouseEnter(list, row)
    local entry = ZO_ScrollList_GetData(row)
    if not entry then
        return
    end
    InitializeTooltip(ItemTooltip, row, RIGHT, -12, 0, LEFT)
    ItemTooltip:SetLink(WC.Inventory.GetLink(entry.itemId))
    if entry.origin then
        ZO_Tooltip_AddDivider(ItemTooltip)
        ItemTooltip:AddLine(GetString(ORIGIN_TEXT[entry.origin]), "ZoFontGame")
    end
end

function Window.OnRowExit(row)
    ZO_ScrollList_MouseExit(list, row)
    ClearTooltip(ItemTooltip)
end

function Window.OnRowMouseUp(row, button, upInside)
    if button ~= MOUSE_BUTTON_INDEX_LEFT or not upInside then
        return
    end
    local entry = ZO_ScrollList_GetData(row)
    if entry then
        WC.Policy.SetExcluded(entry.itemId, not WC.Policy.IsExcluded(entry.itemId))
        WC.Policy.Changed()   -- redraws this window's rows through OnPolicyChanged
    end
end

function Window.OnSearchChanged(editBox)
    search = editBox:GetText():lower()
    if control and not control:IsHidden() then
        FillList()
    end
end

-- Excludes (or with value false, un-excludes) every material the list shows now, so the filter
-- and search pick what changes; then the filter is applied again (e.g. "Not excluded" empties).
local function SetAllShown(value)
    for _, entry in ipairs(shown) do
        WC.Policy.SetExcluded(entry.itemId, value)
    end
    WC.Policy.Changed()
    FillList()
end

function Window.MarkAll()
    SetAllShown(true)
end

function Window.ClearMarks()
    SetAllShown(false)
end

-- Puts the current category back to the shipped defaults: removes the player's own marks.
function Window.ResetCategory()
    for _, entry in ipairs(members[current] or {}) do
        WC.Policy.SetExcluded(entry.itemId, WC.Policy.IsExcludedByDefault(entry.itemId))
    end
    WC.Policy.Changed()
end

-- Any exclusion change, from here, right-click or settings: redraw rows in place.
function Window.OnPolicyChanged()
    if control and not control:IsHidden() then
        ZO_ScrollList_RefreshVisible(list)
        UpdateSummary()
    end
end

local FillCombo = WC.Util.FillCombo

local function IndexOf(values, value)
    for index, v in ipairs(values) do
        if v == value then
            return index
        end
    end
    return 1
end

-- Opens the window on a category (default: the last one shown), rebuilding every list.
function Window.Open(category)
    if category then
        current = category
    end
    members = BuildMembers()
    categoryCombo:SelectItemByIndex(IndexOf(Window.CATEGORIES, current), true)
    searchBox:SetText("")
    search = ""
    FillList()
    SCENE_MANAGER:ShowTopLevel(control)
end

function Window.Close()
    SCENE_MANAGER:HideTopLevel(control)
end

function Window.Init()
    control = WritCrafterExclusionsWindow
    control:SetDrawLayer(DL_OVERLAY)
    SCENE_MANAGER:RegisterTopLevel(control, false)

    control:GetNamedChild("Title"):SetText(GetString(SI_WRITCRAFTER_EXPENSIVE_SUBMENU))
    control:GetNamedChild("Hint"):SetText(GetString(SI_WRITCRAFTER_EXCL_HINT))
    control:GetNamedChild("CategoryLabel"):SetText(GetString(SI_WRITCRAFTER_EXCL_CATEGORY))
    control:GetNamedChild("ShowLabel"):SetText(GetString(SI_WRITCRAFTER_EXCL_SHOW))
    control:GetNamedChild("SearchLabel"):SetText(GetString(SI_WRITCRAFTER_EXCL_SEARCH))
    control:GetNamedChild("Reset"):SetText(GetString(SI_WRITCRAFTER_EXCL_RESET))
    control:GetNamedChild("MarkAll"):SetText(GetString(SI_WRITCRAFTER_EXCL_MARK_ALL))
    control:GetNamedChild("ClearMarks"):SetText(GetString(SI_WRITCRAFTER_EXCL_CLEAR_MARKS))

    -- Click a heading to sort by it, click again to reverse. Names start A to Z; counts and
    -- prices start highest first.
    local headers = control:GetNamedChild("Headers")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Name"), GetString(SI_WRITCRAFTER_EXCL_COL_NAME),
        "name", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Count"), GetString(SI_WRITCRAFTER_EXCL_COL_HAVE),
        "count", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Price"), GetString(SI_WRITCRAFTER_EXCL_COL_PRICE),
        "price", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    sortHeaders = ZO_SortHeaderGroup:New(headers, true)
    sortHeaders:AddHeadersFromContainer()
    sortHeaders:RegisterCallback(ZO_SortHeaderGroup.HEADER_CLICKED, function(key, order)
        sortKey, sortUp = key, order == ZO_SORT_ORDER_UP
        FillList()
    end)
    searchBox = control:GetNamedChild("Search"):GetNamedChild("Box")

    list = control:GetNamedChild("List")
    ZO_ScrollList_AddDataType(list, ROW_TYPE, "WritCrafterExclusionRow", ROW_HEIGHT, SetupRow)
    ZO_ScrollList_EnableHighlight(list, "ZO_ThinListHighlight")

    local categories = {}
    for _, category in ipairs(Window.CATEGORIES) do
        categories[#categories + 1] = { name = Window.CategoryName(category), value = category }
    end
    categoryCombo = ZO_ComboBox_ObjectFromContainer(control:GetNamedChild("Category"))
    FillCombo(categoryCombo, categories, function(category)
        current = category
        FillList()
    end)

    showCombo = ZO_ComboBox_ObjectFromContainer(control:GetNamedChild("Show"))
    FillCombo(showCombo, {
        { name = GetString(SI_WRITCRAFTER_EXCL_SHOW_ALL),      value = FILTER_ALL },
        { name = GetString(SI_WRITCRAFTER_EXCL_SHOW_EXCLUDED), value = FILTER_EXCLUDED },
        { name = GetString(SI_WRITCRAFTER_EXCL_SHOW_NOT_EXCLUDED), value = FILTER_NOT_EXCLUDED },
        { name = GetString(SI_WRITCRAFTER_EXCL_SHOW_OWNED),    value = FILTER_OWNED },
    }, function(value)
        filter = value
        FillList()
    end)
    showCombo:SelectItemByIndex(FILTER_ALL, true)
end
