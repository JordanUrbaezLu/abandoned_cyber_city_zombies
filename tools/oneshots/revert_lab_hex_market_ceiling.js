#!/usr/bin/env node
// revert_lab_hex_market_ceiling.js - FIX BATCH 3 texture coherence one-shot (2026-07-19).
//
// (1) LAB REVERT TO PRE-SWEEP (user flagged the lab walls twice: the room must read as ONE
//     hex system with its floor). Every face the P2/P3 sweep painted in the lab super-region
//     (lab interior + BOTH connector corridors, x[-1150,1150] y[3040,4470]) whose CURRENT
//     token is one of the sweep tokens (t10_concrete_painted_01_white /
//     t10_metal_aluminum_painted_01_panels) is restored to its EXACT HEAD token, matched
//     per-face by BRUSH AABB + face plane (normal axis + offset) - the sweep swapped tokens
//     only, so the brush geometry is identical to HEAD. (Plane-point TEXT is NOT unique - the
//     greybox generators reuse template points - so the earlier text-signature idea fails.)
//     Result: lab walls+ceiling+fins -> hex again;
//     lab_w corridor -> its HEAD poured-concrete grey; lab_e corridor untouched (HEAD
//     stainless, never painted). The ACCC0016/0017 emissive strips are separate chalk meshes
//     (mwiii_* materials) - KEPT (accents on hex are fine).
//     Supersedes: tools/oneshots/paint_p3_lab_ceiling.js (marked in its header).
// (2) MARKET CEILING HARMONIZE (map-wide zone-coherence audit): P1 left the 3 market ceiling
//     slabs rust-brown metal over the new brick walls + linoleum floor = the odd-one-out.
//     The slab UNDERSIDE faces (down-normal, slab bottom z>=200) go t7_metal_paint_rust_brown
//     -> t10_ceiling_tile_01_dirty (the Bus Station ceiling family - same t10 interior set,
//     already in the fastfile, zero new xpak; Geometry class, NEVER Decal).
//
// Marker-guarded one-shot: refuses to run twice. Token swaps ONLY - the byte diff is
// exactly N face-line token substitutions + the marker comment line.
'use strict';
const fs = require('fs');
const cp = require('child_process');
const path = require('path');

