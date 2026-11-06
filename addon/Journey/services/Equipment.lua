--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

EquipmentService = { }

local slotIDs = { }
local slotNames = { }

for k, v in pairs({
	["HEAD"] = "HeadSlot",
	["NECK"] = "NeckSlot",
	["SHOULDER"] = "ShoulderSlot",
	["BACK"] = "BackSlot",
	["CHEST"] = "ChestSlot",
	["SHIRT"] = "ShirtSlot",
	["TABARD"] = "TabardSlot",
	["WRIST"] = "WristSlot",
	["HANDS"] = "HandsSlot",
	["WAIST"] = "WaistSlot",
	["LEGS"] = "LegsSlot",
	["FEET"] = "FeetSlot",
	["FINGER0"] = "Finger0Slot",
	["FINGER1"] = "Finger1Slot",
	["TRINKET0"] = "Trinket0Slot",
	["TRINKET1"] = "Trinket1Slot",
	["MAINHAND"] = "MainHandSlot",
	["SECONDARYHAND"] = "SecondaryHandSlot",
}) do
	local slotId = GetInventorySlotInfo(v)
	slotIDs[k] = slotId
	table.insert(slotNames, k)
end

local wowversion = select(7,GetBuildInfo())
if (not wowversion) then wowversion = select(4, GetBuildInfo()) end

if (wowversion < 50000) then
	for k, v in pairs({
		["RANGED"] = "RangedSlot",
		["AMMO"] = "AmmoSlot",
	}) do
		local slotId = GetInventorySlotInfo(v)
		slotIDs[k] = slotId
		table.insert(slotNames, k)
	end
end

function EquipmentService.GetEquippedItem(slotName)
	return GetInventoryItemID("player", slotIDs[slotName])
end

function EquipmentService.GetEquippedItemSubClass(slotName)
	local itemID = GetInventoryItemID("player", slotIDs[slotName])
	if (itemID) then
		local subClass = select(13, GetItemInfo(itemID))
		return subClass
	end
end

function EquipmentService.GetSlotNames()
	return slotNames
end
