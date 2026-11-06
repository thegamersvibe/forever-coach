--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()


local minimap_size = {
    indoor = {
        [0] = 300, -- scale
        [1] = 240, -- 1.25
        [2] = 180, -- 5/3
        [3] = 120, -- 2.5
        [4] = 80,  -- 3.75
        [5] = 50,  -- 6
    },
    outdoor = {
        [0] = 466 + 2/3, -- scale
        [1] = 400,       -- 7/6
        [2] = 333 + 1/3, -- 1.4
        [3] = 266 + 2/6, -- 1.75
        [4] = 200,       -- 7/3
        [5] = 133 + 1/3, -- 3.5
    },
}

local GetViewRadius = C_Minimap and C_Minimap.GetViewRadius or function()
    local zoom = Minimap:GetZoom()
    local indoors = GetCVar("minimapZoom")+0 == zoom and "outdoor" or "indoor"
    return minimap_size[indoors][zoom] / 2
end

local CreateFrame = CreateFrame
local GetCVar = GetCVar
local GetPlayerFacing = GetPlayerFacing
local Minimap = Minimap
local Mixin = Mixin

local arrows = { }
local active = false

local screenArrow
local currentArrowScale, currentArrowTextScale
local arrowLabelFont

local function StripColorCodes(text)
    if (not text) then return text end
    return text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
end

local SPRITE_COLS = 9
local SPRITE_ROWS = 12
local SPRITE_FRAMES = 108
local TILE_W = 1 / SPRITE_COLS
local TILE_H = 1 / SPRITE_ROWS

local function SetArrowDirection(texture, rads)
    local normalized = (rads % (2 * math.pi)) / (2 * math.pi)
    local frame = math.floor(normalized * SPRITE_FRAMES + 0.5) % SPRITE_FRAMES
    local col = frame % SPRITE_COLS
    local row = math.floor(frame / SPRITE_COLS)
    texture:SetTexCoord(
        col * TILE_W, (col + 1) * TILE_W,
        row * TILE_H, (row + 1) * TILE_H
    )
    local behind = math.abs(((rads + math.pi) % (2 * math.pi)) - math.pi) / math.pi
    local r = behind
    local g = 1 - behind
    texture:SetVertexColor(r, g, 0, 1)
end

