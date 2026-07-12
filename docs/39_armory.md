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
  of `{ wpn, model }` structs) and `weapon_take`s it. Rejects: nothing held / melee / mines / non-primary
  (pistol, equipment) / **capped wonder weapons** (a racked wonder could let a 2nd player slip past the
  per-match claim cap — `acc_map_randomizer::wonder_cap_key`). Refused when the rack is full
  (`acc_armory_rack_max` = **1** — **one gun racked at a time**, user 2026-07-10; was 8).
- **WITHDRAW pad**: gives the **oldest** racked weapon (FIFO, like the Exchange item locker) to the presser.
  **Mandatory free-slot gate** first (`weapon_give` at the weapon limit silently deletes the held gun);
  `b_switch_weapon = false` so there's no mid-fight view-yank; refused if the presser already carries it.
- **Free** (giving up the gun *is* the cost — untaxed, like the Exchange item locker).
- **Balance**: a gifted gun auto-tunes — `acc_weapon_balance_mult` is name-keyed / owner-agnostic
  (`_acc_damage.gsc`), so no per-give work.
- **Visible contents (2026-07-10)**: the racked gun's **world model displays on the cabinet top**
  — the magicbox idiom (`UseBuildKitWeaponModel`, same engine call as
  `zm_utility::spawn_buildkit_weapon_model`, spawn-guarded), so the model wears the **depositor's
  buildkit variant + PaP camo** when upgraded. Layout (`rack_slot_origin` / `spawn_rack_display`): a
  single racked gun lies **along** the cabinet's long X axis (yaw 0), resting lengthwise like a rifle
  on a rack, at `acc_armory_rack_hover` (default 6u) above the `+48` top face (worldModel origins vary
  per gun; a slight float beats a buried receiver). **Fixed 2026-07-11** ("gun sticks through the
  holder"): the old fixed yaw 90 laid the gun *across* the cabinet, which is only **18u deep** (bounds
  137.8×18.1×48.1, `xmodel_bin_inspect`-verified), so a ~50u rifle jutted ~15u out both narrow faces.
  The row **self-centers for the configured cap**: the shipped cap 1 puts the single gun dead-center;
  a raised `acc_armory_rack_max` fans up to 8 per row at 17u pitch across the 138u top (default yaw
  flips to 90 for that side-by-side row), wrapping +16z per row. The display angle
  (`acc_armory_rack_yaw`/`_pitch`/`_roll`) and hover are **live-tunable dvars**. A withdraw deletes slot 0's model and
  **MoveTo-glides** any survivors forward (0.3s). Rack entries are structs `{ wpn, model }` (single
  array = gun/display can never desync; duplicate weapon objects — two players racking the same gun
  class — stay distinct entries). Dual-wields show the right-hand model only. Ent-pool-full spawn
  failure = that slot just goes undisplayed, never a crash.

Two flanking pads share one kiosk (the Exchange multi-pad idiom, since BO3 use-triggers are single-button).

### UI matrix (2026-07-10 UI pass — every player-facing string, both stations)

**Pad hints are STATE-AWARE** (`update_rack_hints`, called at spawn + after every deposit/withdraw): the
hint tells you the rack state *before* you press — the old static hints invited presses that could only
refuse. 4–6 constant strings total → configstring-cache safe. **No gun names anywhere in the UI**:
`wpn.name` is the INTERNAL class name (`ar_accurate`, not "ICR-1") and `IString(wpn.displayname)`
localization can't be verified offline across the ~50 pack guns (any gap renders a raw `WEAPON_*` token) —
the cabinet-top **world model is the gun's identity**. Internal names go to `acc_utility::log` only.

