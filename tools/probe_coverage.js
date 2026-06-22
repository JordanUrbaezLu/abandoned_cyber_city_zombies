#!/usr/bin/env node
// Find where the map has FLOOR but no CEILING (missing roofs - corridors, gaps). Parses each worldspawn
// brush as the intersection of axis-aligned PLANES (the correct .map reading; AABB-of-all-points fails on
// the filler-plane winding), classifies floor (script_floor_ceiling top z<=20) vs ceiling (z bottom>=200),
// then grid-samples: 'C'=floor+ceiling, 'X'=floor+NO ceiling (MISSING), '.'=no floor. Plaza stays open.
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
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

// Axis-aligned AABB from face planes: a face is an x/y/z plane if all 3 pts share that coord.
function aabb(b) {
  let xs = [], ys = [], zs = [];
  for (const f of b.faces) {
    if (f[0][0] === f[1][0] && f[1][0] === f[2][0]) xs.push(f[0][0]);
    if (f[0][1] === f[1][1] && f[1][1] === f[2][1]) ys.push(f[0][1]);
    if (f[0][2] === f[1][2] && f[1][2] === f[2][2]) zs.push(f[0][2]);
  }
  if (xs.length < 2 || ys.length < 2 || zs.length < 2) return null; // non-axis-aligned/angled -> skip
  return [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys), Math.min(...zs), Math.max(...zs)];
}

const floors = [], ceils = [];
for (const b of brushes) {
  if (b.mat !== 'script_floor_ceiling') continue;
  const a = aabb(b); if (!a) continue;
  if (a[5] <= 20 && a[4] >= -300) floors.push(a);        // top at/below ~floor level
  else if (a[4] >= 200) ceils.push(a);                    // bottom up high = a ceiling/roof
}

const inside = (a, x, y) => x >= a[0] && x <= a[1] && y >= a[2] && y <= a[3];
// Plaza stays open: exclude its room area from "missing".
const PLAZA = [-1100, 1110, -600, 760];

const CELL = 100;
const X0 = -2300, X1 = 2250, Y0 = 350, Y1 = 4300;
let outRows = [], missCells = [];
for (let y = Y1; y >= Y0; y -= CELL) {
  let row = '';
  for (let x = X0; x <= X1; x += CELL) {
    const cx = x + CELL / 2, cy = y - CELL / 2;
    const f = floors.some(a => inside(a, cx, cy));
    if (!f) { row += '.'; continue; }
    if (inside(PLAZA, cx, cy)) { row += 'p'; continue; } // plaza floor, intentionally open
    const c = ceils.some(a => inside(a, cx, cy));
    if (c) row += 'C'; else { row += 'X'; missCells.push([cx, cy]); }
  }
  outRows.push(`y${String(Math.round(y)).padStart(5)} ${row}`);
}
console.log(`brushes=${brushes.length} floors=${floors.length} ceils=${ceils.length}`);
console.log(`grid: x[${X0}..${X1}] step ${CELL}; legend C=roofed X=MISSING p=plaza(open) .=no floor\n`);
console.log(outRows.join('\n'));
console.log(`\nMISSING (floor, no roof) cells: ${missCells.length}`);
