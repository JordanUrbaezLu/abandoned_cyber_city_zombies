# Onboarding — get the map running + contributing (with Claude Code)

Welcome! This is a custom **Black Ops 3 zombies** map built with the BO3 Mod Tools.
This page gets you from a fresh clone to a running game and your first change.
It's deliberately short — the deep references are linked at the end.

> **One golden rule:** you **edit in this repo**, then **sync** to the Mod Tools,
> then **build**. Never edit files inside `...\usermaps\` directly — the sync
> overwrites them. Forgetting to sync = "I changed the code but nothing changed
> in game" (the #1 time-waster).

---

## 1. What you need (Windows only)

The Mod Tools are Windows-only, so this has to be a Windows box.

- [ ] **Black Ops 3** (Steam) + **BO3 Mod Tools** (Steam, AppID 455130, free) —
  *install both into the SAME Steam library folder*, and in the Mod Tools
  **Properties → DLC** enable **"Additional Assets"** (~50 GB). Full walkthrough:
  [SETUP_WINDOWS.md](SETUP_WINDOWS.md) §1.
- [ ] **Visual C++ runtimes**: 2013 **and** 2015 x64 (needed by L3akMod, step 3).
- [ ] **Git**, **Node.js** (for the lint/tooling), and **Claude Code**.
- [ ] Windows Region decimal symbol = **"."** and **16 GB+ RAM** (the linker/light
  step OOMs below that). Preflight checks both.

---

## 2. Clone + the things that AREN'T in the repo

```bash
git clone <repo-url> abandoned_cyber_city_zombies
cd abandoned_cyber_city_zombies

# (a) Stock-scripts mirror — gitignored, but the lint + every "is this engine
#     function real?" check depends on it. Clone it into tmp/:
git clone --depth 1 https://github.com/zeroy99/bo3_modtools tmp/bo3_stock_ref
```

**(b) L3akMod** — required to *build* the custom LUI (`.lua`) HUD, or the linker
errors `Lua not supported`. Download **v1.0.4** from
<https://dtzxporter.com/tools/l3akmod>, and overwrite this one file in your
**Mod Tools** install (back up the original first):

```
<...\Call of Duty Black Ops III 455130>\bin\libtiff64r.dll
```

Credit the **D3V Team** for L3akMod in any release. (Details + why:
[docs/19_lui_pipeline.md](docs/19_lui_pipeline.md).)

**(c) The external asset packs** (Brutus, Skye guns, Charred zombies, perk-icon
shaders). A fresh clone has the *references* to these but not the asset files —
they're game-rip community packs that live in your **Mod Tools** install, not in
git (no redistribution licence — see [CREDITS.md](CREDITS.md)). Without them the
linker aborts with `ERROR: no file for filespec …`.

**Easiest path — get the zip from a teammate who already has them installed:**

```powershell
# Teammate WHO HAS them installed builds the zip:
.\tools\pack_external_assets.ps1                  # -> acc_external_assets.zip

