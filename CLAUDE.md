# Abandoned Cyber City — session brief

Custom BO3 zombies map. Mission: systems-depth zombies map (Data Shards,
Cyberware tree, Overclocks, per-run randomization) on Steam Workshop.
**REQUIREMENTS.md is the design spec; code follows docs.** Roadmap: ROADMAP.md.

## Hard constraints

- This repo lives on **macOS**; BO3 Mod Tools are **Windows-only**. Nothing
  here can be compiled or play-tested locally — correctness comes from
  matching known-good references (see hard-won facts).
- Every substantive change: CHANGELOG.md entry + the relevant doc updated in
  the same commit.

## Code map (one line each)

- `map_source/zm/*.map` — Radiant source; 7-zone greybox + 8 buyable doors (script_flag enter_*), 3 inline mystery boxes (acc_box_*), 2 power switches (script_string corp/vault), all interaction triggers (kiosk/terminals/overload/boss spawn/PaP blockers). Generators in tools/ are ONE-SHOT (refuse re-apply); visual design: docs/map_design.svg (+png), regen via tools/gen_map_design.js. Tracker: docs/20_requirements_checklist.md; blockers: MISSING_REQUIREMENTS.md.
- `scripts/zm/zm_abandoned_cyber_city.gsc|.csc` — entry scripts (stock template structure + 4 `[acc]` hooks).
- `scripts/zm/zm_abandoned_cyber_city/_acc_*.gsc` — 21 custom modules; orchestrated by `acc_main` (exception: `_acc_perk_aura_blast` is called directly from the entry script — it hijacks the stock-but-unfinished `_zm_perk_electric_cherry` pipeline, see docs/13_perks.md Implementation Status).
- `zone_source/*.zone` — linker manifest (scriptparsetree lines for every script).
- `sound/zoneconfig/*.szc`, `zone/` — sound config + workshop publish assets.
- `tools/sync_to_modtools.ps1` — repo ↔ Mod Tools sync (run on Windows).
- `docs/18_first_build_checklist.md` — the e2e build/publish walkthrough.

## Hard-won facts — do not re-learn

- **BO3 GSC ≠ WaW GSC**: `function` keyword required on every definition;
  `#namespace x;` per module; `#using` not `#include`; `&func` pointers.
  Stock namespaces drop the file's leading underscore (`_zm_utility.gsc` →
  `zm_utility::`). Our convention mirrors it: `_acc_main.gsc` → `acc_main::`.
