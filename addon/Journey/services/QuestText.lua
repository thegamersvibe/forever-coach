--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

QuestTextService = { }

local startworkTemplate = { "On the way, ", "kill ", "kill and loot ", "click on ", "use ", "speak to ", "go to the waypoint", "wait for a bit", "go to " }
local completeTemplate = { "", "Kill ", "Kill and loot ", "Click on ", "Use ", "Speak to ", "Go to the waypoint", "Wait for a bit", "Go to " }

function QuestTextService.TryCreateTextTask(task, guide, stepID)
	if (not guide.quests) then return end
	if (task.complete or task.startwork) then
		local questid = task.complete or task.startwork
		local questInfo = guide.quests[questid]
		if (questInfo) then
			local textTaskOuter = {
				condition = task.condition,
			}
			local template = task.complete and completeTemplate or startworkTemplate
			local objectives = CreateObjectivesList(task, questInfo)
			local conditionPrefixTbl = { "(true" }
			for _, objectiveIdx in ipairs(objectives) do
				table.insert(conditionPrefixTbl, " and OBJECTIVE[")
				table.insert(conditionPrefixTbl, questid)
				table.insert(conditionPrefixTbl, "][")
				table.insert(conditionPrefixTbl, objectiveIdx)
				table.insert(conditionPrefixTbl, "]")
			end
			table.insert(conditionPrefixTbl, ") or ")
			local conditionPrefix = table.concat(conditionPrefixTbl)
			for idx, objectiveIdx in ipairs(objectives) do
				local textTask = { condition = table.concat({
					conditionPrefix,
					"not OBJECTIVE[", questid, "][", objectiveIdx, "]",
					" or QUEST[", questid, "] >= COMPLETED",
				})}
				table.insert(textTaskOuter, textTask)
				if (idx > 1) then
					local condition = { conditionPrefix, "(false" }
					for i = idx - 1, 1, -1 do
						table.insert(condition, " or not OBJECTIVE[")
						table.insert(condition, questid)
						table.insert(condition, "][")
						table.insert(condition, objectives[i])
						table.insert(condition, "]")
					end
					table.insert(condition, ") or QUEST[")
					table.insert(condition, questid)
					table.insert(condition,"] >= COMPLETED")
					table.insert(textTask, { paragraph = "", condition = table.concat(condition) })
				end
				if (template) then
					table.insert(textTask, template[1])
				end
				local objective = questInfo.objectives[objectiveIdx]
				if (objective.custom) then
					table.insert(textTask, objective.custom)
				end

				if (objective.kill) then
					if (objective.gameobject) then
						table.insert(textTask, template[4])
						table.insert(textTask, { gameobject = objective.gameobject })
						table.insert(textTask, " and ")
						table.insert(textTask, startworkTemplate[objective.loot and 3 or 2])
					elseif (objective.clicknpc) then
						table.insert(textTask, template[4])
						table.insert(textTask, { npc = objective.clicknpc })
						table.insert(textTask, " and ")
						table.insert(textTask, startworkTemplate[objective.loot and 3 or 2])
					else
						table.insert(textTask, template[objective.loot and 3 or 2])
					end
				elseif (objective.fromkill) then
					table.insert(textTask, template[objective.loot and 3 or 2])
				elseif (objective.clicknpc or objective.clickgameobject) then
					table.insert(textTask, template[4])
				elseif (objective.speakto) then
					table.insert(textTask, template[6])
				elseif (objective.use) then
					table.insert(textTask, template[5])
					table.insert(textTask, { item = objective.use } )
					if (objective.npc or objective.gameobject) then
						table.insert(textTask, " on ")
					end
				elseif (objective.goto) then
					if (objective.gameobject) then
						table.insert(textTask, template[9])
						table.insert(textTask, { gameobject = objective.gameobject })
					elseif (objective.area) then
						table.insert(textTask, template[9])
						table.insert(textTask, { area = objective.area })
					else
						table.insert(textTask, template[7])
					end
				elseif (objective.wait) then
					table.insert(textTask, template[8])
				end
				local npctargets = objective.kill or objective.fromkill or objective.clicknpc or objective.npc or objective.speakto
				if (npctargets) then
					if (type(npctargets) == "number") then
						table.insert(textTask, { npc = npctargets })
					elseif (#npctargets == 1) then
						table.insert(textTask, { npc = npctargets[1] })
					elseif (#npctargets == 2) then
						table.insert(textTask, { npc = npctargets[1] })
						table.insert(textTask, " and ")
						table.insert(textTask, { npc = npctargets[2] })
					elseif (#npctargets == 3) then
						table.insert(textTask, { npc = npctargets[1] })
						table.insert(textTask, ", ")
						table.insert(textTask, { npc = npctargets[2] })
						table.insert(textTask, " and ")
						table.insert(textTask, { npc = npctargets[3] })
					elseif (#npctargets > 3) then
						table.insert(textTask, "NPCs")
					end
				end
				if ((objective.clickgameobject or (objective.gameobject and not objective.goto) or (objective.fromkill and (objective.clicknpc or objective.use))) and not objective.kill) then
					if (objective.fromkill) then
						if (objective.clicknpc) then
							table.insert(textTask, ", and then click on ")
						else
							table.insert(textTask, ", and then use ")
						end
					end
					if (objective.clicknpc) then
						table.insert(textTask, { npc = objective.clicknpc })
					elseif (objective.use) then
						if (objective.gameobject) then
							table.insert(textTask, { gameobject = objective.gameobject })
						else
							table.insert(textTask, { item = objective.use })
						end
					else
						table.insert(textTask, { gameobject = objective.clickgameobject or objective.gameobject })
					end
				end
				if (objective.around) then
					table.insert(textTask, " around the area")
				end
				if (objective.useoncorpse) then
					table.insert(textTask, ", and then use ")
					table.insert(textTask, { item = objective.useoncorpse} )
					table.insert(textTask, " on its corpse")
				end
				table.insert(textTask, ".")
				if (objective.extra) then
					table.insert(textTask, objective.extra)
				end
			end
			if (questInfo.extra) then
				table.insert(textTaskOuter, { paragraph = ""})
				table.insert(textTaskOuter, questInfo.extra)
			end
			if (questInfo.optional and (task.optional or task.startwork)) then
				table.insert(textTaskOuter, { paragraph = ""})
				table.insert(textTaskOuter, questInfo.optional)
			end
			return textTaskOuter
		end
	end
end
