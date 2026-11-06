--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

TargetScanService = { }

--local found = false
--local scanning = false
--local initialized = false
--
--local foundTargets = { }
--local scanFrame = CreateFrame("Frame")
--scanFrame:RegisterEvent("ADDON_ACTION_FORBIDDEN")
--
--scanFrame:SetScript("OnEvent", function()
--    if (scanning) then
--        found = true
--    end
--end)
--
--local forbiddenEventFrames
--local addonLoadedFrame = CreateFrame("Frame")
--addonLoadedFrame:RegisterEvent("ADDON_LOADED")
--addonLoadedFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
--
--addonLoadedFrame:SetScript("OnEvent", function()
--    forbiddenEventFrames = nil
--end)

function TargetScanService.Search(targetStrings, useAlert)
    -- Always return true to keep the target buttons lit up since we can no longer detect the NPC's presence.
    -- Do not play sounds
    return true
    --if (not initialized) then
    --    if (not forbiddenEventFrames) then
    --        forbiddenEventFrames= { }
    --        local frame
    --        repeat
    --            frame = EnumerateFrames(frame)
    --            if (frame and frame ~= scanFrame and UIParent.IsEventRegistered(frame, "ADDON_ACTION_FORBIDDEN")) then
    --                table.insert(forbiddenEventFrames, frame)
    --            end
    --        until(not frame)
    --    end
    --    for _, frame in ipairs(forbiddenEventFrames) do
    --        UIParent.UnregisterEvent(frame, "ADDON_ACTION_FORBIDDEN")
    --    end
    --    initialized = true
    --end
    --for _, targetString in ipairs(targetStrings) do
    --    found = false
    --    scanning = true
    --    TargetUnit(targetString)
    --    scanning = false
    --    if (found) then
    --        if (useAlert) then
    --            local lastFound = foundTargets[targetString] or 0
    --            local now = time()
    --            if (now - lastFound >= 10) then
    --                local soundID = State.GetNPCAlertSound()
    --                if (soundID) then
    --                    PlaySound(soundID)
    --                end
    --            end
    --            foundTargets[targetString] = now
    --        end
    --        return true
    --    end
    --end
    --return false
end

function TargetScanService.Reset()
    --if (forbiddenEventFrames) then
    --    for _, frame in ipairs(forbiddenEventFrames) do
    --        UIParent.RegisterEvent(frame, "ADDON_ACTION_FORBIDDEN")
    --    end
    --end
    --initialized = false
end
