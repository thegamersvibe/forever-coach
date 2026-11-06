--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("DefaultTaskGroupContainer")

local OOPS_MSG = "Oops! It seems that something should be displayed here.\n\n" ..
	"Please report the issue support and be sure to provide the following info:\n\n%s"

local guideFrame
local headerFrame
local TaskGroupContainers
local defaultTaskGroupContainer
local invertedMode = false

function component.Init(components)
	guideFrame = components.GuideContainer.frame
	headerFrame = components.Header.frame
	TaskGroupContainers = components.TaskGroupContainers
	defaultTaskGroupContainer = { }
	local frame = CreateFrame("Frame", nil, guideFrame, "BackdropTemplate")
	frame.boundingBox = CreateFrame("Frame", nil, guideFrame)
	frame.boundingBox:SetSize(240, 50)
	frame.boundingBox:Show()
	frame:SetSize(240, 50)
	frame.backdropInfo = BACKDROP_GLUE_TOOLTIP_16_16
	frame.backdropColor = GLUE_BACKDROP_COLOR
	frame.backdropColorAlpha = 1.0
	frame.backdropBorderColor = GLUE_BACKDROP_BORDER_COLOR
	frame:OnBackdropLoaded()
	defaultTaskGroupContainer.frame = frame
	if (State.IsInvertedModeEnabled()) then
		frame:SetPoint("BOTTOMLEFT", headerFrame, "TOPLEFT", -20, 4)
	else
		frame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", -20, 2)
	end
	frame:SetShown(false)
	local text = frame:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
	text:SetJustifyH("LEFT")
	text:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -10)
	text:SetPoint("RIGHT", frame, "RIGHT", -10, 0)
	defaultTaskGroupContainer.text = text
end

function component.Update()
	if (component:IsDirty()) then
		if (State.IsInvertedModeEnabled() ~= invertedMode) then
			defaultTaskGroupContainer.frame:ClearAllPoints()
			if (State.IsInvertedModeEnabled()) then
				defaultTaskGroupContainer.frame:SetPoint("BOTTOMLEFT", headerFrame, "TOPLEFT", -20, 4)
			else
				defaultTaskGroupContainer.frame:SetPoint("TOPLEFT", headerFrame, "BOTTOMLEFT", -20, 2)
			end
			invertedMode = State.IsInvertedModeEnabled()
		end
		if ((not GuideNavigationService.IsGuideSet()) or TaskGroupContainers.IsShown()) then
			defaultTaskGroupContainer.frame:SetShown(false)
		else
			defaultTaskGroupContainer.frame:SetShown(true)
			defaultTaskGroupContainer.text:SetText(OOPS_MSG:format(Debug.GetDebugInfo()))
			defaultTaskGroupContainer.frame:SetHeight(defaultTaskGroupContainer.text:GetStringHeight() + 26)
		end
		component:MarkClean()
	end
end

UI.Add(component)
