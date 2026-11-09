local WC = WritCrafter

local Icons = {}
WC.InventoryIcons = Icons

local ICON_NAME = "WritCrafterStatus"
local ICON_SIZE = 20

local TEXTURE_CRAFTED  = "/esoui/art/buttons/accept_up.dds"
local TEXTURE_REJECTED = "/esoui/art/buttons/decline_up.dds"
local TEXTURE_RESERVED = "/esoui/art/miscellaneous/locked_up.dds"
local TEXTURE_MISSING  = "/esoui/art/miscellaneous/eso_icon_warning.dds"
local TEXTURE_QUEUED   = "/esoui/art/crafting/smithing_tabicon_creation_up.dds"   -- the station's Create hammer

-- Item lists that show sealed writs or crafted items. Other addons already use the row's
-- top-right corner (LootLog) and left edge (CraftStore), so the badge sits on the item
-- icon's bottom-right corner.
local LIST_NAMES = {
    "ZO_PlayerInventoryList",
    "ZO_PlayerBankBackpack",
    "ZO_HouseBankBackpack",
    -- Crafting stations keep their own lists; deconstruction is where the padlock matters most.
    "ZO_SmithingTopLevelDeconstructionPanelInventoryBackpack",
    "ZO_SmithingTopLevelImprovementPanelInventoryBackpack",
    "ZO_UniversalDeconstructionTopLevel_KeyboardPanelInventoryBackpack",
    "ZO_EnchantingTopLevelInventoryBackpack",
    "ZO_RetraitStation_KeyboardTopLevelRetraitPanelInventoryBackpack",
}
local hookedLists = {}
local hookedListSet = {}
local hookedDataTypes = {}

-- The badge control is created once per row and remembered on it.
local function GetIcon(row)
    local icon = row.wcBadge
    if not icon then
        icon = WINDOW_MANAGER:CreateControl(row:GetName() .. ICON_NAME, row, CT_TEXTURE)
        icon:SetDimensions(ICON_SIZE, ICON_SIZE)
        icon:SetDrawTier(DT_HIGH)
        icon:SetInheritScale(false)
        row.wcBadge = icon
    end
    -- Re-anchor only when the offset settings changed: rows are set up constantly while
    -- scrolling, and every anchor change counts toward the game's per-frame anchor limit.
    local offsetX, offsetY = WC.settings.iconOffsetX, WC.settings.iconOffsetY
    if icon.wcOffsetX ~= offsetX or icon.wcOffsetY ~= offsetY then
        local anchorTo = row:GetNamedChild("Button") or row
        icon:ClearAnchors()
        icon:SetAnchor(BOTTOMRIGHT, anchorTo, BOTTOMRIGHT, 4 + offsetX, 4 + offsetY)
        icon.wcOffsetX, icon.wcOffsetY = offsetX, offsetY
    end
    return icon
end

-- Returns texture and r, g, b for a row, or nil for no badge. Runs for every row drawn, so the
-- cheap checks come first: the item type (a number, no link), then the game lock. Only sealed
-- writs and possible writ items go further, and only those read a link.
local function BadgeFor(bagId, slotIndex)
    local settings = WC.settings
    local itemType = GetItemType(bagId, slotIndex)
    if itemType == ITEMTYPE_MASTER_WRIT then
        local writ = WC.Master.Parse(GetItemLink(bagId, slotIndex))
        if not writ then
            return nil
        end
        local uid = WC.Master.UniqueId(bagId, slotIndex)
        local status = WC.Reservations.GetWritStatus(uid)
        if settings.iconCrafted and status and status.crafted then
            return TEXTURE_CRAFTED, 0.25, 0.85, 0.25
        end
        -- Rejected, unless queued by hand anyway (then it shows as queued below).
        local verdict = WC.Rules.GetStatus(writ)
        if settings.iconRejected and verdict ~= WC.Rules.OK
            and not (verdict == WC.Rules.REJECTED and WC.Queue.IsOverride(uid)) then
            return TEXTURE_REJECTED, 1, 0.3, 0.3
        end
        -- Nothing made yet and not enough of some material: yellow warning.
        if settings.iconMissing and not (status and status.have > 0)
            and #WC.Rules.Shortages(writ) > 0 then
            return TEXTURE_MISSING, 1, 0.85, 0.2
        end
        -- Queued (right-click menu or queue window): crafted at its station on the next visit.
        if settings.iconQueued and WC.Queue.Has(uid) then
            return TEXTURE_QUEUED, 0.45, 0.75, 1
        end
        -- Some but not all made (alchemy and provisioning writs need several): amber check.
        if settings.iconCrafted and status and status.have > 0 then
            return TEXTURE_CRAFTED, 1, 0.7, 0.2
        end
        return nil
    end
    if not settings.iconReserved or not WC.Reservations.IsCandidateType(itemType)
        or IsItemPlayerLocked(bagId, slotIndex) then
        return nil   -- materials, locked gear and everything else can never be set aside
    end
    if WC.Reservations.GetReserved(bagId, slotIndex) > 0 or WC.Reservations.AcceptedQuestFor(bagId, slotIndex) then
        return TEXTURE_RESERVED, 0.9, 0.8, 0.4
    end
    -- Made for a daily writ: the same padlock in blue.
    if WC.DailyItems.QuestFor(bagId, slotIndex) then
        return TEXTURE_RESERVED, 0.4, 0.75, 1
    end
    return nil
