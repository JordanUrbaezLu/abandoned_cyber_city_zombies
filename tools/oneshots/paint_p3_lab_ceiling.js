#!/usr/bin/env node
// =============================================================================
// paint_p3_lab_ceiling.js  (ONE-SHOT, marker-guarded - refuses re-apply)
//
// *** SUPERSEDED 2026-07-19 (FIX BATCH 3): the user flagged the lab walls twice - the whole
// *** white/panel experiment (this one-shot AND the P2 lab wall paint) was REVERTED to the
// *** pre-sweep uniform t7_zm_der_tile_hexagon by tools/oneshots/revert_lab_hex_market_ceiling.js
// *** (per-face HEAD-token restore). Kept for history - do NOT re-run.
//
// P3 = LAB CONSISTENCY batch (2026-07-19, FIX BATCH 2 issue 5): the P2 batch
// painted the lab's 6 perimeter walls + 9 alcove fins t10_concrete_painted_01_
// white but left (a) the lab CEILING hex and (b) the lab_w door-corridor in the
// roof zone's wet-concrete palette -> "lab walls don't match the floor and
// ceiling anymore" (user). Face audit (scratch lab_faces.js over x[-960,980]
// y[3040,4260]): the ONLY non-white/non-hex wall-family faces in the lab region
// are the W-connector brushes; the E-connector is brushed stainless = the
// VAULT's deliberate threshold palette (kept - it reads as a vault airlock, not
// patchwork).
//
// CHOICE: ceiling -> t10_metal_aluminum_painted_01_panels (materialCategory
// "Geometry Plus", verified t10_materials.gdt:211963; the _grey derivative
// already converts for abyss L2, so the family is proven). WHY panels, not
// white: all-white walls+ceiling would blur the two planes into one; a paneled
// aluminum drop-ceiling is the clinical-lab read and keeps three distinct
// surfaces - white walls / panel ceiling / deliberate hex floor - one system.
//
// SWAPS (24 face tokens, signature-exact: brush located by axis-plane AABB +
// uniform current token, worldspawn-only, assert exactly 1 match each):
//   1. lab ceiling      x[-781,819]   y[3048,4248] z[256,272]  hex        -> panels (6)
//   2. W-conn S wall    x[-1119,-781] y[3100,3120] z[0,256]    poured_wet -> white  (6)
//   3. W-conn N wall    x[-1119,-781] y[3336,3356] z[0,256]    poured_wet -> white  (6)
//   4. W-conn ceiling   x[-1119,-781] y[3100,3460] z[256,272]  poured_wet -> panels (6)
// Floors untouched (lab hex + connector asphalt = deliberate). NO decal-
// category tokens (docs/20 corrected verdict - Decal has no collision).
//
// Usage: node tools/oneshots/paint_p3_lab_ceiling.js map_source/zm/zm_abandoned_cyber_city.map
// =============================================================================
'use strict';
const fs = require('fs');
const MARKER = '// === ACC P3 LAB CEILING PAINT (paint_p3_lab_ceiling.js) applied 2026-07-19 ===';
const mapPath = process.argv[2];
if (!mapPath) { console.error('usage: paint_p3_lab_ceiling.js <map>'); process.exit(1); }
let src = fs.readFileSync(mapPath, 'utf8');
if (src.includes('ACC P3 LAB CEILING PAINT')) { console.error('REFUSED: P3 paint marker already present (one-shot).'); process.exit(2); }
const beforeBytes = Buffer.byteLength(src);

const TARGETS = [
  { name: 'lab ceiling', box: [[-781, 819], [3048, 4248], [256, 272]], from: 't7_zm_der_tile_hexagon', to: 't10_metal_aluminum_painted_01_panels' },
  { name: 'W-conn S wall', box: [[-1119, -781], [3100, 3120], [0, 256]], from: 't7_concrete_wall_poured_thick_01_wet', to: 't10_concrete_painted_01_white' },
  { name: 'W-conn N wall', box: [[-1119, -781], [3336, 3356], [0, 256]], from: 't7_concrete_wall_poured_thick_01_wet', to: 't10_concrete_painted_01_white' },
  { name: 'W-conn ceiling', box: [[-1119, -781], [3100, 3460], [256, 272]], from: 't7_concrete_wall_poured_thick_01_wet', to: 't10_metal_aluminum_painted_01_panels' },
];

