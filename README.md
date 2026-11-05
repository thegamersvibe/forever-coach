# Forever Coach

A leveling auditor for **World of Warcraft: Forever**, for every class and spec.

You play, type `/reload`, and get a ranked list of what to fix: gear behind your level, unspent talents, missing trainer ranks, overdue class quests, and play habits (deaths, downtime, wasted procs).

**Status:** in development. Nothing to install yet.

## Planned package
- `ForeverCoach/`: in-game addon. Drop it into `World of Warcraft\_forever_\Interface\AddOns`. `/coach` shows the top fixes.
- `ForeverCoach.exe`: optional desktop report. Portable, read-only: it reads only the addon's own saved file.
- `rules.json`: Forever-specific rules, auto-updated from this repo's releases (same major version only).

## Data
Gear, route and dungeon data are read from **your own** installed addons (GearQuest Forever, Journey, ForeverDungeonJournal) at runtime. None of their data is copied into this repo.

## Safety
No memory reading, no input automation. Only files the game itself writes.
