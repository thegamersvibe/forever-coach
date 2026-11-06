--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "hintbutton",
}, TaskTypeMixin)

function TaskType:IsCompletedFunc()
	return true
end

function TaskType:IsOptional()
	return true
end

function TaskType:RenderFunc(task, container)
	container.button:SetShown(true)
	container:SetButtonColor(Color.MODE_NORMAL)
	if ((task.root.hintLevel or 0) < task.hintbutton) then
		container.button:SetText("Show a Hint")
	else
		container.button:SetText("Show Spoiler")
	end
	container.button:SetScript("OnClick", function()
		task.root.hintLevel = (task.root.hintLevel or 0) + 1
		if (task.root.hintLevel > task.hintbutton) then
			task.root.spoiler = true
		end
		MarkAllDirty()
	end)
end

RegisterTaskType(TaskType)
