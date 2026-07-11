# 06 - Replayability

The explicit systems that make run N+1 meaningfully different from run N, without sacrificing fairness.

## Three Tiers of Variance

Ordered from "subtle" to "radical":

1. **Per-run / per-round variance** - re-rolls come from the box, the perk rotation, and boss drops. Small but pervasive. Default-on.
2. **Build space** - your weapon-Tier / Overclock decisions within a run. Large expressive space. Driven by player choice + Shard RNG. *(The Cyberware skill tree was designed as a co-equal build lever but is currently **disabled** — see Tier 2 below.)*
3. **Modifiers** - optional opt-in rule changes (dvar-toggled). Radical changes to rules. Default-off.

## Tier 1 - Per-Run / Per-Round Variance

Documented so players can learn the *space* of randomization, not guess.

> **What is NOT randomized anymore (retired map-load rolls):** early drafts randomized the
> **power-switch side** and the **Pack-a-Punch approach corridor** per run. Both were removed:
> - **Power switch:** the map now ships a **single** stock switch (Bus Station / "corp"). The Vault switch prefab was deleted from the map source (user 2026-06-18); `_acc_map_randomizer::apply_power_switch_side()` is now a safety no-op — there is nothing to delete.
> - **PaP approach:** `_acc_map_randomizer::apply_pap_approach()` **opens both** Lab corridors every run (user 2026-06-22); the old random path-blocking wall read in-game as a "broken door" and was cut. `blocked_side` is rolled but ignored.
>
> So the layout is now **fixed**; per-run freshness comes from the box, the perk rotation, and boss drops below.

### Wallbuys - five fixed buys, no randomization

**MOSTLY box-only, with FIVE fixed wall-buys (user, 2026-06-23; AK-47 added 2026-06-26; M60 added 2026-06-27; was "no wall buys" 2026-06-14).**
The map is box-first, but five wall-buys are permanent fixtures. `_acc_map_randomizer::remove_all_wallbuys()`
whitelists these five weapon names (skips removing their stubs) while stripping every other wall-buy at load
(`_acc_map_randomizer.gsc:870-879`):

| Weapon | Token | Location | Cost |
|--------|-------|----------|------|
| Five-Seven | `t6_fiveseven` | Lab | 500 |
| Olympia | `t6_olympia` | Bus Station | 500 |
| Frag grenade | `frag_grenade` | Spawn | 100 |
| AK-47 | `t9_ak47` | Abyss Layer 4 ("4th floor" trench, z≈-960) | 1500 |
| M60 | `t9_m60` | Abyss Layer 5 ("bottom floor", before Paradise) | S-tier |

The AK-47 and M60 are S-tier buys planted deep in the pit deliberately, to pull players down the
Abyss Descent. They're placed as stock `weapon_upgrade` struct pairs in the `.map`; the stock system gives
buy-gun → buy-ammo (price keyed to PaP level) for free. **These five are FIXED, not randomized** — the old
per-run wallbuy-pool machinery (`roll_wallbuy_pool`, per-slot single-candidate draws) is gone.

**What randomizes in wallbuys now:** *nothing*. Per-run variance comes from:

- Which Mystery Box pulls you land.
- Which boss items drop.
- Which perks open at the Lab this round (see Perk Rotation below).

**Post-1.0 pool expansion** may add real wallbuy variance (e.g. a Kuda / Weevil / Pharo SMG slot if we re-add SMGs).

### Perk Rotation (per round, at the Lab)

**All 10 perks live in the Lab alcoves** (Electric Cherry is the real 10th, `_acc_perk_electric_cherry`).
A **random 4 of the 10 alcove doors open each round** and the rest stay walled off; the open set
**re-rolls at the start of every round** (`_acc_perk_doors::watch_rounds` → `apply_round`, woken by
`acc_round_start`). No immediate repeats — the previous round's open set is excluded from the next roll
(`candidates_excluding_last`, `_acc_perk_doors.gsc:212-215`). A door bought open stays permanently unlocked
and drops out of the roll. No per-perk guarantees — Jug and Quick Revive are in the pool at equal weight.
`ACC_PERK_DOORS_OPEN_PER_ROUND = 4`, over 10 perks (`_acc_perk_doors.gsc:50`).

