--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local queue = { }
local functions = { }
local GotoAutomatic, IsRecursionSafe

function GotoAutomatic(...)
    GuideNavigationService.SetManualOverrideEnabled(false)
    GuideNavigationService.Goto(...)
end

function IsRecursionSafe(f)
    if (functions[f]) then
        if (State.IsDebugEnabled()) then
            DEFAULT_CHAT_FRAME:AddMessage("RECURSION WARNING!")
        end
        return false
    end
    functions[f] = true
    return true
end

TriggerService = { }

function TriggerService.OnActivate(obj)
    if (obj and obj.onactivate and obj.root == GuideNavigationService.GetStep()) then
        if (obj.activateFired and not obj:IsActive()) then
            obj.activateFired = nil
            return
        end
        if (obj:IsActive() and obj.activateFired == nil) then
            table.insert(queue, obj)
            obj.activateFired = false
        end
    end
end

function TriggerService.OnEnterOrLeave(obj)
    local queued
    if (obj.withinChanged and obj and obj.root == GuideNavigationService.GetStep()) then
        if (obj.onenter) then
            if (obj:IsPlayerWithin() and obj.enterFired == nil) then
                table.insert(queue, obj)
                obj.enterFired = false
                queued = true
            else
                obj.enterFired = nil
            end
        end
        if (obj.onleave) then
            if (not obj:IsPlayerWithin() and obj.leaveFired == nil) then
                table.insert(queue, obj)
                obj.leaveFired = false
                queued = true
            else
                obj.leaveFired = nil
            end
        end
        obj.withinChanged = nil
    end
    return queued
end

function TriggerService.OnComplete(node)
    local currentStep = GuideNavigationService.GetStep()
    if (node.oncomplete and (node == currentStep or node.root == currentStep)) then
        if (node.oncompleteFired and not node.completedPassed) then
            node.oncompleteFired = nil
            return
        end
        if (node.completedPassed and not node.completedFired) then
            table.insert(queue, node)
        end
    end
end

function TriggerService.OnLoad()
    local currentGuide = GuideNavigationService.GetGuide()
    if (currentGuide.onload) then
        local context = {
            SESSION = CustomVariablesService.GetSessionScope(),
            VAR = CustomVariablesService.GetCharacterScope(),
            GUIDE = CustomVariablesService.GetGuideScope(),
            GetNearestZone = LocationsService.GetNearestZone,
            GetCondition = GetCondition,
        }
        local f = loadstring(currentGuide.onload)
        setfenv(f, context)
        f()
    end
end

function TriggerService.RunAll()
    if (#queue == 0) then return false end
    local triggersRan = false
    for _, obj in ipairs(queue) do
        local context = {
            locations = obj.root and obj.root.locations or obj.locations,
            SESSION = CustomVariablesService.GetSessionScope(),
            VAR = CustomVariablesService.GetCharacterScope(),
            GUIDE = CustomVariablesService.GetGuideScope(),
            COMPLETEONSTART = ConditionContext["COMPLETEONSTART"],
            INCOMPLETEONSTART = ConditionContext["INCOMPLETEONSTART"],
            Goto = GotoAutomatic,
        }
        if (obj.oncomplete) then
            if (type(obj.oncomplete) == "string") then
                obj.oncomplete = loadstring(obj.oncomplete)
            end
            if (IsRecursionSafe(obj.oncomplete)) then
                setfenv(obj.oncomplete, context)
                obj.oncomplete()
                obj.completedFired = true
                triggersRan = true
            end
        end
        if (obj.onactivate and obj.activateFired == false) then
            if (type(obj.onactivate) == "string") then
                obj.onactivate = loadstring(obj.onactivate)
            end
            if (IsRecursionSafe(obj.onactivate)) then
                setfenv(obj.onactivate, context)
                obj.onactivate()
                obj.activateFired = true
                triggersRan = true
            end
        end
        if (obj.onenter and obj.enterFired == false) then
            if (type(obj.onenter) == "string") then
                obj.onenter = loadstring(obj.onenter)
            end
            if (IsRecursionSafe(obj.onenter)) then
                setfenv(obj.onenter, context)
                obj.onenter()
                obj.enterFired = true
                triggersRan = true
            end
        end
        if (obj.onleave and obj.leaveFired == false) then
            if (type(obj.onleave) == "string") then
                obj.onleave = loadstring(obj.onleave)
            end
            if (IsRecursionSafe(obj.onleave)) then
                setfenv(obj.onleave, context)
                obj.onleave()
                obj.leaveFired = true
                triggersRan = true
            end
        end
    end
    queue = { }
    return triggersRan
end

function TriggerService.Reset()
    queue = { }
    functions = { }
end
