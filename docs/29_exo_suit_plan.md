# 29 — Exo Suit Upgrade Station + Layered Trench

**Status: LIVE.** Built 2026-06-21, extended to 10 tiers 2026-06-24, remodelled + HUD-reworked
since. `_acc_exo.gsc` owns the tier state + buy station; the three augment EFFECTS live at their
natural chokepoints (depth-speed in `_acc_utility::recompute_move_speed`, resistance in
`_acc_elites::on_player_damaged`, melee in `_acc_damage::on_ai_damage`). The bus_trench watcher
tracks the player's depth layer, and the gun Overclock shares the same 10-tier ladder.

The Exo Suit is the **body** counterpart to the per-gun **Weapon Overclock**. It is **per-player**
and persists for the run.

## 1. The idea
The trench/abyss **descends in layers**, each slower than the last. The **Exo Suit** is the key to
depth: **each tier cancels the speed penalty for one more layer down.** Without the matching tier a
deeper layer is a crawl; with it you walk normally. Loop: **earn shards → buy exo tiers → reach +
fight in the deeper, richer layers (better loot / the Reactor) → earn more → go deeper.** The exo is
*essential for depth* AND a body-augment — each tier also adds damage resistance + knife/melee
damage (see §9) — the 3-effect counterpart to the gun Overclock.

## 2. The speed model (the core mechanic)
Penalty depends only on **how many layers you are below your exo coverage**. Exo tier `T` lets you
walk normal in layers `1..T`. Below that (`_acc_utility.gsc::recompute_move_speed`, ~L497):

```
reduction(layer L, exo tier T) =
    0                      if L <= T          (covered: normal speed)
    0.20 + 0.10*(L-T-1)    if L >  T          (first uncovered layer = -20%, then -10%/layer deeper)
```

Applied as a multiplier: `n_scale *= ( 1 - reduction )`. Gated by the live dvar `acc_trench_slow_on`
(default 1). The reduction is **clamped to 0.90** so speed never reaches 0. Live tuning dvars:
`acc_exo_slow_first` (0.20), `acc_exo_slow_step` (0.10).

| Exo tier ↓ / layer → | L1 | L2 | L3 | L4 | L5 |
|---|---|---|---|---|---|
| **0** | −20% | −30% | −40% | −50% | −60% |
| **1** | 0 | −20% | −30% | −40% | −50% |
| **2** | 0 | 0 | −20% | −30% | −40% |
| **3** | 0 | 0 | 0 | −20% | −30% |
| **4** | 0 | 0 | 0 | 0 | −20% |
| **5** | 0 | 0 | 0 | 0 | 0 |

Layer detection caps at **5 layers** (`ACC_LAYER_MAX = 5`, `_acc_bus_trench.gsc`), so **T5 already
covers every layer that exists** (worst uncovered case = tier 0 at L5 = −60%). Tiers **6–10** still
buy the resistance + melee augments (§9), and their depth-cancellation is **inert until the abyss
grows layers 6–10** (geometry, not GSC — noted in `_acc_exo.gsc` at `ACC_EXO_MAX`).

This depth-aware slow **is** the trench slow — it replaced the old flat −20% term. The Boots boss
item no longer cancels it (only the Exo Suit does — see §9).

## 3. Exo tiers + costs
- `player.acc_exo_tier`, **0..10** (`ACC_EXO_MAX = 10`, `_acc_exo.gsc`), **per-player**, persists for the run.
- **Costs: 4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** (T1..T10, linear +4/tier = 4×tier;
  `_acc_exo.gsc::exo_cost`, dvars `acc_exo_cost_t1..t10`). Total to max = **220**.
- Each tier is a one-time purchase at the Exo Station; the priciest single tier (40) fits the shard cap (§5).

## 4. Gun Overclock → 10 tiers (parity)
The Weapon Overclock shares the same 10-tier ladder (`ACC_TIER_MAX = 10` in `_acc_overclocks.gsc`;
NOT layer-gated). The 4 effects scale off `oc_tier` in `_acc_damage`, reaching T10 with no per-effect
change (`_acc_damage.gsc` ~L188):
- Flat damage: +12%/tier → **+120%** at T10 (`acc_oc_dmg_per_tier` 0.12)
- Glitch Piercing: +15%/tier → **+150%** at T10 vs glitch zombies (`acc_oc_glitch_per_tier` 0.15)
- Ammo refund: +5%/tier → **50%** refund chance at T10 on a headshot kill (`acc_oc_adaptive_per_tier` 0.05)
- Shield piercing: `acc_oc_pierce_per_tier` 0.04/tier → the Riot's front takes **55%** damage-through at
  T10 (25% at T0 · 40% at T5 · never a full bypass — see docs/28 overclock table)
