// =============================================================================
// _acc_lockdown_challenge.gsc - the per-round lockdown CHALLENGE room (Phase A).
//
// Full design + the adversarial-verified fixes: docs/43_lockdown_challenge_room.md.
//
// Each round _acc_lockdown lights ONE of 4 rooms RED (Vault / Alley / Helipad=roof_zone /
// Market) and notifies "acc_lockdown_room_lit". This module turns the lit room into a TRAP:
// walk into the DEFCON room and it's game time - the room commits, the outside horde is stopped
// from spawning inside, and a CONFINED wave of 30 Glitch Stalkers spawns. Kill all 30 -> the
// room clears and drops a free-for-all random boss-item. It stays committed ACROSS ROUNDS until
// cleared (the _acc_lockdown rotation pauses while level.acc_ldc_active is set).
//
// "SEPARATE GAME" isolation is FREE: every challenge glitch already has ignore_enemy_count=true
// (set by _acc_boss_glitch::spawn_glitch), so it is invisible to the round-end count AND the
// round's spawn budget. We track our OWN private kill counter (level.acc_ldc_killed), never the
// stock zombie_total. The shared cost is only the engine ACTOR pool -> capped concurrent.
//
// CONTAINMENT (all GSC-only, NO geometry, -GscOnly, zero LED risk):
//  - Outside horde: disable_zone_spawning stops risers inside the sealed room.
//  - Glitch wave: blink/charge teleports are clamped in-room + a 1Hz yank-back (_acc_boss_glitch
//    ldc_in_room / ldc_random_anchor_nav / ldc_keep_in_room), and SetGoal pins them.
//  - Players: the HARD lock-in re-CLOSES the room's 2 stock buyable border doors via the stock
//    crush-safe close (door_activate open=false -> slides the door back DOWN, solid only when the
//    doorway is player-clear). No acc_seal_<zone> brushes were ever authored (the move-door reuse
//    sidesteps the Radiant/LED-bake risk entirely). See the seal section for the move-door detail.
//
// Live knobs: acc_lockdown_challenge_on (1) / _total (50) / _concurrent (10) / _stagger (0.6) /
// _stagger_initial (0.3, fast fill at start) / _grace (1.5) / _confine (0) / acc_lockdown_reward (1) /
// _challenge_debug (0) / _challenge_force "<zone>" (dev start without the trap). Seal: acc_lockdown_lock_doors (1).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lockdown;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_glitch;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;
#using scripts\zm\zm_abandoned_cyber_city\_acc_health_bars;

#define ACC_LDC_TOTAL_DEF       40    // glitch zombies to purge to clear the room (user 2026-06-18, was 50)
#define ACC_LDC_CONCURRENT_DEF  10    // on-screen at once (was 8) - denser sealed room; coop self-limits via the producer's GetFreeActorCount gate
#define ACC_LDC_STAGGER_DEF     0.6   // seconds between spawns (was 1.3) - much faster trickle so the room fills quickly at the start (user 2026-06-18)
#define ACC_LDC_GRACE_DEF       1.5
#define ACC_LDC_BAR_W           170
#define ACC_LDC_BAR_H           11

#namespace acc_lockdown_challenge;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// Threaded from acc_main::init() AFTER acc_lockdown / acc_boss_glitch / acc_boss_items.
function init()
{
    level.acc_ldc_active   = undefined;   // the committed challenge zone (guards in _acc_lockdown / _acc_boss_glitch read this)
    level.acc_ldc_teardown = false;
    level.acc_ldc_resolved = false;
    level.acc_ldc_zombies  = [];

    level thread watch_challenge();
    level thread on_end_game_safety();

    // Dev: acc_lockdown_challenge_force "<zone>" force-starts a challenge without the trap.
    level thread watch_force_dvar();
}

// Arm the trap whenever a room lights red. One challenge at a time (level.acc_ldc_active).
function watch_challenge()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_lockdown_room_lit", zone );
        if ( getdvarint( "acc_lockdown_challenge_on", 1 ) != 1 ) continue;
        if ( isdefined( level.acc_ldc_active ) ) continue;
        level thread arm_trap( zone );
    }
}

// ---------------------------------------------------------------------------
// Trap (ambient catch - decision #2)
// ---------------------------------------------------------------------------

