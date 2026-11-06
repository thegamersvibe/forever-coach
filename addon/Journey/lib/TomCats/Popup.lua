--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()
local popupFrame, OnMouseDown

local BACKDROP_GLUE_TOOLTIP_16_16 = {
    bgFile = "Interface\\Glues\\Common\\Glue-Tooltip-Background",
    edgeFile = "Interface\\Glues\\Common\\Glue-Tooltip-Border",
    tile = true,
    tileEdge = true,
    tileSize = 16,
    edgeSize = 16,
    insets = { left = 10, right = 5, top = 4, bottom = 9 },
};

local GLUE_BACKDROP_COLOR = CreateColor(0.09, 0.09, 0.09);

local GLUE_BACKDROP_BORDER_COLOR = CreateColor(0.8, 0.8, 0.8);

local function Init()
    popupFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    PopupFrame = popupFrame
    popupFrame:SetSize(400, 116)
    popupFrame.backdropInfo = BACKDROP_GLUE_TOOLTIP_16_16
    popupFrame.backdropColor = GLUE_BACKDROP_COLOR
    popupFrame.backdropBorderColor = GLUE_BACKDROP_BORDER_COLOR
    popupFrame:SetPoint("CENTER")
    popupFrame:SetFrameStrata("TOOLTIP")
    popupFrame.header = popupFrame:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
    popupFrame.header:SetPoint("TOP", 0, -16)
    popupFrame.header:SetWidth(380)
    popupFrame.header:SetJustifyH("CENTER")
    popupFrame.header:Hide()
    popupFrame.info = popupFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    popupFrame.info:SetPoint("CENTER")
    popupFrame.editBox = CreateFrame("EditBox", nil, popupFrame, "InputBoxTemplate")
    popupFrame.editBox:SetSize(280, 32)
    popupFrame.editBox:SetPoint("TOP", 2.5, -16)
    popupFrame.editBox:SetScript("OnChar", function(self)
        self:SetText(self.text)
        self:HighlightText()
    end)
    popupFrame.editBox:SetScript("OnMouseUp", function(self)
        self:HighlightText()
    end)
    popupFrame.editBox:SetScript("OnEscapePressed", function()
        popupFrame:Hide()
    end)
    popupFrame.button = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.button:SetSize(96, 22)
    popupFrame.button:SetPoint("BOTTOM", 0, 16)
    popupFrame.button:SetText(CLOSE)
    popupFrame.button:SetScript("OnClick", function()
        popupFrame:Hide()
    end)
    popupFrame.reloadButton = CreateFrame("Button", nil, popupFrame, "UIPanelButtonTemplate")
    popupFrame.reloadButton:SetSize(96, 22)
    popupFrame.reloadButton:SetPoint("BOTTOM", 0, 16)
    popupFrame.reloadButton:SetText("Reload")
    popupFrame.reloadButton:SetScript("OnClick", function()
        ReloadUI()
    end)
    popupFrame.reloadButton:Hide()
    popupFrame:OnBackdropLoaded()
    popupFrame:Hide()
    popupFrame:RegisterEvent("GLOBAL_MOUSE_DOWN")
    popupFrame:SetScript("OnEvent", OnMouseDown)
end

function OnMouseDown(self)
    if (self:IsShown() and not self:IsMouseOver()) then
        if (self.target) then
            if (self.bounds) then
                local regionWidth, regionHeight = self.target:GetSize()
                if (self.target:IsMouseOver(
                        self.bounds[2],
                        regionHeight + self.bounds[2] - self.bounds[4],
                        self.bounds[1],
                        - (regionWidth - self.bounds[3] - self.bounds[1])
                )) then
                    return
                end
            else
                if (self.target:IsMouseOver()) then
                    return
                end
            end
        end
        HidePopup()
    end
end

function TogglePopup(text, caption, point, target, bounds, headerText, useReload, buttonText)
    Init = Init() or nop
    local toggleID = text or headerText
    if (toggleID == popupFrame._toggleID and popupFrame:IsShown()) then
        HidePopup()
        return
    end
    popupFrame._toggleID = toggleID
    if (useReload) then
        popupFrame.button:Hide()
        popupFrame.reloadButton:Show()
    else
        popupFrame.reloadButton:Hide()
        popupFrame.button:SetText(buttonText or CLOSE)
        popupFrame.button:Show()
    end
    popupFrame.info:ClearAllPoints()
    popupFrame.editBox:ClearAllPoints()
    if (text and text ~= "") then
        popupFrame.editBox.text = text
        popupFrame.editBox:SetText(text)
        popupFrame.editBox:Show()
        popupFrame.info:SetText(caption or "")
        popupFrame.info:Show()
    else
        popupFrame.editBox.text = nil
        popupFrame.editBox:Hide()
        popupFrame.info:Hide()
    end
    if (headerText) then
        popupFrame.header:SetText(headerText)
        popupFrame.header:Show()
        local headerHeight = popupFrame.header:GetStringHeight() or 14
        if (text and text ~= "") then
            popupFrame.editBox:SetPoint("TOP", 2.5, -(headerHeight + 24))
            popupFrame.info:SetPoint("TOP", popupFrame.editBox, "BOTTOM", 0, -4)
            popupFrame:SetHeight(headerHeight + 130)
        else
            popupFrame:SetHeight(headerHeight + 80)
        end
    else
        popupFrame.header:Hide()
        popupFrame.editBox:SetPoint("TOP", 2.5, -16)
        popupFrame.info:SetPoint("CENTER")
        popupFrame:SetSize(400, 116)
    end
    popupFrame:ClearAllPoints()
    if (point) then
        popupFrame:SetPoint(unpack(point))
    else
        popupFrame:SetPoint("CENTER")
    end
    if (popupFrame.editBox:IsShown()) then
        popupFrame.editBox:HighlightText()
    end
    popupFrame.target = target
    popupFrame.bounds = bounds
    popupFrame:Show()
end

function HidePopup()
    Init = Init() or nop
    popupFrame._toggleID = nil
    popupFrame.editBox.text = nil
    popupFrame:Hide()
end
