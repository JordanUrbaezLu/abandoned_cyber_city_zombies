# 29 — Major overhaul checklist (code-cited, no shortcuts)

Master tracker for the 9-item overhaul on the **MajorImprovements** branch. Every
item is backed by the 2026-06-13 code audit (15 agents; per-perk requirement→code
proof + per-area current-state/gaps/fix). Status legend:
`[ ]` todo · `[~]` in progress · `[x]` done (built) · `[!]` blocked/decision-needed.

Verified facts the whole batch leans on:
- **ICR-1 = `ar_accurate`**, **Man-O-War = `ar_damage`** (both STOCK rows in
  `zm_levelcommon_weapons.csv`, no import/GDT needed). Starting pistol =
  `pistol_standard` (keep).
- **World-space-over-head HUD rule:** use raw `NewClientHudElem`/`NewHudElem`
  (NEVER `hud::create*`, which setParents to the screen layer) + `SetWaypoint(TRUE)`
  + a `SetShader`. Our working **door markers** already do this — mirror them.
- **GSC cannot change** weapon recoil, fire rate, reload/swap/drink time, or
  per-stance move speed on a live weapon (those are weapon-GDT / engine). Several
  perk Mega claims therefore need a weapon-GDT (Phase-4) lift OR a card re-scope.

---

## A. Quick HUD/logic fixes

### [x] 1. PaP tier HUD → bottom-right
`_acc_pap_levels::pap_hud_loop` was `BOTTOM_LEFT`; moved to `BOTTOM_RIGHT` (-20,-100,
right-aligned), above the ammo counter. *(done, in this batch)*

### [ ] 9. Multi-pack flicker
Root cause (audit): the **stock** `pack_a_punch_machine_trigger_think` loop (0.1s)
keeps the stock trigger VISIBLE for upgraded guns (`weapon_supports_aat()` ignores
`level.aat_in_use`), fighting our `pap_tier_visibility`. `custom_validation` only
blocks the USE path, not the visibility loop. **Fix:** when our
`pap_tier_machine_watcher` finds the stock trigger, **stop its think loop** —
`t_stock notify("pack_a_punch_trigger_think")` (the loop `endon`s that, stock
`_zm_pack_a_punch.gsc:316`) — then own visibility entirely. Files: `_acc_pap_levels.gsc`.

---

## B. LUI features

### [x] 3. PaP card shows only the NEXT tier (batch 7 - accPapTier + Lua next-tier render)
Today `acc_hud.lua` (idx==10) hardcodes the whole ladder; the server pushes a
constant code 43 with no tier info. **Fix:** new lockstep clientfield
`accPapTier` (3 bits) in `_acc_lui.gsc`+`.csc`; `_acc_perk_info` `#using _acc_pap_levels`
and pushes `acc_pap_levels::get_tier(self, GetCurrentWeapon())` when near PaP; the
card renders one "Next: Tier N — <benefit> (cost)" line (or "MAX" at tier 5).
Files: `_acc_lui.gsc/.csc`, `_acc_perk_info.gsc`, `acc_hud.lua`.

### [~] 2. Mega indicator = glowing colored badge (batch 7); real stock-icon glow infeasible (engine-LUI + missing materials)
Today `_acc_mega_bottles::add_mega_glow_icon` is a pulsing TEXT hudelem. **Fix
(Option B, additive overlay that replicates the stock perk ordering):** new 9-bit
`accMegaMask` clientfield; a classed Lua widget `CoD.AccPerkGlowBar` that subscribes
to the stock `hudItems.perks` model tree to learn slot order, and draws an additive
glow `UIImage` over each Mega'd perk's slot. **Delete** the old text indicator.
Hard part: slot = acquisition order (shifts when a perk is lost) — the widget must
mirror the stock list, not assume a fixed slot. Files: `_acc_mega_bottles.gsc`,
`_acc_lui.gsc/.csc`, `acc_hud.lua`.

