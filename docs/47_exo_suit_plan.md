# docs/47 — Exo Suit Upgrade Station + Layered Trench (deep plan, NOT built)

**Status:** **BUILT 2026-06-21** (`-GscOnly`) — `_acc_exo.gsc` (tier state + station), the depth-aware slow
in `recompute_move_speed`, the bus_trench watcher layer tracking, and the gun Overclock T5 extension are all
live. **Layer 1 works today; layers 2–5 light up as the geometry agent builds the floors** (they extend
`underground_layer` in `_acc_bus_trench`, deepest-z-first — no system change needed). Not yet playtested.
**HUD added 2026-06-22** (§11): an always-on "EXO SUIT N/5" readout + a detailed proximity report card at the
station (the player previously got only a transient buy message and had no idea what the upgrade did).

**Owner split:** the **SYSTEM** (this plan — exo tiers, the per-layer speed slow, the exo station, the
overclock T5 extension) is mine. The **5 trench layers' GEOMETRY** (walkable floors/passages at the depths
in §6) belongs to the **parallel "Black Market" geometry agent** ([docs/45](45_underground_blackmarket_design.md));
the **interface is the layer z-bands in §6**. Build the system against those bands; it activates layer-by-layer
as the geometry lands.

## 1. The idea
The trench now **descends in 5 layers**, each slower than the last. The **Exo Suit** is the key to depth:
**each tier cancels the speed penalty for one more layer down.** Without the matching tier a deeper layer is
a crawl; with it you walk normally. Loop: **earn shards → buy exo tiers → reach deeper layers (better loot /
the Reactor) → earn more → go deeper.** The exo is *essential for depth* AND a body-augment (each tier also
adds damage resistance + knife/melee damage — see §10), the 3-effect counterpart to the gun Overclock.

The Exo Suit is the **body** counterpart to the per-gun **Weapon Overclock** (gun upgrades). It is **per-player**.

## 2. The speed model (the core mechanic)
Penalty depends only on **how many layers you are below your exo coverage**. Exo tier `T` lets you walk normal
in layers `1..T`. Below that:

```
reduction(layer L, exo tier T) =
    0                      if L <= T          (covered: normal speed)
    0.20 + 0.10*(L-T-1)    if L >  T          (= 0.10*(L-T+1); first uncovered layer = -20%, then -10%/layer)
```

Applied as a multiplier into `recompute_move_speed`: `n_scale *= ( 1 - reduction )`.

| Exo tier ↓ / layer → | L1 (Bus Stn) | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| **0** | −20% | −30% | −40% | −50% | −60% |
| **1** | 0 | −20% | −30% | −40% | −50% |
| **2** | 0 | 0 | −20% | −30% | −40% |
| **3** | 0 | 0 | 0 | −20% | −30% |
| **4** | 0 | 0 | 0 | 0 | −20% |
| **5** | 0 | 0 | 0 | 0 | 0 |

This **replaces** today's flat −20% trench slow (the single `acc_trench_slow` term). Worst case (tier 0, L5) =
−60%. Live dvars: `acc_exo_slow_first` (0.20), `acc_exo_slow_step` (0.10).

## 3. Exo tiers + costs
- `player.acc_exo_tier`, 0..5, **per-player**, persists for the run.
- **Costs: 5 / 10 / 15 / 20 / 25** (T1..T5). Total to max = **75**. dvars `acc_exo_cost_t1..t5`.
- Each tier is a one-time purchase at the Exo Station; the priciest single tier (25) fits the cap (§5).
- **At T5** you walk normally in all 5 layers.

## 4. Gun Overclock → 5 tiers (parity)
The Weapon Overclock extends from 4 to **5 tiers** (it is NOT layer-gated; this is parity with the exo /
the 5-layer theme). The 3 effects keep their per-tier increments, now reaching T5:
- Flat damage: +10%/tier → **+50%** at T5
- Glitch Piercing: +25%/tier → **+125%** at T5
- Ammo refund: +10%/tier → **50%** at T5
- Cost ladder: **2 / 4 / 8 / 16 / 24** (T5 = 24 to stay under the cap; total to max one gun = 54).
- Code: `ACC_TIER_MAX` 4→5 in `_acc_overclocks.gsc`; add `ACC_TIER_COST_T5` (24). The 3 effects already
  scale off `oc_tier` in `_acc_damage`, so they extend to T5 with no per-effect change.