local function CreateScreenArrow()
    arrowLabelFont = CreateFont(addonName .. "ArrowLabelFont")
    arrowLabelFont:CopyFontObject(GameFontWhiteSmall)
    arrowLabelFont:SetShadowOffset(0, 0)
    -- Container: handles positioning and dragging, never scaled
    local container = CreateFrame("Frame", nil, UIParent)
    container:SetSize(1, 1)
    local arrowLocation = SavedVariables.HUDArrowLocation
    if (arrowLocation) then
        arrowLocation[2] = nil
        container:SetPoint(unpack(arrowLocation))
    else
        container:SetPoint("CENTER", UIParent, "CENTER", 300, 0)
    end
    container:SetFrameStrata("HIGH")
    container:SetFrameLevel(10)
    container:SetMovable(true)
    container:SetClampedToScreen(true)
    -- Arrow: handles visuals and scale, anchored to container center
    local f = CreateFrame("Frame", addonName .. "ScreenArrow", container)
    f:SetSize(128, 128)
    f:SetPoint("CENTER", container, "CENTER")
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", function() container:StartMoving() end)
    f:SetScript("OnDragStop", function()
        container:StopMovingOrSizing()
        SavedVariables.HUDArrowLocation = { container:GetPoint() }
    end)
    f.container = container
    local arrow = f:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture(I["arrow-atlas.png"])
    arrow:SetAllPoints(f)
    f.arrowTexture = arrow
    local spinFrame = CreateFrame("Frame", nil, f)
    spinFrame:SetAllPoints(f)
    spinFrame:Hide()
    spinFrame.texture = spinFrame:CreateTexture(nil, "OVERLAY")
    spinFrame.texture:SetTexture(I["arrow-spin-atlas.png"])
    spinFrame.texture:SetAllPoints(spinFrame)
    spinFrame.texture:SetVertexColor(0, 1, 0, 1)
    spinFrame.spinIndex = 0
    spinFrame.spinSpeed = 1.5
    spinFrame.elapsed = 0
    spinFrame:SetScript("OnUpdate", function(self, elapsed)
        self.elapsed = self.elapsed + elapsed
        local progress = (self.elapsed / self.spinSpeed) % 1
        local frame = math.floor(progress * SPRITE_FRAMES) % SPRITE_FRAMES
        local col = frame % SPRITE_COLS
        local row = math.floor(frame / SPRITE_COLS)
        self.texture:SetTexCoord(
            col * TILE_W, (col + 1) * TILE_W,
            row * TILE_H, (row + 1) * TILE_H
        )
    end)
    f.pingFrame = spinFrame
    local shadowContainer = CreateFrame("Frame", nil, f)
    shadowContainer:SetAllPoints(f)
    shadowContainer:SetAlpha(0.6)
    local d = 2
    local shadowOffsets = {
        {0, d}, {d, d}, {d, 0}, {d, -d},
        {0, -d}, {-d, -d}, {-d, 0}, {-d, d}
    }
    shadowContainer.labels = {}
    for i, offset in ipairs(shadowOffsets) do
        local shadow = shadowContainer:CreateFontString(nil, "ARTWORK", addonName .. "ArrowLabelFont")
        shadow:SetPoint("TOP", f, "BOTTOM", offset[1], 8 + offset[2])
        shadow:SetTextColor(0, 0, 0, 1)
        shadowContainer.labels[i] = shadow
    end
    f.shadowContainer = shadowContainer
    local labelContainer = CreateFrame("Frame", nil, f)
    labelContainer:SetAllPoints(f)
    labelContainer:SetFrameLevel(shadowContainer:GetFrameLevel() + 1)
    local label = labelContainer:CreateFontString(nil, "OVERLAY", addonName .. "ArrowLabelFont")
    label:SetPoint("TOP", f, "BOTTOM", 0, 8)
    label:SetTextColor(1, 1, 1, 1)
    f.label = label
    -- Distance label with same shadow/outline technique
    local distShadowContainer = CreateFrame("Frame", nil, f)
    distShadowContainer:SetAllPoints(f)
    distShadowContainer:SetAlpha(0.6)
    distShadowContainer.labels = {}
    for i, offset in ipairs(shadowOffsets) do
        local shadow = distShadowContainer:CreateFontString(nil, "ARTWORK", addonName .. "ArrowLabelFont")
        shadow:SetPoint("TOP", label, "BOTTOM", offset[1], offset[2])
        shadow:SetTextColor(0, 0, 0, 1)
        distShadowContainer.labels[i] = shadow
    end
    f.distShadowContainer = distShadowContainer
    local distLabelContainer = CreateFrame("Frame", nil, f)
    distLabelContainer:SetAllPoints(f)
    distLabelContainer:SetFrameLevel(distShadowContainer:GetFrameLevel() + 1)
    local distLabel = distLabelContainer:CreateFontString(nil, "OVERLAY", addonName .. "ArrowLabelFont")
    distLabel:SetPoint("TOP", label, "BOTTOM", 0, 0)
    distLabel:SetTextColor(1, 0.82, 0, 1)
    f.distLabel = distLabel
    currentArrowScale = nil
    currentArrowTextScale = nil
    container:Hide()
    return f
end

local function UpdateScreenArrow(rads, distance, label)
    if (not State.IsScreenArrowEnabled() or (TomTom and State.IsTomTomSupportEnabled())) then
        if (screenArrow and screenArrow.container:IsShown()) then
            screenArrow.pingFrame:Hide()
            screenArrow.container:Hide()
        end
        return
    end
    if (not screenArrow) then
        screenArrow = CreateScreenArrow()
    end
    local arrowScale = State.GetArrowScale()
    local arrowTextScale = State.GetArrowTextScale()
    if (arrowScale ~= currentArrowScale or arrowTextScale ~= currentArrowTextScale) then
        if (arrowScale ~= currentArrowScale) then
            screenArrow:SetScale(0.6 * arrowScale)
        end
        currentArrowScale = arrowScale
        currentArrowTextScale = arrowTextScale
        local fontFile, fontSize = GameFontWhiteSmall:GetFont()
        arrowLabelFont:SetFont(fontFile, fontSize * 1.8 * arrowTextScale, "")
    end
    if (rads) then
        if (distance and distance <= 1.5) then
            if (screenArrow.arrowTexture:IsShown()) then screenArrow.arrowTexture:Hide() end
            if (not screenArrow.pingFrame:IsShown()) then
                screenArrow.pingFrame.elapsed = 0
                screenArrow.pingFrame:Show()
            end
        else
            if (screenArrow.pingFrame:IsShown()) then
                screenArrow.pingFrame:Hide()
            end
            if (not screenArrow.arrowTexture:IsShown()) then screenArrow.arrowTexture:Show() end
            SetArrowDirection(screenArrow.arrowTexture, rads)
        end
        local shadowText = StripColorCodes(label or "")
        if (shadowText ~= screenArrow.lastLabelText) then
            screenArrow.lastLabelText = shadowText
            for _, shadow in ipairs(screenArrow.shadowContainer.labels) do
                shadow:SetText(shadowText)
            end
            screenArrow.label:SetText(label or "")
        end
        if (distance) then
            local distText = math.floor(distance + 0.5) .. " yards"
            if (distText ~= screenArrow.lastDistText) then
                screenArrow.lastDistText = distText
                for _, shadow in ipairs(screenArrow.distShadowContainer.labels) do
                    shadow:SetText(distText)
                end
                screenArrow.distLabel:SetText(distText)
            end
        end
        if (not screenArrow.container:IsShown()) then screenArrow.container:Show() end
    else
        if (screenArrow.pingFrame:IsShown()) then
            screenArrow.pingFrame:Hide()
        end
        if (screenArrow.container:IsShown()) then
            for _, shadow in ipairs(screenArrow.distShadowContainer.labels) do
                shadow:SetText("")
            end
            screenArrow.distLabel:SetText("")
            screenArrow.container:Hide()
        end
    end
