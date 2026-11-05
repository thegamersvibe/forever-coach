# Forever Coach

A leveling auditor for **World of Warcraft: Forever**, for every class and spec.

Play, type `/reload` (or `/coach`), and get a ranked list of what's slowing you down:

- **Build**: unspent talent points, class-quest spells you never learned (Defensive Stance, Bear Form, demon pets…), trainer visits you skipped.
- **Gear**: each slot compared with the best piece you can actually get at your level for your spec, race and faction, plus where it comes from.
- **Play**: deaths per hour and what killed you, time spent eating and recovering, rage sitting near cap, missed procs (Revenge, Overpower, Victory Rush, Riposte…).

## Install
1. Download `ForeverCoach-<version>.zip` from [Releases](https://github.com/thegamersvibe/forever-coach/releases/latest).
2. Copy the `ForeverCoach` folder into `World of Warcraft\_forever_\Interface\AddOns\`.
3. Recommended: install **GearQuest Forever** and enable its module for your class. Gear checks use its data. Everything else works without it.
4. In game, type `/coach`.

### Optional desktop report
Run `ForeverCoach.exe` (no install). It opens a report in your browser that refreshes every time the game saves (`/reload`, logout).
- Reads **only** `WTF\Account\*\SavedVariables\ForeverCoach.lua`.
- Keeps `ForeverCoach\Rules.lua` up to date from this repo (same rules schema only). After an update, `/reload` in game.
- When a new addon or app version is out, it shows a link. It never installs code on its own.
- **Norton / other antivirus:** Norton's auto-sandbox (CyberCapture) silently blocks new unsigned downloads, so the app looks like it does nothing. Add the folder holding `ForeverCoach.exe` to Norton → Settings → Antivirus → Scans and Risks → *Items to Exclude from Auto-Protect, SONAR and Download Intelligence*.
- Windows SmartScreen may warn because the exe isn't code-signed. Choose "More info → Run anyway", or build it yourself (`desktop/`, Go 1.22+).
- If the game is under Program Files and the rules update fails with "access denied", run it once as administrator, or ignore it (the addon still works with its bundled rules).
- Options: `-game "D:\...\_forever_"`, `-port 47321`, `-once` (print to console), `-no-update`.

## Commands
- `/coach`: open or close the window
- `/coach top`: top 3 fixes in chat
- `/coach spec <id|auto>`: which spec to score gear for (GearQuest ids: `protection`, `arms`, `fury`, `bear`, `holy`…)

## Safety
No memory reading, no input automation, no network access from the addon. Only data the game gives every addon, and files the game itself writes.

## Data
Gear data is read at runtime from **your own** GearQuest Forever install. Nothing from other addons is copied into this repo.
Forever-specific knowledge (race-locked class quests, items not in Forever, class milestones, thresholds) lives in [`rules/rules.json`](rules/rules.json). PRs welcome.

## Develop
- `python3 scripts/build_rules_lua.py`: rules.json → addon Rules.lua
- `uv run --with lupa python test/harness.py [path/to/GearQuestForever_<CLASS>]`: runs the addon against a mocked client (Lua 5.1)
- `cd desktop && go test ./...`
- `scripts/release.sh <version>`: build exe and zip, tag, publish a GitHub release
