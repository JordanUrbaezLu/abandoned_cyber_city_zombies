# 48 — Abyss Descent (Made in Abyss vertical layers)

**Design pivot (user, 2026-06-21):** reframe the map around the Bus Station trench as a
*Made in Abyss / Persona*-style **descent** — the deeper you go, the harder it gets, and the
goal is to reach the bottom. **5 floors total.** The existing trench/underground = **Layer 1**;
we add **4 more identical enclosed floors** straight down below it.

See the research that gated this (engine limits, why we build down instead of moving the map up)
in the session memory `made-in-abyss-vertical-research` summary. Headline: **there is no practical
depth limit** — the engine world bound is ≥ ±65,536 (likely ±131,072), symmetric; the map currently
spans only z≈+272..−256, so downward room is effectively unlimited. The real per-layer gates are the
**LED bake**, the **out-of-playable-area monitor**, **navmesh**, and **zone wiring** — not coordinates.

## The module (identical per layer)

- **Pitch = 240u** floor-to-floor (matches the existing surface→trench gap). Walkable floors (all BUILT
  2026-06-21): **L1 (trench)** −240, **L2** −480, **L3** −720, **L4** −960, **L5 (bottom)** −1200.
- **Footprint:** the full pit box **x[−781,819] y[1723,2173]**, stacked directly under the pit.
  All inside the OOB-veto band (x[−900,900] y[−400,2900], z≤−36 → see below).
- **Headroom ≈ 224u** (floor to the ceiling above), roomier than the cramped 144u under-rooms.
- **Descent:** a **slim stairwell** (14 treads × 16u + a final 16u, = 240u; 16/16 stock pitch so the
  navmesh links it) in a **center well whose stairs run along the WIDE (X) axis** and **step off the
  bottom into open interior floor** (never ending at a wall). **NOT a full-span cut** — see below.

## Why it's bake- and collision-safe (do not "clean up")

Generator: **`tools/gen_abyss_layer.js`** (re-runnable, idempotent — strips its own `-ACA2-` marked
brushes/lights + `// ACC ABYSS` tag comments; re-carves the pit floor only if still whole).

1. **Winding:** every brush uses the EXACT `box()` six-plane *filler-winding* + hex GUID proven to
   bake (copied verbatim from `gen_corp_trench.js`). Real-corner windings + malformed GUIDs crash the
   lightmapper at `brush.cpp:1860` (memory `led-relight-dead-end-enclosed-geometry`). **Never** rewrite
   the winding to "real" corners.
2. **Every descent well is a SLIM center strip; stairs run along the WIDE (X) axis and EXIT into open
   interior floor.** The well is `x[−112,112]` (224u = the 14-step run) × 128u deep, against the SOUTH
   wall (`XS`) or NORTH wall (`XN`). The stairs march **west→east**: you enter from the west open edge
   (high) and step off the bottom at **x≈+112 — interior, ~700u from any wall** — so zombies disperse
   instead of jamming a corner. The floor carves into **west chunk** (`x[−781,−112]`, full depth) +
   **east chunk** (`x[112,819]`, full depth) + a **bridge** on the well's far long side, staying **one
   connected surface** (West–Bridge–East). On L1 (the pit) the west/east chunks also carry the existing
   trench stairs (far west `x[−761,−665]` / east `x[703,799]`), untouched; the center well is ~600u clear.
   - **Wells ALTERNATE S/N** (D1 XS, D2 XN, D3 XS, D4 XN) so a floor's down-well is never where the
     stairs from above land.
   - **Dead ends to NOT repeat (all user-caught 2026-06-21):** (a) a full-depth central well **bisected**
     the trench; (b) an SE-**corner** well merged with the existing east trench stair = **navmesh break**;
     (c) corner / short-axis (Y) wells ended the stairs **jammed against the next layer's wall** = zombies
     stuck; (d) the centered D1 well sat in front of the **centered overclock-room door** (south
     under-room) so zombies couldn't reach it = **player invincible** there. The wide-axis center well
     fixes (a)–(c); (d) was fixed by moving the **south under-room door WEST** to `x[−192,−112]` (clear of
     the well, on the solid west chunk) — see `acc_door_under_plaza` in the .map. **Keep the D1 well
     centered/clear of both under-room doors.**
   - **T-junctions** are same-plane (cod2map fixes them), NOT the thin-lip *different-z* cull that caused
     the under-room fall-through (memory `single-slab-floor-over-room`); all floor pieces share one z-extent.
