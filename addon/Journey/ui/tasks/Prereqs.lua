--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "prereqs",
	disableCompleteIcon = true,
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
	for _, route in ipairs(task.prereqs) do
		if (CheckCondition(route)) then
			return false
		end
	end
	return true
end

function TaskType:RenderFunc(task, container)
	local guide = task.defaultguide
	local stepID
	for _, route in ipairs(task.prereqs) do
		if (CheckCondition(route)) then
			guide = route.guide or guide
			stepID = route["goto"]
			break
		end
	end
	task.parent._prereqGuide = guide
	task.parent._prereqStep = stepID
	container.text:SetShown(true)
	container.text:SetText(L["You're missing some prerequisites to start this chapter. Go to the previous guide and we'll try to find the right place for you to start."])
end

RegisterTaskType(TaskType)