const REPO = path.join(__dirname, '..', '..');
const MAP = path.join(REPO, 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const MARKER = '// ACC-ONESHOT revert_lab_hex_market_ceiling 2026-07-19 (lab -> HEAD hex; market ceil -> tile)';

const cur = fs.readFileSync(MAP, 'utf8');
if (cur.includes(MARKER)) { console.error('REFUSED: marker already present (one-shot already applied).'); process.exit(2); }
const head = cp.execSync('git show HEAD:map_source/zm/zm_abandoned_cyber_city.map', { cwd: REPO, maxBuffer: 64 * 1024 * 1024 }).toString();

const N = '(-?[\\d.eE+]+)';
const FACE = new RegExp('^(\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s*\\(\\s*' + N + '\\s+' + N + '\\s+' + N + '\\s*\\)\\s+)(\\S+)([\\s\\S]*)$');

// ---- parse a map's worldspawn brushes into (aabbKey|faceKey) -> token ----
const r1 = v => Math.round(v * 10) / 10;
function faceKey(f) { return f.n.map(x => Math.round(x * 1000) / 1000).join(',') + '|' + r1(f.d); }
function parseWorldspawn(text) {
  const L = text.split('\n');
  let depth = 0, entIdx = -1, brush = null;
  const brushes = [];
  for (let i = 0; i < L.length; i++) {
    const o = (L[i].match(/{/g) || []).length, c = (L[i].match(/}/g) || []).length;
    if (depth === 0 && o > 0) entIdx++;
    const before = depth;
    depth += o - c;
    if (entIdx !== 0) { brush = null; continue; }
    if (before === 1 && o > 0) brush = { faces: [] };
    if (brush) {
      const m = L[i].match(FACE);
      if (m) {
        const p = [[+m[2], +m[3], +m[4]], [+m[5], +m[6], +m[7]], [+m[8], +m[9], +m[10]]];
        const u = [p[1][0] - p[0][0], p[1][1] - p[0][1], p[1][2] - p[0][2]];
        const v = [p[2][0] - p[0][0], p[2][1] - p[0][1], p[2][2] - p[0][2]];
        const n = [v[1] * u[2] - v[2] * u[1], v[2] * u[0] - v[0] * u[2], v[0] * u[1] - v[1] * u[0]];
        const len = Math.hypot(...n) || 1;
        brush.faces.push({ line: i, tok: m[11], n: n.map(x => x / len), d: (n[0] * p[0][0] + n[1] * p[0][1] + n[2] * p[0][2]) / len });
      }
    }
    if (before === 2 && depth === 1 && brush) {
      let mins = [-1e9, -1e9, -1e9], maxs = [1e9, 1e9, 1e9];
      for (const f of brush.faces) for (let a = 0; a < 3; a++) {
        if (f.n[a] > 0.999) maxs[a] = Math.min(maxs[a], f.d);
        if (f.n[a] < -0.999) mins[a] = Math.max(mins[a], -f.d);
      }
      brush.mins = mins; brush.maxs = maxs;
      brush.key = mins.map(r1).join(',') + '|' + maxs.map(r1).join(',');
      brushes.push(brush);
      brush = null;
    }
  }
  return brushes;
}
const headTok = new Map();     // aabbKey|faceKey -> Set(tokens)
for (const b of parseWorldspawn(head)) {
  for (const f of b.faces) {
    const k = b.key + '#' + faceKey(f);
    if (!headTok.has(k)) headTok.set(k, new Set());
    headTok.get(k).add(f.tok);
  }
}

const LAB_REGION = { x1: -1150, x2: 1150, y1: 3040, y2: 4470 };
const MKT_REGION = { x1: -2161, x2: -1281, y1: 360, y2: 1496 };
const SWEEP_TOKENS = new Set(['t10_concrete_painted_01_white', 't10_metal_aluminum_painted_01_panels']);

const lines = cur.split('\n');
let labSwaps = 0, mktSwaps = 0, fail = 0;
const restored = {};

for (const b of parseWorldspawn(cur)) {
  const cx = (b.mins[0] + b.maxs[0]) / 2, cy = (b.mins[1] + b.maxs[1]) / 2;
  const inLab = cx >= LAB_REGION.x1 && cx <= LAB_REGION.x2 && cy >= LAB_REGION.y1 && cy <= LAB_REGION.y2;
  const inMkt = cx >= MKT_REGION.x1 && cx <= MKT_REGION.x2 && cy >= MKT_REGION.y1 && cy <= MKT_REGION.y2;
  for (const f of b.faces) {
    if (inLab && SWEEP_TOKENS.has(f.tok)) {
      const hs = headTok.get(b.key + '#' + faceKey(f));
      if (!hs || hs.size !== 1) { console.error(`FAIL: no unambiguous HEAD token for lab face L${f.line + 1} (${hs ? [...hs].join(',') : 'none'})`); fail++; continue; }
      const ht = [...hs][0];
      lines[f.line] = lines[f.line].replace(` ${f.tok} `, ` ${ht} `);
      restored[ht] = (restored[ht] || 0) + 1;
      labSwaps++;
    } else if (inMkt && f.tok === 't7_metal_paint_rust_brown' && f.n[2] < -0.7 && -f.d <= b.mins[2] + 1 && b.mins[2] >= 200) {
      lines[f.line] = lines[f.line].replace(' t7_metal_paint_rust_brown ', ' t10_ceiling_tile_01_dirty ');
      mktSwaps++;
    }
  }
}

if (fail) { console.error(`${fail} face(s) failed HEAD lookup - NOTHING written.`); process.exit(1); }
if (!labSwaps || !mktSwaps) { console.error(`Unexpected counts (lab ${labSwaps}, market ${mktSwaps}) - NOTHING written.`); process.exit(1); }
lines.splice(1, 0, MARKER);
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`lab faces restored to HEAD: ${labSwaps}`);
for (const [t, n] of Object.entries(restored)) console.log(`   -> ${t}: ${n}`);
console.log(`market ceiling undersides -> t10_ceiling_tile_01_dirty: ${mktSwaps}`);
