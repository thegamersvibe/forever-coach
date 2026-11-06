--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("MinimapButton")

function component.Init(components)
	local frame = CreateMinimapButton({
		name = addonName .. "-MinimapButton",
		iconTexture = I[Brand.minimapIcon],
		backgroundColor = { 0.0,0.0,0.0,1.0 },
		handler_onclick = function()
			State.SetGuideShown(true)
		end
	})
	frame.Icon:SetTexCoord(0, 1, 0, 1)
	frame.tooltip = {
		Show = function(this)
			GameTooltip:ClearLines()
			GameTooltip:SetOwner(this, "ANCHOR_NONE")
			GameTooltip:SetPoint("TOPRIGHT", this, "BOTTOMRIGHT", 0, 0)
			GameTooltip:SetText(Brand.shortTitle, 1, 1, 1)
			GameTooltip:Show()
		end,
		Hide = function()
			GameTooltip:Hide()
		end
	}
	component.frame = frame
end

function component.Update()
	if (component:IsDirty()) then
		component.frame:SetShown(component.frame:IsEnabled() and not State.IsGuideShown())
		component:MarkClean()
	end
end

function UI.SetMinimapButtonEnabled(enabled)
	component.frame:SetEnabled(enabled)
	UI.MarkDirty()
end

UI.Add(component)
