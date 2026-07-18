# 13 - Reference Maps Study

> **Implementation-level techniques** (exact KVPs/APIs with citations from
> shipped community sources) live in **[16_community_techniques.md](16_community_techniques.md)**;
> this doc stays design-level. Raw research dossiers: [research/](research/).

Design patterns and implementation lessons from the custom zombies maps we're inspired by + stock maps we can learn from. Updated as we study more maps.

## Why This Doc Exists

We keep citing "Ameliorama" and "Machin[a]" as inspirations. This doc captures the **concrete** design patterns from those maps (and others worth studying) and maps them to our own decisions. When we're stuck on a design choice, check if a reference map already solved it.

---

## 1. Ameliorama I / II (GoGu, 2021 / 2023)

Steam Workshop: the defining "modern" custom zombies map for deep progression systems. We cite it for skill trees and long-run depth.

### Core mechanics we should borrow

- **Parallel-track progression.** Base/character upgrades via one currency, skill tree via another, single-use lab upgrades via a third. Three systems operating at different timescales.
- **No traditional round system.** Zombies spawn continuously; HP and spawn rates ramp on a continuous curve. Changes pacing feel dramatically.
- **Weapon leveling.** A weapon levels up through kills; level-ups grant emerald currency. Rewards weapon commitment.
- **Dual currency tiers.** Shared currencies (wood, stone, iron) for team resources + personal currencies (gold, emerald) for personal upgrades.
- **Extra-life economy.** Paid "extra life" item spawns you back with 10s invisibility. Distinct from self-revive; it's a purchased resource, not a perk.

### What we took

| Ameliorama idea | Our equivalent |
|---|---|
| Parallel progression tracks | Weapon Tier + PaP Level + Overclock terminal (`_acc_overclocks.gsc`) + Boss Items — the live tracks. The Cyberware skill tree (`_acc_cyberware.gsc`) was designed as a fourth track but is **disabled in play** (turned off 2026-06-19; dormant behind `acc_cyberware_on`, default 0). The Overclock terminal is now the sole weapon-upgrade sink. |
| Skill tree with branches | Cyberware tree (3 branches × 3 tiers, mutually exclusive per tier) — **built but dormant**; re-enable with `acc_cyberware_on 1`. |
| Shared vs personal currencies | Points (personal) + Data Shards (`_acc_data_shards.gsc`, personal, co-op split) + boss-item team drops. Team-shared transfers ride "The Exchange" (`_acc_transfer.gsc`). |
| Weapon leveling-via-use | We chose *explicit* Tier / PaP purchases via Shards instead of kill-grind. Similar intent, less grind. |

### What we explicitly did NOT take

- **No-round-system**: we kept standard BO3 rounds. Our pacing relies on round-gated content (mini-boss from round 10, boss rounds every 9 from round 9 — see `_acc_boss.gsc` + `_acc_civil_protector.gsc`). Removing rounds would cascade a full pacing rework.
- **Resource farming loops**: Ameliorama asks players to chop wood / mine stone. We don't want resource farming; kills are the main resource generator.
- **Safe Zone vs Battlefield split**: we chose a single integrated map with in-combat buy locations.

### Known issues to avoid (from Steam comments on Ameliorama)

- **Menu-stuck bugs**: requiring force-quit because of UI state machine edge cases. We stress-test our LUI interactions (Overclock terminal, item-replace prompt; the Cyberware kiosk LUI is **dormant** — the kiosk is unspawned and its skill-tree screen is still a Phase-4 stub) — our HUD/menu bridge is the Aetherium LUI kit (`_zm_aetherium_hud`), so watch for never-closed `LUI.UITimer` state-pool leaks specifically.
- **Difficulty scaling outpacing currency acquisition**: a known Ameliorama pain point. Our Data Shard budget table is tight; keep an eye on it in playtest.
- **Splitscreen / controller glitches in UI**: stock BO3 splitscreen has edge cases. Decide whether to explicitly support/test splitscreen or declare it unsupported.

### Our open question

- Ameliorama's skill tree is **permanent through deaths**. Our Cyberware tree was designed per-run — but note it is currently **dormant** (disabled in play, see §1), so this is a question for if/when we re-enable it. If per-run resets feel too punishing in playtest, we could consider a light permanent meta like "unlock one cyberware branch for free across all future runs". Currently out-of-scope in [00_overview.md](00_overview.md).

