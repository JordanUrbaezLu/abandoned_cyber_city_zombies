#!/usr/bin/env node
// =============================================================================
// gen_plaza_basement.js - "The Exchange": a player-to-player TRANSFER VAULT room
// UNDER the spawn Plaza, reached by an ENCLOSED STAIRCASE in the SW corner of the
// (enlarged) Implant Lab. (user 2026-06-27: "a room where players can transfer
// shards, money, mega bottles and items to other players" + the fix pass after the
// first attempt put a confusing railed pit in the middle of a cramped room.)
//
// ---- REDESIGN (2026-06-27, v2) -- WHY the first version was broken ------------
//  v1 dropped an OPEN railed pit (z[0,128] rails) into the 360x300 lab's centre -> the
//  user saw "a big square block in the middle of the room". Worse, the buyable door
//  "did nothing" because this generator's OLD strip() only removed single-level LEAF
//  brushes: re-running it left the top-level door ENTITIES duplicated (and stripped
//  their inner brush, leaving empty shells), so the live "acc_door_exchange" resolved
//  to a brushless phantom and the real slab stayed solid forever. v2 fixes BOTH:
//   (1) strip() now removes ALL of this generator's blocks - leaf world brushes inside
//       worldspawn AND top-level door/light entities (anything carrying a 7A2BAE0 guid)
//       PLUS the original arena-floor slab GUID - so a re-run is truly idempotent.
//   (2) the stairwell is an ENCLOSED STAIRCASE ROOM in the SW corner, against the lab's
//       (now extended) WEST wall: full-height (z[0,256]) N/S walls + the west wall + a
//       DOORWAY on the EAST face (facing the lab). You walk up, open the door, and walk
//       DOWN enclosed stairs - it reads as a basement stairwell, not a pen.
//  The lab is ENLARGED WEST to x[-720,-40] in tools/gen_plaza_shrink.js (its west wall
//  #11 moved + a north-extension wall added); benches stay center, doorway stays north.
//
// ---- WHAT THIS BUILDS (LED-bake-gated world brushes + one script_brushmodel door) ----
//  1. CARVES the stock arena-floor slab {219830C1} (x[-1056,1094.5] y[-560,740] z[-16,0])
//     into a connected 4-chunk frame around the stairwell WELL x[-720,-496] y[-440,-312]
//     (flush against the lab's west wall). Strip-GUID + re-emit = the only way to hole a
//     solid stock slab; the original is stored verbatim for --revert.
//  2. A 14-tread 16/16 stairwell descending EAST(top)->WEST(bottom), z=0 -> z=-240.
//  3. The enclosed STAIRCASE ROOM: full-height N/S walls (z[0,256]) + an EAST doorway
//     (the buyable door slab z[0,128] + a lintel z[128,256]); the west side is the lab wall.
//  4. The VAULT room at z=-240 (x[-720,300] y[-448,360]); carved arena floor = its ceiling
//     (z=-16); 4 perimeter walls (z[-240,-16]); always-on lights.
//  5. The buyable slide-up DOOR (flag "enter_exchange", 1500) at the staircase-room EAST
//     doorway. Wired in zm_abandoned_cyber_city.gsc zone_door_trigger_origin (-496,-376,50).
//
// ---- WIRING (in GSC, not here) -----------------------------------------------
//  * zm_abandoned_cyber_city.gsc zone_door_trigger_origin('enter_exchange') = (-496,-376,50).
//    (acc_dedupe_exchange_door is now a harmless no-op since this ships exactly ONE door.)
//  * _acc_bus_trench.gsc origin_in_vault box must cover the new footprint (x[-740,320]
//    y[-460,380] z(-260,0)) - excludes the vault from trench amping + OOB-kill.
//  * _acc_transfer.gsc stations sit at x~80 (east end of the vault) - unchanged.
//
// !! LED bake is THE GATE (tools/_bake_test.ps1 -> BAKED). Then WALK-TEST: buy the door,
//    confirm the slab vanishes and you can descend; the single-slab T-junction trap is
//    invisible to the bake.
//
// Usage: node tools/gen_plaza_basement.js [--out <file>]   apply (default: real .map)
//        node tools/gen_plaza_basement.js --revert         UNDO + restore arena floor
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');

const TAG = '// ACC plaza basement (tools/gen_plaza_basement.js)';
const LIGHTS_HEADER = '// ACC plaza basement lights (gen_plaza_basement.js) - always on';
const MARK = '7A2BAE0';   // unique GUID prefix for every brush/entity this generator emits (verified 0 collisions)

