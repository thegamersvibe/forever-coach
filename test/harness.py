#!/usr/bin/env python3
"""Offline harness: runs the ForeverCoach addon in Lua 5.1 (lupa) against a mocked WoW Forever client.
Forever rules are mocked: health is a secret value (math on it throws), no combat log.

  uv run --with lupa python test/harness.py [GearQuestForever_<CLASS> dir] [ForeverDungeonJournal dir]

Each scenario builds a fresh client. Exits non-zero on any failed assertion.
Set SV_OUT=path to write the main scenario's ForeverCoachDB as a SavedVariables file (for the desktop tests)."""
import os, sys
try:
    import lupa.lua51 as lupa
except ImportError:
    import lupa

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ADDON = os.path.join(ROOT, 'addon', 'ForeverCoach')
GQDIR = sys.argv[1] if len(sys.argv) > 1 else None
FDJDIR = sys.argv[2] if len(sys.argv) > 2 else None
FILES = ['Rules', 'Core', 'Route', 'Session', 'Gear', 'Talents', 'Dungeons', 'Audit', 'UI']

MOCK = r'''
local now = 1000
STATE = { level = 20, class = "WARRIOR", race = "Dwarf", faction = "Alliance", unspent = 2, equipped = {}, bags = {},
          known = { [71] = true }, combat = false, dead = false, xp = 500, xpMax = 10000, rested = 0, zone = "Redridge Mountains",
          talents = { {"Arms", {}}, {"Fury", {}}, {"Protection", { ["Shield Specialization"] = 5, ["Improved Revenge"] = 3 }} },
          reps = {}, skills = { ["First Aid"] = 40 }, trainer = {}, tradeTrainer = false, quests = {}, freeSlots = 10, bagSlots = 4 }
LOCS = {}
function time() return 1700000000 + now end
function GetTime() return now end
function ADVANCE(s) now = now + s end
function UnitName() return "Willtank" end
function GetRealmName() return "TestRealm" end
function UnitClass() return "X", STATE.class end
function UnitRace() return STATE.race, STATE.race end
function UnitFactionGroup() return STATE.faction end
function UnitLevel() return STATE.level end
function UnitXP() return STATE.xp end
function UnitXPMax() return STATE.xpMax end
function GetXPExhaustion() return STATE.rested end
function IsResting() return STATE.resting == true end
function GetMoney() return 12345 end
function UnitCharacterPoints() return STATE.unspent end
function GetNumTalentTabs() return #STATE.talents end
function GetTalentTabInfo(i) local n, t = STATE.talents[i][1], STATE.talents[i][2]; local s = 0; for _, r in pairs(t) do s = s + r end; return n, "icon", s, "bg" end
function GetNumTalents(tab) local n = 0; for _ in pairs(STATE.talents[tab][2]) do n = n + 1 end; return n end
function GetTalentInfo(tab, i) local k = 0; for name, r in pairs(STATE.talents[tab][2]) do k = k + 1; if k == i then return name, "icon", 1, 1, r, 5 end end end
function GetNumSkillLines() local n = 0; for _ in pairs(STATE.skills) do n = n + 1 end; return n end
function GetSkillLineInfo(i) local k = 0; for name, r in pairs(STATE.skills) do k = k + 1; if k == i then return name, false, false, r, 0, 0, 300 end end end
function GetNumFactions() local n = 0; for _ in pairs(STATE.reps) do n = n + 1 end; return n end
function GetFactionInfo(i) local k = 0; for name, st in pairs(STATE.reps) do k = k + 1; if k == i then return name, "", st end end end
local function link(id) return "|cffffffff|Hitem:" .. id .. "::::|h[Item " .. id .. "]|h|r" end
function GetInventoryItemLink(_, slot) local id = STATE.equipped[slot]; return id and link(id) or nil end
C_Container = {
  GetContainerNumSlots = function(b) if b == 0 then return 16 end; return b <= STATE.bagSlots and 0 or 0 end,
  GetContainerNumFreeSlots = function(b) if b == 0 then return STATE.freeSlots end; return 0 end,
  GetContainerItemLink = function(b, s) if b == 0 and STATE.bags[s] then return link(STATE.bags[s]) end end }
C_Item = { GetItemInfoInstant = function(id) return id, "", "", LOCS[id] end, RequestLoadItemDataByID = function() end }
function IsPlayerSpell(id) return STATE.known[id] == true end
function UnitAffectingCombat() return STATE.combat end
function UnitIsDeadOrGhost() return STATE.dead end
function UnitOnTaxi() return false end
SECRET = setmetatable({}, {})
local SM = getmetatable(SECRET)
local function boom() error("attempt to perform arithmetic on a secret number value") end
SM.__add, SM.__sub, SM.__mul, SM.__div, SM.__lt, SM.__le, SM.__unm = boom, boom, boom, boom, boom, boom, boom
function issecretvalue(v) return v == SECRET end
function UnitHealth() return SECRET end
function UnitHealthMax() return 300 end
function IsPlayerMoving() return STATE.moving == true end
USABLE = {}
SPELLNAMES = {[6572]="Revenge",[7384]="Overpower",[402927]="Victory Rush",[71]="Defensive Stance",[712]="Summon Succubus",[713]="Summon Incubus"}
C_Spell = { IsSpellUsable = function(n) return USABLE[n] == true, false end, GetSpellInfo = function(id) return { name = SPELLNAMES[id] } end }
function UnitPowerType() return STATE.ptype or 1 end
function UnitPower(_, t) if STATE.secretPower then return SECRET end; return STATE.rage or 0 end
function UnitPowerMax(_, t) if STATE.secretPower then return SECRET end; return 100 end
function GetRealZoneText() return STATE.zone end
function GetSubZoneText() return "" end
function GetNumTrainerServices() return #STATE.trainer end
function GetTrainerServiceInfo(i) return STATE.trainer[i][1], "", STATE.trainer[i][2] end
function IsTradeskillTrainer() return STATE.tradeTrainer end
C_QuestLog = { IsQuestFlaggedCompleted = function(id) return STATE.quests[id] == "done" end, IsOnQuest = function(id) return STATE.quests[id] == "log" end }
C_Timer = { After = function(_, f) f() end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) CHAT[#CHAT + 1] = m end }
CHAT = {}
UISpecialFrames = {}
function tinsert(t, v) table.insert(t, v) end
local function frame()
  local f = { scripts = {}, events = {} }
  setmetatable(f, { __index = function(t, k) return function(...) return t end end })
  f.SetScript = function(self, k, fn) self.scripts[k] = fn end
  f.RegisterEvent = function(self, e) if not next(self.events) then FRAMES[#FRAMES + 1] = self end; self.events[e] = true end
  f.IsShown = function() return false end
  f.CreateFontString = function() return frame() end
  f.GetStringHeight = function() return 10 end
  return f
end
FRAMES = {}
function CreateFrame() return frame() end
UIParent = frame()
SlashCmdList = {}
function FIRE(event, ...)
  for _, f in ipairs(FRAMES) do if f.events[event] and f.scripts.OnEvent then f.scripts.OnEvent(f, event, ...) end end
end
'''

