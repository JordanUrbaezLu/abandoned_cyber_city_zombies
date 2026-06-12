// =============================================================================
// _acc_events_overload.gsc - Vault Overload side event (Server Vault)
//
// Design reference: docs/06_mechanics.md (Vault Overload state machine).
//
// 90-second hold event. Player must stay on a defined point. Leaving the
// point for >8s cumulative fails the event.
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_OVERLOAD_ACTIVATION_COST_POINTS 1000
#define ACC_OVERLOAD_DURATION_SEC 90
#define ACC_OVERLOAD_LEAVE_THRESHOLD_SEC 8
#define ACC_OVERLOAD_POINT_RADIUS 96
#define ACC_OVERLOAD_REWARD_SHARDS 3

#namespace acc_events_overload;

function init()
{
    acc_utility::log( "events_overload init" );

    level.acc_overload_state = "available";
    level.acc_overload_attempts_used = 0;

    level thread watch_terminal();
}

function watch_terminal()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_overload_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "overload: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

function terminal_loop()
{
    self endon( "death" );

    point_struct = struct::get( "acc_overload_point", "targetname" );
    if ( !isdefined( point_struct ) )
    {
        acc_utility::log( "overload: no point struct placed" );
        return;
    }

    for ( ;; )
    {
        self waittill( "trigger", player );

        if ( !can_attempt( player ) )
        {
            player iprintln( "Vault Overload: unavailable" );
            wait( 0.5 );
            continue;
        }

        if ( player.score < ACC_OVERLOAD_ACTIVATION_COST_POINTS )
        {
            player iprintln( "Vault Overload: needs " + ACC_OVERLOAD_ACTIVATION_COST_POINTS + " points" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): spend via zm_score (see _acc_events_hack.gsc note).
        player zm_score::minus_to_player_score( ACC_OVERLOAD_ACTIVATION_COST_POINTS );
        level.acc_overload_state = "active";
        level.acc_overload_attempts_used += 1;

        result = run_overload( player, point_struct );

        if ( result == "success" )
        {
            acc_data_shards::grant_player( player, ACC_OVERLOAD_REWARD_SHARDS, "overload" );
            unlock_map_shortcut();
            level.acc_overload_state = "consumed";

            if ( player_has_parallel_processing( player ) &&
                 level.acc_overload_attempts_used < 2 )
            {
                level.acc_overload_state = "available";
            }
        }
        else
        {
            level.acc_overload_state = "locked";
            level thread spawn_takedown_wave();
        }

        wait( 1.0 );
    }
}

function can_attempt( player )
{
    if ( level.acc_overload_state == "locked" ) return false;
    if ( level.acc_overload_state == "consumed" ) return false;
    if ( level.acc_overload_state == "active" ) return false;
    return true;
}

function player_has_parallel_processing( player )
{
    return isdefined( player.acc_cw_events_retry ) && player.acc_cw_events_retry == true;
}

// ---------------------------------------------------------------------------
// Main loop
// ---------------------------------------------------------------------------

function run_overload( player, point_struct )
{
    player iprintln( "Vault Overload starting" );
    player.acc_overload_cumulative_off_sec = 0;

    // Spawn scaled waves at 0, 30, 60 second marks.
    level thread overload_wave_schedule( 0, 1 );
    level thread overload_wave_schedule( 30, 2 );
    level thread overload_wave_schedule( 60, 3 );

    tick = 0.5;
    elapsed = 0;
    while ( elapsed < ACC_OVERLOAD_DURATION_SEC )
    {
        wait( tick );
        elapsed += tick;

        if ( !is_player_on_point( player, point_struct ) )
        {
            player.acc_overload_cumulative_off_sec += tick;
            if ( player.acc_overload_cumulative_off_sec >= ACC_OVERLOAD_LEAVE_THRESHOLD_SEC )
            {
                player iprintln( "Vault Overload FAILED - abandoned the point" );
                return "failed";
            }
        }
        else
        {
            // Reset the off-point counter when back on point (generous - not cumulative).
            player.acc_overload_cumulative_off_sec = 0;
        }
    }

    player iprintln( "Vault Overload SUCCESS" );
    return "success";
}

function is_player_on_point( player, point_struct )
{
    if ( !isdefined( player ) || !isalive( player ) ) return false;
    if ( distancesquared( player.origin, point_struct.origin ) <=
         ( ACC_OVERLOAD_POINT_RADIUS * ACC_OVERLOAD_POINT_RADIUS ) )
    {
        return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Wave schedule
// ---------------------------------------------------------------------------

function overload_wave_schedule( at_sec, wave_level )
{
    wait( at_sec );

    // Each wave adds ~4 zombies + an elite forced on waves 2/3.
    zombie_count = 4 + ( 2 * wave_level );
    acc_utility::log( "overload: wave " + wave_level + " (" + zombie_count + " zombies)" );

    // TODO(acc-verify): spawn `zombie_count` zombies via zombie_utility.
    // At wave_level >= 2, force at least one shielded elite; at >= 3 add teleporter.
}

function spawn_takedown_wave()
{
    acc_utility::log( "overload: takedown wave (3 of each elite class)" );
    // TODO(acc-verify): spawn 3 shielded, 3 teleporters, 3 emp simultaneously.
}

// ---------------------------------------------------------------------------
// Reward: map shortcut
// ---------------------------------------------------------------------------

function unlock_map_shortcut()
{
    acc_utility::log( "overload: shortcut Server->Roof unlocked" );
    // TODO(acc-geom): open a brush door prefab named "acc_shortcut_server_roof".
    doors = getentarray( "acc_shortcut_server_roof", "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        doors[ i ] hide();
        doors[ i ] notsolid();
    }
}
