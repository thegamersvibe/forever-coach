--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local context = { }
local functionBase = "return %s"

ConditionContext = context

local currentRoot
local currentObj
local reservedContextVars = { }

function CheckCondition(obj, conditionProperty)
	if (type(obj) ~= "table" or not (conditionProperty or obj.condition)) then
		return true
	end
	currentRoot = obj.root or obj
	currentObj = nil
	conditionProperty = conditionProperty or obj.condition
	local func = loadstring(functionBase:format(conditionProperty))
	setfenv(func, context)
	return (func() == true)
end

function CheckCompleted(obj)
	if (type(obj) ~= "table" or not obj.completed) then return nil end
	currentRoot = obj.root or obj
	currentObj = obj
	local func = loadstring(functionBase:format(obj.completed))
	setfenv(func, context)
	return (func() == true)
end

local REP_LEVELS = {
	UNKNOWN = 0,
	HATED = 1,
	HOSTILE = 2,
	UNFRIENDLY = 3,
	NEUTRAL = 4,
	FRIENDLY = 5,
	HONORED = 6,
	REVERED = 7,
	EXALTED = 8,
}

local QUEST = { }

setmetatable(QUEST, {
	__index = function(_, key)
		return QuestStatus.GetQuestStatus(key)
	end
})

local OBJECTIVE = { }

setmetatable(OBJECTIVE, {
	__index = function(_, key)
		local objectives = { }
		local complete = C_QuestLog_IsQuestFlaggedCompleted(key)
		local questObjectives = QuestStatus.GetQuestObjectives(key) or { }
		for idx, objective in ipairs(questObjectives) do
			objectives[idx] = complete or objective.finished
		end
		return objectives
	end
})

local OBJECTIVECOUNT = { }

setmetatable(OBJECTIVECOUNT, {
	__index = function(_, key)
		local objectives = { }
		local questObjectives = QuestStatus.GetQuestObjectives(key) or { }
		for idx, objective in ipairs(questObjectives) do
			objectives[idx] = objective.numFulfilled or 0
		end
		return objectives
	end
})

local BANKITEM = { }

setmetatable(BANKITEM, {
	__index = function(_, key)
		return GetItemCount(key, true) - GetItemCount(key, false)
	end
})

local ITEM = { }

setmetatable(ITEM, {
	__index = function(_, key)
		return GetItemCount(key, false)
	end
})

local REP = { }

setmetatable(REP, {
	__index = function(_, key)
		local _, _, standingId = GetFactionInfoByID(key)
		if (not standingId) then return REP_LEVELS.UNKNOWN end
		return standingId
	end
})

local HASTAXI = { }

setmetatable(HASTAXI, {
	__index = function(_, key)
		return TaxiService.HasTaxi(key)
	end
})

local HEARTHSTONE = { }

setmetatable(HEARTHSTONE, {
	__index = function(_, key)
		local bindlocation = GetBindLocation()
		if (not bindlocation) then return false end
		local areaname = C_Map.GetAreaInfo(key)
		if (not areaname) then return false end
		return bindlocation == areaname
	end
})

local TGLOCATION_ENABLED = { }

setmetatable(TGLOCATION_ENABLED, {
	__index = function(_, key)
		local lastObj = currentObj
		local enabled = false
		if (currentRoot[key]) then
			enabled = currentRoot.completedPassed or not currentRoot[key].completedPassed
		end
		currentObj = lastObj
		return enabled
	end
})

local WITHIN = { }

setmetatable(WITHIN, {
	__index = function(_, key)
		if (currentRoot ~= GuideNavigationService.GetStep()) then return false end
		local location = LocationsService.GetLocationByIdx(key)
		if (location) then
			return location:IsPlayerWithin()
		end
		return false
	end
})

local VISITED = { }

setmetatable(VISITED, {
	__index = function(_, key)
		if (currentRoot ~= GuideNavigationService.GetStep()) then return false end
		local location = LocationsService.GetLocationByIdx(key)
		if (location) then
			return location:HasVisited()
		end
		return false
	end
})

local EXITED = { }

