// =============================================================================
// _acc_atmosphere.gsc - global volumetric fog for the abandoned cyber-city mood
//
// Design reference: docs/20_atmosphere_and_materials.md (Phase 1 - "flip greybox
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
// Fog is ON by default (the cyber-night atmosphere pass, docs/BO3_MAPMAKING_KB.md). Disable with
// `set acc_fog_on 0`. Tune the per-parameter `acc_fog_*` dvars live - the watch loop
// re-applies every half second, no rebuild (same live-dvar pattern as the
// `acc_zspeed_*` speed-curve knobs). When a look is locked, bake the numbers into the
// #define defaults AND docs/20. The colour grade (vision) is the companion lever below.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\music_shared;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_music;        // single music channel (main theme routes through it)
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;   // underground_layer() for the depth-gated abyss dark vision

#insert scripts\shared\shared.gsh;   // IS_TRUE (dev-gated prop report, 2026-07-02)

// Defaults = cold low city haze. TODO(acc-tune): lock these in a playtest, then
// mirror the numbers in docs/20_atmosphere_and_materials.md.
#define ACC_FOG_START_DIST     0      // units from camera where fog begins
#define ACC_FOG_HALFWAY_DIST    550   // units to half opacity; denser for the shrunk rooms (tune live)
#define ACC_FOG_HALFWAY_HEIGHT  750   // vertical falloff - dense at the floor, thinner at eye level
#define ACC_FOG_BASE_HEIGHT     0     // densest fog sits ON the floor -> obscures the stale floor shadows
#define ACC_FOG_R               0.15  // cool blue-grey night smog. MUST stay lighter than scene-black or
#define ACC_FOG_G               0.19  // the fog is invisible (0.02/0.03/0.06 was near-black = nothing).
#define ACC_FOG_B               0.29  // blue > red so it reads as a cold cyber haze.
#define ACC_FOG_MAX_OPACITY     0.80  // thick enough for mood + floor cover; dial with acc_fog_max_opacity

// "The city wakes up" reveal: when POWER IS TURNED ON the fog SETTLES AWAY DOWNWARD
// (user 2026-06-18 - was first-kill). We can't fade vol fog by opacity
// (VERIFIED(acc): zeroing opacity does NOT clear it - stock _art.gsc:231 hits the same wall),
// so the "fade" is done by SINKING it: lower the fog's base height (the SetVolFog `baseHeight`
// arg - the Z where the haze is densest) a SLIGHT step once per second. vol-fog opacity falls
// off exponentially with height above the base (halving every acc_fog_halfway_height units), so
// as the dense layer slides below the floor the haze at eye level thins to nothing - it looks
// like the fog is settling into the ground. Once the base has sunk acc_fog_settle_depth below
// the floor (invisible), OR acc_fog_settle_max_steps nudges have run (safety cap), we hard-
// disable for good via disable_fog() (planes pushed out, the only true off). TRIGGER: apply_fog
// (the single SetVolFog authority) polls the stock "power_on" FLAG each tick; once set it flips
// level.acc_fog_cleared and runs settle_fog_step() instead of the haze. (NOTE: with the dev
// build's auto-power, power comes on ~1.5s after the haze appears, so the haze is brief; in a
// switch-gated ship build it holds until the player turns power on.) All knobs are live dvars.
#define ACC_FOG_CLEAR_ON_POWER   1    // 1 = power-on settles the fog away; 0 = haze stays all match
#define ACC_FOG_SETTLE_INTERVAL  1.0  // seconds between each slight downward nudge (user: once per second)
#define ACC_FOG_SETTLE_STEP      200  // units the fog base sinks per nudge - keep "slight"; smaller = slower/smoother
#define ACC_FOG_SETTLE_DEPTH     7500 // base must sink this far below the floor to read as invisible (then locked off)
#define ACC_FOG_SETTLE_MAX_STEPS 1200 // hard cap on nudges so the descent always terminates (user: "like 1200 times")

