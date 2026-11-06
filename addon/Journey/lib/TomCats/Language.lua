--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

L = { }

setmetatable(L, {
	__index = function(self, key)
		local value = rawget(self, key)
		if (value) then return value end
		return key
	end
})
