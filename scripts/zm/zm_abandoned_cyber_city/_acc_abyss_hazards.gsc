// =============================================================================
// _acc_abyss_hazards.gsc - "Infected Descent" per-floor twist hazards (docs/30,
// locked plan 2026-07-12; RAMP-IN per the user's pick: L2/L3 SPATIAL-ONLY,
// L4/L5 DAMAGING). One level thread per abyss floor; each tick acts only on
// players whose acc_bus_trench::underground_layer(origin) == that floor - the
// layer math auto-covers the mezzanine decks (Gantry feet -848 -> 4, Overlook
// feet -1120 -> 5), which IS the decks' anti-camp.
//
// Escalation contract: L2 obscure -> L3 disorient -> L4 damage+blind -> L5
// damage+herd-to-exit.
//
// SAFETY RAILS (locked in the plan - keep them on any edit):
//  * NO hazard ever applies a movement slow (recompute_move_speed already
//    layers the Exo/trench slow - a hazard slow = double-punish).
//  * Everything telegraphs before it can hurt (haze/steam tell + rumble).
//  * Damage idiom: DoDamage( amt, origin, undefined, undefined, 0,
//    "MOD_UNKNOWN" ) - undefined attacker dodges the stock self-damage
//    whitelist; MOD_UNKNOWN bypasses PhD BY DESIGN (abyss corruption), flip
//    per-floor via acc_abyss_l4/l5_phd_immune 1.
//  * Damage is small, ticking, self-terminating (leave the area = stops).
//    Downed/spectating players are never damaged.
//  * ONLY live-proven FX are used (acc_haze / acc_steam from _acc_atmosphere)
//    + the stock Earthquake() rumble - no new FX registrations, zero precache
//    risk (the L2 conduit-spark burst is a deferred polish item).
//  * Radius checks are Distance2D + a z-band (memory: 3D Distance() from an
//    elevated center dead-zones feet-origin players).
//  * Master kill-switch acc_abyss_hazards (default 1, read LIVE each cycle);
//    per-floor cadence dvars; dev god-safety acc_abyss_godsafe (default 1,
//    only consulted when level.acc_dev - visuals still run, damage skipped).
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;

#namespace acc_abyss_hazards;

// Floor z of each abyss layer (mirrors gen_abyss_layer.js floorZ()).
#define ACC_L2_FLOOR -480
#define ACC_L3_FLOOR -720
#define ACC_L4_FLOOR -960
#define ACC_L5_FLOOR -1200

function init()
{
    // DEFAULT-OFF IS INTENTIONAL AND STILL IN FORCE - do NOT "restore" it to 1 (comment corrected
    // 2026-07-15 audit; the old wording said "Flip back after", which read as a forgotten bisect
    // leftover and invites exactly that wrong fix).
    //
    // History: the default went 1 -> 0 on 2026-07-12 alongside acc_abyss_deco while the +0x2bc4ee9
    // post-launch CTD was isolated. The bisect ACQUITTED the hazards - "deco/hazards default-off did
    // NOT fix it; removing the [10 baked abyss] lights DID (user-confirmed)" - so this flag is no
    // longer holding back a crash. It stays 0 anyway because the hazards are PARKED behind the
    // user-agreed staged recovery (CHANGELOG, 2026-07-12): "re-introduce ONE floor at a time - props
    // + their clips together, sparse, user look-pass gates each floor; HAZARDS LAST." The per-floor
    // approval loop has not reached them yet.
    //
    // WHEN TO FLIP: only after the abyss floors are re-introduced and look-passed, at the user's call
    // - not as a code-hygiene fix. (docs/30 still describes the hazards as shipped; that doc is ahead
    // of the code by design while this is parked.)
    if ( getdvarint( "acc_abyss_hazards", 0 ) != 1 )
        return;

    level thread l2_brownout_loop();
    level thread l3_spore_loop();
    level thread l4_vent_loop();
    level thread l5_tide_loop();

    acc_utility::log( "abyss hazards init (L2 brownout / L3 spores / L4 vents / L5 tide)" );
}

// ---- shared helpers ---------------------------------------------------------

// Live players currently standing on abyss layer n (auto-excludes Paradise,
// the Exchange vault, stair fringe - underground_layer handles all of it).
function players_on_layer( n )
{
    out = [];
    players = GetPlayers();
    foreach ( p in players )
    {
        if ( !isdefined( p ) || !isalive( p ) ) continue;
        if ( isdefined( p.sessionstate ) && p.sessionstate == "spectator" ) continue;
        if ( acc_bus_trench::underground_layer( p.origin ) != n ) continue;
        out[ out.size ] = p;
    }
    return out;
}