// Ambient bed = the AUDIO half of the atmosphere (the fog above is the visual
// half). A single 2D LOOPING city/rain soundscape, authored as the alias below
// in sound/aliases/acc_audio.csv (see docs/23_sound_plan.md). OFF by default
// (same stance as fog - the owner controls the room), enable with
// `set acc_amb_on 1`. The alias being absent today is a SILENT no-op (a missing
// alias never errors a build), so this ships build-safe before the WAV exists.
#define ACC_AMB_ALIAS           "acc_amb_city_bed"

// Main theme = "Suspense Dark Thriller" (lnplusmusic, Pixabay #392762; user
// 2026-06-24, replaced the Joth "Cyberpunk Moonlight Sonata" CC0 track). Full
// ~1:45 track, played ONCE at game start. 2D/IsMusic STREAMED alias in
// sound/aliases/acc_audio.csv (source wav sound_assets/acc/music/main_theme.wav).
#define ACC_MUSIC_ALIAS         "acc_main_theme"

// Cyber-night COLOUR GRADE = an optional global VisionSetNaked colour grade applied
// at RUNTIME with NO lightmap bake (docs/BO3_MAPMAKING_KB.md). OFF BY DEFAULT (user 2026-06-18): every
// custom grade (cyan / magenta / neutral+cyan) read worse than stock on this flat
// fullbright scene, so the map ships with BASE GAME COLOURS - apply_vision with
// acc_vision_on 0 applies the stock neutral "default" vision and adds no tint of its own.
// The custom grades are NOT deleted, just dormant: `set acc_vision_on 1` re-enables the
// grade and `set acc_vision_set <name>` hot-swaps any loaded vision
// (zm_abandoned_cyber_city / acc_grade_magenta / acc_grade_orange / acc_grade_dark) to
// experiment live. VERIFIED(acc): a BARE server-side `VisionSetNaked( name, blend )`
// sets the GLOBAL naked vision for all players (stock _emp.gsc:428-431).
#define ACC_VISION_ON           0
#define ACC_VISION_SET          "zm_abandoned_cyber_city"

// --- Atmosphere FX (Phase 3+4, user 2026-06-28): neon HERO-GLOWS + ambient dust/steam. Server PlayFX of
//     LOOPING efx (one shot at init persists). Paths verified on disk (share/raw/fx). Gated by acc_atmo_fx.
//     The glow efx are our own perk-machine glows (also client-precached in _acc_perk_lights.csc) reused as
//     the visible neon "sources" the Phase-1 baked light pools spill from. If server FX don't render in-game
//     (see memory power-on-lights-perks-mechanism), promote to a client _acc_atmosphere_fx.csc.
#precache( "fx", "acc/light/fx_perk_glow_teal" );
#precache( "fx", "acc/light/fx_perk_glow_magenta" );
#precache( "fx", "acc/light/fx_perk_glow_amber" );
#precache( "fx", "acc/light/fx_perk_glow_blue" );
#precache( "fx", "acc/light/fx_perk_glow_red" );
#precache( "fx", "dirt/fx_dust_linger_int_sector" );
#precache( "fx", "steam/fx_steam_leak_md_factory_zmb" );

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

    level.acc_fog_cleared = false;   // flips true once power is on; apply_fog then settles the fog away

    // Power-on fog removal (was first-kill): apply_fog (the ONLY SetVolFog caller) polls the stock
    // "power_on" flag each tick and, once it's set, flips acc_fog_cleared and starts the downward
    // settle. No separate flag-wait thread (avoids the flag-not-yet-created crash) - the poll is
    // gated by acc_fog_clear_on_power and only runs until cleared.

    level thread apply_fog();
    level thread apply_vision();
    level thread apply_ambient_bed();
    level thread apply_music();
    level thread apply_fx();          // Phase 3+4: neon hero-glows + ambient dust/steam (acc_atmo_fx)
    // TEMP-DISABLED (user 2026-07-02 "game won't start" bisect): the T7 pilot props are one of
    // two native-crash suspects (holo screen has 5 unresolved display materials; log dies silently
    // right after init in the 22:48/23:49 builds). Re-enable to bisect once the game boots again.
    // level thread spawn_exchange_props(); // T7 prop-pack pilot decor (user 2026-07-02)
}

