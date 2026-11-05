-- Forever Coach: dungeon prep from the player's own ForeverDungeonJournal install (read at runtime).
-- Lists the dungeons that fit your level and the quests to pick up first. No XP totals: the journal's
-- XP text and live values can disagree, so only quest counts and names are shown.
local _, FC = ...
local D = {}
FC.Dungeons = D

local function range(s)
    local lo, hi = tostring(s or ""):match("(%d+)%s*%-%s*(%d+)")
    return tonumber(lo), tonumber(hi)
end

function D:Plan(snap)
    local fdj = _G.ForeverDungeonJournal_NS
    if type(fdj) ~= "table" or type(fdj.DB) ~= "table" then return { status = "missing", list = {} } end
    local lvl, fac, cls = snap.level or 1, snap.faction, snap.class
    local factionOnly = FC:Rules().factionDungeons or {}
    local route = FC.Route:ForPlayer(snap)
    local list = {}
    for name, d in pairs(fdj.DB) do
        local lo, hi = range(type(d) == "table" and d.level)
        local okFaction = not factionOnly[name] or factionOnly[name] == fac
        if lo and hi and okFaction and lvl >= lo - 3 and lvl <= hi - 3 then
            local quests, inLog = {}, 0
            for _, q in ipairs(type(d.quests) == "table" and d.quests or {}) do
                if type(q) == "table" and type(q.name) == "string" then
                    local qf = q.faction or "Both"
                    local okQ = (qf == "Both" or qf == fac) and (not q.classOnly or q.classOnly == cls)
                    local req = tonumber(q.requires) or 0
                    if okQ and req <= lvl + 2 then
                        local done = FC:QuestDone(q.id)
                        if done ~= true then
                            local on = FC:OnQuest(q.id)
                            if on then inLog = inLog + 1 end
                            quests[#quests + 1] = { name = q.name, pickup = q.pickup, requires = req, inLog = on or nil,
                                classOnly = q.classOnly, tooLow = req > lvl or nil }
                        end
                    end
                end
            end
            local zone = FC.Route:Parent(name)
            local onRoute = route[zone] ~= nil
            local fit = (lvl >= lo and lvl <= hi) and 2 or 1
            list[#list + 1] = { name = name, level = d.level, location = d.location, quests = quests, inLog = inLog,
                onRoute = onRoute, score = fit * 10 + (onRoute and 5 or 0) + math.min(#quests, 8), lo = lo }
        end
    end
    table.sort(list, function(a, b) if a.score ~= b.score then return a.score > b.score end return a.lo < b.lo end)
    while #list > 3 do table.remove(list) end
    return { status = "ok", list = list }
end