SERIALIZE = r"""function(v)
  local NL, TAB, b = string.char(10), string.char(9), {}
  local function w(x, ind)
    local t = type(x)
    if t == "table" then
      b[#b+1] = "{" .. NL
      for k, val in pairs(x) do
        b[#b+1] = string.rep(TAB, ind + 1) .. "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
        w(val, ind + 1); b[#b+1] = "," .. NL
      end
      b[#b+1] = string.rep(TAB, ind) .. "}"
    elseif t == "string" then b[#b+1] = string.format("%q", x)
    else b[#b+1] = tostring(x) end
  end
  b[#b+1] = NL .. "ForeverCoachDB = "; w(v, 0); b[#b+1] = NL
  return table.concat(b)
end"""

fails = []


def check(cond, msg):
    print(('PASS ' if cond else 'FAIL ') + msg)
    if not cond: fails.append(msg)


GQ_SRC = []
if GQDIR:
    GQ_SRC = [open(os.path.join(GQDIR, fn), encoding='utf-8').read() for fn in sorted(os.listdir(GQDIR)) if fn.endswith('.generated.lua')]
FDJ_SRC = open(os.path.join(FDJDIR, 'Data', 'Dungeons.lua'), encoding='utf-8').read() if FDJDIR else None
ADDON_SRC = {f: open(os.path.join(ADDON, f + '.lua'), encoding='utf-8').read() for f in FILES}