| Station / state | Hint (on aim) | Press result (toast) |
|---|---|---|
| Deposit pad, rack empty | `RACK your held weapon for a teammate` | ✅ `weapon racked - a teammate can TAKE it at the other end` (model appears on cabinet) |
| Deposit pad, rack occupied | `Rack OCCUPIED - a teammate can TAKE the weapon at the other end` (no press prompt) | ❌ `the rack already holds a weapon - take it first` |
| Deposit refusals (any state) | — | ❌ `hold the weapon you want to rack` (nothing held) / `hold a primary weapon to rack it` (melee, mine, pistol, equipment) / `wonder weapons can't be racked` |
| Withdraw pad, rack empty | `Rack EMPTY - RACK a weapon at the other end to share it` (no press prompt) | ❌ `the rack is empty` |
| Withdraw pad, rack occupied | `TAKE the racked weapon` | ✅ `took the racked weapon - it's in your loadout (switch to it)` — the give deliberately does **not** auto-switch (no view-yank), so the toast must say where the gun went or the take looks like a no-op |
| Withdraw refusals | — | ❌ `no free weapon slot - buy Mule Kick or drop a gun` / `you already carry the racked weapon` |
| Bottle exchange (always) | `EXCHANGE a Mega Bottle for a random Implant` — names the **actual prize** before the spend (was "a random reward", only revealed post-purchase); quantity composed from `acc_armory_bottle_cost` at spawn | ✅ `ARMORY EXCHANGE: a random Implant - grab it, then enable it at a bench` · ❌ `need N Mega Bottle(s)` |

Sounds: every ✅ plays `zmb_cha_ching`, every ❌ plays `zmb_no_purchase`. A player already aiming at a pad
picks a hint change up on the engine's next hint refresh (worst case: re-aim).

**⚠ Cursor-hint ROUTER trap (fixed 2026-07-11 — the "UI buggy on trigger" report):** these hints are also
string-matched by the Aetherium cursor-hint router (`ui/uieditor/widgets/HUD/ZM_CursorHint/ZMCursorHintNew.lua`).
Its loose `isMysteryBoxWeapon` matcher (`hold`+`for`, no buy/cost/mystery keyword) hijacked the **deposit pad**
hint into the Mystery-Box *weapon-pickup card* for a "weapon" named literally *"a teammate"*, and the **bottle
exchange** hint into one named *"a random Implant"*. Guards now bail that matcher on `bottle`, `permanently`,
and (new) **`rack`** — every rack-pad hint contains "rack"/"racked", no box weapon does — so all Armory hints
fall through to the readable `DefaultHint` card. **Any new Armory hint string must keep one of those guard
words (or get its own guard) — re-check `ZMCursorHintNew.lua` on every `SetHintString` change** (memory:
`lui-cursorhint-router-loose-weapon-matcher`).

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
- **Dvars** in [docs/22](22_flags_reference.md): `acc_armory_rack_max` (**1** — one gun at a
  time, user 2026-07-10; was 8), `acc_armory_bottle_cost` (1), and the rack-display tuning knobs
  `acc_armory_rack_hover` (6), `acc_armory_rack_yaw`/`_pitch`/`_roll` (gun lie; yaw cap-aware).

## Build / test

- **Stations = pure GSC** (script-spawned `trigger_radius_use` pads + `#precache`d station models) →
  `.\tools\build_map.ps1 -GscOnly` (linker only, **zero LED-bake risk**). Built + linked clean 2026-07-07;
  the 2026-07-09 station-mesh remodel is likewise `-GscOnly` (both station models pack from the stock gdtDB).
- **Dev mode** (`acc_dev 1`) gives money + bottles + open map, so both stations are reachable + affordable
  immediately. Co-op check: second client withdraws a racked gun (lands on the remote player, no view-yank);
  a full-slot presser is **refused**, not robbed. Disconnect mid-transaction → no lobby CTD.

## The upper room geometry (BUILT 2026-07-07; RESIZED + ROOFED 2026-07-11)

Generator: [`tools/gen_upper_room.js`](../tools/gen_upper_room.js) — a bake-safe vertical generator cloned
from [`gen_abyss_layer.js`](../tools/gen_abyss_layer.js) (same proven `box()` filler-winding + hex GUID +
`PRIMARY_OMNI` lights). Idempotent (strips its own `-AC50-` brushes) and `--revert`-able. Re-run + FULL bake
to move/retune; all placement lives in the `LOFT_`/`STAIR_`/`ROOF_` constants at the top.

