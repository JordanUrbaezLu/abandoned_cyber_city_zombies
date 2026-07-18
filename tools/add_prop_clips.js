#!/usr/bin/env node
// add_prop_clips.js - invisible collision clips around the underground interactable props.
//
// WHY: each interactable is a bare spawn("script_model")+setmodel() (no collision set), so it
// is only solid if its xmodel ships a collision LOD. The decorative ones (e.g. the Altar's
// p7_cai_sign_inteactive_kiosk) have none -> the player walks through them (user 2026-06-19).
// Fix = an invisible `clip` brush snug around each prop (collision is geometry = our lane; this
// does NOT touch the system agent's spawn GSC). Re-runnable: it strips the old PROP CLIPS section
// first, so when props re-home into the Stalls/Cages just update the coords below + re-run.
//
// COORDS MIRROR _acc_glitch_altar.gsc spawn_altars() (the live spawn call site). Keep in sync -
// the system agent moves these; re-sync + re-bake after every spawn_altars edit (audit 2026-06-19
// caught a stale-coord drift: terminal unclipped + phantom clips guarding empty air). FRAGILE by
// design - if the props keep drifting, lock the final coords or move collision to the spawn side.
//
// Usage: node tools/add_prop_clips.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_prop_clips.js <in> <out>'); process.exit(1); }

