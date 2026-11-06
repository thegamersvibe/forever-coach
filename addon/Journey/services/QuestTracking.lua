--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

QuestTrackingService = { }

local activeQuestID
local superTrackedByUs

local function CanUseSuperTrack()
    return C_SuperTrack and C_SuperTrack.SetSuperTrackedQuestID
end

local function ActivateViaSuperTrack(questID)
    if (InCombatLockdown()) then return end
    if (C_SuperTrack.GetSuperTrackedQuestID() ~= questID) then
        C_SuperTrack.SetSuperTrackedQuestID(questID)
    end
    superTrackedByUs = questID
end

local function DeactivateViaSuperTrack()
    if (InCombatLockdown()) then return end
    if (superTrackedByUs and C_SuperTrack.GetSuperTrackedQuestID() == superTrackedByUs) then
        C_SuperTrack.SetSuperTrackedQuestID(0)
    end
    superTrackedByUs = nil
end

-- TODO: Era fallback -- draw blob ourselves using QuestPOIFrame on the world map canvas

local function ShouldTrack(questID)
    if (not questID) then return false end
    local status = QuestStatus.GetQuestStatus(questID)
    return status == QuestStatus.status.ACCEPTED or status == QuestStatus.status.COMPLETED
end

local function GetActiveQuestFromStep()
    local step = GuideNavigationService.GetStep()
    if (not step) then return nil end
    for _, taskGroup in ipairs(step) do
        if (taskGroup.conditionPassed and not taskGroup.completedPassed) then
            for _, task in ipairs(taskGroup) do
                if (task.conditionPassed and not task.completedPassed) then
                    local questID = task.complete or task.startwork or task.turnin
                    if (questID) then
                        return questID
                    end
                end
            end
        end
    end
    return nil
end

local function ApplyTracking(questID)
    activeQuestID = questID
    if (ShouldTrack(questID)) then
        if (CanUseSuperTrack()) then
            ActivateViaSuperTrack(questID)
        end
    else
        if (CanUseSuperTrack()) then
            DeactivateViaSuperTrack()
        end
    end
end

function QuestTrackingService.Update()
    ApplyTracking(GetActiveQuestFromStep())
end

function QuestTrackingService.GetActiveQuest()
    return activeQuestID
end

if (CanUseSuperTrack()) then
    local eventFrame = CreateFrame("Frame")
    eventFrame:RegisterEvent("QUEST_ACCEPTED")
    eventFrame:SetScript("OnEvent", function(_, _, questID)
        local current = C_SuperTrack.GetSuperTrackedQuestID()
        if (current == questID) then
            ApplyTracking(activeQuestID)
        end
    end)
end
