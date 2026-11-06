--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("ExpBarMark")

function component.Init()
    if (MainMenuExpBar and ExhaustionTick) then
        component.frame = CreateFrame("Frame", nil, UIParent)
        local frameSize = MainMenuExpBar:GetHeight() * 1.8
        local frameStrata = ExhaustionTick:GetFrameStrata()
        local frameLevel = ExhaustionTick:GetFrameLevel() + 1
        component.frame:SetSize(frameSize, frameSize)
        component.frame:SetFrameStrata(frameStrata)
        component.frame:SetFrameLevel(frameLevel)
        component.frame.texture = component.frame:CreateTexture(nil, "ARTWORK")
        component.frame.texture:SetAtlas(IconService.GetIconInfo("vignettekill").atlas)
        component.frame.texture:SetAllPoints()
        component.frame:SetShown(false)
    end
end

function component.Update()
    if (MainMenuExpBar and ExhaustionTick) then
        if (component:IsDirty()) then
            component.frame:SetShown(false)
            component:MarkClean()
        end
    end
end

function UI.SetXPGoal(goal)
    if (MainMenuExpBar and ExhaustionTick and MainMenuExpBar:IsShown()) then
        local xpmax = UnitXPMax("player")
        local perc = goal / xpmax
        local xoffset = MainMenuExpBar:GetWidth() * perc
        component.frame:ClearAllPoints()
        component.frame:SetPoint("CENTER", MainMenuExpBar, "LEFT", xoffset, 0)
        component.frame:SetShown(true)
    end
end

UI.Add(component)