// ---- the stock arena-floor slab we carve (verbatim, restored on --revert) -----
const ARENA_FLOOR_GUID = '{219830C1-7D6C-46BB-A802-BEBF577A3379}';
const ORIG_ARENA_FLOOR = [
  TAG + ' (restored original arena floor)',
  '{',
  ' guid "{219830C1-7D6C-46BB-A802-BEBF577A3379}"',
  ' ( -1763.5 -1820.5 -16 ) ( 540.5 -1820.5 -16 ) ( 540.5 739.5 -16 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( -2018 -560 -256 ) ( -2018 -560 0 ) ( 286 -560 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 -64 0 0',
  ' ( 1094.5 665 -256 ) ( 1094.5 -1895 -256 ) ( 1094.5 -1895 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 -64 0 0',
  ' ( 704 740 -256 ) ( 704 740 0 ) ( -1600 740 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 -64 0 0',
  ' ( -1056 767 0 ) ( -1056 -1793 0 ) ( -1056 -1793 -256 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 -64 0 0',
  ' ( -1763.5 739.5 0 ) ( 540.5 739.5 0 ) ( 540.5 -1820.5 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  '}',
];

// ---- geometry constants ------------------------------------------------------
const F = 'script_floor_ceiling', W = 'script_wall';
const AF = { x1: -1056, x2: 1094.5, y1: -560, y2: 740, z1: -16, z2: 0 };  // arena floor slab bounds
// Stairwell WELL = the carved hole. NOT flush against the west wall: the stairs stop ~100u short
// (x1=-620), leaving an open vault LANDING (x[-720,-620]) so zombies STEP OFF the bottom WEST into open
// floor (the abyss "never end at a wall" rule) instead of jamming at the bottom (user 2026-06-27).
// 240 wide (15 treads x 16-run) x 128 deep. Clear of the benches (x=-307.5/-147.5, east) + doorway (north).
const WELL = { x1: -620, x2: -380, y1: -440, y2: -312 };
const TOPZ = 0, BOTZ = -160;            // lab floor -> vault floor (160u drop; shallower so a GENTLE pitch fits)
// GENTLE pitch (user 2026-06-27: 16/16 = 45deg made you SLIDE). 10-rise / 16-run (~32deg, the trench's
// re-pitch) over 15 treads = 150u rise + a final 10u step to the -160 floor; run = 15*16 = 240u (x[-620,-380]).
const STEP_RUN = 16, STEP_RISE = 10, N_STEPS = 15;
const WALL_TH = 20;
const ROOM_H = 256;                     // staircase-room wall height (matches the lab walls; encloses, no pen)
// VAULT room interior (floor z[-176,-160]; ceiling = the carved arena floor underside z=-16, ~144u headroom).
// Spans the stair LANDING (west) -> under the lab to hold the transfer stations (x~80, east).
const ROOM = { x1: -720, x2: 300, y1: -448, y2: 360 };
const ROOM_FLOOR_TOP = -160, ROOM_FLOOR_BASE = -176, ROOM_CEIL = -16;
// buyable door = the EAST doorway of the staircase room (slab z[0,128] + lintel z[128,256] above).
const DOOR = {
  flag: 'enter_exchange',
  slab: 'acc_door_exchange',
  cost: 1500,
  triggerBox: [-384, -376, -444, -308, 0, 128],  // material 'trigger' (dead stock trig; our radius trigs drive the buy)
  slabBox:    [-382, -378, -444, -308, 0, 128],   // material 'script_wall' (hidden+notsolid on buy)
  slideVec:   '0 0 130',
};

