# _acc_ Custom GSC Modules

All custom gameplay logic for Abandoned Cyber City lives in this folder. The `_acc_` prefix ("abandoned cyber city") separates our modules from the stock `_zm_*` scripts that ship with BO3.

**Namespace convention** (mirrors stock): the file keeps the underscore, the GSC namespace drops it. `_acc_main.gsc` declares `#namespace acc_main;` and is called as `acc_main::init()` - exactly like stock `_zm_utility.gsc` → `zm_utility::`. Every function definition uses the BO3 `function` keyword.

## Module Map

| File | Purpose | Referenced by |
|---|---|---|
| `_acc_main.gsc` | Orchestrator. Registers stock callbacks, fans out to every other module. | `scripts/zm/zm_abandoned_cyber_city.gsc` |
| `_acc_early_round_pacing.gsc` | Rounds 1–4: chain `level.max_zombie_func` for extra spawns; `on_ai_spawned` move-speed boost. | `zm_abandoned_cyber_city.gsc` (`post_zm_main`), `_acc_main.gsc` (`init`) |
| `_acc_utility.gsc` | Shared helpers: logging, RNG, weighted pick, clamp, player lookup. | all |
| `_acc_data_shards.gsc` | Custom currency. Drop entity, pickup, HUD bridge, public spend/grant API. | cyberware, overclocks, elites, events, boss, emergency_drop |
| `_acc_cyberware.gsc` | Skill tree (9 nodes, 3 branches, mutual exclusion). Kiosk interaction stub. | main, data_shards |
| `_acc_overclocks.gsc` | Weapon Tier 1-5 progression + Overclock slots. Terminal interaction, weapon family classification, effect flags. | main, data_shards |
| `_acc_weapon_abilities.gsc` | Intrinsic active ability per weapon category (Triple Tap, Stabilizer, Precision Mode, etc). Hotkey + cooldown. | main |
| `_acc_boss_items.gsc` | 6-item boss-drop pool, 2 player slots, drop/equip/unequip/duplicate-to-Shards. | main, data_shards, boss, points (Ledger bonus) |
| `_acc_mega_bottles.gsc` | Empty Mega Bottle acquisition (1 per boss) + per-perk Mega flag system (sticks through death within run). | main, boss |
| `_acc_elites.gsc` | Shielded / Teleporter / EMP elite spawning and death rewards. | main, data_shards |
| `_acc_map_randomizer.gsc` | Per-run rolls: power switch, PaP path, wallbuy pool, perk pool, box initial. | main (via pre_init) |
| `_acc_events_hack.gsc` | Hack Terminal side event (3-stage objective). | main, data_shards |
| `_acc_events_overload.gsc` | Vault Overload point-defense event. | main, data_shards |
| `_acc_emergency_drop.gsc` | 3-Shard clutch button at power switches. | main, data_shards |
| `_acc_modifiers.gsc` | Opt-in rule-change toggles (Code Red, Shardless, etc.) via dvars for now. | main (via pre_init) |
| `_acc_boss.gsc` | Mini-boss (r10/r20) and full boss Subroutine Core (r30+). | main, data_shards |
| `_acc_points.gsc` | Kill-point awards (40 / 100 / 100) with co-op 70/30 damage split and anti-exploit rules. | main, damage |
| `_acc_damage.gsc` | Global AI damage hook. Applies 2x/3x headshot multiplier, forwards each hit to `_acc_points::record_damage`. | main |
| `_acc_decontamination.gsc` | Round 1-4 zone-seal hazard: per-run permutation, 20s evac window, kill-on-reentry, emits acc_decontamination_start/complete (perk rotation keys on complete). | main |
| `_acc_coop_scaling.gsc` | Co-op scaling: regular HP +100%/player, elites/bosses +50% (special_hp_mult), spawn rate +30%/player (max_zombie_func chain). | entry script (post_zm_main), main, elites, boss |
| `_acc_perk_aura_blast.gsc` | Aura Blast perk: hijacks the stock-but-unfinished `_zm_perk_electric_cherry` pipeline (overwrites cost/hint/give/take after `zm_usermap::main()`). 400u / 3s stun / 120s CD, crouch+melee activation. | `zm_abandoned_cyber_city.gsc` (direct, NOT via `acc_main`) |

## Call Order

```
scripts/zm/zm_abandoned_cyber_city.gsc :: main()
  -> zm_usermap::main()                // stock usermap bootstrap (calls load::main() internally;
                                       // BO3 has no _zm::main())
  -> acc_main::pre_init()              // registers callbacks, runs modifier + randomizer pre_init
    -> acc_modifiers::pre_init()
    -> acc_map_randomizer::pre_init()
  -> acc_perk_aura_blast::init()       // overwrite stock cherry registration (cost/hint/give/take);
                                       // AFTER zm_usermap::main(), BEFORE first game tick
  -> (template wiring: zones, start weapon, starting points)
  -> acc_early_round_pacing::post_zm_main()  // chain level.max_zombie_func BEFORE round 1
  -> acc_main::init()                  // threaded; all subsystems init after stock is up
    -> acc_early_round_pacing::init()  // on_ai_spawned speed hook
    -> acc_data_shards::init()
    -> acc_cyberware::init()
    -> acc_overclocks::init()
    -> acc_elites::init()
    -> acc_events_hack::init()
    -> acc_events_overload::init()
    -> acc_emergency_drop::init()
    -> acc_boss::init()
    -> acc_boss_items::init()          // item pool registration; wired to boss deaths
    -> acc_mega_bottles::init()        // mega bottle clientfield + Mega-perk flag tracking
    -> acc_weapon_abilities::init()    // ability table + hotkey listener
    -> acc_points::init()              // must init BEFORE acc_damage (record_damage callees)
    -> acc_damage::init()              // global AI damage hook (last so it sits on top)
    -> watch_round_transitions()       // fires acc_round_start / acc_round_end
```

