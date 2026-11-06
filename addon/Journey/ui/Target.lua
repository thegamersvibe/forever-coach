--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

if (IsRetailAPI()) then
    return
end

local lastStep

local component = UI.CreateComponent("TargetMarker")

local eventFrame = CreateFrame("Frame")

local markedTargets = { }

local targetsInUse = {
    [1] = false,
    [2] = false,
    [3] = false,
    [4] = false,
    [5] = false,
    [6] = false,
    [7] = false,
    [8] = false,
}

local function SetRaidTargetProxy(target, index)
    targetsInUse[index] = true
    SetRaidTarget(target, index)
end

local function SetRaidTargetNoToggle(index, targetOrMouseover, guid)
    if ( GetRaidTargetIndex(targetOrMouseover) ~= index ) then
        if (IsInGroup()) then
            if (markedTargets[index] == guid) then
                return
            end
        end
        markedTargets[index] = guid
        SetRaidTargetProxy(targetOrMouseover, index);
    end
end

local function TrySetMark(targetOrMouseover, hostileMark, friendlyMark, overrideMark)
    if (State.IsTargetMarkingEnabled()) then
        local isAlive = not UnitIsDead(targetOrMouseover)
        if (UnitExists(targetOrMouseover) and not UnitIsPlayer(targetOrMouseover)) then
            if (not overrideMark and GetRaidTargetIndex(targetOrMouseover)) then
                return
            end
            local guid = UnitGUID(targetOrMouseover)
            local npcType, _, _, _, _, npcID = strsplit("-", guid)
            if (npcType == "Pet") then return end
            npcID = tonumber(npcID)
            local currentStep = GuideNavigationService.IsGuideSet() and GuideNavigationService.GetStep() or nil
            if (currentStep) then
                for _, taskGroup in ipairs(currentStep) do
                    if (taskGroup.conditionPassed and taskGroup.buttons and not UI.IsTaskGroupDimmed(taskGroup)) then
                        for _, actionButtonRef in ipairs(taskGroup.buttons) do
                            if (actionButtonRef.conditionPassed) then
                                if (actionButtonRef.target and actionButtonRef.target == npcID and (isAlive or actionButtonRef.allowdead)) then
                                    if (actionButtonRef.alert) then
                                        SetRaidTargetNoToggle(2, targetOrMouseover, guid)
                                    elseif (UnitCanAttack("player", targetOrMouseover)) then
                                        SetRaidTargetNoToggle(hostileMark, targetOrMouseover, guid)
                                    else
                                        SetRaidTargetNoToggle(friendlyMark, targetOrMouseover, guid)
                                    end
                                    return
                                end
                                if (actionButtonRef.targets) then
                                    for _, target in ipairs(actionButtonRef.targets) do
                                        if (target == npcID and (isAlive or actionButtonRef.allowdead)) then
                                            if (actionButtonRef.alert) then
                                                SetRaidTargetNoToggle(2, targetOrMouseover, guid)
                                            elseif (UnitCanAttack("player", targetOrMouseover)) then
                                                SetRaidTargetNoToggle(hostileMark, targetOrMouseover, guid)
                                            else
                                                SetRaidTargetNoToggle(friendlyMark, targetOrMouseover, guid)
                                            end
                                            return
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
end

local function OnEvent(_, event)
    if (event == "PLAYER_TARGET_CHANGED") then
        TrySetMark("target", 8, 5, true)
    elseif (event == "RAID_TARGET_UPDATE") then
        markedTargets = { }
    end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
eventFrame:RegisterEvent("RAID_TARGET_UPDATE")

function component.Update()
    local currentStep = GuideNavigationService.GetStep()
    if (lastStep ~= currentStep) then
        lastStep = currentStep
        if (State.IsTargetMarkingEnabled() and not IsInGroup()) then
            local cleared = false
            for icon, inUse in ipairs(targetsInUse) do
                if (inUse) then
                    SetRaidTarget("player", icon)
                    targetsInUse[icon] = false
                    cleared = true
                end
            end
            if (cleared) then
                SetRaidTarget("player", 0)
            end
        end
    else
        TrySetMark("mouseover", 7, 5, false)
    end
end

UI.Add(component)