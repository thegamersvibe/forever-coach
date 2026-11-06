--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

EvaluationService = { }

function EvaluationService.EvaluateStep(step)
    EvaluationService.EvaluateStepConditions(step)
    -- Evaluate completions
    -- If the step has a "completed" attribute, this will override anything which follows
    step.completedPassed = CheckCompleted(step)
    local completedTaskGroups = 0
    for _, taskGroup in ipairs(step) do
        if (taskGroup.conditionPassed) then
            taskGroup.completedPassed = CheckCompleted(taskGroup)
            taskGroup.optionalPassed = true
            local completedTasks = 0
            for _, task in ipairs(taskGroup) do
                if (task.conditionPassed) then
                    task.completedPassed = CheckCompleted(task)
                    local taskType = task.taskType
                    if (task.completed == nil) then
                        task.completedPassed = taskType:IsCompleted(task)
                    end
                    if (task.completedPassed or taskType:IsOptional(task)) then
                        completedTasks = completedTasks + 1
                    end
                    if (taskType:IsOptional(task) and not task.completedPassed) then
                        taskGroup.optionalPassed = false
                    end
                    TriggerService.OnComplete(task)
                else
                    completedTasks = completedTasks + 1
                end
            end
            if (taskGroup.completed == nil) then
                taskGroup.completedPassed = completedTasks == #taskGroup
            end
            if (taskGroup.completedPassed) then
                completedTaskGroups = completedTaskGroups + 1
            end
            TriggerService.OnComplete(taskGroup)
        else
            completedTaskGroups = completedTaskGroups + 1
        end
    end
    if (step.completed == nil) then
        step.completedPassed = completedTaskGroups == #step
    end
    TriggerService.OnComplete(step)
    if (step.locations) then
        for _, location in ipairs(step.locations) do
            location.conditionPassed = CheckCondition(location)
        end
    end
end

function EvaluationService.EvaluateStepConditions(step)
    -- Evaluate conditions
    step.conditionPassed = CheckCondition(step)
    local conditionPassedTaskGroups = 0
    for _, taskGroup in ipairs(step) do
        taskGroup.conditionPassed = step.conditionPassed and CheckCondition(taskGroup)
        if (taskGroup.buttons) then
            for _, button in ipairs(taskGroup.buttons) do
                button.conditionPassed = CheckCondition(button)
            end
        end
        local conditionPassedTasks = 0
        for _, task in ipairs(taskGroup) do
            task.conditionPassed = step.conditionPassed and taskGroup.conditionPassed and CheckCondition(task)
            if (task.conditionPassed) then
                conditionPassedTasks = conditionPassedTasks + 1
            end
        end
        -- If the taskGroup contains no passing tasks, override the taskGroup's evaluation
        if (conditionPassedTasks == 0) then
            taskGroup.conditionPassed = false
        end
        if (taskGroup.conditionPassed) then
            conditionPassedTaskGroups = conditionPassedTaskGroups + 1
        end
    end
    -- If the step contains no passing taskGroups, override the step's evaluation
    if (conditionPassedTaskGroups == 0) then
        step.conditionPassed = false
    end
end

function EvaluationService.ResetStep(step)
    step.completedFired = nil
    for _, taskGroup in ipairs(step) do
        taskGroup.completedFired = nil
        for _, task in ipairs(taskGroup) do
            task.completedFired = nil
        end
    end
end
