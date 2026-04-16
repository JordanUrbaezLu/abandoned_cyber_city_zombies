# 08 - Milestones

Concrete phased deliverables. Each phase has **exit criteria** - objective tests that you either pass or don't. Don't move to the next phase until exit criteria are green.

## Phase 0 - Research & Design Docs (current)

**Goal.** Capture the design before we build.

**Deliverables.**
- This `docs/` folder populated.
- `README.md` rewritten with project pitch.
- `ROADMAP.md` at repo root with the phase graph.

**Exit criteria.**
- You can describe the full Cyberware tree, Data Shard economy, and randomization strategy in ~2 minutes to a friend without looking at notes.
- You're confident enough in the design to commit to Phase 1 setup.

**Estimate.** Done when docs are approved. Hours, not weeks.

## Phase 1 - Toolchain Install & Orientation

**Goal.** You can build and run a hello-world map.

**Deliverables.**
- BO3 Mod Tools installed on a Windows dev machine.
- Maya or Blender installed (optional at this phase).
- VS Code configured for GSC highlighting.
- A throwaway "one room, one spawn, one light" map builds and runs.

**Exit criteria.**
- You can go from "edit a brush in Radiant" to "walking around in that map in-game" in under 5 minutes, by memory.
- You've read Treyarch's beginner PDF and completed Stage 1-2 of `02_learning_path.md`.

**Estimate.** 1-2 weekends.

## Phase 2 - Zombies Template + Greybox

**Goal.** A playable, ugly, mechanically-complete greybox of the 7 zones in `03_layout.md`.

**Deliverables.**
- `usermaps/zm_abandoned_cyber_city/` initialized from the zm template.
- Geometry for all 7 zones (Spawn, Market, Alley, Corp, Vault, Roof, Lab) - boxy, untextured beyond stock caulk/devgrid. No art.
- All doors/debris prefabs placed between zones with stock costs.
- All perk machine slots placed (placeholder perks - Jug everywhere is fine for now).
- Pack-a-Punch prefab placed in the Lab.
- Spawn points, player_start, mantle points, zombie spawners, zones registered in `_zm_zonemgr`.
- Repo mirrors `/scripts` (initially empty beyond a stub `_acc_main.gsc`) and `/zone_source/zm_abandoned_cyber_city.csv`.

**Exit criteria.**
- You can reach round 10 on the greybox map, using Mystery Box and PaP, with all zones accessible.
- No script errors in `console.log` during a 10-round playtest.
- The zone flow from `03_layout.md` works - you can traverse Spawn -> Market -> Corp -> Vault -> Lab without getting stuck.

**Estimate.** 4-8 weeks of evenings.

## Phase 3 - Core Custom Systems (Data Shards + Cyberware + Overclocks)

**Goal.** The *mechanical* core of the map works. Still ugly; still small asset count.

**Deliverables.**
- `_acc_data_shards.gsc` - currency, elite-kill drop entity, HUD counter (simple `iprintln` or small HUD elem OK; LUI deferred).
- `_acc_cyberware.gsc` - skill-node graph with the 9 nodes from `04_progression_and_skills.md`, with a placeholder interaction trigger (a pedestal in Spawn Plaza that cycles through nodes via F keypress for now - LUI skill tree in Phase 4).
- `_acc_overclocks.gsc` - weapon family registry, per-run active pool roll, application via a Lab Overclock Terminal trigger.
- `_acc_map_randomizer.gsc` - power switch side, PaP approach, wallbuy pool, perk pool all re-roll on map load. Logs the chosen state to `console.log`.
- `_acc_elites.gsc` - at least one elite class (Shielded) spawning on round 5+, dropping a Shard.
- `_acc_emergency_drop.gsc` - callable from a power switch, one drop type (max ammo) working.

**Exit criteria.**
- Solo playtest to round 20 passes: elites spawn, Shards drop, you can buy a full Cyberware branch, Overclocks apply to weapons, map state is different on 3 consecutive runs.
- All buys / currency writes are multiplayer-safe (`self.data_shards` per-player, HUD bridges work per-client).
- No GSC runtime errors across a full 20-round run.

**Estimate.** 6-10 weeks. This is the hardest phase.

## Phase 4 - Remaining Systems + Custom UI + Content Pass

**Goal.** Feature-complete map. All mechanics, all content, minimum viable UI.

