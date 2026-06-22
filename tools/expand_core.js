#!/usr/bin/env node
// expand_core.js - widen + deepen the north Reactor Core into the full arena (user 2026-06-19,
// "continue expanding the underground"). The Core was built by add_under_room.js north as a small
// room (void x[-192,192] y[2189,2517]); this carves its side + back fills into a big arena
// (void x[-384,384] y[2189,2732]) for the Reactor Surge event.
//
// SAFE: the walkable floor (the north single slab z[-96,0]) is NOT touched - it already spans the
// whole footprint x[-781,819] y[2173,2748], so widening only hollows fill BELOW z=-96 + leaves
// sealing walls. No new z=0-over-void => no fall-through (memory single-slab-floor-over-room).
//
// It REPLACES 5 existing brushes (west/east/back fills + front-wall L/R) with the wider arena set,
// keeping the floor slab, the door, and the original room floor (y2173-2517). STRICT: errors if any
// of the 5 is not found (so a layout drift is caught before the build, never silently mis-carved).
//
// Usage: node tools/expand_core.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: expand_core.js <in> <out>'); process.exit(1); }

const F = 'script_floor_ceiling', W = 'script_wall';
const HALF = 384, BACKW = 2732;   // arena half-width + back-wall front face (16-thick wall to slab edge 2748)

let guidCounter = 0xE00;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0E-ACCE-4E15-8A3F-${c}}`; }
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

// ---- parsing ----
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;
const eqB = (b, t) => b && near(b[0],t[0])&&near(b[1],t[1])&&near(b[2],t[2])&&near(b[3],t[3])&&near(b[4],t[4])&&near(b[5],t[5]);

// the 5 brushes add_under_room.js north emitted that we replace (exact bounds):
const TARGETS = [
  { key: 'west_fill',  b: [-781, -192, 2173, 2748, -256, -96] },
  { key: 'east_fill',  b: [ 192,  819, 2173, 2748, -256, -96] },
  { key: 'back_fill',  b: [-192,  192, 2517, 2748, -256, -96] },
  { key: 'front_L',    b: [-192,  -96, 2173, 2189, -240, -96] },
  { key: 'front_R',    b: [  96,  192, 2173, 2189, -240, -96] },
];

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1;
const found = {};
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) stack[stack.length - 1].faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]);
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.faces.length === 6) {
      const b = boundsOf(blk.faces);
      for (const t of TARGETS) if (!found[t.key] && eqB(b, t.b)) { found[t.key] = { start: blk.start, end: i }; }
    }
  }
}
const missing = TARGETS.filter(t => !found[t.key]).map(t => t.key);
if (missing.length) { console.error(`ERROR: north-room brush(es) not found: ${missing.join(', ')} - layout drifted; aborting (no mis-carve).`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

// arena brushes (void x[-384,384] y[2189,2732] is implicit = absence of brush)
const add = ['// ===== REACTOR CORE ARENA (expand_core.js) ====='];
const wadd = (label, txt) => add.push(`// core arena - ${label}\n${txt}`);
wadd('west bottom slab (floor)', box(-781, -192, 2173, 2748, -256, -240, F));
wadd('east bottom slab (floor)', box( 192,  819, 2173, 2748, -256, -240, F));
wadd('back bottom slab (floor for deepened part)', box(-192, 192, 2517, 2748, -256, -240, F));
wadd('west outer wall',  box(-781, -HALF, 2173, 2748, -240, -96, W));
wadd('east outer wall',  box(HALF,  819, 2173, 2748, -240, -96, W));
wadd('back wall',        box(-192,  192, BACKW, 2748, -240, -96, W));
wadd('west back-strip',  box(-HALF, -192, BACKW, 2748, -240, -96, W));
wadd('east back-strip',  box( 192,  HALF, BACKW, 2748, -240, -96, W));
wadd('front wall L (widened)', box(-HALF, -96, 2173, 2189, -240, -96, W));
wadd('front wall R (widened)', box(  96, HALF, 2173, 2189, -240, -96, W));
add.push('// ===== end reactor core arena =====');

for (const t of TARGETS) for (let j = found[t.key].start; j <= found[t.key].end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(...add);
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  Reactor Core -> arena: void x[-${HALF},${HALF}] y[2189,${BACKW}] z[-240,-96] (was x[-192,192] y[2189,2517]).`);
console.log(`  replaced 5 fills/walls -> 10 arena brushes; floor slab + door + room floor (y2173-2517) UNCHANGED.`);
console.log(`[arena] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
