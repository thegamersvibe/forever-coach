# WoW Forever race research

Scope: the companion `races.json` supplies the requested schema. Facts were checked against official race announcements, a commit-pinned game-table extraction, local Journey routing data, and Forever-specific quest/zone guides. This is research, not a live-client verification.

## Integration-critical findings

**Exact token: `Skyborne`, for both factions.** The `[camelot]` section of the pinned `races.txt` identifies its build as `wowf 1.60.1.70755`; it has Alliance race ID 95 and Horde race ID 96, both with file token `Skyborne`. Its header describes these as playable ChrRaces records joined to CharBaseInfo, rather than inferred names.[29]

Journey independently takes the **second** return from `UnitRace("player")` and uppercases it (`Journey_core/Condition.lua:524-525`); both faction-specific Skyborne guides test `SKYBORNE` (`dec/guides.lua:95-122`). This corroborates the token's identity, but only the case-preserved table establishes exact casing.[13][14][29]

All race tokens and allowed classes in the JSON were generated from the captured `[camelot]` race rows, not from a Retail table. The exact eight original-race tokens are `Human`, `Orc`, `Dwarf`, `NightElf`, `Scourge`, `Tauren`, `Gnome`, and `Troll`; particularly, the Undead display name does **not** make `Undead` the raceFile token.[29]

`raceFileConfidence=H` means exact case-preserved extracted table plus corroborating addon use. It does **not** mean a live API call was performed. `races.client-table.tsv` preserves the original table header and the ten faction/race rows used to form nine raceFile records.[29]

### Faction-specific Skyborne classes

Blizzard confirms that faction is selected **at character creation**, and both factions support Druids.[1]

| Faction | Display branch | Race ID | Allowed classes |
|---|---|---:|---|
| Alliance | High Order Skyborne | 95 | DRUID, HUNTER, MAGE, ROGUE, WARRIOR |
| Horde | Windshaper Skyborne | 96 | DRUID, HUNTER, ROGUE, SHAMAN, WARRIOR |

The official class lists agree with the pinned client-table extraction; the numeric race IDs come from the table, not the announcement.[1][29]

**Schema limitation:** `races.Skyborne.classes` is their union because the requested schema has one record per raceFile. Consumers must additionally check `UnitFactionGroup("player")`; the union must not enable Alliance Skyborne Shamans or Horde Skyborne Mages. The tester's Skyborne Druid is consistent with both sources.[1][29]

The other new combinations represented are Human Hunter, Dwarf Shaman, Gnome Priest, Orc Mage, Troll Warlock, and Undead Paladin; the pinned table also retains the original permitted combinations.[29]

## Starting areas and capitals

Blizzard specifies **Zephras Isle, levels 1–12** for both Skyborne factions. Journey divides this into **Thendal Village 1–6** and the subsequent **Zephras Isle 6–12** route; both factions use the initial village guide.[1][14][15]

Thendal Village is area 16635, a subzone of Zephras Isle (area 16593). Journey's `2521` is a different identifier namespace, its map reference, and should not replace the area ID in a database lookup.[14][21][24]

Use **Thendal Village**, matching the area record and Journey. Wowhead's trainer table spells it **Thendall Village**, so that alternate spelling is documented as an alias rather than silently substituted for the canonical key.[9][14][24]

`zones` deliberately includes only the Skyborne parent and initial subzone. **Shen'dar Village** and **Valanaar** are confirmed settlements, but the retrieved trainer list does not establish independent level bands for them; none were invented.[9]

Wowhead labels Zephras Isle's territory **Contested** and its range 1–12. The JSON inherits that faction classification for Thendal Village provisionally; a separate subzone PvP flag was not retrieved. These values are database/routing categories, **not verified PvP-safety advice**.[21][24]

The original-race parent starts are confirmed by Journey's Forever guide recommendations: Human/Elwynn Forest, Dwarf and Gnome/Dun Morogh, Night Elf/Teldrassil, Orc and Troll/Durotar, Tauren/Mulgore, and Undead/Tirisfal Glades.[14]

Human/Northshire Valley and Dwarf/Coldridge Valley are also explicit on their Forever race pages; Gnome still starts in Coldridge Valley and uses Ironforge rather than a Retail Gnomeregan start.[39][40][54]

