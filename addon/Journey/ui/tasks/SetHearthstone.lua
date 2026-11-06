--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "sethearthstone",
	dimmable = true,
	incompleteIcon = IconService.GetIconInfo("poi-town")
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
	if (ConditionContext["SEEKING"]) then return true end
	return GetBindLocation() == C_Map.GetAreaInfo(task.sethearthstone)
end

function TaskType:RenderFunc(task, container)
	local areaName = Names.GetName(C_Map.GetAreaInfo, task.sethearthstone)
	local npcName
	if (task.fromnpc) then
		npcName = Hyperlinks.GetNPCHyperlink(task)
	end
	container.text:SetShown(true)
	if (npcName) then
		container.text:SetText(L["Speak to %s and make |C%s%s|r your new home."]:format(npcName, Color.INN, areaName))
	else
		container.text:SetText(L["Make |C%s%s|r your new home."]:format(Color.INN, areaName))
	end
end

RegisterTaskType(TaskType)