// =============================================================================
// T7 prop-pack PILOT decor (user 2026-07-02: "place a thing or two in... the exchange
// room actually since that's pretty open"). The Exchange = the transfer-vault room
// UNDER the spawn Plaza (gen_plaza_basement.js: floor z=-240, x[-720,300], y[-448,360],
// docs/37). Two static script_models from the MidgetBlaster "T7 Assets" pack (Zombies
// Chronicles Moon server rack + Awakening/crucible holo monitor - fits the cyber read):
// install-side slice source_data\acc_t7_props_pilot.gdt + model_export\_midgetblaster\
// (PNG baseImages - same pipeline as the ALXS PaP/actionfigure images). Zone:
// xmodel,p7_zm_moo_server_comm_02 + xmodel,p7_cru_monitor_holo_screen_01.
// Pure decor: no collision clips added (props sit against walls, out of the lane);
// this module is the visual-dressing home (coordinator may re-home later).
// =============================================================================
// NOTE (compile trap, 2026-07-02): BO3 GSC has NO non-empty array-literal syntax -
// `props[0] = [ a, b, c ]` fails the whole file with "No generated data" (only the
// empty `arr = [];` literal is legal, and the repo lint does NOT catch this).
// Hence plain per-prop calls below.
function spawn_exchange_props()
{
    // Repositioned to CLEARLY-OPEN mid-room floor (2026-07-02 round 3: props did not appear;
    // the old spots hugged the walls - a wall-embedded origin, wrong z, or a dead spawn could
    // all hide silently). Vault interior: x[-720,300] y[-448,360], floor top z=-240.
    n = 0;
    n += spawn_exchange_prop( "p7_zm_moo_server_comm_02", ( -400, 200, -240 ), ( 0, 270, 0 ) );  // rack, open floor N half, faces south
    n += spawn_exchange_prop( "p7_cru_monitor_holo_screen_01", ( 100, -300, -240 ), ( 0, 90, 0 ) ); // holo, open floor S half, faces north

    acc_utility::log( "atmosphere: exchange pilot props spawned (" + n + ")" );
    if ( IS_TRUE( level.acc_dev ) )
        level thread dev_report_exchange_props( n );
}

// Returns 1 on success, 0 on a dead spawn (guarded - spawn() CAN return undefined).
function spawn_exchange_prop( model, origin, angles )
{
    m = spawn( "script_model", origin );
    if ( !isdefined( m ) ) return 0;
    m SetModel( model );
    m.angles = angles;
    return 1;
}

// acc_dev: prove the pilot props in-game either way (round-3 instrumentation).
function dev_report_exchange_props( n )
{
    level flag::wait_till( "initial_blackscreen_passed" );
    wait 6;
    foreach ( p in GetPlayers() )
        p IPrintLnBold( "^3[ACC] exchange props: " + n + " spawned @ (-400,200,-240) + (100,-300,-240)" );
}

