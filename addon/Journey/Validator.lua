--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local conditionsChecked = 0
local completedsChecked = 0
local stepsChecked = 0
local taskGroupsChecked = 0
local tasksChecked = 0
local guidesChecked = 0
local errorsFound = 0

local function ValidateNode(guideID, step, taskGroupIdx, taskIdx)
	local node
	local location
	if (taskIdx) then
		node = step[taskGroupIdx][taskIdx]
		tasksChecked = tasksChecked + 1
		location = "Guide#" .. guideID .. ": Step#" .. step.id .. ": Task Group #" .. taskGroupIdx .. ": Task #" .. taskIdx
	elseif taskGroupIdx then
		node = step[taskGroupIdx]
		taskGroupsChecked = taskGroupsChecked + 1
		location = "Guide#" .. guideID .. ": Step#" .. step.id .. ": Task Group #" .. taskGroupIdx
	else
		node = step
		stepsChecked = stepsChecked + 1
		location = "Guide#" .. guideID .. ": Step#" .. step.id
	end
	if (not pcall(function()
		if (node.condition ~= nil) then
			CheckCondition(node)
			conditionsChecked = conditionsChecked + 1
		end
	end)) then
		DEFAULT_CHAT_FRAME:AddMessage("Invalid condition @ " .. location)
		errorsFound = errorsFound + 1
	end
	if (not pcall(function()
		if (node.completed ~= nil) then
			CheckCompleted(node)
			completedsChecked = completedsChecked + 1
		end
	end)) then
		DEFAULT_CHAT_FRAME:AddMessage("Invalid completed @ " .. location)
		errorsFound = errorsFound + 1
	end
end

function ValidateGuide(guide)
	if (State.IsDebugEnabled()) then
		conditionsChecked = 0
		completedsChecked = 0
		stepsChecked = 0
		taskGroupsChecked = 0
		tasksChecked = 0
		guidesChecked = 0
		errorsFound = 0
	end
	local currentGuide = guide or GuideNavigationService.GetGuide();
	if (currentGuide ~= nil) then
		for _, step in ipairs(currentGuide) do
			ValidateNode(currentGuide.id, step)
			for taskGroupIdx, taskGroup in ipairs(step) do
				ValidateNode(currentGuide.id, step, taskGroupIdx)
				for taskIdx in ipairs(taskGroup) do
					ValidateNode(currentGuide.id, step, taskGroupIdx, taskIdx)
				end
			end
		end
	end
	if (State.IsDebugEnabled()) then
		DEFAULT_CHAT_FRAME:AddMessage("Checked " .. stepsChecked .. " steps")
		DEFAULT_CHAT_FRAME:AddMessage("Checked " .. taskGroupsChecked .. " task groups")
		DEFAULT_CHAT_FRAME:AddMessage("Checked " .. tasksChecked .. " tasks")
		DEFAULT_CHAT_FRAME:AddMessage("Checked " .. conditionsChecked .. " conditions")
		DEFAULT_CHAT_FRAME:AddMessage("Checked " .. completedsChecked .. " completeds")
		DEFAULT_CHAT_FRAME:AddMessage("Errors Found: " .. errorsFound)
	end
end

function ValidateAllGuides()
	DEFAULT_CHAT_FRAME:AddMessage("Checking guides for errors")
	conditionsChecked = 0
	completedsChecked = 0
	stepsChecked = 0
	taskGroupsChecked = 0
	tasksChecked = 0
	guidesChecked = 0
	errorsFound = 0
	for _, guideInfo in ipairs(CatalogService.GetGuideInfos()) do
		local debugEnabled = State.IsDebugEnabled()
		if (debugEnabled) then State.SetDebugEnabled(false) end
		Guide.SetGuide(guideInfo.guideID)
		ValidateGuide(guideInfo.guideID)
		State.SetDebugEnabled(true);
		guidesChecked = guidesChecked + 1
	end
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. guidesChecked .. " guides")
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. stepsChecked .. " steps")
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. taskGroupsChecked .. " task groups")
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. tasksChecked .. " tasks")
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. conditionsChecked .. " conditions")
	DEFAULT_CHAT_FRAME:AddMessage("Checked " .. completedsChecked .. " completeds")
	DEFAULT_CHAT_FRAME:AddMessage("Errors Found: " .. errorsFound)
end