end
Icons.BadgeFor = BadgeFor   -- for /wc perf

local function OnRowSetup(row, data)
    local texture, r, g, b
    if data and data.bagId and data.slotIndex then
        texture, r, g, b = BadgeFor(data.bagId, data.slotIndex)
    end
    if not texture then
        if row.wcBadge then
            row.wcBadge:SetHidden(true)
        end
        return
    end
    local icon = GetIcon(row)
    icon:SetTexture(texture)
    icon:SetColor(r, g, b, 1)
    icon:SetHidden(false)
end

local function AnyListOpen()
    for _, list in ipairs(hookedLists) do
        if not list:IsControlHidden() then
            return true
        end
    end
    return false
end

-- Updates just the badges on the rows currently on screen. Redrawing the rows instead would
-- re-run every inventory addon's row code (CraftStore, AlphaGear, ...) to change one badge.
-- Only lists whose window is open: IsControlHidden also checks parents, where IsHidden
-- doesn't, and a list in a closed window draws its badges fresh when it opens.
function Icons.Refresh()
    for _, list in ipairs(hookedLists) do
        if not list:IsControlHidden() then
            if list.activeControls then
                for _, row in ipairs(list.activeControls) do
                    OnRowSetup(row, row.dataEntry and row.dataEntry.data)
                end
            else
                ZO_ScrollList_RefreshVisible(list)
            end
        end
    end
end

-- Bag events come in bursts (a deposit is several updates); act once they settle. Called by
-- Reservations, only when a change can affect writ badges. With an item window open, the
-- writ matching is redone here, so drawing rows only reads finished results; with none open,
-- it waits until something asks.
local REFRESH_DELAY_MS = 250
local function RefreshSoon()
    local name = WC.name .. "IconRefresh"
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, REFRESH_DELAY_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        if AnyListOpen() then
            WC.Reservations.EnsureFresh()
            Icons.Refresh()
        end
    end)
end
Icons.OnWritItemsChanged = RefreshSoon

-- Hooks every row type of every list that exists so far. Crafting station lists can get their
-- row types later than addon load, so this runs again each time a station opens; anything
-- already hooked is skipped.
-- Returns true when it hooked something new.
local function HookLists()
    local added = false
    for _, name in ipairs(LIST_NAMES) do
        local list = _G[name]
        if list and list.dataTypes then
            for _, dataType in pairs(list.dataTypes) do
                if not hookedDataTypes[dataType] and dataType.setupCallback then
                    SecurePostHook(dataType, "setupCallback", OnRowSetup)
                    hookedDataTypes[dataType] = true
                    added = true
                    if not hookedListSet[list] then
                        hookedListSet[list] = true
                        hookedLists[#hookedLists + 1] = list
                    end
                end
            end
        end
    end
    return added
end

function Icons.Init()
    HookLists()
    -- A station's list may already be drawn by the time a late hook lands; redraw only then.
    EVENT_MANAGER:RegisterForEvent(WC.name .. "Icons", EVENT_CRAFTING_STATION_INTERACT, function()
        if HookLists() then
            RefreshSoon()
        end
    end)
end
