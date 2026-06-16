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
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;

#define ACC_DEV_MONEY_TARGET 1000000
#define ACC_DEV_MONEY_FLOOR  100000

#namespace acc_dev;

function init()
{
    // DEV MODE DEFAULT-ON (pre-release) - default 1, matches the entry script. A plain
    // launch IS the dev sandbox (the Steam launcher truncates +set args, so we can't
    // rely on the flag arriving). Set `acc_dev 0` to disable for a clean consumer test.
    // TODO(ship): flip the default back to 0 before a public build. docs/34_flags_reference.md.
    if ( getdvarint( "acc_dev", 1 ) != 1 )
        return;

    acc_utility::log( "DEV MODE ON (acc_dev 1): unlimited money + door markers + perk cap 18" );

    // Raise the perk cap so all machines in the one-room test build are buyable.
    level.perk_purchase_limit = 18;

    level thread dev_unlimited_money();
    level thread dev_door_markers();

    // Damage numbers: expose the per-player accumulator as a hook that
    // _acc_damage feeds from INSIDE its own actor-damage callback. A separate
    // callback does NOT work - stock dispatch short-circuits on the first non -1
    // return (_zm.gsc:5824), and _acc_damage runs first + returns the modified
    // damage, so a later callback never sees a modified hit (every headshot,
    // every gun hit once you own Double Tap, every PaP'd hit). Feeding from
    // _acc_damage's record path catches EVERY hit. (Hook auto-clears when dev
    // mode is off, so production never shows debug numbers.)
    level.acc_dmg_num_feed = &acc_center_dmg_add;
    level thread dev_player_hud_loop();

    // Round skip (Machina-style "start the next round"): console `acc_skip_round 1`.
    level thread dev_round_skip_watcher();

    // Jugger-Nog perk-icon test: console `acc_dev_jugg_mega 1` = grant Jug + Mega
    // (icon TEAL), `2` = grant Jug base (icon RED). Self-contained - it GIVES you Jug,
    // so no money/machine needed to see the icon.
    level thread dev_jugg_mega_watcher();

    // Teleports so the greybox door chain never blocks testing:
    //   acc_tp_perks 1  -> the perk row    acc_tp_spawn 1 -> back to spawn
    //   acc_open_doors 1 -> set every enter_* door flag (open the whole map)
    level thread dev_teleport_watcher();
}

// ---------------------------------------------------------------------------
// Dev teleports / open-all-doors (console-driven; greybox door chain bypass)
// ---------------------------------------------------------------------------

function dev_teleport_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        if ( getdvarint( "acc_tp_perks", 0 ) == 1 )
        {
            SetDvar( "acc_tp_perks", "0" );
            dev_tp_players( ( 0, 4090, 32 ), "the perk row" );
        }
        if ( getdvarint( "acc_tp_spawn", 0 ) == 1 )
        {
            SetDvar( "acc_tp_spawn", "0" );
            dev_tp_players( ( -291, -316, 32 ), "spawn" );
        }
        if ( getdvarint( "acc_open_doors", 0 ) == 1 )
        {
            SetDvar( "acc_open_doors", "0" );
            dev_open_all_doors();
        }
        wait 0.25;
    }
}

function dev_tp_players( org, label )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        p SetOrigin( org );
        p IPrintLnBold( "^3>> Teleported to " + label );
    }
    acc_utility::log( "dev: teleported players to " + label );
}

// Open EVERY barrier so the whole map - Mystery Box included - is walkable from
// spawn. Two classes of barrier, both handled here:
//   1) The 8 buyable doors (zombie_door triggers). flag::set on the door's
//      script_flag only ACTIVATES THE ZONE behind it (stock sets that flag as an
//      OUTPUT of a purchase, _zm_blockers.gsc:1322); it does NOT retract the
//      door slab. So we also physically clear each slab (Hide/NotSolid/
//      ConnectPaths) - the same thing the entry script's acc_hardcoded_open_map
//      does on load.
//   2) The per-run PaP blocker brush. The randomizer (apply_pap_approach) leaves
//      ONE of acc_pap_block_server / acc_pap_block_roof solid every run; it is a
//      bare script_brushmodel (no trigger/flag), so the door pass misses it. That
//      is the "one door that never opens" and it walls off the box when the box
//      rolls to the blocked side - open BOTH.
function dev_open_all_doors()
{
    doors = GetEntArray( "zombie_door", "targetname" );
    for ( i = 0; i < doors.size; i++ )
    {
        door = doors[ i ];
        if ( !isdefined( door ) )
            continue;

        if ( isdefined( door.script_flag ) && flag::exists( door.script_flag ) )
            flag::set( door.script_flag );

        if ( isdefined( door.target ) )
        {
            slab = GetEnt( door.target, "targetname" );
            if ( isdefined( slab ) )
            {
                slab Hide();
                slab NotSolid();
                slab ConnectPaths();
            }
        }

        door TriggerEnable( false );
    }

    dev_open_pap_blockers();

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) ) players[ i ] IPrintLnBold( "^3>> All doors + PaP blockers opened" );
    acc_utility::log( "dev: opened " + doors.size + " buyable doors + PaP blockers" );
}

