--[[ Copyright (C) 2018-2026 TomCat's Gaming, LLC. All Rights Reserved.
     Unauthorized use, reproduction, or distribution is prohibited.
     See license.txt included with this distribution for full terms. ]]
select(2, ...).SetupGlobalFacade()

CatalogService = { }

local guideInfos
local guideInfoByID
local slotLookup
local minAddonVersionValue
local guideVersionValue
local minGuideVersion = C_AddOns.GetAddOnMetadata(addonName, "X-Min-Guide-Version")
local catalogDecryptKey
local previousBattleTag
local previousBattleTagCaptured
local needsInstallerRun

local function initBattleTag()
    if (not previousBattleTagCaptured) then
        previousBattleTagCaptured = true
        previousBattleTag = SavedVariables.battleTag and SavedVariables.battleTag:lower() or nil
        needsInstallerRun = SavedVariables.needsInstallerRun
    end
    local _, liveTag = BNGetInfo()
    if (liveTag) then
        SavedVariables.battleTag = liveTag
    end
end

local function applySupersedes()
    -- Find productIDs superseded by condition-met entries
    local supersededProducts = { }
    for _, entry in ipairs(guideInfos) do
        if (entry.supersedes and CheckCondition(entry)) then
            for _, supID in ipairs(entry.supersedes) do
                supersededProducts[supID] = true
            end
        end
    end
    if (not next(supersededProducts)) then return end

    -- Rebuild guideInfos without superseded entries
    local filtered = { }
    for _, entry in ipairs(guideInfos) do
        if (entry.productID and supersededProducts[entry.productID]) then
            if (entry.guideID) then
                guideInfoByID[entry.guideID] = nil
                slotLookup[entry.guideID] = nil
            end
        else
            table.insert(filtered, entry)
        end
    end
    guideInfos = filtered
end

local function processGuidesFile(data, prefix)
    if (not data) then return false end
    guideInfos = { }
    guideInfoByID = { }
    slotLookup = { }
    if (data.minAddonVersion) then
        minAddonVersionValue = data.minAddonVersion
    end
    if (data.guideVersion) then
        guideVersionValue = data.guideVersion
    end
    for _, entry in ipairs(data) do
        table.insert(guideInfos, entry)
        if (entry.guideID) then
            guideInfoByID[entry.guideID] = entry
        end
        if (entry.slot and entry.guideID) then
            slotLookup[entry.guideID] = { prefix = prefix, slot = string.format("%04d", entry.slot) }
        end
    end
    applySupersedes()
    return true
end

local function loadCatalogData(suffix)
    local decoded = ReadHTMLTemplate(addonName .. "-" .. suffix)
    if (not decoded) then return nil, nil, nil, "not_found" end

    local signedContent, signature = decoded:match("^(.*), \"(.+)\"%s*$")
    if (not signedContent or not signature) then return nil, nil, nil, "not_signed" end

    local f = loadstring("return " .. signedContent)
    if (not f) then return nil, nil, nil, "parse_failed" end
    setfenv(f, {})
    local ok, result = pcall(f)
    if (not ok) then return nil, nil, nil, "parse_failed" end

    if (result.flavorCondition and not CheckCondition({ condition = result.flavorCondition })) then
        return
    end

    return result, signedContent, signature
end

local function getBattleTag()
    local tag = SavedVariables.battleTag
    return tag and tag:lower() or nil
end

local function deriveDecryptKey(battleTags)
    local sorted = {}
    for _, tag in ipairs(battleTags) do
        table.insert(sorted, tag:lower())
    end
    table.sort(sorted)
    return table.concat(sorted, "")
end

local function isRetryableFailure(reason)
    return reason == "signature_failed" or reason == "parse_failed"
end

local function tryLoadExternalCatalog()
    local catalogData, signedContent, signature, reason = loadCatalogData("ExternalGuides")
    if (not catalogData) then return nil, nil, nil, reason end
    -- Local patch: retain the signed catalog identity, independent of the live account.
    if (catalogData.battleTags) then
        catalogDecryptKey = deriveDecryptKey(catalogData.battleTags)
    end
    return catalogData, signedContent, signature
end

-- Background signature verification
local verifyFrame = CreateFrame("Frame")
local activeVerify

local function cancelBackgroundVerify()
    activeVerify = nil
    verifyFrame:SetScript("OnUpdate", nil)
end

local function onVerifyFailed(source)
    guideInfos = { }
    guideInfoByID = { }
    slotLookup = { }
    catalogDecryptKey = nil
    if (source == "External") then
        print("|cFFFF4444[" .. addonTitle .. "]|r Guide data integrity check failed. Please re-download your guide content.")
    else
        print("|cFFFF4444[" .. addonTitle .. "]|r Addon data integrity check failed. Please reinstall the addon.")
    end
    if (GuideNavigationService and GuideNavigationService.SetGuide) then
        GuideNavigationService.SetGuide(nil)
    end
    MarkAllDirty()
end

