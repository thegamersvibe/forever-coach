--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local hasFlyingMount = false

local frame = CreateFrame("Frame")

local wowversion = select(7,GetBuildInfo())
if (not wowversion) then wowversion = select(4, GetBuildInfo()) end

local function refresh(notify)
	local collectedFilter = C_MountJournal.GetCollectedFilterSetting(1)
	local notcollectedFilter = C_MountJournal.GetCollectedFilterSetting(2)
	C_MountJournal.SetDefaultFilters()
	C_MountJournal.SetTypeFilter(1, false)
	C_MountJournal.SetTypeFilter(2, true)
	local flyingMount = false
	for index = 1, C_MountJournal.GetNumDisplayedMounts() do
		local mountInfo =  { C_MountJournal.GetDisplayedMountInfo(index) }
		if (mountInfo[11]) then
			flyingMount = true
			break
		end
	end
	C_MountJournal.SetDefaultFilters()
	C_MountJournal.SetCollectedFilterSetting(1, collectedFilter)
	C_MountJournal.SetCollectedFilterSetting(2, notcollectedFilter)
	if (hasFlyingMount ~= flyingMount) then
		hasFlyingMount = flyingMount
		if (notify) then
			MarkAllDirty()
		end
	end
end

local function OnEvent(_, event, ...)
	if ( event == "MOUNT_JOURNAL_USABILITY_CHANGED" or event == "COMPANION_LEARNED" or event == "COMPANION_UNLEARNED" or event == "COMPANION_UPDATE" ) then
		local companionType = ...;
		if ( not companionType or companionType == "MOUNT" ) then
			refresh()
		end
	elseif (event == "MOUNT_LEARNED") then
		refresh()
	end
end

MountsService = { }

function MountsService.HasFlyingMount()
	return hasFlyingMount
end

function MountsService.Init()
	refresh(false)
end

frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("MOUNT_JOURNAL_USABILITY_CHANGED")
frame:RegisterEvent("COMPANION_LEARNED")
frame:RegisterEvent("COMPANION_UNLEARNED")
frame:RegisterEvent("COMPANION_UPDATE")
frame:RegisterEvent("NEW_MOUNT_ADDED")
