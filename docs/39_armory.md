# 39 — The Armory (upper room: team weapon rack + mega-bottle exchange)

A new **upper room** reached by **staircases up from the Plaza**, housing two team-support
stations (user, 2026-07-07). Distinct from **The Exchange** ([docs/37](37_transfer_vault.md)),
which is the *shared resource vault* **below** the Plaza.

> Code: [`_acc_armory.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) ·
> Orchestration: [`_acc_main.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc) `acc_armory::init()` ·
> Zone line: [`zm_abandoned_cyber_city.zone`](../zone_source/zm_abandoned_cyber_city.zone) ·
> Room geometry (BUILT): [`tools/gen_upper_room.js`](../tools/gen_upper_room.js) · Dvars: [docs/22](22_flags_reference.md)

**Status: BUILT + LIVE.** Stations shipped 2026-07-07; both stations got distinct station meshes in the
2026-07-09 remodel — weapon rack = `p7_con_cargo_train_armory_cabinet`, bottle exchange =
`p7_zm_vending_wonder` (both pack from the stock gdtDB, `#precache` in `_acc_armory.gsc`).

## Why it exists

Two user asks:
1. **Give guns to teammates** — a station where a strong player can hand a spare weapon to a teammate.
2. **Exchange extra Mega Bottles** — a *new sink* for surplus bottles (The Exchange already **moves**
   bottles between players; this **converts** them).

Both are **QoL team-support** stations, so they live together in one always-reachable upper room.

## What "mega bottle" is here (for reference)

An **Empty Mega Bottle** is a per-player carried integer (`player.acc_mega_bottles`,
[`_acc_mega_bottles.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_mega_bottles.gsc)). +1 to every player
on each boss kill; the only *native* sink is Mega-upgrading an owned perk at a machine. "Surplus" isn't a
formal concept — the Armory exchange just spends whatever the player chooses to feed it.

## Station 1 — Team Weapon Rack (pooled)

Chosen model: a **shared pool** (deposit / withdraw), **not** a directed give — the same call the user made
for The Exchange, and it sidesteps the co-op `closest_player_override` / stale-snapshot hazards (no player
targeting at all). Mesh: **`p7_con_cargo_train_armory_cabinet`** (the long Conduit armory cabinet — its long
X axis spans the two flanking pads at ±55, `spawn_rack_station`).

- **DEPOSIT pad**: racks the player's **currently-held primary** into `level.acc_armory_rack` (a FIFO list
  of weapon objects) and `weapon_take`s it. Rejects: nothing held / melee / mines / non-primary (pistol,
  equipment) / **capped wonder weapons** (a racked wonder could let a 2nd player slip past the per-match
  claim cap — `acc_map_randomizer::wonder_cap_key`). Refused when the rack is full (`acc_armory_rack_max`, 8).
- **WITHDRAW pad**: gives the **oldest** racked weapon (FIFO, like the Exchange item locker) to the presser.
  **Mandatory free-slot gate** first (`weapon_give` at the weapon limit silently deletes the held gun);
  `b_switch_weapon = false` so there's no mid-fight view-yank; refused if the presser already carries it.
- **Free** (giving up the gun *is* the cost — untaxed, like the Exchange item locker).
- **Balance**: a gifted gun auto-tunes — `acc_weapon_balance_mult` is name-keyed / owner-agnostic
  (`_acc_damage.gsc`), so no per-give work.

Two flanking pads share one kiosk (the Exchange multi-pad idiom, since BO3 use-triggers are single-button).

## Station 2 — Mega-Bottle Exchange (1 bottle → random implant)

Mesh: **`p7_zm_vending_wonder`** (the stock Wonderfizz chassis — reads as "bottle → a random reward",
`spawn_bottle_station`). Spend **`acc_armory_bottle_cost`** (1) Empty Mega Bottle for a **random Implant**
(boss item). In this map an
"item" IS an implant, so the exchange drops one via `acc_boss_items::grant_challenge_reward(player.origin)`
→ `spawn_pickup`: a **floor-snapped, free-for-all** pickup that **self-despawns after 60 s**
(`ACC_ITEM_DROP_LIFETIME_SEC` / `watch_lifetime`). The player grabs it (carry) and enables it at an **Implant
Bench** — a dup they already own converts to Data Shards at grab (`watch_pickup`), exactly like a boss drop.

> History: v1 dropped weighted **powerups** (Max Ammo / Insta-Kill / …) — a misread of "a random item".
> User 2026-07-07: "it should be dropping implants instead." Now it drops implants.

## Co-op crash-safety (this branch = `fix/coop-crash-hardening`)

- `zm_utility::is_player_valid` gate at **both** ends of every loop (downed/spectating/disconnected).
- No `entity == undefined` compares; no stale `GetPlayers()` snapshot held across a yield.
- Pool-safe feedback only (`acc_utility::hud_msg`), never raw `hud::create*`.
- Constant/bounded hint + toast strings (weapon names are low-cardinality, rack size ≤ 8 → string-cache safe).
- Free-slot gate before `weapon_give` (the destroy-held-gun trap).

## Files

- [`_acc_armory.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc) — `acc_armory::init()`
  + `spawn_stations()` + rack (`deposit_gun`/`withdraw_gun`) + exchange (`bottle_loop`/`deliver_reward`).
- Wired in `_acc_main.gsc` (`#using` + `acc_armory::init()` after `acc_transfer`), `.zone` (`scriptparsetree`).
- **Dvars** in [docs/22](22_flags_reference.md): only `acc_armory_rack_max` (8) + `acc_armory_bottle_cost` (1).

## Build / test

- **Stations = pure GSC** (script-spawned `trigger_radius_use` pads + `#precache`d station models) →
  `.\tools\build_map.ps1 -GscOnly` (linker only, **zero LED-bake risk**). Built + linked clean 2026-07-07;
  the 2026-07-09 station-mesh remodel is likewise `-GscOnly` (both station models pack from the stock gdtDB).
- **Dev mode** (`acc_dev 1`) gives money + bottles + open map, so both stations are reachable + affordable
  immediately. Co-op check: second client withdraws a racked gun (lands on the remote player, no view-yank);
  a full-slot presser is **refused**, not robbed. Disconnect mid-transaction → no lobby CTD.

## The upper room geometry (BUILT 2026-07-07)

Generator: [`tools/gen_upper_room.js`](../tools/gen_upper_room.js) — a bake-safe vertical generator cloned
from [`gen_abyss_layer.js`](../tools/gen_abyss_layer.js) (same proven `box()` filler-winding + hex GUID +
`PRIMARY_OMNI` lights). Idempotent (strips its own `-AC50-` brushes) and `--revert`-able. Re-run + FULL bake
to move/retune; all placement lives in the `LOFT_`/`STAIR_` constants at the top.

- **Access = a BUYABLE DOOR (10000) in the EAST Plaza wall** (user 2026-07-07/08). The generator **cuts a
  doorway** (y[-64,64] z[0,128]) into east wall #5 (re-emitting it as 2 jambs + a lintel) + a door slab
  (`acc_door_armory`) + a `zombie_door` trigger (`enter_armory`, 10000). Wired in the entry script:
  `zone_door_trigger_origin` (buy origin `(223,0,50)`) + `zone_door_dest_name` ("the Armory"). The flag-set is
  `flag::exists`-guarded, so **no zone edge / flag registration** is needed — the door just hides the slab.
- **Door design** = the map's canonical door skin: the slab is **`t7_metal_diamond_plate_worn_wet`** (worn
  diamond-plate METAL, `DOOR_MAT`), NOT the wall material — every buyable door on this map uses this so the
  doorway reads as an industrial shutter vs the concrete wall (there is no door model/prefab/FX; the *material*
  IS the "this is a door" cue). v1's slab used the wall material and looked like blank concrete (fixed 2026-07-08).
