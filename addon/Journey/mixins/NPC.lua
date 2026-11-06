--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local columns = {
    race = 1,
    gender = 2,
    reactA = 3,
    reactH = 4,
    type = 5,
    levelMin = -1,
    levelMax = -2,
    classification = -3,
    suppressModel = -4,
}

NPCMetatable = {
    __index = function(t, k)
        if (type(k) ~= "number") then
            k = columns[k]
        end
        if (k > 0) then
            return rawget(t, k)
        elseif (k < 0) then
            return rawget(t.ext, math.abs(k))
        end
    end
}

local lastGameversion

function NPCMetatable.Refresh()
    local gameversion = GetCondition("GAMEVERSION")
    if (gameversion == lastGameversion) then return end
    lastGameversion = gameversion
    local extTable
    if (gameversion >= 10000 and gameversion < 20000) then
        extTable = NPCs_Ext_Era
    elseif (gameversion >= 20000 and gameversion < 30000) then
        extTable = NPCs_Ext_TBC
    else
        extTable = NPCs_Ext_WOTLK
    end
    for k, v in pairs(NPCs) do
        v.ext = NPCs_Ext[k] or extTable[k] or { }
    end
end