function apply_fog()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc) -
    // flag::wait_till returns immediately if already set; a bare waittill hangs.
    // This wait is MANDATORY: fog cannot be set before players are in - it is literally how
    // the haze gets set in the first place, NOT optional "flag stuff" we can drop.
    level flag::wait_till( "initial_blackscreen_passed" );

    if ( !isdefined( level.acc_fog_cleared ) ) level.acc_fog_cleared = false;

    // SINGLE fog authority (user 2026-06-17): this is the ONLY thread that calls SetVolFog, so
    // nothing fights it. Every 0.1s it applies either the full haze OR the settle-away descent,
    // depending on acc_fog_cleared. settle_fog_step() re-asserts the fog each tick (so nothing
    // else re-fogs) and nudges it down once per second. `acc_fog_on 0` freezes the loop; the
    // acc_fog_* tuning dvars take effect live.
    for ( ;; )
    {
        // PARADISE FINALE OVERRIDE (user 2026-06-25): once the finale rolls the fog back in (paradise_fog_on),
        // THIS single SetVolFog authority re-asserts a thick paradise haze every tick - overriding the power-on
        // settle/disable below so nothing fights it. The fog had been settled away at power-on; this brings it back.
        if ( isdefined( level.acc_paradise_fog ) && level.acc_paradise_fog )
        {
            paradise_fog_apply();
        }
        else if ( getdvarint( "acc_fog_on", 1 ) == 1 )
        {
            // TRIGGER (user 2026-06-18): start the settle once POWER is on. Poll the stock
            // "power_on" flag (exists-guarded; it's created early, surely by now post-blackscreen)
            // only until cleared. Gated live by acc_fog_clear_on_power.
            if ( !level.acc_fog_cleared
                 && getdvarint( "acc_fog_clear_on_power", ACC_FOG_CLEAR_ON_POWER ) == 1
                 && level flag::exists( "power_on" ) && level flag::get( "power_on" ) )
            {
                level.acc_fog_cleared = true;
                acc_utility::log( "atmosphere fog: power on -> settling away" );
            }

            if ( level.acc_fog_cleared )
                settle_fog_step();      // power is on -> sink the fog away (settles down over time)
            else
                set_fog_from_dvars();   // full cyber-night haze
        }
        wait( 0.1 );
    }
}

// PARADISE FINALE fog (user 2026-06-25). The finale "rolls the fog back in" after the calm first minute, as the
// omen ("fetch me their souls") hits. paradise_fog_on() flips the flag the SINGLE fog authority (apply_fog) reads;
// from then on it re-asserts a THICK haze every tick (overriding the power-on settle), densest at the PARADISE
// floor (z~-1200, below ACC_SP_Z=-1000) so the whole sealed arena is fogged in. All acc_paradise_fog_* live-tunable.
function paradise_fog_on()
{
    level.acc_paradise_fog = true;
    acc_utility::log( "atmosphere fog: PARADISE finale - fog rolled back in" );
}

// "Lift the fog" on the Paradise WIN (user 2026-06-25). Vol fog can't be deleted, so lifting = MOVING it off
// the map: clear the finale flag (so apply_fog stops re-asserting the haze) AND push the fog start plane out to
// ~100,000,000 units NOW (disable_fog) so it's gone instantly for the victory cut, not on the next poll tick.
function paradise_fog_off()
{
    level.acc_paradise_fog = false;
    disable_fog();   // move the fog off the map immediately (planes pushed out - the only true "off")
}

function paradise_fog_apply()
{
    // Bring the fog back the SAME way the map applies its haze (user 2026-06-25): re-run the STANDARD
    // set_fog_from_dvars() - the exact pre-power cyber-night haze, with its real fog planes pushed back ONTO
    // the map (the inverse of disable_fog's push-out). Paradise sits far below the haze base height (z=0), and
    // vol fog is max-density BELOW the base (it's ground fog), so the whole sealed arena fogs up. The override
    // flag in apply_fog re-asserts this every tick, so it beats the power-on settle that had cleared it. Reusing
    // the proven map haze (NOT a custom fog) is exactly what "do it correctly, the way the map already does" means.
    set_fog_from_dvars();
}

