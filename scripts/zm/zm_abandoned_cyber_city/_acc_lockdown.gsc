// =============================================================================
// _acc_lockdown.gsc - per-round "DEFCON" room lockdown (red alarm lighting)
//
// Design reference: docs/37_punishing_middle_design.md (lockdown concept) and
// the per-round rotation contract shared with _acc_decontamination.gsc.
//
// STAGE 1 (this file): the RED-ALARM-LIGHT half only. Each round one eligible
// room is put under a red flashing "security alert" - a handful of flashing-red
// light FX emitters spawned inside the room - and the previous round's room is
// cleared. Which room is lit rotates every round off a per-run shuffled order.
// This stage is PURE GSC + a stock FX => a linker-only build (no cod2map64/LED).
//
// STAGE 2 (later, NOT here): physically LOCKING the room's doors. That needs new
// hidden script_brushmodels ("acc_seal_<zone>") authored in Radiant across each
// doorway (full geometry rebuild) + the show/solid/disconnectpaths toggle (the
// _acc_map_randomizer::apply_pap_approach pattern). Decided design for stage 2:
// LOCK PLAYERS IN (no escape window) - the lockdown is meant to be punishing.
// See docs/37. Until those brushes exist, the lock half is intentionally absent.
//
// VERIFIED(acc): the FX are stock .efx that ship as source in the Mod Tools
// (<tools>\share\raw\fx\light\...): "light/fx_light_flashing_red_factory_zmb" is
// the ZM "Giant"/factory flashing-red alarm light (self-flashing - no script
// pulse loop needed); "light/fx_glow_blink_red_5" is a softer blinking-red glow
// alternative. Both are #precached + listed in the .zone, so the linker compiles
// them into our fastfile (same pipeline as _acc_perk_phd_flopper's dlc4 FX).
//
// VERIFIED(acc): PlayFXOnTag( <fx>, <ent>, "tag_origin" ) is the server-side
// looped-FX-on-an-entity builtin (stock ball.gsc:885, escort.gsc:1654); the host
// is a script_model SetModel'd to the invisible "tag_origin" model (stock idiom -
// exploder_shared.gsc:395, _zm_ai_raps.gsc:639). Deleting the host stops the
// looped FX (there is no server StopFX - that is .csc-only).
//
// OFF by default (acc_lockdown_on = 0), same stance as the fog/ambient knobs in
// _acc_atmosphere.gsc - the owner enables + eyeballs the look in-game:
//   set acc_lockdown_on 1        master switch (takes effect on the NEXT round)
//   set acc_lockdown_use_glow 1  swap the flashing light for the blinking glow
//   set acc_lockdown_fx_z 140    emitter height above the spawner anchor
//   set acc_lockdown_emitters 4  max emitters per room
// When a look is locked, bake the chosen dvar values into the #defines + docs/37.
//
// Public API:
//   init()  - roll the per-run room order + start the round watcher. Call ONCE
//             from acc_main::init(), before watch_round_transitions fires the
//             first acc_round_start (placed next to acc_decontamination::init()).
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;

// Stock ZM factory flashing-red alarm light (self-flashing). Primary look.
#define ACC_LOCKDOWN_FX_FLASH       "light/fx_light_flashing_red_factory_zmb"
// Softer blinking-red glow - the A/B alternative (set acc_lockdown_use_glow 1).
#define ACC_LOCKDOWN_FX_GLOW        "light/fx_glow_blink_red_5"

#define ACC_LOCKDOWN_MAX_EMITTERS   6     // emitters per room (dvar-overridable)
#define ACC_LOCKDOWN_FX_Z           180   // height above each spawner anchor (dvar-overridable)

#precache( "fx", ACC_LOCKDOWN_FX_FLASH );
#precache( "fx", ACC_LOCKDOWN_FX_GLOW );

