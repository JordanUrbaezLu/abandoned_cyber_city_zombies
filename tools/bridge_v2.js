#!/usr/bin/env node
// bridge_v2.js - thicken the trench bridge into a real structure (not a slab) and put
// the two power levers on its LEFT/RIGHT (west/east) sides (user 2026-06-18). Also strips
// the stair guard rails (the trench-raise regen keeps re-adding them).
//  - Bridge: x[-109,147] y[1723,2173] z[26,58] -> z[-16,58] (74u thick, top still 58 = the
//    2x-jump gate). Bottom -16 stays above the raised pit floor (-112): under-bridge floor
//    crossing keeps ~96u headroom, and a 2x jump from the floor (apex ~78 -> z=-34) can't
//    reach the -16 bottom. Sides are now 74u tall -> room to mount levers.
//  - Levers: ends (19,1770,58)/(19,2126,58) -> WEST (-85,1948,58) + EAST (123,1948,58).
//  - Triggers: at deck height z[58,138] over each side lever (jump onto the deck to flip).
// Usage: node tools/bridge_v2.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: bridge_v2.js <in> <out>'); process.exit(1); }

const BX1 = -109, BX2 = 147, BY1 = 1723, BY2 = 2173, BZ1 = -16, BZ2 = 58;   // thick bridge
const OLD_BRIDGE = [-109, 147, 1723, 2173, 26, 58];                          // current bridge to replace
const LW = [-85, 1948], LE = [123, 1948], LZ = 58;                          // west + east lever XY, deck top

let g = 0x800;
function guid() { g++; return `{7A2B9F00-ACC8-4E0C-8A3F-${g.toString(16).toUpperCase().padStart(12, '0')}}`; }
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
const newBridge = `// corp trench BRIDGE (2x-jump-only crossing, THICK - bridge_v2.js)\n${box(BX1, BX2, BY1, BY2, BZ1, BZ2, 'script_floor_ceiling')}`;
const newTrigW = `// Power relay trigger A (WEST side of bridge, deck height - jump to reach)\n${trigUse('acc_power_switch', '1', LW[0]-55, LW[0]+45, LW[1]-50, LW[1]+50, 58, 138)}`;
const newTrigE = `// Power relay trigger B (EAST side of bridge, deck height - jump to reach)\n${trigUse('acc_power_switch', '2', LE[0]-45, LE[0]+55, LE[1]-50, LE[1]+50, 58, 138)}`;

let src = fs.readFileSync(inPath, 'utf8');
let r = 0;
const a = src.replace('"origin" "19 1770 58"', `"origin" "${LW[0]} ${LW[1]} ${LZ}"`); if (a !== src) { r++; src = a; }
const b = src.replace('"origin" "19 2126 58"', `"origin" "${LE[0]} ${LE[1]} ${LZ}"`); if (b !== src) { r++; src = b; }
if (r !== 2) { console.error(`ERROR: relocated ${r}/2 prefab origins (need "19 1770 58" + "19 2126 58") - aborting.`); process.exit(2); }

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function boundsOf(faces){if(faces.length!==6)return null;const A=[[],[],[]];for(const[p1,p2,p3]of faces){const u=[p2[0]-p1[0],p2[1]-p1[1],p2[2]-p1[2]],v=[p3[0]-p1[0],p3[1]-p1[1],p3[2]-p1[2]];const n=[u[1]*v[2]-u[2]*v[1],u[2]*v[0]-u[0]*v[2],u[0]*v[1]-u[1]*v[0]];const a2=n.map(Math.abs),mx=Math.max(...a2);if(mx<1e-6)return null;const ax=a2.indexOf(mx);if(a2[(ax+1)%3]+a2[(ax+2)%3]>mx*1e-4)return null;A[ax].push(p1[ax]);}if(A.some(gr=>gr.length!==2))return null;return[Math.min(...A[0]),Math.max(...A[0]),Math.min(...A[1]),Math.max(...A[1]),Math.min(...A[2]),Math.max(...A[2])];}
const near = (x, y) => Math.abs(x - y) < 1;
const lines = src.split('\n');
const remove = new Array(lines.length).fill(false);
// (a) guard-rail blocks (comment-based)
let rmRail = 0;
for (let i = 0; i < lines.length; i++) {
  if (/^\s*\/\//.test(lines[i]) && /guard rail/i.test(lines[i])) {
    let j = i + 1; while (j < lines.length && !/\{/.test(lines[j])) j++;
    if (j >= lines.length) continue;
    let d = 0, k = j; for (; k < lines.length; k++) { d += (lines[k].match(/{/g)||[]).length - (lines[k].match(/}/g)||[]).length; if (d === 0) break; }
    for (let m = i; m <= k; m++) remove[m] = true; rmRail++;
  }
}
// (b) old bridge brush + (c) old acc_power_switch trigger entities; find worldspawn close
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
      else if (blk.hasPwr) { let s = blk.start; if (s > 0 && /^\s*\/\//.test(lines[s-1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; rmTrig++; }
      continue;
    }
    if (blk.ent === 0 && blk.mat === 'script_floor_ceiling' && blk.faces.length === 6) {
      const bd = boundsOf(blk.faces);
      if (bd && OLD_BRIDGE.every((v, k) => near(bd[k], v))) { let s = blk.start; if (s > 0 && /BRIDGE/.test(lines[s-1])) s -= 1; for (let j = s; j <= i; j++) remove[j] = true; rmBridge++; }
    }
  }
}
if (rmRail !== 2) { console.error(`ERROR: removed ${rmRail} guard rails (expected 2) - aborting.`); process.exit(2); }
if (rmBridge !== 1) { console.error(`ERROR: removed ${rmBridge} old bridge (expected 1) - aborting.`); process.exit(2); }
if (rmTrig !== 2) { console.error(`ERROR: removed ${rmTrig} old triggers (expected 2) - aborting.`); process.exit(2); }
if (wsClose === -1) { console.error('ERROR: worldspawn close not found - aborting.'); process.exit(2); }
const out = [];
for (let i = 0; i < lines.length; i++) { if (i === wsClose) out.push(newBridge); if (remove[i]) continue; out.push(lines[i]); }
out.push(newTrigW, newTrigE, '');
fs.writeFileSync(outArg, out.join('\n'));
console.log(`thickened bridge -> z[${BZ1},${BZ2}] (74u); levers -> W(${LW}) + E(${LE}); stripped 2 rails; wrote ${outArg}`);