- Probability Jug is open in any given round: 4/10 = 40%.
- Probability Jug is NOT offered for 5 consecutive rounds: (6/10)^5 ≈ 7.8%.
- **C(10, 4) = 210 distinct 4-perk rotations possible each round.** A 50-round run has ~50 independent rolls.
- The player's skill becomes **route management** (Lab visits cost time), **patience** (waiting for the right rotation), and **value recognition** (which of the 4 open is most worth buying).

Dev mode runs the same per-round 4-of-10 rotation as normal play (user 2026-07-07). The old per-run,
distributed-across-zones perk model is removed. See [10_perks.md](10_perks.md) for the full spec.

### Weapon Tier / Overclock progression (deterministic, not a random draw)

**This is a build-investment lever, not a map-load randomizer.** Each weapon tracks a **Tier from 0 to 10**
per player; each tier costs `+4` Shards (4 / 8 / 12 … / 40, **220 to max one gun** — `_acc_overclocks.gsc:36-48`).
The Tier scales four fixed effects in `_acc_damage` (flat damage, glitch pierce, ammo refund, shield-pierce) —
**there is no per-tier random roll.** The earlier "random Overclock drawn per tier-up from a family pool"
model and the "3 active-per-family-per-run" model before it were both **abandoned**: the family pools
(`build_family_pools`) and their `apply_oc_*` helpers are **dead, unreferenced code** kept only as a stub
(`_acc_overclocks.gsc:163-167`). So Overclocks add **build depth**, not per-run randomness. See
[04_weapons.md](04_weapons.md#the-overclock-system) for the current rules.

### Hack Terminal Stage Composition

Current greybox 3-stage set (`_acc_events_hack::build_stages`, `_acc_events_hack.gsc:238-265`):

- **Stage 1 - Channel:** hold [USE] to breach the firewall (6-8 s hold, 30 s window).
- **Stage 2 - Survive:** survive a trace; **kills purge it faster** (10-15 kills). At round 11+, the deep trace
  requires **headshot-only** purge kills (`flavor == "headshot"`).
- **Stage 3 - Channel:** return to the terminal and hold [USE] to confirm.

The richer docs/05 kill-stage rotation (Shielded / Teleporter elite waves, melee/trap-kill stages) is a
**TODO(acc-design)**, not yet built — the header note at `_acc_events_hack.gsc:24-26` tracks it. Trap-kill
stages are out of scope while traps are (see Out of Scope).

### Mystery Box Spawn Weights

Standard BO3 box move behavior. There are **six** box spots — Plaza, Lab, Market, Bus Station (Corp),
Helipad (Roof), Vault — each backed by an `acc_box_<node>` chest pair (script_struct `treasure_chest_use`
+ a `<node>_zbarrier`) in the `.map`. The **initial** spawn is **always the Plaza** (start room) —
deterministic every run (`roll_mystery_box_initial` returns `"plaza"`, `_acc_map_randomizer.gsc:671-685`),
so the first box is always where players spawn in; after that the stock `_zm_magicbox` teddy-bear move
rotates the single box randomly among **all six** spots (only the start node is pinned). The start node
must have a chest or stock hides all boxes, and the Plaza always does.

**No duplicates (2026-06-14):** the box never hands out a gun you already hold. The draw is filtered
(via `level.CustomRandomWeaponWeights` → `acc_box_only_weapon_keys`, `_acc_map_randomizer.gsc:352`) to
box-flagged weapons the player does not own *in any form* — base, Pack-a-Punch, or a perk-variant twin
(compared by `acc_weapon_variants::true_base`, so holding a Deadshot `s1_tac19_acc_recoil35` correctly
counts as owning the TAC-19). This covers the stock `keys[0]` fallback **and** the twin gap that stock
`has_weapon_or_upgrade` misses. Only edge case: if you own every available box gun, the box falls back to
a duplicate (max-ammo refill) — unavoidable since the box must give something. Draw is weighted per-gun
tier (`acc_box_weight`; wonder weapons pinned to ~1% rolls, boosted by a Lucky Clover).

### Per-run variance summary

- Layout (power switch, PaP approach): **fixed** (1 combination — both retired).
- Wallbuys: **fixed** (5 buys, no roll).
- Mystery Box: initial always Plaza; then rotates among all 6 spots, weighted by gun tier, filtered no-dupe.
- Perk rotation: **210 distinct 4-of-10 door sets per round**, re-rolled every round.
- Boss item drops + boss-type deck (see [09_boss_items.md](09_boss_items.md), [08_enemies.md](08_enemies.md)).

The map layout is the same every run; the *box pulls, per-round perk offer, and boss drops* keep runs fresh.

## Tier 2 - Build Space (within-run decisions)

The live within-run build lever is the **weapon Tier / Overclock terminal** — see
[04_weapons.md](04_weapons.md#the-overclock-system). The **Cyberware skill tree** described in
[03_progression_and_skills.md](03_progression_and_skills.md) was designed as a co-equal lever but is
**currently disabled** (dormant note below), so within-run build depth today comes entirely from weapon Tiers.

- Weapon Tiers: ~220 Shards to max one gun (T0→T10); you typically deep-tier 1-2 guns per run.

> **Cyberware tree — dormant / disabled (user 2026-06-19).** The 9-node Cyberware skill tree (3 branches x 3
> tiers; designed end-state combinations: **27** = 3 branches x 3 tier-2 choices x 3 tier-3 capstones, modulo
> not all being coherent) was **removed from play**: the weapon Overclock terminal is now the sole upgrade, the
> kiosk is no longer spawned, and node purchase is gated behind `acc_cyberware_on` (default **0**), so players
> cannot buy nodes in a normal run (`_acc_cyberware.gsc:92-97`). The module stays loaded (its damage-flag
> readers are harmless no-ops with no nodes bought). The archetypes and 27-combination math below describe that
> dormant tree, kept as design intent for a possible re-enable.

### Build Archetypes (design intent — the dormant Cyberware tree)

Were the Cyberware tree re-enabled, its three branches would naturally produce three archetypes. You don't have to label your build, but these are the shapes it was designed to emerge:

1. **Overclock / "Sniper"** - single-target damage stacker. Pairs with Sniper or single-shot AR. High ceiling, low margin for error.
2. **Subroutine / "Economy"** - maximizes Shards and survivability. Pairs with the Payroll Ledger boss item and Widow's Wine for grenade-heavy farming. Long, slow runs.
3. **Reflex / "Mobility"** - evasion + burst. Pairs with SMG or shotgun (fast handling) and Phase Step / Overdrive. High APM, big endgame upside.

Mixed builds (e.g. Reflex Tier 1 + Subroutine Tier 2 + Overclock Tier 3) were legal in the tree's design and sometimes optimal - but the tree is dormant today, so the only live within-run build choice is weapon-Tier / Overclock-terminal investment (which most resembles the single-target "Sniper" shape).

## Tier 3 - Modifiers

**Opt-in rule changes, toggled via dvar.** A modifier is enabled by setting `acc_mod_<name> 1`, read
**once** at map load in `_acc_modifiers::pre_init` → `load_modifiers_from_config`
(`_acc_modifiers.gsc:54-83`). Default off; stack freely. A main-menu toggle UI is **not built**
(`TODO(acc-config)` / `TODO(acc-ui)` in the module) — the dvar is the current mechanism.

**Implementation status:** the framework and the following effects are **live** — Fragility (per-player HP
cut, `on_player_connect`), Bleed Out (down-timer mult, consumed in `_acc_cyberware.gsc:878`), Sprint
(`level.acc_mod_force_sprint`, consumed by `_acc_zombie_speed` / `_acc_early_round_pacing`), and Express
(round-10 start + bonus, `express_start`). The others below set a `level.acc_mod_*` field that **no consumer
reads yet** (Code Red HP/elite rate, Limited Liability no-jug, One Shot) or run **stub loops** with
`TODO`s (Draft Mode, Shardless, Roguelike Lite). Treat the un-wired ones as design intent, not shipped.

### "Harder" Modifiers

- **Code Red** (`acc_mod_code_red`): elite spawn rate +50%, zombie HP +20%. *(fields set; not yet consumed)*
- **Limited Liability** (`acc_mod_limited_liability`): no Jug anywhere. *(field set; not yet consumed)*
- **Fragility** (`acc_mod_fragility`): players start with 50% max health. **Live.**
- **Bleed Out** (`acc_mod_bleed_out`): down timer halved. **Live** (via cyberware down-timer math).

### "Weirder" Modifiers

- **Draft Mode** (`acc_mod_draft_mode`): offered 3 random perks every 2 minutes; pick one. *(loop runs; picker UI is a TODO)*
- **Shardless** (`acc_mod_shardless`): no Shards drop; free Cyberware picks at rounds 10/20/30. *(loop runs; picker UI is a TODO)*
- **One Shot** (`acc_mod_one_shot`): one Overclock slot across your whole arsenal. *(field set; not yet consumed)*
- **Roguelike Lite** (`acc_mod_roguelike_lite`): every down removes your lowest-cost Cyberware node. *(watcher runs; node removal is a TODO)*

### "Faster" Modifiers

- **Express** (`acc_mod_express`): start at round 10 with 5000 Points + 5 Shards. **Live.**
- **Sprint** (`acc_mod_sprint`): zombie speed locked at max from round 1; disables the early-round `setmovespeedscale` boost from [05_mechanics.md](05_mechanics.md). **Live** (`level.acc_mod_force_sprint`).
- **Shortened Rounds** (`acc_mod_shortened_rounds`): zombies per round x0.6. *(field set; not yet consumed)*

### Achievement / Score Interaction (planned, not built)

- A **score multiplier** for running with modifiers (e.g. x1.5 Code Red) is **design intent only** — there is no `score_mult` code anywhere in `scripts/` yet.
- Intended goal: the final-round scoreboard reflects modifiers so runs can be compared meaningfully.
- **No in-map unlocks from modifiers.** We avoid persistent meta-progression (see below).

## Persistent Meta-Progression (stance: minimal — and currently NONE)

Stock zombies has almost none; we don't want to inflate that. The intended (but **not yet built** — no
`personal_best` / `mastery` / completion-flag code exists in `scripts/`) meta layer is deliberately tiny:

- **Personal best round** per modifier-set, saved locally. *(design intent, unbuilt)*
- **"Mastery" counter** per build archetype. Cosmetic flex, no in-game effect. *(design intent, unbuilt)*
- **Completion flags** for side objectives. No in-game effect. *(design intent, unbuilt)*

**Why not more?** Persistent power unlocks (long-term currency) would dilute the in-run skill-and-decision loop. Every run should feel complete on its own. Meta exists for bragging, not for power creep.

## Tuning Philosophy

- **Randomization is a *spice*, not a *meal*.** The *systems* do the heavy lifting; randomization adds freshness.
- **Never randomize where players expect determinism.** Door costs, PaP cost, perk cost, zombie round formula, and now the map *layout* itself - all fixed. The box gun and the per-round perk offer - varied.
- **A player who knows the map inside-out should still have surprises every run.** Because the *space of possibilities* is known but the *specific roll* isn't.
- **Modifiers are where we experiment.** If a base-game mechanic might be too harsh, we test it as an opt-in modifier first.

## Out of Scope (explicitly, for v1.0)

- **Traps**: not in v1.0. Too much asset/animation work. Revisit post-release.
- **Random map geometry**: no procedural layouts. Expensive, breaks readability.
- **Persistent rank/unlock system**: see above.
- **Custom game modes beyond modifiers**: no "domination vs zombies" or similar. Future DLC territory.
- **Seeded runs**: post-1.0 nice-to-have - paste a seed to reproduce a run for speedrunning.