### [x] 8. Damage numbers + boss bar over the zombie's head (done right) — built (batch 2)
Done via the stock `entityheadicons` follow pattern: raw `NewClientHudElem` (never a
`hud::create*` factory, which screen-clamps) + world `.z` + `SetWaypoint(false)` +
`SetTargetEnt`. Damage numbers = text over the anchor; boss bar = per-player bg +
width-scaled "white" fill + name. `WorldToScreen` confirmed nonexistent in BO3.
Root cause (audit): both build elems with `hud::createFontString`/`createServerBar`
(→ setParent the screen layer) and pass `SetWaypoint(FALSE)` → they clamp to the
top of the screen. **Fix:**
- Damage numbers (`_acc_dev::show_dmg_number`): `NewClientHudElem(attacker)` (not
  `hud::createFontString`); anchor `Spawn("script_model",org); SetModel("tag_origin")`;
  `SetWaypoint(TRUE)` + a shader; height via the anchor offset; rise + fade as now.
- Boss bar (`_acc_health_bars::boss_bar_track`): `createServerBar` is a 3-elem
  screen composite that can't be one waypoint — replace with a single
  `NewHudElem`/`NewClientHudElem` fill icon (`SetShader("white",w,h)`, width scaled
  by health frac) + a `NewHudElem` name label, both `SetWaypoint(TRUE)` +
  `SetTargetEnt(boss)`. Files: `_acc_dev.gsc`, `_acc_health_bars.gsc`.

---

## C. Content / systems

### [~] 4. Rampage Inducer — REMOVED / superseded (2026-06-14)
**Superseded:** the Rampage Inducer (toggle device + `acc_rampage` dvar + spawn-count/
delay levers) was removed entirely and replaced by the all-round zombie **speed curve**
in `_acc_zombie_speed.gsc` — round 1 = 50% of base-game max, equal ramp to 100% at round
10, then +1 percentage point per round after. The per-run "sprint" modifier now drives
that system (`acc_mod_force_sprint` → ≥100% every round). See docs/11_enemies.md and the
CHANGELOG. Removed file: `_acc_rampage_inducer.gsc`.

### [x] 7. Arsenal = ICR-1 + Man-O-War only — GSC-only (batch 6, corrected 2026-06-14)
Box draws ONLY `ar_accurate`+`ar_damage`; **ALL** wall buys removed; overclock AR family
fixed to the real class names. No `.map` rebuild required for function.

**CORRECTION (user, 2026-06-14)** — the batch-6 pass left two real bugs, now fixed:
- **Box still gave the whole stock arsenal.** Setting `is_in_box=true` on our two guns is
  not enough: the map ships the STOCK `zm_levelcommon_weapons.csv` (zone:78) with ~47 rows
  flagged `in_box=TRUE`, and the box gate reads each weapon's live `is_in_box` per spin.
  Fix: `register_mystery_box_pool` now **clears `is_in_box` on every `level.zombie_weapons`
  entry first**, then re-enables only `ar_accurate`/`ar_damage`.
- **4 wall buys were still LIVE.** Slots with no pool entry (Haymaker/Drakon/Sheiva/Frag)
  were *skipped*, not killed — they kept dispensing their Radiant-default gun (the old
  "go dead" claim was wrong). User now wants **no wall buys at all** (incl. ICR + Bowie).
  Fix: new `remove_all_wallbuys()` walks `level._spawned_wallbuys` and
  `zm_unitrigger::unregister_unitrigger`s every stub in `pre_init` (before any player → no
  purchase trigger is ever built). `roll_wallbuy_pool`/`roll_wallbuy_slot`/
  `weapon_in_zm_table`/`is_rolled_onto_wall`/`apply_wallbuy_pool` deleted.
