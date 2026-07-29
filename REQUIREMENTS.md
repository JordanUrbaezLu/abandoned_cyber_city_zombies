# Requirements

> **This is the master requirements document for Abandoned Cyber City.** Every system of the game is listed here with a one-paragraph summary and a link to its detailed spec. If the design of a system changes, the detailed doc and this summary are **both** updated in the same commit. The `/docs` folder is the source of truth; code reflects what the docs specify, not the other way around.

## Change Control

1. **Docs are authoritative.** When you want to change behavior, edit the relevant doc first.
2. **Code follows docs.** Implementation changes without corresponding doc updates are disallowed.
3. **Major changes get a CHANGELOG entry.** See [CHANGELOG.md](CHANGELOG.md) for history.
4. **Cross-doc consistency.** If Cyberware costs change in `03_progression_and_skills.md`, the Data Shard budget table there AND any references in `04_weapons.md`, `05_mechanics.md`, `10_perks.md`, `12_coop_rules.md` must be updated.
5. **No silent tuning.** If a constant in GSC is changed (e.g. `ACC_HEADSHOT_MULT`), the corresponding doc number changes in the same commit.

## System Index

### 1. Design Foundations

- **[00_overview.md](docs/00_overview.md)** — Pillars, anti-pillars, target player, success criteria.
- **[02_layout.md](docs/02_layout.md)** — 7-zone map graph (ASCII + mermaid), training spots, chokepoints, per-zone gameplay purpose, ~~**decontamination zones**~~ (the decontamination / zone-seal hazard was removed 2026-06-22 — no zone is sealed and no evac window applies), **Lab perk rotation on round start** (fires on `acc_round_start`). (reconciled to code 2026-07-11)

### 2. Core Progression Systems

