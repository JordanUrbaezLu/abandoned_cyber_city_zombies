#!/usr/bin/env node
// add_pit_room.js - re-add ONE trench room the SAFE way (user 2026-06-19, after the
// fall-through disaster). Widen the trench into an OPEN sunken pit over the room footprint
// (remove the z=0 slab there) and build an ENCLOSED room INSIDE that open pit: floor at the
// trench level (z=-240), walls, a ceiling BELOW floor-level (z=-64, so it sits inside the open
// pit - NOT under the Bus Station floor), and a buyable sideways-sliding door.
//
// WHY THIS CAN'T REPEAT THE BUG: the only WALKABLE surfaces are (a) the solid z=0 corp slabs,
// which stay full-thickness z[-256,0] and are untouched outside the notch, and (b) the z=-240
// pit floor, a bottom slab z[-256,-240]. Both are full/bottom slabs cod2map always keeps. The
// only thin slab is the room ROOF (z[-80,-64]); it is NOT walkable, so even if cod2map drops it
// the result is cosmetic (room open to the pit above), never a fall-through.
//
// Usage: node tools/add_pit_room.js <in.map> <out.map> south|north
'use strict';
const fs = require('fs');
const [, , inPath, outArg, side] = process.argv;
if (!inPath || !outArg || (side !== 'south' && side !== 'north')) { console.error('usage: add_pit_room.js <in> <out> south|north'); process.exit(1); }

// ---- design (tunable) ----
const RX1 = -192, RX2 = 192;   // room half-width (384 wide)
const DEPTH = 344;             // how far the room+pit reaches off the trench wall
const FRONT_TH = 16;           // front-wall thickness
const DX1 = -96, DX2 = 96;     // doorway (192 wide)
const DOOR_SLIDE = 192;        // door slides its own width sideways into the wall pocket
const ROOM_TOP = -80;          // room interior ceiling / door top (open pit shaft above this)
const ROOF_TOP = -64;          // room roof slab top - BELOW z=0, inside the open pit
const COST = 1500;

let guidCounter = 0xA00;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0A-ACCA-4E10-8A3F-${c}}`; }
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

// ---- parsing (from add_trench_rooms.js) ----
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;
const SLAB_Y = (side === 'south') ? [1148, 1723] : [2173, 2748];
function isSlab(b){ return near(b[0],-781)&&near(b[1],819)&&near(b[2],SLAB_Y[0])&&near(b[3],SLAB_Y[1])&&b[4]<-100&&near(b[5],0); }

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, slab = null;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces); if (b && isSlab(b)) slab = { b, start: blk.start, end: i };
    }
  }
}
if (!slab) { console.error(`ERROR: ${side} corp ground slab (x[-781,819] y[${SLAB_Y}]) not found - run fill_trench_rooms first.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const SX1 = slab.b[0], SX2 = slab.b[1], SLAB_BOT = slab.b[4], FLOOR_TOP = slab.b[5];
const TRENCH_FLOOR = SLAB_BOT + 16;
const TW   = (side === 'south') ? slab.b[3] : slab.b[2];   // trench-wall face (1723 / 2173)
const BACK = (side === 'south') ? slab.b[2] : slab.b[3];   // far slab face (1148 / 2748)
const RYB  = (side === 'south') ? TW - DEPTH : TW + DEPTH;
const FWY  = (side === 'south') ? TW - FRONT_TH : TW + FRONT_TH;
const sp = (a, b) => (a < b ? [a, b] : [b, a]);
const [PY1, PY2] = sp(RYB, TW);   // pit floor
const [IY1, IY2] = sp(RYB, FWY);  // room interior / roof
const [WY1, WY2] = sp(FWY, TW);   // front wall
const [BY1, BY2] = sp(BACK, RYB); // solid back part

const F = 'script_floor_ceiling', W = 'script_wall';
const add = [];
const wadd = (label, txt) => add.push(`// ${label}\n${txt}`);
wadd(`pit room ${side} - west solid floor`, box(SX1, RX1, SLAB_Y[0], SLAB_Y[1], SLAB_BOT, FLOOR_TOP, F));
wadd(`pit room ${side} - east solid floor`, box(RX2, SX2, SLAB_Y[0], SLAB_Y[1], SLAB_BOT, FLOOR_TOP, F));
wadd(`pit room ${side} - back solid floor`, box(RX1, RX2, BY1, BY2, SLAB_BOT, FLOOR_TOP, F));
wadd(`pit room ${side} - pit floor -240`,   box(RX1, RX2, PY1, PY2, SLAB_BOT, TRENCH_FLOOR, F));
wadd(`pit room ${side} - room roof`,        box(RX1, RX2, IY1, IY2, ROOM_TOP, ROOF_TOP, F));
wadd(`pit room ${side} - front wall L`,     box(RX1, DX1, WY1, WY2, TRENCH_FLOOR, ROOF_TOP, W));
wadd(`pit room ${side} - front wall R`,     box(DX2, RX2, WY1, WY2, TRENCH_FLOOR, ROOF_TOP, W));
wadd(`pit room ${side} - door lintel`,      box(DX1, DX2, WY1, WY2, ROOM_TOP, ROOF_TOP, W));

const tag = (side === 'south') ? 'pit_plaza' : 'pit_lab';
const eg1 = guid(), eg2 = guid();
const doorBrush = box(DX1, DX2, WY1, WY2, TRENCH_FLOOR, ROOM_TOP, W);
const [TGY1, TGY2] = (side === 'south') ? sp(FWY, TW + 40) : sp(FWY, TW - 40);
const trigBrush = box(DX1 - 16, DX2 + 16, TGY1, TGY2, TRENCH_FLOOR, ROOM_TOP + 20, 'trigger');
const ents = [
  `// ===== PIT ROOM DOOR (${side}) =====`,
  ['{', ` guid "${eg1}"`, ' "classname" "trigger_use"', ' "targetname" "zombie_door"',
    ` "target" "acc_door_${tag}"`, ` "zombie_cost" "${COST}"`, ` "script_flag" "enter_${tag}"`,
    ' // brush 0', trigBrush, '}'].join('\n'),
  ['{', ` guid "${eg2}"`, ' "classname" "script_brushmodel"', ` "targetname" "acc_door_${tag}"`,
    ` "script_vector" "${DOOR_SLIDE} 0 0"`, ' "script_transition_time" "1.5"',
    ' // brush 0', doorBrush, '}'].join('\n'),
];

console.log(`  ${side}: slab z[${SLAB_BOT},${FLOOR_TOP}] floor=${TRENCH_FLOOR}; pit/room x[${RX1},${RX2}] y[${Math.min(RYB,TW)},${Math.max(RYB,TW)}]`);
console.log(`  WALKABLE = z0 solid slabs (west/east/back) + z-240 pit floor (both full/bottom slabs); room roof z[-80,-64] is non-walkable.`);
console.log(`  REMOVE ${side} slab lines ${slab.start + 1}-${slab.end + 1}; INJECT 8 brushes + door.`);
for (let j = slab.start; j <= slab.end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) { out.push(`// ===== PIT ROOM ${side.toUpperCase()} (add_pit_room.js) =====`); out.push(...add); out.push(`// ===== end pit room ${side} =====`); }
  if (remove[i]) continue;
  out.push(lines[i]);
  if (i === wsClose) out.push(...ents);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[pit] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
