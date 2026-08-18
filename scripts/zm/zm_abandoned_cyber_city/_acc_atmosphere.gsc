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
#define ACC_FOG_SETTLE_INTERVAL  5.0  // seconds between nudges. P2 re-pace (docs/46): 4 nudges to the
                                      // residual depth x 5s = the ~20s settle lands WITH the boot-up
                                      // cascade's t+21 finale - the air clears as the city finishes waking.
                                      // (was 1.0 = a ~4s settle that beat the cascade by 17s)
#define ACC_FOG_SETTLE_STEP      200  // units the fog base sinks per nudge - keep "slight"; smaller = slower/smoother
#define ACC_FOG_SETTLE_DEPTH     7500 // base must sink this far below the floor to read as invisible (then locked off)
#define ACC_FOG_SETTLE_MAX_STEPS 1200 // hard cap on nudges so the descent always terminates (user: "like 1200 times")

// RESIDUAL HAZE (visual overhaul P0, docs/46 intervention #2, user-approved 2026-07-29): the
// power-on settle no longer ends in disable_fog() - the map's light pools need a permanent thin
// medium to read as VOLUMES (root cause RC2: "the atmospheric medium deletes itself; post-power
// is the flattest possible state"). The descent now STOPS once the base has sunk
// acc_fog_residual_depth below its start and holds a thinner, longer-throw haze from then on
// (wider halfway_dist + lower opacity than the pre-power haze). The old full-disable behavior is
// one dvar away (acc_fog_residual_on 0) and Paradise finale fog still overrides everything.
#define ACC_FOG_RESIDUAL_ON            1     // 1 = settle INTO a thin haze; 0 = legacy settle to full disable_fog()
#define ACC_FOG_RESIDUAL_DEPTH         800   // base stops this far below its start (eye-level haze thins ~2.1x via the 750u halfway_height falloff)
#define ACC_FOG_RESIDUAL_OPACITY       0.55  // residual max_opacity (pre-power haze = 0.80); effective eye-level ~0.25-0.35
#define ACC_FOG_RESIDUAL_HALFWAY_DIST  850   // residual distance falloff (pre-power 550) - thinner up close, still pools light at range

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
// P2 (docs/46 #23): the audition candidate is now acc_grade_vibrant (neutral curve + vkTS 0.12
// = +12% saturation). Still SHIPS OFF - flip ACC_VISION_ON to 1 + rebuild ONLY after the user
// approves the P1 noir rig (a grade only reads correctly on a colored rig; user rejected a bare
// tint on the old flat-white scene 2026-06-18 - that verdict does not transfer to this rig).
#define ACC_VISION_SET          "acc_grade_vibrant"

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
// --- FX pass (2026-07-19): per-zone ambient loops from the installed HB21 library
//     (<tools>\share\raw\fx\, verified on disk). Same wiring rule as the two above:
//     every one of these ALSO has a matching `fx,` line in zone_source (docs/20 §7) -
//     a precache without the zone line = PlayFX silently no-ops. All placed by
//     apply_fx() below, gated by the existing acc_atmo_fx dvar.
#precache( "fx", "dirt/fx_dust_fall_line_sm" );
#precache( "fx", "dirt/fx_dust_fall_ceiling_veiled" );
#precache( "fx", "dirt/fx_dust_fall_lg_lit" );
#precache( "fx", "light/fx_light_flickering_hat_light_sodium" );
#precache( "fx", "light/fx_light_sgen_dayroom_rectangle_flicker" );
#precache( "fx", "steam/fx_steam_aircond" );
#precache( "fx", "steam/fx_steam_manhole_cover" );
#precache( "fx", "steam/fx_steam_vent_floor_line_100" );
#precache( "fx", "water/fx_water_drip_line_25" );
#precache( "fx", "water/fx_water_drip_ceiling" );
#precache( "fx", "electric/fx_elec_gp_wire_sparking_xsml_anim_loop" );
#precache( "fx", "electric/fx_elec_spark_loop_sm" );
#precache( "fx", "fog/fx_fog_ground_wind_lt_sm" );
#precache( "fx", "fog/fx_fog_coolant_vent_md" );
#precache( "fx", "fog/fx_fog_ground_low_rolling_stairs" );
#precache( "fx", "zombie/fx_fungus_pod_ambient_md_zod_zmb" );
// --- P0 sparkle batch (visual overhaul docs/46 Phase 0, 2026-07-29): lensflares at the neon
//     pools, the Alley burn-barrel fire, dumpster flies, Lab/Vault god rays + motes. All paths
//     verified on disk (<tools>\share\raw\fx\) 2026-07-29; each has a `fx,` zone line; all
//     placed by apply_fx() below on the same acc_atmo_fx gate.
#precache( "fx", "lensflares/fx_lensflare_fluorescent" );
#precache( "fx", "lensflares/fx_lensflare_light_cool_lg" );
// FX CRASH LEDGER (2026-07-29, four Alley crash sessions to learn this - see apply_fx +
// memory fx-embedded-light-def-freeze): REMOVED fire/fx_fire_barrel (pcloud spark materials =
// THE killer, present in all 4 crashes), light/fx_light_zm_fire_spot_1 (embedded lightdef),
// animals/fx_bio_fly_dark_50x50 + sword_quest_egg_glow (unproven, out pending probes).
// RULE: grep every new .efx for 'pcloud' AND explicit 'def ' lines BEFORE wiring.
#precache( "fx", "env/light/fx_light_god_ray_sm_single" );
#precache( "fx", "env/light/fx_light_god_rays_dust_motes" );
// P2 boot-up cascade (docs/46 differentiator 2): aviation blink strips ignite at t+18
// (already zoned for the lockdown module; duplicate precache is harmless).
#precache( "fx", "light/fx_glow_blink_red_5" );
// --- INFESTATION FX (user 2026-07-29, rides the ACCINF01/02 model batches): fungus-family
//     recolors/sizes + the Paradise finale organ set. ALL def-grep-verified SAFE (bare
//     dynamicLight2 exactly like the proven md fungus; the freeze class needs `def <lightdef>`).
#precache( "fx", "zombie/fx_fungus_pod_ambient_sm_zod_zmb" );
// (green variant REMOVED - pcloud dust-mote material ref; sm substitutes at L4)
#precache( "fx", "zombie/fx_fungus_pod_ambient_lg_zod_zmb" );
#precache( "fx", "zombie/fx_egg_ready_zod_zmb" );
// (fx_sword_quest_egg_ground_glow + dlc2/island/fx_spores_cloud_exp_md REMOVED pre-wire -
//  pcloud/tail crash classes; fungus_explo below [0 pcloud, 0 defs] is the finale substitute)
#precache( "fx", "zombie/fx_fungus_pod_explo_md_zod_zmb" );

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
    level thread power_bootup_cascade(); // P2 (docs/46): the district-by-district reboot on power_on
    // RE-ENABLED (M6 visual sweep 2026-07-18): the 2026-07-02 crash these props were bisect-suspected
    // for was later PINNED on a clientfield-pool overflow (2026-07-17 post-mortem, memory
    // sound-bank-cache-poisoning-crash) - NOT these props. Both models stayed zoned the whole time.
    level thread spawn_exchange_props(); // T7 prop-pack Exchange decor (re-enabled M6)
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
    // all hide silently). Vault interior: x[-720,300] y[-448,360], floor top z=-160 (NOT -240).
    // M6 (2026-07-18): the holo screen MOVED off (100,-300) - the transfer-items ATM station
    // (98,-280, docs/37, added 2026-07-09 AFTER these origins were picked) now occupies that
    // spot. New home = SE open floor, RAISED to z=-170 (the 12x9 screen floats = hologram
    // read; it was a 9u-tall plaque at ankle height on the floor). Rack got an M6 clip
    // (m6_ex_rack); the tiny floating holo stays walk-through.
    n = 0;
    // z FIXED 2026-07-19: the exchange/vault floor is z=-160, NOT -240 (the stale comment above
    // + memory `lab-exchange-teleporter`). At -240/-170 both props sat 80u/10u UNDER the slab
    // (invisible all along); the m6_ex_rack clip guarded empty air below the floor too.
    n += spawn_exchange_prop( "p7_zm_moo_server_comm_02", ( -400, 200, -160 ), ( 0, 270, 0 ) );  // rack, open floor N half, faces south [clip m6_ex_rack]
    n += spawn_exchange_prop( "p7_cru_monitor_holo_screen_01", ( -300, -380, -90 ), ( 0, 90, 0 ) ); // floating holo, SE open floor, faces north (floats 70 above the -160 floor)

    acc_utility::log( "atmosphere: exchange props spawned (" + n + ")" );
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

