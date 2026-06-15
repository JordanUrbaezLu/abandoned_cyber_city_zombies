// =============================================================================
// _acc_atmosphere.gsc - global volumetric fog for the abandoned cyber-city mood
//
// Design reference: docs/29_atmosphere_and_materials.md (Phase 1 - "flip greybox
// to cyber city"). Fog is the ONE atmosphere lever that is pure GSC (no Radiant):
// a cold, low city haze applied once after the initial blackscreen. The other
// Phase-1 levers - night sky (stock `default_night` SSI + `skybox_default_night`
// xmodel), wet-ground re-skin (stock t7_* materials), and reflection probes - are
// Radiant edits (baked into the BSP); see the design doc. Fog is script, so it
// lives here and rebuilds with a linker-only pass (no cod2map64/LED).
//
// VERIFIED(acc): SetVolFog( startDist, halfwayDist, halfwayHeight, baseHeight,
//   r, g, b, maxOpacity ) is the stock 8-arg volumetric-fog builtin
//   (share/raw/scripts/shared/load_shared.gsc:807, set_fog_progress()). RGB and
//   opacity are 0..1 floats - load_shared feeds it a Radiant `script_color`
//   vector, which is 0..1. It is a bare global call; `self` is irrelevant.
//   (A wider 18-arg sun-fog overload exists in _art.gsc's dev block; the 8-arg
//   shipped-path form is what we want.)
//
// Fog is OFF by default (owner prefers the clean dark night room). To enable +
// tune: `set acc_fog_on 1` (console ~, or +set at launch), then dial the per-
// parameter `acc_fog_*` dvars live - the watch loop re-applies every half second,
// no rebuild (same live-dvar pattern as the `acc_zspeed_*` speed-curve knobs). When
// a look is locked, bake the numbers into the #define defaults AND docs/29.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\music_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// Defaults = cold low city haze. TODO(acc-tune): lock these in a playtest, then
// mirror the numbers in docs/29_atmosphere_and_materials.md.
#define ACC_FOG_START_DIST     0      // units from camera where fog begins
#define ACC_FOG_HALFWAY_DIST    700   // units to half opacity (~sightline death); tune to longest sightline
#define ACC_FOG_HALFWAY_HEIGHT  900   // vertical falloff distance
#define ACC_FOG_BASE_HEIGHT     0     // world-z where the densest fog sits
#define ACC_FOG_R               0.22  // cool blue-grey smog - MUST be lighter than the dark
#define ACC_FOG_G               0.27  // night scene or the fog is invisible (lesson learned:
#define ACC_FOG_B               0.38  // 0.02/0.03/0.06 was near-black = no visible fog)
#define ACC_FOG_MAX_OPACITY     0.85  // visible haze; dial down with acc_fog_max_opacity if too thick

// Ambient bed = the AUDIO half of the atmosphere (the fog above is the visual
// half). A single 2D LOOPING city/rain soundscape, authored as the alias below
// in sound/aliases/acc_audio.csv (see docs/35_sound_plan.md). OFF by default
// (same stance as fog - the owner controls the room), enable with
// `set acc_amb_on 1`. The alias being absent today is a SILENT no-op (a missing
// alias never errors a build), so this ships build-safe before the WAV exists.
#define ACC_AMB_ALIAS           "acc_amb_city_bed"

// Main theme = a CC0 cyberpunk track (Joth, "Cyberpunk Moonlight Sonata"),
// played ONCE at game start. 2D/IsMusic alias in sound/aliases/acc_audio.csv.
#define ACC_MUSIC_ALIAS         "acc_main_theme"

#namespace acc_atmosphere;

// ---------------------------------------------------------------------------
// Init - threaded from acc_main::init().
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "atmosphere init" );

    // Kill stock zombies music IMMEDIATELY so NONE of it is heard - our theme
    // replaces it from the start with no ~10s base-music gap. setMusicState("none")
    // stops anything already cued; bonuszm_musicoverride blocks all future stock
    // music (music_shared.gsc:25-26). (The earlier black screen that made us defer
    // this was the AK-74u weapon bug, since fixed - so early is safe now.) Gated by
    // acc_stock_music_off (set 0 to keep stock music).
    if ( getdvarint( "acc_stock_music_off", 1 ) == 1 )
    {
        music::setmusicstate( "none" );
        level.bonuszm_musicoverride = true;
    }

    level thread apply_fog();
    level thread apply_ambient_bed();
    level thread apply_music();
}

