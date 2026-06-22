#!/usr/bin/env node
// =============================================================================
// pack_lightmap_uvs.js - headless lightmap-UV packer for BO3 .map files.
//
// ⚠️ INERT FOR THE LED BAKE (tested 2026-06-18): this tool correctly rewrites the
// per-face lightmap offsets, BUT Radiant's lightmapper RE-DERIVES its own atlas from
// geometry/materials and IGNORES the .map offsets - so the LED bake still crashes
// `brush.cpp:1860` on the packed map (verified: cod2map clean, LED unchanged .led).
// Kept for reference only. Do NOT re-run expecting it to fix the bake. The dark look
// is delivered LED-free (vision grade + emissive prop models). See memory
// led-relight-dead-end-enclosed-geometry + docs/40.
//
// WHY (root cause, confirmed 2026-06-18): our greybox .map is script-generated and
// emits `lightmap_gray 16384 16384 0 0 0 0` (the unpacked placeholder) on EVERY lit
// face. That dumps ~940 wall/floor lightmap charts on the SAME atlas offset (0,0).
// Radiant's LED bake (and even GUI map-load) tries to pack the colliding charts into
// the lightmap atlas, the D3D CreateTexture allocation overflows, and it asserts
// `radiant\brush.cpp:1860 (Result == S_OK)` (then a cascade of Gfx::* "outstanding
// allocations"). Proof: the shipped map zm_alien_isolation bakes 6733 faces fine -
// its LIT surfaces all have UNIQUE packed UVs; only clip/tool faces sit at 0,0.
//
// FIX: give each LIT face (script_wall / script_floor_ceiling) a UNIQUE, non-colliding
// lightmap offset so the atlas packer succeeds. Non-lit faces (clip/trigger/volume/sky)
// are left untouched at 0,0 - they need no lightmap (matches the shipped map). Scale
// stays 16384 (the proven-good default - cod2map's own seed; lowering it crashes).
// Multi-"page" virtual atlas is fine: the lightmapper repacks (shipped offsets reach
// 26M). We only need the per-face offsets to be DISTINCT and non-overlapping.
//
// Usage:  node tools/pack_lightmap_uvs.js <in.map> <out.map>
// Safe:   only rewrites the 2 lightmap OFFSET numbers on lit faces; every other byte
//         (geometry, materials, tex coords, non-lit faces, entities) is preserved.
// =============================================================================

const fs = require('fs');

// Lit greybox materials that NEED a packed lightmap chart. Everything else
// (clip/trigger/volume/sky/caulk/tool) keeps the 0,0 placeholder = non-lit.
const LIT_MATERIALS = new Set(['script_wall', 'script_floor_ceiling']);

const CELL = 4096;   // world-unit grid spacing between charts (>= largest greybox face)
const COLS = 64;     // charts per virtual-atlas row before wrapping to the next row

// Face line: ( x y z ) ( x y z ) ( x y z ) <mat> <6 tex nums> lightmap_<x> <6 lm nums>
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp(
  '^(\\s*)' +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s*` +
  `\\(\\s*${N}\\s+${N}\\s+${N}\\s*\\)\\s+` +
  '(\\S+)\\s+' +                                   // material
  `${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s+` + // tex 6
  '(lightmap_\\S+)\\s+' +
  `${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s*$`  // lm 6
);

const [, , inPath, outPath] = process.argv;
if (!inPath || !outPath) {
  console.error('usage: node pack_lightmap_uvs.js <in.map> <out.map>');
  process.exit(1);
}

const lines = fs.readFileSync(inPath, 'utf8').split('\n');

// --- Pass 1: parse faces, grouping contiguous face lines into brushes (for bbox) ---
const faces = [];
let cur = null; // current brush
const newBrush = () => ({ faces: [], min: [1e9, 1e9, 1e9], max: [-1e9, -1e9, -1e9] });

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) { cur = null; continue; }              // non-face line closes the brush run
  if (!cur) cur = newBrush();
  const pts = [
    [+m[2], +m[3], +m[4]],
    [+m[5], +m[6], +m[7]],
    [+m[8], +m[9], +m[10]],
  ];
  for (const p of pts) for (let a = 0; a < 3; a++) {
    if (p[a] < cur.min[a]) cur.min[a] = p[a];
    if (p[a] > cur.max[a]) cur.max[a] = p[a];
  }
  const f = { lineIdx: i, mat: m[11], pts, brush: cur };
  cur.faces.push(f);
  faces.push(f);
}

// --- geometry helpers ---
const sub = (a, b) => [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
const cross = (a, b) => [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]];
const dominant = (n) => {
  const a = n.map(Math.abs);
  return a[0] >= a[1] && a[0] >= a[2] ? 0 : (a[1] >= a[2] ? 1 : 2);
};

// --- Pass 2: assign each LIT face a unique grid cell offset ---
const lit = faces.filter((f) => LIT_MATERIALS.has(f.mat));
lit.forEach((f, k) => {
  const n = cross(sub(f.pts[1], f.pts[0]), sub(f.pts[2], f.pts[0]));
  const na = dominant(n);                          // face-normal axis
  const ax = [0, 1, 2].filter((a) => a !== na);    // the two in-plane axes
  const b = f.brush || { min: [Math.min(...f.pts.map(p => p[ax[0]]))], max: [] };
  const minA = (f.brush ? f.brush.min : f.pts.reduce((mn, p) => Math.min(mn, p[ax[0]]), 1e9))[ax[0]] ?? f.pts[0][ax[0]];
  const minB = (f.brush ? f.brush.min : f.pts.reduce((mn, p) => Math.min(mn, p[ax[1]]), 1e9))[ax[1]] ?? f.pts[0][ax[1]];
  const gx = (k % COLS) * CELL;
  const gy = Math.floor(k / COLS) * CELL;
  // offset so the face's world span maps to its own unique cell: uv=(P+offset)/16384.
  f.offU = gx - minA;
  f.offV = gy - minB;
});

// --- Pass 3: rewrite ONLY the lightmap offset pair on lit faces ---
const fmt = (v) => (Number.isInteger(v) ? String(v) : String(Math.round(v * 1000) / 1000));
const LM_TAIL = new RegExp(`(lightmap_\\S+)\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s+${N}\\s*$`);
for (const f of lit) {
  lines[f.lineIdx] = lines[f.lineIdx].replace(
    LM_TAIL,
    (_, lm, sU, sV, _oU, _oV, rot, flag) => `${lm} ${sU} ${sV} ${fmt(f.offU)} ${fmt(f.offV)} ${rot} ${flag}`
  );
}

fs.writeFileSync(outPath, lines.join('\n'));

// --- report ---
const hist = {};
for (const f of faces) hist[f.mat] = (hist[f.mat] || 0) + 1;
const rows = Math.ceil(lit.length / COLS);
console.log(`[pack] total faces parsed : ${faces.length}`);
console.log(`[pack] LIT faces packed   : ${lit.length}  (${[...LIT_MATERIALS].join(', ')})`);
console.log(`[pack] non-lit untouched  : ${faces.length - lit.length}`);
console.log(`[pack] virtual atlas grid : ${COLS} cols x ${rows} rows @ ${CELL}u  (max offset ~${(COLS - 1) * CELL} x ${(rows - 1) * CELL})`);
console.log(`[pack] wrote: ${outPath}`);
console.log(`[pack] top materials: ${Object.entries(hist).sort((a, b) => b[1] - a[1]).slice(0, 8).map(([k, v]) => `${k}:${v}`).join('  ')}`);
