--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "accept",
	dimmable = true,
	compactable = true,
	incompleteIcon = IconService.GetIconInfo("questnormal")
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
	return QuestStatus.GetQuestStatus(task.accept) >= QuestStatus.status.ACCEPTED
end

function TaskType:RenderFunc(task, container)
	local link = Hyperlinks.GetQuestHyperlink(task, "accept")
	container.text:SetShown(true)
	if (task.fromnpc) then
		local name = Hyperlinks.GetNPCHyperlink(task)
		container.text:SetText(L["Speak to %s and accept: |C%s%s|r"]:format(name, Color.QUEST_ACCEPT, link))
	else
		container.text:SetText(L["Accept: |C%s%s|r"]:format(Color.QUEST_ACCEPT, link))
	end
end

RegisterTaskType(TaskType)