**Deliverables.**
- Remaining elite classes (Teleporter, EMP) implemented.
- Mini-boss and full boss implemented (art placeholder models OK).
- Hack Terminal event (`_acc_events_hack.gsc`) with all 3 stages.
- Vault Overload event (`_acc_events_overload.gsc`) with 3-wave structure + map shortcut unlock.
- Custom perks working (Aura Blast active-stun, Deadshot headshot-boost + auto-aim, Widow's Wine grenade-boost), plus retuned stock perks (Jug cost, QR regen, Speed Cola drink/swap speed, Stamin-Up sprint duration cap). No-perk-cap override hooked.
- Wonder weapon chosen (one of the three from `05_weapons.md`) and implemented with its 3 Overclocks.
- LUI: Data Shard HUD element, minimal Cyberware skill-tree UI (can be a simple grid with 9 nodes).
- All stock perks placed with the randomized per-slot logic.
- Modifier system (`_acc_modifiers.gsc`) with at least 4 modifiers working (Code Red, Limited Liability, Shardless, Express).

**Exit criteria.**
- A full solo run to round 30 is possible, with all systems engaged.
- Hack Terminal + Vault Overload can each be triggered and completed/failed correctly.
- At least 2 different builds tested to round 30.
- Modifiers toggled on/off at map load work without bugs.

**Estimate.** 8-12 weeks.

## Phase 5 - Art Pass (minimal)

**Goal.** The map is presentable enough to show people. Not a showcase; not embarrassing.

**Per user direction: art is not a priority. This phase is "make it legible, not beautiful".**

**Deliverables.**
- Zones get a consistent stock-asset reskin - cyber/industrial textures from stock BO3 assets reused. No bespoke models required.
- Lighting: basic per-zone mood (dim undercity, brighter plaza, etc.) using stock lighting tools.
- Sound: ambient loops per zone using stock sound aliases. Custom map music on round transitions if trivial; otherwise stock.
- Skybox: basic cyber skybox (stock or a simple painted backdrop).

**Exit criteria.**
- A non-modder can tell zones apart by looking.
- No z-fighting, no missing textures, no obvious seams.
- FPS holds 60+ on a mid-range 2020 GPU at 1080p.

**Estimate.** 2-4 weeks. Time-boxed.

## Phase 6 - Playtest, Tune, Polish

**Goal.** Feels good. Balance is close. Bugs are low.

**Deliverables.**
- Closed-group playtest with 3-5 experienced zombies players. Ideally 5+ sessions.
- Balance pass on:
  - Data Shard drop rates (target the expected budget in `04_progression_and_skills.md`).
  - Cyberware capstone strength (Meltdown vs Recursion vs Overdrive).
  - Elite HP and spawn timing.
  - Wallbuy / perk / Overclock pool weights.
- Bug-fix pass on whatever playtest surfaces.
- Performance pass: fast file size, asset budget, particle counts, LOD checks.

**Exit criteria.**
- 3 different playtesters each reach round 30+ using different build archetypes.
- No game-breaking bugs in a 2-hour session.
- Fast file size fits within BO3's limit with ~20% headroom.

**Estimate.** 3-6 weeks.

## Phase 7 - Release

**Goal.** Public on Steam Workshop.

**Deliverables.**
- Workshop page: name, description, screenshots (5-10, even if rough), tags (Zombies, Custom Map, Easter Egg-free).
- Changelog / known issues in the Workshop description.
- v1.0 tag in git.
- Post-release plan: what gets iterated on based on player feedback, and what's deferred to a v1.1.

**Exit criteria.**
- Published to Workshop successfully.
- Subscribed, installed, and run by at least one non-dev tester from a fresh install.
- No patch-0 hotfix needed within the first 48 hours.

**Estimate.** 1 weekend.

## Total Estimate

**Solo, evenings/weekends: 8-14 months from Phase 0 to v1.0.**

Phases 3 and 4 dominate (your time-to-scripting-fluency multiplied by the amount of custom GSC we need). Everything else is predictable.

## Post-1.0 (tracked for future)

- Seeded runs (paste a seed, reproduce a map state).
- Additional modifiers.
- Additional wonder weapon (pick from the two unchosen options in `05_weapons.md`).
- A true main Easter Egg, if player feedback demands it. (Explicitly deferred per design direction - not promised.)
- Traps.
- Leaderboard integration if any community solution exists.
