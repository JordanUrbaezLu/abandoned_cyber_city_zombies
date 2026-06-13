# BO3 Zombies Mapmaking — Reusable Knowledge Base

> **Purpose:** everything hard-won building `zm_abandoned_cyber_city`, distilled
> into a **map-agnostic** reference so the *next* map doesn't re-fight any of it.
> Replace `<map>` with your map name (e.g. `zm_my_new_map`). This is the doc to
> copy into a new project and read first. Project-specific notes live in
> CLAUDE.md; this is the portable layer.
>
> Companion docs in this repo: `18_first_build_checklist.md` (e2e build/publish),
> `23_launch_runbook.md` (launch deep-dive), `22_community_techniques.md` (142
> shipped-map techniques), `19_stock_api_verification.md` (stock-API ledger).

---

## 0. Quick reference (the commands that actually work)

```powershell
# Deploy repo -> Mod Tools install (the linker builds from the DEPLOYED copy!)
.\tools\sync_to_modtools.ps1

# Build the .ff directly (GSC-only change: just the linker; geometry reused)
& "<tools>\bin\linker_modtools.exe" -language english -modsource <map>

# Full pipeline if GEOMETRY changed (run in this order):
& "<tools>\bin\cod2map64.exe" -platform pc -navmesh -navvolume -loadFrom "<tools>\map_source\zm\<map>.map" "<tools>\share\raw\maps\zm\<map>.d3dbsp"
& "<tools>\bin\radiant_modtools.exe" -ledSilent +medium +localprobes +forceclean +recompute "<tools>\map_source\zm\<map>.map"
& "<tools>\bin\linker_modtools.exe" -language english -modsource <map>

# Launch (THE one load-bearing arg is +set_gametype zclassic)
start "" "steam://run/311210//+set fs_game <map> +set_gametype zclassic +devmap <map> +set developer 1 +set logfile 1"
```

`<tools>` on the dev box = `C:\Program Files (x86)\Steam\steamapps\common\Call of Duty Black Ops III 455130` (Steam appends the AppID `455130` on name collision — the game itself is the folder without it). Detect the tools root by the presence of `bin\modlauncher.exe`, never by folder name.

---

## 1. Build pipeline

The Mod Tools build is **4 stages**; you can run them by hand (no Launcher GUI):

| Stage | Tool | Produces | Re-run when |
|---|---|---|---|
| GDT DB | `gdtdb.exe /update` | asset DB | GDTs changed |
| Map/BSP | `cod2map64.exe ... -navmesh -navvolume` | `.d3dbsp` + navmesh/navvolume `.hkt` | **geometry** changed |
| Lighting | `radiant_modtools.exe -ledSilent +recompute` | LED lighting | geometry/lights changed |
| Link | `linker_modtools.exe -modsource <map>` | the `.ff` fastfile | **any** change (compiles GSC + packs) |

- **The linker compiles GSC from the DEPLOYED `usermaps\<map>\scripts` copy, NOT your repo.** Edit → **sync** → build, every time. Skipping the sync silently builds stale code and you chase a ghost ("I changed it but nothing changed in game"). Cost us hours. Verify a deploy landed (file size/mtime) before trusting a build.
- For **GSC-only** changes, run *only the linker* — the BSP from the last `cod2map64` is reused. ~4 s.
- Link order matters: geometry/gfx assets convert **before** scriptparsetree GSC compiles. A geometry-asset error aborts the build before GSC is ever tested — clear geometry errors first.
- The linker **stops at the first error** and compiles `#using`'d modules in order. A clean run validates everything up to the break point.
- `cod2map64` warns "NavVolume generation is skipped" when there's no `nav_volume` brush — harmless for ground-only zombies.

---

## 2. Launch & run (the saga, distilled)

Four independent gotchas; all four must be satisfied to get a playable match:

1. **Split-install junction.** Linker writes the `.ff` into the *tools* `usermaps`, but the game loads `usermaps` from the *game* folder. Junction them: `mklink /J "<game>\usermaps" "<tools>\usermaps"`. (`sync_to_modtools.ps1` auto-creates it.)
2. **Steam DRM.** A raw `BlackOps3.exe` launch is refused ("Steam must be running" → exits). Need `steam_appid.txt` = `311210` next to the exe **and** launch *through Steam* (`steam://run/311210//<args>`), not the raw exe. The Mod Tools Launcher's **"Run" checkbox launches the raw exe → don't use it** on a split install.
3. **Gametype = `+set_gametype zclassic`, NOT `+set g_gametype zclassic`.** `g_gametype` is a dvar the engine **resets to the session default** (`callbacks_shared.gsc`: `zclassic` for ZM, `tdm` for MP), so a plain `+set` never survives → falls back to `tdm` → `Com_ERROR: Script file not found: 'scripts/zm/gametypes/tdm.gsc'` → **black screen**. `set_gametype` is the engine command the Launcher itself uses (its "Set a gametype to load with map" knob); it sticks.
4. **Steam Launch Options must be EMPTY** when using `steam://run//<args>` — Steam *appends* them, producing a **doubled command line** that re-corrupts the gametype. Pick ONE arg source.

