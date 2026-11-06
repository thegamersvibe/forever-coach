--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local hasBindings = false
local bindingTemplate = "CLICK " .. addonName .. "_ActionButton%d:LeftButton"

local function UpdateBindings()
    for i = 1, 6 do
        local keybind1, keybind2 = GetBindingKey(bindingTemplate:format(i))
        if (keybind1 or keybind2) then
            hasBindings = true
            return
        end
    end
    hasBindings = false
end

KeybindService = { }

function KeybindService.HasBindings()
    return hasBindings
end

function KeybindService.Init()
    -- Localize the category label without changing its stable Bindings.xml ID.
    if (_G[addonName] == nil or type(_G[addonName]) == "string") then
        _G[addonName] = addonTitle
    end
    for i = 1, 6 do
        _G["BINDING_NAME_" .. bindingTemplate:format(i)] = "Action Button " .. i
    end
    UpdateBindings()
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("UPDATE_BINDINGS")
eventFrame:SetScript("OnEvent", UpdateBindings)
