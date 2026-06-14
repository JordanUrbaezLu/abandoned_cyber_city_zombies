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
// Live tuning: every parameter is read from an `acc_fog_*` dvar (defaults baked
// in below, mirroring the codebase's `getdvarint("acc_rampage",0)` pattern).
// Set `acc_fog_livetune 1` to re-apply continuously so fog can be dialed from the
// console with no rebuild; default applies once. When the look is locked, bake
// the final numbers into the #define defaults AND docs/29 (REQUIREMENTS.md
// "no silent tuning" rule).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// Defaults = cold low city haze. TODO(acc-tune): lock these in a playtest, then
// mirror the numbers in docs/29_atmosphere_and_materials.md.
#define ACC_FOG_START_DIST     0      // units from camera where fog begins
#define ACC_FOG_HALFWAY_DIST    1600  // units to half opacity (~sightline death); tune to longest sightline
#define ACC_FOG_HALFWAY_HEIGHT  600   // vertical falloff distance
#define ACC_FOG_BASE_HEIGHT     0     // world-z where the densest fog sits
#define ACC_FOG_R               0.02  // cold blue-grey (0..1)
#define ACC_FOG_G               0.03
#define ACC_FOG_B               0.06
#define ACC_FOG_MAX_OPACITY     0.70  // cap < 0.8 so zombies / wallbuys stay readable

#namespace acc_atmosphere;

// ---------------------------------------------------------------------------
// Init - threaded from acc_main::init().
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "atmosphere init" );
    level thread apply_fog();
}

function apply_fog()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc) -
    // flag::wait_till returns immediately if already set; a bare waittill hangs.
    level flag::wait_till( "initial_blackscreen_passed" );

    set_fog_from_dvars();

    // Live-tune loop (OFF by default). When `acc_fog_livetune 1`, re-apply every
    // half second so console dvar edits take effect without a rebuild.
    if ( getdvarint( "acc_fog_livetune", 0 ) == 1 )
    {
        for ( ;; )
        {
            wait( 0.5 );
            if ( getdvarint( "acc_fog_livetune", 0 ) != 1 )
            {
                return;
            }
            set_fog_from_dvars();
        }
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
