# Windows Setup — BUILT & BUILDABLE

> **Status of THIS machine:** setup **COMPLETE (2026-07-03)** on the current Win11
> box. BO3 + Mod Tools installed, L3akMod DLL overwrite in place, Node.js on PATH,
> the `TA_TOOLS_PATH` / `TA_GAME_PATH` user env vars set, all external asset packs
> reinstalled, and **the map FULLY BUILDS** (first clean compile + link 2026-06-12;
> in-game verified). Mod Tools root is
> `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130`
> (note the AppID-suffixed folder — Steam name-collision layout when the game and
> tools are both installed; our scripts auto-detect the real tools root by
> requiring `bin\modlauncher.exe`, never by folder name).
>
> **This is a living reference, not a from-scratch install plan.** The whole build
> pipeline is CLI-scriptable — agents and the user build with
> **`.\tools\build_map.ps1`**, NOT the Launcher GUI. New machine / fresh clone?
> Jump to §2.

Run the readiness check any time — it names exactly what (if anything) is missing:

```powershell
# from the repo root
.\tools\preflight_windows.ps1
```

Deeper references: build/launch failure modes = [docs/17_launch_runbook.md](docs/17_launch_runbook.md);
portable mapmaking pipeline = [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md);
publish/release = [docs/34_release_runbook.md](docs/34_release_runbook.md); what needs
*you* specifically = [MISSING_REQUIREMENTS.md](MISSING_REQUIREMENTS.md); onboarding a
new person/box = [ONBOARDING.md](ONBOARDING.md).

## What the map currently contains

The map is fully built — this is not a greybox plan. High level (spec: REQUIREMENTS.md,
tracker: [docs/15_requirements_checklist.md](docs/15_requirements_checklist.md)):

- **7-zone above-ground layout** + a vertical **"Abyss Descent"** underground
  (L2/L3/L5 soul-box layers dropping to the Paradise plaza — [docs/30_abyss_descent.md](docs/30_abyss_descent.md)),
  buyable doors (`script_flag enter_*`), inline mystery boxes, power switches.
- **10 perks** (7 retuned stock + Deadshot, PhD Flopper, and the real **Electric
  Cherry** as the 10th) with per-perk **Mega Bottle** upgrades. Slot cap
  `ACC_PERK_SLOT_MAX = 10`; players start at 4 slots and buy more with Data Shards
  at the underground Neural Expansion Bay, at escalating shard costs (4/6/8/10/12/14).
  A **live 4-of-10 Lab-alcove rotation** re-rolls which perks are available each run.
  Details: [docs/10_perks.md](docs/10_perks.md).
- **Box-only weapon economy** — a large arsenal from the mystery box (Apex pack +
  Skye ports + HB21 elemental bows), plus the Armory upper-room weapon rack. No
  fixed "shortlist". Weapon table:
  `gamedata/weapons/zm/zm_levelcommon_weapons.csv`; runbook: [docs/21_adding_a_gun_runbook.md](docs/21_adding_a_gun_runbook.md).
- **Boss cadence:** mini-boss debut at round 10, then full **boss rounds every 9
  from round 9** (count scales r9=1, r18=2, r27=3), boss **types dealt from a
  no-duplicate shuffled 4-type deck** (`level.acc_boss_roster_fn`): **Phantom,
  Rogue/Civil Protector, Avogadro, Panzer (mechz)**. **Brutus** (his own round-5 power
  cadence) and **Glitch** (its own r12+ test-spawn system) are separate boss modules,
  NOT dealt from the shuffled deck. (The Protector's "round-20" is a design label only —
  at runtime he rides the shared every-9-from-9 roster, first possible at round 9.)
  See [docs/08_enemies.md](docs/08_enemies.md), [docs/09_boss_items.md](docs/09_boss_items.md).
- **Built side systems:** Exo Suit station ([docs/29](docs/29_exo_suit_plan.md)),
  Armory upper room ([docs/39](docs/39_armory.md)), Reactor Surge climax event,
  Glitch Altar shard gamble, Jukebox (replaced the old EE-song teddy bears), and
  The Exchange transfer vault ([docs/37](docs/37_transfer_vault.md)). *(The old
  "Vault Overload" side-event was RETIRED 2026-07-07 — commented out in
  `_acc_main.gsc`.)*
