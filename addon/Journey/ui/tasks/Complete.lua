--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local TaskType = Mixin({
	type = "complete",
	taskPrefix = L["Do: |C%s%s|r"],
	taskColor = Color.QUEST_DO,
	incompleteIcon = IconService.GetIconInfo("worldquest-icon-pvp-ffa")
}, DoQuestMixin)

RegisterTaskType(TaskType)