#namespace acc_lockdown;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "lockdown: init" );

    // Register both FX handles (the #precaches above made them loadable).
    level._effect[ "acc_lockdown_flash" ] = ACC_LOCKDOWN_FX_FLASH;
    level._effect[ "acc_lockdown_glow" ]  = ACC_LOCKDOWN_FX_GLOW;

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
    // lockdown locks them - the .map authors them visible + solid.
    init_seals();

    level thread watch_rounds();
}

// ---------------------------------------------------------------------------
// Eligible rooms + per-run order
// ---------------------------------------------------------------------------

// Red light is purely cosmetic in stage 1, so every room except the spawn
// is eligible (start_zone stays calm). When the door-lock half lands (stage 2)
// this set may narrow for traversal reasons (corp_zone has 4 doorways; locking
// start strands spawns) - revisit get_lockdown_zones then. docs/37.
function get_lockdown_zones()
{
    zones = [];
    zones[ 0 ] = "market_zone";
    zones[ 1 ] = "alley_zone";
    zones[ 2 ] = "corp_zone";
    zones[ 3 ] = "vault_zone";
    zones[ 4 ] = "roof_zone";
    zones[ 5 ] = "lab_zone";
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

    // Master switch (live). OFF (default) => clear any active lockdown and idle,
    // so the owner flips `acc_lockdown_on 1` to start it (takes effect this/next
    // round start).
    if ( getdvarint( "acc_lockdown_on", 0 ) != 1 )
    {
        lockdown_clear();
        return;
    }

    if ( !isdefined( round_number ) )
    {
        round_number = 1;
    }

    zone = pick_zone( round_number );

    // Always clear the previous room first (also covers the no-eligible case).
    lockdown_clear();

    if ( !isdefined( zone ) )
    {
        acc_utility::log( "lockdown: no eligible room this round (" + round_number + ")" );
        return;
    }

    ld_debug( "round " + round_number + " -> " + zone );
    lockdown_apply( zone );
}

// Loud, on-screen debug (acc_lockdown_debug 1, ON by default during bring-up) plus
// the normal [acc] dev log. Set acc_lockdown_debug 0 to silence the center text.
function ld_debug( msg )
{
    if ( getdvarint( "acc_lockdown_debug", 1 ) == 1 )
    {
        iprintlnbold( "[lockdown] " + msg );
    }
    acc_utility::log( "lockdown: " + msg );
}

// Round-robin through the per-run order; skip any room decon has permanently
// sealed (a sealed room is already a dead kill-volume). corp/lab are never decon
// targets, so there is always at least one eligible room - undefined only if the
// order is somehow empty.
function pick_zone( round_number )
{
    // TEST/DEBUG pin: acc_lockdown_force_zone <zone> locks the lockdown to ONE
    // room every round (e.g. "vault_zone"), bypassing the rotation entirely.
    // Empty (default) = normal per-round rotation. Set it in the launcher to test
    // a single room; clear it to resume rotation (no code change needed).
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

    for ( step = 0; step < n; step++ )
    {
        cand = order[ ( ( round_number - 1 ) + step ) % n ];
        if ( !acc_decontamination::is_zone_sealed( cand ) )
        {
            return cand;
        }
    }

    return undefined;
}

// ---------------------------------------------------------------------------
// Apply / clear the red alarm FX in a room
// ---------------------------------------------------------------------------

function lockdown_apply( zone )
{
    level.acc_lockdown_active = zone;

    // Red alarm FX inside the room (threaded pulse so it visibly blinks and works
    // whether the .efx is a one-shot flash or a loop).
    level thread fx_pulse_loop( zone );

    // Stage 2: seal the room's doors (no-op for rooms with no acc_seal_* brushes).
    lock_doors( zone );
}

