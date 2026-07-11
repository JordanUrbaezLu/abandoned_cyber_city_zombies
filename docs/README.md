# Docs index — Abandoned Cyber City

**One doc per topic. This index is the map; each doc below is the _single source
of truth_ for its subject.** Don't scatter the same fact across files — update it
where this index says it lives. Design intent flows top-down: `REQUIREMENTS.md`
(the spec) → these docs → the code. Where a doc and the code disagree, the
**code wins** and the doc is the bug (these were all reconciled against the code
on 2026-07-10).

> Renumbered + de-duplicated 2026-07-10 (65 docs → 40 + the KB). `CHANGELOG.md`
> entries dated before then reference the **old** numbers on purpose (history is
> not rewritten). Portable, map-agnostic mapmaking facts live in the
> **[BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md)** — read it first for any build/engine question.

## Orientation
| # | Doc | What it's for |
|---|-----|----------------|
| 00 | [Overview](00_overview.md) | The pitch: pillars, anti-pillars, target player, doc hub |
| 01 | [Toolchain](01_toolchain.md) | The BO3 Mod Tools toolchain + the headless build/test loop |
| — | [BO3_MAPMAKING_KB](BO3_MAPMAKING_KB.md) | **Portable** reusable mapmaking KB: pipeline, GSC dialect, entity recipes, gotchas |

## Design spec (what the map is)
| # | Doc | What it's for |
|---|-----|----------------|
| 02 | [Layout](02_layout.md) | Zones, flow, chokepoints, training spots, box-only distribution |
| 03 | [Progression & Skills](03_progression_and_skills.md) | Data Shards, Overclocks, the (disabled) Cyberware tree |
| 04 | [Weapons](04_weapons.md) | Arsenal, tier list, Overclock system, wonder weapons |
| 05 | [Mechanics](05_mechanics.md) | Core loop, events (Hack), decontamination history, economy math |
| 06 | [Replayability](06_replayability.md) | The three tiers of run-to-run variance + the 11 modifiers |
| 07 | [Milestones](07_milestones.md) | Build phases (historical → shipped) |
| 08 | [Enemies](08_enemies.md) | Zombie speed curve, elites, the boss roster + cadence |
| 09 | [Boss Items](09_boss_items.md) | The 10-item boss-drop pool, slots, shipped pickup models |
| 10 | [Perks](10_perks.md) | All 10 perks + Megas, slot cap/costs, Lab-alcove rotation |
| 11 | [Controls & HUD](11_controls_and_hud.md) | Input bindings + the shipped Aetherium HUD (bar, gun-badge row, etc.) |
| 12 | [Co-op Rules](12_coop_rules.md) | Co-op scaling, revive, split-screen, shared vs per-player state |
| 31 | [Vague UI Language](31_vague_ui_language.md) | Principle: hide magnitudes in-game; exact numbers live in docs |
| 32 | [Economy Sources](32_economy_sources.md) | Where Data Shards / Mega Bottles / Boss Items come from |
| 33 | [PaP Pricing & Box Odds](33_pap_pricing_tiers.md) | Pack-a-Punch tiers + mystery-box odds |
| 25 | [Weapon Stats Table](25_weapon_stats_table.md) | Per-weapon PaP-form stats reference |

## Feature deep-dives (specific systems)
| # | Doc | What it's for |
|---|-----|----------------|
| 24 | [Punishing the Middle](24_punishing_middle_design.md) | Mid-map risk/reward + lockdown design |
| 26 | [Lockdown Challenge Room](26_lockdown_challenge_room.md) | The "Glitch Purge" challenge room |
| 28 | [The Trench](28_trench_systems_guide.md) | High-level guide to every trench system |
| 29 | [Exo Suit](29_exo_suit_plan.md) | Exo Suit station + layered-trench depth-speed model |
| 30 | [Abyss Descent](30_abyss_descent.md) | The vertical soul-box layers → Paradise |
| 37 | [The Exchange](37_transfer_vault.md) | Player-to-player transfer vault |
| 39 | [The Armory](39_armory.md) | Upper-room weapon rack + mega-bottle exchange |

## Engineering reference
| # | Doc | What it's for |
|---|-----|----------------|
| 14 | [Stock API Verification](14_stock_api_verification.md) | Verified stock BO3 GSC/CSC API behavior + traps |
| 16 | [Community Techniques](16_community_techniques.md) | Cited techniques lifted from shipped community maps |
| 19 | [LUI Pipeline](19_lui_pipeline.md) | The Lua client HUD pipeline + LUI engineering rules/budgets |
| 20 | [Atmosphere & Materials](20_atmosphere_and_materials.md) | Wall/floor skins, sky, fog, lighting (shipped) |
| 21 | [Adding a Gun](21_adding_a_gun_runbook.md) | Reusable box-gun integration runbook + GDT/variant how-to |
| 22 | [Flags Reference](22_flags_reference.md) | Every dev/test/tuning dvar + the one-flag dev-mode design |
| 23 | [Sound & Music](23_sound_plan.md) | Alias inventory, per-event map, music channel, build pipeline |
| 27 | [Stock Models](27_stock_models.md) | Usable stock BO3 xmodels |
| 35 | [BO2 → BO3 Porting](35_bo2_to_bo3_asset_porting.md) | Asset porting pipeline (perk machines, props, mobs) |
| 13 | [Reference Maps Study](13_reference_maps_study.md) | Lessons lifted from shipped zombies maps |

## Ops & runbooks
| # | Doc | What it's for |
|---|-----|----------------|
| 17 | [Launch Runbook](17_launch_runbook.md) | How to actually open the built map |
| 18 | [Test Session](18_test_session.md) | Dev-sandbox test guide |
| 34 | [Release Runbook](34_release_runbook.md) | Steam Workshop build + publish procedure (incl. simple version) |
| 38 | [Workshop Marketing](38_steam_workshop_marketing.md) | Store-page / marketing kit |

## Trackers & player-facing
| # | Doc | What it's for |
|---|-----|----------------|
| 15 | [Requirements Checklist](15_requirements_checklist.md) | Master requirement-vs-implementation tracker |
| 36 | [Player Guide](36_player_guide.md) | New-player-facing guide |

**Root docs (not in this folder):** `REQUIREMENTS.md` (design spec / north star),
`MISSING_REQUIREMENTS.md` (still-open items), `ROADMAP.md`, `CHANGELOG.md`,
`CREDITS.md` (IP/attribution), `SETUP_WINDOWS.md`, `ONBOARDING.md`.
