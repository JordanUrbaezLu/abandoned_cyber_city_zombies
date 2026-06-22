#!/usr/bin/env node
// single_wall_switch.js - revert power to ONE simple wall switch in the Bus Station AND
// thin the bridge back to a slab (user 2026-06-18: "just put one switch ... on the wall at
// the bus station, we can do this later" + "keep the bridge a slab"). Undoes the bridge
// dual-switch + thick deck:
//   - relocate one power_switch prefab from the bridge to the east wall (790,1600,1 = the
//     original known-good Switch A spot, against the east wall, south half = reachable)
//   - delete the second (bridge) prefab; remove the two bridge acc_power_switch triggers
//   - add ONE rim-level acc_power_switch trigger at the wall (walk up to use - no jump)
//   - thin the bridge deck z[-16,58] -> z[42,58] (16u slab again; top still 58)
// _acc_power.gsc unchanged: one acc_power_switch trigger just powers on when used.
// Usage: node tools/single_wall_switch.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: single_wall_switch.js <in> <out>'); process.exit(1); }
const W = [790, 1600, 1];                                   // wall switch origin
const OLD_BRIDGE = [-109, 147, 1723, 2173, -16, 58];        // thick deck to replace
const NB = [-109, 147, 1723, 2173, 42, 58];                 // thin slab (top still 58)
let g = 0x900;
function guid() { g++; return `{7A2B9F00-ACC9-4E0C-8A3F-${g.toString(16).toUpperCase().padStart(12, '0')}}`; }
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
const newBridge = `// corp trench BRIDGE (2x-jump-only crossing, slab)\n${box(NB[0], NB[1], NB[2], NB[3], NB[4], NB[5], 'script_floor_ceiling')}`;
const newTrig = `// Power switch trigger (Bus Station east wall, rim level - walk up to use)\n` +
  ['{', `guid "${guid()}"`, '"classname" "trigger_use"', '"targetname" "acc_power_switch"', '"script_int" "1"',
    box(W[0]-90, W[0], W[1]-60, W[1]+60, 0, 96, 'trigger'), '}'].join('\n');

let src = fs.readFileSync(inPath, 'utf8');
const a = src.replace('"origin" "-85 1948 58"', `"origin" "${W[0]} ${W[1]} ${W[2]}"`);
if (a === src) { console.error('ERROR: prefab origin "-85 1948 58" not found - aborting.'); process.exit(2); }
src = a;

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a2=n.map(Math.abs),mx=Math.max(...a2);if(mx<1e-6)return null;const ax=a2.indexOf(mx);if(a2[(ax+1)%3]+a2[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(gr=>gr.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (x, y) => Math.abs(x - y) < 1;
const lines = src.split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entIdx = -1, wsClose = -1, rmPrefab = 0, rmTrig = 0, rmBridge = 0;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entIdx++; stack.push({ start: i, faces: [], mat: null, ent: entIdx, isEntity: (depth === 0), del: null }); depth++; }
  if (/"origin"\s+"123 1948 58"/.test(lines[i])) { for (const f of stack) if (f.isEntity) f.del = 'prefab'; }
  if (/"targetname"\s+"acc_power_switch"/.test(lines[i])) { for (const f of stack) if (f.isEntity) f.del = 'trig'; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) {
      if (blk.ent === 0 && wsClose === -1) wsClose = i;
      else if (blk.del) { let s = blk.start; if (s > 0 && /^\s*\/\//.test(lines[s-1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; if (blk.del === 'prefab') rmPrefab++; else rmTrig++; }
      continue;
    }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const bd = boundsOf(blk.faces);
      if (bd && OLD_BRIDGE.every((v, k) => near(bd[k], v))) { let s = blk.start; if (s > 0 && /BRIDGE/.test(lines[s-1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; rmBridge++; }
    }
  }
}
if (rmPrefab !== 1) { console.error(`ERROR: removed ${rmPrefab} bridge prefabs (expected 1) - aborting.`); process.exit(2); }
if (rmTrig !== 2) { console.error(`ERROR: removed ${rmTrig} acc_power_switch triggers (expected 2) - aborting.`); process.exit(2); }
if (rmBridge !== 1) { console.error(`ERROR: removed ${rmBridge} thick bridge brushes (expected 1) - aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found - aborting.'); process.exit(2); }
const out = [];
for (let i = 0; i < lines.length; i++) { if (i === wsClose) out.push(newBridge); if (remove[i]) continue; out.push(lines[i]); }
out.push(newTrig, '');
fs.writeFileSync(outArg, out.join('\n'));
console.log(`one wall switch @ (${W}); bridge thinned -> z[${NB[4]},${NB[5]}] slab; deleted 2nd prefab + 2 bridge triggers; added 1 wall trigger; wrote ${outArg}`);
