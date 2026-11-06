--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local maps = {
	{
		mapFrame = WorldMapFrame,
		globalPinScale = 0.10,
		lineThickness = 3
	},
	{
		mapFrame = BattlefieldMapFrame,
		globalPinScale = 0.06,
		lineThickness = 1.2
	}
}

for _, v in ipairs(maps) do
	local ConnectPins, GetMapPin, GetRelativeXY, OnMapIDChanged, OnMapScaleChanged, ResetMapPin, SetPinActive,
	SetPinLocation, SetPinScale, SetPinShown

	local component = UI.CreateComponent(v.mapFrame:GetName() .. "MapPinContainer")

	local activePin
	local mapContainer = v.mapFrame.ScrollContainer.Child
	local mapFrame = v.mapFrame
	local globalPinScale = v.globalPinScale
	local lineThickness = v.lineThickness
	local playerPin
	local mapYDistanceCache = { }
	local mapPins = { }
	local spiritHealerPin
	local Waypoints

	local radiusColors = {
		checkpoint = {
			normal = { 0, 0, 1, 0.3 },
			highlighted = { 0, 0, 1, 0.7 },
			darkened = { 0, 0, 1, 0.2 },
		},
		other = {
			normal = { 1, 0, 0, 0.3 },
			highlighted = { 1, 0, 0, 0.7 },
			darkened = { 1, 0, 0, 0.2 },
		}
	}


	local function GetMapYDistance(mapID)
		local mapYDistance = mapYDistanceCache[mapID]
		if (mapYDistance) then
			return mapYDistance
		end
		local _, worldPosition1 = C_Map.GetWorldPosFromMapPos(mapID, { x = 0.5, y = 0.45 })
		local _, worldPosition2 = C_Map.GetWorldPosFromMapPos(mapID, { x = 0.5, y = 0.55 })
		-- Cannot find Y distance, probably because the player is viewing the Cosmic map
		if (not worldPosition1 or not worldPosition2) then
			return 0.1
		end
		mapYDistance = addon.GetDistanceInYards(worldPosition1.x, worldPosition1.y, worldPosition2.x, worldPosition2.y) * 10
		mapYDistanceCache[mapID] = mapYDistance
		return mapYDistance
	end

	local function GetCircleSizeForRadius(radius)
		local mapYDistance = GetMapYDistance(mapFrame:GetMapID())
		local pinsContainerHeight = component.pinsContainer:GetHeight()
		local yard = pinsContainerHeight / mapYDistance
		return radius * yard * 2
	end

	local function SetRadiusVertexColor(pin)
		pin.radius:SetVertexColor(
				unpack((Flags.HasFlag(pin.location, "C") and radiusColors.checkpoint or radiusColors.other)[pin.radiusColorType])
		)
	end

	local function OnEnter(self)
		GameTooltip:ClearLines()
		GameTooltip:SetOwner(self, "ANCHOR_NONE")
		GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 0)
		GameTooltip:SetText(self.location:GetTooltipLabel(), 1, 1, 1)
		local nextPin = self
		if (playerPin.x) then
			local totalDistance = 0
			while(not nextPin.location:IsActive() and nextPin.connected) do
				totalDistance = totalDistance + addon.GetDistanceInYards(
						nextPin.connected.location.worldX,
						nextPin.connected.location.worldY,
						nextPin.location.worldX,
						nextPin.location.worldY
				)
				nextPin = nextPin.connected
			end
			if (playerPin.connected == nextPin) then
				totalDistance = totalDistance + addon.GetDistanceInYards(
						playerPin.x,
						playerPin.y,
						nextPin.location.worldX,
						nextPin.location.worldY
				)
			else
				totalDistance = addon.GetDistanceInYards(
						playerPin.x,
						playerPin.y,
						self.location.worldX,
						self.location.worldY
				)
			end
			GameTooltip:AddLine(math.floor(totalDistance + 0.5) .. " yards away")
		else
			GameTooltip:AddLine("Unknown distance")
		end
		if (Debug.IsMapPinDebuggingEnabled("HIDDEN")) then
			GameTooltip:AddLine(string.format("Location #%s (debug)", self.location.idx))
		end
		GameTooltip:Show()
		if (Debug.IsMapPinDebuggingEnabled("HIDDEN")) then
			for _, v in ipairs(mapPins) do
				v.radiusColorType = "darkened"
				SetRadiusVertexColor(v)
			end
			self.radiusColorType = "highlighted"
			SetRadiusVertexColor(self)
		end
	end

	local function OnLeave()
		GameTooltip:Hide()
		if (Debug.IsMapPinDebuggingEnabled("HIDDEN")) then
			for _, v in ipairs(mapPins) do
				v.radiusColorType = "normal"
				SetRadiusVertexColor(v)
			end
		end
	end

	local function OnMouseDown(self)
		self:SetNormalTexture(self.active and self.activePushedTexture or self.inactivePushedTexture)
		self:SetHighlightTexture(self.active and self.activePushedHighlightTexture or self.inactivePushedHighlightTexture, "BLEND")
	end

	local function OnMouseUp(self)
		self:SetNormalTexture(self.active and self.activeNormalTexture or self.inactiveNormalTexture)
		self:SetHighlightTexture(self.active and self.activeHighlightTexture or self.inactiveHighlightTexture, "BLEND")
	end

	local function OnClick(self)
		Waypoints.RemoveCurrentLocation()
		LocationsService.SetActiveLocation(self.location)
	end

	local function OnUpdate(pin, elapsed)
		if (pin.line:IsVisible()) then
			pin.elapsed = pin.elapsed + elapsed
			if (pin.elapsed > 0.05) then
				pin.elapsed = 0
				pin.animStep = pin.animStep + 1
				if (pin.animStep == 17) then
					pin.animStep = 1
				end
				pin.line:SetTexCoord(0, 1, (pin.animOffset + pin.animStep - 1)/32, (pin.animOffset + pin.animStep)/32)
				pin.line:Hide()
				pin.line:Show()
			end
		end
		if (pin.radius and pin.radius:IsVisible()) then
			SetRadiusVertexColor(pin)
		end
	end

	function ConnectPins(pin1, pin2)
		pin1.line:SetStartPoint("CENTER", pin1.point, "CENTER", 0, 0)
		pin1.line:SetEndPoint("CENTER", pin2.point, "CENTER", 0, 0)
		pin1.connected = pin2
		pin1.line:SetShown((pin1.shown and not pin1.debugging) and (pin2.shown and not pin2.debugging))
	end

	function GetMapPin(idx)
		while (not idx or #mapPins < idx) do
			local pin = CreateFrame("Button", nil, component.pinsContainer)
			pin:SetSize(128, 128)
			pin:SetFrameLevel(4000)
			pin.point = CreateFrame("Frame", nil, component.pinsContainer)
			pin.point:SetSize(1,1)
			--pin.point:Hide()
			pin.number = pin:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
			pin.number:SetPoint("BOTTOM", pin, "TOP", 0, 2)
			pin.number:SetText(#mapPins + 1)
			pin.number:SetScale(10)
			pin.number:Hide()
			pin.radius = pin.point:CreateTexture(nil, "ARTWORK")
			pin.radius:SetTexture(I.Circle)
			pin.radius:SetPoint("CENTER")
			pin.radius:SetAlpha(0.3)
			pin.radiusColorType = "normal"
			pin.radius:SetVertexColor(unpack(radiusColors.other.normal))
			pin.radius:SetSize(50,50)
			pin.radius:Hide()
			pin.inactiveNormalTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.inactiveNormalTexture:SetTexture(I.MapButtons)
			pin.inactiveNormalTexture:SetTexCoord(0, 0.25, 0, 0.5)
			pin.activeNormalTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.activeNormalTexture:SetTexture(I.MapButtons)
			pin.activeNormalTexture:SetTexCoord(0, 0.25, 0.5, 1)
			pin.inactiveHighlightTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.inactiveHighlightTexture:SetTexture(I.MapButtons)
			pin.inactiveHighlightTexture:SetTexCoord(0.25, 0.5, 0, 0.5)
			pin.activeHighlightTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.activeHighlightTexture:SetTexture(I.MapButtons)
			pin.activeHighlightTexture:SetTexCoord(0.25, 0.5, 0.5, 1)
			pin.inactivePushedTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.inactivePushedTexture:SetTexture(I.MapButtons)
			pin.inactivePushedTexture:SetTexCoord(0.5, 0.75, 0, 0.5)
			pin.activePushedTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.activePushedTexture:SetTexture(I.MapButtons)
			pin.activePushedTexture:SetTexCoord(0.5, 0.75, 0.5, 1)
			pin.inactivePushedHighlightTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.inactivePushedHighlightTexture:SetTexture(I.MapButtons)
			pin.inactivePushedHighlightTexture:SetTexCoord(0.75, 1, 0, 0.5)
			pin.activePushedHighlightTexture = pin:CreateTexture(nil, "ARTWORK")
			pin.activePushedHighlightTexture:SetTexture(I.MapButtons)
			pin.activePushedHighlightTexture:SetTexCoord(0.75, 1, 0.5, 1)
			pin:SetNormalTexture(pin.inactiveNormalTexture)
			pin:SetHighlightTexture(pin.inactiveHighlightTexture, "BLEND")
			local scale = mapContainer:GetScale()
			pin:SetScale(globalPinScale / scale)
			pin:SetPoint("CENTER", pin.point, "CENTER")
			pin:Hide()
			if (not idx) then return pin end
			pin.line = component.pinsContainer:CreateLine()
			pin.line:SetTexture(I.Lines, "REPEAT", nil, "LINEAR")
			pin.line:SetHorizTile(true)
			pin.lineThickness = lineThickness
			pin.line:SetThickness(pin.lineThickness / scale)
			pin.line:SetAlpha(1.0)
			pin.animStep = 1
			pin.elapsed = 0
			pin:SetScript("OnUpdate", OnUpdate)
			pin.line:Hide()
			pin.animOffset = 0
			pin:SetScript("OnClick", OnClick)
			pin:SetScript("OnEnter", OnEnter)
			pin:SetScript("OnLeave", OnLeave)
			pin:SetScript("OnMouseDown", OnMouseDown)
			pin:SetScript("OnMouseUp", OnMouseUp)
			mapPins[#mapPins + 1] = pin
			pin.idx = #mapPins
		end
		return mapPins[idx]
	end

	function GetRelativeXY(frame, xCoord, yCoord)
		local frameWidth, frameHeight = frame:GetSize()
		return frameWidth * (xCoord / 100), -frameHeight * (yCoord / 100)
	end

	function OnMapIDChanged()
		component:MarkDirty()
	end

	function OnMapScaleChanged(_, scale)
		for _, pin in ipairs(mapPins) do
			SetPinScale(pin, 1 / scale)
		end
		SetPinScale(spiritHealerPin, 1 / scale)
		SetPinScale(playerPin, 1 / scale)
	end

	function ResetMapPin(pin)
		pin.shown = false
		pin:SetFrameLevel(4000)
		pin:Hide()
		pin.debugging = nil
		pin.scale = nil
		pin.scaleAdj = nil
		pin.line:Hide()
		pin.radius:Hide()
		pin.connected = false
		pin.active = false
	end

	function SetPinActive(pin, active)
		pin.active = active
		activePin = pin
		pin:SetNormalTexture(active and pin.activeNormalTexture or pin.inactiveNormalTexture)
		pin:SetHighlightTexture(active and pin.activeHighlightTexture or pin.inactiveHighlightTexture, "BLEND")
		pin:SetFrameLevel(active and 4001 or 4000)
		if (active) then
			ConnectPins(playerPin, pin)
		end
	end

	function SetPinLocation(pin, x, y)
		local frameWidth, frameHeight = component.pinsContainer:GetSize()
		pin.point:ClearAllPoints()
		pin.point:SetPoint("CENTER", component.pinsContainer, "TOPLEFT", frameWidth * (x / 100), -frameHeight * (y / 100))
	end

	function SetPinScale(pin, scale)
		pin.scale = scale
		pin:SetScale(scale * globalPinScale * (pin.scaleAdj or 1.0))
		if (pin.line) then
			pin.line:SetThickness(pin.lineThickness * scale)
		end
	end

	function SetPinShown(pin, shown, debugging)
		pin.shown = shown
		pin:SetShown(shown or debugging)
		pin.number:SetShown(Debug.IsMapPinDebuggingEnabled("HIDDEN"))
		pin.inactiveNormalTexture:SetDesaturated(debugging or false)
		if (debugging and not shown) then
			pin.scaleAdj = 0.8
			pin.inactiveNormalTexture:SetVertexColor(1,0,0,1)
		else
			pin.scaleAdj = nil
			pin.inactiveNormalTexture:SetVertexColor(1,1,1,1)
		end
		if (pin.scale) then
			pin:SetScale(pin.scale * globalPinScale * (pin.scaleAdj or 1.0))
		end
		pin.debugging = debugging
		pin.line:SetShown(pin.connected and (pin.connected.shown and not pin.connected.debugging) and shown and not debugging)
		if (Debug.IsMapPinDebuggingEnabled("HIDDEN") and pin.location.radius ~= 0) then
			pin.radius:Show()
			local radiusInPixels = GetCircleSizeForRadius(pin.location.radius)
			pin.radius:SetSize(radiusInPixels, radiusInPixels)
		else
			pin.radius:Hide()
		end
	end

	function component.Init(components)
		Waypoints = components.Waypoints
		component.pinsContainer = CreateFrame("Frame", nil, mapContainer)
		component.pinsContainer:SetAllPoints()
		component.pinsContainer:SetFrameLevel(3002)
		hooksecurefunc(mapContainer, "SetScale", OnMapScaleChanged)
		hooksecurefunc(mapFrame, "SetMapID", OnMapIDChanged)
		playerPin = CreateFrame("Frame", nil, component.pinsContainer)
		playerPin:SetFrameLevel(component.pinsContainer:GetFrameLevel() + 2)
		playerPin:SetSize(1,1)
		playerPin.point = CreateFrame("Frame", nil, component.pinsContainer)
		playerPin.point:SetSize(1,1)
		playerPin:SetPoint("CENTER", playerPin.point, "CENTER")
		playerPin.shown = true
		playerPin.line = component.pinsContainer:CreateLine()
		playerPin.line:SetTexture(I.Lines, "REPEAT", nil, "LINEAR")
		playerPin.line:SetHorizTile(true)
		local scale = mapContainer:GetScale()
		playerPin.line:SetThickness(lineThickness / scale)
		playerPin.line:SetAlpha(1.0)
		playerPin.elapsed = 0
		playerPin.animStep = 16
		playerPin.animOffset = 16
		playerPin.lineThickness = lineThickness
		playerPin:SetScript("OnUpdate", OnUpdate)
		spiritHealerPin = GetMapPin()
		spiritHealerPin.location = { }
		spiritHealerPin:SetScript("OnEnter", function(self)
			GameTooltip:ClearLines()
			GameTooltip:SetOwner(self, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", self, "BOTTOMRIGHT", 0, 0)
			GameTooltip:SetText("Spirit Healer", 1, 1, 1)
			GameTooltip:Show()
		end)
		spiritHealerPin:SetScript("OnLeave", function()
			GameTooltip:Hide()
		end)
	end

	function component.Update()
		if (component:IsDirty()) then
			for _, pin in ipairs(mapPins) do
				ResetMapPin(pin)
			end
			activePin = nil
			playerPin.line:Hide()
			if (GhostService.IsSpiritRessing() and UnitIsDeadOrGhost("player")) then
				if (UnitIsGhost("player")) then
					local location = State.GetLastSpiritHealerLocation()
					if (location) then
						local _, mapPosition = C_Map.GetMapPosFromWorldPos(location.continentID, location, mapFrame:GetMapID())
						SetPinLocation(spiritHealerPin, mapPosition.x * 100, mapPosition.y * 100)
						SetPinActive(spiritHealerPin, true)
						spiritHealerPin.shown = true
						spiritHealerPin.location.continentID = location.continentID
						spiritHealerPin:Show()
					end
				end
			else
				spiritHealerPin:Hide()
				local locations = LocationsService.GetLocations()
				local previousCheckpoint
				if (locations) then
					for idx, location in ipairs(locations) do
						local pin = GetMapPin(idx)
						pin.location = location
						local x, y = location:GetXY(mapFrame:GetMapID())
						local shown
						local debugging
						local nonpassing
						if (Debug.IsMapPinDebuggingEnabled("HIDDEN")) then
							shown = x ~= nil and CheckCondition(location)
							debugging = not location:IsShown()
							nonpassing = not shown and x ~= nil and Debug.IsMapPinDebuggingEnabled("NONPASSING")
						else
							shown = x ~= nil and CheckCondition(location) and location:IsShown()
						end
						SetPinShown(pin, shown, debugging or nonpassing)
						if (shown or nonpassing) then
							SetPinLocation(pin, x, y)
							SetPinActive(pin, location:IsActive())
						else
							ResetMapPin(pin)
						end
						if (shown) then
							if (Flags.HasFlag(location, "C")) then
								if (previousCheckpoint ~= nil) then
									ConnectPins(pin, previousCheckpoint)
								end
								previousCheckpoint = pin
							end
						end
					end
				end
			end
			component:MarkClean()
		end
		if (playerPin.point:IsVisible()) then
			local x, y = UnitPosition("player")
			local mapID = mapFrame:GetMapID()
			local mapPosition = C_Map.GetPlayerMapPosition(mapID, "player")
			if (mapPosition) then
				playerPin.x = x
				playerPin.y = y
				SetPinLocation(playerPin, mapPosition.x * 100, mapPosition.y * 100)
			else
				if (playerPin.connected) then
					local playerMapID = C_Map.GetBestMapForUnit("player")
					if (playerMapID) then
						local playerMapPosition = C_Map.GetPlayerMapPosition(playerMapID, "player")
						if (playerMapPosition) then
							local continentID, playerWorldPos = C_Map.GetWorldPosFromMapPos(playerMapID, playerMapPosition)
							if (playerPin.connected.location.continentID == continentID) then
								local _, newMapPosition = C_Map.GetMapPosFromWorldPos(continentID, playerWorldPos, mapID)
								if (newMapPosition) then
									playerPin.x = x
									playerPin.y = y
									SetPinLocation(playerPin, newMapPosition.x * 100, newMapPosition.y * 100)
									return
								end
							end
						end
					end
				end
				playerPin.line:Hide()
			end
		end
	end
	UI.Add(component)
end