---

## 2. Machin[a] (community, 2022-ish)

The "most advanced custom zombies map" per several youtube reviews. Cyber / industrial aesthetic, intricate EE, custom wonder weapons, **item drop system from bosses**.

### Core mechanics we should borrow

- **Boss-drop item system.** Bosses drop random passive-buff items. Players equip; effects apply while implanted; late runs assemble interesting combinations. **This is the single biggest pattern we took** — our `_acc_boss_items.gsc` is directly inspired.
- **Custom wonder weapons with unique boss synergy.** In Machin[a] one weapon excels against one specific boss. We **considered** this (early docs named a "Signal Staff" / "Vibro Cleaver") but **never shipped boss-specific wonder weapons** — they don't exist in `gamedata/weapons/zm/zm_levelcommon_weapons.csv`. Our arsenal is **box-only** and large (Apex ports + Skye ports + elemental bows) rather than a small counter-weapon set. See "did NOT take" below.
- **Integrated theme-mechanic alignment.** Machine/cyber theme shows up in WEAPON BEHAVIOR (not just art). Energy guns behave differently from gunpowder guns. **We shipped this**: energy weapons (Havoc beam rifle, Tac-19, AE4, Blast-O-Matic, CEL-3, Triple Take, Peacekeeper) are flagged by `_acc_damage::is_energy_weapon()` and buffed by the Plasma Generator (+10% energy) implant; explosive weapons get Warhead Bomber (+20%); bullet guns get High Caliber Rounds (+25%). RW1 is bullet; Fire Bow / Thundergun / Winter's Howl are none. The **Tac-19** is our headline example: `is_weapon_headshot_excluded()` drops its headshot multiplier and it trades that for a bumped base damage in its GDT, making it the crowd-control gun (`_acc_damage.gsc:1620` `is_energy_weapon` / `:1639` `is_weapon_headshot_excluded`, Tac-19 at `:1652`).
- **Multi-stage upgrade for weapons.** Weapons upgrade through multiple tiers with visible external changes. Our PaP L1–3 (`_acc_pap_levels.gsc`, `ACC_PAP_MAX_TIER = 3`) + Overclocks (`_acc_overclocks.gsc`) drive weapon-state escalation.

### What we took

| Machin[a] idea | Our equivalent |
|---|---|
| Boss-drop passive items | Our 10-item pool in `_acc_boss_items.gsc::build_item_pool()`: Gas Tank, Loot Stash, Repair Kit, Rocket Shield, Phase Serum, Boots, Lucky Horseshoe, Turbocharger (Havoc), Nuclear Energy, Battery. Fixed 3-slot implant bench (docs/09). |
| Energy weapon = different damage rules | Tac-19 no-headshot-mult + bumped base damage; energy-weapon family gets the Plasma Generator +10% layer (explosive gets Warhead Bomber +20%). |
| Multi-stage weapon upgrade | PaP L1–3 + Overclocks. |

### What we explicitly did NOT take

- **Boss-specific wonder-weapon counters**: the early "Signal Staff → boss X" / "Vibro Cleaver → boss Y" idea was **abandoned, never built** (no entries in the weapon table). Our difficulty gate is boss HP tuning + the box arsenal, not a mandatory counter-weapon.
- **Intricate main Easter Egg chain**: we dropped main EEs entirely per design direction in [00_overview.md](00_overview.md). Replaced with the Hack Terminal side event (`_acc_events_hack.gsc`; its +2 Data-Shard reward is **off by default** behind the `acc_hack_shard_drop` dvar, so shards come from the trench economy, not the terminal) and the Reactor Surge / Glitch Altar / Jukebox POIs — **not** wonder-weapon craft gates.
- **High visual polish as a design pillar**: Machin[a] is art-heavy; our [00_overview.md](00_overview.md) explicitly de-prioritizes art.

### Lessons from Machin[a] reception

- Players respond to **mechanics felt in-hand** (energy-weapon behavior, item-slot decisions) more than lore. This validates our systems-first bias — and is why we kept the energy-weapon damage distinction even after dropping the counter-weapon idea.

---

## 3. Stock BO3 maps (Shadows of Evil, Der Eisendrache, Gorod Krovi, Revelations, ZNS, etc.)