// Power-on "fade": instead of teleporting the fog away instantly, SINK it (user 2026-06-18).
// Called every 0.1s once acc_fog_cleared is set (i.e. power has come on). It re-applies the haze each tick with a base
// height that drops one SLIGHT step (acc_fog_settle_step) every acc_fog_settle_interval seconds,
// so the dense floor layer slides straight down and the haze thins to nothing at eye level
// (vol-fog opacity halves every acc_fog_halfway_height units above the base). When the base has
// sunk acc_fog_settle_depth below the floor (invisible) OR acc_fog_settle_max_steps nudges have
// run, it's locked off for good via disable_fog(). Framerate-independent: pacing is by an
// accumulated-time counter, not per-frame, so the cadence holds at any tick rate.
function settle_fog_step()
{
    // Already fully settled -> hold it hard-disabled (cheap, and blocks any re-fog).
    if ( isdefined( level.acc_fog_settle_done ) && level.acc_fog_settle_done )
    {
        disable_fog();
        return;
    }

    interval  = getdvarfloat( "acc_fog_settle_interval",  ACC_FOG_SETTLE_INTERVAL );
    step      = getdvarfloat( "acc_fog_settle_step",      ACC_FOG_SETTLE_STEP );
    depth     = getdvarfloat( "acc_fog_settle_depth",     ACC_FOG_SETTLE_DEPTH );
    max_steps = getdvarint(   "acc_fog_settle_max_steps", ACC_FOG_SETTLE_MAX_STEPS );
    if ( interval < 0.1 ) interval = 0.1;   // never faster than the tick

    base_start = getdvarfloat( "acc_fog_base_height", ACC_FOG_BASE_HEIGHT );

    // First settle tick after the kill: begin the descent at the current (live) base height.
    if ( !isdefined( level.acc_fog_settle_base ) )
    {
        level.acc_fog_settle_base  = base_start;
        level.acc_fog_settle_steps = 0;
        level.acc_fog_settle_acc   = 0;     // seconds accumulated toward the next nudge
    }

    // Pace one downward nudge per `interval` seconds, even though this loop ticks every 0.1s.
    level.acc_fog_settle_acc += 0.1;
    if ( level.acc_fog_settle_acc + 0.001 >= interval )
    {
        level.acc_fog_settle_acc = 0;
        level.acc_fog_settle_base -= step;        // the slight move, straight DOWN
        level.acc_fog_settle_steps += 1;

        // Stop once it's far enough below the floor to be invisible, or the cap is reached.
        sunk = base_start - level.acc_fog_settle_base;
        if ( sunk >= depth || level.acc_fog_settle_steps >= max_steps )
        {
            level.acc_fog_settle_done = true;
            disable_fog();
            acc_utility::log( "atmosphere fog: settled away after " + level.acc_fog_settle_steps + " steps" );
            return;
        }
    }

    // Re-apply the haze with the descending base height; colour / opacity / distances unchanged
    // so the layer SINKS rather than fades-to-clear, and nothing else can re-fog between nudges.
    start_dist     = getdvarfloat( "acc_fog_start_dist",     ACC_FOG_START_DIST );
    halfway_dist   = getdvarfloat( "acc_fog_halfway_dist",   ACC_FOG_HALFWAY_DIST );
    halfway_height = getdvarfloat( "acc_fog_halfway_height", ACC_FOG_HALFWAY_HEIGHT );
    r              = getdvarfloat( "acc_fog_r", ACC_FOG_R );
    g              = getdvarfloat( "acc_fog_g", ACC_FOG_G );
    b              = getdvarfloat( "acc_fog_b", ACC_FOG_B );
    max_opacity    = getdvarfloat( "acc_fog_max_opacity",    ACC_FOG_MAX_OPACITY );

    acc_set_vol_fog( start_dist, halfway_dist, halfway_height, level.acc_fog_settle_base, r, g, b, max_opacity );
}

// Remove volumetric fog for good. VERIFIED(acc): opacity 0 does NOT clear vol fog (stock
// _art.gsc:231: "couldn't find discreet fog disabling other than to never set it"). The
// reliable disable is to push the fog start plane out to ~100,000,000 units so fog begins
// far beyond the world and never reaches the camera (stock uses the same trick via setExpFog).
function disable_fog()
{
    acc_set_vol_fog( 100000000, 100000001, 0, 0, 0, 0, 0, 0 );
}

