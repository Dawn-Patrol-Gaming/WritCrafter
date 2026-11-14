local WC = WritCrafter

-- Writ reward handling (PLAN milestone 6, step 1).
--   Boxes: a container that lands in your backpack within a few seconds of completing a crafting
--   quest is a writ reward box (no box names or descriptions, so it works in any language). It's
--   opened right away when that's on, you're out of combat and there's backpack room; otherwise
--   it's remembered and opened as soon as it can be (also after a relog).
--   What's inside: each item is sorted into a reward kind (materials, surveys, master writs, ...)
--   and that kind's action is applied: Leave in bag, Junk (now), Deposit (the next time you open
--   your bank) or Sell (the next time you open a merchant). Chat lists what each box gave.
--   Never touched: locked or FCO ItemSaver-marked items, and items set aside for writs. Only what
--   the box gave is moved or sold; a stack it merged into keeps the rest.
local Rewards = {}
WC.Rewards = Rewards

Rewards.LEAVE, Rewards.DEPOSIT, Rewards.JUNK, Rewards.SELL = "leave", "deposit", "junk", "sell"
Rewards.OPEN = "open"   -- writ and survey containers only: unpack them
Rewards.DECONSTRUCT = "deconstruct"   -- at the next matching station or deconstruction assistant
Rewards.KEEP_STACK = "keepStack"   -- at merchants, sell what rewards gave beyond one full stack

-- Reward kinds, in settings order, with the actions each allows and the default (Leave in bag
-- when none is given).
local L, D, J, S, O = Rewards.LEAVE, Rewards.DEPOSIT, Rewards.JUNK, Rewards.SELL, Rewards.OPEN
local K, X = Rewards.KEEP_STACK, Rewards.DECONSTRUCT
Rewards.KINDS = {
    -- Containers of sealed master writs or survey reports stay closed unless you choose Open.
    { key = "writContainers",  actions = { L, O, D }, default = D },
    { key = "surveyContainers", actions = { L, O, D }, default = D },
    -- Any other container a box gives ("Shipment of Ingots"): opened by default, like Dolgubon's.
    { key = "containers",       actions = { L, O, D }, default = O },
    { key = "materials",   actions = { L, D, J, S }, default = D },
    { key = "improvement", actions = { L, D, J, S }, default = D },
    { key = "surveys",     actions = { L, D, J, S }, default = D },
    { key = "masterWrits", actions = { L, D }, default = D },
    { key = "repairKits",  actions = { L, D, J, S, K }, default = K },
    { key = "ornate",      actions = { L, D, J, S, X }, default = X },
    { key = "intricate",   actions = { L, D, J, S, X }, default = X },
    -- Purple gear with a trait to research ("Exemplary Swift Ring"); worth banking or selling.
    { key = "researchGear", actions = { L, D, J, S }, default = D },
    { key = "soulGems",    actions = { L, D, K }, default = K },
    { key = "glyphs",      actions = { L, D, J, S, X }, default = X },
    -- Recipes by quality: e.g. sell the green ones, bank the blue and purple ones for a guild trader.
    { key = "recipesFine",     actions = { L, D, J, S }, default = S },   -- white and green
    { key = "recipesSuperior", actions = { L, D, J, S }, default = D },   -- blue
    { key = "recipesEpic",     actions = { L, D, J, S }, default = D },   -- purple and gold
    { key = "psijic",      actions = { L, D }, default = D },
    -- Not from boxes: what a writ craft makes beyond what the writ needs (potions, poisons, food,
    -- drink; skills make several per craft). They share a stack with the writ's items, so no Junk.
    { key = "extras",      actions = { L, D, S }, default = S },
}

local BOX_WINDOW_MS   = 8000    -- a container this soon after a crafting quest completes is its reward
local LOOT_WINDOW_MS  = 2500    -- items arriving this long after a box is opened came from it
local MIN_FREE_SLOTS  = 4       -- room needed before a box is opened
local OPEN_GAP_MS     = 1200    -- between boxes
local RETRY_MS        = 3000    -- after the game didn't open a box
local MAX_ATTEMPTS    = 3       -- tries per box before it's left for you

local Say = WC.Util.Say

local Uid = WC.Util.UniqueId

