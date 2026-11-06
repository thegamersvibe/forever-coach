--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local IllustrationContainer = CreateFrame("Button", nil, UIParent)
IllustrationContainer:SetFrameStrata("FULLSCREEN")
IllustrationContainer:SetPoint("TOPLEFT")
IllustrationContainer:SetPoint("BOTTOMRIGHT")
local blackout = IllustrationContainer:CreateTexture(nil, "BACKGROUND")
blackout:SetColorTexture(0, 0, 0, 1)
blackout:SetAllPoints()
local illustrationFrame = IllustrationContainer:CreateTexture(nil, "ARTWORK")
illustrationFrame:SetPoint("CENTER")

IllustrationContainer:Hide()
IllustrationContainer:SetScript("OnClick", function(self)
	self:Hide()
end)

function ShowIllustration(filename)
	local illustration = IllustrationService.GetIllustration(filename)
	if (illustration) then
		local wscale = 1.0
		local hscale = 1.0
		if (illustration.width > blackout:GetWidth()) then
			wscale = blackout:GetWidth() / illustration.width
		end
		if (illustration.height > blackout:GetHeight()) then
			hscale = blackout:GetHeight() / illustration.height
		end
		illustrationFrame:SetTexCoord(illustration.left, illustration.right, illustration.top, illustration.bottom)
		illustrationFrame:SetTexture(string.format("Interface/AddOns/%s/illustrations/%s.png", addonName, filename))
		local scale = math.min(wscale, hscale)
		illustrationFrame:SetSize(illustration.width * scale, illustration.height * scale)
		IllustrationContainer:Show()
	end
end
