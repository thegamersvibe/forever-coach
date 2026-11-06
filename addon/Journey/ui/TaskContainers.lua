--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("TaskContainers")

local taskDetailContainers, waypoints

local CreateTaskContainer, GetTaskContainersHeight, SetTaskContainerShown, UpdateTaskContainer,
	UpdateAllTaskContainers, UIPanelButton_Down, UIPanelButton_Up

function UIPanelButton_Down(self)
	if ( self:IsEnabled() ) then
		self.Left:SetTexture(I["UI-Panel-Button-Down"])
		self.Middle:SetTexture(I["UI-Panel-Button-Down"])
		self.Right:SetTexture(I["UI-Panel-Button-Down"])
	end
end

function UIPanelButton_Up(self)
	if ( self:IsEnabled() ) then
		self.Left:SetTexture(I["UI-Panel-Button-Up"])
		self.Middle:SetTexture(I["UI-Panel-Button-Up"])
		self.Right:SetTexture(I["UI-Panel-Button-Up"])
	end
end

local function SetButtonColor(self, color)
	local r, g, b
	if (color) then
		r = tonumber(color:sub(3,4), 16) / 128
		g = tonumber(color:sub(5,6), 16) / 128
		b = tonumber(color:sub(7,8), 16) / 128
	else
		r = 1
		g = 0
		b = 0
	end
	self.button.Left:SetVertexColor(r, g, b)
	self.button.Middle:SetVertexColor(r, g, b)
	self.button.Right:SetVertexColor(r, g, b)
	self.button.Highlight:SetVertexColor(r, g, b)
end

local function AddButtonBackground(button, originalTexture)
	local bgTexture = button:CreateTexture("Background")
	bgTexture:SetTexCoord(originalTexture:GetTexCoord())
	bgTexture:SetSize(originalTexture:GetSize())
	bgTexture:SetAllPoints(originalTexture)
	local layer, sublayer = originalTexture:GetDrawLayer()
	bgTexture:SetDrawLayer(layer, sublayer - 1)
	bgTexture:SetTexture(I["UI-Panel-Button-Background"])
end

function CreateTaskContainer(parent, renderFrame)
	local taskContainer = { }
	taskContainer.Update = UpdateTaskContainer
	taskContainer.parent = parent
	local frame = CreateFrame("Frame", nil, renderFrame)
	frame:SetHeight(20)
	frame:SetHyperlinksEnabled(true)
	frame:SetScript("OnHyperlinkClick", Hyperlinks.OnHyperlinkClick)
	frame:SetScript("OnHyperlinkEnter", Hyperlinks.OnHyperlinkEnter)
	frame:SetScript("OnHyperlinkLeave", Hyperlinks.OnHyperlinkLeave)
	taskContainer.icon = CreateFrame("Button", nil, frame)
	taskContainer.icon:SetSize(1, ICONSIZE)
	taskContainer.icon:SetPoint("TOPLEFT", 0, 0)
	taskContainer.icon:Hide()
	taskContainer.icon:SetScript("OnEnter", function()
		if (taskContainer.task and taskContainer.task.warn) then
			Hyperlinks.OnEnterTooltipFuncSimple(function()
				if (taskContainer.task and taskContainer.task.warn) then
					GuideTooltip:SetOwner(taskContainer.icon, "ANCHOR_CURSOR")
					GuideTooltip:SetText(taskContainer.task.warn)
					GuideTooltip:Show()
				end
			end)
		end
	end)
	taskContainer.icon:SetScript("OnLeave", Hyperlinks.OnLeaveTooltipFunc)
	taskContainer.icon.texture = taskContainer.icon:CreateTexture()
	taskContainer.icon.texture:SetPoint("TOPLEFT", 1, -1)
	taskContainer.text = frame:CreateFontString(nil, "ARTWORK", "GameFontWhiteSmall")
	taskContainer.text:SetJustifyH("LEFT")
	taskContainer.text:SetPoint("TOPLEFT", taskContainer.icon, "TOPRIGHT", 0, -2)
	taskContainer.text:SetPoint("RIGHT", -10, 0)
	taskContainer.taskDetailContainers = taskDetailContainers.CreateFactory(taskContainer)
	taskContainer.button = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
	taskContainer.button:SetPoint("BOTTOM", 0, 4)
	taskContainer.button:SetPoint("LEFT", 0, 0)
	taskContainer.button:SetPoint("RIGHT", -8, 0)
	taskContainer.button.MiddleBG = AddButtonBackground(taskContainer.button, taskContainer.button.Middle)
	taskContainer.button.LeftBG = AddButtonBackground(taskContainer.button, taskContainer.button.Left)
	taskContainer.button.RightBG = AddButtonBackground(taskContainer.button, taskContainer.button.Right)
	taskContainer.button.Highlight = taskContainer.button:GetHighlightTexture()
	taskContainer.button.Highlight:SetDesaturated(true)
	taskContainer.button:SetScript("OnShow", UIPanelButton_Up)
	taskContainer.button:SetScript("OnMouseDown", UIPanelButton_Down)
	taskContainer.button:SetScript("OnMouseUp", UIPanelButton_Up)
	taskContainer.button:SetScript("OnEnable", UIPanelButton_Up)
	taskContainer.button:Hide()
	taskContainer.SetButtonColor = SetButtonColor
	taskContainer.SetShown = SetTaskContainerShown
	taskContainer.frame = frame
	taskContainer.renderFrame = renderFrame
	return taskContainer
