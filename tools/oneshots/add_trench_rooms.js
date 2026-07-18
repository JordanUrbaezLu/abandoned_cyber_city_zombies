#!/usr/bin/env node
// add_trench_rooms.js - carve TWO rooms off the Bus Station trench (user 2026-06-18).
//
// One room behind the SOUTH trench wall (y=TRENCH_Y1, "facing the Plaza") and one
// behind the NORTH wall (y=TRENCH_Y2, "facing the Lab"), both at the trench-floor
// level. Each is gated by a buyable stock zombie_door (a script_brushmodel that
// slides SIDEWAYS into the wall pocket - so the room height is not limited by the
// slide, unlike the stock slide-UP doors). The fall-tax (_acc_bus_trench, y-band
// gated) is UNTOUCHED: it still applies in the pit; the rooms (outside the band) are
// a respite.
//
// POST-PROCESSOR: run AFTER gen_corp_trench.js / add_corp_trench.js (it reads the
// LIVE slab z-bounds from the .map, so it tracks the parallel agent's depth retunes).
// Re-run after any trench regen. BAKE-GATE after (tools/_bake_test.ps1) - new
// enclosed geometry + navmesh regen.
//
// Usage:
//   node tools/add_trench_rooms.js <in.map> --dry      # report only
//   node tools/add_trench_rooms.js <in.map> <out.map>  # carve rooms + add doors
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_trench_rooms.js <in> <out|--dry>'); process.exit(1); }
const dry = (outArg === '--dry');

// ---- room design (XY fixed; Z read live from the slabs) -----------------------
const RX1 = -256, RX2 = 256;        // room interior half-width (512 wide, centred on x=0)
const ROOM_DEPTH = 384;             // how far the room reaches back from the trench wall
const FRONT_TH = 16;                // front-wall thickness
const DX1 = -112, DX2 = 112;        // doorway opening (224 wide, centred)
const DOOR_SLIDE = 224;             // door slides +x by its own width -> fully clears the doorway
const COST = 1500;                  // buyable cost (trench is deep/late; corp doors are 1000-1250)

let guidCounter = 0x700;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F07-ACC7-4E0D-8A3F-${c}}`; }
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

// ---- .map parsing (borrowed from add_corp_trench.js) --------------------------
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 2;

// south slab y[1148,1723], north slab y[2173,2748], trench floor y[1723,2173] - all
// script_floor_ceiling, x[-781,819]. Match by y-range + x; read z live.
function classifySlab(b){
  if(!(near(b[0],-781)&&near(b[1],819)))return null;
  if(near(b[2],1148)&&near(b[3],1723))return 'south';
  if(near(b[2],2173)&&near(b[3],2748))return 'north';
  if(near(b[2],1723)&&near(b[3],2173))return 'trenchfloor';
  return null;
}

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1;
const found = {}; // south/north slab spans + ranges to remove
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces); if (!b) continue;
      const kind = classifySlab(b);
      if (kind === 'south' || kind === 'north') { found[kind] = { b, start: blk.start, end: i }; }
      else if (kind === 'trenchfloor') { found.trenchfloor = { b }; }
    }
  }
}
for (const k of ['south', 'north', 'trenchfloor']) if (!found[k]) { console.error(`ERROR: ${k} slab not found - aborting (run gen_corp_trench first?).`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const SLAB_BOT = found.south.b[4];          // slab bottom (e.g. -256)
const FLOOR_TOP = found.south.b[5];          // main floor top (0)
const TRENCH_FLOOR = found.trenchfloor.b[5]; // trench floor SURFACE (e.g. -240)
const SX1 = found.south.b[0], SX2 = found.south.b[1];
const RZ_CEIL = TRENCH_FLOOR + 160;          // 160-tall rooms (ceiling slab above stays solid)
console.log(`  live: slab z[${SLAB_BOT},${FLOOR_TOP}] trench floor z=${TRENCH_FLOOR} -> room z[${TRENCH_FLOOR},${RZ_CEIL}]`);

// ---- build the two rooms (decompose each slab + front wall + door) ------------
const wsAdd = [];   // worldspawn brushes
const entAdd = [];  // door entities (trigger + brushmodel)
const wadd = (label, txt) => wsAdd.push(`// ${label}\n${txt}`);