## Event Conventions

Custom events this namespace publishes (subscribe via `level waittill(...)`):

- `acc_game_start` - fired after initial blackscreen passes.
- `acc_round_start` (args: round_number) - every round transition.
- `acc_round_end` (args: previous_round_number) - emitted right before the new round's start event.
- `acc_shards_changed` (args: player) - emitted when a player's shard count changes.
- `acc_cyberware_purchased` (args: player, node_id) - node bought.
- `acc_boss_dead` - full boss defeated.

## State Conventions

Per-player state lives as fields on `self` (the player), prefixed `acc_`:

- `self.acc_data_shards` (int) - currency count.
- `self.acc_cyberware_nodes` (array of string node ids) - purchased nodes.
- `self.acc_cyberware_respecs_used` (int) - respec counter.
- `self.acc_cw_*` - individual cyberware effect flags (damage_mult, sprint_boost, etc.).
- `self.acc_weapon_progress` (map of weapon_name -> { tier, overclocks[] }) - weapon tier state.
- `self.acc_oc_active` (map of weapon_name -> struct of flags) - effect toggles per weapon.
- `self.acc_equipped_items` (array of item_id) - equipped boss items (max 2).
- `self.acc_item_state` (map of item_id -> struct) - per-item runtime state (cooldowns, counters).
- `self.acc_item_*` (various flags) - per-item effect toggles (e.g. `acc_item_neural_boots`, `acc_item_battery_charged`).
- `self.acc_mega_bottles` (int) - empty Mega Bottle count in inventory.
- `self.acc_mega_perks` (map of specialty_string -> true) - Mega'd perks; sticks across death within a run.
- `self.acc_ability_ready_at` (map of ability_id -> gametime ms) - per-ability cooldowns.
- `self.acc_ability_*_primed` / `acc_ability_*_until` - per-ability effect state flags.

Level state lives on `level.acc_*`:

- `level.acc_map_state` (struct) - per-run rolled state.
- `level.acc_modifiers` (map of name -> true) - active modifiers this run.
- `level.acc_cyberware_tree` (struct) - node graph.
- `level.acc_oc_pools` (map of family -> array) - all Overclocks per family.
- `level.acc_oc_active` (map of family -> array) - active 3 per family this run.
- `level.acc_hack_state`, `level.acc_overload_state` - event state machines.
- `level.acc_elite_active_count` (int) - live elite count (for pacing).

Per-actor state used by `_acc_damage.gsc`:

- `actor.acc_is_boss` (bool) - set by `_acc_boss.gsc` on full-boss spawn; triggers 3x headshot.
- `actor.acc_is_mini_boss` (bool) - set by `_acc_boss.gsc` on Juggernaut Host spawn; triggers 3x headshot.
- `actor.acc_is_elite` (bool) - set by `_acc_elites.gsc`; keeps the 2x regular headshot multiplier (no special case needed).

Per-actor state used by `_acc_points.gsc`:

- `actor.acc_damage_contrib` (map of player-entnum -> { damage, player }) - cumulative per-player damage, capped at actor maxhealth. Cleared on actor death (GC'd with the actor).

## TODO Markers

Grep for these to find things that need verification against stock BO3 code once the Mod Tools are installed:

- `TODO(acc-verify)` - API name or behavior I'm not 100% sure is the exact BO3 spelling. Most likely to need tweaks on first compile.
- `TODO(acc-geom)` - requires a Radiant-placed entity with a specific targetname.
- `TODO(acc-model)` - needs a custom or stock model asset.
- `TODO(acc-fx)` - visual effect to author / pick from stock.
- `TODO(acc-tune)` - balancing knob, decision deferred to playtest.
- `TODO(acc-config)` - config/UI wiring, not core logic.
- `TODO(acc-ui)` - LUI work, deferred to Phase 4.
- `TODO(acc-data)` - data table that should be external (CSV/GDT) not inline code.

Rough expected count by status on first clean compile:
- **Will compile**: all files should parse and the script graph should load.
- **Will probably throw runtime warnings**: `TODO(acc-verify)` sites where stock API spelling drifted.
- **Will silently no-op**: `TODO(acc-geom)` sites - they look for Radiant targetnames that don't exist yet.

## Design -> Code Traceability

Every module's header block points at its canonical design doc. If you change a design doc, update the header comment and any constants in the module. Keep them in sync.
