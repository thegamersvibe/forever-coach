--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

--[[ Creature Functions ]]

local dataMineTooltipName = ("%sDatamineTooltip"):format(addonName)
local dataMineTooltip = _G.CreateFrame("GameTooltip", dataMineTooltipName, UIParent, "GameTooltipTemplate")
local dataMineNameText = _G[("%sDatamineTooltipTextLeft1"):format(addonName)]
local dataMineText2 = _G[("%sDatamineTooltipTextLeft2"):format(addonName)]
local dataMineText3 = _G[("%sDatamineTooltipTextLeft3"):format(addonName)]
local dataMineText4 = _G[("%sDatamineTooltipTextLeft4"):format(addonName)]

local creatureNameCache = { }

function GetCreatureName(creatureID)
	local creatureInfo = GetCreatureInfo(creatureID)
	return creatureInfo and creatureInfo.name
end

function GetCreatureInfo(creatureID)
	local creatureInfo = creatureNameCache[creatureID]
	if (not creatureInfo) then
		dataMineTooltip:SetOwner(UIParent, "ANCHOR_NONE")
		dataMineTooltip:SetHyperlink(("unit:Creature-0-0-0-0-%d"):format(creatureID))
		local creatureName = dataMineNameText:GetText()
		if (creatureName and canaccessvalue(creatureName)) then
			local line2 = dataMineText2:GetText()
			creatureInfo = {
				name = creatureName,
				title = line2 and string.sub(line2,1,string.len(LEVEL)) ~= LEVEL and line2 or nil,
			}
			creatureNameCache[creatureID] = creatureInfo
		end
	end
	return creatureInfo
end

--[[ Texture Functions ]]

function AddDisabledTexture(frame, texture, width, height, points)
	local _texture = AddTexture(frame, texture, width, height, points)
	frame:SetDisabledTexture(_texture)
	return _texture
end

function AddHighlightTexture(frame, texture, width, height, points)
	if (type(texture) == "table") then
		local _texture = AddTexture(frame, texture.texture, width, height, points)
		frame.highlight = _texture
		frame:SetHighlightTexture(_texture, texture.alphaMode)
		return _texture
	else
		local _texture = AddTexture(frame, texture, width, height, points)
		frame.highlight = _texture
		frame:SetHighlightTexture(_texture)
		return _texture
	end
end

function AddNormalTexture(frame, texture, width, height, points)
	local _texture = AddTexture(frame, texture, width, height, points)
	frame.normal = _texture
	frame:SetNormalTexture(_texture)
	return _texture
end

function AddPushedTexture(frame, texture, width, height, points)
	local _texture = AddTexture(frame, texture, width, height, points)
	frame.pushed = _texture
	frame:SetPushedTexture(_texture)
	return _texture
end

function AddTexture(frame, texture, width, height, points)
	local _texture
	if (type(texture) == "table") then
		_texture = frame:CreateTexture(nil, texture.level or "ARTWORK")
		if (texture.texCoords) then
			--todo: not implemented
		end
		if (texture.drawLayer) then
			_texture:SetDrawLayer(texture.level or "ARTWORK", texture.drawLayer)
		end
		_texture:SetTexture(texture.texture)
	else
		_texture = frame:CreateTexture(nil, "ARTWORK")
		_texture:SetTexture(texture)
	end
	if (width) then
		_texture:SetWidth(width)
	end
	if (height) then
		_texture:SetHeight(height)
	end
	if (points) then
		if (type(points) == "string") then
			_texture:SetPoint(points)
		elseif (type(points == "table")) then
			if (type(points[1]) == "table") then
				for _, v in ipairs(points) do
					_texture:SetPoint(unpack(v))
				end
			else
				_texture:SetPoint(unpack(points))
			end
		end
	elseif (not (width or height)) then
		_texture:SetAllPoints()
	end
	return _texture
end

function CreateTexture(texture, level, texCoords, alphaMode)
	return {
		texture = texture,
		level = level,
		texCoords = texCoords,
		alphaMode = alphaMode
	}
end

--[[ Text Manipulation Functions ]]

function RemoveSpaces(str)
	local newstr = string.gsub(str, "%s+", "")
	return newstr
