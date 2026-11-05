-- Forever Coach: per-session play stats from events the client gives every addon.
-- Nothing here reads memory or automates input.
local _, FC = ...
local safe = FC.safe
local S = {}
FC.Session = S

local MAX_SESSIONS = 30
local cur, tick
local procWindows = {} -- spellId -> {open=expiry or nil, total=n, used=n}

local function now() return GetTime() end

local function newSession()
    return {
        start = time(), level = UnitLevel("player"), xp = 0, seconds = 0, combat = 0, recovery = 0, dead = 0,
        deaths = {}, kills = 0, capped = 0, powerSeconds = 0, procs = {},
    }
end

function S:Start()
    cur = newSession()
    S.lastXP, S.lastXPMax = UnitXP("player"), UnitXPMax("player")
    procWindows = {}
    for _, p in ipairs(FC:Rules().procSpells or {}) do
        local _, cls = UnitClass("player")
        if p.class == cls and FC:KnowsSpell(p.spellId) then
            procWindows[p.spellId] = { name = p.name, trigger = p.trigger, window = p.window or 5, total = 0, used = 0 }
        end
    end
    if not tick then
        tick = CreateFrame("Frame")
        local acc = 0
        tick:SetScript("OnUpdate", function(_, el)
            acc = acc + el
            if acc < 1 then return end
            local dt = acc; acc = 0
            S:Tick(dt)
        end)
    end
end

function S:Tick(dt)
    if not cur then return end
    cur.seconds = cur.seconds + dt
    if UnitIsDeadOrGhost("player") then cur.dead = cur.dead + dt return end
    if UnitOnTaxi and UnitOnTaxi("player") then return end
    if UnitAffectingCombat("player") then
        cur.combat = cur.combat + dt
        local ptype = UnitPowerType("player")
        local max = UnitPowerMax("player", ptype) or 0
        if ptype == 1 and max > 0 then -- rage
            cur.powerSeconds = cur.powerSeconds + dt
            if (UnitPower("player", ptype) or 0) >= max * 0.9 then cur.capped = cur.capped + dt end
        end
    else
        local hp, hpMax = UnitHealth("player"), UnitHealthMax("player")
        local mp, mpMax = UnitPower("player", 0), UnitPowerMax("player", 0)
        local low = (hpMax > 0 and hp / hpMax < 0.7) or (mpMax and mpMax > 0 and UnitPowerType("player") == 0 and mp / mpMax < 0.4)
        if low then cur.recovery = cur.recovery + dt end -- eating/drinking/bandaging/sitting low
    end
    -- close expired proc windows
    local t = now()
    for _, w in pairs(procWindows) do
        if w.open and t > w.open then w.open = nil end
    end
end

local function openWindows(trigger)
    local t = now()
    for _, w in pairs(procWindows) do
        if w.trigger == trigger and not w.open then
            w.open = t + w.window; w.total = w.total + 1
        elseif w.trigger == trigger then
            w.open = t + w.window
        end
    end
end

local lastHit = {}
local DEFEND = { DODGE = true, PARRY = true, BLOCK = true }

function S:CLEU()
    if not cur then return end
    local info = { CombatLogGetCurrentEventInfo() }
    local sub, srcGUID, srcName, dstGUID = info[2], info[4], info[5], info[8]
    local me = UnitGUID("player")
    if dstGUID == me then
        if sub == "SWING_DAMAGE" then
            lastHit = { name = srcName, spell = "melee", amount = info[12], t = now() }
            if (info[16] or 0) > 0 then openWindows("defend") end -- blocked amount
        elseif sub == "SPELL_DAMAGE" or sub == "RANGE_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" then
            lastHit = { name = srcName, spell = info[13], amount = info[15], t = now() }
        elseif sub == "SWING_MISSED" and DEFEND[info[12]] then
            openWindows("defend"); if info[12] == "PARRY" then openWindows("parry") end
        elseif (sub == "SPELL_MISSED" or sub == "RANGE_MISSED") and DEFEND[info[15]] then
            openWindows("defend")
        end
    elseif srcGUID == me then
        if (sub == "SWING_MISSED" and info[12] == "DODGE") or (sub == "SPELL_MISSED" and info[15] == "DODGE") then
            openWindows("targetDodge")
        elseif sub == "PARTY_KILL" then
            cur.kills = cur.kills + 1; openWindows("kill")
        elseif sub == "SPELL_CAST_SUCCESS" then
            local name = info[13]
            for _, w in pairs(procWindows) do
                if w.open and w.name == name then w.used = w.used + 1; w.open = nil end
            end
        end
    end
end

function S:Death()
    if not cur then return end
    local d = { level = UnitLevel("player"), zone = GetRealZoneText and GetRealZoneText() or "?", time = time() }
    if lastHit.t and now() - lastHit.t < 10 then d.by = lastHit.name; d.spell = lastHit.spell end
    table.insert(cur.deaths, d)
end

function S:XP()
    if not cur then return end
    local xp, xpMax = UnitXP("player"), UnitXPMax("player")
    if S.lastXP then
        if xp >= S.lastXP then cur.xp = cur.xp + (xp - S.lastXP)
        else cur.xp = cur.xp + (S.lastXPMax - S.lastXP) + xp end -- level up
    end
    S.lastXP, S.lastXPMax = xp, xpMax
end

local function syncProcs()
    if not cur then return end
    for _, w in pairs(procWindows) do cur.procs[w.name] = { windows = w.total, used = w.used } end
end

function S:Finish()
    if not cur or cur.seconds < 30 then return end
    cur.finish = time(); cur.endLevel = UnitLevel("player")
    syncProcs()
    local c = FC:Char()
    table.insert(c.sessions, cur)
    while #c.sessions > MAX_SESSIONS do table.remove(c.sessions, 1) end
    cur = nil
end

function S:Current() syncProcs(); return cur end

local ev = CreateFrame("Frame")
ev:RegisterEvent("PLAYER_DEAD")
ev:RegisterEvent("PLAYER_XP_UPDATE")
if CombatLogGetCurrentEventInfo then ev:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED") end
ev:SetScript("OnEvent", function(_, e)
    if e == "COMBAT_LOG_EVENT_UNFILTERED" then pcall(S.CLEU, S)
    elseif e == "PLAYER_DEAD" then S:Death()
    elseif e == "PLAYER_XP_UPDATE" then S:XP() end
end)