end

function GetTaskContainersHeight(self)
	local height = 19
	for idx = 1, math.max(#self) do
		local taskContainerFrame = self[idx].frame
		if (taskContainerFrame:IsShown()) then
			height = height + taskContainerFrame:GetHeight()
		end
	end
	return height
end

function SetTaskContainerShown(self, shown)
	local frame = self.frame
	frame:ClearAllPoints()
	local hasPrevious = self:HasPrevious()
	if (shown) then
		frame:SetPoint(
				"TOPLEFT",
				hasPrevious and self:GetPrevious().frame or self.renderFrame,
				hasPrevious and "BOTTOMLEFT" or "TOPLEFT",
				hasPrevious and 0 or 13,
				hasPrevious and 0 or -8)
	else
		frame:SetPoint(
				"BOTTOMLEFT",
				hasPrevious and self:GetPrevious().frame or self.renderFrame,
				hasPrevious and "BOTTOMLEFT" or "TOPLEFT",
				hasPrevious and 0 or 13,
				hasPrevious and 0 or -8)
	end
	frame:SetPoint("RIGHT", self.renderFrame, "RIGHT", 0, 0)
	frame:SetShown(shown)
end

function UpdateTaskContainer(self)
	local currentStep = GuideNavigationService.GetStep()
	local taskGroup = currentStep[self.parent:GetIndex()]
	local taskIdx = self:GetIndex()
	local task = taskGroup[taskIdx]
	if (task and task.conditionPassed) then
		local taskType = task.taskType
		taskType:Render(task, self)
		self:SetShown(true)
		local height
		if (self.text:IsShown()) then
			height = self.text:GetStringHeight() + 7
			for _, taskDetailContainer in ipairs(self.taskDetailContainers) do
				if (taskDetailContainer.text:IsShown()) then
					height = height + taskDetailContainer.text:GetStringHeight()
							+ (taskDetailContainer.defaultFont and 1 or 0.5)
					if (not taskDetailContainer.icon:IsShown()) then
						height = height + 7
					end
				end
			end
		elseif (self.button:IsShown()) then
			height = 25
		else
			height = 0
		end
		if (taskType.compactable) then
			for i = taskIdx + 1, #taskGroup do
				local nextTask = taskGroup[i]
				if (nextTask and nextTask.conditionPassed) then
					if (nextTask.taskType.compactable) then
						height = height - 6
					end
					break
				end
			end
		end
		self.frame:SetHeight(height)
		self.frame:SetAlpha((taskType:IsDimmable(task)
				and (not UI.IsTaskGroupDimmed(task.parent)) and task.completedPassed) and DIM or 1.0)
	else
		self:SetShown(false)
	end
end

function UpdateAllTaskContainers(self)
	local currentStep = GuideNavigationService.GetStep()
	local taskGroup = currentStep[self.parent:GetIndex()]
	for idx = 1, math.max(#taskGroup, #self) do
		self[idx]:Update()
	end
end

function component.CreateFactory(parent, renderFrame)
	local factory = CreateFactory(function()
		return CreateTaskContainer(parent, renderFrame)
	end, {
		GetHeight = GetTaskContainersHeight,
		UpdateAll = UpdateAllTaskContainers,
		parent = parent,
		renderFrame = renderFrame
	})
	return factory
end

function component.Init(components)
	taskDetailContainers = components.TaskDetailContainers
	waypoints = components.Waypoints
end

UI.Add(component)
