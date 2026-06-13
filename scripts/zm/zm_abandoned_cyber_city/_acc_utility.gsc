// =============================================================================
// _acc_utility.gsc - shared helpers used across every _acc_ module
//
// Keep this file SMALL. Rule of thumb: if only one module uses a helper, put
// it in that module. If two or more need it, it belongs here.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_utility;

#namespace acc_utility;

// ---------------------------------------------------------------------------
// Logging. All _acc_ logs are prefixed so you can grep console.log cleanly.
// ---------------------------------------------------------------------------

function log( msg )
{
    iprintlnbold_if_dev( "[acc] " + msg );
    /# println( "[acc] " + msg ); #/  // /# #/ = devmode-only block
}

function log_player( player, msg )
{
    log( "player=" + player.name + " " + msg );
}

function iprintlnbold_if_dev( msg )
{
    /# iprintln( msg ); #/
}

// ---------------------------------------------------------------------------
// RNG. We use a seeded PRNG for map-state rolls so runs can be reproduced by
// seed later (post-1.0 feature, see docs/07_replayability.md).
// For now, randomint is fine; the wrapper gives us one place to swap in a
// seeded PRNG later without hunting every callsite.
// ---------------------------------------------------------------------------

function acc_rand_int( max_exclusive )
{
    // TODO(acc-seeded): swap in seeded PRNG when we build that feature.
    return randomint( max_exclusive );
}

function acc_rand_float()
{
    return randomfloat( 1.0 );
}

// Weighted pick. `choices` is an array of objects each with `.weight` and `.value`.
function acc_weighted_pick( choices )
{
    total = 0;
    for ( i = 0; i < choices.size; i++ )
    {
        total += choices[ i ].weight;
    }

    if ( total <= 0 )
    {
        // Fallback: uniform pick.
        return choices[ acc_rand_int( choices.size ) ].value;
    }

    roll = randomfloat( total );
    acc = 0;
    for ( i = 0; i < choices.size; i++ )
    {
        acc += choices[ i ].weight;
        if ( roll <= acc )
        {
            return choices[ i ].value;
        }
    }

    return choices[ choices.size - 1 ].value;
}

// ---------------------------------------------------------------------------
// Player helpers
// ---------------------------------------------------------------------------

function get_all_players()
{
    // level.players is maintained by stock on connect/disconnect.
    // Use this instead of iterating entity pools.
    return level.players;
}

function get_closest_player_to( origin )
{
    return zm_utility::get_closest_player( origin );
}

// ---------------------------------------------------------------------------
// Delayed actions. Safe wrappers so we don't forget endon-on-disconnect.
// ---------------------------------------------------------------------------

function run_after_delay( delay_sec, func )
{
    self endon( "disconnect" );
    wait( delay_sec );
    self [[ func ]]();
}

// ---------------------------------------------------------------------------
// Math
// ---------------------------------------------------------------------------

function clamp_int( x, low, high )
{
    if ( x < low ) return low;
    if ( x > high ) return high;
    return x;
}

function clamp_float( x, low, high )
{
    if ( x < low ) return low;
    if ( x > high ) return high;
    return x;
}

// ---------------------------------------------------------------------------
// Move speed - single owner.
//
// VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE (last-writer-wins; stock
// resets to 1 on every spawn, zm_usermap.gsc:336), so read-modify-write
// stacking between modules silently erases each other. Every speed-affecting
// system sets its flag and calls this recompute instead of writing the scale
// directly. Writers: _acc_boss_items (Neural Boots), _acc_cyberware (Reflex
// T1), _acc_mega_bottles (The Flash).
// ---------------------------------------------------------------------------

function recompute_move_speed( player )
{
    n_scale = 1.0;
    if ( isdefined( player.acc_item_neural_boots ) && player.acc_item_neural_boots )
    {
        n_scale = n_scale * 1.20; // Neural Boots (docs/12_boss_items.md)
    }
    if ( isdefined( player.acc_cw_rx1_speed ) && player.acc_cw_rx1_speed )
    {
        n_scale = n_scale * 1.10; // Cyberware Reflex T1 (docs/04)
    }
    if ( isdefined( player.acc_flash_speed ) && player.acc_flash_speed )
    {
        n_scale = n_scale * 1.12; // The Flash Mega (docs/13)
    }
    player SetMoveSpeedScale( n_scale );
}
