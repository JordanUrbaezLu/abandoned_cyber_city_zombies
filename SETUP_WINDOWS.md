# Windows Setup — READY TO BUILD

> **Status of THIS machine (2026-06-12, `tools/preflight_windows.ps1`: ALL 20
> CHECKS GREEN):** repo here, git/node/policy/line-endings/disk/RAM/locale all
> verified, BO3 installed, **Mod Tools installed** at
> `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130`
> (note the AppID-suffixed folder — Steam name-collision layout; both our
> scripts auto-detect it by requiring `bin\modlauncher.exe`), prefabs
> extracted, **repo already synced into the usermap**. The next action is
> step 3: open the Launcher and click Build.

Run the readiness check any time — it tells you exactly what's left:

```powershell
# from the repo root
.\tools\preflight_windows.ps1
```

The deeper failure-mode reference for build/publish is
[docs/18_first_build_checklist.md](docs/18_first_build_checklist.md). What the
map contains and what to play-test is summarized there too (7 zones, all 9
perks, 6 wallbuys, 3 box spawns, buyable doors, decontamination, Mega Bottle
loop). The open-items tracker is
[docs/20_requirements_checklist.md](docs/20_requirements_checklist.md); what
needs *you* specifically is [MISSING_REQUIREMENTS.md](MISSING_REQUIREMENTS.md).

## 0. Already done on this machine (for the record)

- ✅ Repo cloned, all 21 GSC modules + map + zone manifest verified intact
  (preflight checks brace balance and zone↔file consistency on every run).
- ✅ Line endings pinned repo-side via `.gitattributes` (`* text=auto eol=lf`):
  your `core.autocrlf` setting **no longer matters** for this repo, and
  Radiant re-saving `.map` files with CRLF gets normalized back to LF on
  commit automatically.
- ✅ PowerShell execution policy `RemoteSigned` (sync script runs).
- ✅ 600+ GB free on C:.
- ✅ BO3 base game at
  `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III`
  (the sync script auto-detects this path).
- ✅ Node.js present (needed only for the map tooling:
  `tools/gen_map_design.js` regenerates [docs/map_design.svg](docs/map_design.svg)).

## 1. Install the Mod Tools ✅ DONE on this machine

Kept for reference / future machines. Note this box's quirk: Steam installed
the tools into `...\Call of Duty Black Ops III 455130` (AppID suffix) beside
the game folder — `preflight_windows.ps1` and `sync_to_modtools.ps1` both
detect the real tools root by `bin\modlauncher.exe`, never by folder name.

Facts below verified June 2026 against the open-sourced Launcher
(`TreyarchGames/ModLauncher`) + official Treyarch guides — sources in
[docs/research/](docs/research/).

1. Steam → **Library** → include **Tools** in the type filter (note: the
   "ready to play" filter HIDES tools — searching the library by name also
   works). Find **Call of Duty: Black Ops III - Mod Tools** (AppID 455130,
   free with the game) → **Install** (~21-23 GB base).
2. **Don't skip:** right-click the Mod Tools → **Properties → DLC** → enable
   **"BO3 Mod Tools - Additional Assets"** (~50 GB). Without it, large parts
   of the stock asset library (models/prefabs we reference) are missing.
3. **Mod Tools must install into the SAME Steam library folder as BO3** —
   the #1 documented cause of `file not found: scripts/zm/zm_usermap.gsc`
   build failures. (Ours: `C:\Program Files (x86)\Steam`.)
4. The Launcher opens immediately; the one-time ~20 min asset conversion
   happens on the **first launch of Radiant** — start Radiant once and let
   it finish before doing anything else in it.
