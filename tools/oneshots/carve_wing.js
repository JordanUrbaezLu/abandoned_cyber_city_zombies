#!/usr/bin/env node
// carve_wing.js - carve a market-wing alcove out of the SOUTH under-room's side fill,
// opening into the Foundry. west = THE STALLS, east = THE CAGES (docs/45).
//
// SAFE BY CONSTRUCTION: the walkable floor is NOT touched. The south single slab z[-96,0]
// already spans the whole footprint x[-781,819], so the ceiling over the wing already
// exists. We only REPLACE the solid side-fill (z[-256,-96]) with: a bottom slab
// (z[-256,-240], always kept) + three sealing walls (z[-240,-96]) + an open void. The void's
// inner edge opens straight into the Foundry room (no door - you already paid 1500 for the
// Foundry). No new z=0-over-void brush => the fall-through cull cannot occur. See
// memory single-slab-floor-over-room.
//
// Usage: node tools/carve_wing.js <in.map> <out.map> west|east
'use strict';
const fs = require('fs');
const [, , inPath, outArg, side] = process.argv;
if (!inPath || !outArg || (side !== 'west' && side !== 'east')) { console.error('usage: carve_wing.js <in> <out> west|east'); process.exit(1); }

// ---- design (tunable) ----
const FLOOR_BOT = -96;     // ceiling of the wing = bottom of the single floor slab
const ROOM_FLOOR = -240;   // wing floor top (= trench/Foundry floor level, flush)
const RY0 = 1379, RY1 = 1700;   // wing void y-extent (inside the south room footprint)
const WALL = 61;           // outer-wall thickness

// the south under-room's side fill we carve (from add_under_room.js south):
//   west fill = box(-781,-192, 1148,1723, -256,-96);  east fill = box(192,819, 1148,1723, -256,-96)
const FX1 = (side === 'west') ? -781 : 192;
const FX2 = (side === 'west') ? -192 : 819;
const FY1 = 1148, FY2 = 1723, FZB = -256, FZT = -96;
const INNER = (side === 'west') ? FX2 : FX1;                 // edge that opens into the Foundry
const OUTER = (side === 'west') ? FX1 : FX2;                 // far edge (gets the outer wall)
const WALLX = (side === 'west') ? [OUTER, OUTER + WALL] : [OUTER - WALL, OUTER];
const VX1 = (side === 'west') ? OUTER + WALL : INNER;        // void x-range
const VX2 = (side === 'west') ? INNER : OUTER - WALL;

let guidCounter = 0xC00;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0C-ACCC-4E12-8A3F-${c}}`; }
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

// ---- parsing (from add_under_room.js) ----
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;
function isFill(b){ return near(b[0],Math.min(FX1,FX2))&&near(b[1],Math.max(FX1,FX2))&&near(b[2],FY1)&&near(b[3],FY2)&&near(b[4],FZB)&&near(b[5],FZT); }

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, fill = null;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces); if (b && isFill(b)) fill = { b, start: blk.start, end: i };
    }
  }
}
if (!fill) { console.error(`ERROR: south ${side} fill (x[${Math.min(FX1,FX2)},${Math.max(FX1,FX2)}] y[${FY1},${FY2}] z[${FZB},${FZT}]) not found - run add_under_room south first.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const lo = Math.min(VX1, VX2), hi = Math.max(VX1, VX2);
const F = 'script_floor_ceiling', W = 'script_wall';
const name = (side === 'west') ? 'STALLS' : 'CAGES';
const add = [];
const wadd = (label, txt) => add.push(`// ${label}\n${txt}`);
wadd(`${name} - bottom slab (always kept)`, box(Math.min(FX1,FX2), Math.max(FX1,FX2), FY1, FY2, FZB, ROOM_FLOOR, F));
wadd(`${name} - outer wall`,  box(WALLX[0], WALLX[1], FY1, FY2, ROOM_FLOOR, FLOOR_BOT, W));
wadd(`${name} - south wall`,  box(lo, hi, FY1, RY0, ROOM_FLOOR, FLOOR_BOT, W));
wadd(`${name} - north wall`,  box(lo, hi, RY1, FY2, ROOM_FLOOR, FLOOR_BOT, W));
// void x[${lo},${hi}] y[${RY0},${RY1}] z[${ROOM_FLOOR},${FLOOR_BOT}] = open; INNER edge x=${INNER} opens into the Foundry.

console.log(`  ${name} (${side}): void x[${lo},${hi}] y[${RY0},${RY1}] z[${ROOM_FLOOR},${FLOOR_BOT}]; opens into Foundry at x=${INNER}`);
console.log(`  walkable floor UNCHANGED (existing single slab z[-96,0]); replaced solid fill with bottom slab + 3 walls + open void.`);
console.log(`  REMOVE ${side} fill lines ${fill.start + 1}-${fill.end + 1}; INJECT 4 brushes.`);
for (let j = fill.start; j <= fill.end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) { out.push(`// ===== ${name} WING (carve_wing.js ${side}) =====`); out.push(...add); out.push(`// ===== end ${name.toLowerCase()} wing =====`); }
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[wing] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
