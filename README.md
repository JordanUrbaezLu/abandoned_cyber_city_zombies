# Abandoned Cyber City

A custom **Call of Duty: Black Ops III** zombies map focused on **mechanics, skill expression, and replayability**. Inspired by Ameliorama I/II and Machin[a], with a deliberate bias toward systems depth over art and narrative.

> **Status**: Fully built and playable. First clean compile + link 2026-06-12; the full multi-zone map plus ~48 custom `_acc_` systems build with `tools/build_map.ps1` and run in-game on Windows with the BO3 Mod Tools. Ongoing work is balance, content, and polish. Recent state: [CHANGELOG.md](CHANGELOG.md).

## Start Here

- **New contributor? Want it running?** → **[ONBOARDING.md](ONBOARDING.md)** — clone, build, play, and contribute (with Claude Code) in a few steps.
- **What are the requirements?** → **[REQUIREMENTS.md](REQUIREMENTS.md)**. This is the authoritative spec for every system. Design changes go in the doc first, code follows.
- **What changed recently?** → [CHANGELOG.md](CHANGELOG.md).
- **Setting up a Windows dev box?** Full install + publish walkthrough: [SETUP_WINDOWS.md](SETUP_WINDOWS.md).
- **Portable mapmaking reference** (build pipeline, GSC dialect, entity recipes, gotchas): [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md).
- **Want to read the design cold?** Start with [docs/00_overview.md](docs/00_overview.md) then follow the numbered docs.
- **Want to see the code?** Start with [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md).

## What Makes It Different

- **Cyberware skill tree** with mutually-exclusive tiers. Every run commits to a build.
- **Weapon Overclocks** drawn from randomized per-run pools.
- **Map state randomization** - power routing, PaP approach, wallbuy pool, perk pool re-roll each game.
- **Two currencies** - Points for the basics, Data Shards for the systems.
- **Vertical "Abyss Descent"** - soul-box layers below the city (L2/L3/L5) that open the Paradise plaza, plus trench-only stations (Exo Suit, Reactor Surge, Glitch Altar, Jukebox).
- **Optional risk/reward events** (Hack Terminal).
- **No Easter Egg mega-quest. No persistent meta-progression.** The loop is the product.

## Pillars

1. Meaningful upgrading.
2. Skill-based difficulty.
3. Replayability through fair randomization.
4. Multiple viable builds per run.
5. Skill over grind.

## Repo Layout

```
.
├── README.md                   this file
├── ROADMAP.md                  phase graph + summaries
├── SETUP_WINDOWS.md            one-time Windows dev-box setup
├── docs/                       design, mechanics, references, mapmaking KB
├── map_source/zm/              Radiant .map source (full multi-zone map)
├── scripts/zm/                 map entry scripts (.gsc / .csc) +
│   └── zm_abandoned_cyber_city/   custom _acc_ GSC modules
├── zone_source/                .zone asset manifest for the linker
├── sound/                      sound aliases + zone config (.szc)
├── zone/                       workshop publish assets (images, json example)
├── ui/                         custom LUI (Aetherium HUD + gun-badge row)
├── tools/                      build/sync scripts + helpers
└── .gitignore
```