5. Re-run `.\tools\preflight_windows.ps1` — it confirms `map_source\`,
   `bin\launcher.exe`, the extracted `_prefabs\zm`, plus two machine
   requirements it also checks: Windows Region **decimal symbol must be
   "."** (officially documented; EU locales break compile/light) and
   **16 GB RAM** (linker/light can OOM below that — pagefile + closing
   Radiant during builds are the documented mitigations).

## 2. Sync Repo → Mod Tools (1 min)

We never edit inside `usermaps\` directly — edit in the repo, sync over.
The repo ships the complete usermap kit, so **no Launcher "New Map" step is
needed**; the sync creates the usermap folder and the Launcher picks it up.

```powershell
.\tools\sync_to_modtools.ps1 -DryRun   # preview
.\tools\sync_to_modtools.ps1
.\tools\preflight_windows.ps1          # now checks the synced paths too
```

What lands where:
- `scripts\*` → `usermaps\zm_abandoned_cyber_city\scripts\`
- `zone_source\`, `sound\`, `ui\` → same-named folders under the usermap
- `zone\*` → copied without deleting (Launcher writes `workshop.json` there)
- `map_source\zm\zm_abandoned_cyber_city.map` → `<BO3 root>\map_source\zm\`
  (Radiant reads map sources from the game root, not usermaps)

**After any Radiant session, run `.\tools\sync_to_modtools.ps1 -Reverse`** so
the edited `.map` flows back into the repo — the repo is the source of truth.

## 3. First Build (5-15 min)

1. Open the Launcher (Steam must be running and logged in).
2. `zm_abandoned_cyber_city` appears in the map list (it scans `usermaps\`).
   If it doesn't: **New Map → zm → zm_abandoned_cyber_city** to register it,
   then re-run the sync (our files overwriting the generated ones is correct).
3. Select the map, check **Compile / Light / Link**, click **Build**.
4. Success ends with a linked fast file in `usermaps\...\zone_out\`.
5. On failure, work the table in
   [docs/18_first_build_checklist.md](docs/18_first_build_checklist.md) Step 3:
   - GSC error in an `_acc_` file → grep that file for `TODO(acc-verify)`;
     compare the named call against `share\raw\scripts\zm\` (we keep a mirror
     in `tmp/bo3_stock_ref` — clone command in CLAUDE.md).
   - Missing asset on a `.zone` line → comment it out with `//` and note it.
   - Sound zone error → comment out the `sound,zm_abandoned_cyber_city` line
     for the first build.
   - Radiant/BSP error on the `.map` → the map is template + hand-authored
     geometry; the error names a brush/entity — check it against the
     CHANGELOG entity map before touching anything.

## 4. Test In-Game (30 min for the full loop)

