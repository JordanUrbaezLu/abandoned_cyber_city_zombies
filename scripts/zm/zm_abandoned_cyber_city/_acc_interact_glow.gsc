// =============================================================================
// _acc_interact_glow.gsc - "you can USE this" holo shimmer on interactable station models.
//
// THE PROBLEM (user 2026-07-17): nothing tells a player which world models are
// interactable - the stations (Exo pod, Implant Bench, kiosks, terminals, jukebox...)
// read as decoration until you happen to walk into their use-trigger. Item drops
// already have an FX glow (_acc_perk_lights::set_glow); stations deserved an
// actual glow ON the mesh, not an FX at its feet.
//
// THE LEVER (there is no "make this model glow" API): the engine's duplicate-render
// pass - the same mechanism the AW mystery box uses for its cyan holo overlay
// (scripts/planet/_aw/_zm_aw_mysterybox.csc, DR filter ids 30-32). The server sets a
// 1-bit scriptmover clientfield on the station's script_model; the client callback
// flips the ent's DR flag and the engine re-renders the mesh with our DIM clone of
// the box holo material layered over it (see _acc_interact_glow.csc for the
// material/techset ground truth).
//
// PULSE (v4, user 2026-07-17 after two failed shader-side attempts): the SERVER
// blinks the clientfield itself - ON 1.05s / OFF 0.45s, random phase per station.
// This rides the exact CF 1->0->1 transition path the box holo uses live (appear
// at reveal / vanish at grab), the most proven toggle in the pipeline. The ghost
// techset's flicker* GDT knobs are INERT (v2) and CSC filter-vs-filter alternation
// showed nothing (v3, two materials differing only in inert scaleRGB) - do NOT
// resurrect either; material-side pulsing has no verified lever.
//
// WHY EXPLICIT glow_on() CALLS (not a central model-name scan): the deco modules
// (_acc_surface_deco / _acc_abyss_deco) spawn the SAME meshes as pure decoration
// (5 deco reactor generators, a deco cryo pod, deco terminals/ATM/console...) -
// a name scan would shimmer half the scenery. The owning module tags its own ent.
//
// LOCKSTEP: scope/name/version/bits/type MUST equal _acc_interact_glow.csc
// (register unconditionally in BOTH VMs - Clientfield Mismatch otherwise).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace acc_interact_glow;

#define ACC_GLOW_ON_TIME   0.7    // seconds lit per cycle - one brief holo flash (user 2026-07-17:
                                  // "No glow for 4 seconds" then the flash; 0.3 was too short -> 0.7)
#define ACC_GLOW_OFF_TIME  4.0    // seconds dark per cycle (the resting state is NO glow)

// Clientfield registration MUST ride the REGISTER_SYSTEM autoexec (the pre-load
// phase) - the _acc_tripletake precedent; an acc_main-time register is too late.
REGISTER_SYSTEM( "acc_interact_glow", &__init__, undefined )

function __init__()
{
    // 1 scriptmover bit (every clientfield set is a finite shared budget - actor-clientfield
    // memory): 0 = off, 1 = cyan holo shimmer.
    clientfield::register( "scriptmover", "acc_interact_glow", VERSION_SHIP, 1, "int" );
}

// Tag a station's script_model as interactable: starts the server-side blink
// (pulsing cyan holo on the mesh). Call right after spawn/setmodel. Safe on
// undefined; re-apply just restarts the blink thread.
function glow_on( ent )
{
    if ( !isdefined( ent ) )
        return;
    ent thread glow_blink();
}

// Clear the shimmer (station consumed / disabled / mid-cooldown).
function glow_off( ent )
{
    if ( !isdefined( ent ) )
        return;
    ent notify( "acc_glow_blink_stop" );
    ent clientfield::set( "acc_interact_glow", 0 );
}

// PERMANENT (non-blinking) shimmer. Kills any blink thread first so nothing flips the CF
// back off; glow_on/glow_off both cleanly supersede this later. (Built for the teleporter's
// 2026-07-17 solid-when-ready language; UNUSED since 2026-07-18 - the teleporter reverted to
// the station blink-when-usable convention. Kept: clean generic API.)
function glow_solid( ent )
{
    if ( !isdefined( ent ) )
        return;
    ent notify( "acc_glow_blink_stop" );
    ent clientfield::set( "acc_interact_glow", 1 );
}

function glow_blink()   // self = the station script_model
{
    self notify( "acc_glow_blink_stop" );   // replace-safe: one blink thread per ent
    self endon( "acc_glow_blink_stop" );
    self endon( "death" );
    level endon( "end_game" );

    // Cadence: the station default is a brief flash every ~4.7s (resting = dark). An ent can
    // override via self.acc_glow_on_time/_off_time BEFORE glow_on.
    on_t  = ( isdefined( self.acc_glow_on_time )  ? self.acc_glow_on_time  : ACC_GLOW_ON_TIME );
    off_t = ( isdefined( self.acc_glow_off_time ) ? self.acc_glow_off_time : ACC_GLOW_OFF_TIME );

    // Random phase offset: stations blink out of sync (organic, not a room-wide strobe).
    // EXCEPT ents flagged acc_glow_sync (the teleporter pad = ONE machine built from 9 pieces,
    // user 2026-07-18 "they blink randomly... not in sync"): flagged ents skip the phase, so
    // every piece glow_on'd in the same frame pulses in lockstep forever (identical waits).
    if ( !( isdefined( self.acc_glow_sync ) && self.acc_glow_sync ) )
        wait randomfloatrange( 0.05, on_t + off_t );

    for ( ;; )
    {
        self clientfield::set( "acc_interact_glow", 1 );
        wait on_t;
        self clientfield::set( "acc_interact_glow", 0 );
        wait off_t;
    }
}