3. **Stairs are SLIM** (~108u, like the ~96u trench stairs), **not the full trench length** — 14 treads.
4. **Each generated layer's floor is ONE slab** split only around its own down-well; its ceiling is the
   floor above, open only at that well.

## Wiring — FREE for every layer (no GSC change)

The stock out-of-playable-area monitor hard-kills any player whose feet are below every enabled
`player_volume` (the Samantha-laugh death; memory `sunken-floor-oob-kill`). The trench already vetoes
this via `level.player_out_of_playable_area_monitor_callback = acc_trench_oob_allow`
(`_acc_bus_trench.gsc`), which returns false for `player_in_underground()` = **z≤−36 AND x[−900,900]
AND y[−400,2900]**. Every abyss layer is below −36 inside that XY band, so **standing on any floor is
auto-protected — no `ACC_UNDER_Z` change, no new zones, no new callback.** (Do NOT *lower* `ACC_UNDER_Z`
— that would strand the shallow layers.) Zombies follow players down once cod2map regenerates the
navmesh over the 16/16 stairs. Programmatic trench spawning already keys off `player_in_underground`,
so the trench effects (−20% slow, fall-tax, AI-cap bump, danger HUD) apply uniformly to every layer —
a good base for "deeper = harder" escalation later.

## Build discipline (per layer, MANDATORY)

One layer at a time. After each: full build **WITH the LED bake** (`tools/build_map.ps1`, never
`-SkipLED`; or fast gate `tools/_bake_test.ps1 <map>` → BAKED/CRASHED). If it crashes (`brush.cpp:1860`)
or the lightmap atlas over-budgets, **revert that layer** before continuing — so we always know which
layer broke it. cod2map regenerates the navmesh (cwd=bin, handled by build_map). Verify a fresh `.ff`.

## Status

- **ALL 5 FLOORS BUILT 2026-06-21** (L1 pit −240 → L2 −480 → L3 −720 → L4 −960 → L5 −1200).
  `gen_abyss_layer.js` is a multi-layer generator: one carved pit floor + four generated rooms, joined by
  four slim **wide-axis (X-running) center stairwells** that step off the bottom into open interior floor
  (never a wall), alternating south/north (D1 XS, D2 XN, D3 XS, D4 XN) so a floor's down-well is never
  where the stairs from above land. Every floor stays a connected surface (West–Bridge–East, never
  bisected); each room has 6 always-dim lights. Full build **OK** (fresh .ff 36.02 MB, navmesh
  regenerated). Deployed.
  **Awaiting in-game walk + zombie-path test** — descend to L5; confirm no fall-through, no OOB death,
  lights at every depth, the trench paths normally up top, and **zombies disperse off each stair bottom**.
  - *History (all user-caught 2026-06-21):* descent placement iterated 4×: (1) full-depth central well
    **bisected** the trench; (2) SE-**corner** well merged with the existing east trench stair =
    **navmesh break**; (3) center-south but **short-axis (Y) stairs ended jammed at the next wall** =
    zombies stuck; (4) FIX = **wide-axis (X) center stairs** exiting into open interior floor.
- **Revert/re-apply** stay in the generator: `node tools/gen_abyss_layer.js --revert` (strip all +
  restore the original pit floor), `node tools/gen_abyss_layer.js [--upto N]` (re-apply; `--upto` for
  incremental bake-gating). git can't be used — the .map had other uncommitted WIP.
- **Not yet done (content, deferred):** floors are identical greybox shells for now (per the user
  "identical for now"). Per-layer escalation, unique rooms, props, and the Exo-gated descent flavor come
  later. The Exo Suit / layered-slow system (`_acc_exo.gsc`, docs/47) already reads these z-levels.