-- Saved per character: boxes waiting to be opened, and items waiting for the bank or a merchant.
local function State()
    local character = WC.character
    character.rewardBoxes = character.rewardBoxes or {}   -- [uid] = true
    character.rewardTodo = character.rewardTodo or {}     -- [uid] = { action, quantity, link }
    character.rewardStack = character.rewardStack or {}   -- [itemId] = { quantity, link }: Keep a Stack
    return character
end

-- Sorting ---------------------------------------------------------------------------------------

local BOOSTERS = {
    [ITEMTYPE_BLACKSMITHING_BOOSTER] = true, [ITEMTYPE_CLOTHIER_BOOSTER] = true,
    [ITEMTYPE_WOODWORKING_BOOSTER] = true, [ITEMTYPE_JEWELRYCRAFTING_BOOSTER] = true,
}
local GLYPHS = { [ITEMTYPE_GLYPH_ARMOR] = true, [ITEMTYPE_GLYPH_WEAPON] = true, [ITEMTYPE_GLYPH_JEWELRY] = true }
local ORNATE = {
    [ITEM_TRAIT_TYPE_ARMOR_ORNATE] = true, [ITEM_TRAIT_TYPE_WEAPON_ORNATE] = true, [ITEM_TRAIT_TYPE_JEWELRY_ORNATE] = true,
}
local INTRICATE = {
    [ITEM_TRAIT_TYPE_ARMOR_INTRICATE] = true, [ITEM_TRAIT_TYPE_WEAPON_INTRICATE] = true,
    [ITEM_TRAIT_TYPE_JEWELRY_INTRICATE] = true,
}

