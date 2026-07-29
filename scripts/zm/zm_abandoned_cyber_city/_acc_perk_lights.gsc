// =============================================================================
// _acc_perk_lights.gsc - perk machine + Pack-a-Punch GLOW when power turns on
// (server half). MACHINE AURAS ARE THE GLOW (re-affirmed 2026-07-25): the
// 2026-07-24 "native" attempt (rely on stock's off_model->on_model swap and
// retire the auras) was REFUTED LIVE - the model swap shows no visible power
// delta in this build ("native glow doesnt work"), so the colour auras are back
// as the one power visual. STRICTLY power-gated: the fields are only ever set
// after the "power_on" flag (power_glow_watch below); pre-power every machine's
// field is 0 = no aura. Also owns the shared set_glow pipeline other systems
// ride (purge 11 / shard banks 12 / loot 13 / abyss lamps 14-15).
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
// from .gsc. See memory power-on-lights-perks-mechanism + docs/20.
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
    level thread glow_rekick_watch();
}

// MACHINE AURAS RESTORED 2026-07-25 (user: "native glow doesnt work so we can go
// back to the fx glows"): the 2026-07-24 native attempt (rely on stock's
// off_model -> on_model swap) was REFUTED LIVE - the swap produces no visible
// power delta in this build, so the per-machine colour auras below are THE
// power-on glow again. Set ONLY here, after the "power_on" flag (power_glow_watch)
// - machines can never aura before the switch is flipped; the scatter re-pulses a
// moved machine's field post-move, and glow_rekick_watch re-pulses band machines
// when players first descend (a latched CF set far from the viewer never renders
// on approach). One-shot (the clientfield value LATCHES, so late-joining clients
// still get the glow via the client callback's initial-snapshot fire). Idempotent.
function glow_all_machines()
{
    if ( isdefined( level.acc_perk_glow_done ) && level.acc_perk_glow_done ) return;
    level.acc_perk_glow_done = true;

    // All perk machines carry the stock "zombie_vending" trigger whose .machine is the
    // renderable script_model (has tag_origin). By power-on time these have long existed.
    // VERIFIED(acc): trigger.machine is the stock-blessed machine handle (perk_machine_spawn_init).
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
    dbg( "machines glowed = " + glowed );

    // Pack-a-Punch: the "pack_a_punch" script_noteworthy ent is the USE TRIGGER, not a
    // renderable model (and a zbarrier is not scriptmover scope), so spawn our own
    // invisible script_model host at its origin and glow THAT - the same invisible
    // "tag_origin" host idiom _acc_lockdown.gsc uses. (BLOCKING fix from the design verify.)
    pap = GetEntArray( "pack_a_punch", "script_noteworthy" );
    pap_n = 0;
    if ( isdefined( pap ) ) pap_n = pap.size;
    dbg( "pack_a_punch ents = " + pap_n );

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

    // PARADISE PaP glow (user 2026-07-09: "the pap in paradise doesn't glow like the lab one"): the
    // arena's 2nd PaP is our CUSTOM script_model vendor (_acc_pap_levels::spawn_paradise_pap_at,
    // registered on level.acc_custom_pap_machines) - it carries no "pack_a_punch" noteworthy, so the
    // scan above only ever found the SURFACE machine. Give each custom vendor its own invisible glow
    // host (the same tag_origin idiom). Own z dvar: the custom model's origin is the FLOOR (unlike the
    // elevated surface trigger the -50 offset above corrects for).
    level.acc_custom_pap_glow_hosts = [];
    if ( isdefined( level.acc_custom_pap_machines ) )
    {
        foreach ( t in level.acc_custom_pap_machines )
        {
            if ( !isdefined( t ) || !isdefined( t.acc_pap_model ) ) continue;
            org = t.acc_pap_model.origin + ( 0, 0, getdvarint( "acc_paradise_pap_glow_z", -20 ) );
            host = spawn( "script_model", org );
            host setmodel( "tag_origin" );
            host clientfield::set( "accPerkGlow", 10 );
            ARRAY_ADD( level.acc_custom_pap_glow_hosts, host );
            dbg( "custom PaP glow host spawned at " + org + " -> glow 10" );
        }
    }
}