**Canonical launch:** see §0. Repo wraps it in `PLAY_TEST_MAP.bat` / `tools\run_game.ps1`.

**Steam launch-jam (automation hazard):** force-killing `BlackOps3.exe` (`Stop-Process`) + rapid `steam://run` relaunches makes Steam **silently ignore** launch requests (no process, no log). Fix: fully restart Steam (`steam.exe -shutdown`, relaunch, wait for full connect). Interactive user launches are unaffected. Don't hammer relaunches in a loop.

---

## 3. GSC dialect (BO3 ≠ WaW/BO1/BO2)

- `function` keyword on **every** definition. `#using` not `#include`. `#insert` for `.gsh` macros. `&func` / `&ns::func` for pointers.
- `#namespace x;` **after** every `#using`/`#insert`/`#define`/`#precache` (it terminates the preamble). A `#using` after `#namespace` = `unexpected TOKEN_USING`.
- Stock namespaces drop the file's leading underscore: `_zm_utility.gsc` → `zm_utility::`. Convention here: `_acc_main.gsc` → `acc_main::`.
- **No `_zm::main()`.** Usermaps bootstrap via `zm_usermap::main()` (calls `load::main()`). Entry scripts live in `scripts/zm/`, NOT `maps/zm/`.
- **Ternary must be fully paren-wrapped:** `( cond ? a : b )`. Bare `= cond ? a : b` or `return cond ? a : b` fail. No general ternary operator — it's a parenthesized-primary production.
- **No `.field` on a parenthesized expression:** `( call() ).name` errors; `call().name` is fine. Use a temp var for the paren case.
- **Reserved keywords:** `class` (TOKEN_CLASS), likely `new`. `type` is NOT reserved (stock uses it as a param).
- **Cross-module call needs BOTH** the `#using` AND the function to exist. Stock macro needs its `#insert`. `tools/lint_gsc_xref.js` statically verifies all four classes — run it before every build.
- **`.csc` (client VM) cannot call `.gsc` (server VM).** HUD/clientfield work that must be client-side needs real `.csc` modules.
- `IPrintLnBold` on a player shows in `console_mp.log` as `[ SCRIPTER] [msg]...` — great for proof-of-life. The `/# println #/` dev-block does NOT reliably route to that log.

---

## 4. Map anatomy (Radiant entity recipes, verified)