- Cost ladder: **4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40** (`ACC_TIER_COST_T1..T10`, shared with
  the Exo Suit; total to max one gun = 220).

## 5. Economy / cap
- **Shard cap = 500** (`ACC_SHARDS_MAX`, `_acc_data_shards.gsc`). Covers the priciest single tier (40)
  with headroom; maxing everything (exo 220 + a gun 220 + perk slots + …) is a deliberate long-haul
  grind, the cap just blocks hoarding so you spend as you earn.

## 6. Layer detection — the depth z-bands
`_acc_bus_trench.gsc::underground_layer( origin )` maps a world `z` to `0..ACC_LAYER_MAX`:
`layer = int( (depth - 1) / ACC_LAYER_PITCH ) + 1`, where `depth = -z`. The constants are **hardcoded**
(there are no `acc_layer_z*` dvars):

| Constant | value | meaning |
|---|---|---|
| `ACC_UNDER_Z` | −36 | above this = surface (layer 0) |
| `ACC_LAYER_PITCH` | 240 | z-units per layer |
| `ACC_LAYER_MAX` | 5 | deepest detected layer |

So layer 1 ≈ `−240 < z ≤ −36`, layer 2 ≈ `−480 < z ≤ −240`, … layer 5 = `z ≤ −960` (clamped). The
`−1` epsilon makes a floor at exactly `−240*N` read as layer N, not N+1. Layers only count inside the
underground XY box `x[−900,900] y[−400,2900]`; the "second part" descent hub and The Exchange vault
sit in that box but are **excluded** (their own rules, no per-layer slow/amp). The whole underground
is the vertical **Abyss Descent** (docs/30), not a flat floor.

The bus_trench watcher writes the player's current layer to **`player.acc_trench_layer`** and calls
`recompute_move_speed` on any layer change (`trench_fall_watcher`, ~L361–371) — that field is what
`recompute_move_speed` reads (§2), so the slow updates live as you descend/ascend. `player.acc_trench_slow`
(a bool) is kept for the speed-flags diagnostic.

## 7. Implementation map
**`_acc_exo.gsc`** (tier state + station + cost only; the effects live elsewhere):
- `on_player_connect(p)` — `p.acc_exo_tier = 0`.
- `on_player_spawned(p)` — `recompute_move_speed(p)` (**critical:** `SetMoveSpeedScale` resets to 1 on
  every spawn, so the exo/trench slow must be re-applied after death/revive) + `sync_exo_hud(p)`.
- `spawn_station()` / `spawn_station_at(origin, yaw)` — model + `trigger_radius_use` **+
  `TriggerIgnoreTeam()`** (the script-trigger lesson, memory `script-trigger-needs-ignoreteam`) +
  `station_loop` **+ `station_hint_loop`**. Records `origin` in `level.acc_exo_station_origins` for the
  proximity card (§10).
- `station_loop()` — on use: alive-check → if `tier < ACC_EXO_MAX`, `acc_data_shards::try_spend( cost )`
  → `tier++` → `PlaySound( "acc_shard_pickup" )` → `recompute_move_speed` + `sync_exo_hud`. It
  **writes no hint** — see below.
