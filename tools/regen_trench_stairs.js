// =============================================================================
// regen_trench_stairs.js  (re-runnable, idempotent)
//
// Player complaint (user 2026-06-26): the Bus-Station -> trench stairs are "so
// steep the player glitches." They were 14 steps of 16 tall x 16 deep = a 45deg
// pitch; the player hull catches on the step nosings and stutters.
//
// FIX (user's request): keep the TOP (lip) where it is, but make each step
// SHORTER and the staircase LONGER -> lower rise per step + a gentler slope.
//   OLD: 14 steps, rise 16, run 16  -> 45.0deg, 224u long, treads -16..-224
//   NEW: 23 steps, rise 10, run 16  -> 32.0deg, 368u long, treads -10..-230
// Both stairs still land on the -240 trench floor (final 10u drop to the floor
// brush, same as the old final 16u drop). The two stairs sit on OPPOSITE x walls
// (W: x[-761,-665], E: x[703,799]) so extending them toward the middle cannot
// collide; the 368u run fits the 450u trench (y[1723,2173]) with ~82u to spare.
// Lower 10u risers link the navmesh even more easily than the old 16u (stock step
// tolerance ~18u), and zombies still path the crossing.
//
// This REPLACES (in place) the 28 stair brushes (W S1..S14 + E N1..N14) and the 2
// stair pit-side walls in map_source/zm/zm_abandoned_cyber_city.map. Geometry =
// world brushes (NOT script_brushmodel) -> BSP + navmesh + LED all regenerate ->
// run a FULL build WITH the LED bake (tools/build_map.ps1, no -SkipLED) or the
// fast gate tools/_bake_test.ps1. Re-runnable: re-finds the spans by their stable
// comment markers and rebuilds from the params below.
//
// box() winding is VERBATIM from tools/gen_corp_trench.js (proven parse+bake
// clean - it produced the original stairs).
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// ---- trench + stair params (trench bounds verbatim from gen_corp_trench.js) ----
const TRENCH_Y1 = 1723, TRENCH_Y2 = 2173, TRENCH_FLOOR = -240;
const STAIR_CHANNELS = [
  { x1: -761, x2: -665, side: 'south', name: 'W', wall: 'west' },   // WEST wall, SOUTH lip (treads march north)
  { x1: 703, x2: 799, side: 'north', name: 'E', wall: 'east' },     // EAST wall, NORTH lip (treads march south)
];
const STEP_RISE = 10;   // tread-to-tread height (was 16). LOWER = gentler = no glitch. 10*24=240 to the floor.
const STEP_RUN = 16;    // tread depth in Y (unchanged; 23*16=368u run, fits the 450u trench).
const N_STEPS = 23;     // 23 treads -10..-230, then a clean 10u drop to the -240 floor brush. (24th "tread" = floor.)
const PIT_TH = 16;      // pit-side wall thickness (seals the open pit-facing side of each stair)
const PIT_TOP = 128;    // pit-side wall top z (verbatim from the old pit-side walls)
// (The crouch DROP-IN window is NOT here - user 2026-06-28: it belongs in the rim PARAPET beside each stair,
//  see tools/gen_trench_walls.js S_CROUCH/N_CROUCH. These pit-side walls stay SOLID.)

const runY = N_STEPS * STEP_RUN;
if (runY > (TRENCH_Y2 - TRENCH_Y1)) {
  console.error(`regen_trench_stairs: run ${runY}u exceeds trench depth ${TRENCH_Y2 - TRENCH_Y1}u - aborting.`);
  process.exit(1);
}

// ---- well-formed GUIDs, distinct first-group so they can't collide with old ----
let stepCtr = 0, wallCtr = 0;
function stepGuid() { stepCtr++; return `{7A2B9F01-ACC3-4E0C-8A3F-${stepCtr.toString(16).toUpperCase().padStart(12, '0')}}`; }
function wallGuid() { wallCtr++; return `{7A2BAA01-ACCA-4E0D-8A3F-${wallCtr.toString(16).toUpperCase().padStart(12, '0')}}`; }

