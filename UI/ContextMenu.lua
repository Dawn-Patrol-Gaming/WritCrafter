local WC = WritCrafter

local ContextMenu = {}
WC.ContextMenu = ContextMenu

-- Right-click on any material in a bag (reagent, rune, trait, ingredient, style): one
-- exclude / stop excluding toggle, the same switch as Settings → Material exclusions.
-- Each bag reports its rows as a different slot type; craft bag rows aren't SLOT_TYPE_ITEM.
local SLOT_TYPES = {
    [SLOT_TYPE_ITEM]               = true,   -- backpack
    [SLOT_TYPE_BANK_ITEM]          = true,   -- bank and house storage
    [SLOT_TYPE_CRAFT_BAG_ITEM]     = true,
    [SLOT_TYPE_CRAFTING_COMPONENT] = true,   -- material lists at crafting stations
}

local function OnContextMenu(inventorySlot)
    if not SLOT_TYPES[ZO_InventorySlot_GetType(inventorySlot)] then
        return
    end
    local bagId, slotIndex = ZO_Inventory_GetBagAndIndex(inventorySlot)
    if not bagId then
        return
    end
    local link = GetItemLink(bagId, slotIndex)
    local itemId = GetItemLinkItemId(link)
    local Policy = WC.Policy

    if WC.Data.Alchemy.REAGENTS[itemId] or WC.Data.PriceDefaults.Category(link) then
        local excluded = Policy.IsExcluded(itemId)
        local label = excluded and SI_WRITCRAFTER_MENU_UNMARK_EXPENSIVE or SI_WRITCRAFTER_MENU_MARK_EXPENSIVE
        AddCustomMenuItem(GetString(label), function()
            Policy.SetExcluded(itemId, not excluded)
            Policy.Changed()
        end, MENU_ADD_OPTION_LABEL)
    end
end

function ContextMenu.Init()
    LibCustomMenu:RegisterContextMenu(OnContextMenu, LibCustomMenu.CATEGORY_LATE)
end