function apply_fog()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc) -
    // flag::wait_till returns immediately if already set; a bare waittill hangs.
    level flag::wait_till( "initial_blackscreen_passed" );

    // Fog is OFF by default - the owner prefers the clean dark night room (no fog).
    // To turn it on: launch with `+set acc_fog_on 1`, or type `set acc_fog_on 1` in
    // the console (~); the watch loop below picks it up live and re-applies every
    // half second so the acc_fog_* tuning dvars take effect with no rebuild.
    for ( ;; )
    {
        if ( getdvarint( "acc_fog_on", 0 ) == 1 )
        {
            set_fog_from_dvars();
        }
        wait( 0.5 );
    }
}

function set_fog_from_dvars()
{
    start_dist     = getdvarfloat( "acc_fog_start_dist",     ACC_FOG_START_DIST );
    halfway_dist   = getdvarfloat( "acc_fog_halfway_dist",   ACC_FOG_HALFWAY_DIST );
    halfway_height = getdvarfloat( "acc_fog_halfway_height", ACC_FOG_HALFWAY_HEIGHT );
    base_height    = getdvarfloat( "acc_fog_base_height",    ACC_FOG_BASE_HEIGHT );
    r              = getdvarfloat( "acc_fog_r", ACC_FOG_R );
    g              = getdvarfloat( "acc_fog_g", ACC_FOG_G );
    b              = getdvarfloat( "acc_fog_b", ACC_FOG_B );
    max_opacity    = getdvarfloat( "acc_fog_max_opacity",    ACC_FOG_MAX_OPACITY );

    // VERIFIED(acc): see header - stock 8-arg signature, 0..1 RGB + opacity.
    SetVolFog( start_dist, halfway_dist, halfway_height, base_height, r, g, b, max_opacity );

    acc_utility::log( "atmosphere fog applied (halfway=" + halfway_dist + " opacity=" + max_opacity + ")" );
}

// ---------------------------------------------------------------------------
// Ambient bed - global looping soundscape. Mirrors the fog pattern: wait for
// the blackscreen flag, then watch the `acc_amb_on` dvar and start/stop a single
// level-owned looping emitter live (no rebuild). The alias is 2D (PanType=2d in
// acc_audio.csv) so the world position of the emitter is irrelevant - it plays
// at constant volume for every player. OFF by default.
// ---------------------------------------------------------------------------

function apply_ambient_bed()
{
    level endon( "end_game" );

    // VERIFIED(acc): same flag the fog loop waits on - "initial_blackscreen_passed"
    // is a FLAG (_zm.gsc); flag::wait_till returns immediately if already set.
    level flag::wait_till( "initial_blackscreen_passed" );

    started = false;
    for ( ;; )
    {
        want_on = ( getdvarint( "acc_amb_on", 0 ) == 1 );

        if ( want_on && !started )
        {
            if ( !isdefined( level.acc_amb_ent ) )
            {
                level.acc_amb_ent = spawn( "script_origin", (0,0,0) );
            }
            // PlayLoopSound is the stock looping-emitter builtin; StopLoopSound
            // ends it. A 2D alias plays non-positionally for all players.
            level.acc_amb_ent PlayLoopSound( ACC_AMB_ALIAS );
            started = true;
            acc_utility::log( "atmosphere ambient bed ON (" + ACC_AMB_ALIAS + ")" );
        }
        else if ( !want_on && started )
        {
            if ( isdefined( level.acc_amb_ent ) )
            {
                level.acc_amb_ent StopLoopSound();
            }
            started = false;
            acc_utility::log( "atmosphere ambient bed OFF" );
        }

        wait( 0.5 );
    }
}

// ---------------------------------------------------------------------------
// Main theme - the CC0 cyberpunk track, played ONCE to everyone. It is a 2D
// SERVER sound, so it only reaches clients once they're connected/in-game -
// playing it at map-init plays to NOBODY (the "song wasn't there" bug). So we
// wait for the blackscreen to pass (players are in), then play. Stock music is
// killed in init(), so there is no base music before it - just the brief loading
// intro, then the theme. The alias is 2D + IsMusic; play_sound_2D blocks until the
// full track finishes (no cutoff). On by default; `set acc_music_on 0` mutes.
// ---------------------------------------------------------------------------

function apply_music()
{
    level endon( "end_game" );

    // Wait until players are actually in (blackscreen passed) - a 2D server sound
    // played at init reaches nobody. Stock music is already off (init), so there is
    // no base music during this wait, just the loading intro, then the theme.
    level flag::wait_till( "initial_blackscreen_passed" );
    wait( 1 );

    if ( getdvarint( "acc_music_on", 1 ) == 1 )
    {
        zm_utility::play_sound_2D( ACC_MUSIC_ALIAS );
    }
}
