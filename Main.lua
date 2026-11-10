local WC = WritCrafter

local function OnAddOnLoaded(_, addonName)
    if addonName ~= WC.name then
        return
    end
    EVENT_MANAGER:UnregisterForEvent(WC.name, EVENT_ADD_ON_LOADED)

    WC.SavedVars.Init()
    WC.Log.Init()
    WC.Inventory.Init()
    WC.Price.Init()
    WC.Rules.Init()
    WC.Reservations.Init()
    WC.Queue.Init()
    WC.Engine.Init()
    WC.Daily.Init()
    WC.DailyItems.Init()
    WC.Bank.Init()
    WC.Rolis.Init()
    WC.Markers.Init()
    WC.ExclusionsWindow.Init()
    WC.QueueWindow.Init()
    WC.Settings.Init()
    WC.Tooltip.Init()
    WC.InventoryIcons.Init()
    WC.ContextMenu.Init()
    WC.Slash.Init()
end

EVENT_MANAGER:RegisterForEvent(WC.name, EVENT_ADD_ON_LOADED, OnAddOnLoaded)
