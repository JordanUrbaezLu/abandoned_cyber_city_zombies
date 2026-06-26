# 06 - Mechanics

Deep-dive on the systems that make the map tick. If `04_progression_and_skills.md` is the "what", this is the "how it actually plays moment to moment".

## Round & Pacing Model

A zombies round has an implicit structure; we make ours explicit and tune each phase.

```mermaid
flowchart LR
    Prep[Prep phase<br/>5-8s, no zombies] --> Spawn[Spawn phase<br/>zombies appear in waves]
    Spawn --> Combat[Combat phase<br/>player cleans up]
    Combat --> Bleed[Bleed phase<br/>last 1-3 zombies]
    Bleed --> Prep
```

We tune two levers that stock BO3 mostly leaves alone:

### 1. Spawn Cadence, Not Just Count

Stock BO3 spawns zombies in small batches gated by alive-count. We keep that but **add deliberate "pressure pulses"**: every 3rd round past round 10, an extra wave of 8-12 zombies spawns at the ~50% mark of the round. This prevents the late-game from being "train for 2 minutes, kill the last 3".

### 2. Elite Timing

Elites don't just spawn randomly. They spawn **at inflection points**:

- Shielded elites spawn **at the end of a wave**, forcing you to shift from chaff clearing to priority targeting.
- Teleporters spawn **during a wave**, splitting your attention.
- EMP elites spawn **just before bleed**, preventing the lull.

This means the **texture** of a round is predictable (you can plan) but the **moment** is tense (you must execute).

### 3. Early round pressure (rounds 1–4)

