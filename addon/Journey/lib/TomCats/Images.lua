--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local imagesPattern = "Interface\\AddOns\\%s\\images\\%s%s"

I = { }

setmetatable(I, {
	__index = function(_, key)
		local ext = ".blp"
		if key:match("%.[^%.]+$") then
			ext = ""
		end
		return imagesPattern:format(addonName, key, ext)
	end,
})
