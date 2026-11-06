--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("GuideMenu")

local guideContainer, guideHeader, guideMenu

local function createGuideMenu()
	local menuData = { }
	local recommendedMenuData = { }
	local submenus = { }
	for _, guideInfo in ipairs(CatalogService.GetGuideInfos()) do
		local moduleInfo = GuideModules.GetModule(guideInfo.moduleID)
		if (moduleInfo) then
			if (CheckCondition(guideInfo)) then
				local installed = CatalogService.IsInstalled(guideInfo.guideID)
				local incompatibleReason = CatalogService.CheckCompatibility()
				local compatible = installed and not GuideModules.IsExpired() and not incompatibleReason
				local _menu = menuData
				if (guideInfo.group) then
					local submenu = submenus[guideInfo.group]
					if (not submenu) then
						submenu = { }
						table.insert(
								submenu,
								{
									text = guideInfo.group,
									isTitle = true,
									notCheckable = true
								})
						submenus[guideInfo.group] = submenu
						table.insert(menuData, {
							text = guideInfo.group,
							hasArrow = true,
							menuList = submenu,
							notCheckable = true
						})
					end
					_menu = submenu
				end
				local descriptionFormat = installed and (compatible and "%s" or "|cFFFF9900%s|r") or "|cFFFF0000%s|r"
				local menuText = string.format(descriptionFormat, guideInfo.description)
				local text2
				if (Flags.HasFlag(guideInfo, "F")) then
					text2 = "FREE"
				end
				local guideMenuItem = {
					text = menuText,
					text2 = text2,
					value = guideInfo.guideID,
					isNotRadio = true,
					notCheckable = false,
					checked = function()
						return (GuideNavigationService.IsGuideSet() and guideInfo.guideID == GuideNavigationService.GetGuide().id)
								or false
					end,
					func = function()
						if (installed and compatible) then
							if (CatalogService.HandleStubGuide(guideInfo.guideID)) then
								-- stub handled, do nothing
							elseif (GuideNavigationService.IsGuideSet() and guideInfo.guideID == GuideNavigationService.GetGuide().id) then
								GuideNavigationService.SetGuide(nil)
							else
								GuideNavigationService.SetSeeking(true)
								GuideNavigationService.Goto(guideInfo.guideID)
							end
						else
							if (GuideModules.IsExpired()) then
								TogglePopup(
									nil, nil, nil, nil, nil,
									"|cFFFF0000UPDATE REQUIRED:|r\n\n|cFFFFD100" .. addonTitle .. "|r\n\nPlease update your addon"
								)
							elseif (incompatibleReason == "addon") then
								TogglePopup(
									nil, nil, nil, nil, nil,
									"|cFFFF0000INCOMPATIBLE:|r\n\n|cFFFFD100" .. addonTitle .. "|r\n\nPlease update your addon"
								)
							elseif (incompatibleReason == "guide") then
								TogglePopup(
									nil, nil, nil, nil, nil,
									"|cFFFF0000GUIDE UPDATE REQUIRED:|r\n\n|cFFFFD100" .. addonTitle .. "|r\n\nYour guide data is outdated.\nPlease run the " .. Brand.installerName .. "\nto update your guides."
								)
							elseif (GuideModules.HasLegacyModules()) then
								TogglePopup(
									Brand.website,
									"Press Ctrl-C to copy the link",
									nil, nil, nil,
									"|cFFFF0000GUIDE UPDATE REQUIRED:|r\n\n|cFFFFD100" .. addonTitle .. "|r\n\nYour installed guides are not compatible\nwith this version of the addon.\n\nPlease visit our website to get the update:"
								)
							else
								-- D folder may have been installed since the menu was built
								CatalogService.Reload()
								if (CatalogService.IsInstalled(guideInfo.guideID)) then
									GuideNavigationService.SetSeeking(true)
									GuideNavigationService.Goto(guideInfo.guideID)
								else
									local freeText = Flags.HasFlag(guideInfo, "F") and "\n(This guide is FREE!)" or ""
									TogglePopup(
										Brand.website,
										"Press Ctrl-C to copy the link",
										nil, nil, nil,
										string.format("|cFFFF0000GUIDE NOT INSTALLED:|r\n\n|cFFFFD100%s|r" .. freeText .. "\n\nVisit our website to get it:", guideInfo.description)
									)
								end
							end
						end
						UI.CloseGuideMenu()
					end,
					guideInfo = guideInfo
				}
				guideMenuItem.tooltipTitle = (not installed and "Not Installed")
						or (not compatible and "Incompatible version (please update)")
				if (not guideMenuItem.tooltipTitle) then
					guideMenuItem.tooltipTitle = guideInfo.tooltipTitle
					guideMenuItem.tooltipText = guideInfo.tooltipText
				end
				guideMenuItem.tooltipOnButton = guideMenuItem.tooltipTitle and 1
				table.insert(
						_menu,
						guideMenuItem)
				if (installed and guideInfo.recommended and CheckCondition(guideInfo, guideInfo.recommended)) then
					table.insert(recommendedMenuData, guideMenuItem)
				end
			end
		end
	end
	if (#recommendedMenuData ~= 0) then
		local idx = 1
		for i = #recommendedMenuData, 1, -1 do
			local menuItem = CreateFromMixins(recommendedMenuData[i])
			if (idx > 1 and Flags.HasFlag(menuItem.guideInfo, "S")) then
				menuItem.text = menuItem.text .. " |cFFBEF4A4(safer)|r"
			end
			table.insert(
					menuData,
					idx,
					menuItem
			)
			idx = idx + 1
		end
		table.insert(
				menuData,
				#recommendedMenuData + 1,
				{
					text = "",
					isTitle = true,
					notCheckable = true
				})
		table.insert(
				menuData,
				#recommendedMenuData + 2,
				{
					text = L["All Guides"],
					isTitle = true,
					notCheckable = true
				})
		table.insert(
				menuData,
				1,
				{
					text = #recommendedMenuData == 1 and L["Recommended Guide"] or L["Recommended Guides"],
					isTitle = true,
					notCheckable = true
				}
		)
	else
		table.insert(
				menuData,
				1,
				{
					text = L["All Guides"],
					isTitle = true,
					notCheckable = true
				})
	end
	table.insert(
			menuData,
			{
				text = "",
				isTitle = true,
				notCheckable = true
			})
	table.insert(
			menuData,
			{
				text = L["Options"],
				isTitle = true,
				notCheckable = true
			})
	table.insert(
			menuData,
			{
				text = L["Hide Guide"],
				isNotRadio = true,
				notCheckable = false,
				checked = function()
					return false
				end,
				func = function()
					State.SetGuideShown(false)
					UI.CloseGuideMenu()
				end
			})
	table.insert(
			menuData,
			{
				text = L["Lock Window"],
				isNotRadio = true,
				notCheckable = false,
				checked = function()
					return UI.IsGuideContainerLocked()
				end,
				func = function()
					UI.SetGuideContainerLocked(not UI.IsGuideContainerLocked())
					UI.CloseGuideMenu()
				end
			})
	table.insert(
			menuData,
			{
				text = L["Inverted Mode"],
				isNotRadio = true,
				notCheckable = false,
				checked = function()
					return State.IsInvertedModeEnabled()
				end,
				func = function()
					State.SetInvertedModeEnabled(not State.IsInvertedModeEnabled())
					UI.CloseGuideMenu()
				end
			})
	local returnToRuneGuide = State.GetReturnToGuide(GUIDE_TYPE.RUNE)
	local returnToRuneGuideIsComplete = returnToRuneGuide and RunesService.IsRuneGuideComplete(returnToRuneGuide)
	local returnToLevelingGuide = State.GetReturnToGuide(GUIDE_TYPE.LEVELING)
	if (returnToLevelingGuide or (returnToRuneGuide and not returnToRuneGuideIsComplete)) then
		table.insert(
				menuData,
				1,
				{
					text = "",
					isTitle = true,
					notCheckable = true
				})
	end
	if (returnToRuneGuide and not returnToRuneGuideIsComplete) then
		table.insert(
				menuData,
				1,
				{
					text = "Resume Rune Guide",
					notCheckable = true,
					func = function()
						GuideNavigationService.Goto(returnToRuneGuide)
						UI.CloseGuideMenu()
					end
				})
	end
	if (returnToLevelingGuide) then
		table.insert(
				menuData,
				1,
				{
					text = "Resume Leveling Guide",
					notCheckable = true,
					func = function()
						GuideNavigationService.Goto(returnToLevelingGuide)
						UI.CloseGuideMenu()
					end
				})
	end
	table.insert(
			menuData,
			1,
			{
				text = "",
				isTitle = true,
				notCheckable = true
			})
	table.insert(
			menuData,
			1,
			{
				text = string.format("%s %s", addonTitle, GetDisplayVersion()),
				isTitle = true,
				notCheckable = true,
			})
	table.insert(
			menuData,
			{
				text = "Advanced Options",
				notCheckable = true,
				func = function()
					UI.OpenConfigurationWindow()
					UI.CloseGuideMenu()
				end
			})
	return menuData
end

function component.Init(components)
	guideContainer = components.GuideContainer
	guideHeader = components.Header

end

function UI.CloseGuideMenu()
	if (guideMenu) then
		guideMenu:Display(false)
	end
end

function UI.ToggleGuideMenu()
	if (not guideMenu) then
		guideMenu = TieredMenu.CreateMenu(guideContainer.frame)
	end
	if (guideMenu:IsShown()) then
		guideMenu:Display(false)
	else
		if (State.IsInvertedModeEnabled()) then
			if (GuideNavigationService.IsGuideSet()) then
				if (ScreenSide.GetCurrentSide(guideContainer.frame) == SCREEN_LEFT) then
					guideMenu:Display(createGuideMenu(), "BOTTOMLEFT", guideHeader.frame, "TOPRIGHT", -4, -2)
				else
					guideMenu:Display(createGuideMenu(), "BOTTOMRIGHT", guideHeader.frame, "TOPLEFT", -16, -2)
				end
			else
				guideMenu:Display(createGuideMenu(), "BOTTOMLEFT", guideHeader.frame, "TOPLEFT", -34, 0)
			end
		else
			if (GuideNavigationService.IsGuideSet()) then
				if (ScreenSide.GetCurrentSide(guideContainer.frame) == SCREEN_LEFT) then
					guideMenu:Display(createGuideMenu(), "TOPLEFT", guideHeader.frame, "BOTTOMRIGHT", -4, 2)
				else
					guideMenu:Display(createGuideMenu(), "TOPRIGHT", guideHeader.frame, "BOTTOMLEFT", -16, 2)
				end
			else
				guideMenu:Display(createGuideMenu(), "TOPLEFT", guideHeader.frame, "BOTTOMLEFT", -20, 0)
			end
		end
	end
end

UI.Add(component)
