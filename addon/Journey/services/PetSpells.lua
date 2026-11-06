--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

PetSpellsService = { }

function PetSpellsService.HasPetSpell(spellID)
	for i = 1, NUM_PET_ACTION_SLOTS do
		local _, _, _, _, _, _, spellID_ = GetPetActionInfo(i)
		if spellID == spellID_ then
			return true
		end
	end
	return false
end