// CHANGE-GATED SetVolFog (user 2026-07-04): the apply_fog loop re-asserted IDENTICAL fog params
// every 0.1s for the whole match (~10 engine calls + 10 "setVolFog: Old syntax used" console lines
// per second = tens of thousands of log lines burying the real fatal in console_mp.log). SetVolFog
// only overwrites the single GLOBAL fog state, so re-issuing unchanged values does nothing - call
// the engine ONLY when a parameter actually changed (the same want!=applied pattern the vision
// loop uses). The single-authority design is unchanged: everything still routes through the one
// apply_fog loop; this wrapper just skips the redundant engine calls. Verified NOT the state-pool
// leak (no allocation), purely log/CPU hygiene.
function acc_set_vol_fog( start_dist, halfway_dist, halfway_height, base_height, r, g, b, opacity )
{
    key = start_dist + "," + halfway_dist + "," + halfway_height + "," + base_height + ","
          + r + "," + g + "," + b + "," + opacity;
    if ( isdefined( level.acc_fog_last_applied ) && level.acc_fog_last_applied == key )
        return;
    level.acc_fog_last_applied = key;
    SetVolFog( start_dist, halfway_dist, halfway_height, base_height, r, g, b, opacity );
}

// ---------------------------------------------------------------------------
// Cyber-night colour grade - global VisionSetNaked, no lightmap bake (docs/BO3_MAPMAKING_KB.md).
// Watches acc_vision_on / acc_vision_set so the look can be toggled + hot-swapped
// live. Applies only on CHANGE so it does not spam the renderer every half second.
//
// REVIVE GOTCHA (docs/20 §7c, fixed 2026-06-24): this CHANGE-GATE is per-this-loop
// (the local `applied`), but the engine FORCE-RESTORES the MAP-NAME vision
// ("zm_abandoned_cyber_city") PER-CLIENT on every revive (visionset_mgr / _zm_laststand),
// which BYPASSES this global slot - so after a down/revive a player keeps whatever
// vision/zm_abandoned_cyber_city.vision is, regardless of `applied`. That file is kept
// == stock default.vision (neutral) so the restore is harmless; NEVER tint the map-name
// .vision (it caused the "gray screen on revive" bug). Custom global grades go through
// acc_vision_set (the acc_grade_* files), not the map-name file.
// ---------------------------------------------------------------------------