- `station_hint_loop()` / `station_hint_text(p)` / `nearest_station_player(origin)` — the **nearest-player
  keeper** that owns the hint. Live feedback still rides the **trigger hint string** (no popups — user
  2026-07-03): `"EXO SUIT - Tier N/10 - faster, tougher, stronger melee - next costs X Data Shards …"`
  and the `"Tier 10/10 MAX - fully augmented"` line — but composed from the player **at the pod**, polled
  at 0.25s and change-guarded on `self.acc_last_exo_hint`.
  **Why (co-op fix 2026-07-15):** `acc_exo_tier` is per-player but `SetHintString` is one *entity-global*
  string, so writing it from the transaction latched the last buyer's private tier as the whole team's
  prompt — a Tier-10 player's press left `"Tier 10/10 MAX - fully augmented"` pinned for a teammate at
  Tier 0, hiding the map's core body sink and quoting them no price. The buy was always correct
  (`station_loop` reads `player`), so this was purely a display leak, and **invisible solo**. Same
  constraint `_acc_perk_info` documents for the perk wall ("the shown price can't be per-player on a
  shared trigger"); same keeper shape as `acc_pap_levels::paradise_pap_hint_loop`. String set stays
  bounded (10 tier lines + MAX + the idle discovery line = 12), well under the 250-triggerstring cap, and
  no hint carries `hold`+`for` without a cost keyword (memory `lui-cursorhint-router-loose-weapon-matcher`).

**Station model + placement.** A **cryogen stasis pod** (`p7_cry_cryogen_pod_exterior`, T7-dump carve,
docs/09 remodel 2026-07-09) — a body-augmentation chamber. The pod origin is mid-body, so it spawns
`+63 z` or it sinks into the floor. **MOVED to the PLAZA start room (user 2026-07-13)** — it previously
lived in the Foundry under-room in the bus-station trench at `(−120, 1550, −240)`. It now sits on the open
spawn-band floor of the Plaza (interior `x[−470,213] y[−240,720]`, floor `z=0`) at `(−200, −100, 0)`, yaw 0
— front-left of a spawning player (spawns are `x[−120,40] y[−90,−130]`), immediately discoverable, and clear
of the start box `(100,−150)`, the leaderboard terminal `(−340,−210)`, and all four plaza caches. Its `.map`
collision clip is a shallow `z=0` worldspawn clip (`tools/add_prop_clips.js` `exo_station`; navmesh auto-cut,
no LED risk). Buying tiers up top before descending still realises the loop: earn shards → buy Exo tiers →
descend → spend at the deeper sinks (Overclock, Glitch Altar — docs/30, `_acc_glitch_altar.gsc`).

**`_acc_utility.gsc::recompute_move_speed`** — reads `player.acc_trench_layer` + `player.acc_exo_tier`
and applies the depth-aware slow (§2). Boots do NOT cancel it (they still give +8% overall via
`acc_boots_mult`).

## 8. Dvars (all live)
`acc_exo_on` (1) · `acc_exo_cost_t1..t10` (4/8/12/16/20/24/28/32/36/40) · `acc_exo_slow_first` (0.20) ·
`acc_exo_slow_step` (0.10) · `acc_trench_slow_on` (1) · **`acc_exo_resist_per_tier`** (0.06 = −6%/tier
damage taken) · **`acc_exo_melee_per_tier`** (0.15 = +15%/tier knife/melee; user 2026-07-18 halved from 0.30) · `acc_boots_mult` (1.08).
Layer detection is hardcoded (ACC_UNDER_Z / ACC_LAYER_PITCH / ACC_LAYER_MAX), **not** dvar-driven.

## 9. The three augments + risks
Each tier stacks **THREE per-tier effects** (the body counterpart to the gun Overclock's 3):
1. **Depth-speed gate** (§2) — normal speed down to layer `T`.
2. **Damage resistance** — `_acc_elites.gsc::on_player_damaged` (~L578): all incoming damage ×
   `(1 - exo_tier * acc_exo_resist_per_tier)`, **clamped at −80%**, floored so a hit always deals ≥1
   (−30% at T5, −60% at T10 with the 0.06 default).
3. **Knife/melee damage** — `_acc_damage.gsc::on_ai_damage` (~L816, melee-only; guns untouched): adds
   `exo_tier * acc_exo_melee_per_tier` to the player's melee hits (+75% at T5, +150% at T10 with the
   0.15 default — user 2026-07-18 halved it from 0.30).

Standing risks / gotchas:
- **Move-speed reapply on spawn** — the #1 trap; the slow vanishes after death unless `recompute_move_speed`
  runs on spawn (handled in `on_player_spawned`).
- **Layer detection on stairs/ramps** — z changes continuously while descending; the watcher recomputes
  only on a *changed* integer layer, so the slow doesn't flicker mid-stair.
- **Boots item** — Boots no longer negate the trench slow (only the Exo Suit does); they still give +8%
  overall (`recompute_move_speed`, `acc_boots_mult`).
- **`SetMoveSpeedScale` CTD breadcrumb** exists in `recompute_move_speed` (boots+slide diag) — a
  multiplicative factor is safe; just never feed it an undefined.

## 10. HUD
Both pieces use **NO new clientfield** (the clientuimodel pool is full):

1. **Tier readout in the squad roster.** The old always-on top-left "EXO SUIT N/5" hudelem was
   **reclaimed** (user 2026-06-27) — `sync_exo_hud` is now a no-op stub (freeing a slot in the shared
   per-client server-hudelem pool, memory `server-hudelem-pool-exhaustion-coop`). The tier is instead
   shown in the roster stats line (`_acc_health_bars.gsc`: `SetText( "EXO " + tier + "  MB " + mb )`),
   which reads `player.acc_exo_tier` directly, so nothing visible is lost.
2. **Detailed report card at the station.** Reuses the live LUI proximity-card system (`_acc_perk_info`
   → `accPerkCard` → `acc_hud.lua`), exactly like the Overclock kiosk card. The exo tier is encoded into
   the unused `accPerkCard` code range **108..127** (`108 + exo_tier`, above the +64 Armory-discount
   range), so **no new clientfield** (`_acc_perk_info.gsc` ~L366). Walking up shows the current tier,
   what it does, and the next tier's Data-Shard cost + benefit. Costs mirrored in `acc_hud.lua`
   (`AccExoCosts`); the station origin is recorded in `level.acc_exo_station_origins` for the proximity
   competition.