- Overclock AR family already `array("ar_accurate","ar_damage")` — unchanged.
- **Cosmetic removal (done 2026-06-14, full geometry rebuild):** unregistering kills the
  PURCHASE only; the wall gun model + chalk + fx are client-spawned and would remain as
  "ghost" walls. Deleted the 6 wallbuy entity PAIRS from the `.map` (ICR 34/35,
  Haymaker 36/37, Bowie 39/40, Drakon 41/42, Sheiva 44/45, Frag 46/47) + cod2map/LED/linker
  rebuild. `remove_all_wallbuys()` stays as the runtime safety net (no-ops once structs gone).
  **⚠️ The `vending_weapon_upgrade_spawnable` prefab (entity 23) is Pack-a-Punch, NOT a
  wallbuy — it is preserved.** The interleaved perk machines (33 Deadshot / 38 Widow's Wine /
  43 PhD Flopper) and the box are preserved too.
- Files: `_acc_map_randomizer.gsc`, `.map` (+ `docs/05`, `docs/07`, CHANGELOG).

### [~] 5. Per-perk code-proof audit + fix every gap (30 gaps — see table below)
The audit found ~30 claimed benefits with NO proving code. **DECISION (user, 2026-06-13):
RE-SCOPE.** Implement every **GSC-possible** gap (damage mults, HP, ammo, grenade
counts, web 1-hit, revive time, regen, immunity refactor) AND **rephrase/remove the
GSC-impossible claims** (recoil, fire rate, ×2 walk/×4 crawl, reload/drink/swap time)
from `acc_hud.lua` (AccPerkCards) + docs/13 so **no card ever claims something the
code doesn't do**. The hard ones (zero recoil etc.) may be revisited later via
engine/GDT, but for now the rule is: every remaining card bullet has proving code.
The table's "**GSC-impossible**" rows → re-scope; all others → implement.

#### Perk gap table (status · tier · benefit · resolution)
| Perk | Gap | Tier | Resolution |
|---|---|---|---|
| Jugger-Nog | survive 6 melee hits (vs stock 5) | base | implement: override `zombie_perk_juggernaut_health` / zombie melee tuning |
| Jugger-Nog | "7 hits" exact count | mega | implement: recompute +HP from measured per-hit dmg |
| Jugger-Nog | immune to boss abilities | mega | implement: make `_acc_boss` debuffs per-player + skip Ultimate-Tank owners |
| Quick Revive | +30% faster HP regen | base | implement: per-player regen via `player_healthRegen*` dvars gated on perk |
| Quick Revive | revive 40% faster (Savior) | mega | implement: `player.get_revive_time` override in apply_mega_effects |
| Quick Revive | +15% speed near downed ally | mega | implement: watcher → `SetMoveSpeedScale` while a teammate is in laststand |
| Speed Cola | ~30% faster swap (base) | base | **GSC-limited**: implement via weapon swap-time hook OR re-scope |
| Speed Cola | ~40% faster drink (base) | base | implement: shorten the stock vending drink wait for perk owners |
| Speed Cola | +65% reload (Mega) | mega | **GSC-limited** (reload scalar is GDT) → GDT or re-scope |
| Speed Cola | +15% swap / +15% drink (Mega) | mega | depends on base swap/drink existing first |
| Double Tap | +3% weapon damage (base) | base | implement: flat mult in `_acc_damage` keyed on perk |
| Double Tap | +50% fire rate (Mega) | mega | **GSC-impossible** (fire rate is GDT) → GDT or re-scope |
| Double Tap | +6% damage total (Mega) | mega | implement: mult in `_acc_damage` keyed on Mega flag |
| Stamin-Up | longer sprint (Mega) | mega | **GSC-limited** (no sprint-duration dvar) → re-scope or stance hack |
| Stamin-Up | ×2 walk speed (Mega) | mega | **GSC-impossible** (only one move-scale) → re-scope |
| Stamin-Up | ×4 crawl speed (Mega) | mega | **GSC-limited** (stance watcher) → re-scope or build watcher |
| Mule Kick | +30% reserve ammo (Mega) | mega | implement: `SetWeaponAmmoStock` per held weapon on apply/re-give |
| Mule Kick | +2 lethal (Mega) | mega | implement: raise lethal weapon max ammo +2 |
| Mule Kick | +2 tactical (Mega) | mega | implement: raise tactical weapon max ammo +2 |
| Deadshot | no head-snap on bosses (base) | base | **GSC-limited** (aim params are engine) → re-scope or engine |
| Deadshot | **zero recoil (Mega)** | mega | **GSC-impossible** (recoil is GDT) → GDT (Stabilizer Phase-4) or re-scope |
| Widow's Wine | +50% frag dmg +25% radius (base) | base | implement: mult in `_acc_damage` on grenade MOD |
| Widow's Wine | +50% EMP grenade (base) | base | blocked on the EMP grenade existing (Phase-4) |
| Widow's Wine | web nades 1-hit zombies (Mega) | mega | implement: damage branch in `_acc_damage` for spider-grenade MOD |
| Widow's Wine | hold 6 web nades (Mega) | mega | implement: set spider grenade max ammo 6 in apply_mega_effects |
| PhD Flopper | finished stock stub (cost/hint/machine-id) | base | done (`_acc_perk_phd_flopper.gsc` hijacks the stock cherry pipeline for the dive-explosion + immunity ability); Overcharge Mega = TODO |

