--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local frame = CreateFrame("Frame")

local areaCache
local currentAreaID
local currentContinentID
local currentWMOAreaID
local currentParentWMOAreaID

local OnEvent, Refresh

function OnEvent(_, event)
    if (event == "ZONE_CHANGED" or event == "ZONE_CHANGED_INDOORS" or event == "ZONE_CHANGED_NEW_AREA") then
        Refresh()
        MarkAllDirty()
    end
end

function Refresh()
    currentAreaID = nil
    currentWMOAreaID = nil
    currentParentWMOAreaID = nil
    currentContinentID = nil
    local mapID = C_Map.GetBestMapForUnit("player")
    local position = mapID and C_Map.GetPlayerMapPosition(mapID, "player")
    if (position) then
        currentContinentID = C_Map.GetWorldPosFromMapPos(mapID, position)
    end
    local subZoneText = GetSubZoneText()
    local zoneText = GetZoneText()
    if (subZoneText) then
        currentAreaID = areaCache[subZoneText]
        currentWMOAreaID = WMOAreas[subZoneText]
    end
    if (zoneText) then
        if (not currentAreaID) then
            currentAreaID = areaCache[zoneText]
        end
        if (not currentWMOAreaID) then
            currentWMOAreaID = WMOAreas[zoneText]
        end
        currentParentWMOAreaID = WMOAreas[zoneText] or currentWMOAreaID
    end
    if (not currentAreaID) then
        if (position) then
            local exploredAreaIDs = C_MapExplorationInfo.GetExploredAreaIDsAtPosition(mapID, position);
            if (exploredAreaIDs) then
                for _, areaID in ipairs(exploredAreaIDs) do
                    local name = C_Map.GetAreaInfo(areaID);
                    if name then
                        currentAreaID = areaCache[name]
                        break
                    end
                end
            end
        end
    end
end

PlacesService = { }

function PlacesService.GetCurrentAreaID()
    return currentAreaID
end

function PlacesService.GetCurrentContinentID()
    return currentContinentID
end

function PlacesService.GetCurrentParentWMOAreaID()
    return currentParentWMOAreaID
end

function PlacesService.GetCurrentWMOAreaID()
    return currentWMOAreaID
end

function PlacesService.GetWMOAreaName(id)
    return WMOAreasLUT[id]
end

function PlacesService.Init()
    areaCache = { }
    for i = 1, 15000 do
        local areaName = C_Map.GetAreaInfo(i)
        if (areaName and not areaCache[areaName]) then
            areaCache[areaName] = i
        end
    end
    frame:RegisterEvent("ZONE_CHANGED")
    frame:RegisterEvent("ZONE_CHANGED_INDOORS")
    frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
    frame:SetScript("OnEvent", OnEvent)
    Refresh()
end

