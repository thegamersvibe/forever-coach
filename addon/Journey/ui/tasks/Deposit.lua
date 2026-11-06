--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "deposit",
	taskLabel = L["Deposit into bank:"],
	incompleteIcon = IconService.GetIconInfo("vignetteloot"),
}, BankTaskMixin)

function TaskType:IsObjectiveComplete(itemObjective)
	local totalInBags = GetItemCount(itemObjective.item, false)
	local totalInBank = GetItemCount(itemObjective.item, true) - totalInBags
	local totalToMove = totalInBags
	if (itemObjective.bags and totalInBags > itemObjective.bags) then
		totalToMove = totalInBags - itemObjective.bags
	elseif (itemObjective.bank) then
		totalToMove = math.min(itemObjective.bank - totalInBank, totalInBags)
	end
	return totalToMove <= 0
end

RegisterTaskType(TaskType)
