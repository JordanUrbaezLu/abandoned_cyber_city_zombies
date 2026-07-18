#!/usr/bin/env node
// carve_south_concourse.js - carve the unused SOUTH STRIP (y[1148,1379]) behind the Foundry +
// both wings into a connecting concourse, linking Stalls <-> Foundry <-> Cages along their south
// edge (user 2026-06-19, "keep expanding the underground"). New walkable space + a connectivity
// loop instead of three dead-end rooms off the Foundry.
//
// SAFE: the walkable floor (south single slab z[-96,0]) is untouched - it already spans the whole
// corp footprint x[-781,819], so we only hollow solid fill BELOW z=-96 + add sealing walls. No new
// z=0-over-void (single-slab rule, memory single-slab-floor-over-room). Proven carve, same as the
// wings/arena. STRICT: errors if any of the 3 target brushes isn't found (catches layout drift).
//
// Removes: Foundry back-fill, Stalls south wall, Cages south wall. Adds: a re-floor under the
// Foundry strip, an outer south wall, and leaves the concourse void open NORTH into all 3 rooms.
// Side walls (Stalls outer x[-781,-720], Cages outer x[758,819]) already seal east/west.
//
// Usage: node tools/carve_south_concourse.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: carve_south_concourse.js <in> <out>'); process.exit(1); }

const F = 'script_floor_ceiling', W = 'script_wall';
const STRIP_S = 1148, STRIP_N = 1379;     // the south strip (back-fill band)
const SOUTH_WALL_N = 1163;                // outer south wall front face (15-thick seal to corp edge 1148)
const VX1 = -720, VX2 = 758;              // concourse void x-extent (between the wing outer walls)

let guidCounter = 0xF00;                  // fresh seed - no overlap with the other generators (audit: avoid dup GUIDs)
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0F-ACCF-4E16-8A3F-${c}}`; }
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

const TARGETS = [
  { key: 'foundry_back_fill', b: [-192, 192, 1148, 1379, -256, -96] },   // add_under_room south back fill
  { key: 'stalls_south_wall', b: [-720, -192, 1148, 1379, -240, -96] },  // carve_wing west south wall
  { key: 'cages_south_wall',  b: [192, 758, 1148, 1379, -240, -96] },    // carve_wing east south wall
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
      for (const t of TARGETS) if (!found[t.key] && eqB(b, t.b)) found[t.key] = { start: blk.start, end: i };
    }
  }
}
const missing = TARGETS.filter(t => !found[t.key]).map(t => t.key);
if (missing.length) { console.error(`ERROR: south-strip brush(es) not found: ${missing.join(', ')} - layout drifted; aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const add = ['// ===== SOUTH CONCOURSE (carve_south_concourse.js) ====='];
const wadd = (label, txt) => add.push(`// concourse - ${label}\n${txt}`);
wadd('re-floor under Foundry strip (bottom slab)', box(-192, 192, STRIP_S, STRIP_N, -256, -240, F));
wadd('outer south wall (seal)', box(VX1, VX2, STRIP_S, SOUTH_WALL_N, -240, -96, W));
// void x[VX1,VX2] y[SOUTH_WALL_N,STRIP_N] z[-240,-96] = open; opens NORTH (y=1379) into Stalls/Foundry/Cages
add.push('// ===== end south concourse =====');

for (const t of TARGETS) for (let j = found[t.key].start; j <= found[t.key].end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(...add);
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  South concourse: void x[${VX1},${VX2}] y[${SOUTH_WALL_N},${STRIP_N}] z[-240,-96]; opens N into Stalls/Foundry/Cages.`);
console.log(`  removed 3 fill/walls -> 2 brushes (re-floor + south wall); floor slab + side outer walls UNCHANGED.`);
console.log(`[concourse] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