// parse worldspawn (entity 0) brushes: line spans + axis-plane AABB + face lines/tokens
const lines = src.split('\n');
let depth = 0, worldDone = false, cur = null;
const brushes = [];
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') {
    depth++;
    if (depth === 2 && !worldDone) cur = { faces: [], mins: [-Infinity, -Infinity, -Infinity], maxs: [Infinity, Infinity, Infinity], patch: false };
    continue;
  }
  if (t === '}') {
    if (depth === 2 && cur) { if (!cur.patch && cur.faces.length >= 4) brushes.push(cur); cur = null; }
    depth--;
    if (depth === 0) worldDone = true;
    continue;
  }
  if (worldDone) break;
  if (depth >= 2 && cur) {
    if (depth > 2) { cur.patch = true; continue; }
    const m = t.match(/^\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)\s*(\S+)/);
    if (!m) { if (/^(mesh|curve)/.test(t)) cur.patch = true; continue; }
    const p1 = [+m[1], +m[2], +m[3]], p2 = [+m[4], +m[5], +m[6]], p3 = [+m[7], +m[8], +m[9]];
    const v1 = [p2[0] - p1[0], p2[1] - p1[1], p2[2] - p1[2]];
    const v2 = [p3[0] - p1[0], p3[1] - p1[1], p3[2] - p1[2]];
    const n = [v2[1] * v1[2] - v2[2] * v1[1], v2[2] * v1[0] - v2[0] * v1[2], v2[0] * v1[1] - v2[1] * v1[0]];
    const len = Math.hypot(n[0], n[1], n[2]);
    if (len > 1e-6) {
      const un = n.map(c => c / len);
      for (let a = 0; a < 3; a++) {
        if (un[a] > 0.999) cur.maxs[a] = Math.min(cur.maxs[a], un[0] * p1[0] + un[1] * p1[1] + un[2] * p1[2]);
        else if (un[a] < -0.999) cur.mins[a] = Math.max(cur.mins[a], -(un[0] * p1[0] + un[1] * p1[1] + un[2] * p1[2]));
      }
    }
    cur.faces.push({ line: i, tok: m[10] });
  }
}

let totalSwaps = 0;
for (const tgt of TARGETS) {
  const eq = (a, b) => Math.abs(a - b) < 0.51;
  const hits = brushes.filter(b =>
    eq(b.mins[0], tgt.box[0][0]) && eq(b.maxs[0], tgt.box[0][1]) &&
    eq(b.mins[1], tgt.box[1][0]) && eq(b.maxs[1], tgt.box[1][1]) &&
    eq(b.mins[2], tgt.box[2][0]) && eq(b.maxs[2], tgt.box[2][1]) &&
    b.faces.every(f => f.tok === tgt.from));
  if (hits.length !== 1) { console.error(`ABORT: '${tgt.name}' signature matched ${hits.length} brushes (need exactly 1). Nothing written.`); process.exit(3); }
  for (const f of hits[0].faces) {
    const before = lines[f.line];
    // token is a standalone word after the 3rd ')' - replace exactly one occurrence
    const after = before.replace(new RegExp(`(\\)\\s*)${tgt.from}(\\s)`), `$1${tgt.to}$2`);
    if (after === before) { console.error(`ABORT: token replace failed on line ${f.line + 1} ('${tgt.name}').`); process.exit(3); }
    lines[f.line] = after;
    totalSwaps++;
  }
  console.log(`  ${tgt.name}: 6 faces ${tgt.from} -> ${tgt.to}`);
}
if (totalSwaps !== 24) { console.error(`ABORT: expected exactly 24 swaps, computed ${totalSwaps}. Nothing written.`); process.exit(3); }

// marker: as a // comment right after the "// entity 0" line (NEVER inside the iwmap
// layer-def header - a stray line there breaks the Radiant parser; learned 2026-07-19)
const entIdx = lines.findIndex(l => l.trim() === '// entity 0');
lines.splice(entIdx >= 0 ? entIdx + 1 : lines.findIndex(l => l.trim() === '{'), 0, MARKER);
const out = lines.join('\n');
fs.writeFileSync(mapPath, out);
console.log(`OK: 24 face tokens swapped + marker. bytes ${beforeBytes} -> ${Buffer.byteLength(out)}`);
