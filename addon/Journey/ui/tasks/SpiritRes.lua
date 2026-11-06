--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
    type = "spiritres",
    dimmable = true,
    incompleteIcon = IconService.GetIconInfo("spiritres") --todo: Set icon to something for resurrection
}, TaskTypeMixin)

function TaskType:IsCompletedFunc(task)
    return GhostService.HasPlayerSpiritRessed(task.root)
end

function TaskType:RenderFunc(task, container)
    container.text:SetShown(true)
    if (UnitIsDead("player")) then
        container.text:SetText("Res at the Spirit Healer (Release Spirit)")
    else
        container.text:SetText("Res at the Spirit Healer")
    end
end

function TaskType:Setup(task)
    if (not task.setupCompleted) then
        task.condition = task.condition and "not HC and (DEADORGHOST or (" .. task.condition .. "))" or "not HC and DEADORGHOST"
        task.setupCompleted = true
    end
end

RegisterTaskType(TaskType)
