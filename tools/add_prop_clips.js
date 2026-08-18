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
// =============================================================================
// PROP FRONT-AXIS CONVENTIONS (per model family) - the ONE ledger that ends the
// recurring yaw flips (docs/47 audit: "a single measured front-axis note per model
// family would end the recurring flips"). "Front" = the side the mesh PRESENTS
// (screen / seat / doors / open counter). Yaw is CCW about +Z; at yaw 0 the listed
// native front points the given axis. "backs N/S/W/E -> yaw" = the yaw to use so the
// front faces the ROOM when the prop is flush to that wall.
//
//   FAMILY                               NATIVE FRONT @yaw0   backs N/S/W/E -> yaw
//   p7_zm_tra_* (flat-back furniture)    -Y                   0 / 180 / 90 / 270
//   t10_zm_* (signs / menu boards)       +Y (face)            180 / 0 / 270 / 90
//   t10_street_bench_iron_ornate_*       -X   WALKABOUT-PROVEN 2026-08-03 (all 4
//                                             Plaza benches flipped to face fountain)
//   t10_decor_shaftesbury_..._angel      -Y   (angel 180->0 to face spawn/center)
//   vending / station family             -Y   CONFIRMED via Paradise PaP 0->180 ->
//     (p7_zm_vending_*, drop_pod console,      the blanket-yaw-0 sweep, Wave 1)
//      cryogen pod, Neural/Overclock)
//   dragon terminal                      +X   LB-proof (E kiosks yaw 180 cited,
//     (p7_zm_sta_dragon_network_..._terminal)  Wave 1)
//   p8_zm_off_monitor_security_*         -Y   lab N-wall pair proof (mount yaw 0,
//                                             screen hung roomward facing south)
//   p7_cru_monitor_holo_screen_01        +X
//   p7_out_monitor_atm (ATM totem)       +X, BUT origin = BACK face - the 37u mesh
//     extends +X FROM the origin (NOT centered), so a yaw-180 flip keeps the clip
//     span identical while the screen swings to -X (see transfer_* clips L94-97).
//   p7_zm_sta_drop_pod_console_blue      UNVERIFIED - Gorod console (perk_slot_vendor);
//                                             assumed -Y with the vending family,
//                                             CONFIRM in-game before trusting.
//
// When you add/rotate a clip, set the .map misc_model AND the GSC deco twin to the
// SAME yaw this table implies (lockstep is mandatory - see the deco module headers).
// =============================================================================
const PROPS = [
  { x: -200, y: 4120, hx: 29, hy: 26, bot: 0, top: 114, label: 'exo_station' },  // p7_cry_cryogen_pod_exterior (stasis pod 58x53x114, yaw 0) - THE SCIENTIST'S OFFICE (user 2026-07-26, gen_scientist_office.js room behind the Lab N wall; whole office translated -360y by the 2026-08-02 lab compression, gen_compress_lab_paradise.js). Surface z=0 floor -> shallow worldspawn clip. Mirrors _acc_exo::spawn_station_at (-200,4120,0).
  // ===== THE SCIENTIST'S OFFICE furniture (gen_scientist_office.js statics, user 2026-07-26; -360y with the office 2026-08-02) - z=0 room floor, snug boxes =====
  { x:  -75, y: 4130, hx: 28, hy: 16, bot: 0, top:  31, label: 'sci_desk' },       // p7_rus_desk_metal_vintage (yaw 180) - the loot gun rests on top (GSC display at ~z37)
  { x:  -75, y: 4178, hx: 14, hy: 14, bot: 0, top:  24, label: 'sci_chair' },      // p8_zm_off_chair_office_executive_black behind the desk (Track C kit swap 2026-08-03; was p7_zm_tra_booth_chair - audit Lab#11 wrong-kit)
  { x: -252, y: 4180, hx: 11, hy: 11, bot: 0, top:  73, label: 'sci_coat_rack' },  // p8_zm_off_coat_lab_rack, NW corner
  { x: -268, y: 4100, hx: 16, hy:  9, bot: 0, top:  52, label: 'sci_filing' },     // p8_zm_off_filing_cabinet_01 (18x32 at yaw 90 -> hx16/hy9), W wall
  { x:   80, y: 4172, hx: 30, hy: 23, bot: 0, top:  56, label: 'sci_console' },    // p8_zm_off_console_control_01 (60 wide x 46 deep - audit fix 2026-08-03: the old hx23/hy30 assumed a yaw-swapped AABB, but a 180-deg yaw keeps the AABB; 7u of console stuck out unclipped while 7u of air was solid), NE corner, yaw 180
  { x:   92, y: 3932, hx: 28, hy: 27, bot: 0, top:  49, label: 'sci_tank' },       // p8_zm_off_tank_chemical, SE corner
  { x:    0, y: 2704, hx: 46, hy: 23, top: -190, label: 'reactor_plinth' },   // generator plinth on the back wall's INTERIOR face y2732 (verify-corrected 2026-08-03; mesh back edge y2727, 5u gap)
  // Data Cache "storages" (user 2026-07-10): model reverted p7_zm_sta_computer_tower_01 -> p7_cai_stacking_cargo_crate
  // (the crate the user preferred). The crate SHIPS a _col LOD so it self-collides; these clips are belt-and-suspenders
  // sized SNUG to the 64x64x48 crate. ALL emitted as brushmodel (LED-exempt, zero bake risk). Coords mirror the
  // spawn_cache_at call sites: pit/bus-trench = _acc_glitch_altar.gsc:78-79; plaza = zm_abandoned_cyber_city::
  // acc_spawn_plaza_props (the 3 plaza clips MIGRATED here from gen_plaza_shrink obstacle clips #0-2; 4th added 2026-07-10).
  { x: -360, y: 1950, hx: 32, hy: 32, bot: -240, top:  -192, brushmodel: true, gable: true, label: 'pit_cache_w' },   // trench/pit WEST (z=-240 floor). GABLED 2026-07-19 (fall-exposed under the open pit/bridge; mid-floor -> ridge cap, spills N/S onto open walkable floor)
  { x:  360, y: 1950, hx: 32, hy: 32, bot: -240, top:  -192, brushmodel: true, gable: true, label: 'pit_cache_e' },   // trench/pit EAST (gabled 2026-07-19, same reasoning)
  { x: -320, y:   30, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_1' },  // plaza surface (z=0)
  { x:   80, y:  230, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_2' },  // plaza surface
  { x:  -80, y:  560, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_3' },  // plaza surface
  { x: -360, y:  460, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_4' },  // plaza surface, 4th cache. MOVED off (-420,460) 2026-07-10 (boss pocket vs the L-wall corner x=-480/y=390), then off (-300,460) 2026-07-12 (crate east edge sat inside the plaza window-barricade planks at (-227.5,446)); -360 clears the barricade ~48u + keeps ~78u to the x=-470 doorway jamb.
  { x:  120, y: 1550, hx: 25, hy: 22, top: -169, label: 'perk_slot_vendor' }, // p7_zm_sta_drop_pod_console_blue (Gorod console 49x44x71, yaw 0). Foundry/Exo room EAST; mirrors _acc_glitch_altar spawn_perk_slot_vendor_at (120,1550).
  { x:  395, y: 1948, hx: 15, hy: 17, bot:  -480, top:  -454, brushmodel: true, label: 'ammo_crate_l2' }, // west_ammo_crate_model ([West] pack ZeRoY S4 crate 29x33x25; x NOT origin-centered: model x[-19.6,+9.3] -> clip center = spawn x-5) - abyss L2 EAST, spawn (400,1948).
  { x: -405, y: 1948, hx: 15, hy: 17, bot: -1200, top: -1174, brushmodel: true, label: 'ammo_crate_l5' }, // west_ammo_crate_model (same offset; spawn (-400,1948)) - abyss L5 WEST, the bottom before Paradise.
  { x: -400, y: 1948, hx: 24, hy: 17, bot: -480, top: -402, brushmodel: true, label: 'overclock_terminal' }, // p7_zm_sta_dragon_network_data_terminal (48x34x78) - abyss L2 WEST.
  { x:  400, y: 1948, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'overclock_l5' }, // dragon network terminal - abyss L5 EAST.
  { x: -200, y: -100, hx: 24, hy: 17, bot:     0, top:    78, brushmodel: true, label: 'overclock_plaza' }, // dragon network terminal (48x34x78, yaw 0) - PLAZA start room, the ex-Exo-pod spot (SWAPPED user 2026-07-26; briefly 'overclock_lab' @ (-500,3700) earlier same day). Mirrors _acc_glitch_altar spawn_terminal_at (-200,-100,0).
  { x: -400, y: 1948, hx: 81, hy: 33, bot:  -720, top:  -600, brushmodel: true, label: 'glitch_altar_l3' }, // p7_ram_altar (stone altar 162x66x58, yaw 0 - the 2026-08-03 broadside rotation was REVERTED same day: yaw 90 put the clip 17u from both flanking L3 eruption risers, under the 45u rail). TOP RAISED -662->-600 (2026-07-13): 120u anti-perch cap - the 58u slab top stays unreachable.
  { x:  550, y: -1180, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'paradise_overclock' },   // dragon network terminal - PARADISE east-mid (COMPRESSED 2026-08-02: interior now x[-700,700] y[-2000,-600]).
  { x: -550, y: -1680, hx: 26, hy: 29, bot: -1200, top: -1086, brushmodel: true, label: 'paradise_exo' },         // cryogen stasis pod (YAW 90 2026-08-03 - front east at the arena; 58x53 AABB X/Y-swapped) - PARADISE west-south.
  { x:  550, y: -1680, hx: 25, hy: 22, bot: -1200, top: -1129, brushmodel: true, label: 'paradise_perk_vendor' }, // drop-pod console - PARADISE east-south.
  // Armory stations in PARADISE (user 2026-07-13): the weapon rack cabinet + the mega-bottle Wonderfizz, west wall.
  // Mirror the loft clips (armory_rack / armory_bottle); spawn_paradise call site (_acc_glitch_altar). Both deep -> brushmodel.
  { x: -550, y: -1180, hx:  9, hy: 69, bot: -1200, top: -1152, brushmodel: true, label: 'paradise_armory_rack' },   // p7_con_cargo_train_armory_cabinet 138x18x48, YAW 90 2026-08-03 (long axis Y parallel to the W wall, long face east; pads at the S/N ends +/-55y) - PARADISE west-mid.
  { x: -550, y: -1430, hx: 28, hy: 37, bot: -1200, top: -1090, brushmodel: true, label: 'paradise_armory_bottle' }, // p7_zm_vending_wonder (Wonderfizz 74x56x110, YAW 90 2026-08-03 - front east) - PARADISE west, between the rack and the Exo.
  // Implant Bench pads: THREE per site since 2026-07-09 (slots 2->3). Model = p7_zm_isl_table_operating
  // (79w[X] x 24d[Y] x 42h). PARADISE row = _acc_glitch_altar (-550 -/+ 2*acc_bench_pad_sep=160, -2080),
  // a straight row - unchanged. The IMPLANT LAB row was RE-SPREAD into a staggered ARC 2026-07-10 (room
  // widened east to x180; user "benches cluttered / one against a wall"): mirrors _acc_boss_items::
  // spawn_bench = center pad @ struct(-227.5,-130.67)+off(153,-359) ~(-75,-490); outer pads +/-sep(175)
  // in X, +stag(60) N in Y -> ~(-250,-430) / (100,-430). Coords are dvar-nudgeable live (Plaza:
  // acc_bench_off_*/acc_bench_lab_sep/acc_bench_lab_stagger) - re-sync here + re-run after any nudge.
  { x: -610, y: -1840, hx: 12, hy: 40, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot1' },          // PARADISE Slot 1 (west) - RE-SYNCED 2026-08-03: the 08-02 compression moved the spawns but left these at y-2080 (buried behind the new S wall = walk-through); yaw 90 row (AABB swapped), y-1840
  { x: -450, y: -1840, hx: 12, hy: 40, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot2' },          // PARADISE Slot 2 (center)
  { x: -290, y: -1840, hx: 12, hy: 40, bot: -1200, top: -1158, brushmodel: true, label: 'bench_slot3' },          // PARADISE Slot 3 (east)
  { x: -250, y: -430, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot1' },              // IMPLANT LAB Slot 1 (west, forward) - staggered arc 2026-07-10
  { x:  -75, y: -490, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot2' },              // IMPLANT LAB Slot 2 (center, deepest/back)
  { x:  100, y: -430, hx: 40, hy: 12, bot: 0, top: 42, brushmodel: true, label: 'lab_bench_slot3' },              // IMPLANT LAB Slot 3 (east, forward)
  { x:  878, y:  -100, hx: 69, hy:  9, bot:   192, top:   240, brushmodel: true, label: 'armory_rack' },          // p7_con_cargo_train_armory_cabinet (138x18x48) - Armory loft (RE-SYNCED 2026-07-11: loft rebuilt, floor 288->192, stations 870->878 - _acc_armory::spawn_stations); long axis spans the deposit/withdraw pads.
  { x:  878, y:   100, hx: 37, hy: 28, bot:   192, top:   302, brushmodel: true, label: 'armory_bottle' },        // p7_zm_vending_wonder (Wonderfizz 74x56x110) - Armory loft bottle exchange (RE-SYNCED 2026-07-11, same move).
  { x:   98, y:   200, hx: 19, hy: 17, bot:  -160, top:  -57, brushmodel: true, label: 'transfer_points' },      // p7_out_monitor_atm (37x34x103; YAW-180 flip 2026-08-03: model origin now x=117 = the EAST back face, mesh extends -X over the SAME span x[80,117] -> numbers unchanged; screen faces WEST at the stair approach) - Exchange vault.
  { x:   98, y:    40, hx: 19, hy: 17, bot:  -160, top:  -57, brushmodel: true, label: 'transfer_shards' },      // ATM - Exchange vault.
  { x:   98, y:  -120, hx: 19, hy: 17, bot:  -160, top:  -57, brushmodel: true, label: 'transfer_bottles' },     // ATM - Exchange vault.
  { x:   98, y:  -280, hx: 19, hy: 17, bot:  -160, top:  -57, brushmodel: true, label: 'transfer_items' },       // ATM - Exchange vault.
  // Jukebox + Paradise PaP (model-clip audit 2026-07-10): both are bare spawn(script_model)+setmodel props whose xmodel
  // ships NO _col LOD (verified via find <model>*_col.xmodel_bin + tools/xmodel_bin_inspect.js) -> walk-through until clipped.
  { x: -706, y: 2450, hx: 12, hy: 17, bot: -240, top: -187, brushmodel: true, label: 'jukebox' },   // cp_town_jukebox: mesh sits +X of the spawn origin (-717,2450) -> clip center x=-706. TRUE W wall x-720 (verify-corrected 2026-08-03: the x-384 plane at y2450 is a bay MOUTH, open floor runs to x-720)              // cp_town_jukebox 22.7x33x53, yaw 0; mesh sits +X of the spawn origin (-150,2240) -> clip center x=-139. North under-room SW (spread from the reactor 2026-07-10).
  { x: -259.6, y: 2260.3, hx: 12, hy: 18, bot: -240, top: -187, brushmodel: true, label: 'slots_vending' },       // CYBER SLOTS floor machine (p8_zm_off_cigarette_vending, TOP-origin hangs 52.8, yaw 0) FREE-STANDING at (-250,2260,-187.2) on the open floor between the jukebox and the trench mystery box (REPLACED the outside-the-room wall-hung spot 2026-07-25). Mirrors _acc_slots::spawn_slot_machine; offsets = the surface cig-vending clip deltas (-9.6,+0.3) at yaw 0.
  // TELEPORTER pads have NO clips (FINAL 2026-07-18): the step-up plates (11u, then 8u) were
  // ZOMBIE-SAFE EXPLOITS - entity clips are navmesh-INVISIBLE, so zombies bumped an unseen ledge
  // at EITHER height and couldn't reach players on the pad. Pads are FLAT now (the Der assembly
  // model is walk-through; players stand at floor level inside the ring). l2_pad_green (the trench
  // teleporter pad) was removed with them; the deco l2_pad_red keeps its 11u plate (pure deco).
  { x:    0, y: -1548, hx: 35, hy: 21, bot: -1200, top: -1125, brushmodel: true, label: 'paradise_pap' },        // p9_fxanim_zm_gp_pap_xmodel 67.9x40.6x75; Paradise standalone Pack-a-Punch (deep z=-1200 -> brushmodel required). Vendor moved (0,-1700)->(0,-1550) w/ the 08-02 compression; YAW 180 2026-08-03 (faces the N approach) -> the -2u mesh offset flips: center y -1552 -> -1548.
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
  // pillar_l5_fountain REMOVED 2026-07-30 (user "pig headed model" - the jade snake fountain at (620,2000) was deleted via gen_remove_pighead.js; its 144-wide clip went with it)54x202, E centerpiece
  { x:  470, y: 2110, hx: 48, hy: 48, bot: -1200, top: -976, brushmodel: true, label: 'l5_column' },          // snake column 106x166x318, N wall (MOVED 240->470 off the D4 stair landing + clip shrunk to the solid shaft, drops the 166-deep sparse snake tail, user 2026-07-13)
  { x: -700, y: 1745, hx: 35, hy: 35, bot: -1200, top: -1100, brushmodel: true, label: 'l5_statue_sw' },      // jade statue 69x69x100, SW corner
  { x:  620, y: 2000, hx: 35, hy: 35, bot: -1200, top: -1100, brushmodel: true, label: 'l5_statue_e' },      // jade statue 69x69x100, E-bay centerpiece (old fountain spot; 2026-08-03 - replaces the purged pighead fountain)
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
  { x: -200, y: 2230, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_traffic_street_con_3' },   // bay-rim cordon partner: barrier(-360,2230) -> cone(-200) line (2026-08-03)
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
  { x: -360, y: 2230, hx: 40, hy: 20, bot: 0, top: 44, label: 'bus_traffic_street_bar_2' },   // re-homed 2026-08-03 (prop audit): N bay-rim cordon E of the ACCC000F POWER arrow decal (x[-500,-436] y2195, 36u clear)
  { x: 400, y: 2228, hx: 8, hy: 8, bot: 0, top: 28, label: 'bus_traffic_street_con_2' },
  { x: 150, y: 2210, hx: 71, hy: 2, bot: 0, top: 97, label: 'bus_fence_quarantine_2' },
  { x: -150, y: 2486, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_7' },
  { x: 150, y: 2486, hx: 58, hy: 15, bot: 0, top: 39, label: 'bus_bench_wood_8' },
  { x: 300, y: 2545, hx: 14, hy: 30, bot: 0, top: 44, label: 'bus_booth_chair' },
  { x: -747, y: 2600, hx: 14, hy: 14, bot: 0, top: 36, label: 'bus_sink_bathroom' },
  { x: -751, y: 2680, hx: 10, hy: 10, bot: 0, top: 88, label: 'bus_urinal_bathroom' },
  { x: -665, y: 2704, hx: 14, hy: 11, bot: 0, top: 41, label: 'bus_sink_standing' },
  { x: -485, y: 2645, hx: 5, hy: 24, bot: 0, top: 79, label: 'bus_frame_window_wood' },
  { x: 620, y: 2690, hx: 93, hy: 24, bot: 0, top: 54, label: 'bus_table_kitchen_long_2' },
  { x: 580, y: 2648, hx: 9, hy: 9, bot: 0, top: 27, label: 'bus_stool_counter' },
  { x: 660, y: 2648, hx: 9, hy: 9, bot: 0, top: 27, label: 'bus_stool_counter_2' },
  { x: 775, y: 2695, hx: 15, hy: 14, bot: 0, top: 49, label: 'bus_stove_kitchen' },
  { x: -290, y: 2700, hx: 14, hy: 5, bot: 0, top: 95, label: 'bus_stepladder_lrg' },
  { x: -380, y: 2705, hx: 24, hy: 16, bot: 0, top: 56, label: 'bus_shelve_oilrack' },
  { x: 240, y: 2716, hx: 18, hy: 9, bot: 0, top: 63, label: 'bus_power_panel' },
  { x: -80, y: 2420, hx: 49, hy: 25, bot: 0, top: 38, label: 'bus_table_wood_lrg_bro' },
  { x: 120, y: 2560, hx: 42, hy: 43, bot: 0, top: 19, label: 'bus_debris_rubble_02' },
  { x: -560, y: 2712, hx: 13, hy: 10, bot: 0, top: 66, label: 'bus_tv_vintage_on_4' },
  { x: -560, y: 1690, hx: 8, hy: 8, bot: 0, top: 61, label: 'bus_street_lamp_full' },   // MOVED (-660,1660)->(-560,1690) 2026-07-19 FIX BATCH 4: at (-660,1660) it choked the W trench stair TOP mouth - the only E approach lanes were 33u (travel-kiosk N face y1618.8 -> lamp) and 35u (lamp -> S parapet rail y1703), both under the ~40-45u zombie width -> live co-op pile-up "at the top of the steps". New spot hugs the parapet rail S face (5u seal), E approach lane = kiosk -> lamp 63u; the stair mouth x[-761,-657] is fully clear. misc_model + GSC twin moved in lockstep.
  { x: -660, y: 2400, hx: 8, hy: 8, bot: 0, top: 61, label: 'bus_street_lamp_full_2' },

  // ===== SURFACE ZONES pass 2 (2026-07-16): Alley / Market / Vault / Helipad =====
  // wide props get the anti-perch gable (SURFACE_PREFIXES); MIRROR _acc_surface_deco.gsc.
  { x: 2155, y: 480, hx: 23, hy: 22, bot: 0, top: 83, label: 'alley_tank_chemical' },
  { x: 2155, y: 830, hx: 16, hy: 24, bot: 0, top: 56, label: 'alley_shelve_oilrack' },
  { x: 2155, y: 1060, hx: 23, hy: 22, bot: 0, top: 83, label: 'alley_tank_chemical_2' },
  { x: 2130, y: 1430, hx: 42, hy: 43, bot: 0, top: 19, label: 'alley_debris_rubble_02' },
  { x: 1700, y: 1448, hx: 36, hy: 21, bot: 0, top: 20, label: 'alley_bike_destroyed' },
  { x: 1920, y: 1452, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_debris_rubble_pile' },
  { x: 1510, y: 1466, hx: 71, hy: 2, bot: 0, top: 97, label: 'alley_fence_quarantine' },
  { x: 1440, y: 1462, hx: 18, hy: 8, bot: 0, top: 63, label: 'alley_power_panel' },
  { x: 2070, y: 415, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_tank_chemical_3' },
  { x: 1830, y: 770, hx: 70, hy: 2, bot: 0, top: 90, label: 'alley_fence_quarantine_t' },
  { x: 1730, y: 590, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_debris_rubble_pile_2' },
  { x: 2045, y: 1150, hx: 20, hy: 36, bot: 0, top: 53, label: 'alley_pneumatic_dolly' },
  { x: 1600, y: 860, hx: 24, hy: 16, bot: 0, top: 56, label: 'alley_shelve_oilrack_2' },
  { x: 1940, y: 570, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_tank_chemical_4' },
  { x: 1560, y: 900, hx: 11, hy: 10, bot: 0, top: 30, label: 'alley_mannequin_full' },
  { x: 1356, y: 1000, hx: 4, hy: 14, bot: 0, top: 31, label: 'alley_radiator_vintage' },
  { x: -2102, y: 860, hx: 16, hy: 24, bot: 0, top: 56, label: 'market_shelve_oilrack' },
  { x: -2100, y: 930, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_barrel_wood' },
  { x: -2102, y: 1030, hx: 16, hy: 22, bot: 0, top: 37, label: 'market_counter_kitchen_' },
  { x: -2102, y: 1095, hx: 15, hy: 20, bot: 0, top: 37, label: 'market_counter_kitchen__2' },
  { x: -2103, y: 1385, hx: 15, hy: 14, bot: 0, top: 49, label: 'market_stove_kitchen' },
  { x: -1850, y: 446, hx: 93, hy: 24, bot: 0, top: 54, label: 'market_table_kitchen_lo' },
  { x: -2000, y: 440, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_table_rustic_woo' },
  { x: -1850, y: 500, hx: 9, hy: 9, bot: 0, top: 27, label: 'market_stool_counter' },
  { x: -1870, y: 1390, hx: 93, hy: 24, bot: 0, top: 54, label: 'market_table_kitchen_lo_2' },
  { x: -1615, y: 1364, hx: 30, hy: 14, bot: 0, top: 45, label: 'market_booth_chair' },   // pulled to the table's W end + yaw 90 (hx/hy swapped for the rotation; diner-nook regroup 2026-08-03)
  { x: -2050, y: 1420, hx: 30, hy: 10, bot: 0, top: 26, label: 'market_counter_kitchen__3' },
  { x: -1720, y: 520, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_mannequin_full' },
  { x: -1660, y: 1320, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_mannequin_full_2' },
  // vault_vault_bank_door / vault_tank_chemical / vault_tank_chemical_2 /
  // vault_radiator_vintage / vault_x_tank_chemical REMOVED (M5 anchor upgrade
  // 2026-07-18): the TranZit bank props + vault chem tanks went with their spawns;
  // the BO6 circular vault portal (M5 VAULT section below) is the new S-wall anchor.
  { x: 1899, y: 2400, hx: 20, hy: 20, bot: 0, top: 100, label: 'vault_server_comm_02' },
  { x: 1904, y: 2490, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_computer_tower_0' },
  { x: 1895, y: 2590, hx: 24, hy: 17, bot: 0, top: 78, label: 'vault_dragon_network_d' },
  { x: 1900.5, y: 2680, hx: 18.5, hy: 17, bot: 0, top: 103, label: 'vault_monitor_atm' },
  { x: 1897, y: 2970, hx: 22, hy: 24, bot: 0, top: 71, label: 'vault_drop_pod_console' },
  { x: 1400, y: 2328, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_generator_lg_01_' },
  { x: 1560, y: 2312, hx: 69, hy: 9, bot: 0, top: 48, label: 'vault_cargo_train_armo' },   // MOVED 1650->1560 (M5: opens the S-wall span for the vault portal)
  { x: 1127, y: 2620, hx: 8, hy: 17, bot: 0, top: 63, label: 'vault_power_panel' },
  { x: 1134, y: 2820, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_computer_tower_0_2' },
  { x: 1143, y: 2960, hx: 24, hy: 17, bot: 0, top: 78, label: 'vault_dragon_network_d_2' },
  { x: 1720, y: 3352, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_generator_lg_01__2' },
  { x: -1810, y: 3273, hx: 100, hy: 100, bot: 0, top: 210, label: 'roof_water_tower' },
  // roof_tank_chemical / roof_tank_chemical_2 / roof_barrel_wood / roof_gas_pump REMOVED
  // (M4 hero swap 2026-07-18): the central tank cluster + S gas pump went with their spawns;
  // the bomber-wreck shell (roof_m4_bomber, M4 section below) is the new central obstacle.
  { x: -1760, y: 2330, hx: 24, hy: 16, bot: 0, top: 56, label: 'roof_shelve_oilrack' },
  { x: -1650, y: 2320, hx: 17, hy: 8, bot: 0, top: 63, label: 'roof_power_panel' },
  { x: -1560, y: 2332, hx: 40, hy: 20, bot: 0, top: 44, label: 'roof_traffic_street_b' },
  { x: -1440, y: 2334, hx: 7, hy: 7, bot: 0, top: 28, label: 'roof_traffic_street_c' },
  { x: -1650, y: 3352, hx: 21, hy: 20, bot: 0, top: 40, label: 'roof_cage_animal_med' },
  { x: -1540, y: 3348, hx: 36, hy: 20, bot: 0, top: 53, label: 'roof_pneumatic_dolly' },
  { x: -1140, y: 2650, hx: 8, hy: 17, bot: 0, top: 63, label: 'roof_power_panel_2' },
  { x: -1148, y: 2990, hx: 16, hy: 24, bot: 0, top: 56, label: 'roof_shelve_oilrack_2' },
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
  { x: 1560, y: 1420, hx: 23, hy: 28, bot: 0, top: 14, label: 'alley_x_debris_rubble_' },
  { x: 1900, y: 1280, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_x_tank_chemical' },
  { x: 1700, y: 1300, hx: 11, hy: 10, bot: 0, top: 30, label: 'alley_x_mannequin_full' },
  { x: -1900, y: 900, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_x_barrel_wood' },
  { x: -1500, y: 1100, hx: 23, hy: 28, bot: 0, top: 14, label: 'market_x_debris_rubble_' },
  { x: -1850, y: 700, hx: 11, hy: 10, bot: 0, top: 30, label: 'market_x_mannequin_full' },
  { x: -1560, y: 1364, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_x_table_rustic_w' },   // slid to the sofa-pair midline under the DINER sign (diner-nook regroup 2026-08-03)
  { x: -1450, y: 600, hx: 26, hy: 29, bot: 0, top: 29, label: 'market_x_planter_stone' },
  { x: 1350, y: 3352, hx: 15, hy: 12, bot: 0, top: 72, label: 'vault_x_computer_tower' },
  { x: 1250, y: 2320, hx: 17, hy: 24, bot: 0, top: 78, label: 'vault_x_dragon_network' },
  { x: 1130, y: 3050, hx: 4, hy: 4, bot: 0, top: 33, label: 'vault_x_monitor_suppor' },
  // roof_x_barrel_wood + roof_x_gas_pump REMOVED (M4 hero swap, with their spawns).
  { x: -1200, y: 2700, hx: 23, hy: 22, bot: 0, top: 83, label: 'roof_x_tank_chemical' },
  { x: -1600, y: 3120, hx: 43, hy: 42, bot: 0, top: 19, label: 'roof_x_debris_rubble_' },
  { x: -1550, y: 2900, hx: 8, hy: 8, bot: 0, top: 28, label: 'roof_x_traffic_street' },   // cone - now sits UNDER the M4 bomber hull (clip inside the wreck shell, harmless)
  // ===== PLAZA SURFACE (z=0) - _acc_surface_deco.gsc spawn_plaza() derelict civic
  // plaza pass (M1 visual sweep, 2026-07-18). SHALLOW worldspawn clips (bot:0) ->
  // navmesh AUTO-CUT, LED-safe; wide ones (min half-extent >=12) get the anti-perch
  // gable via the plaza_ SURFACE_PREFIXES entry; thin ones (picket, bollards, stubs,
  // parking blocks) MUST stay flat boxes (gabling a sliver = degenerate brush =
  // linker 0xC0000409). GENERATED with the spawns by scratch gen_plaza_layout.js
  // (bounds-measured, yaw-rotated, origin-offset - the fountain mesh sits +x/-y of
  // its origin, the pedestal -y, parking blocks -0.1x). Grass patches, houseplants
  // and wall-mounts (neon sign, LED strips) carry NO clip. If a prop moves, edit
  // gen_plaza_layout.js -> regen -> paste both blocks -> re-bake (FULL build).
  { x: -31.2, y: 126.2, hx: 22, hy: 37, bot: 0, top: 125, label: 'plaza_fountain' },   // memorial angel fountain HERO (43x72x125, yaw 0 - mesh sits +x/-y of origin natively)
  { x: -454.3, y: 87.1, hx: 17, hy: 108, bot: 0, top: 90, label: 'plaza_bed_w' },      // merged W planter bed: fence 128+64 run + hollyhock/camomile boxes
  { x: 0, y: 699.9, hx: 64, hy: 18, bot: 0, top: 90, label: 'plaza_bed_n' },           // merged N planter bed under the dead neon sign
  { x: -440, y: 215, hx: 2, hy: 4, bot: 0, top: 90, label: 'plaza_picket' },           // lone iron fence picket (7x4x90 sliver - NEVER gable)
  { x: -220, y: 9.5, hx: 34, hy: 17, bot: 0, top: 42, label: 'plaza_bench_1' },        // ornate iron bench row A west (yaw 270 since the 2026-08-03 flip - faces the fountain)
  { x: -140, y: 9.5, hx: 34, hy: 17, bot: 0, top: 42, label: 'plaza_bench_2' },        // row A east (yaw 270)
  { x: -120, y: 335.5, hx: 34, hy: 17, bot: 0, top: 42, label: 'plaza_bench_3' },      // row B west (yaw 270)
  { x: 30, y: 335.5, hx: 34, hy: 17, bot: 0, top: 42, label: 'plaza_bench_4' },        // row B east (yaw 90)
  { x: -438, y: 250, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_1' },        // NW mouth line (leads to, never blocks, the y400-656 gap)
  { x: -438, y: 305, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_2' },
  { x: -438, y: 360, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_3' },
  { x: 180, y: 250, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_4' },         // NE mouth line
  { x: 180, y: 305, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_5' },
  { x: 180, y: 360, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_bollard_6' },
  { x: -380, y: 674.3, hx: 14, hy: 16, bot: 0, top: 47, label: 'plaza_pedestal' },     // classical end post pedestal, NW corner (mesh -y of origin)
  { x: 160, y: -220, hx: 6, hy: 6, bot: 0, top: 19, label: 'plaza_stub_1' },           // broken classical post stub (yaw 35 -> padded square)
  { x: 185, y: -205, hx: 6, hy: 6, bot: 0, top: 25, label: 'plaza_stub_2' },           // broken post stub (yaw 290)
  { x: -428.1, y: -150, hx: 40, hy: 6, bot: 0, top: 8, label: 'plaza_pblock_1' },      // parking block W row (11x80x7, yaw 90; step-over height)
  { x: -90.1, y: -215, hx: 40, hy: 6, bot: 0, top: 8, label: 'plaza_pblock_2' },       // parking block S row
  { x: -0.1, y: -215, hx: 40, hy: 6, bot: 0, top: 8, label: 'plaza_pblock_3' },
  // ===== PLAZA->ALLEY CONNECTOR (density-gradient pass 2026-08-03; docs/47 item 12) =====
  // 9 baked misc_models at the map tail (the 10th, a red cage beacon, was CUT - 2nd instance of a light model crashes the LED bake, see CHANGELOG). Only the 3
  // S-wall floor solids get clips; litter/foliage/wall mounts (blue LED, electric set, wire
  // bundle, biohazard sign, red cage beacon) stay clipless per the M3/M6 no-clip conventions.
  // 'plaza_conn_' rides the existing 'plaza_' SURFACE_PREFIXES entry: the planter (min 26>=12)
  // auto-gables; the 7x7 bollards stay flat slivers (gabling a sliver = 0xC0000409).
  { x: 260, y: 435, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_conn_bollard_1' },   // S-wall cordon echo of the plaza NE mouth line (28u wall standoff = the x180 line's read)
  { x: 315, y: 435, hx: 7, hy: 7, bot: 0, top: 44, label: 'plaza_conn_bollard_2' },   // 55u pitch, same cadence as the plaza lines
  { x: 390, y: 438, hx: 26, hy: 29, bot: 0, top: 29, label: 'plaza_conn_planter' },   // p7_zm_tra_planter_stone (market_x_planter_stone extents); ends the classical run, N lane stays 189u
  // ===== LAB SURFACE (z=0) - _acc_surface_deco.gsc spawn_lab() clinical
  // cyberware-lab pass (M2 visual sweep, 2026-07-18). SHALLOW worldspawn clips
  // (bot:0) -> navmesh AUTO-CUT, LED-safe; wide ones (min half-extent >=12) get
  // the anti-perch gable via the lab_ SURFACE_PREFIXES entry; thin ones (coat
  // rack, curtain, aether canisters, filing cabinet) MUST stay flat (gabling a
  // sliver = degenerate brush = linker 0xC0000409). GENERATED with the spawns by
  // scratch gen_lab_layout.js (bounds-measured, yaw-rotated, origin-offset;
  // validates vs perk strip y>=4020, both corridor mouths, pad r110, wallbuy r90,
  // box strip, PaP, boss r60, risers >=45). The 3 flat teleporter plates, hazmat
  // suits, wall-mounts (lightbox/holo/LED/hanging coats) and the leaned chamber
  // cover carry NO clip. NOTE: lab_bench_slot1-3 above are the IMPLANT LAB
  // (plaza south room), not this zone. If a prop moves, edit gen_lab_layout.js
  // -> regen -> paste both blocks -> re-bake (FULL build).
  { x: 200, y: 3660, hx: 73, hy: 73, bot: 0, top: 62, label: 'lab_teleporter_prototy' },   // HERO teleporter core generator (145 dia, 62 tall) N of the pad
  { x: 332.9, y: 3573, hx: 44, hy: 45, bot: 0, top: 71, label: 'lab_apd_canister' },   // sci-fi coolant canister feeding the core
  // DECON UNITS = WALK-THROUGH (2026-07-19 FIX BATCH 2, were 3 solid gable boxes). Vertex decode:
  // all three are open frames (BO4 walk-through airlocks). Clips now fit the FRAMES only; every
  // passage >=45u so zombies path through (no camping pocket). Lintels/roofs >=12 half-extent
  // auto-gable (anti-perch); thin posts stay flat boxes.
  { x: -616, y: 3104.5, hx: 6, hy: 29.5, bot: 0, top: 118, label: 'lab_decon1_pillar_w' },     // p8_zm_whi_decontamination_unit_open W side pillar (world x[-622,-610])
  { x: -504, y: 3104.5, hx: 6, hy: 29.5, bot: 0, top: 118, label: 'lab_decon1_pillar_e' },     // E side pillar - passage between pillars = 100u
  { x: -560, y: 3104.5, hx: 62, hy: 29.5, bot: 96, top: 118, label: 'lab_decon1_lintel' },     // roof/curtain-rail band (auto-gabled; 96u headroom under it)
  { x: -471, y: 3080, hx: 5, hy: 5, bot: 0, top: 96, label: 'lab_decon2_post_sw' },            // unit_small_open corner posts (canopy frame)
  { x: -363, y: 3080, hx: 5, hy: 5, bot: 0, top: 96, label: 'lab_decon2_post_se' },
  { x: -471, y: 3161, hx: 5, hy: 5, bot: 0, top: 96, label: 'lab_decon2_post_nw' },
  { x: -363, y: 3161, hx: 5, hy: 5, bot: 0, top: 96, label: 'lab_decon2_post_ne' },            // passages: 98u (x), 71u (y)
  { x: -417, y: 3120.5, hx: 59, hy: 45.5, bot: 86, top: 96, label: 'lab_decon2_roof' },        // canopy slab (auto-gabled; 86u headroom)
  { x: -343, y: 3103, hx: 5, hy: 31, bot: 0, top: 113, label: 'lab_decon3_post_w' },           // unit_front 3-post arch frame
  { x: -287, y: 3103, hx: 5, hy: 31, bot: 0, top: 113, label: 'lab_decon3_post_c' },
  { x: -231, y: 3103, hx: 5, hy: 31, bot: 0, top: 113, label: 'lab_decon3_post_e' },           // both bays = 46u
  { x: -289.5, y: 3103, hx: 58.5, hy: 31, bot: 100, top: 113, label: 'lab_decon3_lintel' },    // arch header (auto-gabled; 100u headroom)
  { x: -728.8, y: 3519.9, hx: 25, hy: 67, bot: 0, top: 81, label: 'lab_test_chamber' },   // specimen test chamber (81 tall), W wall
  { x: -738.1, y: 3424.6, hx: 17, hy: 25, bot: 0, top: 117, label: 'lab_energy_barrier_01_' },   // GREEN energy barrier post, W wall (glow)
  { x: -725, y: 3612, hx: 11, hy: 11, bot: 0, top: 73, label: 'lab_coat_lab_rack' },   // lab-coat rack S of the PaP (thin - flat)
  { x: 778.9, y: 3410, hx: 13, hy: 18, bot: 0, top: 44, label: 'lab_medical_cart_main' },   // medical cart
  { x: 782.7, y: 3465, hx: 13, hy: 23, bot: 0, top: 66, label: 'lab_respirator_machine' },   // respirator machine
  // CURTAIN = WALK-THROUGH (2026-07-19 FIX BATCH 2, was one solid 76u sliver): the model is
  // pure hanging fabric (75x3.6, top-origin) - clip only the two END slivers (pole line),
  // middle 56u passage open so players AND zombies brush through the fabric.
  { x: 750.5, y: 3487, hx: 2, hy: 5, bot: 0, top: 83, label: 'lab_curtain_end_s' },         // portable curtain S end sliver
  { x: 750.5, y: 3553, hx: 2, hy: 5, bot: 0, top: 83, label: 'lab_curtain_end_n' },         // N end sliver - passage y[3492,3548] = 56u
  { x: 160.5, y: 3822, hx: 70, hy: 47, bot: 0, top: 65, label: 'lab_apd_turbine' },   // APD turbine (mesh extends -y), FLUSHED onto the new inner N wall face y3868 (2026-08-02 lab compression: interior now y[3068,3868], gen_compress_lab_paradise.js)
  { x: 250, y: 3790, hx: 14, hy: 14, bot: 0, top: 31, label: 'lab_apd_element' },   // APD glowing element core (yaw 45 -> padded square)
  { x: 100, y: 3860, hx: 6, hy: 7, bot: 0, top: 30, label: 'lab_aether_canister_on' },   // aether canister (glow; sliver - flat), flush the new N wall
  { x: 300, y: 3800, hx: 6, hy: 7, bot: 0, top: 30, label: 'lab_aether_canister_on_2' },   // aether canister (glow; sliver - flat)
  { x: 769.9, y: 3794.6, hx: 17, hy: 25, bot: 0, top: 117, label: 'lab_energy_barrier_01__2' },   // RED energy barrier post N of the box (glow)
  // -- 2026-08-02 lab compression: the old E-wall industrial corner (y3835-3965, now sealed band)
  //    relayouts onto the new N wall (face y3868) + an NE spur off the red barrier. Origins mirror
  //    the misc_model moves in gen_compress_lab_paradise.js LAB_MOVES - keep in lockstep. --
  { x: 330, y: 3846.5, hx: 30, hy: 23, bot: 0, top: 56, label: 'lab_console_control_01' },   // control console, new N wall (yaw 90->0: hx/hy swapped)
  { x: 718, y: 3852, hx: 16, hy: 9, bot: 0, top: 52, label: 'lab_filing_cabinet_01' },   // filing cabinet, new N wall (thin - flat)
  { x: 520, y: 3846.5, hx: 44, hy: 23, bot: 0, top: 56, label: 'lab_console_control_02' },   // wide control console, new N wall (yaw 90->0)
  { x: 724, y: 3792, hx: 28, hy: 27, bot: 0, top: 49, label: 'lab_tank_chemical' },   // pressure tank 1 - NE spur (merges w/ the red barrier mass)
  { x: 735, y: 3737, hx: 28, hy: 28, bot: 0, top: 49, label: 'lab_tank_chemical_2' },   // pressure tank 2 (yaw 30 -> padded square) - NE spur south end
  { x: -190, y: 3240, hx: 53, hy: 28, bot: 0, top: 42, label: 'lab_morgue_table' },   // steel morgue/work table -> center-south medical cluster (yaw 0->90)
  { x: 610, y: 3851.2, hx: 21, hy: 15, bot: 0, top: 40, label: 'lab_locker_military_op' },   // locker, open - new N wall
  { x: 658, y: 3851.3, hx: 21, hy: 15, bot: 0, top: 40, label: 'lab_locker_military_cl' },   // locker, closed - new N wall
  // -- 2026-08-02 lab densification (gen_compress_lab_paradise.js NEW_STATICS; all models
  //    already zoned elsewhere in this map - zero new .zone lines) --
  { x: -440, y: 3480, hx: 46, hy: 23, bot: 0, top: 50, label: 'lab_gen_blue' },          // p7_ris_generator_lg_01_blue - W-center data island S anchor
  { x: -450, y: 3560, hx: 12, hy: 15, bot: 0, top: 72, label: 'lab_comp_tower' },        // p7_zm_sta_computer_tower_01 - island W
  { x: -370, y: 3545, hx: 20, hy: 20, bot: 0, top: 100, label: 'lab_server_comm' },      // p7_zm_moo_server_comm_02 - island center
  { x: -300, y: 3510, hx: 24, hy: 17, bot: 0, top: 78, label: 'lab_dragon_terminal' },   // p7_zm_sta_dragon_network_data_terminal (yaw 270) - island E
  { x: -680, y: 3841, hx: 67, hy: 25, bot: 0, top: 81, label: 'lab_test_chamber_2' },    // 2nd specimen test chamber (yaw 90), NW corner vs the new N wall
  { x: -500, y: 3839, hx: 95, hy: 27, bot: 0, top: 124, label: 'lab_console_standing_2' }, // BIG standing console bank (yaw 180), new N wall W
  { x: -270, y: 3841, hx: 57, hy: 27, bot: 0, top: 124, label: 'lab_console_standing_1' }, // standing console bank (yaw 0), new N wall W of the office door
  { x: -115, y: 3240, hx: 13, hy: 18, bot: 0, top: 44, label: 'lab_medical_cart_2' },    // 2nd medical cart (yaw 90 - the orientation these dims fit) beside the morgue table
  // ===== SURFACE center anchors (2026-07-16) =====
  { x: -250, y: 2400, hx: 30, hy: 30, bot: 0, top: 53, label: 'bus_c_pneumatic_dol' },
  { x: -190, y: 2445, hx: 6, hy: 19, bot: 0, top: 27, label: 'bus_c_suitcase_lrg' },
  { x: -300, y: 2360, hx: 14, hy: 16, bot: 0, top: 20, label: 'bus_c_suitcase_med' },
  { x: 1650, y: 928, hx: 22, hy: 23, bot: 0, top: 83, label: 'alley_c_tank_chemical' },
  // alley_c_barrel_wood REMOVED (M3): the wood center anchor became the burn barrel;
  // its replacement clip lives in the M3 section below (alley_m3_barrel_metal_bur).
  { x: -1650, y: 700, hx: 10, hy: 30, bot: 0, top: 26, label: 'market_c_counter_kitch' },
  { x: -1560, y: 820, hx: 25, hy: 17, bot: 0, top: 22, label: 'market_c_table_rustic_' },
  { x: -1680, y: 810, hx: 17, hy: 17, bot: 0, top: 50, label: 'market_c_barrel_wood' },
  { x: 1450, y: 2650, hx: 12, hy: 15, bot: 0, top: 72, label: 'vault_c_computer_towe' },
  { x: 1580, y: 2650, hx: 20, hy: 20, bot: 0, top: 100, label: 'vault_c_server_comm_0' },
  { x: 1500, y: 3000, hx: 46, hy: 23, bot: 0, top: 50, label: 'vault_c_generator_lg_' },
  { x: -1420, y: 2965, hx: 42, hy: 43, bot: 0, top: 19, label: 'roof_c_debris_rubble' },   // crash rubble flush with the M4 bomber shell (intentional graze - overlap legal). SHIFTED N +45 2026-07-19 FIX BATCH 3: at y2920 it blocked the new E-door N passage exit (34u < 45).
  // roof_c_barrel_wood REMOVED (M4 hero swap, with its spawn).
  // ===== M3 MARKET + ALLEY (2026-07-18): market re-theme (neon night-market) +
  // alley densify (service gut) - _acc_surface_deco.gsc spawn_market()/spawn_alley().
  // GENERATED with the spawns by scratch gen_market_alley_layout.js (bounds-measured,
  // yaw-rotated, origin-offset; validates vs box r60 / risers+dog >=45 / door-mouth
  // aprons / kept-clip overlap). REMOVED above with their spawns: market_gas_pump,
  // market_sign_building_ga, market_couch_floral, alley_outhouse, alley_barrel_wood
  // x3, alley_x_barrel_wood x2, alley_cage_animal_med x2, alley_x_cage_animal_me,
  // alley_c_barrel_wood (burn-barrel replacement below). Wall/overhead signage,
  // flush wall mounts (<=15u deep), flat litter, TVs-on-furniture, foliage and the
  // atop-rubble wire coil carry NO clip. The dirty dumpster clip intentionally
  // grazes the two kept S-E alley chem-tank clips by 1-2u (flush junk row -
  // overlapping clip brushes are legal). Wide tops gable via the existing
  // market_/alley_ SURFACE_PREFIXES entries; thin ones stay flat (0xC0000409).
  { x: -1950, y: 700, hx: 52, hy: 97, bot: 0, top: 62, label: 'market_m3_stand_tarp_a' },      // tarp stall A, W stall row (centered origin, z+30.6 lift). hx 63->52 2026-07-19 FIX BATCH 4: the taxi<->stall N-S lane was 49u (horde pinch); 11u shave into the tarp canopy overhang each side -> lane 60u (zombies graze the cloth edge - poles stay covered)
  { x: -1460, y: 900, hx: 63, hy: 97, bot: 0, top: 62, label: 'market_m3_stand_tarp_b' },      // tarp stall B, E stall row
  { x: -1670, y: 600, hx: 97, hy: 63, bot: 0, top: 62, label: 'market_m3_stand_tarp_c' },      // tarp stall C, S mid-row (flush with the center counter cluster)
  { x: -1874, y: 1218.1, hx: 89, hy: 56, bot: 0, top: 116, label: 'market_m3_kiosk_large' },   // film kiosk stall island, mid-north
  { x: -2100, y: 710.7, hx: 38, hy: 94, bot: 0, top: 54, label: 'market_m3_vista_taxi' },      // wrecked taxi vs the W wall (yaw 90). MOVED N +150 2026-07-19: at y560.7 the clip (y[466.7,654.7]) CONTAINED the market riser struct (-2066,560) - zombies rose inside the car. New clip y[616.7,804.7] clears both W-wall risers by >=56u.
  { x: -1600, y: 1440.9, hx: 34, hy: 11, bot: 0, top: 40, label: 'market_m3_booth_sofa' },     // restaurant booth sofa vs the N wall
  { x: -1520, y: 1440.9, hx: 34, hy: 11, bot: 0, top: 40, label: 'market_m3_booth_sofa_2' },   // booth sofa pair
  { x: -1309.4, y: 801.7, hx: 8, hy: 34, bot: 0, top: 57, label: 'market_m3_display_case' },   // display case vs the E wall
  { x: -1311.6, y: 950.3, hx: 12, hy: 18, bot: 0, top: 58, label: 'market_m3_cig_vending' },   // wall-hung cigarette vending (top-origin, hangs z2-58)
  { x: 2100, y: 460, hx: 34, hy: 23, bot: 0, top: 47, label: 'alley_m3_dumpster_dirty' },      // open dirty dumpster, old outhouse bay
  { x: 1416.6, y: 1103.4, hx: 30, hy: 51, bot: 0, top: 53, label: 'alley_m3_dumpster_blue' },  // blue street dumpster, W wall (corner origin)
  { x: 2141.4, y: 746.7, hx: 30, hy: 51, bot: 0, top: 53, label: 'alley_m3_dumpster_green' },  // green street dumpster, E wall (yaw 180)
  { x: 2148, y: 545.9, hx: 23, hy: 30, bot: 0, top: 122, label: 'alley_m3_ac_unit_lrg' },      // large AC unit, E wall (121 tall)
  { x: 2040, y: 1060, hx: 32, hy: 44, bot: 0, top: 95, label: 'alley_m3_scaffolding' },        // scaffolding tower, E mid-room
  { x: 1610, y: 995, hx: 14, hy: 14, bot: 0, top: 44, label: 'alley_m3_barrel_burn' },         // burn barrel center anchor (replaces alley_c_barrel_wood)
  { x: 1592.5, y: 1083.7, hx: 33, hy: 26, bot: 0, top: 150, label: 'alley_m3_chainlink_hole' },// holed chainlink stub, mid-room weave
  { x: 1781, y: 517.8, hx: 48, hy: 17, bot: 0, top: 133, label: 'alley_m3_chainlink_dmg' },    // damaged chainlink run, S mid-room
  { x: 1768, y: 419.6, hx: 86, hy: 23, bot: 0, top: 37, label: 'alley_m3_wire_coil' },         // barbed wire coil along the S wall
  { x: 1445, y: 1250, hx: 16, hy: 14, bot: 0, top: 48, label: 'alley_m3_trash_bin' },          // street trash bin near the corp mouth lane edge
  // ===== M4 BUS STATION + HELIPAD (2026-07-18): corp accent layer (SEALED schoolbus,
  // p7_spa spaceport kit, street kit, staff corner, nature reclaim) + roof hero swap
  // (bomber wreck replaces the tank cluster) - _acc_surface_deco.gsc spawn_bus_station()/
  // spawn_helipad(). GENERATED with the spawns by scratch gen_bus_roof_layout.js
  // (bounds-measured, yaw-rotated, origin-offset; validates vs trench+rim band, stair
  // mouths, bridge span, corridor aprons, box r60, POWER-decal spans, kept-clip overlap).
  // REMOVED above with their spawns: roof_tank_chemical x2, roof_barrel_wood,
  // roof_gas_pump, roof_x_barrel_wood, roof_x_gas_pump, roof_c_barrel_wood.
  // bus_m4_schoolbus_seal = THE SEALED SHELL: one full-perimeter gabled box slightly
  // larger than the whole bus (walk-in interior COMPLETELY unreachable - no door gaps,
  // no window entries; the model ships no _col LOD so this shell is its only collision).
  // roof_m4_bomber = gabled shell over the whole wreck; the kept cone/debris_c clips
  // sit inside/flush with it on purpose (crash rubble - overlapping clips legal).
  // Wall-flush mounts (handrails, railings, chainlink, cloth, wire, timecard, ivy),
  // flat litter and weeds carry NO clip. Wide tops gable via the existing bus_/roof_
  // SURFACE_PREFIXES entries; thin ones stay flat (0xC0000409).
  { x: -27, y: 2658, hx: 234, hy: 70, bot: 0, top: 134, label: 'bus_m4_schoolbus_seal' },     // SEALED dead coach, RE-PARKED AGAIN 2026-07-19 FIX BATCH 3: the parapet spot covered the ACCC000F POWER arrow decal (x[-500,-436] y2195) - user placed those deliberately. Now yaw 0 flush on the TRUE N wall y2728 (seal x[-261,207] y[2588,2728]); stepladder/power_panel moved aside for the span. misc_model + GSC twin in lockstep.
  { x: -600, y: 1519.8, hx: 57, hy: 99, bot: 0, top: 98, label: 'bus_m4_travel_kiosk_btm' },   // travel kiosk (base unit), SW island
  { x: -410, y: 1686, hx: 40, hy: 6, bot: 0, top: 7, label: 'bus_m4_parking_block_gr' },       // parking block row W, S bus-bay rim approach (W of the POWER text decal)
  { x: 200, y: 1686, hx: 40, hy: 6, bot: 0, top: 7, label: 'bus_m4_parking_block_gr_2' },      // parking block row E, S bus-bay rim approach
  { x: 430, y: 2205, hx: 2, hy: 7, bot: 0, top: 128, label: 'bus_m4_street_usa_no_pa' },       // NO PARKING post leaned at the N rim parapet (decals clear)
  { x: 740, y: 1494.9, hx: 12, hy: 27, bot: 0, top: 16, label: 'bus_m4_bike_stand_02' },       // bike stand, SE wall bay S of the staff desk
  { x: 778.3, y: 1590, hx: 19, hy: 36, bot: 0, top: 34, label: 'bus_m4_desk_metal_vinta' },    // staff desk flush on the E wall under the payphone bank
  { x: 768.6, y: 1672, hx: 17, hy: 24, bot: 0, top: 75, label: 'bus_m4_refrigerator_vin' },    // staff fridge, E wall by the S rim corner
  { x: 790, y: 1509.2, hx: 9, hy: 14, bot: 0, top: 72, label: 'bus_m4_locker_open' },          // staff locker (open), E wall
  { x: 789.1, y: 1477.3, hx: 10, hy: 14, bot: 0, top: 72, label: 'bus_m4_locker_closed' },     // staff locker (closed), E wall
  { x: -390, y: 2450, hx: 9, hy: 9, bot: 0, top: 120, label: 'bus_m4_tree_beech_bare_' },      // bare beech (small) trunk clip, N hall
  { x: 350, y: 1600, hx: 9, hy: 9, bot: 0, top: 120, label: 'bus_m4_tree_beech_bare__2' },     // bare beech (medium) trunk clip, S hall
  // BOMBER = ENTERABLE (2026-07-19 FIX BATCH 2, was one sealed gable shell). Vertex decode
  // (tools/xmodel_bin_inspect.js + scratch slicers) proved jup_vertigo_plane_boneyard_bomber_main_01
  // is a CONTINUOUS open-ended hull tube: side walls local x+-[83,98] full length, OPEN belly
  // (interior floor = the world roof floor - navmesh survives), constant cross-section = both tube
  // ends are torn-open mouths (no nose/tail taper), inner roof ~z96. Fitted set: 2 thin wall boxes
  // z[0,85] (seal the skin incl. any window holes) + 2 mono-slope roof wedges (bottom z85 = the
  // invisible interior ceiling, 56deg tops meeting at a ridge over the centerline = anti-perch).
  // Mouths stay OPEN: interior corridor x[-1606,-1442] = 164u wide - zombies path in through both
  // ends, no camping pocket. The cone (roof_x_traffic_street) + debris_c rubble edge sit inside as
  // real visible knee-high obstacles (lanes around them >=60u).
  { x: -1614, y: 2786.5, hx: 8, hy: 263.5, bot: 0, top: 85, label: 'roof_m4_bomber_wall_w' },  // W hull skin, thin box (hx<12 -> flat top, capped by the roof wedge above). W side has only a FRAMED WINDOW (sill+header) - stays sealed.
  // E hull skin SPLIT for the THIRD ENTRANCE (2026-07-19 FIX BATCH 3): vertex decode found the
  // model's side DOUBLE-DOOR bay on the E skin - two full-height ~40u leaves world y[2795,2835] +
  // y[2843,2883] around an 8u mullion y[2835,2843] (the family's _double_door_a variant naming).
  // Each leaf is <45u, so the clip gap is widened ~5u into each visual jamb: S passage y[2790,2835]
  // = 45u, N passage y[2843,2888] = 45u (zombie-pathable), the mullion post keeps its own sliver
  // clip (no walk-through-post). Flanking boxes cap at the same z85 interior ceiling (the roof
  // wedges above start at z85 - no new perch tops). Worldspawn -> navmesh auto-cut at compile.
  { x: -1434, y: 2651.5, hx: 8, hy: 128.5, bot: 0, top: 85, label: 'roof_m4_bomber_wall_e_s' }, // E skin, S of the door bay (y[2523,2780]). WIDENED 2026-07-19 FIX BATCH 4: each 45u door passage -> 55u (another ~10u into the visual jamb; horde-flow pass after the co-op pile-up report)
  { x: -1434, y: 2839, hx: 8, hy: 4, bot: 0, top: 85, label: 'roof_m4_bomber_door_post' },      // door mullion post (y[2835,2843]; sliver - NEVER gable)
  { x: -1434, y: 2974, hx: 8, hy: 76, bot: 0, top: 85, label: 'roof_m4_bomber_wall_e_n' },      // E skin, N of the door bay (y[2898,3050]). WIDENED with wall_e_s: S passage y[2780,2835] = 55u, N passage y[2843,2898] = 55u
  { x: -1573, y: 2786.5, hx: 49, hy: 263.5, bot: 85, top: 96, wedge: 'E', label: 'roof_m4_bomber_roof_w' }, // W roof half: bottom z85 = interior ceiling; top slopes up E to the ridge (worldspawn wedge, LED-safe shallow)
  { x: -1475, y: 2786.5, hx: 49, hy: 263.5, bot: 85, top: 96, wedge: 'W', label: 'roof_m4_bomber_roof_e' }, // E roof half (ridge meets at x-1524, ~56deg both sides)
  { x: -1240, y: 2600, hx: 25, hy: 25, bot: 0, top: 42, label: 'roof_m4_crate_metal_lrg' },    // metal crate, E bay between the door mouths
  { x: -1300, y: 2600, hx: 25, hy: 25, bot: 0, top: 42, label: 'roof_m4_crate_metal_lrg_2' },  // metal crate pair (studio light head rides this clip)
  { x: -1294.2, y: 3255, hx: 116, hy: 69, bot: 0, top: 152, label: 'roof_m4_fuel_tank_rust' }, // rusty fuel tank, NE corner (clear of the lab-door apron)
  { x: -1900, y: 2894.1, hx: 29, hy: 59, bot: 0, top: 62, label: 'roof_m4_generator' },        // field generator, W wall N of the box
  { x: -1866, y: 2965, hx: 5, hy: 5, bot: 0, top: 60, label: 'roof_m4_tank_propane' },         // propane tank beside the generator
  { x: -1856, y: 2950, hx: 5, hy: 5, bot: 0, top: 60, label: 'roof_m4_tank_propane_2' },       // propane tank pair
  { x: -1680, y: 3300, hx: 12, hy: 12, bot: 0, top: 61, label: 'roof_m4_light_studio_tri' },   // studio light tripod (yaw 15 -> padded square), N by the water tower
  { x: -1480, y: 2380, hx: 12, hy: 12, bot: 0, top: 61, label: 'roof_m4_light_studio_tri_2' }, // studio light tripod (yaw 40 -> padded square), S edge kit
  // ===== M5 VAULT anchor upgrade (2026-07-18): the BO6 circular bank-vault door
  // (t10_zm_door_circular_vault_01 set) becomes the zone's S-wall anchor + a BO4
  // Classified bank-security suite - _acc_surface_deco.gsc spawn_vault().
  // GENERATED with the spawns by scratch gen_vault_layout.js (bounds-measured,
  // yaw-rotated, origin-offset; validates vs box r60 / risers+dog >=45 / both
  // W-mouth door aprons / acc_power_vault trigger / kept-clip overlap).
  // REMOVED above with their spawns: vault_vault_bank_door, vault_tank_chemical,
  // vault_tank_chemical_2, vault_radiator_vintage, vault_x_tank_chemical;
  // vault_cargo_train_armo MOVED 1650->1560 (opens the S-wall portal span).
  // vault_m5_door_assembly = ONE gabled shell over the whole portal (frame+leaf+
  // wheel+hinge). The metal detector gets its two side-pillar clips ONLY - the
  // 41u walkway gap between them stays OPEN (players walk through the archway).
  // Sockets/monitors/screens/plaques are wall mounts with NO clip. Wide tops
  // gable via the existing vault_ SURFACE_PREFIXES entry; thin ones stay flat
  // (0xC0000409 degenerate-brush trap).
  { x: 1780, y: 2310, hx: 96, hy: 30, bot: 0, top: 128, label: 'vault_m5_door_assembly' },       // ANCHOR sealed vault portal, S wall (frame+leaf+wheel+hinge in one gabled clip). FLUSHED -20y 2026-07-19 FIX BATCH 3: M5 assumed wall plane y2300, real interior plane is y2280.
  { x: 1660, y: 2288.9, hx: 16, hy: 9, bot: 0, top: 96, label: 'vault_m5_safety_deposit' },      // safety-deposit panel, S wall west flank
  { x: 1908, y: 2288.9, hx: 16, hy: 9, bot: 0, top: 96, label: 'vault_m5_safety_deposit_2' },    // safety-deposit panel, S wall east flank
  { x: 1910, y: 2356, hx: 9, hy: 16, bot: 0, top: 96, label: 'vault_m5_safety_deposit_3' },    // safety-deposit panel, E wall SE nook (old chem-tank bay)
  { x: 1700, y: 2450, hx: 29, hy: 23, bot: 0, top: 55, label: 'vault_m5_console_control_' },     // security control console W, ops row facing the vault door. hx 36->29 2026-07-19 FIX BATCH 4 (with the filing-cabinet shaves below): filing->ops N-S lane 47u -> 60u; console mesh edge grazes, desk body stays covered
  { x: 1886.7, y: 2450, hx: 36, hy: 23, bot: 0, top: 55, label: 'vault_m5_console_control__2' }, // security control console E (114u door aisle between)
  { x: 1892, y: 3280, hx: 27, hy: 57, bot: 0, top: 124, label: 'vault_m5_console_standing' },    // standing console bank, E wall N of the box (103u clear)
  { x: 1470, y: 3351.9, hx: 95, hy: 27, bot: 0, top: 124, label: 'vault_m5_console_standing_2' },// BIG standing console bank, N wall (old TranZit-door span)
  { x: 1142, y: 2880, hx: 10, hy: 22, bot: 0, top: 127, label: 'vault_m5_monitor_pole' },        // security-monitor floor pole, W wall (old teller-window bay)
  { x: 1610, y: 3376, hx: 39, hy: 4, bot: 0, top: 106, label: 'vault_m5_elevator_pair' },        // closed elevator door pair, N wall (flush flat clip)
  { x: 1598, y: 2458, hx: 13, hy: 8, bot: 0, top: 52, label: 'vault_m5_filing_cabinet_0' },      // filing cabinet, W of the ops row. hx 19->13 2026-07-19 FIX BATCH 4 (filing->ops lane 47u -> 60u with the console shave; drawer-front graze OK)
  { x: 1596.6, y: 2420, hx: 12, hy: 8, bot: 0, top: 52, label: 'vault_m5_filing_cabinet_0_2' },  // filing cabinet pair (hx 18->12, same lane widening)
  { x: 1133.8, y: 2700, hx: 15, hy: 21, bot: 0, top: 40, label: 'vault_m5_locker_military_' },   // military locker, W wall between the door mouths
  { x: 1133.8, y: 2742, hx: 15, hy: 21, bot: 0, top: 40, label: 'vault_m5_locker_military__2' }, // military locker pair (flush)
  { x: 1290, y: 2400.5, hx: 21, hy: 7, bot: 0, top: 109, label: 'vault_m5_detector_s' },         // metal-detector S pillar (the 41u walkway gap stays OPEN)
  { x: 1290, y: 2455.5, hx: 21, hy: 7, bot: 0, top: 109, label: 'vault_m5_detector_n' },         // metal-detector N pillar
  // ===== M6 ABYSS ORGANICS + PARADISE + MISSED ROOMS (2026-07-18): the final visual-sweep
  // batch - _acc_abyss_deco.gsc spawn_m6_trench/l2/l3/l4/l5() + _acc_surface_deco.gsc
  // spawn_paradise_m6/armory_loft_m6/implant_lab_m6/under_rooms_m6() + the re-enabled
  // _acc_atmosphere exchange rack. GENERATED with the spawns by scratch gen_m6_layout.js
  // (bounds-measured; keep-clears validated: abyss stairwell bands + stair landings +
  // station kiosks r110 + L4 Gantry + L5 Paradise-door/Overlook + all 12 Paradise risers +
  // perk row + PaP/wonder ring + armory/implant/under-room aprons). ALL M6 clips are
  // brushmodel:true FLAT boxes (trench/abyss rule: LED-exempt, NEVER gabled - "anything in
  // the trench is fine"; the deep floors require brushmodel anyway). Ceiling/wall mounts,
  // moss/grass/weeds, flush art (doors/electric sets) and the flat spawner hole carry NO clip.
  // (mesh-offset note: the White tunnel bins are NOT origin-centered - segment yaw90 mesh spans
  // y[origin, origin+32]; the dmg wreck spans x[origin-141, origin+279]. Clip centers below are
  // the MESH centers, not the spawn origins - keep them offset or the clip guards air.)
  // m6_tr_seg_w + m6_tr_seg_e REMOVED 2026-07-19 FIX BATCH 4 (live co-op: zombies PILED UP at the
  // trench stair bottoms). The two 168x24 wall-rib clips were the ONLY brushmodel clips standing on
  // the open pit floor's N strip - the same strip the W stair's bottom mouth (x[-761,-665] y[2091,
  // 2173]) opens onto. Brushmodel clips are navmesh-INVISIBLE; the runtime DisconnectPaths sweep
  // (manage_prop_clip_navmesh) disables every nav POLY the brush touches, and over a big open slab
  // those polys extend far past the clip footprint - so the ribs could kill the N-strip polys that
  // link the stair landing to the pit floor (zombies stack at the last connected poly = "bottom of
  // the stairs"). The rib MODELS stay (24u-deep wall dressing, walk-through is invisible at a wall);
  // with no clip there is also no perch top at all, so the old fall-exposure wedge is moot.
  // m6_tr_wreck REMOVED 2026-07-19: the 418x164 full-height wreck clip (x[240,658] y[1723,1887])
  // sealed the E trench stair's only pit-floor approach (29u slot vs the x687 stair wall, < the
  // 32u player capsule) AND swallowed the (480,1830) trench riser. The riser rows (y1830/y2070,
  // x +-160/+-480) leave NO legal pit spot for a footprint that big - prop + clip + GSC twin deleted.
  { x: 300, y: 1743, hx: 84, hy: 16, bot: -480, top: -354, brushmodel: true, label: 'm6_l2_seg' },        // tunnel rib vs the L2 S wall E bay
  { x: -700, y: 1837, hx: 80, hy: 114, bot: -720, top: -562, brushmodel: true, label: 'm6_l3_tent1' },    // L3 wall tentacle mass (x[-780,-620] y[1723,1951]; wraps the SW spore-rock clip - overlap legal)
  { x: -650, y: 2060, hx: 50, hy: 49, bot: -720, top: -674, brushmodel: true, label: 'm6_l3_egg1' },      // L3 egg nest, W bay N. hy 59->49 2026-07-19 FIX BATCH 4: the tent1<->egg-blob W-bay lane was 50u (and egg1->N wall 54u); organic mesh edge graze OK -> lane 60u/64u
  { x: -560, y: 2110, hx: 60, hy: 60, bot: -720, top: -674, brushmodel: true, label: 'm6_l3_egg2' },      // L3 egg nest (yaw 120 - padded square)
  { x: -690, y: 2140, hx: 60, hy: 33, bot: -720, top: -674, brushmodel: true, label: 'm6_l3_egg3' },      // L3 egg nest vs the N wall (clamped y<=2173)
  { x: -640, y: 1940, hx: 17, hy: 37, bot: -960, top: -937, brushmodel: true, label: 'm6_l4_pigslab' },   // L4 butcher slab
  { x: 620, y: 1745, hx: 14, hy: 14, bot: -960, top: -895, brushmodel: true, label: 'm6_l4_mannequin' },  // L4 specimen mannequin
  // m6_l5_hive REMOVED (user 2026-07-26 "clip/model blocking you on the stairs... preventing players from
  // completing the map"): the hive @ (260,2105) x[197,323] y[2040,2170] sat IN the D4 stairwell band
  // (y[2045,2173]) - the EXACT landing spot l5_column was already moved off of (240,2110 -> 470, user
  // 2026-07-13). Together with m6_l5_brute1 (x[132,208] y[1956,2024]) it pinched every exit from the
  // final L4->L5 stairs to <=20u slivers (player capsule ~32u) = map uncompletable. The D4 landing
  // (x[112,~420] x y[1956,2173]) is a KEEP-CLEAR - never place a clipped prop there again.
  { x: -640, y: -1940, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm1' },  // PARADISE palm trunk, SW corner (TRUNK-ONLY - canopy ~300u up). All 7 re-homed by the 2026-08-02 compression (interior now x[-700,700] y[-2000,-600]).
  { x: 640, y: -1940, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm2' },   // palm trunk, SE corner
  { x: 640, y: -660, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm3' },    // palm trunk, NE corner
  { x: -640, y: -660, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm4' },   // palm trunk, NW corner
  { x: -650, y: -1035, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm5' },  // palm trunk, W wall (by the satellite nest)
  { x: 650, y: -1450, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm6' },   // palm trunk, E wall mid
  { x: -80, y: -1950, hx: 16, hy: 16, bot: -1200, top: -1080, brushmodel: true, label: 'm6_pd_palm7' },   // palm trunk, S wall center (behind the heart)
  { x: 990, y: 208, hx: 14, hy: 14, bot: 192, top: 234, brushmodel: true, label: 'm6_ar_rack1' },         // ARMORY loft gun rack, N wall E
  { x: 1042, y: 208, hx: 14, hy: 14, bot: 192, top: 234, brushmodel: true, label: 'm6_ar_rack2' },        // gun rack, NE corner
  { x: 720, y: 170, hx: 37, hy: 55, bot: 192, top: 240, brushmodel: true, label: 'm6_ar_ammo' },          // ammo crate pile, NW corner (yaw 90 bbox)
  { x: 700, y: -205, hx: 21, hy: 15, bot: 192, top: 231, brushmodel: true, label: 'm6_ar_locker' },       // military locker, SW corner
  { x: 150, y: -250, hx: 16, hy: 9, bot: 0, top: 52, brushmodel: true, label: 'm6_il_filing' },           // IMPLANT LAB filing cabinet, NE corner
  { x: 165, y: -300, hx: 11, hy: 11, bot: 0, top: 72, brushmodel: true, label: 'm6_il_coat' },            // lab-coat rack, E wall
  // implant-lab curtain: same walk-through treatment as the Lab one (2026-07-19) - end slivers only, 56u middle passage.
  { x: -680, y: -503, hx: 3, hy: 5, bot: 0, top: 83, brushmodel: true, label: 'm6_il_curtain_s' },        // portable curtain S end sliver (brushmodel is NEVER gabled, no 0xC0000409 risk)
  { x: -680, y: -437, hx: 3, hy: 5, bot: 0, top: 83, brushmodel: true, label: 'm6_il_curtain_n' },        // N end sliver
  { x: -140, y: 1430, hx: 24, hy: 34, bot: -240, top: -118, brushmodel: true, label: 'm6_us_tank' },      // UNDER-S Foundry pressure tank
  { x: -150, y: 1560, hx: 19, hy: 32, bot: -240, top: -207, brushmodel: true, label: 'm6_us_table' },     // steel table (yaw 90 bbox)
  { x: -100, y: 1440, hx: 15, hy: 15, bot: -240, top: -194, brushmodel: true, label: 'm6_us_canister' },  // industrial canister
  { x: 300, y: 2380, hx: 24, hy: 34, bot: -240, top: -118, brushmodel: true, label: 'm6_un_tank' },       // UNDER-N pressure tank, E wall
  { x: 240, y: 2660, hx: 32, hy: 19, bot: -240, top: -207, brushmodel: true, label: 'm6_un_table' },      // steel table, NE back bay
  { x: 300, y: 2680, hx: 15, hy: 15, bot: -240, top: -194, brushmodel: true, label: 'm6_un_canister1' },  // canister by the table
  { x: 150, y: 2710, hx: 15, hy: 15, bot: -240, top: -194, brushmodel: true, label: 'm6_un_canister2' },  // canister vs the back wall
  { x: -400, y: 200, hx: 14, hy: 12, bot: -160, top: -133, brushmodel: true, label: 'm6_ex_rack' },       // EXCHANGE re-enabled server rack (28x24x27 - mirrors l2_rack); z RAISED 2026-07-19: exchange floor is -160 (stale -240 comment trap), the old clip+prop were buried 80u under the slab

  // ===== INFESTATION CLIPS (2026-07-29, user "add precise clips... careful for ground clips") =====
  // Policy: clip ONLY free-standing fat bodies + cluster masses from the ACCINF01/02 + ACCSWP01
  // batches; wall/prop-FUSED eggs, thin stalks, carpets, wall growths, ceiling pieces, glyphs and
  // the prone soldier corpse stay walk-through (brushable - lanes survive). All DEEP (< -240) so
  // ALL brushmodel (LED-exempt; worldspawn below -240 = brush.cpp:1860 crash). 26 entities total,
  // BOUNDED + documented (G_Spawn budget note in CHANGELOG). Abyss floors are CEILINGED -> flat
  // tops legal (the 2026-07-19 anti-perch rule targets open fall columns; none of these sit under
  // a well - verified against the D-well keep-clear bands). PARADISE mass clips carry TALL CAPS
  // (top floor+130..150, the glitch_altar_l3 unreachable-cap trick) - a perchable nest ledge or a
  // walk-in horseshoe pocket would cheese the finale arena, so the heart box also SEALS the pocket.
  // -- descent: free-standing bodies (egg core = 48x48 snug box, top floor+58; lean tips overhang) --
  // inf_l2_stray_egg REMOVED (Wave 1 prop audit deleted the free-standing mid-lane egg at (490,1810) but its clip survived = a 48x48 invisible barrier mid-floor at L2; the regen drops the orphan brush)
  { x:  250, y: 1765, hx: 24, hy: 24, bot:  -720, top:  -662, brushmodel: true, label: 'inf_l3_s_egg' },       // S hazard-pod anchor (D3 well x[-112,112] clear)
  { x: -720, y: 2030, hx: 14, hy: 14, bot:  -720, top:  -620, brushmodel: true, label: 'inf_l3_tendril' },     // plant03 trunk, W-bay nest pocket
  { x: -625, y: 2100, hx: 75, hy: 55, bot:  -720, top:  -648, brushmodel: true, label: 'inf_l3_wnest' },       // the ORIGINAL M6 3-egg W-bay nest (also unclipped until now)
  // (inf_l4_vessel_egg / inf_l5_fa_egg1 / inf_l5_fa_egg3 / inf_l5_fb_egg REMOVED 2026-07-29b -
  //  their pieces were CUT by gen_infestation_thin.js, the ~29% L4/L5 clutter reduction)
  { x: -500, y: 2000, hx: 14, hy: 14, bot:  -960, top:  -860, brushmodel: true, label: 'inf_l4_tendril' },     // plant03 trunk behind the tank
  { x: -670, y: 2100, hx: 55, hy: 55, bot:  -960, top:  -870, brushmodel: true, label: 'inf_l4_hive02' },      // 'the specimen that got away' green mass (mesh 124 wide)
  { x: -700, y: 2055, hx: 55, hy: 60, bot: -1200, top: -1077, brushmodel: true, label: 'inf_l5_hive01' },      // the re-homed W-wall hive (mesh x[-762,-638]; queen clip x[-529,-389] clear)
  { x: -220, y: 2145, hx: 55, hy: 28, bot: -1200, top: -1110, brushmodel: true, label: 'inf_l5_hive02_n' },    // N-wall green hive (W of the D4 well band x[112,420])
  { x: -660, y: 1930, hx: 24, hy: 24, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_fa_egg2' },     // Field A south
  { x: -300, y: 2050, hx: 24, hy: 24, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_anchor_egg' },  // hive02 anchor (riser (-400,2046) clear per design)
  // -- COVERAGE v2 (2026-07-29b, user "a lot of models are missing clips" - post-thin, every
  //    remaining solid BODY gets a snug clip: fused eggs get wall/prop-flush boxes (never
  //    protruding past the model into the lane), poison stalks get 24u trunk boxes. Still
  //    unclipped by design: carpets/fans, membranes, vines, wall arms, glyphs, ceilings, the
  //    prone soldier, and the L3 swap stalk at (-250,1760) (its clip edge would graze the D3
  //    soul-trigger r110). L1 egg = worldspawn (bot -240 legal, saves a slot). --
  { x:  330, y: 1748, hx: 20, hy: 14, bot:  -240, top:  -182, label: 'inf_l1_egg' },                            // THE one L1 egg, S-rim tuck (worldspawn)
  { x:  688, y: 2132, hx: 20, hy: 18, bot:  -480, top:  -422, brushmodel: true, label: 'inf_l2_gen_egg' },      // generator-corner egg (flush NE)
  { x: -702, y: 1990, hx: 18, hy: 20, bot:  -480, top:  -422, brushmodel: true, label: 'inf_l2_breaker_egg' },  // breaker-wall egg (flush W)
  { x:  720, y: 2085, hx: 12, hy: 12, bot:  -480, top:  -390, brushmodel: true, label: 'inf_l2_stalk' },        // poison stalk by the generator egg
  { x:  680, y: 1790, hx: 60, hy: 45, bot:  -720, top:  -655, brushmodel: true, label: 'inf_l3_enest' },        // the SECOND nest cluster (2 eggs, E-S bay)
  { x:  600, y: 1780, hx: 12, hy: 12, bot:  -720, top:  -630, brushmodel: true, label: 'inf_l3_stalk' },        // second-nest spore stalk
  { x:  450, y: 1750, hx: 12, hy: 12, bot:  -720, top:  -630, brushmodel: true, label: 'inf_l3_stalk_grn' },    // swap poison_green (old tall_grass spot)
  { x:  702, y: 2072, hx: 20, hy: 20, bot:  -720, top:  -662, brushmodel: true, label: 'inf_l3_ne_egg' },       // NE rock-fused egg (flush)
  { x:  505, y: 2012, hx: 20, hy: 20, bot:  -720, top:  -662, brushmodel: true, label: 'inf_l3_emid_egg' },     // E-mid rock-fused egg (flush)
  { x:  452, y: 1748, hx: 20, hy: 16, bot:  -960, top:  -902, brushmodel: true, label: 'inf_l4_vsw_egg' },      // vessel SW-corner egg (flush S)
  { x:  758, y: 1748, hx: 20, hy: 16, bot:  -960, top:  -902, brushmodel: true, label: 'inf_l4_vs_egg' },       // vessel S-face egg (flush S wall)
  { x: -552, y: 1790, hx: 20, hy: 20, bot:  -960, top:  -902, brushmodel: true, label: 'inf_l4_frost_egg' },    // frosted-pod clutch egg (flush W)
  { x: -580, y: 2058, hx: 20, hy: 20, bot:  -960, top:  -902, brushmodel: true, label: 'inf_l4_hive_egg' },     // hive02 E-edge anchor egg
  { x:  630, y: 1885, hx: 12, hy: 12, bot:  -960, top:  -870, brushmodel: true, label: 'inf_l4_stalk' },        // L4 poison stalk
  { x: -602, y: 1990, hx: 20, hy: 20, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_ring_egg' },     // hive01 ring egg
  { x:  555, y: 1865, hx: 20, hy: 20, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_fbs_egg' },      // Field B south egg (was fountain-fused; now rings the l5_statue_e jade idol 80u NE)
  { x:  720, y: 1905, hx: 20, hy: 20, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_fbe_egg' },      // Field B east egg (brute2-fused)
  { x:  620, y: 1757, hx: 20, hy: 20, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_altar_egg' },    // S-band altar anchor egg
  { x: -190, y: 1772, hx: 20, hy: 20, bot: -1200, top: -1142, brushmodel: true, label: 'inf_l5_niche_egg' },    // W niche anchor egg
  { x:  560, y: 1740, hx: 12, hy: 12, bot: -1200, top: -1110, brushmodel: true, label: 'inf_l5_stalk' },        // S-edge poison stalk
  // -- PARADISE: cluster boxes w/ tall anti-camp caps (floor -1200; risers r45 + perk r60 + PaP r200
  //    + kiosk r110 + bench pads all re-checked against the design's keep-clear notes) --
  { x:   40, y: -1865, hx: 270, hy: 75, bot: -1200, top: -1065, brushmodel: true, label: 'inf_pd_heart' },     // THE HEART: horseshoe+totem+altar+nest columns as ONE sealed mass (all inf_pd_* re-homed by the 2026-08-02 compression; bench row y-1810 backs onto its W flank, box (450,-1900) clears the E edge 310)
  { x: -232, y: -672, hx: 97, hy: 57, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_jaw_w' },       // gate W jaw (E edge -135 keeps the x[-132,132] hall-mouth lane open; UNCHANGED - the N wall did not move)
  { x:  232, y: -672, hx: 97, hy: 57, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_jaw_e' },       // gate E jaw
  { x: -602, y: -1912, hx: 78, hy: 78, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_brood_sw' },   // SW corner brood + tendril (bench slot1 y[-1822,-1798] backs onto its N edge -1834)
  { x:  602, y: -1912, hx: 78, hy: 78, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_brood_se' },   // SE corner brood + plant02 sprawl (box (450,-1900) W of it, gap 44)
  { x: -597, y: -675, hx: 75, hy: 70, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_brood_nw' },    // NW corner brood (QR perk (-630,-820) r60: gap 15)
  { x:  597, y: -675, hx: 75, hy: 70, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_brood_ne' },    // NE corner brood (EC perk (630,-820) r60: gap 15)
  { x: -605, y: -1000, hx: 60, hy: 55, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_sat_w' },      // W satellite nest (armory rack kiosk (-550,-1180) r110: gap 15 past the circle)
  { x:  620, y: -1005, hx: 55, hy: 55, bot: -1200, top: -1070, brushmodel: true, label: 'inf_pd_sat_e' },      // E satellite nest (OC kiosk (550,-1180) r110: gap 11 past the circle)
  { x:  435, y:  -690, hx: 24, hy: 24, bot: -1200, top: -1142, brushmodel: true, label: 'inf_pd_perkgap_e' },  // perk-gap egg E (between Widow x370 and PhD x500 in the tightened row). W twin at (-435,-690) intentionally UNCLIPPED.
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

// ANTI-PERCH MONO-SLOPE WEDGE (2026-07-19): like gableBox but ONE tilted top plane - for props
// hugging a wall, where a gable's far slope would spill the player INTO the wall/a dead pocket.
// `raise` = which edge is HIGH ('N'=+y, 'S'=-y, 'E'=+x, 'W'=-x); the player slides toward the
// OPPOSITE (open-floor) side. Rise = 1.5x the full span across the slope => ~56deg cross-slope,
// past the walkable limit. Same >=12u min-half-extent rule as gables (thin slivers stay flat -
// the degenerate-brush linker crash applies to wedges too). Winding follows the proven gableBox
// roof convention: outward normal = (p3-p1)x(p2-p1).
// FALL-EXPOSURE RULE (2026-07-19, supersedes "trench/abyss clips stay flat"): any trench/abyss
// clip top under an OPEN fall column (the pit is open to the surface rim + the Rocket-Shield
// bridge) gets a wedge/gable; clips under a ceiling (abyss L2-L5, under-rooms, Exchange, loft)
// stay flat - no fall column can put a player on them.
function wedgeBox(x1, x2, y1, y2, z1, z2, tex, raise) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const span = (raise === 'N' || raise === 'S') ? (y2 - y1) : (x2 - x1);
  const peak = z2 + Math.max(24, Math.ceil(span * 1.5));
  let top;
  if (raise === 'N')      top = ` ( ${x1} ${y1} ${z2} ) ( ${x1} ${y2} ${peak} ) ( ${x2} ${y1} ${z2} ) ${t}`;
  else if (raise === 'S') top = ` ( ${x1} ${y2} ${z2} ) ( ${x2} ${y2} ${z2} ) ( ${x1} ${y1} ${peak} ) ${t}`;
  else if (raise === 'E') top = ` ( ${x1} ${y2} ${z2} ) ( ${x2} ${y2} ${peak} ) ( ${x1} ${y1} ${z2} ) ${t}`;
  else                    top = ` ( ${x2} ${y1} ${z2} ) ( ${x1} ${y1} ${peak} ) ( ${x2} ${y2} ${z2} ) ${t}`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,   // bottom (-z)
    top,                                                                        // tilted top
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,             // y1 wall (-y)
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,            // x2 wall (+x)
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,              // y2 wall (+y)
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`].join('\n') + '\n}';
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
function brushmodelEntity(label, brush) {   // brush = prebuilt "{ guid... planes }" (box/gableBox/wedgeBox)
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
    // Anti-perch tops for FALL-EXPOSED brushmodel clips (see wedgeBox header): `wedge: 'N|S|E|W'`
    // (raised edge; slides toward the opposite open side) or `gable: true` (mid-floor, ridge cap).
    let body, tag = '';
    if (p.wedge && Math.min(p.hx, p.hy) >= 12) { body = wedgeBox(x1, x2, y1, y2, z1, z2, MAT, p.wedge); tag = ` [anti-perch wedge raise-${p.wedge}]`; }
    else if (p.gable && Math.min(p.hx, p.hy) >= 12) { body = gableBox(x1, x2, y1, y2, z1, z2, MAT); tag = ' [anti-perch gable]'; }
    else body = box(x1, x2, y1, y2, z1, z2, MAT);
    entityBlock.push(`// clip(brushmodel): ${p.label} @ (${p.x},${p.y}) z[${z1},${z2}]${tag}`);
    entityBlock.push(brushmodelEntity(p.label, body));
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
  // 'lab_' (M2, 2026-07-18) = the LAB PaP/perk zone surface clips. The pre-existing
  // lab_bench_slot1-3 (IMPLANT LAB, plaza south room) are brushmodel:true and take the
  // brushmodel branch above BEFORE this check, so the prefix never gables them.
  const SURFACE_PREFIXES = ['bus_', 'alley_', 'market_', 'vault_', 'roof_', 'plaza_', 'lab_'];
  const antiPerch = SURFACE_PREFIXES.some(pre => p.label.startsWith(pre)) && Math.min(p.hx, p.hy) >= 12;
  // `wedge:` is honored on WORLDSPAWN entries too (2026-07-19, bomber enterable rework):
  // a shallow (bot >= 0) mono-slope wedge bakes fine as worldspawn and avoids the
  // brushmodel DisconnectPaths sweep entirely (the bomber roof wedges float at z85+ -
  // nothing for navmesh to cut, and worldspawn costs zero entities).
  if (p.wedge && Math.min(p.hx, p.hy) >= 12) {
    block.push(`// clip: ${p.label} @ (${p.x},${p.y}) [anti-perch wedge raise-${p.wedge}]`);
    block.push(wedgeBox(x1, x2, y1, y2, z1, z2, MAT, p.wedge));
  } else {
    block.push(`// clip: ${p.label} @ (${p.x},${p.y})${antiPerch ? ' [anti-perch gable]' : ''}`);
    block.push(antiPerch ? gableBox(x1, x2, y1, y2, z1, z2, MAT) : box(x1, x2, y1, y2, z1, z2, MAT));
  }
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
