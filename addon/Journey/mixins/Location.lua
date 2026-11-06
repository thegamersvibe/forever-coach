--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

LocationMixin = { }

function LocationMixin:Activate()
    LocationsService.SetActiveLocation(self)
end

function LocationMixin:GetMap()
    return self.map
end

function LocationMixin:GetTooltipLabel(useAlt)
    if (self.npc) then
        local npcColor = NPCColor
        if (useAlt) then
            npcColor = NPCAltColor
        end
        local name = Names.GetName(GetCreatureName, self.npc)
        local npcInfo = NPCs[self.npc]
        if (npcInfo) then
            name = string.format("|c%s%s|r", npcColor[GetNPCReaction(self.npc)], name)
        end
        return string.format(self.label or npcInfo and NPCRaces[npcInfo.race] and "%s (%s %s)" or "%s",
                name, npcInfo and NPCRaces[npcInfo.race] or "", npcInfo and NPCGenders[npcInfo.gender] or "")
    end
    if (self.label or self.quest or self.gameobject or self.area or self.wmoarea or self.item or self.zone
            or self.taxi) then
        local subject = self.quest and (type(self.quest) == "number" and Names.GetQuestName(self.quest) or self.quest)
                or self.gameobject and (type(self.gameobject) == "number" and Names.GetGameObjectName(self.gameobject) or self.gameobject)
                or self.area and (type(self.area) == "number" and Names.GetName(C_Map.GetAreaInfo, self.area) or self.area)
                or self.wmoarea and (type(self.wmoarea) == "number" and Names.GetName(PlacesService.GetWMOAreaName, self.wmoarea) or self.wmoarea)
                or self.item and (type(self.item) == "number" and Names.GetName(GetItemInfo, self.item) or self.item)
                or self.zone and (type(self.zone) == "number" and Names.GetName(GetMapName, self.zone) or self.zone)
                or self.taxi and (type(self.taxi) == "number" and Names.GetName(TaxiService.GetTaxiName, self.taxi) or self.taxi)
        if (subject) then
            subject = string.format("|c%s%s|r",
                    self.quest and (useAlt and Color.QUEST_ALT or Color.QUEST)
                            or self.gameobject and (useAlt and Color.GAME_OBJECT_ALT or Color.GAME_OBJECT)
                            or self.area and (useAlt and Color.AREA_ALT or Color.AREA)
                            or self.wmoarea and (useAlt and Color.WMOAREA_ALT or Color.WMOAREA)
                            or self.item and (useAlt and Color.ITEM_ALT or Color.ITEM)
                            or self.zone and (useAlt and Color.ZONE_ALT or Color.ZONE)
                            or self.taxi and (useAlt and Color.TAXI_ALT or Color.TAXI),
                    subject)
        end
        return string.format(self.label or "%s", subject)
    end
    if (Flags.HasFlag(self, "H")) then
        return "Hidden"
    end
    return "Follow Waypoint"
end

function LocationMixin:GetXY(mapID)
    if (self.map == mapID) then
        return self.x, self.y
    end
    if (not self[mapID]) then
        local continentID, worldPosition = C_Map.GetWorldPosFromMapPos(self.map, { x = self.x / 100, y = self.y / 100 })
        if (not worldPosition) then return end
        local _, mapPosition = C_Map.GetMapPosFromWorldPos(continentID, worldPosition, mapID)
        if (not mapPosition) then return end
        self[mapID] = {
            x = mapPosition.x * 100,
            y = mapPosition.y * 100
        }
    end
    return self[mapID].x, self[mapID].y
end

function LocationMixin:HasExited()
    return GuideNavigationService.GetGuide().bookmark.exited[self.idx]
end


function LocationMixin:HasVisited()
    return GuideNavigationService.GetGuide().bookmark.visited[self.idx]
end

function LocationMixin:IsActive()
    return self == LocationsService.GetActiveLocation()
end

function LocationMixin:IsPlayerWithin()
    return self.within
end

function LocationMixin:IsValidCheckpoint()
    return CheckCondition(self) and Flags.HasFlag(self, "C")
end

function LocationMixin:IsNavigationSuppressed()
    return self.polygon ~= nil and self.within
end

function LocationMixin:IsShown()
    if (self:IsNavigationSuppressed()) then return false end
    return Flags.HasFlag(self, "V") or (self:IsActive() and not Flags.HasFlag(self, "H"))
end

function LocationMixin:ResetFlags()
    self.flags = self.originalFlags
end

function LocationMixin:SetFlags(flags)
    self.flags = flags
end
