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
//   - exo_station    (230,1450) Foundry  - p7_cai_work_table_metal_03_white       (_acc_exo::spawn_station_at)
//        (room RELOCATED east to center x=350 on 2026-06-25 so its door clears the abyss well; clip +350 too)
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
  { x: -120, y: 1550, hx: 26, hy: 29, top: -126, label: 'exo_station' },  // p7_cry_cryogen_pod_exterior (stasis pod 58x53x114, spawns yaw 90 -> X/Y swapped) - Foundry/Exo room WEST (-120,1550); mirrors _acc_exo::spawn_station_at.
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
  { x: -300, y:  460, hx: 32, hy: 32, bot:    0, top:    48, brushmodel: true, label: 'plaza_cache_4' },  // plaza surface, 4th cache. MOVED off (-420,460) 2026-07-10 - that spot pocketed a boss vs the L-wall corner (x=-480 / y=390); -300 is open main plaza, ~180u clear.
  { x:  120, y: 1550, hx: 25, hy: 22, top: -169, label: 'perk_slot_vendor' }, // p7_zm_sta_drop_pod_console_blue (Gorod console 49x44x71, yaw 0). Foundry/Exo room EAST; mirrors _acc_glitch_altar spawn_perk_slot_vendor_at (120,1550).
  { x:  400, y: 1948, hx: 39, hy: 10, bot:  -480, top:  -459, brushmodel: true, label: 'ammo_crate_l2' }, // p7_zm_sha_crate_ammo_closed_sml_stack_full (ammo-crate stack 78x20x21) - abyss L2 EAST.
  { x: -400, y: 1948, hx: 39, hy: 10, bot: -1200, top: -1179, brushmodel: true, label: 'ammo_crate_l5' }, // ammo-crate stack - abyss L5 WEST, the bottom before Paradise.
  { x: -400, y: 1948, hx: 24, hy: 17, bot: -480, top: -402, brushmodel: true, label: 'overclock_terminal' }, // p7_zm_sta_dragon_network_data_terminal (48x34x78) - abyss L2 WEST.
  { x:  400, y: 1948, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'overclock_l5' }, // dragon network terminal - abyss L5 EAST.
  { x: -400, y: 1948, hx: 81, hy: 33, bot:  -720, top:  -662, brushmodel: true, label: 'glitch_altar_l3' }, // p7_ram_altar (stone altar 162x66x58) - abyss L3; slab x[-781,-112] holds the 162 width fine.
  { x: -850, y: -1350, hx: 81, hy: 33, bot: -1200, top: -1142, brushmodel: true, label: 'paradise_altar' },       // p7_ram_altar - PARADISE west-mid (was a skipped walk-through clip; brushmodel = real collision now).
  { x:  850, y: -1350, hx: 24, hy: 17, bot: -1200, top: -1122, brushmodel: true, label: 'paradise_overclock' },   // dragon network terminal - PARADISE east-mid.
  { x: -850, y: -1950, hx: 29, hy: 26, bot: -1200, top: -1086, brushmodel: true, label: 'paradise_exo' },         // cryogen stasis pod (yaw 0) - PARADISE west-south.
  { x:  850, y: -1950, hx: 25, hy: 22, bot: -1200, top: -1129, brushmodel: true, label: 'paradise_perk_vendor' }, // drop-pod console - PARADISE east-south.
  { x:  850, y: -1650, hx: 39, hy: 10, bot: -1200, top: -1179, brushmodel: true, label: 'paradise_ammo_crate' },  // ammo-crate stack - PARADISE east wall (AMMO CRATE #3, user 2026-07-09).
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
  { x:  870, y:  -100, hx: 69, hy:  9, bot:   288, top:   336, brushmodel: true, label: 'armory_rack' },          // p7_con_cargo_train_armory_cabinet (138x18x48) - Armory loft (z=288); long axis spans the deposit/withdraw pads.
  { x:  870, y:   100, hx: 37, hy: 28, bot:   288, top:   398, brushmodel: true, label: 'armory_bottle' },        // p7_zm_vending_wonder (Wonderfizz 74x56x110) - Armory loft bottle exchange.
  { x:   98, y:   200, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_points' },      // p7_out_monitor_atm (37x34x103; mesh extends +X from its back-face origin at x=80 -> clip centered x=98) - Exchange vault.
  { x:   98, y:    40, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_shards' },      // ATM - Exchange vault.
  { x:   98, y:  -120, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_bottles' },     // ATM - Exchange vault.
  { x:   98, y:  -280, hx: 19, hy: 17, bot:  -240, top:  -137, brushmodel: true, label: 'transfer_items' },       // ATM - Exchange vault.
  // Jukebox + Paradise PaP (model-clip audit 2026-07-10): both are bare spawn(script_model)+setmodel props whose xmodel
  // ships NO _col LOD (verified via find <model>*_col.xmodel_bin + tools/xmodel_bin_inspect.js) -> walk-through until clipped.
  { x: -139, y:  2240, hx: 12, hy: 17, bot:  -240, top:  -187, brushmodel: true, label: 'jukebox' },              // cp_town_jukebox 22.7x33x53, yaw 0; mesh sits +X of the spawn origin (-150,2240) -> clip center x=-139. North under-room SW (spread from the reactor 2026-07-10).
  { x:    0, y: -1702, hx: 35, hy: 21, bot: -1200, top: -1125, brushmodel: true, label: 'paradise_pap' },        // p9_fxanim_zm_gp_pap_xmodel 67.9x40.6x75; Paradise standalone Pack-a-Punch (deep z=-1200 -> brushmodel required).
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

// A DEEP clip emitted as a script_brushmodel ENTITY (lives in the entity list, AFTER the worldspawn close). The
// LED lightmapper IGNORES script_brushmodels (memory brushmodel-wall-led-exempt + the shipped acc_ec_right_wall /
// acc_door_implant precedents in this .map), so an abyss-depth `clip` here gives REAL collision WITHOUT the
// worldspawn-clip bake crash (brush.cpp:1860). It is solid at load - static, no GSC needed (same as the EC wall).
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
  block.push(`// clip: ${p.label} @ (${p.x},${p.y})`);
  block.push(box(x1, x2, y1, y2, z1, z2, MAT));
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
