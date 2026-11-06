--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

IllustrationService = { }

local columnLUT = {
    ["filename"] = 1,
    ["width"] = 2,
    ["height"] = 3,
    ["left"] = 4,
    ["right"] = 5,
    ["top"] = 6,
    ["bottom"] = 7
}

local illustrationLUT = { }

local IllustrationMetatable = {
    __index = function(t, k, v)
        local column = columnLUT[k]
        if (type(column) == "number") then
            return rawget(t, column)
        end
    end
}

local function GetTexBound(val)
    local square = 2
    while(true) do
        if (val > square) then
            square = square * 2
        else
            break
        end
    end
    return val / square
end

for _, illustration in ipairs(Illustrations) do
    setmetatable(illustration, IllustrationMetatable)
    illustrationLUT[illustration.filename] = illustration
    illustration[columnLUT["left"]] = 0
    illustration[columnLUT["right"]] = GetTexBound(illustration.width)
    illustration[columnLUT["top"]] = 0
    illustration[columnLUT["bottom"]] = GetTexBound(illustration.height)
end

function IllustrationService.GetIllustration(name)
    return illustrationLUT[name]
end
