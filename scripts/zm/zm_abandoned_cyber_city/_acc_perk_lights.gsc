// =============================================================================
// _acc_perk_lights.gsc - perk machine + Pack-a-Punch GLOW when power turns on
// (server half). Like base zombies: dark until you flip the Bus Station switch,
// then each machine lights with a coloured glow.
//
// WHY THIS SHAPE (root-caused, multi-agent design + adversarial verify 2026-06-18):
// the 2026-06-17 attempt failed because it played FX SERVER-SIDE (PlayFXOnTag in a
// .gsc, like _acc_lockdown) - and server-side PlayFX does NOT render in this build
// (stock perk_fx is server-side too, which is exactly why the machines are dark).
// The path that DOES render here is the CLIENT VM: stock power-ups glow via a
// scriptmover clientfield + client-side PlayFXOnTag (_zm_powerups.csc), and
// power-ups render fine. So we copy that: the SERVER (this file) only sets a
// per-machine "accPerkGlow" colour-index clientfield on the power_on flag; the
// CLIENT (_acc_perk_lights.csc) actually PlayFX's the glow. No FX is ever played
// from .gsc. See memory power-on-lights-perks-mechanism + docs/29.
//
// LED-SAFE: this is pure .gsc/.csc/.zone/.fx - it NEVER touches map_source/*.map,
// so it ships with `build_map.ps1 -GscOnly` (no cod2map64/LED) and cannot regress
// the Radiant bake. (The user's hard constraint: don't break the just-fixed LED.)
//
// Power gate copies _acc_atmosphere::apply_fog's proven poll: wait for the
// blackscreen flag, then poll the global "power_on" flag (set by the corp/Bus
// Station switch via zm_power::turn_power_on_and_open_doors). OFF before the
// switch, lit after. `set acc_perk_lights_on 0` disables the whole feature.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_perk_lights;

// REGISTER_SYSTEM autoexec registers the clientfield at the correct pre-load phase,
// IN LOCKSTEP with the .csc mirror (scope/name/version/bits/type MUST match or the
// bit layout desyncs). Server registers + sets; client registers + plays the FX.
REGISTER_SYSTEM( "acc_perk_lights", &__init__, undefined )

function __init__()
{
    // scriptmover scope = the same pool stock power-ups use for their glow clientfield
    // (clientfield_shared.gsc), and script_models (the perk machine + our PaP host) are
    // scriptmover-scope ents. 4 bits = colour indices 0..15 (we use 0=off, 1..10).
    clientfield::register( "scriptmover", "accPerkGlow", VERSION_SHIP, 4, "int" );
}

// Threaded from acc_main::init() (gameplay time - NOT from the REGISTER_SYSTEM
// __init__, which would risk the flag-wait-from-init crash). Gated by acc_perk_lights_on.
function init()
{
    if ( getdvarint( "acc_perk_lights_on", 1 ) == 0 ) return;
    level thread power_glow_watch();
}

function power_glow_watch()
{
    level endon( "end_game" );

    // Same gate as the fog: players must be in before clientfields network. The
    // "power_on" flag is set by the Bus Station (corp) switch handler.
    level flag::wait_till( "initial_blackscreen_passed" );

    while ( !( level flag::exists( "power_on" ) && level flag::get( "power_on" ) ) )
        wait( 0.25 );

    glow_all_machines();
}

