# docs/45 — Underground: The Black Market (level design / geometry)

**Owner split (user, 2026-06-19):** the **GEOMETRY** — rooms + passageway + lighting +
the anchor coordinates — is THIS deliverable. The **Data Shard SYSTEM** (economy, the
Reactor Surge event logic, overclock/cyberware wiring, cache combat-metering, payouts)
is a **parallel agent**. The **interface between us is the anchor table in §3**: my
geometry guarantees solid, lit, reachable floor at those exact coords; their system
spawns its content there. I do NOT touch the shard economy/overclock logic.

Source: 27-agent design pass (`underground-design` workflow, 2026-06-19). Winner =
**Black Market / Vault** (26.0) tied with **Reactor Event** (26.0); the synthesis fused
the Black Market's split-room shop frame with the Reactor Event's sealed-arena climax.

## Pitch
Power runs the city above; down here nothing is powered and nothing is safe. A slowed,
pitch-black, surge-spawning danger box off the trench hub where Data Shards finally buy
something — climaxing in the repeatable, tier-dialed **Reactor Surge** in the deepest
room. You don't farm the underground; you **raid** it.

## 1. Room map (everything doors off the trench hub at z=-240)

```
        [4] REACTOR CORE  (front = add_under_room north + widen; back = free-void)
              │  north door (off the pit)   Arm Plinth (0,2120,-240)
   ┌──────────┴──────────┐
   │   [HUB] THE PIT      │  exists — keeps every trench effect (drip/surge/-25%/HUD)
   │   caches ±360,1950   │
   └──────────┬──────────┘
              │  enter_under_plaza door (zombie_door, 1500, sideways slide "192 0 0") — EXISTS
        [1] THE FOUNDRY  (south under-room — EXISTS)
        ╱ open arch (free)        open arch (free) ╲
   [2] THE STALLS                              [3] THE CAGES
```

| Space | x | y | z | Build path | New geom? |
|---|---|---|---|---|---|
| **[HUB] Pit** | -665..703 | 1723..2173 | -240 | exists | no |
| **[1] Foundry** | -192..192 | 1379..1723 | -240..-96 | exists (`add_under_room south`) | no |
| **[2] Stalls** | -720..-260 | 1379..1700 | -240..-96 | carve west fill (≤ z=-96) | yes |
| **[3] Cages** | 260..720 | 1379..1700 | -240..-96 | carve east fill (≤ z=-96) | yes |
| **[4a] Core front** | -384..384 | 2173..2748 | -240..-96 | `add_under_room north`, then widen below z=-96 | yes |
| **[4b] Core back** | -384..384 | 2748..2820 | -240..-80 | free-void normal floored room | yes |
| **[5a/5b] Pit caches** | ±360 | 1950 | -240 | exists | no |

Why split the rooms N/S across the pit: every trip between the gamble (Foundry),
the loadout (Stalls/Cages), and the event (Core) is a pit crossing under the worst
drip — so the slow + danger system finally has a *reason*, and each room gets one
identity instead of four sinks crammed in a corner.

## 2. Build order (GEOMETRY only — incremental, bake-gated, user-tested each step)

The system/GSC step (the other agent) lands first/parallel; my geometry steps:

1. **[4a] Core front** — `node tools/add_under_room.js <map> <map> north` (proven mirror
   of the working south room). Bake-gate → full `build_map.ps1` → **user walk-tests**
   (no fall-through, no OOB kill, door slides, zombies path). ← *this step, now.*
2. **[4a] widen** — extend the north carve to x±384 below z=-96 (no new z=0-over-void). Bake-gate, build, walk-test.
3. **[4b] Core back** — free-void box past y=2748, ceiling steps to z=-80. Bake-gate, build, walk-test.
4. **[2] Stalls** — carve the south west-fill, open arch off the Foundry. Bake-gate, build, walk-test.
5. **[3] Cages** — carve the south east-fill, open arch off the Foundry. Bake-gate, build, walk-test.
6. **Lighting** — one baked light per room (dim/bright power-gated, `gen_room_roofs.js` recipe), LED-gated per room.