function arm_trap( zone )
{
    level endon( "end_game" );

    // Grace: let anyone already standing in the room when it lit bolt out before it arms.
    wait( getdvarfloat( "acc_lockdown_challenge_grace", ACC_LDC_GRACE_DEF ) );

    volumes = acc_decontamination::get_zone_volumes( zone );

    for ( ;; )
    {
        // Disarm if the room is no longer the active lit room (the rotation moved on) or a
        // challenge already committed (here or elsewhere).
        if ( !isdefined( level.acc_lockdown_active ) || level.acc_lockdown_active != zone ) return;
        if ( isdefined( level.acc_ldc_active ) ) return;

        party = inside_party( volumes );
        if ( party.size > 0 )
        {
            commit_challenge( zone, party );
            return;
        }

        wait( 0.25 );
    }
}

// Valid players currently inside the room's volume = the committed party.
function inside_party( volumes )
{
    party = [];
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !zm_utility::is_player_valid( p ) ) continue;   // excludes spectators / laststand
        if ( acc_decontamination::player_in_zone_volumes( p, volumes ) )
            party[ party.size ] = p;
    }
    return party;
}

// ---------------------------------------------------------------------------
// Commit + seal
// ---------------------------------------------------------------------------

function commit_challenge( zone, party )
{
    level endon( "end_game" );

    level.acc_ldc_active   = zone;
    level.acc_ldc_killed   = 0;
    level.acc_ldc_spawned  = 0;
    level.acc_ldc_party    = party;
    level.acc_ldc_teardown = false;
    level.acc_ldc_resolved = false;
    level.acc_ldc_zombies  = [];

    // CRITICAL (docs/43 §4.1): stop the OUTSIDE horde from RISING inside the sealed room.
    acc_decontamination::disable_zone_spawning( zone );

    // Belt-and-suspenders: nudge the party off any doorway footprint to the room interior BEFORE the
    // doors close, so nobody is standing where a door re-materializes. The stock close is already
    // crush-safe on its own; this is best-effort and SKIPS itself unless it can resolve a proven-safe
    // navmesh point (never SetOrigin to a raw/degenerate centroid that could itself trip the OOB kill).
    relocate_party_safe( zone, party );

    // Phase B SEAL (LED-safe, no new geometry): stock crush-safe CLOSE of the room's 2 buyable border
    // doors (moves them back DOWN into the doorway, solid only when player-clear) + a nav re-assert.
    // The real "doors slam, you're stuck" lock-in.
    seal_room( zone );
    level thread reseal_monitor( zone );

    // Optional belt-and-suspenders soft yank-back (default OFF now the doors seal). acc_lockdown_challenge_confine 1.
    if ( getdvarint( "acc_lockdown_challenge_confine", 0 ) == 1 )
        level thread confine_players( zone );

    ldc_debug( "COMMIT zone=" + zone + " party=" + party.size );

    // Per-inside-player "GLITCH PURGE X/30" HUD (server-side hud::, NOT a clientuimodel field -
    // that pool is full at 64 bits and overflow crashes at load; docs/43 §4.8).
    for ( i = 0; i < party.size; i++ )
    {
        p = party[ i ];
        if ( isdefined( p ) && isplayer( p ) ) p create_challenge_hud();
    }
    ldc_announce( party, "^1LOCKDOWN ENGAGED^7 - defeat 30 Glitch Stalkers to escape" );

    level thread challenge_producer( zone );
    level thread watch_fail( zone );
}

// ---------------------------------------------------------------------------
// The confined wave
// ---------------------------------------------------------------------------

function challenge_producer( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    total        = getdvarint( "acc_lockdown_challenge_total", ACC_LDC_TOTAL_DEF );
    cap          = getdvarint( "acc_lockdown_challenge_concurrent", ACC_LDC_CONCURRENT_DEF );
    stagger      = getdvarfloat( "acc_lockdown_challenge_stagger", ACC_LDC_STAGGER_DEF );
    stagger_init = getdvarfloat( "acc_lockdown_challenge_stagger_initial", 0.3 );  // fast fill at the start

    while ( level.acc_ldc_spawned < total )
    {
        // Share the engine actor pool with the outside horde: cap concurrent + only spawn when
        // a slot is free (spawn_zombie itself hard-waits on GetFreeActorCount, so this just
        // avoids parking the producer in that spin under a dense horde - docs/43 §4.3).
        if ( ldc_alive() >= cap || GetFreeActorCount() < 1 )
        {
            wait( 0.25 );
            continue;
        }

        h = spawn_challenge_glitch( zone );
        if ( isdefined( h ) )
        {
            level.acc_ldc_spawned++;
            level.acc_ldc_zombies[ level.acc_ldc_zombies.size ] = h;
            h thread ldc_death_watch( zone );
        }

        // Fill the room FAST when the trap first snaps shut (user 2026-06-18 - it spawned in too slow),
        // then drop to the normal replacement trickle once the room has been filled to the cap once.
        wait( ( level.acc_ldc_spawned < cap ? stagger_init : stagger ) );
    }
}