When unsure how a system should behave, grep the stock map's GSC. These are the canonical implementations Treyarch built the framework around.

### Shadows of Evil (`zm_zod`)

- **Rituals and beast mode**: complex state-machine gameplay. Our side events (Hack Terminal, Reactor Surge) are distant cousins — timed objective sequences with pressure scaling. (The old "Vault Overload" timed point-defense event was **retired 2026-07-07** and is commented out in `_acc_main.gsc` — nothing reads `level.acc_overload_state` anymore.)
- **Shadow Man boss**: phase-based boss fight with add spawning and arena mechanics. We do **not** copy the arena-lockout shape. Our current model is a **multi-boss roster**: boss rounds deal from a no-duplicate shuffled **4-type deck** (Phantom, Rogue/Civil Protector, Avogadro, Panzer — `_acc_civil_protector.gsc:247-250`), while Brutus (round 10/20) and Glitch run on their own independent mini-boss cadences outside that deck — no single scripted "Shadow Man"-style fight, no arena lockout. (An earlier single "Subroutine Core" full boss with HP-threshold phases + arena lockout was **removed 2026-06-22**, superseded by the roster.)

### Der Eisendrache (`zm_castle`)

- **Bow / wonder weapon progression**: 4 elemental bows, each requiring an EE-style side quest to acquire. We **ported elemental bows** (`elemental_bow_demongate`, docs/hb21) but they're **box-obtainable**, not quest-gated — we dropped the acquisition quest.
- **Map density**: small but dense. Our layout target.

### Origins (BO2, but canonical)

- **Elemental staffs**: four wonder weapons with distinct elemental damage types. We drew visual/mechanical cues from these for the elemental bows we ended up shipping (the "Signal Staff"/"Vibro Cleaver" names never shipped — see §2).
- **Panzer Soldat mini-boss**: flame-thrower mini-boss that spawns from round 8+. **We shipped a Panzer** (`_acc_boss_panzer.gsc`, mechz-based) as a roster boss — structurally similar mid-round pressure with a distinct engagement pattern (electroball zap).

---

## 4. Stock Zombies Framework — How Stock Maps Do It

Patterns we mirror because stock is the path of least resistance:

### Round progression: `_zm.gsc`

- `level.round_number` increments.
- `level waittill( "start_of_round" )` fires at each round's start.
- `level.round_start_time` tracks when round began.
- Stock ties zombie HP and move speed to round number in a formula. We follow it with tweaks (see [03_progression_and_skills.md](03_progression_and_skills.md)), plus custom **early-round** spawn-count / move-speed pressure from [`05_mechanics.md`](05_mechanics.md) (early openers are faster and denser than stock).

### Power & perks: `_zm_power.gsc` + `_zm_perks.gsc`

- Stock: one power switch, flips once, stays on.
- Our variant: **one** power switch (the Bus Station "corp" switch, script_string `corp`). An earlier dual-switch design (corp / vault, live one rolled per run) was cut — the vault switch prefab was removed from the map source 2026-06-18, so `_acc_map_randomizer.gsc::roll_power_switch_side()` now hardcodes `return "corp";` (the `acc_power_side` override is retired).
- Perk machines require power on, then stay buyable for the rest of the run. We ship **10 perks** (Electric Cherry is the real 10th, finishing the stock-but-unfinished pipeline); slot cap `ACC_PERK_SLOT_MAX = 10` (`_acc_perks.gsc`) with escalating shard costs, and the Lab alcove runs a live 4-of-10 door roll (`_acc_perk_doors.gsc`, `ACC_PERK_DOORS_OPEN_PER_ROUND = 4`).

### Mystery Box: `_zm_magicbox.gsc`

- `treasure_chest_init()` sets up the initial spawn point.
- Box moves after N uses + random teddy bear chance.
- Weapons registered to the box pool via `add_zombie_weapon()` calls at init.
- Our `register_mystery_box_pool()` layers on top with our **large box-only arsenal** (Apex + Skye ports + elemental bows) — weapons are box-obtained, there is no wallbuy-only shortlist.

### Zones: `_zm_zonemgr.gsc`

