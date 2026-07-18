#!/usr/bin/env node
// remove_walls_in_region.js - delete worldspawn script_wall box brushes whose
// CENTER falls inside an XY region. Use to clear FREESTANDING INTERIOR walls
// (thin + full-height, so remove_obstacles' shape rules can't tell them from a
// perimeter wall) by giving an interior region that excludes the room's edges.
// Floors/entities (perks/boxes/doors/PaP brushmodels) are untouched (worldspawn
// script_wall only). REUSABLE per-zone: pass that zone's interior box.
//
// Usage:
//   node tools/remove_walls_in_region.js <in.map> --dry  <x1> <y1> <x2> <y2>
//   node tools/remove_walls_in_region.js <in.map> <out>  <x1> <y1> <x2> <y2>
const fs = require('fs');
const [, , inPath, arg2, X1, Y1, X2, Y2] = process.argv;
if (!inPath || !arg2 || X2 === undefined) { console.error('usage: remove_walls_in_region.js <in> <out|--dry> <x1> <y1> <x2> <y2>'); process.exit(1); }
const dry = (arg2 === '--dry');
const rx1 = Math.min(+X1, +X2), rx2 = Math.max(+X1, +X2), ry1 = Math.min(+Y1, +Y2), ry2 = Math.max(+Y1, +Y2);
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(g=>g.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, removed = 0, kept = 0;
const r2 = (v) => Math.round(v * 10) / 10;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  if (depth === 0 && opens > 0) entityIdx++;
  for (let o = 0; o < opens; o++) stack.push({ start: i, faces: [], mat: null, ent: entityIdx });
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length-1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  depth += opens - closes;
  for (let c = 0; c < closes; c++) {
    const blk = stack.pop();
    if (!blk || blk.ent !== 0 || blk.mat !== 'script_wall' || blk.faces.length !== 6) continue;
    const b = boundsOf(blk.faces); if (!b) continue;
    const cx = (b[0]+b[1])/2, cy = (b[2]+b[3])/2;
    if (cx >= rx1 && cx <= rx2 && cy >= ry1 && cy <= ry2) {
      console.log(`  REMOVE wall: ${r2(b[1]-b[0])}x${r2(b[3]-b[2])} center(${r2(cx)},${r2(cy)})  x[${r2(b[0])},${r2(b[1])}] y[${r2(b[2])},${r2(b[3])}] z[${r2(b[4])},${r2(b[5])}]`);
      for (let j = blk.start; j <= i; j++) remove[j] = true; removed++;
    } else kept++;
  }
}
console.log(`\n[region] would remove ${removed} worldspawn script_wall(s) centered in x[${rx1},${rx2}] y[${ry1},${ry2}]; keep ${kept} other wall(s).`);
if (!dry) { const out = lines.filter((_, i) => !remove[i]); fs.writeFileSync(arg2, out.join('\n')); console.log(`[region] lines ${lines.length} -> ${out.length}; wrote ${arg2}`); }
else console.log('[region] --dry: nothing written.');