# You (fresh clone) apply it, then verify:
.\tools\unpack_external_assets.ps1 -ZipFile <path>\acc_external_assets.zip
.\tools\check_external_assets.ps1                 # all-green = build won't filespec-fail
```

`unpack` drops every pack into the right Mod Tools folder and runs `gdtdb /update`;
then carry on with the normal sync + build below. Sharing the zip **privately** is
the supported path — these are partly unlicensed, so **never commit them to a
public repo**.

**Manual path — download each pack** (verified 2026-06-14; off-platform links rot,
credit each author; full provenance in [CREDITS.md](CREDITS.md)):

| Pack | Author | Provides | Where to get it | Installs to (Mod Tools root) |
|---|---|---|---|---|
| **NSZ Brutus** v1.0.4 | NateSmithZombies | r3/r10/r20 mini-boss | MEGA folder `https://mega.nz/folder/g7BHRCyI#5v2pEFoKQ058pAeWlHfmnA` → `NSZ_Brutus` · [modme #765](https://forum.modme.co/wiki/threads/765.html) · [UGX](https://www.ugx-mods.com/forum/mods/7/nsz-bo2-pack-zombie-boss-brutus/10676/) · fallback [modme #2831](https://forum.modme.co/wiki/threads/2831.html) | `model_export\_NSZ`, `xanim_export\_NSZ`, `sound_assets\_NSZ`, `share\raw\fx\_NSZ`, `share\raw\animtables\zm_brutus.*`, `share\raw\scripts\_NSZ`, `map_source\_prefabs\_NSZ` |
| **Skye weapon ports** (6 guns) | TheSkyeLord + LilRobot | AK-47, Tac-19, AE4, Five-seven, ASM1, Ripper | [UGX Master Hub #16874](https://www.ugx-mods.com/forum/full-weapons/84/skyes-weapon-ports-to-bo3-master-hub/16874/) ([modme mirror](https://forum.modme.co/wiki/threads/2565.html)) · wiring: [Skye-Weapon-Templates](https://github.com/FanaticSoftware/Skye-Weapon-Templates) · AW pack is Deflate64 (~1.27 GB) → unzip with WinRAR | `model_export\skye_ports`, `xanim_export\skye_ports`, `sound_assets\skye_ports`, `share\raw\fx\skye_efx`, `source_data\skye_*.gdt`, `map_source\_prefabs\zm\skye_prefabs` |
| **Charred Zombie pack** | Logical (rip via Greyhound/HydraX, Scobalula) | base-horde reskin | ⚠️ **No public link recorded — get the zip from the owner** (search UGX/Modme "Logical Charred Zombie") | `model_export\_custom_zombies\charredzombies`, `source_data\_charred_zombies.gdt` |
| **Perk-icon shaders** | Ronan (Cyberpunk Shaders) | 16 perk HUD icons (`i_acc_perk_*`) | Rip PNGs come with the zip — they are the ONLY gitignored part since the 2026-07-10 split; the GDT + our custom badge/OC/PaP art are **git-tracked**. After unpack, [`tools/deploy_perk_shaders.ps1`](tools/deploy_perk_shaders.ps1) overlays the repo-tracked files | `source_data\acc_perk_shaders.gdt`, `source_data\acc_perk_shaders\` |
| **West Electric Cherry machine** (EC-machine-only lift) | Westchief596 ([West] Community Perk Collection v2.7; machine templates Betiroval/F3ARxReaper666/HarryBo21) | the real EC vending model `electric_cherry_model` | full pack from Westchief596 (Discord `@westchief596`); the owner keeps the zip. EC-only lift recipe: CHANGELOG 2026-07-01 | `source_data\acc_west_electric_cherry.gdt`, `_custom\westchief596\perks\Electric Cherry` |
| **HB21 Civil Protector** v2.0.0 | HarryBo21 (+ ~50 pack credits) | ally robot AI (`archetype_ally_zod_robot_companion_ar/_gold_ar`) | UGX/Modme "HarryBo21 Civil Protector" (`hb21_civil_protector_v2.0.0.rar`). ⚠️ **Install needs 3 fixes** (all in the teammate zip already): 2 stub fuse `.efx` (the "HB21 FX library" dep we don't have), weapon GDT retargeted arak→`vm/wm_t9_ak47` + camo/grenade blanked, 2 `.efx` `gfx_smk_*`→`gfx_fire_*` material swaps — recipe in memory `hb21-civil-protector-integration` + CHANGELOG 2026-07-02 | `model_export\black_ops_3\c_zom_zod_robot_protector`, `xanim_export\black_ops_3\ai_robot_*` + `ai_cmpn_*`, `source_data\c_zom_zod_robot_protector.gdt`, `share\raw\{fx,behavior,animstatemachines,animtables,accuracy,sound\aliases}`, `sound_assets\{chr\robot,en\vox\scripted\zod,fly,zmb\ai\civil_protector,…}`, `map_source\_prefabs\zm\harrybo21_prefabs` |
| **Panzer / mechz** *(optional, WIP — not shipped yet)* | Spiki | future heavy boss | [modme #3087](https://forum.modme.co/wiki/threads/3087.html) (MEGA, password `Chungus4Prez`) | `model_export\*mechz*`, `source_data\*mechz*` *(confirm on import)* |

> ⚠️ **All of these are game-rip and not Workshop-publishable as-is** — keep the
> Workshop item **Private** until the IP/credit review in [CREDITS.md](CREDITS.md)
> is done. **The table above is a SAMPLE (the oldest packs) — the single source of
> truth is [`tools/external_assets_manifest.ps1`](tools/external_assets_manifest.ps1)
> (33 packs as of 2026-07-10, incl. Apex weapons, HB21 bows + FX library, Panzer,
> BOTD zombies, T7 carves…), and `.\tools\check_external_assets.ps1` prints exactly
> what your machine is missing, with per-pack download links.**

---

## 3. Check your machine, then sync

**One command restores a machine** (new box OR fresh clone on an existing box —
idempotent, safe to re-run anytime):

```powershell
.\tools\restore_machine.ps1 -ZipFile <path>\acc_external_assets.zip   # first run on a new machine
.\tools\restore_machine.ps1                                           # re-run anytime (no zip needed)
```

It chains everything in the right order: TA_* env vars + Smart-App-Control gate →
external-pack unpack + check → bin patches (`converter_gdt_dirs` `_custom` line,
L3akMod check) → stock `zbarriers.gdt` PaP patch → repo-owned GDT deploys
(`deploy_source_data.ps1`, `deploy_perk_shaders.ps1`) → perk-glow FX regen →
`sync_to_modtools.ps1` → `gdtdb /update`. The individual pieces, if you prefer:

```powershell
.\tools\preflight_windows.ps1    # ~30 checks; names the exact problem if any
.\tools\sync_to_modtools.ps1     # copies repo -> Mod Tools usermap (+ junction)
```

Preflight all-green = you're ready to build. The sync also auto-detects your Mod
Tools path (by `bin\modlauncher.exe`) and bridges the split-install junction, so
the game can find the built map. Re-run it any time you're unsure.

---

## 4. Build + play

**Build with [`tools/build_map.ps1`](tools/build_map.ps1) — the one-command headless
pipeline.** No Launcher GUI needed (compiling is not a manual step). Pick the mode by
WHAT you changed — getting this wrong is the #2 time-waster ("I changed it but nothing
changed in game"):
- **GSC / `.csc` / `.zone` / `.csv` / `.lua` only (fast, ~10s)** — linker only, BSP +
  lightmap reused:
  ```powershell
  .\tools\build_map.ps1 -GscOnly
  ```
- **Geometry (`.map`), a material/sky/probe, OR a weapon GDT changed** — a relink is
  **not enough**; it silently reuses the old baked geometry/GDT. Run the **full** build,
  which chains `gdtdb /update` → `cod2map64` (`.map` geometry + navmesh) → **Radiant LED
  bake** → linker:
  ```powershell
  .\tools\build_map.ps1
  ```

> **The LED bake is the gate.** After ANY geometry/`.map`/material/sky/probe change, run
> the FULL build **with** the LED bake — never `-SkipLED` (it's a RED FLAG that hides a
> lightmapper regression). `.\tools\_bake_test.ps1 <map.path>` is the fast pass/fail check
> (prints **BAKED** / **CRASHED**). **Build success = a FRESH `.ff` was written**, not the
> linker exit code — the linker prints `ERROR:` for waived-missing materials yet still
> packs a valid `.ff`. (The Launcher GUI's Build/Compile does the same steps if you prefer
> it; leave its "Run" checkbox UNCHECKED — it trips Steam DRM on this setup.)

**Play** — double-click **`PLAY_TEST_MAP.bat`** (or `.\tools\run_game.ps1`). It
launches through Steam with the right dev args.

> **Two launch gotchas** (both solved by the `.bat`, don't fight them):
> the gametype must be `+set_gametype zclassic`, and your Steam **Launch Options
> must be EMPTY** (Steam doubles the args otherwise). See
> [docs/17_launch_runbook.md](docs/17_launch_runbook.md).

You spawn in Spawn. The launch scripts pass dev **flags**, so you get a
sandbox: unlimited money + Data Shards, power on, whole map open, a boss on
round 2. Those flags are all opt-in — **launch with no `acc_` flags and you get
the clean consumer game** (closed map, earn your own money, decon hazard live).
Full list + recipes: [docs/22_flags_reference.md](docs/22_flags_reference.md)
(`run_game.ps1 -NoDev` = clean game, `-ClosedMap` = sandbox but map closed).

---

## 5. The day-to-day loop

```
edit in the repo  →  .\tools\sync_to_modtools.ps1  →  build  →  PLAY_TEST_MAP.bat
```

- **Always sync before building** (the linker compiles the *deployed* copy).
- After editing geometry in **Radiant**, run `.\tools\sync_to_modtools.ps1 -Reverse`
  to pull the `.map` back into the repo (the repo is the source of truth).
- The runtime oracle is `<game>\console_mp.log` (server `IPrintLnBold` shows as
  `[ SCRIPTER]` lines). Custom **LUI** errors show on-screen as `UI Error <code>`,
  not in the log.

> **Heads-up — guns "swap" themselves by design.** Perks/abilities that change baked
> weapon stats (Deadshot recoil, Double Tap fire-rate/swap, Speed Cola reload) work by
> hot-swapping your gun for a cloned **variant "twin"** with scaled GDT fields — the
> engine has no per-player recoil/fire-rate setter. The swap engine is
> [`_acc_weapon_variants.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc)
> (read its header first). Twins are generated by `tools/apply_recoil_overhaul.js`, and the
> **GSC allow-list + zone `weaponfull` lines + `source_data/acc_weapon_variants.gdt` must
> stay in lockstep** — regenerate and re-list all three together, then full-Compile. Turn
> on `acc_variants_debug 1` to watch swaps print on-screen.

