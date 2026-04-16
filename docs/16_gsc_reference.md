# 16 - GSC / CSC / BO3 API Reference

Working reference for the BO3 zombies modding APIs we rely on. Verified against community canon (modme forums, bo3explorer, UGX Mods wiki) as of scaffold time. **Update this file when we discover new patterns or when stock API names drift.**

## Why This Doc Exists

The scaffold has a lot of `TODO(acc-verify)` markers because my (the AI pair-dev) training data was approximated. This doc collects the **verified** APIs so those TODOs can be resolved. When a future change needs a BO3 API, look here first.

---

## 1. Language Fundamentals

### File types

- **`.gsc`** - GameScript, server-side logic. Runs on the host / server in multiplayer.
- **`.csc`** - ClientScript, client-side logic. Runs on each player's machine. Used for local HUD, FX, sounds.
- **`.gsh`** - GSC header file. Shared constants, #defines, includes.
- **`.csh`** - CSC header file. Same role for client scripts.

Map-specific scripts live at `usermaps/<map>/scripts/zm/<map>/*.gsc`. Stock community scripts live at `share/raw/scripts/zm/...`.

### Preprocessor directives

```gsc
#using scripts\shared\callbacks_shared;    // import another file's public functions
#insert scripts\zm\_zm_utility.gsh;        // inline-include a header
#define ACC_HEADSHOT_MULT 2.0              // compile-time constant
#precache( "string", "ZOMBIE_FOO_STR" );   // tell the engine to load an asset at map load
```

- `#using` is preferred over `#include` in BO3.
- `#precache` is required for any localized string, FX, model, or sound that the script references.

### Syntax

- C-like: curly braces, semicolons, if/else/while/for.
- No classes. Use `spawnstruct()` for struct-like records.
- First-class function pointers via `&function_name`.
- Function pointer call: `obj [[ func_ptr ]]( args )`.

```gsc
my_function( arg1, arg2 )
{
    if ( arg1 > 0 )
    {
        result = do_thing( arg1 );
        return result;
    }
    return undefined;
}
```

### Scopes

- **`self`** - the entity the function is running on (implicit).
- **`level`** - global game state (everything persistent).
- **`game`** - cross-round game state (persists through restarts).

### Threading model

- `thread fn()` runs `fn` concurrently (coroutine-like).
- `wait(n)` suspends for n seconds (real time).
- `waittill("event")` suspends until an event is notified on the entity.
- `waittill("event", arg1, arg2)` also captures args.
- `notify("event", arg1)` fires the event.
- `endon("event")` kills the thread when the event fires. **Always** endon `"disconnect"` on player threads, `"death"` on entity threads, and `"end_game"` on level threads.

```gsc
self endon( "disconnect" );
for ( ;; )
{
    self waittill( "melee_hit", victim );
    victim thread on_melee_hit();
}
```

### Arrays and associative arrays

- Index-based: `arr[0]`, `arr[1]`.
- Key-based (associative): `dict["key"] = value;`.
- `arr.size` for length.
- `getarraykeys( dict )` to iterate an associative array.

```gsc
kills = 0;
keys = getarraykeys( zombie.acc_damage_contrib );
for ( i = 0; i < keys.size; i++ )
{
    entry = zombie.acc_damage_contrib[ keys[ i ] ];
    kills += entry.damage;
}
```

### Structs

```gsc
s = spawnstruct();
s.damage = 42;
s.player = self;
```

No type declarations; fields are created on assignment.

### `/# ... #/` - devmode blocks

Code inside `/# #/` only runs in dev builds (launcher with `-dev` flag). Use for logging, debug prints. Strip in release.

```gsc
/# println("[acc] " + msg); #/
```

---

## 2. BO3 Zombies Framework - What to Use

### The `callback` namespace (`scripts/shared/callbacks_shared.gsc`)

Global event-bus for engine events. Register via `callback::on_<event>(&fn)`.

**Key callbacks:**

| Callback | Fires when | Registration |
|---|---|---|
| `callback::on_connect( &fn )` | Player joins | `fn` runs with `self` = player |
| `callback::on_spawned( &fn )` | Player respawns (round start, revive) | `self` = player |
| `callback::on_disconnect( &fn )` | Player leaves | `self` = player |
| `callback::on_ai_spawned( &fn )` | Any AI actor spawns | `self` = actor |
| `callback::on_ai_damage( &fn )` | Any AI takes damage (pre-apply) | `self` = AI; fn can modify damage |
| `callback::on_ai_killed( &fn )` | AI dies | `self` = AI |

### `callback::on_ai_damage` signature (CRITICAL — canonical)

From modme forums (confirmed via bo3explorer `callbacks_shared.gsc` source):

