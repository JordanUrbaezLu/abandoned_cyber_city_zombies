# 19 - Stock API Verification Ledger

**What this is.** On 2026-06-11 every stock-API touchpoint in our 20 GSC files
was verified against the real Treyarch script sources (a local clone of the
stock `share/raw/scripts` mirror) by a multi-agent review: one verifier per
script file plus four external-evidence researchers, with every non-clean
finding re-checked by an independent adversarial reviewer before any fix was
applied. **Tally: 211 claims verified clean, 52 findings confirmed and fixed,
5 findings refuted (no change needed).**

Every applied fix is marked `VERIFIED(acc)` in the code with the stock
`file:line` evidence inline (46 citation comments). Grep `VERIFIED(acc)` to
see them all; grep `TODO(acc-verify)` for the 8 that remain (all are
Phase 3/4 implementation stubs - wave spawners for the two events, cyberware
move-speed wiring, `getentitynumber` stability, primary-weapon check - none
block the first build).

## Ground truth setup (re-run anytime)

```bash
# from the repo root - the mirror is gitignored, ~40MB
git clone --depth 1 https://github.com/zeroy99/bo3_modtools tmp/bo3_stock_ref
```

550 `.gsc` + 318 `.csc` + 116 `.gsh`, matching the Mod Tools install's
`share/raw/scripts`. All `file:line` citations in code comments and below
refer to this tree.

## The headline traps (cost us real bugs - do not relearn)

