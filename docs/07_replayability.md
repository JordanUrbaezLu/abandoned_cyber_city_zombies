# 07 - Replayability

The explicit systems that make run N+1 meaningfully different from run N, without sacrificing fairness.

## Three Tiers of Variance

Ordered from "subtle" to "radical":

1. **Per-run map state** - re-rolls every time you load the map. Small but pervasive. Default-on.
2. **Build space** - your Cyberware + Overclock decisions within a run. Large expressive space. Driven by player choice + Shard RNG.
3. **Modifiers** - optional toggles you pick before the run. Radical changes to rules. Default-off.

## Tier 1 - Per-Run Map State Randomization

Re-rolled at map load. Documented so players can learn the *space* of randomization, not guess.

### Power Switch Side

- State A: Power Switch A active in Corporate Plaza. Server Vault switch is dead (handle inert).
- State B: reverse.
- Effect: changes where you rush for power. Affects perk unlock order (power-gated perks).
- Weight: 50/50.

### Pack-a-Punch Approach

- State A: approach from Server Vault. Roof-side door welded shut.
- State B: reverse.
- Effect: after the PaP round, the Lab approach determines which zone you've already familiar with mid-run.
- Weight: 50/50.

### Wallbuy Pool Per Slot

**ARSENAL RESTRICTED (user, 2026-06-14): there are NO wall buys on the current map.**
Per the 2-gun arsenal directive (ICR-1 + Man-O-War only, both Mystery-Box-only), every wall
buy is removed at load by `_acc_map_randomizer::remove_all_wallbuys()` — it unregisters the
stub of each placed wall struct (the 5 gun/grenade walls *and* the Bowie melee wall) so no
purchase trigger is ever built. The per-run wallbuy randomization machinery
(`roll_wallbuy_pool`, `apply_wallbuy_pool`, etc.) was deleted with it. The historical
single-candidate slot plan below is kept only for when a future version re-expands the roster.

Historical slots (no longer wired — kept for reference):

- ~~**Service Alley shotgun**: Haymaker 12.~~
- ~~**Corporate Plaza AR (full-auto slot)**: ICR-1.~~ (now Box-only)
- ~~**Corporate Plaza AR (semi-auto slot)**: M14 EBR.~~
- ~~**Rooftop Helipad sniper**: Intervention.~~
- ~~**Server Vault tactical**: EMP Grenade.~~
- ~~**Near-perk melee upgrade**: Bowie Knife.~~

**What actually randomizes in wallbuys now**: *nothing* - there are no wall buys. Per-run variance comes from:

- Which Mystery Box pulls you land (bad/strong 50/50 per family).
- Which Overclocks roll at each tier-up.
- Which boss items drop.
- Which perks spawn at which perk-slot (see Perk Pool below).

Weights are first-draft and will tune against playtest feedback.

**Post-1.0 pool expansion** will add real wallbuy variance (e.g. Kuda / Weevil / Pharo SMG slot if we re-add SMGs).

### Perk Rotation (per round, at the Lab)

