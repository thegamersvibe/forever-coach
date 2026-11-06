select(2, ...).SetupGlobalFacade()

local AddonVersion = addonVersion
local GuideVersion = "3.03.01"
local GuideVersionMinimum = "3.03.01"

GuideModules = { }

local modules

local GuideModulesBase = {
	--Starter = {
	--	name = "Starter",
	--},
	--SoD = {
	--	name = "Season of Discovery",
	--},
	--Era = {
	--	name = "Classic Era",
	--},
	--TBC = {
	--	name = "The Burning Crusade",
	--},
	--Wrath = {
	--	name = "Wrath of the Lich King",
	--},
	--Cata = {
	--	name = "Cataclysm",
	--},
	--MoP = {
	--	name = "Mists of Pandaria",
	--}
}

local major, minor, _ = GuideVersion:match("(%d+)%.(%d+)%.(%d+)")

for _, v in pairs(GuideModulesBase) do
	v.latest = v.latest or GuideVersion
	v.minimum = v.minimum or GuideVersionMinimum or ("%s.%s.%s"):format(major, minor, "01")
end
-- Module properties
-- version: the version of the guide module
-- latest: latest known version of the guide module as of this addon's release
-- minimum: minimum version of the guide module that is compatible with this version of the addon
-- maximum: maximum version of the guide module that is compatible with this version of the addon
-- requires: minimum version of the addon that the guide module requires in order to function
-- preferred: latest known version of the addon available at the time of the guide module's release
-- installed: (boolean or nil) determines that the guide was able to be loaded, but not necessarily that it is compatible
-- compatible: (boolean or nil) determines that the guide is compatible with the addon

local LatestAddonVersion = AddonVersion

function GuideModules.GetAddonVersion()
	return AddonVersion
end

local defaultModule = {
	installed = true,
	compatible = true,
	version = "4.0.0",
}

function GuideModules.GetModule(moduleID)
	return modules[moduleID] or defaultModule
end


-- local expiration = 1793505600 -- Nov. 1 2026

function GuideModules.IsExpired()
	return false --GetServerTime() > expiration
end

local legacyModules = { "Era", "TBC", "Wrath" }
local hasLegacy

function GuideModules.HasLegacyModules()
	if (hasLegacy == nil) then
		hasLegacy = false
		for _, module in ipairs(legacyModules) do
			if (ReadHTMLTemplate(addonName .. "-Legacy-" .. module)) then
				hasLegacy = true
				break
			end
		end
	end
	return hasLegacy
end

function GuideModules.Reload()
	modules = { }
	for moduleName, moduleInfoBase in pairs(GuideModulesBase) do
		modules[moduleName] = {
			latest = moduleInfoBase.latest,
			minimum = moduleInfoBase.minimum,
			name = moduleInfoBase.name,
		}
		local moduleInfo = modules[moduleName]
		local metadata = LoadHTMLData(addonName .. "-" .. moduleName .. "-metadata")
		if (metadata) then
			moduleInfo.version = metadata.version
			moduleInfo.requires = metadata.requires
			moduleInfo.installed = true
			moduleInfo.preferred = metadata.preferred
		end
	end
	UI.MarkDirty()
	Condition_ResetGuides()
end