// The mandated environmental-damage idiom. Skips downed players + dev god-safety.
function hazard_damage( player, amt )
{
    if ( !isdefined( player ) || !isalive( player ) ) return;
    if ( player laststand::player_is_in_laststand() ) return;
    if ( IS_TRUE( level.acc_dev ) && getdvarint( "acc_abyss_godsafe", 1 ) == 1 ) return;
    player DoDamage( amt, player.origin, undefined, undefined, 0, "MOD_UNKNOWN" );
}

function fx_at( key, origin )
{
    if ( !isdefined( level._effect ) || !isdefined( level._effect[ key ] ) ) return;
    PlayFX( level._effect[ key ], origin );
}

// ---- L2 "FALTERING GRID" - rolling brownout (SPATIAL ONLY) ------------------
// The grid buckles on a jittered period: a floor-wide rumble + haze swells at
// the conduit anchors transiently obscure the room. No damage, no slow. (A
// true baked-light dim is impossible at runtime - lighting states are
// map-global - so the haze swell IS the obscurant; a csc dynamic-light flicker
// is a deferred polish experiment.)
function l2_brownout_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        period = getdvarfloat( "acc_abyss_l2_brownout_period", 14 );
        wait period + RandomFloatRange( -3, 3 );
        if ( getdvarint( "acc_abyss_hazards", 1 ) != 1 ) continue;
        if ( players_on_layer( 2 ).size == 0 ) continue;   // nobody there - don't spam FX

        // The beat: rumble + haze swell at the four conduit anchors (mirrors
        // the _acc_abyss_deco wire-run/breaker placements).
        Earthquake( 0.22, 1.2, ( 0, 1948, ACC_L2_FLOOR ), 900 );
        fx_at( "acc_haze", ( -400, 1760, ACC_L2_FLOOR + 60 ) );
        fx_at( "acc_haze", (  500, 2130, ACC_L2_FLOOR + 60 ) );
        fx_at( "acc_haze", ( -550, 1948, ACC_L2_FLOOR + 60 ) );
        fx_at( "acc_haze", (  560, 1880, ACC_L2_FLOOR + 60 ) );
    }
}

// ---- L3 "CORRUPTION BLOOM" - spore bursts (SPATIAL ONLY) --------------------
// Round-robin pods at the floor's pinch points rupture: a steam hiss tell,
// then a dense lingering haze cloud (the moving fog-wall obstacle). No damage.
function l3_spore_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // Pod anchors mirror the _acc_abyss_deco spore-rock / mutated-plant spots.
    pods = [];
    pods[ pods.size ] = ( -700, 1780, ACC_L3_FLOOR );
    pods[ pods.size ] = (  750, 2120, ACC_L3_FLOOR );
    pods[ pods.size ] = ( -650, 2130, ACC_L3_FLOOR );
    pods[ pods.size ] = (  250, 1745, ACC_L3_FLOOR );
    pods[ pods.size ] = (  450, 1990, ACC_L3_FLOOR );   // the slalom rock

    i = 0;
    for ( ;; )
    {
        wait getdvarfloat( "acc_abyss_l3_spore_period", 11 );
        if ( getdvarint( "acc_abyss_hazards", 1 ) != 1 ) continue;
        if ( players_on_layer( 3 ).size == 0 ) continue;

        pod = pods[ i % pods.size ];
        i++;

        fx_at( "acc_steam", pod );          // the hiss tell
        wait 1.5;
        // The cloud: two stacked lingering haze emits read dense; a second
        // pulse at half-life keeps it alive for the full window.
        fx_at( "acc_haze", pod + ( 0, 0, 20 ) );
        fx_at( "acc_haze", pod + ( 0, 0, 60 ) );
        level thread spore_cloud_refresh( pod );
    }
}

function spore_cloud_refresh( pod )
{
    level endon( "end_game" );
    wait getdvarfloat( "acc_abyss_l3_spore_life", 8 ) * 0.5;
    fx_at( "acc_haze", pod + ( 0, 0, 40 ) );
}