- **Aetherium LUI HUD** is the shipped base (since 2026-07-03) with the gun-badge
  chip row (2026-07-08); round progress is a **smooth bar** (the radial ring was
  abandoned). See [docs/11_controls_and_hud.md](docs/11_controls_and_hud.md).
- **~48 active `_acc_` modules** orchestrated by `acc_main::init()` (plus the
  directly-called `_acc_perk_electric_cherry`).

## 1. Install the Mod Tools (reference — already DONE on this box)

Kept for future machines. This box's quirk: Steam installed the tools into
`...\Call of Duty Black Ops III 455130` (AppID suffix) beside the game folder —
`preflight_windows.ps1` and `sync_to_modtools.ps1` both detect the real tools root
by `bin\modlauncher.exe`, never by folder name.

1. Steam → **Library** → include **Tools** in the type filter (the "ready to play"
   filter HIDES tools; searching the library by name also works). Find **Call of
   Duty: Black Ops III - Mod Tools** (free with the game) → **Install** (~21-23 GB base).
2. **Don't skip:** right-click the Mod Tools → **Properties → DLC** → enable **"BO3
   Mod Tools - Additional Assets"** (~50 GB). Without it, large parts of the stock
   asset library (models/prefabs we reference) are missing.
3. **Mod Tools must install into the SAME Steam library folder as BO3** — the #1
   documented cause of `file not found: scripts/zm/zm_usermap.gsc` build failures.
4. First launch of **Radiant** runs a one-time ~20 min asset conversion — let it
   finish before doing anything else in it.
5. **Two durable new-box gotchas (2026-07 lessons):**
   - The Treyarch tools **0xC0000005-crash with no message** unless the
     `TA_TOOLS_PATH` / `TA_GAME_PATH` **user env vars** are set. Set them.
   - **Smart App Control (SAC) must be OFF.** SAC blocks `gdtdb.exe`, so nothing
     builds — cod2map/Radiant/linker all assert on the missing `gdtDB\gdt.db`.
6. **Custom LUI needs the L3akMod DLL overwrite.** The public linker can't compile
   a `.lua` rawfile (`Lua not supported`) until `bin\libtiff64r.dll` is replaced
   with L3akMod v1.0.4 (dtzxporter.com/tools/l3akmod; needs the VS2013+VS2015 x64
   runtimes). Original backed up at `bin\libtiff64r.dll.acc-orig-backup`. Full LUI
   recipe: [docs/19_lui_pipeline.md](docs/19_lui_pipeline.md).
7. Re-run `.\tools\preflight_windows.ps1` — it also checks Windows Region **decimal
   symbol = "."** (EU locales break compile/light) and **16 GB RAM** (linker/light
   can OOM below that).

## 2. New machine / fresh clone → one-command restore

The whole restore is scripted. On a fresh clone (even on an existing box) run:

```powershell
.\tools\restore_machine.ps1 -ZipFile C:\path\acc_external_assets.zip   # first run
.\tools\restore_machine.ps1                                            # re-run anytime (idempotent)
```

It wraps: external-pack unpack + `check_external_assets.ps1` gate, `TA_*` env-var
set, Smart-App-Control check, L3akMod DLL check, `apply_bin_patches.ps1`, the GDT
deploys (`deploy_source_data.ps1`, `deploy_perk_shaders.ps1`), perk-glow FX regen,
`gdtdb`, and the repo→Mod-Tools sync. It does **not** install BO3/Mod Tools/Node or
the L3akMod DLL for you (§1). Prereqs it verifies are listed in the script header.

**External (game-rip) asset packs are NOT in git** (NSZ Brutus / Skye guns /
Charred zombies / Ronan perk-icon shaders — no redistribution licence). A fresh
clone has only the *references*, so the linker fails `no file for filespec` until
they're installed. Get a teammate's bundle
(`tools/unpack_external_assets.ps1 -ZipFile <zip>`) and make
`tools\check_external_assets.ps1` all-green before building (preflight does NOT
cover this). Paths: `tools/external_assets_manifest.ps1`.

## 3. Sync Repo → Mod Tools