setmetatable(EXITED, {
	__index = function(_, key)
		if (currentRoot ~= GuideNavigationService.GetStep()) then return false end
		local location = LocationsService.GetLocationByIdx(key)
		if (location) then
			return location:HasExited()
		end
		return false
	end
})

local BUFF = { }

setmetatable(BUFF, {
	__index = function(_, key)
		return AuraService.PlayerHasBuff(key) and true or false
	end
})

local BUFFCOUNT = { }

setmetatable(BUFFCOUNT, {
	__index = function(_, key)
		return AuraService.PlayerHasBuff(key) or 0
	end
})

local DEBUFF = { }

setmetatable(DEBUFF, {
	__index = function(_, key)
		return AuraService.PlayerHasDebuff(key)
	end
})

local SPELL = { }

setmetatable(SPELL, {
	__index = function(_, key)
		return IsPlayerSpell(key)
	end
})

local SPELLCAST = { }

setmetatable(SPELLCAST, {
	__index = function(_, key)
		if (currentRoot) then
			if (currentRoot == GuideNavigationService.GetStep()) then
				SpellsCastService.AddWatch(key)
			end
			return SpellsCastService.WasSpellCast(key)
		end
	end
})

local PETSPELL = { }

setmetatable(PETSPELL, {
	__index = function(_, key)
		return PetSpellsService.HasPetSpell(key)
	end
})