| Trap | Truth | Evidence |
|---|---|---|
| `callback::on_ai_damage` / `on_ai_killed` | Registration exists, **no dispatch site anywhere in stock** - handlers never run. Forum-circulated 13-arg signature belongs to a different system. | grep of all 550 `.gsc`; only `#"on_ai_spawned"` dispatches (`spawner_shared.gsc:583`) |
| Damage modification | `zm::register_actor_damage_callback` - 12 positional args ON the AI; return `-1` = unchanged (later callbacks still run), else return becomes the damage | `_zm.gsc:5824-5861`; stock user `_zm_powerup_weapon_minigun.gsc:53` |
| `level waittill("zombie_killed")` | Never fires - that notify is player-entity, no-args, insta-kill path only. Use `zm_spawner::register_zombie_death_event_callback` (runs ON the zombie, arg = attacker; mod/hitloc = `self.damagemod`/`self.damagelocation`) | `_zm_powerups.gsc:1463`; `_zm_spawner.gsc:2463/2344/1790` |
| `"power_on"`, `"initial_blackscreen_passed"` | FLAGS, not notifies - bare `waittill` hangs if already set; use `flag::wait_till` | `_zm.gsc:1612/1615`; `flag_shared.gsc:240` |
| `callback::on_ai_spawned` handler shape | Dispatched with NO args on the spawned actor: handler is zero-param, uses `self` | `callbacks_shared.gsc:43-49` |
| `player.score` direct writes | Desync `pers["score"]`/stats/notifies. Spend: `zm_score::minus_to_player_score`; award: `add_to_player_score` (**rounds UP to multiple of 10** - pre-quantize shares) | `_zm_score.gsc:521/528/551` |
| Suppressing stock kill points | `zm_score::register_score_event("death"/"ballistic_knife_death", &fn)` - return replaces the award. `level.zombie_score_callback` does not exist | `_zm_score.gsc:45/147` |
| Weapons | `GetCurrentWeapon()` returns an OBJECT (compare `weapon.name`); PaP base lookup is table-driven via `zm_weapons::get_base_weapon` (never string-strip; `rootWeapon.name` keeps `_upgraded`) | `_zm.gsc:5288`; `_zm_weapons.gsc:1624` |
| BO3 weapon names | Class-based, unsuffixed: `"shotgun_fullauto"` (Haymaker), `"ar_accurate"` (ICR-1 - `ar_standard` is the KN-44!), `"sniper_fastsemi"` (Drakon), `"shotgun_semiauto"` (Brecci), `"ar_longburst"` (XR-2), `"sniper_fastbolt"` (Locus), `"bowie_knife"`. `<name>_zm` is BO1/BO2 and matches nothing | grep of every `GetWeapon("...")` in stock; AR/sniper mapping from GDT naming - confirm on first compile |
| ZM perk specialties | `"specialty_doubletap2"`, `"specialty_staminup"` (`specialty_rof`/`specialty_longersprint` are giant-legacy/MP strings) | `_zm_perks.gsh:26-27` |
| Player downed check | `player.isdowned` does not exist; use `zm_utility::is_player_valid` (laststand-aware) | `_zm_utility.gsc:1600`; `_zm_laststand.gsc:200` |
| Dynamic struct members | `obj.(name)` is not GSC - use string-keyed arrays `obj[name]` | stock pattern `_zm.gsc:3054` |
| Promoting freshly spawned zombies | `zombie_spawn_init` runs at frame end and CLOBBERS health - wait for `zombie.zombie_init_done` first | `_zm_spawner.gsc:295/389`; pattern `_zm_ai_faller.gsc:168` |
| Zombie speed scaling | `SetMoveSpeedScale` is for players; zombies are anim-driven - `ASMSetAnimationRate` (Widow's Wine pattern). Also: `zm_usermap` resets player move scale to 1 on EVERY spawn - reapply after `"spawned_player"` | `_zm_perk_widows_wine.gsc:443`; `zm_usermap.gsc:336` |
| AI teleports | Clamp to navmesh first: `GetClosestPointOnNavMesh` then `ForceTeleport` | `shared/ai/zombie.gsc:1192-1212` |
| Round waits | No `util::waittill_round`; loop `level.round_number` + `waittill("between_round_over")`. Fast-forward: `zm_utility::zombie_goto_round(n)` | `_zm.gsc:4555`; `_zm_utility.gsc:5972` |
| Round-1 hooks | `level._zombie_custom_add_weapons` is consumed synchronously INSIDE `zm_usermap::main()` - set it before the bootstrap | `zm_usermap.gsc:135` → `_zm_weapons.gsc:678` |
| Mystery Box initial location | `level.start_chest_name` is read ~0.05s after magicbox init - set it in `pre_init`, not at blackscreen | `_zm_magicbox.gsc:58/96/223` |
| Melee mod strings | `MOD_MELEE`, `MOD_MELEE_WEAPON_BUTT`, `MOD_MELEE_ASSASSINATE` (no "...ASSASSINATION") | `_weapon_utils.gsc:25` |
| Headshot hitlocs | `"head"`/`"helmet"` (stock); `"neck"` is a real hitloc we ADD by design; `"j_head"` is a bone tag, never a hitloc | `_globallogic_utils.gsc:334` |
| Power off/on from script | No `zm_power::turn_power_off_all`; clear/set the `"power_on"` flag (stock watcher reacts). Perks pause: `zm_perks::perk_pause_all_perks`/`unpause` | `_zm_power.gsc:163-169/773`; `_zm_perks.gsc:1295/1314` |
| GSC `#define` | File-local; sharing requires a `.gsh` + `#insert`. `#using` never shares macros | stock convention (`_zm_perks.gsh`) |
| Self-notify ordering | A synchronous call that notifies before the caller's `waittill` is armed = permanent hang (GSC notifies are not latched). Thread the worker, then wait | applied in `_acc_boss.gsc` |

## External evidence (beyond the script mirror)

- **GSC subfolders under usermaps: SUPPORTED — keep our layout.** Shipped
  proof: `clixmods/zm_nuked` (Workshop id 3558354570) uses
  `scriptparsetree,scripts\zm\classic_features\*.gsc` with matching nested
  `#using`; UGX Mod uses `scripts/zm/ugxm/*`; `ohm-nabar/zm_building` nests
  3 deep; stock itself nests (`scripts/zm/gametypes/`).
- **Our `.zone` is structurally complete.** Validated line-by-line against 7
  shipped zones (header, skybox/luts, col/gfx_map, sound, scriptparsetrees,
  levelcommon stringtable). `//` comments proven safe. The `sound,<map>` line
  is safe with only the stock-template `.szc` and no alias CSVs
  (`zm_phasmo` ships exactly that combination).
- **Publish flow.** `workshop.json` is Launcher-generated (do not hand-author;
  it reuses `PublisherID` on update). Publish does NOT verify a build exists -
  Compile+Light+Link first or you upload an empty item. Before a public
  release, set Build Language to all languages and re-link. Common failures +
  fixes are in [18_first_build_checklist.md](18_first_build_checklist.md).

## Method note

Verification = a claim-by-claim grep of the stock sources with required
`file:line` citations, then an independent adversarial re-check of every
proposed fix (5 findings died in that pass - e.g. claims that were actually
fine). What this can NOT verify: GDT-level data (the AR/sniper marketing-name
mapping), linker behavior, runtime feel. Those gates remain on the Windows
box - see the checklist's known-risks list.
