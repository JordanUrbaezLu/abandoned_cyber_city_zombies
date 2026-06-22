// =============================================================================
// _acc_power.gsc - Bus Station (corp_zone) power.
//
// HISTORY: this module used to OVERRIDE stock power for a custom DUAL-switch (delete the
// stock use_elec_switch OR-triggers; gate power behind two acc_power_switch triggers; later
// it also spawned a lever model + played the flip/power-on sounds, because the .map had no
// lever to animate).
//
// >>> DECISION 2026-06-19 (user). The Bus Station ended up with TWO switches stacked:
//     (1) the stock power_switch PREFAB, WEST-wall-mounted in the Bus Station's NORTH/Lab half WITH the
//         native flip animation + power-on sound (moved 2026-06-21, origin (-752 2250 1), angles
//         (0 90 0) facing east into the room). The trench's only north exit is the EAST stair channel,
//         so players climb out on the NE side and must cross the dark Lab half to the FAR WEST wall to
//         flip it - they can't power on the instant they leave the stairs. Was (790 1600 1) Plaza side,
//         then (790 2250 1) next to the east stairs (too easy), now the opposite wall.
//     (2) our custom acc_power_switch trigger, whose generator brush has degenerate winding so
//         its centroid floated - the script-spawned lever appeared MID-AIR.
//     User chose to KEEP THE WALL PREFAB (native anim+sound, already correctly placed) and
//     REMOVE our mid-air duplicate. So this module now STANDS DOWN:
//       - does NOT delete the prefab's stock use_elec_switch trigger -> stock _zm_power powers
//         the map natively (animation + sound) when the player flips the wall switch;
//       - does NOT spawn any lever model;
//       - deletes our leftover acc_power_switch trigger(s) at runtime so there is no mid-air
//         use-prompt / duplicate.
//     Pure GSC (NO .map edit) => LED-safe, and no interference with concurrent Radiant edits.
//     (acc_auto_power stays 0, so the player still must flip the wall switch.)
//
// >>> TO RESTORE THE CUSTOM DUAL-SWITCH later: recover the prior version of this file from git
//     (it deleted use_elec_switch, gated power behind acc_power_switch via relay_watcher, and
//     spawned p7_zm_der_pswitch_* + played zmb_switch_flip/zmb_turn_on), and place a second
//     acc_power_switch trigger on the far side of the trench.
//
// Public API: init() - call once from acc_main::init().
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_power;

function init()
{
    level thread setup();
}

function setup()
{
    level endon( "end_game" );

    // Let stock _zm_power::electric_switch_init thread the prefab's use_elec_switch first
    // (it powers the map natively on flip), then just clear OUR leftover mid-air trigger(s).
    wait 1;

    removed = 0;
    foreach ( t in GetEntArray( "acc_power_switch", "targetname" ) )
    {
        if ( IsDefined( t ) )
        {
            t Delete();   // remove the mid-air duplicate use-prompt (our old custom switch)
            removed++;
        }
    }

    acc_utility::log( "power: standing down to the stock wall prefab (native anim+sound); cleared " + removed + " leftover acc_power_switch trigger(s)" );
}
