// =============================================================================
// _acc_fury.gsc - Apothicon Fury TRENCH ELITE (user 2026-07-03)
//
// The HB21 Apothicon Fury pack (v1.1.0, external - see tools/external_assets_manifest.ps1)
// ships the archetype + a "special fury rounds" mode; that mode is DISABLED in our
// zm_genesis_apothicon_fury.gsh (APOTHICAN_FURY_USE_SPECIAL_FURY_ROUNDS 0) - THIS module
// is the only spawner. Design (user): "like the glitch and shielded" - an ELITE, not a
// boss. It does NOT count toward the round (SpawnActor'd extra, zombie_total untouched -
// same contract as the Glitch altar zombies).
//
//   - HEALTH: flat 12x the current round's zombie health (acc_fury_health_mult), OVERRIDING
//     the pack's 1.2/1.5/1.7 round tiers (its threaded health_init runs first; we re-set
//     after our post-spawn wait, so ours wins). The 12x is against a CO-OP-SCALED zombie at any
//     player count - but unlike our promoted-factory-zombie elites (Shielded/Glitch), this actor is
//     SpawnActor'd, so stock zombie_spawn_init + acc_coop_scaling's level.zombie_init_done hook NEVER
//     run on it and fury_tune must apply regular_hp_mult() BY HAND (fixed 2026-07-15 - see fury_tune).
//   - SPEED: matches the round zombies' GAIT - run before acc_zspeed_sprint_round (15,
//     read via acc_zombie_speed::sprint_start_round() - never re-inline the default here),
//     sprint from it (the horde's exact speed is a per-zombie xanim playback rate from
//     _acc_zombie_speed that a different archetype can't share; gait is the same knob the
//     stock fury uses, ai::set_behavior_attribute("move_speed")).
//   - CADENCE (user 2026-07-03, PER-PLAYER): EVERY player runs their OWN independent
//     acc_fury_interval (30s) clock; while that player is at trench LAYER >= acc_fury_min_layer
//     (2 - "level 2 trench and below", NOT layer 1/the pit), each full interval meteor-drops one
//     fury near them. Timers are per-player, so N players deep = N independent spawn streams
//     ("stacks"). Leaving the deep trench PAUSES that player's clock (doesn't reset). Cap scales:
//     acc_fury_max_per_player (2) x deep-player count, hard-ceiling acc_fury_max_ceil (8).
//   (A dev-only round-1 test spawn validated the archetype in game 2026-07-03 and was
//   removed the same day - the trench cadence is the only spawner.)
//
// Points/AAT/death events are the pack's own (registered per-archetype in
// zm_genesis_apothicon_fury.gsc __init__). Kill credit pays like a zombie kill.
// =============================================================================

#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_genesis_apothicon_fury;
#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;   // underground_layer (trench-layer gate)
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;  // regular_hp_mult() - the fury is SpawnActor'd, so it never gets the co-op HP hook (see fury_tune)
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;  // sprint_start_round() - the ONE sprint-round authority (see gait below)

#insert scripts\shared\shared.gsh;

// Underground z gate for the SPAWN SPOT (a drop can't land above the deep trench). The PLAYER
// gate is now a trench-LAYER check (>= acc_fury_min_layer), not this plane.
#define ACC_FURY_Z_DEF          -36
#define ACC_FURY_INTERVAL_DEF    30   // seconds between a PLAYER's trench fury drops (user 2026-07-03, per-player)
#define ACC_FURY_MIN_LAYER_DEF    2   // only spawn while a player is at trench LAYER >= 2 (user 2026-07-03: "lv2 and below")
#define ACC_FURY_MAX_PER_PLAYER   2   // furies a single deep player contributes to the alive cap
#define ACC_FURY_MAX_CEIL_DEF     8   // hard ceiling on total alive furies (actor-budget safety)
#define ACC_FURY_HEALTH_MULT_DEF  12.0 // x current round zombie health (user 2026-07-03: 5x -> 8x; 2026-07-04: 8x -> 10x; 2026-07-09: 10x -> 12x)

#namespace acc_fury;

function init()
{
    if ( getdvarint( "acc_fury_on", 1 ) != 1 ) return;

    level.acc_furies = [];
    level thread fury_manager();
    if ( IS_TRUE( level.acc_dev ) )
        level thread dev_fury_watchers();

    dbg( "init (12x hp, PER-PLAYER every " + getdvarfloat( "acc_fury_interval", ACC_FURY_INTERVAL_DEF )
        + "s at trench layer >= " + getdvarint( "acc_fury_min_layer", ACC_FURY_MIN_LAYER_DEF ) + ")" );
}

