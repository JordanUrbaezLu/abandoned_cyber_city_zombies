// =============================================================================
// _acc_boss_items.gsc - boss-drop items (Machin[a]-style passive buffs)
//
// Design reference: docs/12_boss_items.md.
//
// Bosses drop random items from a 6-item pool on death. Players have 2 item
// slots. Duplicates auto-convert to 3 Data Shards.
//
// Status: STUB. Item table + drop/equip plumbing is in place; effect
// implementations are stubbed with TODOs for Phase 4 authoring.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_ITEM_SLOTS_PER_PLAYER 2
#define ACC_ITEM_PICKUP_RADIUS 64
#define ACC_ITEM_DROP_LIFETIME_SEC 60
#define ACC_ITEM_DUPLICATE_SHARD_CONVERT 3

#define ACC_BOSS_ITEM_DROP_CHANCE_MINI 0.50    // 50% from Juggernaut Host
#define ACC_BOSS_ITEM_DROP_CHANCE_FULL 1.00    // 100% from Subroutine Core

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "boss_items init (pool=6, slots=" +
                       ACC_ITEM_SLOTS_PER_PLAYER + ")" );

    level.acc_item_pool = build_item_pool();
}

// Payroll Ledger bonus applied as a multiplier on the player's share of kill
// points. Exposed as a constant here so _acc_points.gsc can reference it.
#define ACC_ITEM_LEDGER_POINTS_MULT 1.10

on_player_connect( player )
{
    // Array of equipped item-ids (max ACC_ITEM_SLOTS_PER_PLAYER).
    player.acc_equipped_items = [];
    // Per-item cooldowns / counters (for items like Ghost Shroud, Kinetic Battery).
    player.acc_item_state = [];
}

// ---------------------------------------------------------------------------
// Item pool
// ---------------------------------------------------------------------------

build_item_pool()
{
    pool = [];

    pool[ pool.size ] = item(
        "neural_boots",
        "Neural Boots",
        "feet",
        &apply_neural_boots,
        &remove_neural_boots
    );

    pool[ pool.size ] = item(
        "overclocked_gauntlets",
        "Overclocked Gauntlets",
        "hands",
        &apply_overclocked_gauntlets,
        &remove_overclocked_gauntlets
    );

    pool[ pool.size ] = item(
        "targeting_visor",
        "Targeting Visor",
        "head",
        &apply_targeting_visor,
        &remove_targeting_visor
    );

    pool[ pool.size ] = item(
        "kinetic_battery",
        "Kinetic Battery",
        "back",
        &apply_kinetic_battery,
        &remove_kinetic_battery
    );

    pool[ pool.size ] = item(
        "ghost_shroud",
        "Ghost Shroud",
        "chest",
        &apply_ghost_shroud,
        &remove_ghost_shroud
    );

    pool[ pool.size ] = item(
        "payroll_ledger",
        "Payroll Ledger",
        "implant",
        &apply_payroll_ledger,
        &remove_payroll_ledger
    );

    return pool;
}

item( id, display_name, slot, on_equip, on_unequip )
{
    i = spawnstruct();
    i.id = id;
    i.display_name = display_name;
    i.slot = slot;
    i.on_equip = on_equip;
    i.on_unequip = on_unequip;
    return i;
}

find_item( item_id )
{
    for ( i = 0; i < level.acc_item_pool.size; i++ )
    {
        if ( level.acc_item_pool[ i ].id == item_id )
        {
            return level.acc_item_pool[ i ];
        }
    }
    return undefined;
}

// ---------------------------------------------------------------------------
// Boss drop entry point. Called from _acc_boss.gsc on boss death.
//
// tier = "mini" | "full"
// killer = player who landed the killing blow (may be undefined)
// origin = boss corpse origin
// ---------------------------------------------------------------------------

on_boss_death( tier, killer, origin )
{
    chance = ACC_BOSS_ITEM_DROP_CHANCE_MINI;
    if ( tier == "full" ) chance = ACC_BOSS_ITEM_DROP_CHANCE_FULL;

    if ( _acc_utility::acc_rand_float() > chance )
    {
        _acc_utility::log( "boss_items: drop rolled but missed (" + tier + ")" );
        return;
    }

    // Pick a random item from the pool.
    picked = level.acc_item_pool[ _acc_utility::acc_rand_int( level.acc_item_pool.size ) ];

    // If killer already has this item, auto-convert to Shards right here.
    if ( isdefined( killer ) && isplayer( killer ) &&
         player_has_item( killer, picked.id ) )
    {
        _acc_data_shards::grant_player( killer, ACC_ITEM_DUPLICATE_SHARD_CONVERT,
                                        "boss_item_duplicate" );
        _acc_utility::log( "boss_items: " + picked.id +
                           " was duplicate for " + killer.name +
                           " -> +" + ACC_ITEM_DUPLICATE_SHARD_CONVERT + " shards" );
        return;
    }

    // Otherwise spawn a pickup entity at boss corpse.
    spawn_pickup( picked, origin );
}

// ---------------------------------------------------------------------------
// Pickup entity
// ---------------------------------------------------------------------------

spawn_pickup( item_struct, origin )
{
    // TODO(acc-model): swap `script_model` + tag_origin for a themed glowing
    // model per item slot (boots / gauntlets / visor / battery / shroud).
    pickup = spawn( "script_model", origin );
    pickup setmodel( "tag_origin" );
    pickup.acc_item_id = item_struct.id;
    pickup.acc_created_at = gettime();

    pickup thread watch_pickup();
    pickup thread watch_lifetime();
}

