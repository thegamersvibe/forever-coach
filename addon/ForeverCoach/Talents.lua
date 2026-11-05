-- Forever Coach: compare the character's talents with a guide's leveling order (rules.talentBuilds).
-- Only the order (level -> talent name) is stored; credit and a link to the guide are shown with every tip.
local _, FC = ...
local T = {}
FC.Talents = T

-- Returns nil when there's no build for this class/spec, else a plan:
-- { source, url, next = {level, name, points}, timeline = {...}, offPlan = n, unspent }
function T:Plan(snap, spec)
    if not spec then return nil end
    local key = tostring(snap.class) .. ":" .. tostring(spec)
    local b = (FC:Rules().talentBuilds or {})[key]
    if type(b) ~= "table" or type(b.order) ~= "table" then return nil end
    local t = snap.talents or {}
    local ranks = t.ranks or {}
    local lvl = snap.level or 1
    -- expected ranks per talent at this level
    local want, wantAny = {}, 0
    local timeline = {}
    local totals, seen = {}, {}
    for _, step in ipairs(b.order) do totals[step[2]] = (totals[step[2]] or 0) + 1 end
    for _, step in ipairs(b.order) do
        local L, name = step[1], step[2]
        local state = (L <= lvl) and "due" or "later"
        seen[name] = (seen[name] or 0) + 1
        local label = name == "*" and ("any " .. (b.tree or "") .. " talent")
            or (totals[name] > 1 and (name .. " " .. seen[name] .. "/" .. totals[name]) or name)
        timeline[#timeline + 1] = { level = L, name = label, raw = name, state = state }
        if L <= lvl then
            if name == "*" then wantAny = wantAny + 1 else want[name] = (want[name] or 0) + 1 end
        end
    end
    -- mark which due steps are satisfied, in order
    local used = {}
    local treeSpent = 0
    for _, tab in ipairs(t.tabs or {}) do if tab.name == b.tree then treeSpent = tab.spent or 0 end end
    local namedSpent = 0
    for name, n in pairs(want) do namedSpent = namedSpent + math.min(n, ranks[name] or 0) end
    local freeTree = math.max(0, treeSpent - namedSpent)
    local nextStep
    for _, s in ipairs(timeline) do
        if s.state == "due" then
            local raw = s.raw
            if raw == "*" then
                if freeTree > 0 then freeTree = freeTree - 1; s.state = "done" else s.state = "todo" end
            else
                used[raw] = (used[raw] or 0) + 1
                if t.detailed and (ranks[raw] or 0) >= used[raw] then s.state = "done"
                elseif not t.detailed then s.state = "unknown"
                else s.state = "todo" end
            end
            if s.state == "todo" and not nextStep then nextStep = s end
        end
    end
    -- points in talents the guide doesn't list up to this level (only when talent detail is readable)
    local offPlan = 0
    if t.detailed then
        local guideNames = {}
        for _, step in ipairs(b.order) do if step[2] ~= "*" then guideNames[step[2]] = true end end
        local anySlack = wantAny
        for name, r in pairs(ranks) do
            local extra = r - (want[name] or 0)
            if extra > 0 then
                if not guideNames[name] and anySlack > 0 then
                    local use = math.min(extra, anySlack); anySlack = anySlack - use; extra = extra - use
                end
                offPlan = offPlan + math.max(0, extra)
            end
        end
    end
    -- what's next after the current level
    local upcoming = {}
    for _, s in ipairs(timeline) do if s.state == "later" and #upcoming < 3 then upcoming[#upcoming + 1] = s end end
    return { source = b.source, url = b.url, note = b.note, next = nextStep, upcoming = upcoming, offPlan = offPlan,
        detailed = t.detailed, unspent = t.unspent, timeline = timeline }
end
