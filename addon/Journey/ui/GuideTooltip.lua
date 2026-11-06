--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

local component = UI.CreateComponent("GuideTooltip")

local wowversion = select(7,GetBuildInfo())
if (not wowversion) then wowversion = select(4, GetBuildInfo()) end

function component.Init(components)
    GuideTooltip = CreateFrame("GameTooltip", addonName .. "GuideTooltip", UIParent, "GameTooltipTemplate")
    GuideTooltip:SetFrameStrata("TOOLTIP")
    GuideTooltip:Hide()
    GameTooltip_OnLoad(GuideTooltip);
    GuideTooltip.shoppingTooltips = { ShoppingTooltip1, ShoppingTooltip2 };
    GameTooltip_OnLoad(GuideTooltip)
    if (wowversion < 16000 or (wowversion >= 20000 and wowversion < 120000)) then
        GuideTooltip:SetScript("OnTooltipSetUnit", GameTooltip_OnTooltipSetUnit)
        GuideTooltip:SetScript("OnTooltipSetItem", function(self, ...)
            GameTooltip_OnTooltipSetItem(self, ...)
            local owner = self:GetOwner()
            local OnEnter = owner and owner:HasScript("OnEnter") and owner:GetScript("OnEnter")
            if (OnEnter) then
                self.refreshOnly = true
                OnEnter(owner)
            end
        end)
        GuideTooltip:SetScript("OnTooltipSetSpell", function(self, ...)
            GameTooltip_OnTooltipSetSpell(self, ...)
            local owner = self:GetOwner()
            local OnEnter = owner and owner:HasScript("OnEnter") and owner:GetScript("OnEnter")
            if (OnEnter) then
                self.refreshOnly = true
                OnEnter(owner)
            end
        end)
    end
    GuideTooltip:SetScript("OnHide", function()
        GameTooltip_OnHide(GuideTooltip)
        GuideTooltip.refreshOnly = nil
    end)
    GuideTooltip:SetScript("OnUpdate", GameTooltip_OnUpdate)
    GuideTooltip.NineSlice:SetAlpha(0.8)

    local OnModelLoaded = function(self)
        self:SetPosition(0, 0, 0)
        self:SetFacing(0)
        self:SetPitch(0)
        self:SetRoll(0)
        self:SetCamDistanceScale(1)
        self.spinning = false
        local modelFileID = self:GetModelFileID()
        local adjustment = ModelAdjustments[modelFileID]
        if (adjustment) then
            self:SetPosition(adjustment.x, adjustment.y, adjustment.z)
            local facing = adjustment.facing
            if (not facing) then
                self.spinning = true
                facing = 0
            else
                self.spinning = false
            end
            if (not self.spinning) then
                self:SetFacing(adjustment.facing)
            end
            self:SetPitch(adjustment.pitch)
            self:SetRoll(adjustment.roll)
            self:SetCamDistanceScale(adjustment.camDistanceScale)
        end
        self:RefreshCamera()
    end
    local facing = 0
    local maxrads = 6.28319
    local duration = 3
    local OnUpdate = function(self, elapsed)
        if (self.spinning) then
            facing = (facing + maxrads * (elapsed / duration)) % maxrads
            self:SetFacing(facing)
        end
    end

    GuideTooltip.objectModel = CreateFrame("PlayerModel", nil, GuideTooltip)
    GuideTooltip.objectModel:SetScript("OnModelLoaded", OnModelLoaded)
    GuideTooltip.objectModel:SetScript("OnUpdate", OnUpdate)
    GuideTooltip.objectModel:SetSize(200, 200)
    GuideTooltip.objectModel:Hide()

    GuideTooltip.creatureModel = CreateFrame("PlayerModel", nil, GuideTooltip)
    GuideTooltip.creatureModel:SetScript("OnUpdate", OnUpdate)
    GuideTooltip.creatureModel:SetSize(200, 200)
    GuideTooltip.creatureModel:Hide()
    GuideTooltip.creatureModel:SetScript("OnModelLoaded", OnModelLoaded)

    function GuideTooltip:SetGameObject(gameObjectID)
        local gameObjectName = Names.GetGameObjectName(gameObjectID)
        if (gameObjectName) then
            GuideTooltip:AddLine(string.format("|c%s%s|r", Color.GAME_OBJECT, gameObjectName), nil, nil, nil, true)
        end
        local gameObjectModel = GameObjectModels[gameObjectID]
        if (gameObjectModel) then
            local model = GuideTooltip.objectModel
            GameTooltip_InsertFrame(GuideTooltip, model)
            model:ClearModel()
            model:SetModel(gameObjectModel)
        end
    end

    function GuideTooltip:SetNPC(npcID)
        local creatureInfo = GetCreatureInfo(npcID)
        local npcInfo = NPCs[npcID]
        if (creatureInfo) then
            GuideTooltip:AddLine(string.format("|c%s%s|r",
                    NPCColor[GetNPCReaction(npcID)] or Color.NPC, creatureInfo.name), nil, nil, nil, true)
            if (creatureInfo.title) then
                GuideTooltip:AddLine(creatureInfo.title, 1, 1, 1, true)
            end
        end
        if (npcInfo) then
            if (NPCRaces[npcInfo.race]) then
                GuideTooltip:AddLine(string.format("%s %s", NPCRaces[npcInfo.race], NPCGenders[npcInfo.gender] ))
            end
            if (NPCTypes[npcInfo.type]) then
                GuideTooltip:AddLine(NPCTypes[npcInfo.type])
            end
            if (npcInfo.levelMin) then
                local oneLevel = npcInfo.levelMin == npcInfo.levelMax
                GuideTooltip:AddLine(string.format(
                        oneLevel and "%s: %s" or "%s: %s - %s",
                        LEVEL,
                        npcInfo.levelMin,
                        not oneLevel and npcInfo.levelMax
                ))
            end
            if (NPCClassifications[npcInfo.classification]) then
                GuideTooltip:AddLine(NPCClassifications[npcInfo.classification])
            end
            if (not npcInfo.suppressModel) then
                local model = GuideTooltip.creatureModel
                GameTooltip_InsertFrame(GuideTooltip, model)
                model:ClearModel()
                model:SetCreature(npcID)
            end
        end
    end

    function GuideTooltip:SetNPCs(npcIDs)
        GuideTooltip:SetNPC(npcIDs[1])
        if (#npcIDs > 1) then
            GuideTooltip:AddLine(" ")
            GuideTooltip:AddLine("Also Targeting:")
            for i = 2, #npcIDs do
                local creatureInfo = GetCreatureInfo(npcIDs[i])
                if (creatureInfo) then
                    GuideTooltip:AddLine(string.format("|c%s%s|r",
                            NPCColor[GetNPCReaction(npcIDs[i])] or Color.NPC, creatureInfo.name), nil, nil, nil, true)
                end
            end
        end
    end

    function GuideTooltip:SetSideAnchor()
        self:SetOwner(components.Header.frame, "ANCHOR_NONE")
        if (State.IsInvertedModeEnabled()) then
            if (ScreenSide.GetCurrentSide(components.GuideContainer.frame) == SCREEN_LEFT) then
                self:SetPoint("BOTTOMLEFT", components.Header.frame, "TOPRIGHT", 3, 0)
            else
                self:SetPoint("BOTTOMRIGHT", components.Header.frame, "TOPLEFT", -18, 0)
            end
        else
            if (ScreenSide.GetCurrentSide(components.GuideContainer.frame) == SCREEN_LEFT) then
                self:SetPoint("TOPLEFT", components.Header.frame, "BOTTOMRIGHT", 3, 0)
            else
                self:SetPoint("TOPRIGHT", components.Header.frame, "BOTTOMLEFT", -18, 0)
            end
        end
    end

end

UI.Add(component)
