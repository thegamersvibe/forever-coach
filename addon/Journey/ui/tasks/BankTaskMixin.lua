--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local colorFormat = "|c%s%s|r"

BankTaskMixin = Mixin({
	dimmable = true
}, TaskTypeMixin)

function BankTaskMixin:IsCompletedFunc(task)
	for _, itemObjective in ipairs(task) do
		if (CheckCondition(itemObjective)) then
			if (not self:IsObjectiveComplete(itemObjective)) then return false end
		end
	end
	return true
end

function BankTaskMixin:IsObjectiveComplete()
	return false
end

function BankTaskMixin:RenderFunc(task, container)
	local detailIdx = 0
	for _, itemObjective in ipairs(task) do
		if (CheckCondition(itemObjective)) then
			detailIdx = detailIdx + 1
			local detail = container.taskDetailContainers[detailIdx]
			local iconTexture = select(5,GetItemInfoInstant(itemObjective.item))
			if (not iconTexture) then
				iconTexture = 134400
			end
			IconService.SetIconTexture(detail.icon, { texture = iconTexture, scale = 0.8 })
			detail:SetAlpha(self:IsObjectiveComplete(itemObjective) and DIM or 1.0)
			detail.hasIcon = true
			detail.text:SetText(colorFormat:format(Color.ITEM, Hyperlinks.GetItemHyperlink(itemObjective)))
			detail:SetShown(true)
		end
	end
	container.text:SetShown(true)
	container.text:SetText(self.taskLabel)
end