Stock BO3 front-loads a slow walk phase; we **compress that window** so the first minutes are a real setup phase (doors, training lanes, Shard routing) instead of idle cleanup. **Lab perk lineup** updates only **after** [decontamination](03_layout.md#decontamination-zones-round-hazard), not at round start.

| Lever | Rule |
|---|---|
| **Spawn count** | Multiply stock `[[ level.max_zombie_func ]]( n_max, n_round )` output: **×1.50** on round **1**, **×1.45** on rounds **2–4** (integer **ceil**). From round **5**, multiplier **×1.0**. Other systems (e.g. **Shortened Rounds** modifier) multiply on top of this. _(Moderate spawn-intensity tune, 2026-06-18 — up from ×1.40/×1.35.)_ |
| **Move speed** | On zombie AI spawn, apply **`setmovespeedscale( 1.15 )`** for rounds **1–4** (stacks with stock anim tier). **Sprint** modifier skips this boost (see `07_replayability.md`). |

**Code**: [`_acc_early_round_pacing.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_early_round_pacing.gsc) — `post_zm_main()` chains `level.max_zombie_func` from `scripts/zm/zm_abandoned_cyber_city.gsc` after `zm_usermap::main()`, still inside `main()` so the chain exists before round 1; `init()` registers `callback::on_ai_spawned` for speed. Constants: `ACC_EARLY_SPAWN_MULT_R1`, `ACC_EARLY_SPAWN_MULT`, `ACC_EARLY_SPEED_SCALE`, `ACC_EARLY_ROUND_MAX`.

### 4. Decontamination before Lab perk rotation

Each round’s **script order** (see [03_layout.md](03_layout.md)):

1. **`acc_round_start`** (or stock `start_of_round`) — round counter advances; zombies can spawn per stock rules.
2. **Decontamination** — one eligible zone (Market, Alley, Vault, or Roof) is declared contaminated per the run’s seal schedule; **20s** to evacuate or die; zone **seals permanently** (rounds **1–4** only for new seals).
3. **`acc_decontamination_complete`** — safe to update machine states that assume players are not mid-evacuation.
4. **Lab perk re-roll** — `roll_perk_rotation()` runs; Lab machines show the new **4-of-9** lineup.

Rounds **5+** still emit **(2)** with **no new permanent seal**, but the **20s** window may be **0s** or skipped in implementation — perk roll still waits for the **complete** notify so one code path handles all rounds.

## Point Economy

Stock BO3 kill awards are **replaced** (not modified) by our own table:

| Kill type | Points |
|---|---|
| Regular kill | 70 |
| Headshot kill | 110 |
| Knife / melee kill | 100 |

Stock BO3 per-hit points (10 per damaging hit) are kept unchanged.

### Why these numbers

- Regular-kill points **70** (user 2026-06-23: raised 40 -> 70, above the stock 60 for a generous body-kill economy).
- Headshot **110** / knife **100** (user 2026-06-23: headshot 100 -> 110) as the payout for skill-expressing kills.
- ~1.57x multiplier from regular -> headshot still means **aiming is worth it even when you're not stacking Overclocks**.
- Combined with the 2.5x headshot damage multiplier (see "Headshot Multiplier" above), a skilled aim player earns both more points *and* more kills per minute.

### Co-op Kill-Point Split (70 / 30)

When a zombie is killed, the point award is distributed:

- **Killer**: gets **70%** of the kill's base points.
- **Other qualifying damage contributors**: split the remaining **30%** equally among themselves.
- **Solo (no other qualifying contributors)**: the killer gets **100%**. No penalty for playing solo.

**Payouts are quantized to 10-point units** - a verified BO3 engine constraint:
the stock score API rounds every award UP to a multiple of 10
(`_zm_score.gsc:528`; see [19_stock_api_verification.md](19_stock_api_verification.md)),
so shares are computed in 10-pt chunks with leftover chunks going to the
earliest contributors. Totals across players always equal the full base award
exactly (no inflation; no rounding exploit). The killer's 70% rounds to the
nearest 10.

**Multipliers (Double Points, Payroll Ledger) are re-applied by us.** Because we
**replace** the stock kill award (our `register_score_event` callback returns 0),
the stock score path where Double Points applies its ×2 (`_zm_score::get_points_multiplier`)
never sees our points. So `award_player` re-applies the same team-scoped
`zombie_point_scalar` the powerup sets (×2 while active) **before** the Payroll
Ledger's +10%, so the two stack multiplicatively (×2.2 with both). Any future
points-affecting powerup that works through the stock score-event path will
likewise need re-applying here. (Bug history: Double Points silently did nothing
on kills until this was added, 2026-06-23.)

Example payouts (regular kill = 40 pts base; killer share 28 → 30):

| Players who contributed | Killer gets | Others get | Total granted |
|---|---|---|---|
| Killer only (solo) | 40 | - | 40 |
| Killer + 1 other | 30 | 10 | 40 |
| Killer + 2 others | 30 | 10 / 0 | 40 |
| Killer + 3 others | 30 | 10 / 0 / 0 | 40 |

Same split for a 100-pt headshot or knife kill (killer share = 70):

| Players who contributed | Killer gets | Others get | Total granted |
|---|---|---|---|
| Killer only | 100 | - | 100 |
| Killer + 1 other | 70 | 30 | 100 |
| Killer + 2 others | 70 | 20 / 10 | 100 |
| Killer + 3 others | 70 | 10 / 10 / 10 | 100 |

On a low-value kill some contributors can receive 0 (the pool only has one
10-pt chunk) - acceptable: headshot/knife kills are where assist money lives,
and the 5% qualification bar below still gates who is in the pool at all.

### Anti-Exploit Rules (hard-enforced in code)

The split system is a natural target for cheese. Every rule below is enforced in `_acc_points.gsc`.

1. **Per-player damage is capped at the zombie's max HP.** Overshooting a dying zombie doesn't inflate your damage share. Example: regular zombie has 150 HP. Player A deals 500 damage with a PaP'd AK-47 pre-kill. Recorded contribution: 150, not 500.
2. **Minimum contribution threshold: 5% of zombie max HP** to qualify for a share. This kills the "tag-and-run" exploit where you hit every zombie with 1 damage and vulture a share on everything. A 150-HP zombie requires 7.5 damage from a player for that player to count.
3. **Only player-sourced damage counts.** Environmental kills (fall damage, fire, etc.) and AI-sourced damage (if any exotic setup) do not create a damage record.
4. **Per-player aggregation.** The same player's shots on the same zombie sum to one record. You cannot inflate "contributor count" by switching weapons, reloading, etc.
5. **Disconnected / invalid players at payout time are skipped.** If a player contributed 50% of damage then disconnected, the 30% pool redistributes among remaining qualifiers; nobody "inherits" the disconnected player's share, and no share is dropped on the ground.
6. **Killer-rule overrides.** If the killer is somehow invalid (disconnected in the same frame they fired the killing shot - rare but possible), the full base is split equally among remaining qualifiers as a fallback. No points are lost.

### Exploits we explicitly chose NOT to defend against

- **Coordinated kill-stealing.** Player A softens a zombie to 20 HP with an AK-47, Player B knifes it for a 100-point knife kill. Player B gets 70. Player A only contributed damage, so they get 30. **This is intended as a coordinated play**, not an exploit. If you and a teammate want to split roles (suppressor + finisher), the math supports it.
- **Headshot-hunt coordination.** Similar to above: one player tickles the zombie down, the other headshots for 100. Intended.

### Stock-Award Override Status

The module intends to **fully replace** stock kill awards. Stock BO3 awards 60/100/130 per kill via `_zm_score::player_killed_event` (or similar). At first compile the override is not yet wired - players may receive stock + our awards (double). First-playtest fix; TODO marker in [`_acc_points.gsc::init()`](../scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc).

### Design Interaction Notes

- **Widow's Wine perk** (see [13_perks.md](13_perks.md)): grenade damage boost applies to the grenade owner, so splash kills via Widow's-boosted frags still feed the 70/30 split normally. The perk doesn't bypass the split; it just makes those grenades more likely to land the final blow.
- **Deadshot perk** (see [13_perks.md](13_perks.md)): the 1.4x headshot bonus is per-player — only applies to the shooter's damage, not the share others earn from a Deadshot player's kill.
- **Meltdown capstone** (AoE kills from Cyberware tier-3 Overclock branch): the AoE kill from Meltdown still counts as "the caster's kill" for point purposes (the AoE source is the weapon; the player who fired is the killer).
- **Multi-kill bonus (+50 per extra zombie killed within 0.5s)**: previously part of this doc's Point Economy section - **cut for now** to keep the point system surface area small. The 2x headshot multiplier plus the precision weapon tier (FAL, Drakon, Intervention) already rewards the playstyle a multi-kill bonus was targeting. Re-add as a modifier in `_acc_modifiers.gsc` if playtest feedback wants it.

### Data Source

- Points module: [`scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_points.gsc).
- Damage recording is fed from `_acc_damage.gsc::on_ai_damage`, which calls `_acc_points::record_damage` on every player-sourced hit.

## Headshot Multiplier (skill lever)

Each gun's GDT carries a hit-location multiplier (`locHead`/`locHelmet`), **normalized across the whole roster to 5.0** (headshot-excluded shotguns = 1.0) by `tools/normalize_gun_loc.js`. The engine bakes that into the incoming damage; `_acc_damage.gsc` then applies our **headshot temper** as a SEPARATE multiplicative factor (`n_hs_temper`):

- **Regular zombies + elites**: `ACC_HEADSHOT_MULT = 0.5` → `5.0 × 0.5` = **2.5× body** (user 2026-06-25).
- **Bosses (mini-boss + full boss)**: `ACC_BOSS_HEADSHOT_MULT = 0.6` → `5.0 × 0.6` = **3× body** (user 2026-06-25).
- **Limb / body hits**: untouched (stock).
- **Headshot-excluded guns** (Tac-19 / Olympia, `locHead 1.0`): no map bonus → **1× (flat)**.

| Target | Body shot | Head shot (ours) |
|---|---|---|
| Regular zombie / elite | 1.0x | **2.5x** |
| Boss / mini-boss | 1.0x | **3.0x** |

### Why it's a skill lever

- Spray-and-pray players barely notice the change - most of their rounds go center-mass.
- Aim-focused players effectively **double their damage-per-bullet** against chaff, letting them clear rounds faster, conserve ammo, and spend more time on positioning.
- **Boss fights become aim tests.** A 30-round Subroutine Core with clean headshots dies in ~60% the time it would from body shots. Miss, spray, and the fight drags into phase-3 power/perk debuffs (see Boss phases in [11_enemies.md](11_enemies.md)) which can snowball into a wipe.

### Stacking with Perks / Cyberware / Overclocks

**Bonuses ADD, reductions multiply.** Damage *bonuses* (Deadshot, Cyberware, PaP tier, abilities) are summed into one bonus factor — a literal sum, so a 1.3x and a 1.3x give **2.6x, not 1.69x**. The **headshot temper is NOT in that sum** — it's a separate multiplicative factor (×0.5 reg / ×0.6 boss, on top of the engine `locHead`), so it tempers ONLY the loc-inflation, not the PaP/Deadshot/Cyberware bonuses (that's what keeps a PaP headshot a clean 2.5x of the boosted body instead of ballooning). Damage *reductions* (per-gun balance cuts, shielded-elite frontal resist, boss per-hit cap) stay multiplicative and apply last: `final = damage × locHead × (bonus sum, or 1 if none) × headshot_temper × reductions`.