function apply_vision()
{
    level endon( "end_game" );

    // Same flag the fog waits on - players are in once the blackscreen passes.
    level flag::wait_till( "initial_blackscreen_passed" );

    applied      = "";
    power_was_on = false;

    for ( ;; )
    {
        // POWER-ON LIGHT WARM-UP (user 2026-06-22): the baked lights map-wide flip on INSTANTLY when power
        // comes on (a binary lighting-state swap - can't be faded at the bake), so we fake a SLOW swell.
        // CheckForPower masks the lightmap to the CURRENT pre-power darkness (acc_power_light_start, NOT pitch
        // black) BEFORE the bright flip - so there's neither a flash NOR a dip-to-black (user: "stay the same
        // darkness, don't go darker"). Here we just re-assert that start and SLOW-LERP it up to default over
        // `ramp` seconds - a uniform, gentle ramp ("slow slow slow"), no fast surge at the end. The block runs
        // synchronously and OWNS the vision for the duration. acc_power_light_ramp_on toggles; acc_power_light_ramp
        // is the seconds (15); acc_power_light_start is the starting grade (default warm1 ~18% - dial it to match
        // your pre-power dark: blackout=darker, warm2=~45%, default=no dim).
        pwr = ( level flag::exists( "power_on" ) && level flag::get( "power_on" ) );
        if ( pwr && !power_was_on )
        {
            power_was_on = true;
            ramp = getdvarfloat( "acc_power_light_ramp", 15.0 );
            if ( getdvarint( "acc_power_light_ramp_on", 1 ) == 1 && ramp > 0.1 )
            {
                start = getdvarstring( "acc_power_light_start", "acc_grade_warm1" );
                acc_utility::log( "atmosphere: power-on warm-up " + start + " -> default over " + ramp + "s" );
                VisionSetNaked( start, 0 );        // hold AT the pre-power darkness (CheckForPower set the same)
                wait 0.1;                           // let it land as the current vision so the lerp starts from it
                VisionSetNaked( "default", ramp );  // SLOW uniform lerp: pre-power dark -> full over `ramp` seconds
                wait( ramp );
                applied = "default";
                continue;
            }
        }

        on   = ( getdvarint( "acc_vision_on", ACC_VISION_ON ) == 1 );
        vset = getdvarstring( "acc_vision_set", ACC_VISION_SET );
        // OFF -> revert to the stock neutral "default" vision (not "", which no-ops).
        want = ( on ? vset : "default" );

        // ABYSS DARKNESS (user 2026-06-22): the trench/abyss "won't get dark" because the baseline
        // brightness is the VISION TONEMAP CURVE TOP + sky/IBL ambient - NOT the point lights, so dimming
        // bake_intensity_scale can never reach it (confirmed: all 7 reflection probes are surface-only, so
        // the abyss uses the bright default cubemap; volume_sun fill is already 0 0 0). The vision tonemap is
        // the LAST stage before the frame, so a NEUTRAL near-black grade (acc_grade_abyss_dark.vision, vkRM
        // 0.08, R=G=B = no hue) crushes the IBL/curve floor to black. Apply it whenever a player is below the
        // trench lip. This is the GLOBAL slot (solo-correct; a per-player clientfield->.csc upgrade is the
        // coop follow-up). Gate: acc_abyss_dark_on; vision name: acc_abyss_dark_vision (swap live to retune).
        // Default OFF (user 2026-06-22): the abyss darkness now comes from FEWER baked lights (gen_abyss_layer.js
        // emitLights = 1 small central pool/layer), so the vision crush is a separate optional lever - flip
        // `acc_abyss_dark_on 1` to ALSO post-process-darken if the light reduction alone isn't enough.
        if ( getdvarint( "acc_abyss_dark_on", 0 ) == 1 && any_player_underground() )
            want = getdvarstring( "acc_abyss_dark_vision", "acc_grade_abyss_dark" );

        if ( want != applied && want != "" )
        {
            // VERIFIED(acc): bare server-side VisionSetNaked( name, blend ) = the
            // GLOBAL naked vision for every player (stock _emp.gsc:428-431). New
            // joiners inherit the global render state.
            VisionSetNaked( want, 1.0 );
            applied = want;
            acc_utility::log( "atmosphere vision: " + want );
        }

        wait( 0.25 );   // snappier poll so the dark settles in quickly when you drop into the trench
    }
}

// True if ANY player is below the trench lip (underground_layer>0). The naked vision is ONE global slot, so
// in solo this is exactly the local player; in coop it darkens everyone while anyone is down the trench (the
// approximation the per-player clientfield upgrade fixes). Cheap: a handful of players, polled every 0.25s.
function any_player_underground()
{
    players = GetPlayers();
    if ( !isdefined( players ) )
        return false;
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) && acc_bus_trench::underground_layer( players[ i ].origin ) > 0 )
            return true;
    }
    return false;
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

    // VERIFIED(acc): see header - stock 8-arg signature, 0..1 RGB + opacity. Full haze at
    // max_opacity; the power-on removal is a downward sink ending in disable_fog() (planes out),
    // NOT an opacity ramp, because opacity 0 does not clear vol fog. Change-gated (acc_set_vol_fog)
    // so the 0.1s authority loop no longer re-issues identical values 10x/sec.
    acc_set_vol_fog( start_dist, halfway_dist, halfway_height, base_height, r, g, b, max_opacity );
}

