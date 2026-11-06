--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local autoAdvanceEnabled, currentGuide, currentStep, hasNextStep, hasPreviousStep, manualOverrideEnabled,
    progressTrackersDirty
local GetNextStepID, GetPreviousStepID, SyncValues, UpdateLastPassing

function GetNextStepID(skipCompleted)
    local last = currentStep
    for idx = currentStep.idx + 1, #currentGuide do
        local step = currentGuide[idx]
        EvaluationService.EvaluateStep(step)
        if (step.conditionPassed) then
            last = step
            if (skipCompleted) then
                if (not step.completedPassed) then
                    return step.id
                end
            else
                return step.id
            end
        end
    end
    return last.id
end

function GetPreviousStepID(skipCompleted)
    local last = currentStep
    for idx = currentStep.idx - 1, 1, -1 do
        local step = currentGuide[idx]
        EvaluationService.EvaluateStep(step)
        if (step.conditionPassed) then
            last = step
            if (skipCompleted) then
                if (not step.completedPassed) then
                    return step.id
                end
            else
                return step.id
            end
        end
    end
    return last.id
end

function SyncValues(key, table1, table2)
    local value = table1[key] or table2[key]
    table1[key] = value
    table2[key] = value
end

function UpdateLastPassing()
    local lastPassingChecked = currentGuide.lastPassing and currentGuide.lastPassing.idx
    currentGuide.lastPassing = nil
    for idx = #currentGuide, 1, -1 do
        local step = currentGuide[idx]
        if (idx ~= lastPassingChecked) then
            EvaluationService.EvaluateStepConditions(step)
        end
        if (step.conditionPassed) then
            currentGuide.lastPassing = step
            break
        end
    end
    if (lastPassingChecked ~= (currentGuide.lastPassing and currentGuide.lastPassing.idx)) then
        progressTrackersDirty = true
    end
end

GuideNavigationService = { }

function GuideNavigationService.AutoAdvance()
    if (not currentStep.conditionPassed or
            (autoAdvanceEnabled and currentStep.completedPassed and GuideNavigationService.HasNextStep())) then
        GuideNavigationService.SetStep(GetNextStepID())
        LocationsService.UpdatePlayerPosition()
        GuideNavigationService.SetManualOverrideEnabled(false)
        return true
    end
    if (not currentStep.completedPassed) then
        autoAdvanceEnabled = true
    end
    return false
end

function GuideNavigationService.ClearCaches()
    hasNextStep = nil
    hasPreviousStep = nil
end

function GuideNavigationService.GetGuide()
    return currentGuide
end

function GuideNavigationService.GetStep()
    return currentStep
end

function GuideNavigationService.Goto(guideID, stepID)
    if (guideID) then
        if (guideID == "return") then
            guideID = State.GetReturnToGuide(GUIDE_TYPE.LEVELING)
        end
        if (Brand.resolveGuideAlias) then
            guideID = Brand.resolveGuideAlias(guideID) or guideID
        end
        GuideNavigationService.SetGuide(guideID)
        if (not stepID) then
            GuideNavigationService.SetStepFromBookmark()
        end
    end
    if (stepID) then
        if (stepID == "next") then
            GuideNavigationService.SetStepToNext(true)
        else
            GuideNavigationService.SetStep(stepID)
        end
    end
end

