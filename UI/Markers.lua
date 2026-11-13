local WC = WritCrafter

-- Station markers for master writs (PLAN milestone 5, step 4): a tinted quest marker floating
-- over each crafting station in a house where one of your master writs can be made. Houses only:
-- out in the world you're standing at the station when you need it.
--   Where stations are: read from the house's furniture (Data/Stations.lua by furniture ID, then
--   the name, then what you've used there). A Grand Master station you've used is remembered too
--   (house and owner, position), in case its furnishing is missing from the table.
--   Which writs: Off (the default), every sealed master writ in your backpack not yet crafted
--   for, or only queued ones; accepted master writs still to craft count in both.
--   Essential Housing Tools: while its master writ markers are on, WritCrafter draws none at all
--   and its setting is greyed out (it's the newcomer).
-- Drawn with the game's 3D render space: a texture at a world position, turned to face the
-- camera each frame while any marker is shown.
local Markers = {}
WC.Markers = Markers

Markers.OFF, Markers.ALL, Markers.QUEUED = "off", "all", "queued"

local TEXTURE      = "EsoUI/Art/FloatingMarkers/repeatableQuest_icon_assisted.dds"
local COLOR        = { 0.25, 0.85, 1, 1 }   -- cyan: apart from the game's white quest markers and EHT's gold ones
local SIZE_M       = 1.2                     -- marker size in metres
local HEIGHT_CM    = 300                     -- above where you stood at the station
local SAME_SPOT_CM = 300                     -- a recorded station this close is the same station
local REFRESH_MS   = 500

local window, camera
local pool, shown = {}, {}   -- texture controls; the ones in use

-- Essential Housing Tools ------------------------------------------------------------------------

-- Whether Essential Housing Tools is marking master writ stations. Read defensively: it isn't ours.
function Markers.EhtMarking()
    if not (EHT and EHT.GetSetting) then
        return false
    end
    local ok, writs = pcall(EHT.GetSetting, "ShowMasterWritPOIs")
    local okAll, all = pcall(EHT.GetSetting, "ShowPOIs")
    return ok and writs == true and (not okAll or all ~= false)
end

function Markers.Mode()
    if Markers.EhtMarking() then
        return Markers.OFF
    end
    return WC.settings.stationMarkers or Markers.OFF
end

-- Remembering stations ---------------------------------------------------------------------------

-- Where you are: the zone, or in a house, the house and its owner (another player's house of the
-- same kind has its stations elsewhere).
local function LocationKey()
    local zoneId = GetUnitRawWorldPosition("player")
    local houseId = GetCurrentZoneHouseId and GetCurrentZoneHouseId() or 0
    if houseId ~= 0 then
        return string.format("house:%d:%s", houseId, GetCurrentHouseOwner() or "")
    end
    return string.format("zone:%d", zoneId or 0)
end

local function Known()
    WC.sv.stations = WC.sv.stations or {}
    return WC.sv.stations
end

-- The set of the smithing station you're at: 0 for a plain station, nil when unknown.
local PROBE_STYLES = { 0, 1 }
local function StationSet()
    for patternIndex = 1, GetNumSmithingPatterns() do
        local _, _, _, numMaterials = GetSmithingPatternInfo(patternIndex)
        if (numMaterials or 0) > 0 then
            local _, _, quantity = GetSmithingPatternMaterialItemInfo(patternIndex, 1)
            for _, styleId in ipairs(PROBE_STYLES) do
                local link = GetSmithingPatternResultLink(patternIndex, 1, quantity or 1, styleId, 1)
                if link and link ~= "" then
                    local _, _, _, _, _, setId = GetItemLinkSetInfo(link)
                    if setId and setId ~= 0 then
                        return setId
                    end
                    break
                end
            end
        end
    end
    return 0
end

local SMITHING = {
    [CRAFTING_TYPE_BLACKSMITHING] = true, [CRAFTING_TYPE_CLOTHIER] = true,
    [CRAFTING_TYPE_WOODWORKING] = true, [CRAFTING_TYPE_JEWELRYCRAFTING] = true,
}

local function OnStationInteract(_, craft)
    if not craft or craft == CRAFTING_TYPE_INVALID then
        return
    end
    -- Markers are for houses only; out in the world nothing is recorded.
    if not (GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0) then
        return
    end
    local _, x, y, z = GetUnitRawWorldPosition("player")
    if not x then
        return
    end
    local record = { craft = craft, x = x, y = y, z = z, set = 0 }
    if SMITHING[craft] then
        if GetCraftingInteractionMode() == CRAFTING_INTERACTION_MODE_CONSOLIDATED_STATION then
            record.gm = true
        else
            record.set = StationSet()
        end
    end
    -- In a house: the station furniture you're at may have a name without its craft ("Maormer
    -- Cookfire"); remember which craft that kind of furniture is.
    Markers.LearnFurnitureKind(craft, x, y, z)
    local key = LocationKey()
    local list = Known()[key] or {}
    Known()[key] = list
    for index, other in ipairs(list) do
        local dx, dy, dz = other.x - x, other.y - y, other.z - z
        if other.craft == craft and dx * dx + dy * dy + dz * dz < SAME_SPOT_CM * SAME_SPOT_CM then
            list[index] = record   -- the same station: keep the latest spot and set
            Markers.RefreshSoon()
            return
        end
    end
    list[#list + 1] = record
    Markers.RefreshSoon()
end

-- Which stations to mark ---------------------------------------------------------------------------

-- The writs to find stations for: { craft, setId } (setId nil outside smithing).
local function WritsToMark(mode)
    local list = {}
    local function Add(writ)
        list[#list + 1] = { craft = writ.craft, setId = SMITHING[writ.craft] and writ.setId or nil }
    end
    if mode == Markers.QUEUED then
        for _, entry in ipairs(WC.Queue.List()) do
            local status = WC.Reservations.GetWritStatus(entry.uid)
            if not (status and status.crafted) then
                Add(entry.writ)
            end
        end
    else
        for slotIndex in WC.Inventory.Slots(BAG_BACKPACK) do
            if GetItemType(BAG_BACKPACK, slotIndex) == ITEMTYPE_MASTER_WRIT then
                local writ = WC.Master.Parse(GetItemLink(BAG_BACKPACK, slotIndex))
                local status = writ and WC.Reservations.GetWritStatus(WC.Util.UniqueId(BAG_BACKPACK, slotIndex))
                if writ and not (status and status.crafted) and WC.Rules.GetStatus(writ) ~= WC.Rules.CANNOT then
                    Add(writ)
                end
            end
        end
    end
    -- Accepted master writs still to craft, in either mode.
    for _, entry in ipairs(WC.Master.Accepted()) do
        if entry.condition then
            Add(entry.writ)
        end
    end
    return list
end

-- Stations in a house, from its furniture ---------------------------------------------------------
-- The game says nothing about a station furniture item but its name: "Blacksmithing Station (Law
-- of Julianos)". The craft is found by the first word of the game's own craft names
-- ("Blacksmithing", "Jewelry" from "Jewelry Crafting"), and the set by the bracketed text, which
-- the game cuts short on long names ("(Whitestrake's)", "(Might of the Lost Legion"), so a writ's
-- set matches when its name starts with that text. Grand Master stations carry no set in their
-- name: those come from your visits. Read once per house, again when furniture changes.

local CRAFTING_STATION_SUBCATEGORY = 104   -- furniture subcategory "Crafting Stations" (as EHT uses)
local STATION_CRAFTS = {
    CRAFTING_TYPE_BLACKSMITHING, CRAFTING_TYPE_CLOTHIER, CRAFTING_TYPE_WOODWORKING,
    CRAFTING_TYPE_JEWELRYCRAFTING, CRAFTING_TYPE_ALCHEMY, CRAFTING_TYPE_ENCHANTING,
    CRAFTING_TYPE_PROVISIONING,
}
local FURNITURE_HEIGHT_CM = 250   -- above the station's own position (its base)

local craftWords   -- { { craft, word } }, from the game's craft names
local function CraftWords()
    if not craftWords then
        craftWords = {}
        for _, craft in ipairs(STATION_CRAFTS) do
            local name = WC.Util.CraftName(craft):lower()
            local word = name:match("^(%S+)")
            if word then
                craftWords[#craftWords + 1] = { craft = craft, word = word }
            end
        end
    end
    return craftWords
end

-- Reads a station furniture name: its craft (or nil) and bracketed set text (or nil).
local function ParseStationName(name)
    local lower = zo_strformat("<<1>>", name):lower()
    local craft
    for _, entry in ipairs(CraftWords()) do
        if lower:find(entry.word, 1, true) then
            craft = entry.craft
            break
        end
    end
    local setText = lower:match("%(([^%)]+)")
    if setText then
        setText = zo_strtrim(setText)
        if setText == "" then
            setText = nil
        end
    end
    return craft, setText
end

local function InHouse()
    return GetCurrentZoneHouseId and GetCurrentZoneHouseId() ~= 0
end

local houseStations, houseStationsKey
local function ForgetHouseStations()
    houseStations, houseStationsKey = nil, nil
end

-- Kinds of station furniture whose name doesn't say the craft, learned when you use one:
-- [furnitureDataId] = craft. The ID is the same for that furniture in every house.
local function FurnitureKinds()
    WC.sv.stationKinds = WC.sv.stationKinds or {}
    return WC.sv.stationKinds
end

-- Every crafting station in the house you're in: { craft, setText, x, y, z, name, dataId, furniture }.
local function HouseStations()
    if not InHouse() then
        return {}
    end
    local key = LocationKey()
    if houseStations and houseStationsKey == key then
        return houseStations
    end
    local list = {}
    local furnitureId = GetNextPlacedHousingFurnitureId()
    while furnitureId do
        local name, _, dataId = GetPlacedHousingFurnitureInfo(furnitureId)
        if dataId and dataId ~= 0 then
            local _, subcategoryId = GetFurnitureDataCategoryInfo(dataId)
            if subcategoryId == CRAFTING_STATION_SUBCATEGORY then
                -- Known furnishing first (any language), then the name, then what you've used.
                local known = WC.Data.Stations.ByFurnitureId(dataId)
                local nameCraft, setText = ParseStationName(name or "")
                local craft = (known and known.craft) or nameCraft or FurnitureKinds()[dataId]
                local x, y, z = HousingEditorGetFurnitureWorldPosition(furnitureId)
                if x then
                    list[#list + 1] = { craft = craft, gm = known and known.gm or nil,
                        named = known ~= nil or nameCraft ~= nil,
                        setText = setText, x = x, y = y + FURNITURE_HEIGHT_CM - HEIGHT_CM, z = z,
                        name = zo_strformat("<<1>>", name or ""), dataId = dataId, furniture = true }
                end
            end
        end
        furnitureId = GetNextPlacedHousingFurnitureId(furnitureId)
    end
    houseStations, houseStationsKey = list, key
    return list
end

-- You opened a station of this craft at (x, y, z): if the nearest station furniture's name
-- doesn't say its craft, remember it for that kind of furniture.
local LEARN_RADIUS_CM = 400   -- you stand right at the station you use; anything farther is another
function Markers.LearnFurnitureKind(craft, x, y, z)
    if not InHouse() then
        return
    end
    local nearest, nearestDistance
    for _, station in ipairs(HouseStations()) do
        local dx, dz = station.x - x, station.z - z
        local distance = dx * dx + dz * dz
        if distance < LEARN_RADIUS_CM * LEARN_RADIUS_CM and (not nearestDistance or distance < nearestDistance) then
            nearest, nearestDistance = station, distance
        end
    end
    if nearest and not nearest.named and nearest.dataId and FurnitureKinds()[nearest.dataId] ~= craft then
        FurnitureKinds()[nearest.dataId] = craft
        ForgetHouseStations()
    end
end

local setNameCache = {}
local function SetNameLower(setId)
    local name = setNameCache[setId]
    if not name then
        name = zo_strformat("<<1>>", GetItemSetName(setId)):lower()
        setNameCache[setId] = name
    end
    return name
end

local function StationFits(station, writ)
    if not station.craft or station.craft ~= writ.craft then
        return false
    end
    if not writ.setId then
        return true
    end
    if station.gm then
        return WC.GrandMaster.HasSet(writ.craft, writ.setId)
    end
    if station.furniture then
        return station.setText ~= nil and SetNameLower(writ.setId):sub(1, #station.setText) == station.setText
    end
    return station.set == writ.setId
end

-- The stations to mark here: houses only (out in the world you're at the station when you need
-- it). The house's furniture covers everything, Grand Master stations included; a Grand Master
-- station you've used is only added when the furniture didn't show one for that craft (a
-- furnishing missing from Data/Stations.lua), so nothing is marked twice.
local function StationsHere()
    if not InHouse() then
        return {}
    end
    local list, furnitureGm = {}, {}
    for _, station in ipairs(HouseStations()) do
        list[#list + 1] = station
        if station.gm then
            furnitureGm[station.craft] = true
        end
    end
    for _, station in ipairs(Known()[LocationKey()] or {}) do
        if station.gm and not furnitureGm[station.craft] then
            list[#list + 1] = station
        end
    end
    return list
end

-- Drawing ----------------------------------------------------------------------------------------

local created = 0
local function AcquireMarker()
    local marker = table.remove(pool)
    if not marker then
        created = created + 1
        marker = WINDOW_MANAGER:CreateControl(WC.name .. "Marker" .. created, window, CT_TEXTURE)
        marker:SetTexture(TEXTURE)
    end
    marker:Create3DRenderSpace()
    marker:SetColor(unpack(COLOR))   -- every time: a fresh render space may not keep it
    marker:Set3DLocalDimensions(SIZE_M, SIZE_M)
    marker:Set3DRenderSpaceUsesDepthBuffer(false)
    marker:SetHidden(false)
    return marker
end

local function ReleaseAll()
    for _, marker in ipairs(shown) do
        marker:SetHidden(true)
        marker:Destroy3DRenderSpace()
        pool[#pool + 1] = marker
    end
    ZO_ClearTable(shown)
end

-- Each frame while markers are shown: place them (the render space's origin can move) and turn
-- them to face the camera.
local function OnUpdate()
    Set3DRenderSpaceToCurrentCamera(camera:GetName())
    local fX, fY, fZ = camera:Get3DRenderSpaceForward()
    local rX, rY, rZ = camera:Get3DRenderSpaceRight()
    local uX, uY, uZ = camera:Get3DRenderSpaceUp()
    for _, marker in ipairs(shown) do
        marker:Set3DRenderSpaceOrigin(WorldPositionToGuiRender3DPosition(marker.wcX, marker.wcY, marker.wcZ))
        marker:Set3DRenderSpaceForward(fX, fY, fZ)
        marker:Set3DRenderSpaceRight(rX, rY, rZ)
        marker:Set3DRenderSpaceUp(uX, uY, uZ)
    end
end

local markedStations = {}   -- [station record] = true while it has a marker (for /wc stations)

function Markers.Refresh()
    if not window then
        return
    end
    ReleaseAll()
    ZO_ClearTable(markedStations)
    local mode = Markers.Mode()
    local stations = mode ~= Markers.OFF and StationsHere()
    if stations and #stations > 0 then
        local writs = WritsToMark(mode)
        for _, station in ipairs(stations) do
            for _, writ in ipairs(writs) do
                if StationFits(station, writ) then
                    local marker = AcquireMarker()
                    marker.wcX, marker.wcY, marker.wcZ = station.x, station.y + HEIGHT_CM, station.z
                    shown[#shown + 1] = marker
                    markedStations[station] = true
                    break
                end
            end
        end
    end
    local name = WC.name .. "Markers"
    if #shown > 0 then
        EVENT_MANAGER:RegisterForUpdate(name, 0, OnUpdate)
        OnUpdate()
    else
        EVENT_MANAGER:UnregisterForUpdate(name)
    end
end

function Markers.RefreshSoon()
    local name = WC.name .. "MarkersRefresh"
    EVENT_MANAGER:UnregisterForUpdate(name)
    EVENT_MANAGER:RegisterForUpdate(name, REFRESH_MS, function()
        EVENT_MANAGER:UnregisterForUpdate(name)
        Markers.Refresh()
    end)
end

-- /wc stations ------------------------------------------------------------------------------------
-- What the markers are working from: the mode, the stations learned here (and which are marked),
-- and, in a house, every crafting station in its furniture with what the game says about it
-- (to see whether house stations could be found without opening them).

local LIST_SHOWN = 15

local Say = WC.Log.Say

local function Distance(x, y, z)
    local _, px, py, pz = GetUnitRawWorldPosition("player")
    if not px then
        return 0
    end
    local dx, dy, dz = x - px, y - py, z - pz
    return zo_sqrt(dx * dx + dy * dy + dz * dz) / 100
end

local CraftName = WC.Util.CraftName

function Markers.Diagnose()
    local eht
    if not EHT then
        eht = GetString(SI_WRITCRAFTER_STATIONS_EHT_NONE)
    else
        eht = GetString(Markers.EhtMarking() and SI_WRITCRAFTER_STATIONS_EHT_ON or SI_WRITCRAFTER_STATIONS_EHT_OFF)
    end
    Say(zo_strformat(SI_WRITCRAFTER_STATIONS_MODE, Markers.Mode(), WC.settings.stationMarkers or Markers.OFF, eht, #shown))

    local showAll = WC.settings.logLevel >= WC.Log.LEVEL_DEBUG
    -- The writs markers are looked for, as the chosen mode would pick them (even if it's Off now).
    local mode = WC.settings.stationMarkers or Markers.OFF
    local writs = WritsToMark(mode == Markers.OFF and Markers.ALL or mode)
    Say(zo_strformat(SI_WRITCRAFTER_STATIONS_WRITS, #writs))
    for index, writ in ipairs(writs) do
        if index > LIST_SHOWN and not showAll then
            Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_MORE, #writs - LIST_SHOWN))
            break
        end
        local set = writ.setId and zo_strformat("<<1>>", GetItemSetName(writ.setId)) or "-"
        local gm = writ.setId and WC.GrandMaster.HasSet(writ.craft, writ.setId)
        Say(zo_strformat(SI_WRITCRAFTER_STATIONS_WRIT_ROW, CraftName(writ.craft), set, GetString(gm and SI_YES or SI_NO)))
    end

    local key = LocationKey()
    local stations = Known()[key] or {}
    Say(zo_strformat(SI_WRITCRAFTER_STATIONS_HERE, key, #stations))
    for index, station in ipairs(stations) do
        if index > LIST_SHOWN and not showAll then
            Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_MORE, #stations - LIST_SHOWN))
            break
        end
        local what
        if station.gm then
            what = GetString(SI_WRITCRAFTER_QUEUE_STATION_GM)
        elseif station.set and station.set ~= 0 then
            what = zo_strformat("<<1>>", GetItemSetName(station.set))
        else
            what = "-"
        end
        Say(zo_strformat(SI_WRITCRAFTER_STATIONS_ROW, CraftName(station.craft), what,
            string.format("%.1f", Distance(station.x, station.y, station.z)),
            GetString(markedStations[station] and SI_YES or SI_NO)))
    end

    if not InHouse() then
        return
    end
    -- This house's crafting stations, read from their furniture names (the same list the markers
    -- use, so "marked" is accurate).
    local stationsInHouse = HouseStations()
    local recognised, marked, unknown = 0, {}, {}
    for _, station in ipairs(stationsInHouse) do
        if station.craft then
            recognised = recognised + 1
        else
            unknown[#unknown + 1] = station.name
        end
        if markedStations[station] then
            marked[#marked + 1] = station
        end
    end
    Say(zo_strformat(SI_WRITCRAFTER_STATIONS_FURNITURE, #stationsInHouse, recognised, #marked))
    for index, station in ipairs(marked) do
        if index > LIST_SHOWN and not showAll then
            Say(zo_strformat(SI_WRITCRAFTER_SELFTEST_MORE, #marked - LIST_SHOWN))
            break
        end
        Say(zo_strformat(SI_WRITCRAFTER_STATIONS_FURNITURE_ROW, station.name,
            string.format("%.1f", Distance(station.x, station.y, station.z))))
    end
    if #unknown > 0 then
        Say(zo_strformat(SI_WRITCRAFTER_STATIONS_UNKNOWN, table.concat(unknown, ", ")))
    end
end

function Markers.Init()
    window = WINDOW_MANAGER:CreateTopLevelWindow(WC.name .. "Markers")
    window:SetAnchorFill(GuiRoot)
    window:SetDrawLayer(DL_BACKGROUND)
    window:SetMouseEnabled(false)
    camera = WINDOW_MANAGER:CreateControl(WC.name .. "MarkersCamera", window, CT_CONTROL)
    camera:Create3DRenderSpace()
    -- Only out in the world (the HUD), not over menus and windows.
    local fragment = ZO_SimpleSceneFragment:New(window)
    HUD_SCENE:AddFragment(fragment)
    HUD_UI_SCENE:AddFragment(fragment)

    -- Stations recorded out in the world before markers became houses-only: no longer used.
    for key in pairs(Known()) do
        if key:find("^zone:") then
            Known()[key] = nil
        end
    end

    local namespace = WC.name .. "Markers"
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_CRAFTING_STATION_INTERACT, OnStationInteract)
    EVENT_MANAGER:RegisterForEvent(namespace, EVENT_PLAYER_ACTIVATED, function()
        ForgetHouseStations()
        Markers.RefreshSoon()
    end)
    local function OnFurnitureChanged()
        ForgetHouseStations()
        Markers.RefreshSoon()
    end
    for _, event in ipairs({ EVENT_HOUSING_FURNITURE_PLACED, EVENT_HOUSING_FURNITURE_REMOVED }) do
        if event then
            EVENT_MANAGER:RegisterForEvent(namespace .. tostring(event), event, OnFurnitureChanged)
        end
    end
    WC.Inventory.AddListener(Markers.RefreshSoon)
    WC.Daily.OnJournalChanged(Markers.RefreshSoon)
end
