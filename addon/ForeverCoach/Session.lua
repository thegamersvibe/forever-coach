-- Forever Coach: per-session play stats from data WoW Forever gives every addon.
-- Forever hides exact health/power from addons ("secret values") and has no addon combat log, so:
--   * every number from a unit API goes through num(), which drops secret values
--   * downtime = standing still out of combat (short stops only; long ones count as AFK/vendor)
--   * proc use = the spell becoming usable (C_Spell.IsSpellUsable) vs. you casting it (UNIT_SPELLCAST_SUCCEEDED)
-- Nothing here reads memory or automates input.
local _, FC = ...
local S = {}
FC.Session = S

local MAX_SESSIONS = 30
local IDLE_AFK = 120        -- seconds standing still before it counts as AFK/vendor, not downtime
local PROC_POLL = 0.2
local cur, tick
local procs = {}            -- name -> { spell = name, window, open = expiry|nil, total, used }
local idle = 0

-- Secret-safe number: nil if the client hides the value from addons.
local function num(v)
    if v == nil then return nil end
    if issecretvalue and issecretvalue(v) then return nil end
    if type(v) ~= "number" then return nil end
    return v
end
local function flag(v)
    if issecretvalue and issecretvalue(v) then return nil end
    return v
end
FC.num = num

local function now() return GetTime() end

local function noteError(where, err)
    local c = FC:Char()
    c.lastError = { where = where, err = tostring(err), time = time(), version = FC.VERSION }
end

local function newSession()
    return {
        start = time(), level = UnitLevel("player"), xp = 0, seconds = 0, combat = 0, recovery = 0, dead = 0,
        deaths = {}, kills = 0, capped = 0, powerSeconds = 0, procs = {}, afk = 0,
    }
end

local function spellName(id) return FC:SpellName(id) end

local function usable(name)
    if C_Spell and C_Spell.IsSpellUsable then
        local ok, u, lowPower = pcall(C_Spell.IsSpellUsable, name)
        if ok then return flag(u) == true or flag(lowPower) == true end
    elseif IsUsableSpell then
        local ok, u, lowPower = pcall(IsUsableSpell, name)
        if ok then return u == true or lowPower == true end
    end
    return false
end

function S:Start()
    cur = newSession()
    S.lastXP, S.lastXPMax = num(UnitXP("player")), num(UnitXPMax("player"))
    procs, idle = {}, 0
    local _, cls = UnitClass("player")
    for _, p in ipairs(FC:Rules().procSpells or {}) do
        if p.class == cls and FC:KnowsSpell(p.spellId) then
            local name = spellName(p.spellId) or p.name
            procs[name] = { spell = name, label = p.name, window = p.window or 5, total = 0, used = 0, was = false }
        end
    end
    if not tick then
        tick = CreateFrame("Frame")
        local acc, pacc = 0, 0
        tick:SetScript("OnUpdate", function(_, el)
            acc, pacc = acc + el, pacc + el
            if pacc >= PROC_POLL then
                local ok, err = pcall(S.PollProcs, S); pacc = 0
                if not ok then noteError("PollProcs", err) end
            end
            if acc >= 1 then
                local ok, err = pcall(S.Tick, S, acc); acc = 0
                if not ok then noteError("Tick", err) end
            end
        end)
    end
end

-- A proc "chance" starts when the spell turns usable in combat; it's "used" if you cast it before the window ends.
function S:PollProcs()
    if not cur then return end
    local inCombat = flag(UnitAffectingCombat("player")) == true
    local t = now()
    for _, w in pairs(procs) do
        local u = usable(w.spell)
        if u and not w.was and (inCombat or w.window > 10) then
            w.total = w.total + 1; w.open = t + w.window
        end
        -- casting makes the spell unusable a moment before the cast event lands, so a window only expires by time
        if w.open and t > w.open + 0.5 then w.open = nil end
        w.was = u
    end
end

function S:Cast(spellID)
    if not cur or not spellID then return end
    local name = spellName(spellID)
    local w = name and procs[name]
    if w and w.open then w.used = w.used + 1; w.open = nil end
end

function S:Tick(dt)
    if not cur then return end
    cur.seconds = cur.seconds + dt
    if flag(UnitIsDeadOrGhost("player")) then cur.dead = cur.dead + dt; idle = 0; return end
    if UnitOnTaxi and flag(UnitOnTaxi("player")) then idle = 0; return end
    if flag(UnitAffectingCombat("player")) then
        cur.combat = cur.combat + dt; idle = 0
        local ptype = num(UnitPowerType("player"))
        if ptype == 1 then -- rage, only when the client lets addons read it
            local p, mx = num(UnitPower("player", 1)), num(UnitPowerMax("player", 1))
            if p and mx and mx > 0 then
                cur.powerSeconds = cur.powerSeconds + dt
                if p >= mx * 0.9 then cur.capped = cur.capped + dt end
            end
        end
    else
        local moving = IsPlayerMoving and flag(IsPlayerMoving())
        if moving then
            idle = 0
        else
            idle = idle + dt
            if idle <= IDLE_AFK then cur.recovery = cur.recovery + dt else cur.afk = cur.afk + dt end
            if idle > IDLE_AFK and idle - dt <= IDLE_AFK then
                -- just crossed into AFK: the last IDLE_AFK seconds weren't downtime either
                cur.recovery = math.max(0, cur.recovery - IDLE_AFK); cur.afk = cur.afk + IDLE_AFK
            end
        end
    end
end

function S:Death()
    if not cur then return end
    table.insert(cur.deaths, { level = UnitLevel("player"), zone = GetRealZoneText and GetRealZoneText() or "?", time = time() })
end

function S:XP()
    if not cur then return end
    local xp, xpMax = num(UnitXP("player")), num(UnitXPMax("player"))
    if not (xp and xpMax) then return end
    if S.lastXP and S.lastXPMax then
        if xp >= S.lastXP then cur.xp = cur.xp + (xp - S.lastXP)
        else cur.xp = cur.xp + (S.lastXPMax - S.lastXP) + xp end -- level up
        if flag(UnitAffectingCombat("player")) and xp ~= S.lastXP then cur.kills = cur.kills + 1 end
    end
    S.lastXP, S.lastXPMax = xp, xpMax
end

local function syncProcs()
    if not cur then return end
    for _, w in pairs(procs) do cur.procs[w.label] = { windows = w.total, used = w.used } end
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
ev:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED")
ev:SetScript("OnEvent", function(_, e, unit, _, spellID)
    local ok, err = true, nil
    if e == "UNIT_SPELLCAST_SUCCEEDED" then
        if unit == "player" then ok, err = pcall(S.Cast, S, spellID) end
    elseif e == "PLAYER_DEAD" then ok, err = pcall(S.Death, S)
    elseif e == "PLAYER_XP_UPDATE" then ok, err = pcall(S.XP, S) end
    if not ok then noteError(e, err) end
end)
