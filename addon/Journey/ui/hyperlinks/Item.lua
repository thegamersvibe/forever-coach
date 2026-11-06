--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local function TooltipShow(frame, itemRef)
    GuideTooltip:SetOwner(frame, "ANCHOR_CURSOR")
    local itemID = itemRef.item or itemRef.getitem
    local bagId, slot = GetItemLocation(itemID)
    if (not bagId) then
        GuideTooltip:SetHyperlink(string.format("|Hitem:%s|h|h", itemRef.item or itemRef.getitem))
    else
        GuideTooltip:SetBagItem(bagId, slot)
    end
    GuideTooltip:Show()
end

local function OnClick(frame, itemRef)
    TogglePopup(Hyperlinks.GetExternalSiteURL("item", itemRef.item or itemRef.getitem), L["CTRL-C"], nil, frame)
end

function Hyperlinks.GetItemHyperlink(itemRef)
    local itemID = itemRef.item or itemRef.getitem
    local name = itemRef.label or Names.GetName(GetItemInfo, itemID)
    return string.format("|Hitem:%s:%s|h%s|h", itemID, Hyperlinks.CreateReference(itemRef), name)
end

Hyperlinks.RegisterHyperlinkType("item", OnClick, Hyperlinks.OnEnterTooltipFunc, Hyperlinks.OnLeaveTooltipFunc, TooltipShow)