When synced into the Mod Tools on Windows (`tools\sync_to_modtools.ps1`), `scripts/`, `zone_source/`, `sound/`, `zone/`, and `ui/` land in `usermaps\zm_abandoned_cyber_city\`, and `map_source\zm\zm_abandoned_cyber_city.map` lands in the game root's `map_source\zm\` (where Radiant expects it).

## Documentation

### Design

- [docs/00_overview.md](docs/00_overview.md) - pitch, pillars, anti-pillars, success criteria.
- [docs/02_layout.md](docs/02_layout.md) - zone graph and gameplay flow.
- [docs/03_progression_and_skills.md](docs/03_progression_and_skills.md) - Cyberware tree and Data Shard economy.
- [docs/04_weapons.md](docs/04_weapons.md) - the (box-only) arsenal, Overclocks, Pack-a-Punch.
- [docs/08_enemies.md](docs/08_enemies.md) - bestiary, elite timing, boss design.
- [docs/09_boss_items.md](docs/09_boss_items.md) - boss-drop items, slot rules, duplicate handling.
- [docs/10_perks.md](docs/10_perks.md) - the 10 perks (stock + custom, incl. Electric Cherry), per-run slot randomization.
- [docs/11_controls_and_hud.md](docs/11_controls_and_hud.md) - input bindings and HUD elements.
- [docs/12_coop_rules.md](docs/12_coop_rules.md) - multiplayer scaling and per-player vs shared rules.
- [docs/30_abyss_descent.md](docs/30_abyss_descent.md) - the vertical underground (soul boxes, Paradise gate).
- [docs/29_exo_suit_plan.md](docs/29_exo_suit_plan.md) - Exo Suit station and depth-gate.
- [docs/37_transfer_vault.md](docs/37_transfer_vault.md) - The Exchange transfer vault.
- [docs/39_armory.md](docs/39_armory.md) - the Armory upper room and bottle exchange.
- [docs/05_mechanics.md](docs/05_mechanics.md) - round pacing, economy, events, feedback loops.
- [docs/06_replayability.md](docs/06_replayability.md) - randomization, modifiers, build archetypes.
- [docs/13_reference_maps_study.md](docs/13_reference_maps_study.md) - design lessons from Ameliorama, Machin[a], and stock Treyarch maps.
- [docs/36_player_guide.md](docs/36_player_guide.md) - the in-fiction player guide.

### How to Build & Ship

- [SETUP_WINDOWS.md](SETUP_WINDOWS.md) - the install + build walkthrough.
- [docs/BO3_MAPMAKING_KB.md](docs/BO3_MAPMAKING_KB.md) - build pipeline, launch, GSC dialect, entity recipes, gotchas.
- [docs/17_launch_runbook.md](docs/17_launch_runbook.md) - launching the built `.ff` in-game (the gametype/split-install gotchas).
- [docs/21_adding_a_gun_runbook.md](docs/21_adding_a_gun_runbook.md) - end-to-end recipe for adding a weapon.
- [docs/19_lui_pipeline.md](docs/19_lui_pipeline.md) - custom LUI/HUD pipeline (Aetherium HUD, clientfield bridge).
- [docs/34_release_runbook.md](docs/34_release_runbook.md) - Steam Workshop release checklist.

### Reference

- [docs/14_stock_api_verification.md](docs/14_stock_api_verification.md) - the stock-API verification ledger (verified vs. fixed vs. refuted; the trap list). Read before touching stock interfaces.
- [docs/16_community_techniques.md](docs/16_community_techniques.md) - cited techniques lifted from shipped community sources.
- [docs/22_flags_reference.md](docs/22_flags_reference.md) - the `script_flag` / level-flag reference.
- [docs/15_requirements_checklist.md](docs/15_requirements_checklist.md) - requirements tracker.

### Project Management

- [docs/07_milestones.md](docs/07_milestones.md) - phased milestones with exit criteria.
- [ROADMAP.md](ROADMAP.md) - top-level phase graph.

### Code

- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module map, call order, event/state conventions, TODO marker legend.
- [tools/README.md](tools/README.md) - build + sync script usage and flags.

## Conventions

- **[REQUIREMENTS.md](REQUIREMENTS.md) is the spec.** Code follows docs, never the other way around.
- Every substantive change gets a [CHANGELOG.md](CHANGELOG.md) entry AND an update to the relevant detailed doc in the same commit.
- All custom GSC module **files** use the `_acc_` prefix ("abandoned cyber city") to separate them from stock `_zm_*` scripts. Their **GSC namespaces drop the leading underscore** (`_acc_main.gsc` declares `#namespace acc_main;`, called as `acc_main::`), mirroring the stock convention (`_zm_utility.gsc` → `zm_utility::`).
- Per-player state is stored on `self.acc_*` fields; level state on `level.acc_*`.
- Custom events use the `acc_*` namespace (e.g. `acc_round_start`, `acc_shards_changed`).
- **Dev/test mode is ONE hardcoded flag.** `acc_dev` resolves once (in `acc_main::acc_resolve_dev_flags()`) into `level.acc_dev`; every module gates on `IS_TRUE( level.acc_dev )`. There is no runtime dev console — never "set dvar X to test".
- BO3 GSC syntax, not WaW/BO1: `function` keyword on every definition, `&func` function pointers, entry scripts in `scripts/zm/` (not `maps/zm/`), `zm_usermap::main()` bootstrap (there is no `_zm::main()` in BO3).

## Systems (all built)

Orchestrated by `acc_main::init()` (`scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc`, ~48 active modules):

- **Economy & progression**: Data Shards, Cyberware tree, Weapon Overclocks, per-run map randomizer.
- **Weapons**: box-only arsenal (Apex + Skye ports + elemental bows), Pack-a-Punch tiers, gun-badge chip HUD row.
- **Perks**: 10 perks (stock + custom incl. Electric Cherry), escalating shard-cost perk slots (cap 10), a live 4-of-10 Lab-alcove rotation.
- **Enemies & bosses**: elites/trench skins; a mini-boss debut at round 10, then full boss rounds every 9 from round 9 (count scales), boss types dealt from a no-duplicate shuffled deck. Roster: Brutus, Glitch, Phantom, Avogadro, Panzer (mechz), and the Rogue/Civil Protector.
- **Underground**: the vertical Abyss Descent (soul-box layers → Paradise plaza), Exo Suit station, Reactor Surge, Glitch Altar, Jukebox, The Exchange transfer vault, the Armory upper room.
- **Presentation**: the Aetherium LUI HUD (shipped base) with a smooth round-progress bar, custom atmosphere/fog, and a full Radiant LED lightmap bake (~157 lights + ~15 reflection probes).

## Not a Goal

- Showcase-quality art.
- Main-quest Easter Egg.
- Persistent unlock grind.
- New-player accessibility.

## License

TBD.