end

function FormatQuestObjective(objective, questCompleted)
	local _, _, arg1, arg2 = string.find(objective.text, "(.*):%s(.*)");
	if ( arg1 and arg2 ) then
		return string.format("%s/%s %s", (questCompleted and objective.numRequired) or objective.numFulfilled, objective.numRequired, arg1)
	else
		return objective.text;
	end
end

function FormatQuestObjectiveForTooltip(objective)
	local _, _, arg1, arg2 = string.find(objective.text, "(.*):%s(.*)");
	if ( arg1 and arg2 ) then
		return string.format("- %s x %s", arg1, objective.numRequired)
	else
		return objective.text;
	end
end

--[[ Quest Status Functions ]]
function IsQuestAccepted(questID)
	return C_QuestLog_IsOnQuest(questID) or C_QuestLog_IsQuestFlaggedCompleted(questID)
end

function IsQuestCompleted(questID)
	if (C_QuestLog_IsQuestFlaggedCompleted(questID)) then return true end
	if (not C_QuestLog_IsOnQuest(questID)) then return false end
	local questObjectives = C_QuestLog_GetQuestObjectives(questID)
	local questIndex = 1
	while(true) do
		local questLogTitleText, _, _, _, _, isComplete, _, _questID, startEvent = GetQuestLogTitle(questIndex)
		if (questLogTitleText == nil) then return false end
		if (questID == _questID) then
			if (isComplete) then
				if (isComplete == -1) then return false end
				return true
			end
			return not (startEvent or #questObjectives > 0)
		end
		questIndex = questIndex + 1
	end
end

function IsQuestTurnedIn(questID)
	return C_QuestLog_IsQuestFlaggedCompleted(questID)
end

--[[ Spell Lookup Functions ]]
local spellMap = {
	[465] = { 465, 10290, 643, 10291, 1032, 10292, 10293, 27149 }
}

local IsSpellKnown_Orig = IsSpellKnown

IsSpellKnown = function(spellID)
	if (spellMap[spellID]) then
		for _, v in ipairs(spellMap[spellID]) do
			if (IsSpellKnown_Orig(v)) then
				return true
			end
		end
		return false
	end
	return IsSpellKnown_Orig(spellID)
end

--[[ Item Functions ]]

function GetItemLocation(itemId)
	if (itemId) then
		for bagId = 0, 4 do
			for slot = 1, GetContainerNumSlots(bagId) do
				local itemLink = GetContainerItemLink(bagId, slot)
				if (itemLink) then
					local itemId_ = GetItemInfoInstant(itemLink)
					if (itemId == itemId_) then
						return bagId, slot
					end
				end
			end
		end
	end
end

--[[ Map Functions]]

function GetMapName(mapID)
	local mapInfo = C_Map.GetMapInfo(mapID)
	return mapInfo and mapInfo.name
end

--[[ Other Lua/Misc ]]

function ApplyMetatable(data, metatable)
	for _, v in pairs(data) do
		setmetatable(v, metatable)
	end
end

function selectN(n, ...)
	local n_ = select(n, ...)
	return n_
end

function DefaultTrue(var)
	return var == nil or var == true
end

function DefaultEmptyTable(var)
	return var or { }
end

function DefaultValue(var, default)
	if (var ~= nil) then return var end
	return default
end

function CommaFormat(n)
	return tostring(math.floor(n)):reverse():gsub("(%d%d%d)","%1,")
	                              :gsub(",(%-?)$","%1"):reverse()
end

function CreateObjectivesList(task, questInfo)
	local objectives
	if (task.objectives) then
		objectives = task.objectives
	elseif (task.seq) then
		if (type(task.seq) == "table") then
			objectives = task.seq
		else
			objectives = { }
			for _, i in ipairs(task.seq) do
				table.insert(objectives, i)
			end
		end
	elseif (task.objective) then
		objectives = { task.objective }
	else
		objectives = { }
		for i = 1, #questInfo.objectives do
			table.insert(objectives, i)
		end
	end
	return objectives
end

function GetDisplayVersion()
	if (not addonVersion) then return "" end
	return (addonVersion:gsub("%-.*", ""))
end