end

local function OnUpdate()
    if (active) then
        local playerFacing = GetPlayerFacing()
        local unitPositionX, unitPositionY = UnitPosition("player")
        local hasPosition = playerFacing and unitPositionX and unitPositionY
        for arrow, arrowActive in pairs(arrows) do
            if (hasPosition and arrowActive) then
                local rawRads = math.atan2((arrow.worldTargetY - unitPositionY), arrow.worldTargetX - unitPositionX)
                local distance = addon.GetDistanceInYards(
                        arrow.worldTargetX,
                        arrow.worldTargetY,
                        unitPositionX,
                        unitPositionY)
                UpdateScreenArrow(rawRads - playerFacing, distance, arrow.screenLabel)
                local r = GetViewRadius()
                if (distance > r * 0.75) then
                    if (not arrow:IsShown()) then arrow:Show() end
                    if (arrow.ping:IsShown()) then
                        arrow.ping.animation:Stop()
                        arrow.ping:Hide()
                    end
                    local adj = 0
                    if (GetCVar("rotateMinimap") == "1") then
                        adj = adj - playerFacing
                    end
                    local rads = rawRads + adj
                    local rotation = rads + (math.pi * 0.50)
                    arrow.overlay:SetRotation(rads)
                    arrow.background:SetRotation(rads)
                    arrow:ClearAllPoints()
                    local arrowRadius = (Minimap:GetWidth() /  2) - 17
                    arrow:SetPoint("CENTER", Minimap, "CENTER", arrowRadius * math.cos(rotation), arrowRadius * math.sin(rotation))
                else
                    if (not arrow.ping:IsShown()) then
                        arrow.ping:Show()
                        if (arrow.enablePingAnimation) then
                            arrow.ping.animation:Play()
                        end
                    end
                    local xDist = unitPositionY - arrow.worldTargetY
                    local yDist = unitPositionX - arrow.worldTargetX
                    if (GetCVar("rotateMinimap") == "1") then
                        local s = math.sin(playerFacing)
                        local c = math.cos(playerFacing)
                        local newXDist = xDist*c - yDist*s
                        local newYDist = xDist*s + yDist*c
                        xDist = newXDist
                        yDist = newYDist
                    end
                    local w = Minimap:GetWidth() / 2
                    local h = Minimap:GetHeight() / 2
                    arrow.ping:SetPoint(
                            "CENTER",
                            Minimap,
                            "CENTER",
                            ((xDist) / r) * h,
                            -((yDist) / r) * w
                    )
                    if (arrow:IsShown()) then arrow:Hide() end
                end
            else
                if (arrow.ping:IsShown()) then
                    arrow.ping.animation:Stop()
                    arrow.ping:Hide()
                end
                if (arrow:IsShown()) then arrow:Hide() end
                UpdateScreenArrow(nil)
            end
        end
    end
end

local function OnEnter(arrow, target)
    if (arrow.tooltip) then
        arrow.tooltip.Show(target or arrow)
    end
end

local function OnLeave(arrow)
    if (arrow.tooltip) then
        arrow.tooltip.Hide()
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", OnUpdate)

local ArrowMixin = { }

