# 02 - Layout

Gameplay-first layout. Theme and art are flavor only; this doc is about **flow, chokepoints, training potential, risk/reward zones, and how randomization slots into geometry**.

> **Visual design**: **[map_design.svg](map_design.svg)** — the as-built map
> rendered from the real `.map` source (rooms, corridors, every perk machine,
> box, door, terminal, power switch, spawn marked + legend). Regenerate
> after map edits: `node tools/gen_map_design.js`.

> **Decontamination was CUT (user 2026-06-22).** An earlier design had a per-round
> "contamination" hazard that sealed a zone each round and killed players caught inside.
> It is no longer in the game — no zone is ever sealed, no EVACUATE warning fires, no
> player is killed. `_acc_decontamination::run_decon_phase` now only re-emits
> `acc_decontamination_complete` once per round as a harmless tick (the module's zone
> helpers stay because `_acc_lockdown`/`_acc_lockdown_challenge` reuse them). All zones
> below are permanent — read them as always-open.

## Design Philosophy

- **Small and dense beats big and empty.** Target total playable footprint comparable to Der Eisendrache, not Tranzit.
- **Every zone must have a reason to visit.** A box location, a Data Shard source, a PaP route node, or a risk/reward event. Zones that are just corridors die.
- **Two distinct training spots per major zone.** A training spot = a loop or chokepoint where a skilled player can herd the horde. Without them, late-game collapses into "camp one corner".
- **Every zone has at least two exits.** No dead-end panic traps unless the panic is a designed risk.
- **Verticality is earned.** Rooftops and the Vault are late-unlock so early rounds stay grounded.
- **Bus Station is a cut vertex** in the zone graph — every path from Plaza to the Lab runs through it.

## Map Diagram (read + build reference)

### ASCII (topology)

Hub-and-spoke with two Lab approaches. `==` / `||` are **doors** (buyable or always open per run).

```
                         +---------------------------+
                         |          Helipad          |
                         |   (sniper, box, train)    |
                         +-------------||------------+
                                       |
         +-----------------------------+----------------------------+
         |                             |                            |
         |                     +-------+--------+                   |
         |                     |    Bus Station    |                 |
         |                     |    (HUB — power,  |                 |
         |                     |     trench, box)  |                 |
         +----------+----------+-------+--------+----------+--------+
         |          |                  |          |          |        |
  +------+---+  +---+------+     +-----+----+ +---+-----+ +--+-------+--+
  |  Plaza   |  |  Market  |     |  Alley  | | Vault   | |   Lab    |
  |          |  |          |     |         | |         | |          |
  | (SPAWN)  |  |          |     |         | |         | |  (PaP)   |
  +------+---+  +----------+     +---------+ +----+----+ +-----+----+
         |            |               |           |           |
         |            +-------+-------+           |           |
         |                    |                   |           |
         +--------------------+                   +-----+-----+
                                                        |
                                              PaP / perks / OC
```

**Legend**

- **SPAWN**: Plaza is the starting zone.
- **HUB**: Bus Station is the cut vertex — required for connectivity between Plaza, the side zones, and both Lab approaches. It holds the map's single power switch and the trench/Abyss descent.
- **PaP**: the Lab holds Pack-a-Punch, the Overclock terminal, and all 10 perks.

### Mermaid (same graph, for slides / wiki)

```mermaid
flowchart LR
    subgraph spawn["Spawn"]
        SP[Plaza]
    end

    subgraph hub["Hub — cut vertex"]
        CORP[Bus Station<br/>Power switch, trench/Abyss, box]
    end

    subgraph upgrade["Upgrade hub"]
        LAB[Lab<br/>PaP, perks, Overclock]
    end

    subgraph side["Side zones"]
        MKT[Market]
        AL[Alley]
        VLT[Vault]
        ROOF[Helipad]
    end

    SP <--> MKT
    SP <--> AL
    MKT <--> CORP
    AL <--> CORP
    CORP <--> VLT
    CORP <--> ROOF
    VLT <--> LAB
    ROOF <--> LAB
```

Key properties:

