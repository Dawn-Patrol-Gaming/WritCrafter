local WC = WritCrafter

-- Asks before a sealed master writ you can't craft (your settings reject it, or you don't know
-- the recipe, motif or trait) turns into a quest. Using the item offers the quest in one step,
-- with no normal way to back out once you click Accept, so this steps in a moment earlier: when
-- the quest is offered for a writ used by hand (not through WritCrafter's own Accept Crafted
-- Writs, which only ever uses writs whose items are already made), it runs the writ through the
-- same check as the queue window, and if that check would reject or cannot-craft it, the offer is
-- turned away before it's accepted, with a dialog asking whether to take it anyway.
--
-- Which writ: UseItem is private (it can't be hooked, even after the call), and the game's own
-- inventory calls it directly, so a writ used by hand is recognised by the slot you last touched
-- (hovered, right-clicked, double-clicked or selected on gamepad): a sealed writ, still in that
-- slot, touched moments before a quest is offered outside any conversation with an NPC. Add-ons
-- that use writs go through CallSecureProtected, which is watched directly.
local Guard = {}
WC.AcceptGuard = Guard

local ADDON_USE_MS    = 5000    -- longest between an add-on using a writ and its quest being offered
local TOUCH_WINDOW_MS = 10000   -- a writ touched this recently may be the one just used
local FORCE_ACCEPT_MS = 300     -- "Accept Anyway": as Writs/Rolis.lua waits for its own offers

-- { writ, verdict }: the offer on screen is for this writ, which would be rejected. Kept until
-- the next quest offer (every Accept follows an offer, so it can't reach another quest), however
-- long you take to click.
local pending
local touched       -- { bagId, slotIndex, link, control, ms }: the sealed writ slot last touched
local addonUse      -- { bagId, slotIndex, ms }: a writ an add-on just used
local inChatter     -- true while talking to an NPC: its quest offers are never a writ's
local skipNext       -- true: the next AcceptOfferedQuest (from "Accept Anyway") is let through
local forceAccept    -- true: accept the next quest offer ourselves, without the player clicking

local function Debug(fmt, ...)
    if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
        WC.Log.Debug(string.format(fmt, ...))
    end
end

-- If the queue window would reject this writ or call it uncraftable, remember that so the offer
-- on screen can be turned away.
local function Check(bagId, slotIndex, how)
    local writ = WC.Master.Parse(GetItemLink(bagId, slotIndex))
    if not writ then
        return
    end
    local verdict = WC.Rules.Evaluate(writ)
    Debug("Accept guard: %s %s, %s", writ.link, how,
        verdict.status == WC.Rules.OK and "craftable" or ("will ask: " .. (verdict.reasons[1] or "?")))
    if verdict.status ~= WC.Rules.OK then
        pending = { writ = writ, verdict = verdict }
    end
end

-- Inventory slot hooks (game UI functions, guarded: a change in a game update makes the guard
-- miss writs, never breaks the inventory).
local function Touch(inventorySlot)
    if not (WC.settings.acceptGuard and inventorySlot) then
        return
    end
    local ok, bagId, slotIndex = pcall(ZO_Inventory_GetBagAndIndex, inventorySlot)
    if ok and bagId and slotIndex and GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
        touched = { bagId = bagId, slotIndex = slotIndex, link = GetItemLink(bagId, slotIndex),
            control = inventorySlot, ms = GetFrameTimeMilliseconds() }
    end
end

local function OnMouseEnter(inventorySlot)
    local ok, button = pcall(ZO_InventorySlot_GetInventorySlotComponents, inventorySlot)
    Touch(ok and button or nil)
end

-- Add-ons use items through CallSecureProtected. WritCrafter's own uses (Accept Crafted Writs,
-- "Accept Anyway") are never checked, and the offer they bring isn't the touched writ's.
local function OnSecureCall(funcName, bagId, slotIndex)
    if funcName ~= "UseItem" then
        return
    end
    touched, addonUse = nil, nil
    if not WC.Util.IsAutomatedUse() and GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
        addonUse = { bagId = bagId, slotIndex = slotIndex, ms = GetFrameTimeMilliseconds() }
    end
end

-- Whether the touched writ is plausibly the one whose quest is being offered.
local function TouchedWrit()
    if not touched or inChatter then
        return nil
    end
    local recent = GetFrameTimeMilliseconds() - touched.ms <= TOUCH_WINDOW_MS
    local hovered = WINDOW_MANAGER:GetMouseOverControl() == touched.control
    if not (recent or hovered) or GetItemLink(touched.bagId, touched.slotIndex) ~= touched.link then
        return nil
    end
    return touched
end

-- A quest is offered. After "Accept Anyway" reuses the item, the offer is accepted the same way
-- WritCrafter's own Accept Crafted Writs accepts its own offers: no need for you to click again.
-- Otherwise, if it follows a sealed writ you just touched, that writ is checked.
local function OnQuestOffered()
    pending = nil
    if forceAccept then
        forceAccept = false
        zo_callLater(function()
            AcceptOfferedQuest()
            ResetChatter()
        end, FORCE_ACCEPT_MS)
        return
    end
    local used = addonUse
    addonUse = nil
    if not WC.settings.acceptGuard then
        return
    end
    if used and GetFrameTimeMilliseconds() - used.ms <= ADDON_USE_MS then
        Check(used.bagId, used.slotIndex, "used by an add-on")
        return
    end
    local writ = TouchedWrit()
    if writ then
        Check(writ.bagId, writ.slotIndex, "used by hand")
    elseif touched then
        Debug("Accept guard: quest offered, not checked (last writ touched %d ms ago, talking to an NPC: %s)",
            GetFrameTimeMilliseconds() - touched.ms, tostring(inChatter == true))
    end
end

-- Finds the same writ again by its link (turning the offer away leaves the item where it was)
-- and uses it again, this time letting the offer through and taking it for you.
local function AcceptAnyway(data)
    for slotIndex in WC.Inventory.Slots(BAG_BACKPACK) do
        if GetItemType(BAG_BACKPACK, slotIndex) == ITEMTYPE_MASTER_WRIT
            and GetItemLink(BAG_BACKPACK, slotIndex) == data.link then
            skipNext, forceAccept = true, true
            WC.Util.UseItem(BAG_BACKPACK, slotIndex)
            return
        end
    end
end

local DIALOG_NAME = "WRITCRAFTER_ACCEPT_BLOCKED"

-- Hooked onto the global AcceptOfferedQuest: returning true (ZO_PreHook's way of blocking a
-- call) stops the quest from being added. Used by the game itself when you click Accept in the
-- writ's offer, and by WritCrafter's own automation (Accept Crafted Writs, "Accept Anyway" here).
local function CheckAccept()
    if skipNext then
        skipNext = false
        return false
    end
    if not pending then
        if touched then
            Debug("Accept guard: Accept clicked, nothing to turn away")
        end
        return false
    end
    Debug("Accept guard: Accept clicked for %s: turned away", pending.writ.link)
    local writ, verdict = pending.writ, pending.verdict
    pending, touched = nil, nil
    ResetChatter()
    ZO_Dialogs_ShowDialog(DIALOG_NAME, { link = writ.link },
        { mainTextParams = { WC.Util.ItemName(writ.link), verdict.reasons[1] or "" } })
    return true
end

function Guard.Init()
    SecurePostHook("CallSecureProtected", OnSecureCall)
    SecurePostHook("ZO_InventorySlot_OnMouseEnter", OnMouseEnter)
    SecurePostHook("ZO_InventorySlot_DiscoverSlotActionsFromActionList", Touch)
    ZO_PreHook("AcceptOfferedQuest", CheckAccept)
    local namespace = WC.name .. "AcceptGuard"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_OFFERED, OnQuestOffered)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CHATTER_BEGIN, function() inChatter = true end)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CHATTER_END, function() inChatter = false end)
    ESO_Dialogs[DIALOG_NAME] = {
        title = { text = WRITCRAFTER_ACCEPT_BLOCKED_TITLE },
        mainText = { text = WRITCRAFTER_ACCEPT_BLOCKED_TEXT },
        buttons = {
            { text = WRITCRAFTER_ACCEPT_ANYWAY, callback = function(dialog) AcceptAnyway(dialog.data) end },
            { text = SI_DIALOG_CANCEL },
        },
    }
end