// Build a full Glitch Stalker (reusing _acc_boss_glitch::spawn_glitch), tag it as a challenge
// zombie (so its death drops NO reward), teleport it INTO the room, and pin it to the centre.
function spawn_challenge_glitch( zone )
{
    rnd  = ( isdefined( level.round_number ) ? level.round_number : 1 );
    host = acc_boss_glitch::spawn_glitch( rnd );
    if ( !isdefined( host ) || !isalive( host ) ) return undefined;

    host.acc_ldc = true;

    // Stock this room's interior anchor origins ON the actor: _acc_boss_glitch reads them to keep
    // every blink/charge teleport in-room, and ldc_keep_in_room uses them as the escape test.
    structs = struct::get_array( zone + "_spawners", "targetname" );
    origins = [];
    for ( i = 0; i < structs.size; i++ )
        if ( isdefined( structs[ i ].origin ) )
            origins[ origins.size ] = structs[ i ].origin;
    host.acc_ldc_anchors = origins;

    // spawn_glitch spawns at a base spawner (start/corp), so teleport into the room interior.
    if ( origins.size > 0 )
    {
        a   = origins[ acc_utility::acc_rand_int( origins.size ) ];
        nav = GetClosestPointOnNavMesh( a, 100, 30 );
        if ( isdefined( nav ) )
            host forceteleport( nav );
    }
    host SetGoal( acc_lockdown::room_center_origin( zone ) );
    host thread ldc_keep_in_room();   // safety net: yank back if it ever leaves the room

    return host;
}

// Per-actor: count ONLY tagged challenge zombies; the 30th fires the clear. Killed by the
// "acc_ldc_done" teardown so culled survivors never re-enter the count.
function ldc_death_watch( zone )
{
    level endon( "acc_ldc_done" );

    self waittill( "death" );

    if ( !( isdefined( self.acc_ldc ) && self.acc_ldc ) ) return;
    if ( isdefined( level.acc_ldc_teardown ) && level.acc_ldc_teardown ) return;

    level.acc_ldc_killed++;
    ldc_update_hud();
    level notify( "acc_ldc_kill" );

    total = getdvarint( "acc_lockdown_challenge_total", ACC_LDC_TOTAL_DEF );
    if ( level.acc_ldc_killed >= total )
        level thread challenge_clear( zone );
}

function ldc_alive()
{
    if ( !isdefined( level.acc_ldc_zombies ) ) return 0;

    fresh = [];
    for ( i = 0; i < level.acc_ldc_zombies.size; i++ )
    {
        z = level.acc_ldc_zombies[ i ];
        if ( isdefined( z ) && isalive( z ) )
            fresh[ fresh.size ] = z;
    }
    level.acc_ldc_zombies = fresh;
    return fresh.size;
}

// Containment safety net (self = a challenge zombie). Each ~1s, if it has somehow left the room
// (not within acc_lockdown_challenge_bounds_margin of ANY of its room anchors), yank it back to a
// random in-room anchor. The _acc_boss_glitch blink/charge clamps make this rare; this catches the
// rest (e.g. a knockback or a stock teleport). Ends on death or the challenge teardown.
function ldc_keep_in_room()
{
    self endon( "death" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 1 );
        if ( !isalive( self ) ) return;
        if ( !( isdefined( self.acc_ldc_anchors ) && self.acc_ldc_anchors.size > 0 ) ) return;

        if ( !point_near_anchors( self.origin, self.acc_ldc_anchors ) )
        {
            a   = self.acc_ldc_anchors[ acc_utility::acc_rand_int( self.acc_ldc_anchors.size ) ];
            nav = GetClosestPointOnNavMesh( a, 100, 40 );
            if ( isdefined( nav ) ) self forceteleport( nav );
            else self forceteleport( a );
        }
    }
}

