// =============================================================================
// _acc_utility.gsc - shared helpers used across every _acc_ module
//
// Keep this file SMALL. Rule of thumb: if only one module uses a helper, put
// it in that module. If two or more need it, it belongs here.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;

#using scripts\zm\_zm_utility;

#namespace acc_utility;

// ---------------------------------------------------------------------------
// On-screen feedback message (shared). Use INSTEAD of iprintln for trench / machine
// feedback: iprintln dumps into the bottom notification area where the round counter and
// points cover it (user 2026-06-19). This is a single per-player hudelem at upper-center,
// dvar-tunable (acc_msg_y; SMALLER = higher) and (acc_msg_sec = hold seconds); a new message
// refreshes the same elem in place instead of stacking. Call ON the player: `player acc_utility::hud_msg( txt )`.
// ---------------------------------------------------------------------------

function hud_msg( text )   // self = player
{
    if ( !isdefined( self ) ) return;
    if ( !isdefined( self.acc_hud_msg ) )
    {
        self.acc_hud_msg = self hud::createFontString( "default", 1.5 );
        self.acc_hud_msg.alignX = "center";
        self.acc_hud_msg.alignY = "middle";
        self.acc_hud_msg.color  = ( 0.6, 0.9, 1.0 );
        self.acc_hud_msg.hidewheninmenu = true;
    }
    // Re-apply the anchor each show so a live acc_msg_y tweak takes effect without a relog.
    self.acc_hud_msg hud::setPoint( "TOP", "TOP", 0, getdvarint( "acc_msg_y", 190 ) );
    self.acc_hud_msg SetText( text );
    self.acc_hud_msg.alpha = 1;
    self thread hud_msg_fade();
}

function hud_msg_fade()   // self = player
{
    self notify( "acc_hud_msg_refresh" );   // cancel any in-flight fade so messages don't stack/flicker
    self endon( "acc_hud_msg_refresh" );
    self endon( "disconnect" );
    wait( getdvarfloat( "acc_msg_sec", 3.0 ) );
    if ( isdefined( self.acc_hud_msg ) )
    {
        self.acc_hud_msg fadeovertime( 0.5 );
        self.acc_hud_msg.alpha = 0;
    }
}

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

// Drop/pickup debug channel, gated by the `acc_drops_debug` dvar (default 0 =
// silent in normal play). Uses IPrintLnBold deliberately: it is the ONLY channel
// that reaches console_mp.log (printed there as "[ SCRIPTER] ..."); the /# #/
// dev block in log() does NOT reliably route to the log (CLAUDE.md logging truth).
// Launch with: +set acc_drops_debug 1 +set logfile 1
function drops_debug( msg )
{
    if ( getdvarint( "acc_drops_debug", 0 ) != 1 ) return;
    players = get_all_players();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
        {
            p IPrintLnBold( "^6[drops] ^7" + msg );
        }
    }
}

// Crash-diagnostic breadcrumb channel (user 2026-06-19: random CTD on boots + slide). GSC can't
// catch a hard engine crash, so instead we drop a breadcrumb at each step of the suspect paths; the
// LAST [CRASHDBG] line in console_mp.log = the step just before the CTD. Gated by `acc_crash_debug`
// (default 0, silent). Routes via IPrintLnBold (the one channel that reaches console_mp.log as
// "[ SCRIPTER] ..."; the /# #/ println does not reliably). ENABLE + REPRODUCE + READ:
//   launch with  +set acc_crash_debug 1 +set logfile 1
//   reproduce the crash, then read the LAST "[CRASHDBG]" lines in <game>\console_mp.log.
function crash_log( player, msg )
{
    if ( getdvarint( "acc_crash_debug", 0 ) != 1 ) return;
    if ( isdefined( player ) && isplayer( player ) )
    {
        player IPrintLnBold( "^1[CRASHDBG]^7 " + msg );
    }
    else
    {
        players = get_all_players();
        if ( isdefined( players ) && players.size > 0 && isdefined( players[ 0 ] ) )
            players[ 0 ] IPrintLnBold( "^1[CRASHDBG]^7 " + msg );
    }
    /# println( "[CRASHDBG] " + msg ); #/
}