-- Stackable containers of sealed master writs or survey reports, by item ID (one per craft;
-- the same IDs Dolgubon's Lazy Writ Crafter uses).
local WRIT_CONTAINERS = {
    [217917] = true, [217918] = true, [217919] = true, [217920] = true,
    [217921] = true, [217922] = true, [217923] = true,
}
local SURVEY_CONTAINERS = {
    [219849] = true, [219850] = true, [219851] = true, [219852] = true, [219853] = true, [219854] = true,
}

-- The reward kind of an item link, or nil (anything else is left alone).
function Rewards.KindOf(link)
    local itemId = GetItemLinkItemId(link)
    if WRIT_CONTAINERS[itemId] then
        return "writContainers"
    elseif SURVEY_CONTAINERS[itemId] then
        return "surveyContainers"
    end
    local itemType, specialized = GetItemLinkItemType(link)
    if (itemType == ITEMTYPE_CONTAINER or itemType == ITEMTYPE_CONTAINER_STACKABLE)
        and specialized ~= SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE then
        return "containers"
    end
    if itemType == ITEMTYPE_MASTER_WRIT then
        return "masterWrits"
    elseif specialized == SPECIALIZED_ITEMTYPE_TROPHY_SURVEY_REPORT then
        return "surveys"
    elseif specialized == SPECIALIZED_ITEMTYPE_TROPHY_RECIPE_FRAGMENT then
        return "psijic"
    elseif itemType == ITEMTYPE_RECIPE then
        local quality = GetItemLinkFunctionalQuality(link)
        if quality >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT then
            return "recipesEpic"
        elseif quality == ITEM_FUNCTIONAL_QUALITY_ARCANE then
            return "recipesSuperior"
        end
        return "recipesFine"
    elseif itemType == ITEMTYPE_SOUL_GEM then
        return "soulGems"
    elseif GLYPHS[itemType] then
        return "glyphs"
    elseif itemType == ITEMTYPE_TOOL then
        return "repairKits"
    elseif BOOSTERS[itemType] then
        return "improvement"
    elseif itemType == ITEMTYPE_WEAPON or itemType == ITEMTYPE_ARMOR then
        local trait = GetItemLinkTraitInfo(link)
        if ORNATE[trait] then
            return "ornate"
        elseif INTRICATE[trait] then
            return "intricate"
        end
        if trait ~= ITEM_TRAIT_TYPE_NONE and GetItemLinkFunctionalQuality(link) >= ITEM_FUNCTIONAL_QUALITY_ARTIFACT then
            return "researchGear"
        end
        return nil
    elseif CanItemLinkBeVirtual(link) then
        return "materials"   -- anything the craft bag takes: raw and refined materials, runes, ...
    end
end

-- Each kind's default action (Leave in bag unless the kind says otherwise).
function Rewards.DefaultFor(kind)
    for _, entry in ipairs(Rewards.KINDS) do
        if entry.key == kind then
            return entry.default or Rewards.LEAVE
        end
    end
    return Rewards.LEAVE
end

-- Kinds split up later fall back to the old kind's choice (Recipes became three by quality).
local FORMERLY = { recipesFine = "recipes", recipesSuperior = "recipes", recipesEpic = "recipes",
    researchGear = "researchJewelry" }

function Rewards.ActionFor(kind)
    local actions = WC.settings.rewardActions
    return (actions and (actions[kind] or (FORMERLY[kind] and actions[FORMERLY[kind]]))) or Rewards.DefaultFor(kind)
end

-- Items WritCrafter may act on: not locked, not FCO ItemSaver-marked, not set aside for a writ.
local function MayTouch(bagId, slotIndex)
    return not WC.Inventory.IsProtected(bagId, slotIndex)   -- locked or FCO ItemSaver-marked
        and WC.Reservations.GetReserved(bagId, slotIndex) == 0
end

local function Takeable(slotIndex, entry)
    local stack = GetSlotStackSize(BAG_BACKPACK, slotIndex)
    if WC.Inventory.IsProtected(BAG_BACKPACK, slotIndex) then
        return 0
    end
    if entry.extra then
        return zo_max(0, zo_min(entry.quantity, stack - WC.Reservations.GetReserved(BAG_BACKPACK, slotIndex)))
    end
    if WC.Reservations.GetReserved(BAG_BACKPACK, slotIndex) > 0 then
        return 0
    end
    return zo_min(entry.quantity, stack)
end

-- Applies a kind's action to what a box just gave (quantity of the stack at bagId/slotIndex).
-- Returns the action actually taken, for the chat summary.
local function Apply(bagId, slotIndex, quantity, link, kind)
    local action = Rewards.ActionFor(kind)
    if action == Rewards.LEAVE or bagId ~= BAG_BACKPACK then
        return Rewards.LEAVE   -- the craft bag can't be junked, sold or deposited from
    end
    if not MayTouch(bagId, slotIndex) then
        if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
            WC.Log.Debug(string.format("Reward %s left alone: protected (locked or FCO marked) %s, set aside for a writ %d",
                link, tostring(WC.Inventory.IsProtected(bagId, slotIndex)), WC.Reservations.GetReserved(bagId, slotIndex)))
        end
        return Rewards.LEAVE
    end
    if action == Rewards.KEEP_STACK then
        -- Counted per item: at the next merchant at most this many are sold, and only what's
        -- above one full stack.
        local itemId = GetItemId(bagId, slotIndex)
        local entry = State().rewardStack[itemId] or { quantity = 0, link = link }
        entry.quantity = entry.quantity + quantity
        State().rewardStack[itemId] = entry
        return Rewards.KEEP_STACK
    end
    if action == Rewards.OPEN then
        State().rewardBoxes[Uid(bagId, slotIndex)] = true   -- opened after this box, one at a time
        return Rewards.OPEN
    end
    if action == Rewards.JUNK then
        -- Junk marks the whole stack, so only when the box made the stack.
        if GetSlotStackSize(bagId, slotIndex) == quantity and CanItemBeMarkedAsJunk(bagId, slotIndex) then
            SetItemIsJunk(bagId, slotIndex, true)
            return Rewards.JUNK
        end
        return Rewards.LEAVE
    end
    -- Deposit and Sell happen at the bank or a merchant; remember what to take.
    local todo = State().rewardTodo
    local uid = Uid(bagId, slotIndex)
    local entry = todo[uid]
    if entry and entry.action == action then
        entry.quantity = entry.quantity + quantity
    else
        todo[uid] = { action = action, quantity = quantity, link = link }
    end
    return action
end

-- Extra crafted items ----------------------------------------------------------------------------

local EXTRA_WINDOW_MS = 15000   -- the crafted items land within this long of the craft starting
local expected = {}             -- { itemId, link, quantity, untilMs }

-- Called by the crafting code: this craft makes `quantity` more of resultLink than the writ needs.
function Rewards.ExpectExtra(resultLink, quantity)
    if Rewards.ActionFor("extras") == Rewards.LEAVE or quantity <= 0 then
        return
    end
    expected[#expected + 1] = { itemId = GetItemLinkItemId(resultLink), link = resultLink, quantity = quantity,
        untilMs = GetFrameTimeMilliseconds() + EXTRA_WINDOW_MS }
end

-- Crafted items landed in the backpack: if extras were expected for them, remember those for the
-- bank or a merchant. Returns true when it was such an item.
local function TakeExtra(slotIndex, stackCountChange)
    local now = GetFrameTimeMilliseconds()
    local itemId = GetItemId(BAG_BACKPACK, slotIndex)
    for index = #expected, 1, -1 do
        local extra = expected[index]
        if now > extra.untilMs then
            table.remove(expected, index)
        elseif extra.itemId == itemId then
            table.remove(expected, index)
            local quantity = zo_min(extra.quantity, stackCountChange)
            local action = Rewards.ActionFor("extras")
            local todo = State().rewardTodo
            local uid = Uid(BAG_BACKPACK, slotIndex)
            local entry = todo[uid]
            if entry and entry.action == action and entry.extra then
                entry.quantity = entry.quantity + quantity
            else
                todo[uid] = { action = action, quantity = quantity, link = extra.link, extra = true }
            end
            if WC.settings.rewardSummary then
                local stringId = action == Rewards.DEPOSIT and SI_WRITCRAFTER_REWARD_DID_DEPOSIT or SI_WRITCRAFTER_REWARD_DID_SELL
                Say(SI_WRITCRAFTER_REWARD_EXTRA, quantity, extra.link, GetString(stringId))
            end
            return true
        end
    end
    return false
end

-- Opening boxes ---------------------------------------------------------------------------------

local opening          -- { uid, until, gave = { lines } } while a box is being opened
local completedAt = 0  -- when a crafting quest last completed

local ACTION_STRING = {
    [Rewards.DEPOSIT] = SI_WRITCRAFTER_REWARD_DID_DEPOSIT,
    [Rewards.JUNK]    = SI_WRITCRAFTER_REWARD_DID_JUNK,
    [Rewards.SELL]    = SI_WRITCRAFTER_REWARD_DID_SELL,
    [Rewards.OPEN]    = SI_WRITCRAFTER_REWARD_DID_OPEN,
    [Rewards.KEEP_STACK] = SI_WRITCRAFTER_REWARD_DID_KEEP_STACK,
    [Rewards.DECONSTRUCT] = SI_WRITCRAFTER_REWARD_DID_DECONSTRUCT,
}

-- Backpack slots by unique ID: [uid] = slotIndex, read in one pass, so looking up every waiting
-- box or remembered item costs one walk over the backpack instead of one walk each.
local function BackpackSlots()
    local slots = {}
    for slotIndex in WC.Inventory.Slots(BAG_BACKPACK) do
        slots[Uid(BAG_BACKPACK, slotIndex)] = slotIndex
    end
    return slots
end

local function FindByUid(uid)
    return BackpackSlots()[uid]
end

-- Progress through a run of boxes, shown in the top-right corner: "Opening writ rewards: 3 of 12".
local runOpened = 0
local attempts = {}   -- [uid] = times the game didn't open it

-- A box is only crossed off once it's really been opened (it's gone, or its stack is smaller):
-- the game ignores using an item at some moments (seen 2026-11-11: mid-conversation at a
-- delivery crate), and such a box is tried again a little later, a few times.
local function FinishOpening()
    if not opening then
        return
    end
    local uid = opening.uid
    local slotIndex = FindByUid(uid)
    local left = slotIndex and GetSlotStackSize(BAG_BACKPACK, slotIndex) or 0
    local delay = OPEN_GAP_MS
    if left < opening.stack then
        attempts[uid] = nil
        if left == 0 then
            State().rewardBoxes[uid] = nil   -- a stack stays listed until it's used up
        end
        if WC.settings.rewardSummary and #opening.gave > 0 then
            Say(SI_WRITCRAFTER_REWARD_GAVE, table.concat(opening.gave, ", "))
        end
    else
        runOpened = zo_max(runOpened - 1, 0)
        attempts[uid] = (attempts[uid] or 0) + 1
        if attempts[uid] >= MAX_ATTEMPTS then
            State().rewardBoxes[uid] = nil   -- left for you to open
            attempts[uid] = nil
        end
        WC.Log.Debug(string.format("Reward box not opened (try %d)", attempts[uid] or MAX_ATTEMPTS))
        delay = RETRY_MS
    end
    opening = nil
    zo_callLater(Rewards.OpenWaiting, delay)
