#!/usr/bin/env node
// =============================================================================
// gen_relocate_exo_room.js - move the SOUTH under-room (the Exo Suit / "Foundry" room) EAST along the pit's
// south wall, into the OPEN, so its buyable DOOR is clear of the centered abyss descent well + stairs
// (user 2026-06-25: "shift the door over more - you have so much room").
//
// WHY a tool, not a slide: the room is a small ENCLOSED box under the pit's south slab; its door must sit in
// the room's front wall, so "shift the door" == relocate the whole room. The walkable floor over the room is
// ONE single full-width slab (no thin-lip T-junction -> no fall-through, see add_under_room.js); the fills
// below it just re-divide around the room's new X. Door size UNCHANGED (80u, user: don't enlarge).
//
// Idempotent: strips the existing "UNDER ROOM SOUTH" marked block + its door/trigger entities and regenerates
// them at --cx. Reuses add_under_room.js's EXACT geometry + box() winding. GEOMETRY -> FULL LED-baked build.
// KEEP acc_exo's Foundry station origin in sync: its x shifts by the same --cx (was centered at 0).
//
// Usage: node tools/gen_relocate_exo_room.js [--cx 350]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const cxArg = process.argv.indexOf('--cx');
const ROOM_CX = cxArg > 0 ? parseInt(process.argv[cxArg + 1], 10) : 350;   // room center X (0 = original)

// ---- constants (verbatim from add_under_room.js, south side) ----
const SX1 = -781, SX2 = 819;          // walkable slab x (the WHOLE south corp half)
const SLAB_Y = [1148, 1723];
const SLAB_BOT = -256, FLOOR_BOT = -96, FLOOR_TOP = 0, ROOM_FLOOR = -240;
const DEPTH = 344, FRONT_TH = 16;
const TW = 1723, RYB = TW - DEPTH /*1379*/, FWY = TW - FRONT_TH /*1707*/, BACK = SLAB_Y[0] /*1148*/;
const COST = 1000, DOOR_W = 80;       // keep the door the SAME 80u width (user: don't enlarge)
const F = 'script_floor_ceiling', W = 'script_wall';

const RX1 = ROOM_CX - 192, RX2 = ROOM_CX + 192;   // room x bounds (384 wide)
const DX2 = RX2, DX1 = RX2 - DOOR_W;              // 80u doorway at the room's EAST edge (matches the old layout)
const IY1 = RYB, IY2 = TW;     // room interior y [1379,1723]
const WY1 = FWY, WY2 = TW;     // front-wall band y [1707,1723]
const BY1 = BACK, BY2 = RYB;   // back fill y [1148,1379]
const DOOR_SLIDE = -DOOR_W;    // slides its own width WEST, into the solid front wall

let g = 0xC00;
function guid() { g++; const c = g.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0C-ACC5-4E11-8A3F-${c}}`; }
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
const wadd = (label, txt) => `// ${label}\n${txt}`;

// ---- regenerated south room (worldspawn block) ----
const blockLines = [
  '// ===== UNDER ROOM SOUTH (add_under_room.js) =====',
  wadd(`under room south - SINGLE walkable floor slab z[${FLOOR_BOT},0]`, box(SX1, SX2, SLAB_Y[0], SLAB_Y[1], FLOOR_BOT, FLOOR_TOP, F)),
  wadd('under room south - west fill', box(SX1, RX1, SLAB_Y[0], SLAB_Y[1], SLAB_BOT, FLOOR_BOT, F)),
  wadd('under room south - east fill', box(RX2, SX2, SLAB_Y[0], SLAB_Y[1], SLAB_BOT, FLOOR_BOT, F)),
  wadd('under room south - back fill', box(RX1, RX2, BY1, BY2, SLAB_BOT, FLOOR_BOT, F)),
  wadd('under room south - room floor', box(RX1, RX2, IY1, IY2, SLAB_BOT, ROOM_FLOOR, F)),
  wadd(`under room south - front wall (SOLID x[${RX1},${DX1}]; doorway x[${DX1},${DX2}] - relocated to room center ${ROOM_CX})`, box(RX1, DX1, WY1, WY2, ROOM_FLOOR, FLOOR_BOT, W)),
  '// ===== end under room south =====',
].join('\n');

