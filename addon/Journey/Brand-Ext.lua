--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

-- Local artwork aliases leave the shared images/content resolver unchanged.
I["relax-icon"] = "Interface\\AddOns\\Journey\\assets\\relax-icon"
I["relax-banner"] = "Interface\\AddOns\\Journey\\assets\\relax-banner"
Brand.headerLogo = "relax-icon"
Brand.minimapIcon = "relax-icon"
Brand.headerLogoHC = "relax-icon"
Brand.headerIconBorderHidden = true
Brand.headerIconSize = 58
Brand.headerIconOffsetX = -2
Brand.hardcoreDisabled = true
Brand.slashCommand = "journey"
Brand.hasWebGuides = false
Brand.installerName = "Journey Guide Manager"


function Brand.configurationWindowSetupTitle(parent)
	-- The 1024x512 texture contains a 1024x434 banner above transparent padding.
	local bannerHeight = 256 * 434 / 1024
	local logo = parent:CreateTexture(nil, "ARTWORK")
	logo:SetTexture(I["relax-banner"])
	logo:SetTexCoord(0, 1, 0, 434 / 512)
	logo:SetSize(256, bannerHeight)
	logo:SetPoint("TOP", 0, -20)

	local title = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	title:SetPoint("TOP", logo, "BOTTOM", 0, -6)
	title:SetText(string.format("%s %s", addonTitle, GetDisplayVersion()))
	-- Keep the controls below the title as the banner's aspect ratio changes.
	return title, 20 + bannerHeight + 6 + 60
end

-- Deprecated: Remove this once Era guides are fully migrated to Forever context including guide ID conditions and
-- goto buttons have been resolved
function Brand.registerGuideAlias(guideID, context)
	local baseID = guideID:match("^(.+)_FVR$")
	if (baseID) then
		context[baseID] = true
	end
end

-- Deprecated: Remove this once Era guides are fully migrated to Forever context including guide ID conditions and
-- goto buttons have been resolved
function Brand.resolveGuideAlias(guideID)
	if (not CatalogService.IsInstalled(guideID)) then
		local fvrID = guideID .. "_FVR"
		if (CatalogService.IsInstalled(fvrID)) then
			return fvrID
		end
	end
	return guideID
end