- Zones are named regions. Opening a zone enables zombie spawners in it.
- Stock pattern: debris/doors have triggers that call `open_zone("zone_name")`.
- Our 7 zones (see [02_layout.md](02_layout.md)) follow stock naming. Note the vertical **Abyss Descent** (L2/L3/L5 soul-box layers → Paradise plaza), which reuses the start-zone volume and merges by targetname.

---

## 5. Critical Takeaways (for our implementation)

1. **Keep the `_zm_` module touch-points shallow.** We override the minimum necessary (damage hook, score hook, mystery-box pool, perk registration). Don't wholesale replace stock systems; extend them.
2. **Treat stock scripts as authoritative API.** When our design needs something, first grep stock to see if there's a helper for it (ledger: docs/14).
3. **Boss fights are the biggest implementation surface.** Phase transitions, add spawning, multi-boss debt directors, multiple vulnerability windows — all complex. The roster is built (`_acc_boss*.gsc` + `_acc_civil_protector.gsc` shared `level.acc_boss_roster_fn`); keep new bosses on the shared roster so the no-duplicate deck and per-type debt directors cover them automatically.
4. **HUD / LUI is the biggest VISIBILITY risk.** Players judge the map by the HUD first. Our shipped base is the Aetherium LUI HUD (`_zm_aetherium_hud`, base since 2026-07-03) with the gun-badge chip row (2026-07-08) and a smooth round-progress **bar** (the radial ring was abandoned).
5. **Test for long-run stability.** Ameliorama runs go 3–4 hours. Desync and memory issues (e.g. LUI state-pool exhaustion) emerge only at long durations. Include at least one 90-minute session in playtest.

---

## 6. Unsolved Design Questions From This Study

Open items worth revisiting (tracked here so we don't forget):

- **Kill point streaks / combo bonus**: stock BO3 doesn't have this; some custom maps do. Should our multi-kill bonus return (it was cut in an earlier balance pass)? Playtest call.
- **Weapon XP alternative to Tier?**: Ameliorama levels weapons via kills. Ours uses Shard spending. Hybrid ("first Tier free via weapon XP, rest via Shards")? Deferred.
- **Skill tree persistence as a modifier**: offer a modifier that makes Cyberware persist across deaths within a run? Would soften the respawn penalty. (Moot until the Cyberware tree is re-enabled — it's dormant in ship, see §1.)
- **Mini-boss / boss-type variety**: Machin[a] has multiple mini-boss types per map. We ship a **Brutus mini-boss** (Trench Warden, its own cadence) plus a **4-type boss roster** dealt from a no-duplicate shuffled deck (Phantom / Rogue Protector / Avogadro / Panzer). Room for more roster entries post-1.0 — add via the shared roster fn. (reconciled to code 2026-07-11)

---

## 7. Maps We Should Study Next

Ordered by relevance to our design:

1. **Machin[a]** — detailed pass through the workshop page and any community teardowns. Our biggest design cousin.
2. **Ameliorama II** — specifically its skill tree UI. If we re-enable the (currently dormant) Cyberware tree, its LUI should take visual cues from here.
3. **Shadows of Evil (`zm_zod`)** — the stock boss-fight + ritual patterns are what our boss fights + side events should mirror.
4. **Der Eisendrache** — bow crafting as a reference for elemental-bow behavior (we dropped the acquisition quest, kept the bows).
5. **Leviathan** and **Tranzit: Reimagined** — long-tail community maps known for clean GSC; source-dive for idioms.

When we study a new map, append findings here with:

- Map name + author.
- Core design patterns observed.
- What we took.
- What we rejected and why.
- Any technical gotchas noted by players.

---

## 8. Reference Resources

- **bo3explorer** (`bo3explorer.zeroy.com`): searchable index of stock BO3 scripts + models + assets. Critical for API verification.
- **Modme Forums** (`forum.modme.co`): actively maintained wiki for BO3 + legacy CoDs. Our perk + damage references came from here.
- **UGX Mods Forums / Wiki**: older but comprehensive; some info drifts. Good for broad context.
- **Zeroy's BO3 source explorer**: same as bo3explorer; canonical.
- **Harry Bo21 / DTZxPorter**: community veterans whose base scripts are the starting templates for custom perks, weapons, menus.

## Update Policy

Each time we adopt a pattern from a map OR decide explicitly to reject one, log it here in the relevant map's section. This doc grows with the project and becomes institutional knowledge.