Bonus layers summed on a single headshot (each ADDS its value into the pool):

- **Deadshot perk** (1.3, or 1.5 with American Sniper Mega — no double dip; see [13_perks.md](13_perks.md))
- Cyberware **Amplifier (OC Tier 1)** (`+15%` weapon damage) — 1.15
- Cyberware **Overload (Tier 2 OC branch)** (`+30%` crit damage on headshots) — 1.30
- **PaP custom tier** (1.33 / 1.67 / 2.00 for T1–T3; the `_up` transform is deferred to T2, and `acc_weapon_balance_mult` normalizes base/`_up`/twin so this ladder is the only PaP damage lever)
- Weapon **Overclock** if rolled (e.g. AR **Overpressure** at 1.5 ADS)
- Weapon ability **Precision Mode** (auto-crit = 4.0) / **Slug Round** (3.0) / **Kinetic Battery** (3.0) when active

(Base weapon damage and the stock ~1.5x weapon-GDT headshot mult are already baked into the incoming `damage` before any of this.)

Because bonuses ADD instead of multiply, big stacks no longer explode geometrically — e.g. a regular-zombie headshot with Mega Deadshot (1.5) + Overload (1.30) + PaP T3 (2.0) sums the pool to 4.8, then `× locHead 5.0 × temper 0.5` = **12× the raw body shot** — strong, but not the ~100x a geometric stack would reach. **Intended** — rewards the precision archetype without runaway multiplication.