function ArrowMixin:SetTarget(targetX, targetY, mapID, disablePingAnimation)
    assert(type(targetX) == "number")
    assert(type(targetY) == "number")
    assert(type(mapID) == "number")
    local _, coordinate = C_Map.GetWorldPosFromMapPos(mapID, { x = targetX, y = targetY })
    if (not coordinate) then return end
    self.targetX = targetX
    self.targetY = targetY
    self.mapID = mapID
    self.worldTargetX = coordinate.x
    self.worldTargetY = coordinate.y
    self.enablePingAnimation = not disablePingAnimation
    arrows[self] = true
    active = true
    self:Show()
    if (disablePingAnimation) then
        self.ping.animation:Stop()
    else
        self.ping.animation:Play()
    end
end

function ArrowMixin:ClearTarget()
    self.targetX = nil
    self.targetY = nil
    self.mapID = nil
    arrows[self] = false
    active = false
    for _, v in pairs(arrows) do
        if (v) then
            active = true
        end
    end
    self:Hide()
    if (self.ping:IsShown()) then
        self.ping.animation:Stop()
        self.ping:Hide()
    end
    UpdateScreenArrow(nil)
end

function addon.CreateArrow(r, g, b)
    local arrow = CreateFrame("Frame", nil, Minimap)
    Mixin(arrow, ArrowMixin)
    arrows[arrow] = false
    arrow:SetScript("OnEnter", function() OnEnter(arrow) end)
    arrow:SetScript("OnLeave", OnLeave)
    arrow:Hide()
    arrow:SetSize(34,34)
    arrow:SetPoint("CENTER", Minimap, "CENTER",0,0)
    arrow:SetFrameStrata("LOW")
    arrow:SetFrameLevel(3)
    local overlay = arrow:CreateTexture(nil, "OVERLAY")
    overlay:SetAllPoints(arrow)
    overlay:SetColorTexture(r, g, b, 1)
    local mask = arrow:CreateMaskTexture()
    mask:SetTexture(I["Arrow-Mask"])
    mask:SetSize(34, 34)
    mask:SetAllPoints(arrow)
    overlay:AddMaskTexture(mask)
    local background = arrow:CreateTexture(nil, "BACKGROUND")
    background:SetTexture(I["Arrow-Shadow"])
    background:SetSize(34, 34)
    background:SetAllPoints(arrow)
    arrow.overlay = mask
    arrow.background = background
    local ping = CreateFrame("Frame", nil, Minimap)
    ping:Hide()
    arrow.ping = ping
    ping:SetScript("OnEnter", function() OnEnter(arrow, ping) end)
    ping:SetScript("OnLeave", OnLeave)
    ping:SetSize(32, 32)
    ping:SetPoint("CENTER", Minimap, "CENTER", 0, 0)
    ping:SetFrameStrata("LOW")
    ping:SetFrameLevel(3)
    ping.centerRing = ping:CreateTexture(nil, "OVERLAY")
    ping.centerRing:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Center")
    ping.centerRing:SetSize(16, 16)
    ping.centerRing:SetPoint("CENTER")
    ping.rotatingRing = ping:CreateTexture(nil, "OVERLAY")
    ping.rotatingRing:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Rotate")
    ping.rotatingRing:SetSize(24, 24)
    ping.rotatingRing:SetPoint("CENTER")
    ping.expandingRing = ping:CreateTexture(nil, "OVERLAY")
    ping.expandingRing:SetTexture("Interface\\minimap\\UI-Minimap-Ping-Expand")
    ping.expandingRing:SetSize(16, 16)
    ping.expandingRing:SetPoint("CENTER")
    ping.animation = ping:CreateAnimationGroup()
    ping.animation:SetLooping("REPEAT")
    local rotationAnim = ping.animation:CreateAnimation("Rotation")
    rotationAnim:SetTarget(ping.rotatingRing)
    rotationAnim:SetDegrees(-180)
    rotationAnim:SetDuration(0.8)
    rotationAnim:SetOrder(1)
    local scaleAnim = ping.animation:CreateAnimation("Scale")
    scaleAnim:SetTarget(ping.expandingRing)
    if (scaleAnim.SetFromScale) then
        scaleAnim:SetFromScale(0.1, 0.1)
        scaleAnim:SetToScale(1.5, 1.5)
    else
        scaleAnim:SetScaleFrom(0.1, 0.1)
        scaleAnim:SetScaleTo(1.5, 1.5)
    end
    scaleAnim:SetDuration(0.8)
    scaleAnim:SetOrder(1)
    return arrow
end
