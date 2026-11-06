--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
    type = "die",
    dimmable = true,
    incompleteIcon = IconService.GetIconInfo("dungeonskull")
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
    return GhostService.HasPlayerDied(task.root)
end

function TaskType:RenderFunc(task, container)
    container.text:SetShown(true)
    container.text:SetText("Die on purpose")
end

function TaskType:Setup(task)
    if (not task.setupCompleted) then
        task.condition = task.condition and "not HC and (" .. task.condition .. ")" or "not HC"
        task.setupCompleted = true
    end
end

RegisterTaskType(TaskType)
