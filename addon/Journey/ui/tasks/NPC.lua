--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "npc",
}, TaskTypeMixin)

function TaskType:RenderFunc(task, container)
	local link = Hyperlinks.GetNPCHyperlink(task)
	container.text:SetShown(true)
	local hint = ""
	if (task.hint and type(task.hint) == "string") then
		hint = " (" .. task.hint .. ")"
	end
	if (task.click) then
		container.text:SetText(L["Click on %s%s."]:format(link, hint))
	else
		container.text:SetText(L["Speak to %s%s."]:format(link, hint))
	end
end

RegisterTaskType(TaskType)
