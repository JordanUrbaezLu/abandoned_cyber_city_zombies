# 02 - Learning Path

Ordered curriculum for going from zero BO3 map experience to shipping this map. Roughly 60-100 hours of focused learning before you're productive on the custom systems.

## How to Use This Doc

- Each stage has an **objective**, a short list of **resources**, and an **exit test**.
- Don't skip ahead. BO3 modding has sharp edges; skipping Radiant fundamentals will cost you 10x later.
- Resources listed are community-maintained. URLs drift - search by title on Google, YouTube, the UGX Mods wiki, and CabConModding forums.

## Stage 1 - Orientation (4-6 hours)

**Objective.** Understand the toolchain end-to-end at a surface level. Don't build anything yet.

**Do this.**
- Read `01_toolchain.md` in this repo.
- Read Treyarch's official **Mod Tools Beginner's Guide** PDF (ships with the Mod Tools install).
- Watch any "Intro to BO3 Mod Tools" overview video (MakeCents has a recent one; NSZ Tom BMX has the classic one).
- Skim the UGX Mods wiki home page so you know what's there.

**Exit test.** You can explain (to a rubber duck) the role of Radiant, APE, Launcher, GSC, and LUI without looking anything up.

## Stage 2 - Radiant Fundamentals (8-12 hours)

**Objective.** Build a tiny room. Nothing fancy. The goal is confidence with the editor, not the output.

**Do this.**
- Follow a "Make your first BO3 zombies map" tutorial series end to end - MakeCents' or NSZ's. Budget ~8 hours; do not deviate.
- Topics you must be able to do without looking up: create brushes, caulk/hollow rooms, snap to grid, place `info_player_start`, add a light, compile with Launcher, run in-game.
- Topic you must understand but don't have to memorize: prefabs, patches, terrain.

**Exit test.** You can build a 2-room box map with a doorway, a light, and a functioning player spawn, and play it in BO3 zombies mode, in under 30 minutes, without referring to any guide.

## Stage 3 - Zombies Template (6-10 hours)

**Objective.** Get the `zm` template compiling with perks, Pack-a-Punch, Mystery Box, and a door working. Still ugly; still tiny.

**Do this.**
- Create a new map from the `zm` template in Radiant.
- Place the perk machine prefabs, one per stock perk (Jug, Quick Revive, Double Tap, Speed Cola, Stamin-Up, Mule Kick, plus whatever the template ships with).
- Place the Pack-a-Punch prefab.
- Place the Mystery Box prefab and its move locations.
- Add two zones connected by a debris/door prefab.
- Compile, run, play through round 10.

**Exit test.** You can hit round 10 on your own template map with all perks and PaP functional.

## Stage 4 - GSC Scripting Basics (10-15 hours)

**Objective.** Write, compile, and debug GSC. This is where your SWE background pays off.

**Do this.**
- Read the UGX Mods GSC language reference end to end. Short doc. C-like with event threads.
- Walk through a "Custom GSC script" tutorial - the classic examples are "give player points on zombie kill" and "spawn a zombie when you press a trigger".
- Read through stock `share/raw/scripts/zm/_zm_perks.gsc` and `_zm_weapons.gsc`. You won't understand it all - that's fine. The point is pattern exposure: `level.callback_*`, `self thread ...`, `on_player_connect`, `wait_till_trigger_activated`, etc.
- Learn the debug loop: `iprintln()` for quick log lines, `/developer 1` + `/developer_script 1` in console, reading `logs/console.log`.

**Key concepts to internalize.**
- `self` vs `level` vs `game` scope.
- Event threads and callbacks.
- The round flow: `level flag "initial_blackscreen_passed"`, `level.round_number`, round-start callbacks.
- How perks are registered (`_zm_perks::register_perk`) and how pack-a-punch variants are declared.
- How `clientfields` / CSC bridges to client-side effects.

**Exit test.** You can write a GSC module that: (1) gives the player 1 "Data Shard" when they kill a zombie with a headshot, (2) stores it on `self.data_shards`, (3) displays the count via `iprintln` when it changes. Compiled and working in-game.

## Stage 5 - APE & Custom Assets (lightweight, 4-6 hours)

**Objective.** Understand how assets enter the pipeline. We'll use stock assets heavily, but you need to be able to add a custom sound, material, or weapon variant.

**Do this.**
- Follow one tutorial on adding a custom weapon (reskin of stock, no new model).
- Follow one tutorial on adding a custom sound alias.
- Understand the `zone_source` CSV - what each column means, why an asset not listed there will silently fail at runtime.

**Exit test.** You added a new sound alias that plays on zombie death, and a weapon GDT that gives you a variant of the stock M8A7 with changed fire rate, both in the usermaps build.

## Stage 6 - LUI (deferred, 8-12 hours when we need it)

**Objective.** Build the Cyberware skill-tree UI and the Data Shard HUD.

**Do this only when we reach Phase 4 (see `08_milestones.md`).**
- Read CabConModding's LUI primer.
- Follow any "custom HUD element" tutorial - NSZ has one.
- Understand the HUD elem vs LUI widget split; pick the simplest tool that does the job.

**Exit test.** Data Shard count renders as a HUD number you can update from GSC in under 1 frame of delay, and clicking through a placeholder "skill tree" screen works without crashing the menu system.

## Community Resources (canonical, stable entry points)

- **UGX Mods Wiki** (`ugx-mods.com/wiki/index.php`) - reference-grade docs on GSC, zone CSV format, perk registration, weapons.
- **CabConModding** - forum + deep-dive GSC tutorials.
- **NSZ Zombies Modding** / **Tom BMX** YouTube channels - classic mapping series.
- **MakeCents** YouTube - current, long-form, Radiant through LUI.
- **Treyarch Mod Tools Beginner's Guide** - PDF in your Mod Tools install.
- **Zombie Modding Discord** servers - search for "Zombie Modding" or "UGX" - real-time help when you're stuck.

## When You Get Stuck

In priority order:
1. Search the UGX Mods wiki for the concept.
2. Grep `share/raw/scripts/zm/` for an existing example of what you're trying to do. Stock Treyarch code is your best reference.
3. Ask in a modding Discord with: a minimal repro, your `console.log` output, and what you've already tried.
4. Post on CabConModding forum as a last resort (slower response but archived).

Avoid: random YouTube videos more than 3 years old with low view counts. BO3 tooling has been stable, but some conventions have drifted.
