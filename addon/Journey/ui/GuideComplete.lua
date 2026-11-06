--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("ProgressBar")

local modelFrame
local guideContainer
local shown

function component.Init(components)
	guideContainer = components.GuideContainer.frame
	modelFrame = CreateFrame("PlayerModel")
	modelFrame:SetFrameLevel(5)
	modelFrame:SetScript("OnUpdate", Model_OnUpdate)
	modelFrame:SetSize(75,150)
	modelFrame:SetShown(false)
end

function component.Update()
	if (component:IsDirty()) then
		if (GuideNavigationService.IsGuideSet()) then
			if (not GuideNavigationService.HasNextStep()) then
				if (not shown) then
					shown = true
					modelFrame:SetShown(true)
					modelFrame:SetUnit("player", false)
					modelFrame:ClearAllPoints()
					modelFrame:SetPoint("BOTTOMRIGHT", guideContainer, "TOPRIGHT", -24, -60)
					modelFrame:SetAnimation(68)
					PlaySound(8173)
					C_Timer.NewTimer(3, function()
						modelFrame:SetShown(false)
						UI:MarkDirty()
					end)
				end
			else
				shown = false
				modelFrame:SetShown(false)
			end
		end
		component:MarkClean()
	end
end

UI.Add(component)
