// =============================================================================
// _acc_perk_doors.gsc - the 10-perk specialty REGISTRY (doors fully gone)
//
// *** RETIRED 2026-07-24 (user): the per-round random-4-of-10 alcove-door
// rotation AND the 2-Mega-Bottle permanent door unlock are superseded by the
// MAP-WIDE PERK SCATTER (_acc_perk_scatter.gsc). ***
// *** GEOMETRY REMOVED 2026-07-25 (user "clean up the lab"): the alcove
// partition fins, the 10 acc_perk_door_* gate slabs and the acc_ec_right_wall
// seal were deleted from the .map (tombstones in the map source), so the
// force-open + EC-seal code that used to live here is gone too. The Lab's two
// scatter pads moved apart with the cleanup: one on the N wall, one inside
// the S-wall decon tent (_acc_perk_scatter.gsc::build_pads). The full door
// rotation implementation lives in git history before 2026-07-24. ***
//
// What this module still owns:
//   - level.acc_perk_door_specs: the canonical 10-perk specialty registry.
//     _acc_paradise reads it (give-all-perks, no #using - via the level var),
//     and _acc_perk_scatter's roster matches it. KEEP IT POPULATED.
//
// Public API:
//   init() - set the registry. Called ONCE from acc_main::init().
// =============================================================================

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_perk_doors;

// The 10 perk specialties (order = the old Lab row left-to-right; cosmetic).
// PhD Flopper hijacks specialty_electriccherry; Electric Cherry (the real 10th
// perk, _acc_perk_electric_cherry) rides specialty_combat_efficiency.
function get_perk_door_specs()
{
    s = [];
    s[ 0 ] = "specialty_quickrevive";
    s[ 1 ] = "specialty_armorvest";
    s[ 2 ] = "specialty_fastreload";
    s[ 3 ] = "specialty_doubletap2";
    s[ 4 ] = "specialty_staminup";
    s[ 5 ] = "specialty_additionalprimaryweapon";
    s[ 6 ] = "specialty_deadshot";
    s[ 7 ] = "specialty_widowswine";
    s[ 8 ] = "specialty_electriccherry";
    s[ 9 ] = "specialty_combat_efficiency";
    return s;
}

function init()
{
    acc_utility::log( "perk_doors: init (registry-only - alcove geometry removed 2026-07-25)" );

    level.acc_perk_door_specs = get_perk_door_specs();
}
