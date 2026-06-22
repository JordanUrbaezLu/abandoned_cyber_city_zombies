#!/usr/bin/env node
// add_trench_floor.js - underground FLOOR, segment 1: carve a tight HALL A + the first
// CHAMBER B extending SOUTH out of the Plaza-facing trench room (user 2026-06-18, the
// "Data Vault" gauntlet, workflow underground-shards-design).
//
// Carves a doorway through the south room's back wall (the "trench room S - back wing"
// slab at y[1148,1339]), then builds a tight 192u-wide hall (Hall A) and a wider chamber
// (Chamber B) south of it as fully-ENCLOSED sealed boxes (floor + ceiling-slab-to-z0 + all
// walls), at the SAME z-band as the rooms (floor z=-240, ceiling void top z=-80). Every
// segment is a sealed cavity so cod2map can't leak.
//
// POST-PROCESSOR: run AFTER add_trench_rooms.js (reads the south back-wing's LIVE z, so it
// tracks depth retunes). BAKE-GATE after (tools/_bake_test.ps1). Re-run after any regen.
//
// Usage:
//   node tools/add_trench_floor.js <in.map> --dry
//   node tools/add_trench_floor.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_trench_floor.js <in> <out|--dry>'); process.exit(1); }
const dry = (outArg === '--dry');

// ---- design (XY fixed; Z read live from the south back wing) -------------------
const DX = 96;          // doorway / hall half-width (192u tight lane)
const HALL_WT = 32;     // hall wall thickness
const CH_HX = 256;      // chamber interior half-width (512 wide)
const CH_WT = 32;       // chamber wall thickness
const BW_Y1 = 1148, BW_Y2 = 1339;   // south back-wing y-span (the wall we carve through)
const HALL_Y1 = 1019, HALL_Y2 = 1148;   // Hall A (south of the back wing)
const CH_Y1 = 700, CH_Y2 = 1019;         // Chamber B (south of Hall A)
const CH_S_WT = 32;     // chamber south end-wall thickness
const CH_N_WT = 32;     // chamber north wall thickness (beside the hall mouth)

let guidCounter = 0x800;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F08-ACC8-4E0E-8A3F-${c}}`; }
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

// ---- parsing (from add_trench_rooms.js) ---------------------------------------
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;

// the south back wing add_trench_rooms.js created: x[-256,256] y[1148,1339] z[SLAB_BOT,0]
function isSouthBackWing(b){ return near(b[0],-256)&&near(b[1],256)&&near(b[2],BW_Y1)&&near(b[3],BW_Y2)&&b[4]<-100&&near(b[5],0); }

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, bw = null;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces);
      if (b && isSouthBackWing(b)) bw = { b, start: blk.start, end: i };
    }
  }
}
if (!bw) { console.error('ERROR: south room back wing (x[-256,256] y[1148,1339]) not found - run add_trench_rooms first.'); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const SLAB_BOT = bw.b[4];               // -256
const FLOOR_TOP = bw.b[5];               // 0
const TRENCH_FLOOR = SLAB_BOT + 16;      // -240 (room/hall floor surface)
const RZ_CEIL = TRENCH_FLOOR + 160;      // -80 (ceiling void top; ceiling slab RZ_CEIL..0)
console.log(`  live: back wing z[${SLAB_BOT},${FLOOR_TOP}] -> floor ${TRENCH_FLOOR}, ceil ${RZ_CEIL}`);

const add = [];
const F = 'script_floor_ceiling', W = 'script_wall';
const wadd = (label, txt) => add.push(`// ${label}\n${txt}`);

// --- carve the doorway through the south back wing (replaces it) ---
wadd('floor seg1 - back wing L',  box(-256, -DX, BW_Y1, BW_Y2, SLAB_BOT, FLOOR_TOP, F));
wadd('floor seg1 - back wing R',  box(  DX, 256, BW_Y1, BW_Y2, SLAB_BOT, FLOOR_TOP, F));
wadd('floor seg1 - doorway floor',box(-DX,  DX, BW_Y1, BW_Y2, SLAB_BOT, TRENCH_FLOOR, F));
wadd('floor seg1 - doorway ceil', box(-DX,  DX, BW_Y1, BW_Y2, RZ_CEIL, FLOOR_TOP, F));

// --- Hall A: tight 192u lane south of the back wing ---
wadd('floor seg1 - HallA floor', box(-DX - HALL_WT, DX + HALL_WT, HALL_Y1, HALL_Y2, SLAB_BOT, TRENCH_FLOOR, F));
wadd('floor seg1 - HallA ceil',  box(-DX - HALL_WT, DX + HALL_WT, HALL_Y1, HALL_Y2, RZ_CEIL, FLOOR_TOP, F));
wadd('floor seg1 - HallA W wall', box(-DX - HALL_WT, -DX, HALL_Y1, HALL_Y2, TRENCH_FLOOR, RZ_CEIL, W));
wadd('floor seg1 - HallA E wall', box(  DX, DX + HALL_WT, HALL_Y1, HALL_Y2, TRENCH_FLOOR, RZ_CEIL, W));

// --- Chamber B: wider room south of Hall A ---
wadd('floor seg1 - ChamberB floor', box(-CH_HX - CH_WT, CH_HX + CH_WT, CH_Y1, CH_Y2, SLAB_BOT, TRENCH_FLOOR, F));
wadd('floor seg1 - ChamberB ceil',  box(-CH_HX - CH_WT, CH_HX + CH_WT, CH_Y1, CH_Y2, RZ_CEIL, FLOOR_TOP, F));
wadd('floor seg1 - ChamberB W wall', box(-CH_HX - CH_WT, -CH_HX, CH_Y1, CH_Y2, TRENCH_FLOOR, RZ_CEIL, W));
wadd('floor seg1 - ChamberB E wall', box(  CH_HX, CH_HX + CH_WT, CH_Y1, CH_Y2, TRENCH_FLOOR, RZ_CEIL, W));
wadd('floor seg1 - ChamberB S wall', box(-CH_HX - CH_WT, CH_HX + CH_WT, CH_Y1, CH_Y1 + CH_S_WT, TRENCH_FLOOR, RZ_CEIL, W));
// north wall closes the chamber's top edge EXCEPT the Hall A mouth (x[-DX,DX])
wadd('floor seg1 - ChamberB N wall L', box(-CH_HX, -DX, CH_Y2 - CH_N_WT, CH_Y2, TRENCH_FLOOR, RZ_CEIL, W));
wadd('floor seg1 - ChamberB N wall R', box(  DX, CH_HX, CH_Y2 - CH_N_WT, CH_Y2, TRENCH_FLOOR, RZ_CEIL, W));

console.log(`  REMOVE back wing lines ${bw.start + 1}-${bw.end + 1}; INJECT ${add.length} brushes.`);
if (dry) { console.log('[floor] --dry: nothing written.'); process.exit(0); }

for (let j = bw.start; j <= bw.end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) { out.push('// ===== UNDERGROUND FLOOR seg1: Hall A + Chamber B (add_trench_floor.js) ====='); out.push(...add); out.push('// ===== end floor seg1 ====='); }
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[floor] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
