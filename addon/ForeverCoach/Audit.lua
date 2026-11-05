-- Forever Coach: turns snapshot + gear + sessions into ranked findings.
-- Each finding: { impact = 1..100, area = "Gear|Build|Play|Next", text = "...", fix = "..." }
local _, FC = ...
local A = {}
FC.Audit = A

local function add(list, impact, area, text, fix) list[#list + 1] = { impact = impact, area = area, text = text, fix = fix } end

local function recentSessions(c, n)
    local out, s = {}, c.sessions or {}
    for i = #s, math.max(1, #s - (n or 5) + 1), -1 do out[#out + 1] = s[i] end
    local live = FC.Session and FC.Session:Current()
    if live and live.seconds > 60 then table.insert(out, 1, live) end
    return out
end

function A:Run(c)
    local snap, gear, T = c.snapshot, c.gear or {}, FC:Rules().thresholds or {}
    local F = {}
    if not snap then return F end

    -- Build: talent points
    local unspent = snap.talents and snap.talents.unspent
    if type(unspent) == "number" and unspent > 0 and snap.level >= 10 then
        add(F, 70 + math.min(unspent, 5) * 5, "Build", unspent .. " unspent talent point" .. (unspent > 1 and "s" or ""), "Open talents (N) and spend them")
    end

    -- Build: class milestone spells
    for _, m in ipairs(FC:Rules().spellMilestones or {}) do
        if m.class == snap.class and snap.level >= m.level and snap.spells and snap.spells[m.spellId] == false then
            local over = snap.level - m.level
            add(F, math.min(90, 55 + over * 5), "Build", m.name .. " not learned (available since " .. m.level .. ")", m.how)
        end
    end

    -- Build: trainer
    if c.trainer and c.trainer.available and c.trainer.available > 0 then
        add(F, 60, "Build", c.trainer.available .. " skill(s) were trainable at your last trainer visit (level " .. c.trainer.level .. ")", "Visit your class trainer")
    end
    local lastTrain = c.trainer and c.trainer.level or 0
    if snap.level >= 4 and snap.level % 2 == 0 and lastTrain < snap.level then
        add(F, 45, "Build", "New ranks unlock at even levels; you haven't visited a trainer at " .. snap.level, "Train before your next quest hub")
    end

    -- Gear
    if gear.status == "missing" then
        add(F, 30, "Gear", "GearQuest Forever not installed: gear audit off", "Install GearQuest Forever to enable gear checks")
    elseif gear.status == "classdata" then
        add(F, 30, "Gear", "GearQuest class module for your class is disabled", "Enable 'GearQuest Forever: <class>' in AddOns, then /reload")
    elseif gear.slots then
        if gear.specSource == "default" then
            add(F, 40, "Gear", "Gear scored for default spec '" .. tostring(gear.spec) .. "'", "Pick your spec in GearQuest or /coach spec <id>")
        end
        local seen = {}
        for _, e in pairs(gear.slots) do
            local b = e.best
            if b and not seen[e.slot .. b.id] then
                local gap = e.gapPct or 0
                if not e.id and snap.level >= 5 then
                    seen[e.slot .. b.id] = true
                    add(F, 65, "Gear", "Empty " .. (e.label or e.slot) .. " slot", (b.name or ("item " .. b.id)) .. " — " .. FC.Gear.Short(b.how or b.source))
                elseif gap >= (T.gearUpgradePct or 12) then
                    seen[e.slot .. b.id] = true
                    add(F, math.min(85, 30 + gap / 2), "Gear", (e.label or e.slot) .. " is " .. gap .. "% behind the best for your level",
                        (b.name or ("item " .. b.id)) .. " — " .. FC.Gear.Short(b.how or b.source))
                end
            end
        end
    end

    -- Play (needs session data)
    local ss = recentSessions(c, 5)
    local secs, combat, recovery, dead, deaths, capped, powerSecs, xp = 0, 0, 0, 0, {}, 0, 0, 0
    local procs = {}
    for _, s in ipairs(ss) do
        secs = secs + s.seconds; combat = combat + s.combat; recovery = recovery + s.recovery; dead = dead + s.dead
        capped = capped + s.capped; powerSecs = powerSecs + s.powerSeconds; xp = xp + (s.xp or 0)
        for _, d in ipairs(s.deaths or {}) do deaths[#deaths + 1] = d end
        for name, p in pairs(s.procs or {}) do
            procs[name] = procs[name] or { windows = 0, used = 0 }
            procs[name].windows = procs[name].windows + p.windows; procs[name].used = procs[name].used + p.used
        end
    end
    if secs >= (T.minSessionMinutes or 10) * 60 then
        local hours = secs / 3600
        local dph = #deaths / hours
        if dph >= (T.deathsPerHour or 1) then
            local by = {}
            for _, d in ipairs(deaths) do if d.by then by[d.by] = (by[d.by] or 0) + 1 end end
            local top, n = nil, 0
            for k, v in pairs(by) do if v > n then top, n = k, v end end
            add(F, math.min(90, 50 + dph * 10), "Play", string.format("%.1f deaths/hour (%d recent)", dph, #deaths),
                top and ("Most from: " .. top .. ". Pull fewer, use cooldowns earlier, keep a potion.") or "Pull fewer and keep a potion ready")
        end
        local active = secs - dead
        local down = active > 0 and recovery / active * 100 or 0
        if down >= (T.downtimePct or 25) then
            local fa = snap.skills and snap.skills["First Aid"]
            local tip = (not fa or fa.rank < snap.level * (T.firstAidPerLevel or 4)) and "Level First Aid and carry bandages; " or ""
            add(F, math.min(80, 30 + down), "Play", string.format("%d%% of your time is spent recovering", math.floor(down)),
                tip .. "buy food/water for your level; use Victory Rush / self-heals in combat")
        end
        if powerSecs > 120 then
            local cp = capped / powerSecs * 100
            if cp >= (T.rageCappedPct or 8) then
                add(F, 40 + cp, "Play", string.format("Rage near cap %d%% of combat", math.floor(cp)), "Spend it: Heroic Strike/Cleave when above ~60 rage")
            end
        end
        for name, p in pairs(procs) do
            if p.windows >= (T.procMinWindows or 8) then
                local waste = (p.windows - p.used) / p.windows * 100
                if waste >= (T.procWastedPct or 30) then
                    add(F, math.min(85, 35 + waste / 2), "Play", string.format("%s: used %d of %d chances (%d%% missed)", name, p.used, p.windows, math.floor(waste)),
                        "Bind " .. name .. " to an easy key and press it whenever it lights up")
                end
            end
        end
        if xp > 0 and hours > 0 then c.xpPerHour = math.floor(xp / hours) end
    end

    -- Rested XP
    if snap.rested == 0 and snap.level < 60 then
        add(F, 15, "Next", "No rested XP", "Log out in an inn or city to earn rested XP")
    end

    table.sort(F, function(a, b) return a.impact > b.impact end)
    return F
end