// DEV log that ALSO reaches console_mp.log (IPrintLnBold routes as [ SCRIPTER]; acc_utility::log's
// /# println #/ path does NOT). No-op in normal play.
function dbg( msg )
{
    acc_utility::log( "fury: " + msg );
    // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
    if ( !IS_TRUE( level.acc_dev ) )
        return;
    players = GetPlayers();
    if ( players.size > 0 && isdefined( players[ 0 ] ) && isplayer( players[ 0 ] ) )
        players[ 0 ] IPrintLnBold( "^5[FURY] " + msg );
}

// DEV: (1) console `acc_fury_spawn 1` force-drops a fury near player 0 NOW (bypasses layer/timer -
// proves the SPAWN path works independent of the gate). (2) every 5s print each player's trench
// layer so we can see whether anyone is actually reaching layer >= 2.
function dev_fury_watchers()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );
    n = 0;
    for ( ;; )
    {
        if ( getdvarint( "acc_fury_spawn", 0 ) == 1 )
        {
            SetDvar( "acc_fury_spawn", "0" );
            players = GetPlayers();
            if ( players.size > 0 && isdefined( players[ 0 ] ) )
            {
                dbg( "FORCE-SPAWN (console) near player at layer " + acc_bus_trench::underground_layer( players[ 0 ].origin ) );
                e = spawn_fury_near( players[ 0 ], false );   // require_underground=false so it works anywhere
                dbg( "force-spawn result: " + ( isdefined( e ) ? "OK" : "FAILED (query/zone/pack-spawn)" ) );
            }
        }
        n++;
        if ( n % 5 == 0 )   // every 5s, layer readout for player 0
        {
            players = GetPlayers();
            if ( players.size > 0 && isdefined( players[ 0 ] ) )
                dbg( "layer=" + acc_bus_trench::underground_layer( players[ 0 ].origin )
                     + " z=" + int( players[ 0 ].origin[ 2 ] ) + " (need layer >= "
                     + getdvarint( "acc_fury_min_layer", ACC_FURY_MIN_LAYER_DEF ) + ") furies=" + fury_count() );
        }
        wait 1;
    }
}

// Give every connected player ONE persistent per-player timer thread (guard flag so we never
// double-thread). Each player's timer is independent - N players deep = N spawn streams.
function fury_manager()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        foreach ( player in players )
        {
            if ( isdefined( player ) && !IS_TRUE( player.acc_fury_timer_on ) )
            {
                player.acc_fury_timer_on = true;
                player thread fury_player_timer();
            }
        }
        wait 2;
    }
}

// self = a player. Their OWN clock, advancing only while at trench layer >= min (leaving PAUSES
// it, doesn't reset). Independent per player => furies stack in co-op. Live-diagnosed 2026-07-03:
// requiring the FULL 30s dwell before the FIRST spawn meant furies almost never appeared (nobody
// camps deep-trench 30s straight - the user reached layer 2 for ~20s and saw nothing). FIX: the
// FIRST drop after entering the deep trench arms in acc_fury_arm_sec (8s), so descending actually
// produces a fury; subsequent drops keep the acc_fury_interval (30s) cadence while they stay deep.
// Bailing out of the deep trench re-arms the short delay on the next descent.
function fury_player_timer()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    b_first = true;   // next drop uses the short arm (fresh descent), not the full interval

    for ( ;; )
    {
        delay = ( b_first
                  ? getdvarfloat( "acc_fury_arm_sec", 8 )
                  : getdvarfloat( "acc_fury_interval", ACC_FURY_INTERVAL_DEF ) );

        waited = 0;
        while ( waited < delay )
        {
            wait 1;
            if ( player_deep( self ) ) waited += 1;
        }

        if ( !player_deep( self ) )   // surfaced before the timer fired -> re-arm the short delay
        {
            b_first = true;
            continue;
        }
        if ( fury_count() >= effective_cap() )
            continue;

        e = spawn_fury_near( self, true );
        if ( isdefined( e ) )
        {
            b_first = false;   // armed drop done -> stay on the 30s cadence while deep
            dbg( "spawned near you (layer " + acc_bus_trench::underground_layer( self.origin ) + ", next in " + getdvarfloat( "acc_fury_interval", ACC_FURY_INTERVAL_DEF ) + "s)" );
        }
    }
}

// A player is "deep" (fury-eligible) while at trench LAYER >= acc_fury_min_layer (2). Uses the
// canonical _acc_bus_trench layer (which already excludes the hallway / Exchange / surface).
function player_deep( player )
{
    if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) ) return false;
    return acc_bus_trench::underground_layer( player.origin ) >= getdvarint( "acc_fury_min_layer", ACC_FURY_MIN_LAYER_DEF );
}

// How many players are currently deep - scales the alive cap so more players => more furies allowed.
function deep_player_count()
{
    n = 0;
    foreach ( player in GetPlayers() )
        if ( player_deep( player ) ) n++;
    return n;
}