### Deadshot Effective Damage Table (with our multiplier)

Effective head:body with Deadshot (no PaP/Cyberware in the pool). Deadshot ADDS into the bonus pool, which the headshot temper (×0.5 reg / ×0.6 boss) then scales on top of the engine `locHead 5.0`:

| Target | Body | Headshot (no Deadshot) | + Deadshot (1.3) | + Mega Deadshot (1.5) |
|---|---|---|---|---|
| Regular zombie / elite | 1.0x | **2.5x** | 5.0 × 1.3 × 0.5 = **3.25x** | 5.0 × 1.5 × 0.5 = **3.75x** |
| Boss / mini-boss | 1.0x | **3.0x** | 5.0 × 1.3 × 0.6 = **3.9x** | 5.0 × 1.5 × 0.6 = **4.5x** |

Layer on the full Cyberware/Overclock/PaP stack (all summed into the bonus factor) and the precision-on-head build still scales hard, but additively rather than geometrically. Playtest will tell us if this is fun or broken; tuning levers in [13_perks.md](13_perks.md).

### Synergistic Overclocks

- **Adaptive Aim (AR)**: headshots refund one round to the magazine. The 2.5x headshot damage + ammo refund makes clean aim functionally infinite at range.
- **Thermal Lock (Sniper)**: 0.5s aim guarantees a headshot hitbox. Cashes in our 2.5x cleanly.
- **Reactive Powder (Sniper)**: headshots deal 50% AoE damage - AoE is of the *buffed* headshot damage, so it scales with our multiplier too.

