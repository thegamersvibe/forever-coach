--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local taskTypes = { }

TaskTypeMixin = {
	GetType = function(self)
		return self.type
	end
}

function TaskTypeMixin:IsCompleted(task)
	if (self.IsCompletedFunc) then
		return self:IsCompletedFunc(task)
	end
	return true
end

function TaskTypeMixin:IsDimmable(task)
	return (task.completed and true) or self.dimmable
end

function TaskTypeMixin:IsOptional(task)
	return task.optional or false
end

function TaskTypeMixin:Render(task, container)
	container.isDirty = nil
	container.task = task
	if (self.compactable) then
		container.compactable = true
	end
	container.text:Hide()
	container.button:Hide()
	for _, taskDetailContainer in ipairs(container.taskDetailContainers) do
		taskDetailContainer:Reset()
	end
	self:RenderFunc(task, container)
	local completed = task.completedPassed
	local icon = task.iconOverride or self.incompleteIcon
	IconService.SetIconTexture(
			container.icon,
			icon and (completed and not self.disableCompleteIcon and IconService.GetIconInfo("capacitance-general-workordercheckmark") or icon))
end

function TaskTypeMixin:RenderFunc(task, container)
	container.text:SetText("Render not defined for " .. self:GetType())
	container.text:Show()
end

function TaskTypeMixin:Setup(task)

end

function GetTaskType(task)
	for k, v in pairs(taskTypes) do
		if (task[k]) then return v end
	end
	return taskTypes.text
end

function RegisterTaskType(taskType)
	taskTypes[taskType.type] = taskType
end
