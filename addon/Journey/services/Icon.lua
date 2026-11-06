--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local function ResizeToFit(width, height, boxSize)
    local aspectRatio = width / height
    local newWidth, newHeight
    if aspectRatio > 1 then
        newWidth = boxSize
        newHeight = boxSize / aspectRatio
    else
        newHeight = boxSize
        newWidth = boxSize * aspectRatio
    end
    return newWidth, newHeight
end

IconService = { }

function IconService.GetIconInfo(name)
    name = string.lower(name)
    local iconInfo = Icons[name]
    if (not iconInfo) then
        local atlasInfo = C_Texture.GetAtlasInfo(name)
        if (atlasInfo) then
            iconInfo = {
                atlas = name
            }
        else
            iconInfo = Icons["default"]
        end
        Icons[name] = iconInfo
    end
    return iconInfo
end

function IconService.GetIconText(name, fontSize, scaleOverride, offsetXOverride, offsetYOverride)
    local iconInfo = IconService.GetIconInfo(name)
    local targetSize = ICONSIZE - 2
    local scale = (scaleOverride or iconInfo.scale or 1.0) * (targetSize / fontSize)
    local iconWidth = (iconInfo.width or targetSize) * scale
    local iconHeight = (iconInfo.height or targetSize) * scale
    local offsetX = offsetXOverride or iconInfo.offsetX or 0
    local offsetY = offsetYOverride or iconInfo.offsetY or 0
    local textPattern
    if (iconInfo.texture) then
        textPattern = "|T%s:%s:%s:%s:%s|t"
    else
        textPattern = "|A:%s:%s:%s:%s:%s|a"
    end
    return string.format(textPattern, iconInfo.texture or iconInfo.atlas, iconWidth, iconHeight, offsetX, offsetY)
end

function IconService.SetIconTexture(iconFrame, iconInfo)
    if (iconInfo) then
        local width, height
        local targetSize = (ICONSIZE * (iconInfo.scale or 1)) - 2
        if (iconInfo.atlas) then
            iconFrame.texture:SetAtlas(iconInfo.atlas, false)
            local atlasInfo = C_Texture.GetAtlasInfo(iconInfo.atlas)
            width, height = ResizeToFit(atlasInfo.width, atlasInfo.height, targetSize)
        else
            iconFrame.texture:SetTexture(iconInfo.texture)
            local textureWidth = iconInfo.width or targetSize
            local textureHeight = iconInfo.height or targetSize
            width, height = ResizeToFit(textureWidth, textureHeight, targetSize)
        end
        iconFrame.texture:SetSize(width, height)
        local targetFrameSize = ICONSIZE
        if (iconInfo.resize) then
            targetFrameSize = math.max(ICONSIZE, targetSize + 2)
        end
        iconFrame:SetSize(targetFrameSize + 1, targetFrameSize)
        iconFrame.texture:ClearAllPoints()
        iconFrame.texture:SetPoint("TOPLEFT", (targetFrameSize - width) / 2, -(targetFrameSize - height) / 2)
        iconFrame:Show()
    else
        iconFrame:SetSize(1, ICONSIZE)
        iconFrame:Hide()
    end
end
