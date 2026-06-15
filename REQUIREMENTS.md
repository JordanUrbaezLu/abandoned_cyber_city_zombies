# Requirements

> **This is the master requirements document for Abandoned Cyber City.** Every system of the game is listed here with a one-paragraph summary and a link to its detailed spec. If the design of a system changes, the detailed doc and this summary are **both** updated in the same commit. The `/docs` folder is the source of truth; code reflects what the docs specify, not the other way around.

## Change Control

1. **Docs are authoritative.** When you want to change behavior, edit the relevant doc first.
2. **Code follows docs.** Implementation changes without corresponding doc updates are disallowed.
3. **Major changes get a CHANGELOG entry.** See [CHANGELOG.md](CHANGELOG.md) for history.
4. **Cross-doc consistency.** If Cyberware costs change in `04_progression_and_skills.md`, the Data Shard budget table there AND any references in `05_weapons.md`, `06_mechanics.md`, `13_perks.md`, `15_coop_rules.md` must be updated.
5. **No silent tuning.** If a constant in GSC is changed (e.g. `ACC_HEADSHOT_MULT`), the corresponding doc number changes in the same commit.

## System Index

### 1. Design Foundations

- **[00_overview.md](docs/00_overview.md)** — Pillars, anti-pillars, target player, success criteria.
- **[03_layout.md](docs/03_layout.md)** — 7-zone map graph (ASCII + mermaid), training spots, chokepoints, per-zone gameplay purpose, **decontamination zones** (rounds **1–4** seal one of four eligible zones; **20s** evac or die; **Spawn / Corp / Lab never seal**), **Lab perk rotation after decontamination closes** (not at round start).

### 2. Core Progression Systems

- **[04_progression_and_skills.md](docs/04_progression_and_skills.md)** — **Cyberware Skill Tree** (9 nodes, 3 branches × 3 tiers, mutual exclusion within tier) + **Data Shard economy** (earning rates, spending budget, difficulty curve). Respec rules.
- **[05_weapons.md](docs/05_weapons.md)** — **16-weapon roster** (3 tiers per gun category: normal/bad/strong + pistol + melee + grenades) + **PaP L1-L5** (50k Points to max) + **Tier 1-5** (15 Shards to max) + **Weapon Abilities** (per-category hotkey skill) + **Overclock System** (per-family pools, random roll on tier-up) + **Wonder Weapons** (Signal Staff + Vibro Cleaver, both craft-gated, each counters one specific boss).
- **[13_perks.md](docs/13_perks.md)** — 9-perk roster (6 stock + PhD Flopper + Deadshot + Widow's Wine); **each perk's base effects and Mega upgrade are documented in the same subsection** under **Perk reference (base + Mega)**. **No 4-perk cap**. **All perks at the Lab** (4 machines); rotation re-rolls every round to a random 4-of-9 (no duplicates). Equal weights. Baseline HP rule: 3 hits without Jug / 6 hits with Jug on this map (**stock BO3 Jug = 5** hits before down). **Mega Bottle system**: every boss kill gives 1 Empty Mega Bottle per player; applying at a perk machine upgrades an owned perk to its named Mega variant (Savior, Gun Slinger, Sleight of Hand Expert, Ultimate Tank, Spiderman, The Flash, The Armory, Overcharge, American Sniper). Mega flag sticks across death within a run.

### 3. Combat & Encounter Systems

- **[06_mechanics.md](docs/06_mechanics.md)** — **Round pacing** (pressure pulses, elite timing, **early rounds 1–4**: higher spawn counts + faster zombies vs stock), **Point Economy** (40/100/100 + 70/30 co-op split + 7 anti-exploit rules), **Headshot Multiplier** (2x regular, 3x boss, Tac-19 excluded), **Data Shard flow**, **Side Events** (Hack Terminal 3-stage + Vault Overload 90s defense), **Emergency Drop** (3-Shard clutch button), **GSC module architecture**.
- **[11_enemies.md](docs/11_enemies.md)** — Regular zombies, 3 elite classes (Shielded r5+, Teleporter r11+, EMP r21+), mini-boss (Juggernaut Host r10/r20), full boss (Subroutine Core r30+). HP scaling, spawn timing rules, boss counter weapons.
- **[12_boss_items.md](docs/12_boss_items.md)** — 6 passive-buff items (Neural Boots, Overclocked Gauntlets, Targeting Visor, Kinetic Battery, Ghost Shroud, Payroll Ledger). 2 slots per player. Mini-boss 50% drop, full boss 100%, duplicates → 3 Shards.

### 4. Replayability & Run Variance

- **[07_replayability.md](docs/07_replayability.md)** — Per-run map state (power side, PaP path, perk slot pool, Overclock roll per tier), build archetypes (Overclock / Subroutine / Reflex), optional modifiers (Code Red, Shardless, etc.), explicit minimal-meta-progression stance.

### 5. Player Interface

- **[14_controls_and_hud.md](docs/14_controls_and_hud.md)** — Input bindings (stock + custom `acc_ability` hotkey), HUD element list (Shards, Cyberware stack, Weapon status, Items, Objectives, Boss HP), LUI widget plan.
- **[15_coop_rules.md](docs/15_coop_rules.md)** — 1-4 player support, HP / spawn-rate scaling, per-player vs shared resources, revive rules, item pickup priority, side event activator-gating.
- **[29_atmosphere_and_materials.md](docs/29_atmosphere_and_materials.md)** — the map's **look**: art direction (palette, low-key neon lighting, smog-night sky/fog), build-vs-buy (~90% stock-skin), the verified BO3 material/sky/fog pipeline, verified stock asset shortlist, per-zone art direction, phased plan, and Workshop licensing policy. Pairs with the portable recipe in [BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md).

### 6. Development & Shipping

- **[20_requirements_checklist.md](docs/20_requirements_checklist.md)** — **the working tracker**: all 471 checkable requirements extracted from the docs with per-item implementation status (audited against code + map, 2026-06-12) and the concrete next task for each gap. Work top-down from this.
- **[21_weapon_import_sources.md](docs/21_weapon_import_sources.md)** — verified sources + install recipe for the 7 roster import weapons (TheSkyeLord packs + Skye-Weapon-Templates wiring; covers all 7).
- **[01_toolchain.md](docs/01_toolchain.md)** — BO3 Mod Tools (Radiant, APE, Launcher, GSC/CSC, LUI), directory layout, build/test loop, version control strategy, common pitfalls.
- **[02_learning_path.md](docs/02_learning_path.md)** — 6-stage curriculum from zero map experience to shipping.
- **[08_milestones.md](docs/08_milestones.md)** — Phases 0-7 with concrete deliverables and exit criteria.
- **[09_language_and_publishing.md](docs/09_language_and_publishing.md)** — GSC / CSC / LUI / GDT overview, Steam Workshop publishing flow.
- **[10_today_quickstart.md](docs/10_today_quickstart.md)** — 9-step walkthrough to ship a box-room test map in a single day.
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md)** — First-boot install walkthrough for the Windows dev laptop.

