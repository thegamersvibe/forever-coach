--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local bankOpen = false
local bankBags = { -1 }
for bankBag = NUM_BAG_SLOTS + 1, NUM_BAG_SLOTS + 1 + NUM_BANKBAGSLOTS do
	table.insert(bankBags, bankBag)
end
local bags = { 0, 1, 2, 3, 4 }
local checkEmptyContainerSpace, moveItem

local function OnEvent(_, event)
	if (event == "BANKFRAME_OPENED") then
		bankOpen = true
	elseif (event == "BANKFRAME_CLOSED") then
		bankOpen = false
	end
	if (bankOpen and State.IsAutoBankingEnabled()) then
		local step = GuideNavigationService.GetStep()
		local bankHasRoom, bankFAC, bankFAS
		local bagsHaveRoom, bagFAC, bagFAS
		if (step and not step.completedPassed) then
			for _, taskGroup in ipairs(step) do
				if (taskGroup.conditionPassed and not taskGroup.completedPassed) then
					for _, task in ipairs(taskGroup) do
						if (task.conditionPassed and not task.completedPassed) then
							if (task.deposit) then
								if (bankHasRoom == nil) then
									bankHasRoom, bankFAC, bankFAS = checkEmptyContainerSpace(1, bankBags)
								end
								if (bankHasRoom > 0) then
									for _, v in ipairs(task) do
										if (CheckCondition(v)) then
											local totalInBags = GetItemCount(v.item, false)
											local totalInBank = GetItemCount(v.item, true) - totalInBags
											local totalToMove = totalInBags
											if (v.bags and totalInBags > v.bags) then
												totalToMove = totalInBags - v.bags
											elseif (v.bank) then
												totalToMove = math.min(v.bank - totalInBank, totalInBags)
											end
											if (totalToMove > 0) then
												moveItem(v.item, totalToMove, bags, bankFAC, bankFAS)
												return
											end
										end
									end
								end
							elseif (task.withdraw) then
								if (bagsHaveRoom == nil) then
									bagsHaveRoom, bagFAC, bagFAS = checkEmptyContainerSpace(1, bags)
								end
								if (bagsHaveRoom > 0) then
									for _, v in ipairs(task) do
										if (CheckCondition(v)) then
											local totalInBags = GetItemCount(v.item, false)
											local totalInBank = GetItemCount(v.item, true) - totalInBags
											local totalToMove = totalInBank
											if (v.bank and totalInBank > v.bank) then
												totalToMove = totalInBank - v.bank
											elseif (v.bags) then
												totalToMove = math.min(v.bags - totalInBags, totalInBank)
											end
											if (totalToMove > 0) then
												moveItem(v.item, totalToMove, bankBags, bagFAC, bagFAS)
												return
											end
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

function checkEmptyContainerSpace(minimum, containers)
	local empty = 0
	local firstContainer, firstSlot
	for _, container in  ipairs(containers) do
		for slot = 1, C_Container.GetContainerNumSlots(container) do
			local  itemInfo = C_Container.GetContainerItemInfo(container, slot)
			if not itemInfo then
				empty = empty + 1
				if (not firstContainer) then
					firstContainer = container
					firstSlot = slot
				end
				if (minimum and minimum == empty) then
					return empty, firstContainer, firstSlot
				end
			end
		end
	end
	return empty, firstContainer, firstSlot
end

function moveItem(itemID, totalToMove, fromContainers, toContainer, toSlot)
	for _, bag in ipairs(fromContainers) do
		for slot = 1, C_Container.GetContainerNumSlots(bag) do
			local itemInfo = C_Container.GetContainerItemInfo(bag, slot)
			if (itemInfo and itemInfo.itemID == itemID) then
				if (itemInfo.stackCount <= totalToMove) then
					C_Container.UseContainerItem(bag, slot)
				else
					C_Container.SplitContainerItem(bag, slot, totalToMove)
					C_Container.PickupContainerItem(toContainer, toSlot)
				end
				return
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("BANKFRAME_OPENED")
frame:RegisterEvent("BANKFRAME_CLOSED")
frame:RegisterEvent("BAG_UPDATE_DELAYED")
