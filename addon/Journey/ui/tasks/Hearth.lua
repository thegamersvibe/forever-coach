--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "hearth",
	disableCompleteIcon = true,
}, TaskTypeMixin)

function TaskType:RenderFunc(task, container)
	local name = Hyperlinks.GetAreaHyperlink({ area = task.hearth} )
	container.text:SetShown(true)
	container.text:SetText(L["Hearth (if you can) to |C%s%s|r."]:format(Color.AREA, name))
end

RegisterTaskType(TaskType)