### 7. Reference Material (working knowledge)

- **[16_gsc_reference.md](docs/16_gsc_reference.md)** — BO3 GSC/CSC language + API reference. Verified signatures for `callback::on_ai_damage`, `_zm_score::add_to_player_score`, `clientfield::register`, common utility modules, custom perk setup workflow, common gotchas. **Update when we discover new patterns.**
- **[22_community_techniques.md](docs/22_community_techniques.md)** — 142-technique ledger mined from shipped community sources (exact mechanisms + citations); raw dossiers in [docs/research/](docs/research/). **Append on every external-codebase exploration.**
- **[17_reference_maps_study.md](docs/17_reference_maps_study.md)** — Design patterns from Ameliorama, Machin[a], Shadows of Evil, Origins, Der Eisendrache. What we took, what we rejected, what we haven't studied yet. **Append when we study a new map.**

## Per-System Requirements Summary (canonical quick-reference)

### Weapons (v1.0 roster: 16)

| Slot | Normal (wallbuy) | Bad (box) | Strong (box) |
|---|---|---|---|
| Shotgun | Haymaker 12 | Brecci | Tac-19 (import) |
| AR full-auto | ICR-1 | XR-2 | AK-47 (import) |
| Semi-auto AR | M14 EBR (import) | G3 (import) | FN FAL (import) |
| Sniper | Intervention (import) | Locus | Drakon |

Plus: B23R starter, Bowie Knife, Frag, EMP Grenade, Signal Staff (wonder), Vibro Cleaver (wonder).

### Weapon Progression

- **PaP L1 → L5** via Points: 5k / 7.5k / 10k / 12.5k / 15k. Cumulative +20% damage and +1 reserve mag per level. Total **50,000 Points** to max.
- **Tier 1 → Tier 5** via Data Shards: 1 / 2 / 3 / 4 / 5. Unlocks 1 Overclock slot per tier. Total **15 Shards** to max.
- **Intrinsic ability** per weapon category, hotkey-triggered with cooldown (Triple Tap / Stabilizer / Precision Mode / Slug Round / Thermal Vision / Whirlwind / Extended Fuse / Overcharge). See `docs/05_weapons.md`.
- Special rule: **Tac-19 does not receive headshot multiplier** (flat damage across hit location, base damage bumped to compensate).

### Point Economy