function door(tag, flag, brushBox, trigBox) {
  const eg1 = guid(), eg2 = guid();
  entAdd.push([
    '{', ` guid "${eg1}"`,
    ' "classname" "trigger_use"', ' "targetname" "zombie_door"',
    ` "target" "acc_door_${tag}"`, ` "zombie_cost" "${COST}"`,
    ` "script_flag" "enter_${tag}"`, ' // brush 0', trigBox, '}'].join('\n'));
  entAdd.push([
    '{', ` guid "${eg2}"`,
    ' "classname" "script_brushmodel"', ` "targetname" "acc_door_${tag}"`,
    ` "script_vector" "${DOOR_SLIDE} 0 0"`, ' "script_transition_time" "1.5"',
    ' // brush 0', brushBox, '}'].join('\n'));
}

// SOUTH room (Plaza-facing): behind y=TRENCH_Y1(1723), reaches south (-y)
{
  const TW = found.south.b[3];        // trench wall plane = slab north face (1723)
  const SY = found.south.b[2];        // slab south extent (1148)
  const FWY = TW - FRONT_TH;          // front-wall inner face (1707)
  const RYB = TW - ROOM_DEPTH;        // room back wall (1339)
  wadd('trench room S - west wing',  box(SX1, RX1, SY, TW, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room S - east wing',  box(RX2, SX2, SY, TW, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room S - back wing',  box(RX1, RX2, SY, RYB, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room S - floor',      box(RX1, RX2, RYB, TW, SLAB_BOT, TRENCH_FLOOR, 'script_floor_ceiling'));
  wadd('trench room S - ceiling',    box(RX1, RX2, RYB, TW, RZ_CEIL, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room S - front wall L', box(RX1, DX1, FWY, TW, TRENCH_FLOOR, RZ_CEIL, 'script_wall'));
  wadd('trench room S - front wall R', box(DX2, RX2, FWY, TW, TRENCH_FLOOR, RZ_CEIL, 'script_wall'));
  door('trench_plaza', /*flag*/null,
    box(DX1, DX2, FWY, TW, TRENCH_FLOOR, RZ_CEIL, 'script_wall'),
    box(DX1 - 16, DX2 + 16, FWY, TW + 40, TRENCH_FLOOR, RZ_CEIL - 60, 'trigger'));
}
// NORTH room (Lab-facing): behind y=TRENCH_Y2(2173), reaches north (+y)
{
  const TW = found.north.b[2];        // trench wall plane = slab south face (2173)
  const NY = found.north.b[3];        // slab north extent (2748)
  const FWY = TW + FRONT_TH;          // front-wall inner face (2189)
  const RYB = TW + ROOM_DEPTH;        // room back wall (2557)
  wadd('trench room N - west wing',  box(SX1, RX1, TW, NY, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room N - east wing',  box(RX2, SX2, TW, NY, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room N - back wing',  box(RX1, RX2, RYB, NY, SLAB_BOT, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room N - floor',      box(RX1, RX2, TW, RYB, SLAB_BOT, TRENCH_FLOOR, 'script_floor_ceiling'));
  wadd('trench room N - ceiling',    box(RX1, RX2, TW, RYB, RZ_CEIL, FLOOR_TOP, 'script_floor_ceiling'));
  wadd('trench room N - front wall L', box(RX1, DX1, TW, FWY, TRENCH_FLOOR, RZ_CEIL, 'script_wall'));
  wadd('trench room N - front wall R', box(DX2, RX2, TW, FWY, TRENCH_FLOOR, RZ_CEIL, 'script_wall'));
  door('trench_lab', /*flag*/null,
    box(DX1, DX2, TW, FWY, TRENCH_FLOOR, RZ_CEIL, 'script_wall'),
    box(DX1 - 16, DX2 + 16, TW - 40, FWY, TRENCH_FLOOR, RZ_CEIL - 60, 'trigger'));
}

console.log(`  REMOVE south slab lines ${found.south.start + 1}-${found.south.end + 1}, north slab ${found.north.start + 1}-${found.north.end + 1}`);
console.log(`  INJECT ${wsAdd.length} worldspawn brushes + ${entAdd.length} door entities.`);
if (dry) { console.log('[rooms] --dry: nothing written.'); process.exit(0); }

for (let j = found.south.start; j <= found.south.end; j++) remove[j] = true;
for (let j = found.north.start; j <= found.north.end; j++) remove[j] = true;
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) { out.push('// ===== TRENCH ROOMS (add_trench_rooms.js) ====='); out.push(...wsAdd); out.push('// ===== end trench rooms ====='); }
  if (remove[i]) continue;
  out.push(lines[i]);
  if (i === wsClose) { out.push('// ===== TRENCH ROOM DOORS ====='); out.push(...entAdd); }
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[rooms] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