```gsc
callback::on_ai_damage( &my_damage_fn );

my_damage_fn(
    str_mod,           // string, means of death: "MOD_RIFLE_BULLET", "MOD_MELEE", "MOD_HEAD_SHOT", "MOD_EXPLOSIVE", etc.
    str_hit_location,  // string, hit location: "head", "helmet", "torso_upper", etc.
    v_hit_origin,      // vector, world position of hit
    e_player,          // entity, the attacker (typically a player)
    n_amount,          // int, damage amount (you can modify and return)
    w_weapon,          // weapon struct
    direction_vec,     // vector, direction of damage
    tagName,           // string, bone/tag hit
    modelName,         // string
    partName,          // string
    dFlags,            // int, damage flags bitset
    inflictor,         // entity, actual damage source (can differ from e_player)
    chargeLevel        // int, for charged weapons
)
{
    // self == the AI entity being damaged
    // Modify n_amount and return it to change the damage applied.
    return n_amount;
}
```

**Implications for our code:** our `_acc_damage.gsc` had args in the wrong order / names. Fixed as of v0.8.0.

### Damage flow

1. Weapon fires.
2. Engine calculates raw damage from weapon GDT stats (including stock headshot mult baked into GDT).
3. `callback::on_ai_damage` fires for all registered handlers. Each can modify `n_amount`.
4. Engine applies final damage to AI HP.
5. If AI HP <= 0, engine triggers death. `callback::on_ai_killed` fires.
6. `zombie_killed` notify fires at level-scope (see below).

### `zombie_killed` notify (level-scope)

Fires on zombie death. Pattern:

```gsc
level endon( "end_game" );
for ( ;; )
{
    level waittill( "zombie_killed", zombie, attacker, mod, hit_location );
    // zombie = the AI entity (may already be freed, check isdefined)
    // attacker = the player who got the killing blow
    // mod = string means-of-death
    // hit_location = string (may be undefined)
}
```

From `scripts/shared/ai/zombie_utility.gsc`.

### Scoring

**`_zm_score::add_to_player_score( points )`** is the stock way to award points.

```gsc
#using scripts\zm\_zm_score;

self _zm_score::add_to_player_score( 100 );
// self = the player receiving points
// This handles HUD feedback, VO cues, and stock score tracking.
```

Direct `self.score += pts` works but bypasses the "+100" floater text players expect. **Always use the helper.**

### Clientfields

Register with:

```gsc
clientfield::register( str_type, str_name, n_version, n_bits, str_format_type );
```

Parameters:
- `str_type`: scope. Most common: `"toplayer"` (per-player), `"allplayers"` (broadcast), `"world"` (world state), `"clientuimodel"` (HUD binding).
- `str_name`: unique string ID.
- `n_version`: usually `1`.
- `n_bits`: bit width for the value. 1 bit = bool, 7 bits = 0-127, etc.
- `str_format_type`: `"int"`, `"float"`, `"counter"`.

Set with:

```gsc
self clientfield::set_to_player( "acc_data_shards", shard_count );
// self = the player
```

Register in `init()` on the server; read in `.csc` via UIModel bindings.

### Common utility modules

| Module | What it has |
|---|---|
| `scripts\zm\_zm` | Main zombies framework orchestrator (`_zm::main()`). |
| `scripts\zm\_zm_utility` | Helper functions: `get_closest_player`, `flag_set/wait`, `is_player_valid`, zone helpers. |
| `scripts\zm\_zm_score` | Point awards (`add_to_player_score`). |
| `scripts\zm\_zm_weapons` | Weapon registry, wallbuy setup, PaP config. |
| `scripts\zm\_zm_perks` | Perk registration, purchase, loss-on-death. |
| `scripts\zm\_zm_powerups` | Max ammo, insta-kill, double points drop logic. |
| `scripts\zm\_zm_magicbox` | Mystery Box. |
| `scripts\zm\_zm_zonemgr` | Zone activation / debris / doors. |
| `scripts\shared\ai\zombie_utility` | AI spawner helpers, zombie death tracking. |
| `scripts\shared\util_shared` | Math, array, misc helpers. |
| `scripts\shared\array_shared` | Array operations: `array::randomize`, `array::contains`, `array::remove_index`. |

### `level.max_zombie_func` (zombies spawned per round)

After the stock framework computes a base `n_max` from round + player count, it resolves the final count with:

```gsc
n_zombie_count = [[ level.max_zombie_func ]]( n_max, n_round );
```

If unset, stock assigns `&zombie_utility::default_max_zombie_func`. To modify counts, **save** the previous function pointer, assign your wrapper, and **delegate** to the saved pointer so you preserve stock behavior, then apply a multiplier or cap. Our early-round spawn boost uses this pattern in [`_acc_early_round_pacing.gsc`](../scripts/zm/zm_abandoned_cyber_city/_acc_early_round_pacing.gsc); `post_zm_main()` runs from `maps/zm/zm_abandoned_cyber_city.gsc` immediately after `_zm::main()` so the chain exists before round 1.