- Regular kill: **40 pts**.
- Headshot kill: **100 pts**.
- Knife kill: **100 pts**.
- Stock per-hit damage points (10/hit): unchanged.
- Co-op split: **70% killer / 30% split among qualifying damage contributors**. Solo = 100% to killer.
- Headshot damage multiplier: **2x regular / 3x boss** (our code; stacks multiplicatively with stock weapon GDT headshot mult).

### Data Shard Economy

- Elite kill: 1 (diminishing returns below round 10 after second kill).
- Boss mini: 2 (r10) / 3 (r20). Full boss: 4 per player independently.
- Hack Terminal success: 2 (activator only).
- Vault Overload success: 3 (activator only).
- Subroutine Cyberware T1 passive: 1 Shard per 2 minutes.
- Expected clean-run budget: ~4 @ r10 / ~10 @ r20 / ~18 @ r30 / ~25 @ r40 / ~32 @ r50.

### Enemies

| Enemy | Unlocks | Shard drop | HP (solo baseline) |
|---|---|---|---|
| Regular zombie | r1 | 0 | 150 + 100/round |
| Shielded elite | r5 | 1 | ~2x regular |
| Teleporter elite | r11 | 1 | ~0.8x regular elite |
| EMP elite | r21 | 1 | ~1.5x regular elite |
| Juggernaut Host (mini-boss) | r10, r20 | 2-3 | ~50k |
| Subroutine Core (full boss) | r30, +10 | 4 per player | 50k + 15k/round past 30 |

Boss counters: Vibro Cleaver → Juggernaut Host (+300%). Signal Staff → Subroutine Core (+300%).

### Cyberware

- 9 nodes (3 branches × 3 tiers): Overclock / Subroutine / Reflex.
- Mutually exclusive within tier.
- Costs: 2 / 3 / 5 Shards per tier (10 Shards for a full branch).
- Respec: 3-Shard tax, once per run, cannot respec from Tier 3.

### Boss Items

- Pool: 6 items (Neural Boots, Overclocked Gauntlets, Targeting Visor, Kinetic Battery, Ghost Shroud, Payroll Ledger).
- 2 equipped slots per player.
- Mini-boss drop: 50% chance; full boss: 100% guaranteed.
- Duplicates → 3 Data Shards.

### Perks

