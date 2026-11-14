local WC = WritCrafter

-- Potion search: pick up to three effects, see every reagent combo that makes them, sorted by
-- how much of each you have. Opened with /wc potions or a keybind. A standalone window, not a
-- tab inside the game's own alchemy station screen (that screen is UI, not the stable crafting
-- API this addon otherwise relies on). Favorites are remembered per character.
local Window = {}
WC.PotionSearch = Window

local ROW_TYPE   = 1
local ROW_HEIGHT = 32
local ANY = 0   -- an effect dropdown's "(Any)" choice: that slot is left out of the search

local control, list, sortHeaders
local effectCombos = {}       -- the three Effect dropdowns
local sortKey, sortUp = "stock", false   -- most stock first by default

-- Effect names, from the game, each worked out once. Falls back to the effect's number if the
-- game ever doesn't answer, so a lookup problem shows up as an odd label, not a Lua error.
local effectNames = {}
local function EffectName(effect)
    local name = effectNames[effect]
    if not name then
        local ok, result = pcall(GetAlchemyEffectName, effect)
        name = (ok and result and result ~= "" and zo_strformat("<<1>>", result))
            or zo_strformat(SI_WRITCRAFTER_POTION_EFFECT_FALLBACK, effect)
        effectNames[effect] = name
    end
    return name
end

-- Favorited combos, kept with the character: [comboKey] = { combo = {r1,r2,r3}, effects = {...} }.
local function Favorites()
    WC.character.potionFavorites = WC.character.potionFavorites or {}
    return WC.character.potionFavorites
end

local function ComboKey(combo)
    local sorted = { combo[1], combo[2], combo[3] }
    table.sort(sorted)
    return table.concat(sorted, ":")
end

local function Reagents(combo)
    local names = {}
    for i, itemId in ipairs(combo) do
        names[i] = WC.Util.ItemName(itemId)
    end
    return table.concat(names, " + ")
end

local function EffectList(effects)
    local names = {}
    for i, effect in ipairs(effects) do
        names[i] = EffectName(effect)
    end
    return table.concat(names, ", ")
end