1. In the Launcher, add `+set developer 1 +set logfile 1` to the run options
   if the field is available (enables the `~` console + console.log). For the
   Mega-loop test add `+set acc_test_boss 1` (or set the dvar in console —
   it's re-read every round).
2. **Run Game**. You spawn in Spawn Plaza: pistol, 500 points, window
   barricade, debris-pile training loop.
3. Console (`~`): expect `[acc] pre_init done`, `[acc] init complete`, the
   decontamination order log lines, and zone/door logs as you buy through.
4. Walk the full greybox loop from
   [docs/18_first_build_checklist.md](docs/18_first_build_checklist.md):
   buy doors (Market 750 / Alley 750 → Corp 1000 → Vault/Roof 1250 → Lab
   1500), flip a power switch, buy all 9 perks in the Lab, hit the box, buy
   wallbuys, trigger the Hack/Overload events, watch a round-1 zone get
   decontaminated (20s evac), and with `acc_test_boss 1` kill the round-2
   Juggernaut Host → Mega Bottle → upgrade a perk at its machine.
5. Known-by-design behaviors: rounds 1-4 are faster/denser than stock; perk
   machines re-roll nothing yet visually (rotation re-skin is Phase 4);
   wallbuys may show the ICR-1 world model on some guns (model names pending
   APE verification).

If the game crashes at a script runtime error: the error names a file:line —
disable that module (comment its line in `acc_main::init()` plus its
`scriptparsetree` line in the `.zone`), **Compile Scripts** (30-90 s), rerun.
The module set degrades one module at a time by design. File every finding in
CHANGELOG and tick items in [docs/20](docs/20_requirements_checklist.md).

## 5. Right after the first successful build

In priority order (this is the "perfect position" payoff):

1. **Verify the flagged unknowns in APE** (10 min): weapon class names
   (HVK-30, KRM-262 vs Argus), world model names for Haymaker/Drakon wallbuy
   structs, chalk material names — every site is marked `TODO(acc-verify)` /
   `TODO(acc-geom)`; docs/18 lists them.
2. **Install the Skye weapon packs** —
   [docs/21_weapon_import_sources.md](docs/21_weapon_import_sources.md) has
   verified links + the 6-step recipe. That turns the 7 import-gun stand-ins
   into the real roster.
3. **Publish Private to Workshop** (step 6 below) so the e2e pipeline is
   proven early.
4. Work [docs/20](docs/20_requirements_checklist.md) top-down; the
   highest-value next systems are listed in
   [MISSING_REQUIREMENTS.md](MISSING_REQUIREMENTS.md) §7, and
   [docs/22_community_techniques.md](docs/22_community_techniques.md) has the
   harvested blueprints (Wonderfizz GSC→LUI menu for the Cyberware UI,
   item-drop framework for physical Shard pickups).

## 6. Publish to Workshop, Private (~15 min)

1. Launcher, map selected → publish panel (**Publish** / **File → Publish**,
   label varies by version).
2. Fill from [zone/workshop.json.example](zone/workshop.json.example):
   Title `Abandoned Cyber City - dev build`; description marks it a test
   build; **Tags**: Map, Zombies; **Type**: map; thumbnail
   `usermaps\zm_abandoned_cyber_city\zone\previewimage.png`.
3. **Visibility: Private (Hidden).**
4. Upload, save the Workshop URL.
5. Capture the generated `workshop.json` back into the repo (future publishes
   then update the SAME Workshop item):

   ```powershell
   .\tools\sync_to_modtools.ps1 -Reverse
   git add zone\workshop.json; git commit -m "chore: capture workshop.json from first publish"
   ```

## 7. Verify End-to-End (10 min)

1. Open the Workshop URL, **Subscribe**.
2. Launch BO3 normally (not via Launcher) → Zombies → Custom Games → play a
   round.
3. All green = ship test passed. Log it in CHANGELOG.

## 8. Day-to-Day Iteration

```powershell
.\tools\sync_to_modtools.ps1     # repo -> Mod Tools
# Launcher: Build (or Compile Scripts for GSC-only changes) -> Run Game
.\tools\sync_to_modtools.ps1 -Reverse   # after any Radiant session
node tools\gen_map_design.js            # refresh docs/map_design.svg after map edits
```

- Script-only changes: **Compile Scripts** (30-90 s), not a full build.
- The one-shot generators (`gen_zone_greybox.js`, `apply_*.js`,
  `gen_interactives.js`) have ALREADY been applied and refuse to re-run —
  geometry edits from here happen in Radiant.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Anything feels off before building | — | `.\tools\preflight_windows.ps1` first; it names the exact problem |
| Sync script won't run ("running scripts is disabled") | Execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` (already set on this box) |
| Launcher doesn't see Steam | Steam not running | Open Steam, log in, reopen Launcher |
| Map missing from Launcher list | Sync didn't run / wrong drive | Re-run sync with `-ModToolsRoot "<path>"` |
| GSC compile error on `_acc_*` | Stock API drift | Grep `TODO(acc-verify)` in that file; check `docs/research/` dossiers |
| Radiant/BSP error on the `.map` | Hand-authored brush/entity issue | Error names it; cross-reference the CHANGELOG entity map |
| Line endings ever look wrong | — | `.gitattributes` pins LF; `git add --renormalize .` fixes any stragglers |
| Map doesn't appear in-game after subscribing | Steam sync quirk | Unsubscribe, restart Steam, re-subscribe |
| `.gsc` not picked up | Missing zone line | Preflight catches this — it diffs modules vs `scriptparsetree` lines |

## What's in the repo (as of 2026-06-12)

- 7-zone greybox map: all 9 perk machines, 6 wallbuys, 3 mystery-box spawns,
  8 buyable doors, 2 power switches, PaP + per-run approach blocker, every
  interaction trigger (Cyberware kiosk, Overclock terminal, Hack/Overload,
  emergency drop), boss spawn. Visual: [docs/map_design.svg](docs/map_design.svg).
- 21 `_acc_` modules: Data Shards, Cyberware (all 9 nodes), Overclocks,
  decontamination, co-op scaling, Mega Bottles (live upgrade loop), bosses
  (mini + Subroutine Core + `acc_test_boss` dev loop), elites, events,
  randomizer, points/damage pipelines.
- Knowledge base: [docs/20](docs/20_requirements_checklist.md) tracker (202/471),
  [docs/21](docs/21_weapon_import_sources.md) weapon imports,
  [docs/22](docs/22_community_techniques.md) 142-technique ledger,
  [docs/research/](docs/research/) verified dossiers.

Everything compiles-on-paper against verified stock references; the first
build is where paper meets the linker. Expect a handful of `TODO(acc-verify)`
fixes, not a rewrite.