---

## D. Geometry (HIGH RISK — last)

### [~] 6. Halve room sizes + add obstacles — **research done + Stage 0 built (2026-06-15)**
**Full research report + staged plan: [docs/36_map_tightening_research.md](36_map_tightening_research.md).**
**User decisions:** aggressive **~40-50%** shrink, **all 7 zones**, **Stage 0 tooling first**,
**geometry-only** (no difficulty re-tune yet — revisit speed cap at the first playtest).
**Stage 0 DONE:** `source_data/rooms.json` (source-of-truth) + `tools/validate_rooms.js`
(in preflight, 26 ok/0 err) + `gen_rooms.js` re-run guard + `_acc_perk_info.gsc` PaP
live-origin fix. Verified correction: vault/roof have **two overlapping shells**
(greybox outer + a larger `gen_rooms` shell) to reconcile in Stage 2.

Audit risk = **HIGH**. The greybox is procedurally generated and **coordinate-
coupled**: rooms, corridors, wall-gaps, door (trigger+brushmodel) pairs, zone
`info_volume`s, and ~40 gameplay entity origins all reference shared coordinates.
Naive global-scale breaks everything; the generators are one-shot/consumed.
**Plan (staged, one room at a time, build+run between each — full detail in docs/36 §6):**
1. Build a `.map`→JSON round-trip + single source-of-truth for room AABBs (kill the
   3-way duplication in `gen_zone_greybox.js` / `gen_map_design.js` / the baked `.map`).
2. Stage 1: **market_zone only** (leaf, 2 corridors, isolated) — shrink its brushes,
   recompute its 2 wall-gaps, move its 5 spawners + perks/box to the shrunk room,
   rebuild the zone volume, fix both door pairs. Build (cod2map→radiant LED→linker)
   + run; verify in-zone reads, doors flush, spawns path, interactables reachable.
3. Propagate to other leaves (alley/vault/roof), then hub (corp), then start/lab.
4. Obstacles pass per validated room: `script_wall` cover that avoids every
   `riser_location`/`dog_location`, keeps corridor mouths clear + ≥192–256 lanes.
5. Re-validate per-run randomization (power A/B, lab approach, decon bounds, corp
   cut-vertex, overload/boss points) after each room.
Files: `.map`, `tools/gen_*`, `docs/03_layout.md`, `docs/map_design.*`, several `_acc_*`.

---

## Execution order
A (1✓, 9) → C-fast (4✓, 7-GSC) → B (8, 3, 2) → C-content (5: GSC-possible gaps +
re-scope decision) → 7-.map → D (6, staged). Each chunk: implement → lint → build →
**user tests** → check off here + CHANGELOG.