- **No `_zm::main()` in BO3.** Usermaps bootstrap via `zm_usermap::main()`
  (calls `load::main()` internally). Entry scripts live in `scripts/zm/`,
  NOT `maps/zm/` (that's WaW).
- **Zone manifest is `.zone`** (`>class,zm_mod_level` header, `scriptparsetree`
  for custom GSC, `col_map`/`gfx_map` BSP lines) — NOT a `rawfile` CSV.
- **Linker DOES support GSC subfolders under usermaps** — keep our
  `scripts/zm/zm_abandoned_cyber_city/_acc_*.gsc` layout. Hard evidence
  (verified 2026-06): shipped Workshop map `clixmods/zm_nuked` uses
  `scriptparsetree,scripts\zm\classic_features\*.gsc` + matching
  `#using scripts\zm\classic_features\...;`; UGX Mod
  (`treminaor/ugx-mod-bo3`) uses `scripts/zm/ugxm/*`; usermap
  `ohm-nabar/zm_building` uses 3-deep `scripts/Sphynx/commands/*`;
  `ColDog5044/zm_countryside` has linker-emitted
  `zone_source/all/scriptgdb/scripts/lilrobot/*.gsc.gdb` proving compile.
  Stock itself nests (`scripts/zm/gametypes/`). Slashes: `/` and `\` both
  fine in zone lines; `#using` uses `\`.
- **Radiant map sources live in `<BO3 root>\map_source\zm\`**, not under
  `usermaps\`. Never mirror that folder (holds `_prefabs/` + other maps).
- **`.csc` cannot call `.gsc`** (separate VMs). Client `_acc_` modules must be
  real `.csc` files (Phase 4).
- **Stock-API truth lives in docs/19_stock_api_verification.md** — the
  2026-06 ledger (211 verified / 52 fixed / 5 refuted, every fix cited
  `VERIFIED(acc)` in code). Headline traps: `callback::on_ai_damage` and
  `on_ai_killed` are register-only (NEVER dispatched — use
  `zm::register_actor_damage_callback` / 
  `zm_spawner::register_zombie_death_event_callback`); `"power_on"` and
  `"initial_blackscreen_passed"` are FLAGS (use `flag::wait_till`, bare
  waittill hangs); never write `player.score` (use `zm_score::` API, which
  rounds UP to multiples of 10); weapons are objects (`weapon.name`), PaP
  base lookup via `zm_weapons::get_base_weapon`; BO3 weapon names are
  class-based (`"ar_accurate"`=ICR-1, `"shotgun_fullauto"`=Haymaker — never
  `<name>_zm`); ZM perk specialties are `specialty_doubletap2` /
  `specialty_staminup`. Read the ledger before touching stock interfaces.
- **Local stock-scripts mirror** (gitignored, agents/greps depend on it):
  `git clone --depth 1 https://github.com/zeroy99/bo3_modtools tmp/bo3_stock_ref`
- **Ground truth sources** (all public GitHub, verified 2026-06):
  - Pristine Launcher zm template (map/gsc/csc/zone/szc/images):
    `FanaticSoftware/Skye-Weapon-Templates` → `rex/templates/01. ZM - Base/`
  - Shipped community map with full source: `MattFiler/zm_alien_isolation`
  - Stock `share/raw` scripts mirror: `zeroy99/bo3_modtools`
- **zm wiring entities** (from template): player spawns = `script_struct`
  targetname `initial_spawn_points` (script_int 1/2, noteworthy
  `initial_spawn`); zones = `info_volume` noteworthy `player_volume`,
  targetname `<zone>`, target `<zone>_spawners`; zombie spawn locations =
  structs targetname `<zone>_spawners` (noteworthy `riser_location` /
  `dog_location`); the AI spawner itself = one `actor_spawner_zm_factory_zombie`.
- **Wallbuy + perk-machine map anatomy** (verified vs stock scripts + shipped
  `zm_alien_isolation` source, 2026-06): wallbuy = script_struct targetname
  `weapon_upgrade` (`zombie_weapon_upgrade` = class weapon name, `target` →
  second struct carrying the gun's world `model`; chalk decal mesh optional —
  a shipped map omits it and even uses the wrong model, both fine). Perk
  machine = script_struct targetname `zm_perk_machine`, `script_noteworthy` =
  specialty, `model` = vending model (e.g. `p7_zm_vending_ads` for
  `specialty_deadshot`), optional `script_string` location filter matching
  `<gametype>_perks_<location>` (ours: `zclassic_perks_start_room`) — the
  stock `vending_*_struct.map` prefabs contain exactly this struct, so inline
  structs are equivalent (zm_alien_isolation ships jug that way). Single-chest
  maps ignore `level.start_chest_name` (`_zm_magicbox.gsc` size==1 branch).

## Verification bar

- GSC: structural lint (column-0 lines must be comment/directive/`function`/
  brace; brace+paren balance) — see CHANGELOG Unreleased entry for the last
  full pass. Real verification only happens on the Windows box:
  `docs/18_first_build_checklist.md`.
- Status of perishable claims (compile-readiness, TODO counts): grep
  `TODO(acc-verify)` / `TODO(acc-geom)`; don't trust prose counts.

## History

CHANGELOG.md (newest first). Current state: starting-room build kit complete,
awaiting first Windows compile.
