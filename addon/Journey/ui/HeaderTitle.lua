--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("HeaderTitle")
local title, currentTitleText
local subtitle, currentSubtitleText
local boundingBox

function component.Init(components)
	boundingBox = CreateFrame("Frame", nil, components.Header.frame)
	boundingBox:SetHeight(1)
	title = boundingBox:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetTextScale(0.85)
	title:SetPoint("TOP")
	subtitle = boundingBox:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	subtitle:SetTextScale(0.9)
	subtitle:SetPoint("BOTTOM")
end

function component.Update()
	if (component:IsDirty()) then
		local newTitleText, newSubtitleText = HeaderService.GetHeaderTitles()
		if (currentTitleText ~= newTitleText or currentSubtitleText ~= newSubtitleText) then
			currentTitleText = newTitleText
			currentSubtitleText = newSubtitleText
			boundingBox:SetScale(1)
			title:SetScale(1)
			subtitle:SetScale(1)
			title:SetShown(currentTitleText ~= nil)
			subtitle:SetShown(currentSubtitleText ~= nil)
			title:SetText(currentTitleText or "")
			subtitle:SetText(currentSubtitleText or "")
			local boxHeight = currentTitleText and currentSubtitleText and 1 or 0
			local offs = currentTitleText ~= nil and 4 or 2
			boundingBox:ClearAllPoints()
			boundingBox:SetPoint("LEFT", currentTitleText and 27 or 30, offs)
			boundingBox:SetPoint("RIGHT", currentTitleText and -44 or -16, offs)
			if (currentTitleText) then
				local titleScale = 1
				local titleHeight = title:GetStringHeight()
				if (title:GetStringWidth() > boundingBox:GetWidth()) then
					titleScale = boundingBox:GetWidth() / title:GetStringWidth()
					title:SetScale(titleScale)
				end
				boxHeight = boxHeight + titleHeight * titleScale
			end
			if (currentSubtitleText) then
				local subtitleScale = 1
				local subtitleHeight = subtitle:GetStringHeight()
				if (subtitle:GetStringWidth() > boundingBox:GetWidth()) then
					subtitleScale = boundingBox:GetWidth() / subtitle:GetStringWidth()
					subtitle:SetScale(subtitleScale)
				end
				boxHeight = boxHeight + subtitleHeight * subtitleScale
			end
			boundingBox:SetHeight(boxHeight)
		end
		component:MarkClean()
	end
end

UI.Add(component)
