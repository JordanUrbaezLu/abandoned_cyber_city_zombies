#!/usr/bin/env node
// =============================================================================
// gen_upper_room.js - "The Armory" upper room. A buyable door in the EAST Plaza wall
// opens onto a staircase that climbs EAST into the sealed east dead-space up to an
// enclosed loft (the _acc_armory.gsc stations). docs/60.
//
// LAYOUT (user 2026-07-07 v3): "face the stairs east/west, start at the Plaza wall, add a
//   buyable door (5k), put it where it CAN'T intercept the playable Plaza, and skin the walls
//   like the Plaza." So: everything lives EAST of the x=213 Plaza wall (the sealed dead-space
//   from gen_plaza_shrink's 75% east-shrink), reached ONLY through a bought door in that wall.
//   Nothing touches the playable Plaza floor (x[-470,213]) except the door + its buy trigger.
//   - Door: a gap cut in the east wall (wall #5, y[-64,64] z[0,128]) + a slide-up slab
//     (acc_door_armory) + a zombie_door trigger (enter_armory, 5000). Wired in the entry
//     script (zone_door_trigger_origin + zone_door_dest_name).
//   - Staircase: 18 treads (16/16) climbing +X from x=234 (at the wall) to x=522 (z=288).
//   - Loft: enclosed room x[522,922] y[-200,200], floor z=288, walls z[288,544], ceiling
//     z[544,560], WEST-wall doorway for the stairs. Floats over the dead-space (in-zone via
//     the tall start_zone volume z[-166,1041] -> no OOB; zombies path the 16/16 stairs).
//
// MATERIALS (user: "model the walls with the plaza wall design"): the Plaza is re-skinned -
//   walls = t7_concrete_wall_weathered_01_wet, floor/streets = t7_asphalt_damaged_dark_wet
//   (both STOCK, ship free, NO .zone line - docs/29). The Armory uses the SAME so it reads as
//   part of the Plaza instead of the greybox checker.
//
// ---- BAKE / IDEMPOTENCY --------------------------------------------------------
//  Brushes use the proven box() filler-winding + hex GUID (bakes; do NOT alter). The generator
//  REMOVES the solid east wall #5 (guid 14FA6613..006) and re-emits it SPLIT (2 jambs + lintel)
//  around the doorway; on --revert it strips its own -AC50- brushes/lights/entities AND restores
//  the original solid wall #5 byte-faithfully. Re-runnable.
//
// !! LED bake is THE GATE: build_map.ps1 (NO -SkipLED) or _bake_test.ps1.
//
// Usage: node tools/gen_upper_room.js            apply (writes the real .map)
//        node tools/gen_upper_room.js --revert    UNDO: strip Armory + restore the solid east wall
//        node tools/gen_upper_room.js --out <f>   write elsewhere (dry run)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');

// ---- Materials (match the re-skinned Plaza; stock, ship free, no .zone line) ----
const WALL_MAT = 't7_concrete_wall_weathered_01_wet';   // the Plaza wall design (user ask)
const FLOOR_MAT = 't7_asphalt_damaged_dark_wet';        // the Plaza street/floor
const DOOR_MAT = 't7_metal_diamond_plate_worn_wet';     // the CANONICAL buyable-door skin - every door slab on
                                                        // this map uses this worn diamond-plate metal so the
                                                        // doorway reads as a shutter vs the concrete wall (audit
                                                        // 2026-07-07). The whole "this is a door" cue IS this material.

