# 30 — Abyss Descent (Made in Abyss vertical layers)

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
   - **ANTI-CAMP DRAIN on the 2x-jump bridge (user 2026-06-25; RETARGETED 2026-06-26):** the camp spot is the
     **elevated "2x-jump-only" corp trench BRIDGE** (the `.map` "corp trench BRIDGE" slab / `bridge_v2.js`) —
     `x[−109,147]`, `y[1723,2173]`, **deck top `z=+58`** (the highest walkable point, **above** ground `z=0`),
     reachable only with the **double-jump item** and carrying the two power levers. Zombies can't get up there →
     a free safe-camp. `_acc_bus_trench::bridge_drain_watcher` bleeds **15% of max health / second** while a
     player **camps** there (`MOD_UNKNOWN`, so **PhD Flopper does NOT negate it**), with a red "GET OFF THE
     BRIDGE" prompt. The detection box is the bridge footprint with a Z window **above ground** (`z 20..178`)
     — the trench/abyss is all **negative z** and the bus-station ground (`z=0`) is **cut away** inside this XY
     column, so nothing is standable between the deck (`z58`) and the trench floor and the window excludes the
     whole trench by elevation. A **dwell gate** (`acc_bridge_dwell_sec`, default **2s**, resets on step-off)
     spares brief lever-flip / crossing visits; only sustained camping bleeds. Dvars
     `acc_bridge_drain_on/_pct/_sec` + `acc_bridge_dwell_sec`.
   - **THE REAL "no damage on the bridge" BUG (fixed 2026-07-05):** for a long time the drain bled *nothing* and
     ~4 attempts kept re-aiming the detection box — but the box was never the fault. The bleed passed the
     **player as its own attacker** (`self DoDamage(…, self, self, …, "MOD_UNKNOWN")`). Stock
     `Callback_PlayerDamage` (`_zm.gsc:1424-1448`) has a **self-inflicted-damage MOD whitelist**: a same-team
     player attacking itself takes **no** damage unless the MOD is GRENADE / GRENADE_SPLASH / EXPLOSIVE /
     PROJECTILE / PROJECTILE_SPLASH / BURNED / SUICIDE. `MOD_UNKNOWN` isn't on it, so every tick was silently
     dropped **before** any override ran. **Fix:** pass an **undefined attacker/inflictor** (stock idiom for
     source-less damage — `_oob.gsc:308`, `zombie_vortex.gsc:353`, and our own `_acc_decontamination.gsc:392`
     seal) so the `isPlayer(eAttacker)` block is skipped, while **keeping `MOD_UNKNOWN`** so PhD/perks still
     can't negate the camp bleed. (Earlier `z=−240`→`z=+58` retarget history preserved in the CHANGELOG.)
   - **Wells ALTERNATE S/N** (D1 XS, D2 XN, D3 XS, D4 XN) so a floor's down-well is never where the
     stairs from above land.
   - **Dead ends to NOT repeat (all user-caught 2026-06-21):** (a) a full-depth central well **bisected**
     the trench; (b) an SE-**corner** well merged with the existing east trench stair = **navmesh break**;
     (c) corner / short-axis (Y) wells ended the stairs **jammed against the next layer's wall** = zombies
     stuck; (d) the centered D1 well sat in front of the **centered overclock-room door** (south
     under-room) so zombies couldn't reach it = **player invincible** there. The wide-axis center well
     fixes (a)–(c); (d) was first fixed by moving the **south under-room door** off the centered well, then
     (user 2026-06-24) moved again to the **EAST** doorway `x[112,192]` because the west position `x[−192,−112]`
     sat right on the **abyss-L2 (D1) well buy trigger** at `(−136,1787)` — players kept mis-buying the wrong
     one. East is clear of both the well AND the D1 trigger (slide flipped to `-80` west); see
     `acc_door_under_plaza` in the .map. **Keep the D1 well centered/clear of both under-room doors.**
   - **T-junctions** are same-plane (cod2map fixes them), NOT the thin-lip *different-z* cull that caused
     the under-room fall-through (memory `single-slab-floor-over-room`); all floor pieces share one z-extent.
3. **Stairs are SLIM** (~108u, like the ~96u trench stairs), **not the full trench length** — 14 treads.
4. **Each generated layer's floor is ONE slab** split only around its own down-well; its ceiling is the
   floor above, open only at that well.