end

local function Progress(text)
    if WC.settings.craftNotice then
        WC.Notices.Corner(text)
    end
end

-- How many boxes are still waiting (a stack of containers counts each one).
local function WaitingCount(slots)
    local count = 0
    for uid in pairs(State().rewardBoxes) do
        local slotIndex = slots[uid]
        if slotIndex then
            count = count + GetSlotStackSize(BAG_BACKPACK, slotIndex)
        end
    end
    return count
end

function Rewards.OpenWaiting()
    if opening or not WC.settings.rewardOpenBoxes then
        return
    end
    local boxes = State().rewardBoxes
    local uid = next(boxes)
    if not uid then
        if runOpened > 0 then
            Progress(zo_strformat(SI_WRITCRAFTER_REWARD_PROGRESS_DONE, runOpened))
            runOpened = 0
        end
        return
    end
    -- Not in combat, nor while talking to anyone or using a station, bank or merchant (the game
    -- ignores opening a box then); tried again when that ends, or on the next bag change.
    if IsUnitInCombat("player") or GetNumBagFreeSlots(BAG_BACKPACK) < MIN_FREE_SLOTS
        or GetInteractionType() ~= INTERACTION_NONE then
        return
    end
    local slots = BackpackSlots()
    local slotIndex = slots[uid]
    if not slotIndex then
        boxes[uid] = nil   -- opened by hand, moved or gone
        zo_callLater(Rewards.OpenWaiting, 0)
        return
    end
    local waiting = WaitingCount(slots)   -- this box included
    runOpened = runOpened + 1
    Progress(zo_strformat(SI_WRITCRAFTER_REWARD_PROGRESS, runOpened, runOpened - 1 + waiting))
    opening = { uid = uid, gave = {}, stack = GetSlotStackSize(BAG_BACKPACK, slotIndex) }
    opening.untilMs = GetFrameTimeMilliseconds() + LOOT_WINDOW_MS
    WC.Util.UseItem(BAG_BACKPACK, slotIndex)
    zo_callLater(function()
        if opening and opening.uid == uid and GetFrameTimeMilliseconds() >= opening.untilMs then
            FinishOpening()
        end
    end, LOOT_WINDOW_MS + 100)
