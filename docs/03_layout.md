# 03 - Layout

Gameplay-first layout. Theme and art are flavor only; this doc is about **flow, chokepoints, training potential, risk/reward zones, how randomization slots into geometry**, and the **decontamination** round hazard.

> **Visual design**: **[map_design.svg](map_design.svg)** — the as-built map
> rendered from the real `.map` source (rooms, corridors, every perk machine,
> wallbuy, box, door, terminal, power switch, spawn marked + legend). Regenerate
> after map edits: `node tools/gen_map_design.js`.

## Design Philosophy

- **Small and dense beats big and empty.** Target total playable footprint comparable to Der Eisendrache, not Tranzit.
- **Every zone must have a reason to visit.** A wallbuy, a Data Shard source, a PaP route node, or a risk/reward event. Zones that are just corridors die.
- **Two distinct training spots per major zone.** A training spot = a loop or chokepoint where a skilled player can herd the horde. Without them, late-game collapses into "camp one corner".
- **Every zone has at least two exits.** No dead-end panic traps unless the panic is a designed risk (see Vault Overload).
- **Verticality is earned.** Rooftops and the Vault are late-unlock so early rounds stay grounded.
- **Spawn and Lab are never permanently sealed** by decontamination (see below). **Plaza** is never sealed: it is a **cut vertex** in the zone graph; sealing it would strand players away from the Lab.

## Map Diagram (read + build reference)

### ASCII (topology)

Hub-and-spoke with two Lab approaches. `==` / `||` are **doors** (buyable or always open per run). `xxx` = zone sealed after decontamination (example: Market already locked).

```
                         +---------------------------+
                         |          Helipad          |
                         |   (sniper, box, train)    |
                         +-------------||------------+
                                       |
         +-----------------------------+----------------------------+
         |                             |                            |
         |                     +-------+--------+                   |
         |                     |       Plaza       |                 |
         |                     |    (HUB — never   |                 |
         |                     |   decontaminated) |                 |
         +----------+----------+-------+--------+----------+--------+
         |          |                  |          |          |        |
  +------+---+  +---+------+     +-----+----+ +---+-----+ +--+-------+--+
  |  Spawn   |  |  Market  |     |  Alley  | | Vault   | |   Lab    |
  |          |  |          |     |         | |         | |          |
  | (SAFE)   |  |xxxxxxxxxx|     |         | |         | | (SAFE)   |
  +------+---+  +----------+     +---------+ +----+----+ +-----+----+
         |            |               |           |           |
         |            +-------+-------+           |           |
         |                    |                   |           |
         +--------------------+                   +-----+-----+
                                                        |
                                              PaP / perks / OC
```

**Legend**

