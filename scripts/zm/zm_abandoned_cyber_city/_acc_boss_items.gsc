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

#namespace acc_boss_items;

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

function init()
{
    acc_utility::log( "boss_items init (pool=6, slots=" +
                       ACC_ITEM_SLOTS_PER_PLAYER + ")" );

    level.acc_item_pool = build_item_pool();
}

// Payroll Ledger points bonus: the multiplier is owned by _acc_points.gsc as
// ACC_POINTS_LEDGER_MULT (GSC #defines are file-local; #using does not share
// macros - only a .gsh pulled in via #insert does). _acc_points.gsc applies
// the bonus by calling acc_boss_items::player_has_ledger(). If the value ever
// needs to be shared, move it into a common .gsh and #insert it from both files.

function on_player_connect( player )
{
    // Array of equipped item-ids (max ACC_ITEM_SLOTS_PER_PLAYER).
    player.acc_equipped_items = [];
    // Per-item cooldowns / counters (for items like Ghost Shroud, Kinetic Battery).
    player.acc_item_state = [];
    player thread reapply_move_speed_on_spawn();
}

// VERIFIED(acc): zm_usermap giveCustomCharacters() runs SetMoveSpeedScale(1)
// on EVERY player spawn (zm_usermap.gsc:336), silently wiping the Neural
// Boots bonus on respawn - reapply after each "spawned_player" notify
// (notify site _zm.gsc:3337).
function reapply_move_speed_on_spawn()
{
    self endon( "disconnect" );
    for ( ;; )
    {
        self waittill( "spawned_player" );
        wait( 0.05 ); // run after zm_usermap giveCustomCharacters() resets to 1
        setmovespeedscale_hook( self );
    }
}

// ---------------------------------------------------------------------------
// Item pool
// ---------------------------------------------------------------------------

function build_item_pool()
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

function item( id, display_name, slot, on_equip, on_unequip )
{
    i = spawnstruct();
    i.id = id;
    i.display_name = display_name;
    i.slot = slot;
    i.on_equip = on_equip;
    i.on_unequip = on_unequip;
    return i;
}

function find_item( item_id )
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

function on_boss_death( tier, killer, origin )
{
    chance = ACC_BOSS_ITEM_DROP_CHANCE_MINI;
    if ( tier == "full" ) chance = ACC_BOSS_ITEM_DROP_CHANCE_FULL;

    if ( acc_utility::acc_rand_float() > chance )
    {
        acc_utility::log( "boss_items: drop rolled but missed (" + tier + ")" );
        return;
    }

    // Pick a random item from the pool.
    picked = level.acc_item_pool[ acc_utility::acc_rand_int( level.acc_item_pool.size ) ];

    // If killer already has this item, auto-convert to Shards right here.
    if ( isdefined( killer ) && isplayer( killer ) &&
         player_has_item( killer, picked.id ) )
    {
        acc_data_shards::grant_player( killer, ACC_ITEM_DUPLICATE_SHARD_CONVERT,
                                        "boss_item_duplicate" );
        acc_utility::log( "boss_items: " + picked.id +
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

function spawn_pickup( item_struct, origin )
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

function watch_pickup()
{
    self endon( "acc_item_claimed" );
    self endon( "death" );

    for ( ;; )
    {
        wait( 0.1 );
        closest = acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( closest ) ) continue;
        if ( distancesquared( closest.origin, self.origin ) >
             ( ACC_ITEM_PICKUP_RADIUS * ACC_ITEM_PICKUP_RADIUS ) ) continue;

        // Attempt pickup.
        item_struct = find_item( self.acc_item_id );
        if ( !isdefined( item_struct ) ) break;

        if ( player_has_item( closest, item_struct.id ) )
        {
            // Already owned - convert to shards for this player.
            acc_data_shards::grant_player( closest, ACC_ITEM_DUPLICATE_SHARD_CONVERT,
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

function watch_lifetime()
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

function player_has_item( player, item_id )
{
    if ( !isdefined( player.acc_equipped_items ) ) return false;
    for ( i = 0; i < player.acc_equipped_items.size; i++ )
    {
        if ( player.acc_equipped_items[ i ] == item_id ) return true;
    }
    return false;
}

function equip_item( player, item_id )
{
    if ( player_has_item( player, item_id ) ) return;

    item_struct = find_item( item_id );
    if ( !isdefined( item_struct ) ) return;

    player.acc_equipped_items[ player.acc_equipped_items.size ] = item_id;
    player [[ item_struct.on_equip ]]();
}

function unequip_item( player, item_id )
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

function apply_neural_boots()        { self.acc_item_neural_boots = true; setmovespeedscale_hook( self ); acc_utility::log( "equip: neural_boots" ); }
function remove_neural_boots()       { self.acc_item_neural_boots = false; setmovespeedscale_hook( self ); acc_utility::log( "unequip: neural_boots" ); }

function apply_overclocked_gauntlets()   { self.acc_item_gauntlets = true; acc_utility::log( "equip: overclocked_gauntlets" ); }
function remove_overclocked_gauntlets()  { self.acc_item_gauntlets = false; acc_utility::log( "unequip: overclocked_gauntlets" ); }

function apply_targeting_visor()     { self.acc_item_visor = true; acc_utility::log( "equip: targeting_visor" ); }
function remove_targeting_visor()    { self.acc_item_visor = false; acc_utility::log( "unequip: targeting_visor" ); }

function apply_kinetic_battery()
{
    self.acc_item_battery = true;
    self.acc_item_battery_kill_count = 0;
    self.acc_item_battery_charged = false;
    acc_utility::log( "equip: kinetic_battery" );
}
function remove_kinetic_battery()
{
    self.acc_item_battery = false;
    acc_utility::log( "unequip: kinetic_battery" );
}

function apply_ghost_shroud()
{
    self.acc_item_shroud = true;
    self.acc_item_shroud_ready_at = 0;
    acc_utility::log( "equip: ghost_shroud" );
}
function remove_ghost_shroud()       { self.acc_item_shroud = false; acc_utility::log( "unequip: ghost_shroud" ); }

function apply_payroll_ledger()      { self.acc_item_ledger = true; acc_utility::log( "equip: payroll_ledger (+10% Points on kills)" ); }
function remove_payroll_ledger()     { self.acc_item_ledger = false; acc_utility::log( "unequip: payroll_ledger" ); }

// Exposed helper so _acc_points.gsc can apply the ledger bonus without
// knowing the implementation detail of the flag name.
function player_has_ledger( player )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_item_ledger ) ) return false;
    return player.acc_item_ledger == true;
}

// Movement speed hook - applies +20% when Neural Boots equipped AND holding a primary.
// VERIFIED(acc): SetMoveSpeedScale(player, float) is the stock API
// (_zm.gsc:4795, zm_usermap.gsc:336). Stamin-Up uses the 'marathon' specialty,
// not this scale - no perk conflict. Respawn reset handled by
// reapply_move_speed_on_spawn above.
function setmovespeedscale_hook( player )
{
    // VERIFIED(acc): the scale is ABSOLUTE (last-writer-wins), so all speed
    // sources recompute through the single owner in acc_utility - Neural
    // Boots, Cyberware Reflex T1, and The Flash Mega stack there.
    // TODO(acc-verify): boots should only apply when holding a primary.
    acc_utility::recompute_move_speed( player );
}
