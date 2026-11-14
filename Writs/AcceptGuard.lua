local WC = WritCrafter

-- Asks before a sealed master writ you can't craft (your settings reject it, or you don't know
-- the recipe, motif or trait) turns into a quest. Using the item offers the quest in one step,
-- with no normal way to back out once you click Accept, so this steps in a moment earlier: when
-- the item is used by hand (not through WritCrafter's own Accept Crafted Writs, which only ever
-- uses writs whose items are already made), it runs the writ through the same check as the queue
-- window, and if that check would reject or cannot-craft it, the quest offer is turned away
-- before it's accepted, with a dialog asking whether to take it anyway.
local Guard = {}
WC.AcceptGuard = Guard

local PENDING_TIMEOUT_MS = 5000   -- longest between using the writ and its quest being offered
local FORCE_ACCEPT_MS    = 300    -- "Accept Anyway": as Writs/Rolis.lua waits for its own offers

local pending       -- { writ, verdict } for the writ just used by hand, until its offer is seen
local skipNext       -- true: the next AcceptOfferedQuest (from "Accept Anyway") is let through
local forceAccept    -- true: accept the next quest offer ourselves, without the player clicking

-- A sealed master writ was just used by hand. If the queue window would reject it or call it
-- uncraftable, remember that so the quest offer it's about to make can be turned away.
local function OnUseItem(funcName, bagId, slotIndex)
    if funcName ~= "UseItem" or WC.Util.IsAutomatedUse() then
        return
    end
    pending = nil
    if not WC.settings.acceptGuard or GetItemType(bagId, slotIndex) ~= ITEMTYPE_MASTER_WRIT then
        return
    end
    local writ = WC.Master.Parse(GetItemLink(bagId, slotIndex))
    if not writ then
        return
    end
    local verdict = WC.Rules.Evaluate(writ)
    if verdict.status == WC.Rules.OK then
        return
    end
    pending = { writ = writ, verdict = verdict }
    zo_callLater(function()
        if pending and pending.writ == writ then
            pending = nil
        end
    end, PENDING_TIMEOUT_MS)
end

-- After "Accept Anyway" reuses the item, the offer that follows is accepted the same way
-- WritCrafter's own Accept Crafted Writs accepts its own offers: no need for you to click again.
local function OnQuestOffered()
    if forceAccept then
        forceAccept = false
        zo_callLater(function()
            AcceptOfferedQuest()
            ResetChatter()
        end, FORCE_ACCEPT_MS)
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
        return false
    end
    local writ, verdict = pending.writ, pending.verdict
    pending = nil
    ResetChatter()
    ZO_Dialogs_ShowDialog(DIALOG_NAME, { link = writ.link },
        { mainTextParams = { WC.Util.ItemName(writ.link), verdict.reasons[1] or "" } })
    return true
end

function Guard.Init()
    SecurePostHook("CallSecureProtected", OnUseItem)
    ZO_PreHook("AcceptOfferedQuest", CheckAccept)
    EVENT_MANAGER:RegisterForEvent(WC.name .. "AcceptGuard", EVENT_QUEST_OFFERED, OnQuestOffered)
    ESO_Dialogs[DIALOG_NAME] = {
        title = { text = SI_WRITCRAFTER_ACCEPT_BLOCKED_TITLE },
        mainText = { text = SI_WRITCRAFTER_ACCEPT_BLOCKED_TEXT },
        buttons = {
            { text = SI_WRITCRAFTER_ACCEPT_ANYWAY, callback = function(dialog) AcceptAnyway(dialog.data) end },
            { text = SI_DIALOG_CANCEL },
        },
    }
end