We never edit inside `usermaps\` directly — edit in the repo, sync over. The repo
ships the complete usermap kit, so **no Launcher "New Map" step is needed**; the
sync creates the usermap folder.

```powershell
.\tools\sync_to_modtools.ps1 -DryRun   # preview
.\tools\sync_to_modtools.ps1
.\tools\preflight_windows.ps1          # now checks the synced paths too
```

What lands where:
- `scripts\*` → `usermaps\zm_abandoned_cyber_city\scripts\`
- `zone_source\`, `sound\`, `ui\`, `fonts\`, `localizedstrings\` → same-named
  folders under the usermap (mirror); `vision\`, `gamedata\` → copy
- `zone\*` → copied without deleting (Launcher writes `workshop.json` there)
- `map_source\zm\zm_abandoned_cyber_city.map` → `<BO3 root>\map_source\zm\`
  (Radiant reads map sources from the game root, not usermaps)
- `map_source\_prefabs\acc\*` → `<BO3 root>\map_source\_prefabs\acc\` (our custom
  clone prefabs; copy)
- `sound\aliases\*.csv` → **also** `<tools>\share\raw\sound\aliases\` (the
  sound-bank compile reads THAT path, not the usermap copy)
- `sound_assets\*` → **tools-root** `sound_assets\` (alias FileSpec paths are
  relative to it; copy — never purges the installed game-rip packs)
- Repo-owned `source_data\*.gdt` (acc_ssi, acc_weapon_variants) deploy via
  `.\tools\deploy_source_data.ps1` (NOT this sync); perk-shader GDT + art via
  `.\tools\deploy_perk_shaders.ps1`

**After any Radiant session, run `.\tools\sync_to_modtools.ps1 -Reverse`** so the
edited `.map` flows back into the repo — the repo is the source of truth. **After
any install-side GDT balance pass, run `.\tools\deploy_source_data.ps1 -Reverse`**
so the GDT edits land in git too (this is how `acc_weapon_variants.gdt` silently
went 2 MB stale, 2026-07-10).

### 3b. Split-install deploy (this machine — automatic)

On this box the Mod Tools installed to a **separate** folder from the game
(`...Call of Duty Black Ops III 455130` vs `...Call of Duty Black Ops III`). The
linker writes the built `.ff` into the **tools** `usermaps\`, but `BlackOps3.exe`
loads usermaps from the **game** folder. `tools\sync_to_modtools.ps1` creates a
**directory junction** `<game>\usermaps -> <tools>\usermaps` automatically
(idempotent), so every build is instantly loadable. Preflight verifies it. By hand
if ever needed:
```powershell
New-Item -ItemType Junction -Path "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III\usermaps" -Target "C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130\usermaps"
```

## 4. Build the map — headless, one command

**Agents (and the user) build with `build_map.ps1`; the Launcher GUI is NOT
required and compiling is NOT a user action.** The user's job is to TEST.

```powershell
.\tools\build_map.ps1            # FULL geometry build: asset-gate -> sync -> cod2map64
                                 # (BSP+navmesh, cwd=bin) -> Radiant LED bake -> linker -> verify .ff
.\tools\build_map.ps1 -GscOnly   # FAST path for GSC/CSC/.zone/.csv-only changes (linker only,
                                 # reuses the last cod2map64 BSP+navmesh) — ~seconds
.\tools\build_map.ps1 -Run       # build, then launch run_game.ps1 on success
```

Two rules that bite:

- **Build success = a FRESH `.ff` was written, NOT the linker exit code.** The
  linker prints `ERROR: Material … not found in gdtDB` for user-waived
  missing-but-substituted assets and exits nonzero, yet still packs a valid `.ff`.
  `build_map.ps1` waives those and fails only if no fresh `.ff` lands.
- **The Radiant LED bake is the gate.** After the pre-stage3 revert the map BAKES
  AGAIN (~157 light entities + ~15 reflection probes), so LED runs **by default** —
  `-SkipLED` is now a **red flag** that hides the `brush.cpp:1860` lightmapper
  regression. After ANY geometry/`.map`/material/sky/probe change, build WITH the
  LED bake, or use the fast gate `.\tools\_bake_test.ps1 <map.path>` (cod2map + LED,
  prints **BAKED** / **CRASHED**). If LED CRASHES, the change re-introduced the
  lightmapper-killing geometry — REVERT or FIX before testing. `-GscOnly` stays
  safe for script-only changes (BSP+lightmap reused, can't regress the bake).

The Launcher GUI (Compile / Light / Link → Build) still works if you prefer it, but
it's optional. On failure, work [docs/17_launch_runbook.md](docs/17_launch_runbook.md):
GSC error in an `_acc_` file → grep it for `TODO(acc-verify)` and compare the call
against the stock mirror (`tmp/bo3_stock_ref`, clone command in CLAUDE.md); missing
asset on a `.zone` line → it's usually normal usermap noise (see below), else
comment it with `//`; a Radiant/BSP error names a brush/entity → cross-reference the
CHANGELOG entity map.