- **9 total**: Jugger-Nog, Quick Revive, Speed Cola, Double Tap 2.0, Stamin-Up, Mule Kick, Deadshot, Widow's Wine, PhD Flopper.
- **All perks at the Lab** (4 machines). Every round start, the 4 machines re-roll to a random 4-of-9 from the full roster.
- No duplicates in rotation; no per-perk guarantees; equal weights.
- 126 distinct 4-perk rotations per round; 50 independent rolls in a 50-round run.
- **No perk cap** — players can hold all 9 simultaneously if they can afford them.
- Baseline HP: 3 zombie hits to die without Jug, **6** with Jug on this map (stock BO3 Jug = **5** hits before down).
- **Route tension**: the Lab is now the map's highest-traffic zone; players route back every round to check the rotation.
- **Mega Bottle upgrades**: every boss kill drops **1 Empty Mega Bottle per player** (both mini and full). Applying a bottle at a perk machine currently dispensing a perk the player owns **upgrades that perk to its Mega variant** (named like Savior, Gun Slinger, American Sniper, etc.). Mega flag persists through death for the run (re-buying the perk re-applies Mega). ~5 bottles max per 50-round run (from 5 boss kills); you cannot Mega all 9 perks in one run. See [13_perks.md](docs/13_perks.md#mega-bottles-system) and per-perk Mega under **Perk reference** in that file.

### Co-op

- 1-4 players.
- HP: regular zombies scale +100%/player; elites / bosses scale +50%/player.
- Spawn rate: +30%/player.
- Boss Shards: full reward granted independently to each player.
- Point 70/30 split on co-op kills.

### Replayability Levers

- Map state per run: power switch side, PaP approach, perk slot assignments (240 combos), Mystery Box initial.
- Per-weapon random Overclock rolls at each tier-up.
- Boss-item drop RNG.
- 11 opt-in modifiers (Code Red, Shardless, Express, etc.).

### Out of Scope (v1.0)

- Main-quest Easter Egg.
- Persistent meta-progression (rank, unlocks, saved inventories).
- SMG and LMG weapon categories.
- Traps.
- Procedural level geometry.
- Custom game modes beyond modifiers.

## Code ↔ Doc Mapping

Every GSC module in [`scripts/zm/zm_abandoned_cyber_city/`](scripts/zm/zm_abandoned_cyber_city/) has a corresponding design doc. Module module-map with doc refs in [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md).

| Module | Primary design doc |
|---|---|
| `_acc_main.gsc` | (orchestrator, no single doc) |
| `_acc_utility.gsc` | (internal) |
| `_acc_data_shards.gsc` | [04_progression_and_skills.md](docs/04_progression_and_skills.md) |
| `_acc_cyberware.gsc` | [04_progression_and_skills.md](docs/04_progression_and_skills.md) |
| `_acc_overclocks.gsc` | [05_weapons.md](docs/05_weapons.md) |
| `_acc_weapon_abilities.gsc` | [05_weapons.md](docs/05_weapons.md) |
| `_acc_elites.gsc` | [11_enemies.md](docs/11_enemies.md) |
| `_acc_map_randomizer.gsc` | [07_replayability.md](docs/07_replayability.md) |
| `_acc_events_hack.gsc` | [06_mechanics.md](docs/06_mechanics.md) |
| `_acc_events_overload.gsc` | [06_mechanics.md](docs/06_mechanics.md) |
| `_acc_emergency_drop.gsc` | [06_mechanics.md](docs/06_mechanics.md) |
| `_acc_modifiers.gsc` | [07_replayability.md](docs/07_replayability.md) |
| `_acc_boss.gsc` | [11_enemies.md](docs/11_enemies.md) |
| `_acc_boss_items.gsc` | [12_boss_items.md](docs/12_boss_items.md) |
| `_acc_mega_bottles.gsc` | [13_perks.md](docs/13_perks.md) (Mega Bottles section) |
| `_acc_points.gsc` | [06_mechanics.md](docs/06_mechanics.md) (also [16_gsc_reference.md](docs/16_gsc_reference.md) for `_zm_score::add_to_player_score` usage) |
| `_acc_damage.gsc` | [06_mechanics.md](docs/06_mechanics.md) (also [16_gsc_reference.md](docs/16_gsc_reference.md) for verified `callback::on_ai_damage` signature) |
| `_acc_early_round_pacing.gsc` | [06_mechanics.md](docs/06_mechanics.md) (Early round pressure), [04_progression_and_skills.md](docs/04_progression_and_skills.md) (difficulty curve) |
| `_acc_atmosphere.gsc` | [29_atmosphere_and_materials.md](docs/29_atmosphere_and_materials.md) (Phase 1 fog; sky/material plan) |

## How to Use This Document

- **Before changing a system**: read the relevant detailed doc.
- **When changing a system**: update the detailed doc first. Update this REQUIREMENTS summary if the change is substantive. Commit the code change in the same commit.
- **When starting a new session / returning to the project**: read this doc first to refresh full system state in 5 minutes.
- **When a teammate asks "what does X do?"**: link them here, then to the specific doc.

## Implementation Status Snapshot

| System | Design | Code | Playable |
|---|---|---|---|
| Map layout (zone graph) | ✓ | N/A (Radiant) | Needs Radiant authoring |
| Cyberware tree | ✓ | Scaffolded | Needs verify + polish |
| Data Shards | ✓ | Scaffolded | Functional when Radiant is ready |
| Weapon Tier 1-5 + Overclocks | ✓ | Scaffolded | Needs tier-unlock UX in Phase 4 |
| Weapon PaP L1-L5 | ✓ | Needs stock override | Phase 3 |
| Weapon abilities | ✓ | Stubbed | Phase 4 |
| Point economy + 70/30 | ✓ | Scaffolded | Needs stock-award suppression |
| Headshot multiplier | ✓ | Scaffolded | API verification needed |
| Elites (3 classes) | ✓ | Scaffolded | Needs Phase 4 polish |
| Bosses | ✓ | Scaffolded | Needs combat authoring |
| Boss items (5) | ✓ | Stubbed | Phase 4 |
| Perks (stock + custom) | ✓ | Custom perks stubbed | Phase 4 |
| Side events (Hack, Overload) | ✓ | Scaffolded | Phase 3-4 |
| Map randomizer | ✓ | Scaffolded | Functional |
| Modifiers | ✓ | Stubbed | Phase 4 |
| Early round pacing (r1–4 density + speed) | ✓ | Scaffolded | Verify `default_max_zombie_func` + spawn hook on hardware |
| Wonder weapons | ✓ | Design only | Phase 4 |
| HUD / LUI | ✓ | `iprintln` fallback | Phase 4 |
| Co-op scaling | ✓ | Needs hookup | Phase 3-4 |

"Scaffolded" = module exists with correct structure + public API + TODO markers for unverified stock APIs.
"Stubbed" = module exists with table/data but effect functions log-only.
"Design only" = no GSC file yet.

## When in Doubt

- Read the detailed doc for the system.
- If the doc is unclear: write down the ambiguity and raise it as a design decision to make BEFORE coding.
- If there's a contradiction between docs: the more specific doc wins. Update the other doc to match.
- If code contradicts docs: the doc wins. Fix the code or update the doc (never both).
