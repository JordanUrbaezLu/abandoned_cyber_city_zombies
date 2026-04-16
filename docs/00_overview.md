# 00 - Overview

## Elevator Pitch

**Abandoned Cyber City** is a custom Call of Duty: Black Ops III zombies map built around **mechanics, skill expression, and replayability**. Players extract "Data Shards" from elite enemies and spend them on a branching, mutually-exclusive **Cyberware** skill tree that reshapes how their weapons, movement, and perks behave for that run. Weapon **Overclocks** are pulled from randomized pools. Map state (power routing, Pack-a-Punch path, wallbuy pool, elite spawn mix) re-rolls each game. The result: every run asks different build questions, and strong players are rewarded with longer, cleaner runs - not just more loot.

Aesthetics and lore are explicitly de-prioritized. The map's visual language ("cyber city") is flavor; the design work is in systems.

## Inspirations

- **Ameliorama I / II** - deep branching augment/skill system, optional objectives that reward map knowledge, unforgiving late-game pacing, runs measured in hours.
- **Machin[a]** - augment/machine theme baked into the mechanics (we borrow the theme as flavor, not as a design constraint).
- **Stock BO3 maps** - pacing, perk/PaP loop, boss round cadence as the baseline we build on top of.

## Design Pillars (ranked)

1. **Meaningful upgrading** - every currency spend is a decision. Data Shards are finite per run; skill branches are mutually exclusive within a tier; Overclocks commit you to a playstyle.
2. **Skill-based difficulty** - faster ramp than stock BO3, elite enemies from round 5+, boss round every 10. A lost run should trace to a decision, not RNG.
3. **Replayability through randomization** - map *state* (not geometry) re-rolls per game: power routing, PaP path, wallbuy pool, elite cadence, Overclock pool. Geography and core objectives stay stable so muscle memory still pays off.
4. **Multiple viable builds** - at least 3 distinct build archetypes reach the late game (e.g. Crit / AoE / Mobility) and the tree forces commitment, so runs feel different to play, not just to watch.
5. **Skill over grind** - unlocks are gated by objectives and decisions, not raw time. No "shoot 10,000 zombies for X".

## Anti-Pillars (what this map is NOT)

- **Not an Easter-Egg-centric map.** No long scripted main quest. Optional objectives exist to gate rewards, but there's no "beat-the-map" cutscene EE.
- **Not a showcase map.** Art passes get minimum viable effort. If it reads clearly and plays well, it's done.
- **Not a mega-sandbox.** Zones are small, connected, readable. Density beats scale.
- **Not fair theater.** High-risk paths should have high reward and should actually be able to kill you.
- **Not a beginner map.** Assumes perk/PaP/round-management literacy.

## Target Player

- Primary: experienced custom zombies players who beat Ameliorama-tier maps and want a mechanical / build-craft puzzle.
- Secondary: intermediate players who want a skill ceiling to climb.
- Not targeted: first-time zombies players.

## Success Criteria (for v1.0 Workshop release)

- 4-player co-op stable over a 2-hour run without persistent desync.
- At least **3 viable build archetypes** reach round 50+ in solo when piloted well.
- Map-state randomization produces at least **16 distinct opening-10-minute experiences** (rough: 4 power states x 4 Overclock pools).
- Median solo run length before avoidable death at round 30: **25+ minutes** (a measure of tension-without-cheap-deaths).
- Workshop rating target: 4.5+ stars after 500 unique downloads, with reviews citing "build variety" or "replayability".

## Open Design Questions (answered in later docs)

- Solo vs co-op difficulty scaling: HP, spawn rate, or both? (`05_progression_and_skills.md`)
- Target "beat the map" round - Ameliorama-hard (40+) vs accessible (25-30)? (`05`)
- Randomization ceiling - how much re-rolls before it feels unfair? (`07_replayability.md`)
- Wonder weapon identity - nanite swarm, EMP railgun, or code-injection pistol? (`05_weapons.md`)

## Relationship to Other Docs

- `01_toolchain.md` - how we build this thing.
- `02_learning_path.md` - how **you** learn to build this thing.
- `03_layout.md` - physical map, gameplay-first (theme is flavor only).
- `04_progression_and_skills.md` - the Cyberware tree, Data Shard economy, difficulty curve.
- `05_weapons.md` - arsenal (10-weapon shortlist), Overclocks, custom perks, wonder weapon candidates.
- `06_mechanics.md` - round pacing, encounter design, economy math, feedback loops.
- `07_replayability.md` - randomization systems, modifiers, build archetypes, hard mode.
- `08_milestones.md` - phased deliverables with exit criteria.
- `11_enemies.md` - bestiary, elite timing, boss design.