The original-race capital mappings agree with the Forever community faction tables. These tables explicitly label their capital material as third-party rather than Blizzard-confirmed; the JSON retains familiar service-city mappings and does not repeat their beta-state or racial-ability claims.[55][56]

**Valanaar** is verified as the Skyborne trainer/service and skyboat hub. Its use in the JSON's `capital` field is a practical hub designation, supported by community capital tables, not an asserted official political classification.[9][55][56]

## Skyborne class quests

Coordinates below are on the Zephras Isle map. Journey supplies quest/NPC relationships and map coordinates; the Wowhead trainer guide resolves their display names.[9][15][16]

| Class | Player level / checkpoint | Quest and ID | Giver and NPC ID | Local position / evidence |
|---|---:|---|---|---|
| DRUID | 10 | The Great Ursera Spirit — 94006 | Lotheluum Starbreeze — 252359 | Valanaar, 64.0,75.1; Journey 0011:1421–1428 |
| DRUID | 10 | Strength and Mercy — 94638 | Urs'endris — 255853 | 69.8,61.7; Journey 0011:1430–1442 |
| WARRIOR | 10 | The Skybreaker Bulwark — 94003 | Seena Skybreaker — 252377 | Valanaar, 59.9,72.9; Journey 0011:1395–1403 |
| HUNTER | 10 | Taming the Beast — 94978 | Quel'ana Quickgale — 252389 | Valanaar, 59.6,72.6; Journey 0011:975–995 |
| MAGE | 10 | Speak with Belann — 93791 | Anathamaas Aetherwind — 252373 | Valanaar; independent guide resolves the actual lead-in giver |
| MAGE | 10 | Boughs in the Wind — 93797 | Belann Windwood — 256507 | Valanaar, about 62.9,77.4; Journey 0011:1355–1364 |
| SHAMAN | **3** | Call of Earth — 92466 | Windshaper Boro — 251374 | Thendal Village, 42.8,23.5; Journey 0010:160–169 |
| SHAMAN | 10 | Call of Fire — 97243 | Sessaria Skystride — 252382 | Valanaar, 58.2,78.4; Journey 0011:913–923 |
| SHAMAN | 10 | Call of Fire — 97243 | Aarnor Galestrike — 254082 | Alternate starter in Shen'dar Village, from quest Quick Facts |

The Druid, Warrior and Hunter rows are supported by their actual quest text, local acceptance steps and the independent class guides.[16][26][34]

The Hunter chain uses `94978 → 94979 → 94013`, then `Training the Beast (94050)`; its IDs are **not sequential**. The latter quest turns in to the pet trainer (254411) rather than the original class trainer.[16][32]

The Mage lead-in deserves care: Journey collapses accepting and completing `93791` onto Belann. The independent walkthrough explicitly starts it with **Anathamaas Aetherwind**, then sends the player to Belann. The JSON uses that distinction rather than treating the turn-in NPC as the lead-in giver.[16][33][38]

Call of Earth's Quick Facts say **quest level 4, requires player level 3**. Journey independently comments that level 3 is required. Do not copy the original-race Shaman level-4 requirement onto Skyborne.[15][31]

The Call of Fire Quick Facts list both Sessaria and Aarnor as starters and require level 10. The local route uses Sessaria, then Olariaan Swiftburn (268592) at the Shrine of Flames, through IDs 97244, 97245 and 97257, ending back at Sessaria.[16][30]

### Bear Form is not the Moonglade chain

At level 10, obtain `The Great Ursera Spirit` from Lotheluum, meet Urs'endris, then take `Strength and Mercy`. Kill **Ur'endra (258443)** in the Shen'dar Highlands near 53.7,65.1 and return to Urs'endris. `Strength and Mercy` explicitly rewards **Bear Form (5487)**.[16][17][18]

Approach the cave from its upper/northern side; the independent Druid guide confirms this and presents the Skyborne chain separately from Night Elf and Tauren routes.[16][26]

A September beta forum thread reports Skyborne players reaching Moonglade without a follow-up; the original poster later points to the Druid trainer in Valanaar, and another player reports completing the island spirit/mate quest. This is corroboration of routing differences, **not evidence of an active launch bug or a tested fix**.[11]

