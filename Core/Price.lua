local WC = WritCrafter

local Price = {}
WC.Price = Price

Price.SOURCES = { "auto", "esohub", "mm", "ttc", "att" }

local SOURCE_NAMES = {
    esohub = SI_WRITCRAFTER_SOURCE_ESOHUB,
    mm     = SI_WRITCRAFTER_SOURCE_MM,
    ttc    = SI_WRITCRAFTER_SOURCE_TTC,
    att    = SI_WRITCRAFTER_SOURCE_ATT,
}

-- [link] = { gold or false, sourceKey }. Prices barely move within a session.
local cache = {}

-- Price libraries are called through pcall: prices feed inventory row setup, where one
-- library error would break the whole list. Results are captured into locals first because
-- a bare `return` gives no value at all, and tonumber() with no argument throws.
local function FromEsoHub(link)
    if not (LibEsoHubPrices and LibEsoHubPrices.GetSimpleItemPrice) then
        return nil
    end
    local ok, result = pcall(LibEsoHubPrices.GetSimpleItemPrice, link)
    local gold = ok and tonumber(result) or nil
    if gold and gold > 0 then
        return gold, "esohub"
    end
    return nil
end

-- sourceKey nil searches the market sources only. Asking LibPrice with no list would also
-- search Furniture Catalogue, Rolis and the NPC vendor, and a vendor price of a few gold
-- would make anything without market data look cheap.
local function FromLibPrice(link, sourceKey)
    if not (LibPrice and LibPrice.ItemLinkToPriceGold) then
        return nil
    end
    local ok, gold, source
    if sourceKey then
        ok, gold, source = pcall(LibPrice.ItemLinkToPriceGold, link, sourceKey)
    else
        ok, gold, source = pcall(LibPrice.ItemLinkToPriceGold, link, "mm", "att", "ttc")
    end
    gold = ok and tonumber(gold) or nil
    if gold and gold > 0 then
        return gold, source
    end
    return nil
end

local function Lookup(link)
    local mode = WC.settings.priceSource
    if mode == "esohub" then
        return FromEsoHub(link)
    elseif mode == "auto" then
        local gold, source = FromEsoHub(link)
        if gold then
            return gold, source
        end
        return FromLibPrice(link)
    end
    return FromLibPrice(link, mode)
end

function Price.Init()
end

function Price.ClearCache()
    ZO_ClearTable(cache)
end

-- Returns gold per unit and the source key, or nil when no source has data.
function Price.Get(link)
    local hit = cache[link]
    if hit then
        if hit[1] then
            return hit[1], hit[2]
        end
        return nil
    end
    local gold, source = Lookup(link)
    cache[link] = { gold or false, source }
    return gold, source
end

function Price.GetById(itemId)
    return Price.Get(WC.Inventory.GetLink(itemId))
end

function Price.SourceName(sourceKey)
    local stringId = SOURCE_NAMES[sourceKey]
    return stringId and GetString(stringId) or tostring(sourceKey)
end

function Price.Format(gold)
    if gold >= 100 then
        return ZO_CommaDelimitNumber(zo_round(gold))
    end
    return string.format("%.1f", gold)
end
