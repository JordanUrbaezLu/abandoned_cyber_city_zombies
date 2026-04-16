// =============================================================================
// zm_abandoned_cyber_city.gsc - map entry script (server-side)
//
// Mirrors the pattern of stock zm maps (e.g. maps/zm/zm_zod.gsc). The Radiant
// `.map` file references this via the "script_runner" / "map script" hook.
//
// This file should stay small: it registers the map, wires stock callbacks,
// and hands off to scripts/zm/zm_abandoned_cyber_city/_acc_main.gsc for all
// custom systems.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_zonemgr;

// Map-specific custom systems live under scripts/zm/zm_abandoned_cyber_city/.
#using scripts\zm\zm_abandoned_cyber_city\_acc_main;
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;

#insert scripts\zm\_zm_utility.gsh;

#precache( "string", "ZOMBIE_ACC_INTRO_LINE" ); // TODO(acc-verify): define in localized_strings

// Entry point. Name `main()` is required; BO3 engine calls it on map load.
main()
{
    level.map_name = "zm_abandoned_cyber_city";

    // Standard zm init. Do not reorder these.
    _load::main();

    // Register our custom namespace (prefix `acc_`) callbacks BEFORE _zm::main()
    // so we can hook round/spawn events on the first tick.
    level thread _acc_main::pre_init();

    // Kick off stock zombies framework.
    _zm::main();

    // Chain spawn-count override before any round computes zombie totals.
    _acc_early_round_pacing::post_zm_main();

    // Custom systems spin up after stock has finished bootstrapping.
    level thread _acc_main::init();
}
