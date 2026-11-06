--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("HeaderSettingsButton")

function component.Init(components)
	local parent = components.Header.frame
	local frame = CreateFrame("Button", nil, parent)
	frame:SetSize(30, 30)
	frame:SetScale(0.7)
	frame:SetPoint("BOTTOMRIGHT", parent.IconBorder, "BOTTOMRIGHT", 2, 4)
	AddTexture(
			frame,
			"Interface\\Minimap\\MiniMap-TrackingBorder",
			52, 52,
			"TOPLEFT")
	AddTexture(
			frame,
			CreateTexture(
					"Interface\\Minimap\\UI-Minimap-Background",
					"BACKGROUND"
			),
			24,24,
			{ "TOPLEFT", 2, -2 })
	AddNormalTexture(
			frame,
			"Interface\\Worldmap\\Gear_64Grey",
			18, 18,
			{ "TOPLEFT", 6.5, -5.5 })
	AddHighlightTexture(
			frame,
			"Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
	AddPushedTexture(
			frame,
			"Interface\\Worldmap\\Gear_64Grey",
			18, 18,
			{ "TOPLEFT", 7.5, -6.5 })
	frame:RegisterForClicks("AnyUp")
	frame:SetScript("OnClick", function()
		UI.ToggleGuideMenu()
	end)
	component.frame = frame
end

UI.Add(component)
