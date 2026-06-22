#!/usr/bin/env node
// probe_floor_holes.js <map> - zoom into the market<->bus-station region and report floor coverage per
// cell, distinguishing a GENUINE HOLE (no floor at any z -> you fall to the skybox) from the intended
// TRENCH (floor only far below 0). Reuses probe_coverage.js's axis-aligned plane parse.
//   legend:  #=floor near 0 (normal)   t=floor only deep (trench/underground)   .=NO floor (HOLE)
'use strict';
const fs = require('fs');
const MAP = process.argv[2];
if (!MAP) { console.error('usage: probe_floor_holes.js <map>'); process.exit(1); }
const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let end = lines.findIndex(l => l.includes('// entity 1')); if (end < 0) end = lines.length;

const ptRe = /\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)/g;
const matRe = /\)\s*(script_\w+)\s/;
const brushes = [];
let depth = 0, cur = null;
for (let i = 0; i < end; i++) {
  const t = lines[i].trim();
  if (t === '{') { depth++; if (depth >= 2) cur = { faces: [], mat: null }; continue; }
  if (t === '}') { if (cur) brushes.push(cur); cur = null; if (depth > 0) depth--; continue; }
  if (!cur) continue;
  let m; ptRe.lastIndex = 0; const pts = [];
  while ((m = ptRe.exec(lines[i])) && pts.length < 3) pts.push([+m[1], +m[2], +m[3]]);
  if (pts.length === 3) cur.faces.push(pts);
  if (!cur.mat) { const mm = lines[i].match(matRe); if (mm) cur.mat = mm[1]; }
}
function aabb(b) {
  let xs = [], ys = [], zs = [];
  for (const f of b.faces) {
    if (f[0][0] === f[1][0] && f[1][0] === f[2][0]) xs.push(f[0][0]);
    if (f[0][1] === f[1][1] && f[1][1] === f[2][1]) ys.push(f[0][1]);
    if (f[0][2] === f[1][2] && f[1][2] === f[2][2]) zs.push(f[0][2]);
  }
  if (xs.length < 2 || ys.length < 2 || zs.length < 2) return null;
  return [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys), Math.min(...zs), Math.max(...zs)];
}
const floors = [];
for (const b of brushes) {
  if (b.mat !== 'script_floor_ceiling') continue;
  const a = aabb(b); if (!a) continue;
  if (a[5] <= 40) floors.push(a);   // a floor surface = top at/below ~floor level (incl. deep trench)
}
const inside = (a, x, y) => x >= a[0] && x <= a[1] && y >= a[2] && y <= a[3];

// market<->bus-station transition + bus-station body
const CELL = 80, X0 = -1500, X1 = 900, Y0 = 1100, Y1 = 2820;
let rows = [], holes = 0, normal = 0, trench = 0;
for (let y = Y1; y >= Y0; y -= CELL) {
  let row = '';
  for (let x = X0; x <= X1; x += CELL) {
    const cx = x + CELL / 2, cy = y - CELL / 2;
    const covering = floors.filter(a => inside(a, cx, cy));
    if (!covering.length) { row += '.'; holes++; continue; }
    const topZ = Math.max(...covering.map(a => a[5]));
    if (topZ >= -40) { row += '#'; normal++; } else { row += 't'; trench++; }
  }
  rows.push(`y${String(Math.round(y)).padStart(5)} ${row}`);
}
console.log(`${MAP.split(/[\\/]/).pop()}: floors=${floors.length}  x[${X0}..${X1}] step${CELL}  legend: #=floor~0  t=deep/trench  .=HOLE`);
console.log(rows.join('\n'));
console.log(`cells: normal=${normal} trench=${trench} HOLES=${holes}`);