## 5. Economy / cap
- **Shard cap = 50** (raised from 30, done 2026-06-21). Covers the priciest single tier (exo T5 = 25) with
  headroom; maxing everything (exo 75 + a gun 54 + perk slots 40 + …) is a deliberate long-haul grind, the
  cap just blocks hoarding so you spend as you earn.

## 6. 🔗 Geometry interface — the 5 layer z-bands (parallel agent builds these)
I detect the player's layer from `z`. PROPOSED bands (geometry agent confirms/adjusts the real floor depths;
current underground floor is z≈−240 = layer 1):

| Layer | z range (player feet) | notes |
|---|---|---|
| surface | z > −160 | not in the trench |
| **1** | −360 < z ≤ −160 | Bus Station trench / current underground (floor ≈ −240) |
| **2** | −560 < z ≤ −360 | new |
| **3** | −760 < z ≤ −560 | new |
| **4** | −960 < z ≤ −760 | new |
| **5** | z ≤ −960 | deepest; the Reactor / best loot live here |

- All layers stay inside the OOB-kill veto (`player_in_underground`, `z < −36`, no lower bound) **provided**
  they stay within the XY box `x[-900,900] y[-400,2900]` — geometry agent must keep the deeper floors inside it.
- `current_trench_layer(player)` (new, in `_acc_bus_trench` or `_acc_exo`) maps z → 0..5 via these thresholds
  (live dvars `acc_layer_z1..z5` so they can be retuned to match the built floors).

## 7. System implementation
**New module `_acc_exo.gsc`:**
- `init()` — thread the deferred station spawn (~1.5 s, like the altar).
- `on_player_connect(p)` — `p.acc_exo_tier = 0`.
- `on_player_spawned(p)` — `acc_utility::recompute_move_speed(p)` (**critical:** `SetMoveSpeedScale` resets to
  1 on every spawn, so the exo/trench slow must be re-applied after death/revive).
- `spawn_station_at(origin, yaw)` — model + `trigger_radius_use` **+ `TriggerIgnoreTeam()`** (the script-trigger
  lesson, memory `script-trigger-needs-ignoreteam`) + `station_loop`.
- `station_loop()` — on use: validate → if `tier < 5`, `try_spend(acc_exo_cost_t{tier+1})` → `tier++` →
  `recompute_move_speed` → `hud_msg` ("EXO SUIT — Tier N/5, normal speed to layer N"); at 5, "fully augmented".
- `current_trench_layer(player)` + the slow lives where `recompute_move_speed` can read it.

**`_acc_utility.gsc::recompute_move_speed`:** replace the single `acc_trench_slow` term with the depth-aware
slow: `L = current_trench_layer(player); T = (player.acc_exo_tier or 0); if (L > T) n_scale *= 1 - reduction(L,T)`.
(The Boots boss item NO LONGER negates the trench slow — done 2026-06-21; the Exo Suit is the only thing
that cancels it. Boots still give their +8% overall.)

**`_acc_bus_trench.gsc`:** the per-player trench watcher already polls position; have it detect **layer changes**
and call `recompute_move_speed` on a change (so the slow updates as you descend/ascend). The existing
`player_in_underground` stays as the broad veto/effect footprint; layer is the finer depth read.

**Station placement:** at the **top of the descent** so you upgrade *before* going deep. **Built 2026-06-24**
in the **Foundry under-room** (`(230, 1450, -240)`, layer 1 — originally the freed Overclock spot at
`(-120,1450,-240)`, but the room was **relocated EAST to center x=350 on 2026-06-25** so its buyable door
clears the centered abyss descent well — see `gen_relocate_exo_room.js`). **NOTE the Foundry "room" is NOT a
sealed box:** it is a shallow 384×344 niche whose front wall IS the trench's south retaining wall — room floor
and pit floor are both `z=-240`, flush — so opening the buyable door (`enter_under_plaza`, doorway now `x[462,542]`)
makes the niche continuous with the full-width pit; in-game it reads as part of the trench, not a closed room.
This realises the loop: earn shards in the pit → buy Exo tiers up top → descend → spend at the deeper sinks
(Overclock L2, Glitch Altar L3 — see docs/48 + `_acc_glitch_altar.gsc`).

