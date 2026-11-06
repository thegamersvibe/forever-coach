--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

ScreenSide = { }

function ScreenSide.GetCurrentSide(frame)
    local l1, _, w1 = frame:GetScaledRect()
    local l2, _, w2 = UIParent:GetScaledRect()
    local left = l1 - l2
    local right = w2 - (l1 + w1)
    return left > right and SCREEN_RIGHT or SCREEN_LEFT
end