5. **Each stairwell is a fully ENCLOSED "door down"** (`emitWellWalls`, user 2026-06-22). The stairs run W→E
   inside an opening cut in the layer floor. Three non-entry sides are walled **both below the floor** (so a
   zombie on the treads can't fall out the side) **and as a 128u jump-proof RAILING above the floor** (so
   nothing can drop in from this layer's floor): **SOUTH + NORTH** = full wall `fz..(cz+128)`; **EAST** (the
   exit side) = railing **above the floor only** (`cz..cz+128`) because the stairs step off the **bottom**
   eastward onto the next layer (that must stay open). The **WEST stair entry stays open** — the only way down
   is to walk the stairs from the west. ⚠ A first pass walled only *below* the floor (`fz..cz`) and you could
   still **jump in from a side ledge** (it didn't stop the drop) — the **above-floor railing is the actual
   fix**. Was the "zombies path over and get stuck / you can still jump off the ledge" bug. 12 walls (3×4).

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

- **ALL 5 FLOORS LIVE** (L1 pit −240 → L2 −480 → L3 −720 → L4 −960 → L5 −1200; first built 2026-06-21).
  `gen_abyss_layer.js` is a multi-layer generator: one carved pit floor + four generated rooms, joined by
  four slim **wide-axis (X-running) center stairwells** that step off the bottom into open interior floor
  (never a wall), alternating south/north (D1 XS, D2 XN, D3 XS, D4 XN) so a floor's down-well is never
  where the stairs from above land. Every floor stays a connected surface (West–Bridge–East, never
  bisected); each room bakes pitch black (`lightsForLayer=0`). Builds clean **with the LED bake** (fresh `.ff` + regenerated
  navmesh) and is deployed. The whole **Paradise finale (below) is built on top of the descent**, so L5 is
  reached in play every run. **Regression-watch on any geometry change:** descend to L5 and confirm no
  fall-through, no OOB death, lights at every depth, the trench paths normally up top, and zombies disperse
  off each stair bottom. (The 4× descent-placement dead-ends are catalogued in "Why it's bake-safe" §2 above.)
- **Revert/re-apply** stay in the generator: `node tools/gen_abyss_layer.js --revert` (strip all +
  restore the original pit floor), `node tools/gen_abyss_layer.js [--upto N]` (re-apply; `--upto` for
  incremental bake-gating). git can't be used — the .map had other uncommitted WIP.
- **First content placed — descent rewards (user, 2026-06-24):** the two big shard SINKS moved DOWN so the
  abyss pays off, and the Exo Suit (what lets you walk deeper) moved UP to gate the descent:
  - **L2 (z=-480):** Cyberware Weapon **Overclock** terminal — `(-400, 1948, -480)` (WEST; now **solid** — `add_prop_clips.js`
    `overclock_terminal`, re-clipped 2026-06-27 at the L2 depth after the move off the Foundry dropped its old clip) — and,
    **opposite it across the well, an AMMO CRATE** — `(400, 1948, -480)` (EAST, user 2026-06-27). Refills your **held** weapon's reserve:
    **1000** for a base gun, **5000** if it's Pack-a-Punched, **10000 flat for a wonder weapon** regardless of PaP state
    (`acc_ammo_crate_base` / `acc_ammo_crate_pap` / `acc_ammo_crate_wonder`, wonder tier user 2026-07-08 — same WONDER
    list as the PaP price tier via `_acc_pap_levels::pap_price_bucket`; the Fire Bow is serviceable here even though its
    in-place PaP has no registered upgrade form, the ammo-less Leviathan Axe is not). A weapon with
    **no PaP version** (melee/equipment/no-pack specials) **can't be serviced** — the crate says so and charges nothing.
    The "is it PaP'd" gate is stock `is_weapon_upgraded`; "does it have a PaP version" is `level.zombie_weapons[base].upgrade`
    (same test as `_acc_weapon_variants`). `_acc_ammo_crate.gsc`, spawned by `_acc_glitch_altar::spawn_altars`. **Solid** —
    the `west_ammo_crate_model` ([West] Ammo Crates pack, ZeRoY S4 crate — remodeled 2026-07-12; NOT the Data Cache's `p7_cai_stacking_cargo_crate`), with a **30×34×26 clip** (center = spawn x−5; the model's x-bounds are off-origin) via `tools/add_prop_clips.js` `ammo_crate_l2` (which carries
    a per-prop `bot` so the clip sits on the L2 floor z=-480, not the hardcoded z=-240 pit; **needs a full LED bake**, not `-GscOnly`) (reconciled to code 2026-07-11).
  - **L3 (z=-720):** **Glitch Altar** gamble — `(-400, 1948, -720)` (now **solid** — `add_prop_clips.js` `glitch_altar_l3`,
    a 162×66×58 clip for the `p7_ram_altar` stone altar; the floating core orb stays decorative/no-clip) (reconciled to code 2026-07-11).
    Its `trigger_radius_use` is **radius 110** (bumped from the kiosk-era 72, user 2026-07-12): the 2026-07-09 remodel grew
    the base to a 162-long slab (X half-extent 81) but left the trigger at 72, so the hint couldn't reach the two X-ends
    without standing inside the slab — it only showed from one long Y-face. 110 clears the 81 half-slab + player stand-off,
    prompting from every walkable side (applies to the Paradise altar too — same `spawn_altar_at` helper).
  - **L4 (z=-960):** **AK-47 wall-buy** — `script_struct` `weapon_upgrade` `zombie_weapon_upgrade "t9_ak47"` at `(-400, 1725, -904)`
    on the south wall face (model `wpn_t9_ak47_world`, `.map` entity 9007, user 2026-06-26). An **S-tier** wall-buy dropped down the pit
    to pull players deeper; **1500 pts** from `zm_levelcommon_weapons.csv`. Survives `remove_all_wallbuys()` via its `t9_ak47` whitelist
    entry. No GSC station on L4 — the gun IS the reward.
  - **L5 (z=-1200, the bottom):** **Ammo Crate** — `(-400, 1948, -1200)` (WEST, the refill before the Paradise gate; `ammo_crate_l5`
    clip) — and **opposite it, a 2nd Cyberware Weapon Overclock** — `(400, 1948, -1200)` (EAST, user 2026-06-28). GSC-spawned and
    **solid** — its clip (`add_prop_clips.js` `overclock_l5`, `brushmodel: true`, `bot z=-1200`) sits on the L5 floor. Plus an **M60
    wall-buy** — `weapon_upgrade` `zombie_weapon_upgrade "t9_m60"` at `(-400, 1725, -1144)` on the south wall's west jamb (model
    `wpn_t9_m60_world`, `.map` entity 9009, user 2026-06-27): the S-tier bottom-floor gun right before the Paradise door, **1500 pts**,
    whitelisted past `remove_all_wallbuys()`.
  - **Foundry under-room (L1, z=-240):** **Exo Suit** station — `(-120, 1550, -240)` (WEST side of the Foundry
    under-room; the Exo station and the Neural Expansion Bay vendor sit on opposite sides the long way — Exo WEST,
    vendor EAST at `(120,1550)`; user 2026-06-28) (reconciled to code 2026-07-11).
    The room is a shallow niche whose front wall IS the trench's south wall (floors flush at z=-240) — opening its
    buyable door (`enter_under_plaza`, doorway `x[462,542]`) fuses it with the full-width pit, so it reads as huge.

  The L2 Overclock + L3 Altar sit on the **WEST floor chunk** (`x[-781,-112]`, a solid full-depth slab on every layer)
  at the layer mid (`y=1948`); the **EAST chunk** (`x=+400`, same `y=1948`) carries the **L2 ammo crate**, the **L5 Overclock**,
  while the L5 ammo crate takes the L5 WEST — both sides
  clear of the alternating center stairwells (`x[-112,112]`) and of where the stairs from above land (they step off
  east at `x≈+112`, right by the crate). The **models + use-triggers are pure GSC script spawns**
  (`_acc_glitch_altar.gsc` spawns the Altar + Overclock + ammo crate; `_acc_exo.gsc` spawns the Exo station), but their
  **collision clips are `.map` brushes** (`add_prop_clips.js`, deep props via per-prop `bot` — user 2026-06-27 "add clips
  to those"), so a clip change **needs a full LED bake**, not `-GscOnly`. ⚠ **L2..L5 bake PITCH BLACK** (`lightsForLayer=0`):
  the Altar self-glows (floating core orb = beacon), but the Overclock kiosk **and the ammo crate** do **not** — if either
  is too hard to find in-game, add a bake-gated light near it rather than re-lighting the whole abyss. **Depends on the abyss
  floors being walk/zombie-path verified** (the open item above) — if a layer turns out unreachable, its
  station is stranded.
- **Not yet done (content, deferred):** every layer now carries at least one reward (L2 Overclock + Ammo Crate,
  L3 Glitch Altar, L4 AK-47 wall-buy, L5 Ammo Crate + Overclock + M60 wall-buy), but the rooms are still shared
  greybox — **per-layer escalation and unique per-floor geometry come later.** The Exo Suit / layered-slow system
  (`_acc_exo.gsc`, docs/29) already reads these z-levels.

## The bottom now EXITS to PARADISE (user 2026-06-25)

L5's **south wall has a doorway** (`gen_abyss_layer.js`, only the bottom layer) into **"Paradise"** — the second
part of the map. Beyond it: a **long dark hallway** runs south and opens into a large **OPEN-AIR plaza** (a deep
~1000u pit, floor z=-1200, capped with the existing `sky` material so you look up at the night sky), placed south of
the surface map so the sky cap has clear void above it. Geometry: **`tools/gen_descent_hub.js`** (hallway + plaza +
the `acc_abyss_hub_door` slab). OOB-safe + trench-NEUTRAL via `acc_bus_trench::player_in_second_part` (footprint
`ACC_SP_*`). Paradise is a full second hub: GSC-spawned duplicate Glitch Altar / Overclock / Exo / perk-slot vendor /
boss-item bench + a **permanent mystery box** + a **2nd Pack-a-Punch** (`acc_glitch_altar::spawn_paradise`),
plus **all 10 perks** as `.map` entities (`tools/gen_paradise_props.js`). The four Paradise kiosks (Altar / Overclock /
Exo / perk vendor, all at z=-1200) are **solid** — `add_prop_clips.js` `paradise_*`, clipped at the Paradise floor via
per-prop `bot` (user 2026-06-27), each with its remodeled model's snug dims (altar 162×66×58, overclock 48×34×78, exo 58×52×114, perk vendor 50×44×71; the stations were remodeled 2026-07-09) (reconciled to code 2026-07-11).

**The 2nd Pack-a-Punch is a STANDALONE GSC vendor, NOT a 2nd stock machine** (`_acc_pap_levels::spawn_paradise_pap_at`,
at `(0,-1700,-1200)`). Stock supports exactly one PaP: `spawn_init` renames every `zm_pack_a_punch` zbarrier to the
shared `vending_packapunch`, then `vending_weapon_upgrade()` does a singular `GetEnt("vending_packapunch")` that
**fatals the load** with two — which is what broke the surface PaP on the earlier attempt. The standalone vendor
(`script_model` + `trigger_radius_use`, like the Paradise box) dispatches through the **same player-scoped tier path**
(`acc_do_first_pack` / `acc_do_tier_up` / `acc_pap_actionfigure`) the surface PaP uses, so the tier lives on
`player.acc_pap_tier[base]` and **never resets** between the two machines. It never carries the `zm_pack_a_punch`
targetname, so stock's singleton is untouched and the surface PaP is safe. `gen_paradise_props.js` no longer injects a
stock 2nd PaP; `acc_dedupe_pack_a_punch()` neutralizes any leftover from an older `.map`.

Its price prompt is our own nearest-player keeper (`paradise_pap_hint_loop` → `paradise_pap_hint_text`), since the stock
cost machinery doesn't apply to a custom trigger: it shows the **real next-tier charge** (`^2[cost]`) or `Pack-a-Punch - MAX`
at tier 3. Its "can this tier up" gate passes a weapon that is `pap_weapon_packable` **or** already `is_upgraded_safe` —
mirroring the surface keeper — because a bare `_up` gun (no `_acc` twin = any player without a Mega perk) is *not*
`pap_weapon_packable`: `packed_form` returns it unchanged, which previously hid the price and made `MAX` unreachable while
the Use-hold still charged tier 3 (fixed 2026-07-15).

### The descent gates are SOUL BOXES (user 2026-06-25)

The 4 abyss descent doors (`acc_abyss_door_1..4`, `_acc_abyss_doors.gsc`) **no longer cost currency** — each opens
when the team banks souls (one per kill on that door's layer). Costs are **per-layer AND scale with the live player
count** (user 2026-06-25): the **first gate** (layer 1, the trench, where everyone roams early) needs **125 souls
per player**; the **deeper gates ESCALATE per floor** (user 2026-07-12 "make it 125,50,75,100 ... factor in players
automatically"): **50 per player at L2→L3, then +25/floor → 75 at L3→L4, 100 at L4→L5**. Per-player descent totals
**125 / 50 / 75 / 100** — i.e. solo 350 to reach the bottom, ×player count in co-op (a full 4-player lobby = 500 /
200 / 300 / 400). `souls_needed(layer)` = `(base + step·max(0,layer−2)) × GetPlayers().size`, evaluated **live** so
the per-kill bank check auto-rescales on a dis/connect, and the floating hint **re-syncs to that live value whenever
the player count changes** (`soul_hint_watcher`, user 2026-06-27) so the displayed goal always matches the requirement.
Tuning dvars: `acc_soul_door_cost_first` (125/player) + `acc_soul_door_cost` (50 base) + `acc_soul_door_step` (25/floor);
dev mode is a cheap flat 10.

**The soul-box hint shows the fixed GOAL, not the live count (triggerstring-cap fix, 2026-06-25).** The first
cut of `soul_update_hint` embedded the live `door.acc_souls` counter and re-set the hint on **every** soul-banking
kill — minting a new unique `SetHintString` per soul (0..100 **per layer door**). The `triggerstring` BG-cache caps
at **250 unique strings per match** (never freed), so grinding souls underground overflowed it → the round-~18-20
CTD `BG_Cache_GetIndexInternal - Exceeded '250' items for type 'triggerstring'` (reproduced twice, both at the
soul boxes). It now builds a **constant** hint from `souls_needed()` only and is set once at trigger creation; live
progress is shown via the `IPrintLnBold` milestone every 25 souls (chat prints are not triggerstrings). General
rule: never interpolate an *unbounded*/per-kill runtime value into a `SetHintString` literal — but a **bounded** one
(player count 1–4) is fine, so the hint is re-synced **only on a player-count change** (`soul_hint_watcher`, ≤16
distinct strings total) to keep what's shown aligned with `souls_needed()` (user 2026-06-27). Only the **Paradise
gate** (`acc_abyss_hub_door`) keeps currency, **scaled by live player count** (user 2026-06-27): **solo = 50 Data
Shards + 50,000 points**, **+25 shards + 25,000 points per extra player** (2p 75/75k, 3p 100/100k, 4p 125/125k) — two
communal pools, contribute-all + all-survivors-gather to open. `hub_cost_watcher` keeps the price aligned to the live
count until the first payment locks it in (a partially-paid pool is never rescaled). Dvars `acc_hub_door_shards_solo`
(50) / `_per` (25) / `acc_hub_door_points_solo` (50000) / `_per` (25000). (Supersedes the old flat 100 / 100k, and the
even older points-only `door_cost` 2k/3k/5k/8k.)

**The gate hint shows the FIXED TOTAL, not live remaining (triggerstring-cap fix, 2026-06-25).** The engine caps the
`triggerstring` BG-cache at **250 unique strings per match**, and every distinct string passed to `SetHintString` burns
a slot permanently. The first cut of the gate hint embedded the *live remaining* points (an arbitrary "all you carry"
number) and re-set on every deposit, minting a new unique string each time until the cache overflowed mid-match
(`BG_Cache_GetIndexInternal - Exceeded '250' items for type 'triggerstring'`). It now builds from snapshotted totals
(`level.acc_hub_shards_total` / `_points_total`) so it is a **constant** string; live progress is announced via
`IPrintLnBold` (not a triggerstring). General rule: never interpolate an unbounded runtime value into a `SetHintString`
literal.

## Paradise = the FINAL ONSLAUGHT + the WIN condition (user 2026-06-25)

Paradise is the map's **climax**: surviving a scripted timed finale **WINS** — and, since 2026-07-12
(user), **winning no longer ends the run** — it REWARDS the survivors and normal play resumes on the
surface, so a Paradise win is a mid-run trophy you can build a high round on top of. Module
`_acc_paradise.gsc` (orchestrated by `acc_main`); armed by `_acc_abyss_doors` setting `level.acc_paradise_open` when
the gate opens, and it starts the instant the team drops into the plaza. The sequence (all `acc_paradise_*` live dvars):

| Phase | Default | What happens |
|---|---|---|
| **1 — CALM** | `acc_paradise_calm_sec` 60 | One-shot **victory fanfare** (`acc_paradise_calm`, the Mario stage-win jingle), clear air, a **very light trickle** (`acc_paradise_trickle_sec` 12). A fakeout. |
| **2 — OMEN** | instant | **Fog rolls back in** (`acc_atmosphere::paradise_fog_on` → re-runs the map's `set_fog_from_dvars` haze every tick, overriding the power-on settle) + a **"fetch me their souls" omen cue** — a **CUSTOM** alias `acc_paradise_omen` (`play_fetch_souls` → `PlayLocalSound`, user 2026-06-25). It replaced the stock dog-round announcer `zmb_dog_round_start`, which was SILENT here because that alias lives in a dog-round sound bank this map never loads. |
| **3 — DREAD** | `acc_paradise_dread_sec` 10 | Fog closing in, trickle continues. |
| **4 — BATTLE** | `acc_paradise_survive_sec` 225 (**3:45**, user 2026-06-27) | Arena **seals** (`acc_paradise_seal`); the **"115" anthem** (`acc_paradise_music`, max volume — wav +10% louder 2026-07-12 via `tools/amplify_wav.js --loudness-db 0.83`) plays; the bosses arrive on a **STAGED roster** (user 2026-07-12 nerf — was 1 of each from the opening bell): **3:45 Trench Warden (Brutus) + Phantom → 2:45 +Rogue Protector → 1:45 +Panzer → 0:45 +Avogadro** (unlock minutes `acc_paradise_rp/panzer/avo_unlock_min` on `level.acc_paradise_battle_minute`; the **Apothicon Fury is DROPPED from the wave** — `maybe_spawn_fury` kept for a re-add) — + the **x4 horde** (regular surge + shield/glitch gauntlet, `acc_paradise_spawn_mult` 4). **Every minute, in lockstep** (`escalation_loop`): the **boss wave tops the UNLOCKED roster back up to 1 of each** (concurrent cap **1 each**: `acc_paradise_brutus_max`/`_phantom_max`/`_rp_max`/`_avo_max`/`_panzer_max`, so a killed boss is replaced the next minute), the **wave-baseline horde trench-buff** steps up a layer (**L2** min 0–1 → **L3** → **L4** → **L5** final wave; `_acc_zombie_speed::paradise_buff_layer` reads `level.acc_paradise_horde_layer` as the floor), and a **UI alert** fires ("The horde is getting stronger", or **"You will never escape!"** on the L5 step at 3:00). **Four waves**: L2/L3/L4 are **60s** each, the **final L5 wave is 45s** (3:00 → 3:45). **ON TOP of the wave, every zombie individually ages +1 tier per 30s it stays ALIVE** (`acc_paradise_age_step_sec` 30, 0 = ramp off, capped at `acc_paradise_buff_max` L5 — the per-zombie anti-kite ramp restored 2026-07-09; stamped + computed in `paradise_buff_layer`, effective layer = max(wave, birth wave + age steps)): kiting instead of killing outscales the wave clock 2:1 — a wave-1 zombie a runner never kills is L5 by 1:30. **NO power-up drops** the whole battle (`block_powerup_drop` on `level.custom_zombie_powerup_drop`). A **countdown timer HUD**; **boss HUD + boss music suppressed** (`level.acc_paradise_onslaught`). |
| **WIN (run continues, user 2026-07-12)** | reward window `acc_paradise_reward_sec` 60 | Latch `level.acc_paradise_won` → banner + fanfare → **lift the fog** → **purge horde** → **reward every survivor**: **all perks** (`level.acc_perk_door_specs` via `zm_perks::give_perk`) + **enhanced Jug = 350 HP** (`n_player_health_boost` 100 + `perk_set_max_health_if_jugg`, survives downs; `acc_paradise_hp_boost`) + a **gold health bar at full HP** (`_acc_health_bars::hp_bar_color`, gated on `player.acc_paradise_reward`) → **drop the 5 wonder weapons** as hold-`[+activate]` plaza-floor pickups for the window (`acc_paradise_wonder_loot`; 2026-07-12 fix: a grabbed pickup now actually vanishes and un-grabbed ones clear at window close — both teardown paths used to notify their own endon and die before their deletes ran) → the **win banner fades out** ~5s into the window (`acc_paradise_win_banner_sec`; it used to stay on screen for the rest of the run) → **teleport survivors to the surface** `(-291,-316,32)` (fan-out ring, OOB 12s grace = no down) → `flag::set("spawn_zombies")` **resumes stock rounds** + `unseal_arena()` reopens the gate (`ConnectPaths`). **NO `end_game`** — the run ends later on death/quit, and the recorder tags that entry **(Paradise Winner)** (docs/40) via the latched flag. **LOSE** = team wipe ends the match normally (stock game-over). |

**Boss-HUD / music suppression**: `_acc_health_bars::boss_bar_listener`/`boss_bar_track` skip + self-destroy bars
while `level.acc_paradise_onslaught`; `_acc_boss::boss_music` returns early on the same flag (the "115" anthem owns
the audio). **Paradise risers**: 12 floor points (`get_paradise_risers`, was 6). **Brutus in paradise**:
`_acc_boss_brutus::spawn_one_paradise` + `paradise_warden_think` (the trench-warden twin, paradise-tethered).

## Enhancement — the "Infected Descent" (LOCKED plan 2026-07-12; Phase 0 BUILT)

The per-layer escalation + unique per-floor geometry deferred above is now a **locked, phased plan**
(user choices 2026-07-12: **Abyssal Horror** direction, 4 distinct themed floors, **ramp-in** difficulty,
mezzanines): the shaft is *infected* — **L2 Faltering Grid → L3 Corruption Bloom → L4 Specimen Vault →
L5 The Maw** — every floor gets a verified-in-library T7 prop palette (9 carve batches), a twist
(L2/L3 **spatial only**: rolling brownout / spore-fog bursts; L4/L5 **damaging**: pod-rupture vents /
a south-sweeping corrosive tide that always leaves a safe lane at the Paradise mouth — all
`DoDamage(undefined attacker, MOD_UNKNOWN)`, **never a move-slow** on top of the Exo layer slow, PhD
bypassed by default via `acc_abyss_l4/l5_phd_immune 0`), and two **mezzanine decks on the damaging
floors only** (their hazard is the anti-camp): the **L4 "Gantry"** (N wall, floor+112, 7-tread stair —
universal high ground) and the **L5 "Overlook"** (W wall, floor+80, double-jump perch, Phase 3).
**Footprint expansion = NO-GO** (verified: Y is welded to the Bus-Station surface geometry; an X widen
strands the un-owned base-map pit end walls → unsealed lip + bake-crash risk). Construction rule:
decor = runtime `script_model` (bake-neutral), collision/decks = `acc_clip_*` `script_brushmodel`
(LED-exempt, auto-navmesh-cut by the prefix sweep), lights = bake-gated `lightEntity()` only.
Full plan: memory `abyss-horror-enhancement-plan` + the plan artifact linked there.

- **Phase 0 (BUILT 2026-07-12, awaiting the in-game readability verdict):** the L4 **Gantry**
  (`tools/oneshots/gen_abyss_mezzanine.js`, marker `-ACB5-`, idempotent + `--revert`; deck
  x[140,780] y[2013,2173] top z=-848, 3 rails, stair x[140,220] from y=1901, all visible
  `script_brushmodel`s in `t7_metal_diamond_plate_worn_wet` + **2 baked deck lights** at 0.15) and
  the two probe props via NEW **`_acc_abyss_deco.gsc`** (kill-switch `acc_abyss_deco`; **since
  2026-07-19 the 100 static abyss props are baked into the `.map` as `misc_model` statics — G_Spawn
  entity-cap hotfix, see docs/02 — and the GSC spawn gate defaults 0; `floor_lights_on`/`spawn_lamp`
  stay runtime**): the carved
  **LARGE specimen tank** `p7_zm_isl_specimen_container_lg` (install
  `source_data\acc_t7_props_deco.gdt`, manifest "deco slice"; 63x65x120, glass + body-silhouette,
  **no `_col`** — clip in Phase 3; ⚠ the *mutant* vats are SKINNED — junk `j_` joints → linker
  convert-fail as rigid carves, static variants only, and strip any stock-named material like
  `global_invisible` the carve tool re-authors) at (-400,1948) and a **cryo pod** (400,1948,+63
  mid-body lift). **THE TEST:** at L4 with
  power on — does the vat read at all / do the lights carry the deck? If dark: intensity → 0.25
  re-bake, else swap the hero to a proven emissive (boils panel / runes / red cage light).
  Zombies **cannot** path onto the deck (brushmodels are off-navmesh) — its anti-camp vent hazard
  is Phase 5, so the Gantry is a *known temporary free camp* until then. **(SUPERSEDED 2026-07-13 —
  see Phase 8: the Gantry deck+stairs were rebuilt as WORLDSPAWN geometry so zombies path up; it is
  no longer a brushmodel / no longer a free camp.)**
- **Phase 1 (DONE 2026-07-12, validation link pending):** all 9 batches carved — **171 xmodels /
  317 materials / 130 shipped images** in the regenerated install `acc_t7_props_deco.gdt`, gdtdb
  green. Per-model joint inspection first (the skinned trap): 2 dropped (`pustule_01`,
  `rune_portal` — jointed at every LOD), 3 LOD1-laddered (`snake_throne_arch` + 2 scaffold
  crossbeams, ladders capped at their real deepest LOD); the lotus3 **hung androids inspect
  static** (carvable). Dedupe lesson: gdtdb collides vs ALL install GDTs incl. `texture_assets`
  and derived `"name" [ "parent" ]` entries — global-sweep the carve GDT (34 stripped; the zod
  glyph already ships as its own standalone install GDT from a parallel session). The next
  `-GscOnly` link is the conversion oracle for the 171. Manifest deco Paths += asylum /
  cosmodrome / castle / lotus3.
- **Phases 2-5 (BUILT 2026-07-12 — "finish all floors then I'll test", one build):**
  - **Phase 2 deco:** ~105 placements across all four floors in `_acc_abyss_deco.gsc`
    (`spawn_l2..l5`; origins computed from bounds-measured dims — standing z = floor+lift,
    hanging z = ceiling−(H−lift); 88 zone `xmodel,` lines). Oversize set-pieces CUT by
    measurement (apothicon statue 2130×1085×1001 / its head / apoth shells / giant chamber
    tubes = arena-scale); the Maw hero = the 416-wide snake hatchery. TWO placements
    RELOCATED off the Overlook footprint they punched through (hatchery −600→−380 N wall;
    crystal monolith −700,1870→−540,1790).
    - **ZONE TRIM (2026-07-16, build-size audit):** the Phase-2 block zoned the whole carve
      library up front, but `spawn_l2..l5()` only actually place **46** of the **85** models —
      the other **39** (rune/membrane/boils/signage variant-siblings, the CUT snake hero/teeth/
      wings, and the fusebox/zapper/light-panel cluster dropped from the L2 first draft) packed
      dead geometry (+ any unshared textures) for nothing and rendered nothing. They were **removed
      from `zone_source`** (154 → 115 `xmodel,` lines) after verifying each has zero active spawn/
      placement anywhere, then confirmed clean with a `-GscOnly` rebuild. **Measured saving was small**
      — `.ff` 122.9 → 118.7 MB (their geometry/LOD), `.xpak` **flat** (the trimmed props are
      variant-siblings that share streamed textures with kept props, so little unique image data
      dropped). So the trim is a **correctness / manifest-hygiene** win, not a size win — the real
      *4.1 → 7.1 GB* scare was a stale `*~lk` lock file inflating the build folder (see CHANGELOG
      2026-07-16 + docs/34); this trim is the small, tidy other half. The **carve GDT is untouched**: to place any trimmed model in a
      later phase, add its `spawn_prop()` call **and** re-add its `xmodel,` zone line (git has
      the former full list). Rule going forward: **zone a deco model only when you place it.**
  - **Phase 3 obstacles + Overlook:** 9 mid-floor pillar obstacles (L2 2× powerbreaker
    slabs / L3 2-root+rock slalom / L4 2× containment cylinders / L5 crystal monolith +
    jade snake fountain) + hero clips for the lg tank + hatchery — 11 new
    `acc_clip_pillar_*`/`deco_*` brushmodels in `add_prop_clips.js` (auto navmesh-cut).
    **L5 "Overlook"** added to `gen_abyss_mezzanine.js`: W-wall deck x[−781,−621]
    y[1783,2113] top z=−1120 (floor+80), east interior rail, floor+40 step-hop at the SE
    corner (double-jump access, heights tunable), 2 dim deck lights (0.10).
  - **Phase 4 lights:** `gen_abyss_layer.js::lightsForLayer` flipped `0` →
    `Math.max(0,5−n)` (L2:3 / L3:2 / L4:1 / **L5:0 by design** — the Maw's glow budget is
    its runes/beacon/deck lights) + the generator's oneshots-move path bug fixed (`'..'`
    one short). Full abyss regen: 105 `-ACA2-` brushes + 6 lights, all mezz/clip markers
    survived.
  - **Phase 5 hazards:** NEW `_acc_abyss_hazards.gsc` (ramp-in: **L2 rolling brownout** =
    rumble + conduit haze swells, spatial only — a true baked-light dim is impossible at
    runtime (lighting states are map-global), so the haze IS the obscurant, csc
    dynamic-light flicker deferred; **L3 spore bursts** = round-robin pod tell → lingering
    fog-wall clouds, spatial only; **L4 pod-rupture vents** = 7 anchors incl. one ON the
    Gantry deck (its anti-camp), 1.5s steam tell → 2.5s vent, ~18/0.5s tick in a 96u
    Distance2D+z-band ring; **L5 corrosive tide** = 2s rumble+haze tell → a 4-column haze
    line sweeping N→S at 90u/s (under sprint), ~22/0.5s tick while north of it, ALWAYS
    stops at y=1880 = a permanent safe lane at the Paradise mouth, sweeps the Overlook's
    Y band = the perch's anti-camp). **Proven-FX-only** (`acc_haze`/`acc_steam` +
    `Earthquake` — zero new FX registrations); damage idiom `DoDamage(amt, origin,
    undefined, undefined, 0, "MOD_UNKNOWN")` (PhD-bypass by design,
    `acc_abyss_l4/l5_phd_immune` 0); downed/spectating players never damaged; dev runs
    honor `acc_abyss_godsafe` (visuals still fire). NO hazard applies a move-slow (the
    Exo/trench slow already stacks). Master kill `acc_abyss_hazards`; all cadences/damage
    live-dvar-tunable (`acc_abyss_l2_brownout_* / l3_spore_* / l4_vent_* / l5_tide_*`).
  - Gates: xref lint green; fast `_bake_test` **BAKED** (LED 64.5s) with the Overlook +
    clips + lights in; full build → the user's single all-floors test run.
- **Phase 6 (test-feedback pass, 2026-07-13):** per-floor playtest verdicts folded in:
  - **Soul-defeat lights** — the vision-grade "tint" the user rejected was pulled
    (`acc_abyss_lit` default `0`); floor lights now = REAL FX omnis spawned by
    `floor_lights_on()` when a floor's soul door fills. FX walked up from a dim/culled
    lantern → `fx_light_zm_fire_omni_12` → **`fx_light_candle_ramses`** (clean white
    `PRIMARY_OMNI`, intensity 5000 / radius 200, `PRIMARY_NOSHADOWMAP` = fills the bay
    evenly and is cheaper than a shadowed omni). Lamp count `6→10` (added S/N depth rows)
    for the "a bit brighter" ask. `accPerkGlow` index **15** = the bright lamp.
  - **L4/L5 clip audit** (user "models on the stairs, invisible clips in many places"):
    deterministic cross-check of every L4/L5 clip vs the descent-well / stair-landing / door
    coords. `l4_vessel_s` moved `300→500` (was in the D3 landing); `l5_column` moved
    `240→470` off the D4 landing + clip shrunk `106×166 → 96×96` (dropped the sparse
    snake-tail half); **`deco_l5_hatchery` 416-wide clip REMOVED** (wall-flush hero = a huge
    invisible wall; the N wall already blocks). Re-audit: zero clips in any stair/well/door
    landing.
  - **Publish build:** `acc_dev` + `acc_god` defaults reverted `1→0` (ship-safe); full build
    (cod2map + LED bake + linker) green. Still gated on the CREDITS.md IP/music review before
    a **Public** listing.
  - **L4 Gantry BALCONY GIFT** (user 2026-07-13): the raised deck is player-only high ground
    (navmesh excludes it), so it now hands out **one random Implant/boss-item every game** as a
    climb-up reward — `_acc_boss_items::spawn_abyss_balcony_gift` seats a PERSISTENT pickup center-
    east of the deck at `(600,2093,-848)` (floor-snapped onto the deck brushmodel). "Persistent" =
    `spawn_pickup(...,true)` skips the 60s `watch_lifetime`, so it waits on the deck until grabbed
    (free-for-all, one per game, no respawn). Kill switch `acc_abyss_balcony_gift`.
- **Phase 8 (playtest bug pass, 2026-07-13):** three abyss playtest bugs folded in (full LED bake
  re-verified **BAKED** 61.5s + fresh `.ff`):
  - **L4 Gantry rebuilt as WORLDSPAWN** (user chose "real geometry" over a camp-drain): the deck +
    7 stairs + 3 rails are now `-ACB5-` box() brushes injected INSIDE the worldspawn entity by
    `gen_abyss_mezzanine.js` (no longer `script_brushmodel` entities), so cod2map generates navmesh
    over the 16/16 stairs + deck and **zombies path up to threaten balcony campers** (the gift still
    seats at `(600,2093,-848)`). Proves **deep worldspawn is NOT universally bake-fatal** — a SOLID
    staircase+platform (no enclosed void / dead-end pocket) at z=-848 baked fine; the `brush.cpp:1860`
    crash is specifically enclosed-void/dead-end geometry, not depth per se. Revert: `--revert`.
    ⚠ Zombie-pathing-up still needs an in-game confirmation.
  - **L5 Overlook REMOVED** (user: the west-wall perch near the L5 ammo crate was a zombie-proof
    safe camp with no reward). Deck + rail + step deleted from `gen_abyss_mezzanine.js`; the tide's
    safe-lane-vs-perch overlap is moot now. (The deco keep-clear + hazard comments still name it as a
    spatial landmark — harmless; that W-wall band is just open floor now.)
  - **L5 snake hatchery hero REMOVED** (user: "random model with no clip on the stairs to the 5th
    floor"): it sat at the top of the D4 descent (`(-380,2140,-977)`, y inside the well band) with
    its clip already stripped in Phase 6, so it floated walk-through beside the stairs. Dropped from
    `_acc_abyss_deco::spawn_l5`.

- **Phase 7 (pending):** further balance-pass the hazard dvars, decide `acc_sparks` + csc
  light-flicker polish.
- **M6 horror-organics layer (BUILT 2026-07-18, visual-sweep final batch):** the infection finally
  gets its ORGANIC read, per-floor, additive-only — **38 new props (trench 7 / L2 6 / L3 10 / L4 8 /
  L5 7), 14 new `acc_clip_m6_*` brushmodel FLAT clips** (never gabled — trench rule), **ZERO light
  entities** (pitch-black stands; baked abyss lights = the bisect-proven CTD — the ONLY glow is
  model-own emissive material). Sources: the **moicesttom ghost pack** (`custom_ghost_*`,
  `_custom\_moicesttom\gdt\gdt_ghost\alien_ghost.gdt` — the 3 `armory_alien_*` models had shipped
  **bins with no GDT entries**, added as derived `[ "custom_ghost_alien_weeds01" ]` entries + gdtdb
  update; their materials were already registered), BO4 White tunnel/mannequin/spawner-hole/bloody
  door, BO4 office pig-slab/meat-hooks, BO6 moss. Per floor: **trench** = 2 tunnel ribs framing the
  N-room door + the 420×226 collapsed-tunnel wreck against the S wall E half (clip `m6_tr_wreck`,
  lanes verified vs both stair channels/caches/D1 well) + moss; **L2** = rib + flush blast door +
  moss (the grid, breached); **L3** = wall tentacle mass wrapping the SW spore rock + ceiling
  tentacle splat + a 3-egg nest mound (W bay N) + alien grass/weeds (the bloom); **L4** = 2
  **ceiling GLO-SPROUTS** (`custom_ghost_alien_plant_ceil`, roll 180) in clear view from the Gantry
  — **this is the locked plan's Phase-0 emissive proof piece**: its `mtl_dct_alien_plant_glo_sprout`
  is `lit_emissive_advanced` with a dedicated `_em` map, the same emissive class as the PROVEN L3
  boils panel — plus butcher slab + severed mannequin head + specimen mannequin + 2 meat hooks on
  the Gantry face + a bloody door (the experiments); **L5** = the **flesh hive** (125×129×120 Maw
  heart, N-center) + dead queen + 2 dead brutes (corpse STATUES — static `script_model`s, never AI)
  + 2 ceiling sprouts + a flat walkable spawner hole (the infection's source). Layout generated +
  keep-clear-validated by scratch `gen_m6_layout.js` (stairwell bands, stair landings, station
  kiosks r110, L4 Gantry, L5 Paradise door + tide safe lane, M60/AK wallbuys). Full build green:
  LED bake passed, every M6 xmodel + the sprout material ff_grep-verified in the fresh `.ff`.

**Paradise boss audit fixes (user 2026-07-09):** the **Phantom** and the **Glitch Stalker** never landed a melee
swing in the arena — both are stock-zombie-BT hosts that spawn TOPSIDE and blink to players, so warping below
every `player_volume` (arena z=-1200) left `completed_emerging_into_playable_area` unset and the stock melee
branch locked (the same trench lockout `tag_trench_zombie` fixes; they chased + stood in your face swinging
nothing). Both now thread `acc_bus_trench::force_playable_emergence()` at spawn (no-op topside). The Avogadro
and Rogue Protector are unaffected (script-driven zap/bullet damage — by design chip+stun pressure, low per-hit
numbers). **In-arena Ammo Crate** (user 2026-07-09): a third `_acc_ammo_crate` crate at `(850,-1650,-1200)` (east
wall, between the Overclock and the Neural Bay) so the onslaught has a refill without leaving the fight.

**Parity rule (user 2026-07-09): the bosses behave EXACTLY as in normal rounds.** No boss damage number reads
the onslaught flag anywhere. The **Avogadro keeps hacking in the arena** — his seek now targets the arena's own
duplicate perk row / PaP via a **paradise twin cache** + dimension-aware `target_origin()` (the old
pause-hacking-in-paradise fallback is gone; `do_hack`/`perk_pause` were always per-specialty across both
dimensions). The **Rogue Protector's death reward is now suppressed** in the arena like every other boss.
The **Avogadro pack's `death_rewards`** (1000 pts + a forced `full_ammo`) was the **last** unguarded exception —
guarded 2026-07-15 (review): `specific_powerup_drop` spawns directly and never consults
`level.custom_zombie_powerup_drop`, so `block_powerup_drop` could not stop it and a wave-Avogadro kill handed out
a free Max Ammo mid-finale. Every forced drop now carries the `level.acc_paradise_onslaught` guard. (Reward-path
only — the parity rule above is intact: no *damage* number reads the flag.) Deliberate finale-only deltas that remain
(presentation/economy, not behavior): boss HUD + music suppressed, all drops/power-ups/shards blocked, and the
paradise Brutus rides the same trench-warden tether he uses topside.

**M6 Paradise dressing (2026-07-18, visual-sweep final batch):** the reward plaza gets its
**synthwave-oasis read** — **7 MWIII Vertigo palms** (`jup_vertigo_palm_01/_02`, 552/519 tall — the
sky cap at −200 gives 1000u of headroom) ringing the arena **edges only** (4 corners + W/E mid-wall +
S center), each with a **TRUNK-ONLY** flat brushmodel clip (`m6_pd_palm1-7` — canopies ~300u up stay
overhead), + 7 walk-through lush accents (5 already-zoned BO6 overgrowth grass patches at the palm
bases + 2 cast-iron ferns flanking the hall mouth). Keep-clears validated by scratch
`gen_m6_layout.js`: the arena floor stays OPEN for the 4-boss onslaught — all **12 risers** (r45),
every station kiosk (r110), the **PaP + wonder-loot ring** (r200), the box, the 3 bench pads, all 10
perk machines (r60) and the hall mouth. **VISTA VERDICT — skyline pieces SKIPPED:** the brief's
pyramid/towers/ziggurat were bounds-measured at **3674×3674×2434 / 4640×3264×11072 / 6656×6144×1536**
— bigger than the whole 2000×1600 arena — and the `gen_descent_hub.js` sky cap ends AT the arena
walls (no out-of-bounds shelf exists; outside the walls is unrendered void), so there is nowhere a
vista piece could stand OR be seen. `_acc_surface_deco::spawn_paradise_m6`.

**Engine guard rails (tune down if unstable in coop):** concurrent caps on Brutus/Phantom (`_brutus_max`/
`_phantom_max` 1, was 4), shield+glitch specials (`acc_paradise_special_max` 12, was 8), and an extra AI-cap bump
(`acc_paradise_ai_bonus` 12, stacks on the trench +14). **Audio**: `sound_assets/acc/music/115.wav` +
`paradise_calm.wav` + `sound_assets/acc/fx/paradise_omen.wav` (the Phase-2 omen cue; all 48k/16-bit) + a **game-closed sound build**; both tracks are **copyrighted — test-only, NOT for
the public Workshop** (CREDITS.md IP review). **Real wavs in place since 2026-07-09** — they are gitignored
(licensing) so they never migrated to the new box, which had been silently shipping placeholder copies (the Brutus
track as "115", the nuke SFX as the "win fanfare"); resample any re-download with `tools/resample48k.js`. **Regression-watch in-game:** fog actually renders at the
paradise depth (z≈−1200, below the haze base height); and — TOP watch for the 2026-07-12 win-continues change —
that after a win **stock rounds resume cleanly on the surface** (the finale cleared `spawn_zombies` + froze the
round; `win()` must re-`flag::set` it and the teleport must land everyone up top without an OOB down) **and that the
finale's AI-cap bump actually unwinds** — `level.zombie_ai_limit` must be back to the base **50** (`ACC_AI_LIMIT`) once
the trench's +14 also releases, not 62. `ai_pressure()` therefore does **not** `endon("acc_paradise_end")`: `win()` fires
that notify mid-battle, which would kill the loop before it gives the +12 back, and since the run *continues* the leak
would be permanent (a 2026-07-15 review fix; the unwind now rides `win()` clearing `acc_paradise_onslaught`). (The multi-boss
arena was stabilised by the 2026-07-09 boss audit above — Phantom/Glitch melee lockout fixed via
`force_playable_emergence`, and concurrent caps cut to 1-of-each.)
