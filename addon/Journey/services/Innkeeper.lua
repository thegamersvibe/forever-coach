--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local function OnEvent(_, event)
	if (State.IsAutoSetHome()) then
		local currentStep = GuideNavigationService.GetStep()
		if (currentStep) then
			for _, taskGroup in ipairs(currentStep) do
				for _, task in ipairs(taskGroup) do
					if (task.sethearthstone and taskGroup.conditionPassed and not taskGroup.completedPassed
							and task.conditionPassed and not task.completedPassed) then
						if (event == "GOSSIP_SHOW") then
							if (C_GossipInfo and C_GossipInfo.GetOptions) then
								local options = C_GossipInfo.GetOptions()
								if (options) then
									for idx, option in ipairs(options) do
										if (option.icon == 132052) then
											C_Timer.NewTimer(0.1, function()
												C_GossipInfo.SelectOption(option.gossipOptionID)
											end)
											break
										end
									end
								end
							end
						elseif (event == "CONFIRM_BINDER") then
							C_Timer.NewTimer(0.1, function()
								C_PlayerInteractionManager.ConfirmationInteraction(Enum.PlayerInteractionType.Binder)
								C_PlayerInteractionManager.ClearInteraction(Enum.PlayerInteractionType.Binder)
							end)
						end
						return
					end
				end
			end
		end
	end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnEvent", OnEvent)
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("CONFIRM_BINDER")