end

-- The game's loot window, when it opens for our box: take everything.
local function OnLootUpdated()
    if opening then
        LootAll()
    end
end

-- Quiet looting: while WritCrafter opens one of its boxes, the loot window isn't drawn at all
-- (otherwise it flashes up for each box). Done the way Dolgubon's does it, by stepping in before
-- the game's loot window updates; any other loot window is left alone. A hook on the game's own
-- window (not an API function), so it's guarded: if that window isn't found, boxes still open,
-- with the window showing briefly.
local lootHooked = false
local function HookLootWindow()
    if lootHooked or not (SYSTEMS and SYSTEMS.GetObject) then
        return
    end
    local lootSystem = SYSTEMS:GetObject("loot")
    if not (lootSystem and lootSystem.UpdateLootWindow) then
        return
    end
    ZO_PreHook(lootSystem, "UpdateLootWindow", function()
        if opening then
            LootAll()
            EndLooting()
            return true   -- our box: don't draw the window
        end
        return false
    end)
    lootHooked = true
end

local function OnLootClosed()
    if opening then
        opening.untilMs = GetFrameTimeMilliseconds() + 800   -- last items may still be landing
        local uid = opening.uid
        zo_callLater(function()
            if opening and opening.uid == uid then
                FinishOpening()
            end
        end, 900)
    end
end

