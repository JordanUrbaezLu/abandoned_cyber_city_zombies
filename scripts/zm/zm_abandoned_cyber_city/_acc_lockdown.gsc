// =============================================================================
// _acc_lockdown.gsc - per-round "DEFCON" room lockdown (MAGENTA "purge" alarm lighting; was red, user 2026-06-24)
//
// Design reference: docs/24_punishing_middle_design.md (lockdown concept) and
// the per-round rotation contract shared with _acc_decontamination.gsc.
//
// ONE of four rooms - Vault, Alley, Helipad (roof_zone), Market - lights up RED as the DEFCON
// room. It STAYS lit until the player DEFEATS the challenge inside it (NOT a per-round rotation,
// user 2026-06-18); on defeat the alarm turns OFF and the NEXT DEFCON lights ~acc_lockdown_cooldown
// (4) rounds later, round-robin through a per-run shuffled order. First one at acc_lockdown_first_round
// (7). ON by default (acc_lockdown_on 1).
//
// STAGE 1 (this file, the LIGHT half): red glow FX scattered through the active room.
// STAGE 2 (later, scaffolded here): physically LOCKING the room's doors so you are stuck
// inside for the round - via hidden script_brushmodels "acc_seal_<zone>" authored in
// Radiant across each doorway (none exist yet, so lock_doors() is a harmless no-op until
// they do). Decided design (docs/24 §11): LOCK PLAYERS IN, no escape window.
//
// RENDER (the important bit): the red FX is driven CLIENT-side, NOT server-side. Stock/
// server `PlayFX` does NOT render in this build (the ORIGINAL version of this file used
// server PlayFXOnTag and the red light never showed - same wall the 2026-06-17 perk-glow
// attempt hit). The fix: spawn invisible script_model hosts at the room's anchor points and
// drive the proven client-side glow pipeline on them via acc_perk_lights::set_glow (the
// `accPerkGlow` clientfield + _acc_perk_lights.csc PlayFX). Index 11 = the MAGENTA glow clone
// (user 2026-06-24, was 1=red - now the "purge" lights match the Glitch Stalker's magenta glow).
// This is PURE GSC/CSC + the already-packed acc/light/fx_perk_glow_magenta.efx => LED-safe,
// linker-only build (no cod2map64/LED, no .map edit).
//
// Live knobs:
//   set acc_lockdown_on 0          disable the whole feature (takes effect next round)
//   set acc_lockdown_color 11      glow colour index (11 = magenta default; 1 red .. 12 dim-white; see _acc_perk_lights.csc)
//   set acc_lockdown_fx_z 140      emitter height above each spawner anchor
//   set acc_lockdown_emitters 6    max red emitters per room
//   set acc_lockdown_force_zone vault_zone   pin ONE room every round (test); "" = rotate
//   set acc_lockdown_lock_doors 0  red light WITHOUT sealing (no-op anyway until seals exist)
//   set acc_lockdown_debug 0       silence the on-screen "[lockdown] round N -> <zone>" text
//
// Public API:
//   init()  - roll the per-run room order + start the round watcher. Call ONCE from
//             acc_main::init() (after acc_perk_lights::init so the glow field is registered),
//             before watch_round_transitions fires the first acc_round_start.
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;

#define ACC_LOCKDOWN_GLOW_INDEX     11    // accPerkGlow colour index for the "purge" alarm: 11 = MAGENTA (user 2026-06-24, was 1=red - now matches the Glitch Stalker glow)
#define ACC_LOCKDOWN_MAX_EMITTERS   6     // red emitters per room (dvar-overridable)
#define ACC_LOCKDOWN_FX_Z           180   // height above each spawner anchor (dvar-overridable)
#define ACC_LOCKDOWN_FIRST_ROUND    7     // DEFCON stays OFF before this round (user 2026-06-18:
                                          // earlier is too early - no ammo / not prepared for the trap)
#define ACC_LOCKDOWN_COOLDOWN       4     // rounds AFTER a DEFCON is defeated before the next one lights
                                          // (user 2026-06-18: defeat one -> next available in 4 rounds)