// ---- L4 "SPECIMEN VAULT" - pod rupture vents (DAMAGING + blind) -------------
// A random vault pod blows its seal: 1.5s steam tell, then a 2.5s vent that
// blinds the pinch and ticks damage in a tight ring. The 7th anchor sits ON
// the Gantry deck = the deck's anti-camp.
function l4_vent_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    vents = [];
    vents[ vents.size ] = (  300, 1745, ACC_L4_FLOOR );   // lit vessel, S wall
    vents[ vents.size ] = (  795, 1800, ACC_L4_FLOOR );   // vessel, E wall
    vents[ vents.size ] = ( -600, 1760, ACC_L4_FLOOR );   // frosted pod, S wall
    vents[ vents.size ] = ( -756, 1850, ACC_L4_FLOOR );   // frosted pod, W wall
    vents[ vents.size ] = ( -250, 1880, ACC_L4_FLOOR );   // vat cylinder, W bay
    vents[ vents.size ] = (  560, 1870, ACC_L4_FLOOR );   // vat cylinder, E bay
    vents[ vents.size ] = (  740, 2090, -848 );           // GANTRY DECK anchor (anti-camp)

    for ( ;; )
    {
        wait getdvarfloat( "acc_abyss_l4_vent_period", 9 );
        if ( getdvarint( "acc_abyss_hazards", 1 ) != 1 ) continue;
        if ( players_on_layer( 4 ).size == 0 ) continue;

        vent = vents[ acc_utility::acc_rand_int( vents.size ) ];
        fx_at( "acc_steam", vent );         // the 1.5s hiss tell
        wait getdvarfloat( "acc_abyss_l4_vent_tell", 1.5 );

        dur    = getdvarfloat( "acc_abyss_l4_vent_dur", 2.5 );
        radius = getdvarfloat( "acc_abyss_l4_vent_radius", 96 );
        dmg    = getdvarint( "acc_abyss_l4_vent_dmg", 18 );
        for ( t = 0; t < dur; t += 0.5 )
        {
            fx_at( "acc_steam", vent + ( 0, 0, 30 ) );
            foreach ( p in players_on_layer( 4 ) )
            {
                if ( Distance2D( p.origin, vent ) > radius ) continue;
                if ( abs( p.origin[ 2 ] - vent[ 2 ] ) > 128 ) continue;   // z-band (covers deck vs floor)
                hazard_damage( p, dmg );
            }
            wait 0.5;
        }
    }
}

// ---- L5 "THE MAW" - corrosive tide (DAMAGING + herd-to-exit) ----------------
// The maw swallows: after a 2s rumble tell, a bile line wells from the NORTH
// wall and sweeps SOUTH at under-sprint speed. Anyone NORTH of the line ticks
// damage until they outrun it. The line ALWAYS stops short of the south third
// - a permanent safe lane at the Paradise mouth. Sweeps the Overlook's Y band
// too (deck players read as layer 5) = the perch's anti-camp.
function l5_tide_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        wait getdvarfloat( "acc_abyss_l5_tide_period", 16 );
        if ( getdvarint( "acc_abyss_hazards", 1 ) != 1 ) continue;
        if ( players_on_layer( 5 ).size == 0 ) continue;

        // The tell: a deep rumble + haze welling along the north wall.
        Earthquake( 0.3, 2, ( 0, 2173, ACC_L5_FLOOR ), 1400 );
        fx_at( "acc_haze", ( -400, 2150, ACC_L5_FLOOR + 30 ) );
        fx_at( "acc_haze", (  400, 2150, ACC_L5_FLOOR + 30 ) );
        wait 2;

        speed  = getdvarfloat( "acc_abyss_l5_tide_speed", 90 );
        stop_y = getdvarfloat( "acc_abyss_l5_tide_stop_y", 1880 );
        dmg    = getdvarint( "acc_abyss_l5_tide_dmg", 22 );
        if ( speed < 10 ) speed = 10;   // guard a nonsense dvar from stalling the loop

        line_y = 2173;
        while ( line_y > stop_y )
        {
            line_y -= speed * 0.5;      // 0.5s ticks
            if ( line_y < stop_y ) line_y = stop_y;

            // The advancing front: a sparse haze row at the line (kept to 4
            // columns per tick so a sweep stays ~30 FX total).
            fx_at( "acc_haze", ( -600, line_y, ACC_L5_FLOOR + 20 ) );
            fx_at( "acc_haze", ( -200, line_y, ACC_L5_FLOOR + 20 ) );
            fx_at( "acc_haze", (  200, line_y, ACC_L5_FLOOR + 20 ) );
            fx_at( "acc_haze", (  600, line_y, ACC_L5_FLOOR + 20 ) );

            foreach ( p in players_on_layer( 5 ) )
            {
                if ( p.origin[ 1 ] > line_y ) hazard_damage( p, dmg );
            }
            wait 0.5;
        }
        // The tide recedes instantly - the floor is never persistent.
    }
}
