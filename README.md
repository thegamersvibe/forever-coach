# Relax Coach — guild bundle

Two **separate WoW Forever addons**, plus a native Windows report app:

- **Relax Coach** — leveling, equipment, talent, dungeon and session advice. Works without Journey.
- **Relax Journey** — the rebranded Journey guide UI and the included guide-content pack. Can be enabled independently of Coach.
- **RelaxCoach.exe** — a real Windows app window with account selection, saved-character reports and an explicit Coach-addon updater.

## Download

**[Download the latest app release](https://github.com/thegamersvibe/relax-coach/releases/latest)**. **v1.4.1 is app-only:** `RelaxCoach.exe` and `SHA256SUMS.txt`. It adds explicit app self-updates and preserves report filters; it does not install or replace either addon or any Journey guides.

For a full first installation, the existing **[`RelaxCoach-Guild-1.4.0.zip`](https://github.com/thegamersvibe/relax-coach/releases/tag/v1.4.0)** contains both addons and its original guide-content pack. The smaller `RelaxCoach-1.4.0.zip` on that release is Coach-only. After either older package is installed, replace its app with the latest `RelaxCoach.exe` once. Each release's `SHA256SUMS.txt` covers only that release's assets.

## Install or upgrade the guild bundle

Portable installation is also supported: with WoW closed, **merge** the archive's `Interface` folder into `_forever_` (do not replace your whole existing `Interface` folder), then run `RelaxCoach.exe` from a writable folder. Back up any addon/content folders you replace. The installer below is optional and automates backup and shortcut creation.

1. Close WoW. Extract the guild ZIP somewhere outside the game folder.
2. Open PowerShell in the extracted folder and run the installer, substituting your actual `_forever_` path:
   ```powershell
   powershell -NoProfile -ExecutionPolicy Bypass -File .\Install-RelaxCoach.ps1 -Game "C:\Program Files (x86)\World of Warcraft\_forever_"
   ```
3. The installer verifies the package, backs up the directories it replaces, installs the app under your user folder and creates the **Relax Coach** desktop shortcut. If your game directory denies writes, run PowerShell as administrator; do not disable antivirus.
4. In WoW's AddOns list, **Relax Coach** and **Relax Journey** have separate checkboxes. Use `/coach` for Coach and `/journey` for Journey.
5. Open **Relax Coach** from the desktop. Select the game folder and, if more than one account is present, explicitly select yours. The app remembers that choice and does not switch to another account automatically.

The app needs Microsoft Edge WebView2 Runtime. The executable is unsigned. If security software flags it, verify the download/checksum or build from source; do not exclude your entire game folder.

### Installing over normal Journey

This is an **in-place replacement**, not a second side-by-side Journey install. The installer backs up and replaces:

- `Interface\AddOns\ForeverCoach`
- `Interface\AddOns\Journey`
- `Interface\Content\Journey-Content`

It **does not overwrite or delete `WTF`**. The technical addon IDs, `ForeverCoachDB`, `Journey_Account` and `Journey_Character` remain unchanged so existing saves can be reused. Save preservation is verified; compatibility with every newer/older upstream Journey save format is not guaranteed.

Use the included `Restore-RelaxCoach.ps1 -Backup <backup-folder>` with WoW closed to restore the previous addon/content/app files. The install output records the backup folder. Avoid letting another addon manager overwrite `Journey` unless you intend to return to upstream Journey.

## Updates

- **Update App** (app v1.4.1+): check explicitly, then confirm the update. It verifies the executable checksum, restarts only Relax Coach, and supports backup/rollback. WoW can stay running; addons, guides and saves are untouched.
- **One-time bootstrap from an older app:** close only Relax Coach and replace its `RelaxCoach.exe` with the latest release asset. Subsequent app releases can use **Update App**.
- **Update Addon**: updates **Coach only**, with explicit consent, SHA-256 verification and backup/rollback. Close WoW first. App-only releases intentionally have no addon package and do not offer an addon update.
- **Journey and guide content** are separate. The v1.4.1 app release does not redistribute newly issued account guide packages or overwrite an existing Journey installation.
- The app reads saves on disk. Use `/reload` or log out in WoW, then **Refresh**. Refresh cannot force WoW to write its saves.

## Coverage and known limits

- Optional installed providers: GearQuest Forever for comparable item scores, ForeverDungeonJournal for dungeon information. Unknown or incomparable gear is shown as unscored, not assigned an invented score.
- Included Journey code: `4.00.03-1-gca353d2`; guide-content version: `4.00.05`. The original signed catalog and guide bytes are retained. The content's existing validity date is **18 December 2026**; this release does not remove expiry checks.
- This is not a claim of complete coverage for every custom Forever class/spec/item or every leveling route. Some route entries are stubs.
- An intermittent blank native window occurred during development. The final local candidate passed ten restart/Refresh cycles and a more-than-three-minute minimize/restore test, but the earlier root cause was not conclusively identified. If the window is blank, close and reopen it and report the issue.

## Privacy and credits

Release bundles contain addon/program/guide files, **not player WTF saves, account credentials, local reports or private test evidence**. Reading and rendering your saves happens locally. Version checks and explicit updates contact GitHub.

Relax branding and Coach are maintained by **TheGamersVibe**. Coach is MIT-licensed (`LICENSE`). Journey and its guide content retain their original authorship, upstream credits and separate license; see [`addon/Journey/license.txt`](addon/Journey/license.txt) and [Journey](https://www.getjourney.gg/). The root MIT license does not relicense Journey or its content.

## Development

```sh
python3 scripts/build_rules_lua.py
uv run --with lupa python test/harness.py
(cd desktop && go test -race ./... && go vet ./...)
# Windows build; Go must support the version specified by desktop/go.mod:
(cd desktop && GOOS=windows GOARCH=amd64 CGO_ENABLED=0 go build -trimpath -ldflags '-H windowsgui' -o ../dist/RelaxCoach.exe .)
python3 scripts/build_public_bundle.py --exe dist/RelaxCoach.exe
python3 scripts/build_guild_bundle.py --exe dist/RelaxCoach.exe
python3 -m unittest discover -s test -p 'test_*bundle.py'
```

The packaging scripts build local artifacts only; they do not publish, push or tag.
