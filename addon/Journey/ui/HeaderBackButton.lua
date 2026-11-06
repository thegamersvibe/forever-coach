--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("HeaderBackButton")

function component.Init(components)
	local parent = components.Header.frame
	local frame = CreateFrame("Button", nil, parent)
	frame:SetSize(20,20)
	frame:SetPoint("RIGHT", parent, "RIGHT", -22, 4)
	frame:Disable()
	AddNormalTexture(frame, I["UI-SquareButton-Left-Up"])
	AddDisabledTexture(frame, I["UI-SquareButton-Left-Disabled"])
	AddHighlightTexture(
			frame,
			CreateTexture("Interface\\Buttons\\UI-Common-MouseHilight",nil,nil, "ADD"))
	AddPushedTexture(frame, I["UI-SquareButton-Left-Down"])
	frame:SetScript("OnClick", function()
		if (IsShiftKeyDown()) then
			GuideNavigationService.SetSeeking(true)
			GuideNavigationService.SetManualOverrideEnabled(false)
			GuideNavigationService.SetStepToPrevious(true)
			GuideNavigationService.SetSeeking(false)
		else
			GuideNavigationService.SetManualOverrideEnabled(true)
			GuideNavigationService.SetStepToPrevious()
		end
	end)
	component.frame = frame
end

function component.Update()
	if (component:IsDirty()) then
		if (GuideNavigationService.IsGuideSet()) then
			component.frame:SetEnabled(GuideNavigationService.HasPreviousStep())
			component.frame:SetShown(true)
		else
			component.frame:SetShown(false)
		end
		component:MarkClean()
	end
end

UI.Add(component)