## 5. Launch the built map: use Steam, NOT the Launcher's "Run"

On a split install the Launcher's **Run** checkbox does NOT reliably start the game —
it launches `BlackOps3.exe` directly, which BO3's Steam DRM refuses ("Steam must be
running to play this game" popup, then exits), even with Steam running and
`steam_appid.txt` present. Launch **through Steam** instead:

```powershell
.\tools\run_game.ps1            # engine args only — dev vs clean rides the BUILD
                                # (the level.acc_dev/acc_god hardcodes; the legacy
                                # -NoDev/-ClosedMap/... switches are no-ops)
```

It calls `steam://run/311210//<engine args>` and waits for load (~30-60 s; RAM climbs
to ~5 GB). `PLAY_NORMAL.bat` in the repo root is a double-click equivalent.

**Dev mode is ONE hardcoded flag.** `level.acc_dev` is a compile-time boolean set in
`acc_resolve_dev_flags()` (`scripts/zm/zm_abandoned_cyber_city.gsc`): ship state =
`level.acc_dev = false;`, test session = flip it to `true;` + rebuild. There is NO
dvar/launch-flag path — `+set acc_dev 1` does nothing (the dvar resolution was removed
2026-07-16). A dev build gives unlimited money, 25 starting Data Shards, all perk slots,
and the Mega-Bottle top-up; bosses run their **real** cadence (the early test spawns were
removed 2026-07-16), and debug prints ride `level.acc_dev` (the per-feature debug dvars
were deleted the same day). **There is no runtime dev console — never "set dvar X to
test".** Clean normal play = a build with the `= false;` ship lines (`prep_release.ps1`
Gate 0 enforces them, and FAILS if a dvar read reappears). Design: CLAUDE.md
(dev-mode section).

**CRITICAL #1 — the gametype must be `+set_gametype zclassic` (engine command), NOT
`+set g_gametype zclassic` (dvar).** The `g_gametype` dvar is immediately reset to
the session default by the engine (`callbacks_shared.gsc`), so a plain `+set` never
survives — the launch falls back to MP default `tdm`, can't find
`scripts/zm/gametypes/tdm.gsc` (absent in a ZM build), and hard-errors to a **black
screen**. `set_gametype` is the command the Launcher itself uses, and it sticks.
The repo launchers pass `+set_gametype zclassic`.

**CRITICAL #2 — Steam Launch Options must be EMPTY** when using `steam://run//<args>`
or the `.bat`. Steam *appends* Launch Options to the inline args → a **doubled
command line** that re-corrupts the gametype back to `tdm`. Pick ONE arg source:
Launch Options empty + the `.bat`/`run_game.ps1`, OR the engine args in Launch Options
launched from Steam's **Play** button — never both.

Steam must be running and logged in. **console_mp.log is the runtime oracle** (needs
`+set logfile 1`): the LAST lines are the fatal error; the wall of "Could not find
material/fx" (margwa/mech/DLC/`*_zm` weapon-table entries) is NORMAL usermap asset
noise, not the failure.

## 6. Test In-Game

1. Spawn in; with a dev build (`level.acc_dev = true;`) you get the full sandbox. Walk the systems loop from
   the test session guide ([docs/18_test_session.md](docs/18_test_session.md)) and
   the player guide ([docs/36_player_guide.md](docs/36_player_guide.md)): buy doors,
   flip power, buy/upgrade perks at the Neural Expansion Bay, hit the box, ride the
   Abyss Descent, trigger a boss round, work the Exo Suit / Armory / Reactor / Glitch
   Altar / Jukebox / Exchange.