**All 9 perks are consolidated to the Lab** (4 perk machines). Machines re-roll to a random 4-of-9 **after each round’s [decontamination phase](03_layout.md#decontamination-zones-round-hazard) completes** — not at the first frame of the round. No duplicates in the rotation. No per-perk guarantees — Jug and Quick Revive are in the pool at equal weights with everything else.

- Probability Jug is in any given round's rotation: 4/9 ≈ 44%.
- Probability Jug is NOT offered for 5 consecutive rounds: (5/9)^5 ≈ 5.3%.
- **C(9, 4) = 126 distinct 4-perk rotations possible each round.** A 50-round run has 50 independent rolls.
- The player's skill becomes **route management** (Lab visits cost time) + **patience** (waiting for the right rotation) + **value recognition** (knowing which of the 4 offered is most worth buying).

The old per-run, distributed-across-zones perk model is removed. Variance now comes from per-round shuffles, not per-run slot draws. See [13_perks.md](13_perks.md) for the full spec including probability tables and tuning levers.

### Overclock Draw Per Tier-Up

Per weapon family (AR / Shotgun / Sniper; SMG + LMG pools dormant in v1.0), a weapon's Overclocks are **drawn at each Tier upgrade** (T1 through T5) from the family pool (no duplicates per weapon). Re-rolling costs 1 Data Shard.

- The *family pool* is stable and visible (players learn what's possible).
- The *rolled-per-tier-up* Overclock is random, so each weapon's build-path varies per run.
- Wonder weapon Overclocks: all 3 always active on use (built into the weapon, not tier-gated).
- This is the **largest single source of per-weapon run variance** and a key replayability lever.
- Previous design had "3 active-per-family-per-run"; that was superseded by the tier-unlock model described above. See [05_weapons.md](05_weapons.md#the-overclock-system) for the current rules.

### Hack Terminal Stage Composition

- Stage 1 is always "kill N zombies" (easy).
- Stage 2 rotates: (Shielded, Teleporter) - both unlocked at round 11+. Before round 11, it's "kill N zombies fast".
- Stage 3 rotates: (headshots, melee kills, trap kills). "Trap kills" only if we add traps (see Out of Scope).

### Mystery Box Spawn Weights

Standard BO3 box move behavior. Initial spawn is weighted per run across 3 possible spawn nodes (one per weapon-carrying zone: Market, Corp, Roof). Weights re-roll.

### Total Variance at Map Load

Rough count:
- Power switch: 2
- PaP approach: 2
- Wallbuy pool: ~300 combinations across 7 slots (product of pool sizes)
- Perk pool: ~60 combinations
- Overclock active pool: 5 families x C(pool, 3) = very large
- Mystery Box initial: 3

You never see the same opening twice. In practice, players will register the top ~10 archetype patterns and play into them.

## Tier 2 - Build Space (within-run decisions)

Covered in `04_progression_and_skills.md` (Cyberware) and `05_weapons.md` (Overclocks). Summary numbers:

- Cyberware end-state combinations: **27** (3 branches x 3 tier-2 choices x 3 tier-3 capstones, modulo not all combinations being coherent).
- Recognizable **build archetypes**: see below.
- Overclocks on active weapons: typically 2-3 slotted on 2-3 weapons = ~6-9 Overclocks shaping a single run.

### Build Archetypes (emergent, not enforced)

The three branches of Cyberware naturally produce three archetypes. You don't have to label your build, but these are the shapes that emerge:

1. **Overclock / "Sniper"** - single-target damage stacker. Pairs with Sniper or single-shot AR. Crit Overclock + Overload + Meltdown. High ceiling, low margin for error.
2. **Subroutine / "Economy"** - maximizes Shards and survivability. Pairs with AoE Overclocks (Swarm, Shrapnel, Meltdown), Payroll Ledger boss item, and Widow's Wine for grenade-heavy farming. Long, slow runs.
3. **Reflex / "Mobility"** - evasion + burst. Pairs with SMG or shotgun (fast handling) and Phase Step / Overdrive. High APM, big endgame upside via Overdrive stacking.

Mixed builds (e.g. Reflex Tier 1 + Subroutine Tier 2 + Overclock Tier 3) are legal and sometimes optimal - but emergent, not on-rails.

## Tier 3 - Modifiers

Toggled at map load, pre-run. Default off. Stack freely. Purely opt-in.

### "Harder" Modifiers (no Shard cost change)

- **Code Red**: elite spawn rate +50%. Zombie HP +20%.
- **Limited Liability**: no Jug available anywhere in the map. Yes, really.
- **Fragility**: players start with 50% max health. Jug restores baseline.
- **Bleed Out**: down timer halved (30s -> 15s).

### "Weirder" Modifiers (rule changes)

- **Draft Mode**: instead of buying perks, you're offered 3 random perks on a cycle every 2 minutes; pick one. No free perk re-picks.
- **Shardless**: no Data Shards drop. Cyberware and Overclocks are free-picked at preset interval (round 10, 20, 30). Pure weapon/Points game.
- **One Shot**: you get **one** Overclock slot across your entire arsenal. Forces weapon commitment.
- **Roguelike Lite**: every time you down, you lose your lowest-cost Cyberware node (not the Points refund, the actual node).

### "Faster" Modifiers (for short sessions)

- **Express**: start at round 10. Start with 5 Shards and 5000 Points.
- **Sprint**: zombie movement speed locked at max from round 1. **Disables** the baseline early-round `setmovespeedscale` boost from [`06_mechanics.md`](06_mechanics.md) (early pacing skips when `level.acc_mod_force_sprint` is set).
- **Shortened Rounds**: zombies per round x0.6.

### Achievement / Score Interaction

- Running with modifiers applies a **score multiplier** (e.g. x1.5 for Code Red, x1.3 for Fragility, x2 for stacked harder modifiers).
- Final-round scoreboard reflects modifiers, so runs can be compared meaningfully.
- **No in-map unlocks from modifiers.** We're avoiding persistent meta-progression (see below).

## Persistent Meta-Progression (explicit stance: minimal)

Stock zombies has almost none; we don't want to inflate that much. Here's the entire meta layer:

- **Personal best round** per modifier-set, saved locally.
- **"Mastery" counter** per build archetype (rounds reached with each archetype). Purely cosmetic flex, no in-game effect.
- **Completion flags** for side objectives ("completed Vault Overload 10 times"). Again, no in-game effect.

**Why not more?** Persistent power unlocks (Ameliorama-style long-term currency) would dilute the in-run skill-and-decision loop. Every run should feel complete on its own. Meta exists for bragging, not for power creep.

## Tuning Philosophy

- **Randomization is a *spice*, not a *meal*.** The *systems* do the heavy lifting; randomization adds freshness.
- **Never randomize where players expect determinism.** Door costs, PaP cost, perk cost, zombie round formula - fixed. Wallbuy *gun*, perk *identity per slot*, Overclock *pool* - varied.
- **A player who knows the map inside-out should still have surprises every run.** Because the *space of possibilities* is known but the *specific roll* isn't.
- **Modifiers are where we experiment.** If a base-game mechanic might be too harsh, we test it as an opt-in modifier first.

## Out of Scope (explicitly, for v1.0)

- **Traps**: not in v1.0. Too much asset/animation work. Revisit post-release.
- **Random map geometry**: no procedural layouts. Expensive, breaks readability.
- **Persistent rank/unlock system**: see above.
- **Custom game modes beyond modifiers**: no "domination vs zombies" or similar. Future DLC territory.
- **Seeded runs**: if we ship, I want to add this post-1.0 - paste a seed to get the same map state for speedrunning.