local function OnSlotUpdate(_, bagId, slotIndex, isNewItem, _, _, stackCountChange)
    if bagId ~= BAG_BACKPACK and bagId ~= BAG_VIRTUAL then
        return
    end
    local now = GetFrameTimeMilliseconds()
    local fromBox = opening and now <= opening.untilMs
    -- A box arriving shortly after a crafting quest completed (not something a box just gave:
    -- writ and survey containers inside a reward box are its contents).
    if not fromBox and bagId == BAG_BACKPACK and isNewItem and now - completedAt < BOX_WINDOW_MS then
        local itemType, specialized = GetItemType(bagId, slotIndex)
        local kind = Rewards.KindOf(GetItemLink(bagId, slotIndex))
        if itemType == ITEMTYPE_CONTAINER and specialized ~= SPECIALIZED_ITEMTYPE_CONTAINER_STYLE_PAGE
            and kind ~= "writContainers" and kind ~= "surveyContainers" then
            State().rewardBoxes[Uid(bagId, slotIndex)] = true
            zo_callLater(Rewards.OpenWaiting, 500)
            return
        end
    end
    -- Extra crafted items (not from a box).
    if not fromBox and bagId == BAG_BACKPACK and (stackCountChange or 0) > 0 and #expected > 0
        and TakeExtra(slotIndex, stackCountChange) then
        return
    end
    -- Items from the box being opened.
    if fromBox and (stackCountChange or 0) > 0 then
        local link = GetItemLink(bagId, slotIndex)
        local kind = Rewards.KindOf(link)
        local action = kind and Apply(bagId, slotIndex, stackCountChange, link, kind) or Rewards.LEAVE
        if WC.settings.logLevel >= WC.Log.LEVEL_DEBUG then
            WC.Log.Debug(string.format("Reward %s: bag %d, kind %s, setting %s, done %s", link, bagId,
                tostring(kind), kind and Rewards.ActionFor(kind) or "-", tostring(action)))
        end
        local text = zo_strformat("<<1>> x <<2>>", stackCountChange, link)
        if ACTION_STRING[action] then
            text = text .. " " .. GetString(ACTION_STRING[action])
        end
        opening.gave[#opening.gave + 1] = text
    end
end

local function OnQuestComplete(_, _, _, _, _, _, questType)
    if questType == QUEST_TYPE_CRAFTING then
        completedAt = GetFrameTimeMilliseconds()
    end
end

-- Bank and merchant ------------------------------------------------------------------------------

-- Empty bank slots (the ESO Plus bank's too, when subscribed), listed once: moves land a moment
-- later, so asking for "the first empty slot" per item gives every item the same slot and only
-- the first move goes through (seen 2026-11-11).
local function EmptyBankSlots()
    local slots = {}
    local bags = { BAG_BANK }
    if IsESOPlusSubscriber() then
        bags[#bags + 1] = BAG_SUBSCRIBER_BANK
    end
    for _, bagId in ipairs(bags) do
        for slotIndex = 0, GetBagSize(bagId) - 1 do
            if GetItemId(bagId, slotIndex) == 0 then
                slots[#slots + 1] = { bagId, slotIndex }
            end
        end
    end
    return slots
end

-- Moves the remembered Deposit items into the bank (only what the boxes gave).
local function OnOpenBank(_, bankBag)
    if bankBag ~= BAG_BANK then
        return
    end
    local todo = State().rewardTodo
    local moved = 0
    local empties, nextEmpty = nil, 1
    local slots = BackpackSlots()
    for uid, entry in pairs(todo) do
        if entry.action == Rewards.DEPOSIT then
            local slotIndex = slots[uid]
            if not slotIndex then
                todo[uid] = nil
            elseif Takeable(slotIndex, entry) > 0 then
                empties = empties or EmptyBankSlots()
                local dest = empties[nextEmpty]
                if not dest then
                    Say(SI_WRITCRAFTER_REWARD_BANK_FULL)
                    break
                end
                nextEmpty = nextEmpty + 1
                local destBag, destSlot = dest[1], dest[2]
                local quantity = Takeable(slotIndex, entry)
                WC.Util.MoveItem(BAG_BACKPACK, slotIndex, destBag, destSlot, quantity)
                todo[uid] = nil
                moved = moved + 1
            else
                todo[uid] = nil   -- locked or set aside since: leave it
            end
        end
    end
    if moved > 0 then
        Say(SI_WRITCRAFTER_REWARD_DEPOSITED, moved)
    end
end

-- Sells the remembered Sell items (only what the boxes gave).
local function OnOpenStore()
    local todo = State().rewardTodo
    local sold = 0
    local slots = BackpackSlots()
    for uid, entry in pairs(todo) do
        if entry.action == Rewards.SELL then
            local slotIndex = slots[uid]
            local quantity = slotIndex and Takeable(slotIndex, entry) or 0
            if quantity > 0 then
                SellInventoryItem(BAG_BACKPACK, slotIndex, quantity)
                sold = sold + 1
            end
            todo[uid] = nil
        end
    end
    if sold > 0 then
        Say(SI_WRITCRAFTER_REWARD_SOLD, sold)
    end
    Rewards.SellBeyondStack()
end

-- Keep a Stack, Sell the Rest: only what writ rewards gave is ever sold (counted per item as the
-- boxes are opened), and only the part of it above one full stack in the backpack, smallest
-- stacks first. What you had before is never sold (seen 2026-11-11: counting the whole backpack
-- sold hundreds of soul gems that weren't from rewards). The counts are cleared after each
-- merchant visit: what's left is part of the stack you keep. Locked, FCO ItemSaver-marked,
-- writ, Crown Store, stolen and junk-marked items are left out.
function Rewards.SellBeyondStack()
    local fromRewards = State().rewardStack
    if not next(fromRewards) then
        return
    end
    local byItem = {}   -- [itemId] = { maxStack, slots = { { slotIndex, count } } }
    for slotIndex in WC.Inventory.Slots(BAG_BACKPACK) do
        local itemId = GetItemId(BAG_BACKPACK, slotIndex)
        local link = fromRewards[itemId] and GetItemLink(BAG_BACKPACK, slotIndex)
        local kind = link and Rewards.KindOf(link)
        local crown = IsItemFromCrownStore and IsItemFromCrownStore(BAG_BACKPACK, slotIndex)
        if kind and Rewards.ActionFor(kind) == Rewards.KEEP_STACK and MayTouch(BAG_BACKPACK, slotIndex) and not crown
            and not IsItemStolen(BAG_BACKPACK, slotIndex) and not IsItemJunk(BAG_BACKPACK, slotIndex) then
            local count, maxStack = GetSlotStackSize(BAG_BACKPACK, slotIndex)
            local entry = byItem[itemId] or { maxStack = maxStack, slots = {}, total = 0, link = link }
            byItem[itemId] = entry
            entry.slots[#entry.slots + 1] = { slotIndex = slotIndex, count = count }
            entry.total = entry.total + count
        end
    end
    for itemId, entry in pairs(byItem) do
        local excess = zo_min(entry.total - entry.maxStack, fromRewards[itemId].quantity)
        if excess > 0 then
            table.sort(entry.slots, function(a, b) return a.count < b.count end)
            local soldCount = 0
            for _, slot in ipairs(entry.slots) do
                if excess <= 0 then
                    break
                end
                local quantity = zo_min(slot.count, excess)
                SellInventoryItem(BAG_BACKPACK, slot.slotIndex, quantity)
                excess = excess - quantity
                soldCount = soldCount + quantity
            end
            Say(SI_WRITCRAFTER_REWARD_SOLD_EXTRA, soldCount, entry.link, entry.maxStack)
        end
    end
    ZO_ClearTable(fromRewards)
end

-- Deconstruction --------------------------------------------------------------------------------
-- Items marked Deconstruct are taken apart at the next crafting station that can (the gear's own
-- craft, enchanting for glyphs), or at a deconstruction assistant, which takes everything. All of
-- them at once, in one batch, the way the game's deconstruction screen sends several selected
-- items (Dolgubon's did them one at a time, which usually stopped after one or two). It runs as a
-- job of the crafting engine, after any writ crafting at that station.

local MAX_PER_BATCH = 50   -- the rest go in the next batch

-- Which station takes an item apart: enchanting for glyphs, the gear's own craft otherwise.
local function DeconstructCraft(bagId, slotIndex)
    if GLYPHS[GetItemType(bagId, slotIndex)] then
        return CRAFTING_TYPE_ENCHANTING
    end
    return GetItemLinkCraftingSkillType(GetItemLink(bagId, slotIndex))
end

-- A deconstruction assistant (or any universal deconstruction station) takes every craft's items.
local function AtUniversalDeconstruction()
    return CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION ~= nil
        and GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_UNIVERSAL_DECONSTRUCTION
end

-- Reward items waiting to be taken apart here: { uid, slotIndex, quantity }. Items gone, locked
-- or set aside for a writ since are forgotten.
local function DeconstructItems(skill)
    local todo = State().rewardTodo
    local items, slots = {}, nil
    local universal = AtUniversalDeconstruction()
    for uid, entry in pairs(todo) do
        if entry.action == Rewards.DECONSTRUCT then
            slots = slots or BackpackSlots()
            local slotIndex = slots[uid]
            if not slotIndex then
                todo[uid] = nil
            elseif universal or DeconstructCraft(BAG_BACKPACK, slotIndex) == skill then
                local quantity = Takeable(slotIndex, entry)
                if quantity > 0 then
                    items[#items + 1] = { uid = uid, slotIndex = slotIndex, quantity = quantity }
                else
                    todo[uid] = nil
                end
            end
        end
    end
    return items
end

local function DeconstructJobs(skill)
    if not next(State().rewardTodo) or #DeconstructItems(skill) == 0 then
        return {}
    end
    return { {
        id       = "rewards:deconstruct",
        source   = "rewards",
        label    = GetString(SI_WRITCRAFTER_REWARD_DECONSTRUCT_LABEL),
        State    = function() return #DeconstructItems(skill) > 0 and "active" or "done" end,
        Progress = function() return -#DeconstructItems(skill) end,
        Craft    = function()
            local items = DeconstructItems(skill)
            if #items == 0 then
                return false
            end
            PrepareDeconstructMessage()
            local added = 0
            for index, item in ipairs(items) do
                if index > MAX_PER_BATCH then
                    break
                end
                if AddItemToDeconstructMessage(BAG_BACKPACK, item.slotIndex, item.quantity) then
                    added = added + 1
                else
                    State().rewardTodo[item.uid] = nil   -- the game won't take this one apart: forget it
                end
            end
            if added == 0 then
                return false, GetString(SI_WRITCRAFTER_REWARD_DECONSTRUCT_NONE)
            end
            SendDeconstructMessage()
            Say(SI_WRITCRAFTER_REWARD_DECONSTRUCTING, added)
            return true
        end,
    } }
end

function Rewards.Init()
    WC.Engine.AddJobSource(DeconstructJobs)
    local namespace = WC.name .. "Rewards"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_QUEST_COMPLETE, OnQuestComplete)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_INVENTORY_SINGLE_SLOT_UPDATE, OnSlotUpdate)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_LOOT_UPDATED, OnLootUpdated)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_LOOT_CLOSED, OnLootClosed)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_OPEN_BANK, OnOpenBank)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_OPEN_STORE, OnOpenStore)
    -- Boxes left waiting (no room, combat, a relog): try again when things change.
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat then
            zo_callLater(Rewards.OpenWaiting, 1000)
        end
    end)
    -- Boxes wait out conversations, stations, the bank and merchants.
    for _, event in ipairs({ EVENT_CHATTER_END, EVENT_END_CRAFTING_STATION_INTERACT, EVENT_CLOSE_BANK,
        EVENT_CLOSE_STORE }) do
        EVENT_MANAGER:RegisterForEvent(namespace .. "Free" .. event, event, function()
            zo_callLater(Rewards.OpenWaiting, 1000)
        end)
    end
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
        HookLootWindow()   -- the loot window may only exist once the UI is up
        zo_callLater(Rewards.OpenWaiting, 3000)
    end)
    HookLootWindow()
    -- Room may have been made: try once bag changes settle.
    WC.Inventory.AddListener(function()
        if opening or not next(State().rewardBoxes) then
            return
        end
        WC.Util.Later("RewardsRetry", 1500, Rewards.OpenWaiting)
    end)
end
