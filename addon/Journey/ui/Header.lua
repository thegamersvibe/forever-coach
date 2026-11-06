--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("Header")
local hc

local function RefreshIcon()
	if (hc) then
		component.frame.Icon:SetTexture(I[Brand.headerLogoHC])
	else
		component.frame.Icon:SetTexture(I[Brand.headerLogo])
	end
	component.frame.Icon:SetTexCoord(0, 1, 0, 1)
end

function component.Init(components)
	hc = HardcoreService.IsHardcoreEnabled()
	local guideContainer = components.GuideContainer.frame
	local frame = CreateFrame("Frame", nil, guideContainer, "BackdropTemplate")
	component.frame = frame
	frame:SetSize(220, 44)
	frame:SetPoint("TOPLEFT", 22, 0)
	frame.backdropInfo = BACKDROP_GLUE_TOOLTIP_16_16
	frame.backdropColor = GLUE_BACKDROP_COLOR
	frame.backdropColorAlpha = 1.0
	frame.backdropBorderColor = CreateColor(0.78, 0.73, 0.56)
	frame:OnBackdropLoaded()
	frame.IconBorder = frame:CreateTexture(nil, "OVERLAY")
	frame.IconBorder:SetAtlas("auctionhouse-itemicon-border-artifact")
	frame.IconBorder:SetSize(56, 56)
	frame.IconBorder:SetPoint("LEFT", -32, 3)
	if (Brand.headerIconBorderHidden) then
		frame.IconBorder:Hide()
	end
	frame.Icon = frame:CreateTexture(nil, "ARTWORK")
	RefreshIcon()
	frame.Icon:SetSize(Brand.headerIconSize or 36, Brand.headerIconSize or 36)
	frame.Icon:SetPoint("CENTER", frame.IconBorder, "CENTER", Brand.headerIconOffsetX or 0, 0)
end

function component.Update()
	if (component:IsDirty()) then
		local newHC = HardcoreService.IsHardcoreEnabled()
		if (newHC ~= hc) then
			hc = newHC
			RefreshIcon()
		end
		component:MarkClean()
	end
end

UI.Add(component)
