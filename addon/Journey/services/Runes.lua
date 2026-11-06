--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local searchActive = false
local OnClick, OnEnter
local lastOnEnter

function OnClick(self)
	if (self.skillLineAbilityID and SkillLineAbilitySpellLUT[self.skillLineAbilityID]) then
		local spoilerLevel = State.GetRuneSpoilerLevel(self.skillLineAbilityID)
		if (spoilerLevel < 2 and IsShiftKeyDown()) then
			State.SetRuneSpoilerLevel(self.skillLineAbilityID, spoilerLevel + 1)
			EngravingFrame_UpdateRuneList(EngravingFrame)
			MarkAllDirty()
			OnEnter(self)
		else
			RunesService.OpenRuneGuide(SkillLineAbilityGuideLUT[self.skillLineAbilityID])
		end
	end
end

function OnEnter(self)
	lastOnEnter = self
	if (self.skillLineAbilityID and SkillLineAbilitySpellLUT[self.skillLineAbilityID]) then
		self.showingTooltip = true
		local spoilerLevel = State.GetRuneSpoilerLevel(self.skillLineAbilityID)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT");
		local hasGuide = SkillLineAbilityGuideLUT[self.skillLineAbilityID]
		if (spoilerLevel == 0) then
			GameTooltip:SetText("Mysterious Rune")
			GameTooltip:AddLine("You have not collected this rune", 1, 0, 0, true)
			if (hasGuide) then
				GameTooltip:AddLine("<Click to view the guide>", 0, 1, 0, true)
			else
				GameTooltip:AddLine("(Guide not yet available)", 0.5, 0.5, 0.5, true)
			end
			GameTooltip:AddLine("<Shift-Click to reveal the name>", 0, 1, 0, true)
			GameTooltip:Show()
		elseif (spoilerLevel == 1) then
			local spellName = GetSpellInfo(SkillLineAbilitySpellLUT[self.skillLineAbilityID])
			GameTooltip:SetText(spellName)
			GameTooltip:AddLine("You have not collected this rune", 1, 0, 0, true)
			if (hasGuide) then
				GameTooltip:AddLine("<Click to view the guide>", 0, 1, 0, true)
			else
				GameTooltip:AddLine("(Guide not yet available)", 0.5, 0.5, 0.5, true)
			end
			GameTooltip:AddLine("<Shift-Click to reveal spell info>", 0, 1, 0, true)
			GameTooltip:Show()
		elseif (spoilerLevel == 2) then
			GameTooltip:SetEngravingRune(self.skillLineAbilityID);
			if (not GameTooltipTextLeft3:GetText()) then
				if (hasGuide) then
					GameTooltipTextLeft2:SetText("|cFFFF0000You have not collected this rune|r\n|cFF00FF00<Click to view the the guide>|r")
				else
					GameTooltipTextLeft2:SetText("|cFFFF0000You have not collected this rune|r\n|cFF808080(Guide not yet available)|r")
				end
				C_Timer.NewTimer(TOOLTIP_UPDATE_TIME, function()
					if (self.showingTooltip) then
						OnEnter(self)
					end
				end)
			else
				GameTooltipTextLeft2:SetText(("|cFFFF0000You have not collected this rune|r\n%s"):format(GameTooltipTextLeft2:GetText()))
				if (hasGuide) then
					GameTooltipTextLeft3:SetText("|cFF00FF00<Click to view the the guide>|r")
				else
					GameTooltipTextLeft3:SetText("|cFF808080(Guide not yet available)|r")
				end
			end
			GameTooltip:Show()
		end
	end
end

RunesService = { }

function RunesService.Init()
	if (not (C_Engraving and C_Engraving.IsEngravingEnabled())) then
		return;
	end
	if (not C_AddOns.IsAddOnLoaded("Blizzard_EngravingUI")) then
		UIParentLoadAddOn("Blizzard_EngravingUI");
	end
	local excludedCategories = {
		--[1] = true,
		--[9] = true,
	}
	local funcenv = {
		C_Engraving = CreateFromMixins(C_Engraving, {
			GetRuneCategories = function(a, b)
				local categories = _G.C_Engraving.GetRuneCategories(a, searchActive)
				local newCategories = { }
				for _, categoryID in ipairs(categories) do
					if (not excludedCategories[categoryID]) then
						table.insert(newCategories, categoryID)
					end
				end
				return newCategories
			end,
			GetRunesForCategory = function(a, b)
				local runes = _G.C_Engraving.GetRunesForCategory(a, searchActive)
				local newRunes = { }
				for _, rune in ipairs(runes) do
					if (SkillLineAbilitySpellLUT[rune.skillLineAbilityID]) then
						table.insert(newRunes, rune)
					end
				end
				return newRunes
			end
		})
	}
	setmetatable(funcenv, {
		__index = function(self, key)
			local value = rawget(self, key)
			if (not value) then
				return _G[key]
			end
			return value
		end,
		__newindex = function(_, key, value)
			_G[key] = value
		end
	})
	setfenv(EngravingFrame_UpdateRuneList, funcenv)
	setfenv(EngravingFrame_CalculateScroll, funcenv)
	setfenv(EngravingFrame_SetupFilterDropdown, funcenv)
	EngravingFrame_SetupFilterDropdown(EngravingFrame)
	local buttons = EngravingFrame.scrollFrame.buttons
	for _, button in ipairs(buttons) do
		hooksecurefunc(button, "Show", function(self)
			local spellID = self.skillLineAbilityID and SkillLineAbilitySpellLUT[self.skillLineAbilityID]
			GetSpellInfo(spellID)
			if (spellID and not IsPlayerSpell(spellID)) then
				local spoilerLevel = State.GetRuneSpoilerLevel(self.skillLineAbilityID)
				self.disabledBG:Show()
				self.icon:SetDesaturated(true)
				self:SetAlpha(0.3)
				self:SetScript("OnClick", OnClick)
				if (spoilerLevel == 0) then
					self.icon:SetTexture(134400)
					self.name:SetText("Mysterious Rune")
				end
				self:SetScript("OnEnter", OnEnter)
			else
				self.icon:SetDesaturated(false)
				self:SetAlpha(1)
				self:SetScript("OnEnter", RuneSpellButton_OnEnter)
				self:SetScript("OnLeave", RuneSpellButton_OnLeave)
				self:SetScript("OnClick", EngravingFrameSpell_OnClick)
			end
		end)
		button:SetScript("OnLeave", function(self)
			lastOnEnter = self
			GameTooltip_Hide();
			self.showingTooltip = false;
		end)
	end
	hooksecurefunc(C_Engraving, "SetSearchFilter", function(text)
		searchActive = text ~= ""
	end)
end

function RunesService.IsRuneGuide(guideID)
	return (guideID and string.sub(guideID, 1, 3) == "SOD")
end

function RunesService.IsRuneGuideComplete(guideID)
	return IsPlayerSpell(SkillLineAbilitySpellLUT[SkillLineAbilityGuideRLUT[guideID]])
end

function RunesService.OpenRuneGuide(guideID)
	State.SetGuideShown(true)
	GuideNavigationService.Goto(guideID)
end

local eventFrame = CreateFrame("Frame")

eventFrame:SetScript("OnEvent", function()
	if (lastOnEnter and GameTooltip:GetOwner() == lastOnEnter) then
		OnEnter(lastOnEnter)
	end
end)

eventFrame:RegisterEvent("SPELL_TEXT_UPDATE")
