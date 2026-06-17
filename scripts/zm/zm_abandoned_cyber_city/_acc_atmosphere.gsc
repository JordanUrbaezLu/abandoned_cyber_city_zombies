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
// Fog is ON by default (the cyber-night atmosphere pass, docs/40). Disable with
// `set acc_fog_on 0`. Tune the per-parameter `acc_fog_*` dvars live - the watch loop
// re-applies every half second, no rebuild (same live-dvar pattern as the
// `acc_zspeed_*` speed-curve knobs). When a look is locked, bake the numbers into the
// #define defaults AND docs/29. The colour grade (vision) is the companion lever below.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\music_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// Defaults = cold low city haze. TODO(acc-tune): lock these in a playtest, then
// mirror the numbers in docs/29_atmosphere_and_materials.md.
#define ACC_FOG_START_DIST     0      // units from camera where fog begins
#define ACC_FOG_HALFWAY_DIST    550   // units to half opacity; denser for the shrunk rooms (tune live)
#define ACC_FOG_HALFWAY_HEIGHT  750   // vertical falloff - dense at the floor, thinner at eye level
#define ACC_FOG_BASE_HEIGHT     0     // densest fog sits ON the floor -> obscures the stale floor shadows
#define ACC_FOG_R               0.15  // cool blue-grey night smog. MUST stay lighter than scene-black or
#define ACC_FOG_G               0.19  // the fog is invisible (0.02/0.03/0.06 was near-black = nothing).
#define ACC_FOG_B               0.29  // blue > red so it reads as a cold cyber haze.
#define ACC_FOG_MAX_OPACITY     0.80  // thick enough for mood + floor cover; dial with acc_fog_max_opacity

// "The city wakes up" reveal: when POWER turns on, the fog lifts smoothly to nothing
// over ACC_FOG_CLEAR_TIME seconds (one-way). Gated by acc_fog_clear_on_power; tune the
// duration live with acc_fog_clear_time. Manual test trigger: `set acc_fog_clear 1`.
#define ACC_FOG_CLEAR_TIME       12   // seconds for the haze to fade out after power-on
#define ACC_FOG_CLEAR_ON_POWER   1    // 1 = power-on clears the fog; 0 = fog stays

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

// Cyber-night COLOUR GRADE = the visual half of "make it dark" that the LED bake
// can't deliver (docs/40): a global VisionSetNaked colour grade (cool/dark), which
// the engine applies at RUNTIME with NO lightmap bake. The grade lives in
// vision/zm_abandoned_cyber_city.vision (zone: rawfile,vision/...). ON by default;
// `set acc_vision_on 0` reverts to the stock "default" vision live, and
// `set acc_vision_set <name>` hot-swaps to any loaded vision (e.g. a stock one) to
// experiment. VERIFIED(acc): a BARE server-side `VisionSetNaked( name, blend )`
// sets the GLOBAL naked vision for all players (stock _emp.gsc:428-431).
#define ACC_VISION_ON           1
#define ACC_VISION_SET          "zm_abandoned_cyber_city"

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

    level.acc_fog_fade = 1.0;   // full fog, always (the haze just stays - user 2026-06-17)

    level thread apply_fog();
    level thread apply_vision();
    level thread apply_ambient_bed();
    level thread apply_music();
}

function apply_fog()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc) -
    // flag::wait_till returns immediately if already set; a bare waittill hangs.
    level flag::wait_till( "initial_blackscreen_passed" );

    if ( !isdefined( level.acc_fog_fade ) ) level.acc_fog_fade = 1.0;
    if ( !isdefined( level.acc_fog_target_fade ) ) level.acc_fog_target_fade = 1.0;

    // SINGLE fog authority (user 2026-06-17): this is the ONLY thread that calls
    // SetVolFog, so nothing fights it (the old separate clear_fog thread + this loop
    // both calling SetVolFog made the haze "flash" but never settle). It eases the live
    // fade toward its target every 0.1s; watch_fog_clear sets the target to 0 on power-on
    // so the haze lifts smoothly over acc_fog_clear_time. `acc_fog_on 0` stops it; the
    // acc_fog_* tuning dvars still take effect live (re-read every tick).
    for ( ;; )
    {
        if ( getdvarint( "acc_fog_on", 1 ) == 1 )
        {
            tgt = level.acc_fog_target_fade;
            ct  = getdvarfloat( "acc_fog_clear_time", ACC_FOG_CLEAR_TIME );
            if ( ct < 0.1 ) ct = 0.1;
            step = 0.1 / ct;               // full 1.0 -> 0.0 over ct seconds

            if ( level.acc_fog_fade > tgt )
            {
                level.acc_fog_fade = level.acc_fog_fade - step;
                if ( level.acc_fog_fade < tgt ) level.acc_fog_fade = tgt;
            }
            else if ( level.acc_fog_fade < tgt )
            {
                level.acc_fog_fade = level.acc_fog_fade + step;
                if ( level.acc_fog_fade > tgt ) level.acc_fog_fade = tgt;
            }

            set_fog_from_dvars();
        }
        wait( 0.1 );
    }
}

// ---------------------------------------------------------------------------
// Cyber-night colour grade - global VisionSetNaked, no lightmap bake (docs/40).
// Watches acc_vision_on / acc_vision_set so the look can be toggled + hot-swapped
// live. Applies only on CHANGE so it does not spam the renderer every half second.
// ---------------------------------------------------------------------------

function apply_vision()
{
    level endon( "end_game" );

    // Same flag the fog waits on - players are in once the blackscreen passes.
    level flag::wait_till( "initial_blackscreen_passed" );

    applied = "";
    for ( ;; )
    {
        on   = ( getdvarint( "acc_vision_on", ACC_VISION_ON ) == 1 );
        vset = getdvarstring( "acc_vision_set", ACC_VISION_SET );
        // OFF -> revert to the stock neutral "default" vision (not "", which no-ops).
        want = ( on ? vset : "default" );

        if ( want != applied && want != "" )
        {
            // VERIFIED(acc): bare server-side VisionSetNaked( name, blend ) = the
            // GLOBAL naked vision for every player (stock _emp.gsc:428-431). New
            // joiners inherit the global render state.
            VisionSetNaked( want, 1.0 );
            applied = want;
            acc_utility::log( "atmosphere vision: " + want );
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

    // Power-on "the city wakes" reveal: level.acc_fog_fade ramps 1->0 (clear_fog),
    // scaling the opacity so the haze lifts smoothly. Defaults to 1 (full fog).
    if ( !isdefined( level.acc_fog_fade ) )
        level.acc_fog_fade = 1.0;
    max_opacity = max_opacity * level.acc_fog_fade;

    // VERIFIED(acc): see header - stock 8-arg signature, 0..1 RGB + opacity.
    SetVolFog( start_dist, halfway_dist, halfway_height, base_height, r, g, b, max_opacity );

    acc_utility::log( "atmosphere fog applied (halfway=" + halfway_dist + " opacity=" + max_opacity + ")" );
}

// (Fog lift-on-power was removed 2026-06-17 - the haze just stays. Simpler, and it
// never reliably faded anyway. apply_fog keeps level.acc_fog_fade at 1.0.)

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