- **[03_progression_and_skills.md](docs/03_progression_and_skills.md)** — **Cyberware Skill Tree** (9 nodes, 3 branches × 3 tiers, mutual exclusion within tier) + **Data Shard economy** (earning rates, spending budget, difficulty curve). Respec rules.
- **[04_weapons.md](docs/04_weapons.md)** — **~29-weapon roster** (mostly Skye/Apex/CW/BO2 imports across all gun categories + pistol + melee + grenades) + **PaP tiers 1-3** (per-gun price buckets; +33% / +67% / +100% damage) + **Tier 1-10** (4/8/…/40 Shards, 220 to max one gun) + **Weapon Abilities** (per-category hotkey skill) + **Overclock System** (per-family pools, random roll on tier-up) + **Wonder Weapons** (Thundergun, Blast-O-Matic, Fire Bow, Leviathan Axe).
- **[10_perks.md](docs/10_perks.md)** — 10-perk roster (6 stock + PhD Flopper + Deadshot + Widow's Wine + Electric Cherry); **each perk's base effects and Mega upgrade are documented in the same subsection** under **Perk reference (base + Mega)**. **No 4-perk cap**. **All perks at the Lab** (10 door-gated alcoves); rotation re-rolls every round to a random 4-of-10 (no duplicates). Equal weights. Baseline HP rule: 3 hits without Jug / 6 hits with Jug on this map (**stock BO3 Jug = 5** hits before down). **Mega Bottle system**: every boss kill gives 1 Empty Mega Bottle per player; applying at a perk machine upgrades an owned perk to its named Mega variant (Savior, Gun Slinger, Sleight of Hand Expert, Ultimate Tank, Spiderman, The Flash, The Armory, PhD Slider, American Sniper, Power Surge). Mega flag sticks across death within a run.

### 3. Combat & Encounter Systems

- **[05_mechanics.md](docs/05_mechanics.md)** — **Round pacing** (pressure pulses, elite timing, **early rounds 1–4**: higher spawn counts + faster zombies vs stock), **Point Economy** (70/110/100 + 70/30 co-op split + 5 anti-exploit rules), **Headshot Multiplier** (2.5x regular, 4x boss, Tac-19 excluded), **Data Shard flow**, **Side Events** (Hack Terminal 3-stage + Vault Overload 90s defense), **Emergency Drop** (3-Shard clutch button), **GSC module architecture**.
- **[08_enemies.md](docs/08_enemies.md)** — Regular zombies, 3 elite classes (Shielded r5+, Teleporter r11+, EMP r21+), Glitch Stalker mini-boss (every 2nd round; count scales with round, r4=1, r6=2, r8=3, unbounded), boss rounds every 9 from r9 (roster roll from a 4-boss deck: The Phantom / Rogue Protector / Avogadro / Panzer; count scales r9=1, r18=2, r27=3), plus the Trench Warden (Brutus — one enemy, not two; debuts at power-on & r5+, respawns 3 rounds after each kill). HP scaling, spawn timing rules, boss counter weapons.
- **[09_boss_items.md](docs/09_boss_items.md)** — 15 passive-buff items (Sentry Drone [replaced Gas Tank 2026-07-22], Loot Stash, Repair Kit, Rocket Shield, Phase Serum, Boots, Lucky Horseshoe, Turbocharger, Plasma Generator, Battery, Berzerker, High Caliber, Warhead Bomber, Hive Node, Dark Magic). 3 slots per player. Every boss kill drops 1 item via the unified reward; duplicates → 3 Shards.

### 4. Replayability & Run Variance

- **[06_replayability.md](docs/06_replayability.md)** — Per-run map state (power side, PaP path, perk slot pool, Overclock roll per tier), build archetypes (Overclock / Subroutine / Reflex), optional modifiers (Code Red, Shardless, etc.), explicit minimal-meta-progression stance.

### 5. Player Interface

- **[11_controls_and_hud.md](docs/11_controls_and_hud.md)** — Input bindings (stock + custom `acc_ability` hotkey), HUD element list (Shards, Cyberware stack, Weapon status, Items, Objectives, Boss HP), LUI widget plan.
- **[12_coop_rules.md](docs/12_coop_rules.md)** — 1-4 player support, HP / spawn-rate scaling, per-player vs shared resources, revive rules, item pickup priority, side event activator-gating.
- **[20_atmosphere_and_materials.md](docs/20_atmosphere_and_materials.md)** — the map's **look**: art direction (palette, low-key neon lighting, smog-night sky/fog), build-vs-buy (~90% stock-skin), the verified BO3 material/sky/fog pipeline, verified stock asset shortlist, per-zone art direction, phased plan, and Workshop licensing policy. Pairs with the portable recipe in [BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md).

### 6. Development & Shipping

- **[15_requirements_checklist.md](docs/15_requirements_checklist.md)** — **the working tracker**: all 471 checkable requirements extracted from the docs with per-item implementation status (audited against code + map, 2026-06-12) and the concrete next task for each gap. Work top-down from this.
- **[21_adding_a_gun_runbook.md](docs/21_adding_a_gun_runbook.md)** — verified sources + install recipe for the ~29-gun import roster (Skye/Apex/CW/BO2 packs + Skye-Weapon-Templates wiring).
- **[01_toolchain.md](docs/01_toolchain.md)** — BO3 Mod Tools (Radiant, APE, Launcher, GSC/CSC, LUI), directory layout, build/test loop, version control strategy, common pitfalls.
- **[01_toolchain.md](docs/01_toolchain.md)** — 6-stage curriculum from zero map experience to shipping.
- **[07_milestones.md](docs/07_milestones.md)** — Phases 0-7 with concrete deliverables and exit criteria.
- **[34_release_runbook.md](docs/34_release_runbook.md)** — GSC / CSC / LUI / GDT overview, Steam Workshop publishing flow.
- **[17_launch_runbook.md](docs/17_launch_runbook.md)** — 9-step walkthrough to ship a box-room test map in a single day.
- **[SETUP_WINDOWS.md](SETUP_WINDOWS.md)** — First-boot install walkthrough for the Windows dev laptop.

### 7. Reference Material (working knowledge)

- **[14_stock_api_verification.md](docs/14_stock_api_verification.md)** — BO3 GSC/CSC language + API reference. Verified signatures for `callback::on_ai_damage`, `_zm_score::add_to_player_score`, `clientfield::register`, common utility modules, custom perk setup workflow, common gotchas. **Update when we discover new patterns.**
- **[16_community_techniques.md](docs/16_community_techniques.md)** — 142-technique ledger mined from shipped community sources (exact mechanisms + citations); raw dossiers in [docs/research/](docs/research/). **Append on every external-codebase exploration.**
- **[13_reference_maps_study.md](docs/13_reference_maps_study.md)** — Design patterns from Ameliorama, Machin[a], Shadows of Evil, Origins, Der Eisendrache. What we took, what we rejected, what we haven't studied yet. **Append when we study a new map.**

## Per-System Requirements Summary (canonical quick-reference)

### Weapons (v1.0 roster: ~29)

The 4×3 normal/bad/strong roster below was replaced by a ~29-gun import roster (mostly Skye/Apex/CW/BO2 packs), rolled from the Mystery Box with tier-weighted odds. (reconciled to code 2026-07-11)

| Category | Weapons (in code) |
|---|---|
| Pistol | Five-Seven (starter), RW1 |
| Shotgun | Peacekeeper, Streetsweeper, CEL-3, Olympia, Tac-19 |
| AR | Havoc, M16, AK-47, XM4, AE4, Grav |
| SMG | Alternator, Prowler, PPSH-41, AK-74u |
| LMG | M60, RPD, HAMR |
| Marksman / Sniper | MK14, MORS |
| Explosive special | Mahem, War Machine |
| Wonder | Thundergun, Blast-O-Matic, Fire Bow, Leviathan Axe |
| Melee | Action Figure |
| Tactical (rare box roll) | Monkey Bomb, Li'l Arnie |

Plus: Five-Seven starter, Bowie Knife, Frag, EMP Grenade, and four wonder-tier weapons: Thundergun, Blast-O-Matic, Fire Bow (elemental_bow_demongate), Leviathan Axe.

### Weapon Progression

- **PaP tiers 1 → 3** via Points, priced per gun by bucket (WONDER 10k/15k/20k, TOP 5k/7.5k/10k, MID 4k/6k/8k, BOT 3k/4.5k/6k). Cumulative damage +33% / +67% / +100%.
- **Tier 1 → Tier 10** via Data Shards: 4 / 8 / 12 / 16 / 20 / 24 / 28 / 32 / 36 / 40. Unlocks 1 Overclock slot per tier. Total **220 Shards** to max one gun.
- **Intrinsic ability** per weapon category, hotkey-triggered with cooldown (Triple Tap / Stabilizer / Precision Mode / Slug Round / Thermal Vision / Whirlwind / Extended Fuse / Overcharge). See `docs/04_weapons.md`.
- Special rule: **Tac-19 does not receive headshot multiplier** (flat damage across hit location, base damage bumped to compensate).

### Point Economy

- Regular kill: **70 pts**.
- Headshot kill: **110 pts**.
- Knife kill: **100 pts**.
- Stock per-hit damage points (10/hit): suppressed to 0 by default (kill-only economy; restorable via `acc_hit_points 1`).
- Co-op split: **70% killer / 30% split among qualifying damage contributors**. Solo = 100% to killer.
- Headshot damage multiplier: **2.5x regular / 4x boss** (our code; stacks multiplicatively with stock weapon GDT headshot mult).

### Data Shard Economy

- Elite kill: 1 (diminishing returns below round 10 after second kill).
- Boss reward: floor(round/3) Shards per boss, granted independently to each player (r10 → 3, r20 → 6). ~~Full boss: 4 per player independently.~~ (Subroutine Core full boss removed 2026-06-22.)
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
| Brutus / Trench Warden (mini-boss) | power-on & r5+ (respawns 3 rounds after each kill) | floor(round/3) | 65k base (×1.12/round from r5) |
| ~~Subroutine Core (full boss)~~ | ~~r30, +10~~ | ~~4 per player~~ | ~~50k + 15k/round past 30~~ (boss removed 2026-06-22) |

Boss counters: the Vibro Cleaver / Signal Staff counter-weapons and the Juggernaut Host / Subroutine Core bosses they targeted no longer exist in code; the wonder weapons are the Thundergun, Blast-O-Matic, Fire Bow, and Leviathan Axe. (reconciled to code 2026-07-11)

### Cyberware

- 9 nodes (3 branches × 3 tiers): Overclock / Subroutine / Reflex.
- Mutually exclusive within tier.
- Costs: 2 / 3 / 5 Shards per tier (10 Shards for a full branch).
- Respec: 3-Shard tax, once per run, cannot respec from Tier 3.

### Boss Items

- Pool: **15 items** (Sentry Drone [replaced Gas Tank 2026-07-22], Loot Stash, Repair Kit, Rocket Shield, Phase Serum, Boots, Lucky Horseshoe, Turbocharger, Plasma Generator, Battery, Berzerker, High Caliber Rounds, Warhead Bomber, Hive Node, Dark Magic). (reconciled to code 2026-07-22)
- **3** equipped slots per player. (reconciled to code 2026-07-11)
- Every boss kill drops 1 item (unified boss reward). ~~Mini-boss drop: 50% chance; full boss: 100% guaranteed.~~ (Full boss removed 2026-06-22.)
- Duplicates → 3 Data Shards.

### Perks

- **10 total**: Jugger-Nog, Quick Revive, Speed Cola, Double Tap 2.0, Stamin-Up, Mule Kick, Deadshot, Widow's Wine, PhD Flopper, Electric Cherry. (reconciled to code 2026-07-11 — Electric Cherry is the real 10th, `specialty_combat_efficiency`)
- **MAP-WIDE PERK SCATTER (user 2026-07-24 — supersedes the Lab alcove-door rotation)**: the 10
  machines live on **10 fixed pads spread across the map** — Plaza (permanently Quick Revive, solo
  auto-power per stock), Lab ×2 (two of the old alcoves), Alley, Market, Helipad, Vault, the Bus
  Station jukebox under-room, **Abyss Layer 2 past the first soul door** (user 2026-07-25 — a
  perk reward for descending), and the Exchange — and the perk→pad assignment
  **reshuffles at random at the start of every round divisible by 3** (3, 6, 9, …). The opening
  layout is also random per run. Announced, but new locations are not revealed. **Spots = perks,
  always**: every perk has a home at all times; adding a perk later means adding a pad with it.
- **Pin (2 Empty Mega Bottles)**: a player who owns a perk's **Mega** can spend 2 bottles at its
  machine to lock that perk onto its current pad for the rest of the game — the perk and pad both
  leave the rotation. (Successor of the retired 2-bottle permanent door unlock.)
- Perks stay power-gated until the Bus Station switch is flipped (machines relocate before power
  too); owned perks are never affected by a scatter.
- **Perk-slot cap**: everyone starts with 4 perk slots and buys additional slots with Data Shards up to 10 (all perks). (reconciled to code 2026-07-11)
- Baseline HP: 3 zombie hits to die without Jug, **6** with Jug on this map (stock BO3 Jug = **5** hits before down).
- **Route tension**: every 3rd round the whole map becomes the shop — players learn the new layout by traveling it (or pin the perks they care about).
- **Mega Bottle upgrades**: every boss kill drops **1 Empty Mega Bottle per player** (both mini and full). Applying a bottle at a perk machine currently dispensing a perk the player owns **upgrades that perk to its Mega variant** (named like Savior, Gun Slinger, American Sniper, etc.). Mega flag persists through death for the run (re-buying the perk re-applies Mega). ~5 bottles max per 50-round run (from 5 boss kills); you cannot Mega all 10 perks in one run. See [10_perks.md](docs/10_perks.md#mega-bottles-system) and per-perk Mega under **Perk reference** in that file.

### Co-op

- 1-4 players.
- HP: regular zombies scale +20%/extra player; elites scale +50%/extra player; bosses scale logarithmically (~+50% per doubling of players: 2p ×1.50, 3p ×1.79, 4p ×2.00).
- Spawn rate: +30%/player.
- Boss Shards: full reward granted independently to each player.
- Point 70/30 split on co-op kills.

### Replayability Levers

- Map state per run: PaP approach (power switch side is now fixed to Corp; the Vault switch was removed — reconciled to code 2026-07-11), perk slot assignments (240 combos), Mystery Box initial.
- Per-weapon random Overclock rolls at each tier-up.
- Boss-item drop RNG.
- 11 opt-in modifiers (Code Red, Shardless, Express, etc.).

### Out of Scope (v1.0)

- Main-quest Easter Egg.
- Persistent meta-progression (rank, unlocks, saved inventories).
- ~~SMG and LMG weapon categories.~~ Now in scope — SMGs (Alternator, Prowler, PPSH-41, AK-74u) and LMGs (M60, RPD, HAMR) ship in the box roster. (reconciled to code 2026-07-11)
- Traps.
- Procedural level geometry.
- Custom game modes beyond modifiers.

## Code ↔ Doc Mapping

Every GSC module in [`scripts/zm/zm_abandoned_cyber_city/`](scripts/zm/zm_abandoned_cyber_city/) has a corresponding design doc. Module module-map with doc refs in [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md).

| Module | Primary design doc |
|---|---|
| `_acc_main.gsc` | (orchestrator, no single doc) |
| `_acc_utility.gsc` | (internal) |
| `_acc_data_shards.gsc` | [03_progression_and_skills.md](docs/03_progression_and_skills.md) |
| `_acc_cyberware.gsc` | [03_progression_and_skills.md](docs/03_progression_and_skills.md) |
| `_acc_overclocks.gsc` | [04_weapons.md](docs/04_weapons.md) |
| `_acc_weapon_abilities.gsc` | [04_weapons.md](docs/04_weapons.md) |
| `_acc_elites.gsc` | [08_enemies.md](docs/08_enemies.md) |
| `_acc_map_randomizer.gsc` | [06_replayability.md](docs/06_replayability.md) |
| `_acc_events_hack.gsc` | [05_mechanics.md](docs/05_mechanics.md) |
| `_acc_events_overload.gsc` | [05_mechanics.md](docs/05_mechanics.md) |
| `_acc_emergency_drop.gsc` | [05_mechanics.md](docs/05_mechanics.md) |
| `_acc_modifiers.gsc` | [06_replayability.md](docs/06_replayability.md) |
| `_acc_boss.gsc` | [08_enemies.md](docs/08_enemies.md) |
| `_acc_boss_items.gsc` | [09_boss_items.md](docs/09_boss_items.md) |
| `_acc_mega_bottles.gsc` | [10_perks.md](docs/10_perks.md) (Mega Bottles section) |
| `_acc_points.gsc` | [05_mechanics.md](docs/05_mechanics.md) (also [14_stock_api_verification.md](docs/14_stock_api_verification.md) for `_zm_score::add_to_player_score` usage) |
| `_acc_damage.gsc` | [05_mechanics.md](docs/05_mechanics.md) (also [14_stock_api_verification.md](docs/14_stock_api_verification.md) for verified `callback::on_ai_damage` signature) |
| `_acc_early_round_pacing.gsc` | [05_mechanics.md](docs/05_mechanics.md) (Early round pressure), [03_progression_and_skills.md](docs/03_progression_and_skills.md) (difficulty curve) |
| `_acc_atmosphere.gsc` | [20_atmosphere_and_materials.md](docs/20_atmosphere_and_materials.md) (Phase 1 fog; sky/material plan) |

## How to Use This Document

- **Before changing a system**: read the relevant detailed doc.
- **When changing a system**: update the detailed doc first. Update this REQUIREMENTS summary if the change is substantive. Commit the code change in the same commit.
- **When starting a new session / returning to the project**: read this doc first to refresh full system state in 5 minutes.
- **When a teammate asks "what does X do?"**: link them here, then to the specific doc.

## Implementation Status Snapshot

> ⚠️ **Historical (pre-2026-06) planning table** — the "Code"/"Playable" columns predate the fully-built,
> shipping map and are NOT current status (see the top-of-file System Index + CHANGELOG for real state).
> System labels reconciled to code 2026-07-11; the phase columns are left as history.

| System | Design | Code | Playable |
|---|---|---|---|
| Map layout (zone graph) | ✓ | N/A (Radiant) | Needs Radiant authoring |
| Cyberware tree | ✓ | Scaffolded | Needs verify + polish |
| Data Shards | ✓ | Scaffolded | Functional when Radiant is ready |
| Weapon Tier 1-10 + Overclocks | ✓ | Scaffolded | Needs tier-unlock UX in Phase 4 |
| Weapon PaP L1-L3 | ✓ | Needs stock override | Phase 3 |
| Weapon abilities | ✓ | Stubbed | Phase 4 |
| Point economy + 70/30 | ✓ | Scaffolded | Needs stock-award suppression |
| Headshot multiplier | ✓ | Scaffolded | API verification needed |
| Elites (3 classes) | ✓ | Scaffolded | Needs Phase 4 polish |
| Bosses | ✓ | Scaffolded | Needs combat authoring |
| Boss items (11) | ✓ | Stubbed | Phase 4 |
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