// ---- East Plaza wall (wall #5) — cut a doorway, keep jambs + lintel -----------
const EW_X1 = 213, EW_X2 = 233;            // east wall thickness (x)
const EW_Y1 = -260, EW_Y2 = 400;           // wall #5 span (y)
const EW_Z2 = 256;                         // wall height
const DOOR_HALF = 64;                      // doorway half-width in Y -> 128u opening, centered on y=0
const DOOR_H = 128;                        // doorway height (z[0,128]); lintel above
const ORIG_EAST_WALL_GUID = '14FA6613-ACC6-4E0D-8A3F-000000000006';
const ORIG_EAST_WALL_COMMENT = '// ACC plaza shrink (tools/gen_plaza_shrink.js) wall #5 [213,233,-260,400,0,256]';
const ORIG_EAST_WALL = [
  ORIG_EAST_WALL_COMMENT,
  '{',
  ` guid "{${ORIG_EAST_WALL_GUID}}"`,
  ' ( 134.5 459.5 0 ) ( 86.5 459.5 0 ) ( 86.5 419.5 0 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 94.5 419.5 256 ) ( 94.5 459.5 256 ) ( 142.5 459.5 256 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 86.5 -260 88 ) ( 134.5 -260 88 ) ( 134.5 -260 0 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 233 415.5 88 ) ( 233 455.5 88 ) ( 233 455.5 0 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 138.5 400 88 ) ( 90.5 400 88 ) ( 90.5 400 0 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 213 459.5 88 ) ( 213 419.5 88 ) ( 213 419.5 0 ) t7_concrete_wall_weathered_01_wet 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  '}',
];

// ---- Staircase (climbs +X / EAST from the wall into the dead-space) -----------
// Pitch (user 2026-07-07: "way too steep"): 12u rise / 20u run per tread => ~31deg (was 16/16 = 45deg,
// a ladder). Rise <=16u also links the navmesh cleanly (docs/03). Longer run -> the loft shifts east.
const RISE = 12, RUN = 20;
const FLOOR_TOP = 288, FLOOR_TH = 16;      // loft floor top z=288
const N_STEPS = FLOOR_TOP / RISE;          // 24 treads (288 / 12)
const STAIR_Y1 = -DOOR_HALF, STAIR_Y2 = DOOR_HALF;   // 128u wide, aligned to the door
const STAIR_BASE_X = EW_X2 + 1;            // 234 (just east of the wall)
const STAIR_TOP_X = STAIR_BASE_X + RUN * N_STEPS;    // 234 + 480 = 714 (= loft west edge)
const RAIL_TOP = FLOOR_TOP + 64;           // 352 (side-rail height)

// ---- Loft (enclosed room over the east dead-space) ----------------------------
const LX1 = STAIR_TOP_X, LX2 = STAIR_TOP_X + 360;    // x[714,1074] (within the dead-space arena floor x<=1094.5)
const LY1 = -200, LY2 = 200;               // y[-200,200]
const WALL_TH = 20, ROOM_H = 256, CEIL_TH = 16;
const FLOOR_BASE = FLOOR_TOP - FLOOR_TH;   // 272
const WALL_TOP = FLOOR_TOP + ROOM_H;       // 544
const CEIL_TOP = WALL_TOP + CEIL_TH;       // 560
const LOFT_DOOR_H = 128;                   // west-wall doorway height above the loft floor

// ---- Door (slab + trigger) ----------------------------------------------------
const SLAB = 'acc_door_armory', DOOR_FLAG = 'enter_armory', DOOR_COST = 10000;

// ---- bake-safe box() (VERBATIM winding; DO NOT alter) -------------------------
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAD00-AC50-4E0C-8A3F-${c}}`;
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

// ---- bake-safe light (always-on PRIMARY_OMNI) ---------------------------------
let lc = 0;
function lguid() { lc++; const c = lc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAD01-AC50-4E14-8A3F-${c}}`; }
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

// ---- door entities (top-level; the map's custom acc_fix_zone_doors drives the buy) ----
function doorTrigger() {
  return ['// ACC ARMORY door trigger (enter_armory, 5000)',
    '{', ` guid "${guid()}"`,
    ' "classname" "trigger_use"',
    ' "targetname" "zombie_door"',
    ` "target" "${SLAB}"`,
    ` "zombie_cost" "${DOOR_COST}"`,
    ` "script_flag" "${DOOR_FLAG}"`,
    box(EW_X1, EW_X2, -DOOR_HALF, DOOR_HALF, 0, DOOR_H, 'trigger'),
    '}'].join('\n');
}
function doorSlab() {
  // Diamond-plate METAL skin (DOOR_MAT) = the canonical door look, NOT the wall material. The custom buy loop
  // (zone_door_trigger_wait) just hide()/notsolid()s the slab on purchase; script_vector/transition are
  // vestigial (kept to mirror the other door slabs exactly).
  return ['// ACC ARMORY door slab (acc_door_armory - diamond-plate metal; hidden on buy)',
    '{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "${SLAB}"`,
    ' "script_vector" "0 0 130"',
    ' "script_transition_time" "1.5"',
    box(EW_X1 + 1, EW_X2 - 1, -DOOR_HALF + 2, DOOR_HALF - 2, 0, DOOR_H, DOOR_MAT),
    '}'].join('\n');
}