#namespace acc_lockdown;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "lockdown: init" );

    level.acc_lockdown_emitters = [];
    level.acc_lockdown_active   = undefined;

    // Per-run shuffled order over the eligible rooms (same seeded-RNG plan as
    // decon's roll_decon_order, so a future seeded PRNG covers both).
    level.acc_lockdown_order = roll_order();
    for ( i = 0; i < level.acc_lockdown_order.size; i++ )
    {
        acc_utility::log( "lockdown order slot " + ( i + 1 ) + ": " +
                           level.acc_lockdown_order[ i ] );
    }

    // Stage 2: make the door-seal brushes inert (hidden + non-solid) until a
    // lockdown locks them - the .map authors them visible + solid. No-op today
    // (no acc_seal_* brushes exist yet).
    init_seals();

    // HARDCODE DISABLED with the Glitch Purge (user 2026-07-04): the DEFCON room-lighting rotation is
    // the purge's TELEGRAPH - with the purge off (_acc_lockdown_challenge hardcode-disabled) a red room
    // leads nowhere, so the lights are killed too (they're one feature - "those are tied together").
    // SAME gate/flag as the purge so both come back together: OFF in ALL versions until
    // `+set acc_lockdown_challenge_on 1`. We return BEFORE watch_rounds so no room ever lights red;
    // level.acc_lockdown_active stays undefined and the setup above (order/seals) is harmless.
    if ( getdvarint( "acc_lockdown_challenge_on", 0 ) != 1 )
    {
        acc_utility::log( "lockdown: room-light rotation HARDCODE DISABLED (with the Glitch Purge) - no room will light red" );
        return;
    }

    level thread watch_rounds();
}

// ---------------------------------------------------------------------------
// Eligible rooms + per-run order
// ---------------------------------------------------------------------------

// The FOUR rooms the lockdown rotates through (user 2026-06-18): Vault, Alley,
// Helipad (= roof_zone - the rooftop helipad), Market. Each has >=5 "<zone>_spawners"
// anchor structs (verified in the .map) used for the red emitter placement. NOT
// included: start_zone (spawns), corp_zone (the Bus Station hub - 4 doorways), lab_zone.
function get_lockdown_zones()
{
    zones = [];
    zones[ 0 ] = "vault_zone";
    zones[ 1 ] = "alley_zone";
    zones[ 2 ] = "roof_zone";    // Helipad
    zones[ 3 ] = "market_zone";
    return zones;
}

// Fisher-Yates via the project RNG wrapper (mirrors decon's roll_decon_order).
function roll_order()
{
    zones = get_lockdown_zones();

    for ( i = zones.size - 1; i > 0; i-- )
    {
        j = acc_utility::acc_rand_int( i + 1 );
        tmp = zones[ i ];
        zones[ i ] = zones[ j ];
        zones[ j ] = tmp;
    }

    return zones;
}

// ---------------------------------------------------------------------------
// Round watcher
// ---------------------------------------------------------------------------

function watch_rounds()
{
    level endon( "end_game" );

    // acc_round_start is dispatched by _acc_main::watch_round_transitions after
    // stock "start_of_round" (and only after initial_blackscreen_passed for
    // round 1), so players are already in - no flag wait needed here.
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        // Threaded so a pathologically short round can never make the watcher
        // miss the next acc_round_start.
        level thread run_lockdown( round_number );
    }
}

