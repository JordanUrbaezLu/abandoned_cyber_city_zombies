# 00 - Overview

## Elevator Pitch

**Abandoned Cyber City** is a custom Call of Duty: Black Ops III zombies map built around **mechanics, skill expression, and replayability**. Players extract "Data Shards" from elite enemies and spend them on a branching **Cyberware / perk economy** that reshapes how their weapons, movement, and perks behave for that run. Weapon **Overclocks** are pulled from randomized pools. Map state (power routing, Pack-a-Punch path, wallbuy pool, elite spawn mix) re-rolls each game. The result: every run asks different build questions, and strong players are rewarded with longer, cleaner runs - not just more loot.

Systems come first. The "cyber city" theme is the flavor wrapper; the design work is in the mechanics.

## Inspirations

- **Ameliorama I / II** - deep branching augment/skill system, optional objectives that reward map knowledge, unforgiving late-game pacing, runs measured in hours.
- **Machin[a]** - augment/machine theme baked into the mechanics (we borrow the theme as flavor, not as a design constraint).
- **Stock BO3 maps** - pacing, perk/PaP loop, boss round cadence as the baseline we build on top of.

## Design Pillars (ranked)

1. **Meaningful upgrading** - every currency spend is a decision. Data Shards are finite per run; skill branches are mutually exclusive within a tier; Overclocks commit you to a playstyle.
2. **Skill-based difficulty** - faster ramp than stock BO3, elite enemies from round 5+, a mini-boss debut at round 10 and full **boss rounds every 9 rounds from round 9** (the count scales: r9=1, r18=2, r27=3 bosses, dealt from a no-duplicate shuffled roster - see `08_enemies.md`). A lost run should trace to a decision, not RNG.
3. **Replayability through randomization** - map *state* (not geometry) re-rolls per game: power routing, PaP path, wallbuy pool, elite cadence, Overclock pool. Geography and core objectives stay stable so muscle memory still pays off.
4. **Multiple viable builds** - at least 3 distinct build archetypes reach the late game (e.g. Crit / AoE / Mobility) and the tree forces commitment, so runs feel different to play, not just to watch.
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
- Map-state randomization produces meaningfully different openings (power routing x Overclock pool x wallbuy roll x Lab-alcove perk roll).
- Median solo run length before avoidable death at round 30: **25+ minutes** (a measure of tension-without-cheap-deaths).
- Workshop rating target: 4.5+ stars after 500 unique downloads, with reviews citing "build variety" or "replayability".

## Design Questions - resolved

The founding open questions have all been answered in the shipped build:

- **Solo vs co-op scaling** - both HP and spawn rate scale with player count; see `_acc_coop_scaling.gsc` and `03_progression_and_skills.md`.
- **Target "beat the map" difficulty** - Ameliorama-hard: the boss cadence and shard economy are tuned for deep runs (round 50+), not a 25-30 accessible cap. See `05_mechanics.md` / `08_enemies.md`.
- **Randomization ceiling** - the re-roll surfaces (state, not geometry) are enumerated in `06_replayability.md`.
- **Wonder weapon identity** - settled and shipped: the Havoc charge gun plus the elemental bows are the wonder-weapon tier (all box-only). See `04_weapons.md`.

## Relationship to Other Docs

- `01_toolchain.md` - how we build this thing (see also `BO3_MAPMAKING_KB.md`, the portable pipeline reference).
- `02_layout.md` - physical map, gameplay-first (theme is flavor only).
- `03_progression_and_skills.md` - the Cyberware/perk tree, Data Shard economy, difficulty curve.
- `04_weapons.md` - arsenal (large, box-only pool: Apex + Skye ports + elemental bows), Overclocks, custom perks.
- `05_mechanics.md` - round pacing, encounter design, economy math, feedback loops.
- `06_replayability.md` - randomization systems, modifiers, build archetypes, hard mode.
- `07_milestones.md` - phased deliverables with exit criteria.
- `08_enemies.md` - bestiary, elite timing, boss design and cadence.