// ---- strip prior run + the original solid east wall ---------------------------
function strip(lines) {
  const out = [];
  let k = 0;
  while (k < lines.length) {
    const t = lines[k].trim();
    if (t.startsWith('// ACC ARMORY')) { k++; continue; }
    if (t === ORIG_EAST_WALL_COMMENT) { k++; continue; }   // drop the comment; its brush is dropped below
    if (t === '{') {
      // Scan the whole block. Remove it wholesale if it's marked (-AC50- / the original wall guid)
      // AND is NOT worldspawn - this catches my worldspawn-child brushes AND my top-level door
      // ENTITIES (trigger/slab, which wrap a brush so a leaf-only test would miss them + leave a
      // broken empty wrapper). Worldspawn itself is marked (holds my brushes) but must be descended
      // into, so its inner marked leaf brushes get removed one by one.
      let d = 0, j = k, marked = false, isWorld = false;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') d++;
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
        if (lines[j].includes('-AC50-') || lines[j].includes(ORIG_EAST_WALL_GUID)) marked = true;
        if (lines[j].includes('"classname" "worldspawn"')) isWorld = true;
      }
      if (marked && !isWorld) { k = j; continue; }   // drop the whole marked (non-worldspawn) block
      out.push(lines[k]); k++; continue;             // worldspawn / unmarked: descend
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

// ---- generation ---------------------------------------------------------------
const brushes = [];
const lights = ['// ACC ARMORY lights (gen_upper_room.js) - always-on'];
const badd = (label, txt) => { brushes.push(`// ACC ARMORY ${label}`); brushes.push(txt); };

// East wall #5 re-emitted SPLIT around the doorway (jambs + lintel), Plaza wall material.
badd('east wall SOUTH jamb', box(EW_X1, EW_X2, EW_Y1, -DOOR_HALF, 0, EW_Z2, WALL_MAT));
badd('east wall NORTH jamb', box(EW_X1, EW_X2, DOOR_HALF, EW_Y2, 0, EW_Z2, WALL_MAT));
badd('east wall LINTEL (over door)', box(EW_X1, EW_X2, -DOOR_HALF, DOOR_HALF, DOOR_H, EW_Z2, WALL_MAT));

// Staircase: 18 treads climbing +X from the wall to the loft.
for (let s = 1; s <= N_STEPS; s++) {
  const tx1 = STAIR_BASE_X + RUN * (s - 1), tx2 = STAIR_BASE_X + RUN * s, tz = RISE * s;
  badd(`stair tread ${s} (z=${tz})`, box(tx1, tx2, STAIR_Y1, STAIR_Y2, 0, tz, FLOOR_MAT));
}
// Stairwell side rails (full-height along the two long sides; open at the door + the loft).
badd('stair rail south', box(STAIR_BASE_X, STAIR_TOP_X, STAIR_Y1 - WALL_TH, STAIR_Y1, 0, RAIL_TOP, WALL_MAT));
badd('stair rail north', box(STAIR_BASE_X, STAIR_TOP_X, STAIR_Y2, STAIR_Y2 + WALL_TH, 0, RAIL_TOP, WALL_MAT));

// Loft floor (single slab) + ceiling.
badd(`loft floor z[${FLOOR_BASE},${FLOOR_TOP}]`, box(LX1, LX2, LY1, LY2, FLOOR_BASE, FLOOR_TOP, FLOOR_MAT));
badd(`loft ceiling z[${WALL_TOP},${CEIL_TOP}]`, box(LX1, LX2, LY1, LY2, WALL_TOP, CEIL_TOP, WALL_MAT));

// Loft perimeter walls z[288,544]. N/S span full x; E spans inner y. WEST wall has the stair doorway.
badd('loft wall north', box(LX1, LX2, LY2 - WALL_TH, LY2, FLOOR_TOP, WALL_TOP, WALL_MAT));
badd('loft wall south', box(LX1, LX2, LY1, LY1 + WALL_TH, FLOOR_TOP, WALL_TOP, WALL_MAT));
badd('loft wall east', box(LX2 - WALL_TH, LX2, LY1 + WALL_TH, LY2 - WALL_TH, FLOOR_TOP, WALL_TOP, WALL_MAT));
badd('loft west wall SOUTH jamb', box(LX1, LX1 + WALL_TH, LY1 + WALL_TH, STAIR_Y1, FLOOR_TOP, WALL_TOP, WALL_MAT));
badd('loft west wall NORTH jamb', box(LX1, LX1 + WALL_TH, STAIR_Y2, LY2 - WALL_TH, FLOOR_TOP, WALL_TOP, WALL_MAT));
badd('loft west wall LINTEL (over stair doorway)', box(LX1, LX1 + WALL_TH, STAIR_Y1, STAIR_Y2, FLOOR_TOP + LOFT_DOOR_H, WALL_TOP, WALL_MAT));

// Interior lights: 4 always-on at z=488 (200u above the loft floor).
const LZ = FLOOR_TOP + 200, LR = 340, LI = 1.0;
const lxs = [LX1 + 120, LX2 - 120], lys = [LY1 + 80, LY2 - 80];
let ln = 0;
for (const lx of lxs) for (const ly of lys) { lights.push(lightEntity(`acc_armory_light_${ln}`, Math.round(lx), Math.round(ly), LZ, LR, LI)); ln++; }

// ---- assemble -----------------------------------------------------------------
const rawLines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let lines = strip(rawLines);   // removes -AC50- + '// ACC ARMORY' + the original solid east wall #5

if (REVERT) {
  // restore the original solid east wall (re-insert just before worldspawn close)
  const wsClose = worldspawnClose(lines);
  const at = wsClose >= 0 ? wsClose : lines.length;
  lines = [...lines.slice(0, at), ...ORIG_EAST_WALL, ...lines.slice(at)];
  while (lines.length && lines[lines.length - 1] === '') lines.pop();
  lines.push('');
  fs.writeFileSync(OUT, lines.join('\n'));
  console.log(`[armory] REVERTED: stripped Armory + restored solid east wall #5. wrote ${OUT} (${rawLines.length} -> ${lines.length} lines).`);
  process.exit(0);
}

const wsClose = worldspawnClose(lines);
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) {
    out.push('// ACC ARMORY (gen_upper_room.js) ===== BEGIN brushes =====');
    out.push(...brushes);
    out.push('// ACC ARMORY ===== END brushes =====');
  }
  out.push(lines[i]);
}
while (out.length && out[out.length - 1] === '') out.pop();
out.push(...lights, doorTrigger(), doorSlab(), '');
fs.writeFileSync(OUT, out.join('\n'));

console.log(`[armory] door: east wall gap y[${-DOOR_HALF},${DOOR_HALF}] z[0,${DOOR_H}] -> ${DOOR_FLAG} (${DOOR_COST})`);
console.log(`[armory] stairs climb +X x[${STAIR_BASE_X},${STAIR_TOP_X}] y[${STAIR_Y1},${STAIR_Y2}] (${N_STEPS} treads ${RISE}rise/${RUN}run)`);
console.log(`[armory] loft x[${LX1},${LX2}] y[${LY1},${LY2}] z${FLOOR_TOP}->${CEIL_TOP} + 4 lights; mats: ${WALL_MAT} / ${FLOOR_MAT}`);
console.log(`[armory] wrote ${OUT} (${lines.length} -> ${out.length} lines). WIRE the door in the entry script; then FULL LED build.`);
