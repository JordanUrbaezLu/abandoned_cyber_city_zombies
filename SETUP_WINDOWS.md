# Windows Setup

Follow this once your Windows gaming laptop arrives. Assumes the laptop boots Windows 10 or 11 fresh out of the box.

## 1. Install the Basics (~2-3 hours, mostly downloads)

1. **Steam** from [steampowered.com](https://store.steampowered.com/).
2. Sign in. Install **Call of Duty: Black Ops III** (if you already own it, it's in your library).
3. In Steam, filter library -> **Tools** -> install **Call of Duty: Black Ops III - Mod Tools**.
4. First launch of Mod Tools runs a one-time ~30-60 min asset extraction. Let it finish.
5. Install **Git for Windows** from [git-scm.com](https://git-scm.com/download/win).
6. Install **VS Code** from [code.visualstudio.com](https://code.visualstudio.com/).
7. Optional but recommended: in VS Code, install the extension **"GSC Support"** (search GSC in the marketplace) for syntax highlighting.

## 2. Clone This Repo

Somewhere **outside** the Mod Tools install. For example `C:\dev\`.

```powershell
mkdir C:\dev
cd C:\dev
git clone <your-repo-url> abandoned_cyber_city_zombies
cd abandoned_cyber_city_zombies
```

Do **not** clone directly into the Mod Tools `usermaps\` folder - we sync into it with a script.

## 3. Create the Map Shell in Launcher (one-time)

Before syncing our code, the Mod Tools need a map entry registered.

1. Open **Launcher** from Steam.
2. **New Map** -> template: **zm** -> name: `zm_abandoned_cyber_city`.
3. Launcher generates `<Steam>\steamapps\common\Call of Duty Black Ops III\usermaps\zm_abandoned_cyber_city\` with the template scaffolding.
4. Close Launcher for now.

## 4. Sync Repo -> Mod Tools

We don't edit inside `usermaps\` directly. We edit here in the repo and sync.

```powershell
# From the repo root
.\tools\sync_to_modtools.ps1
```

This copies:
- `maps\zm\zm_abandoned_cyber_city.gsc` -> `usermaps\zm_abandoned_cyber_city\maps\zm\`
- `maps\zm\zm_abandoned_cyber_city.csc` -> same
- `scripts\zm\zm_abandoned_cyber_city\*` -> `usermaps\zm_abandoned_cyber_city\scripts\zm\zm_abandoned_cyber_city\`
- `zone_source\zm_abandoned_cyber_city.csv` -> `usermaps\zm_abandoned_cyber_city\zone_source\`
- `ui\*` (when we add LUI later) -> `usermaps\zm_abandoned_cyber_city\ui\`

See [tools/README.md](tools/README.md) for flags (dry-run, reverse-sync, etc.).

## 5. First Build

1. Open Launcher.
2. Select `zm_abandoned_cyber_city` from the map list.
3. **Compile Map** (builds the fast file).
4. Expect 5-15 min on first compile.
5. Watch the log for errors. First-compile errors are almost always one of:
   - A `#include` pointing at a file that doesn't exist yet -> comment out the offending include.
   - A `TODO(acc-verify)` API call with a stock name that drifted -> fix with the real name.
   - An asset in `zone_source\zm_abandoned_cyber_city.csv` that doesn't exist -> remove the line.

## 6. Test In-Game

1. In Launcher, **Run Game** / **Play**.
2. BO3 boots into your map.
3. You should see the Radiant-authored greybox, with our custom systems initializing (check the console log for `[acc] init complete`).

## 7. Iterate

The day-to-day loop:

```powershell
# Edit files in the repo on macOS or Windows (your preference)
# On the Windows laptop, from the repo root:
.\tools\sync_to_modtools.ps1
# Then in Launcher: Compile Map -> Run Game
```

For script-only changes, Launcher has a **"Compile Scripts"** button that skips the full map compile (~30 seconds instead of 5+ minutes).

## 8. First Workshop Publish

When you're ready to put a dev build on Workshop (Private visibility):

1. Launcher -> **Publish Mod/Map**.
2. Title: `Abandoned Cyber City - dev build`.
3. Visibility: **Private (Hidden)**.
4. Upload.
5. Save the Workshop URL.

See [docs/09_language_and_publishing.md](docs/09_language_and_publishing.md) for the full publishing reference.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Launcher doesn't see Steam | Steam not running | Open Steam, log in, reopen Launcher |
| "Cannot find file" on compile | Sync didn't copy everything | Re-run sync script with `-Verbose` flag |
| GSC compile error on `_acc_*` | API name drifted from my scaffold | Grep `TODO(acc-verify)` in the affected file |
| Map doesn't appear in-game after Workshop publish | Steam hasn't finished installing | Restart Steam, wait 2 min, check Custom Maps list |
| `.gsc` file not being picked up | Missing from zone_source CSV | Add a `rawfile,scripts\zm\zm_abandoned_cyber_city\_acc_yourfile.gsc` line |

## What's in the Repo Already (when you start)

- `docs/` - design, mechanics, references.
- `maps/zm/zm_abandoned_cyber_city.gsc` and `.csc` - entry points.
- `scripts/zm/zm_abandoned_cyber_city/_acc_*.gsc` - all custom systems (scaffolded, most are stubs with TODOs).
- `zone_source/zm_abandoned_cyber_city.csv` - asset manifest.
- `tools/sync_to_modtools.ps1` - the sync script.

You can compile and run Day 1 with the scaffold. Most systems will print `[acc] <name> init complete` to console and do nothing else until we fill them in during Phase 3.
