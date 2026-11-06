--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

function OnEvent(_, _, unitID, _, spellID)
	if (unitID == "player") then
		local currentStep = GuideNavigationService.GetStep()
		if (currentStep) then
			if (currentStep.spellsCast and currentStep.spellsCast[spellID] == false) then
				currentStep.spellsCast[spellID] = true
				MarkAllDirty()
			end
		end
	end
end

SpellsCastService = { }

function SpellsCastService.AddWatch(spellID)
	local currentStep = GuideNavigationService.GetStep()
	if (currentStep) then
		local bookmark = GuideNavigationService.GetGuide().bookmark
		bookmark.spellsCast = currentStep.spellsCast or bookmark.spellsCast or { }
		currentStep.spellsCast = bookmark.spellsCast
		currentStep.spellsCast[spellID] = currentStep.spellsCast[spellID] or false
	end
end

function SpellsCastService.WasSpellCast(spellID)
	local currentStep = GuideNavigationService.GetStep()
	if (currentStep and currentStep.spellsCast) then
		return currentStep.spellsCast[spellID] or false
	end
	return false
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
frame:SetScript("OnEvent", OnEvent)