// Alive-fury cap = NUMBER OF PLAYERS in the game (user 2026-07-07: "match number of players - solo 1, ...,
// 4p 4"). Was deep-players x 2 (up to 8); now simply the live player count, so it tracks the lobby size
// (solo 1 / duo 2 / trio 3 / quad 4). The actor-budget ceiling (8) still backstops as a hard safety.
function effective_cap()
{
    cap = GetPlayers().size;
    if ( cap < 1 ) cap = 1;
    ceil = getdvarint( "acc_fury_max_ceil", ACC_FURY_MAX_CEIL_DEF );
    if ( cap > ceil ) cap = ceil;
    return cap;
}

// Living fury census (self-pruning).
function fury_count()
{
    alive = [];
    foreach ( e in level.acc_furies )
    {
        if ( isdefined( e ) && IsAlive( e ) )
            alive[ alive.size ] = e;
    }
    level.acc_furies = alive;
    return alive.size;
}

// Meteor-drop one fury near `player` (pack flow: navmesh query -> spot filter -> meteor FX ->
// spawn). require_underground constrains candidates below the z gate so a trench drop can't land
// on the surface above the player. Returns the AI or undefined.
//
// THE TRENCH-SPAWN FIX (user 2026-07-03: "furies spawned fine at Plaza but never in the trench"):
// the deep trench floor (z=-240 and below) sits BELOW every zone's player_volume (corp_zone spans
// z[-16,400]), so zm_utility::check_point_in_enabled_zone() returns FALSE for EVERY trench navmesh
// point and rejected all 20 candidates - the fury only ever spawned on the surface (Plaza), which
// IS in an enabled zone. So we SKIP the enabled-zone check on the underground path: the query is
// already centered on a valid deep player and returns pathable navmesh, and apothicon_fury_spawn
// force-sets completed_emerging_into_playable_area=1 (no OOB-kill / melee-lockout below the volume -
// the SAME below-zone fix the trench SURGE uses). The surface dev force-spawn still gates on the zone.
function spawn_fury_near( player, require_underground )
{
    z_gate = getdvarfloat( "acc_fury_z", ACC_FURY_Z_DEF );

    query = positionQuery_Source_Navigation( player.origin, 200, 800, 128, 20 );
    if ( !isdefined( query ) || query.data.size == 0 )
    {
        dbg( "spawn FAIL: navmesh query empty near player (no nav within 800u?)" );
        return undefined;
    }

    n_reject_z = 0;
    n_reject_zone = 0;
    spots = array::randomize( query.data );
    foreach ( spot in spots )
    {
        origin = spot.origin;
        if ( IS_TRUE( require_underground ) && origin[ 2 ] > z_gate ) { n_reject_z++; continue; }
        // Enabled-zone gate ONLY on the surface path - the trench is below all zone volumes (see header).
        if ( !IS_TRUE( require_underground ) && !zm_utility::check_point_in_enabled_zone( origin, 1 ) ) { n_reject_zone++; continue; }

        angles = VectorToAngles( VectorNormalize( player.origin - origin ) );

        // Pack visuals: sky meteor + landing boom, then the spawn (blocks ~1.5s).
        zm_genesis_apothicon_fury::apothicon_fury_meteor_fx( origin );
        e = zm_genesis_apothicon_fury::apothicon_fury_spawn( origin, angles, 0 );
        if ( !isdefined( e ) )
        {
            dbg( "spawn FAIL: pack apothicon_fury_spawn returned undefined (archetype not loaded?)" );
            continue;
        }

        // [acc] ROUND-END FIX (user 2026-07-04): the pack spawns the fury with is_zombie=1 but never
        // sets ignore_enemy_count, so stock get_current_zombie_count() COUNTS it toward the round - a
        // fury alive after the horde clears would make the round NEVER END (softlock). This is the
        // "SpawnActor'd extra, zombie_total untouched" the header promised but the flag was missing.
        // Set it HERE (not in fury_tune, which has a `wait 1` window where it would still be counted).
        // Mirrors every sibling extra spawner (_acc_bus_trench:965, _acc_boss_glitch:282).
        e.ignore_enemy_count = true;
        e.acc_is_fury = true;   // [acc] leveling: tag so _acc_leveling::on_zombie_killed pays the Fury elite XP bonus (docs/45)

        // [acc] BELOW-WORLD CULL IMMUNITY (Paradise audit, user 2026-07-09): the pack threads the stock
        // zombie_utility::round_spawn_failsafe on every fury (zm_genesis_apothicon_fury.gsc:193), and
        // that failsafe silently DoDamage-kills ANY actor whose z sits below below_world_check (-1000)
        // on its 30s tick - REGARDLESS of movement. A trench-L5 fury (z=-1200) was being culled ~30s in,
        // and every Paradise fury (arena z=-1200) would be guaranteed dead in 30s. The failsafe re-reads
        // this flag each loop, so setting it here (same frame as spawn) fully disarms it - the same
        // treatment every deep boss gets (paradise Brutus / Rogue Protector / Avogadro).
        e.ignore_round_spawn_failsafe = true;

        level.acc_furies[ level.acc_furies.size ] = e;
        e thread fury_tune();
        return e;
    }
    dbg( "spawn FAIL: no usable spot of " + query.data.size + " (z-rejected " + n_reject_z + ", zone-disabled " + n_reject_zone + ")" );
    return undefined;
}

