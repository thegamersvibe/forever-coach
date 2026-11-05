-- Forever Coach: /coach macros creates ready-made class macros (character-specific) with WoW's own macro API.
-- Our own macros (names starting "FC ") are updated to the current version; any other macro is never touched. Out of combat only.
local _, FC = ...
local M = {}
FC.Macros = M

local ICON = "INV_MISC_QUESTIONMARK" -- question mark: the icon follows #showtooltip

-- name (max 16 chars), level it becomes useful, body (max 255 chars)
M.SETS = {
    WARRIOR = {
        { "FC Charge", 4, "#showtooltip\n/cast [nocombat,stance:1] Charge; [nocombat] Battle Stance; [stance:3] Intercept; Berserker Stance" },
        { "FC Revenge", 14, "#showtooltip Revenge\n/startattack\n/cast [nostance:2] Defensive Stance; Revenge" },
        { "FC ShieldBlock", 16, "#showtooltip Shield Block\n/cast [nostance:2] Defensive Stance; Shield Block" },
        { "FC Taunt", 10, "#showtooltip\n/cast [mod:ctrl,stance:1,@mouseover,harm,nodead][mod:ctrl,stance:1] Mocking Blow; [mod:ctrl] Battle Stance; [stance:2,@mouseover,harm,nodead][stance:2] Taunt; Defensive Stance" },
        { "FC Overpower", 12, "#showtooltip Overpower\n/startattack\n/cast [stance:1] Overpower; Battle Stance" },
        { "FC Quest", 20, "#showtooltip\n/startattack\n/cast Victory Rush\n/cast Overpower" },
        { "FC Interrupt", 12, "#showtooltip\n/cast [stance:3] Pummel; Shield Bash" },
        { "FC Clap", 6, "#showtooltip\n/cast [mod:ctrl] Demoralizing Shout; [stance:3] Battle Stance; Thunder Clap" },
        { "FC BersRage", 30, "#showtooltip Berserker Rage\n/cast [stance:3] Berserker Rage; Berserker Stance" },
    },
}

local function exists(name)
    return GetMacroIndexByName and (GetMacroIndexByName(name) or 0) > 0
end

-- returns created, skipped (already current), failed, error message, updated
function M:Install(class)
    local set = self.SETS[class]
    if not set then return nil, nil, nil, "no macros for your class yet" end
    if InCombatLockdown and InCombatLockdown() then return nil, nil, nil, "can't create macros in combat" end
    if not CreateMacro or not GetNumMacros then return nil, nil, nil, "macro API unavailable" end
    local created, skipped, full, updated = {}, {}, {}, {}
    for _, m in ipairs(set) do
        local name, body = m[1], m[3]
        if exists(name) then
            local idx = GetMacroIndexByName(name)
            local _, _, cur = GetMacroInfo and GetMacroInfo(idx)
            if cur == body then
                skipped[#skipped + 1] = name
            elseif EditMacro and pcall(EditMacro, idx, name, ICON, body) then
                updated[#updated + 1] = name
            else
                full[#full + 1] = name
            end
        else
            local _, perChar = GetNumMacros()
            local maxChar = (MAX_CHARACTER_MACROS or 30)
            if (perChar or 0) >= maxChar then
                full[#full + 1] = name
            else
                local ok, idx = pcall(CreateMacro, name, ICON, body, true)
                if ok and idx then created[#created + 1] = name else full[#full + 1] = name end
            end
        end
    end
    return created, skipped, full, nil, updated
end