// props: x,y on the z=-240 floor + half-extents (snug to the model silhouette). label for comments.
// RE-SYNCED to the LIVE z=-240 spawn origins (user 2026-06-25 "make hitboxes match the models - no invisible walls"):
//   - exo_station    (-200,-100) PLAZA   - p7_cry_cryogen_pod_exterior (yaw 0)     (_acc_exo::spawn_station_at)
//        (MOVED to the plaza start room 2026-07-13, was the bus-station trench @ (-120,1550,-240); z=0 surface clip)
//   - reactor_plinth   (0,2120)  pit     - p7_cai_sign_inteactive_kiosk (no LOD)  (_acc_reactor::spawn_plinth_at)
//   - pit_cache_w/e (-/+360,1950) pit    - p7_cai_stacking_cargo_crate            (_acc_glitch_altar::spawn_altars)
//   - perk_slot_vendor (-250,1820) pit                                            (_acc_glitch_altar::spawn_altars)
// Props that LEAVE the z=-240 floor leave INVISIBLE WALLS if an old clip stays. Props default to the z=-240
// floor (CLIP_BOT/TOP below); a DEEP prop sets a per-prop `bot` (+ `top`) for its own floor. A deep WORLDSPAWN
// clip (bot < -240) CRASHES the LED bake (brush.cpp:1860, see below), so deep clips are emitted ONE of two ways:
//   - `brushmodel: true` -> a script_brushmodel ENTITY (LED-EXEMPT) in the entity list = REAL collision that bakes.
//   - no flag            -> SKIPPED (walk-through) so the map still bakes.
// The 4 ABYSS stations are clipped via brushmodel (user 2026-06-27 "all deep abyss stations"): Overclock L2 (z-480),
// Ammo Crate bookends (L2 east z-480 & L5 z-1200), Glitch Altar L3 (z-720); L4 = AK-47 wall-buy. The 4 PARADISE
// stations stay skipped for now (add `brushmodel: true` to clip them too). Coords mirror spawn_altars. Half-extents
// are SNUG estimates; if a box over/under-reaches in playtest, just nudge hx/hy + re-run + full bake.
// STATION REMODEL (user 2026-07-09, docs/52): every station got a DISTINCT bounds-measured
// model (tools/xmodel_bin_inspect.js; all spawn SetScale 1.0 so clip == visual - "make sure
// the hitboxes make sense"). Extents below are the measured mesh footprints, snug. NEW
// stations (armory loft, transfer vault, paradise ammo crate, implant bench pads) are clipped
// too; ALL new/updated Paradise + loft clips use `brushmodel: true` (LED-exempt at ANY depth -
// zero bake risk; the shallow legacy worldspawn clips keep baking as before, just resized).
const PROPS = [
  { x: -200, y: -100, hx: 29, hy: 26, bot: 0, top: 114, label: 'exo_station' },  // p7_cry_cryogen_pod_exterior (stasis pod 58x53x114, yaw 0 -> hx29/hy26) - MOVED to the PLAZA start room (user 2026-07-13, was the bus-station trench @ (-120,1550,-240)); surface z=0 floor -> shallow worldspawn clip (navmesh auto-cut, no LED risk). Mirrors _acc_exo::spawn_station_at (-200,-100,0).
  { x:    0, y: 2493, hx: 46, hy: 23, top: -190, label: 'reactor_plinth' }, // p7_ris_generator_lg_01_blue (industrial generator 92x46x50, yaw 0 - long axis X along the back wall). Jukebox NORTH under-room; the jukebox machine sits WEST at (-140,2350), clear. Mirrors _acc_reactor::spawn_plinth_at (0,2493).
  // Data Cache "storages" (user 2026-07-10): model reverted p7_zm_sta_computer_tower_01 -> p7_cai_stacking_cargo_crate
  // (the crate the user preferred). The crate SHIPS a _col LOD so it self-collides; these clips are belt-and-suspenders
  // sized SNUG to the 64x64x48 crate. ALL emitted as brushmodel (LED-exempt, zero bake risk). Coords mirror the
  // spawn_cache_at call sites: pit/bus-trench = _acc_glitch_altar.gsc:78-79; plaza = zm_abandoned_cyber_city::
  // acc_spawn_plaza_props (the 3 plaza clips MIGRATED here from gen_plaza_shrink obstacle clips #0-2; 4th added 2026-07-10).
  { x: -360, y: 1950, hx: 32, hy: 32, bot: -240, top:  -192, brushmodel: true, label: 'pit_cache_w' },   // trench/pit WEST (z=-240 floor)
  { x:  360, y: 1950, hx: 32, hy: 32, bot: -240, top:  -192, brushmodel: true, label: 'pit_cache_e' },   // trench/pit EAST
  { x: -320, y:   30, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_1' },  // plaza surface (z=0)
  { x:   80, y:  230, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_2' },  // plaza surface
  { x:  -80, y:  560, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_3' },  // plaza surface
  { x: -360, y:  460, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_4' },  // plaza surface, 4th cache. MOVED off (-420,460) 2026-07-10 (boss pocket vs the L-wall corner x=-480/y=390), then off (-300,460) 2026-07-12 (crate east edge sat inside the plaza window-barricade planks at (-227.5,446)); -360 clears the barricade ~48u + keeps ~78u to the x=-470 doorway jamb.
  { x:  120, y: 1550, hx: 25, hy: 22, top: -169, label: 'perk_slot_vendor' }, // p7_zm_sta_drop_pod_console_blue (Gorod console 49x44x71, yaw 0). Foundry/Exo room EAST; mirrors _acc_glitch_altar spawn_perk_slot_vendor_at (120,1550).
  { x:  395, y: 1948, hx: 15, hy: 17, bot:  -480, top:  -454, brushmodel: true, label: 'ammo_crate_l2' }, // west_ammo_crate_model ([West] pack ZeRoY S4 crate 29x33x25; x NOT origin-centered: model x[-19.6,+9.3] -> clip center = spawn x-5) - abyss L2 EAST, spawn (400,1948).
  { x: -405, y: 1948, hx: 15, hy: 17, bot: -1200, top: -1174, brushmodel: true, label: 'ammo_crate_l5' }, // west_ammo_crate_model (same offset; spawn (-400,1948)) - abyss L5 WEST, the bottom before Paradise.
  { x: -400, y: 1948, hx: 24, hy: 17, bot: -480, top: -402, brushmodel: true, label: 'overclock_terminal' }, // p7_zm_sta_dragon_network_data_terminal (48x34x78) - abyss L2 WEST.
  { x:  400, y: 1948, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'overclock_l5' }, // dragon network terminal - abyss L5 EAST.
  { x: -400, y: 1948, hx: 81, hy: 33, bot:  -720, top:  -600, brushmodel: true, label: 'glitch_altar_l3' }, // p7_ram_altar (stone altar 162x66x58) - abyss L3; slab x[-781,-112] holds the 162 width fine. TOP RAISED -662->-600 (2026-07-13): the 58u slab top was jump-on-able with the Rocket Shield implant (~80u apex, 2x jump); a 120u-tall invisible cap now makes the top unreachable while the side-approach use-trigger (radius 110) is unaffected.
  { x:  850, y: -1350, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'paradise_overclock' },   // dragon network terminal - PARADISE east-mid.
  { x: -850, y: -1950, hx: 29, hy: 26, bot: -1200, top: -1086, brushmodel: true, label: 'paradise_exo' },         // cryogen stasis pod (yaw 0) - PARADISE west-south.
  { x:  850, y: -1950, hx: 25, hy: 22, bot: -1200, top: -1129, brushmodel: true, label: 'paradise_perk_vendor' }, // drop-pod console - PARADISE east-south.
  // Armory stations in PARADISE (user 2026-07-13): the weapon rack cabinet + the mega-bottle Wonderfizz, west wall.
  // Mirror the loft clips (armory_rack / armory_bottle); spawn_paradise call site (_acc_glitch_altar). Both deep -> brushmodel.
  { x: -850, y: -1350, hx: 69, hy:  9, bot: -1200, top: -1152, brushmodel: true, label: 'paradise_armory_rack' },   // p7_con_cargo_train_armory_cabinet 138x18x48, yaw 0 (long axis X) - PARADISE west-mid.
  { x: -850, y: -1650, hx: 37, hy: 28, bot: -1200, top: -1090, brushmodel: true, label: 'paradise_armory_bottle' }, // p7_zm_vending_wonder (Wonderfizz 74x56x110) - PARADISE west, between the rack and the Exo.
  // Implant Bench pads: THREE per site since 2026-07-09 (slots 2->3). Model = p7_zm_isl_table_operating
  // (79w[X] x 24d[Y] x 42h). PARADISE row = _acc_glitch_altar (-550 -/+ 2*acc_bench_pad_sep=160, -2080),
  // a straight row - unchanged. The IMPLANT LAB row was RE-SPREAD into a staggered ARC 2026-07-10 (room
  // widened east to x180; user "benches cluttered / one against a wall"): mirrors _acc_boss_items::
  // spawn_bench = center pad @ struct(-227.5,-130.67)+off(153,-359) ~(-75,-490); outer pads +/-sep(175)
  // in X, +stag(60) N in Y -> ~(-250,-430) / (100,-430). Coords are dvar-nudgeable live (Plaza:
  // acc_bench_off_*/acc_bench_lab_sep/acc_bench_lab_stagger) - re-sync here + re-run after any nudge.
  { x: -710, y: -2080, hx: 40, hy: 12, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot1' },          // PARADISE Slot 1 (west)
  { x: -550, y: -2080, hx: 40, hy: 12, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot2' },          // PARADISE Slot 2 (center)
  { x: -390, y: -2080, hx: 40, hy: 12, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot3' },          // PARADISE Slot 3 (east; NEW 2026-07-09)
  { x: -250, y: -430, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot1' },              // IMPLANT LAB Slot 1 (west, forward) - staggered arc 2026-07-10
  { x:  -75, y: -490, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot2' },              // IMPLANT LAB Slot 2 (center, deepest/back)
  { x:  100, y: -430, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot3' },              // IMPLANT LAB Slot 3 (east, forward)
  { x:  878, y:  -100, hx: 69, hy:  9, bot:   192, top:   240, brushmodel: true, label: 'armory_rack' },          // p7_con_cargo_train_armory_cabinet (138x18x48) - Armory loft (RE-SYNCED 2026-07-11: loft rebuilt, floor 288->192, stations 870->878 - _acc_armory::spawn_stations); long axis spans the deposit/withdraw pads.
  { x:  878, y:   100, hx: 37, hy: 28, bot:   192, top:   302, brushmodel: true, label: 'armory_bottle' },        // p7_zm_vending_wonder (Wonderfizz 74x56x110) - Armory loft bottle exchange (RE-SYNCED 2026-07-11, same move).
  { x:   98, y:   200, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_points' },      // p7_out_monitor_atm (37x34x103; mesh extends +X from its back-face origin at x=80 -> clip centered x=98) - Exchange vault.
  { x:   98, y:    40, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_shards' },      // ATM - Exchange vault.
  { x:   98, y:  -120, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_bottles' },     // ATM - Exchange vault.
  { x:   98, y:  -280, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_items' },       // ATM - Exchange vault.
  // Jukebox + Paradise PaP (model-clip audit 2026-07-10): both are bare spawn(script_model)+setmodel props whose xmodel
  // ships NO _col LOD (verified via find <model>*_col.xmodel_bin + tools/xmodel_bin_inspect.js) -> walk-through until clipped.
  { x: -139, y:  2240, hx: 12, hy: 17, bot:  -240, top:  -187, brushmodel: true, label: 'jukebox' },              // cp_town_jukebox 22.7x33x53, yaw 0; mesh sits +X of the spawn origin (-150,2240) -> clip center x=-139. North under-room SW (spread from the reactor 2026-07-10).
  // TELEPORTER pads have NO clips (FINAL 2026-07-18): the step-up plates (11u, then 8u) were
  // ZOMBIE-SAFE EXPLOITS - entity clips are navmesh-INVISIBLE, so zombies bumped an unseen ledge
  // at EITHER height and couldn't reach players on the pad. Pads are FLAT now (the Der assembly
  // model is walk-through; players stand at floor level inside the ring). l2_pad_green (the trench
  // teleporter pad) was removed with them; the deco l2_pad_red keeps its 11u plate (pure deco).
  { x:    0, y: -1702, hx: 35, hy: 21, bot: -1200, top: -1125, brushmodel: true, label: 'paradise_pap' },        // p9_fxanim_zm_gp_pap_xmodel 67.9x40.6x75; Paradise standalone Pack-a-Punch (deep z=-1200 -> brushmodel required).
  { x: -340, y: -210, hx: 17, hy: 24, bot: 0, top: 78, brushmodel: true, label: 'leaderboard_terminal' },        // dragon network terminal 48x34x78 at yaw 90 (X/Y swapped) - PLAZA south wall, west of the Implant door (user 2026-07-11 "network computer has no clip"). Mirrors _acc_leaderboard ACC_LB_STATION_ORIGIN (-340,-210,0).
  // ===== INFECTED DESCENT obstacle/hero clips - per-floor approval loop (2026-07-12) =====
  // Each floor's clips return TOGETHER WITH its approved dressing pass (a clip with no
  // visible model = an invisible wall). L2 = IN + user "ALL of the items need clips":
  // every spawn_l2 prop below is clipped snug to its measured silhouette. The flat fault
  // pads get an 11-tall plate (under the ~18u auto-step, so you walk up onto them).
  { x: -550, y: 1948, hx: 46, hy:  8, bot: -480, top: -368, brushmodel: true, label: 'pillar_l2_w' },   // powerbreaker slab 93x16x112, W bay mid (_acc_abyss_deco spawn_l2)
  { x:  560, y: 1880, hx:  8, hy: 46, bot: -480, top: -368, brushmodel: true, label: 'pillar_l2_e' },   // powerbreaker slab yaw 90 (X/Y swap), E bay
  { x: -560, y: 1748, hx: 72, hy: 15, bot: -480, top: -408, brushmodel: true, label: 'l2_tower_row' },  // 3x computer tower (24x30x72, +36 lift) as one row clip, S wall W bay
  { x: -756, y: 1900, hx: 14, hy: 12, bot: -480, top: -453, brushmodel: true, label: 'l2_rack_w' },     // server_comm_02 28x24x27, W wall
  { x:  795, y: 1900, hx: 14, hy: 12, bot: -480, top: -453, brushmodel: true, label: 'l2_rack_e' },     // server_comm_02, E wall
  { x: -756, y: 2050, hx:  8, hy: 46, bot: -480, top: -368, brushmodel: true, label: 'l2_breaker_wall' }, // powerbreaker cabinet yaw 90, W wall
  { x: -400, y: 1731, hx:128, hy:  8, bot: -372, top: -342, brushmodel: true, label: 'l2_cable_s' },    // wire bundle 256x51x26 @ chest height, S wall
  { x:  500, y: 2165, hx:128, hy:  8, bot: -372, top: -342, brushmodel: true, label: 'l2_cable_n' },    // wire bundle, N wall
  { x: -600, y: 2120, hx: 46, hy: 23, bot: -480, top: -430, brushmodel: true, label: 'l2_gen_w' },      // generator 92x46x50, N wall W bay
  { x:  600, y: 2120, hx: 46, hy: 23, bot: -480, top: -430, brushmodel: true, label: 'l2_gen_blue' },   // BLUE generator, N wall E bay
  { x:  550, y: 1735, hx: 60, hy: 11, bot: -393, top: -370, brushmodel: true, label: 'l2_console' },    // green console strip 121x22x19 @ z+70, S wall E bay
  { x:  480, y: 1948, hx: 64, hy: 64, bot: -480, top: -469, brushmodel: true, label: 'l2_pad_red' },    // fault pad 129x129x11 (walkable step-up plate)
  // --- L3 "Corruption Bloom" (approved 2026-07-12; every touchable item clipped; glyph/
  //     vines = near-flat decals + ceiling hangers 156u up = unclipped) ---
  // CLIP RULE (user 2026-07-12 "clips inconsistent, objects oddly shaped"): clip only REAL 3D
  // solids in walkable space; the FLAT wall/floor art (boils panel, membranes, root walls,
  // intestine pile) is flush against already-solid walls/floor -> NO clip (a box on flush art
  // = the "invisible wall" inconsistency the user saw; the wall behind it already blocks you).
  { x: -620, y: 1850, hx: 57, hy: 19, bot: -720, top: -668, brushmodel: true, label: 'pillar_l3_root_w' }, // slalom twisted root 115x38x52, W bay (MOVED off the Glitch Altar - clip x[-677,-563] now clears the altar footprint x[-481,-319], user 2026-07-13)
  { x:  450, y: 1990, hx: 30, hy: 27, bot: -720, top: -631, brushmodel: true, label: 'pillar_l3_rock_e' }, // slalom spore rock 60x55x89, E bay
  { x:  620, y: 1860, hx: 57, hy: 19, bot: -720, top: -668, brushmodel: true, label: 'pillar_l3_root_e' }, // slalom twisted root, E bay
  { x: -700, y: 1780, hx: 30, hy: 27, bot: -720, top: -631, brushmodel: true, label: 'l3_rock_sw' },    // spore rock 60x55x89, SW corner (real obstacle)
  { x:  750, y: 2120, hx: 30, hy: 27, bot: -720, top: -631, brushmodel: true, label: 'l3_rock_ne' },    // spore rock, NE corner (real obstacle)
  // --- L4 "Specimen Vault" (approved 2026-07-13; real solids only - hanging cages/signage/beacon unclipped) ---
  { x: -400, y: 1948, hx: 32, hy: 33, bot: -960, top: -840, brushmodel: true, label: 'deco_l4_tank' },  // lg specimen tank 63x65x120 (HERO)
  { x:  400, y: 1948, hx: 27, hy: 29, bot: -960, top: -846, brushmodel: true, label: 'l4_pod_e' },      // cryo pod exterior 58x53x114, yaw90
  { x: -600, y: 1760, hx: 16, hy: 47, bot: -960, top: -869, brushmodel: true, label: 'l4_pod_frost' },  // frosted pod 31x93x91, S wall W bay
  { x: -550, y: 1880, hx: 40, hy: 31, bot: -960, top: -918, brushmodel: true, label: 'l4_table' },      // operating table 79x24x42 (yaw30 bbox)
  { x: -756, y: 2050, hx:  9, hy:  9, bot: -960, top: -915, brushmodel: true, label: 'l4_console' },     // interrogation console 17x16x45, W wall
  { x:  758, y: 1820, hx: 58, hy: 58, bot: -960, top: -797, brushmodel: true, label: 'l4_vessel_e' },   // containment vessel 116x116x163, E wall flush
  { x:  500, y: 1745, hx: 36, hy: 46, bot: -960, top: -798, brushmodel: true, label: 'l4_vessel_s' },   // vessel decor 71x93x162, S wall (MOVED 300->500: was in the D3 stair landing, user 2026-07-13)
  { x: -250, y: 1880, hx: 22, hy: 22, bot: -960, top: -822, brushmodel: true, label: 'pillar_l4_cyl_w' }, // vat cylinder 44x44x138, W bay slalom
  { x:  560, y: 1870, hx: 22, hy: 22, bot: -960, top: -822, brushmodel: true, label: 'pillar_l4_cyl_e' }, // vat cylinder, E bay slalom
  // --- L5 "The Maw" (approved 2026-07-13; real solids only - arch/sconces/runes/vines/beacon unclipped) ---
  // deco_l5_hatchery: CLIP REMOVED (user 2026-07-13 "invisible clips in many places"): a 416-wide bbox clip on a
  // sparse decorative snake-hatchery = a huge invisible wall along the whole N bay. It's a wall-flush hero piece -
  // walk-through is fine; the N wall behind it already blocks you.
  { x: -540, y: 1850, hx: 47, hy: 64, bot: -1200, top: -976, brushmodel: true, label: 'pillar_l5_monolith' }, // crystal monolith 94x128x258, W bay (caps ceiling)
  { x:  700, y: 1850, hx: 62, hy: 47, bot: -1200, top: -1069, brushmodel: true, label: 'l5_monolith_e' },     // crystal monolith 75x124x131, E bay (yaw210 bbox)
  { x:  620, y: 2000, hx: 72, hy: 77, bot: -1200, top: -998, brushmodel: true, label: 'pillar_l5_fountain' }, // jade fountain 144x154x202, E centerpiece
  { x:  470, y: 2110, hx: 48, hy: 48, bot: -1200, top: -976, brushmodel: true, label: 'l5_column' },          // snake column 106x166x318, N wall (MOVED 240->470 off the D4 stair landing + clip shrunk to the solid shaft, drops the 166-deep sparse snake tail, user 2026-07-13)
  { x: -700, y: 1745, hx: 35, hy: 35, bot: -1200, top: -1100, brushmodel: true, label: 'l5_statue_sw' },      // jade statue 69x69x100, SW corner
  { x:  700, y: 1760, hx: 59, hy: 59, bot: -1200, top: -1104, brushmodel: true, label: 'l5_egg_base_se' },    // egg niche base 117x117x96, SE corner
  { x:  760, y: 2120, hx: 23, hy: 16, bot: -1200, top: -1104, brushmodel: true, label: 'l5_egg_nest_ne' },    // egg nest 46x32x96, NE
  { x: -250, y: 1755, hx: 23, hy: 16, bot: -1200, top: -1104, brushmodel: true, label: 'l5_egg_nest_s' },     // egg nest, S wall W of the door

  // ===== BUS STATION SURFACE (z=0) - _acc_surface_deco.gsc terminal revamp (2026-07-16) =====
  // SHALLOW worldspawn clips (bot:0) -> navmesh AUTO-CUT (zombies route around), LED-safe. Half-extents are
  // bounds-measured (xmodel_bin_inspect --bounds), yaw-rotated, origin-offset (bench origins offset via cy).
  // GENERATED with the spawns from scratch/gen_bus_layout.js - EVERY floor prop is clipped; overhead/high
  // props (signs, wall TVs, fans, caged lights, sconces, payphones) carry no floor clip (above nav ceiling).
  // If a prop moves, edit gen_bus_layout.js -> regen -> paste both blocks -> re-bake.
  { x: -500, y: 1198, hx: 41, hy: 9, bot: 0, top: 112, label: 'bus_vault_bank_frame' },
  { x: -500, y: 1206, hx: 36, hy: 10, bot: 0, top: 102, label: 'bus_vault_bank_door' },
  { x: -450, y: 1262, hx: 93, hy: 24, bot: 0, top: 54, label: 'bus_table_kitchen_long' },
  { x: -505, y: 1244, hx: 17, hy: 3, bot: 0, top: 48, label: 'bus_window_teller' },
  { x: -405, y: 1244, hx: 17, hy: 3, bot: 0, top: 48, label: 'bus_window_teller_2' },
  { x: -120, y: 1210, hx: 13, hy: 10, bot: 0, top: 66, label: 'bus_tv_vintage_on' },
  { x: 0, y: 1210, hx: 13, hy: 10, bot: 0, top: 66, label: 'bus_tv_vintage_on_2' },
  { x: 120, y: 1210, hx: 13, hy: 10, bot: 0, top: 66, label: 'bus_tv_vintage_on_3' },
  { x: -190, y: 1358, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood' },
  { x: 190, y: 1358, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_2' },
  { x: -190, y: 1448, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_3' },
  { x: 190, y: 1448, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_4' },
  { x: -190, y: 1538, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_5' },
  { x: 190, y: 1538, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_6' },
  { x: -270, y: 1372, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_suitcase_med' },
  { x: 270, y: 1552, hx: 6, hy: 19, bot: 0, top: 27, label: 'bus_suitcase_lrg' },
  { x: -100, y: 1614, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion' },
  { x: 60, y: 1614, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_2' },
  { x: -100, y: 1662, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_3' },
  { x: 60, y: 1662, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_4' },
  { x: -430, y: 1658, hx: 40, hy: 20, bot: 0, top: 44, label: 'bus_traffic_street_bar' },
  { x: 300, y: 1662, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_traffic_street_con' },
  { x: 600, y: 1655, hx: 71, hy: 2, bot: 0, top: 97, label: 'bus_fence_quarantine' },
  { x: 600, y: 1540, hx: 36, hy: 20, bot: 0, top: 53, label: 'bus_pneumatic_dolly' },
  { x: 558, y: 1500, hx: 19, hy: 8, bot: 0, top: 27, label: 'bus_suitcase_lrg_2' },
  { x: 648, y: 1580, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_suitcase_med_2' },
  { x: 560, y: 1578, hx: 14, hy: 8, bot: 0, top: 6, label: 'bus_suitcase_med_cloth' },
  { x: 450, y: 1520, hx: 25, hy: 17, bot: 0, top: 23, label: 'bus_table_rustic_wood_' },
  { x: 410, y: 1490, hx: 7, hy: 7, bot: 0, top: 26, label: 'bus_ashtray_tall' },
  { x: -100, y: 2262, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_5' },
  { x: 60, y: 2262, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_6' },
  { x: -100, y: 2314, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_7' },
  { x: 60, y: 2314, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_post_stanchion_8' },
  { x: -470, y: 2222, hx: 40, hy: 20, bot: 0, top: 44, label: 'bus_traffic_street_bar_2' },
  { x: 400, y: 2228, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_traffic_street_con_2' },
  { x: 150, y: 2210, hx: 71, hy: 2, bot: 0, top: 97, label: 'bus_fence_quarantine_2' },
  { x: -150, y: 2486, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_7' },
  { x: 150, y: 2486, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_8' },
  { x: 300, y: 2545, hx: 14, hy: 30, bot: 0, top: 44, label: 'bus_booth_chair' },
  { x: -702, y: 2600, hx: 14, hy: 14, bot: 0, top: 36, label: 'bus_sink_bathroom' },
  { x: -702, y: 2680, hx: 10, hy: 10, bot: 0, top: 88, label: 'bus_urinal_bathroom' },
  { x: -560, y: 2708, hx: 14, hy: 11, bot: 0, top: 41, label: 'bus_sink_standing' },
  { x: -485, y: 2645, hx: 5, hy: 24, bot: 0, top: 79, label: 'bus_frame_window_wood' },
  { x: 620, y: 2690, hx: 93, hy: 24, bot: 0, top: 54, label: 'bus_table_kitchen_long_2' },
  { x: 580, y: 2648, hx: 9, hy: 9, bot: 0, top: 27, label: 'bus_stool_counter' },
  { x: 660, y: 2648, hx: 9, hy: 9, bot: 0, top: 27, label: 'bus_stool_counter_2' },
  { x: 702, y: 2600, hx: 15, hy: 14, bot: 0, top: 49, label: 'bus_stove_kitchen' },
  { x: -250, y: 2700, hx: 14, hy: 5, bot: 0, top: 95, label: 'bus_stepladder_lrg' },
  { x: -380, y: 2705, hx: 24, hy: 16, bot: 0, top: 56, label: 'bus_shelve_oilrack' },
  { x: 150, y: 2716, hx: 18, hy: 9, bot: 0, top: 63, label: 'bus_power_panel' },
  { x: -80, y: 2420, hx: 49, hy: 25, bot: 0, top: 38, label: 'bus_table_wood_lrg_bro' },
  { x: 120, y: 2560, hx: 42, hy: 43, bot: 0, top: 19, label: 'bus_debris_rubble_02' },
  { x: -560, y: 2712, hx: 13, hy: 10, bot: 0, top: 66, label: 'bus_tv_vintage_on_4' },
  { x: -660, y: 1660, hx: 8, hy: 8, bot: 0, top: 61, label: 'bus_street_lamp_full' },
  { x: -660, y: 2400, hx: 8, hy: 8, bot: 0, top: 61, label: 'bus_street_lamp_full_2' },

  // ===== SURFACE ZONES pass 2 (2026-07-16): Alley / Market / Vault / Helipad =====
  // wide props get the anti-perch gable (SURFACE_PREFIXES); MIRROR _acc_surface_deco.gsc.
  { x: 1945, y: 480, hx: 23, hy: 22, bot: 0, top: 83, label: 'alley_tank_chemical' },
  { x: 1945, y: 830, hx: 16, hy: 24, bot: 0, top: 56, label: 'alley_shelve_oilrack' },
  { x: 1945, y: 1060, hx: 23, hy: 22, bot: 0, top: 83, label: 'alley_tank_chemical_2' },
  { x: 1895, y: 720, hx: 20, hy: 20, bot: 0, top: 40, label: 'alley_cage_animal_med' },
  { x: 1900, y: 445, hx: 46, hy: 50, bot: 0, top: 125, label: 'alley_outhouse' },
  { x: 1895, y: 1400, hx: 42, hy: 43, bot: 0, top: 19, label: 'alley_debris_rubble_02' },
  { x: 1700, y: 1448, hx: 36, hy: 21, bot: 0, top: 20, label: 'alley_bike_destroyed' },
  { x: 1820, y: 1452, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_debris_rubble_pile' },
  { x: 1510, y: 1466, hx: 71, hy: 2, bot: 0, top: 97, label: 'alley_fence_quarantine' },
  { x: 1440, y: 1462, hx: 18, hy: 8, bot: 0, top: 63, label: 'alley_power_panel' },
  { x: 1860, y: 415, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_tank_chemical_3' },
  { x: 1780, y: 420, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_barrel_wood' },
  { x: 1730, y: 770, hx: 70, hy: 2, bot: 0, top: 90, label: 'alley_fence_quarantine_t' },
  { x: 1660, y: 1080, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_barrel_wood_2' },
  { x: 1700, y: 1105, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_barrel_wood_3' },
  { x: 1650, y: 590, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_debris_rubble_pile_2' },
  { x: 1625, y: 1300, hx: 16, hy: 35, bot: 0, top: 23, label: 'alley_wheelbarrow_full' },
  { x: 1850, y: 1150, hx: 20, hy: 36, bot: 0, top: 53, label: 'alley_pneumatic_dolly' },
  { x: 1600, y: 860, hx: 24, hy: 16, bot: 0, top: 56, label: 'alley_shelve_oilrack_2' },
  { x: 1830, y: 570, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_tank_chemical_4' },
  { x: 1620, y: 1000, hx: 20, hy: 20, bot: 0, top: 40, label: 'alley_cage_animal_med_2' },
  { x: 1560, y: 900, hx: 11, hy: 10, bot: 0, top: 30, label: 'alley_mannequin_full' },
  { x: 1356, y: 1000, hx: 4, hy: 14, bot: 0, top: 31, label: 'alley_radiator_vintage' },
  { x: -2106, y: 460, hx: 12, hy: 15, bot: 0, top: 53, label: 'market_gas_pump' },
  { x: -2102, y: 680, hx: 16, hy: 24, bot: 0, top: 56, label: 'market_shelve_oilrack' },
  { x: -2100, y: 760, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_barrel_wood' },
  { x: -2102, y: 1030, hx: 16, hy: 22, bot: 0, top: 37, label: 'market_counter_kitchen_' },
  { x: -2102, y: 1095, hx: 15, hy: 20, bot: 0, top: 37, label: 'market_counter_kitchen__2' },
  { x: -2103, y: 1385, hx: 15, hy: 14, bot: 0, top: 49, label: 'market_stove_kitchen' },
  { x: -1850, y: 446, hx: 93, hy: 24, bot: 0, top: 54, label: 'market_table_kitchen_lo' },
  { x: -2000, y: 440, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_table_rustic_woo' },
  { x: -1850, y: 500, hx: 9, hy: 9, bot: 0, top: 27, label: 'market_stool_counter' },
  { x: -1560, y: 476, hx: 91, hy: 54, bot: 0, top: 97, label: 'market_sign_building_ga' },
  { x: -1870, y: 1390, hx: 93, hy: 24, bot: 0, top: 54, label: 'market_table_kitchen_lo_2' },
  { x: -1600, y: 1374, hx: 14, hy: 41, bot: 0, top: 39, label: 'market_couch_floral' },
  { x: -1720, y: 1360, hx: 14, hy: 30, bot: 0, top: 45, label: 'market_booth_chair' },
  { x: -2050, y: 1420, hx: 30, hy: 10, bot: 0, top: 26, label: 'market_counter_kitchen__3' },
  { x: -1720, y: 520, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_mannequin_full' },
  { x: -1660, y: 1320, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_mannequin_full_2' },
  { x: 1500, y: 3364, hx: 34, hy: 8, bot: 0, top: 102, label: 'vault_vault_bank_door' },
  { x: 1910, y: 2400, hx: 20, hy: 20, bot: 0, top: 100, label: 'vault_server_comm_02' },
  { x: 1915, y: 2490, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_computer_tower_0' },
  { x: 1913, y: 2590, hx: 17, hy: 24, bot: 0, top: 78, label: 'vault_dragon_network_d' },
  { x: 1913, y: 2680, hx: 17, hy: 18, bot: 0, top: 103, label: 'vault_monitor_atm' },
  { x: 1908, y: 2970, hx: 22, hy: 24, bot: 0, top: 71, label: 'vault_drop_pod_console' },
  { x: 1885, y: 3352, hx: 22, hy: 23, bot: 0, top: 83, label: 'vault_tank_chemical' },
  { x: 1400, y: 2328, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_generator_lg_01_' },
  { x: 1650, y: 2312, hx: 69, hy: 9, bot: 0, top: 48, label: 'vault_cargo_train_armo' },
  { x: 1880, y: 2338, hx: 22, hy: 23, bot: 0, top: 83, label: 'vault_tank_chemical_2' },
  { x: 1127, y: 2620, hx: 8, hy: 17, bot: 0, top: 63, label: 'vault_power_panel' },
  { x: 1123, y: 2720, hx: 4, hy: 14, bot: 0, top: 31, label: 'vault_radiator_vintage' },
  { x: 1134, y: 2820, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_computer_tower_0_2' },
  { x: 1136, y: 2960, hx: 17, hy: 24, bot: 0, top: 78, label: 'vault_dragon_network_d_2' },
  { x: 1720, y: 3352, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_generator_lg_01__2' },
  { x: -1810, y: 3273, hx: 100, hy: 100, bot: 0, top: 210, label: 'roof_water_tower' },
  { x: -1548, y: 2852, hx: 22, hy: 23, bot: 0, top: 83, label: 'roof_tank_chemical' },
  { x: -1500, y: 2872, hx: 22, hy: 23, bot: 0, top: 83, label: 'roof_tank_chemical_2' },
  { x: -1524, y: 2812, hx: 17, hy: 17, bot: 0, top: 50, label: 'roof_barrel_wood' },
  { x: -1870, y: 2326, hx: 15, hy: 12, bot: 0, top: 53, label: 'roof_gas_pump' },
  { x: -1760, y: 2330, hx: 24, hy: 16, bot: 0, top: 56, label: 'roof_shelve_oilrack' },
  { x: -1650, y: 2320, hx: 17, hy: 8, bot: 0, top: 63, label: 'roof_power_panel' },
  { x: -1560, y: 2332, hx: 40, hy: 20, bot: 0, top: 44, label: 'roof_traffic_street_b' },
  { x: -1440, y: 2334, hx: 7, hy: 7, bot: 0, top: 28, label: 'roof_traffic_street_c' },
  { x: -1650, y: 3352, hx: 21, hy: 20, bot: 0, top: 40, label: 'roof_cage_animal_med' },
  { x: -1540, y: 3348, hx: 36, hy: 20, bot: 0, top: 53, label: 'roof_pneumatic_dolly' },
  { x: -1430, y: 3358, hx: 14, hy: 4, bot: 0, top: 31, label: 'roof_radiator_vintage' },
  { x: -1140, y: 2650, hx: 8, hy: 17, bot: 0, top: 63, label: 'roof_power_panel_2' },
  { x: -1148, y: 2990, hx: 16, hy: 24, bot: 0, top: 56, label: 'roof_shelve_oilrack_2' },
  { x: -1895, y: 2400, hx: 8, hy: 8, bot: 0, top: 62, label: 'roof_street_lamp_full' },
  { x: -1908, y: 3040, hx: 2, hy: 72, bot: 0, top: 97, label: 'roof_fence_quarantine' },
  { x: -1835, y: 2470, hx: 42, hy: 43, bot: 0, top: 19, label: 'roof_debris_rubble_02' },
  // ===== SURFACE pass 3 (+25% props, 2026-07-16) =====
  { x: 490, y: 1400, hx: 19, hy: 6, bot: 0, top: 27, label: 'bus_x_suitcase_lrg' },
  { x: 455, y: 1438, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_x_suitcase_med' },
  { x: 690, y: 1360, hx: 7, hy: 7, bot: 0, top: 26, label: 'bus_x_ashtray_tall' },
  { x: -350, y: 1655, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_x_traffic_street' },
  { x: 250, y: 2235, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_x_traffic_street_2' },
  { x: -180, y: 1614, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_x_post_stanchion' },
  { x: 140, y: 1614, hx: 7, hy: 7, bot: 0, top: 42, label: 'bus_x_post_stanchion_2' },
  { x: 735, y: 2660, hx: 23, hy: 28, bot: 0, top: 14, label: 'bus_x_debris_rubble_' },
  { x: -500, y: 2702, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_x_bench_wood' },
  { x: -260, y: 2560, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_x_suitcase_med_2' },
  { x: 1800, y: 1000, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_x_barrel_wood' },
  { x: 1560, y: 1420, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_x_debris_rubble_' },
  { x: 1830, y: 1280, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_x_tank_chemical' },
  { x: 1700, y: 650, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_x_barrel_wood_2' },
  { x: 1900, y: 1150, hx: 20, hy: 20, bot: 0, top: 40, label: 'alley_x_cage_animal_me' },
  { x: 1600, y: 700, hx: 28, hy: 28, bot: 0, top: 23, label: 'alley_x_wheelbarrow_fu' },
  { x: 1700, y: 1300, hx: 11, hy: 10, bot: 0, top: 30, label: 'alley_x_mannequin_full' },
  { x: -1900, y: 900, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_x_barrel_wood' },
  { x: -1500, y: 1100, hx: 23, hy: 28, bot: 0, top: 14, label: 'market_x_debris_rubble_' },
  { x: -1850, y: 700, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_x_mannequin_full' },
  { x: -1600, y: 1350, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_x_table_rustic_w' },
  { x: -1450, y: 600, hx: 26, hy: 29, bot: 0, top: 29, label: 'market_x_planter_stone' },
  { x: 1250, y: 2700, hx: 22, hy: 23, bot: 0, top: 83, label: 'vault_x_tank_chemical' },
  { x: 1350, y: 3352, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_x_computer_tower' },
  { x: 1250, y: 2320, hx: 24, hy: 17, bot: 0, top: 78, label: 'vault_x_dragon_network' },
  { x: 1130, y: 3050, hx: 4, hy: 4, bot: 0, top: 33, label: 'vault_x_monitor_suppor' },
  { x: -1500, y: 3000, hx: 17, hy: 17, bot: 0, top: 50, label: 'roof_x_barrel_wood' },
  { x: -1200, y: 2700, hx: 23, hy: 22, bot: 0, top: 83, label: 'roof_x_tank_chemical' },
  { x: -1600, y: 3120, hx: 43, hy: 42, bot: 0, top: 19, label: 'roof_x_debris_rubble_' },
  { x: -1250, y: 3050, hx: 12, hy: 15, bot: 0, top: 53, label: 'roof_x_gas_pump' },
  { x: -1550, y: 2900, hx: 8, hy: 8, bot: 0, top: 28, label: 'roof_x_traffic_street' },
  // ===== SURFACE center anchors (2026-07-16) =====
  { x: -250, y: 2400, hx: 30, hy: 30, bot: 0, top: 53, label: 'bus_c_pneumatic_dol' },
  { x: -190, y: 2445, hx: 6, hy: 19, bot: 0, top: 27, label: 'bus_c_suitcase_lrg' },
  { x: -300, y: 2360, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_c_suitcase_med' },
  { x: 1650, y: 928, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_c_tank_chemical' },
  { x: 1610, y: 995, hx: 17, hy: 17, bot: 0, top: 50, label: 'alley_c_barrel_wood' },
  { x: -1650, y: 700, hx: 10, hy: 30, bot: 0, top: 26, label: 'market_c_counter_kitch' },
  { x: -1560, y: 820, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_c_table_rustic_' },
  { x: -1680, y: 810, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_c_barrel_wood' },
  { x: 1450, y: 2650, hx: 12, hy: 15, bot: 0, top: 72, label: 'vault_c_computer_towe' },
  { x: 1580, y: 2650, hx: 20, hy: 20, bot: 0, top: 100, label: 'vault_c_server_comm_0' },
  { x: 1500, y: 3000, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_c_generator_lg_' },
  { x: -1420, y: 2920, hx: 42, hy: 43, bot: 0, top: 19, label: 'roof_c_debris_rubble' },
  { x: -1620, y: 2760, hx: 17, hy: 17, bot: 0, top: 50, label: 'roof_c_barrel_wood' },
];
const CLIP_BOT = -240, CLIP_TOP = -160;   // default: sits on the z=-240 floor, 80 tall. Per-prop `top` can override
                                          // (e.g. the cargo crates use top=-192 = a snug 48-tall clip = the plaza crate height).
const MAT = 'clip';                       // invisible solid (player+AI+bullets); stock tools material, ships free, no zone line

let guidCounter = 0xD00;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0D-ACCD-4E13-8A3F-${c}}`; }
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`, '}'].join('\n');
}

// ANTI-PERCH gable cap (user 2026-07-16: "players jump on the Bus Station props + camp,
// esp. with the Rocket Shield double-jump - make the clip tops slanted"). Same solid as
// box() but the FLAT TOP is replaced by two steep roof planes meeting at a central RIDGE
// (run along the LONGER horizontal axis so the CROSS-slope stays steep). The ridge rises
// 1.5x the SHORT half-extent above the model top => ~56deg, steeper than the walkable
// limit, so a player who lands on top slides off (the ridge is a zero-width line, so even
// a shield-jump landing can't balance). Bus Station SURFACE props only - trench/abyss
// clips (brushmodel) stay flat ("anything in the trench is fine"). Planes wound to the
// box() convention: outward normal = (p3-p1)x(p2-p1). 7 planes (convex "house" prism).
function gableBox(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
  const hx = (x2 - x1) / 2, hy = (y2 - y1) / 2;
  // Peak rises 3x the SHORT half-extent above the model top => ~72deg cross-slope. (1.5x/~56deg
  // was NOT steep enough - BO3 still let players stand, 2026-07-16.) ABSOLUTE cap at z228 so a
  // tall+wide prop (e.g. the alley outhouse, 92x100x125) can't punch through the ~240u ceiling -
  // its slope just gets a bit shallower, still well past walkable.
  const peak = Math.min(228, z2 + Math.max(24, Math.round(3.0 * Math.min(hx, hy))));
  const walls = ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,   // bottom (-z)
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,             // y1 wall (-y)
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,            // x2 wall (+x)
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,              // y2 wall (+y)
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`];           // x1 wall (-x)
  const roof = (hx >= hy)   // ridge along X (slope across Y) : ridge along Y (slope across X)
    ? [` ( ${x1} ${y1} ${z2} ) ( ${x1} ${cy} ${peak} ) ( ${x2} ${y1} ${z2} ) ${t}`,   // S roof (up,-y)
       ` ( ${x1} ${y2} ${z2} ) ( ${x2} ${y2} ${z2} ) ( ${x1} ${cy} ${peak} ) ${t}`]   // N roof (up,+y)
    : [` ( ${x1} ${y1} ${z2} ) ( ${x1} ${y2} ${z2} ) ( ${cx} ${y1} ${peak} ) ${t}`,   // W roof (up,-x)
       ` ( ${x2} ${y1} ${z2} ) ( ${cx} ${y1} ${peak} ) ( ${x2} ${y2} ${z2} ) ${t}`];  // E roof (up,+x)
  return walls.concat(roof, '}').join('\n');
}

// A DEEP clip emitted as a script_brushmodel ENTITY (lives in the entity list, AFTER the worldspawn close). The
// LED lightmapper IGNORES script_brushmodels (memory brushmodel-wall-led-exempt + the shipped acc_ec_right_wall /
// acc_door_implant precedents in this .map), so an abyss-depth `clip` here gives REAL collision WITHOUT the
// worldspawn-clip bake crash (brush.cpp:1860). It is solid at load - static, no GSC needed (same as the EC wall).
// NAVMESH (2026-07-11): the navmesh generator ALSO ignores script_brushmodels (radiant\configs\navmesh.json
// exclusions), so these clips are collision zombies cannot path around - they grind on the prop. The runtime
// cut is DisconnectPaths(), done centrally by _acc_map_randomizer.gsc::manage_prop_clip_navmesh, which sweeps
// ALL `acc_clip_*` targetnames - so new brushmodel clips emitted here are covered automatically, keep the
// `acc_clip_` prefix. (Worldspawn clips from box() need nothing - cod2map cuts the mesh around them at compile.)
// Two guids: one for the entity, one for the nested brush (box() emits the brush wrapper + 6 planes).
function brushmodelEntity(label, x1, x2, y1, y2, z1, z2, tex) {
  const brush = box(x1, x2, y1, y2, z1, z2, tex);   // "{ guid... 6 planes }"
  return ['{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "acc_clip_${label}"`,
    brush, '}'].join('\n');
}

let lines = fs.readFileSync(inPath, 'utf8').split('\n');

// strip any prior PROP CLIPS blocks (clean re-run) - BOTH the worldspawn block AND the brushmodel-entity block
// (the brushmodel headers contain "PROP CLIPS"/"end prop clips" as substrings, so this loop catches both).
for (;;) {
  const s = lines.findIndex(l => l.includes('===== PROP CLIPS'));
  if (s < 0) break;
  let e = -1;
  for (let i = s; i < lines.length; i++) { if (lines[i].includes('===== end prop clips')) { e = i; break; } }
  if (e < 0) { console.error('ERROR: unterminated PROP CLIPS block'); process.exit(2); }
  console.log(`  stripped prior PROP CLIPS block (lines ${s + 1}-${e + 1})`);
  lines.splice(s, e - s + 1);
}

// find worldspawn close (entity 0)
let depth = 0, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) depth++;
  for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && wsClose === -1) wsClose = i; }
}
if (wsClose < 0) { console.error('ERROR: worldspawn close not found'); process.exit(2); }

// SHALLOW clips -> worldspawn `clip` brushes (injected BEFORE the worldspawn close). DEEP clips (bot < -240) ->
// either a script_brushmodel ENTITY (if `brushmodel: true`, injected AFTER the worldspawn close = the entity list)
// or skipped (walk-through). A deep WORLDSPAWN `clip` brush inside the enclosed abyss box CRASHES the Radiant LED
// bake (exit 0xC0000005 / brush.cpp:1860, memory led-relight-dead-end-enclosed-geometry); the script_brushmodel is
// LED-EXEMPT so it bakes. The shallow z[-240,-160] clips bake fine as plain worldspawn brushes.
const block = ['// ===== PROP CLIPS (add_prop_clips.js) - invisible collision around underground interactables ====='];
const entityBlock = ['// ===== PROP CLIPS (brushmodel) - deep abyss-depth clips as LED-exempt script_brushmodels ====='];
let nWs = 0, nBm = 0, nSkip = 0;
for (const p of PROPS) {
  const deep = (p.bot !== undefined && p.bot < CLIP_BOT);
  const z1 = (p.bot !== undefined ? p.bot : CLIP_BOT), z2 = (p.top !== undefined ? p.top : CLIP_TOP);
  const x1 = p.x - p.hx, x2 = p.x + p.hx, y1 = p.y - p.hy, y2 = p.y + p.hy;

  // brushmodel is honored at ANY depth (2026-07-09): a script_brushmodel is LED-exempt
  // everywhere, so new clips (armory loft z288, Exchange z-240, Paradise) carry zero bake
  // risk. Only legacy shallow clips stay worldspawn (they were already baking fine).
  if (p.brushmodel) {
    entityBlock.push(`// clip(brushmodel): ${p.label} @ (${p.x},${p.y}) z[${z1},${z2}]`);
    entityBlock.push(brushmodelEntity(p.label, x1, x2, y1, y2, z1, z2, MAT));
    nBm++;
    continue;
  }
  if (deep) {
    // Deep but NOT opted into a brushmodel (e.g. the Paradise stations) - skipped (walk-through) so the map still
    // bakes. Add `brushmodel: true` to its PROPS entry to give it real collision.
    console.log(`  SKIP deep clip '${p.label}' (z=${p.bot}): no brushmodel flag (still walk-through).`);
    nSkip++;
    continue;
  }
  // SURFACE-zone props get an anti-perch GABLE cap (slanted top) - but ONLY the genuinely-
  // perchable WIDE ones (min half-extent >= 12u => top >= 24u, wide enough for a player capsule
  // to balance on). Thin props (stanchions 7x7, fence 71x2, poles) keep a flat box: a player
  // can't stand on a <24u top anyway, and a peaked cap on a sliver top makes a degenerate brush
  // that crashes the linker. Trench/abyss (brushmodel) clips + legacy shallow (exo_station) stay flat.
  const SURFACE_PREFIXES = ['bus_', 'alley_', 'market_', 'vault_', 'roof_'];
  const antiPerch = SURFACE_PREFIXES.some(pre => p.label.startsWith(pre)) && Math.min(p.hx, p.hy) >= 12;
  block.push(`// clip: ${p.label} @ (${p.x},${p.y})${antiPerch ? ' [anti-perch gable]' : ''}`);
  block.push(antiPerch ? gableBox(x1, x2, y1, y2, z1, z2, MAT) : box(x1, x2, y1, y2, z1, z2, MAT));
  nWs++;
}
block.push('// ===== end prop clips =====');
entityBlock.push('// ===== end prop clips (brushmodel) =====');

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(...block);                   // worldspawn brushes: BEFORE the worldspawn close brace
  out.push(lines[i]);
  if (i === wsClose && nBm > 0) out.push(...entityBlock);  // brushmodel entities: AFTER the close brace (entity list)
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  ${nWs} worldspawn clip(s) + ${nBm} brushmodel clip(s) injected (mat '${MAT}'); ${nSkip} deep clip(s) skipped (no brushmodel flag).`);
console.log(`[clips] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
