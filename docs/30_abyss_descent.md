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
  bisected); each room has 6 always-dim lights. Builds clean **with the LED bake** (fresh `.ff` + regenerated
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
    same model + **56×56×48 clip** as the Data Cache shards crate, via `tools/add_prop_clips.js` `ammo_crate` (which gained
    a per-prop `bot` so the clip sits on the L2 floor z=-480, not the hardcoded z=-240 pit; **needs a full LED bake**, not `-GscOnly`).
  - **L3 (z=-720):** **Glitch Altar** gamble — `(-400, 1948, -720)` (now **solid** — `add_prop_clips.js` `glitch_altar_l3`,
    48×18×64 thin slab matching the reactor/perk-vendor sign kiosk; the floating core orb stays decorative/no-clip).
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
  - **Foundry under-room (L1, z=-240):** **Exo Suit** station — `(230, 1450, -240)` (room relocated EAST to
    center x=350 on 2026-06-25 so the door clears the abyss well; was the freed Overclock spot at `(-120,1450,-240)`).
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
per-prop `bot` (user 2026-06-27), reusing each model's snug dims (ticket-kiosk 60×68×80, work-table 60×36×80, sign-kiosk 48×18×64).

**The 2nd Pack-a-Punch is a STANDALONE GSC vendor, NOT a 2nd stock machine** (`_acc_pap_levels::spawn_paradise_pap_at`,
at `(0,-1700,-1200)`). Stock supports exactly one PaP: `spawn_init` renames every `zm_pack_a_punch` zbarrier to the
shared `vending_packapunch`, then `vending_weapon_upgrade()` does a singular `GetEnt("vending_packapunch")` that
**fatals the load** with two — which is what broke the surface PaP on the earlier attempt. The standalone vendor
(`script_model` + `trigger_radius_use`, like the Paradise box) dispatches through the **same player-scoped tier path**
(`acc_do_first_pack` / `acc_do_tier_up` / `acc_pap_actionfigure`) the surface PaP uses, so the tier lives on
`player.acc_pap_tier[base]` and **never resets** between the two machines. It never carries the `zm_pack_a_punch`
targetname, so stock's singleton is untouched and the surface PaP is safe. `gen_paradise_props.js` no longer injects a
stock 2nd PaP; `acc_dedupe_pack_a_punch()` neutralizes any leftover from an older `.map`.

### The descent gates are SOUL BOXES (user 2026-06-25)

The 4 abyss descent doors (`acc_abyss_door_1..4`, `_acc_abyss_doors.gsc`) **no longer cost currency** — each opens
when the team banks souls (one per kill on that door's layer). Costs are **per-layer AND scale with the live player
count** (user 2026-06-25): the **first gate** (layer 1, the trench, where everyone roams early) needs **125 souls
per player**; each **deeper gate** needs **50 per player** — i.e. 125/50 solo up to **500/200 at a full 4-player
lobby**. `souls_needed(layer)` multiplies the per-player base by `GetPlayers().size`, evaluated **live** so the
per-kill bank check auto-rescales on a dis/connect, and the floating hint **re-syncs to that live value whenever the
player count changes** (`soul_hint_watcher`, user 2026-06-27) so the displayed goal always matches the requirement. Tuning
dvars: `acc_soul_door_cost_first` (125/player) + `acc_soul_door_cost` (50/player); dev mode is a cheap flat 10.

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

Paradise is the **end of the map**: surviving a scripted timed finale **WINS the match**. Module
`_acc_paradise.gsc` (orchestrated by `acc_main`); armed by `_acc_abyss_doors` setting `level.acc_paradise_open` when
the gate opens, and it starts the instant the team drops into the plaza. The sequence (all `acc_paradise_*` live dvars):

| Phase | Default | What happens |
|---|---|---|
| **1 — CALM** | `acc_paradise_calm_sec` 60 | One-shot **victory fanfare** (`acc_paradise_calm`, the Mario stage-win jingle), clear air, a **very light trickle** (`acc_paradise_trickle_sec` 12). A fakeout. |
| **2 — OMEN** | instant | **Fog rolls back in** (`acc_atmosphere::paradise_fog_on` → re-runs the map's `set_fog_from_dvars` haze every tick, overriding the power-on settle) + the stock **dog-round announcer** `zmb_dog_round_start` ("fetch me their souls"). |
| **3 — DREAD** | `acc_paradise_dread_sec` 10 | Fog closing in, trickle continues. |
| **4 — BATTLE** | `acc_paradise_survive_sec` 225 (**3:45**, user 2026-06-27) | Arena **seals** (`acc_paradise_seal`); the **"115" anthem** (`acc_paradise_music`, max volume) plays; **1 of EACH boss** (user 2026-07-05) — **Trench Warden (Brutus) + Phantom + Rogue Protector + Avogadro + Apothicon Fury + Panzer** (Fury + Panzer added 2026-07-09; the Fury meteor-drops onto a player via the trench below-zone spawn path, boss-flagged + below-world-cull-immune) — + the **x4 horde** (regular surge + shield/glitch gauntlet, `acc_paradise_spawn_mult` 4). **Every minute, in lockstep** (`escalation_loop`): the **boss wave tops back up to 1 of each** (concurrent cap **1 each**: `acc_paradise_brutus_max`/`_phantom_max`/`_rp_max`/`_avo_max`/`_fury_max`/`_panzer_max`, so a killed boss is replaced the next minute), the **wave-baseline horde trench-buff** steps up a layer (**L2** min 0–1 → **L3** → **L4** → **L5** final wave; `_acc_zombie_speed::paradise_buff_layer` reads `level.acc_paradise_horde_layer` as the floor), and a **UI alert** fires ("The horde is getting stronger", or **"You will never escape!"** on the L5 step at 3:00). **Four waves**: L2/L3/L4 are **60s** each, the **final L5 wave is 45s** (3:00 → 3:45). **ON TOP of the wave, every zombie individually ages +1 tier per 30s it stays ALIVE** (`acc_paradise_age_step_sec` 30, 0 = ramp off, capped at `acc_paradise_buff_max` L5 — the per-zombie anti-kite ramp restored 2026-07-09; stamped + computed in `paradise_buff_layer`, effective layer = max(wave, birth wave + age steps)): kiting instead of killing outscales the wave clock 2:1 — a wave-1 zombie a runner never kills is L5 by 1:30. **NO power-up drops** the whole battle (`block_powerup_drop` on `level.custom_zombie_powerup_drop`). A **countdown timer HUD**; **boss HUD + boss music suppressed** (`level.acc_paradise_onslaught`). |
| **WIN** | — | Banner → replay the fanfare → **lift the fog** (`paradise_fog_off` = `disable_fog`, planes pushed off-map) → fade → purge horde → `level notify("end_game")` (docs/16 end-game recipe). **LOSE** = team wipe ends the match normally. |

**Boss-HUD / music suppression**: `_acc_health_bars::boss_bar_listener`/`boss_bar_track` skip + self-destroy bars
while `level.acc_paradise_onslaught`; `_acc_boss::boss_music` returns early on the same flag (the "115" anthem owns
the audio). **Paradise risers**: 12 floor points (`get_paradise_risers`, was 6). **Brutus in paradise**:
`_acc_boss_brutus::spawn_one_paradise` + `paradise_warden_think` (the trench-warden twin, paradise-tethered).

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
dimensions). The **Rogue Protector's death reward is now suppressed** in the arena like every other boss
(it was the lone exception to the survive-not-farm finale). Deliberate finale-only deltas that remain
(presentation/economy, not behavior): boss HUD + music suppressed, all drops/power-ups/shards blocked, and the
paradise Brutus rides the same trench-warden tether he uses topside.

**Engine guard rails (tune down if unstable in coop):** concurrent caps on Brutus/Phantom (`_brutus_max`/
`_phantom_max` 1, was 4), shield+glitch specials (`acc_paradise_special_max` 12, was 8), and an extra AI-cap bump
(`acc_paradise_ai_bonus` 12, stacks on the trench +14). **Audio**: `sound_assets/acc/music/115.wav` +
`paradise_calm.wav` (48k/16-bit) + a **game-closed sound build**; both tracks are **copyrighted — test-only, NOT for
the public Workshop** (CREDITS.md IP review). **Real wavs in place since 2026-07-09** — they are gitignored
(licensing) so they never migrated to the new box, which had been silently shipping placeholder copies (the Brutus
track as "115", the nuke SFX as the "win fanfare"); resample any re-download with `tools/resample48k.js`. **Regression-watch in-game:** fog actually renders at the
paradise depth (z≈−1200, below the haze base height) and the win→`end_game` flow fires cleanly. (The multi-boss
arena was stabilised by the 2026-07-09 boss audit above — Phantom/Glitch melee lockout fixed via
`force_playable_emergence`, and concurrent caps cut to 1-of-each.)