Stock prefabs live in `<tools>\map_source\_prefabs\zm\zm_core\`. Inline structs are equivalent to the prefabs (shipped maps do both).

- **Player spawns:** `script_struct` targetname `initial_spawn_points` (script_int 1..4, noteworthy `initial_spawn`).
- **Zones:** `info_volume` noteworthy `player_volume`, targetname `<zone>`, target `<zone>_spawners`. A zone only exists once `zone_init` runs — reached via `zm_zonemgr::add_adjacent_zone(a, b, flag)` or the `manage_zones` init list. The entry script wires the graph in `<map>::main()`.
- **Zombie spawn locations:** `script_struct` targetname `<zone>_spawners`, noteworthy `riser_location` / `dog_location`. One `actor_spawner_zm_factory_zombie` per map drives them.
- **Buyable doors:** `trigger_use` targetname `zombie_door`, `target <door_slab>`, `zombie_cost <n>`, `script_flag <enter_x>`. The `<door_slab>` = `script_brushmodel` (same targetname as the trigger's `target`) with `script_vector "0 0 130"` + `script_transition_time` (slides up on purchase). Stock `_zm_blockers::door_init` `flag::init`s the `script_flag` during load.
- **Perk machines:** `script_struct` targetname `zm_perk_machine`, `script_noteworthy` = specialty (e.g. `specialty_armorvest`), `model` = vending model, optional `script_string` location filter (`<gametype>_perks_<location>`).
- **Pack-a-Punch:** `misc_prefab` model `_prefabs/zm/zm_core/vending_weapon_upgrade_spawnable.map`, `script_string <gametype>_perks_<location>`.
- **Wallbuys:** `script_struct` targetname `weapon_upgrade` (`zombie_weapon_upgrade` = class weapon name, `target` → a second struct carrying the world `model`). Chalk decal optional.
- **Mystery box:** `zbarrier_zmcore_MagicBox` (+ `treasure_chest_use` trigger, `zombie_cost`). Single-chest maps ignore `level.start_chest_name`.
- **Power switch:** `_prefabs/zm/zm_core/power_switch.map`. Power = the `"power_on"` FLAG.
- **Template skybox trap:** the stock zm template `volume_sun` ships MP sky (`ssi1/ssi2` = `mp_havoc`, `ssi1_runtime_override` = `mp_havoc_overide`) → hard link error `xmodel 'skybox_mp_havoc_override' is missing`. Set all three to `default_day`. **Every new map from the template needs this.**

---

## 5. Verified stock APIs (the traps)

From `19_stock_api_verification.md` — read it before touching stock interfaces.

- **Damage:** `callback::on_ai_damage` / `on_ai_killed` are **register-only, never dispatched**. Use `zm::register_actor_damage_callback(&fn)` (modifying) and `zm_spawner::register_zombie_death_event_callback`. The damage callback `self`=victim; signature `(inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, ...)`; `return -1` = no change (read-only), else the new damage. Callbacks chain; later registrants see earlier modifications.
- **Flags:** `"power_on"` and `"initial_blackscreen_passed"` are FLAGS — use `flag::wait_till` (a bare `waittill` hangs / misses an already-set flag). `flag::exists(name)`, `flag::init(name)`, `flag::set/get`.
- **Score/points:** never write `player.score`; use `zm_score::add_to_player_score(points)` (rounds UP to multiples of 10). Reading `player.score` is fine.
- **Perks:** cost lives in `level._custom_perks[specialty].cost` — set it before the first purchase/machine read (in `main()`). `level.perk_purchase_limit` removes the 4-perk cap. ZM specialties: `specialty_doubletap2`, `specialty_staminup`, `specialty_armorvest`(Jug), `specialty_quickrevive`, `specialty_fastreload`(Speed), `specialty_additionalprimaryweapon`(Mule), `specialty_deadshot`, `specialty_widowswine`, `specialty_electriccherry`(reusable for a custom perk — it ships unfinished).
- **Weapons are objects** (`weapon.name`); BO3 names are class-based (`ar_accurate`=ICR-1, `shotgun_fullauto`=Haymaker) — never `<name>_zm`. PaP base lookup: `zm_weapons::get_base_weapon`.
- **Zones:** `level.zones[name].volumes` (info_volume ents); `player IsTouching(volume)` tests occupancy (stock `any_player_in_zone` pattern).
- **HUD:** `player hud::createFontString(font, scale)` (needs `#using scripts\shared\hud_util_shared`); `elem hud::setPoint("TOP_RIGHT", "TOP_RIGHT", x, y)` (underscored point names — `"BOTTOMLEFT"` silently anchors center). `elem SetText("DMG " + n)` accepts raw concatenated strings (stock `_zm.gsc:4679`); `SetValue(n)` for pure numbers. Through-walls world marker: a hudelem with `SetShader("white", w, h)` + `SetWaypoint(true)` + `SetTargetEnt(ent)` (`"white"` is the engine built-in, zero asset risk).
- **Custom perk machine hint** that isn't localized shows the raw `&"TOKEN"`. Quick fix: `trigger SetCursorHint("HINT_NOICON"); trigger SetHintString("raw text")`, re-applied on a loop (the perk think re-sets hints on power changes). Proper fix: a `.str` localize pass (Phase 4).

---

## 6. Dev/test sandbox toolkit (reusable patterns)

These let you exercise a whole map fast. In this repo they're **hardcoded ON** in the entry script + `_acc_dev.gsc` (tagged `HARDCODED`); re-gate behind a dvar before ship. **Put proof-of-life in the ENTRY script `main()`** — it provably runs (the map loads) independent of any module init, so a banner/effect there isolates "build live?" from "module init failed?".

