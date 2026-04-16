# Abandoned Cyber City

A custom **Call of Duty: Black Ops III** zombies map focused on **mechanics, skill expression, and replayability**. Inspired by Ameliorama I/II and Machin[a], with a deliberate bias toward systems depth over art and narrative.

> **Status**: Design complete, Phase 3 code scaffolded. No playable build yet - needs a Windows machine with BO3 Mod Tools to compile.

## Start Here

- **What are the requirements?** → **[REQUIREMENTS.md](REQUIREMENTS.md)**. This is the authoritative spec for every system. Design changes go in the doc first, code follows.
- **What changed recently?** → [CHANGELOG.md](CHANGELOG.md).
- **Waiting on Windows hardware?** The repo is pre-scaffolded; when the laptop arrives, follow [SETUP_WINDOWS.md](SETUP_WINDOWS.md).
- **Want to read the design cold?** Start with [docs/00_overview.md](docs/00_overview.md) then follow the numbered docs.
- **Want to see the code?** Start with [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md).

## What Makes It Different

- **Cyberware skill tree** with mutually-exclusive tiers. Every run commits to a build.
- **Weapon Overclocks** drawn from randomized per-run pools.
- **Map state randomization** - power routing, PaP approach, wallbuy pool, perk pool re-roll each game.
- **Two currencies** - Points for the basics, Data Shards for the systems.
- **Optional risk/reward events** (Hack Terminal, Vault Overload).
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
├── SETUP_WINDOWS.md            one-time Windows laptop setup
├── docs/                       design, mechanics, references (11 files)
├── maps/zm/                    map entry scripts (.gsc / .csc)
├── scripts/zm/zm_abandoned_cyber_city/
│                               custom _acc_ GSC modules (12 files)
├── zone_source/                asset manifest CSV for Launcher
├── ui/                         LUI (deferred to Phase 4)
├── tools/                      Windows sync script + helpers
└── .gitignore
```

When synced into the Mod Tools on Windows (`tools\sync_to_modtools.ps1`), the `maps/`, `scripts/`, `zone_source/`, and `ui/` trees mirror into `usermaps\zm_abandoned_cyber_city\`.

## Documentation

### Design

- [docs/00_overview.md](docs/00_overview.md) - pitch, pillars, anti-pillars, success criteria.
- [docs/03_layout.md](docs/03_layout.md) - zone graph and gameplay flow.
- [docs/04_progression_and_skills.md](docs/04_progression_and_skills.md) - Cyberware tree and Data Shard economy.
- [docs/05_weapons.md](docs/05_weapons.md) - arsenal (10-weapon shortlist), Overclocks, perks.
- [docs/11_enemies.md](docs/11_enemies.md) - bestiary, elite timing, boss design.
- [docs/12_boss_items.md](docs/12_boss_items.md) - 5 boss-drop items, slot rules, duplicate handling.
- [docs/13_perks.md](docs/13_perks.md) - 8 perks (6 stock + 2 custom), per-run slot randomization.
- [docs/14_controls_and_hud.md](docs/14_controls_and_hud.md) - input bindings, HUD elements, LUI plan.
- [docs/15_coop_rules.md](docs/15_coop_rules.md) - multiplayer scaling and per-player vs shared rules.
- [docs/16_gsc_reference.md](docs/16_gsc_reference.md) - verified BO3 GSC/CSC API reference (callbacks, scoring, clientfields, common patterns).
- [docs/17_reference_maps_study.md](docs/17_reference_maps_study.md) - design lessons from Ameliorama, Machin[a], and stock Treyarch maps.
- [docs/06_mechanics.md](docs/06_mechanics.md) - round pacing, economy, events, feedback loops.
- [docs/07_replayability.md](docs/07_replayability.md) - randomization, modifiers, build archetypes.

### How to Build & Ship

- [docs/01_toolchain.md](docs/01_toolchain.md) - BO3 Mod Tools reference.
- [docs/02_learning_path.md](docs/02_learning_path.md) - curriculum for going from zero to shipping.
- [docs/09_language_and_publishing.md](docs/09_language_and_publishing.md) - GSC/LUI basics and Steam Workshop publishing.
- [docs/10_today_quickstart.md](docs/10_today_quickstart.md) - fastest path to a box-room build on Workshop.
- [SETUP_WINDOWS.md](SETUP_WINDOWS.md) - the actual install + first-compile walkthrough.

### Project Management

- [docs/08_milestones.md](docs/08_milestones.md) - phased milestones with exit criteria.
- [ROADMAP.md](ROADMAP.md) - top-level phase graph.

### Code

- [scripts/zm/zm_abandoned_cyber_city/README.md](scripts/zm/zm_abandoned_cyber_city/README.md) - module map, call order, event/state conventions, TODO marker legend.
- [tools/README.md](tools/README.md) - sync script usage and flags.

## Conventions

- **[REQUIREMENTS.md](REQUIREMENTS.md) is the spec.** Code follows docs, never the other way around.
- Every substantive change gets a [CHANGELOG.md](CHANGELOG.md) entry AND an update to the relevant detailed doc in the same commit.
- All custom GSC modules use the `_acc_` prefix ("abandoned cyber city") to separate them from stock `_zm_*` scripts.
- Per-player state is stored on `self.acc_*` fields; level state on `level.acc_*`.
- Custom events use the `acc_*` namespace (e.g. `acc_round_start`, `acc_shards_changed`).
- Every file that has unverified API calls marks them `TODO(acc-verify)`. Grep for this on first compile.

## Status (first compile readiness)

When you sync and compile on Windows for the first time:

- **Will parse**: all files should be syntactically valid GSC.
- **Will fail gracefully**: any `TODO(acc-geom)` lookup for a Radiant entity that doesn't exist yet will log and continue - no crash.
- **Expect**: ~5-15 `TODO(acc-verify)` compile warnings about stock API function names that may need tweaking. These are documented in each file near the call site.
- **Don't expect**: a fully playable custom map on Day 1. The Radiant `.map` (geometry) still has to be authored in the editor. Once geometry is in place with the targetnames referenced in `TODO(acc-geom)` markers, the custom systems light up.

## Not a Goal

- Showcase-quality art.
- Main-quest Easter Egg.
- Persistent unlock grind.
- New-player accessibility.

## License

TBD.
