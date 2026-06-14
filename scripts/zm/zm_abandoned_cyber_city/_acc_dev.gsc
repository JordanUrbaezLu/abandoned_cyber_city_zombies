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
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
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

    // Damage indicators: a read-only actor-damage callback feeds per-player
    // last-hit + DPS; the HUD loop renders them and the current-zone sign.
    zm::register_actor_damage_callback( &dev_damage_cb );
    level thread dev_player_hud_loop();

    // Round skip (Machina-style "start the next round"): console `acc_skip_round 1`.
    level thread dev_round_skip_watcher();
}

// ---------------------------------------------------------------------------
// Round skip - console: `acc_skip_round 1` advances to the next round
// ---------------------------------------------------------------------------

function dev_round_skip_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        if ( getdvarint( "acc_skip_round", 0 ) == 1 )
        {
            SetDvar( "acc_skip_round", "0" );
            dev_skip_round();
        }
        wait 0.25;
    }
}

function dev_skip_round()
{
    // Kill whatever is alive (clean next round) + zero the spawn budget, then end
    // the round-wait. "kill_round" only fires in developer mode (we run with
    // +set developer 1); the kill + zombie_total=0 ends it regardless.
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zombies = GetAITeamArray( team );
    for ( i = 0; i < zombies.size; i++ )
    {
        z = zombies[ i ];
        if ( isdefined( z ) && isalive( z ) )
            z DoDamage( z.health + 1000, z.origin );
    }
    level.zombie_total = 0;
    /# level notify( "kill_round" ); #/

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) )
            players[ i ] IPrintLnBold( "^3>> SKIPPING TO NEXT ROUND" );
    }
    acc_utility::log( "dev: round skipped" );
}

// ---------------------------------------------------------------------------
// Damage indicators + zone signage HUD
// ---------------------------------------------------------------------------

// Read-only actor-damage callback (self = victim/zombie). Registered AFTER
// _acc_damage, so the value is already perk/overclock-modified. Spawns a
// floating damage NUMBER at the hit enemy. NEVER modifies damage (-1).
function dev_damage_cb( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
    if ( isdefined( attacker ) && isplayer( attacker ) && isdefined( damage ) && damage > 0 )
        self accumulate_dmg_number( attacker, int( damage ) );
    return -1; // no damage modification
}

// self = zombie. Batch hits inside a short window into ONE rising number
// (perf + readability with automatic weapons).
function accumulate_dmg_number( attacker, amount )
{
    if ( !isdefined( self.acc_dmg_pending ) ) self.acc_dmg_pending = 0;
    self.acc_dmg_pending += amount;
    self.acc_dmg_attacker = attacker;

    if ( !IS_TRUE( self.acc_dmg_num_active ) )
    {
        self.acc_dmg_num_active = true;
        self thread show_dmg_number();
    }
}

// self = zombie.
function show_dmg_number()
{
    wait 0.1; // batch window
    if ( !isdefined( self ) ) return;

    total = self.acc_dmg_pending;
    attacker = self.acc_dmg_attacker;
    org = self.origin;
    self.acc_dmg_pending = 0;
    self.acc_dmg_num_active = false;

    if ( !isdefined( attacker ) || !isplayer( attacker ) || total <= 0 ) return;

    // DISABLED pending the correct implementation. In-game proof established the hard
    // BO3 rule: world-space TEXT is impossible - SetWaypoint(false)+SetTargetEnt renders
    // ICONS over the entity but SUPPRESSES text; removing SetWaypoint dumps the text to
    // the top-left (0,0); and there is no WorldToScreen for per-frame projection. Floating
    // damage NUMBERS therefore must be world-projected digit ICONS (or a LUI world-anchored
    // widget) - being implemented next. Until then we do NOT render the broken top-left
    // number. (accumulate_dmg_number still tracks the per-hit total above for that work.)
}

// Zone signage only (the DMG/DPS side panel was replaced by floating numbers).
function dev_player_hud_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) )
                continue;
            ensure_dev_huds( p );
            dev_update_zone( p );
        }
        wait 0.2;
    }
}

function ensure_dev_huds( p )
{
    if ( !isdefined( p.acc_dev_zone_hud ) )
    {
        p.acc_dev_zone_hud = p hud::createFontString( "default", 2.0 );
        p.acc_dev_zone_hud hud::setPoint( "TOP", "TOP", 0, 36 );
        p.acc_dev_zone_hud.color = ( 0.3, 0.85, 1.0 );
        p.acc_dev_zone_hud.alpha = 0.85;
        p.acc_dev_zone_hud.hidewheninmenu = true;
    }
}

// Zone signage: greybox locations look identical, so show the current zone's
// name (top of screen) + a banner on change so you can tell them apart.
function dev_update_zone( p )
{
    zone = dev_get_player_zone( p );
    if ( !isdefined( zone ) )
        return;

    if ( !isdefined( p.acc_dev_cur_zone ) || p.acc_dev_cur_zone != zone )
    {
        p.acc_dev_cur_zone = zone;
        name = dev_zone_name( zone );
        p.acc_dev_zone_hud SetText( name );
        p IPrintLnBold( "^5>> " + name );
    }
}

function dev_get_player_zone( p )
{
    if ( !isdefined( level.zones ) )
        return undefined;

    keys = GetArrayKeys( level.zones );
    for ( i = 0; i < keys.size; i++ )
    {
        z = level.zones[ keys[ i ] ];
        if ( !isdefined( z ) || !isdefined( z.volumes ) )
            continue;
        for ( j = 0; j < z.volumes.size; j++ )
        {
            if ( isdefined( z.volumes[ j ] ) && p IsTouching( z.volumes[ j ] ) )
                return keys[ i ];
        }
    }
    return undefined;
}

function dev_zone_name( zone )
{
    switch ( zone )
    {
    case "start_zone":  return "SPAWN PLAZA";
    case "market_zone": return "UNDERCITY MARKET";
    case "alley_zone":  return "SERVICE ALLEY";
    case "corp_zone":   return "CORPORATE PLAZA";
    case "vault_zone":  return "SERVER VAULT";
    case "roof_zone":   return "ROOFTOP HELIPAD";
    case "lab_zone":    return "SUBTERRANEAN LAB";
    }
    return zone;
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
