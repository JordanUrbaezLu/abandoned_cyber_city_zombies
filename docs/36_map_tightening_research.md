# docs/36 — Map Tightening Overhaul: Research Report

> Status: research reconciled + **Stage 0 tooling BUILT** (2026-06-15). §1-§5 are the research; §6 is the staged plan (Stage 0 done, Stages 1-6 pending). Where a verification corrected an inventory claim, the **corrected value is used** and flagged inline.
> Companion docs: `docs/29_overhaul_checklist.md` §6 (the parent task, "Halve room sizes + add obstacles", HIGH RISK, staged last), `docs/03_layout.md` (design rules), `docs/11_enemies.md` (difficulty philosophy).

---

## 0. Decisions & status (2026-06-15)

**User decisions** (locked in after reviewing the research):
- **Shrink aggressiveness:** **aggressive ~40-50%** (the literal "halve" from docs/29 §6) — NOT the report's moderate 20-30% default. The §7 per-zone targets below are therefore a floor, not the goal; expect deeper cuts. ⚠️ This is the report's flagged "worst legitimate stack" (aggressive shrink + uncapped speed curve + decon) — revisit the speed-cap question (§5, §8 Q3) at the first build+playtest gate.
- **Scope:** **all 7 zones** (light on Roof/Corp trains where possible, but nothing is exempt).
- **Sequencing:** **Stage 0 tooling first** (done), geometry after.
- **Difficulty re-tune:** **geometry only first** — leave the speed curve / radii / modifiers alone for now; playtest tightened rooms, then decide on a cap.

**Stage 0 — DONE (tooling, no geometry change):**
- `source_data/rooms.json` — canonical source-of-truth for the duplicated geometry (7 outer footprints, wall dims, 8 corridors, wall-gaps, the vault/roof gen_rooms shells, PaP origin).
- `tools/validate_rooms.js` — asserts the 4 footprint copies + 2 PaP-origin literals agree with the SoT (generic axis-aligned brush-AABB parser for the baked `.map`). Wired into `tools/preflight_windows.ps1`. Currently **26 ok / 0 error**.
- `tools/gen_rooms.js` — added the missing re-run guard (it writes the `.map` in place and had none → double-injected).
- `scripts/.../_acc_perk_info.gsc` — PaP origin now read **live** from `GetEntArray("pack_a_punch","script_noteworthy")[0].origin` (literal kept as fallback) → the one silent-break literal is fixed.

**Verified correction to this report (open Q7 resolved): vault/roof have TWO overlapping shells, not a nested inner chamber.** `gen_zone_greybox` built the outer rooms (vault floor `X[1119,2319]`, 256u walls) AND `gen_rooms.js` *also* injected a second closed shell (vault `X[984,2416]`, 16u walls, 128u ceiling — `// ACC room shell` brushes at `map:1147+`). The gen_rooms shell is **larger** in X (984 < 1119) and uses **different** door-gap Y-bands (`y2474-2536 / y3120-3186` vs greybox `y2300-2556 / y3100-3356`) — so they genuinely conflict and overlap. The validator flags this as 2 warnings. **Canonical = the greybox outer room** (it matches the grid, door slabs, and corridors); the gen_rooms shell must be **removed/reconciled** when vault/roof are tightened (Stage 2). Treat the §2 "inner sub-chamber" / "nested" language below as superseded by this.

---

## 1. Executive summary

Abandoned Cyber City is a **7-zone grid of large, mostly empty greybox boxes** laid out in 4 rows (south: Market | Start | Alley; mid: Corp; north: Roof / Vault; apex: Lab), connected by 8 buyable sliding doors and 256u-wide corridors. Rooms run **1160 x 1360u (Market/Alley)**, **1560 x 1560u (Corp)**, **1160 x 1160u (Vault/Roof)**, **1560 x 1160u (Lab)**, and **~2110 x 1962u (Start)** of *interior* floor — verified against the baked `.map` brush planes. The difficulty problem this overhaul solves: the rooms are big, flat and under-furnished, so encounters read as "kite around an empty floor," undercutting the map's stated mission ("small and dense beats big and empty… target Der Eisendrache, not Tranzit" — `docs/03_layout.md:12`, `docs/00_overview.md:27`). The fix is to **shrink room interiors toward Der Eisendrache density and add cover/obstacles that break sightlines and force tighter, higher-skill trains** — without narrowing the already-minimum 256u corridors, without removing the ≥2-exits-per-zone guarantee, and without collapsing the open training loops the (uncapped) zombie speed curve was tuned against. The work is genuinely **HIGH RISK** because room footprints are duplicated across four un-cross-checked artifacts with no single source of truth, and the geometry generators are one-shot/consumed — so the first deliverable is tooling (a source-of-truth + validator), not geometry.

---

## 2. Current layout — as-built (VERIFIED coordinates)

All AABBs below are **interior** (inset 20u from the 20u-thick, 256u-tall perimeter walls), confirmed by the geometry verification's independent brush-plane re-parse. `+X` = east, `+Y` = north, `+Z` = up; floor walkable at z=0, walls rise to z=256.

| Zone (script) | Interior W×D (X×Y) | Z height | Exits / doors (cost) | Training spots today | Key entities | How tight is it now |
|---|---|---|---|---|---|---|
| **Plaza** (`start_zone`) | ~2110 × 1962 `X[-1036,1074.5] Y[-1053.5,908]` | 256u (NOT 128u) | 2: `enter_market` W (750), `enter_alley` E (750). **One gap per side, Y400-656** — see correction below | 1 small debris loop (R~8), brushes near `X[-81,119] Y[-172,28]` | info_player_start `(-227.5,-476.5,40)`; 8 initial_spawn_points (Y-284.5/-348.5); MagicBox: none; Brutus/dog/charred risers at z207-208 NW corner `(~-131,~586-670)` | Largest, irregular, **never sealed**. Lots of dead floor. Most shrink headroom of any zone. |
| **Market** (`market_zone`) | 1160 × 1360 `X[-2461,-1301] Y[220,1580]` | 256u | 2: corridor to Start (E gap Y400-656) + corridor to Corp via `enter_corp_w` (E gap Y1200-1456, cost 1000) | Stall-row loop (3 crate blocks at Y[850,950], X bands `[-2181,-2021]/[-1961,-1801]/[-1741,-1581]`) | MagicBox `(-1881,1540)` (~40u from N wall); 4 corner risers + center dog | Leaf, decon-sealable. **The pilot room** (isolated, 2 corridors). Box sits very close to N wall — shrink risk. |
| **Alley** (`alley_zone`) | 1160 × 1360 `X[1339.5,2499.5] Y[220,1580]` | 256u | 2: corridor to Start (W gap Y400-656) + `enter_corp_e` to Corp (W gap Y1200-1456, cost 1000) | **None designed** (intentionally no good train) | No box, no perk, no chalk in source; 4 corner risers + center dog | Leaf, decon-sealable. Sparsest zone; mirror of Market. Good candidate for a *true chokepoint*. |
| **Bus Station** (`corp_zone`) | 1560 × 1560 `X[-761,799] Y[1168,2728]` | 256u | **4**: `enter_corp_w` SW (1000), `enter_corp_e` SE (1000), `enter_roof` NW (1250), `enter_vault` NE (1250) | **2**: fountain loop (center block `X[-131,169] Y[1798,2098]`) + lobby S-curve (low walls `X[-481,-61] Y1448-1468` and `X[99,519] Y1598-1618`) | MagicBox `(640,2690)`; power switch "corp" `(790,1900)` (**only 9u from E wall**); hack terminal; 2 shiva chalk decals | **Cut-vertex — NEVER sealed.** Sealing it disconnects Plaza↔Lab. All 4 corridor mouths and both trains are non-negotiable. |
| **Vault** (`vault_zone`) | 1160 × 1160 `X[1139,2299] Y[2220,3380]` | 256u outer | 2: `enter_vault` from Corp (W gap Y2300-2556, 1250), `enter_lab_e` to Lab (W gap Y3100-3356, 1500) | Vault Overload defend point only (`acc_overload_point` `(1712,2900)`, hold radius 96u) | Inner 16u-walled sub-chamber `X[984,2416] Y[2474,3186]`, walls z0-128, **real 128u ceiling**; power switch "vault" `(2292,2800)`; overload terminal; frag chalk; PaP blocker `acc_pap_block_server X[1040,1056] Y[3120,3336]` z0-256 in lab_e corridor | Decon-sealable. Nested inner chamber — shrinking outer box can orphan it. Single sanctioned dead-end (Overload). |
| **Helipad** (`roof_zone`) | 1160 × 1160 `X[-2299,-1139] Y[2220,3380]` | 256u outer | 2: `enter_roof` from Corp (E gap Y2300-2556, 1250), `enter_lab_w` to Lab (E gap Y3100-3356, 1500) | **Best late-game train** (large open + central obstacle block `X[-1847,-1591] Y[2672,2928]`) | MagicBox `(-1419,3340)`; inner helipad sub-chamber `X[-2416,-984] Y[2474,3186]` (mirror of vault); shiva chalk; PaP blocker `acc_pap_block_roof X[-1056,-1040] Y[3120,3336]` z0-256 in lab_w corridor | Decon-sealable. **Documented "best late-game training spot" — the speed curve assumes this stays open.** Tighten with extreme care. |
| **Lab** (`lab_zone`) | 1560 × 1160 `X[-761,799] Y[3068,4228]` | 256u | 2: `enter_lab_e` from Vault SE (1500), `enter_lab_w` from Roof SW (1500). **Both approaches must stay physically intact** (one welded shut per run) | **None designed** (transaction/boss zone) | Cyberware kiosk W `(-740..-676,3520..3584)`; Overclock terminal E `(676..740,...)`; boss spawn `(19,3648)` = also lab dog spawn; bowie chalk; **perk staging row at Y=4195** (inside lab, ~33u from N wall — *corrected*, not "north of lab"); randomizer expects 4 `acc_lab_perk_a..d` (TODO(acc-geom), not yet placed) | **Never sealed** (holds PaP + all 9 perks + Overclocks). Boss arena double-booked with dog spawn. Reserve floor for the 4 future perk machines. |