// ---- bake-safe box() (verbatim winding from gen_abyss_layer.js; DO NOT alter) -
// GUID PREFIX 7A2BAE0* is the strip marker (NOT the middle group - the abyss family uses "-ACE0-").
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAE00-AE0C-4E0C-8A3F-${c}}`;
}
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// ---- bake-safe light (always-on; a usable room must be lit pre- + post-power) -
let lc = 0;
function lguid() { lc++; const c = lc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAE01-AE14-4E14-8A3F-${c}}`; }
function lightEntity(tag, x, y, z, radius, intensity) {
  return ['{', `guid "${lguid()}"`,
    '"classname" "light"', `"targetname" "${tag}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    '"_color" "1 1 1"', `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    '"lightingstate1" "1"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

function doorEntities() {
  const [tx1, tx2, ty1, ty2, tz1, tz2] = DOOR.triggerBox;
  const [sx1, sx2, sy1, sy2, sz1, sz2] = DOOR.slabBox;
  const trig = [
    `${TAG} exchange-door trigger (${DOOR.flag}, ${DOOR.cost})`,
    '{', ` guid "${guid()}"`,
    ' "classname" "trigger_use"',
    ' "targetname" "zombie_door"',
    ` "target" "${DOOR.slab}"`,
    ` "zombie_cost" "${DOOR.cost}"`,
    ` "script_flag" "${DOOR.flag}"`,
    box(tx1, tx2, ty1, ty2, tz1, tz2, 'trigger'),
    '}',
  ].join('\n');
  const slab = [
    `${TAG} exchange-door slab (${DOOR.slab})`,
    '{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "${DOOR.slab}"`,
    ` "script_vector" "${DOOR.slideVec}"`,
    ' "script_transition_time" "1.5"',
    box(sx1, sx2, sy1, sy2, sz1, sz2, 'script_wall'),
    '}',
  ].join('\n');
  return [trig, slab];
}

// ---- emit world brushes ------------------------------------------------------
const brushes = [];
const badd = (label, txt) => { brushes.push(`${TAG} ${label}`); brushes.push(txt); };

// 1. carved arena floor = 4 connected chunks around the WELL hole (replaces the stock slab).
badd(`arena floor WEST of well`,  box(AF.x1, WELL.x1, AF.y1, AF.y2, AF.z1, AF.z2, F));
badd(`arena floor EAST of well`,  box(WELL.x2, AF.x2, AF.y1, AF.y2, AF.z1, AF.z2, F));
badd(`arena floor NORTH of well`, box(WELL.x1, WELL.x2, WELL.y2, AF.y2, AF.z1, AF.z2, F));
badd(`arena floor SOUTH of well`, box(WELL.x1, WELL.x2, AF.y1, WELL.y1, AF.z1, AF.z2, F));

// 2. vault floor (single full slab); ceiling is the carved arena floor above (z=-16).
badd(`vault floor slab`, box(ROOM.x1, ROOM.x2, ROOM.y1, ROOM.y2, ROOM_FLOOR_BASE, ROOM_FLOOR_TOP, F));

// 3. vault perimeter walls (z[-240,-16], up to the arena-floor underside = the ceiling).
badd(`vault wall west`,  box(ROOM.x1 - WALL_TH, ROOM.x1, ROOM.y1 - WALL_TH, ROOM.y2 + WALL_TH, ROOM_FLOOR_TOP, ROOM_CEIL, W));
badd(`vault wall east`,  box(ROOM.x2, ROOM.x2 + WALL_TH, ROOM.y1 - WALL_TH, ROOM.y2 + WALL_TH, ROOM_FLOOR_TOP, ROOM_CEIL, W));
badd(`vault wall south`, box(ROOM.x1 - WALL_TH, ROOM.x2 + WALL_TH, ROOM.y1 - WALL_TH, ROOM.y1, ROOM_FLOOR_TOP, ROOM_CEIL, W));
badd(`vault wall north`, box(ROOM.x1 - WALL_TH, ROOM.x2 + WALL_TH, ROOM.y2, ROOM.y2 + WALL_TH, ROOM_FLOOR_TOP, ROOM_CEIL, W));

// 4. stairwell: 15 GENTLE stepped treads, EAST (high) -> WEST (low); rise 10 / run 16. The bottom tread
//    sits at z=-150 and steps off WEST onto the vault LANDING (z=-160) - open floor, so zombies disperse.
for (let s = 1; s <= N_STEPS; s++) {
  const treadZ = TOPZ - STEP_RISE * s;                  // -10 (top, east) .. -150 (bottom, west)
  const xB = WELL.x2 - STEP_RUN * (s - 1), xA = xB - STEP_RUN;
  badd(`stair tread ${s} (top z=${treadZ})`, box(xA, xB, WELL.y1, WELL.y2, BOTZ, treadZ, F));
}

// 5. ENCLOSED staircase room (NOT a railed pit): full-height N/S/W walls + an EAST doorway (door slab
//    z[0,128] + lintel z[128,256]). The WEST wall is LAB-LEVEL (z[0,256]) so nobody falls into the well
//    from the lab floor west of it - but it sits ABOVE z=0, so the bottom tread still opens WEST into the
//    vault landing (z<0) UNDER it. You can only enter through the (gated) east doorway.
badd(`staircase room NORTH wall`, box(WELL.x1 - WALL_TH, WELL.x2 + WALL_TH, WELL.y2, WELL.y2 + WALL_TH, 0, ROOM_H, W));
badd(`staircase room SOUTH wall`, box(WELL.x1 - WALL_TH, WELL.x2 + WALL_TH, WELL.y1 - WALL_TH, WELL.y1, 0, ROOM_H, W));
badd(`staircase room WEST wall (lab-level; bottom opens west BELOW it)`, box(WELL.x1 - WALL_TH, WELL.x1, WELL.y1 - WALL_TH, WELL.y2 + WALL_TH, 0, ROOM_H, W));
badd(`staircase room EAST lintel (above the doorway)`, box(WELL.x2, WELL.x2 + WALL_TH, WELL.y1, WELL.y2, 128, ROOM_H, W));

// 6. lights (enclosed -> bakes black). Stair bottom (west) + along the vault hall to the stations (east).
const lights = [LIGHTS_HEADER];
lights.push(lightEntity('acc_exchange_light_stair', -660, -376, -70, 380, 1.4));
lights.push(lightEntity('acc_exchange_light_w', -320, -120, -80, 540, 1.5));
lights.push(lightEntity('acc_exchange_light_c', 60, -200, -80, 540, 1.5));
lights.push(lightEntity('acc_exchange_light_e', 90, 200, -80, 540, 1.5));

// ---- strip prior run: ALL blocks carrying a 7A2BAE0 guid (leaf world brushes inside worldspawn
//      AND top-level door/light entities AND any brushless leftover shells), my tag comments, and
//      the original arena-floor slab. Worldspawn is kept + descended so only its inner marked
//      leaf brushes are removed. This is the v2 fix for the duplicate-door corruption. -----------
function strip(lines) {
  const out = [];
  let k = 0;
  while (k < lines.length) {
    const t = lines[k].trim();
    if (t.startsWith(TAG) || t === LIGHTS_HEADER) { k++; continue; }
    if (t === '{') {
      // scan the whole block [k, j); note if it is worldspawn and whether it carries our marker.
      let d = 0, j = k, isWs = false, marked = false;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') d++;
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
        if (lines[j].includes('"classname" "worldspawn"')) isWs = true;
        if (lines[j].includes(MARK) || lines[j].includes(ARENA_FLOOR_GUID)) marked = true;
      }
      if (isWs) { out.push(lines[k]); k++; continue; }        // keep worldspawn; descend (inner marked leaves get dropped below)
      if (marked) { k = j; continue; }                        // drop the whole non-worldspawn marked block (entity / leaf / shell)
      out.push(lines[k]); k++; continue;                      // keep+descend an unmarked block
    }
    out.push(lines[k]); k++;
  }
  return out;
}

function worldspawnClose(lines) {
  let depth = 0, entityIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
    for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; depth++; }
    for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && entityIdx === 0) return i; }
  }
  return -1;
}

