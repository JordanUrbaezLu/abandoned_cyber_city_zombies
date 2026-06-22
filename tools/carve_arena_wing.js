#!/usr/bin/env node
// carve_arena_wing.js - carve a wing room out of the Reactor Core ARENA's wide outer-wall fill
// (west|east), opening into the arena (user 2026-06-19, keep expanding the underground north end).
// Mirrors carve_wing.js (south) but for the arena's outer walls from expand_core.js.
//
// SAFE: the walkable floor (north single slab z[-96,0]) + the arena's bottom slabs (z[-256,-240])
// are untouched. We only replace the outer WALL (z[-240,-96]) with a far-outer wall + 2 seal walls,
// leaving the wing void open INTO the arena at x=+/-384. No new z=0-over-void (single-slab rule).
// STRICT: errors if the target outer wall isn't found (catches drift).
//
// Usage: node tools/carve_arena_wing.js <in.map> <out.map> west|east
'use strict';
const fs = require('fs');
const [, , inPath, outArg, side] = process.argv;
if (!inPath || !outArg || (side !== 'west' && side !== 'east')) { console.error('usage: carve_arena_wing.js <in> <out> west|east'); process.exit(1); }

const F = 'script_floor_ceiling', W = 'script_wall';
const WY_S = 2280, WY_N = 2640;   // wing void y-extent (inside the arena depth, leaving south/north seal walls)
const FAR = 61;                   // far-outer wall thickness

// arena outer walls from expand_core.js: west box(-781,-384, 2173,2748, -240,-96); east box(384,819, ...)
const TGT = (side === 'west') ? [-781, -384, 2173, 2748, -240, -96] : [384, 819, 2173, 2748, -240, -96];
const INNER = (side === 'west') ? -384 : 384;                 // edge that opens into the arena
const OUTER = (side === 'west') ? -781 : 819;
const FARX  = (side === 'west') ? [OUTER, OUTER + FAR] : [OUTER - FAR, OUTER];
const VX1   = (side === 'west') ? OUTER + FAR : INNER;
const VX2   = (side === 'west') ? INNER : OUTER - FAR;
const lo = Math.min(VX1, VX2), hi = Math.max(VX1, VX2);

let guidCounter = 0x1000;   // fresh seed (audit: avoid dup GUIDs)
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F10-ACD0-4E17-8A3F-${c}}`; }
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

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;
const eqB = (b, t) => b && near(b[0],t[0])&&near(b[1],t[1])&&near(b[2],t[2])&&near(b[3],t[3])&&near(b[4],t[4])&&near(b[5],t[5]);

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, target = null;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) stack[stack.length - 1].faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]);
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.faces.length === 6 && !target) { const b = boundsOf(blk.faces); if (eqB(b, TGT)) target = { start: blk.start, end: i }; }
  }
}
if (!target) { console.error(`ERROR: arena ${side} outer wall ${TGT} not found - run expand_core first / layout drifted; aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const name = (side === 'west') ? 'ARENA WEST WING' : 'ARENA EAST WING';
const add = [`// ===== ${name} (carve_arena_wing.js ${side}) =====`];
const wadd = (label, txt) => add.push(`// ${label}\n${txt}`);
wadd('far outer wall', box(FARX[0], FARX[1], 2173, 2748, -240, -96, W));
wadd('south seal wall', box(lo, hi, 2173, WY_S, -240, -96, W));
wadd('north seal wall', box(lo, hi, WY_N, 2748, -240, -96, W));
// void x[lo,hi] y[WY_S,WY_N] z[-240,-96] = open; opens into the arena at x=INNER
add.push(`// ===== end ${name.toLowerCase()} =====`);

for (let j = target.start; j <= target.end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) { if (i === wsClose) out.push(...add); if (remove[i]) continue; out.push(lines[i]); }
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  ${name}: void x[${lo},${hi}] y[${WY_S},${WY_N}] z[-240,-96]; opens into arena at x=${INNER}.`);
console.log(`  replaced 1 outer wall -> 3 walls; floor slab + bottom slab UNCHANGED.`);
console.log(`[arena-wing] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
