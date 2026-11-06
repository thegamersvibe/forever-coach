--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local INSIDE_TEX = "Interface\\WorldMap\\UI-QuestBlob-Inside"
local OUTSIDE_TEX = "Interface\\WorldMap\\UI-QuestBlob-Outside"

local FILL_ALPHA = 0.50
local BORDER_ALPHA = 0.75
local GLOW_DEPTH = 50

local sqrt = math.sqrt

local blobOverlayEnabled = nil -- nil = follow dev mode, true/false = explicit override
local blobOverlayIndex = nil

local function IsBlobOverlayEnabled()
    if (blobOverlayEnabled ~= nil) then return blobOverlayEnabled end
    return State.IsDevEnabled()
end

function ToggleBlobOverlay()
    local currentlyOn = IsBlobOverlayEnabled()
    blobOverlayEnabled = not currentlyOn
    if (not blobOverlayEnabled) then
        blobOverlayIndex = nil
    end
    MarkAllDirty()
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: Blob overlay %s", addonTitle, blobOverlayEnabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
end

function CycleBlobOverlay()
    if (not blobOverlayEnabled) then
        blobOverlayEnabled = true
    end
    local locations = LocationsService.GetLocations()
    if (not locations) then return end
    local blobIndices = {}
    for idx, location in ipairs(locations) do
        if (location.polygon) then
            blobIndices[#blobIndices + 1] = idx
        end
    end
    if (#blobIndices == 0) then
        DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: No blob locations on this step", addonTitle))
        return
    end
    if (blobOverlayIndex == nil) then
        blobOverlayIndex = 1
    else
        blobOverlayIndex = blobOverlayIndex + 1
        if (blobOverlayIndex > #blobIndices) then
            blobOverlayIndex = 1
        end
    end
    local locIdx = blobIndices[blobOverlayIndex]
    DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: Blob %d/%d (location %d)", addonTitle, blobOverlayIndex, #blobIndices, locIdx))
    MarkAllDirty()
end

local maps = {
    {
        mapFrame = WorldMapFrame,
    },
    {
        mapFrame = BattlefieldMapFrame,
    }
}

for _, v in ipairs(maps) do
    local component = UI.CreateComponent(v.mapFrame:GetName() .. "MapBlobOverlay")

    local mapFrame = v.mapFrame
    local mapContainer = v.mapFrame.ScrollContainer.Child
    local overlay
    local fillPool
    local borderPool

    local function TextureResetter(_, tex)
        tex:Hide()
        tex:ClearAllPoints()
        tex:SetTexture(nil)
        tex:SetVertexOffset(1, 0, 0)
        tex:SetVertexOffset(2, 0, 0)
        tex:SetVertexOffset(3, 0, 0)
        tex:SetVertexOffset(4, 0, 0)
    end

    local function Nudge(px, py, tx, ty, d)
        local dx, dy = tx - px, ty - py
        local len = sqrt(dx * dx + dy * dy)
        if (len < 0.001) then return px, py end
        return px + dx / len * d, py + dy / len * d
    end

    local function SetupWedge(tex, parent, apexX, apexY, v1x, v1y, v2x, v2y)
        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", apexX, -apexY)
        tex:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", apexX, -apexY)
        tex:SetVertexOffset(1, 0, 0)
        tex:SetVertexOffset(3, 0, 0)
        tex:SetVertexOffset(2, v1x - apexX, -(v1y - apexY))
        tex:SetVertexOffset(4, v2x - apexX, -(v2y - apexY))
    end

    local function SetupBorderStrip(tex, parent, cx, cy, v1x, v1y, v2x, v2y, depth)
        local in1x, in1y = Nudge(v1x, v1y, cx, cy, 2)
        local in2x, in2y = Nudge(v2x, v2y, cx, cy, 2)
        local out1x, out1y = Nudge(v1x, v1y, cx, cy, -depth)
        local out2x, out2y = Nudge(v2x, v2y, cx, cy, -depth)

        tex:SetPoint("TOPLEFT", parent, "TOPLEFT", cx, -cy)
        tex:SetPoint("BOTTOMRIGHT", parent, "TOPLEFT", cx, -cy)
        tex:SetVertexOffset(1, in1x - cx, -(in1y - cy))
        tex:SetVertexOffset(3, in2x - cx, -(in2y - cy))
        tex:SetVertexOffset(2, out1x - cx, -(out1y - cy))
        tex:SetVertexOffset(4, out2x - cx, -(out2y - cy))
    end

    local function DrawBlob(polygon)
        local fw = overlay:GetWidth()
        local fh = overlay:GetHeight()

        local pts = {}
        for i, vertex in ipairs(polygon) do
            -- vertex[3] = mapX%, vertex[4] = mapY%
            pts[i] = { vertex[3] / 100 * fw, vertex[4] / 100 * fh }
        end

        local cx, cy = 0, 0
        for _, p in ipairs(pts) do
            cx = cx + p[1]
            cy = cy + p[2]
        end
        cx = cx / #pts
        cy = cy / #pts

        -- Scale glow depth relative to canvas size
        local glowDepth = fh * 0.02

        for i = 1, #pts do
            local j = (i % #pts) + 1
            local v1x, v1y = pts[i][1], pts[i][2]
            local v2x, v2y = pts[j][1], pts[j][2]

            local fill = fillPool:Acquire()
            fill:SetTexture(INSIDE_TEX)
            fill:SetAlpha(FILL_ALPHA)
            SetupWedge(fill, overlay, cx, cy, v1x, v1y, v2x, v2y)
            fill:Show()

            local border = borderPool:Acquire()
            border:SetTexture(OUTSIDE_TEX)
            border:SetAlpha(BORDER_ALPHA)
            SetupBorderStrip(border, overlay, cx, cy, v1x, v1y, v2x, v2y, glowDepth)
            border:Show()
        end
    end

    local function OnMapIDChanged()
        component:MarkDirty()
    end

    function component.Init()
        overlay = CreateFrame("Frame", nil, mapContainer)
        overlay:SetAllPoints(mapContainer)
        overlay:SetFrameStrata("DIALOG")
        fillPool = CreateTexturePool(overlay, "ARTWORK", 0, nil, TextureResetter)
        borderPool = CreateTexturePool(overlay, "OVERLAY", 0, nil, TextureResetter)
        hooksecurefunc(mapFrame, "SetMapID", OnMapIDChanged)
        local sc = mapFrame.ScrollContainer
        if (sc) then
            hooksecurefunc(sc, "CreateZoomLevels", function(self)
                if (State.IsDevEnabled() and self.zoomLevels and #self.zoomLevels > 0) then
                    local maxLevel = self.zoomLevels[#self.zoomLevels]
                    table.insert(self.zoomLevels, { scale = maxLevel.scale * 2, layerIndex = maxLevel.layerIndex })
                    table.insert(self.zoomLevels, { scale = maxLevel.scale * 4, layerIndex = maxLevel.layerIndex })
                end
            end)
        end
    end

    function component.Update()
        if (component:IsDirty()) then
            fillPool:ReleaseAll()
            borderPool:ReleaseAll()

            if (IsBlobOverlayEnabled()) then
                local locations = LocationsService.GetLocations()
                if (locations) then
                    if (blobOverlayIndex) then
                        local blobIndices = {}
                        for idx, location in ipairs(locations) do
                            if (location.polygon) then
                                blobIndices[#blobIndices + 1] = idx
                            end
                        end
                        if (blobOverlayIndex <= #blobIndices) then
                            local location = locations[blobIndices[blobOverlayIndex]]
                            local x, y = location:GetXY(mapFrame:GetMapID())
                            if (x) then
                                DrawBlob(location.polygon)
                            end
                        end
                    else
                        local location = LocationsService.GetActiveLocation()
                        if (location and location.polygon) then
                            local x, y = location:GetXY(mapFrame:GetMapID())
                            if (x) then
                                DrawBlob(location.polygon)
                            end
                        end
                    end
                end
            end

            component:MarkClean()
        end
    end

    UI.Add(component)
end
