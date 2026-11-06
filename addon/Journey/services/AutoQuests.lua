--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local CreateLUTFromIDs, CreateLUTFromTitles, FindFirstEligible, GetQuestReward0, GetQuestReward1, OnEvent

function CreateLUTFromIDs(data)
    if (data and #data > 0) then
        local result = { }
        for _, row in ipairs(data) do
            result[row.questID] = row.questID
        end
        return result
    end
end

function CreateLUTFromTitles(rowlen, ...)
    local datalen = select("#", ...)
    if (datalen > 0) then
        local result = { }
        local count = 0
        for i = 1, datalen , rowlen do
            count = count + 1
            result[select(i, ...)] = count
        end
        return result
    end
end

function FindFirstEligible(acceptQuests, turninQuests, useIDs, questComplete)
    local currentStep = GuideNavigationService.GetStep()
    for _, taskGroup in ipairs(currentStep) do
        if (taskGroup.conditionPassed) then
            for _, task in ipairs(taskGroup) do
                if (task.acceptone or task.accept or task.turnin) then
                    local questIDs = task.acceptone
                    if (not questIDs) then
                        questIDs = { task.accept or task.turnin }
                    end
                    for _, questID in ipairs(questIDs) do
                        if (questID
                                and not C_QuestLog_IsQuestFlaggedCompleted(questID)
                                and task.conditionPassed
                                and (not task.completedPassed or task.optional)
                                and task.auto ~= false) then
                            local lut = (((task.accept or task.acceptone) and not C_QuestLog_IsOnQuest(questID)) and acceptQuests)
                                    or (task.turnin and (questComplete or IsQuestCompleted(questID)) and turninQuests)
                            if (lut) then
                                local questKey = (useIDs and questID) or Names.GetQuestName(questID)
                                local result = lut[questKey]
                                if (result) then
                                    return result, (task.accept or task.acceptone) and true
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

function GetQuestReward0()
    GetQuestReward(0)
end

function GetQuestReward1()
    GetQuestReward(1)
end

function OnEvent(_, event, ...)
    if (GuideNavigationService.IsGuideSet()) then
        local autoQuestsEnabled = State.IsAutoQuestsEnabled()
        local currentStep = GuideNavigationService.GetStep()
        if (not currentStep.completedPassed) then
            local acceptQuests, turninQuests, useIDs, acceptFunction, turninFunction, questComplete
            if (event == "QUEST_DETAIL") then
                local questID = GetQuestID()
                acceptQuests = { [questID] = questID }
                acceptFunction = AcceptQuest
                useIDs = true
            elseif (event == "QUEST_PROGRESS") then
                if (not IsQuestCompletable()) then return end
                local questID = GetQuestID()
                turninQuests = { [questID] = questID }
                turninFunction = CompleteQuest
                useIDs = true
            elseif (event == "QUEST_COMPLETE") then
                if (GetNumQuestChoices() > 1) then return end
                local questID = GetQuestID()
                turninQuests = { [questID] = questID }
                turninFunction = GetNumQuestChoices() == 0 and GetQuestReward0 or GetQuestReward1
                questComplete = true
                useIDs = true
            elseif (event == "GOSSIP_SHOW") then
                if (C_GossipInfo and C_GossipInfo.GetAvailableQuests) then
                    acceptQuests = CreateLUTFromIDs(C_GossipInfo.GetAvailableQuests())
                    turninQuests = CreateLUTFromIDs(C_GossipInfo.GetActiveQuests())
                    acceptFunction =  C_GossipInfo.SelectAvailableQuest
                    turninFunction = C_GossipInfo.SelectActiveQuest
                    useIDs = true
                else
                    acceptQuests = CreateLUTFromTitles(7, GetGossipAvailableQuests())
                    turninQuests = CreateLUTFromTitles(6, GetGossipActiveQuests())
                    acceptFunction = SelectGossipAvailableQuest
                    turninFunction = SelectGossipActiveQuest
                end
            elseif (event == "QUEST_GREETING") then
                local numAvailableQuests = GetNumAvailableQuests()
                if (numAvailableQuests > 0) then
                    acceptQuests = { }
                    for i = 1, numAvailableQuests do
                        acceptQuests[GetAvailableTitle(i)] = i
                    end
                    acceptFunction = SelectAvailableQuest
                end
                local numActiveQuests = GetNumActiveQuests()
                if (numActiveQuests > 0) then
                    turninQuests = { }
                    for i = 1, numActiveQuests do
                        turninQuests[GetActiveTitle(i)] = i
                    end
                    turninFunction = SelectActiveQuest
                end
            end
            local result, isAccept = FindFirstEligible(acceptQuests, turninQuests, useIDs, questComplete)
            if (result and autoQuestsEnabled) then
                if (isAccept) then
                    acceptFunction(result)
                else
                    turninFunction(result)
                end
                return true
            end
        end
    end
end

AutoQuestsService = { }

function AutoQuestsService.OnGossipShow()
    return OnEvent(_, "GOSSIP_SHOW")
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GOSSIP_SHOW")
eventFrame:RegisterEvent("QUEST_COMPLETE")
eventFrame:RegisterEvent("QUEST_DETAIL")
eventFrame:RegisterEvent("QUEST_GREETING")
eventFrame:RegisterEvent("QUEST_PROGRESS")
eventFrame:SetScript("OnEvent", OnEvent)