- Plaza has two exits (Market, Alley), both buyable early so players pick their opener.
- Bus Station is the **hub** — four connections, two training spots, the map's power switch, and the trench/Abyss.
- Lab (PaP + perks) has two approaches (Vault-side or Roof-side). One approach is **randomly blocked per run** (`_acc_map_randomizer::roll_pap_approach` returns `server` or `roof` — the blocked side; see [Randomized Geometry Elements](#randomized-geometry-elements)).
- Total: **7 zones**, all permanent (no zone is ever sealed).

## Zone Graph (compact)

```mermaid
flowchart TD
    Spawn[Plaza<br/>Starting zone]
    Market[Market<br/>Box location]
    Alley[Alley<br/>Shard lane]
    Corp[Bus Station<br/>Power switch, box, trench/Abyss]
    Server[Vault]
    Roof[Helipad<br/>Box, late train]
    Lab[Lab<br/>PaP, Overclock, ALL perks]

    Spawn <--> Market
    Spawn <--> Alley
    Market <--> Corp
    Alley <--> Corp
    Corp <--> Server
    Corp <--> Roof
    Server <--> Lab
    Roof <--> Lab
```

## Weapons are box-only

**There are no wallbuys on this map.** `_acc_map_randomizer::remove_all_wallbuys()`
unregisters every stock wallbuy purchase stub at load, and the world-model spawner
(`spawn_acc_wallbuy_models`) stays defined-but-uncalled. All guns come from the
**Mystery Box** (which moves among six chests) — a large arsenal (Apex pack + Skye
ports + elemental bows). See [04_weapons.md](04_weapons.md). Any "wallbuy" wording in
older docs is stale; the per-zone notes below list box locations, not wallbuys.

## Per-Zone Gameplay Notes

### Plaza (Spawn Plaza, `start_zone`)
- **Purpose**: first 3-4 rounds. Establish economy.
- **Size (tightened 2026-06-26)**: was a huge near-empty arena; **shrunk ~75%** to a compact space
  (interior **x[-470,213] y[-240,720]** ≈ 683×960) via [tools/gen_plaza_shrink.js](../tools/gen_plaza_shrink.js).
  It ADDS a tighter inner wall ring inside the old footprint and seals the dead space (the stock template arena
  is too irregular to safely value-remap the perimeter — that crashes the LED bake). The squeeze is taken from
  the **east** (spawns + window-barricade + corridor mouths fix the W/S/N sides). The two corner exits (NW→Market,
  NE→Alley) stay connected by connector corridors to the original wall mouths; the buyable doors (further out)
  are untouched. See CHANGELOG 2026-06-26.
- **Implant Lab (side-room)**: the gated room south of the plaza (interior **x[-720,180] y[-540,-240]**,
  widened WEST 2026-06-27 then EAST 2026-07-10) holds the three boss-item **Implant Bench** pads — spread as
  a **staggered arc** across the open EAST half (out of the Exchange staircase's SW corner and clear of every
  wall; relayout 2026-07-10). Entered by a **tight 80u doorway** with a **buyable slide-up door**
  (`enter_implant`, 1500). Also holds the descent to **The Exchange** (below). See [09_boss_items.md](09_boss_items.md).
- **The Exchange (transfer vault, under the Plaza)**: a stairwell carved **down from the Implant Lab floor**
  leads to an enclosed **transfer vault** at **z=-240 directly under the Plaza** (room x[-360,300] y[-420,360]).
  A **SHARED TEAM VAULT** for player-to-player transfers of Points / Data Shards / Mega Bottles / Boss Items —
  deposit/withdraw pads, no targeting. Gated by a **buyable slide-up door** (`enter_exchange`, 1500). Built by
  [tools/gen_plaza_basement.js](../tools/gen_plaza_basement.js) (carves the stock arena-floor slab around the
  stairwell well; LED-bake-gated). A **safe** room (excluded from the trench amping, OOB-vetoed). Full design:
  [37_transfer_vault.md](37_transfer_vault.md).
- **The Armory (upper room)**: an enclosed **mezzanine loft** at **z=288** (room to z=560, footprint
  x[-220,180] y[488,850]) reached by an **18-tread 16/16 staircase up from the Plaza floor** (x[-80,48]
  y[200,488], north of spawn, into a south-wall doorway; zombies path up). Houses a **shared team WEAPON RACK**
  (pooled deposit/withdraw — give guns to teammates) + a **MEGA-BOTTLE EXCHANGE** (1 bottle → random reward).
  It sits inside the tall `start_zone` player_volume (z to 1041), so **no new zone** is needed. The **stair
  base MUST be in playable floor (x[-470,213])** — v1 mistakenly floated it over the sealed east dead-space
  and was walled off (fixed 2026-07-07). Built by [tools/gen_upper_room.js](../tools/gen_upper_room.js)
  (LED-bake-gated → BAKED). Full design: [39_armory.md](39_armory.md).
- **Layout**: open-but-shrunk (an interior maze was tried then removed per user). Difficulty comes from the ~75%
  shrink + **3 scattered cargo-crate props** as low cover, with zombie risers spread across the floor. Players
  spawn in the back band beside the mystery box. No more giant circles.
- **No perks.** Forces movement.

### Market
- **Purpose**: early economy and box location. Mid-risk.
- **Features**: Mystery Box possible spawn. **No perk machines** — all perks live in the Lab per [10_perks.md](10_perks.md).
- **Training**: stall-row loop. Strong early training.

### Alley
- **Purpose**: alternative opener. Faster access to the Bus Station, fewer sightlines.
- **Features**: Data Shard lane (first elite spawn happens here around round 5).
- **Training**: bad. It's a corridor. Don't camp here.

### Bus Station
- **Purpose**: **the hub**. Where a large share of a typical run is spent.
- **Power**: a **single stock wall power-switch prefab**, west-wall-mounted in the Bus Station's **north/Lab half**
  with the native flip animation + power-on sound (origin `(-752 2250 1)`, facing east into the room). The trench's
  only north exit is the **east** stair channel, so players climb out on the NE side and must cross the dark Lab half
  to the **far west wall** to flip it — you can't power on the instant you leave the stairs.
  **Design note:** this replaced an earlier custom **dual-switch** (one each side of the trench). Per the user's
  2026-06-19 decision, `_acc_power.gsc` now **stands down** — it keeps the stock `use_elec_switch` prefab (which powers
  the map natively) and only deletes a leftover mid-air `acc_power_switch` trigger. To restore the dual-switch, recover
  the prior `_acc_power.gsc` from git (see its header comment).
- **Features**: Mystery Box possible spawn. **No perk machines** — all perks at the Lab.
- **Trench (cross-room)**: a horizontal (E-W) trench is cut **dead-centre**, splitting the room into a south half (the two entrances from Market/Alley, plus the power switch and box) and a north half (the doors to Vault/Helipad). It spans the full room width and is a **deep multi-layer abyss** (first floor −240, then descending on a fixed 240u pitch through layers L2 −480, L3 −720, L4 −960, L5 −1200 — see [30_abyss_descent.md](30_abyss_descent.md)) **with vertical walls** (all four sides sealed, incl. E/W end walls) — you can't step over it or jump the 450u gap across the top, so to cross you go **down and up the far side**. **One thin (96u) staircase per side, hugging the side walls**: a stair against the **west wall** (south lip) and one against the **east wall** (north lip), joined by the open trench floor — cross by going **down one wall and up the other** (diagonal: SW down → across the open pit → NE up). Or **just jump in** (preferred/faster). **Rocket-Shield BRIDGE:** one central deck (`x[-109,147]`, full S→N span) floats **58u above the rim** — reachable ONLY by the Rocket Shield **2× jump**; the express crossing for that item, off the navmesh so zombies can't follow (`tools/add_trench_bridge.js`).
  - **The pit is a deliberate kill-box (user, 2026-06-18):**
    - **No random death** — the trench floor sits below the corp_zone playable-area volume, so stock ZM's out-of-playable-area monitor *was* hard-killing standing players (hp-full, no-damage, ~3s delay). `_acc_bus_trench::init` registers `level.player_out_of_playable_area_monitor_callback` to **veto that kill in the trench only** (rest of map still guarded) → safe at ANY depth. See memory `sunken-floor-oob-kill`.
    - **Move-speed penalty while exposed underground** — a **layered slow gated by your Exo Suit tier**, NOT a flat multiplier. You move normally within the layers your Exo covers; below that you take **−20% at the first uncovered layer** and **−10% per layer deeper** (`acc_exo_slow_first` 0.20 + `acc_exo_slow_step` 0.10 × extra layers, gated by `acc_trench_slow_on`, capped so speed never hits 0; composed in `_acc_utility::recompute_move_speed`). The `player.acc_trench_slow` boolean is kept only for the debug speed-flags readout. See [29_exo_suit_plan.md](29_exo_suit_plan.md).
    - **Spawn surge + raised zombie cap** — entering bursts extra zombies at the corp risers (`spawn_corp_surge`, `acc_trench_surge_count` **5**, 12 s cooldown) and raises `level.zombie_ai_limit` by `acc_trench_ai_bonus` (**14**) while anyone's in the pit; `_acc_zombie_speed` trench-aggro beelines/sprints them at you. (Both defaults were cut ~25% from 6/18, user 2026-06-18.)
    - **Pulsing full-screen red DANGER warning** (`_acc_bus_trench` `trench_warning_on`, dvar `acc_trench_warn`).
    - **Native engine fall damage is disabled map-wide** (`disable_native_fall_damage`), so the drop never kills; the only fall cost is the scripted, velocity-gated **~35 tax** (`ACC_TRENCH_FALL_DMG` = 35, applied ~0.2s after entry so it lands on impact; PhD-negated — the stair walk is free).
  - **Two trench rooms (user, 2026-06-18):** two greybox rooms open off the pit at the **trench-floor level** — a **Plaza-facing** room behind the south wall (`y=TRENCH_Y1`) and a **Lab-facing** room behind the north wall (`y=TRENCH_Y2`), each ~**512w × 384d × 160h**, carved into the ground slabs (the slab above each stays solid = the walkable floor). Each is gated by a **buyable stock `zombie_door`** (1500 pts, `enter_trench_plaza` / `enter_trench_lab` → `acc_door_trench_plaza` / `acc_door_trench_lab`) that slides **sideways** into the wall pocket (so the room height isn't limited by a slide-up). **The whole underground counts as "the trench"** (user 2026-06-18): `player_in_trench` aliases the broad `player_in_underground` footprint, so the slow, spawn surge, AI-cap raise, zombie aggro, and the danger warning all apply down here, not just the open pit (the fall-tax still only fires on a real fall into the pit). NOT a respite. Brushes: `tools/add_trench_rooms.js` (post-processor — reads the **live** slab z, so it tracks the parallel depth retunes; **re-run after any `gen_corp_trench` regen**). Navmesh regenerates through the doorways → zombies follow once a door is bought.
  - **Underground = the Abyss Descent:** the rooms are the entrance to a vertical sub-level — a stacked set of **soul-box layers (L2/L3/L5)** descending to a **Paradise plaza** at the bottom. This supersedes the old "Data Vault gauntlet / Hall A → Hall C" greybox snapshot. The Plaza-facing room holds the shard **Glitch Altar** (`_acc_glitch_altar.gsc`); the layers hold the underground shard economy (caches, Cyberware/Overclock sinks). The deeper you go the harder it gets; each layer is an idempotent module authored by `tools/gen_abyss_layer.js`. The OOB-kill veto covers the whole sub-level (`_acc_bus_trench::player_in_underground`). Full design + per-layer detail: [30_abyss_descent.md](30_abyss_descent.md); trench systems overview: [28_trench_systems_guide.md](28_trench_systems_guide.md).
  - Geometry SoT: `source_data/rooms.json` "trenches".corp; brushes `tools/gen_corp_trench.js`. Navmesh links the stairs so zombies funnel through. **Stairs re-pitched 2026-06-26** (players reported the original 16-tall/16-deep 45° steps glitched the player hull): `tools/regen_trench_stairs.js` rebuilt both stairs at **10-tall / 16-deep (≈32°), 23 steps, 368u long** — same top lip (south W / north E), extended toward the middle (W `y[1723,2091]`, E `y[1805,2173]`; opposite x-walls so no collision), pit-side walls re-sized to match. Lower 10u risers link the navmesh more easily than 16u. Geometry change → full LED bake (passed).
- **Hack terminal**: optional intrusion event (`_acc_events_hack.gsc`; see [05_mechanics.md](05_mechanics.md)). Success completes a multi-stage channel/survive sequence; failure locks the terminal for the run and spawns a **penalty wave** (`spawn_penalty_wave`). The old **+2 Data Shard** reward is now **OFF by default** — the shard economy moved underground (trench-only), so the topside hack grants nothing unless you set `acc_hack_shard_drop 1`. The documented free-Overclock-voucher reward is still a `TODO(acc-oc)` in code, not yet granted. <!-- TODO(acc-verify): Overclock voucher reward remains a code TODO; keep flagged until implemented. -->

### Vault
- **Purpose**: high-risk, high-reward transit zone on one of the two Lab approaches.
- **Features**: **No power here** (the map's single power switch lives in the Bus Station). **No perk machines** — all perks at the Lab.
- **Retired:** the earlier **"Vault Overload"** timed-defense side-event is **removed** (user 2026-07-07). `acc_events_overload::init()` is commented out in `_acc_main.gsc`, and the event's `acc_overload_terminal` trigger + point struct were deleted from the `.map`. Nothing reads `level.acc_overload_state`.

### Helipad
- **Purpose**: late-game training arena. Opens verticality once you've paid for the elevator or taken the service stairs.
- **Features**: Mystery Box possible spawn. **No perk machines** — all perks at the Lab.
- **Training**: the **best late-game training spot in the map**. Large open area with a central obstacle. Elite enemies don't path well here; that's intentional and is compensated by a Helipad-specific modifier (see [06_replayability.md](06_replayability.md)) that forces you to move on timers.

### Lab (Pack-a-Punch + Overclock Terminal + ALL Perks)
- **Purpose**: the map's upgrade + perk hub. Everything that costs progression currency lives here.
- **Features**:
  - **Pack-a-Punch machine** (L1-L5 progression via Points, see [04_weapons.md](04_weapons.md)).
  - **Overclock Terminal** (spend Data Shards to advance weapon tier T1-T5 or re-roll an Overclock).
  - **10 perk alcoves** along the Lab north wall. **A random 4 of the 10 alcove doors open each round** and the rest stay walled off; the 4 re-roll every round (`_acc_perk_doors.gsc`, `ACC_PERK_DOORS_OPEN_PER_ROUND` = 4 of 10 specialties). A player can also **permanently unlock** one currently-closed door for the rest of the game by paying **2 Empty Mega Bottles** (`ACC_PERK_DOOR_UNLOCK_COST`) — that becomes a bonus always-open alcove on top of the 4 rotating ones. Manual override `set acc_perk_doors_all_open 1` forces all open (dev mode runs the real rotation). See [10_perks.md](10_perks.md).
  - **Wonder weapon**: the elemental bows are the map's wonder weapons (box arsenal, see [04_weapons.md](04_weapons.md)). <!-- TODO(acc-verify): the earlier "Signal Staff craft terminal" is not present in code or the weapon CSV; if it is ever built, restore its terminal here. -->
- **Access**: two approaches (from the Vault side or from the Roof side). One is **blocked per run** at random (`roll_pap_approach`) — rerouting punishes players who don't know both paths.
- **Training**: none. It's a transaction zone.
- **Frequency of visit**: high — perk rotation + PaP + Overclock.

## Randomized Geometry Elements

These are features **of the layout** that re-roll per run/round. Full randomization catalog is in [06_replayability.md](06_replayability.md).

- **Power switch**: **not randomized.** There is exactly one switch (the Bus Station wall prefab). The old "A (Corp) or B (Vault)" roll is retired — the Vault switch prefab was deleted from the map, so `roll_power_switch_side()` always returns `corp`.
- **Lab approach blocked**: Vault-side (`server`) or Roof-side (`roof`), rolled once per run by `roll_pap_approach`. Changes your PaP route.
- **Perk rotation (per round)**: a random **4 of the 10** Lab perk alcove doors open each round; no duplicates. Rolled per round in `_acc_perk_doors.gsc` — independent of any round-start tick. See [10_perks.md](10_perks.md).
- **Mystery Box location weights**: standard BO3-style box move among the six chests; the initial spawn weights vary per run (`roll_mystery_box_initial` → plaza or lab).

## Training Spot Summary

Knowing where you can train is a skill check. Listed best-to-worst for late game:

1. **Helipad** — biggest, cleanest circle.
2. **Bus Station** (south half) — big, safe, central.
3. **Bus Station S-curve** — tighter, higher efficiency, unforgiving.
4. **Market stall row** — early-game only.

## Out-of-Scope for This Doc

- Asset lists, specific prefab choices, exact brush counts.
- Lighting, VFX, soundscape.
- Performance budgets.