Each geometry step = one batch, full `build_map.ps1` **with LED** (never `-SkipLED`); a
bake crash (`brush.cpp:1860`) reverts only that step. Backups in `/tmp/acc_map_*.bak`.

## 3. System anchor coords — INTERFACE (solid, lit floor guaranteed here)

The parallel shard-system agent spawns content at these. Re-homing the *existing*
stranded spawns = edit the literals in `acc_glitch_altar::spawn_altars()`
(`_acc_glitch_altar.gsc:66-72`). **Coordinate before both editing that function.**

| System | Anchor coord | Room | Spawn fn |
|---|---|---|---|
| Glitch Altar | (0, 1480, -240) | Foundry center | `acc_glitch_altar::spawn_altar_at` |
| Pit Cache W | (-360, 1950, -240) | Pit | `acc_data_shards::spawn_cache_at(o,2)` |
| Pit Cache E | (360, 1950, -240) | Pit | `acc_data_shards::spawn_cache_at(o,3)` |
| Cyberware kiosk | (500, 1500, -240) yaw 270 | Cages | `acc_cyberware::spawn_kiosk_at(o,yaw)` |
| Overclock terminal | (-500, 1500, -240) yaw 90 | Stalls | `acc_overclocks::spawn_terminal_at(o,yaw)` |
| Guaranteed caches (new) | (640, 1450, -240) | Cages | reuse `spawn_cache_at` + cost gate |
| Rotating stalls (new) ×3 | (-640, 1450, -240) | Stalls | new `trigger_radius_use` |
| Reactor Plinth + risers (new) | (0, 2120, -240); risers on Core floor | Core | new `_acc_reactor.gsc` |

## 4. Lighting / atmosphere (buildable levers only)

- One **baked light per enclosed room** (Foundry, Stalls, Cages, Core) via the proven
  `gen_room_roofs.js` dim/bright two-light recipe (DIM `lightingstate1` pre-power,
  BRIGHT `lightingstate2` post-power); proven `box()` winding + hex GUID, **never**
  `add_vault_ceiling.js` winding. Core bakes deliberately darker. Bake-gate each.
- **Power-gated reveal:** wire to `set_lighting_state(0)→(1)` — pre-power near-black,
  post-power moody-visible. Makes "turn on power" a prerequisite for comfortable raiding.
- **Client FX only** via `acc_perk_lights::set_glow(host, color_index)` on invisible
  `tag_origin` hosts (teal Altar orb, cache crates, stall props, Plinth red→cyan,
  red Reactor-Door seam, Core strobe during a Surge). Verify each `.efx` on disk first.
  **No server `PlayFX`** (renders nothing here).
- Fog stays global cold blue-grey; **no default vision grade** (`ACC_VISION_ON 0`).

## 5. Build-rule compliance (the fall-through lessons, locked in)

- **Single-slab over void:** Stalls/Cages carve voids in the *existing* south slab's fill
  below z=-96 (no new z=0-over-void). Core front *widens* the proven north single-slab
  carve below z=-96. Core back is past the corp footprint → normal floored room, no
  overhead-slab constraint. Never hand-author a new z=0 slab over a hollow.
- **OOB-veto:** all inside `player_in_underground` (`x[-900,900] y[-400,2900] z<-36`).
  Core capped at **y=2820 < 2900, x±384 < ±900** → no `ACC_UNDER_*` edit, no second
  `player_out_of_playable_area_monitor_callback`.
- **Doors slide sideways** (`"192 0 0"`), never up. Stalls/Cages use free open arches.
- **Interactables** are `script_brushmodel` / `trigger_radius_use` (deletable/movable),
  never prefab bodies.
- **LED bake is the gate**; navmesh via full `cod2map64` (cwd=bin) so zombies path the
  new rooms. **Success oracle = fresh `.ff` + in-game walk-test**, not the linker exit code.