// GLOW RE-KICK (2026-07-09 Paradise lesson, generalized 2026-07-25 for the perk
// scatter): the power-on pass sets every machine's field ONCE - and the client plays
// the looping glow FX the moment the value arrives, which for machines far below the
// team (the Paradise row at z=-1200; scattered machines in the under-rooms/Exchange/L2
// at z=-160..-480) is while every player is far ABOVE them; an FX spawned that far out
// never becomes visible when you finally arrive. Fix: edge-triggered re-pulses per
// band - each time the team first transitions into the UNDERGROUND band (anyone below
// z<-100) pulse the z[-600,-100] machines, and into the DEEP band (anyone below
// z<-1000) pulse the z<-600 ents (Paradise row + custom PaP hosts). Once per descent,
// not per tick; a brief 0.25s off-blink on ents whose glow WAS rendering is the worst case.
function glow_rekick_watch()
{
    level endon( "end_game" );

    was_deep = false;
    was_under = false;
    for ( ;; )
    {
        wait 1;
        deep = false;
        under = false;
        foreach ( p in GetPlayers() )
        {
            if ( !isdefined( p ) || !isplayer( p ) || !isalive( p ) ) continue;
            if ( p.origin[ 2 ] < -1000 ) deep = true;
            if ( p.origin[ 2 ] < -100 )  under = true;
        }
        if ( deep && !was_deep )
            pulse_band_glows( -999999, -600 );
        if ( under && !was_under )
            pulse_band_glows( -600, -100 );
        was_deep = deep;
        was_under = under;
    }
}

// Re-pulse the glow ents whose origin z falls in (zmin, zmax]: 0 now, the real index a
// beat later. The two values must land in DIFFERENT snapshots or they coalesce into
// no-change (no client callback), hence the threaded re-set with a real wait.
function pulse_band_glows( zmin, zmax )
{
    n = 0;
    triggers = GetEntArray( "zombie_vending", "targetname" );
    foreach ( t in triggers )
    {
        if ( !isdefined( t.machine ) ) continue;
        z = t.machine.origin[ 2 ];
        if ( z <= zmin || z > zmax ) continue;
        idx = perk_color_index( t.script_noteworthy );
        t.machine clientfield::set( "accPerkGlow", 0 );
        t.machine thread reglow( idx );
        n++;
    }
    if ( isdefined( level.acc_custom_pap_glow_hosts ) )
    {
        foreach ( host in level.acc_custom_pap_glow_hosts )
        {
            if ( !isdefined( host ) ) continue;
            z = host.origin[ 2 ];
            if ( z <= zmin || z > zmax ) continue;
            host clientfield::set( "accPerkGlow", 0 );
            host thread reglow( 10 );
            n++;
        }
    }
    dbg( "glow pulse band (" + zmin + "," + zmax + "]: rekicked " + n + " glow ents" );
}

function reglow( idx )   // self = the machine model / glow host
{
    level endon( "end_game" );
    wait 0.25;   // > one snapshot, so the 0 actually transmits before the re-set
    if ( isdefined( self ) )
        self clientfield::set( "accPerkGlow", idx );
}

function safe_sn( t )
{
    if ( isdefined( t.script_noteworthy ) ) return t.script_noteworthy;
    return "<none>";
}

// Diagnostic: always to console_mp.log; on-screen only in a dev build (rides level.acc_dev - the
// acc_perk_lights_debug dvar was removed 2026-07-16). Build dev to re-read the live
// specialty -> index map + PaP detection.
function dbg( msg )
{
    acc_utility::log( "perk_lights: " + msg );
    if ( !IS_TRUE( level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
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
        case "specialty_combat_efficiency":       return 10;  // Electric Cherry - teal (INTENTIONAL: no spare perk-colour glow FX, and teal/cyan reads as "electric" + matches EC's teal Mega icon; explicit so it's not a silent fall-through. user 2026-06-26)
        default:                                  return 10;  // generic / PaP - teal
    }
}

// Public: drive the coloured-glow FX on ANY scriptmover ent (the per-round lockdown "purge" room
// alarm in _acc_lockdown + the trench shard-bank indicator in _acc_data_shards reuse this exact
// client-side pipeline, not just perk machines). The client _acc_perk_lights.csc renders it.
// color_index 0 = off; 1..13 = the colours in the .csc level._effect map (1 red, 2 green, ...
// 7 blacklight, 8 white, 9 purple, 10 teal, 11 MAGENTA [purge lights], 12 DIM WHITE [shard banks],
// 13 DIM AMBER [dropped-item loot glow, user 2026-07-08]). accPerkGlow is a 4-bit field (0..15),
// so indices 11..13 fit with no width change. Centralises the "accPerkGlow" field name so callers
// do not hardcode it.
function set_glow( ent, color_index )
{
    if ( !isdefined( ent ) ) return;
    ent clientfield::set( "accPerkGlow", color_index );
}