// ---- assemble ----------------------------------------------------------------
const rawLines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let lines = strip(rawLines);

if (REVERT) {
  const wsClose = worldspawnClose(lines);
  if (wsClose === -1) { console.error('ERROR: worldspawn close not found for revert.'); process.exit(2); }
  const o = [...lines.slice(0, wsClose), ...ORIG_ARENA_FLOOR, ...lines.slice(wsClose)];
  while (o.length && o[o.length - 1] === '') o.pop();
  o.push('');
  fs.writeFileSync(OUT, o.join('\n'));
  console.log(`[basement] REVERTED: stripped all 7A2BAE0 geometry/entities + restored the original arena floor.`);
  console.log(`[basement] wrote ${OUT} (${rawLines.length} -> ${o.length} lines). Re-apply: node tools/gen_plaza_basement.js`);
  process.exit(0);
}

const wsClose = worldspawnClose(lines);
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const doorBlocks = doorEntities();
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) {
    out.push(`${TAG} ===== BEGIN world brushes (carved floor + stairwell + vault) =====`);
    out.push(...brushes);
    out.push(`${TAG} ===== END world brushes =====`);
  }
  out.push(lines[i]);
}
while (out.length && out[out.length - 1] === '') out.pop();
out.push(...doorBlocks, ...lights, '');
fs.writeFileSync(OUT, out.join('\n'));

console.log(`[basement] v2: enclosed staircase room in the SW corner; well x[${WELL.x1},${WELL.x2}] y[${WELL.y1},${WELL.y2}]`);
console.log(`[basement]   + ${N_STEPS}-tread stairwell z ${TOPZ}->${BOTZ}, vault x[${ROOM.x1},${ROOM.x2}] y[${ROOM.y1},${ROOM.y2}] floor z${ROOM_FLOOR_TOP}`);
console.log(`[basement]   + door ${DOOR.flag} (${DOOR.cost}) on the EAST doorway @ trigger-origin (-380,-376,50)`);
console.log(`[basement] wrote ${OUT} (${rawLines.length} -> ${out.length} lines). BAKE-GATE: tools/_bake_test.ps1`);