watch_pickup()
{
    self endon( "acc_item_claimed" );
    self endon( "death" );

    for ( ;; )
    {
        wait( 0.1 );
        closest = _acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( closest ) ) continue;
        if ( distancesquared( closest.origin, self.origin ) >
             ( ACC_ITEM_PICKUP_RADIUS * ACC_ITEM_PICKUP_RADIUS ) ) continue;

        // Attempt pickup.
        item_struct = find_item( self.acc_item_id );
        if ( !isdefined( item_struct ) ) break;

        if ( player_has_item( closest, item_struct.id ) )
        {
            // Already owned - convert to shards for this player.
            _acc_data_shards::grant_player( closest, ACC_ITEM_DUPLICATE_SHARD_CONVERT,
                                            "boss_item_duplicate" );
            self notify( "acc_item_claimed" );
            self delete();
            return;
        }

        if ( closest.acc_equipped_items.size >= ACC_ITEM_SLOTS_PER_PLAYER )
        {
            // TODO(acc-ui): show a replace prompt LUI for Phase 4. For now,
            // refuse and log - pickup stays on the ground.
            closest iprintln( "Inventory full - unequip via Cyberware Kiosk first" );
            wait( 1.0 ); // avoid spam re-checks from same player
            continue;
        }

        // Equip.
        equip_item( closest, item_struct.id );
        closest iprintln( "Picked up: " + item_struct.display_name );
        self notify( "acc_item_claimed" );
        self delete();
        return;
    }
}

watch_lifetime()
{
    self endon( "acc_item_claimed" );
    self endon( "death" );

    wait( ACC_ITEM_DROP_LIFETIME_SEC );

    if ( isdefined( self ) )
    {
        self delete();
    }
}

// ---------------------------------------------------------------------------
// Equip / unequip
// ---------------------------------------------------------------------------

player_has_item( player, item_id )
{
    if ( !isdefined( player.acc_equipped_items ) ) return false;
    for ( i = 0; i < player.acc_equipped_items.size; i++ )
    {
        if ( player.acc_equipped_items[ i ] == item_id ) return true;
    }
    return false;
}

equip_item( player, item_id )
{
    if ( player_has_item( player, item_id ) ) return;

    item_struct = find_item( item_id );
    if ( !isdefined( item_struct ) ) return;

    player.acc_equipped_items[ player.acc_equipped_items.size ] = item_id;
    player [[ item_struct.on_equip ]]();
}

unequip_item( player, item_id )
{
    item_struct = find_item( item_id );
    if ( !isdefined( item_struct ) ) return;

    new_arr = [];
    for ( i = 0; i < player.acc_equipped_items.size; i++ )
    {
        if ( player.acc_equipped_items[ i ] != item_id )
        {
            new_arr[ new_arr.size ] = player.acc_equipped_items[ i ];
        }
    }
    player.acc_equipped_items = new_arr;
    player [[ item_struct.on_unequip ]]();
}

// ---------------------------------------------------------------------------
// Effect implementations - STUBS
//
// Each apply_*/remove_* runs on `self` = the owning player. Item effects
// are mostly "set a flag or adjust a stat". Other modules read these flags
// to apply the actual gameplay effect.
// ---------------------------------------------------------------------------

apply_neural_boots()        { self.acc_item_neural_boots = true; setmovespeedscale_hook( self ); _acc_utility::log( "equip: neural_boots" ); }
remove_neural_boots()       { self.acc_item_neural_boots = false; setmovespeedscale_hook( self ); _acc_utility::log( "unequip: neural_boots" ); }

apply_overclocked_gauntlets()   { self.acc_item_gauntlets = true; _acc_utility::log( "equip: overclocked_gauntlets" ); }
remove_overclocked_gauntlets()  { self.acc_item_gauntlets = false; _acc_utility::log( "unequip: overclocked_gauntlets" ); }

apply_targeting_visor()     { self.acc_item_visor = true; _acc_utility::log( "equip: targeting_visor" ); }
remove_targeting_visor()    { self.acc_item_visor = false; _acc_utility::log( "unequip: targeting_visor" ); }

apply_kinetic_battery()
{
    self.acc_item_battery = true;
    self.acc_item_battery_kill_count = 0;
    self.acc_item_battery_charged = false;
    _acc_utility::log( "equip: kinetic_battery" );
}
remove_kinetic_battery()
{
    self.acc_item_battery = false;
    _acc_utility::log( "unequip: kinetic_battery" );
}

apply_ghost_shroud()
{
    self.acc_item_shroud = true;
    self.acc_item_shroud_ready_at = 0;
    _acc_utility::log( "equip: ghost_shroud" );
}
remove_ghost_shroud()       { self.acc_item_shroud = false; _acc_utility::log( "unequip: ghost_shroud" ); }

apply_payroll_ledger()      { self.acc_item_ledger = true; _acc_utility::log( "equip: payroll_ledger (+10% Points on kills)" ); }
remove_payroll_ledger()     { self.acc_item_ledger = false; _acc_utility::log( "unequip: payroll_ledger" ); }

// Exposed helper so _acc_points.gsc can apply the ledger bonus without
// knowing the implementation detail of the flag name.
player_has_ledger( player )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_item_ledger ) ) return false;
    return player.acc_item_ledger == true;
}

// Movement speed hook - applies +20% when Neural Boots equipped AND holding a primary.
// TODO(acc-verify): actual move speed API and interaction with stock.
setmovespeedscale_hook( player )
{
    base = 1.0;
    // Stacks multiplicatively with Cyberware Reflex Tier 1 (handled by that module).
    if ( isdefined( player.acc_item_neural_boots ) && player.acc_item_neural_boots )
    {
        // TODO(acc-verify): only apply when holding a primary (not pistol/knife alone).
        base = base * 1.20;
    }
    player setmovespeedscale( base );
}