---

## 3. Common Patterns (Idioms We Should Use)

### Register on every zombie spawn

```gsc
callback::on_ai_spawned( &on_spawned_hook );

on_spawned_hook( actor )
{
    if ( !is_zombie( actor ) ) return;
    actor thread watch_death();
}
```

### Per-player init on connect

```gsc
callback::on_connect( &on_connect );

on_connect()
{
    self.acc_data_shards = 0;
    // self = the connecting player (implicit)
}
```

### Wait for round start

```gsc
level waittill( "start_of_round" );  // fires at each round start
level.round_number                   // int, current round
```

### Safe iteration over players

```gsc
for ( i = 0; i < level.players.size; i++ )
{
    p = level.players[ i ];
    if ( !isdefined( p ) ) continue;
    if ( !isplayer( p ) ) continue;
    p do_thing();
}
```

### Dvar read (for configuration)

```gsc
if ( getdvarint( "acc_mod_code_red", 0 ) == 1 )
{
    level.acc_mod_code_red = true;
}
```

Players can set dvars via console: `/set acc_mod_code_red 1`.

---

## 4. Weapon System

### Adding a custom weapon (from the modme guide)

1. Acquire or author the weapon's GDT files and model/anim assets.
2. Add the weapon filename to `share/raw/gamedata/weapons/zm/zm_levelcommon_weapons.csv`.
3. Copy an existing weapon's GDT entry as a template (same class: AR, shotgun, etc.), rename fields, tune stats.
4. In your map's zone source: include the weapon manifest line `weapon,sp/<weapon_name_zm>` in `usermaps/<map>/zone_source/<map>.csv`.
5. Add the weapon to the Mystery Box draftable pool or a wallbuy via `_zm_weapons::add_zombie_weapon()`.
6. Test: spawn via console `/give <weapon_name_zm>` or buy from wallbuy.

### Registering a weapon in the Mystery Box

```gsc
// TODO(acc-verify): confirm exact helper signature in _zm_weapons.
_zm_weapons::add_zombie_weapon( "ak47_zm", "Press &&1 for AK-47", 950, <ammo>, <upgrade>, <cost_upgrade> );
```

### Pack-a-Punch

The stock PaP "machine" is a script_struct with a specific targetname. When a player interacts, `_zm_magicbox::pack_a_punch_weapon_for_player()` runs. Our PaP L1-L5 design overrides this to loop 5 times.

TODO(acc-implement): our custom 5-level PaP needs to intercept the PaP trigger and replace stock single-upgrade with our cumulative level system. Phase 3 work.

---

## 5. Custom Perks (modme wiki pattern)

For our **Aura Blast**, **Deadshot**, and **Widow's Wine** perks (see [13_perks.md](13_perks.md)), follow this pattern:

1. **Script files**: create `_zm_perk_<name>.gsc`, `.csc`, and `.gsh` in `usermaps/<map>/scripts/zm/`. Use a template (Harry Bo21 / DTZxPorter base is canonical).
2. **`.gsh` file** defines:
   - Perk display name localized string.
   - Perk specialty (must be unique - engine enforces).
   - Bottle weapon file (vending machine's "pickup" item).
   - Models for machine and bottle.
3. **Zone file** additions:
   ```
   scriptparsetree,scripts/zm/_zm_perk_aura_blast.gsc
   scriptparsetree,scripts/zm/_zm_perk_aura_blast.csc
   scriptparsetree,scripts/zm/_zm_perk_aura_blast.gsh
   xmodel,<machine_model>
   weapon,<bottle_weapon_file>
   ```
4. **Radiant**: place the perk machine prefab at the slot location. Prefab has the struct targetname the script reads.
5. **Init** in `init()`:
   ```gsc
   _zm_perks::register_perk(
       "specialty_aura_blast",         // specialty id (engine-unique)
       &acquire_aura_blast,            // on-acquire callback
       "aura_blast_bottle_zm",         // bottle weapon GDT name
       2500,                           // point cost (see docs/13_perks.md)
       "Aura Blast",                   // display name
       "&&1 for Aura Blast [Cost: 2500]"
   );
   ```
6. **Effect function** (`acquire_aura_blast`) sets per-player flags + registers the active-ability hotkey listener.

Pattern for an **active** perk (Aura Blast-style):

```gsc
acquire_aura_blast()
{
    self.acc_perk_aura_blast = true;
    self.acc_perk_aura_blast_ready_at = 0;
    self thread aura_blast_ability_listener();
}

aura_blast_ability_listener()
{
    self endon( "disconnect" );
    self notify( "acc_aura_blast_restart" );
    self endon( "acc_aura_blast_restart" );

    for ( ;; )
    {
        self waittill( "acc_perk_ability" );   // hotkey-fired notify
        now = gettime();
        if ( now < self.acc_perk_aura_blast_ready_at )
        {
            self iprintln( "Aura Blast on cooldown" );
            continue;
        }
        self.acc_perk_aura_blast_ready_at = now + 120000;  // 120s CD in ms
        self trigger_aura_blast();
    }
}

trigger_aura_blast()
{
    // stun all enemies within 400u for 3s. Details in _acc_perks.gsc.
}
```

Pattern for a **damage-modifier** perk (Deadshot-style): hook into the existing `_acc_damage.gsc::on_ai_damage` pipeline rather than registering a separate damage callback.

Pattern for a **grenade-boost** perk (Widow's Wine-style): hook `weapon_fired` or the per-grenade explosion event; check owner's perk flag; boost radius/damage.

---

## 6. LUI (HUD) - Rough Guide

(Phase 4 work. Keeping this section short for now.)

- LUI files live in `usermaps/<map>/ui/uieditor/widgets/<map>/`.
- Each widget is a Lua file with a `CoD.Menu.NewForUIEditor` constructor.
- Widgets listen to clientfield changes via `LUI.OverrideFunction_CallOriginalSecond` on the UI state.
- For our HUD elements (Data Shards counter, Cyberware stack, etc.), the canonical pattern is:
  1. Register clientfield in GSC (server-side).
  2. Set clientfield when state changes.
  3. Widget in CSC binds to the clientfield via `CoD.UIModel.GetUIModelByRefName`.
  4. Widget re-renders on model change.

---

## 7. Known Gotchas

- **Editing `share/raw/scripts/zm/...`** is forbidden. Always copy to usermaps first.
- **Fast file size limit** is ~512MB (ish) - aggressive texture atlases and redundant assets eat this fast.
- **`#precache` missing** for a string/model/sound will cause silent runtime misses, not compile errors.
- **`zm_levelcommon_weapons.csv`** must be edited to register a weapon; zone source alone is not enough.
- **Radiant prefabs with children** - if you rename a child entity inside a stock prefab, scripts that look for the original targetname break silently. Don't rename inside prefabs; leave them alone.
- **`isdefined()` everywhere** - GSC is dynamic; an accessed undefined field throws a script error. Defensively check.
- **Match `callback::on_ai_damage` signature EXACTLY** - extra or mis-ordered args silently break.
- **Team string for zombies**: `"axis"` (not `"enemy"` or `"zombie"`).
- **`isplayer(e)`** vs `isplayer(self)` - `self` implicit, explicit arg is the check. `isplayer(self)` works inside method context.

---

## 8. Debug Loop

- Run game in **devmode** via Launcher's "Run Game" with dev flag.
- Console commands:
  - `/developer 1` + `/developer_script 1` - enable script errors in console.
  - `/set acc_mod_<name> 1` - toggle our modifiers at runtime.
  - `/give <weapon_name_zm>` - spawn a weapon.
  - `/spawn_round <round>` - skip to a round (for boss testing).
- Log output: `%USERPROFILE%\Documents\Call of Duty Black Ops III\usermaps\<map>\logs\console.log` (or similar; exact path varies).
- `iprintln( "text" )` for player-visible feedback; `iprintlnbold( "text" )` for big center text; `println( "text" )` for console-only.

---

## 9. Resource Ladder (canonical)

When stuck, in order:

1. **`bo3explorer.zeroy.com`** — indexed source of stock scripts. Search by filename.
2. **modme forums + wiki** — community-maintained tutorials and API refs.
3. **UGX Mods wiki** — older but comprehensive; some info drifts.
4. **`share/raw/scripts/zm/`** on your own install — the canonical source. Grep stock map scripts (e.g. `zm_zod.gsc`) for working examples.
5. **Discord communities**: "Zombie Modding", "UGX Mods", Modme. Real-time help.

---

## 10. Our Convention Summary

For every GSC module we write:

- `_acc_` prefix on the filename (namespaces custom from stock).
- Design-doc header comment pointing at the canonical design doc.
- Constants defined via `#define` at the top (tune knobs).
- `init()` public entry; per-player init via `on_player_connect(player)`.
- Every long-running thread has `endon("end_game")` at the top.
- Every per-player thread has `endon("disconnect")`.
- State lives on `self.acc_*` for players, `level.acc_*` for world.
- Custom events in `acc_*` namespace.
- `TODO(acc-verify)` for API calls I'm not 100% sure about.
- `TODO(acc-geom)` for lookups that depend on Radiant entities.
- `TODO(acc-tune)` for balancing knobs.
- `TODO(acc-ui)` for LUI work.

## Update Policy

When we discover a new BO3 API, verified signature, or convention, **add it to this doc in the same commit as the code change**. This is our growing API reference; keep it accurate.
