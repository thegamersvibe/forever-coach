--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "startwork",
	taskPrefix = L["Start: |C%s%s|r"],
	taskColor = Color.QUEST_STARTWORK,
	incompleteIcon = IconService.GetIconInfo("slay")
}, DoQuestMixin)

function TaskType:IsOptional(task)
	return task.optional ~= false
end

RegisterTaskType(TaskType)
