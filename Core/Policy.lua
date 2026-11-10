local WC = WritCrafter

local Policy = {}
WC.Policy = Policy

Policy.MIMIC_NEVER  = "never"
Policy.MIMIC_NEEDED = "needed"   -- when the style material is too expensive or you have none
Policy.MIMIC_STONE_ID = 71668    -- Crown Mimic Stone
Policy.MIMIC_ALWAYS = "always"

-- Excluded without the player's own mark: style materials by vendor, then (optionally) live
-- price vs the category ceiling, then the shipped default list.
function Policy.IsExpensiveByDefault(itemId)
    local link = WC.Inventory.GetLink(itemId)
    -- Style materials: excluded unless an NPC sells them, whatever the price.
    if GetItemLinkItemType(link) == ITEMTYPE_STYLE_MATERIAL then
        return not WC.Data.PriceDefaults.IsVendorStyleMaterial(itemId)
    end
    if WC.settings.liveCeilings then
        local category = WC.Data.PriceDefaults.Category(link)
        if category then
            local gold = WC.Price.Get(link)
            if gold then
                return gold > WC.settings.ceilings[category]
            end
        end
    end
    return WC.Data.PriceDefaults.EXPENSIVE[itemId] == true
end

-- The player's own mark wins over the default.
function Policy.IsExpensive(itemId)
    local override = WC.settings.expensive[itemId]
    if override ~= nil then
        return override
    end
    return Policy.IsExpensiveByDefault(itemId)
end

-- Stores a mark only when it differs from the default, so later default changes still
-- reach items the player never touched.
function Policy.SetExpensive(itemId, value)
    if value == Policy.IsExpensiveByDefault(itemId) then
        WC.settings.expensive[itemId] = nil
    else
        WC.settings.expensive[itemId] = value
    end
end

-- By default only overland plants that aren't expensive are allowed. Reagents have one
-- switch, their own (see IsExcluded); the too-expensive marks don't apply to them.
function Policy.IsReagentAllowedByDefault(itemId)
    local reagent = WC.Data.Alchemy.REAGENTS[itemId]
    return reagent ~= nil
        and reagent.source == WC.Data.Alchemy.SOURCE_PLANT
        and not Policy.IsExpensiveByDefault(itemId)
end

-- A reagent's own checkbox has the final say.
function Policy.IsReagentAllowed(itemId)
    local override = WC.settings.reagents[itemId]
    if override ~= nil then
        return override
    end
    return Policy.IsReagentAllowedByDefault(itemId)
end

function Policy.SetReagentAllowed(itemId, value)
    if value == Policy.IsReagentAllowedByDefault(itemId) then
        WC.settings.reagents[itemId] = nil
    else
        WC.settings.reagents[itemId] = value
    end
end

-- "Excluded from writs", the single switch the settings and right-click menu show for every
-- material. Reagents are stored as their allow list (inverted), everything else as the
-- too-expensive marks.
function Policy.IsExcluded(itemId)
    if WC.Data.Alchemy.REAGENTS[itemId] then
        return not Policy.IsReagentAllowed(itemId)
    end
    return Policy.IsExpensive(itemId)
end

function Policy.IsExcludedByDefault(itemId)
    if WC.Data.Alchemy.REAGENTS[itemId] then
        return not Policy.IsReagentAllowedByDefault(itemId)
    end
    return Policy.IsExpensiveByDefault(itemId)
end

function Policy.SetExcluded(itemId, value)
    if WC.Data.Alchemy.REAGENTS[itemId] then
        Policy.SetReagentAllowed(itemId, not value)
    else
        Policy.SetExpensive(itemId, value)
    end
end

-- Anything that changes a verdict: clear cached verdicts, re-match items, redraw icons.
function Policy.Changed()
    WC.Price.ClearCache()
    WC.Rules.ClearCache()
    WC.Reservations.Invalidate()
    WC.InventoryIcons.Refresh()
    WC.ExclusionsWindow.OnPolicyChanged()
    WC.QueueWindow.OnPolicyChanged()
    WC.Markers.RefreshSoon()
end

-- Per-writ mimic choice from the queue window, per character, keyed by the sealed writ's link
-- (identical writs share it). nil = follow the Mimic stones setting.
local function MimicChoices()
    WC.character.mimic = WC.character.mimic or {}
    return WC.character.mimic
end

function Policy.MimicChoice(writLink)
    return writLink and MimicChoices()[writLink]
end

function Policy.SetMimicChoice(writLink, value)
    MimicChoices()[writLink] = value
    Policy.Changed()
end

-- Forgets choices for writs no longer in this character's bags or the bank.
function Policy.PruneMimicChoices(presentLinks)
    local choices = MimicChoices()
    for link in pairs(choices) do
        if not presentLinks[link] then
            choices[link] = nil
        end
    end
end

-- Whether a writ uses a mimic stone: its own choice if it has one, else the setting.
function Policy.UseMimicFor(writLink, styleMaterialId, ignoreStock)
    local choice = Policy.MimicChoice(writLink)
    if choice ~= nil then
        return choice
    end
    return Policy.UseMimic(styleMaterialId, ignoreStock)
end

function Policy.IsGoldExcluded(craft)
    return WC.settings.excludeGold[craft] == true
end

-- Whether a mimic stone replaces the style material for this writ. A mimic stone only stands
-- in for the material of a style you already know, so an unknown motif can't be crafted
-- whatever this says; the caller checks that first.
-- ignoreStock (badges): the "none in stock" case never changes a writ's status, so skip it.
function Policy.UseMimic(styleMaterialId, ignoreStock)
    local mode = WC.settings.mimic
    if mode == Policy.MIMIC_ALWAYS then
        return true
    elseif mode == Policy.MIMIC_NEEDED then
        return Policy.IsExpensive(styleMaterialId)
            or (not ignoreStock and WC.Inventory.GetStock(styleMaterialId).usable == 0)
    end
    return false
end