---

## 6. Working with Claude Code

- **`CLAUDE.md` loads automatically** — it's the project brief + a "hard-won facts,
  do not re-learn" list (BO3 GSC dialect, the LUI/L3akMod pipeline, launch fixes).
  Skim it before your first task; it'll save you the traps we already hit.
- **Lint before every build** — these catch most mistakes statically:
  ```powershell
  node tools\lint_gsc_xref.js        # cross-refs, #using, function pointers resolve
  .\tools\preflight_windows.ps1      # GSC structure (ternaries, namespace order, braces) + machine state
  ```
- **Verify engine functions against `tmp/bo3_stock_ref` before using them.** Dev
  mode is `abort_on_error TRUE`: one unresolved/misspelled engine call is a *fatal*
  load error. The lint validates our own cross-refs but **not** engine builtins —
  grep the stock mirror to confirm a function exists + its signature.
- **Conventions:** every substantive change gets a **CHANGELOG.md** entry + the
  relevant doc updated *in the same commit*. Branch off `main`; don't commit/push
  unless asked.

---

## 7. Where to read more

| You want… | Go to |
|---|---|
| The design spec (what every system should do) | [REQUIREMENTS.md](REQUIREMENTS.md) |
| Project brief + hard-won facts (Claude reads this) | [CLAUDE.md](CLAUDE.md) |
| Portable BO3 mapmaking reference | [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md) |
| What every perk does (base + Mega) | [docs/10_perks.md](docs/10_perks.md) |
| Weapon-variant "twins" (recoil/fire/reload per perk) | [`_acc_weapon_variants.gsc`](scripts/zm/zm_abandoned_cyber_city/_acc_weapon_variants.gsc) header + [docs/10_perks.md](docs/10_perks.md) |
| Adding a new gun to the box | [docs/21_adding_a_gun_runbook.md](docs/21_adding_a_gun_runbook.md) |
| What changed recently | [CHANGELOG.md](CHANGELOG.md) |
| Full Windows setup + publish | [SETUP_WINDOWS.md](SETUP_WINDOWS.md) |
| Launch troubleshooting | [docs/17_launch_runbook.md](docs/17_launch_runbook.md) |
| All dev/test/tuning flags (dvars) | [docs/22_flags_reference.md](docs/22_flags_reference.md) |
| Custom LUI / HUD pipeline | [docs/19_lui_pipeline.md](docs/19_lui_pipeline.md) |
| The code map | [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) |
| What's left to build | [docs/15_requirements_checklist.md](docs/15_requirements_checklist.md) |

Stuck? Run `.\tools\preflight_windows.ps1` first — it usually names the exact
problem. Then check the Troubleshooting table in
[SETUP_WINDOWS.md](SETUP_WINDOWS.md). Welcome aboard.
