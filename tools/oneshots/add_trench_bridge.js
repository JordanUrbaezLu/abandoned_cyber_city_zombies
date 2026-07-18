#!/usr/bin/env node
// add_trench_bridge.js - Bus Station trench: REMOVE the two stair guard rails and
// add a single central BRIDGE deck across the trench that is reachable ONLY with the
// Rocket Shield 2x jump (user 2026-06-18).
//
// Deck: x[-45,83] (128u wide) y[1723,2173] (full trench span, S rim -> N rim),
// z[42,58] (16u thick, TOP at +58 = 58u above the rim z=0). Stock jump apex ~39u
// can't reach it; Rocket Shield apex ~78u (velocity x1.42) clears it. ANTI-CHEESE:
// it floats over the open 288u pit (no supports/footholds), sheer sides, ends flush
// with the rim edges -> the ONLY way up is a straight 2x jump from a lip. It's
// disconnected from the navmesh so zombies can't path onto it. The stairs (now
// railless) stay the no-item route; the open pit floor under the deck is untouched.
//
// Usage: node tools/add_trench_bridge.js <in.map> <out.map|--dry>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_trench_bridge.js <in> <out|--dry>'); process.exit(1); }
const dry = (outArg === '--dry');

// --- bridge deck ---
const BX1 = -45, BX2 = 83, BY1 = 1723, BY2 = 2173, BZ1 = 42, BZ2 = 58;
let g = 0x600;
function guid() { g++; return `{7A2B9F00-ACC6-4E0C-8A3F-${g.toString(16).toUpperCase().padStart(12, '0')}}`; }
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`, '}'].join('\n');
}
const bridge = `// corp trench BRIDGE (2x-jump-only crossing, tools/add_trench_bridge.js)\n${box(BX1, BX2, BY1, BY2, BZ1, BZ2, 'script_floor_ceiling')}`;

// --- guard rails to remove (script_wall, exact bounds) ---
const RAILS = [[-665, -649, 1723, 1995, -288, 0], [687, 703, 1901, 2173, -288, 0]];
const near = (a, b) => Math.abs(a - b) < 1;
function isRail(b) { return RAILS.some((r) => near(b[0], r[0]) && near(b[1], r[1]) && near(b[2], r[2]) && near(b[3], r[3]) && near(b[4], r[4]) && near(b[5], r[5])); }

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(gr=>gr.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, removed = 0;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0) }); depth++; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) { if (blk.ent === 0 && wsClose === -1) wsClose = i; continue; }
    if (blk.ent === 0 && blk.mat === 'script_wall' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces);
      if (b && isRail(b)) {
        let s = blk.start;
        if (s > 0 && /guard rail/.test(lines[s - 1])) s -= 1;   // drop the comment line too
        for (let j = s; j <= i; j++) remove[j] = true;
        removed++;
        console.log(`  REMOVE guard rail: x[${b[0]},${b[1]}] y[${b[2]},${b[3]}] z[${b[4]},${b[5]}]`);
      }
    }
  }
}
if (removed !== 2) { console.error(`ERROR: expected to remove 2 guard rails, removed ${removed} - aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn closing brace not found - aborting.'); process.exit(2); }
console.log(`  INJECT bridge deck x[${BX1},${BX2}] y[${BY1},${BY2}] z[${BZ1},${BZ2}] (top +${BZ2}) before worldspawn close (line ${wsClose + 1}).`);
if (dry) { console.log('[bridge] --dry: nothing written.'); process.exit(0); }
const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(bridge);
  if (remove[i]) continue;
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[bridge] removed 2 rails + added bridge; lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