def client(state=None, gq=True, fdj=True, spec_hook=None):
    L = lupa.LuaRuntime(unpack_returned_tuples=True)
    L.execute(MOCK)
    G = L.globals()
    for k, v in (state or {}).items():
        if isinstance(v, dict):
            t = L.table()
            for kk, vv in v.items(): t[kk] = vv
            G.STATE[k] = t
        elif isinstance(v, list):
            G.STATE[k] = L.table(*v)
        else:
            G.STATE[k] = v
    if gq and GQ_SRC:
        L.execute('GearQuest = { Data = {} }')
        for src in GQ_SRC: L.execute(src)
        L.execute('GearQuest.Spec = { GetDisplaySpec = function(_, c) return SPEC_GQ end, GetDefaultSpec = function() return "arms" end,'
                  ' GetOptions = function() return {{id="arms"},{id="fury"},{id="protection"}} end }')
        # equip locations for picked items: weapons default to one-handers, shields to off-hand
        L.execute('''
          local SL = { Head="INVTYPE_HEAD", Neck="INVTYPE_NECK", Shoulder="INVTYPE_SHOULDER", Back="INVTYPE_CLOAK", Chest="INVTYPE_CHEST",
            Wrist="INVTYPE_WRIST", Hands="INVTYPE_HAND", Waist="INVTYPE_WAIST", Legs="INVTYPE_LEGS", Feet="INVTYPE_FEET",
            Finger="INVTYPE_FINGER", Trinket="INVTYPE_TRINKET", MainHand="INVTYPE_WEAPON", SecondaryHand="INVTYPE_SHIELD", Ranged="INVTYPE_RANGED" }
          for _, list in ipairs({ GearQuest.Data.warriorPicks or {}, GearQuest.Data.warriorEarly1to9 or {} }) do
            for _, r in ipairs(list) do if not LOCS[r[1]] then LOCS[r[1]] = SL[r[2]] end end
          end''')
    if fdj and FDJ_SRC:
        L.execute('ForeverDungeonJournal_NS = { Constants = { ALBA_FAIRMOON_LOCATION = "Sentinel Hill" } }')
        L.execute('return function(...) ' + FDJ_SRC + '\nend')('ForeverDungeonJournal', G.ForeverDungeonJournal_NS)
    ns = L.table()
    for f in FILES:
        L.execute('return function(...) ' + ADDON_SRC[f] + '\nend')('ForeverCoach', ns)
    G.FIRE('ADDON_LOADED', 'ForeverCoach')
    G.FIRE('PLAYER_LOGIN')
    FC = G.ForeverCoach
    return L, G, FC, FC.Char(FC)


def findings(c):
    F = c.findings
    return [F[i] for i in range(1, len(F) + 1)] if F else []


def show(c, n=8):
    for f in findings(c)[:n]:
        print(f'    [{f.area} {f.impact}] {f.text}' + (f'  <{f.where}>' if f.where else '') + f'  ->  {f.fix}')


def refresh(FC):
    FC.Refresh(FC, 'test')


# 1. Main: level 20 Dwarf prot warrior in Redridge, naked
print('== scenario: level 20 Dwarf protection warrior, Redridge, naked')
L, G, FC, c = client()
show(c)
texts = [f.text for f in findings(c)]
check(any('2 unspent talent points' in t for t in texts), 'unspent talents detected')
check(not any('Defensive Stance' in t for t in texts), 'known Defensive Stance not flagged')
check(any(t.startswith('Revenge not learned') for t in texts), 'Revenge (14) flagged as missing for prot')
check(c.lastError is None, f'no internal error ({c.lastError and c.lastError.err})')
check(all(1 <= f.impact <= 100 for f in findings(c)), 'impacts clamped to 1..100')
tp = c.talentPlan
check(tp is not None and tp.next is not None, 'talent plan found for WARRIOR:protection')
if tp and tp.next:
    print('   talent next:', tp.next.level, tp.next.name, '| unspent fix:', [f.fix for f in findings(c) if 'unspent' in f.text][0])
    check(tp.next.level == 18, f'talent plan: Shield Spec + Imp Revenge done, next is level 18 ({tp.next.level})')