local contextFunctions = {
	ACTIVE = function()
		if (currentRoot ~= GuideNavigationService.GetStep()) then return 0 end
		local activeLocation = LocationsService.GetActiveLocation()
		return activeLocation and activeLocation.idx or 0
	end,
	AH = function()
		return State.IsAHEnabled()
	end,
	ALIVE = function()
		return not UnitIsDeadOrGhost("player")
	end,
	AREA = function()
		return PlacesService.GetCurrentAreaID()
	end,
	CONTINENT = function()
		local _, _, _, continentID = UnitPosition("player")
		return continentID
	end,
	DEAD = function()
		return UnitIsDead("player")
	end,
	DEADORGHOST = function()
		return UnitIsDeadOrGhost("player")
	end,
	DIED = function()
		return GhostService.HasPlayerDied(currentRoot)
	end,
	CHECKPOINT = function()
		if (currentRoot ~= GuideNavigationService.GetStep()) then return 0 end
		return GuideNavigationService.GetGuide().bookmark.checkpoint
	end,
	COMPLETE = function()
		if (currentObj and currentObj.taskType) then
			return currentObj.taskType:IsCompleted(currentObj)
		end
	end,
	FLYING = function()
		return IsPlayerSpell(34090) or IsPlayerSpell(54197)
	end,
	FLYINGMOUNT = function()
		return MountsService.HasFlyingMount()
	end,
	FLYINGTBC = function()
		return (IsPlayerSpell(34090) or IsPlayerSpell(54197)) and MountsService.HasFlyingMount()
	end,
	FLYINGWOTLK = function()
		return IsPlayerSpell(54197) and MountsService.HasFlyingMount()
	end,
	GHOST = function()
		return UnitIsGhost("player")
	end,
	GROUPS = function()
		return State.IsGroupingEnabled()
	end,
	GUIDE = function()
		return CustomVariablesService.GetGuideScope()
	end,
	HASRETURNGUIDE = function()
		return State.GetReturnToGuide(GUIDE_TYPE.LEVELING) and RunesService.IsRuneGuide(GuideNavigationService.GetGuide().id)
	end,
	HC = function()
		return HardcoreService.IsHardcoreEnabled()
	end,
	HINTLEVEL = function()
		return currentRoot.hintLevel or 0
	end,
	HINTLEVEL0 = function()
		return (currentRoot.hintLevel or 0) == 0
	end,
	HINTLEVEL1 = function()
		return (currentRoot.hintLevel or 0) >= 1
	end,
	HINTLEVEL2 = function()
		return (currentRoot.hintLevel or 0) >= 2
	end,
	HINTLEVEL3 = function()
		return (currentRoot.hintLevel or 0) >= 3
	end,
	HINTLEVEL4 = function()
		return (currentRoot.hintLevel or 0) >= 4
	end,
	HINTLEVEL5 = function()
		return (currentRoot.hintLevel or 0) >= 5
	end,
	HINTLEVEL6 = function()
		return (currentRoot.hintLevel or 0) >= 6
	end,
	HINTLEVEL7 = function()
		return (currentRoot.hintLevel or 0) >= 7
	end,
	HINTLEVEL8 = function()
		return (currentRoot.hintLevel or 0) >= 8
	end,
	HINTLEVEL9 = function()
		return (currentRoot.hintLevel or 0) >= 9
	end,
	SPOILER = function()
		return currentRoot.spoiler or false
	end,
	INDOORS = function()
		return IsIndoors()
	end,
	INGROUP = function()
		return IsInGroup()
	end,
	JOYOUS = function()
		return AuraService.PlayerHasBuff(377749)
	end,
	LEVEL = function()
		return UnitLevel("player")
	end,
	LEVELD = function()
		return UnitLevel("player") + UnitXP("player") / UnitXPMax("player")
	end,
	MONEY = GetMoney,
	ONTAXI = function()
		if (PlayerOnTaxiOverride) then
			return PlayerOnTaxiOverride()
		end
		return UnitOnTaxi("player")
	end,
	OUTDOORS = function()
		return IsOutdoors()
	end,
	PARENTWMOAREA = function()
		return PlacesService.GetCurrentParentWMOAreaID()
	end,
	PETSTABLE = function()
		return MerchantService.IsPetStableVisited(currentRoot)
	end,
	REPAIRED = function()
		return MerchantService.IsRepairMerchantVisited(currentRoot)
	end,
	RESUPPLIED = function()
		return MerchantService.IsSupplyMerchantVisited(currentRoot)
	end,
	ROOT_COMPLETED = function()
		local lastObj = currentObj
		local complete = currentRoot.completedPassed or false
		currentObj = lastObj
		return complete
	end,
	SPIRITRESSED = function()
		return GhostService.HasPlayerSpiritRessed(currentRoot)
	end,
	TALENTTRAINER = function()
		return MerchantService.IsTalentTrainerVisited(currentRoot)
	end,
	TAXITAKEN = function()
		return TaxiService.IsTaxiTaken(currentRoot)
	end,
	TRADESKILLTRAINER = function()
		return MerchantService.IsTradeskillTrainerVisited(currentRoot)
	end,
	WEAPONSKILLTRAINER = function()
		return MerchantService.IsTalentTrainerVisited(currentRoot)
	end,
	WMOAREA = function()
		return PlacesService.GetCurrentWMOAreaID()
	end,
	XP = function()
		return UnitXP("player")
	end,
	XPMAX = function()
		return UnitXPMax("player")
	end,
	ZONE = function()
		if (PlayerPositionOverride) then
			local _, _, mapID = PlayerPositionOverride()
			if (mapID) then
				return mapID
			end
		end
		return C_Map.GetBestMapForUnit("player")
	end,
	SOM2 = function()
		return AuraService.PlayerHasBuff(436412)
	end,
	INVEHICLE = function()
		return UnitInVehicle("player")
	end
}

setmetatable(context, {
	__index = function(tbl, key)
		local dotPosition = string.find(key, "%.")
		local subKey
		if dotPosition then
			local newKey = string.sub(key, 1, dotPosition - 1)
			subKey = string.sub(key, dotPosition + 1)
			key = newKey
		end
		local val = rawget(tbl, key) or contextFunctions[key]
		if (type(val) == "function") then
			return val()
		else
			if (subKey) then
				return val[subKey]
			else
				return val
			end
		end
	end,
	__newindex = function(tbl, key, val)
		local dotPosition = string.find(key, "%.")
		if dotPosition then
			local newKey = string.sub(key, 1, dotPosition - 1)
			local subKey = string.sub(key, dotPosition + 1)
			local subTable = rawget(tbl, newKey)
			if (subTable) then
				subTable[subKey] = val
			end
		else
			rawset(tbl, key, val)
		end
	end
})