2. If the game crashes at a script runtime error, the error names a `file:line` —
   disable that module (comment its call in `acc_main::init()` plus its
   `scriptparsetree` line in the `.zone`), rebuild `-GscOnly`, rerun. File every
   finding in CHANGELOG and tick items in [docs/15](docs/15_requirements_checklist.md).

## 7. Publish to Workshop

The publish/release procedure lives in [docs/34_release_runbook.md](docs/34_release_runbook.md)
(and `tools/prep_release.ps1`). Never publish the Workshop item **Public** until the
IP/credit review in [CREDITS.md](CREDITS.md) is done. Keep visibility **Private
(Hidden)** for dev builds; capture the generated `workshop.json` back into the repo
(`.\tools\sync_to_modtools.ps1 -Reverse`) so future publishes update the SAME item.

## 8. Day-to-Day Iteration

```powershell
.\tools\build_map.ps1 -GscOnly          # GSC/CSC/.zone/.csv change (seconds)
.\tools\build_map.ps1                    # any geometry/material/sky change (full + LED bake)
.\tools\build_map.ps1 -Run               # build then launch
.\tools\sync_to_modtools.ps1 -Reverse    # after any Radiant session (pull .map back to repo)
```

- The one-shot generators (`gen_zone_greybox.js`, `apply_*.js`, `gen_interactives.js`,
  etc.) have ALREADY been applied and refuse to re-run — geometry edits from here
  happen in Radiant.
- **Concurrent sessions clobber `.map` appends** — the user runs parallel sessions;
  whole-file `.map` rewrites erase other sessions' appended entities. Grep your
  markers before every geometry build.

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---|---|---|
| Anything feels off before building | — | `.\tools\preflight_windows.ps1` first; it names the exact problem |
| Fresh machine / clone won't build | Missing env vars / packs / DLL | `.\tools\restore_machine.ps1 -ZipFile <zip>` (§2) |
| `no file for filespec` at link | External packs not installed | `.\tools\check_external_assets.ps1`, then unpack a teammate's zip |
| Linker `Lua not supported` | L3akMod DLL not applied | Overwrite `bin\libtiff64r.dll` with L3akMod v1.0.4 (§1.6) |
| Tools crash 0xC0000005, no message | `TA_TOOLS_PATH`/`TA_GAME_PATH` unset | Set the user env vars (§1.5), relog |
| Nothing builds, `gdt.db` missing | Smart App Control ON | Turn SAC OFF (§1.5) |
| LED bake CRASHES on `brush.cpp:1860` | Geometry re-broke the lightmapper | Revert/fix the last geometry change; never ship a failed bake |
| Sync script won't run ("disabled") | Execution policy | `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |
| Map missing from Launcher list | Sync didn't run / wrong drive | Re-run sync with `-ModToolsRoot "<path>"` |
| Black screen on launch | Wrong gametype arg | Use `+set_gametype zclassic`; keep Steam Launch Options EMPTY (§5) |
| "I changed code but nothing changed in game" | Built stale (skipped sync) | The linker builds the DEPLOYED copy — sync THEN build |
| GSC compile error on `_acc_*` | Stock API drift | Grep `TODO(acc-verify)`; check [docs/14](docs/14_stock_api_verification.md) + `docs/research/` |
| Map doesn't appear after subscribing | Steam sync quirk | Unsubscribe, restart Steam, re-subscribe |
| `.gsc` not picked up | Missing zone line | Preflight diffs modules vs `scriptparsetree` lines |

## Verification bar

Real verification happens on this Windows box: build with `build_map.ps1`, confirm a
fresh `.ff`, and drive the systems loop in-game. Structural GSC lint (column-0 rules,
brace/paren balance, cross-module `#using` xref) runs in preflight; the stock-API
ledger is [docs/14](docs/14_stock_api_verification.md). Perishable claims
(compile-readiness, TODO counts) — grep `TODO(acc-verify)` / `TODO(acc-geom)`; don't
trust prose counts.