function run_lockdown( round_number )
{
    level endon( "end_game" );

    // A lockdown CHALLENGE in progress (set by _acc_lockdown_challenge) OWNS the lit room: it
    // stays sealed + red ACROSS ROUNDS until cleared (docs/26 decision #1). So do NOT clear /
    // rotate / unseal here - bail and leave the current emitters + seal in place. Undefined in
    // normal play -> normal rotation. (Fixes the round-boundary unseal conflict the plan flags.)
    if ( isdefined( level.acc_ldc_active ) )
    {
        ld_debug( "challenge active in " + level.acc_ldc_active + " - lockdown rotation paused" );
        return;
    }

    // Master switch (live), ON by default. Set acc_lockdown_on 0 to clear any active
    // lockdown and idle.
    if ( getdvarint( "acc_lockdown_on", 1 ) != 1 )
    {
        lockdown_clear();
        return;
    }

    if ( !isdefined( round_number ) )
    {
        round_number = 1;
    }

    // A DEFCON room is already lit and waiting to be entered/defeated -> KEEP it lit (it stays until
    // you defeat it, user 2026-06-18). Don't rotate or clear it each round.
    if ( isdefined( level.acc_lockdown_active ) )
    {
        ld_debug( "DEFCON still lit in " + level.acc_lockdown_active + " - waiting to be defeated" );
        return;
    }

    // Nothing lit: light the NEXT DEFCON only once the cooldown round is reached. on_defcon_cleared
    // sets next = defeat_round + acc_lockdown_cooldown (default 4) after each defeat; the FIRST one is
    // gated at acc_lockdown_first_round. So a defeated DEFCON returns every ~4 rounds (and before the
    // first round / on cooldown, nothing is lit so players see no DEFCON available).
    if ( !isdefined( level.acc_lockdown_next_round ) )
        level.acc_lockdown_next_round = getdvarint( "acc_lockdown_first_round", ACC_LOCKDOWN_FIRST_ROUND );

    if ( round_number < level.acc_lockdown_next_round )
    {
        lockdown_clear();
        return;
    }

    zone = pick_zone();

    // Always clear the previous room first (also covers the no-eligible case).
    lockdown_clear();

    if ( !isdefined( zone ) )
    {
        acc_utility::log( "lockdown: no eligible room this round (" + round_number + ")" );
        return;
    }

    ld_debug( "round " + round_number + " -> DEFCON lights " + zone );
    lockdown_apply( zone );
}

// Called by _acc_lockdown_challenge when a DEFCON is DEFEATED (all glitch purged): turn the alarm OFF
// (so players see no available DEFCON) and gate the next one to defeat_round + acc_lockdown_cooldown.
function on_defcon_cleared( round_number )
{
    if ( !isdefined( round_number ) )
        round_number = ( isdefined( level.round_number ) ? level.round_number : 1 );

    cd = getdvarint( "acc_lockdown_cooldown", ACC_LOCKDOWN_COOLDOWN );
    level.acc_lockdown_next_round = round_number + cd;
    lockdown_clear();   // lights off
    ld_debug( "DEFCON cleared at round " + round_number + " - lights off, next DEFCON round " + level.acc_lockdown_next_round );
}

// Called on a FAILED challenge (party wiped / timed out): clear the lights and gate the next DEFCON to a SHORT
// fail cooldown (audit 2026-06-25). Was: left next_round untouched, so a DEFCON re-lit the VERY NEXT round with
// zero breather for the recovering party (clear/timeout both rest acc_lockdown_cooldown). Now a fail rests
// acc_lockdown_fail_cooldown (default 1) - it still returns sooner than a clear, but guarantees >= 1 DEFCON-free
// round. round_number is optional (back-compat): if omitted, falls back to the current round.
function on_defcon_failed( round_number )
{
    if ( !isdefined( round_number ) )
        round_number = ( isdefined( level.round_number ) ? level.round_number : 1 );

    fail_cd = getdvarint( "acc_lockdown_fail_cooldown", 1 );
    if ( fail_cd < 1 ) fail_cd = 1;
    level.acc_lockdown_next_round = round_number + fail_cd;
    lockdown_clear();
    ld_debug( "DEFCON failed at round " + round_number + " - lights off, next DEFCON round " + level.acc_lockdown_next_round );
}

// On-screen debug (acc_lockdown_debug 1) + the [acc] dev log, so the owner can watch the rotation pick
// a room each round. DEFAULT OFF for release (user 2026-06-25); set acc_lockdown_debug 1 to show it.
function ld_debug( msg )
{
    if ( getdvarint( "acc_lockdown_debug", 0 ) == 1 )   // acc_dev DECOUPLED 2026-07-10 (clean screen; [lockdown] rides acc_lockdown_debug now)
    {
        iprintlnbold( "[lockdown] " + msg );
    }
    acc_utility::log( "lockdown: " + msg );
}

