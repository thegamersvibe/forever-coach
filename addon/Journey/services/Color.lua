--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

ColorService = { }

local cache = { }

local function HexToColor(hex)
    -- Extract individual red, green, and blue components
    local redHex = hex:sub(3, 4)
    local greenHex = hex:sub(5, 6)
    local blueHex = hex:sub(7, 8)

    -- Convert hexadecimal to decimal values
    local red = tonumber(redHex, 16)
    local green = tonumber(greenHex, 16)
    local blue = tonumber(blueHex, 16)

    -- Normalize the decimal values to the range of 0 to 1
    local rNormalized = red / 255
    local gNormalized = green / 255
    local bNormalized = blue / 255

    -- Create a Color object using the normalized values
    local color = CreateColor(rNormalized, gNormalized, bNormalized)

    return color
end

function ColorService.GetColor(colorName)
    local color = cache[colorName]
    if (not color) then
        color = HexToColor(Color[colorName])
        cache[colorName] = color
    end
    return color
end
