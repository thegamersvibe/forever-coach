-- Forever Coach: gear audit. Reads GearQuest Forever's data from the player's own install at runtime.
local _, FC = ...
local safe = FC.safe
local G = {}
FC.Gear = G

G.SLOTS = { -- inventory slot id -> GearQuest slot name
    [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Finger", [12] = "Finger", [13] = "Trinket", [14] = "Trinket",
    [16] = "MainHand", [17] = "SecondaryHand", [18] = "Ranged",
}
G.LABELS = { [1] = "Head", [2] = "Neck", [3] = "Shoulder", [15] = "Back", [5] = "Chest", [9] = "Wrist", [10] = "Hands",
    [6] = "Waist", [7] = "Legs", [8] = "Feet", [11] = "Ring 1", [12] = "Ring 2", [13] = "Trinket 1", [14] = "Trinket 2",
    [16] = "Main Hand", [17] = "Off Hand", [18] = "Ranged" }
-- GearQuest tab order per class (used only when GearQuest can't tell us the spec)
local TAB_SPEC = {
    WARRIOR = { "arms", "fury", "protection" }, PALADIN = { "holy", "protection", "retribution" },
    HUNTER = { "beast_mastery", "marksmanship", "survival" }, ROGUE = { "assassination", "combat", "subtlety" },
    PRIEST = { "discipline", "holy", "shadow" }, SHAMAN = { "elemental", "enhancement", "restoration" },
    MAGE = { "arcane", "fire", "frost" }, WARLOCK = { "affliction", "demonology", "destruction" },
    DRUID = { "balance", "feral", "restoration" },
}

local PREFIX = { WARRIOR = "warrior", PALADIN = "paladin", HUNTER = "hunter", ROGUE = "rogue", PRIEST = "priest",
    SHAMAN = "shaman", MAGE = "mage", WARLOCK = "warlock", DRUID = "druid" }

function G:Status()
    local GQ = _G.GearQuest
    if not GQ or not GQ.Data then return "missing" end
    return "ok"
end

function G:Spec(snap)
    local c = FC:Char()
    if c.specOverride then return c.specOverride, "manual" end
    local GQ = _G.GearQuest
    if GQ and GQ.Spec and GQ.Spec.GetDisplaySpec then
        local s = safe(GQ.Spec.GetDisplaySpec, GQ.Spec, snap.class)
        if s then return s, "gearquest" end
    end
    local best, bi = -1, nil
    for i, t in ipairs(snap.talents.tabs) do if (t.spent or 0) > best then best, bi = t.spent, i end end
    local map = TAB_SPEC[snap.class]
    if bi and best > 0 and map then return map[bi], "talents" end
    return map and map[1], "default"
end

function G:Tables(class)
    local GQ = _G.GearQuest
    local p = PREFIX[class]
    if not (GQ and GQ.Data and p) then return end
    if GQ.Data.EnsureClassLoaded then safe(GQ.Data.EnsureClassLoaded, GQ.Data, class) end
    local D = GQ.Data
    local facts = D[p .. "ItemFacts"] or (class == "PALADIN" and D.itemFacts)
    return { D[p .. "Picks"], D[p .. "Early1to9"] }, { facts, D[p .. "Early1to9Facts"] }
end

-- Clean GearQuest source text: HTML entities, quest-text "Objective:" dumps, length.
function G.Short(s)
    s = tostring(s or "")
    s = s:gsub("&nbsp;", " "):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&amp;", "&"):gsub("&#39;", "'"):gsub("&quot;", '"')
    s = s:gsub("%s*Objective:.*$", ""):gsub("%s+", " ")
    if #s > 170 then s = s:sub(1, 167) .. "..." end
    return s
end

local function fact(factTables, id)
    for _, t in ipairs(factTables) do if t and t[id] then return t[id] end end
end

local function blockedBy(f, race)
    if not f then return "unknown item" end
    local rules = FC:Rules()
    local ins = (f.instructions or "") .. " " .. (f.zone or "")
    for q, races in pairs(rules.raceOnlyQuests or {}) do
        if ins:find("'" .. q .. "'", 1, true) then
            local ok = false
            for _, r in ipairs(races) do if r == race then ok = true end end
            if not ok then return q .. " is a " .. table.concat(races, "/") .. " quest" end
        end
    end
    for _, pat in ipairs(rules.unavailablePatterns or {}) do
        if ins:find(pat, 1, true) then return "not in Forever" end
    end
    if f.sourceType == "unsourced" then return "no known source" end
end

local function rowFields(r) -- generated rows: {id, slot, lo, hi, rank, spec, faction, score}
    if type(r[5]) == "number" then return r[1], r[2], r[3], r[4], r[5], r[6], r[7], r[8] end
    return r[1], r[2], r[3], r[4], r.rank or 4, r[5], r[6], r[8]
end

-- Returns per-slot audit: equipped score vs best obtainable pick at this level.
function G:Audit(snap)
    local out = { status = self:Status(), slots = {} }
    if out.status ~= "ok" then return out end
    local spec, specSource = self:Spec(snap)
    out.spec, out.specSource = spec, specSource
    local pickTables, factTables = self:Tables(snap.class)
    if not pickTables or not pickTables[1] then out.status = "classdata"; return out end

    local lvl, fac, race = snap.level, snap.faction, snap.race
    local bestFor, scoreOf = {}, {}
    for _, rows in ipairs(pickTables) do
        if rows then
            for i = 1, #rows do
                local id, slot, lo, hi, rank, rspec, rfac, score = rowFields(rows[i])
                if rspec == spec and rfac == fac and score then
                    if not scoreOf[id] or score > scoreOf[id] then scoreOf[id] = score end
                    if lo <= lvl and lvl <= hi then
                        local f = fact(factTables, id)
                        local req = f and tonumber(f.reqLevel) or 0
                        if req <= lvl and not blockedBy(f, race) then
                            local b = bestFor[slot]
                            if not b or rank < b.rank or (rank == b.rank and score > b.score) then
                                bestFor[slot] = { id = id, score = score, rank = rank, name = f and f.name, source = f and f.sourceType,
                                    how = f and f.instructions, zone = f and f.zone }
                            end
                        end
                    end
                end
            end
        end
    end
    for inv, slot in pairs(self.SLOTS) do
        local eq = snap.equipped[inv]
        local best = bestFor[slot]
        local entry = { slot = slot, label = G.LABELS[inv], inv = inv, best = best }
        if eq then
            entry.id = eq.id
            entry.score = scoreOf[eq.id]
            if not entry.score and _G.GearQuest and GearQuest.Compare and GearQuest.Compare.ScoreItemStats then
                entry.score = safe(GearQuest.Compare.ScoreItemStats, GearQuest.Compare, { itemId = eq.id })
                entry.estimated = true
            end
        end
        if best then
            local have = entry.score or 0
            entry.gapPct = best.score > 0 and math.floor((best.score - have) / best.score * 100 + 0.5) or 0
            if eq and eq.id == best.id then entry.gapPct = 0 end
        end
        out.slots[inv] = entry
    end
    return out
end