### Verification corrections applied to this table
- **Start_zone wall openings (CORRECTED):** the inventory's start-zone notes claimed the west wall has **two** openings (corp_w + market). The independent re-parse + the authoritative `zm_zonemgr::add_adjacent_zone` graph (`zm_abandoned_cyber_city.gsc:427-434`) prove **each side wall of Start has exactly ONE gap (Y400-656)**: west = Market corridor, east = Alley corridor. `corp_w` is the **Market→Corp** corridor (`bw76 X[-1281,-781] Y[1200,1456]`) and does **not** breach Start's wall. Connectivity: `start↔market`, `start↔alley`, `market↔corp` (enter_corp_w), `alley↔corp` (enter_corp_e), `corp↔vault`, `corp↔roof`, `vault↔lab` (enter_lab_e), `roof↔lab` (enter_lab_w). **Start does not connect directly to Corp.**
- **Wall dims (CONFIRMED, load-bearing):** all 7 room perimeters are **20u thick / 256u tall**, NOT the session brief's assumed 16u/128u. Only the inner vault/helipad sub-chambers use 16u walls + a 128u ceiling. Any tool hard-coding 16u/128u will misalign every wall.
- **Perk staging row (CORRECTED):** parked at Y=4195 which is *inside* the lab interior (`Y[3068,4228]`), ~33u from the N wall — not "north of lab."

---

## 3. What "tighten + add tight spaces (harder)" means here

The mission already wants this directionally — but the bound is **"Der Eisendrache-sized, dense-not-empty,"** not "as small as possible" (`docs/03:12` anti-pillar: "Zones are small, connected, readable. Density beats scale."). Difficulty is supposed to come from spawn density, elite utility, movement/positioning and the speed curve — **NOT from cramped kill-boxes or bullet-sponge HP** (`docs/11:7-13`, `docs/06:296-304`). So "harder via tight spaces" must be read as a *skill* lever, not a *trap* lever.

Concrete translation:

1. **Shrink room interiors, not corridors.** The tightening headroom is in the room AABBs (1160-1560u of interior), because **corridors and wall-gaps are already at the bottom of the cited 192-256u lane floor** (`gen_zone_greybox.js:65-85`, `docs/29:176`). Narrowing a 256u corridor risks a hard navmesh-pathing failure, not just a balance shift. **Corridors and door gaps stay at 256u.**
2. **Add cover/pillars/debris to break sightlines and create tight-but-legal trains.** The sanctioned model already exists in-greybox: Corp's lobby S-curve is explicitly "tight, efficient, unforgiving" vs the "big, safe" fountain (`docs/03:176,221`). Roof's central obstacle and Market's stall row are the same idea. Tightening = **denser interior obstacles + a smaller room box**, producing shorter sightlines and tighter loop radii.
3. **Create true chokepoints only where a dead-end is sanctioned** — Vault Overload (point defense by design) and the boss room (Lab exits seal for the committed fight). Everywhere else, **every encounter keeps ≥2 outs** (`docs/06:300`).

### Hard rules that constrain the work (must all hold)
| Rule | Source | Implication for tightening |
|---|---|---|
| ≥2 exits per zone; no undesigned dead-ends | `docs/03:15`, `docs/06:300` | Never create a single-exit space (except Overload + sealed boss). |
| **Corp is a cut-vertex, never sealed** | `docs/03:17,55,112-116` | Keep all 4 corridor mouths (W Market, E Alley, NE Vault, NW Roof) open + passable. |
| **Plaza & Lab never sealed; both Lab approaches intact** | `docs/03:17,54,92-93` | One Lab approach welds per run — keep both physically built. |
| ≥2 training spots per *major* zone | `docs/03:14` | Don't degrade Corp's 2 trains (the only decon-survivable ones). |
| Min lane width 192-256u; avoid every riser/dog struct | `docs/29:176`, reference-techniques dossier | Cover must clear 4 risers + 1 dog per zone; lanes ≥192u (256u is the real safe floor for a horde train — see open Qs). |
| Decon already shrinks the map (seals 1 of Market/Alley/Vault/Roof per round R1-4) | `docs/03:95-127`, `_acc_decontamination.gsc:58` | Geometry tightening *compounds* with decon — don't double-count into an unsurvivable mid-run state. |
| Verticality is earned (Roof/Vault late-unlock) | `docs/03:16,187` | Don't push players upward early via tightening. |

**The sharpest tension:** the zombie speed curve (R10 = 105% of base-game max, then **+1pt/round with no cap**, sprint-locked, no slow tail — `_acc_zombie_speed.gsc:103-194`) was tuned around *large open training loops* where the player out-circles a near-player-speed horde on the loop radius. Shrinking the named loops directly attacks that survival tool (see §5).

---

## 4. Coupling & risk map — exactly what breaks when a room shrinks

The verifications confirm the duplication is **4-way (not the 3-way docs/29 assumed)** for room footprints, **plus 2 more copies** of the PaP origin. There is **no single source of truth and no validator**, and the generators are one-shot/consumed — so shrinking a room today is hand-editing baked brushes plus separate manual fixes to several files, with nothing to keep them in sync.