### Implementation

Hook is `scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc::on_ai_damage`. Multiplier constants are at the top of that file for easy tuning without a docs round-trip.

### Tuning backstop

If the headshot bonus feels broken in playtest (likely for snipers / FAL), we can:

- Knock regular and boss down (regular is 2.5x, boss 3.0x now).
- Or split by elite class: regular 2.5x, elites 1.5x (bullet sponges feel less silly).
- Or flip the boss rule: bosses get NO extra headshot bonus, but they have an exposed "crit spot" that takes a larger one.

Decision deferred to Phase 6 playtest.

## Data Shard Economy (detailed flow)

**Data Shards are a TRENCH-ONLY economy (user, 2026-06-19).** Every shard the run produces comes from
descending into the dangerous underground trench — there is no topside faucet. This is the whole point of
the trench: it is the dangerous place, and shards are the reward for braving it. The loop is fully
underground — you earn in the exposed pit and spend in the Foundry room.

```mermaid
flowchart LR
    Pit[Pit Data Caches<br/>exposed, re-arm/round, scale w/ round] --> Bank[self.acc_data_shards]
    Warden[Trench Warden kill] --> Bank
    Altar[Glitch Altar jackpot] --> Bank
    Bank --> Skill[Cyberware kiosk]
    Bank --> OC[Overclock terminal]
    Bank --> AltarSpend[Glitch Altar gamble]
    Bank --> Emergency[Emergency drop]
```

- **SOURCE — Pit Data Caches:** two caches sit on the open trench-pit floor (the amped-horde danger zone,
  reached for free off the stairs — no door). Each pays once per round to the first looter, then shows
  "depleted" and re-arms next round. Yield **scales with the round** (`cache_yield`: base + 1 per
  `acc_cache_scale_rounds`, capped at `acc_cache_yield_max`) so the faucet keeps pace with rising costs.
- **SOURCE — Trench Warden:** the recurring trench boss grants `acc_warden_shard_reward` shards to every
  player on death.
- **SOURCE — Glitch Altar:** the jackpot boon (net-negative EV — see below).
- The **topside elite drop is OFF by default** (`acc_elite_shard_drop` 0); flip it on to restore the old
  1-shard corpse pickup if you want a surface trickle.

### The Foundry (where shards are spent)

All the deep sinks live in the enclosed underground room, entered from the pit through the buyable
`enter_under_plaza` door (1500 points — a one-time investment to unlock your spend hub): the **Cyberware
kiosk**, the **Overclock terminal**, and the **Glitch Altar**. So you brave the pit to *earn*, then duck
into the room to *spend* without surfacing. (The Cyberware/Overclock sinks also have surface fallback
triggers in the Lab.)

> **Note (2026-06-19):** the old elite-kill *diminishing-returns* rule below is now inert — elites are no
> longer a default shard source, and the DR branch was gated on a `source_tag` that was never produced. Kept
> for historical context; the anti-farm pressure now comes from the trench danger + per-round cache re-arm.

### Diminishing Returns (historical — now inert)

- Past round 10, elite Shard yield is normal.
- Between rounds 1-10, elite Shard drops reduce to 50% after the second elite kill that round.
- The Subroutine Tier 1 passive (+1 Shard per 2 min) has **no cap**, so a skilled run that stays long on a round still nets value.

## Risk/Reward Events