function point_near_anchors( p, anchors )
{
    d  = getdvarint( "acc_lockdown_challenge_bounds_margin", 300 );
    d2 = d * d;
    for ( i = 0; i < anchors.size; i++ )
    {
        dx = p[ 0 ] - anchors[ i ][ 0 ];
        dy = p[ 1 ] - anchors[ i ][ 1 ];
        if ( ( dx * dx + dy * dy ) <= d2 ) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Resolve (clear / fail) - one-shot guarded, mutually exclusive
// ---------------------------------------------------------------------------

function challenge_clear( zone )
{
    if ( isdefined( level.acc_ldc_resolved ) && level.acc_ldc_resolved ) return;
    level.acc_ldc_resolved = true;
    level.acc_ldc_teardown = true;
    level notify( "acc_ldc_done" );

    ldc_debug( "CLEAR zone=" + zone );
    teardown_common( zone );

    if ( getdvarint( "acc_lockdown_reward", 1 ) == 1 )
        acc_boss_items::grant_challenge_reward( acc_lockdown::room_center_origin( zone ) );

    ldc_announce( level.acc_ldc_party, "^2LOCKDOWN CLEARED^7 - reward dropped" );

    level.acc_ldc_active = undefined;

    // Defeated: turn the DEFCON alarm OFF and gate the next one to +acc_lockdown_cooldown rounds
    // (user 2026-06-18 - so players don't think another is available, and a new one returns in ~4).
    acc_lockdown::on_defcon_cleared( ( isdefined( level.round_number ) ? level.round_number : 1 ) );
}

function challenge_fail( zone )
{
    if ( isdefined( level.acc_ldc_resolved ) && level.acc_ldc_resolved ) return;
    level.acc_ldc_resolved = true;
    level.acc_ldc_teardown = true;
    level notify( "acc_ldc_done" );

    ldc_debug( "FAIL zone=" + zone );
    teardown_common( zone );

    ldc_announce( level.acc_ldc_party, "^1LOCKDOWN FAILED^7" );

    level.acc_ldc_active = undefined;

    // Failed (party wiped): lights off; the uncleared DEFCON re-arms next round.
    acc_lockdown::on_defcon_failed();
}

// Unseal (Phase B) + RESTORE the room's outside spawns (mandatory, or that room stays dead) +
// cull any surviving tagged zombies (their death watches are already endon'd by acc_ldc_done).
function teardown_common( zone )
{
    unseal_room( zone );                                  // re-open the doors we closed (escape valve)
    acc_decontamination::enable_zone_spawning( zone );    // restore the room's outside spawns

    if ( isdefined( level.acc_ldc_party ) )
    {
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( isdefined( p ) && isplayer( p ) ) p destroy_challenge_hud();
        }
    }

    if ( isdefined( level.acc_ldc_zombies ) )
    {
        for ( i = 0; i < level.acc_ldc_zombies.size; i++ )
        {
            z = level.acc_ldc_zombies[ i ];
            if ( isdefined( z ) && isalive( z ) )
                z Kill();
        }
    }
    level.acc_ldc_zombies = [];
}

// Always-unseal safety: if the game ends mid-challenge, restore the active room's spawns so a
// future run/round is never left with a permanently dead room.
function on_end_game_safety()
{
    level waittill( "end_game" );
    if ( isdefined( level.acc_ldc_active ) )
        acc_decontamination::enable_zone_spawning( level.acc_ldc_active );
}

// ---------------------------------------------------------------------------
// Phase B door seal (LED-safe: reuses the existing buyable border doors, no new geometry)
// ---------------------------------------------------------------------------

// Each of the 4 rooms is bordered by exactly 2 stock buyable doors (acc_door_* script_brushmodels,
// verified in the current .map). We only touch doors that are OPEN (their enter_* flag set) so an
// un-bought (already-closed) door is left closed on teardown. NO acc_seal_* brushes / no .map edit
// -> -GscOnly, zero LED risk.
//
// HOW THIS MAP OPENS DOORS (the load-bearing fact, re-verified 2026-06-18): the entry script's
// acc_hardcoded_open_map (zm_abandoned_cyber_city.gsc:317) and dev_open_all_doors both open a door by
// `slab Show-inverse` = ConnectPaths(); NotSolid(); Hide() IN PLACE - the slab NEVER moves, it just
// goes invisible + non-colliding while sitting at its CLOSED origin z[0,128]. (It does carry
// script_vector "0 0 130", but the stock buy/MoveTo path is bypassed here - the map force-opens it.)
// So to RE-CLOSE = Show() + Solid() + DisconnectPaths() in place; the slab is already at z[0,128].
// We must NOT MoveTo it (that earlier "crush-safe close" via door_activate(false) slid it DOWN through
// the floor, so the room stopped locking). Crush-safety is kept by GATING Solid() on "no player is in
// the doorway" (door_player_touching) - the relocate-to-centre at commit means it's normally already
// clear, so it solidifies instantly; a player caught in it just defers the solid until they step off.
function room_doors( zone )
{
    d = [];
    switch ( zone )
    {
        case "vault_zone":  d[ 0 ] = make_door( "acc_door_vault",  "enter_vault" );  d[ 1 ] = make_door( "acc_door_lab_e",  "enter_lab_e" );  break;
        case "roof_zone":   d[ 0 ] = make_door( "acc_door_roof",   "enter_roof" );   d[ 1 ] = make_door( "acc_door_lab_w",  "enter_lab_w" );  break;
        case "alley_zone":  d[ 0 ] = make_door( "acc_door_alley",  "enter_alley" );  d[ 1 ] = make_door( "acc_door_corp_e", "enter_corp_e" ); break;
        case "market_zone": d[ 0 ] = make_door( "acc_door_market", "enter_market" ); d[ 1 ] = make_door( "acc_door_corp_w", "enter_corp_w" ); break;
    }
    return d;
}

function make_door( tn, flag )
{
    s = spawnstruct();
    s.tn = tn;
    s.flag = flag;
    return s;
}

function seal_room( zone )
{
    level.acc_ldc_sealed_doors = [];
    if ( getdvarint( "acc_lockdown_lock_doors", 1 ) != 1 ) return;

    doors = room_doors( zone );
    for ( i = 0; i < doors.size; i++ )
    {
        // Only close doors that are currently OPEN (their enter_* flag set). An un-bought door is
        // already a solid wall, so leave it - and must NOT re-open it on teardown.
        if ( !( level flag::exists( doors[ i ].flag ) && level flag::get( doors[ i ].flag ) ) ) continue;

        ents = getentarray( doors[ i ].tn, "targetname" );
        for ( j = 0; j < ents.size; j++ )
        {
            e = ents[ j ];
            if ( !isdefined( e ) ) continue;

            // Re-close IN PLACE (the slab is hidden at its closed origin z[0,128], it never moved -
            // see the section comment). Show + cut nav always (both safe); Solid only when the doorway
            // is player-clear so a caught player can't be stuck/ejected (reseal_monitor finishes it).
            e Show();
            e DisconnectPaths();
            if ( !door_player_touching( e ) ) e Solid();
            level.acc_ldc_sealed_doors[ level.acc_ldc_sealed_doors.size ] = e;
        }
    }
    ldc_debug( "sealing " + level.acc_ldc_sealed_doors.size + " door(s) for " + zone );
}

// True if any player is inside the door slab's bounds (the stock crush-safe occupancy test,
// _zm_blockers::door_solid_thread:1104). Used to never Solid() a slab a player is standing in.
function door_player_touching( e )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && p IsTouching( e ) )
            return true;
    }
    return false;
}

