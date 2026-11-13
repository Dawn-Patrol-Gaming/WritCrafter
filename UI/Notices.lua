local WC = WritCrafter

-- On-screen notices drawn above the crafting window: a short message in the top-right corner
-- (progress, "crafting started", "done") and a large banner in the middle for problems. The
-- game's own alerts and centre-screen announcements are part of the HUD, which is hidden at a
-- station, and chat is rolled up there too, so these are WritCrafter's own labels.
local Notices = {}
WC.Notices = Notices

local CORNER_MS = 4000
local BANNER_MS = 6000

local corner
local banner

-- Hides a notice once its time is up, unless it was shown again since.
local function HideLater(window, ms)
    zo_callLater(function()
        if GetGameTimeMilliseconds() - window.shownAt >= ms - 50 then
            window:SetHidden(true)
        end
    end, ms)
end

-- A short message in the top-right corner. Its right edge stays put, so longer text grows to the
-- left. Shown whatever the settings say; callers check On-Screen Notices.
function Notices.Corner(text)
    if not corner then
        corner = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "Corner")
        corner:SetDrawTier(DT_HIGH)
        corner:SetDrawLayer(DL_OVERLAY)
        corner:SetMouseEnabled(false)
        corner:SetDimensions(10, 10)
        corner:SetAnchor(TOPRIGHT, GuiRoot, TOPRIGHT, -40, 4)   -- above the station's tab icons
        corner.label = WINDOW_MANAGER:CreateControl(WC.name .. "CornerText", corner, CT_LABEL)
        corner.label:SetFont("ZoFontWinH2")
        corner.label:SetColor(1, 0.9, 0.6, 1)
        corner.label:SetHorizontalAlignment(TEXT_ALIGN_RIGHT)
        corner.label:SetAnchor(TOPRIGHT, corner, TOPRIGHT, 0, 0)
    end
    corner.label:SetText(text)
    corner:SetHidden(false)
    corner.shownAt = GetGameTimeMilliseconds()
    HideLater(corner, CORNER_MS)
end

local function BannerLabel(name, font, offsetY)
    local label = WINDOW_MANAGER:CreateControl(WC.name .. name, banner, CT_LABEL)
    label:SetFont(font)
    label:SetColor(1, 0.45, 0.3, 1)
    label:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
    label:SetDimensionConstraints(0, 0, 1100, 0)
    label:SetAnchor(TOP, banner, TOP, 0, offsetY)
    return label
end

-- A large message in the middle of the screen: a title and a line of detail (the reason itself,
-- since chat isn't visible at a station). Only with On-Screen Notices on.
function Notices.Banner(title, detail)
    if not WC.settings.craftNotice then
        return
    end
    if not banner then
        banner = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "Banner")
        banner:SetDrawTier(DT_HIGH)
        banner:SetDrawLayer(DL_OVERLAY)
        banner:SetMouseEnabled(false)
        banner:SetDimensions(1100, 200)
        banner:SetAnchor(CENTER, GuiRoot, CENTER, 0, -200)
        banner.title = BannerLabel("BannerTitle", "ZoFontCallout3", 0)
        banner.detail = BannerLabel("BannerDetail", "ZoFontWinH1", 70)
        banner.detail:SetColor(1, 0.8, 0.6, 1)
    end
    banner.title:SetText(title)
    banner.detail:SetText(detail or "")
    banner:SetHidden(false)
    banner.shownAt = GetGameTimeMilliseconds()
    HideLater(banner, BANNER_MS)
end
