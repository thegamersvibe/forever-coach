--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local function TooltipShow(frame, questRef, refType)
    GuideTooltip:SetSideAnchor()
    local questID = questRef[refType]
    if (Compatibility.CanUseQuestLinks()) then
        GuideTooltip:SetHyperlink(string.format("|Hquest:%s|h|h", questID))
    else
        -- Classic Era (non-HC) version
        GuideTooltip:AddLine(Names.GetQuestName(questID))
        if (C_QuestLog_IsOnQuest(questID)) then
            GuideTooltip:AddLine(L["You are on this quest"], 0, 1, 0)
        end
        local info = QuestInfo[questID]
        if (info) then
            GuideTooltip:AddLine(" ")
            GuideTooltip:AddLine(info, 1, 1, 1, true)
        end
    end
    if (questRef.note) then
        GuideTooltip:AddLine(" ")
        if (refType == "skipped") then
            GuideTooltip:AddLine(string.format("|c%sWhy Skipped?:|r", Color.SKIPPED_HEADING))
        else
            GuideTooltip:AddLine(string.format("|c%sNote:|r", Color.NOTE_HEADING))
        end
        GuideTooltip:AddLine(questRef.note, 1, 1, 1, true)
    end
    if (questRef.warn) then
        GuideTooltip:AddLine(" ")
        GuideTooltip:AddLine(string.format("|A:services-icon-warning:16:16|a %s", questRef.warn))
    end
    GuideTooltip:Show()
end

local function OnClick(frame, questRef, refType)
    TogglePopup(Hyperlinks.GetExternalSiteURL("quest", questRef[refType]), L["CTRL-C"], nil, frame)
end

function Hyperlinks.GetQuestHyperlink(questRef, refType)
    local questName = Names.GetQuestName(questRef[refType])
    local name = questRef.label or questName
    return string.format("|Hquest:%s:%s:%s|h%s|h", questRef[refType], Hyperlinks.CreateReference(questRef), refType, name)
end

Hyperlinks.RegisterHyperlinkType("quest", OnClick, Hyperlinks.OnEnterTooltipFunc, Hyperlinks.OnLeaveTooltipFunc, TooltipShow)