// Set the per-perk colour index on every perk machine + a PaP host. One-shot (the
// clientfield value LATCHES, so late-joining clients still get the glow via the
// client callback's initial-snapshot fire). Idempotent guard so it never double-runs.
function glow_all_machines()
{
    if ( isdefined( level.acc_perk_glow_done ) && level.acc_perk_glow_done ) return;
    level.acc_perk_glow_done = true;

    // All 9 perk machines (6 stock struct prefabs + 3 inline structs) carry targetname
    // "zm_perk_machine"; stock perk_machine_spawn_init gives each a "zombie_vending"
    // trigger whose .machine is the renderable script_model (has tag_origin). By power-on
    // time these have long existed. VERIFIED(acc): GetEntArray("zombie_vending",...) +
    // trigger.machine is the stock-blessed machine handle (perk_machine_spawn_init).
    triggers = GetEntArray( "zombie_vending", "targetname" );
    dbg( "power on -> glowing. zombie_vending triggers = " + triggers.size );

    glowed = 0;
    foreach ( t in triggers )
    {
        if ( !isdefined( t.machine ) )
        {
            dbg( "  SKIP (no .machine) sn=" + safe_sn( t ) );
            continue;
        }

        idx = perk_color_index( t.script_noteworthy );
        dbg( "  machine sn=" + safe_sn( t ) + " -> glow " + idx );
        t.machine clientfield::set( "accPerkGlow", idx );
        glowed++;
    }

    // Pack-a-Punch: the "pack_a_punch" script_noteworthy ent is the USE TRIGGER, not a
    // renderable model (and a zbarrier is not scriptmover scope), so spawn our own
    // invisible script_model host at its origin and glow THAT - the same invisible
    // "tag_origin" host idiom _acc_lockdown.gsc uses. (BLOCKING fix from the design verify.)
    pap = GetEntArray( "pack_a_punch", "script_noteworthy" );
    pap_n = 0;
    if ( isdefined( pap ) ) pap_n = pap.size;
    dbg( "pack_a_punch ents = " + pap_n + " (machines glowed = " + glowed + ")" );

    if ( pap_n > 0 && isdefined( pap[ 0 ] ) )
    {
        pap_ent = pap[ 0 ];
        // PaP glow sits LOWER than the perk glows (user 2026-06-18): the shared FX is lifted up
        // the body for the tall perk cabinets, so the PaP host drops it back down. Live-tunable
        // via `acc_pap_glow_z` (units relative to the PaP origin; negative = lower).
        pap_z = getdvarint( "acc_pap_glow_z", -50 );
        pap_org = pap_ent.origin + ( 0, 0, pap_z );
        host = spawn( "script_model", pap_org );
        host setmodel( "tag_origin" );          // invisible FX host (has tag_origin)
        level.acc_pap_glow_host = host;          // keep a ref so it is not GC'd
        host clientfield::set( "accPerkGlow", 10 );
        dbg( "PaP host spawned at " + pap_org + " (z" + pap_z + ") -> glow 10" );
    }
    else
    {
        dbg( "PaP NOT FOUND via pack_a_punch noteworthy - no PaP glow" );
    }
}

function safe_sn( t )
{
    if ( isdefined( t.script_noteworthy ) ) return t.script_noteworthy;
    return "<none>";
}

// Diagnostic: always to console_mp.log; on-screen only when acc_perk_lights_debug 1 (default
// OFF now that the colours are locked - flip it on to re-read the live specialty -> index map
// + PaP detection without a rebuild).
function dbg( msg )
{
    acc_utility::log( "perk_lights: " + msg );
    if ( getdvarint( "acc_perk_lights_debug", 0 ) == 0 ) return;
    players = GetPlayers();
    foreach ( p in players )
        p IPrintLnBold( "[perklight] " + msg );
}

// specialty string -> colour index (the .csc maps each index to an FX). VERIFIED(acc)
// keys: Double Tap = specialty_doubletap2, Stamin-Up = specialty_staminup (NOT
// specialty_rof / specialty_longersprint - CLAUDE.md hard-won fact). Unknown -> 10.
function perk_color_index( specialty )
{
    if ( !isdefined( specialty ) ) return 10;
    switch ( specialty )
    {
        case "specialty_armorvest":               return 1;   // Jugg          - red
        case "specialty_fastreload":              return 2;   // Speed Cola    - green
        case "specialty_doubletap2":              return 3;   // Double Tap    - yellow
        case "specialty_staminup":                return 4;   // Stamin-Up     - orange
        case "specialty_additionalprimaryweapon": return 5;   // Mule Kick     - amber
        case "specialty_quickrevive":             return 6;   // Quick Revive  - blue
        case "specialty_deadshot":                return 7;   // Deadshot      - blacklight/UV
        case "specialty_widowswine":              return 8;   // Widow's Wine  - white
        case "specialty_electriccherry":          return 9;   // PhD Flopper   - purple
        default:                                  return 10;  // generic / PaP - teal
    }
}

// Public: drive the coloured-glow FX on ANY scriptmover ent (the per-round red room alarm
// in _acc_lockdown reuses this exact client-side pipeline, not just perk machines). The
// client _acc_perk_lights.csc renders it. color_index 0 = off; 1..10 = the colours in
// perk_color_index / the .csc level._effect map (1 red, 2 green, ... 7 blacklight, 8 white,
// 9 purple, 10 teal). Centralises
// the "accPerkGlow" field name so callers do not hardcode it.
function set_glow( ent, color_index )
{
    if ( !isdefined( ent ) ) return;
    ent clientfield::set( "accPerkGlow", color_index );
}