// (Fog clear history: lift-on-power -> opacity-fade-on-first-kill -> instant disable-on-first-kill
// -> settle-away-downward-on-first-kill -> SETTLE-AWAY-DOWNWARD-on-POWER-ON. The opacity fade NEVER
// worked: zeroing vol-fog opacity does not remove it (fixed 2026-06-17 by disable_fog() pushing the
// planes out, per _art.gsc:231). 2026-06-18: the instant disable became a gradual downward sink
// (settle_fog_step) for a "settles into the ground" fade, and the trigger moved from first-kill to
// the "power_on" flag - we lower the base height, since opacity still can't be faded directly.)

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
        // Route through the single music channel so a boss spawn / teddy-bear song cleanly takes over (and
        // this one-shot theme stops the moment it does). Reaches the whole lobby, same as play_sound_2D.
        acc_music::play( ACC_MUSIC_ALIAS, false );
    }
}

// ---------------------------------------------------------------------------
// Atmosphere FX (Phase 3+4) - neon HERO-GLOWS + ambient dust/steam, placed with server PlayFX at fixed
// world points after the blackscreen. The glow efx loop, so one PlayFX persists; they are the visible neon
// "sources" the Phase-1 baked light pools spill from. Gated by acc_atmo_fx (default 1). Revert: acc_atmo_fx 0.
// ---------------------------------------------------------------------------

function apply_fx()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );
    if ( getdvarint( "acc_atmo_fx", 1 ) != 1 )
        return;

    level._effect[ "acc_glow_teal" ]    = "acc/light/fx_perk_glow_teal";
    level._effect[ "acc_glow_magenta" ] = "acc/light/fx_perk_glow_magenta";
    level._effect[ "acc_glow_amber" ]   = "acc/light/fx_perk_glow_amber";
    level._effect[ "acc_glow_blue" ]    = "acc/light/fx_perk_glow_blue";
    level._effect[ "acc_glow_red" ]     = "acc/light/fx_perk_glow_red";
    level._effect[ "acc_haze" ]         = "dirt/fx_dust_linger_int_sector";
    level._effect[ "acc_steam" ]        = "steam/fx_steam_leak_md_factory_zmb";

    // HERO glow SPRITES were removed (user 2026-06-28: "put them in spots where they don't show... move it above
    // the ceiling"). The orbs showed as bright floating sprites in mid-room. The colored glow now comes purely from
    // the Phase-1 BAKED neon lights (gen_neon_lights.js) - a light entity casts the colored pool with NO visible
    // on-map source - which also carry each zone's UNIQUE color. (To re-add a recessed neon accent later, place a
    // glow just inside a wall/ceiling so only its halo spills.) Steam + haze below are plumes/drift, not orbs - kept.
    // AMBIENT drifting interior dust/haze (subtle life):
    fx_at( "acc_haze", (     0, 1950, 120 ) );  // Corp
    fx_at( "acc_haze", ( -1596,  928, 110 ) );  // Market
    fx_at( "acc_haze", (  1634,  928, 110 ) );  // Alley
    fx_at( "acc_haze", (     0, 1950,-180 ) );  // Trench
    // STEAM vents (placed low so the plume rises):
    fx_at( "acc_steam", (  1700, 1000,  20 ) );  // Alley vent
    fx_at( "acc_steam", (  1300, 2600,  20 ) );  // Vault
    fx_at( "acc_steam", (  -200, 1948,-230 ) );  // Trench

    acc_utility::log( "atmosphere FX placed (neon glows + drifting haze + steam vents)" );
}

function fx_at( key, origin )
{
    if ( isdefined( level._effect[ key ] ) )
        PlayFX( level._effect[ key ], origin );
}