// Round-robin through the per-run order for each NEW DEFCON (a counter, not the round, since DEFCONs
// are now sparse); skip any room decon has permanently sealed. undefined only if the order is empty.
function pick_zone()
{
    // TEST/DEBUG pin: acc_lockdown_force_zone <zone> locks the lockdown to ONE room (e.g. "vault_zone"),
    // bypassing rotation. Empty (default) = normal round-robin.
    forced = getdvarstring( "acc_lockdown_force_zone" );
    if ( isdefined( forced ) && forced != "" )
    {
        return forced;
    }

    order = level.acc_lockdown_order;
    n = order.size;
    if ( n == 0 )
    {
        return undefined;
    }

    if ( !isdefined( level.acc_lockdown_count ) )
        level.acc_lockdown_count = 0;

    for ( step = 0; step < n; step++ )
    {
        cand = order[ ( level.acc_lockdown_count + step ) % n ];
        if ( !acc_decontamination::is_zone_sealed( cand ) )
        {
            level.acc_lockdown_count++;   // advance the round-robin for the NEXT DEFCON
            return cand;
        }
    }

    return undefined;
}

// ---------------------------------------------------------------------------
// Apply / clear the red alarm glow in a room (CLIENT-side FX via _acc_perk_lights)
// ---------------------------------------------------------------------------

function lockdown_apply( zone )
{
    level.acc_lockdown_active = zone;

    spawn_room_emitters( zone );

    // Stage 2: seal the room's doors (no-op for rooms with no acc_seal_* brushes).
    lock_doors( zone );

    // Tell the challenge layer (_acc_lockdown_challenge) a room just lit, so it can arm the
    // TRAP on this zone. A notify with no listener is a harmless no-op (module absent/disabled).
    level notify( "acc_lockdown_room_lit", zone );
}

// Spawn an invisible script_model host at each of the room's anchor points and drive the
// red glow on it via the proven client-side pipeline (acc_perk_lights::set_glow ->
// accPerkGlow clientfield -> _acc_perk_lights.csc PlayFX). Several emitters per room give
// the "red room" coverage. Steady (the glow .efx loops); no server pulse loop needed.
function spawn_room_emitters( zone )
{
    color   = getdvarint( "acc_lockdown_color", ACC_LOCKDOWN_GLOW_INDEX );
    origins = room_emitter_origins( zone );

    ld_debug( zone + ": " + origins.size + " red emitter(s) @ z" +
              getdvarint( "acc_lockdown_fx_z", ACC_LOCKDOWN_FX_Z ) + " color=" + color );

    for ( i = 0; i < origins.size; i++ )
    {
        // Invisible FX host: a script_model SetModel'd to "tag_origin" (has the tag the
        // client PlayFXOnTag attaches to). The clientfield drives the render.
        e = spawn( "script_model", origins[ i ] );
        e SetModel( "tag_origin" );
        acc_perk_lights::set_glow( e, color );
        level.acc_lockdown_emitters[ level.acc_lockdown_emitters.size ] = e;
    }
}

function clear_emitters()
{
    if ( isdefined( level.acc_lockdown_emitters ) )
    {
        for ( i = 0; i < level.acc_lockdown_emitters.size; i++ )
        {
            e = level.acc_lockdown_emitters[ i ];
            if ( isdefined( e ) )
            {
                acc_perk_lights::set_glow( e, 0 );   // client StopFX
                e Delete();                           // remove the host
            }
        }
    }
    level.acc_lockdown_emitters = [];
}

function lockdown_clear()
{
    // Stage 2: unlock the previously-sealed room's doors first (safe if undefined).
    unlock_doors( level.acc_lockdown_active );

    clear_emitters();

    level.acc_lockdown_active = undefined;
}

