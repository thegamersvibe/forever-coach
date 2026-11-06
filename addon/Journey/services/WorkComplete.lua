--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local isDirty
local tracker

WorkCompleteService = { }

function WorkCompleteService.MarkDirty()
	isDirty = true
end

function WorkCompleteService.Update()
	if (isDirty) then
		-- check the tracker for completed do quests, objectives, or level/xp tasks
		-- if any complete but were not complete previously, flag for playSound
		if (SavedVariables and SavedVariables.objectiveCompletionSound) then
			local playSound = false
			if (tracker) then
				for task, val in pairs(tracker) do
					if (task.completedPassed) then
						playSound = true
						break
					else
						local questID = task.complete or task.startwork
						if (questID) then
							local objectives = C_QuestLog_GetQuestObjectives(questID)
							for idx in pairs(val) do
								if (objectives and objectives[idx] and objectives[idx].finished) then
									playSound = true
									break
								end
							end
						end
						if (playSound) then break end
					end
				end
			end
			if (playSound) then
				local playerFaction = UnitFactionGroup("player")
				PlaySound(playerFaction == "Horde" and 6199 or 6199)
			end
		end
		-- track any incomplete quests, objectives, or level/xp tasks
		local currentStep = GuideNavigationService.GetStep()
		tracker = { }
		if (currentStep) then
			for _, taskGroup in ipairs(currentStep) do
				if (taskGroup.conditionPassed) then
					for _, task in ipairs(taskGroup) do
						if (task.conditionPassed and not task.completedPassed) then
							local questID = task.complete or task.startwork
							if (questID) then
								tracker[task] = { }
								local objectives = C_QuestLog_GetQuestObjectives(questID)
								if (objectives and #objectives > 0) then
									for idx, objective in ipairs(objectives) do
										if (not objective.finished) then
											tracker[task][idx] = true
										end
									end
								end
							elseif (task.level) then
								tracker[task] = true
							end
						end
					end
				end
			end
		end
		isDirty = nil
	end
end

function SetObjectiveCompletionSoundEnabled(enabled)
	SavedVariables.objectiveCompletionSound = enabled
end

function IsObjectiveCompletionSoundEnabled()
	return SavedVariables.objectiveCompletionSound
end
