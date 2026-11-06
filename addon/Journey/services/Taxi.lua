--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local taxiMaps

do
	local wowversion = GetWowVersion()
	if (wowversion >= 50000 and wowversion < 60000) then
		taxiMaps = {
			1463,   -- Eastern Kingdoms
			1464,   -- Kalimdor
			987,    -- Outland
			988,    -- Northrend
			2473,	-- Pandaria
		}
	elseif (wowversion >= 110000) then
		taxiMaps = {
			1208,   -- Eastern Kingdoms
			1209,   -- Kalimdor
			1467,   -- Outland
			1384,   -- Northrend
			1923,	-- Pandaria
		}
	else
		taxiMaps = {
			1463,   -- Eastern Kingdoms
			1464,   -- Kalimdor
			987,    -- Outland
			988,    -- Northrend
		}
	end
end

local taxiMapFlags = {
	ALLIANCE = 1,
	HORDE = 2
}

local FindEligibleTaxiNode, HookTakeTaxiNode
local lastEligibleStep
local Taxis
local TaxiNodeLUT
local useLegacyAPI = true

function FindEligibleTaxiNode()
	local currentStep = GuideNavigationService.GetStep()
	if (currentStep) then
		for _, taskGroup in ipairs(currentStep) do
			if (taskGroup.conditionPassed and not taskGroup.completedPassed) then
				for _, task in ipairs(taskGroup) do
					local taxiNodeID = task.taketaxi
					if (taxiNodeID and task.conditionPassed and not task.completedPassed) then
						return taxiNodeID
					end
				end
			end
		end
	end
end

local function OnEvent(_, event, _, arg3)
	if (event == "TAXIMAP_OPENED") then
		local foundTaxiNodeID = FindEligibleTaxiNode()
		local foundTaxiIDX
		if (useLegacyAPI) then
			local nodes = NumTaxiNodes()
			for i = 1, nodes do
				local name = TaxiNodeName(i)
				local taxiNodeID = TaxiNodeLUT[name]
				if (taxiNodeID) then
					Taxis[TaxiNodeLUT[name]] = true
					if (taxiNodeID == foundTaxiNodeID) then
						foundTaxiIDX = i
					end
				end
			end
		else
			for _, map in ipairs(taxiMaps) do
				local taxiNodes = C_TaxiMap.GetAllTaxiNodes(map)
				for _, node in ipairs(taxiNodes) do
					Taxis[node.nodeID] = node.state ~= Enum.FlightPathState.Unreachable
					if (node.nodeID == foundTaxiNodeID) then
						foundTaxiIDX = node.slotIndex
					end
				end
			end
		end
		if (foundTaxiIDX) then
			lastEligibleStep = GuideNavigationService.GetStep()
			if (State.IsAutoTaxiEnabled()) then
				TakeTaxiNode(foundTaxiIDX)
			end
		end
		MarkAllDirty()
		return
	end
	if (event == "UI_INFO_MESSAGE" and arg3 == ERR_NEWTAXIPATH) then
		local y, x, _, continent = UnitPosition("player")
		if (y) then
			local flag = taxiMapFlags[PLAYER_FACTION]
			local minDistance, minDistanceNode = 2147483647, nil
			for taxiNodeID, taxiNodeLocation in pairs(TaxiNodeLocations) do
				if (continent == taxiNodeLocation.continentID and bit.band(taxiNodeLocation.flags, flag) ~= 0) then
					local distance = addon.GetDistanceInYards(x, y, taxiNodeLocation.x, taxiNodeLocation.y)
					if (distance < minDistance) then
						minDistance = distance
						minDistanceNode = taxiNodeID
					end
				end
			end
			if (minDistanceNode ~= nil) then
				Taxis[minDistanceNode] = true
				MarkAllDirty()
				return
			end
		end
	end
end

TaxiService = { }

function TaxiService.GetTaxiName(nodeID)
	return TaxiNodes[nodeID] or "..."
end

function TaxiService.HasTaxi(nodeID)
	return Taxis[nodeID] or false
end

function TaxiService.Init()
	SavedVariablesPerCharacter.knownTaxis = SavedVariablesPerCharacter.knownTaxis or { }
	Taxis = SavedVariablesPerCharacter.knownTaxis
	for _, map in ipairs(taxiMaps) do
		local taxiNodes = C_TaxiMap.GetTaxiNodesForMap(map)
		for _, node in ipairs(taxiNodes) do
			useLegacyAPI = false
			TaxiNodes[node.nodeID] = node.name
		end
	end
	if (useLegacyAPI) then
		TaxiNodeLUT = { }
		for k, v in ipairs(TaxiNodes) do
			TaxiNodeLUT[v] = k
		end
	end
end

function TaxiService.IsTaxiTaken(rootNode)
	local step = rootNode or GuideNavigationService.GetStep()
	return step.taxiTaken or false
end

function TaxiService.OnGossipShow()
	if (not GuideNavigationService.IsGuideSet()) then return false end
	local gossipOption
	local options = C_GossipInfo.GetOptions()
	if (options) then
		for _, option in ipairs(options) do
			if (option.icon == 132057) then
				gossipOption = option
				break
			end
		end
	end
	if (gossipOption and FindEligibleTaxiNode()) then
		if (State.IsAutoTaxiEnabled()) then
			C_GossipInfo.SelectOption(gossipOption.gossipOptionID)
		end
		return true
	end
end

local lastOnTaxi = false

local function OnUpdate()
	local onTaxi = UnitOnTaxi("player")
	if (onTaxi ~= lastOnTaxi) then
		lastOnTaxi = onTaxi
		if (onTaxi) then
			local currentStep = GuideNavigationService.GetStep()
			if (currentStep and currentStep == lastEligibleStep) then
				GuideNavigationService.GetGuide().bookmark.taxiTaken = true
				currentStep.taxiTaken = true
				MarkAllDirty()
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", OnEvent)
frame:SetScript("OnUpdate", OnUpdate)
frame:RegisterEvent("TAXIMAP_OPENED")
frame:RegisterEvent("UI_INFO_MESSAGE")
