--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "gameobject",
}, TaskTypeMixin)

function TaskType:RenderFunc(task, container)
	local name = Hyperlinks.GetGameObjectHyperlink(task)
	container.text:SetShown(true)
	container.text:SetText(L["Click on |c%s%s|r."]:format(Color.GAME_OBJECT, name))
end

RegisterTaskType(TaskType)
