--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local overlayTable

local columns = {
    x = 1,
    y = 2,
    z = 3,
    facing = 4,
    pitch = 5,
    roll = 6,
    camDistanceScale = 7,
}

ModelAdjustmentMetatable = {
    __index = function(t, k)
        if (type(k) == "number") then
            return rawget(t, k)
        end
        return rawget(t, columns[k] or 0)
    end
}

ModelAdjustmentsMetatable = {
    __index = function(t, k)
        return overlayTable[k]
    end,
}

ModelAdjustments_GetKeys = function()
    local keys = { }
    for k in pairs(ModelAdjustments) do
        table.insert(keys, k)
    end
    for k in pairs(overlayTable) do
        table.insert(keys, k)
    end
    table.sort(keys)
    return keys
end

local lastGameversion

function ModelAdjustmentsMetatable.Refresh()
    local gameversion = GetCondition("GAMEVERSION")
    if (gameversion == lastGameversion) then  return end
    lastGameversion = gameversion
    if (gameversion >= 10000 and gameversion < 20000) then
        overlayTable = ModelAdjustments_Era
    elseif (gameversion >= 20000 and gameversion < 30000) then
        overlayTable = ModelAdjustments_TBC
    else
        overlayTable = ModelAdjustments_WOTLK
    end
end