// Compact string of the speed flags currently active on a player (for crash_log breadcrumbs).
function active_speed_flags( player )
{
    f = "";
    if ( isdefined( player.acc_item_boots ) && player.acc_item_boots )                 f += "boots ";
    if ( isdefined( player.acc_item_neural_boots ) && player.acc_item_neural_boots )   f += "nboots ";
    if ( isdefined( player.acc_mega_flopper_speed ) && player.acc_mega_flopper_speed ) f += "megaflop ";
    if ( isdefined( player.acc_rocket_slide_speed ) && player.acc_rocket_slide_speed ) f += "rocket ";
    if ( isdefined( player.acc_gas_burst ) && player.acc_gas_burst )                   f += "gas ";
    if ( isdefined( player.acc_flash_speed ) && player.acc_flash_speed )               f += "flash ";
    if ( isdefined( player.acc_savior_speed ) && player.acc_savior_speed )             f += "savior ";
    if ( isdefined( player.acc_cw_rx1_speed ) && player.acc_cw_rx1_speed )             f += "cwrx1 ";
    if ( isdefined( player.acc_trench_slow ) && player.acc_trench_slow )               f += "trench ";
    return f;
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

// Like get_closest_player_to but SKIPS players with the GLITCH cloak flag
// (self.acc_cloak_glitch, set by the Phase Serum boss item). Only the Glitch Stalker
// targeting uses this, so the cloak hides you from the STALKER ONLY - the regular
// horde (which uses the stock find-flesh path) still targets you normally. Returns
// undefined when every player is cloaked (callers already guard for that).
function get_closest_uncloaked_player( origin )
{
    players = arraycopy( level.players );
    filtered = [];
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && !( isdefined( p.acc_cloak_glitch ) && p.acc_cloak_glitch ) )
        {
            filtered[ filtered.size ] = p;
        }
    }
    if ( filtered.size == 0 ) return undefined;
    return arraygetclosest( origin, filtered );
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
    if ( isdefined( player.acc_item_boots ) && player.acc_item_boots )
    {
        n_scale = n_scale * getdvarfloat( "acc_boots_mult", 1.08 ); // Boots boss item: +8% move overall + trench-slow immunity (user 2026-06-18, docs/12)
    }
    if ( isdefined( player.acc_cw_rx1_speed ) && player.acc_cw_rx1_speed )
    {
        n_scale = n_scale * 1.10; // Cyberware Reflex T1 (docs/04)
    }
    if ( isdefined( player.acc_flash_speed ) && player.acc_flash_speed )
    {
        n_scale = n_scale * 1.15; // The Flash Mega: +15% move (docs/13)
    }
    if ( isdefined( player.acc_savior_speed ) && player.acc_savior_speed )
    {
        n_scale = n_scale * 1.15; // Savior Mega: +15% while a teammate is down (docs/13)
    }
    if ( isdefined( player.acc_mega_flopper_speed ) && player.acc_mega_flopper_speed )
    {
        n_scale = n_scale * getdvarfloat( "acc_mega_flopper_slide_mult", 1.35 ); // Mega Flopper (PhD Slider): 1.35x WHILE SLIDING (user 2026-06-18, docs/13)
    }
    if ( isdefined( player.acc_gas_burst ) && player.acc_gas_burst )
    {
        n_scale = n_scale * getdvarfloat( "acc_gas_burst_mult", 2.0 ); // Gas Tank nitro burst: +100% (live dvar, docs/12)
    }
    if ( isdefined( player.acc_rocket_slide_speed ) && player.acc_rocket_slide_speed )
    {
        n_scale = n_scale * getdvarfloat( "acc_rocket_slide_mult", 1.35 ); // Rocket Shield: 1.35x while sliding (live dvar, docs/12)
    }
    // Layered trench slow (docs/47): depends on how many layers you are BELOW your Exo Suit's coverage.
    // Exo tier T -> normal in layers 1..T; below that, -20% at the first uncovered layer, then -10% per
    // layer deeper (-0.10*(L-T-1)). Boots do NOT cancel this (user 2026-06-21) - only the Exo Suit does.
    // acc_trench_layer is set by the bus_trench watcher; acc_exo_tier by _acc_exo. Gated by acc_trench_slow_on.
    exo_layer = ( isdefined( player.acc_trench_layer ) ? player.acc_trench_layer : 0 );
    exo_tier  = ( isdefined( player.acc_exo_tier ) ? player.acc_exo_tier : 0 );
    if ( exo_layer > exo_tier && getdvarint( "acc_trench_slow_on", 1 ) == 1 )
    {
        exo_red = getdvarfloat( "acc_exo_slow_first", 0.20 ) + ( ( exo_layer - exo_tier - 1 ) * getdvarfloat( "acc_exo_slow_step", 0.10 ) );
        if ( exo_red > 0.90 ) exo_red = 0.90;   // never let speed hit 0
        n_scale = n_scale * ( 1.0 - exo_red );
    }
    // Crash breadcrumb (boots+slide CTD diag, user 2026-06-19): log the scale + active flags
    // immediately BEFORE the engine call, then AFTER. If the CTD is SetMoveSpeedScale, the log
    // shows "->SetMoveSpeedScale" (with the value) but never "OK".
    crash_log( player, "recompute_move_speed scale=" + n_scale + " flags=[ " + active_speed_flags( player ) + "] ->SetMoveSpeedScale" );
    player SetMoveSpeedScale( n_scale );
    crash_log( player, "recompute_move_speed SetMoveSpeedScale OK (scale=" + n_scale + ")" );
}