### Hack Terminal (Bus Station)

State machine:

```mermaid
stateDiagram-v2
    [*] --> Available
    Available --> Active: player interacts (cost 500 points)
    Active --> Success: complete 3 minigame stages<br/>(each: kill N specific enemies within T seconds)
    Active --> Failed: miss a stage timer
    Success --> Consumed: reward 2 Shards + 1 Overclock roll
    Failed --> Locked: penalty wave spawns
    Locked --> [*]
    Consumed --> [*]
```

- **Stage 1**: kill 10 zombies within 40 seconds. Easy baseline.
- **Stage 2**: kill 3 Shielded elites within 60 seconds. Forces elite uptime.
- **Stage 3**: kill 15 zombies using headshots within 45 seconds. Skill check.

Each stage runs back-to-back. Fail at any stage and the terminal is locked for the run. Success is one of the cleanest Shard/Point returns available.

**Parallel Processing** (Subroutine Tier 2) allows a second attempt; the second attempt stages rotate (different elite types, different zombie counts) so it's not a replay.

### Vault Overload (Vault)

90-second hold event. Player stands on a point; leaving the point pauses progress.

```mermaid
stateDiagram-v2
    [*] --> Idle
    Idle --> Active: player interacts (cost 1000 points)
    Active --> Wave1: 0-30s normal wave
    Wave1 --> Wave2: 30-60s + 1 elite type forced
    Wave2 --> Wave3: 60-90s + 2 elite types forced
    Wave3 --> Success: 3 Shards + map shortcut unlock
    Active --> Failed: player leaves point >8s
    Failed --> Locked: takedown wave (3 elites of each type spawn at once)
    Locked --> [*]
    Success --> [*]
```

- You **can** leave the point briefly (≤8s) to reposition. Longer and it fails.
- The "map shortcut unlock" for the run opens a direct path from Vault to Helipad (bypasses Corp). This is a tangible quality-of-life reward for nailing the event.

### Why These Two Events Exist

- They **test different skills**: Hack = burst objective clearing, Vault = sustained positional defense.
- They **gate Shards behind optional pressure**, keeping the base Data Shard economy tight.
- Failing them has a real penalty (spawn wave), not just "try again later".

## Encounter Design Principles

Hard rules for any fight in the map:

1. **Every encounter has at least 2 outs.** No single-exit spaces. The only exceptions are Vault Overload (point defense by design) and the boss room (committed fight).
2. **No invisible damage.** Every source of damage has a visual tell.
3. **HP scaling is conservative.** Elites never become bullet sponges. Difficulty comes from spawn density and utility (EMP drain, teleport flanks).
4. **Movement solves most problems.** Any 1v1 with a zombie, including elites, can be outrun by an unupgraded player. Elite *density* is the threat, not individual stats.
5. **No cheap deaths.** If a player loses a run, they should be able to name the decision that killed them.

## Downed & Revive Mechanics

- Stock BO3 behavior preserved: down -> bleed out in 30s -> die or be revived.
- **Subroutine Caching** doubles bleed to 60s.
- **Self-revive** (when carried): 1-time use, 10s revive animation. Purchase cost 4000 points + 2 Data Shards. Caching halves the Shard cost.
- **PhD Flopper perk** (see `13_perks.md`) isn't a save — but a dive-to-prone nova explosion clears nearby zombies, giving you a repositioning window before a second hit lands. Not a "downed prevention" layer but a "recovery option" layer.
- **Ghost Shroud boss item** is the clutch 1-HP save; stacks independently with Jugger-Nog's doubled HP pool to maximize survival time before the save is even needed.

## Emergency Drop System

Spend 3 Data Shards at any power switch to call an **emergency drop** - a random Care Package-style drop at the closest safe zone. Drop can be one of:

- Max ammo (all players)
- 2 minute insta-kill
- 2 minute double points
- Random Overclock scroll (apply to any weapon for free)
- Full perk (random) granted to caller

