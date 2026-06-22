#!/usr/bin/env node
// levers_onto_bridge.js - put the two power levers ON the trench bridge (user 2026-06-18:
// "on the side of the bridge so players need to jump to interact"). Power now REQUIRES the
// Rocket Shield 2x jump to reach the deck.
//  1) Thicken/widen the bridge deck (x[-45,83] z[42,58] -> x[-109,147] z[26,58], top still 58).
//  2) Relocate both power_switch prefabs onto the deck ends (790,1600,1 -> 19,1770,58;
//     -750,2300,1 -> 19,2126,58).
//  3) Replace the two acc_power_switch trigger_use brushes with ones at DECK height
//     (z[58,138]) over each lever, so they only fire while standing on the bridge.
// _acc_power.gsc is unchanged (still finds acc_power_switch + deletes stock use_elec_switch).
// Usage: node tools/levers_onto_bridge.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: levers_onto_bridge.js <in> <out>'); process.exit(1); }

// --- new geometry params ---
const NBX1 = -109, NBX2 = 147, BY1 = 1723, BY2 = 2173, NBZ1 = 26, NBZ2 = 58;   // thicker/wider bridge
const LZ = 58;                                                                   // lever origin = deck top
const LA = [19, 1770], LB = [19, 2126];                                          // lever XY (S end, N end)
const OLD_BRIDGE = [-45, 83, 1723, 2173, 42, 58];                                // old bridge bounds (to remove)

let g = 0x700;
function guid() { g++; return `{7A2B9F00-ACC7-4E0C-8A3F-${g.toString(16).toUpperCase().padStart(12, '0')}}`; }
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
function trigUse(name, sint, x1, x2, y1, y2, z1, z2) {
  return ['{', `guid "${guid()}"`, '"classname" "trigger_use"', `"targetname" "${name}"`, `"script_int" "${sint}"`,
    box(x1, x2, y1, y2, z1, z2, 'trigger'), '}'].join('\n');
}
const newBridge = `// corp trench BRIDGE (2x-jump-only crossing, thicker - levers_onto_bridge.js)\n${box(NBX1, NBX2, BY1, BY2, NBZ1, NBZ2, 'script_floor_ceiling')}`;
const newTrigA = `// Power relay trigger A (S end of bridge, deck height - jump to reach)\n${trigUse('acc_power_switch', '1', LA[0]-60, LA[0]+60, LA[1]-50, LA[1]+50, 58, 138)}`;
const newTrigB = `// Power relay trigger B (N end of bridge, deck height - jump to reach)\n${trigUse('acc_power_switch', '2', LB[0]-60, LB[0]+60, LB[1]-50, LB[1]+50, 58, 138)}`;

let src = fs.readFileSync(inPath, 'utf8');
// (1) relocate prefabs
let r = 0;
const repA = src.replace('"origin" "790 1600 1"', `"origin" "${LA[0]} ${LA[1]} ${LZ}"`); if (repA !== src) { r++; src = repA; }
const repB = src.replace('"origin" "-750 2300 1"', `"origin" "${LB[0]} ${LB[1]} ${LZ}"`); if (repB !== src) { r++; src = repB; }
if (r !== 2) { console.error(`ERROR: relocated ${r}/2 prefab origins (expected 790 1600 1 and -750 2300 1) - aborting.`); process.exit(2); }

// (2)+(3) remove old bridge brush + old acc_power_switch trigger entities, find worldspawn close
const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a=n.map(Math.abs),mx=Math.max(...a);if(mx<1e-6)return null;const ax=a.indexOf(mx);if(a[(ax+1)%3]+a[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(gr=>gr.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[2-1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (a, b) => Math.abs(a - b) < 1;
const lines = src.split('\n');
const remove = new Array(lines.length).fill(false);
const stack = []; let depth = 0, entityIdx = -1, wsClose = -1, rmBridge = 0, rmTrig = 0;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; stack.push({ start: i, faces: [], mat: null, ent: entityIdx, isEntity: (depth === 0), hasPwr: false }); depth++; }
  if (/"targetname"\s+"acc_power_switch"/.test(lines[i])) { for (const f of stack) if (f.isEntity) f.hasPwr = true; }
  const m = lines[i].match(FACE_RE);
  if (m && stack.length) { const t = stack[stack.length - 1]; t.faces.push([[+m[1],+m[2],+m[3]],[+m[4],+m[5],+m[6]],[+m[7],+m[8],+m[9]]]); if (!t.mat) t.mat = m[10]; }
  for (let c = 0; c < closes; c++) {
    depth--; const blk = stack.pop(); if (!blk) continue;
    if (blk.isEntity) {
      if (blk.ent === 0 && wsClose === -1) wsClose = i;
      else if (blk.hasPwr) { let s = blk.start; if (s > 0 && /^\s*\/\//.test(lines[s - 1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; rmTrig++; }
      continue;
    }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const b = boundsOf(blk.faces);
      if (b && OLD_BRIDGE.every((v, k) => near(b[k], v))) { let s = blk.start; if (s > 0 && /BRIDGE/.test(lines[s - 1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; rmBridge++; }
    }
  }
}
if (rmBridge !== 1) { console.error(`ERROR: removed ${rmBridge} old bridge brushes (expected 1) - aborting.`); process.exit(2); }
if (rmTrig !== 2) { console.error(`ERROR: removed ${rmTrig} old acc_power_switch triggers (expected 2) - aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found - aborting.'); process.exit(2); }

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(newBridge);
  if (remove[i]) continue;
  out.push(lines[i]);
}
out.push(newTrigA, newTrigB, '');
fs.writeFileSync(outArg, out.join('\n'));
console.log(`relocated 2 prefabs onto deck; replaced bridge (x[${NBX1},${NBX2}] z[${NBZ1},${NBZ2}]) + 2 triggers (deck height z[58,138]); wrote ${outArg}`);
