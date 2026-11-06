--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

QuestStatus = { }

local EventFrame = CreateFrame("Frame")

local TURNEDIN = 3
local COMPLETED = 2
local ACCEPTED = 1
local NONE = 0
local FAILED = -1

local interval, minInterval, maxInterval, timeSinceLastUpdate = 1, 1/15, 1, 0
local queue = { }

local function OnUpdate(_, elapsed)
	timeSinceLastUpdate = timeSinceLastUpdate + elapsed
	if (timeSinceLastUpdate > interval) then
		timeSinceLastUpdate = 0
		if (next(queue) == nil) then
			interval = maxInterval
			return
		end
		for questID in pairs(queue) do
			local questObjectives = C_QuestLog_GetQuestObjectives(questID)
			if (questObjectives ~= nil) then
				queue[questID] = nil
				UI.MarkDirty()
			end
		end
	end
end

function QuestStatus.GetQuestObjectives(questID)
	local questObjectives = C_QuestLog_GetQuestObjectives(questID)
	if (questObjectives == nil) then
		queue[questID] = true
		interval = minInterval
	end
	return questObjectives
end

function QuestStatus.GetQuestStatus(questID)
	if (QuestStatusOverride) then
		local questStatus = QuestStatusOverride.GetQuestStatus(questID)
		if (questStatus) then
			return questStatus
		end
	end
	if (C_QuestLog_IsQuestFlaggedCompleted(questID)) then return TURNEDIN end
	if (not C_QuestLog_IsOnQuest(questID)) then return NONE end
	local questObjectives = QuestStatus.GetQuestObjectives(questID)
	local questIndex = 1
	while(true) do
		local questLogTitleText, _, _, _, _, isComplete, _, _questID, startEvent = GetQuestLogTitle(questIndex)
		if (questLogTitleText == nil) then return NONE end -- should never hit this
		if (questID == _questID) then
			if (isComplete) then
				if (isComplete == -1) then return FAILED end
				return COMPLETED
			end
			return (startEvent or #questObjectives > 0) and ACCEPTED or COMPLETED
		end
		questIndex = questIndex + 1
	end
end

QuestStatus.status = {
	TURNEDIN = TURNEDIN,
	COMPLETED = COMPLETED,
	ACCEPTED = ACCEPTED,
	NONE = NONE,
	FAILED = FAILED
}

EventFrame:SetScript("OnUpdate", OnUpdate)