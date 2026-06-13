// =============================================================================
// _acc_dev.gsc - test/dev harness, gated entirely on the `acc_dev` dvar
//
// `+set acc_dev 1` (run_game.ps1 sets it by default) turns on a sandbox so the
// whole map can be exercised in one sitting:
//   - Unlimited money: every player's points are topped back up to ~1,000,000
//     whenever they drop below a floor (buy any wallbuy, spam the box, PaP).
//   - Perk cap raised to 18 so every machine in the test room is buyable.
//   - Buyable-door markers: a through-walls waypoint over each closed buyable
//     door (the doors stay closed - this just makes them findable). The marker
//     is destroyed once that door's script_flag is set (i.e. it's been bought).
//
// Everything no-ops when acc_dev != 1, so this module is inert in normal play.
// Marker shader is the engine built-in "white" (always present) tinted via
// .color, so it can never introduce a missing-asset build error.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_DEV_MONEY_TARGET 1000000
#define ACC_DEV_MONEY_FLOOR  100000

#namespace acc_dev;

function init()
{
    // HARDCODED ON (no dvar gate) - user requested flags-free dev sandbox while
    // we validate the build end-to-end. Re-add a `getdvarint("acc_dev")` gate
    // before shipping.
    acc_utility::log( "DEV MODE ON (hardcoded): unlimited money + door markers + perk cap 18" );

    // Raise the perk cap so all machines in the one-room test build are buyable.
    level.perk_purchase_limit = 18;

    level thread dev_unlimited_money();
    level thread dev_door_markers();
}

// ---------------------------------------------------------------------------
// Unlimited money
// ---------------------------------------------------------------------------

function dev_unlimited_money()
{
    level endon( "end_game" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;

            // Reading .score is fine; only WRITES must go through the API
            // (zm_score::add_to_player_score rounds up to multiples of 10).
            cur = 0;
            if ( isdefined( p.score ) ) cur = p.score;
            if ( cur < ACC_DEV_MONEY_FLOOR )
                p zm_score::add_to_player_score( ACC_DEV_MONEY_TARGET - cur );
        }
        wait 1;
    }
}

// ---------------------------------------------------------------------------
// Buyable-door markers (through-walls waypoints)
// ---------------------------------------------------------------------------

function dev_door_markers()
{
    level endon( "end_game" );

    // Doors are spawned by the stock blocker init during the load flow; wait
    // for the world to be live, then poll briefly for the triggers.
    level flag::wait_till( "initial_blackscreen_passed" );

    doors = [];
    for ( i = 0; i < 30; i++ )
    {
        doors = GetEntArray( "zombie_door", "targetname" );
        if ( doors.size > 0 ) break;
        wait 0.5;
    }
    if ( doors.size == 0 )
    {
        acc_utility::log( "dev: no zombie_door triggers to mark" );
        return;
    }

    for ( i = 0; i < doors.size; i++ )
        level thread dev_mark_one_door( doors[ i ] );
    acc_utility::log( "dev: marking " + doors.size + " buyable doors" );
}

function dev_mark_one_door( door )
{
    level endon( "end_game" );

    // End marking when the door is purchased (its script_flag gets set).
    if ( isdefined( door.script_flag ) )
        level thread end_marking_on_flag( door, door.script_flag );

    markers = [];
    for ( ;; )
    {
        if ( IS_TRUE( door.acc_marker_done ) ) break;

        // (Re)create a marker for any player that doesn't have one yet
        // (handles late joins in co-op tests).
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            key = p GetEntityNumber();
            if ( isdefined( markers[ key ] ) ) continue;
            markers[ key ] = create_door_marker( p, door );
        }
        wait 2;
    }

    keys = GetArrayKeys( markers );
    for ( i = 0; i < keys.size; i++ )
    {
        if ( isdefined( markers[ keys[ i ] ] ) )
            markers[ keys[ i ] ] Destroy();
    }
}

function end_marking_on_flag( door, flagname )
{
    level endon( "end_game" );
    level flag::wait_till( flagname );
    door.acc_marker_done = true;
}

// Cyan square that tracks the door and shows through walls (off-screen arrow
// points toward it). "white" is the engine built-in material, tinted by .color.
function create_door_marker( player, door )
{
    elem = NewClientHudElem( player );
    elem.archived = false;
    elem.x = 0;
    elem.y = 0;
    elem.z = 56;            // float above the door trigger's origin
    elem.alpha = 0.9;
    elem.color = ( 0.15, 0.9, 1.0 );
    elem SetShader( "white", 14, 14 );
    elem SetWaypoint( true ); // constant on-screen size + edge arrow when offscreen
    elem SetTargetEnt( door );
    return elem;
}