function apply_fog()
{
    level endon( "end_game" );

    // EARLY GATE (user 2026-08-02 "start everything at once"): fog DOES need players in
    // (a frame-0 SetVolFog was the original "no haze" bug), but players spawn DURING the
    // loading blackscreen - waiting for "initial_blackscreen_passed" (set only AFTER the
    // fade + control unfreeze, _zm.gsc:530) made the haze visibly POP IN while you were
    // already walking. Gate on the first player entity instead: the 0.1s authority loop
    // below asserts the haze under the blackscreen, so it's up the frame the screen fades
    // (and re-asserts over anything stock applies during the fade).
    acc_utility::wait_players_in();

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
    // Already fully settled -> hold the end state (cheap + change-gated, and blocks any re-fog):
    // residual thin haze (docs/46 P0 default) or the legacy hard-disable (acc_fog_residual_on 0).
    if ( isdefined( level.acc_fog_settle_done ) && level.acc_fog_settle_done )
    {
        hold_settled_fog();
        return;
    }

    interval  = getdvarfloat( "acc_fog_settle_interval",  ACC_FOG_SETTLE_INTERVAL );
    step      = getdvarfloat( "acc_fog_settle_step",      ACC_FOG_SETTLE_STEP );
    max_steps = getdvarint(   "acc_fog_settle_max_steps", ACC_FOG_SETTLE_MAX_STEPS );
    if ( interval < 0.1 ) interval = 0.1;   // never faster than the tick

    // Residual mode ends the descent EARLY (a shallow sink to "thin", not "gone").
    if ( getdvarint( "acc_fog_residual_on", ACC_FOG_RESIDUAL_ON ) == 1 )
        depth = getdvarfloat( "acc_fog_residual_depth", ACC_FOG_RESIDUAL_DEPTH );
    else
        depth = getdvarfloat( "acc_fog_settle_depth",   ACC_FOG_SETTLE_DEPTH );

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

        // Stop at the target depth (residual: shallow; legacy: invisible), or the cap.
        sunk = base_start - level.acc_fog_settle_base;
        if ( sunk >= depth || level.acc_fog_settle_steps >= max_steps )
        {
            level.acc_fog_settle_done = true;
            hold_settled_fog();
            acc_utility::log( "atmosphere fog: settled after " + level.acc_fog_settle_steps + " steps (residual haze " + getdvarint( "acc_fog_residual_on", ACC_FOG_RESIDUAL_ON ) + ")" );
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

// The settled-state holder (docs/46 P0): once the power-on descent finishes, re-assert either
// the thin RESIDUAL haze (default - the light pools keep a medium for the rest of the match)
// or the legacy full disable. Runs every 0.1s from the single fog authority; acc_set_vol_fog's
// change-gate makes the steady state one engine call, not ten per second. Same colour as the
// pre-power haze (cold blue-grey), just thinner (lower opacity) and longer-throw (wider
// halfway_dist), with the base parked acc_fog_residual_depth below its start. NOTE: after the
// Paradise WIN (paradise_fog_off's instant disable), this quietly restores the city's residual
// haze on the next tick - intended: the surface keeps its atmosphere post-victory.
function hold_settled_fog()
{
    if ( getdvarint( "acc_fog_residual_on", ACC_FOG_RESIDUAL_ON ) != 1 )
    {
        disable_fog();
        return;
    }

    base_start = getdvarfloat( "acc_fog_base_height", ACC_FOG_BASE_HEIGHT );
    r_depth    = getdvarfloat( "acc_fog_residual_depth",        ACC_FOG_RESIDUAL_DEPTH );
    r_opacity  = getdvarfloat( "acc_fog_residual_opacity",      ACC_FOG_RESIDUAL_OPACITY );
    r_halfway  = getdvarfloat( "acc_fog_residual_halfway_dist", ACC_FOG_RESIDUAL_HALFWAY_DIST );

    start_dist     = getdvarfloat( "acc_fog_start_dist",     ACC_FOG_START_DIST );
    halfway_height = getdvarfloat( "acc_fog_halfway_height", ACC_FOG_HALFWAY_HEIGHT );
    r              = getdvarfloat( "acc_fog_r", ACC_FOG_R );
    g              = getdvarfloat( "acc_fog_g", ACC_FOG_G );
    b              = getdvarfloat( "acc_fog_b", ACC_FOG_B );

    acc_set_vol_fog( start_dist, r_halfway, halfway_height, base_start - r_depth, r, g, b, r_opacity );
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

    // EARLY GATE (2026-08-02, matches the fog loop): a LOOPING emitter reaches every
    // client for as long as it loops, so late-connecting co-op clients still hear it -
    // start it under the blackscreen so the bed is already playing at fade-in.
    acc_utility::wait_players_in();

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

    // The theme is a ONE-SHOT 2D server sound: it only reaches clients connected at
    // start time, so it KEEPS the blackscreen-passed gate (the earliest all-clients-
    // guaranteed moment in co-op - an early solo-style start would skip late loaders).
    // The extra +1s settle wait was REMOVED (user 2026-08-02 "start everything at
    // once"): the flag fires the same instant controls unfreeze, so the theme now
    // starts the moment you can walk instead of a second later.
    level flag::wait_till( "initial_blackscreen_passed" );

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
    // EARLY GATE (2026-08-02): these are persistent LOOPS at fixed world points - a late
    // client sees an ongoing loop like any map FX. Placing them under the blackscreen
    // means the neon glows / haze / steam are already alive at fade-in instead of
    // popping on while you're walking (user "start everything at once").
    acc_utility::wait_players_in();
    if ( getdvarint( "acc_atmo_fx", 1 ) != 1 )
        return;

    level._effect[ "acc_glow_teal" ]    = "acc/light/fx_perk_glow_teal";
    level._effect[ "acc_glow_magenta" ] = "acc/light/fx_perk_glow_magenta";
    level._effect[ "acc_glow_amber" ]   = "acc/light/fx_perk_glow_amber";
    level._effect[ "acc_glow_blue" ]    = "acc/light/fx_perk_glow_blue";
    level._effect[ "acc_glow_red" ]     = "acc/light/fx_perk_glow_red";
    level._effect[ "acc_haze" ]         = "dirt/fx_dust_linger_int_sector";
    level._effect[ "acc_steam" ]        = "steam/fx_steam_leak_md_factory_zmb";
    // FX pass (2026-07-19): per-zone ambient loops (HB21 library). Registered here,
    // placed below; all ride the same acc_atmo_fx gate. Zone lines in zone_source.
    level._effect[ "acc_dust_line" ]    = "dirt/fx_dust_fall_line_sm";
    level._effect[ "acc_dust_veiled" ]  = "dirt/fx_dust_fall_ceiling_veiled";
    level._effect[ "acc_dust_lit" ]     = "dirt/fx_dust_fall_lg_lit";
    level._effect[ "acc_flicker_sodium" ] = "light/fx_light_flickering_hat_light_sodium";
    level._effect[ "acc_flicker_rect" ] = "light/fx_light_sgen_dayroom_rectangle_flicker";
    level._effect[ "acc_steam_ac" ]     = "steam/fx_steam_aircond";
    level._effect[ "acc_steam_manhole" ] = "steam/fx_steam_manhole_cover";
    level._effect[ "acc_steam_line" ]   = "steam/fx_steam_vent_floor_line_100";
    level._effect[ "acc_drip_line" ]    = "water/fx_water_drip_line_25";
    level._effect[ "acc_drip_ceiling" ] = "water/fx_water_drip_ceiling";
    level._effect[ "acc_wire_spark" ]   = "electric/fx_elec_gp_wire_sparking_xsml_anim_loop";
    level._effect[ "acc_spark_loop" ]   = "electric/fx_elec_spark_loop_sm";
    level._effect[ "acc_fog_wind" ]     = "fog/fx_fog_ground_wind_lt_sm";
    level._effect[ "acc_fog_coolant" ]  = "fog/fx_fog_coolant_vent_md";
    level._effect[ "acc_fog_stairs" ]   = "fog/fx_fog_ground_low_rolling_stairs";
    level._effect[ "acc_fungus_pod" ]   = "zombie/fx_fungus_pod_ambient_md_zod_zmb";
    // P0 sparkle batch (docs/46 Phase 0, 2026-07-29):
    level._effect[ "acc_flare" ]        = "lensflares/fx_lensflare_fluorescent";
    level._effect[ "acc_flare_cool" ]   = "lensflares/fx_lensflare_light_cool_lg";
    // (acc_fire_barrel REMOVED - pcloud spark materials = THE Alley crash, 4/4 sessions;
    //  acc_flies / acc_egg_glow stay out as unproven until single-fx probe tests)
    level._effect[ "acc_god_ray" ]      = "env/light/fx_light_god_ray_sm_single";
    level._effect[ "acc_god_motes" ]    = "env/light/fx_light_god_rays_dust_motes";
    level._effect[ "acc_blink_red" ]    = "light/fx_glow_blink_red_5";   // P2 cascade: Helipad strips
    // Infestation family (2026-07-29): size/color variants of the proven fungus pod + the
    // Paradise finale organs (egg_ready/spores/explo/ground-glow used by _acc_paradise weave).
    level._effect[ "acc_fungus_sm" ]    = "zombie/fx_fungus_pod_ambient_sm_zod_zmb";
    // (green variant REMOVED - pcloud dust-mote ref, crash class; sm substitutes at L4)
    level._effect[ "acc_fungus_lg" ]    = "zombie/fx_fungus_pod_ambient_lg_zod_zmb";
    level._effect[ "acc_egg_ready" ]    = "zombie/fx_egg_ready_zod_zmb";
    // (spore_burst REMOVED - pcloud dust-mote ref; fungus_explo [0 pcloud] is the finale substitute)
    level._effect[ "acc_fungus_explo" ] = "zombie/fx_fungus_pod_explo_md_zod_zmb";

    // HERO glow SPRITES were removed (user 2026-06-28: "put them in spots where they don't show... move it above
    // the ceiling"). The orbs showed as bright floating sprites in mid-room. The colored glow now comes purely from
    // the Phase-1 BAKED neon lights (gen_neon_lights.js) - a light entity casts the colored pool with NO visible
    // on-map source - which also carry each zone's UNIQUE color. (To re-add a recessed neon accent later, place a
    // glow just inside a wall/ceiling so only its halo spills.) Steam + haze below are plumes/drift, not orbs - kept.
    // AMBIENT drifting interior dust/haze (subtle life):
    fx_at( "acc_haze", (     0, 1950, 120 ) );  // Corp
    fx_at( "acc_haze", ( -1596,  928, 110 ) );  // Market
    fx_at( "acc_haze", (  1760, 928, 110 ) );  // Alley
    fx_at( "acc_haze", (     0, 1950,-180 ) );  // Trench
    // STEAM vents (placed low so the plume rises):
    fx_at( "acc_steam", (  1700, 1000,  20 ) );  // Alley vent
    fx_at( "acc_steam", (  1300, 2600,  20 ) );  // Vault
    fx_at( "acc_steam", (  -200, 1948,-230 ) );  // Trench

    // -- FX pass (2026-07-19): per-zone ambient accent loops. Origins derive from the
    //    _acc_surface_deco / _acc_abyss_deco prop layout (plumes rise from vents/machines/
    //    wreckage, not empty air); every placement is off the doorway aprons and training-
    //    lane centers (subtle accents, per the visual-sweep plan). Same acc_atmo_fx gate.
    // PLAZA - dust sifting down over the memorial-angel fountain island (-40,130, ceil 256):
    fx_at( "acc_dust_line",      (   -40,  130,  200 ) );
    // MARKET - sodium hat-light flicker just under the caged ceiling fixture above the tarp
    // stall row (fixture at -1720,700,232), + AC steam off the W-wall stove/kitchen corner:
    fx_at( "acc_flicker_sodium", ( -1720,  700,  228 ) );
    fx_at( "acc_steam_ac",       ( -2110, 1385,  110 ) );
    // ALLEY - ceiling drip line mid-corridor between the two cage lights (1760,650/1150),
    // + wire-spark loop atop the 121u AC unit by the E-wall electric boxes (2148,545)
    // (re-centered/moved 2026-07-19 FIX BATCH 3 with the real-E-wall prop re-place):
    fx_at( "acc_drip_line",      (  1760, 900, 230 ) );
    fx_at( "acc_wire_spark",     (  2148, 545, 150 ) );
    // BUS STATION - manhole steam on the open S-hall floor W of the boarding queue, +
    // a floor vent line along the S trench-rim approach (E of the parking block at 200,1686;
    // clear of the x[-132,132] queue/bridge lane and the E stair mouth x>703):
    fx_at( "acc_steam_manhole",  (  -350, 1560,    0 ) );
    fx_at( "acc_steam_line",     (   330, 1690,    0 ) );
    // VAULT - veiled ceiling dust under the N cage light (1650,3050,234), + a lit dust
    // shaft over the mid-room server island (racks at 1450/1580,2650):
    fx_at( "acc_dust_veiled",    (  1650, 3050,  228 ) );
    fx_at( "acc_dust_lit",       (  1520, 2650,  215 ) );
    // HELIPAD - ground fog drifting the SW open pad (W training lane, clear of the bomber
    // hull at -1524,2845), + spark loop on the W-wall field generator (-1900,2900):
    fx_at( "acc_fog_wind",       ( -1750, 2550,    0 ) );
    fx_at( "acc_spark_loop",     ( -1885, 2905,   45 ) );
    // LAB - coolant fog at the W-wall specimen test-chamber base (-730,3520), + fluorescent
    // rectangle flicker above the E-wall medical row (cart/respirator at ~780,3410-3465):
    fx_at( "acc_fog_coolant",    (  -712, 3540,    5 ) );
    fx_at( "acc_flicker_rect",   (   760, 3450,  200 ) );
    // TRENCH MOUTH - low fog rolling down the W-south stair channel top (x[-761,-665] S lip):
    fx_at( "acc_fog_stairs",     (  -713, 1760,  -40 ) );
    // ABYSS (no lights / no glow FX down here by design - these are organic ambience):
    // L3 fungus pod beside the W-wall tentacle mass; L5 pod MOVED 2026-07-29 with the
    // ACCINF01 hive01 re-home (it glowed over the empty D4 keep-clear; now it rides the
    // re-homed hive on the L5 W wall - the two MUST move together); L4 ceiling drip, W bay:
    fx_at( "acc_fungus_pod",     (  -740, 1845, -716 ) );
    fx_at( "acc_fungus_pod",     (  -700, 2050,-1194 ) );
    fx_at( "acc_drip_ceiling",   (  -500, 1990, -740 ) );
    // -- INFESTATION GRADIENT loops (2026-07-29, ride the ACCINF01/02 model batches; every
    //    loop anchors a glow-core cluster so unproven-glow neighbors read in the dark):
    fx_at( "acc_fungus_sm",      (   690, 2110, -476 ) );  // L2 strangled-generator cluster
    fx_at( "acc_fungus_sm",      (  -450, 1770, -476 ) );  // L2 cable-run cluster
    fx_at( "acc_fungus_sm",      (   660, 1795, -716 ) );  // L3 second nest (E-S bay)
    // (green variant SWAPPED to sm 2026-07-29: fx_fungus_pod_ambient_green carries a
    //  gfx_dust_mote_1_pcloud_em reference = the particlecloud crash class; sm has zero)
    fx_at( "acc_fungus_sm",      (   505, 1780, -950 ) );  // L4 lit-vessel clutch
    fx_at( "acc_fungus_sm",      (  -655, 2095, -950 ) );  // L4 hive02 corner
    fx_at( "acc_fungus_lg",      (   660, 2070,-1194 ) );  // L5 E field / N-wall massing
    // (flies over the dead queen REMOVED - fx_bio_fly = the particlecloud crash class)
    // Paradise (the heart - permanent, matching the settled-fog precedent):
    fx_at( "acc_fungus_lg",      (     0,-1900,-1195 ) );  // the heart nest (re-homed 2026-08-02 w/ the Paradise compression)
    fx_at( "acc_fungus_sm",      (  -620,-1015,-1195 ) );  // W satellite nest
    fx_at( "acc_fungus_sm",      (   630,-1005,-1195 ) );  // E satellite nest
    // (flies over the heart REMOVED - same crash class)

    // -- P0 sparkle batch, AMBIENT half (docs/46 Phase 0, 2026-07-29; RC5 "nothing moves" +
    //    the rain-floor graft). These read as unpowered decay, so they run from the start.
    //    The POWERED half (lensflares, god rays) moved to the P2 boot-up cascade below
    //    (docs/46 differentiator 2) - pre-power the city is now truly dead, and each district's
    //    powered FX IGNITE in sequence when the switch is thrown. Smoke column DEFERRED to
    //    Phase 6 (needs the Helipad's open sky).
    // ALLEY FREEZE - FINAL VERDICT (2026-07-29, crash 4/4 with a READABLE material name at
    // last): `Com_ERROR: Vertex type 5 ('particlecloud') ... in material
    // 'ec/gfx_fxt_spark_2_pcloud_em'` -> that material is referenced by exactly ONE wired fx:
    // `fire/fx_fire_barrel` (its ember/spark elements). THE FIRE WAS PRESENT IN EVERY CRASHING
    // SESSION - the single common denominator; the earlier def-light and flies removals were
    // de-risking of adjacent classes, but the barrel fire was the killer. THE TRUE
    // DISCRIMINATOR (validated against every proven fx = 0 hits, every crasher >= 1): grep the
    // .efx for 'pcloud' MATERIAL references - a *_pcloud_* material lacks its particlecloud
    // vertex-decl techset variant in a usermap .ff and Com_ERRORs on first render. The barrel
    // fire is REMOVED (the burn-barrel prop stays; a pcloud-free fire fx can be auditioned
    // later); flies/sword-glow stay out as unproven. Memory: fx-embedded-light-def-freeze.
    // RAIN FLOOR (docs/46 graft - "just rained" ships day 1): drip lines at the two Plaza
    // doorway eaves (over the Market/Alley corridor mouths, Plaza side) + both trench rims
    // (clear of the x[-132,132] bridge/queue lane):
    fx_at( "acc_drip_line",      ( -1250,  430,  230 ) );  // Plaza -> Market door eave
    fx_at( "acc_drip_line",      (  1070,  430,  230 ) );  // Plaza -> Alley door eave
    fx_at( "acc_drip_line",      (   300, 1728,   -5 ) );  // trench N rim lip
    fx_at( "acc_drip_line",      (  -300, 2168,   -5 ) );  // trench S rim lip

    acc_utility::log( "atmosphere FX placed (drifting haze + steam vents + 17 zone ambient loops + P0 ambient: fire barrel, flies, 4 drips; powered FX ride the P2 cascade)" );
}

function fx_at( key, origin )
{
    if ( isdefined( level._effect[ key ] ) )
        PlayFX( level._effect[ key ], origin );
}

// ---------------------------------------------------------------------------
// P2 THE CASCADING BOOT-UP (docs/46 differentiator 2, v1 - 2026-07-29).
// When power comes on, the city doesn't just switch on - it REBOOTS district by
// district, radiating outward from the Bus Station over ~21s: spark salvos, sign
// false-starts, steam releases, and each zone's powered FX (lensflares, god rays)
// igniting in graph order. The engine's binary lighting-state flip still happens
// at t+0 underneath (masked by apply_vision's 15s warm-up lerp); this FX cascade
// rides OVER it. The fog settle was re-paced to ~20s (ACC_FOG_SETTLE_INTERVAL 5.0
// x 4 nudges to the residual depth) so the air clears exactly as the reboot
// completes. INTERIM FINALE (pre-Phase-4): a map-wide sign-flare beat; when the
// holo city-double ships (P4a), its de-rez ignition replaces this with ONE added
// line at t+21. All beats are one-wait-one-call lines - trivially re-orderable.
// Bursts ride acc_utility::play_fx_burst (bare server PlayFX one-shots don't
// render - memory server-playfx-does-not-render; loops via fx_at DO, proven).
// Gate: same acc_atmo_fx master switch as apply_fx. NO clientfields, NO dvars.
// ---------------------------------------------------------------------------

function power_bootup_cascade()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );
    if ( getdvarint( "acc_atmo_fx", 1 ) != 1 )
        return;

    level flag::wait_till( "power_on" );
    acc_utility::log( "atmosphere: POWER ON -> boot-up cascade begins (t+0 Bus Station)" );

    // t+0 - BUS STATION (the switch's own district wakes first): spark salvo at the
    // departure board + the floor vent, a manhole steam RELEASE, and the board's
    // fluorescent flicker ignites (a second acc_flicker_rect loop, board-mounted).
    level thread acc_utility::play_fx_burst( "acc_wire_spark",  (     0, 1235,  215 ), 1.5 );
    level thread acc_utility::play_fx_burst( "acc_spark_loop",  (   330, 1690,   10 ), 1.5 );
    level thread acc_utility::play_fx_burst( "acc_steam_manhole", ( -350, 1560,    0 ), 2.5 );
    fx_at( "acc_flicker_rect",   (     0, 1235,  222 ) );

    // t+2.5 - TRENCH RIM: the infection stirs with the city (differentiator 3 tie-in) -
    // fungus pulses at both rim lips, then the wake DESCENDS the shaft level by level
    // (the infestation gradient answering the reboot - it reaches the L5 hive at t+14).
    wait( 2.5 );
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (   300, 1728,  -40 ), 2.0 );
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (  -300, 2168,  -40 ), 2.0 );
    level thread descent_hive_wake();

    // t+3.5 - BUS STATION flares catch (the hub is lit; the wave spreads outward).
    wait( 1.0 );
    fx_at( "acc_flare_cool",     (     0, 1360,  175 ) );
    fx_at( "acc_flare_cool",     (     0, 2280,  175 ) );

    // t+6 - MARKET + ALLEY. Both hero signs STUTTER-IGNITE with two false starts
    // (short flare bursts) before the persistent bloom catches - the "dying city
    // remembers how to be alive" beat.
    wait( 2.5 );
    level thread sign_stutter_ignite( "acc_flare", ( -1720,  700,  150 ) );   // Market @ S cage light
    level thread acc_utility::play_fx_burst( "acc_wire_spark", ( -1560, 1420, 150 ), 1.2 );  // diner sign sparks
    wait( 0.9 );
    level thread sign_stutter_ignite( "acc_flare", (  1610,  995,  150 ) );   // Alley @ the burning barrel
    level thread acc_utility::play_fx_burst( "acc_spark_loop", (  2040, 1060, 120 ), 1.2 );  // scaffold sparks

    // t+10 - PLAZA + VAULT.
    wait( 3.1 );
    fx_at( "acc_flare",          (   -40,  130,  150 ) );  // fountain angel (cyan)
    level thread acc_utility::play_fx_burst( "acc_spark_loop", (   212,  150, 150 ), 1.0 );  // LED bar pops
    fx_at( "acc_flare",          (  1400, 2700,  150 ) );  // Vault mid cage light (green)
    fx_at( "acc_god_ray",        (  1650, 3050,  236 ) );  // Vault god-ray shaft
    level thread acc_utility::play_fx_burst( "acc_wire_spark", ( 1136, 2880, 140 ), 1.5 );   // security desk wakes

    // t+14 - LAB.
    wait( 4.0 );
    fx_at( "acc_flare",          (     0, 3830,  175 ) );  // Lab N pool (purple; moved with the 2026-08-02 lab compression - inner N wall now y3868)
    fx_at( "acc_god_motes",      (   760, 3450,  230 ) );  // motes over the medical row
    level thread acc_utility::play_fx_burst( "acc_spark_loop", (  150, 3450,  40 ), 1.5 );   // teleporter pad stirs

    // t+18 - HELIPAD: flare + the aviation blink strips begin (pad corners; they move
    // to the parapet against real sky when Phase 6 opens the roof).
    wait( 4.0 );
    fx_at( "acc_flare",          ( -1500, 2600,  150 ) );
    fx_at( "acc_blink_red",      ( -1900, 2330,  238 ) );
    fx_at( "acc_blink_red",      ( -1150, 2330,  238 ) );
    fx_at( "acc_blink_red",      ( -1900, 3350,  238 ) );
    fx_at( "acc_blink_red",      ( -1150, 3350,  238 ) );
    level thread acc_utility::play_fx_burst( "acc_spark_loop", ( -1524, 2845,  80 ), 1.5 );  // bomber wreck arcs

    // t+21 - FINALE (interim until P4a ships the holo city-double): a map-wide
    // sign-flare surge as the fog settle completes - every district's bloom pops
    // once, together. (P4a adds: the holo's de-rez loop snaps on HERE.)
    wait( 3.0 );
    level thread acc_utility::play_fx_burst( "acc_flare", (   -40,  130, 150 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare", ( -1720,  700, 150 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare", (  1610,  995, 150 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare_cool", ( 0, 1360, 175 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare_cool", ( 0, 2280, 175 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare", (  1400, 2700, 150 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare", ( -1500, 2600, 150 ), 0.8 );
    level thread acc_utility::play_fx_burst( "acc_flare", (     0, 3830, 175 ), 0.8 );

    acc_utility::log( "atmosphere: boot-up cascade complete (t+21 finale fired)" );
}

// The infestation answers the reboot: fungus-pulse bursts walk DOWN the shaft one level
// per beat (L2 t+5 -> L3 t+8 -> L4 t+11 -> L5 hive t+14, offsets from power_on; this thread
// starts at the cascade's t+2.5 rim beat). Pure server bursts on the proven md fungus fx.
function descent_hive_wake()
{
    level endon( "end_game" );
    wait( 2.5 );   // t+5 - L2 strangled generator
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (   690, 2115, -465 ), 2.0 );
    wait( 3.0 );   // t+8 - both L3 nests
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (  -740, 1845, -710 ), 2.0 );
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (   660, 1795, -710 ), 2.0 );
    wait( 3.0 );   // t+11 - L4 vessels + hive02
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (   505, 1780, -950 ), 2.0 );
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (  -655, 2095, -950 ), 2.0 );
    wait( 3.0 );   // t+14 - the wake reaches the re-homed L5 hive
    level thread acc_utility::play_fx_burst( "acc_fungus_pod", (  -700, 2050,-1190 ), 2.0 );
}

// Two short false-start blooms, then the persistent flare catches. The plan's
// "stutter-ignite" - a loop can't flicker, so the false starts are short-lived
// play_fx_burst pops and the real fx_at loop lands on the third beat.
function sign_stutter_ignite( key, origin )
{
    level endon( "end_game" );
    level thread acc_utility::play_fx_burst( key, origin, 0.35 );
    wait( 0.8 );
    level thread acc_utility::play_fx_burst( key, origin, 0.35 );
    wait( 0.9 );
    fx_at( key, origin );
}
