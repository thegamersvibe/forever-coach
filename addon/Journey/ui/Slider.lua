--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local next = 0

function CreateSlider(parent, opts)
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(100, 16 + (opts.topPadding or 0))

    frame.text = frame:CreateFontString(nil, "ARTWORK");
    frame.text:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -opts.topPadding or 0)
    frame.text:SetFontObject(GameFontHighlightSmallLeft)
    frame.text:SetText(opts.text)
    next = next + 1
    local sliderFrameName = addonName .. "Slider" .. next
    local slider = CreateFrame("Slider", sliderFrameName, frame, "UISliderTemplate")
    slider:SetSize(144, 17)
    slider.Text = slider:CreateFontString(nil, "ARTWORK");
    slider.Text:SetPoint("BOTTOM", slider, "TOP")
    slider.Text:SetFontObject(GameFontHighlight)
    slider.Low = slider:CreateFontString(nil, "ARTWORK");
    slider.Low:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", -4, 3)
    slider.Low:SetFontObject(GameFontHighlightSmall)
    slider.High = slider:CreateFontString(nil, "ARTWORK");
    slider.High:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 4, 3)
    slider.High:SetFontObject(GameFontHighlightSmall)
    _G[sliderFrameName] = nil
    function slider:GetPreferredEntryHeight()
        return self:GetHeight();
    end
    slider.Text:ClearAllPoints()
    slider.Text:SetPoint("LEFT", slider, "RIGHT", 8, 0)
    slider:SetScript("OnEnter", slider.OnEnter)
    slider:SetScript("OnLeave", slider.OnLeave)
    slider:SetMinMaxValues(opts.min or 0, opts.max or 100)
    slider:SetValueStep(opts.step or 1)
    slider:SetObeyStepOnDrag(true)
    slider.Low:SetText("-")
    slider.High:SetText("+")
    slider.SetDisplayValue = slider.SetValue;
    slider.GetValue = opts.GetValue
    slider.GetCurrentValue = slider.GetValue
    slider.SetValue = function(self, value)
        opts.SetValue(value)
        local newValue = opts.GetValue()
        self:SetDisplayValue(newValue);
        self.Text:SetText(opts.FormatValue(newValue))
    end
    slider:SetScript("OnValueChanged", function(self, value)
        self:SetValue(value)
    end)
    local value = opts.GetValue()
    slider:SetDisplayValue(value)
    slider.Text:SetText(opts.FormatValue(value))
    slider:SetPoint("LEFT", frame, "LEFT", 120, 0)
    function frame:SetEnabled(enabled)
        if (enabled) then slider:Enable() else slider:Disable() end
        self:SetAlpha(enabled and 1.0 or 0.4)
    end
    return frame
end
