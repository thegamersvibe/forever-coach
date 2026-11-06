--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local function TooltipShow(frame, objectRef)
    GuideTooltip:SetSideAnchor()
    GuideTooltip:SetGameObject(objectRef.gameobject)
    GuideTooltip:Show()
end

local function OnClick(frame, objectRef)
    TogglePopup(Hyperlinks.GetExternalSiteURL("object", objectRef.gameobject), L["CTRL-C"], nil, frame)
end

function Hyperlinks.GetGameObjectHyperlink(objectRef)
    local name = objectRef.label
    if (not name and type(objectRef.gameobject) == "string") then
        name = objectRef.gameobject
    elseif (not name) then
        name = Names.GetGameObjectName(objectRef.gameobject)
    end
    return string.format("|Hgameobject:%s:%s|h%s|h", objectRef.gameobject, Hyperlinks.CreateReference(objectRef), name)
end

Hyperlinks.RegisterHyperlinkType("gameobject", OnClick, Hyperlinks.OnEnterTooltipFunc, Hyperlinks.OnLeaveTooltipFunc, TooltipShow)
