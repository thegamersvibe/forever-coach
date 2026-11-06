--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local eventFrame = CreateFrame("Frame")
local buffs = { }
local debuffs = { }
local deferred = false

AuraService = { }

function AuraService.PlayerHasBuff(spellID)
	return buffs[spellID] or false
end

function AuraService.PlayerHasDebuff(spellID)
	return debuffs[spellID] or false
end

local function OnEvent(_, event, unitTarget)
	if (event == "PLAYER_ENTERING_WORLD" or (event == "PLAYER_REGEN_ENABLED" and deferred) or unitTarget == "player") then
		if (C_Secrets.ShouldAurasBeSecret()) then
			deferred = true
			return
		end
		deferred = false
		buffs = { }
		local index = 1
		while true do
			local buffName, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", index)
			if not buffName then
				break
			end
			buffs[spellId] = buffs[spellId] or 0
			buffs[spellId] = buffs[spellId] + 1
			index = index + 1
		end
		debuffs = { }
		index = 1
		while true do
			local debuffName, _, _, _, _, _, _, _, _, spellId = UnitDebuff("player", index)
			if not debuffName then
				break
			end
			debuffs[spellId] = debuffs[spellId] or 0
			debuffs[spellId] = debuffs[spellId] + 1
			index = index + 1
		end
		MarkAllDirty()
	end
end

eventFrame:SetScript("OnEvent", OnEvent)
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
