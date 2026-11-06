--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local collectWidgets, widgetHandlers

local colorFormat = "|c%s%s|r"

local TaskType = Mixin({
	type = "text",
	disableCompleteIcon = true,
}, TaskTypeMixin)

function TaskType:RenderFunc(task, container)
	container.text:SetIndentedWordWrap(false)
	if (task.icon) then
		task.iconOverride = IconService.GetIconInfo(task.icon)
	end
	local output = { { } }
	local colorTracker = { }
	local overrideColor = task.color or task.parent.color or task.root.color
	if (overrideColor) then
		table.insert(output[1], "|c")
		table.insert(output[1], Color[overrideColor])
		colorTracker[#colorTracker + 1] = "|c" .. Color[overrideColor]
	end
	if (task.text == "multitext") then
		for _, widget in ipairs(task) do
			collectWidgets(widget, output, colorTracker)
		end
		for idx = 2, #output do
			--todo: Reset icon and bounds before use
			local detail = container.taskDetailContainers[idx-1]
			detail:SetAlpha(1.0)
			detail.text:SetText(table.concat(output[idx]))
			detail.hasIcon = false
			detail:SetShown(true)
		end
	else
		table.insert(output[1], task.text)
	end
	container.text:SetText(table.concat(output[1]))
	container.text:SetShown(true)
end

local function ColorName(idAttribute, color, lookupFunction, hyperlinkFunction)
	return function(widget, output)
		local name
		if (type(widget[idAttribute]) == "number") then
			name = hyperlinkFunction and hyperlinkFunction(widget)
					or widget.label or Names.GetName(lookupFunction, widget[idAttribute])
		else
			name = widget[idAttribute]
		end
		local c = color
		if (type(c) == "function") then
			c = c(widget)
		end
		table.insert(output[#output], colorFormat:format(c, name))
	end
end

local ColorItemName = ColorName("item", Color.ITEM, nil, Hyperlinks.GetItemHyperlink)
local ColorSpellName = ColorName("spell", Color.SPELL, GetSpellInfo, Hyperlinks.GetSpellHyperlink)

local function ColorValue(color, valueAttribute)
	return function(widget, output)
		table.insert(output[#output], colorFormat:format(color, widget[valueAttribute]))
	end
end

local function NewParagraph(output, val)
	if (#output[#output] > 0) then
		output[#output + 1] = { }
	end
	if (val) then
		table.insert(output[#output], val)
	end
end

widgetHandlers = {
	area = {
		renderFunc = ColorName("area", Color.AREA, nil, Hyperlinks.GetAreaHyperlink)
	},
	bold = { renderFunc = ColorValue(Color.BOLD, "bold") },
	gameobject = { renderFunc = ColorName("gameobject", Color.GAME_OBJECT, nil, Hyperlinks.GetGameObjectHyperlink) },
	getout = { renderFunc = function(widget, output, default)
		NewParagraph(output, colorFormat:format(Color.GET_OUT, widget.getout))
	end},
	icon = { renderFunc = function(widget, output, default)
		table.insert(output[#output], IconService.GetIconText(widget.icon, 10, widget.scale, widget.offsetx, widget.offsety)) --todo: Dynamically scale this with the text resize feature
	end},
	illustration = {
		renderFunc = function(widget, output, default)
			table.insert(output[#output], string.format("|cFF00FF00|Himage:%s|h[%s]|h|r", widget.illustration, widget.label))
		end
	},
	italic = { renderFunc = ColorValue(Color.ITALIC, "italic") },
	item = { renderFunc = function(widget, output, default)
		if (widget.showicon ~= false) then
			local _, _, _, _, icon = GetItemInfoInstant(widget.item)
			if (not icon) then
				icon = 134400
			end
			table.insert(output[#output], string.format("|T%s:14:14:0:0|t ", icon))
		end
		ColorItemName(widget, output, default)
		if (widget.showquantity) then
			local itemCount = GetItemCount(widget.item, false)
			local bankItemCount = GetItemCount(widget.item, true) - itemCount
			if (bankItemCount > 0) then
				table.insert(output[#output], string.format(" (%s in bags; %s in bank)", itemCount, bankItemCount))
			else
				table.insert(output[#output], string.format(" (%s in bags)", itemCount))
			end
		end
	end},
	location = {
		renderFunc = function(widget, output, default)
			local location = LocationsService.GetLocationByIdx(widget.location)
			if (CheckCondition(location)) then
				local template = widget.template or location:IsActive() and "Active" or "%s"
				table.insert(output[#output], string.format(
						"|c%s|Hlocation:%s|h[%s]|h|r",
						Color.LOCATION,
						widget.location,
						string.format(template, string.format("%.0f.%.0f", location.x, location.y))
				))
			end
		end
	},
	newline = {
		renderFunc = function(widget, output)
			table.insert(output[#output], "\n")
			table.insert(output[#output], widget.newline)
		end
	},
	npc = {
		renderFunc = function(widget, output)
			table.insert(output[#output], Hyperlinks.GetNPCHyperlink(widget))
		end
	},
	paragraph = {
		renderFunc = function(widget, output)
			NewParagraph(output, widget.paragraph)
		end
	},
	quest = {
		renderFunc = function(widget, output)
			if (widget.label) then
				local link = Hyperlinks.GetQuestHyperlink(widget, "quest")
				table.insert(output[#output], colorFormat:format(Color.QUEST, link))
			else
				local link = Hyperlinks.GetQuestHyperlink(widget, "quest")
				table.insert(output[#output], "\"")
				table.insert(output[#output], colorFormat:format(Color.QUEST, link))
				table.insert(output[#output], "\"")
			end
		end
	},
	red = { renderFunc = ColorValue(Color.RED_TEXT, "red") },
	search = { renderFunc = ColorValue(Color.SEARCH_TERM, "label") },
	skill = { renderFunc = ColorValue(Color.SKILL, "label") },
	skipped = {
		renderFunc = function(widget, output)
			local link = Hyperlinks.GetQuestHyperlink(widget, "skipped")
			table.insert(output[#output], "\"")
			table.insert(output[#output], colorFormat:format(Color.QUEST_SKIPPED, link))
			table.insert(output[#output], "\"")
		end
	},
	spell = { renderFunc = function(widget, output, default)
		if (widget.showicon ~= false) then
			local _, _, icon = GetSpellInfo(widget.spell)
			if (icon) then
				table.insert(output[#output], string.format("|T%s:14:14:0:0|t ", icon))
			end
		end
		ColorSpellName(widget, output, default)
	end},
	spelldesc = { renderFunc = function(widget, output)
		local spell = Spell:CreateFromSpellID(widget.spelldesc)
		local desc = spell:GetSpellDescription()
		if (not desc or desc == "") then
			table.insert(output[#output], "...")
			spell:ContinueOnSpellLoad(function()
				UI.MarkDirty()
			end)
		else
			table.insert(output[#output], desc)
		end
	end},
	target = { renderFunc = nop },
	taxi = {
		renderFunc = ColorName("taxi", Color.TAXI, TaxiService.GetTaxiName)
	},
	tip = {
		renderFunc = function(widget, output)
			NewParagraph(output, colorFormat:format(Color.TIP, widget.tip))
		end
	},
	underscore = { renderFunc = ColorValue(Color.UNDERSCORE, "underscore") },
	video = { renderFunc = nop },
	wmoarea = {
		renderFunc = ColorName("wmoarea", Color.WMOAREA, PlacesService.GetWMOAreaName)
	},
	zone = { renderFunc = ColorName("zone", Color.ZONE, nil, Hyperlinks.GetZoneHyperlink) },
}

function collectWidgets(widget, output, colorTracker)
	local outputSize = #output
	if (widget.color) then
		table.insert(output[outputSize], "|c")
		table.insert(output[outputSize], Color[widget.color])
		colorTracker[#colorTracker + 1] = "|c" .. Color[widget.color]
	end
	if (type(widget) == "string") then
		table.insert(output[outputSize], widget)
	else
		-- if it is a known widget, render it
		local widgetFound = false
		for key, widgetHandler in pairs(widgetHandlers) do
			if (widget[key] ~= nil) then
				if (CheckCondition(widget)) then
					widgetHandler.renderFunc(widget, output)
					if (#colorTracker > 0 and outputSize ~= #output) then
						table.insert(output[#output], 1, table.concat(colorTracker))
					end
				end
				widgetFound = true
				break
			end
		end
		-- otherwise traverse the tree
		if (not widgetFound) then
			for k in pairs(widget) do
				if (not (MULTITEXT_IGNORED_KEYS[k] or type(k) == "number")) then
					print("No widget handler found for:" , k)
				end
			end
			if (CheckCondition(widget)) then
				for _, widget_ in ipairs(widget) do
					collectWidgets(widget_, output, colorTracker)
				end
			end
		end
	end
	if (widget.color) then
		table.insert(output[#output], "|r")
		colorTracker[#colorTracker] = nil
	end
end

RegisterTaskType(TaskType)