function unseal_room( zone )
{
    if ( !isdefined( level.acc_ldc_sealed_doors ) ) return;

    for ( i = 0; i < level.acc_ldc_sealed_doors.size; i++ )
    {
        e = level.acc_ldc_sealed_doors[ i ];
        if ( !isdefined( e ) ) continue;

        // Re-OPEN exactly how the map opened it (Hide/NotSolid/ConnectPaths in place) so players leave.
        e Hide();
        e NotSolid();
        e ConnectPaths();
    }
    level.acc_ldc_sealed_doors = [];
}

// Re-assert the seal every ~1s, crush-safely: Show + cut nav always; (re)Solid only when the doorway
// is player-clear. This also COMPLETES any door left un-solid at seal time (a player was standing in
// it) the moment they step off, and re-cuts a stray ConnectPaths. Ends before unseal (teardown
// notifies acc_ldc_done before unseal_room re-connects the paths).
function reseal_monitor( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 1 );
        if ( !isdefined( level.acc_ldc_sealed_doors ) ) continue;
        for ( i = 0; i < level.acc_ldc_sealed_doors.size; i++ )
        {
            e = level.acc_ldc_sealed_doors[ i ];
            if ( !isdefined( e ) ) continue;
            e Show();
            e DisconnectPaths();
            if ( !door_player_touching( e ) ) e Solid();
        }
    }
}

