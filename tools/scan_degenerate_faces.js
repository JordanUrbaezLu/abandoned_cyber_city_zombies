#!/usr/bin/env node
// scan_degenerate_faces.js - find faces that make Radiant's lightmapper compute a
// NaN/Inf lightmap UV (the Reddit brush.cpp:1860 cause, but COMPUTED not text):
//   - collinear/coincident plane points  -> zero normal -> NaN when normalized
//   - non-finite or absurd param values
//   - zero-area / sliver windings
// Usage: node tools/scan_degenerate_faces.js <map>
const fs = require('fs');
const N = '(-?[\\d.]+|-?\\d*\\.#[A-Z]+\\d*|-?[Ii]nf|-?[Nn]a[Nn])';
const FACE_RE = new RegExp(
  '^\\s*' +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s+` +
  '(\\S+)\\s+(.*)$'
);
const p = process.argv[2];
if (!p) { console.error('usage: node scan_degenerate_faces.js <map>'); process.exit(1); }
const lines = fs.readFileSync(p, 'utf8').split('\n');
const num = (s) => { const v = parseFloat(s); return v; };
const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const len = (v) => Math.hypot(v[0], v[1], v[2]);

let total = 0, bad = 0;
const flag = (i, why, mat, line) => { bad++; console.log(`  L${i+1}  [${why}]  mat=${mat}\n      ${line.trim().slice(0, 160)}`); };

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) continue;
  total++;
  const raw = [m[1],m[2],m[3], m[4],m[5],m[6], m[7],m[8],m[9]];
  // non-finite text in the plane points?
  if (raw.some((t) => /#|inf|nan/i.test(t))) { flag(i, 'NaN/Inf TEXT in plane pts', m[10], lines[i]); continue; }
  const pts = [[num(m[1]),num(m[2]),num(m[3])], [num(m[4]),num(m[5]),num(m[6])], [num(m[7]),num(m[8]),num(m[9])]];
  // params after material may carry NaN/Inf text
  if (/#|[^a-z](inf|nan|ind)/i.test(m[12] || '')) { flag(i, 'NaN/Inf TEXT in tex/lm params', m[10], lines[i]); continue; }
  // coincident points
  const eq = (a, b) => a[0]===b[0] && a[1]===b[1] && a[2]===b[2];
  if (eq(pts[0],pts[1]) || eq(pts[1],pts[2]) || eq(pts[0],pts[2])) { flag(i, 'COINCIDENT plane points', m[10], lines[i]); continue; }
  // collinear (zero normal) -> NaN normal
  const n = cross(sub(pts[1],pts[0]), sub(pts[2],pts[0]));
  const nl = len(n);
  if (!isFinite(nl) || nl < 1e-6) { flag(i, `DEGENERATE (|normal|=${nl.toExponential(2)})`, m[10], lines[i]); continue; }
  // extreme plane-definition coordinate (map is ~4000u; >8000 = a far-out plane point,
  // the sun_volume-class issue that can blow up Radiant's bbox-derived lighting grid)
  if (pts.some((q) => q.some((c) => !isFinite(c) || Math.abs(c) > 8000))) { flag(i, `EXTREME plane coord (max ${Math.max(...pts.flat().map(Math.abs)).toFixed(0)})`, m[10], lines[i]); continue; }
}
console.log(`\n[scan] ${p}`);
console.log(`[scan] faces parsed: ${total}   SUSPECT faces: ${bad}`);
if (bad === 0) console.log('[scan] no degenerate / NaN-producing faces found.');