- **SAFE**: Spawn and Lab are **never** chosen as decontamination seals (see [Decontamination zones](#decontamination-zones-round-hazard)).
- **HUB**: Plaza is **never** sealed — required for connectivity between Spawn, side zones, and both Lab approaches.
- **Eligible seals** (four): Market, Alley, Vault, Helipad. One of these **locks permanently for the run** each round for the first four rounds (order is **run-randomized**).

### Mermaid (same graph, for slides / wiki)

```mermaid
flowchart LR
    subgraph safe["Never sealed"]
        SP[Spawn]
        LAB[Lab<br/>PaP, perks, Overclock]
    end

    subgraph hub["Never sealed — hub"]
        CORP[Plaza<br/>Power A, hack, AR, box]
    end

    subgraph sealable["Decontamination-eligible"]
        MKT[Market]
        AL[Alley]
        VLT[Vault<br/>Power B, Overload]
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

- Spawn has two exits (Market, Alley), both buyable early so players pick their opener.
- Corp is the **hub** — four connections, two training spots, one of two power switches.
- Lab (PaP + perks) has two approaches (Server or Roof). One approach may be **randomly blocked per run** (see Randomization) — independent of decontamination.
- Total: **7 zones**. Eligible for **permanent seal**: **4** (Market, Alley, Vault, Roof). **Never sealed**: Spawn, Corp, Lab.

## Decontamination zones (round hazard)

**Purpose.** Kill the slow-start problem from the other direction: every round begins with **urgency** — you cannot treat the map as fully safe until you have **left the active contamination zone** and the **timer** has resolved. It also **shrinks** the playable space over the first four rounds so routing and training spots change mid-run.

### Rules (v1.0)

| Rule | Detail |
|---|---|
| **What triggers** | At the **start of each round** (after `start_of_round` / `acc_round_start`), one **eligible zone** is declared **contaminated** for that round’s seal event. |
| **Eligible zones** | **Market**, **Alley**, **Vault**, **Helipad** only. **Not** Spawn, **not** Plaza, **not** Lab. |
| **Order** | A **permutation** of the four zones is rolled **once at map load**. **Round 1** contaminates slot 1, **round 2** slot 2, … **round 4** slot 4. **Round 5+**: **no new permanent zone seal** from this system (map stays at four zones locked). *(Tuning: later rounds could add “soft” re-contamination without new seals — not v1.0.)* |
| **Player warning** | Global HUD + audio: **“DECONTAMINATION — EVACUATE [ZONE NAME]”** at round start. |
| **Escape window** | **20 seconds.** Anyone **inside** the contaminated zone’s volume when the round starts must **leave** that zone’s flagged bounds before the timer hits 0. |
| **Failure** | If still inside when the timer expires: **instant death** (same as being downed with no revive — use stock down/kill path so Quick Revive / co-op rules apply). **Co-op**: each player evaluated independently. |
| **After the timer** | The zone **seals for the rest of the run**: doors close, debris blocks, **kill volume** on re-entry. Zombies may still spawn elsewhere; spawners inside the sealed zone are disabled or redirected in Radiant/script. |
| **Lab perk rotation** | The Lab’s **4-of-9 perk re-roll does not happen at the first frame of the round.** It runs **only after** the decontamination phase completes: **after** the 20s window ends and the zone is sealed (or after round 5+ when there is no new seal — rotation still runs **after** the nominal 0s decontamination tick). See [13_perks.md](13_perks.md#perk-availability-per-round-rotating-lab-machines). |

### Why Corp / Spawn / Lab are excluded

- **Spawn**: must remain a **spawn-safe** floor; sealing it ends the run by definition.
- **Lab**: Pack-a-Punch, Overclocks, **all perks** — sealing it removes progression and contradicts the perk loop.
- **Plaza**: graph-theoretic **cut vertex**; sealing it disconnects typical paths from Spawn to Lab unless duplicate edges exist (they do not in v1.0).

### Skill expression

- **Round planning**: you end the previous round **positioned** so you are not “caught shopping” in a zone that might seal next.
- **Coordination**: in co-op, one player might bait or train in a zone about to seal while others hold doors — high risk.
- **Perk shopping**: you **cannot** rely on seeing the new perk lineup until **after** decontamination resolves — rushing Lab at round start may trap you if Lab path crosses the contaminated zone (pathing literacy).

### Implementation notes (GSC)

- Emit e.g. `acc_decontamination_start` (round, zone_id) at round start; `acc_decontamination_complete` after 20s + seal logic.
- `_acc_map_randomizer.gsc` should subscribe to **`acc_decontamination_complete`** (or an equivalent **wait 20s** after round start when a seal applies) before **`roll_perk_rotation()`**. Until that module is updated, perk roll timing in code may lead docs — **docs win**.

## Zone Graph (compact)

```mermaid
flowchart TD
    Spawn[Spawn<br/>Starting zone, pistol / SMG wallbuys]
    Market[Market<br/>Box, LMG wallbuy]
    Alley[Alley<br/>Shotgun wallbuy, Shard lane]
    Corp[Plaza<br/>Power switch A, box, AR, hack]
    Server[Vault<br/>Power switch B, Overload]
    Roof[Helipad<br/>Box, sniper, late train]
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

## Per-Zone Gameplay Notes

### Spawn
- **Purpose**: first 3-4 rounds. Establish economy.
- **Features**: 2x pistol wallbuy, SMG wallbuy, starting pistol upgrade terminal.
- **Training**: one small loop around a central debris pile. Usable through round ~8.
- **No perks.** Forces movement.
- **Decontamination**: **never** the sealed zone.

### Market
- **Purpose**: early economy and box location. Mid-risk.
- **Features**: Mystery Box possible spawn, LMG wallbuy. **No perk machines** — all perks live in the Lab per [13_perks.md](13_perks.md).
- **Training**: stall-row loop. Strong early training; **lost for the run** if this zone is sealed in your game’s decontamination order.
- **Decontamination**: **eligible** — can be permanently sealed.

### Alley
- **Purpose**: alternative opener. Faster access to Corp, fewer sightlines.
- **Features**: shotgun wallbuy, Data Shard first guaranteed drop (first elite spawn happens here around round 5).
- **Training**: bad. It's a corridor. Don't camp here.
- **Decontamination**: **eligible** — can be permanently sealed.

### Plaza
- **Purpose**: **the hub**. Where a large share of a typical run is spent.
- **Features**: Power Switch A (one of two), Mystery Box possible spawn, AR wallbuy. **No perk machines** — all perks at the Lab.
- **Training**: two distinct spots — the fountain loop (big, safe) and the lobby S-curve (tight, efficient).
- **Hack terminal**: optional intrusion event (see `06_mechanics.md`). Success rewards 2 Data Shards + a random Overclock. Failure locks it for the run and spawns a penalty wave.
- **Decontamination**: **never** sealed (connectivity).

### Vault
- **Purpose**: high-risk, high-reward zone.
- **Features**: Power Switch B (one of two), **Vault Overload event**, EMP Grenade tactical wallbuy. **No perk machines** — all perks at the Lab.
- **Vault Overload**: timed event, player commits to defending a point for 90 seconds against a scaled wave. Success = 3 Data Shards + unlocks a permanent map shortcut for this run. Failure = takedown wave spawns that overwhelms if you're not moving.
- **Training**: only one training spot, and it's the point you're defending during Overload — so you can't both farm and run the event.
- **Decontamination**: **eligible** — can be permanently sealed (Overload may become unreachable if sealed before completion — intentional tension; complete Overload before that round or accept loss of event for that run).

### Helipad
- **Purpose**: late-game training arena. Opens verticality once you've paid for the elevator or taken the service stairs.
- **Features**: Mystery Box possible spawn, sniper wallbuy. **No perk machines** — all perks at the Lab.
- **Training**: the **best late-game training spot in the map**. Large open area with a central obstacle. Elite enemies don't path well here; that's intentional and is compensated by a Helipad-specific modifier (see `07_replayability.md`) that forces you to move on timers.
- **Decontamination**: **eligible** — can be permanently sealed.

### Lab (Pack-a-Punch + Overclock Terminal + ALL Perks)
- **Purpose**: the map's upgrade + perk hub. Everything that costs progression currency lives here.
- **Features**:
  - **Pack-a-Punch machine** (L1-L5 progression via Points, see [05_weapons.md](05_weapons.md)).
  - **Overclock Terminal** (spend Data Shards to advance weapon tier T1-T5 or re-roll an Overclock).
  - **Wonder weapon craft terminal** (Signal Staff, see [05_weapons.md](05_weapons.md#signal-staff-ranged-wonder-weapon)).
  - **4 perk machines** (Lab-A, Lab-B, Lab-C, Lab-D). Machines re-assign to a random 4-of-9 perks **after each round’s decontamination phase**. See [13_perks.md](13_perks.md).
- **Access**: two approaches (from Server or from Roof). One may be **blocked per run** at random — rerouting punishes players who don't know both paths.
- **Training**: none. It's a transaction zone.
- **Frequency of visit**: high — perk rotation + PaP + Overclock. **Perk lineup only updates after contamination resolves**, not at round start.
- **Decontamination**: **never** sealed.

## Randomized Geometry Elements

These are features **of the layout** that re-roll per run. Full randomization catalog is in `07_replayability.md`.

- **Power switch active**: A (Corp) or B (Vault). The other is dead this run. Changes where you must go by round 7-8.
- **Lab approach blocked**: Server-side or Roof-side. Changes your PaP route.
- **Decontamination order**: which of the four eligible zones seals on rounds **1–4** is a **random permutation** at map load (see [Decontamination zones](#decontamination-zones-round-hazard)).
- **Wallbuy pool per slot**: each wallbuy slot pulls from a weighted pool of 3-5 guns. The slot location is fixed; the gun is not.
- **Perk rotation (per round)**: the 4 perk machines in the Lab re-roll to a random 4-of-9 perks **after** decontamination closes for that round. No duplicates in the rotation. See [13_perks.md](13_perks.md).
- **Mystery Box location weights**: standard BO3-style box move, but the initial spawn weights vary per run.

## Training Spot Summary

Knowing where you can train is a skill check. Listed best-to-worst for late game **after accounting for sealed zones** (your order may remove Market, Alley, Vault, or Roof):

1. **Helipad** — biggest, cleanest circle (unless sealed).
2. **Plaza fountain** — big, safe, central.
3. **Plaza S-curve** — tighter, higher efficiency, unforgiving.
4. **Market stall row** — early-game only; **gone** if Market sealed early.
5. **Vault point** — only viable during non-Overload state, and **gone** if Vault sealed.

## Out-of-Scope for This Doc

- Asset lists, specific prefab choices, exact brush counts.
- Lighting, VFX, soundscape.
- Performance budgets (will be added in Phase 5 when we do an art pass, if we do one).