| Coupled artifact | What breaks on a naive shrink | Severity | Auto-handled? |
|---|---|---|---|
| **Room footprint, copy 1** — `gen_zone_greybox.js:54-61` rooms{} (6 rooms, no start) | Edits do nothing (tool only emits paste-text; header says "don't re-run") | — | N/A (consumed). Must edit the SoT instead (Stage 0). |
| **Room footprint, copy 2** — `gen_map_design.js:47-55` rooms[] (6 + start, hand-synced) | SVG silently goes stale; **vault/roof already wrong** (it draws greybox rects, not the baked gen_rooms insets) | **MED** | No — manual; or regenerate after SoT lands. |
| **Room footprint, copy 3** — baked `.map` worldspawn brushes + info_volume planes | The actual geometry; hand-edit per room | **HIGH** | No — manual Radiant + full rebuild. |
| **Room footprint, copy 4** — `gen_rooms.js:63-68` insets (vault `1000..2400 x 2490..3170`, roof mirror; **H=128 not 256**) | **No re-run guard — double-injects shells if re-run** (real footgun). Diverges from greybox numbers; this is what's actually baked for vault/roof | **HIGH** | No — must add a guard before any geometry pass. |
| **Door slab + trigger pair** (8 each = 16 brushmodels) | Slab/trigger reuse a **placeholder template box (planes 1-3 generic 134.5/459.5…)**; only planes 3-6 carry real position. A uniform 6-plane rewrite corrupts them. Slab + trigger + wall-gap + corridor floor = **4 coupled brushes per doorway** — gap must stay aligned to the door slab AND the corridor floor or doors open into a wall / leave a hole | **HIGH** | No — manual, per doorway. |
| **Zone `info_volume`** (oversized, extends into corridors; start's is sheared/garbage AABB) | Resize room but not volume (or vice-versa) → broken zone-occupancy / spawn-eligibility / decon kill-region. Each volume covers the room box + half of each adjacent corridor (`gen_zone_greybox.js:184-190`) | **HIGH** | Decon/zone *detection* is geometry-agnostic (IsTouching on the volume), so shrinking the volume shrinks the kill region in lockstep — **but the volume brush itself must be hand-resized**. |
| **Gameplay entity origins** (~40) | Boxes ~38-40u from N walls, **corp power switch 9u from E wall** — a shrink pushes them outside the new interior | **HIGH** | No — `apply_entity_moves.js` (rewrites origin/angles by GUID) can *relocate* them, but it's manual per entity. |
| **Spawner risers** (4 riser + 1 dog/zone at quarter-points; Start's elevated z207-208 ledge) | Shrink can strand a riser inside cover or outside the regenerated navmesh → zombies fail to spawn/path; **empty spawn pool stalls the round engine** | **HIGH** | No — manual re-placement + navmesh rebuild. |
| **PaP origin, copy A — `_acc_perk_info.gsc:240`** `pap_org = (-700,3700,7.5)` (comment: "Hardcoded - dev map is stable") | Used at `:274` to decide the PaP info-card/tier-ladder. **The ONLY literal world coord in production GSC** (verified by regex sweep). Move PaP → card fires at the empty old spot, never at the real machine | **HIGH (silent break)** | No — but cheap fix: read the live `pack_a_punch` ent origin (as `_acc_pap_levels.gsc:80,93` already does). |
| **PaP origin, copy B — `apply_entity_moves.js:22`** same `-700 3700 7.5` | 6th copy of the same number; moving PaP in Radiant updates the `.map` but not this literal | **MED** | No — manual. |
| **Dev teleport coords — `_acc_dev.gsc:91,96`** `(0,4090,32)` perk row, `(-291,-316,32)` spawn | Drops tester into wrong/solid geometry after a shrink | **LOW (test-only)** | No — manual; dvar-gated, no shipping impact. |
| **Atmosphere fog** — `_acc_atmosphere.gsc:34-41` (halfway 700u, base height world-Z 0) | 700u fog = no fog in a small room; z=0 densest layer wrong if floor moves | **LOW** | OFF by default (`acc_fog_on 0`), live dvar-tunable. |
| **Soft radii** — overload hold 96u, perk/PaP/box info 100-130u, ability AoE (Whirlwind 96u, Meltdown 150u, reactive 128u, shard pickup 48u) | All read live origins (survive a move) BUT assume the room fits the radius. Two interactables closer than 100-130u → info card flickers / discount mis-applies. **AoE radii are pure DistanceSquared with NO line-of-sight trace** — thin cover does NOT block them | **MED** | No — re-tune per shrunk room; decide if cover should block AoE (needs LOS traces added). |

**Geometry-agnostic = SAFE on move (verified):** `_acc_map_randomizer` (power A/B, PaP approach blockers via DisconnectPaths/ConnectPaths, wallbuy removal, lab perk slots — all by targetname/script_string, zero literal origins); decontamination zone bounds (`IsTouching` on info_volumes); boss/Brutus/Panzer spawns (struct::get + pin at own origin); zone graph + all terminals/kiosks/triggers by targetname; pacing/speed/corpse-cleanup/event-wave systems (count- and animation-rate-driven, no geometry). These need **no edits** beyond the navmesh rebuild.

**Build type for geometry edits:** material/sky/probe and any brush/footprint change is **BSP-baked** → full pipeline `cod2map64` (BSP + navmesh, **run with cwd = `<tools>\bin`** or navmesh gen aborts) → `radiant_modtools -ledSilent … +recompute` (LED) → `linker_modtools`. **GSC-only fixes (the PaP coord, dev teleports, radii) are linker-only.** Forgetting the navmesh rebuild leaves a stale `_navmesh.hkt` → zombies won't path the new geometry even though the `.ff` builds clean (silent train-breaking failure). And: **sync to the deployed usermap before every build** (`tools/sync_to_modtools.ps1`) — the linker compiles the deployed copy, not the repo.

---

## 5. Interaction with existing difficulty systems

**Yes — tighter geometry risks unfair stacking with the existing, geometry-blind difficulty stack.** The map already carries a deep difficulty model that *assumes large open training loops exist*:

- **Speed curve** (`_acc_zombie_speed.gsc`): R1 = 70% → R10 = 105% of base-game MAX → **+1pt/round with NO cap** (R20=115%, R30=125%), sprint-locked, re-asserted every 1.5s, **no slow tail**. An unupgraded player caps ~100-108% (≈109% with Stamin-Up, `docs/13:119`). So from ~R15-20 the speed margin is razor-thin and survival depends on **out-circling on the loop radius**, not straight-line running.
- **Early-round density**: ×1.40 (R1), ×1.35 (R2-4) on round *total* count.
- **Co-op**: +100% regular HP, +30% spawn count per extra player.
- **On-screen AI cap is STOCK 24, never overridden** — so the multipliers raise the per-round *total*, not the peak *alive count*. **In a smaller room, those 24 alive occupy proportionally more floor**, shrinking the gap the player needs to round the corner. This is the core tight-space danger: congestion, not more bodies.
- **Brutus** charges *alongside* the wave every 5 rounds (2 of them R20+), with a movement fix forcing a **straight charge** (`acc_brutus_runfwd=1`, goalradius 64) — in a tight room he cuts off the only escape lane far more easily than in an open arena.
- **Modifiers** (`_acc_modifiers.gsc`): `sprint` clamps every round ≥100% (removes the safe early ramp), `code_red` adds HP×1.2 + elite rate×1.5, `fragility` halves player HP. **Worst legitimate stack: tightened map + sprint + code_red + 4-player.**
- **Decontamination already shrinks the map** (seals up to 4 of 7 zones R1-4). A run that seals Roof early (the "best late-game train") *and* runs tightened remaining rooms could leave **no viable late-game train at all** (`docs/03` already warns "gone if Roof sealed").

**There is currently no dynamic difficulty/space sensor — every curve is geometry-blind.**

**Re-tune recommendations (decide before/with the geometry pass):**
1. **Consider a speed cap above R10** (e.g. clamp `acc_zspeed` to some max %) so the uncapped curve and tighter loops don't compound into "no margin to round any obstacle." Today there is none.
2. **Re-validate `ACC_OVERLOAD_POINT_RADIUS` (96u)** against any shrunk Vault alcove — below ~96u of standable floor the Overload becomes impossible to hold.
3. **Re-tune the 100-130u info/discount radii** if interactables end up closer than that after a shrink (flicker / mis-applied discount).
4. **Decide AoE-vs-cover policy:** Meltdown 150u / Whirlwind 96u / reactive 128u are pure distance checks — if new cover is meant to *protect* zombies behind it, these need LOS traces added, or they'll keep hitting through thin walls.
5. **Possibly reduce the early-round mult (1.40/1.35) or the co-op spawn term** for tightened rooms, since R1-4 happens in the smallest/most-sealed state.
6. Consider making the soft radii **dvar-tunable** like the speed curve, so tuning per room doesn't require a recompile.
7. **Prefer tightening NON-training zones** (Alley, Lab transaction strip, Vault point) and explicitly **preserve the open training loops** (Roof arena, both Corp trains) rather than uniform shrinking — this is the safest reconciliation of "harder" with the speed-curve assumption.

---

## 6. Recommended staged plan

This refines `docs/29` §6 into concrete, build-gated stages. **Tooling first, geometry last, one room at a time, build+run between each.** Recommended mitigation for the duplication is the **lightweight validator (low-risk)**, not the full round-trip regenerator (high-risk) — both verifications and the tooling dossier converge on this.

### Stage 0 — Source of truth + validator + guards (NO geometry change) — ✅ DONE 2026-06-15
- **Changes:** (a) ✅ Created `source_data/rooms.json` capturing the canonical per-room **outer footprint**, wall dims (20u/256u), wall gaps, corridor edges, the vault/roof gen_rooms shells, and the PaP origin. *(Scoped OUT: spawner/box/entity origins — they live only in the `.map` and are hand-tuned, e.g. market dog at y=1100 ≠ generator's computed y=900, so the `.map` stays authoritative for those; the SoT tracks only the **duplicated** geometry.)* (b) ✅ Wrote `tools/validate_rooms.js` asserting the 4 footprint copies (`gen_zone_greybox.js` rooms, `gen_map_design.js` rooms, baked `.map` floor slabs, `gen_rooms.js` shells) AND the 2 PaP-origin literals agree — wired into `tools/preflight_windows.ps1`. (c) ✅ Added the re-run guard to `gen_rooms.js`. (d) ✅ Refactored `_acc_perk_info.gsc` to read the live `pack_a_punch` ent origin (literal kept as fallback). (e) ✅ Resolved the vault/roof ambiguity — see §0: it's a **double-shell conflict**, canonical = greybox outer; the gen_rooms shell is removed/reconciled in Stage 2.
- **Verify:** ✅ validator green (26 ok / 0 error, 2 warns = the known vault/roof double-shell). GSC xref lint clean. PowerShell preflight syntax OK. *(Regenerating the SVG + an in-game PaP-card check happen at the next build — no geometry changed, so deferred to Stage 1's build.)*
- **Build type:** linker-only (GSC refactor) + tooling (no build). No BSP.
- **Rollback:** trivial (revert JSON/JS/GSC; no geometry touched).

### Stage 1 — Pilot leaf: `market_zone` ONLY
- **Changes:** shrink Market's interior (proposal §7), recompute its **2 wall gaps** (E side: Y400-656 to Start, Y1200-1456 to corp_w), move its **5 spawners** (4 risers + dog) + MagicBox `(-1881,1540)` into the shrunk box, **resize the info_volume** (room box + half each adjacent corridor), fix **both door pairs** (slab + trigger, planes 3-6 only), keep the corridor floor slabs (`bw70`, `bw76`) bridging the gap.
- **Verify in-game:** in-zone reads correct; both doors flush (no wall-hole / no door-into-wall); zombies spawn from all 5 risers and path; box reachable; decon seal still shrinks the kill region; validator green.
- **Build type:** **full** — `cod2map64` (cwd=`<tools>\bin`) → radiant LED → linker. Sync first.
- **Rollback:** Market is a leaf with 2 corridors and no cut-vertex role — revert its brushes/entities/volume only; nothing else depends on it.

### Stage 2 — Propagate to remaining leaves (Alley → Vault → Roof)
- **Changes:** repeat Stage 1 per room. **Vault/Roof carry nested inner sub-chambers** (`bw102-113`, separate 16u-walled boxes with their own 128u ceiling and a single doorway gap) — shrink the *outer* box without colliding with / orphaning the inner chamber. **Roof: tighten conservatively** — it's the documented best late-game train. Both carry PaP blockers in their lab corridors (`Y3120-3336`, z0-256) — don't overlap them.
- **Verify:** per-room as Stage 1, plus inner chamber intact (Vault/Roof) and Overload hold still works (Vault, re-check 96u radius).
- **Build type:** full per room.
- **Rollback:** per leaf, independent.

### Stage 3 — Hub: `corp_zone` (HIGHEST CARE)
- **Changes:** shrink Corp's 1560×1560 interior while **keeping all 4 corridor mouths open** (cut-vertex) and **both trains** (fountain + S-curve). Move box `(640,2690)`, **relocate the power switch off the 9u-from-wall position**, 5 spawners.
- **Verify:** Plaza→Lab path intact through Corp; both trains still loopable; power switch reachable; decon never seals Corp.
- **Build type:** full.
- **Rollback:** higher blast radius — Corp connects 4 zones; revert is per-zone but must re-verify graph connectivity.

### Stage 4 — Safe zones: `start_zone` then `lab_zone`
- **Changes:** Start has the most dead floor → most shrink headroom, but it's irregular and **its info_volume is sheared (don't derive size from it)**; keep it spawn-safe with the elevated NW riser ledge (z207-208) valid. Lab must **reserve floor for the 4 future `acc_lab_perk_a..d` machines** and not collide with the boss arena `(19,3648)` (= lab dog spawn); keep **both Lab approaches built**.
- **Verify:** Start spawns + initial_spawn_points valid; Lab boss arena + kiosk/terminal reachable; both Lab doors flush; dev teleports updated.
- **Build type:** full.
- **Rollback:** per zone.

### Stage 5 — Obstacle pass per validated room
- **Changes:** add `script_brushmodel` cover (auto-DisconnectPaths; **`script_model` would need a clip brush or zombies path through**) that **avoids every riser/dog struct**, keeps corridor mouths clear, keeps lanes **≥192-256u**, and builds the intended tight-but-2-out training loops (§7). Add cover only *after* a room's shrink is validated.
- **Verify:** zombies path around every obstacle; no riser trapped; lanes measured ≥192u; ≥2 outs preserved; no new single-exit space.
- **Build type:** full (obstacles are BSP-baked; navmesh regen required).
- **Rollback:** per obstacle/room.

### Stage 6 — Re-validate all per-run randomization + difficulty re-tune
- **Changes:** apply §5 re-tunes (speed cap decision, radii, AoE-LOS decision, early-mult). Re-run the randomizer across many seeds.
- **Verify:** power A/B both seeds, both Lab approaches weld correctly, decon bounds, Corp cut-vertex, overload/boss points — all valid post-shrink. Confirm no decon-order produces an unsurvivable no-train state.
- **Build type:** linker-only (GSC tuning) unless geometry changes.
- **Rollback:** revert tuning dvars/constants.

---

## 7. Specific tightening proposals per zone

Targets below aim for **Der Eisendrache density (dense-not-tiny)** — roughly a **20-30% interior reduction** on over-large rooms, **lighter on Roof/Corp** (training-critical), with cover doing most of the "tight" work. All keep corridors/gaps at 256u. **These are starting proposals for the user to set aggressiveness on (see §8) — not final numbers.**

| Zone | Current interior | Proposed target | Cover / chokepoints | Two training loops | Corridors | Rule it must not violate |
|---|---|---|---|---|---|---|
| **Start (`start_zone`)** | ~2110×1962 | **~1700×1500** (most headroom; trim the dead S/SW floor away from spawns) | A small central debris cluster + 2 low ledges to shorten sightlines from the door mouths | Keep the 1 small debris loop (R~8) + add a second tight loop near the NW riser ledge — **but keep it spawn-safe** | Both at 256u (Y400-656 each side) | Plaza never sealed; keep 8 initial_spawn_points + elevated risers valid. |
| **Market (`market_zone`)** | 1160×1360 | **~950×1100** | Tighten the existing 3-stall row into a true serpentine; add 1 corner pillar | Stall-row loop (kept) + a second short S near the box | E gaps Y400-656 + Y1200-1456 @256u | Leaf, ≥2 exits; box must stay reachable (~40u clearance — relocate inward). **Pilot — validate here first.** |
| **Alley (`alley_zone`)** | 1160×1360 | **~900×1100** | This is the sanctioned place for a **true chokepoint** (intentionally no good train) — a narrow dog-leg of cover that funnels the horde | None designed (keep it) — but still ≥2 outs (Start corridor + corp_e) | W gaps Y400-656 + Y1200-1456 @256u | ≥2 exits even though no train — never a single-exit kill-box. |
| **Corp (`corp_zone`)** | 1560×1560 | **~1350×1350** (light trim only) | Add cover that *sharpens* the S-curve (the "tight, unforgiving" model) without shrinking the fountain loop | **Keep BOTH**: fountain (big/safe) + S-curve (tight) — these are the only decon-survivable trains | **All 4 mouths open** @256u | **Cut-vertex — never sealed; Plaza↔Lab must stay connected.** Move power switch off the 9u wall margin. |
| **Vault (`vault_zone`)** | 1160×1160 outer | **~1000×1000 outer** | Keep the inner sub-chamber as the Overload arena; add minimal cover *outside* the 96u hold bubble | Overload defend point only (sanctioned dead-end) | W gaps Y2300-2556 + Y3100-3356 @256u | Don't shrink below 96u standable around `acc_overload_point (1712,2900)`; don't orphan inner chamber `X[984,2416] Y[2474,3186]`; don't overlap PaP blocker. |
| **Roof (`roof_zone`)** | 1160×1160 outer | **~1100×1100 (lightest trim)** | Keep the large open circle + central obstacle `X[-1847,-1591] Y[2672,2928]`; add at most one extra low block | **Best late-game train — preserve the open loop radius**; the speed curve depends on it | E gaps Y2300-2556 + Y3100-3356 @256u | Don't collapse the documented best late-game train; don't orphan inner helipad chamber; verticality earned (late-unlock). |
| **Lab (`lab_zone`)** | 1560×1160 | **~1300×1050** | Cover flanking the kiosk/terminal to make the transaction zone tense; **none in the boss arena center** | None designed (transaction/boss) — keep boss exit-seal intent | Both lab gaps Y3100-3356 @256u | **Never sealed; both approaches built.** Reserve floor for 4 `acc_lab_perk_a..d`; don't collide boss spawn `(19,3648)` (= dog spawn). |

---

## 8. Open questions / decisions needed from the user

1. **How aggressive a shrink?** No measured Der Eisendrache footprint budget exists (`docs/20:148` is still open/design-only). The §7 proposals assume ~20-30% interior reduction (lighter on Roof/Corp). **Decision: a fixed % target, per-zone hand-tuned, or a configurable dvar-driven approach?** And is there a *minimum room dimension* (vs the 192-256u lane floor) below which a zone can't host a horde train? Not documented.
2. **Keep the procedural generator or hand-author in Radiant?** The generators are one-shot/consumed and the duplication has no SoT. Recommended: **Stage 0 validator (low-risk)** over the full `.map↔JSON` round-trip regenerator (high-risk, doesn't exist). Confirm you want validator-only, not a full regenerator rebuild.
3. **Cap the speed curve?** R10 = 105% then **+1pt/round uncapped** — in tighter loops a 110-120% wave eats the radius advantage. Should tightened rooms ship with a speed cap (e.g. clamp `acc_zspeed` to a max %), and should the soft radii be made dvar-tunable like the speed curve?
4. **Should cover block AoE/sightlines, or only the player's view?** Meltdown 150u / Whirlwind 96u / reactive 128u are pure distance checks (no LOS). If cover is meant to *protect* zombies behind it, LOS traces must be added before placing cover.
5. **Opt-in vs baked?** `docs/07` says "modifiers are where we experiment." Should new tight spaces ship as a **"harder" modifier toggle** first (test harshness as a toggle) rather than baked into base geometry — especially given the decon double-count risk?
6. **Limit tightening to NON-training zones?** Safest reconciliation with the speed curve: tighten Alley / Lab strip / Vault point and **explicitly preserve Roof + both Corp trains**. Confirm this is acceptable, or whether the open trains may be tightened too.
7. **Canonical vault/roof footprint?** `gen_rooms.js` inset (what's baked) vs greybox outer (what `gen_map_design.js` draws) — the SVG is already wrong for these two. Pick the canonical source for Stage 0's `rooms.json`.
8. **Sequencing with unbuilt geometry:** `acc_seal_<zone>`, `acc_shortcut_server_roof`, the 4 `acc_lab_perk_a..d`, and (per `gen_rooms.js`) the **vault/roof doorways may not be cut yet** — several modules log "not placed yet"/TODO(acc-geom). Should the decon physical-seal geometry and these structs be authored *in tandem* with the shrink (same zone bounds), or after?
9. **AI cap:** keep stock 24 alive? Tightening rooms while holding 24 changes effective density even with no spawn-count change; lowering the cap would be the cleanest compensation for tight spaces.

---

### Source file/coordinate index (for the implementation pass)
- Baked geometry: `map_source/zm/zm_abandoned_cyber_city.map`
- Generators (one-shot): `tools/gen_zone_greybox.js`, `tools/gen_rooms.js` (no guard), `tools/gen_map_design.js` (SVG, idempotent), `tools/apply_zone_greybox.js`, `tools/apply_entity_moves.js` (relocate by GUID, PaP literal at :22), `tools/apply_zone_materials.js` (idempotent)
- Zone graph (authoritative connectivity): `scripts/zm/zm_abandoned_cyber_city.gsc:427-434`
- Silent-break literal to fix: `scripts/zm/zm_abandoned_cyber_city/_acc_perk_info.gsc:240` (used :274); survives-a-move reference: `_acc_pap_levels.gsc:80,93`
- Dev teleports: `_acc_dev.gsc:91,96`
- Soft radii: `_acc_events_overload.gsc:42,81,301` (96u); `_acc_perk_info.gsc:35-37`; `_acc_atmosphere.gsc:34-41` (fog)
- Difficulty curves (geometry-blind): `_acc_zombie_speed.gsc:103-194`, `_acc_early_round_pacing.gsc:27-88`, `_acc_coop_scaling.gsc:41-112`, `_acc_modifiers.gsc:95-154`, `_acc_boss.gsc`, `_acc_elites.gsc:38-46`
- Geometry-agnostic (safe): `_acc_map_randomizer.gsc`, `_acc_decontamination.gsc:297-353`
- Parent plan + rules: `docs/29_overhaul_checklist.md:160-186`, `docs/03_layout.md`, `docs/11_enemies.md`

---
---

# Stage-1 pre-edit de-risk (2026-06-15)

> Output of a 12-agent deep workflow (7 mechanics deep-dives → 4 adversarial verifiers → synthesis), all re-verified against the `.map`. Purpose: make the first geometry edit (market_zone) mechanical with zero surprises, and give a reusable playbook for the other 6 zones. Verifier corrections are folded in inline.

## 9. Geometry-editing playbook (read before ANY brush edit)

This is the reusable procedure for every zone shrink. Read it in full before the first `Edit` call.

### 9.1 The brush format (gen_zone_greybox family)

Every greybox room/wall/floor/stall brush is **6 plane lines in a fixed order**, emitted by `tools/gen_zone_greybox.js:39-52` `box(x1,x2,y1,y2,z1,z2,tex)`:

| Plane line | Role | Constant axis = the real bound | Verified literal (market floor, `map:390-395`) |
|---|---|---|---|
| Plane0 (1st) | bottom | `z1` | `( 134.5 459.5 -16 ) ...` |
| Plane1 (2nd) | top | `z2` | `( 94.5 419.5 0 ) ...` |
| Plane2 (3rd) | SOUTH (-Y) | `y1` | `( 86.5 200 88 ) ...` |
| Plane3 (4th) | EAST (+X) | `x2` | `( -1281 415.5 88 ) ...` |
| Plane4 (5th) | NORTH (+Y) | `y2` | `( 138.5 1600 88 ) ...` |
| Plane5 (6th) | WEST (-X) | `x1` | `( -2481 459.5 88 ) ...` |

**Only the constant-axis number is real.** On Plane3/Plane5 it is the **1st** number of each point (X); on Plane2/Plane4 it is the **2nd** (Y); on Plane0/Plane1 it is the **3rd** (Z). Every other number (`86.5/90.5/94.5/134.5/138.5/142.5/415.5/419.5/455.5/459.5` and the `88/0` Z-placeholders) is a **byte-identical hardcoded placeholder on every brush in the file** — zero positional info, never touch it (verified against the emitter and a byte-for-byte re-emit of brush 31).

> **Two incompatible brush families coexist.** The gen_zone_greybox family above (placeholder planes, 20u walls / 256u tall) vs the **gen_rooms** family (`tools/gen_rooms.js:30-44`, **full-corner** planes, **16u walls / 128u tall**, used ONLY for the vault/roof double-shell `map:1147-1268`, guids `ACCB00xx`). Never apply one family's winding to the other. Market Stage 1 touches only the gen_zone_greybox family.

### 9.2 Recommended edit mechanism: hand-edit the plane constants

**For Stage 1 (market), hand-edit the plane-constant numbers directly with `Edit`.** Market touches ~10 brushes + ~7 entities, each changing 1-2 numbers; the numbers are fully enumerated in §10 so there's no judgement at edit time, and the `Edit` tool's exact-string-match fails loudly on any mismatch (it's its own safety net). The repo's geometry was built this way (`gen_zone_greybox.js:5-9`: fragments "pasted into the .map by hand/Edit"; produced the FIRST CLEAN COMPILE).

A **by-guid brush-rewrite tool** (modeled on `apply_entity_moves.js:57-73`, emitting the 6 planes via the matching `box()` winding) is better **only when scaling to all 7 zones** — build it *after* market validates the footprint math, not before. Do **not** round-trip through Radiant for an axis-aligned shrink: it re-exports ~1000 unrelated faces, rewrites GUIDs/formatting, and breaks the by-GUID cross-checks in `validate_rooms.js`.

### 9.3 What makes a brush invalid (the only rules you can break)

1. The plane **normal is mathematically independent** of the constant value you edit (the constant cancels in both edge vectors) — editing `x1/x2/y1/y2/z1/z2` keeps the same outward normal.
2. **Keep the ordering `x1<x2`, `y1<y2`, `z1<z2`.** Crossing them (e.g. moving WEST east *past* EAST) makes the opposing half-spaces stop overlapping → empty solid the BSP rejects/culls. *(Verifier correction: the failure is the half-space **offset `d`**, NOT a "normal inversion" — do not propagate "normal inverts" wording. The actionable `x1<x2` rule is correct.)*
3. **Minimum wall thickness = 20u**, height 256u, floor slab 16u. 20u compiled clean; never go thinner.
4. Never corrupt a placeholder so two points in one plane line coincide → zeroes that plane's normal → degenerate brush.

### 9.4 Fixed-vs-free wall rule (the core DOF principle)

**Every corridor in ACC runs E-W, so all door/corridor wall-gaps live on a room's EAST or WEST wall.** Therefore:
- A wall **carrying a gap is FIXED** perpendicular — can't move without dragging the corridor floor + door slab + trigger + gap with it.
- **N/S walls carry no gaps → free** to move inward in Y, bounded only by the Y-band the E/W gaps occupy ("gap-Y envelope" — pulling past it orphans a gap).
- An **X-wall is free only if it carries no gap.**

For **market**: EAST wall (`x2=-1281`) holds BOTH gaps (`Y[400,656]` start; `Y[1200,1456]` corp_w) → **FIXED, never touched**. WEST / NORTH / SOUTH are free.

### 9.5 Non-negotiable build sequence (geometry = full pipeline, NOT linker-only)

A brush move is BSP-baked; a linker-only pass repacks the `.ff` around the **old** `.d3dbsp` + **old** `_navmesh.hkt` → walls look unchanged AND zombies path the old footprint. Mandatory order (`<tools>` = the AppID-suffixed Mod Tools root):

```
1. .\tools\preflight_windows.ps1        # 0 FAIL; runs validate_rooms.js + lint_gsc_xref.js + brace/CRLF canary
2. .\tools\sync_to_modtools.ps1         # linker reads the DEPLOYED copy; verify <tools>\map_source\...\.map mtime changed
3. Push-Location "<tools>\bin"; & "<tools>\bin\cod2map64.exe" -platform pc -navmesh -navvolume -loadFrom "<tools>\map_source\zm\zm_abandoned_cyber_city.map" "<tools>\share\raw\maps\zm\zm_abandoned_cyber_city.d3dbsp"; Pop-Location
4. & "<tools>\bin\radiant_modtools.exe" -ledSilent +medium +localprobes +forceclean +recompute "<tools>\map_source\zm\zm_abandoned_cyber_city.map"
5. & "<tools>\bin\linker_modtools.exe" -language english -modsource zm_abandoned_cyber_city
6. .\tools\run_game.ps1                  # Steam launch, +set_gametype zclassic
```

**`cod2map64` MUST run with cwd = `<tools>\bin`** or navmesh gen aborts (`ERROR: Unable to load navigation mesh generation settings`) **while still writing the `.d3dbsp`** — build looks fine but `_navmesh.hkt` is stale and zombies path old geometry (verified live 2026-06-13).

### 9.6 Navmesh-staleness check (every geometry build)

The `.ff` building clean is **not** proof the navmesh updated. After step 3:
- `Get-Item "<tools>\share\raw\maps\zm\zm_abandoned_cyber_city*.hkt" | Select Name,LastWriteTime` — `_navmesh.hkt` mtime must be **newer than your `.map` edit**.
- `cod2map64` stdout must NOT contain `Unable to load navigation mesh generation settings`. (`NavVolume generation is skipped` is harmless — ground-only zombies.)
- In-game: zombies emerge from all risers and path through the new layout without bunching at a wall.

No `.zone` edit is needed for a coordinate-only brush move (face material tokens are never listed in the `.zone`; geometry rides in via the `col_map`/`gfx_map` `.d3dbsp` lines). Do **not** change the material token during a shrink (that's a separate re-skin that hits the docs/29 §14 techset blocker).

---

## 10. market_zone Stage-1 shrink spec (exact, copy-ready)

> **EXECUTED 2026-06-15** — went with the **non-flush variant** (`X[-2161,-1281] Y[360,1496]`, interior 840×1096 = **41.6%**) for the pilot: no brush deletions (bw35/bw37 kept as 20u stubs), only constant-axis edits, EAST wall + both corridor mouths untouched. All 4 footprint copies synced, validator green; 5 orphaned chalk decals also removed. **Awaiting the full geometry build + the §11 playtest.** The flush spec below (43.3%) is retained as the more-aggressive reference for a later pass.

**Chosen footprint** (flush-to-gap variant, **~43.3% area cut**): outer `X[-2201,-1281] Y[400,1456]`, was `X[-2481,-1281] Y[200,1600]`. Interior (20u inset) `X[-2181,-1301] Y[420,1436]` = 880×1016 = 894,080u² vs current 1,160×1,360 = 1,577,600u² = **43.3% smaller**.
- WEST moves **+280u east** (-2481→-2201; inner -2461→-2181).
- SOUTH moves **+200u north** (200→400; inner 220→420).
- NORTH moves **-144u south** (1600→1456; inner 1580→1436).
- New `y1=400` lands exactly on the start-corridor gap bottom; new `y2=1456` on the corp_w gap top. Both gaps stay fully inside the new Y extent.

> **Flush-cut caveat:** this footprint sits *exactly* on the gap edges, so the two outer EAST-wall segments collapse to zero and are deleted. If a build shows a sliver/T-junction at the wall-end↔corridor seam, fall back to the **non-flush variant** `X[-2201,-1281] Y[360,1496]` (≈41.6%, `x1=-2161`) which keeps a 20u solid stub on bw35/bw37 and deletes nothing. *(Recommended: try non-flush first if any doubt — it preserves the full 256u corridor mouths and avoids the corner question entirely.)*

### 10.1 Brush edits (gen_zone_greybox family, all `script_*` tokens unchanged)

| Brush | guid tail | Lines | Change | Exact edit |
|---|---|---|---|---|
| **bw31 floor** | `...0101` | 387-396 | S, N, W | L392 `200`→`400`; L394 `1600`→`1456`; L395 `-2481`→`-2201`. **Leave L393 EAST `-1281`.** |
| **bw32 SOUTH wall** | `...0102` | 397-406 | move N +200, follow W | L402 `200`→`400`; L404 `220`→`420`; L405 `-2481`→`-2201`. Leave L403. |
| **bw33 NORTH wall** | `...0103` | 407-416 | move S -144, follow W | L412 `1580`→`1436`; L414 `1600`→`1456`; L415 `-2481`→`-2201`. Leave L413. |
| **bw34 WEST wall** | `...0104` | 417-426 | move E +280, follow S/N | L422 `220`→`420`; L423 `-2461`→`-2181`; L424 `1580`→`1436`; L425 `-2481`→`-2201`. |
| **bw35 EAST seg1** | `...0105` | 427-436 | **DELETE** (flush) | South wall now reaches y=400 (gap bottom) → this `Y[220,400]` segment is zero-length. Delete the block incl. `// brush 35`. |
| **bw36 EAST seg2** | `...0106` | 437-446 | **NONE** | Solid wall between the two corridor mouths (`Y[656,1200]`). Leave entirely. |
| **bw37 EAST seg3** | `...0107` | 447-456 | **DELETE** (flush) | North wall now reaches y=1456 (gap top) → this `Y[1456,1580]` segment is zero-length. Delete the block incl. `// brush 37`. |

After deletion the east wall is one clean run: bw36 solid `Y[656,1200]`, gaps `Y[400,656]` and `Y[1200,1456]` open to their corridors.

### 10.2 Obstacle brush edits (3 stalls — re-space inside new interior `X[-2181,-1301]`)

| Brush | guid tail | Lines | Old X | New X |
|---|---|---|---|---|
| **bw103** | `...0149` | 1107-1116 | `[-2181,-2021]` | `[-2101,-1941]` (L1113 `-2021`→`-1941`; L1115 `-2181`→`-2101`) |
| **bw104** | `...014A` | 1117-1126 | `[-1961,-1801]` | `[-1881,-1721]` (L1123 `-1801`→`-1721`; L1125 `-1961`→`-1881`) |
| **bw105** | `...014B` | 1127-1136 | `[-1741,-1581]` | `[-1661,-1501]` (L1133 `-1581`→`-1501`; L1135 `-1741`→`-1661`) |

Y bounds (`850/950`) unchanged.

### 10.3 Entity moves (origins live ONLY in the .map — hand-tuned, authoritative)

| Entity | guid tail | Line | Old origin | New origin | Reason |
|---|---|---|---|---|---|
| **riser ent49** | `...0155` | 1781 | `-2181 550 0` | `-2090 640 0` | old X flush with new WEST inner; pull in (91u off W, 220u off S) |
| **riser ent50** | `...0156` | 1792 | `-2181 1250 0` | `-2090 1216 0` | clears new WEST 91u, new NORTH inner (1436) 220u |
| **riser ent51** | `...0157` | 1803 | `-1581 550 0` | `-1500 640 0` | inside; nudge off E datum |
| **riser ent52** | `...0158` | 1814 | `-1581 1250 0` | `-1500 1216 0` | inside; clears new NORTH 220u |
| **dog ent53** | `...0159` | 1824 | `-1881 1100 0` | `-1700 1130 0` | keep hand-tuned ~y1100 feel; 306u off NORTH inner (do NOT revert to computed y=900) |
| **Box zbarrier ent24** | `...0201` | 1559 | `-1881 1540 13.75` | `-1561 1340 13.75` | y=1540 is NORTH of new wall (y2=1456) → buried; move into interior (96u off NORTH inner) |
| **Box struct ent24b** | `...0202` | 1586 | `-1881 1540 13.75` | `-1561 1340 13.75` | **MUST equal ent24 origin** or prompt/barrier desync |
| **reflection probe ent116** | `...03C2` | 2870 | `-1881 940 90` | `-1741 928 90` | recenter on new centroid; also shrink `size_max`/`size_min` half-extents (non-fatal if left, mis-lights) |

> **Clearance basis (verifier reconciliation):** the SHRINK-MATH verifier's "192u FAIL" is NOT a spec (its own openQuestion was "192u spec?"). The authoritative spawner rule is **≥64u from any wall (ideally 96-128u), ≥96u from cover**; 192u is the *lane* minimum (gap between obstacles), not a per-spawner radius. The verifier's valid point — that the *current* origins fail and entities **must** be relocated — is honored above.

### 10.4 info_volume ent48 — resize brush0 ONLY (zone trigger AND decon kill-region)

Union of 3 brushes, `z[-16,400]`, `map:1738-1775`. **Resize only brush0** (the room box); brush1/brush2 (corridor-half coverage at the fixed EAST edge) **do not change**.

| Brush0 (`...0151`) plane | Line | Old | New |
|---|---|---|---|
| SOUTH | 1750 | `200` | `400` |
| EAST | 1751 | `-1281` | **unchanged** |
| NORTH | 1752 | `1600` | `1456` |
| WEST | 1753 | `-2481` | `-2201` |

This volume drives **three** systems at once: stock zone occupancy/spawn-enable, the dev zone HUD readout, and the decontamination EVACUATE kill-region (`_acc_decontamination.gsc:506-528` reads `level.zones[market_zone].volumes`). A mis-fit volume breaks all three together.

### 10.5 What explicitly does NOT change
- **EAST wall datum** `x=-1281`/`-1301` — bw31 Plane3, bw36 Plane3/5, info_volume brush0 EAST. Never moved.
- **bw36** (solid east wall between the two mouths).
- **Both corridors** (start-market + corp_w) — attach at the fixed EAST edge, run east; zero edits.
- **enter_market door** trigger ent88 (`X[-1200,-1136]`) + slab ent89 (`X[-1176,-1160]`) — in the corridor gap, east of x=-1281.
- **enter_corp_w door** trigger ent92 + slab ent93 — in the c_mkt_corp corridor, east of x=-1281.

### 10.6 rooms.json update (do FIRST, before the .map)
Set `source_data/rooms.json` `market_zone.outer` → `{ "x1": -2201, "x2": -1281, "y1": 400, "y2": 1456 }`. Then `node tools/validate_rooms.js` (it will FAIL until the .map matches — expected; it tells you which copy drifted). Do **not** re-run `gen_zone_greybox.js` (stdout scaffolder, no idempotency, would clobber hand-tuned origins).

---

## 11. Pre-edit + in-game verification checklists

### 11.1 Before editing
- [ ] `node tools/validate_rooms.js` GREEN at baseline (26 ok, 2 warn = known vault/roof double-shell, 0 error).
- [ ] Backup: `Copy-Item map_source\zm\zm_abandoned_cyber_city.map …\.map.market-bak` (working mode is edit-on-main, no commits — this is the rollback anchor).
- [ ] Edit `rooms.json` market_zone.outer FIRST (§10.6).
- [ ] Make the .map brush + entity edits per §10 (each `Edit` matches a unique line; a failed match = mis-read placeholder, stop and re-read).
- [ ] Re-run `validate_rooms.js` → GREEN.
- [ ] `.\tools\preflight_windows.ps1` → 0 FAIL.

### 11.2 After building (full pipeline §9.5, navmesh check §9.6)
Launch `.\tools\run_game.ps1`. `console_mp.log` is the runtime oracle (last lines = fatal; the wall of "Could not find material/fx" is normal usermap noise).
- [ ] **Zone reads** — dev zone HUD reads `MARKET` in the shrunk room (`_acc_dev.gsc:391-439`).
- [ ] **Both doors flush** — no hole beside either doorway, no slab into a wall (`acc_tp_spawn 1` / `acc_tp_perks 1`).
- [ ] **All 5 spawners emerge + path** — 4 risers + dog at new origins, no bunching at a wall (`acc_skip_round 1`).
- [ ] **Box reachable** — acc_box_market at `(-1561,1340)`, weapon spawns, clear of the north wall.
- [ ] **Decon kill-region matches** — die only inside the new room, survive in corridors/adjacent rooms.
- [ ] **No void/fall-through** across the whole new floor.
- [ ] **No z-fighting** at moved wall/floor seams + relocated stalls.

### 11.3 Rollback if a build/playtest fails
- Market-only edit → `git checkout -- map_source/zm/zm_abandoned_cyber_city.map source_data/rooms.json` (or hand-restore from `*.market-bak`).
- **After any rollback, RE-RUN the full geometry pipeline** or the broken geometry stays baked in the deployed `.ff`.

---

## 12. vault/roof double-shell — reconcile BEFORE shrinking those zones

**Pre-existing bug, independent of the shrink.** Each of vault/roof has two shells:
- **Shell A (KEEP)** — gen_zone_greybox room: 20u walls, `z[0,256]`, door gaps `Y[2300,2556]`/`Y[3100,3356]` that **exactly** match the corridors and **fully contain** the door slabs (20u margin). Vault brushes 54-60 (`map:617-748`, guids `...0118-011E`); roof 61-67 (`...011F-0125`).
- **Shell B (DELETE)** — gen_rooms shell: 16u walls, `z[-16,144]` with a solid 128u ceiling inside a 256u room, footprint **larger in X** (`x[984,2416]` vs `x[1119,2319]` — pokes 135u west into the live corp_vlt corridor next to the door slab), and **misaligned** door gaps (`Y[2474,2536]`/`Y[3120,3186]`) that do NOT contain the door-slab travel. Causes a coplanar double floor (z-fight), a low false ceiling, and solid geometry in the corridor/door path.

**Delete these 12 brushes (anchor on the `ACCB00xx` guid prefix):** vault `ACCB0010-0015` (`map:1147-1207`), roof `ACCB0020-0025` (`map:1208-1268`). Delete each whole block incl. its `// brush …` comment + the `// ACC room shell:` header, but **preserve the worldspawn close `}` (L1269) and `// entity 1` (L1270)**.

**Safe order:** (1) do this BEFORE shrinking vault/roof; (2) remove `genRoomsShells` from `rooms.json` AND the `parseGenRooms`/`genRoomsShells` loop from `validate_rooms.js` in the same change; (3) delete the 12 .map brushes; (4) `validate_rooms.js` → GREEN (now 26 ok, **0 warn**); (5) full geometry rebuild (Shell B's wall was solid in the corridor → navmesh near the door must regenerate). Do NOT re-run `gen_rooms.js` (false premise; its guard refuses anyway). After deletion vault/roof are open-top like the other 5 rooms (no leak — *confirm at the vault/roof build*).

---

## 13. Per-zone shrink feasibility (all 7)

All E-W corridors → gaps on E/W walls. Geometry-only (no corridor moves) reduction per zone:

| Zone | Fixed wall(s) | Free | Geometry-only cut | Notes |
|---|---|---|---|---|
| **market** | EAST (both gaps) | W,N,S | **~43.3%** ✅ | Stage-1 pilot. |
| **alley** | WEST (both gaps) | E,N,S | **~43.3%** ✅ | Exact X-mirror of market: `X[1319.5,2239.5] Y[400,1456]`. |
| **lab** | both X-walls (single gap each) | N,S | **~45.5%** ✅ | Pull N to `y2=3720` (**not 3700** — PaP is at y=3700; keep it inside). |
| **start** | both X-walls (one gap/side) | N,S | **~38-44%** ✅ | Largest absolute; keep the 4 template `initial_spawn_points` + spawners inside the new Y (read them from the .map first). |
| **vault** | WEST (2 gaps) | E,N,S | **~42.6%** ⚠️ | **Reconcile §12 double-shell FIRST.** Pull free EAST in ~400u. |
| **roof** | EAST (2 gaps) | W,N,S | **~42.6%** ⚠️ | Mirror of vault. **§12 first.** Confirm roof door-slab X asymmetry is intentional. |
| **corp** | **BOTH X-walls** (4 gaps) | N,S only | **~15.6% only** ❌ | The 4-mouth cut-vertex. X can't shrink; Y floored at 1316. **40% needs corridor surgery** (relocating the vault/roof corridors south) → cascades into vault/roof. Design decision: accept ~15% or scope a dedicated corp-corridor stage. |

**Recommended stage order:** market (pilot) → alley (mirror) → lab → start → [vault+roof after §12] → corp (last; decide surgery vs accept ~15%).

---

## 14. Remaining unknowns / must-confirm-at-build-time

Honest list of what cannot be verified from source:

| # | Unknown | Cheapest check |
|---|---|---|
| 1 | Flush-cut T-junction/sliver from deleting bw35/bw37 | Build flush variant + scan cod2map/LED stdout + look in-game. **Fallback:** non-flush `Y[360,1496]` (§10). |
| 2 | Navmesh regen near corridor mouths after walls narrow | `_navmesh.hkt` mtime (§9.6) + watch all 5 spawners path. |
| 3 | Z-fighting at moved seams | In-game look along moved wall/floor seams. |
| 4 | Brush-winding literal sign cod2map64 consumes | A real build is the final arbiter; low-risk (edits keep the proven emitter winding, change only a constant). |
| 5 | Exact `_navmesh.hkt` filename on this install | List `<tools>\share\raw\maps\zm\` after a known-good build. |
| 6 | ent48 corridor-half oversize — deliberate decon design or convenience? | Confirm intended decon boundary vs docs/03 / user (this spec leaves brush1/2 as-is). |
| 7 | Box clearance at 96u from new north wall | In-game: boards must not clip; if tight pull box to `y=1300` (136u). |
| 8 | `radiant_modtools -ledSilent +recompute` truly non-interactive from PS? | Confirm live next build. |
| 9 | 24-alive congestion in a ~43%-smaller room (tight + sprint + code_red + 4p) | First-playtest gate (locked: geometry-only first, no `zombie_ai_limit` change yet). |
| 10 | ~~GSC hardcoded market coords assuming old west face?~~ **RESOLVED 2026-06-15** | Grepped GSC for `-2481/-2461/-2181/-1881` + `market_zone`: **zero literal market coords**. `market_zone` appears only by NAME (decon eligible-list `_acc_decontamination.gsc:109`, name guard `:131`, dev friendly-name `_acc_dev.gsc:431`). The market shrink has **no GSC coupling** — fully name/volume/targetname-driven. |