-- Every row the current search or the favorites list gives, before filters.
local function BuildRows()
    if ZO_CheckButton_IsChecked(control:GetNamedChild("Favorites")) then
        local rows = {}
        for _, entry in pairs(Favorites()) do
            local combo = entry.combo
            local allowed, minStock = true, math.huge
            for _, itemId in ipairs(combo) do
                if not WC.Policy.IsReagentAllowed(itemId) then
                    allowed = false
                end
                minStock = zo_min(minStock, WC.Inventory.GetStock(itemId).usable)
            end
            rows[#rows + 1] = { combo = combo, effects = entry.effects, allowed = allowed,
                stock = minStock, price = 0 }
        end
        return rows
    end
    local effects = {}
    for _, combo in ipairs(effectCombos) do
        local value = ZO_ComboBox_ObjectFromContainer(combo):GetSelectedItemData()
        value = value and value.value
        if value and value ~= ANY then
            effects[#effects + 1] = value
        end
    end
    if #effects == 0 then
        return {}
    end
    return WC.AlchemySolver.Search(effects)
end

-- Value of a sortable column; rows without one sort last.
local SORT_VALUES = {
    reagents = function(row) return Reagents(row.combo):lower() end,
    effects  = function(row) return EffectList(row.effects):lower() end,
    stock    = function(row) return row.stock end,
    price    = function(row) return row.price > 0 and row.price or nil end,
}

local function TieBreak(a, b)
    return ComboKey(a.combo) < ComboKey(b.combo)
end

local function SortRows(rows)
    if sortKey then
        WC.Util.SortRows(rows, SORT_VALUES[sortKey], sortUp, TieBreak)
    else
        table.sort(rows, TieBreak)
    end
end

function Window.Refresh()
    if not control or control:IsHidden() then
        return
    end
    local rows = BuildRows()
    local ownedOnly = ZO_CheckButton_IsChecked(control:GetNamedChild("OwnedOnly"))
    local allowedOnly = ZO_CheckButton_IsChecked(control:GetNamedChild("AllowedOnly"))
    local kept = {}
    for _, row in ipairs(rows) do
        if (not ownedOnly or row.stock > 0) and (not allowedOnly or row.allowed) then
            kept[#kept + 1] = row
        end
    end
    SortRows(kept)
    WC.Util.FillScrollList(list, ROW_TYPE, kept)
    control:GetNamedChild("Empty"):SetHidden(#kept > 0)
end

-- The favorite marker: a gold star when favorited, a dim one otherwise. Plain ASCII, not a
-- texture or a Unicode character, so it doesn't depend on guessing a game icon's file path or
-- the game font's glyph coverage.
local FAVORITE_STAR, PLAIN_STAR = "|cFFDD55*|r", "|c666666*|r"

local function SetStar(star, favorited)
    star:SetText(favorited and FAVORITE_STAR or PLAIN_STAR)
end

local function SetupRow(row, data)
    local favorites = Favorites()
    local key = ComboKey(data.combo)
    SetStar(row:GetNamedChild("Star"), favorites[key] ~= nil)
    row:GetNamedChild("Reagents"):SetText(data.allowed and Reagents(data.combo)
        or "|c808080" .. Reagents(data.combo) .. "|r")
    row:GetNamedChild("Effects"):SetText(EffectList(data.effects))
    row:GetNamedChild("Stock"):SetText(data.stock < math.huge and data.stock or "-")
    row:GetNamedChild("Price"):SetText(data.price > 0 and WC.Price.Format(data.price) or "-")
end

function Window.OnStarClicked(star, upInside)
    if not upInside then
        return
    end
    local row = star:GetParent()
    local data = ZO_ScrollList_GetData(row)
    if not data then
        return
    end
    local favorites = Favorites()
    local key = ComboKey(data.combo)
    if favorites[key] then
        favorites[key] = nil
    else
        favorites[key] = { combo = data.combo, effects = data.effects }
    end
    SetStar(star, favorites[key] ~= nil)
    if ZO_CheckButton_IsChecked(control:GetNamedChild("Favorites")) and not favorites[key] then
        Window.Refresh()   -- it just left the favorites list
    end
end

function Window.OnRowEnter(row)
    ZO_ScrollList_MouseEnter(list, row)
    local data = ZO_ScrollList_GetData(row)
    if data and data.anyUnknown then
        InitializeTooltip(InformationTooltip, row, LEFT, 0, 0, RIGHT)
        SetTooltipText(InformationTooltip, GetString(SI_WRITCRAFTER_POTION_UNKNOWN_TRAIT))
    end
end

function Window.OnRowExit(row)
    ZO_ScrollList_MouseExit(list, row)
    ClearTooltip(InformationTooltip)
end

function Window.Open()
    SCENE_MANAGER:ShowTopLevel(control)
    Window.Refresh()
end

function Window.Close()
    SCENE_MANAGER:HideTopLevel(control)
end

function Window.Toggle()
    if control:IsHidden() then
        Window.Open()
    else
        Window.Close()
    end
end

local function InitEffectCombo(name)
    local combo = control:GetNamedChild(name)
    local object = ZO_ComboBox_ObjectFromContainer(combo)
    local items = { { name = GetString(SI_WRITCRAFTER_POTION_ANY), value = ANY } }
    for _, effect in ipairs(WC.AlchemySolver.EFFECTS) do
        items[#items + 1] = { name = EffectName(effect), value = effect }
    end
    WC.Util.FillCombo(object, items, function() Window.Refresh() end)
    object:SelectItemByIndex(1, true)
    effectCombos[#effectCombos + 1] = combo
end

function Window.Init()
    control = WritCrafterPotionWindow
    control:SetDrawLayer(DL_OVERLAY)
    SCENE_MANAGER:RegisterTopLevel(control, false)

    control:GetNamedChild("Title"):SetText(GetString(SI_WRITCRAFTER_POTION_TITLE))
    control:GetNamedChild("Hint"):SetText(GetString(SI_WRITCRAFTER_POTION_HINT))
    control:GetNamedChild("Empty"):SetText(GetString(SI_WRITCRAFTER_POTION_EMPTY))

    InitEffectCombo("Effect1")
    InitEffectCombo("Effect2")
    InitEffectCombo("Effect3")

    ZO_CheckButton_SetLabelText(control:GetNamedChild("OwnedOnly"), GetString(SI_WRITCRAFTER_POTION_OWNED_ONLY))
    ZO_CheckButton_SetLabelText(control:GetNamedChild("AllowedOnly"), GetString(SI_WRITCRAFTER_POTION_ALLOWED_ONLY))
    ZO_CheckButton_SetLabelText(control:GetNamedChild("Favorites"), GetString(SI_WRITCRAFTER_POTION_FAVORITES))
    for _, name in ipairs({ "OwnedOnly", "AllowedOnly", "Favorites" }) do
        local box = control:GetNamedChild(name)
        ZO_CheckButton_SetUnchecked(box)
        ZO_CheckButton_SetToggleFunction(box, Window.Refresh)
    end

    local headers = control:GetNamedChild("Headers")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Reagents"), GetString(SI_WRITCRAFTER_POTION_COL_REAGENTS),
        "reagents", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Effects"), GetString(SI_WRITCRAFTER_POTION_COL_EFFECTS),
        "effects", ZO_SORT_ORDER_UP, TEXT_ALIGN_LEFT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Stock"), GetString(SI_WRITCRAFTER_POTION_COL_STOCK),
        "stock", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    ZO_SortHeader_Initialize(headers:GetNamedChild("Price"), GetString(SI_WRITCRAFTER_POTION_COL_PRICE),
        "price", ZO_SORT_ORDER_DOWN, TEXT_ALIGN_RIGHT, "ZoFontGameBold")
    sortHeaders = ZO_SortHeaderGroup:New(headers, true)
    sortHeaders:AddHeadersFromContainer()
    sortHeaders:RegisterCallback(ZO_SortHeaderGroup.HEADER_CLICKED, function(key, order)
        sortKey, sortUp = key, order == ZO_SORT_ORDER_UP
        Window.Refresh()
    end)

    list = control:GetNamedChild("List")
    ZO_ScrollList_AddDataType(list, ROW_TYPE, "WritCrafterPotionRow", ROW_HEIGHT, SetupRow)
    ZO_ScrollList_EnableHighlight(list, "ZO_ThinListHighlight")

    WC.Inventory.AddListener(function()
        if control and not control:IsHidden() then
            Window.Refresh()
        end
    end)
end
