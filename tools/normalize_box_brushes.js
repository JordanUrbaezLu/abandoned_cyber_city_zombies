#!/usr/bin/env node
// =============================================================================
// normalize_box_brushes.js - repair the generator's malformed axis-aligned box
// brushes that crash the Radiant LED bake.
//
// THE BUG (found 2026-06-18 by snapshot bisection): tightening-overhaul brushes
// (ACCADDS cover + their regenerated descendants) have TOP/BOTTOM faces whose
// plane-definition points are leftover TEMPLATE coordinates far from the brush's
// real location, with inverted winding. cod2map tolerates it; Radiant's lightmapper
// asserts brush.cpp:1860. coord-cleaning missed it (offsets only ~600u, under 8000).
//
// THE FIX: for every brush that is a closed AXIS-ALIGNED box (exactly 6 faces, each
// with an axis-aligned normal, 2 per axis), recompute the 6 plane-constants -> bbox,
// and re-emit 6 CLEAN canonical faces with correct outward winding, preserving each
// face's material/tex/lightmap params by (axis, min/max) position. Planes (hence BSP
// collision + brush volume) are IDENTICAL; only the point coordinates + winding change.
// Non-axis-aligned / non-6-face brushes are passed through untouched.
//
// Usage: node tools/normalize_box_brushes.js <in.map> <out.map>
// =============================================================================
const fs = require('fs');
const Nx = '(-?[\\d.]+)';
const FACE_RE = new RegExp(
  '^(\\s*)' +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s*` +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s*` +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s+` +
  '(.*)$'
);
const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) { console.error('usage: normalize_box_brushes.js <in> <out>'); process.exit(1); }

const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const fmt = (v) => { const r = Math.round(v*100)/100; return String(r); };
const P = (p) => `( ${fmt(p[0])} ${fmt(p[1])} ${fmt(p[2])} )`;

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
// group contiguous face lines into brushes
const brushes = []; // {start, faces:[{idx, indent, pts, tail}]}
let cur = null;
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) { if (cur) { brushes.push(cur); cur = null; } continue; }
  if (!cur) cur = { faces: [] };
  cur.faces.push({ idx: i, indent: m[1], pts: [[+m[2],+m[3],+m[4]],[+m[5],+m[6],+m[7]],[+m[8],+m[9],+m[10]]], tail: m[11] });
}
if (cur) brushes.push(cur);

let fixed = 0, anomalous = 0;
for (const b of brushes) {
  if (b.faces.length !== 6) continue;
  // each face must be axis-aligned; record axis(0/1/2), const value, params
  const info = [];
  let ok = true;
  for (const f of b.faces) {
    const n = cross(sub(f.pts[1], f.pts[0]), sub(f.pts[2], f.pts[0]));
    const a = [Math.abs(n[0]), Math.abs(n[1]), Math.abs(n[2])];
    const mx = Math.max(...a);
    if (mx < 1e-6) { ok = false; break; }
    const axis = a.indexOf(mx);
    // axis-aligned if the other two components are ~0 relative to the dominant
    if ((a[(axis+1)%3] + a[(axis+2)%3]) > mx * 1e-4) { ok = false; break; }
    info.push({ axis, val: f.pts[0][axis], tail: f.tail, indent: f.indent });
  }
  if (!ok) continue;
  // must be 2 faces per axis with 2 distinct constants
  const byAxis = [[], [], []];
  for (const it of info) byAxis[it.axis].push(it);
  if (byAxis.some((g) => g.length !== 2)) continue;
  const bnd = byAxis.map((g) => g.map((x) => x.val).sort((p, q) => p - q));
  if (bnd.some((g) => Math.abs(g[0] - g[1]) < 1e-4)) continue; // zero-thickness: skip
  // anomaly check: any face point off its own plane's bbox, OR a point outside bbox
  let anom = false;
  for (const f of b.faces) {
    for (const p of f.pts) {
      for (let a = 0; a < 3; a++) {
        if (p[a] < bnd[a][0] - 1e-3 || p[a] > bnd[a][1] + 1e-3) { anom = true; }
      }
    }
  }
  if (anom) anomalous++;
  // params per (axis,min/max): the face whose const == that bound
  const paramFor = (axis, which) => {
    const g = byAxis[axis];
    const lo = Math.min(g[0].val, g[1].val), hi = Math.max(g[0].val, g[1].val);
    const target = which === 'min' ? lo : hi;
    const f = g.find((x) => Math.abs(x.val - target) < 1e-4) || g[0];
    return { tail: f.tail, indent: f.indent };
  };
  const [x0, x1] = bnd[0], [y0, y1] = bnd[1], [z0, z1] = bnd[2];
  // canonical box faces, OUTWARD normals (CoD interior = positive side / standard winding)
  const faces = [
    { which: ['z', 'max'], pts: [[x0,y0,z1],[x1,y0,z1],[x1,y1,z1]] },   // +z top
    { which: ['z', 'min'], pts: [[x0,y1,z0],[x1,y1,z0],[x1,y0,z0]] },   // -z bottom
    { which: ['y', 'max'], pts: [[x0,y1,z1],[x0,y1,z0],[x1,y1,z0]] },   // +y
    { which: ['y', 'min'], pts: [[x1,y0,z1],[x1,y0,z0],[x0,y0,z0]] },   // -y
    { which: ['x', 'max'], pts: [[x1,y1,z1],[x1,y1,z0],[x1,y0,z0]] },   // +x
    { which: ['x', 'min'], pts: [[x0,y0,z1],[x0,y0,z0],[x0,y1,z0]] },   // -x
  ];
  const axisIdx = { x: 0, y: 1, z: 2 };
  b.faces.forEach((f, k) => {
    const nf = faces[k];
    const pr = paramFor(axisIdx[nf.which[0]], nf.which[1]);
    lines[f.idx] = `${pr.indent}${P(nf.pts[0])} ${P(nf.pts[1])} ${P(nf.pts[2])} ${pr.tail}`;
  });
  fixed++;
}
fs.writeFileSync(outPath, lines.join('\n'));
console.log(`[normalize] box brushes re-emitted clean: ${fixed}  (of which ${anomalous} had off-bbox / malformed points)`);
console.log(`[normalize] wrote ${outPath}`);