### Rogue gap

The trainer guide verifies **Eltheen Nightbreeze** in Valanaar and **Akeri Duskblade** in Thendal Village. No retrieved evidence established a Skyborne level-10 Rogue unlock quest from Eltheen, so no such `classQuestGivers` row was invented.[9]

## Race-locked reward routing

The `raceOnlyQuests` mapping is for **acquisition through race-specific class chains**, not restrictions on equipping the resulting items. It is a curated routing subset, not an exhaustive live-server race-mask dump.

| Reward quest | Race tokens | Reward / limitation | Evidence |
|---|---|---|---|
| Dead-tooth Jack — 1667 | Human | Haggard weapon choice; Warrior chain | [34][48] |
| Grey Iron Weapons — 1682 | Dwarf, Gnome | Umbral weapon choice; Warrior chain | [34][36] |
| Weapons of Elunite — 1693 | NightElf | Elunite weapon choice; Warrior chain | [34][35] |
| Forged Steel — 1503 | Orc, Tauren, Troll | Thun'grim weapon choice; Warrior chain | [34][49] |
| Heirloom Weapon — 1822 | Scourge | Heirloom weapon choice; Warrior chain | [34][50] |
| The Skybreaker Bulwark — 94003 | Skyborne | Warrior, both factions; Defensive Stance plus Stormforged Protector (275290) | [19][34] |
| Boughs in the Wind — 93797 | Skyborne | Mage, therefore Alliance; Windbough Wand (263430) plus Elixir of Minor Spirit (250344) | [20][38] |
| Strength and Mercy — 94638 | Skyborne | Druid, both factions; Bear Form spell, not equipment | [18][26] |
| Old Fire-Eye — 95140 | Scourge | Undead Paladin weapon chain; Wolfsbane (267369) | [53][57] |

**Heirloom Weapon (1822)** is the actual final weapon-choice quest; **Agamand Heirlooms (1821)** is its preceding collection quest. This distinction prevents attaching the item reward to the wrong quest name.[37][50]

The `classQuestGivers` rows for the eight original-race Warrior reward routes use the respective NPCs named by the Forever Warrior guide: Marshal Haggard, Tormus Deepforge, Mathiel, Thun'grim Firegaze and Coleman Farthing. Level 10 is the guide's early chain checkpoint; prerequisites must still be completed before a final reward stage appears.[34]

The mapping deliberately does **not** assign Skyborne-only gates to generic names `Taming the Beast`, `Call of Earth`, or `Call of Fire`; other races have identically named quest chains. Use quest IDs plus race/faction when extending those routes.[16][31][52]

The island overview identifies the bag reward from `The Problem With Prideclaws` and relic rewards from `Meddlesome Mages`, but this does not alone prove race-exclusivity. They were not added to `raceOnlyQuests` merely for occurring on the island.[9]

## New-combination class-quest additions

- **Dwarf Shaman:** `Call of Earth (94373)` starts at **Teo Hammerstorm (257446)** inside Anvilmar, Dun Morogh, at level **4** and about 28.8,66.2. Local Journey accepts it from the same NPC. This is a different chain/minimum from Skyborne's level-3 quest.[52][59]
- **Undead Paladin:** `A Lesson in Divinity (94427)` is the level-12 Redemption chain according to the Forever Paladin guide. Local Journey accepts it from NPC 246378 at Bandarion Keep; the NPC page resolves that ID to **Danitha Morr** in Tirisfal Glades.[53][58][60]
- **Undead Paladin:** at level **20**, **Danitha Morr** begins `Diplomatic Incident (91858)` at Bandarion Keep, leading to the `Old Fire-Eye` / Wolfsbane chain. Do not route it through the Alliance Paladin chain.[53]

The level-12 Redemption entry is guide-sourced, not a live-measured minimum; local Journey also has acceptance routing but no direct API proof of current availability. Treat launch quest requirements and prerequisites as candidates for tester confirmation.[53][58]

## Method and remaining uncertainty

