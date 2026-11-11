local WC = WritCrafter

-- Daily writ status strip: one icon per crafting station (the game's own craft icons), coloured by
-- that craft's daily writ: not picked up, still to craft, ready to turn in, or turned in. Shown
-- while you have any daily writ; it goes away once the last one is turned in. Drag it anywhere;
-- the spot is remembered. Only out in the world (the HUD), not over menus.
local Status = {}
WC.WritStatus = Status

local ICON_SIZE = 32
local GAP = 4

local CRAFTS = {
    { craft = CRAFTING_TYPE_BLACKSMITHING,   icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_blacksmithing_up.dds" },
    { craft = CRAFTING_TYPE_CLOTHIER,        icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_clothing_up.dds" },
    { craft = CRAFTING_TYPE_WOODWORKING,     icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_woodworking_up.dds" },
    { craft = CRAFTING_TYPE_JEWELRYCRAFTING, icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_jewelrycrafting_up.dds" },
    { craft = CRAFTING_TYPE_ALCHEMY,         icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_alchemy_up.dds" },
    { craft = CRAFTING_TYPE_ENCHANTING,      icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_enchanting_up.dds" },
    { craft = CRAFTING_TYPE_PROVISIONING,    icon = "EsoUI/Art/Inventory/inventory_tabIcon_Craftbag_provisioning_up.dds" },
}

local NONE, TO_CRAFT, READY, TURNED_IN = "none", "toCraft", "ready", "turnedIn"
local COLORS = {
    [NONE]      = { 0.55, 0.55, 0.55, 0.35 },   -- not picked up
    [TO_CRAFT]  = { 1, 0.7, 0.2, 1 },           -- amber
    [READY]     = { 0.3, 0.85, 1, 1 },          -- cyan
    [TURNED_IN] = { 0.35, 0.9, 0.35, 1 },       -- green
}
local STATUS_TEXT = {
    [NONE]      = SI_WRITCRAFTER_STATUS_NONE,
    [TO_CRAFT]  = SI_WRITCRAFTER_STATUS_TO_CRAFT,
    [READY]     = SI_WRITCRAFTER_STATUS_READY,
    [TURNED_IN] = SI_WRITCRAFTER_STATUS_TURNED_IN,
}

local window   -- placed and moved by you; shown out in the world (the HUD)
local strip    -- the icons, shown only while you have daily writs
local icons = {}        -- [craft] = texture
local statuses = {}     -- [craft] = status, as last drawn
-- [craft] = true: turned in since the strip last emptied (kept with the character, so a reload
-- doesn't lose it).
local function TurnedIn()
    WC.character.writTurnedIn = WC.character.writTurnedIn or {}
    return WC.character.writTurnedIn
end

-- [quest name] = true: the daily writ has moved on from its crafting step to delivery. The game
-- doesn't call such a quest complete (the delivery is still a task), and the delivery task's
-- wording is the only other difference, so the step change is watched instead (any language).
-- Kept with the character; forgotten when the quest leaves the journal.
local function Ready()
    WC.character.writReady = WC.character.writReady or {}
    return WC.character.writReady
end

-- Each craft's daily writ status, and whether any daily writ is in the journal.
local function Read()
    local result, any = {}, false
    local masterQuests = WC.character.acceptedWrits or {}
    for _, entry in ipairs(WC.Daily.Quests()) do
        local craft = not masterQuests[entry.quest] and WC.Dialogs.WritCraft(entry.quest)
        if craft then
            local ready = Ready()[entry.quest] or GetJournalQuestIsComplete(entry.questIndex)
            result[craft] = ready and READY or TO_CRAFT
            any = true
        end
    end
    for _, entry in ipairs(CRAFTS) do
        if not result[entry.craft] then
            result[entry.craft] = TurnedIn()[entry.craft] and TURNED_IN or NONE
        end
    end
    return result, any
end

function Status.Refresh()
    if not window then
        return
    end
    local result, any = Read()
    if not any or not WC.settings.writStatus then
        -- The last writ is in: start fresh for the next set. (An empty journal right after
        -- logging in may just not be loaded yet, so nothing is forgotten then.)
        if not any and GetNumJournalQuests() > 0 then
            ZO_ClearTable(TurnedIn())
            ZO_ClearTable(Ready())
        end
        strip:SetHidden(true)
        window:SetMouseEnabled(false)   -- nothing to grab while it's empty
        return
    end
    for _, entry in ipairs(CRAFTS) do
        local status = result[entry.craft]
        statuses[entry.craft] = status
        icons[entry.craft]:SetColor(unpack(COLORS[status]))
    end
    strip:SetHidden(false)
    window:SetMouseEnabled(true)
end

local function RefreshSoon()
    local name = WC.name .. "WritStatusRefresh"
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, 300, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        Status.Refresh()
    end)
end
Status.RefreshSoon = RefreshSoon

-- A daily writ was turned in: its craft shows green until the strip empties.
local function OnQuestComplete(_, questName, _, _, _, _, questType)
    if questType == QUEST_TYPE_CRAFTING then
        local craft = WC.Dialogs.WritCraft(questName)
        if craft then
            TurnedIn()[craft] = true
        end
    end
    RefreshSoon()
end

-- Called by the crafting engine when a station visit leaves a daily writ with nothing to craft.
function Status.MarkReady(quest)
    Ready()[quest] = true
    RefreshSoon()
end

-- A daily writ moving on to its next main step has everything crafted: it's ready to deliver
-- (also when crafted by hand).
local function OnJournalChanged(event, ...)
    if event == EVENT_QUEST_ADVANCED then
        local questIndex, questName, isPushed, isComplete, mainStepChanged = ...
        if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING then
            WC.Log.Debug(string.format("Quest advanced: %s, pushed %s, complete %s, main step changed %s",
                tostring(questName), tostring(isPushed), tostring(isComplete), tostring(mainStepChanged)))
        end
        if mainStepChanged and GetJournalQuestType(questIndex) == QUEST_TYPE_CRAFTING
            and not (WC.character.acceptedWrits or {})[questName] and WC.Dialogs.WritCraft(questName) then
            Ready()[questName] = true
        end
    elseif event == EVENT_QUEST_REMOVED then
        Ready()[select(3, ...)] = nil
    end
    RefreshSoon()
end

local function OnIconEnter(icon)
    local status = statuses[icon.wcCraft] or NONE
    InitializeTooltip(InformationTooltip, icon, BOTTOM, 0, -4)
    SetTooltipText(InformationTooltip, zo_strformat(SI_WRITCRAFTER_STATUS_TOOLTIP,
        zo_strformat("<<1>>", GetCraftingSkillName(icon.wcCraft)), GetString(STATUS_TEXT[status])))
end

function Status.Init()
    window = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "WritStatus")
    window:SetDimensions(#CRAFTS * (ICON_SIZE + GAP) + GAP, ICON_SIZE + 2 * GAP)
    window:SetMouseEnabled(false)
    window:SetMovable(true)
    window:SetClampedToScreen(true)
    local x, y = WC.settings.writStatusX, WC.settings.writStatusY
    if x and y then
        window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, x, y)
    elseif ZO_PlayerAttributeHealth then
        -- First time: just above the health, magicka and stamina bars, where it's seen and easy
        -- to grab (at the top of the screen it ends up under other UI). Once the UI has settled
        -- that spot is pinned to the screen: left attached to the health bar, dragging it
        -- wouldn't move it up or down (seen 2026-11-11).
        window:SetAnchor(BOTTOM, ZO_PlayerAttributeHealth, TOP, 0, -22)
        local placeName = WC.name .. "WritStatusPlace"
        EVENT_MANAGER:RegisterForEvent(placeName, EVENT_PLAYER_ACTIVATED, function()
            EVENT_MANAGER:UnregisterForEvent(placeName, EVENT_PLAYER_ACTIVATED)
            zo_callLater(function()
                if WC.settings.writStatusX then
                    return   -- already moved by hand
                end
                local left, top = window:GetLeft(), window:GetTop()
                window:ClearAnchors()
                window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, left, top)
            end, 1000)
        end)
    else
        window:SetAnchor(BOTTOM, GuiRoot, BOTTOM, 0, -170)
    end
    window:SetHandler("OnMoveStop", function(control)
        WC.settings.writStatusX, WC.settings.writStatusY = control:GetLeft(), control:GetTop()
    end)
    strip = WINDOW_MANAGER:CreateControl(WC.name .. "WritStatusStrip", window, CT_CONTROL)
    strip:SetAnchorFill(window)
    strip:SetHidden(true)
    local backdrop = WINDOW_MANAGER:CreateControlFromVirtual(WC.name .. "WritStatusBackdrop", strip, "ZO_DefaultBackdrop")
    backdrop:SetAnchorFill(strip)
    backdrop:SetAlpha(0.6)
    for index, entry in ipairs(CRAFTS) do
        local icon = WINDOW_MANAGER:CreateControl(WC.name .. "WritStatus" .. entry.craft, strip, CT_TEXTURE)
        icon:SetDimensions(ICON_SIZE, ICON_SIZE)
        icon:SetAnchor(LEFT, strip, LEFT, GAP + (index - 1) * (ICON_SIZE + GAP), 0)
        icon:SetTexture(entry.icon)
        icon:SetMouseEnabled(true)
        icon.wcCraft = entry.craft
        icon:SetHandler("OnMouseEnter", OnIconEnter)
        icon:SetHandler("OnMouseExit", function() ClearTooltip(InformationTooltip) end)
        icons[entry.craft] = icon
    end
    -- Out in the world only.
    local fragment = ZO_SimpleSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    local namespace = WC.name .. "WritStatus"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_COMPLETE, OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, RefreshSoon)
    WC.Daily.OnJournalChanged(OnJournalChanged)
end