local function startBackgroundVerify(signedContent, signature, source)
    cancelBackgroundVerify()
    local state = CryptoService.BeginVerify(signedContent, signature, CATALOG_PUBLIC_KEY)
    if (not state) then
        onVerifyFailed(source)
        return
    end
    activeVerify = { state = state, source = source }
    verifyFrame:SetScript("OnUpdate", function()
        if (not activeVerify) then
            verifyFrame:SetScript("OnUpdate", nil)
            return
        end
        if (CryptoService.ContinueVerify(activeVerify.state)) then
            local passed = CryptoService.GetResult(activeVerify.state)
            local src = activeVerify.source
            activeVerify = nil
            verifyFrame:SetScript("OnUpdate", nil)
            if (not passed) then
                onVerifyFailed(src)
            end
        end
    end)
end

local loadingCatalog
local function ensureLoaded()
    if (guideInfos or loadingCatalog) then return end
    loadingCatalog = true
    initBattleTag()

    -- Try external catalog with one retry for transient parse failures
    local catalogData, signedContent, signature, dReason = tryLoadExternalCatalog()
    if (not catalogData and isRetryableFailure(dReason)) then
        catalogData, signedContent, signature, dReason = tryLoadExternalCatalog()
    end

    local source = "External"
    if (not processGuidesFile(catalogData, "External")) then
        -- Try bundled catalog with one retry
        local gData, gSigned, gSig, gReason = loadCatalogData("BundledGuides")
        if (not gData and isRetryableFailure(gReason)) then
            gData, gSigned, gSig, gReason = loadCatalogData("BundledGuides")
        end
        processGuidesFile(gData, "Bundled")
        signedContent = gSigned
        signature = gSig
        source = "Bundled"
    end

    -- Verify signature in the background
    if (signedContent and signature) then
        startBackgroundVerify(signedContent, signature, source)
    end
    loadingCatalog = nil
end

function CatalogService.Reload()
    cancelBackgroundVerify()
    guideInfos = nil
    guideInfoByID = nil
    slotLookup = nil
    minAddonVersionValue = nil
    guideVersionValue = nil
    catalogDecryptKey = nil
    ensureLoaded()
end

function CatalogService.GetGuideInfos()
    ensureLoaded()
    return guideInfos
end

function CatalogService.GetGuideTemplate(guideID)
    ensureLoaded()
    local slot = slotLookup[guideID]
    if (not slot) then return nil end
    return ("%s-%s%s"):format(addonName, slot.prefix, slot.slot)
end

function CatalogService.GetDecryptKey(guideID)
    if (not catalogDecryptKey) then return nil end
    local info = guideInfoByID and guideInfoByID[guideID]
    if (not info or not info.encrypted) then return nil end
    if (info.expires and GetServerTime() > info.expires) then return nil end
    return catalogDecryptKey
end

function CatalogService.GetContentHash(guideID)
    local info = guideInfoByID and guideInfoByID[guideID]
    if (not info) then return nil end
    return info.contentHash
end

function CatalogService.GetSlotInfo(guideID)
    return slotLookup[guideID]
end

function CatalogService.IsConditionMet(guideID)
    ensureLoaded()
    local info = guideInfoByID and guideInfoByID[guideID]
    return CheckCondition(info)
end

function CatalogService.IsInstalled(guideID)
    ensureLoaded()
    return slotLookup[guideID] ~= nil
end

function CatalogService.CheckCompatibility()
    ensureLoaded()
    if (minAddonVersionValue and addonVersion < minAddonVersionValue) then
        return "addon"
    end
    if (minGuideVersion and guideVersionValue and guideVersionValue < minGuideVersion) then
        return "guide"
    end
    return nil
end

local function isStub(guideID)
    local info = guideInfoByID and guideInfoByID[guideID]
    return info and info.stub == true
end

local function showSetupPopup(header, message, useReload, buttonText)
    TogglePopup(
        nil, nil, nil, nil, nil,
        "|cFFFFAA00" .. header .. ":|r\n\n|cFFFFD100" .. addonTitle .. "|r\n\n" .. message,
        useReload,
        buttonText
    )
end

function CatalogService.HandleStubGuide(guideID)
    if (not isStub(guideID)) then
        return false
    end

    CatalogService.Reload()

    if (not isStub(guideID)) then
        return false
    end

    local name = Brand.installerName

    if (previousBattleTag) then
        showSetupPopup("ADDITIONAL SETUP REQUIRED", "Please re-run the " .. name .. " to\nfinish setting up your guides.")
        return true
    end

    local _, liveTag = BNGetInfo()
    if (liveTag) then
        SavedVariables.battleTag = liveTag
        SavedVariables.needsInstallerRun = true
        showSetupPopup("ADDITIONAL SETUP REQUIRED", "Click Reload, and when prompted,\nre-run the " .. name .. ".", true)
        return true
    end

    showSetupPopup("SETUP PENDING", "You can complete your guide installation\nwhen Battle.net comes back online.")
    return true
end

function CatalogService.CheckStartupPrompt()
    if (not needsInstallerRun) then return end
    needsInstallerRun = nil
    SavedVariables.needsInstallerRun = nil
    showSetupPopup("ADDITIONAL SETUP REQUIRED", "Please re-run the " .. Brand.installerName .. " to\nfinish setting up your guides.", false, "I'm done!")
end