if GQ_SRC:
    g = c.gear
    check(g.status == 'ok', f'gear status ok ({g.status})')
    check(g.spec == 'protection' and g.specSource == 'talents', f'spec from talents ({g.spec}/{g.specSource})')
    r1, r2 = g.slots[11].best, g.slots[12].best
    check(not (r1 and r2 and r1.id == r2.id), f'rings never recommend the same item twice ({r1 and r1.name} / {r2 and r2.name})')
    bests = [g.slots[s].best for s in range(1, 19) if g.slots[s] and g.slots[s].best]
    check(not any('Elunite' in (b.name or '') for b in bests), 'no Night Elf-only reward for Dwarf')
    check(not any(b.kind == 'denied' for b in bests), 'no items from Horde-only zones')
    mh = g.slots[16].best
    print('   best MainHand:', mh.name, '|', mh.where)
    G.STATE.equipped[16] = mh.id
    refresh(FC)
    check(c.gear.slots[16].gapPct == 0, 'equipping best MH clears gap')
    # unknown equipped item must not become a 100% gap
    G.STATE.equipped[5] = 999999
    refresh(FC)
    e5 = c.gear.slots[5]
    check(e5.scoreStatus == 'unknown' and e5.gapPct is None, f'unknown chest is "unknown", not 100% behind ({e5.scoreStatus}, {e5.gapPct})')
    check(not any('Chest' in f.text for f in findings(c)), 'no chest finding for an unknown item')
    # owned upgrade in bags ranks first among gear
    chest_best = c.gear.slots[5].best
    G.STATE.equipped[5] = None
    G.STATE.bags[1] = chest_best.id
    G.LOCS[chest_best.id] = 'INVTYPE_CHEST'
    refresh(FC)
    gearf = [f for f in findings(c) if f.area == 'Gear']
    check(gearf and gearf[0].text.startswith('Upgrade in your bags'), f'bag upgrade is the top gear tip ({gearf[0].text if gearf else None})')
    G.STATE.bags[1] = None
    # /coach spec validation
    CH = len(G.CHAT)
    G.SlashCmdList.FOREVERCOACH('spec tankk')
    check(c.specOverride is None and 'unknown spec' in (G.CHAT[len(G.CHAT)] or ''), 'invalid /coach spec rejected')
    G.SlashCmdList.FOREVERCOACH('spec arms')
    check(c.gear.spec == 'arms' and c.gear.specSource == 'manual', 'manual spec override')
    G.SlashCmdList.FOREVERCOACH('spec auto')

# trainer: purchases clear the reminder; profession trainers ignored
G.STATE.trainer = L.table(L.table('Rend', 'available'), L.table('Thunder Clap', 'available'))
G.FIRE('TRAINER_SHOW'); refresh(FC)
check(any('left to train' in f.text for f in findings(c)), 'trainer: available skills reported')
G.STATE.trainer = L.table(L.table('Rend', 'used'), L.table('Thunder Clap', 'used'))
G.FIRE('TRAINER_UPDATE'); G.FIRE('TRAINER_CLOSED')
check(not any('left to train' in f.text for f in findings(c)), 'trainer: reminder clears after buying')

# Session: secret health, procs via usability, AFK split, XP across level-up
S = FC.Session
G.STATE.known[6572] = True
S.Start(S)
G.STATE.combat = True
for i in range(10):
    G.USABLE['Revenge'] = True; S.PollProcs(S)
    if i < 3:
        G.USABLE['Revenge'] = False; S.PollProcs(S)
        G.FIRE('UNIT_SPELLCAST_SUCCEEDED', 'player', 'cast-guid', 6572)
    G.ADVANCE(6); S.PollProcs(S); S.Tick(S, 6)
    G.USABLE['Revenge'] = False; S.PollProcs(S)
G.FIRE('PLAYER_DEAD'); G.FIRE('PLAYER_DEAD')
G.STATE.combat = False; G.STATE.moving = False
for _ in range(60): S.Tick(S, 1)
G.STATE.moving = True
for _ in range(500): S.Tick(S, 1)
G.STATE.moving = False
S.Tick(S, 121)  # one long frame: must not double count
cur = S.Current(S)
check(abs(cur.recovery - 60) < 2 and abs(cur.afk - 121) < 1, f'AFK split exact for long frames (stopped {cur.recovery}, afk {cur.afk})')
G.STATE.moving = True
for _ in range(400): S.Tick(S, 1)
# XP across a level-up: 9500/10000 at 20, +1600 -> level 21 with 1100/11000
G.STATE.xp = 9500; G.FIRE('PLAYER_XP_UPDATE')
before = cur.xp
G.FIRE('PLAYER_LEVEL_UP', 21)
G.STATE.level = 21; G.STATE.xp = 1100; G.STATE.xpMax = 11000
G.FIRE('PLAYER_XP_UPDATE')
check(cur.xp - before == 1600, f'XP across level-up counted ({cur.xp - before})')
G.STATE.level = 20; G.STATE.xp = 500; G.STATE.xpMax = 10000
refresh(FC)
show(c, 20)
texts = [f.text for f in findings(c)]
check(any(t.startswith('Revenge: cast 3 of 10') for t in texts), 'Revenge usage 3/10 via usability')
check(any('deaths per hour' in t for t in texts), 'death rate flagged')
check(c.lastError is None, f'no refresh error ({c.lastError and c.lastError.err})')
G.FIRE('PLAYER_LOGOUT')
check(len(c.sessions) == 1, 'session saved on logout')
out = os.environ.get('SV_OUT')
if out:
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'w', encoding='utf-8').write(L.eval(SERIALIZE)(G.ForeverCoachDB))
    print('wrote', out)

