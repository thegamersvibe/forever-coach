--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("TaskDetailContainers")

local smallFont, tinyFont

local CreateTaskDetailContainer, Reset, SetFontSmall, SetFontTiny, SetTaskDetailContainerAlpha,
	SetTaskDetailContainerShown, UpdateTaskDetailContainer, UpdateAllTaskDetailContainers

function CreateTaskDetailContainer(parent)
	local taskDetailContainer = { }
	taskDetailContainer.parent = parent
	taskDetailContainer.text = parent.frame:CreateFontString(nil, "ARTWORK", "JGGameFontWhiteSmall")
	taskDetailContainer.text:SetJustifyH("LEFT")
	taskDetailContainer.text:SetIndentedWordWrap(true)
	taskDetailContainer.icon = CreateFrame("Frame", nil, parent.frame)
	taskDetailContainer.icon:SetSize(1, ICONSIZE)
	taskDetailContainer.icon:Hide()
	taskDetailContainer.icon.texture = taskDetailContainer.icon:CreateTexture()
	taskDetailContainer.icon.texture:SetPoint("CENTER")
	taskDetailContainer.SetShown = SetTaskDetailContainerShown
	taskDetailContainer.Update = UpdateTaskDetailContainer
	taskDetailContainer.SetAlpha = SetTaskDetailContainerAlpha
	taskDetailContainer.Reset = Reset
	taskDetailContainer.SetFontSmall = SetFontSmall
	taskDetailContainer.SetFontTiny = SetFontTiny
	taskDetailContainer.defaultFont = true
	return taskDetailContainer
end

function Reset(self)
	self.text:SetFontObject(smallFont)
	self.defaultFont = true
	self.text:Hide()
	self.icon:Hide()
end

function SetFontSmall(self)
	self.defaultFont = true
	self.text:SetFontObject(smallFont)
end

function SetFontTiny(self)
	self.defaultFont = false
	self.text:SetFontObject(tinyFont)
end

function SetTaskDetailContainerAlpha(self, alpha)
	self.text:SetAlpha(alpha)
	self.icon:SetAlpha(alpha)
end

function SetTaskDetailContainerShown(self, shown)
	self.text:SetShown(shown)
	self.icon:SetShown(shown and self.hasIcon)
    self.text:SetIndentedWordWrap(self.hasIcon)
	local hasPrevious = self:HasPrevious()
	if (self.hasIcon) then
		if (hasPrevious) then
			self.icon:SetPoint("TOPLEFT", self:GetPrevious().text, "BOTTOMLEFT", -(ICONSIZE+1), self.defaultFont and 1 or 2)
		else
			self.icon:SetPoint("TOPLEFT", self.parent.text, "BOTTOMLEFT", -4, self.defaultFont and 1 or 2)
		end
	else
		IconService.SetIconTexture(self.icon) -- Clear icon from the frame
		if (hasPrevious) then
			self.icon:SetPoint("TOPLEFT", self:GetPrevious().text, "BOTTOMLEFT", -1, -6)
		else
			self.icon:SetPoint("TOPLEFT", self.parent.text, "BOTTOMLEFT", -1, -6)
		end
	end
	self.text:SetPoint("TOPLEFT", self.icon, "TOPRIGHT", 0, self.defaultFont and -2 or -2.5)
	self.text:SetPoint("RIGHT", self.parent.frame, "RIGHT", -10, 0)
end

function UpdateTaskDetailContainer(self)

end

function UpdateAllTaskDetailContainers(self)

end

function component.CreateFactory(parent)
	local factory = CreateFactory(function()
		return CreateTaskDetailContainer(parent)
	end, {
		UpdateAll = UpdateAllTaskDetailContainers,
		parent = parent
	})
	return factory
end

function component.Init()
	smallFont = CreateFont("JGGameFontWhiteSmall")
	smallFont:CopyFontObject(GameFontWhiteSmall)
	tinyFont = CreateFont("JGGameFontWhiteTiny")
	tinyFont:CopyFontObject(GameFontWhiteTiny2)
	tinyFont:SetTextColor(0.8, 0.8, 0.8)
end

UI.Add(component)
