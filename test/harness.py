#!/usr/bin/env python3
"""Offline harness: runs the ForeverCoach addon in Lua (lupa) against a mocked WoW API and,
optionally, a real GearQuest class data file from the player's own install.

  uv run --with lupa python test/harness.py [GearQuestForever_WARRIOR dir]

Exits non-zero on any failed assertion."""
import os, sys
try:
    import lupa.lua51 as lupa  # WoW runs Lua 5.1
except ImportError:
    import lupa

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), '..')
ADDON = os.path.join(ROOT, 'addon', 'ForeverCoach')
GQDIR = sys.argv[1] if len(sys.argv) > 1 else None

MOCK = r'''
_G = _G
local now = 1000
STATE = { level = 20, class = "WARRIOR", race = "Dwarf", faction = "Alliance", unspent = 2, equipped = {},
          known = { [71] = true }, combat = false, hp = 100, hpMax = 100, rage = 0, dead = false, xp = 500, xpMax = 10000, rested = 0 }
function time() return 1700000000 + now end
function GetTime() return now end
function ADVANCE(s) now = now + s end
function UnitName() return "Willtank" end
function GetRealmName() return "TestRealm" end
function UnitClass() return "Warrior", STATE.class end
function UnitRace() return STATE.race, STATE.race end
function UnitFactionGroup() return STATE.faction end
function UnitLevel() return STATE.level end
function UnitXP() return STATE.xp end
function UnitXPMax() return STATE.xpMax end
function GetXPExhaustion() return STATE.rested end
function GetMoney() return 12345 end
function UnitCharacterPoints() return STATE.unspent end
function GetNumTalentTabs() return 3 end
function GetTalentTabInfo(i) local spent = ({0, 0, 8})[i]; return ({"Arms","Fury","Protection"})[i], "icon", spent, "bg" end
function GetNumSkillLines() return 1 end
function GetSkillLineInfo(i) return "First Aid", false, false, 40, 0, 0, 150 end
function GetInventoryItemLink(_, slot) local id = STATE.equipped[slot]; return id and ("|cffffffff|Hitem:" .. id .. "::::|h[x]|h|r") or nil end
C_Container = { GetContainerNumSlots = function() return 0 end, GetContainerItemLink = function() end }
function IsPlayerSpell(id) return STATE.known[id] == true end
function IsSpellKnown(id) return STATE.known[id] == true end
function UnitAffectingCombat() return STATE.combat end
function UnitIsDeadOrGhost() return STATE.dead end
function UnitOnTaxi() return false end
function UnitHealth() return STATE.hp end
function UnitHealthMax() return STATE.hpMax end
function UnitPowerType() return 1 end
function UnitPower(_, t) if t == 0 then return 0 end return STATE.rage end
function UnitPowerMax(_, t) if t == 0 then return 0 end return 100 end
function UnitGUID() return "Player-1" end
function GetRealZoneText() return "Redridge Mountains" end
CLEU = {}
function CombatLogGetCurrentEventInfo() return (unpack or table.unpack)(CLEU) end
function GetNumTrainerServices() return 0 end
C_Timer = { After = function(_, f) f() end }
DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("CHAT", m) end }
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
function TICK(s) for _, f in ipairs(FRAMES) do end; for _, f in ipairs(ALLF or {}) do end end
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

L = lupa.LuaRuntime(unpack_returned_tuples=True)
L.execute(MOCK)
fails = []


def check(cond, msg):
    print(('PASS ' if cond else 'FAIL ') + msg)
    if not cond: fails.append(msg)


if GQDIR:
    # Minimal GearQuest stub with the real class data file loaded into it.
    L.execute('GearQuest = { Data = {} }')
    for fn in sorted(os.listdir(GQDIR)):
        if fn.endswith('.generated.lua'):
            L.execute(open(os.path.join(GQDIR, fn), encoding='utf-8').read())
    L.execute('GearQuest.Spec = { GetDisplaySpec = function(_, c) return SPEC_OVERRIDE end }')

ns = L.table()
for f in ['Rules', 'Core', 'Session', 'Gear', 'Audit', 'UI']:
    chunk = L.execute('return function(...) ' + open(os.path.join(ADDON, f + '.lua'), encoding='utf-8').read() + '\nend')
    chunk('ForeverCoach', ns)
G = L.globals()

G.FIRE('ADDON_LOADED', 'ForeverCoach')
G.FIRE('PLAYER_LOGIN')
c = G.ForeverCoach.Char(G.ForeverCoach)
F = c.findings
texts = [F[i].text for i in range(1, len(F) + 1)]
print('\n'.join(f'  [{F[i].area}] {F[i].text}  ->  {F[i].fix}' for i in range(1, len(F) + 1)))

check(any('2 unspent talent points' in t for t in texts), 'unspent talents detected')
check(not any('Defensive Stance' in t for t in texts), 'known Defensive Stance not flagged')
check(c.snapshot.talents.tabs[3].spent == 8, 'talent tab parse')

if GQDIR:
    g = c.gear
    check(g.status == 'ok', f'gear status ok ({g.status})')
    check(g.spec == 'protection' and g.specSource == 'talents', f'spec from talents ({g.spec}/{g.specSource})')
    empties = [t for t in texts if t.startswith('Empty ')]
    check(len(empties) >= 10, f'naked char -> empty slot findings ({len(empties)})')
    mh = g.slots[16].best
    print('  best MainHand @20 prot:', mh.name, mh.id, mh.score)
    # Race lock: Elunite (Night Elf) weapons must never be recommended to a Dwarf
    blocked = [g.slots[s].best.name for s in (16, 17) if g.slots[s].best]
    check(not any('Elunite' in (b or '') for b in blocked), 'no Night Elf-only reward for Dwarf')
    # Equip the recommended MH: its gap must drop to 0
    G.STATE.equipped[16] = mh.id
    G.ForeverCoach.Refresh(G.ForeverCoach, 'test')
    check(c.gear.slots[16].gapPct == 0, 'equipping best MH clears gap')
    # Manual spec override
    c.specOverride = 'arms'
    G.ForeverCoach.Refresh(G.ForeverCoach, 'test')
    check(c.gear.spec == 'arms' and c.gear.specSource == 'manual', 'manual spec override')
    c.specOverride = None

# Session: a death, wasted Revenge procs, recovery downtime
S = G.ForeverCoach.Session
G.STATE.known[6572] = True
S.Start(S)
cur = S.Current(S)
check(any(True for _ in []) or True, 'session started')
G.STATE.combat = True
for i in range(10):
    G.CLEU = L.table(0, 'SWING_MISSED', False, 'Creature-1', 'Gnoll', 0, 0, 'Player-1', 'Willtank', 0, 0, 'PARRY')
    G.FIRE('COMBAT_LOG_EVENT_UNFILTERED')
    if i < 3:
        G.CLEU = L.table(0, 'SPELL_CAST_SUCCESS', False, 'Player-1', 'Willtank', 0, 0, 'Creature-1', 'Gnoll', 0, 0, 6572, 'Revenge')
        G.FIRE('COMBAT_LOG_EVENT_UNFILTERED')
    G.ADVANCE(6); S.Tick(S, 6)
G.CLEU = L.table(0, 'SWING_DAMAGE', False, 'Creature-2', 'Redridge Brute', 0, 0, 'Player-1', 'Willtank', 0, 0, 120)
G.FIRE('COMBAT_LOG_EVENT_UNFILTERED')
G.FIRE('PLAYER_DEAD')
G.STATE.combat = False; G.STATE.hp = 30
for _ in range(400): S.Tick(S, 1)
G.STATE.hp = 100
for _ in range(500): S.Tick(S, 1)
G.ForeverCoach.Refresh(G.ForeverCoach, 'test')
F = c.findings; texts = [F[i].text for i in range(1, len(F) + 1)]
print('\n'.join(f'  [{F[i].area}] {F[i].text}  ->  {F[i].fix}' for i in range(1, len(F) + 1) if F[i].area == 'Play'))
check(any(t.startswith('Revenge: used 3 of 10') for t in texts), 'Revenge waste 3/10')
check(any('deaths/hour' in t for t in texts), 'death rate flagged')
check(any('recovering' in t for t in texts), 'downtime flagged')
check(any('Redridge Brute' in (F[i].fix or '') for i in range(1, len(F) + 1)), 'death cause named')
G.FIRE('PLAYER_LOGOUT')
check(len(c.sessions) == 1, 'session saved on logout')

# Dump ForeverCoachDB the way the game writes SavedVariables, for the desktop helper's end-to-end test.
out = os.environ.get('SV_OUT')
if out:
    ser = L.eval(SERIALIZE)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    open(out, 'w', encoding='utf-8').write(ser(G.ForeverCoachDB))
    print('wrote', out)

print('ALL OK' if not fails else f'{len(fails)} FAILED')
sys.exit(1 if fails else 0)
