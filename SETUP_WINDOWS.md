# Windows Setup — from a blank machine to a published Workshop build

Follow this top to bottom on a fresh Windows 10/11 machine. At the end you
will have built the starting-room map, played it, and published it to Steam
Workshop (Private). The deeper failure-mode reference for the build/publish
steps is [docs/18_first_build_checklist.md](docs/18_first_build_checklist.md) -
this doc is the complete happy path.

## 0. Prerequisites (check before you start)

- A Steam account that **owns Call of Duty: Black Ops III** (the Mod Tools are
  free, the game is not).
- **Disk space: ~170 GB free** on one drive. BO3 is ~100 GB, the Mod Tools are
  ~60 GB plus a one-time asset extraction. An SSD makes compile times tolerable.
- Time: **3-6 hours**, almost all of it download/extraction waits. Plan to
  start the downloads, walk away, and do the build steps in a second sitting.

## 1. Install the Basics (~2-3 hours, mostly downloads)

1. **Steam** from [steampowered.com](https://store.steampowered.com/). Sign in.
2. Install **Call of Duty: Black Ops III**. When it finishes, launch it once to
   the main menu and quit (lets it write its player config).
3. In your Steam **Library**, set the type filter to include **Tools** ->
   find **Call of Duty: Black Ops III - Mod Tools** -> Install.
4. First launch of Mod Tools runs a one-time **30-60 min asset extraction**.
   Let it finish - interrupting it causes worse problems than waiting.
   When done, the **Launcher** window is your home base.
5. Install **Git for Windows** from [git-scm.com](https://git-scm.com/download/win).
   In its installer, when asked about line endings, pick
   **"Checkout as-is, commit as-is"** (= `core.autocrlf false`). GSC and
   Radiant `.map` files must not get CRLF-rewritten.
6. Install **VS Code** from [code.visualstudio.com](https://code.visualstudio.com/).
   Optional: the **"GSC Support"** extension for syntax highlighting.
7. Open **PowerShell** once and unblock local scripts (one-time, needed for
   our sync script):

   ```powershell
   Set-ExecutionPolicy -Scope CurrentUser RemoteSigned
   ```

## 2. Clone This Repo

Somewhere **outside** the Mod Tools install. For example `C:\dev\`.

```powershell
mkdir C:\dev
cd C:\dev
git config --global core.autocrlf false   # skip if you set it in the Git installer
git clone <your-repo-url> abandoned_cyber_city_zombies
cd abandoned_cyber_city_zombies
```

Do **not** clone directly into the Mod Tools `usermaps\` folder - we sync into
it with a script.

## 3. Sync Repo -> Mod Tools (5 min)

We never edit inside `usermaps\` directly. We edit in the repo and sync.
The repo ships the complete usermap kit (Radiant `.map` source, entry scripts,
`.zone` manifest, sound config, publish images), so **no Launcher "New Map"
step is needed** - the sync creates the usermap folder and Launcher picks it
up from disk.

```powershell
# From the repo root
.\tools\sync_to_modtools.ps1 -DryRun   # preview what it will do
.\tools\sync_to_modtools.ps1
```

This copies:
- `scripts\*` -> `usermaps\zm_abandoned_cyber_city\scripts\` (entry `.gsc`/`.csc` in `scripts\zm\`, modules in `scripts\zm\zm_abandoned_cyber_city\`)
- `zone_source\zm_abandoned_cyber_city.zone` -> `usermaps\zm_abandoned_cyber_city\zone_source\`
- `sound\*`, `zone\*`, `ui\*` -> same-named folders under the usermap
- `map_source\zm\zm_abandoned_cyber_city.map` -> `<BO3 root>\map_source\zm\` (Radiant reads map sources from the game root, not usermaps)

**Verify** all three exist before moving on:
`usermaps\zm_abandoned_cyber_city\zone_source\zm_abandoned_cyber_city.zone`,
`usermaps\zm_abandoned_cyber_city\scripts\zm\zm_abandoned_cyber_city.gsc`,
`<BO3 root>\map_source\zm\zm_abandoned_cyber_city.map`.

See [tools/README.md](tools/README.md) for flags.
**After any Radiant session, run `.\tools\sync_to_modtools.ps1 -Reverse`** so
the edited `.map` flows back into the repo - the repo is the source of truth.

## 4. First Build (5-15 min)

1. Open Launcher (Steam must be running and logged in first).
2. `zm_abandoned_cyber_city` appears in the map list (Launcher scans
   `usermaps\`). If it doesn't: use **New Map -> zm -> zm_abandoned_cyber_city**
   to register it, then re-run the sync (our files overwriting the generated
   ones is correct and intended).
3. Select the map, make sure **Compile / Light / Link** are all checked, click
   **Build**.
4. Watch the log. Success ends with a linked fast file in `zone_out\`.
5. If it fails, work the failure-mode table in
   [docs/18_first_build_checklist.md](docs/18_first_build_checklist.md) Step 3.
   Short version:
   - GSC error in an `_acc_` file -> grep that file for `TODO(acc-verify)`; a stock API name drifted; compare against `share\raw\scripts\zm\`.
   - Missing asset -> comment out that line in the `.zone` with `//`.
   - Linker can't find the module subfolder -> flatten fallback (documented there).
   - Sound zone error -> comment out the `sound,zm_abandoned_cyber_city` line for now.

## 5. Test In-Game (10 min)

1. In Launcher, add `+set developer 1 +set logfile 1` to the run/command-line
   options if the field is available (enables the `~` console and console.log).
2. Click **Run Game**.
3. BO3 boots into the starting room: pistol, 500 points, zombies at the
   barrier. Survive a round, buy the debris, confirm points award on kills.
4. Open the console (`~`) and look for `[acc] pre_init done` and
   `[acc] init complete`. Warnings about missing `acc_*` targetnames are
   expected - that geometry arrives in Phase 2.
5. Early rounds are deliberately faster/denser than stock - that's
   `_acc_early_round_pacing`, not a bug.

If the game crashes with a script runtime error: the error names a file:line -
almost always a `TODO(acc-verify)` call. Disable that module (comment its line
in `acc_main::init()` plus its `scriptparsetree` line in the `.zone`), rebuild
scripts, rerun. The module set degrades one module at a time by design.

## 6. Publish to Workshop, Private (~15 min)

1. In Launcher with the map selected, open the publish panel (**Publish** /
   **File -> Publish Mod/Map**, label varies by Launcher version).
2. Fill the fields using [zone/workshop.json.example](zone/workshop.json.example)
   as the source of truth:
   - **Title**: `Abandoned Cyber City - dev build`
   - **Description**: mark it as a test build, not for public play.
   - **Tags**: Map, Zombies. **Type**: map.
   - **Thumbnail**: `usermaps\zm_abandoned_cyber_city\zone\previewimage.png`
     (stock placeholder, fine for dev).
3. **Visibility: Private (Hidden).** This is a dev build.
4. Upload. Save the Workshop URL it prints.
5. Launcher writes `usermaps\zm_abandoned_cyber_city\zone\workshop.json`
   (including your PublisherID). Pull it back into the repo and commit it -
   future publishes then update the **same** Workshop item:

   ```powershell
   .\tools\sync_to_modtools.ps1 -Reverse
   git add zone\workshop.json && git commit -m "chore: capture workshop.json from first publish"
   ```

## 7. Verify End-to-End (10 min)

1. Open the Workshop URL in a browser, **Subscribe**.
2. Launch BO3 normally (not via Launcher). **Zombies -> Custom Games** -> the
   map appears -> play a round.
3. All green? That's the ship test passed. Log it in
   [CHANGELOG.md](CHANGELOG.md) and start Phase 2 greyboxing.

## 8. Day-to-Day Iteration

```powershell
# Edit files in the repo (macOS or Windows, your preference)
# On the Windows box, from the repo root:
.\tools\sync_to_modtools.ps1
# Then in Launcher: Build -> Run Game
```

- Script-only changes: use Launcher's **Compile Scripts** (30-90 s) instead of
  a full build.
- Geometry changes: edit in **Radiant** (Launcher toolbar), save, then
  `.\tools\sync_to_modtools.ps1 -Reverse` to bring the `.map` back into git.
- Re-publish: same publish panel; it updates the existing Workshop item.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Sync script won't run ("running scripts is disabled") | PowerShell execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (step 1.7) |
| Launcher doesn't see Steam | Steam not running | Open Steam, log in, reopen Launcher |
| Map missing from Launcher list | Sync didn't run / wrong drive detected | Re-run sync with `-ModToolsRoot "<path>"` |
| "Cannot find file" on compile | Sync didn't copy everything | Re-run sync with `-Verbose`, check the three Verify paths in step 3 |
| GSC compile error on `_acc_*` | Stock API name drifted from the scaffold | Grep `TODO(acc-verify)` in the affected file |
| Radiant/BSP error on the stock-template `.map` | Line endings corrupted in clone | Re-clone with `core.autocrlf false` (step 2), re-sync |
| Map doesn't appear in-game after subscribing | Steam sync quirk | Unsubscribe, restart Steam, re-subscribe |
| `.gsc` file not being picked up | Missing from zone manifest | Add a `scriptparsetree,scripts/zm/zm_abandoned_cyber_city/_acc_yourfile.gsc` line to the `.zone` |

## What's in the Repo Already (when you start)

- `docs/` - design, mechanics, references.
- `map_source/zm/zm_abandoned_cyber_city.map` - Radiant starting-room source (stock template geometry).
- `scripts/zm/zm_abandoned_cyber_city.gsc` and `.csc` - entry points.
- `scripts/zm/zm_abandoned_cyber_city/_acc_*.gsc` - all custom systems (Phase 3 logic plus stubs with TODOs).
- `zone_source/zm_abandoned_cyber_city.zone` - asset manifest.
- `sound/zoneconfig/zm_abandoned_cyber_city.szc` - sound zone config.
- `zone/` - workshop publish assets (loading/preview images, `workshop.json.example`).
- `tools/sync_to_modtools.ps1` - the sync script.

You can compile, run, and publish Day 1 with the scaffold. The custom systems
print `[acc] <name> init complete` to console; systems whose geometry doesn't
exist yet (perk kiosks beyond the start room, power switch pair, etc.) log and
idle until the map grows in Phase 2.
