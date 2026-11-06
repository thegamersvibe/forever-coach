--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("ActionButtons")

local buttonsInitialized = 0
local guideContainer
local header
local isCombatDirty
local actionButtons
local lastStep
local taskGroupContainers
local updateTimer = -1

local CreateActionButton, GetItemButton

function CreateActionButton()
	local actionButton = CreateFromMixins(ActionButtonMixin)
	actionButton:Init()
	return actionButton
end

function GetItemButton(taskGroup)
	return taskGroup and taskGroup.buttons and taskGroup.buttons[1]
			and (taskGroup.buttons[1].item or taskGroup.buttons[1].destroy) and taskGroup.buttons[1]
end

function component.Init(components)
	guideContainer = components.GuideContainer
	header = components.Header
	taskGroupContainers = components.TaskGroupContainers
	actionButtons = CreateFactory(CreateActionButton)
end

function component.Update()
	isCombatDirty = isCombatDirty or UI.IsDirty()
	local isDirty = component:IsDirty()
	if (isDirty) then
		local currentStep = GuideNavigationService.IsGuideSet() and GuideNavigationService.GetStep() or nil
		local actionButtonRefs = { }
		local actionButtonRefsLUT = { }
		local activeTaskGroups = { }
		if (currentStep) then
			for _, taskGroup in ipairs(currentStep) do
				if (taskGroup.conditionPassed and taskGroup.buttons and not UI.IsTaskGroupDimmed(taskGroup)) then
					for _, actionButtonRef in ipairs(taskGroup.buttons) do
						if (actionButtonRef.conditionPassed) then
							table.insert(actionButtonRefs, actionButtonRef)
							actionButtonRefsLUT[actionButtonRef] = true
							activeTaskGroups[taskGroup] = true
						end
					end
				end
			end
		end
		if (InCombatLockdown()) then
			if (lastStep ~= currentStep) then lastStep = nil end
			if (isCombatDirty) then
				isCombatDirty = false
				if (lastStep == nil) then
					for _, actionButton in ipairs(actionButtons) do
						actionButton.dim = nil
						actionButton:SetShown(false)
					end
				else
					local hasKeybinds = false
					local hasVisible = false
					local hasVisibleTaskGroups = { }
					for _, actionButton in ipairs(actionButtons) do
						local bindingKey = GetBindingKey(actionButton.bindingName)
						hasKeybinds = hasKeybinds or (actionButton.buttonRef and bindingKey and true) or false
						local buttonVisible = actionButtonRefsLUT[actionButton.buttonRef] and true or false
						if (buttonVisible) then
							hasVisibleTaskGroups[actionButton.buttonRef.parent] = true
						end
						hasVisible = hasVisible or buttonVisible
					end
					for _, actionButton in ipairs(actionButtons) do
						if (actionButtonRefsLUT[actionButton.buttonRef]) then
							actionButton.dim = nil
							actionButton:SetShown(true)
						else
							if (actionButton.buttonRef and ((hasKeybinds and hasVisible)
									or (hasVisibleTaskGroups[actionButton.buttonRef.parent]))) then
								local step = GuideNavigationService.GetStep()
								actionButton.dim = nil
								for i = actionButton.buttonRef.parent.idx + 1, #step do
									if (step[i].conditionPassed and not step[i].completedPassed) then
										actionButton.dim = true
									end
								end
							else
								actionButton.dim = nil
							end
							actionButton:SetShown(false)
						end
					end

				end
			end
		else
			component:MarkClean()
			isCombatDirty = false
			for idx = 1, math.max(#actionButtonRefs, #actionButtons) do
				local actionButton = actionButtons[idx]
				local actionButtonRef = actionButtonRefs[idx]
				local shown = actionButtonRef and true or false
				if (shown) then
					actionButton:SetButtonRef(actionButtonRef)
				else
					actionButton:SetShown(false)
					actionButton:Reset()
				end
			end
			for idx = 1, #actionButtonRefs do
				local actionButton = actionButtons[idx]
				actionButton:SetYOffset()
				actionButton:SetShown(true)
			end
			lastStep = currentStep
		end
	end
	if (UI.IsGuideContainerMoving() or buttonsInitialized < #actionButtons) then
		buttonsInitialized = #actionButtons
		local screenSide = ScreenSide.GetCurrentSide(guideContainer.frame)
		for _, actionButton in ipairs(actionButtons) do
			for idx, button in ipairs(actionButton) do
				actionButton.buttonSide = screenSide == SCREEN_RIGHT and 1 or 2
				if (idx == screenSide) then
					if (actionButton.shown) then
						button:SetAlpha(1.0)
						button.cover:SetShown(false)
						button.cooldown:SetDrawBling(true)
					else
						button:SetAlpha(actionButton.dim and 0.5 or 0.001)
						button.cover:SetShown(true)
						button.cooldown:SetDrawBling(false)
					end
				else
					button:SetAlpha(0.001)
					button.cover:SetShown(true)
					button.cooldown:SetDrawBling(false)
				end
			end
		end
	end
	updateTimer = updateTimer - UI.GetElapsed()
	if ( updateTimer <= 0 or isDirty) then
		for _, actionButton in ipairs(actionButtons) do
			local hotkeyShown = false
			if (actionButton.itemID) then
				local valid
				local questLogIdx = GetQuestLogIndexForItem(actionButton.itemID)
				if (questLogIdx) then
					valid = IsQuestLogSpecialItemInRange(questLogIdx)
				end
				if ( valid == 0 ) then
					hotkeyShown = true
					actionButton:SetHotkeyVertexColor(1.0, 0.1, 0.1)
				elseif ( valid == 1 ) then
					hotkeyShown = true
					actionButton:SetHotkeyVertexColor(0.6, 0.6, 0.6)
				else
					actionButton:SetHotkeyVertexColor(0.6, 0.6, 0.6)
				end
				local itemCount = GetItemCount(actionButton.itemID, false) or 0
				actionButton:SetAvailable(itemCount ~= 0)
			elseif (actionButton.npcIDs) then
				hotkeyShown = true
				if (TargetScanService.Search(actionButton.targetStrings, actionButton.buttonRef.alert)) then
					actionButton:SetHotkeyVertexColor(0.6, 0.6, 0.6)
					actionButton:SetAvailable(true)
				else
					actionButton:SetHotkeyVertexColor(1.0, 0.1, 0.1)
					actionButton:SetAvailable(false)
				end
			end
			actionButton:SetHotkeyShown(hotkeyShown)
			if (actionButton.itemID) then
				if (not actionButton:IsIconTextureSet()) then
					local _, _, _, _, _, _, _, _, _, texture = GetItemInfo(actionButton.itemID)
					if (texture) then
						actionButton:SetIconTexture(texture)
					end
				end
				actionButton:UpdateCount()
			end
		end
		TargetScanService.Reset()
		updateTimer = TOOLTIP_UPDATE_TIME;
	end
	for _, actionButton in ipairs(actionButtons) do
		actionButton.pushed:SetShown(actionButton[1].pushed:IsShown())
	end
end

function component.GetTaskgroupsButtonStatus()
	local status = { }
	for _, actionButton in ipairs(actionButtons) do
		if (actionButton.shown and actionButton.buttonRef and actionButton.buttonRef.parent) then
			status[actionButton.buttonRef.parent.idx] = true
		end
	end
	return status
end

local actionButtonNameTemplate = addonName .. "_ActionButton%d"

function UI.GetNextActionButtonName()
	return actionButtonNameTemplate:format(#actionButtons + 1)
end

UI.Add(component)
