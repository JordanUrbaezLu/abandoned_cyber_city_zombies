#!/usr/bin/env node
// remove_obstacles.js - delete the freestanding training OBSTACLES from the map,
// leaving walls / floors / functional structs / entities untouched.
//
// Signal (robust, position-independent): the greybox generator makes WALLS exactly
// WALL_H=256 tall; every obstacle (debris pile / fountain / S-curves / market stalls /
// roof obstacle, gen_zone_greybox.js:130-137) is SHORT (<=128) and sits on the floor
// (z-min 0). Obstacles are WORLDSPAWN brushes; functional structs (PaP blockers, doors)
// are separate script_brushmodel ENTITIES, so we only touch worldspawn (entity 0).
// => remove worldspawn `script_wall` box brushes with z-min ~0 and z-max < 250.
//
// Usage:
//   node tools/remove_obstacles.js <in.map> --dry      # report only, write nothing
//   node tools/remove_obstacles.js <in.map> <out.map>  # remove + write
const fs = require('fs');
const [, , inPath, arg2] = process.argv;
if (!inPath || !arg2) { console.error('usage: remove_obstacles.js <in> <out|--dry>'); process.exit(1); }
const dry = (arg2 === '--dry');
const outPath = dry ? null : arg2;
const ZMAX_WALL = 250;   // a worldspawn script_wall taller than this is a real wall (keep)

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp(
  '^\\s*' +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s+(\\S+)`
);

function boundsOf(faces) {
  if (faces.length !== 6) return null;
  const A = [[], [], []];
  for (const [p1, p2, p3] of faces) {
    const u = [p2[0]-p1[0], p2[1]-p1[1], p2[2]-p1[2]];
    const v = [p3[0]-p1[0], p3[1]-p1[1], p3[2]-p1[2]];
    const n = [u[1]*v[2]-u[2]*v[1], u[2]*v[0]-u[0]*v[2], u[0]*v[1]-u[1]*v[0]];
    const a = n.map(Math.abs); const mx = Math.max(...a); if (mx < 1e-6) return null;
    const ax = a.indexOf(mx);
    if (a[(ax+1)%3] + a[(ax+2)%3] > mx * 1e-4) return null;
    A[ax].push(p1[ax]);
  }
  if (A.some((g) => g.length !== 2)) return null;
  return [Math.min(...A[0]), Math.max(...A[0]), Math.min(...A[1]), Math.max(...A[1]), Math.min(...A[2]), Math.max(...A[2])];
}

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = [];
let depth = 0, entityIdx = -1;
let removed = 0, keptWalls = 0;
const r2 = (v) => Math.round(v * 10) / 10;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length;
  const closes = (lines[i].match(/}/g) || []).length;
  if (depth === 0 && opens > 0) entityIdx++;             // entering a top-level entity
  for (let o = 0; o < opens; o++) stack.push({ start: i, faces: [], mat: null, ent: entityIdx });
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) {
    const t = stack[stack.length-1];
    t.faces.push([[+m[1],+m[2],+m[3]], [+m[4],+m[5],+m[6]], [+m[7],+m[8],+m[9]]]);
    if (!t.mat) t.mat = m[10];
  }
  depth += opens - closes;
  for (let c = 0; c < closes; c++) {
    const blk = stack.pop();
    if (!blk || blk.faces.length !== 6 || blk.mat !== 'script_wall') continue;
    const b = boundsOf(blk.faces);
    if (!b) continue;
    if (blk.ent !== 0) continue;
    const zmin = b[4], zmax = b[5], dx = b[1]-b[0], dy = b[3]-b[2];
    const isShort = (zmin > -2 && zmin < 2 && zmax < ZMAX_WALL);   // floor-standing low obstacle
    const isBlocky = Math.min(dx, dy) > 40;                        // not a thin (20u) wall => freestanding block/pillar/slab
    if (isShort || isBlocky) {
      console.log(`  REMOVE ${isBlocky ? 'block ' : 'obstacle'}: ${r2(dx)}x${r2(dy)} h=${r2(zmax-zmin)}  x[${r2(b[0])},${r2(b[1])}] y[${r2(b[2])},${r2(b[3])}] z[${r2(zmin)},${r2(zmax)}]`);
      for (let j = blk.start; j <= i; j++) remove[j] = true;
      removed++;
    } else {
      keptWalls++;
    }
  }
}
console.log(`\n[obstacles] would remove ${removed} short worldspawn script_wall obstacle(s); keep ${keptWalls} full-height wall(s).`);
if (!dry) {
  const out = lines.filter((_, i) => !remove[i]);
  fs.writeFileSync(outPath, out.join('\n'));
  console.log(`[obstacles] lines ${lines.length} -> ${out.length}; wrote ${outPath}`);
} else {
  console.log('[obstacles] --dry: nothing written.');
}