function Condition_ResetGuides()
	for _, guideInfo in ipairs(CatalogService.GetGuideInfos()) do
		local moduleInfo = GuideModules.GetModule(guideInfo.moduleID)
		if (moduleInfo and moduleInfo.installed and moduleInfo.compatible) then
			context[guideInfo.guideID] = true
			if (Brand.registerGuideAlias) then
				Brand.registerGuideAlias(guideInfo.guideID, context)
			end
		end
	end
end

function GetCondition(varname)
	return context[varname]
end

function SetCondition(varname, value, scope, allowReserved)
	if (reservedContextVars[varname] and not allowReserved) then
		DEFAULT_CHAT_FRAME:AddMessage("|cFFFF0000Cannot overwrite reserved condition variable: " .. varname .. "|r")
		return
	end
	context[varname] = value
	State.SetCustomVariable(varname, value, scope)
end

function Condition_OnAddonLoad()
	local _, playerClass = UnitClass("Player")
	local _, _, _, gameVersion = GetBuildInfo()
	context["GAMEVERSION"] = gameVersion
	context["PHASE"] = 6
	if (gameVersion < 20000) then
		context["ERA"] = true
		if (gameVersion < 16000) then
			local season = C_Seasons.GetActiveSeason() or 0
			if (season == Enum.SeasonID.Fresh or season == Enum.SeasonID.FreshHardcore) then
				context["PHASE"] = 1
			end
			if (season == Enum.SeasonID.SeasonOfDiscovery) then
				context["SOD"] = true
			end
		else
			context["FOREVER"] = true
		end
	elseif (gameVersion >= 30000 and gameVersion < 40000) then
		context["WOTLK"] = true
	elseif (gameVersion >= 40000) then
		context["CATA"] = true
	else
		context["TBC"] = true
	end
	context["MOPPHASE"] = 2
	context[playerClass] = true
	context["QUEST"] = QUEST
	context["OBJECTIVE"] = OBJECTIVE
	context["OBJECTIVECOUNT"] = OBJECTIVECOUNT
	context["BANKITEM"] = BANKITEM
	context["ITEM"] = ITEM
	for k, v in pairs(QuestStatus.status) do
		context[k] = v
	end
	for repLevel, value in pairs(REP_LEVELS) do
		context[repLevel] = value
	end
	context["REP"] = REP
	context["HASTAXI"] = HASTAXI
	context["HEARTHSTONE"] = HEARTHSTONE
	context["TGLOCATION_ENABLED"] = TGLOCATION_ENABLED
	local playerFaction = UnitFactionGroup("player")
	PLAYER_FACTION = string.upper(playerFaction)
	context[PLAYER_FACTION] = true
	local _, playerRace = UnitRace("player")
	context[string.upper(playerRace)] = true
	context["WITHIN"] = WITHIN
	context["VISITED"] = VISITED
	context["EXITED"] = EXITED
	context["BUFF"] = BUFF
	context["BUFFCOUNT"] = BUFFCOUNT
	context["DEBUFF"] = DEBUFF
	context["SPELL"] = SPELL
	context["PETSPELL"] = PETSPELL
	context["SPELLCAST"] = SPELLCAST
	context["SESSION"] = CustomVariablesService.GetSessionScope()
	context["VAR"] = CustomVariablesService.GetCharacterScope()
	for k, v in pairs(ProfessionService.Tiers) do
		context[k] = v
	end
	for k in pairs(Professions) do
		contextFunctions[k] = function()
			return ProfessionService.PlayerProfessions[k] or 0
		end
		contextFunctions[k .. "_POINTS"] = function()
			return ProfessionService.GetPoints(k)
		end
	end
	for _, slotName in ipairs(EquipmentService.GetSlotNames()) do
		contextFunctions[slotName] = function()
			return EquipmentService.GetEquippedItem(slotName)
		end
		contextFunctions[slotName .. "SUBCLASS"] = function()
			return EquipmentService.GetEquippedItemSubClass(slotName)
		end
	end
	for k, v in pairs(Enum.ItemWeaponSubclass) do
		context[string.upper(k)] = v
	end
end