- **Staircase**: 24 treads, **12-rise / 20-run** (~31°; user 2026-07-07 "way too steep" fix from the old
  16/16 = 45° ladder — and ≤16u risers link the navmesh, docs/02), climbing **EAST (+X)** from
  **x[234,714] y[-64,64]** — starts right at the wall/door, runs into the dead-space, tops at the loft's WEST
  wall doorway. Full-height side rails. Longer run → the loft sits further east.
- **Loft**: enclosed room **x[714,1074] y[-200,200]**, floor z=288, walls z[288,544], ceiling z[544,560] —
  floats over the east dead-space (arena floor reaches x=1094.5). **4 always-on `PRIMARY_OMNI` lights**.
- **Materials (user: "model the walls with the Plaza wall design")**: re-skinned to the Plaza's own re-skin —
  walls/ceiling/slab = **`t7_concrete_wall_weathered_01_wet`**, floor/stairs = **`t7_asphalt_damaged_dark_wet`**.
  Both are STOCK (ship free, **no `.zone` line** — docs/20). (v1/v2 used greybox `script_wall` = the checker.)
- **Nothing intercepts the playable Plaza**: the *only* thing on playable floor is the door + its buy trigger;
  the stairs + loft are entirely in the sealed **east** dead-space (x>233), which is inside the tall
  `start_zone` volume (z[-166,1041]) → in-zone, no OOB, zombies path the stairs. No new zone/risers.
- **⚠ HISTORY**: v1 put it in dead-space with **no door** → unreachable ("I don't see the new area"). v2 moved
  it into the playable Plaza (N-facing stairs) but the loft hung over the Plaza interior / the Bus-Station path
  ("it intercepts things"). v3 (this) = door-into-dead-space, east-facing, Plaza-skinned. **Placement rule:
  only the door touches playable floor (x[-470,213]); everything else lives in dead-space.**
- **Bake**: `_bake_test.ps1` → **BAKED** (LED ~110 s, no `brush.cpp:1860`, atlas within budget).

**To move/retune**: edit the constants at the top of `gen_upper_room.js` + the two `spawn_stations()` origins +
the `zone_door_trigger_origin` case, re-run `node tools/gen_upper_room.js`, then a FULL build **with** the LED
bake. `--revert` restores the solid east wall.
