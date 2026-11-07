--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local slashslug = string.upper(Brand.slashCommand)
local slashCommand = "/" .. Brand.slashCommand

local handlers = {
	show = function()
		State.SetGuideShown(true)
	end,
	hide = function()
		State.SetGuideShown(false)
	end,
	enable = function()
		UI.SetMinimapButtonEnabled(true)
	end,
	disable = function()
		UI.SetMinimapButtonEnabled(false)
	end,
	next = function()
		GuideNavigationService.SetManualOverrideEnabled(true)
		GuideNavigationService.SetStepToNext()
	end,
	back = function()
		GuideNavigationService.SetManualOverrideEnabled(true)
		GuideNavigationService.SetStepToPrevious()
	end,
	["debug on"] = function()
		State.SetDebugEnabled(true)
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: debug on", addonTitle))
		DEFAULT_CHAT_FRAME:AddMessage("Current Step: " .. GuideNavigationService.GetStep().id)
	end,
	["debug off"] = function()
		State.SetDebugEnabled(false)
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: debug off", addonTitle))
	end,
	["validate guides"] = function()
		ValidateAllGuides()
	end,
	goto = function(msg)
		if (msg ~= nil) then
			GuideNavigationService.SetAutoAdvanceEnabled(false)
			GuideNavigationService.SetStep(msg)
		end
	end,
	dev = function()
		if (not DEV_BUILD) then return end
		local enabled = not State.IsDevEnabled()
		State.SetDevEnabled(enabled)
		DEFAULT_CHAT_FRAME:AddMessage(string.format("%s: Dev reload %s", addonTitle, enabled and "|cFF00FF00ON|r" or "|cFFFF0000OFF|r"))
	end,
	blob = function()
		if (not DEV_BUILD) then return end
		if (State.IsDevEnabled()) then ToggleBlobOverlay() end
	end,
	["blob next"] = function()
		if (not DEV_BUILD) then return end
		if (State.IsDevEnabled()) then CycleBlobOverlay() end
	end,
	["way clear"] = function()
		ManualWaypointService.Clear()
	end,
}

local function displayHelp()
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Show the guide interface: %s show", slashCommand))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Hide the guide interface: %s hide", slashCommand))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Enable the minimap button: %s enable", slashCommand))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Disable the minimap button: %s disable", slashCommand))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Next step: %s next", slashCommand))
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Previous step: %s back", slashCommand))
	if (Brand.hasWebGuides) then
	else
		DEFAULT_CHAT_FRAME:AddMessage(string.format("Go to step in current guide: %s goto ##-##", slashCommand))
	end
	DEFAULT_CHAT_FRAME:AddMessage(string.format("Set a waypoint: %s way <x> <y>", slashCommand))
end

local function handleSlashCommand(msg)
	msg = string.lower(msg)
	if (not handlers[msg]) then
		if (string.sub(msg,1,5)=="goto ") then
			handlers.goto(string.sub(msg, 6))
		elseif (string.sub(msg,1,4)=="way ") then
			ManualWaypointService.HandleCommand(string.sub(msg, 5))
		elseif (msg == "way") then
			ManualWaypointService.HandleCommand("")
		else
			displayHelp()
		end
	else
		handlers[msg]()
	end
end

_G["SLASH_" .. slashslug .. "1"] = slashCommand

SlashCmdList[slashslug] = handleSlashCommand
