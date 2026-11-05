-- Forever Coach: /coach macros creates ready-made class macros (character-specific) with WoW's own macro API.
-- Our own macros (names starting "FC ") are updated to the current version; any other macro is never touched. Out of combat only.
local _, FC = ...
local M = {}
FC.Macros = M

local ICON = "INV_MISC_QUESTIONMARK" -- question mark: the icon follows #showtooltip

-- name (max 16 chars), level it becomes useful, body (max 255 chars).
-- Non-warrior sets adapted from foreverdb.net/macros (Forever); main modifier is Ctrl, second Alt, third Shift.
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
    PALADIN = {
        { "FC Heal", 1, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Flash of Light; [@mouseover,help,nodead][help,nodead][@player] Holy Light" },
        { "FC Purify", 8, "#showtooltip Purify\n/cast [@mouseover,help,nodead][help,nodead][@player] Purify" },
        { "FC Blessing", 4, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,@player] Blessing of Wisdom; [mod:alt,@mouseover,help,nodead][mod:alt,@player] Blessing of Kings; [@mouseover,help,nodead][@player] Blessing of Might" },
        { "FC Aura", 1, "#showtooltip\n/cast [mod:ctrl] Retribution Aura; [mod:alt] Concentration Aura; Devotion Aura" },
        { "FC Judge", 4, "#showtooltip Judgement\n/cast [mod:ctrl] Swift Judgement\n/cast [@mouseover,harm,nodead][] Judgement" },
        { "FC Consecrate", 20, "#showtooltip Consecration\n/startattack\n/cast Consecration" },
        { "FC Exorcism", 20, "#showtooltip\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl] Turn Undead; [@mouseover,harm,nodead][] Exorcism" },
        { "FC HoJ", 8, "#showtooltip Hammer of Justice\n/stopcasting\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Hammer of Justice" },
        { "FC BoP", 10, "#showtooltip Blessing of Protection\n/stopcasting\n/cast [mod:shift,@player][@mouseover,help,nodead][help,nodead][@player] Blessing of Protection" },
        { "FC Redemption", 12, "#showtooltip Redemption\n/cast [@mouseover,help,dead][help,dead] Redemption" },
    },
    HUNTER = {
        { "FC PetAttack", 6, "#showtooltip Hunter's Mark\n/petattack\n/cast Hunter's Mark" },
        { "FC PetCmd", 1, "/petfollow [mod:ctrl]\n/petstay [mod:alt]\n/petattack [nomod,@mouseover,harm,nodead][nomod]" },
        { "FC Pet", 10, "#showtooltip\n/cast [mod:ctrl] Revive Pet; [nopet] Call Pet; Mend Pet" },
        { "FC AutoShot", 1, "#showtooltip Auto Shot\n/petattack\n/cast !Auto Shot" },
        { "FC Shot", 20, "#showtooltip\n/cast [mod:ctrl] Multi-Shot; Aimed Shot" },
        { "FC Melee", 1, "#showtooltip Raptor Strike\n/startattack\n/cast Mongoose Bite\n/cast Raptor Strike" },
        { "FC Aspect", 10, "#showtooltip\n/cast [mod:ctrl] !Aspect of the Cheetah; [mod:alt] !Aspect of the Monkey; !Aspect of the Hawk" },
        { "FC Trap", 20, "#showtooltip\n/cast [mod:ctrl] Immolation Trap; [mod:alt] Frost Trap; Freezing Trap" },
        { "FC FeignDeath", 30, "#showtooltip Feign Death\n/stopattack\n/petfollow\n/cast Feign Death" },
        { "FC Concussive", 8, "#showtooltip Concussive Shot\n/cast [@mouseover,harm,nodead][] Concussive Shot" },
    },
    ROGUE = {
        { "FC Opener", 18, "#showtooltip\n/cast [stealth,mod:ctrl] Cheap Shot; [stealth,mod:alt] Garrote; [stealth] Ambush; Sinister Strike\n/startattack [nostealth]" },
        { "FC Stealth", 1, "#showtooltip Stealth\n/cast !Stealth" },
        { "FC Kick", 12, "#showtooltip Kick\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Kick" },
        { "FC Finisher", 10, "#showtooltip\n/cast [mod:ctrl] Slice and Dice; [mod:alt] Rupture; [mod:shift] Expose Armor; Eviscerate" },
        { "FC Escape", 10, "#showtooltip\n/stopattack [mod:alt]\n/cast [mod:ctrl] Sprint; [mod:alt] Vanish; Evasion" },
        { "FC Sap", 10, "#showtooltip Sap\n/cast [nostealth] !Stealth; [@mouseover,harm,nodead][@focus,harm,nodead][] Sap" },
        { "FC Vanish", 22, "#showtooltip Vanish\n/stopattack\n/cast Vanish" },
        { "FC Poison", 20, "#showtooltip\n/use [nomod] Instant Poison; [mod:ctrl] Crippling Poison\n/use [nomod] 16; [mod:ctrl] 17" },
        { "FC Blind", 34, "#showtooltip Blind\n/stopattack [nomod]\n/cast [mod:ctrl,@focus,harm,nodead][nomod] Blind" },
    },
    PRIEST = {
        { "FC Heal", 16, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Flash Heal; [@mouseover,help,nodead][help,nodead][@player] Heal" },
        { "FC LesserHeal", 1, "#showtooltip Lesser Heal\n/cast [@mouseover,help,nodead][help,nodead][@player] Lesser Heal" },
        { "FC Renew", 8, "#showtooltip Renew\n/cast [@mouseover,help,nodead][help,nodead][@player] Renew" },
        { "FC Shield", 6, "#showtooltip Power Word: Shield\n/cast [@mouseover,help,nodead][help,nodead][@player] Power Word: Shield" },
        { "FC Dispel", 18, "#showtooltip Dispel Magic\n/cast [@mouseover,help,nodead][@mouseover,harm,nodead][help,nodead][harm,nodead][@player] Dispel Magic" },
        { "FC Buff", 1, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,@player] Divine Spirit; [mod:alt,@mouseover,help,nodead][mod:alt,@player] Shadow Protection; [@mouseover,help,nodead][help,nodead][@player] Power Word: Fortitude" },
        { "FC SWPain", 4, "#showtooltip Shadow Word: Pain\n/cast [@mouseover,harm,nodead][] Shadow Word: Pain" },
        { "FC Wand", 1, "#showtooltip Shoot\n/cast !Shoot" },
        { "FC Scream", 14, "#showtooltip Psychic Scream\n/stopcasting\n/cast Psychic Scream" },
        { "FC Resurrect", 10, "#showtooltip Resurrection\n/cast [@mouseover,help,dead][help,dead] Resurrection" },
    },
    SHAMAN = {
        { "FC Shock", 4, "#showtooltip\n/cast [mod:ctrl] Frost Shock; [mod:alt] Flame Shock; Earth Shock" },
        { "FC Interrupt", 4, "#showtooltip Earth Shock\n/stopcasting\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Earth Shock" },
        { "FC EarthTotem", 10, "#showtooltip\n/cast [mod:ctrl] Stoneskin Totem; [mod:alt] Earthbind Totem; [mod:shift] Tremor Totem; Strength of Earth Totem" },
        { "FC FireNova", 12, "#showtooltip\n/cast [mod:ctrl] Searing Totem; Fire Nova" },
        { "FC Heal", 1, "#showtooltip Healing Wave\n/cast [mod:shift,@player][@mouseover,help,nodead][help,nodead][@player] Healing Wave" },
        { "FC Shield", 8, "#showtooltip\n/cast [mod:ctrl] Water Shield; Lightning Shield" },
        { "FC Imbue", 1, "#showtooltip\n/cast [mod:ctrl] Flametongue Weapon; [mod:alt] Frostbrand Weapon; [mod:shift] Windfury Weapon; Rockbiter Weapon" },
        { "FC GhostWolf", 20, "#showtooltip Ghost Wolf\n/cast !Ghost Wolf" },
        { "FC Purge", 12, "#showtooltip Purge\n/cast [@mouseover,harm,nodead][@focus,harm,nodead][] Purge" },
        { "FC Rez", 12, "#showtooltip Ancestral Spirit\n/cast [@mouseover,help,dead][help,dead] Ancestral Spirit" },
    },
    MAGE = {
        { "FC Poly", 8, "#showtooltip Polymorph\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Polymorph" },
        { "FC Counter", 24, "#showtooltip Counterspell\n/stopcasting\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Counterspell" },
        { "FC Nova", 10, "#showtooltip Frost Nova\n/stopcasting\n/cast Frost Nova" },
        { "FC Blink", 20, "#showtooltip Blink\n/stopcasting\n/cast Blink" },
        { "FC Ward", 20, "#showtooltip\n/cast [mod:ctrl] Fire Ward; [mod:alt] Frost Ward; Mana Shield" },
        { "FC Conjure", 6, "#showtooltip\n/cast [mod:ctrl] Conjure Food; [mod:alt] Conjure Mana Agate; Conjure Water" },
        { "FC Wand", 1, "#showtooltip Shoot\n/cast !Shoot" },
        { "FC Intellect", 1, "#showtooltip Arcane Intellect\n/cast [@mouseover,help,nodead][help,nodead][@player] Arcane Intellect" },
        { "FC Blizzard", 20, "#showtooltip Blizzard\n/cast [@cursor] Blizzard" },
        { "FC Flamestrike", 16, "#showtooltip Flamestrike\n/cast [@cursor] Flamestrike" },
    },
    WARLOCK = {
        { "FC PetAttack", 1, "#showtooltip\n/petattack\n/cast [pet:Voidwalker] Torment; [pet:Succubus/Incubus] Lash of Pain; [pet:Imp] Firebolt" },
        { "FC PetCmd", 1, "/petattack [nomod,@mouseover,harm,nodead][nomod]\n/petfollow [mod:ctrl]\n/petpassive [mod:ctrl]\n/petdefensive [mod:alt]" },
        { "FC Summon", 10, "#showtooltip\n/cast [combat] Fel Domination\n/cast [mod:ctrl] Summon Voidwalker; [mod:alt] Summon Succubus; [mod:shift] Summon Felhunter; Summon Imp" },
        { "FC Funnel", 12, "#showtooltip\n/cast [nocombat,pet:Voidwalker] Consume Shadows; Health Funnel" },
        { "FC Curse", 4, "#showtooltip\n/cast [mod:ctrl,@mouseover,harm,nodead][mod:ctrl] Curse of Recklessness; [mod:alt,@mouseover,harm,nodead][mod:alt] Curse of the Elements; [@mouseover,harm,nodead][] Curse of Weakness" },
        { "FC Dots", 8, "#showtooltip\n/castsequence reset=target/combat Bane of Agony, Immolate" },
        { "FC Fear", 8, "#showtooltip Fear\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Fear" },
        { "FC Stones", 10, "#showtooltip\n/cast [mod:ctrl] Create Soulstone; Create Healthstone" },
        { "FC RainFire", 20, "#showtooltip Rain of Fire\n/cast [@cursor] Rain of Fire" },
        { "FC SpellLock", 36, "#showtooltip Spell Lock\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Spell Lock" },
    },
    DRUID = {
        { "FC Bear", 10, "#showtooltip\n/startattack [form:1,harm,nodead]\n/cast [form:1,mod:ctrl] Swipe; [form:1] Maul; Bear Form" },
        { "FC Prowl", 20, "#showtooltip Prowl\n/cast [noform][form:1] Cat Form; !Prowl" },
        { "FC Opener", 1, "#showtooltip\n/cast [stealth,mod:ctrl] Pounce; [stealth] Ravage; Claw" },
        { "FC Travel", 20, "#showtooltip\n/cast [swimming] Aquatic Form; [mod:ctrl,outdoors] Travel Form; Cat Form" },
        { "FC Unroot", 20, "#showtooltip Cat Form\n/cancelform\n/cast Cat Form" },
        { "FC Growl", 10, "#showtooltip Growl\n/cast [@mouseover,harm,nodead][] Growl" },
        { "FC SelfHeal", 4, "#showtooltip\n/cancelform\n/cast [mod:ctrl,@player] Regrowth; [@player] Rejuvenation" },
        { "FC HoT", 4, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Regrowth; [@mouseover,help,nodead][help,nodead][@player] Rejuvenation" },
        { "FC Cure", 14, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Remove Curse; [@mouseover,help,nodead][help,nodead][@player] Cure Poison" },
        { "FC MotW", 1, "#showtooltip\n/cast [mod:ctrl,@mouseover,help,nodead][mod:ctrl,help,nodead][mod:ctrl,@player] Thorns; [@mouseover,help,nodead][help,nodead][@player] Mark of the Wild" },
        { "FC Rez", 12, "#showtooltip\n/cast [combat,@mouseover,help,dead][combat,help,dead] Rebirth; [@mouseover,help,dead][help,dead] Revive" },
        { "FC Roots", 8, "#showtooltip Entangling Roots\n/cast [@focus,harm,nodead][@mouseover,harm,nodead][] Entangling Roots" },
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
