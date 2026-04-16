# 17 - Reference Maps Study

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
| Parallel progression tracks | Cyberware tree + Weapon Tier + PaP Level + Boss Items - four tracks in our design. |
| Skill tree with branches | Cyberware tree (3 branches × 3 tiers, mutually exclusive per tier). |
| Shared vs personal currencies | Points (personal) + Data Shards (personal, with split on co-op) + boss-item team drops. |
| Weapon leveling-via-use | We chose *explicit* Tier purchases via Shards instead of kill-grind. Similar intent, less grind. |

### What we explicitly did NOT take

- **No-round-system**: we kept standard BO3 rounds. Our pacing relies on round-gated unlocks (r5 Shielded, r30 full boss). Removing rounds would cascade a full pacing rework.
- **Resource farming loops**: Ameliorama asks players to chop wood / mine stone. We don't want resource farming; kills are the main resource generator.
- **Safe Zone vs Battlefield split**: we chose a single integrated map with in-combat buy locations.

### Known issues to avoid (from Steam comments on Ameliorama)

- **Menu-stuck bugs**: requiring force-quit because of UI state machine edge cases. We should stress-test our LUI interactions (Cyberware kiosk, Overclock terminal, item replace prompt).
- **Difficulty scaling outpacing currency acquisition**: a known Ameliorama pain point. Our Data Shard budget table is tight; we'll need a real playtest check.
- **Splitscreen / controller glitches in UI**: stock BO3 splitscreen has edge cases. We should decide early whether to explicitly test splitscreen (Phase 6) or declare it unsupported.

### Our open question

- Ameliorama's skill tree is **permanent through deaths**. Ours is per-run. If our per-run resets feel too punishing in playtest, we could consider a light permanent meta like "unlock one cyberware branch for free across all future runs". Currently documented as out-of-scope in [00_overview.md](00_overview.md).

---

## 2. Machin[a] (community, 2022-ish)

The "most advanced custom zombies map" per several youtube reviews. Cyber / industrial aesthetic, intricate EE, custom wonder weapons, **item drop system from bosses**.

### Core mechanics we should borrow

- **Boss-drop item system.** Bosses drop random passive-buff items. Players equip; effects stack; late runs assemble interesting combinations. **This is the single biggest pattern we took** - our `_acc_boss_items.gsc` is directly inspired.
- **Custom wonder weapons with unique boss synergy.** One weapon excels against one specific boss. We followed suit: Signal Staff → Subroutine Core, Vibro Cleaver → Juggernaut Host.
- **Integrated theme-mechanic alignment.** Machine/cyber theme shows up in WEAPON BEHAVIOR (not just art). Energy guns behave differently from gunpowder guns. Our Tac-19 (no headshot + bumped damage) follows this - its "energy blast" nature drives its damage rules.
- **Multi-stage upgrade for weapons.** Weapons upgrade through multiple tiers with visible external changes (glowing parts, new model bits). Our PaP L1-5 + Tier 1-5 should trigger visible weapon-state changes.

### What we took

| Machin[a] idea | Our equivalent |
|---|---|
| Boss-drop passive items | Our 6-item pool (Neural Boots, Gauntlets, Visor, Battery, Shroud, Payroll Ledger). |
| Boss-specific wonder weapon counters | Signal Staff vs Core; Vibro Cleaver vs Host. No counter overlap. |
| Energy weapon = different damage rules | Tac-19 no-headshot-mult + bumped base damage. |
| Craft-gated wonder weapons | Gated on side event completion (Hack / Overload). |

### What we explicitly did NOT take

- **Intricate main Easter Egg chain**: we dropped main EEs entirely per design direction in [00_overview.md](00_overview.md). Replaced with side events that gate wonder weapons.
- **High visual polish as a design pillar**: Machin[a] is art-heavy; our [00_overview.md](docs/00_overview.md) explicitly de-prioritizes art.

### Lessons from Machin[a] reception

- Players respond to **mechanics felt in-hand** (energy-weapon behavior, item slot decisions) more than lore. This validates our systems-first bias.
- The boss counter-weapon design **creates a progression lock**: players cannot skip the side events AND still comfortably beat round 30+ bosses. The "difficulty lock via acquisition" is a design tool we've copied.

---

## 3. Stock BO3 maps (Shadows of Evil, Der Eisendrache, Gorod Krovi, Revelations, ZNS, etc.)

When unsure how a system should behave, grep the stock map's GSC. These are the canonical implementations Treyarch built the framework around.

### Shadows of Evil (`zm_zod`)

