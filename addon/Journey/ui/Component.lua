--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local ComponentMixin = { }

function ComponentMixin:MarkClean()
	self.isDirty = false
end

function ComponentMixin:MarkDirty()
	self.isDirty = true
end

function ComponentMixin:IsDirty()
	return self.isDirty or false
end

function UI.CreateComponent(name)
	local component = CreateFromMixins(ComponentMixin)
	component.name = name
	return component
end