// ---- regenerated door + trigger (top-level entities) ----
const doorBrush = box(DX1, DX2, WY1, WY2, ROOM_FLOOR, FLOOR_BOT, W);
const trigBrush = box(DX1, DX2, FWY, TW + 40, ROOM_FLOOR, FLOOR_BOT + 20, 'trigger');   // co-located w/ the door
const eg1 = guid(), eg2 = guid();
const entLines = [
  `// ===== UNDER ROOM DOOR (south) =====  (relocated EAST to room center ${ROOM_CX}; doorway x[${DX1},${DX2}], clear of the abyss well/stairs)`,
  ['{', ` guid "${eg1}"`, ' "classname" "trigger_use"', ' "targetname" "zombie_door"',
    ' "target" "acc_door_under_plaza"', ` "zombie_cost" "${COST}"`, ' "script_flag" "enter_under_plaza"',
    ' // brush 0', trigBrush, '}'].join('\n'),
  ['{', ` guid "${eg2}"`, ' "classname" "script_brushmodel"', ' "targetname" "acc_door_under_plaza"',
    ` "script_vector" "${DOOR_SLIDE} 0 0"`, ' "script_transition_time" "1.5"',
    ' // brush 0', doorBrush, '}'].join('\n'),
].join('\n');

// ---- strip the old south room + door/trigger ----
let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

function stripBetween(arr, beginInc, endInc) {
  const b = arr.findIndex(l => l.includes(beginInc));
  if (b === -1) return arr;
  let e = -1; for (let i = b; i < arr.length; i++) { if (arr[i].includes(endInc)) { e = i; break; } }
  if (e === -1) return arr;
  return [...arr.slice(0, b), ...arr.slice(e + 1)];
}
lines = stripBetween(lines, '===== UNDER ROOM SOUTH', '===== end under room south');

// strip the south door comment + the next 2 brace-balanced entities.
const db = lines.findIndex(l => l.includes('===== UNDER ROOM DOOR (south)'));
if (db !== -1) {
  let ents = 0, depth = 0, end = db;
  for (let i = db + 1; i < lines.length && ents < 2; i++) {
    depth += (lines[i].match(/{/g) || []).length - (lines[i].match(/}/g) || []).length;
    if (depth === 0 && (lines[i].match(/}/g) || []).length > 0) { ents++; end = i; }
  }
  lines = [...lines.slice(0, db), ...lines.slice(end + 1)];
}

// ---- inject: block inside worldspawn, door/trigger as trailing entities ----
function wsClose(arr) { let d = 0, ei = -1; for (let i = 0; i < arr.length; i++) { const o = (arr[i].match(/{/g) || []).length, c = (arr[i].match(/}/g) || []).length; for (let k = 0; k < o; k++) { if (d === 0) ei++; d++; } for (let k = 0; k < c; k++) { d--; if (d === 0 && ei === 0) return i; } } return -1; }
const wc = wsClose(lines);
if (wc === -1) { console.error('worldspawn close not found'); process.exit(2); }
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wc) out.push(blockLines);
  out.push(lines[i]);
  if (i === wc) out.push(entLines);
}
fs.writeFileSync(MAP, out.join('\n'));
console.log(`[relocate-exo] room center ${ROOM_CX}: room x[${RX1},${RX2}] y[${IY1},${IY2}], doorway x[${DX1},${DX2}] (80u, slides ${DOOR_SLIDE} W)`);
console.log(`[relocate-exo] Exo station origin must shift x += ${ROOM_CX} (was centered at 0) - update acc_exo::spawn_station. FULL LED-baked build needed.`);