// ---------------------------------------------------------------------------
// Stage 2: door locking via hidden script_brushmodel seal brushes.
//
// Radiant/.map contract: script_brushmodels named "acc_seal_<zone>" placed across each of
// the room's doorways (authored visible + solid). init_seals() makes them inert at startup;
// lock/unlock toggle them - the proven _acc_map_randomizer::apply_pap_approach pattern.
// NONE exist yet, so all of this is a no-op until the seal brushes are authored.
//
// Decided design (docs/24 §11): LOCK PLAYERS IN, no escape window.
// ---------------------------------------------------------------------------

// Make every seal brush hidden + non-solid + nav-connected (inert) at startup.
function init_seals()
{
    zones = get_lockdown_zones();
    for ( z = 0; z < zones.size; z++ )
    {
        unlock_doors( zones[ z ] );
    }
}

// acc_lockdown_lock_doors (default 1): set 0 to test the red light WITHOUT sealing.
function lock_doors( zone )
{
    if ( getdvarint( "acc_lockdown_lock_doors", 1 ) != 1 )
    {
        return;
    }

    blockers = getentarray( "acc_seal_" + zone, "targetname" );
    for ( i = 0; i < blockers.size; i++ )
    {
        blockers[ i ] show();
        blockers[ i ] solid();
        blockers[ i ] disconnectpaths();
    }

    if ( blockers.size > 0 )
    {
        acc_utility::log( "lockdown: sealed " + blockers.size + " doorway(s) for " + zone );
    }
}

function unlock_doors( zone )
{
    if ( !isdefined( zone ) )
    {
        return;
    }

    blockers = getentarray( "acc_seal_" + zone, "targetname" );
    for ( i = 0; i < blockers.size; i++ )
    {
        blockers[ i ] hide();
        blockers[ i ] notsolid();
        blockers[ i ] connectpaths();
    }
}

// Emitter anchor points inside a room. Data-driven + auto-tracks geometry: we use the
// room's own zombie-spawner structs (targetname "<zone>_spawners" - verified in the .map),
// hand-placed points inside each room. Room CENTER first (centroid) so the glow fills the
// middle, then perimeter points up to the cap. Raised by acc_lockdown_fx_z.
function room_emitter_origins( zone )
{
    origins = [];

    max_n = getdvarint( "acc_lockdown_emitters", ACC_LOCKDOWN_MAX_EMITTERS );
    z_off = getdvarint( "acc_lockdown_fx_z", ACC_LOCKDOWN_FX_Z );

    structs = struct::get_array( zone + "_spawners", "targetname" );

    sum_x = 0;
    sum_y = 0;
    n = 0;
    for ( i = 0; i < structs.size; i++ )
    {
        if ( !isdefined( structs[ i ].origin ) )
        {
            continue;
        }
        sum_x += structs[ i ].origin[ 0 ];
        sum_y += structs[ i ].origin[ 1 ];
        n++;
    }
    if ( n > 0 )
    {
        origins[ origins.size ] = ( sum_x / n, sum_y / n, z_off );
    }

    for ( i = 0; i < structs.size; i++ )
    {
        if ( origins.size >= max_n )
        {
            break;
        }
        if ( !isdefined( structs[ i ].origin ) )
        {
            continue;
        }
        origins[ origins.size ] = structs[ i ].origin + ( 0, 0, z_off );
    }

    return origins;
}

// Public: the room's CENTRE at floor height (centroid of its <zone>_spawners anchors). Reused
// by _acc_lockdown_challenge for the trap centre + the reward drop origin (floor z, unlike
// room_emitter_origins which raises the FX by acc_lockdown_fx_z). Returns (0,0,0) if no anchors.
function room_center_origin( zone )
{
    structs = struct::get_array( zone + "_spawners", "targetname" );

    sum_x = 0;
    sum_y = 0;
    sum_z = 0;
    n = 0;
    for ( i = 0; i < structs.size; i++ )
    {
        if ( !isdefined( structs[ i ].origin ) )
        {
            continue;
        }
        sum_x += structs[ i ].origin[ 0 ];
        sum_y += structs[ i ].origin[ 1 ];
        sum_z += structs[ i ].origin[ 2 ];
        n++;
    }

    if ( n == 0 ) return ( 0, 0, 0 );
    return ( sum_x / n, sum_y / n, sum_z / n );
}