// PARADISE WAVE FURY (user 2026-07-09): spawn ONE fury INTO the Paradise arena as part of the finale
// boss wave (_acc_paradise::maybe_spawn_fury, cap 1 - the same rolling one-of-each contract as the other
// bosses). Anchors the meteor-drop on a living player already in the arena; require_underground=true is
// the below-zone path (z gate -36; the arena floor -1200 passes) which SKIPS the enabled-zone check and
// force-emerges - the exact trench recipe, so the drop can't land topside. Boss-flagged so the battle's
// clean-slate purge, the Rogue Protector landing splash, and the octobomb targeting all exclude it, and
// no-shard like every Paradise wave boss (a THREAT, not a farm). Returns the AI or undefined.
function spawn_paradise_fury()
{
    anchor = undefined;
    foreach ( p in GetPlayers() )
    {
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) && acc_bus_trench::player_in_second_part( p ) )
        {
            anchor = p;
            break;
        }
    }
    if ( !isdefined( anchor ) )
        return undefined;

    e = spawn_fury_near( anchor, true );
    if ( !isdefined( e ) )
        return undefined;

    e.acc_is_mini_boss    = true;   // purge/landing-splash/octobomb exclusion + boss damage handling
    e.acc_no_shard_reward = true;   // parity with the other Paradise wave bosses (no Data Shards)
    dbg( "PARADISE fury joined the battle" );
    return e;
}

// Post-spawn stat override: 12x round zombie health + the horde's current gait.
// Runs AFTER the pack's threaded health_init + the 1s think-done settle, so ours is final.
function fury_tune()
{
    self endon( "death" );

    wait 1;
    self.zombie_think_done = 1;  // hunt immediately (pack sets this only on its own spawn paths)

    // CO-OP: apply regular_hp_mult() BY HAND (fixed 2026-07-15). The Shielded elite and the Glitch Stalker
    // are both PROMOTED FACTORY ZOMBIES - stock zombie_spawn_init runs on them, so acc_coop_scaling's
    // level.zombie_init_done hook bakes the +20%/extra-player mult into maxhealth and a flat multiply on
    // that base is co-op-correct for free. The fury is NOT one of those: it is SpawnActor'd from the pack's
    // own spawner (spawn_fury below), so zombie_spawn_init - and with it the co-op hook - NEVER runs on it.
    // That makes BOTH obvious bases wrong: self.maxhealth here is the PACK's health_init tier (1.2/1.5/1.7x),
    // not a scaled zombie, and level.zombie_health is the SOLO round HP. So multiply explicitly, or a 4p fury
    // is 12x a SOLO zombie = only 7.5x a 4p zombie. Went unnoticed because at 1p the mult is exactly 1.0 -
    // identical in every solo test. Do NOT use special_hp_mult(): that double-counts co-op and breaks parity
    // with the Shielded's "clean multiple of a normal zombie at any player count" contract
    // (_acc_elites.gsc:311-318, _acc_coop_scaling.gsc:99-106).
    n_zombie_health = level.zombie_health;
    if ( !isdefined( n_zombie_health ) || n_zombie_health <= 0 )
        n_zombie_health = level.zombie_vars[ "zombie_health_start" ];
    n_normal_hp = int( n_zombie_health * acc_coop_scaling::regular_hp_mult() );
    if ( n_normal_hp < 1 ) n_normal_hp = 1;
    self.maxhealth = int( n_normal_hp * getdvarfloat( "acc_fury_health_mult", ACC_FURY_HEALTH_MULT_DEF ) );
    self.health = self.maxhealth;

    // Same gait as the round's horde: run pre-sprint-round, sprint from it (_acc_zombie_speed's tier knob).
    // Read the round through acc_zombie_speed::sprint_start_round() - NEVER re-inline the dvar+default here.
    // A local copy of the default drifts: this line carried a stale 17 after the 2026-07-09 curve shift moved
    // the real default to 15 (ACC_ZSPEED_SPRINT_ROUND_DEF), so the Fury jogged at R15-16 while the horde sprinted.
    sprint_round = acc_zombie_speed::sprint_start_round();
    gait = ( ( level.round_number >= sprint_round ) ? "sprint" : "run" );
    self ai::set_behavior_attribute( "move_speed", gait );
}
