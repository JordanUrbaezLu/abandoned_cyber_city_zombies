#!/usr/bin/env node
// =============================================================================
// clean_plane_points.js - rewrite far-out brush-face PLANE-DEFINITION points to
// sane coordinates WITHOUT changing the plane (so geometry/volume is identical).
//
// WHY: our generator emitted faces whose 3 plane points sit ~100,000-126,000 units
// away (sky brushes, sun_volume). The brush volumes are fine (planes intersect to a
// normal box), but Radiant's lightmapper appears to size sun-shadow frustums / the
// lighting grid from the BOUNDING BOX of the raw points (~250k units) -> a giant D3D
// allocation -> brush.cpp:1860 crash on map LOAD/bake (the GfxFrustumRegister /
// LightingStateInst cascade). cod2map is unaffected. Cleaning the points to lie near
// the origin (same plane, same normal/winding) removes the giant bbox.
//
// SAFE: only faces with |coord| > THRESH are touched; the plane equation is preserved
// (new points are exact points on the same plane), so the convex brush is unchanged.
// Usage: node tools/clean_plane_points.js <in.map> <out.map>
// =============================================================================
const fs = require('fs');
const THRESH = 8000;     // map is ~4000u; anything beyond this is a far-out plane point
const SPAN = 2048;       // how far apart to place the 3 clean points on the plane

const Nx = '(-?[\\d.]+)';
const FACE_RE = new RegExp(
  '^(\\s*)' +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s*` +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s*` +
  `\\(\\s*${Nx}\\s+${Nx}\\s+${Nx}\\s*\\)\\s+` +
  '(.*)$'
);
const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) { console.error('usage: node clean_plane_points.js <in.map> <out.map>'); process.exit(1); }

const sub = (a, b) => [a[0]-b[0], a[1]-b[1], a[2]-b[2]];
const add = (a, b) => [a[0]+b[0], a[1]+b[1], a[2]+b[2]];
const mul = (a, s) => [a[0]*s, a[1]*s, a[2]*s];
const cross = (a, b) => [a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0]];
const dot = (a, b) => a[0]*b[0]+a[1]*b[1]+a[2]*b[2];
const norm = (a) => { const l = Math.hypot(...a) || 1; return [a[0]/l, a[1]/l, a[2]/l]; };
const fmt = (v) => { const r = Math.round(v * 100) / 100; return Number.isInteger(r) ? String(r) : String(r); };
const pt = (p) => `( ${fmt(p[0])} ${fmt(p[1])} ${fmt(p[2])} )`;

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
let cleaned = 0;
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) continue;
  const p1 = [+m[2], +m[3], +m[4]], p2 = [+m[5], +m[6], +m[7]], p3 = [+m[8], +m[9], +m[10]];
  const all = [...p1, ...p2, ...p3];
  if (!all.some((c) => Math.abs(c) > THRESH)) continue;   // already sane

  // plane from original points (normal + d); keep the exact normal for winding
  const n0 = cross(sub(p2, p1), sub(p3, p1));
  const nlen = Math.hypot(...n0);
  if (nlen < 1e-9) continue;                              // degenerate (shouldn't happen)
  const n = norm(n0);
  const d = dot(n, p1);                                   // plane: n . x = d

  // P0 = closest point on plane to origin; two in-plane basis vectors
  const P0 = mul(n, d);
  let ref = Math.abs(n[2]) < 0.9 ? [0, 0, 1] : [1, 0, 0];
  const u = norm(cross(n, ref));
  const v = norm(cross(n, u));

  // 3 clean points on the plane; order to preserve the original normal direction
  let A = P0, B = add(P0, mul(u, SPAN)), C = add(P0, mul(v, SPAN));
  if (dot(cross(sub(B, A), sub(C, A)), n0) < 0) { const t = B; B = C; C = t; }

  lines[i] = `${m[1]}${pt(A)} ${pt(B)} ${pt(C)} ${m[11]}`;
  cleaned++;
}
fs.writeFileSync(outPath, lines.join('\n'));
console.log(`[clean] faces with extreme plane points rewritten: ${cleaned}`);
console.log(`[clean] wrote: ${outPath}`);