Weights are biased by round: early rounds lean economy (double points, max ammo), late rounds lean survival (full perk, insta-kill).

Emergency drops are a **clutch button**. 3 Shards is meaningful (third of a full build), so you don't spam them. They exist so that a player with Shards banked and a terrible situation has a lever to pull.

## Glitch Altar System (the shard gamble)

The dangerous Bus Station **trench** is also a **casino**. A **Glitch Altar** sits in the Plaza-facing trench
room: **gamble Data Shards** (default **2**, dvar `acc_altar_cost`) for a **weighted jackpot** on a short
cooldown (`acc_altar_cooldown`, 6 s). Roughly **65% boons / 35% glitch-curses** (user 2026-06-24, riskier
"spice it up" tune — was 72/28), odds telegraphed in the use hint. Curses **never instant-down** you.
Implemented in `_acc_glitch_altar.gsc` — a script-spawned hold-USE trigger + glowing core, **pure GSC** (no
geometry, ships `-GscOnly`).

- **Boons (65%):** Max Ammo (15) · Insta-Kill (13) · Double Points (12) · a random free Perk (8) · **Shard Jackpot** (15, +4 shards) · **Mega Win** (2, free Perk + Insta-Kill — the marquee ~2% top prize).
- **Curses (35%, never down you):** **Surge** (16 — an immediate burst of trench zombies via `acc_bus_trench::spawn_corp_surge`) · **Corruption** (11 — lose up to 2 banked shards) · **Dud** (8 — nothing, you lose the spin).

Distinct from the Emergency Drop (the *guaranteed* 3-shard clutch button): the Altar is **higher variance**
with a real downside, and its shard EV per spin is **negative** (the partial jackpot can't be farmed — the
altar is a sink, the boons are the value). This is the user-chosen answer to "what do Data Shards do"
(2026-06-18, workflow `underground-shards-design`); more shard sinks (Cyberware/Overclock kiosks, a
deeper-access door) are planned to land with the underground floor. All payouts are live dvars
(`acc_altar_jackpot` / `acc_altar_surge` / `acc_altar_drain`) for tuning.

## Feedback Loops (summary)

Positive loops (encourage skilled play):

- **Kills -> Shards -> Cyberware -> better kills.** Primary loop.
- **Overclocks -> weapon power -> elite kills easier -> more Shards -> more Overclocks.** Secondary loop.
- **Hack / Overload success -> map shortcut / extra attempts -> better positioning -> more kills.**

Negative loops (punish bad decisions):

- **Fail Hack -> lose a Shard source -> under-fund Cyberware -> under-powered late game.**
- **Miss elite kills -> miss Shards -> can't buy emergency drop -> clutch situations get worse.**
- **Greedy camping -> pressure pulse wave -> forced into bad position -> down -> resource drain.**

Both loops are deliberate. The map wants you to feel rewarded and punished for the same decisions on different runs.

## GSC System Sketch (for when we start scripting in Phase 3)

Rough modules we'll end up writing, in priority order:

1. `_acc_data_shards.gsc` - currency per player, pickup entity, HUD bridge.
2. `_acc_cyberware.gsc` - skill node graph, purchase validation, effect application, respec.
3. `_acc_overclocks.gsc` - weapon Overclock registry, per-run pool roll, application / re-roll.
4. `_acc_elites.gsc` - elite spawning logic, per-round cadence, elite classes.
5. `_acc_events_hack.gsc`, `_acc_events_overload.gsc` - side events.
6. `_acc_map_randomizer.gsc` - per-run state roll (power side, PaP path, perk pool, wallbuy pool).
7. `_acc_boss.gsc` - boss round orchestration.
8. `_acc_emergency_drop.gsc` - clutch button.
9. `_acc_modifiers.gsc` - optional modifiers (see `07_replayability.md`).

`_acc_` prefix = "abandoned cyber city" namespace, to clearly separate from stock `_zm_*` scripts.