- **Rituals and beast mode**: complex state-machine gameplay. Our Vault Overload is a distant cousin (timed point-defense with pressure wave scaling).
- **Shadow Man boss**: phase-based boss fight with add spawning and arena mechanics. Our Subroutine Core uses the same shape (phase transitions at HP thresholds, debuffs during phases, add waves).
- **Boss fight area lockout**: the Shadow Man fight locks you in. We do the same for Core.

### Der Eisendrache (`zm_castle`)

- **Bow / wonder weapon progression**: 4 elemental bows, each requiring an EE-style side quest to acquire. Our wonder weapon gating (side event + Shards) is a simpler version.
- **Map density**: small but dense. Our layout target.

### Origins (BO2, but canonical)

- **Elemental staffs**: four wonder weapons with distinct elemental damage types. Our Signal Staff + Vibro Cleaver model takes visual/mechanical cues here.
- **Panzer Soldat mini-boss**: flame-thrower mini-boss that spawns from round 8+. Our Juggernaut Host is structurally similar (mid-round pressure, distinct counter strategy).

---

## 4. Stock Zombies Framework — How Stock Maps Do It

Patterns we should mirror because stock is the path of least resistance:

### Round progression: `_zm.gsc`

- `level.round_number` increments.
- `level waittill( "start_of_round" )` fires at each round's start.
- `level.round_start_time` tracks when round began.
- Stock ties zombie HP and move speed to round number in a formula. We follow it with tweaks (see [04_progression_and_skills.md](04_progression_and_skills.md)), plus **rounds 1–4** spawn-count and move-speed pressure from [`06_mechanics.md`](06_mechanics.md) (early openers are faster and denser than stock).

### Power & perks: `_zm_power.gsc` + `_zm_perks.gsc`

- Stock: one power switch, flips once, stays on.
- Our variant: 1 of 2 switches is "live" per run (see `_acc_map_randomizer.gsc`). The other is cosmetic/locked.
- Perk machines require power on, then stay buyable for the rest of the run.

### Mystery Box: `_zm_magicbox.gsc`

- `treasure_chest_init()` sets up the initial spawn point.
- Box moves after N uses + random teddy bear chance.
- Weapons registered to the box pool via `add_zombie_weapon()` calls at init.
- Our `register_mystery_box_pool()` layers on top of this for our 8 bad/strong weapons.

### Zones: `_zm_zonemgr.gsc`

- Zones are named regions. Opening a zone enables zombie spawners in it.
- Stock pattern: debris/doors have triggers that call `open_zone("zone_name")`.
- Our 7 zones (see [03_layout.md](03_layout.md)) follow stock naming.

---

## 5. Critical Takeaways (for our implementation)

1. **Keep the `_zm_` module touch-points shallow.** We override the minimum necessary (damage hook, score hook, mystery-box pool, perk registration). Don't wholesale replace stock systems; extend them.
2. **Treat stock scripts as authoritative API.** When our design needs something, first grep stock to see if there's a helper for it.
3. **Boss fights are the biggest implementation risk.** Phase transitions, add spawning, arena lockout, multiple vulnerability windows - all complex. Budget Phase 4 accordingly.
4. **HUD / LUI is the biggest VISIBILITY risk.** Players judge the map by the HUD first. Phase 4 LUI work is make-or-break for perceived polish.
5. **Test for 2-hour stability.** Ameliorama runs go 3-4 hours. Desync and memory issues emerge only at long durations. Playtest should include at least one 90-minute session in Phase 6.

---

## 6. Unsolved Design Questions From This Study

Open items worth revisiting after study (tracked here so we don't forget):

- **Kill point streaks / combo bonus**: stock BO3 doesn't have this; some custom maps do. Should our multi-kill bonus return (was cut in v0.4)? Playtest Phase 6.
- **Weapon XP alternative to Tier?**: Ameliorama levels weapons via kills. Ours uses Shard spending. Hybrid ("first Tier free via weapon XP, rest via Shards")? Deferred.
- **Skill tree persistence as a modifier**: offer a modifier that makes Cyberware persist across deaths within a run? Would soften the respawn penalty.
- **Mini-boss variants**: Machin[a] has multiple mini-boss types per map. We have one (Juggernaut Host). Post-1.0 candidate.

---

## 7. Maps We Should Study Next

Ordered by relevance to our design:

1. **Machin[a]** — detailed pass through the workshop page and any community teardowns. Our biggest design cousin.
2. **Ameliorama II** — specifically its skill tree UI. Our Cyberware tree LUI should take visual cues.
3. **Shadows of Evil (`zm_zod`)** — the stock boss-fight + ritual patterns are what our Core fight + events should mirror.
4. **Der Eisendrache** — bow crafting as a template for our wonder weapon gates.
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
