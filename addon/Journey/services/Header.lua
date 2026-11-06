--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

HeaderService = { }

function HeaderService.GetHeaderTitles()
    local title1, title2, zoneTitle
    local currentGuide = GuideNavigationService.GetGuide()
    if (not currentGuide) then
        title1 = nil
        title2 = L["Click cogwheel to load a guide"]
    else
        local activeLocation = LocationsService.GetActiveLocation()
        if (activeLocation) then
            local activeMap = activeLocation:GetMap()
            if (activeMap == currentGuide.info.zone) then
                zoneTitle = nil
            else
                zoneTitle = Names.GetName(GetMapName, activeMap)
            end
        end
        local SoDSkillLineAbilityID = SkillLineAbilityGuideRLUT[currentGuide.id]
        if (SoDSkillLineAbilityID
                and State.GetRuneSpoilerLevel(SoDSkillLineAbilityID) == 0
                and not RunesService.IsRuneGuideComplete(currentGuide.id)) then
            title1 = "Mysterious Rune"
        else
            title1 = currentGuide.info.description
        end
        if (zoneTitle) then
            title2 = title1
            title1 = zoneTitle
        end
    end
    return title1, title2
end

function HeaderService.GetStepText()
    local currentStep = GuideNavigationService.GetStep()
    if (currentStep) then
        if (State.IsDevEnabled()) then
            return currentStep.id
        else
            return string.sub(string.match(currentStep.id,"^([%w-]+)"),1,6)
        end
    end
end
