--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local wowversion = select(7,GetBuildInfo())
if (not wowversion) then wowversion = select(4, GetBuildInfo()) end

local eventFrame = CreateFrame("Frame")
local skillNameLUT
local skillPoints = { }
local RefreshSkillPoints

ProfessionService = { }

ProfessionService.Tiers = {
	NONE = 0,
	APPRENTICE = 1,
	JOURNEYMAN = 2,
	EXPERT = 3,
	ARTISAN = 4,
	MASTER = 5,
	GRANDMASTER = 6
}

ProfessionService.PlayerProfessions = { }

function ProfessionService.GetPoints(profKey)
	if (skillNameLUT) then
		local skillName = skillNameLUT[profKey]
		if (skillName) then
			return skillPoints[skillName] or skillPoints[profKey] or 0
		end
	end
	return 0
end

function RefreshSkillPoints()
	if (wowversion < 16000 or (wowversion >= 20000 and wowversion < 120000)) then
		local numSkills = GetNumSkillLines();
		skillPoints = { }
		for i = 1, numSkills do
			local skillName, _, _, skillRank = GetSkillLineInfo(i);
			skillPoints[skillName] = skillRank
		end
	else
		local professions = { GetProfessions() }
		for i = 1, 5 do
			if (professions[i]) then
				local _, _, skillLevel, _, _, _, skillLine = GetProfessionInfo(professions[i])
				local profKey = ProfessionsSkillLinesLUT[skillLine]
				if (profKey) then
					skillPoints[profKey] = skillLevel
				end
			end
		end
	end
end

local function OnEvent()
	if (not skillNameLUT) then
		skillNameLUT = { }
		for profKey, tiers in pairs(Professions) do
			local name = GetSpellInfo(tiers[1])
			if (name) then
				skillNameLUT[name] = profKey
				skillNameLUT[profKey] = name
			end
		end
	end
	for profKey, tiers in pairs(Professions) do
		ProfessionService.PlayerProfessions[profKey] = 0
		for i = #tiers, 1, -1 do
			if (IsPlayerSpell(tiers[i])) then
				ProfessionService.PlayerProfessions[profKey] = i
				break;
			end
		end
	end
	RefreshSkillPoints()
	MarkAllDirty()
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("SPELLS_CHANGED")
eventFrame:RegisterEvent("SKILL_LINES_CHANGED")
eventFrame:RegisterEvent("CHARACTER_POINTS_CHANGED")