**2026-07-11 rebuild (user: "stairs less steep, room ~25% bigger, needs a roof"):**
- **Staircase**: 16 treads, **12-rise / 28-run (~23°)** — was 12/20 (~31°), originally 16/16 (45°). Climbs
  EAST x[234,682]. The stairwell is now **fully enclosed**: side walls up to z=368 + a **4-segment stepped
  solid roof** (segment bases 208/256/304/352 → common top 368; ≥160u headroom over every tread). The
  dead-space above is open night sky (gen_room_roofs deliberately leaves the Plaza + dead-space unroofed),
  so the old open-top rail stairwell showed raw sky — the "it needs a roof" report. Seg 1 starts 1u inside
  the plaza wall face (base 208 < wall top 256 → sealed mouth); seg 4 butts the loft west wall (top 448).
- **Loft**: **x[682,1074] y[-230,230]** = 392×460 = **+25.2% floor area** (was x[714,1074] y[-200,200] =
  360×400). Floor **z=192** (walls z[192,448], ceiling z[448,464]) — **lowered from 288** because the
  shallower run needs x-length and the east edge is HARD-capped at x=1074 (old arena east wall inner face
  1074.5; the zombie spawn gulley is beyond — never extend east). y-extent verified clear of the east
  connector corridor (y≥380) and inside the start_zone volume **x[-1165.5,1264.5] y[-1192,1104]
  z[-166,1041]** (no OOB-monitor exposure). Stations follow: `spawn_stations()` origins (878, ∓100, 192).
- Note: `acc_roof_light_plaza_13` (gen_room_roofs Plaza safe-haven grid, no-shadowmap omni at (930,80,200))
  now sits just above the lowered loft floor; it already shone through the old floor (noshadowmap), harmless.

- **Access = a BUYABLE DOOR (10000) in the EAST Plaza wall** (user 2026-07-07/08). The generator **cuts a
  doorway** (y[-64,64] z[0,128]) into east wall #5 (re-emitting it as 2 jambs + a lintel) + a door slab
  (`acc_door_armory`) + a `zombie_door` trigger (`enter_armory`, 10000). Wired in the entry script:
  `zone_door_trigger_origin` (buy origin `(223,0,50)`) + `zone_door_dest_name` ("the Armory"). The flag-set is
  `flag::exists`-guarded, so **no zone edge / flag registration** is needed — the door just hides the slab.
- **Door design** = the map's canonical door skin: the slab is **`t7_metal_diamond_plate_worn_wet`** (worn
  diamond-plate METAL, `DOOR_MAT`), NOT the wall material — every buyable door on this map uses this so the
  doorway reads as an industrial shutter vs the concrete wall (there is no door model/prefab/FX; the *material*
  IS the "this is a door" cue). v1's slab used the wall material and looked like blank concrete (fixed 2026-07-08).
- **Staircase**: 16 treads, **12-rise / 28-run** (~23°; user 2026-07-11 "less steep" — was 12/20 ≈31°,
  itself the fix from the 16/16 = 45° ladder; ≤16u risers link the navmesh, docs/02), climbing **EAST (+X)**
  from **x[234,682] y[-64,64]** — starts right at the wall/door, runs into the dead-space, tops at the loft's
  WEST wall doorway. **Enclosed**: side walls to z=368 + a stepped solid roof (see the 2026-07-11 rebuild
  section below).
- **Loft**: enclosed room **x[682,1074] y[-230,230]** (+25% area, 2026-07-11), floor z=192, walls z[192,448],
  ceiling z[448,464] — floats over the east dead-space (arena floor reaches x=1094.5). **4 always-on
  `PRIMARY_OMNI` lights**.
- **Materials (user: "model the walls with the Plaza wall design")**: re-skinned to the Plaza's own re-skin —
  walls/ceiling = **`t7_concrete_wall_weathered_01_wet`**, floor/stairs/loft-floor slab = **`t7_asphalt_damaged_dark_wet`** (the door slab is the canonical metal `DOOR_MAT`, above — no slab is concrete).
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
