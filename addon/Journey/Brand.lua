--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

Brand = {
	website = C_AddOns.GetAddOnMetadata(addonName, "X-Website") or "",
	shortTitle = C_AddOns.GetAddOnMetadata(addonName, "X-ShortTitle") or "",
}
