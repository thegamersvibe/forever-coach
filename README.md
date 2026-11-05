# Forever Coach

A leveling auditor for **World of Warcraft: Forever**, for every class and spec.

Play, type `/reload` (or `/coach`), and get a ranked list of what's slowing you down, sorted by what's cheapest and closest:

- **Gear**: upgrades already in your bags first, then the best piece for your level and spec ranked by where it is: your current zone, the next zones on your leveling route (Journey guide), dungeons, then everything else. Items you can't get are left out: the other faction's zones, reputation you don't have, other races' class quests, items not in Forever. Unknown items are shown as "not checked", never as bad gear.
- **Build**: unspent talent points with the next pick from Icy Veins' leveling build for your spec (all 9 classes, 28 specs, levels 10-60), class quests and trainer skills with verified spell IDs for every class, including race-specific quest routes (e.g. Skyborne Bear Form on Zephras Isle), skills left at your class trainer.
- **Dungeons**: which dungeons fit your level and the quests to pick up before you go (from ForeverDungeonJournal).
- **Play** (estimates): deaths per active hour, short stops out of combat, rage near cap, and how often you cast Revenge/Overpower/Victory Rush when they light up. WoW Forever hides health and the combat log from addons, so these are labelled as estimates.
- **Next**: bag space, empty bag slots, rested XP.

## Install
1. Download `ForeverCoach-<version>.zip` from [Releases](https://github.com/thegamersvibe/forever-coach/releases/latest).
2. Copy the `ForeverCoach` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. Recommended: **GearQuest Forever** (with its module for your class) for gear checks, **Journey** for your route, **ForeverDungeonJournal** for dungeon prep. Everything else works without them.
4. In game, type `/coach`.

### Optional desktop report
Run `ForeverCoach.exe` (no install). It opens a report in your browser that refreshes every time the game saves (`/reload`, logout). It has no window; it closes by itself about 3 minutes after you close the report tab. Running it again while it's open just reopens the tab.
- Reads **only** `WTF\Account\*\SavedVariables\ForeverCoach.lua`.
- Keeps `ForeverCoach\Rules.lua` up to date from this repo (same rules schema only). After an update, `/reload` in game.
- When a new addon or app version is out, it shows a link. It never installs code on its own.
- **Norton / other antivirus:** Norton's auto-sandbox (CyberCapture) silently blocks new unsigned downloads, so the app looks like it does nothing. Add the folder holding `ForeverCoach.exe` to Norton → Settings → Antivirus → Scans and Risks → *Items to Exclude from Auto-Protect, SONAR and Download Intelligence*.
- Windows SmartScreen may warn because the exe isn't code-signed. Choose "More info → Run anyway", or build it yourself (`desktop/`, Go 1.22+).
- If the game is under Program Files and the rules update fails with "access denied", run it once as administrator, or ignore it (the addon still works with its bundled rules).
- Options: `-game "D:\...\_forever_"`, `-port 47321`, `-once` (print to console; run from a terminal with `| more`, since the exe has no console of its own), `-no-update`.

## Commands
- `/coach`: open or close the window
- `/coach top`: top 3 fixes in chat
- `/coach spec <id|auto>`, `/coach macros` (creates ready-made macros for your class: all 9 classes, Ctrl as the modifier; adapted from foreverdb.net): which spec to score gear for (GearQuest ids: `protection`, `arms`, `fury`, `bear`, `holy`…)

## Safety
No memory reading, no input automation, no network access from the addon. Only data the game gives every addon, and files the game itself writes.

## Data
Gear and dungeon data are read at runtime from **your own** GearQuest Forever and ForeverDungeonJournal installs. Nothing from other addons is copied into this repo. `rules/rules.json` holds Forever-specific facts: zone names and level bands of the leveling route, faction-locked zones, race-locked class quests, class milestone spell IDs, and guide talent orders (level + talent name only, credited and linked; no guide text).
Forever-specific knowledge (race-locked class quests, items not in Forever, class milestones, thresholds) lives in [`rules/rules.json`](rules/rules.json). PRs welcome.

## Develop
- `python3 scripts/build_rules_lua.py`: rules.json → addon Rules.lua
- `uv run --with lupa python test/harness.py [path/to/GearQuestForever_<CLASS>]`: runs the addon against a mocked client (Lua 5.1)
- `cd desktop && go test ./...`
- `scripts/release.sh <version>`: build exe and zip, tag, publish a GitHub release
