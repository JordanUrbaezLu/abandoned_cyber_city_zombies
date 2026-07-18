#!/usr/bin/env node
// add_corp_trench.js - re-add the BUS STATION (corp_zone) cross-room trench.
// Removes the flat 1600x1600 corp floor slab and injects the 41 trench brushes
// (geometry verbatim from tools/gen_corp_trench.js: S/N ground slabs, recessed
// floor, E/W end walls, 2 diagonal 17-step staircases, 2 guard rails) into
// worldspawn. Coords match _acc_bus_trench.gsc (the fall-tax script, still live).
// BAKE-GATE after (tools/_bake_test.ps1) - new sunken geometry, navmesh regen.
//
// Usage:
//   node tools/add_corp_trench.js <in.map> --dry      # report only
//   node tools/add_corp_trench.js <in.map> <out.map>  # remove floor + inject
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_corp_trench.js <in> <out|--dry>'); process.exit(1); }
const dry = (outArg === '--dry');

// ---- trench geometry (verbatim params from tools/gen_corp_trench.js) ----------
const X1 = -781, X2 = 819, ROOM_Y1 = 1148, ROOM_Y2 = 2748, WALL_TH = 20;
const TRENCH_Y1 = 1723, TRENCH_Y2 = 2173, TRENCH_FLOOR = -288, SLAB_BOT = -304, FLOOR_TOP = 0;
const STAIR_CHANNELS = [
  { x1: -761, x2: -665, side: 'south', name: 'W', wall: 'west' },
  { x1: 703, x2: 799, side: 'north', name: 'E', wall: 'east' },
];
const GUARD_TH = 16, STEP = 16, N_STEPS = 17;
let guidCounter = 0x300;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F00-ACC3-4E0C-8A3F-${c}}`; }
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
const tBrushes = [];
const add = (label, txt) => tBrushes.push(`// ${label}\n${txt}`);
add('corp south ground slab (replaces corp floor)', box(X1, X2, ROOM_Y1, TRENCH_Y1, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
add('corp north ground slab', box(X1, X2, TRENCH_Y2, ROOM_Y2, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
add('corp trench floor', box(X1, X2, TRENCH_Y1, TRENCH_Y2, SLAB_BOT, TRENCH_FLOOR, 'script_floor_ceiling'));
add('corp trench west end wall', box(X1, X1 + WALL_TH, TRENCH_Y1, TRENCH_Y2, TRENCH_FLOOR, FLOOR_TOP, 'script_wall'));
add('corp trench east end wall', box(X2 - WALL_TH, X2, TRENCH_Y1, TRENCH_Y2, TRENCH_FLOOR, FLOOR_TOP, 'script_wall'));
for (const ch of STAIR_CHANNELS) {
  for (let k = 1; k <= N_STEPS; k++) {
    const top = -STEP * k; let yA, yB, lip;
    if (ch.side === 'south') { yA = TRENCH_Y1 + STEP * (k - 1); yB = TRENCH_Y1 + STEP * k; lip = 'S'; }
    else { yB = TRENCH_Y2 - STEP * (k - 1); yA = TRENCH_Y2 - STEP * k; lip = 'N'; }
    add(`corp trench ${ch.name} stair ${lip}${k}`, box(ch.x1, ch.x2, yA, yB, TRENCH_FLOOR, top, 'script_floor_ceiling'));
  }
}
const runY = N_STEPS * STEP;
for (const ch of STAIR_CHANNELS) {
  const yA = (ch.side === 'south') ? TRENCH_Y1 : TRENCH_Y2 - runY;
  const yB = (ch.side === 'south') ? TRENCH_Y1 + runY : TRENCH_Y2;
  const gx1 = (ch.wall === 'west') ? ch.x2 : ch.x1 - GUARD_TH;
  const gx2 = (ch.wall === 'west') ? ch.x2 + GUARD_TH : ch.x1;
  add(`corp trench ${ch.name} stair guard rail`, box(gx1, gx2, yA, yB, TRENCH_FLOOR, FLOOR_TOP, 'script_wall'));
}

// ---- map surgery -------------------------------------------------------------
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 1;
function isCorpFloor(b){return near(b[0],X1)&&near(b[1],X2)&&near(b[2],ROOM_Y1)&&near(b[3],ROOM_Y2)&&near(b[4],-16)&&near(b[5],0);}

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, removedFloor = false;
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
      if (b && isCorpFloor(b)) { for (let j = blk.start; j <= i; j++) remove[j] = true; removedFloor = true; console.log(`  REMOVE corp floor slab: x[${b[0]},${b[1]}] y[${b[2]},${b[3]}] z[${b[4]},${b[5]}]`); }
    }
  }
}
if (!removedFloor) { console.error('ERROR: corp floor slab (x[-781,819] y[1148,2748] z[-16,0]) not found - aborting.'); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn closing brace not found - aborting.'); process.exit(2); }
console.log(`  INJECT ${tBrushes.length} trench brushes before worldspawn close (line ${wsClose + 1}).`);
if (dry) { console.log('[trench] --dry: nothing written.'); process.exit(0); }
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) { out.push('// ===== BUS STATION TRENCH (re-added from gen_corp_trench.js) ====='); out.push(...tBrushes); out.push('// ===== end trench ====='); }
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[trench] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
