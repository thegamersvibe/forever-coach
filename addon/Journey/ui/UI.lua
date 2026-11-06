--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

UI = { }

local components = { }
local updateComponents = { }
local frame
local isDirty
local elapsed

function UI.Update(elapsed_)
	elapsed = elapsed_
	for _, component in ipairs(updateComponents) do
		if (isDirty) then component:MarkDirty() end
		component.Update()
	end
	elapsed = 0
	isDirty = nil
end

function UI.Add(component)
	table.insert(components, component)
	if (component.name) then
		components[component.name] = component
	end
	if (component.Update) then
		table.insert(updateComponents, component)
	end
end

function UI.GetComponent(componentName)
	return components[componentName]
end

function UI.GetElapsed()
	return elapsed
end

function UI.Init()
	frame = CreateFrame("Frame")
	for _, component in ipairs(components) do
		if (component.Init) then
			component.Init(components)
		end
	end
end

function UI.IsDirty()
	return isDirty
end

function UI.MarkDirty()
	isDirty = true
end

function UI.IsTaskGroupDimmed(taskGroup)
	if (taskGroup.root.completedPassed) then
		return true
	elseif (not taskGroup.optionalPassed) then
		if (taskGroup.completedPassed and taskGroup.completed) then
			return true
		end
		return false
	elseif (taskGroup.completedPassed) then
		if (taskGroup.completed) then return true end
		for _, task in ipairs(taskGroup) do
			if (task.conditionPassed) then
				if (task.taskType:IsDimmable(task)) then
					return true
				end
			end
		end
	end
	return false
end