# 00 - Overview

## Elevator Pitch

**Abandoned Cyber City** is a custom Call of Duty: Black Ops III zombies map built around **mechanics, skill expression, and replayability**. Players extract "Data Shards" from elite enemies and spend them across a deep upgrade economy — the **Cyberware Weapon Overclock** terminal, extra perk slots, the Exo Suit — that reshapes how their weapons and perks behave for that run. Weapon **Overclocks** are a flat tier ladder: each terminal tier-up raises the weapon's Overclock tier, and three fixed effects (flat damage, glitch piercing, ammo refund) scale off that tier — the old per-run random-pool draw is dead code (reconciled to code 2026-07-11). (The original branching Cyberware skill tree is built but currently **disabled/dormant** in code — the Overclock terminal is the sole live weapon-upgrade path; see `03_progression_and_skills.md`.) Only the Pack-a-Punch approach path re-rolls each game; power routing (always 'corp'), the wallbuy pool (a fixed set of 5) and the elite spawn mix (deterministic shielded-only, every 4th round) stay constant. The result: every run asks different build questions, and strong players are rewarded with longer, cleaner runs - not just more loot.

Systems come first. The "cyber city" theme is the flavor wrapper; the design work is in the mechanics.

## Inspirations

- **Ameliorama I / II** - deep branching augment/skill system, optional objectives that reward map knowledge, unforgiving late-game pacing, runs measured in hours.
- **Machin[a]** - augment/machine theme baked into the mechanics (we borrow the theme as flavor, not as a design constraint).
- **Stock BO3 maps** - pacing, perk/PaP loop, boss round cadence as the baseline we build on top of.

## Design Pillars (ranked)

1. **Meaningful upgrading** - every currency spend is a decision. Data Shards are finite per run; the deep sinks (weapon Overclocks, perk slots, Exo Suit) all compete for the same slow income; Overclocks commit you to a playstyle.
2. **Skill-based difficulty** - faster ramp than stock BO3, elite enemies from round 4+, a mini-boss debut at round 5 and full **boss rounds every 9 rounds from round 9** (the count scales: r9=1, r18=2, r27=3 bosses, dealt from a no-duplicate shuffled roster - see `08_enemies.md`). A lost run should trace to a decision, not RNG.
3. **Replayability through randomization** - the live per-run map-*state* roll (not geometry) is the Pack-a-Punch approach path (the blocked side re-rolls each game); power routing is always 'corp', the wallbuy pool is a fixed set of 5, elite cadence is deterministic (every 4th round), and the Overclock pool is fixed, so those no longer re-roll. Geography and core objectives stay stable so muscle memory still pays off. (reconciled to code 2026-07-11)
4. **Multiple viable builds** - at least 3 distinct build archetypes reach the late game (e.g. Crit / AoE / Mobility) and the competing shard sinks force commitment, so runs feel different to play, not just to watch.
5. **Skill over grind** - unlocks are gated by objectives and decisions, not raw time. No "shoot 10,000 zombies for X".

## Anti-Pillars (what this map is NOT)

- **Not an Easter-Egg-centric map.** No long scripted main quest. Optional objectives (Abyss Descent soul-box layers, Glitch Altar, side stations) gate rewards, but there's no "beat-the-map" cutscene EE.
- **Not a mega-sandbox.** Zones are small, connected, readable. Density beats scale.
- **Not fair theater.** High-risk paths should have high reward and should actually be able to kill you.
- **Not a beginner map.** Assumes perk/PaP/round-management literacy.

Note: the original brief deprioritized art ("minimum viable effort") in favor of systems. That stance held on *scope* - zones stay small and readable - but a real atmosphere/materials pass and a full prop-remodel pass have since shipped (`20_atmosphere_and_materials.md`, `27_stock_models.md`, trench/underground skins). The map is systems-first, not art-starved.

## Target Player

- Primary: experienced custom zombies players who beat Ameliorama-tier maps and want a mechanical / build-craft puzzle.
- Secondary: intermediate players who want a skill ceiling to climb.
- Not targeted: first-time zombies players.

## Success Criteria (for v1.0 Workshop release)

These were the launch targets set before the scope expanded; treat them as directional, not contractual, and re-validate against the current build.

- 4-player co-op stable over a 2-hour run without persistent desync (co-op HP/spawn scaling lives in `_acc_coop_scaling.gsc`).
- At least **3 viable build archetypes** reach round 50+ in solo when piloted well.
- Map-state randomization produces different openings — the **map-wide perk scatter** re-rolls the perk→pad layout at every round divisible by 3 (opening layout random per run; QR fixed in the Plaza — [10_perks.md](10_perks.md), replaced the Lab 4-of-10 perk-door roll 2026-07-24), plus the box moves and boss drops. Power routing is always `corp`, both Lab approaches are always open (the per-run PaP block was removed 2026-06-22), the Overclock pool is fixed/dead, and wallbuys are a fixed set of 5 — none of those re-roll.
- Median solo run length before avoidable death at round 30: **25+ minutes** (a measure of tension-without-cheap-deaths).
- Workshop rating target: 4.5+ stars after 500 unique downloads, with reviews citing "build variety" or "replayability".

## Design Questions - resolved

The founding open questions have all been answered in the shipped build:

- **Solo vs co-op scaling** - both HP and spawn rate scale with player count; see `_acc_coop_scaling.gsc` and `03_progression_and_skills.md`.
- **Target "beat the map" difficulty** - Ameliorama-hard: the boss cadence and shard economy are tuned for deep runs (round 50+), not a 25-30 accessible cap. See `05_mechanics.md` / `08_enemies.md`.
- **Randomization ceiling** - the re-roll surfaces (state, not geometry) are enumerated in `06_replayability.md`.
- **Wonder weapon identity** - settled and shipped: the wonder-weapon tier is the Havoc charge gun, the Thundergun, the Blast-O-Matic, the Fire Bow, and the Leviathan Axe (all box-only). See `04_weapons.md`.

## Relationship to Other Docs

- `01_toolchain.md` - how we build this thing (see also `BO3_MAPMAKING_KB.md`, the portable pipeline reference).
- `02_layout.md` - physical map, gameplay-first (theme is flavor only).
- `03_progression_and_skills.md` - Data Shard economy, weapon Overclocks, perk/Exo progression, difficulty curve (plus the dormant Cyberware skill tree, kept for reference).
- `04_weapons.md` - arsenal (large, box-only pool: Apex + Skye ports + the Fire Bow / Leviathan Axe), Overclocks, custom perks.
- `05_mechanics.md` - round pacing, encounter design, economy math, feedback loops.
- `06_replayability.md` - randomization systems, modifiers, build archetypes, hard mode.
- `07_milestones.md` - phased deliverables with exit criteria.
- `08_enemies.md` - bestiary, elite timing, boss design and cadence.
