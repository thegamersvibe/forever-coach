--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local OnEvent
local spiritHealerLocation = {
    GetTooltipLabel = function() return "Spirit Healer" end,

}
local updateSpiritHealerLocation

function OnEvent(_, event)
    if (GuideNavigationService.IsGuideSet()) then
        local bookmark = GuideNavigationService.GetGuide().bookmark
        local currentStep = GuideNavigationService.GetStep()
        if (event == "PLAYER_DEAD") then
            bookmark.died = true
            currentStep.died = true
            State.SetLastSpiritHealerLocation(nil)
            MarkAllDirty()
        elseif (event == "PLAYER_ALIVE" or event == "PLAYER_UNGHOST") then
            if (UnitIsDeadOrGhost("player")) then
                updateSpiritHealerLocation = { UnitPosition("player") }
            else
                local last = State.GetLastSpiritHealerLocation()
                if (last) then
                    local x, y, _, continentID = UnitPosition("player")
                    if (x and continentID == last.continentID
                            and addon.GetDistanceInYards(x, y, last.x, last.y) <= 15) then
                        bookmark.spiritRessed = true
                        currentStep.spiritRessed = true
                    end
                end
                State.SetLastSpiritHealerLocation(nil)
            end
            MarkAllDirty()
        end
    end
end

GhostService = { }

function GhostService.GetSpiritHealerLocation()
    return spiritHealerLocation
end

function GhostService.HasPlayerDied(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.died or false
end

function GhostService.HasPlayerSpiritRessed(rootNode)
    local step = rootNode or GuideNavigationService.GetStep()
    return step.spiritRessed or false
end

function GhostService.IsSpiritRessing()
    if (GuideNavigationService.IsGuideSet()) then
        for _, taskGroup in ipairs(GuideNavigationService.GetStep()) do
            if (taskGroup.conditionPassed and not taskGroup.completedPassed) then
                for _, task in ipairs(taskGroup) do
                    if (task.spiritres and task.conditionPassed and not task.completedPassed) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

function GhostService.Update()
    if (updateSpiritHealerLocation) then
        local x, y, _, instanceID = UnitPosition("player")
        local location
        if (x) then
            local playerFacing = GetPlayerFacing()
            location = {
                x = x + 7 * math.cos(playerFacing),
                y = y + 7 * math.sin(playerFacing),
                continentID = instanceID,
                mapID = C_Map.GetBestMapForUnit("player")
            }
        end
        State.SetLastSpiritHealerLocation(location)
        if (updateSpiritHealerLocation[1]) then
            if (x) then
                if (x == updateSpiritHealerLocation[1] and y == updateSpiritHealerLocation[2]) then
                    State.SetLastSpiritHealerLocation(nil)
                    return
                end
            else
                return
            end
        end
        updateSpiritHealerLocation = nil
        MarkAllDirty()
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_ALIVE")
frame:RegisterEvent("PLAYER_UNGHOST")
