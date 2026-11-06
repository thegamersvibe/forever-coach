--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local OnEvent
local merchantShowing
local petStableShowing
local trainerShowing

function OnEvent(_, event)
    if (GuideNavigationService.IsGuideSet()) then
        local bookmark = GuideNavigationService.GetGuide().bookmark
        local currentStep = GuideNavigationService.GetStep()
        if (event == "MERCHANT_SHOW") then
            merchantShowing = true
        elseif (merchantShowing and event == "MERCHANT_CLOSED") then
            bookmark.merchantVisited = true
            currentStep.merchantVisited = true
            merchantShowing = nil
            MarkAllDirty()
        elseif (event == "TRAINER_SHOW") then
            trainerShowing = true
        elseif (trainerShowing and event == "TRAINER_CLOSED") then
            if (IsTradeskillTrainer()) then
                bookmark.tradeskillTrainerVisited = true
                currentStep.tradeskillTrainerVisited = true
            else
                bookmark.talentTrainerVisited = true
                currentStep.talentTrainerVisited = true
            end
            trainerShowing = nil
            MarkAllDirty()
        elseif (event == "PET_STABLE_SHOW") then
            petStableShowing = true
        elseif (petStableShowing and event == "PET_STABLE_CLOSED") then
            bookmark.petStableVisited = true
            currentStep.petStableVisited = true
            petStableShowing = nil
            MarkAllDirty()
        end
    end
end

MERCHANT_TYPE = {
    SUPPLIES = 1,
    REPAIRS = 2,
    TALENTS = 3,
    TRADESKILLS = 4,
    STABLEIN = 5,
    WEAPONSKILLS = 6,
    STABLEOUT = 7,
}

MerchantService = { }

function MerchantService.IsSupplyMerchantVisited(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.merchantVisited or false
end

function MerchantService.IsPetStableVisited(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.petStableVisited or false
end

function MerchantService.IsRepairMerchantVisited(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.merchantVisited or false
end

function MerchantService.IsTalentTrainerVisited(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.talentTrainerVisited or false
end

function MerchantService.IsTradeskillTrainerVisited(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.tradeskillTrainerVisited or false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("MERCHANT_SHOW")
frame:RegisterEvent("MERCHANT_CLOSED")
frame:RegisterEvent("PET_STABLE_SHOW")
frame:RegisterEvent("PET_STABLE_CLOSED")
frame:RegisterEvent("TRAINER_SHOW")
frame:RegisterEvent("TRAINER_CLOSED")
frame:SetScript("OnEvent", OnEvent)
