--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("ProgressBar")

local barWidth, completeBar, hc, headerFrame, incompleteBar

function component.Init(components)
	headerFrame = components.Header.frame
	completeBar = headerFrame:CreateTexture("Background")
	completeBar:SetDrawLayer("Background", 1)
	completeBar:SetColorTexture(10/255, 101/255, 174/255)
	completeBar:SetPoint("BOTTOMLEFT", headerFrame, "BOTTOMLEFT", 24, 8.75)
	completeBar:SetAlpha(0.5)
	completeBar:SetSize(0,4.25)
	incompleteBar = headerFrame:CreateTexture("Background")
	incompleteBar:SetDrawLayer("Background", -1)
	incompleteBar:SetColorTexture(10/255, 101/255, 174/255)
	incompleteBar:SetPoint("LEFT", completeBar, "LEFT")
	incompleteBar:SetPoint("RIGHT", headerFrame, "RIGHT", -4.75, 0)
	incompleteBar:SetHeight(4.25)
	incompleteBar:SetAlpha(0.5)
	barWidth = incompleteBar:GetWidth()
end

function component.Update()
	if (component:IsDirty()) then
		local newHC = HardcoreService.IsHardcoreEnabled()
		if (newHC ~= hc) then
			hc = newHC
			if (hc) then
				completeBar:SetColorTexture(1, 0, 0)
				incompleteBar:SetColorTexture(1, 0, 0)
			else
				completeBar:SetColorTexture(0.04, 0.4, 0.68)
				incompleteBar:SetColorTexture(0.04, 0.4, 0.68)
			end
		end
		if (GuideNavigationService.IsGuideSet()) then
			local currentGuide = GuideNavigationService.GetGuide()
			local progress
			if (not GuideNavigationService.HasNextStep()) then
				progress = 1
			elseif (not GuideNavigationService.HasPreviousStep()) then
				progress = 0
			else
				progress = (GuideNavigationService.GetStep().progress / currentGuide.progress)
			end
			completeBar:SetWidth(progress * barWidth)
			completeBar:SetShown(progress ~= 0)
			incompleteBar:SetShown(progress ~= 1)
		else
			completeBar:SetShown(false)
			incompleteBar:SetShown(false)
		end
		component:MarkClean()
	end
end

UI.Add(component)