1. Resolve tokens/classes from a **build- and commit-pinned case-preserved table**, then cross-check the addon's transformation of `UnitRace` instead of inferring camel-case from uppercase conditions.[13][29]
2. Join local quest IDs/NPC IDs to independent quest/trainer pages. Keep quest giver distinct from turn-in NPC, and quest level distinct from minimum player level.[9][16][31]
3. Keep duplicate titles, faction-specific class eligibility, parent/subzone relationships and area/map ID namespaces explicit; the requested schema cannot encode all of them directly.[1][24][31]
4. Prefer official class/start announcements; use local guides for routing and secondary quest databases for names/rewards. Do not treat a trainer, a shared zone, or a reward table as proof of a race-specific quest gate.[1][9][16]

No live WoW client, character creation, quest availability, quest sharing or equipment restriction test was performed. The JSON notes explicitly preserve the unverified political-capital designation, inherited Thendal territory classification, unsupported Rogue quest gap, and non-exhaustive class-quest coverage.

Recommended live checks are `/dump UnitRace("player")` and `/dump UnitFactionGroup("player")` on both Skyborne factions, then the relevant level-3/10 quest availability checks. These commands are proposed checks, not fabricated execution output.

## Sources

[1] http://worldofwarcraft.blizzard.com/news/24302071/wow-forever-meet-the-new-skyborne
[9] https://www.wowhead.com/forever/guide/zephras-isle-zone-overview
[11] https://us.forums.blizzard.com/en/wow/t/druid-questline-for-bear-form-broken-for-me/2353628
[13] file:///opt/data/cache/scratch/wowf/x/Journey_core/Condition.lua
[14] file:///opt/data/cache/scratch/wowf/x/dec/guides.lua
[15] file:///opt/data/cache/scratch/wowf/x/dec/0010.lua
[16] file:///opt/data/cache/scratch/wowf/x/dec/0011.lua
[17] https://www.wowhead.com/forever/quest=94006/the-great-ursera-spirit
[18] https://www.wowhead.com/forever/quest=94638/strength-and-mercy
[19] https://www.wowhead.com/forever/quest=94003/the-skybreaker-bulwark
[20] https://www.wowhead.com/forever/quest=93797/boughs-in-the-wind
[21] https://www.wowhead.com/forever/zone=16593/zephras-isle
[24] https://wow-forever.gg/db/zones/16635-thendal-village
[26] https://icy-veins.com/wow-forever/druid-shapeshift-forms
[29] https://github.com/DomenikIrrgang/wowlua/blob/f6b59823c32957dd20fd4afad139b06d9b6061ec/crates/wowlua-flavors/data/races.txt
[30] https://www.wowhead.com/forever/quest=97243
[31] https://www.wowhead.com/forever/quest=92466
[32] https://www.wowhead.com/forever/quest=94978/taming-the-beast
[33] https://www.wowhead.com/forever/quest=93791/speak-with-belann
[34] https://www.icy-veins.com/wow-forever/warrior-class-quests
[35] https://www.wowhead.com/forever/quest=1693/weapons-of-elunite
[36] https://www.wowhead.com/forever/quest=1682/grey-iron-weapons
[37] https://www.wowhead.com/forever/quest=1821/agamand-heirlooms
[38] https://gamer-guides.com/warcraft-forever/boughs-in-the-wind
[39] https://wowfdb.com/races/human
[40] https://wowfdb.com/races/dwarf
[48] https://www.wowhead.com/forever/quest=1667/dead-tooth-jack
[49] https://www.wowhead.com/forever/quest=1503/forged-steel
[50] https://www.wowhead.com/forever/quest=1822/heirloom-weapon
[52] https://www.warcrafttavern.com/forever/guides/dwarf-shaman-totem-quests
[53] https://www.icy-veins.com/wow-forever/paladin-class-quests
[54] https://wowfdb.com/races/gnome
[55] https://warcraftforever.wiki/wiki/Horde
[56] https://warcraftforever.wiki/wiki/Alliance
[57] https://www.wowhead.com/forever/quest=95140/old-fire-eye
[58] file:///opt/data/cache/scratch/wowf/x/dec/0021.lua
[59] file:///opt/data/cache/scratch/wowf/x/dec/0001.lua
[60] https://www.wowhead.com/forever/npc=246378/danitha-morr