# 2. Tarek now: level 10 Dwarf in Dun Morogh. Rusty Cutlass (no zone) must not beat a route item.
if GQ_SRC:
    print('== scenario: level 10 Dwarf in Dun Morogh')
    L, G, FC, c = client({'level': 10, 'zone': 'Dun Morogh', 'unspent': 1, 'xp': 100, 'xpMax': 6500,
                          'talents': [['Arms', {}], ['Fury', {}], ['Protection', {}]]})
    show(c, 10)
    mh = c.gear.slots[16].best
    print('   MainHand pick:', mh.name, '|', mh.where)
    check(mh.name != 'Rusty Cutlass', 'Rusty Cutlass (location unknown) no longer the top main hand')
    check(c.gear.specSource == 'default', 'no talents yet -> default spec, flagged')
    t = [f.text for f in findings(c)]
    check(any('default spec' in x for x in t), 'default-spec warning shown at 10')
    dg = c.dungeons
    names = [dg.list[i].name for i in range(1, len(dg.list) + 1)] if dg and dg.list else []
    print('   dungeons:', names)
    if FDJ_SRC:
        check('Hall of Thanes' in names, 'Hall of Thanes suggested near level 10-13 for a Dwarf')
        check('Ragefire Chasm' not in names, 'Horde-only Ragefire Chasm hidden for Alliance')

# 3. Level 1: no gear nagging
print('== scenario: level 1')
L, G, FC, c = client({'level': 1, 'zone': 'Coldridge Valley', 'unspent': 0, 'talents': [['Arms', {}], ['Fury', {}], ['Protection', {}]]})
gear_tips = [f for f in findings(c) if f.area == 'Gear']
check(not gear_tips, f'no gear findings at level 1 ({[f.text for f in gear_tips][:3]})')

# 4. Druid at rage cap: no warrior advice
print('== scenario: druid bear with rage capped, priest standing around')
L, G, FC, c = client({'class': 'DRUID', 'race': 'NightElf', 'level': 20, 'zone': 'Darkshore', 'rage': 100, 'known': {5487: True},
                      'talents': [['Balance', {}], ['Feral Combat', {'Thick Hide': 5}], ['Restoration', {}]]}, gq=False)
S = FC.Session; S.Start(S); G.STATE.combat = True
for _ in range(700): S.Tick(S, 1)
refresh(FC)
t = ' '.join((f.text or '') + ' ' + (f.fix or '') for f in findings(c))
check('Heroic Strike' not in t and 'Victory Rush' not in t, 'no warrior-only advice for a druid')
check(any('GearQuest' in f.text for f in findings(c)), 'missing GearQuest shown as checks off')
check(c.gear.status == 'missing', 'gear status missing')

# 5. Warlock with Incubus instead of Succubus
L, G, FC, c = client({'class': 'WARLOCK', 'race': 'Human', 'level': 22, 'zone': 'Duskwood', 'known': {697: True, 713: True, 712: False},
                      'talents': [['Affliction', {}], ['Demonology', {}], ['Destruction', {}]]}, gq=False)
check(not any('Succubus' in f.text for f in findings(c)), 'Incubus counts for the level 20 demon')

# 6. Secret power + level 60
L, G, FC, c = client({'level': 60, 'secretPower': True, 'zone': 'Silithus', 'unspent': 0}, gq=False)
S = FC.Session; S.Start(S); G.STATE.combat = True
for _ in range(700): S.Tick(S, 1)
refresh(FC)
check(c.lastError is None, f'secret power at 60: no error ({c.lastError and c.lastError.err})')
check(not any('rested' in f.text.lower() for f in findings(c)), 'no rested tip at 60')

# 7. Corrupt GearQuest rows don't crash or wipe other advice
if GQ_SRC:
    L, G, FC, c = client({'level': 12, 'zone': 'Dun Morogh'})
    L.execute('table.insert(GearQuest.Data.warriorPicks, 1, { "x", "MainHand", "1", 60, 1, "protection", "Alliance", 5 }); table.insert(GearQuest.Data.warriorPicks, 1, {})')
    refresh(FC)
    check(c.lastError is None and c.findings is not None and len(findings(c)) > 0, 'malformed GearQuest rows ignored')

print('ALL OK' if not fails else f'{len(fails)} FAILED')
sys.exit(1 if fails else 0)