// Best-effort: move the committed party to a PROVEN-safe interior point before the doors close, so no
// player is standing in a doorway when collision re-materializes. Guards against the room_center_origin
// degenerate case (returns (0,0,0) when a zone has no spawners -> SetOrigin there = instant OOB kill)
// and against an in-geometry centroid by snapping to navmesh first; if neither check passes it leaves
// players where they are (the stock crush-safe close protects them anyway). Never moves a laststand
// player (you must not teleport a downed player).
function relocate_party_safe( zone, party )
{
    center = acc_lockdown::room_center_origin( zone );
    if ( center[ 0 ] == 0 && center[ 1 ] == 0 && center[ 2 ] == 0 ) return;  // degenerate centroid -> do NOT teleport

    nav = GetClosestPointOnNavMesh( center, 200, 60 );
    if ( !isdefined( nav ) ) return;                                          // no proven floor point -> leave players put

    dest = nav + ( 0, 0, 16 );                                               // feet-above-floor, never embedded
    for ( i = 0; i < party.size; i++ )
    {
        p = party[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !zm_utility::is_player_valid( p ) ) continue;                   // skip spectators / laststand
        p SetOrigin( dest );
    }
}

// ---------------------------------------------------------------------------
// Optional soft confinement (default OFF - the door seal above is the real lock-in) + fail detection
// ---------------------------------------------------------------------------

// Belt-and-suspenders only (acc_lockdown_challenge_confine 1): poll the party and yank anyone who
// somehow ends up outside back to the room centre. The door seal makes this unnecessary in normal play.
function confine_players( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    volumes = acc_decontamination::get_zone_volumes( zone );
    center  = acc_lockdown::room_center_origin( zone );

    for ( ;; )
    {
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !zm_utility::is_player_valid( p ) ) continue;   // don't yank a downed player
            if ( !acc_decontamination::player_in_zone_volumes( p, volumes ) )
                p SetOrigin( center + ( 0, 0, 16 ) );
        }
        wait( 0.25 );
    }
}

// Fail only when EVERY live party member is down AND an outside player is alive (so we never
// pre-empt the stock solo/all-wipe -> end_game). (Increment 3 refines this with self-revive
// handling per docs/43 §9.)
function watch_fail( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 0.5 );

        live = [];
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( isdefined( p ) && isplayer( p ) )
                live[ live.size ] = p;
        }
        if ( live.size == 0 )
        {
            challenge_fail( zone );   // everyone disconnected
            return;
        }

        any_up = false;
        for ( i = 0; i < live.size; i++ )
        {
            if ( zm_utility::is_player_valid( live[ i ] ) ) { any_up = true; break; }
        }
        if ( any_up ) continue;   // someone inside is still fighting

        // All inside are down. Fail (unseal) only if the round genuinely continues outside.
        if ( outside_player_alive() )
        {
            challenge_fail( zone );
            return;
        }
        // else: solo / whole-team wipe -> stock end_game owns it; do NOT fail-unseal.
    }
}

function outside_player_alive()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && zm_utility::is_player_valid( p ) && !is_in_party( p ) )
            return true;
    }
    return false;
}

function is_in_party( player )
{
    if ( !isdefined( level.acc_ldc_party ) ) return false;
    for ( i = 0; i < level.acc_ldc_party.size; i++ )
        if ( level.acc_ldc_party[ i ] == player ) return true;
    return false;
}

// ---------------------------------------------------------------------------
// Dev / debug / feedback (real server-side X/30 HUD lands in Increment 3)
// ---------------------------------------------------------------------------