## 8. Build order (when greenlit)
1. `_acc_overclocks`: `ACC_TIER_MAX` 4→5 + `ACC_TIER_COST_T5` 24. (Verify the 3 effects read T5 fine.) Build, lint.
2. New `_acc_exo.gsc` (tier state, station, `current_trench_layer`, the reduction helper). Wire into `_acc_main`
   (#using + init + connect/spawned) and the `.zone` (scriptparsetree).
3. `recompute_move_speed`: swap the flat trench slow for the depth-aware slow (reads exo tier + layer).
4. `_acc_bus_trench`: layer-change → recompute hook.
5. Place the Exo Station at the trench-entrance anchor (coordinate z-bands + anchor with docs/45).
6. Build `-GscOnly`, lint, adversarial review (move-speed reapply, layer math, station usability), then docs/46
   + this doc + CHANGELOG + memory.

## 9. Dvars (all live)
`acc_exo_on` (1) · `acc_exo_cost_t1..t5` (5/10/15/20/25) · `acc_exo_slow_first` (0.20) · `acc_exo_slow_step`
(0.10) · **`acc_exo_resist_per_tier` (0.05 = −5%/tier dmg taken)** · **`acc_exo_melee_per_tier` (0.30 =
+30%/tier knife/melee)** · `acc_layer_z1..z5` (−160/−360/−560/−760/−960) · gun `acc_oc_*` unchanged + new T5 cost.

## 10. Risks / open items
- **Move-speed reapply on spawn** — the #1 trap; the bonus/slow vanishes after death unless recomputed on spawn.
- **Layer detection on stairs/ramps** — z changes continuously while descending; debounce so the slow doesn't
  flicker mid-stair (recompute on a *stable* layer change, or accept per-poll updates).
- **Geometry dependency** — layers 2–5 don't exist until the geometry agent builds them; until then only layer 1
  is reachable and the system is inert below it (harmless). Confirm z-bands match the built floors.
- **Boots item** — RESOLVED (user 2026-06-21): Boots **no longer** negate the trench slow (still give +8%
  overall); only the Exo Suit cancels it. Done in `recompute_move_speed`.
- **Exo augments** = **THREE per-tier effects** (re-added 2026-06-22, the body counterpart to the gun
  Overclock's 3): (1) depth-speed gate (§2); (2) **damage resistance** −`acc_exo_resist_per_tier` (0.05 →
  −25% at T5) on ALL incoming damage, in `_acc_elites::on_player_damaged`; (3) **knife/melee damage**
  +`acc_exo_melee_per_tier` (0.30 → +150% at T5) on the player's melee hits, an additive layer in
  `_acc_damage::on_ai_damage` (melee-only; guns are untouched). Resistance + melee were briefly dropped
  2026-06-21, then restored per the original design.
- **SetMoveSpeedScale CTD breadcrumb** exists in `recompute_move_speed` (boots+slide diag) — a multiplicative
  factor is safe; just never feed it an undefined.

## 11. HUD (added 2026-06-22) — mirrors the Weapon Overclock HUD

The buy gave only a transient `hud_msg`, so players "didn't even know what it does." Added two pieces, both
with **NO new clientfield** (the clientuimodel pool is full — the always-on overclock "vN" took the last dead
field, memory `hud-modernization-plan`):

1. **Always-on tier readout** — a **server-side font string** (`hud::createFontString`, the same mechanism as
   the `DATA SHARDS` count in `_acc_data_shards`), `sync_exo_hud(player)` in `_acc_exo.gsc`. Shows
   `EXO SUIT N/5` one line under the shard count (TOP_LEFT 16,72); dim at tier 0 (discoverable), bright once
   augmented. Refreshed on spawn + on every upgrade. Server-HUD (not LUI) because the exo state is server-side
   and this dodges the full clientfield pool entirely.
2. **Detailed report card at the station** — reuses the live LUI proximity-card system (`_acc_perk_info` →
   `accPerkCard` → `acc_hud.lua`), exactly like the Overclock kiosk card. The exo tier is encoded into the
   **unused `accPerkCard` code range 108..127** (`108 + exo_tier`, above the +64 Armory-discount range), so
   **no new clientfield**. Walking up shows: current tier, what it does (full speed down to layer N + the
   slow rule below it), and the **next tier's Data-Shard cost + benefit** — so you know what you're buying
   before you buy. Costs mirrored in `acc_hud.lua AccExoCosts` (= `_acc_exo::exo_cost`); the Armory discount
   bit is correctly excluded (exo costs shards, not points). The station origin is recorded in
   `level.acc_exo_station_origins` for the proximity competition.
