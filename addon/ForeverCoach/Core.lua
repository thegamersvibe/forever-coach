-- Forever Coach: core state, snapshot of the character, saved data.
local ADDON, FC = ...
FC = FC or {}
_G.ForeverCoach = FC
FC.VERSION = "1.0.2"
FC.SCHEMA = 1

local function safe(f, ...)
    if type(f) ~= "function" then return nil end
    local ok, a, b, c, d, e, g, h, i, j, k = pcall(f, ...)
    if ok then return a, b, c, d, e, g, h, i, j, k end
end
FC.safe = safe

function FC:Rules()
    local r = _G.ForeverCoach_Rules
    if type(r) ~= "table" or r.schema ~= 1 then return { thresholds = {}, raceOnlyQuests = {}, spellMilestones = {}, procSpells = {} } end
    return r
end

function FC:Print(msg) DEFAULT_CHAT_FRAME:AddMessage("|cff4fc3f7Forever Coach|r: " .. tostring(msg)) end

function FC:CharKey()
    local name = UnitName("player") or "?"
    local realm = (GetRealmName and GetRealmName()) or "?"
    return name .. "-" .. realm
end

function FC:Char()
    ForeverCoachDB = ForeverCoachDB or {}
    local db = ForeverCoachDB
    db.schema = FC.SCHEMA
    db.addonVersion = FC.VERSION
    db.chars = db.chars or {}
    local key = self:CharKey()
    db.chars[key] = db.chars[key] or { sessions = {} }
    return db.chars[key]
end

-- Spell known check that tolerates API differences between clients.
function FC:KnowsSpell(id)
    if IsPlayerSpell and safe(IsPlayerSpell, id) then return true end
    if IsSpellKnown and safe(IsSpellKnown, id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and safe(C_SpellBook.IsSpellKnown, id) then return true end
    return false
end

function FC:SpellName(id)
    if C_Spell and C_Spell.GetSpellInfo then
        local info = safe(C_Spell.GetSpellInfo, id)
        if type(info) == "table" and info.name then return info.name end
    end
    if GetSpellInfo then return (safe(GetSpellInfo, id)) end
end

local function itemIdFromLink(link)
    return link and tonumber(link:match("item:(%d+)")) or nil
end
FC.itemIdFromLink = itemIdFromLink

function FC:Talents()
    local t = { tabs = {}, unspent = nil }
    if UnitCharacterPoints then t.unspent = safe(UnitCharacterPoints, "player") end
    local n = (GetNumTalentTabs and safe(GetNumTalentTabs)) or 0
    for tab = 1, n do
        local a, b, c, d = safe(GetTalentTabInfo, tab)
        local spent
        for _, v in ipairs({ c, d, b }) do if type(v) == "number" then spent = v break end end
        if spent == nil and GetNumTalents and GetTalentInfo then
            spent = 0
            for i = 1, (safe(GetNumTalents, tab) or 0) do
                local _, _, _, _, rank = safe(GetTalentInfo, tab, i)
                if type(rank) == "number" then spent = spent + rank end
            end
        end
        t.tabs[tab] = { name = type(a) == "string" and a or ("Tree " .. tab), spent = spent or 0 }
    end
    return t
end

function FC:Skills()
    local out = {}
    local n = (GetNumSkillLines and safe(GetNumSkillLines)) or 0
    for i = 1, n do
        local name, header, _, rank, _, _, maxRank = safe(GetSkillLineInfo, i)
        if name and not header and type(rank) == "number" then out[name] = { rank = rank, max = maxRank } end
    end
    return out
end

function FC:Equipped()
    local out = {}
    for slot = 1, 19 do
        local link = safe(GetInventoryItemLink, "player", slot)
        if link then out[slot] = { id = itemIdFromLink(link), link = link } end
    end
    return out
end

function FC:BagItems()
    local out = {}
    local C = C_Container
    for bag = 0, 4 do
        local n = (C and C.GetContainerNumSlots and safe(C.GetContainerNumSlots, bag)) or (GetContainerNumSlots and safe(GetContainerNumSlots, bag)) or 0
        for s = 1, n do
            local link = (C and C.GetContainerItemLink and safe(C.GetContainerItemLink, bag, s)) or (GetContainerItemLink and safe(GetContainerItemLink, bag, s))
            local id = itemIdFromLink(link)
            if id then out[#out + 1] = { id = id, link = link } end
        end
    end
    return out
end

function FC:Journey()
    local j = _G.Journey_Character
    if type(j) ~= "table" then return nil end
    local g = j.lastGuide
    local bm = g and j.bookmarks and j.bookmarks[g]
    return { guide = g, step = bm and bm.stepID }
end

function FC:Snapshot()
    local _, classFile = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local faction = UnitFactionGroup("player")
    local s = {
        time = time(), name = UnitName("player"), realm = GetRealmName and GetRealmName(),
        class = classFile, race = raceFile, faction = faction, level = UnitLevel("player"),
        xp = UnitXP("player"), xpMax = UnitXPMax("player"), rested = GetXPExhaustion and GetXPExhaustion() or 0,
        money = GetMoney and GetMoney() or 0,
        talents = self:Talents(), skills = self:Skills(), equipped = self:Equipped(), bags = self:BagItems(),
        journey = self:Journey(), spells = {},
    }
    for _, m in ipairs(self:Rules().spellMilestones or {}) do
        if m.class == classFile then s.spells[m.spellId] = self:KnowsSpell(m.spellId) end
    end
    return s
end

function FC:Refresh(reason)
    local c = self:Char()
    c.snapshot = self:Snapshot()
    if FC.Gear then c.gear = FC.Gear:Audit(c.snapshot) end
    if FC.Audit then c.findings = FC.Audit:Run(c) end
    c.updated = time()
    c.reason = reason
    if FC.UI and FC.UI.Update then FC.UI:Update() end
end

local f = CreateFrame("Frame")
FC.frame = f
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_LEVEL_UP")
f:RegisterEvent("PLAYER_LOGOUT")
f:RegisterEvent("TRAINER_SHOW")
f:RegisterEvent("PLAYER_EQUIPMENT_CHANGED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        FC:Char()
    elseif event == "PLAYER_LOGIN" then
        if C_Timer then C_Timer.After(5, function() FC:Refresh("login") end) else FC:Refresh("login") end
        if FC.Session then FC.Session:Start() end
    elseif event == "PLAYER_LEVEL_UP" then
        if C_Timer then C_Timer.After(2, function() FC:Refresh("levelup") end) end
    elseif event == "PLAYER_EQUIPMENT_CHANGED" then
        if C_Timer and not FC._eqPending then
            FC._eqPending = true
            C_Timer.After(2, function() FC._eqPending = nil; FC:Refresh("equip") end)
        end
    elseif event == "TRAINER_SHOW" then
        local c = FC:Char()
        local avail = 0
        for i = 1, ((GetNumTrainerServices and safe(GetNumTrainerServices)) or 0) do
            local _, _, kind = safe(GetTrainerServiceInfo, i)
            if kind == "available" then avail = avail + 1 end
        end
        c.trainer = { level = UnitLevel("player"), time = time(), available = avail }
    elseif event == "PLAYER_LOGOUT" then
        if FC.Session then FC.Session:Finish() end
        FC:Refresh("logout")
    end
end)