// Repeatedly (re)spawn the red FX emitters so the room pulses red. Re-spawning each
// cycle makes a one-shot flash FX repeat, and Delete()-ing prevents a looping FX from
// stacking. Ends on acc_lockdown_stop (lockdown cleared) or end_game.
function fx_pulse_loop( zone )
{
    level endon( "end_game" );
    level endon( "acc_lockdown_stop" );

    fx_key  = lockdown_fx_key();
    origins = room_emitter_origins( zone );

    ld_debug( zone + ": " + origins.size + " red emitter(s) @ z" +
              getdvarint( "acc_lockdown_fx_z", ACC_LOCKDOWN_FX_Z ) + " fx=" + level._effect[ fx_key ] );

    if ( origins.size == 0 )
    {
        return;
    }

    on_sec  = getdvarfloat( "acc_lockdown_pulse_on",  0.6 );
    off_sec = getdvarfloat( "acc_lockdown_pulse_off", 0.4 );

    for ( ;; )
    {
        for ( i = 0; i < origins.size; i++ )
        {
            // Invisible FX host: a script_model SetModel'd to "tag_origin" carries
            // the tag the FX attaches to; Delete()-ing it stops/clears the FX.
            e = spawn( "script_model", origins[ i ] );
            e SetModel( "tag_origin" );
            PlayFXOnTag( level._effect[ fx_key ], e, "tag_origin" );
            level.acc_lockdown_emitters[ level.acc_lockdown_emitters.size ] = e;
        }

        wait( on_sec );
        clear_emitters();
        wait( off_sec );
    }
}

function clear_emitters()
{
    if ( isdefined( level.acc_lockdown_emitters ) )
    {
        for ( i = 0; i < level.acc_lockdown_emitters.size; i++ )
        {
            if ( isdefined( level.acc_lockdown_emitters[ i ] ) )
            {
                level.acc_lockdown_emitters[ i ] Delete();
            }
        }
    }
    level.acc_lockdown_emitters = [];
}

function lockdown_clear()
{
    // Stage 2: unlock the previously-sealed room's doors first (safe if undefined).
    unlock_doors( level.acc_lockdown_active );

    // Stop the pulse loop and remove any live emitters.
    level notify( "acc_lockdown_stop" );
    clear_emitters();

    level.acc_lockdown_active = undefined;
}

// ---------------------------------------------------------------------------
// Stage 2: door locking via hidden script_brushmodel seal brushes.
//
// Radiant/.map contract: script_brushmodels named "acc_seal_<zone>" placed across
// each of the room's doorways (authored visible + solid; tools/add_lockdown_seals.js
// appends the vault's two). init_seals() makes them inert at startup; lock/unlock
// toggle them - the proven _acc_map_randomizer::apply_pap_approach pattern.
//
// Decided design (docs/37 §11): LOCK PLAYERS IN, no escape window. The seal blocks
// both directions, so a player inside survives the round trapped.
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

// acc_lockdown_lock_doors (default 1): set 0 to test the red light WITHOUT sealing
// (e.g. to walk into the room first), then 1 to seal on the next round.
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

// acc_lockdown_use_glow 1 = the softer blinking glow; default = the flashing
// alarm light. Both are precached, so this just selects the registered handle
// (the change takes effect on the next round's apply).
function lockdown_fx_key()
{
    if ( getdvarint( "acc_lockdown_use_glow", 0 ) == 1 )
    {
        return "acc_lockdown_glow";
    }
    return "acc_lockdown_flash";
}

// Emitter anchor points inside a room. Data-driven + auto-tracks the
// map-tightening overhaul: we use the room's own zombie-spawner structs
// (targetname "<zone>_spawners" - verified in the .map), which are hand-placed
// points inside each room that move with the geometry. No hardcoded coordinates
// to drift from source_data/rooms.json. Raised by acc_lockdown_fx_z so the FX
// reads as a wall/ceiling alarm light, not a floor glow.
function room_emitter_origins( zone )
{
    origins = [];

    max_n = getdvarint( "acc_lockdown_emitters", ACC_LOCKDOWN_MAX_EMITTERS );
    z_off = getdvarint( "acc_lockdown_fx_z", ACC_LOCKDOWN_FX_Z );

    structs = struct::get_array( zone + "_spawners", "targetname" );

    // Room CENTER first (centroid of the spawner points) so the red glow fills the
    // middle of the room, not just the perimeter.
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

    // Then the perimeter spawner points (up to the cap).
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