function GuideNavigationService.HasNextStep()
    if (hasNextStep ~= nil) then return hasNextStep end
    if (currentGuide) then
        if (currentStep.idx == #currentGuide) then return false end
        if (currentGuide.lastPassing) then
            EvaluationService.EvaluateStepConditions(currentGuide.lastPassing)
        end
        if (not currentStep.conditionPassed or
                (currentGuide.lastPassing and currentGuide.lastPassing.idx <= currentStep.idx)
                or (not (currentGuide.lastPassing and currentGuide.lastPassing.conditionPassed))) then
            UpdateLastPassing()
        end
        if (currentGuide.lastPassing) then
            return currentGuide.lastPassing.idx > currentStep.idx
        end
    end
    return false
end

function GuideNavigationService.HasPreviousStep()
    if (hasPreviousStep ~= nil) then return hasPreviousStep end
    if (currentGuide) then
        if (currentStep.idx == 1) then return false end
        if (currentGuide.firstPassing) then
            EvaluationService.EvaluateStepConditions(currentGuide.firstPassing)
        end
        if (not currentStep.conditionPassed or
                (currentGuide.firstPassing and currentGuide.firstPassing.idx == currentStep.idx)
                or (not (currentGuide.firstPassing and currentGuide.firstPassing.conditionPassed))) then
            local firstPassingChecked = currentGuide.firstPassing and currentGuide.firstPassing.idx
            currentGuide.firstPassing = nil
            for _, step in ipairs(currentGuide) do
                if (step.idx ~= firstPassingChecked) then
                    EvaluationService.EvaluateStepConditions(step)
                end
                if (step.conditionPassed) then
                    currentGuide.firstPassing = step
                    break
                end
            end
            if (firstPassingChecked ~= (currentGuide.firstPassing and currentGuide.firstPassing.idx)) then
                progressTrackersDirty = true
            end
        end
        if (currentGuide.firstPassing) then
            return currentGuide.firstPassing.idx < currentStep.idx
        end
    end
    return false
end

function GuideNavigationService.IsAutoAdvanceEnabled()
    return autoAdvanceEnabled and true or false
end

function GuideNavigationService.IsGuideSet()
    return currentGuide ~= nil and currentStep ~= nil
end

function GuideNavigationService.IsInstanceStep()
    if (currentGuide) then
        if (currentStep.instance) then return true end
    end
    return false
end

function GuideNavigationService.IsManualOverrideEnabled()
    return manualOverrideEnabled and true or false
end

function GuideNavigationService.RefreshProgressTrackers()
    if (currentGuide and progressTrackersDirty) then
        local progress = 0
        for _, step in ipairs(currentGuide) do
            step.progress = progress
            if (CheckCondition(step)) then
                for _, taskGroup in ipairs(step) do
                    progress = progress + #taskGroup
                end
            end
        end
        currentGuide.progress = progress
        progressTrackersDirty = nil
    end
end

function GuideNavigationService.SetAutoAdvanceEnabled(enabled)
    autoAdvanceEnabled = enabled
end

function GuideNavigationService.SetSeeking(enabled)
    ConditionContext["SEEKING"] = enabled or nil
end

function GuideNavigationService.SetManualOverrideEnabled(enabled)
    manualOverrideEnabled = enabled
end

function GuideNavigationService.SetGuide(guideID)
    local lastGuideID = currentGuide and currentGuide.id
    autoAdvanceEnabled = true
    State.SetGuide(guideID)
    currentGuide = guideID and GuideService.GetGuide(guideID)
    if (currentGuide and currentGuide.id ~= lastGuideID) then
        TriggerService.OnLoad()
    end
    progressTrackersDirty = true
    currentStep = nil
    LocationsService.SetStep(nil)
    LocationsService.SetGuide(currentGuide)
    MarkAllDirty()
end

function GuideNavigationService.SetStep(stepID)
    if (currentGuide) then
        local lastStep = currentStep
        currentStep = currentGuide.stepLUT[stepID]
        if (currentStep ~= lastStep) then
            ConditionContext["COMPLETEONSTART"] = nil
            ConditionContext["INCOMPLETEONSTART"] = nil
        end
        if (currentStep) then
            EvaluationService.EvaluateStepConditions(currentStep)
        end
        if (not (currentStep and currentStep.conditionPassed)) then
            for idx = currentStep and currentStep.idx + 1 or 1, #currentGuide do
                local newStep = currentGuide[idx]
                EvaluationService.EvaluateStepConditions(newStep)
                if (newStep.conditionPassed) then
                    currentStep = newStep
                    if (stepID <= newStep.id) then
                        break
                    end
                end
            end
        end
        if ((not currentGuide.lastPassing) or currentGuide.lastPassing.idx <= currentStep.idx or not currentStep.conditionPassed) then
            UpdateLastPassing()
        end
        if (currentStep.idx > currentGuide.lastPassing.idx) then
            currentStep = currentGuide.lastPassing
        end
        if (currentGuide.bookmark.stepID ~= currentStep.id) then
            currentGuide.bookmark.stepID = currentStep.id
            currentGuide.bookmark.checkpoint = 0
            currentGuide.bookmark.visited = { }
            currentGuide.bookmark.exited = { }
            currentGuide.bookmark.merchantVisited = nil
            currentGuide.bookmark.petStableVisited = nil
            currentGuide.bookmark.talentTrainerVisited = nil
            currentGuide.bookmark.tradeskillTrainerVisited = nil
            currentGuide.bookmark.taxiTaken = nil
            currentGuide.bookmark.died = nil
            currentGuide.bookmark.spiritRessed = nil
            currentGuide.bookmark.spellsCast = nil
        end
        SyncValues("merchantVisited", currentGuide.bookmark, currentStep)
        SyncValues("petStableVisited", currentGuide.bookmark, currentStep)
        SyncValues("talentTrainerVisited", currentGuide.bookmark, currentStep)
        SyncValues("tradeskillTrainerVisited", currentGuide.bookmark, currentStep)
        SyncValues("taxiTaken", currentGuide.bookmark, currentStep)
        SyncValues("died", currentGuide.bookmark, currentStep)
        SyncValues("spiritRessed", currentGuide.bookmark, currentStep)
        Debug.AnnounceStep()
        LocationsService.SetStep(currentStep)
        EvaluationService.ResetStep(currentStep)
        MarkAllDirty()
    end
end

function GuideNavigationService.SetStepFromBookmark()
    if (currentGuide) then
        GuideNavigationService.SetStep(currentGuide.bookmark.stepID or "")
        GuideNavigationService.SetAutoAdvanceEnabled(true)
    end
end

function GuideNavigationService.SetStepToNext(skipCompleted)
    autoAdvanceEnabled = nil
    GuideNavigationService.SetStep(GetNextStepID(skipCompleted))
end

function GuideNavigationService.SetStepToPrevious(skipCompleted)
    autoAdvanceEnabled = nil
    GuideNavigationService.SetStep(GetPreviousStepID(skipCompleted))
end