// Open BOTH per-run PaP blocker brushes regardless of which side this run blocked
// (inverse of the randomizer's block: Hide / NotSolid / ConnectPaths).
function dev_open_pap_blockers()
{
    names = array( "acc_pap_block_server", "acc_pap_block_roof" );
    for ( n = 0; n < names.size; n++ )
    {
        brushes = GetEntArray( names[ n ], "targetname" );
        for ( i = 0; i < brushes.size; i++ )
        {
            b = brushes[ i ];
            if ( !isdefined( b ) )
                continue;
            b Hide();
            b NotSolid();
            b ConnectPaths();
        }
    }
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
// Jugger-Nog Mega toggle - perk-icon indicator test (console: acc_dev_jugg_mega
// 1 = Mega/teal, 2 = base/red). Buy Jug first (the icon needs ownership to show).
// ---------------------------------------------------------------------------

function dev_jugg_mega_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        v = getdvarint( "acc_dev_jugg_mega", 0 );
        if ( v != 0 )
        {
            SetDvar( "acc_dev_jugg_mega", "0" );
            dev_apply_jugg_state( v );
        }
        wait 0.25;
    }
}

// Self-contained perk-icon test: GRANTS Jugger-Nog if you don't already own it (no
// money/machine needed), then sets the Mega flag has_mega_perk() reads so the
// _acc_lui perk_state_watch loop swaps the overlay icon. v: 1 = Jug + Mega (icon
// TEAL), 2 = Jug base (icon RED). give_perk is the stock grant (real perk + HP).
function dev_apply_jugg_state( v )
{
    mega = ( v == 1 );
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;

        if ( !( p HasPerk( "specialty_armorvest" ) ) )
            p zm_perks::give_perk( "specialty_armorvest", false );

        if ( !isdefined( p.acc_mega_perks ) ) p.acc_mega_perks = [];
        p.acc_mega_perks[ "specialty_armorvest" ] = mega;
        p IPrintLnBold( ( mega ? "^3>> Jugger-Nog + Mega (icon -> ^5TEAL^3)" : "^3>> Jugger-Nog base (icon -> ^1RED^3)" ) );
    }
    acc_utility::log( "dev: jugg state v=" + v + " mega=" + ( mega ? "1" : "0" ) );
}

// ---------------------------------------------------------------------------
// Damage indicators + zone signage HUD
// ---------------------------------------------------------------------------

// Crosshair damage NUMBER. self = the ATTACKING player; `amount` = the FINAL
// (perk/overclock/PaP-modified) damage, fed by _acc_damage from inside its own
// actor-damage callback via level.acc_dmg_num_feed. See the init() comment for why
// it must be fed there (stock dispatch short-circuit) - a second callback misses
// every modified/headshot/PaP hit.
//
// WHY crosshair, not over each zombie: over-entity arbitrary TEXT in BO3 requires
// globally overriding CoD.Waypoints (the engine's objective/waypoint dispatcher) +
// shipping objectives.json - it errors the whole HUD if that table fails to load
// (proven: zm_countryside hb21waypoints.lua). That system is built for persistent
// quest markers, NOT many-per-second combat popups (it would spam the compass +
// objective list). The reliable, correct path is a crosshair-anchored LUI number:
// you aim at the zombie, so it reads on-target. See acc_hud.lua CoD.AccDmgNum.

// self = player. Accumulate damage; a push loop batches it to the crosshair number
// every ~0.12s so sustained automatic fire reads as one steadily-updating number
// (instead of a flicker storm) and hides shortly after you stop firing.
function acc_center_dmg_add( amount )
{
    if ( !isdefined( self.acc_cdmg ) ) self.acc_cdmg = 0;
    self.acc_cdmg += amount;

    if ( !IS_TRUE( self.acc_cdmg_loop_on ) )
    {
        self.acc_cdmg_loop_on = true;
        self thread acc_center_dmg_push_loop();
    }
}

// self = player.
function acc_center_dmg_push_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    parity = 0;
    idle_ticks = 0;
    showing = false;

    for ( ;; )
    {
        if ( !isdefined( self ) ) return;

        // Push at the TOP so the FIRST hit shows immediately (no startup lag - the
        // loop is started from acc_center_dmg_add AFTER the hit is accumulated).
        dmg = self.acc_cdmg;
        self.acc_cdmg = 0;

        if ( dmg > 0 )
        {
            if ( dmg > 99999 ) dmg = 99999;
            parity = 1 - parity;
            acc_lui::set_dmg_num( self, dmg * 2 + parity );
            showing = true;
            idle_ticks = 0;
        }
        else
        {
            idle_ticks++;
            if ( showing && idle_ticks >= 5 ) // keep it up ~0.5s after the last hit
            {
                acc_lui::set_dmg_num( self, 0 );
                showing = false;
            }
            if ( idle_ticks >= 10 ) // idle ~1s -> stop until next damage
            {
                self.acc_cdmg_loop_on = false;
                return;
            }
        }

        wait 0.1;
    }
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

        // Unmistakable dev-mode confirmation - if you SEE this, acc_dev IS active
        // (also logs as [ SCRIPTER] in console_mp.log). Absent = NOT in dev mode.
        p IPrintLnBold( "^2DEV MODE ACTIVE^7 - perk-icon test: console ^3acc_dev_jugg_mega 1^7 (teal) / ^32^7 (red)" );
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
    case "start_zone":  return "SPAWN";
    case "market_zone": return "MARKET";
    case "alley_zone":  return "ALLEY";
    case "corp_zone":   return "PLAZA";
    case "vault_zone":  return "VAULT";
    case "roof_zone":   return "HELIPAD";
    case "lab_zone":    return "LAB";
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