// Six-plane axis-aligned box - winding VERBATIM from gen_corp_trench.js box().
function box(guidStr, x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guidStr}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// ---- build the new step block (W S1..SN then E N1..NN) ----------------------
const steps = [];
for (const ch of STAIR_CHANNELS) {
  for (let k = 1; k <= N_STEPS; k++) {
    const top = -STEP_RISE * k;
    let yA, yB, lip;
    if (ch.side === 'south') { yA = TRENCH_Y1 + STEP_RUN * (k - 1); yB = TRENCH_Y1 + STEP_RUN * k; lip = 'S'; }
    else { yB = TRENCH_Y2 - STEP_RUN * (k - 1); yA = TRENCH_Y2 - STEP_RUN * k; lip = 'N'; }
    steps.push(`// corp trench ${ch.name} stair ${lip}${k} (tread z=${top})`);
    steps.push(box(stepGuid(), ch.x1, ch.x2, yA, yB, TRENCH_FLOOR, top, 'script_floor_ceiling'));
  }
}

// ---- build the new pit-side walls (one per channel, full new length) --------
const pitWalls = [];
for (const ch of STAIR_CHANNELS) {
  const yA = (ch.side === 'south') ? TRENCH_Y1 : TRENCH_Y2 - runY;
  const yB = (ch.side === 'south') ? TRENCH_Y1 + runY : TRENCH_Y2;
  const px1 = (ch.wall === 'west') ? ch.x2 : ch.x1 - PIT_TH;
  const px2 = (ch.wall === 'west') ? ch.x2 + PIT_TH : ch.x1;
  pitWalls.push(`// trench ${ch.name} stair pit-side wall`);
  pitWalls.push(box(wallGuid(), px1, px2, yA, yB, TRENCH_FLOOR, PIT_TOP, 'script_wall'));
}

// ---- map surgery: replace the two spans by their stable comment markers ------
let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
function findLine(pred, from = 0) { for (let i = from; i < lines.length; i++) if (pred(lines[i].trim())) return i; return -1; }

// 1) pit-side wall span: ["// trench W stair pit-side wall" .. just before "// ===== end trench walls ====="]
const pStart = findLine(l => l === '// trench W stair pit-side wall');
const pEnd = findLine(l => l === '// ===== end trench walls =====', pStart);
if (pStart < 0 || pEnd < 0) { console.error('regen_trench_stairs: pit-side wall span markers not found - aborting.'); process.exit(1); }
lines.splice(pStart, pEnd - pStart, ...pitWalls.join('\n').split('\n'));

// 2) stair span: [first "// corp trench [WE] stair ..." .. just before "// ===== end trench ====="]
const sStart = findLine(l => /^\/\/ corp trench [WE] stair [SN]\d/.test(l));
const sEnd = findLine(l => l === '// ===== end trench =====', sStart);
if (sStart < 0 || sEnd < 0) { console.error('regen_trench_stairs: stair span markers not found - aborting.'); process.exit(1); }
lines.splice(sStart, sEnd - sStart, ...steps.join('\n').split('\n'));

fs.writeFileSync(MAP, lines.join('\n'));

const slope = (Math.atan2(STEP_RISE, STEP_RUN) * 180 / Math.PI).toFixed(1);
console.log(`regen_trench_stairs: ${STAIR_CHANNELS.length} stairs x ${N_STEPS} steps (rise ${STEP_RISE} / run ${STEP_RUN} = ${slope}deg, ${runY}u long), pit-side walls re-sized.`);
console.log(`  W stair y[${TRENCH_Y1},${TRENCH_Y1 + runY}]  E stair y[${TRENCH_Y2 - runY},${TRENCH_Y2}]  (trench y[${TRENCH_Y1},${TRENCH_Y2}])`);
console.log('  FULL build + LED bake required (BSP/navmesh/lightmap regen).');