- **Unlimited money:** loop, `if cur < floor: player zm_score::add_to_player_score(target - cur)`.
- **Unlimited shards / currency:** loop, top up your custom counter via its grant fn (clamps + syncs HUD).
- **Auto-power:** `if !(level flag::get("power_on")) level flag::set("power_on")` after `initial_blackscreen_passed` — perks/PaP/traps all gate on it.
- **Open the whole map:** for each `zombie_door` trigger: `flag::set(door.script_flag)` (activate zone, guard with `flag::exists`), then on the slab `GetEnt(door.target,"targetname")` do `ConnectPaths(); NotSolid(); Hide();`, then `door TriggerEnable(false)`. Walk everywhere from spawn.
- **Custom perk prices:** set `level._custom_perks[specialty].cost` in `main()`.
- **Damage indicators:** register a read-only `zm::register_actor_damage_callback` (returns `-1`), accumulate per-player `last_hit` + `dps_accum`, render to a HUD on a 0.2s loop (reset DPS every 1s).
- **Zone signage (greybox):** poll `player IsTouching` each zone's `level.zones[z].volumes`; on change, set a top HUD + an `IPrintLnBold` banner with the zone's display name.
- **Init-complete confirmation:** set `level.acc_init_complete = true` at the end of your orchestrator `init()`, and show it in the entry banner — distinguishes "module chain finished" from "a module init threw."
- **Disable lethal hazards for free-roam testing:** e.g. a decontamination/zone-seal system that `DoDamage`s players in a sealing zone will kill you on an open map. Gate it behind a `level.acc_disable_*` flag set by the dev harness; still emit any "complete" notifies downstream systems depend on.
- **Test boss on demand:** spawn a buffed normal zombie early (it looks normal — **announce it** with `IPrintLnBold`), drop your reward currency in bulk on its death.

---

## 7. Verification & debugging

- **`console_mp.log`** (`<game>\console_mp.log`, needs `+set logfile 1`) is the runtime oracle. The **last** lines are the fatal error. The wall of "Could not find material/fx" (margwa/mech/DLC/`*_zm` weapon-table entries) is **normal usermap asset noise**, not the failure. `abort_on_error TRUE` (dev mode) makes any script runtime error fatal — so a *clean load* proves every init ran without throwing.
- **Lints (run before every build):** `node tools/lint_gsc_xref.js` (xref/#using/macro/paren-field) + `tools/preflight_windows.ps1` (brace/paren balance, `#namespace` order, ternary paren-wrap, reserved keywords, zone↔module consistency, LF endings, install detection).
- **Adversarial workflows** were decisive for the stale-deploy bug — when "the code looks right but behaves wrong," an independent audit of the *pipeline/deploy* (not just the code) finds it.

---

## 8. Gotchas catalog (every trap we hit)

| Symptom | Cause | Fix |
|---|---|---|
| "changed code, nothing changed in game" | linker built the un-synced **deployed** copy | sync before every build |
| black screen, log ends `tdm.gsc` | `g_gametype` reset to MP default | `+set_gametype zclassic` |
| black screen, doubled command line | Steam Launch Options appended | empty Launch Options |
| "Steam must be running" popup, exits | raw-exe DRM | `steam_appid.txt` + launch via Steam |
| nothing opens, no log/dump | split-install, `.ff` in tools not game | usermaps junction |
| game won't launch via automation | Steam launch-handler jam from force-kills | restart Steam |
| link error `skybox_mp_havoc_override missing` | template `volume_sun` MP sky | set `ssi*` to `default_day` |
| random death mid-roam | decontamination/zone-seal `DoDamage` | gate behind a disable flag for testing |
| perk machine shows `ZOMBIE_PERK_TOKEN` | unlocalized hint istring | `SetHintString` override / `.str` |
| `Primitive expression field object...` | `.field` on parenthesized expr | temp var |
| `unexpected TOKEN_USING` | `#using` after `#namespace` | `#namespace` last |
| `unexpected TOKEN_CONDITIONAL` | ternary not fully paren-wrapped | `( cond ? a : b )` |

---

## 9. Repo tooling (portable scripts)

- `tools/sync_to_modtools.ps1` — repo ↔ Mod Tools mirror; auto-creates the junction + `steam_appid.txt` on split installs. `-Reverse` pulls `.map` edits back.
- `tools/preflight_windows.ps1` — ~25 readiness checks (run any time).
- `tools/lint_gsc_xref.js` — static GSC cross-reference/dialect lint.
- `tools/run_game.ps1` / `PLAY_TEST_MAP.bat` — DRM-safe launch (the canonical command).
- Local stock-scripts mirror (agents/greps depend on it):
  `git clone --depth 1 https://github.com/zeroy99/bo3_modtools tmp/bo3_stock_ref`
- Ground-truth sources (public GitHub, verified 2026-06): pristine zm template `FanaticSoftware/Skye-Weapon-Templates` → `rex/templates/01. ZM - Base/`; shipped map w/ source `MattFiler/zm_alien_isolation`; stock GDTs `shidouri/T7-GDT-Backup`. Drop-in kits catalogued in `22_community_techniques.md`.
