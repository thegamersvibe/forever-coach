--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local columns = {
    y = 1,
    x = 2,
    continentID = 3,
    flags = 4
}

TaxiNodeLocationsMetatable = {
    __index = function(t, k)
        if (type(k) == "number") then
            return rawget(t, k)
        end
        return rawget(t, columns[k] or 0)
    end
}
