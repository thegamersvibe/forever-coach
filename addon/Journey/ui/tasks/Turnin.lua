--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "turnin",
	dimmable = true,
	compactable = true,
	incompleteIcon = IconService.GetIconInfo("questturnin")
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
	return QuestStatus.GetQuestStatus(task.turnin) >= QuestStatus.status.TURNEDIN
end

function TaskType:RenderFunc(task, container)
	local link = Hyperlinks.GetQuestHyperlink(task, "turnin")
	local questID = task[self.type]
	task.warn = nil
	local objectives = C_QuestLog_GetQuestObjectives(questID)
	local questStatus = QuestStatus.GetQuestStatus(questID)
	local hasObjectives = objectives and #objectives > 0
	task.suppressWarning = task.suppressWarning or TurninOnlyQuests[questID]
	if ((questStatus == 0 or (questStatus < 2 and hasObjectives)) and not task.suppressWarning) then
		if (questStatus == 0) then
			task.warn = string.format("|c%sYou don't have this quest|r", Color.RED_TEXT)
		else
			task.warn = string.format("|c%sQuest is not ready to be turned in|r", Color.RED_TEXT)
		end
		for _, taskGroup in ipairs(task.root) do
			for _, task_ in ipairs(taskGroup) do
				if (questID == task_.accept) then
					task.warn = nil
					break
				end
			end
			if (not task.warn) then break end
		end
	end
	local color
	if (task.warn) then
		color = Color.RED_TEXT
		task.iconOverride = IconService.GetIconInfo("services-icon-warning")
	else
		color = Color.QUEST_TURNIN
		task.iconOverride = nil
	end
	container.text:SetShown(true)
	if (task.fromnpc and not task.warn) then
		local name = Hyperlinks.GetNPCHyperlink(task)
		container.text:SetText(L["Speak to %s and turn in: |C%s%s|r"]:format(name, color, link))
	else
		container.text:SetText(L["Turn in: |C%s%s|r"]:format(color, link))
	end
end

RegisterTaskType(TaskType)
