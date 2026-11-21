local WC = WritCrafter

-- Asks before a sealed master writ you can't craft (your settings reject it, or you don't know
-- the recipe, motif or trait) turns into a quest. Using the item offers the quest in one step,
-- with no normal way to back out once you click Accept, so this steps in a moment earlier: when
-- the quest is offered for a writ used by hand (not through WritCrafter's own Accept Crafted
-- Writs, which only ever uses writs whose items are already made), it runs the writ through the
-- same check as the queue window, and if that check would reject or cannot-craft it, the offer is
-- turned away before it's accepted, with a dialog asking whether to take it anyway.
--
-- Which writ: UseItem is private (it can't be hooked, even after the call), and the offer's text
-- only names the craft. But however the game's inventory uses an item (double-click, the Use key,
-- right-click -> Use, gamepad), it first asks IsItemUsable(bag, slot) about that exact item, then
-- calls ClearCursor, then UseItem, all in one go. So the item IsItemUsable was last asked about,
-- in the same frame as a ClearCursor, is the one being used. Add-ons that use writs go through
-- CallSecureProtected, which is watched directly.
local Guard = {}
WC.AcceptGuard = Guard

local USE_MS          = 5000    -- longest between using a writ and its quest being offered
local FORCE_ACCEPT_MS = 300     -- "Accept Anyway": as Writs/Rolis.lua waits for its own offers

-- { writ, verdict }: the offer on screen is for this writ, which would be rejected. Kept until
-- the next quest offer (every Accept follows an offer, so it can't reach another quest), however
-- long you take to click.
local pending
local askedBag, askedSlot, askedMs   -- the item IsItemUsable was last asked about, and when
local used         -- { bagId, slotIndex, link, ms, how }: a writ just used, by hand or by an add-on
local inChatter     -- true while talking to an NPC: its quest offers are never a writ's
local skipNext      -- true: the next AcceptOfferedQuest (from "Accept Anyway") is let through
local forceAccept   -- true: accept the next quest offer ourselves, without the player clicking

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

-- Called often (the inventory asks it about many items): kept to three assignments.
local function OnIsItemUsable(bagId, slotIndex)
    askedBag, askedSlot, askedMs = bagId, slotIndex, GetFrameTimeMilliseconds()
end

-- Right before the game's inventory uses an item, just after IsItemUsable was asked about it.
-- ClearCursor is called at other times too: if a writ happened to be asked about in the same
-- frame, that leaves a `used` that no quest offer follows, and it expires.
local function OnClearCursor()
    if not (WC.settings.acceptGuard and askedBag and askedMs == GetFrameTimeMilliseconds()) then
        return
    end
    local bagId, slotIndex = askedBag, askedSlot
    askedBag, askedSlot, askedMs = nil, nil, nil
    if GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
        used = { bagId = bagId, slotIndex = slotIndex, ms = GetFrameTimeMilliseconds(), how = "by hand",
            link = GetItemLink(bagId, slotIndex) }
    end
end

-- Add-ons use items through CallSecureProtected. WritCrafter's own uses (Accept Crafted Writs,
-- "Accept Anyway") are never checked, and the offer they bring isn't another writ's.
local function OnSecureCall(funcName, bagId, slotIndex)
    if funcName ~= "UseItem" then
        return
    end
    used = nil
    if not WC.Util.IsAutomatedUse() and GetItemType(bagId, slotIndex) == ITEMTYPE_MASTER_WRIT then
        used = { bagId = bagId, slotIndex = slotIndex, ms = GetFrameTimeMilliseconds(), how = "add-on",
            link = GetItemLink(bagId, slotIndex) }
    end
end

-- A quest is offered. After "Accept Anyway" reuses the item, the offer is accepted the same way
-- WritCrafter's own Accept Crafted Writs accepts its own offers: no need for you to click again.
-- Otherwise, if it follows a sealed writ just used, that writ is checked.
local function OnQuestOffered()
    pending = nil
    local writ = used
    used = nil
    if forceAccept then
        forceAccept = false
        zo_callLater(function()
            AcceptOfferedQuest()
            ResetChatter()
        end, FORCE_ACCEPT_MS)
        return
    end
    if not WC.settings.acceptGuard or not writ then
        return
    end
    local age = GetFrameTimeMilliseconds() - writ.ms
    if inChatter or age > USE_MS or GetItemLink(writ.bagId, writ.slotIndex) ~= writ.link then
        Debug("Accept guard: quest offered, not checked (writ used %d ms ago, %s, talking to an NPC: %s)",
            age, writ.how, tostring(inChatter == true))
        return
    end
    Check(writ.bagId, writ.slotIndex, "used (" .. writ.how .. ")")
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
    Debug("Accept guard: Accept clicked for %s: turned away", pending.writ.link)
    local writ, verdict = pending.writ, pending.verdict
    pending = nil
    ResetChatter()
    ZO_Dialogs_ShowDialog(DIALOG_NAME, { link = writ.link },
        { mainTextParams = { WC.Util.ItemName(writ.link), verdict.reasons[1] or "" } })
    return true
end

function Guard.Init()
    SecurePostHook("CallSecureProtected", OnSecureCall)
    SecurePostHook("IsItemUsable", OnIsItemUsable)
    SecurePostHook("ClearCursor", OnClearCursor)
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
