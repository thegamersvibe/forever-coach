--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("Waypoints")

local arrow = addon.CreateArrow(0, 1, 0)
local currentWaypoint, currentLocation, tooltipLabel, tooltipAltLabel, pingSetting, tomtomSetting, screenArrowSetting, lastSuppressed
local currentGuideID

arrow.tooltip = {
	Show = function(this)
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(this, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPRIGHT", this, "BOTTOMRIGHT", 0, 0)
		GameTooltip:SetText(tooltipLabel, 1, 1, 1)
		GameTooltip:Show()
	end,
	Hide = function()
		GameTooltip:Hide()
	end
}

function component.RemoveCurrentLocation()
	currentLocation = nil
end

function component.Update()
	if (component:IsDirty()) then
		if (GuideNavigationService.IsGuideSet() and ManualWaypointService.GetWaypoint()) then
			ManualWaypointService.Clear(true)
		end
		ManualWaypointService.CheckArrival()
		local activeLocation = LocationsService.GetActiveLocation()
		if (GhostService.IsSpiritRessing() and UnitIsDeadOrGhost("player")) then
			if (UnitIsGhost("player")) then
				local location = State.GetLastSpiritHealerLocation()
				if (location) then
					local _, mapPosition = C_Map.GetMapPosFromWorldPos(location.continentID, location, location.mapID)
					activeLocation = {
						x = mapPosition.x * 100,
						y = mapPosition.y * 100,
						map = location.mapID,
						GetTooltipLabel = function()
							return "Spirit Healer"
						end,
						IsNavigationSuppressed = function()
							return false
						end,
					}
				end
			end
		end
		local changed = false
		local guideID = GuideNavigationService.IsGuideSet() and GuideNavigationService.GetGuide().id or nil
		if (guideID ~= currentGuideID) then
			currentGuideID = guideID
			currentLocation = nil
			arrow:ClearTarget()
			if (TomTom and currentWaypoint) then
				TomTom:RemoveWaypoint(currentWaypoint)
				currentWaypoint = nil
			end
			tooltipLabel = nil
			tooltipAltLabel = nil
			arrow.screenLabel = nil
			changed = true
		end
		if (State.IsMapPingAnimationEnabled() ~= pingSetting) then
			changed = true
			pingSetting = State.IsMapPingAnimationEnabled()
		end
		if (State.IsTomTomSupportEnabled() ~= tomtomSetting) then
			changed = true
			tomtomSetting = State.IsTomTomSupportEnabled()
		end
		if (State.IsScreenArrowEnabled() ~= screenArrowSetting) then
			changed = true
			screenArrowSetting = State.IsScreenArrowEnabled()
		end
		if (currentLocation ~= activeLocation) then
			currentLocation = activeLocation
			changed = true
		end
		if (currentLocation) then
			local newLabel = currentLocation:GetTooltipLabel()
			if (tooltipLabel ~= newLabel) then
				changed = true
			end
			local suppressed = currentLocation:IsNavigationSuppressed()
			if (suppressed ~= lastSuppressed) then
				changed = true
				lastSuppressed = suppressed
			end
		else
			if (lastSuppressed) then
				lastSuppressed = nil
			end
		end
		if (changed) then
			local showNavigation = currentLocation and not currentLocation:IsNavigationSuppressed()
			if (showNavigation) then
				arrow:SetTarget(currentLocation.x / 100, currentLocation.y / 100, currentLocation.map, not State.IsMapPingAnimationEnabled())
				tooltipLabel = currentLocation:GetTooltipLabel()
				tooltipAltLabel = currentLocation:GetTooltipLabel(true)
				arrow.screenLabel = tooltipAltLabel
			else
				arrow:ClearTarget()
				if (not currentLocation) then
					tooltipLabel = nil
					tooltipAltLabel = nil
				end
				arrow.screenLabel = nil
			end
			QuestTrackingService.Update()
			if (TomTom) then
				if (currentWaypoint) then
					TomTom:RemoveWaypoint(currentWaypoint)
					currentWaypoint = nil
				end
				if (showNavigation and State.IsScreenArrowEnabled() and State.IsTomTomSupportEnabled()) then
					local arrivaldistance = 1
					if (currentLocation.radius ~= 0) then
						arrivaldistance = currentLocation.radius
					end
					currentWaypoint = TomTom:AddWaypoint(currentLocation.map, currentLocation.x / 100, currentLocation.y / 100, {
						title = tooltipAltLabel,
						persistent = false,
						minimap = false,
						world = false,
						cleardistance = 0,
						arrivaldistance = arrivaldistance,
					})
				end
			end
		end
		component:MarkClean()
	end
end

UI.Add(component)