function watch_force_dvar()
{
    level endon( "end_game" );
    for ( ;; )
    {
        forced = getdvarstring( "acc_lockdown_challenge_force" );
        if ( isdefined( forced ) && forced != "" && !isdefined( level.acc_ldc_active ) )
        {
            SetDvar( "acc_lockdown_challenge_force", "" );
            party = inside_party( acc_decontamination::get_zone_volumes( forced ) );
            if ( party.size == 0 ) party = GetPlayers();   // dev: just use everyone
            commit_challenge( forced, party );
        }
        wait( 1 );
    }
}

// Per-inside-player objective HUD: "GLITCH PURGE" label + a bar that FILLS as you progress + a
// "killed / total" number. Top-centre, under the zone-name banner. Reuses the proven _acc_health_bars
// hud::createBar idiom (the colored fill is .bar; acc_set_bar_smooth glides it). self = player.
function create_challenge_hud()
{
    if ( isdefined( self.acc_ldc_label ) ) return;   // already built

    total = getdvarint( "acc_lockdown_challenge_total", ACC_LDC_TOTAL_DEF );

    self.acc_ldc_label = self hud::createFontString( "objective", 1.3 );
    self.acc_ldc_label hud::setPoint( "TOP", "TOP", 0, 62 );
    self.acc_ldc_label.alignX = "center";
    self.acc_ldc_label.alignY = "top";
    self.acc_ldc_label.color = ( 1, 0.15, 0.15 );
    self.acc_ldc_label.alpha = 0.95;
    self.acc_ldc_label.hidewheninmenu = true;
    self.acc_ldc_label SetText( "^1GLITCH PURGE" );

    self.acc_ldc_bar = self hud::createBar( ( 0.9, 0.15, 0.15 ), ACC_LDC_BAR_W, ACC_LDC_BAR_H );
    self.acc_ldc_bar hud::setPoint( "TOP", "TOP", 0, 84 );
    self.acc_ldc_bar.alpha = 0.9;
    self.acc_ldc_bar.hidewheninmenu = true;

    self.acc_ldc_num = self hud::createFontString( "default", 1.0 );
    self.acc_ldc_num hud::setPoint( "TOP", "TOP", 0, 98 );
    self.acc_ldc_num.alignX = "center";
    self.acc_ldc_num.alignY = "top";
    self.acc_ldc_num.color = ( 1, 1, 1 );
    self.acc_ldc_num.alpha = 0.95;
    self.acc_ldc_num.hidewheninmenu = true;
    self.acc_ldc_num SetText( "0 / " + total );
}

function destroy_challenge_hud()
{
    if ( isdefined( self.acc_ldc_label ) ) { self.acc_ldc_label Destroy(); self.acc_ldc_label = undefined; }
    if ( isdefined( self.acc_ldc_bar ) )
    {
        if ( isdefined( self.acc_ldc_bar.bar ) ) self.acc_ldc_bar.bar Destroy();   // the colored fill child
        self.acc_ldc_bar Destroy();
        self.acc_ldc_bar = undefined;
    }
    if ( isdefined( self.acc_ldc_num ) ) { self.acc_ldc_num Destroy(); self.acc_ldc_num = undefined; }
}

// Push the live count to every inside player's bar + number (called on each kill).
function ldc_update_hud()
{
    if ( !isdefined( level.acc_ldc_party ) ) return;

    total  = getdvarint( "acc_lockdown_challenge_total", ACC_LDC_TOTAL_DEF );
    killed = level.acc_ldc_killed;
    frac   = ( total > 0 ? ( killed / total ) : 1 );   // bar fills as you clear toward 30

    for ( i = 0; i < level.acc_ldc_party.size; i++ )
    {
        p = level.acc_ldc_party[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !isdefined( p.acc_ldc_bar ) ) continue;

        acc_health_bars::acc_set_bar_smooth( p.acc_ldc_bar, frac, 0.25 );
        if ( isdefined( p.acc_ldc_num ) )
            p.acc_ldc_num SetText( killed + " / " + total );
    }
}

function ldc_announce( party, msg )
{
    if ( !isdefined( party ) ) return;
    for ( i = 0; i < party.size; i++ )
        if ( isdefined( party[ i ] ) && isplayer( party[ i ] ) )
            party[ i ] IPrintLnBold( msg );
}

function ldc_debug( msg )
{
    acc_utility::log( "ldc: " + msg );
    if ( getdvarint( "acc_lockdown_challenge_debug", 0 ) != 1 ) return;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( "[ldc] " + msg );
}
