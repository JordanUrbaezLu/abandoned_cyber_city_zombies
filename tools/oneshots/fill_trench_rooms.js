#!/usr/bin/env node
// fill_trench_rooms.js - EMERGENCY FLOOR FIX (user 2026-06-19).
// The carved underground rooms (add_trench_rooms.js) + floor seg1 (add_trench_floor.js)
// used thin z[-80,0] "ceiling" slabs as the walkable Bus Station floor over a hollow room.
// cod2map DROPS those thin floor-over-void slabs from the collision BSP -> the player falls
// straight through (the brushes are in the .map but the compiler discards them). This restores
// the SOLID corp ground slabs (the original, proven-working Bus Station floor) and removes the
// room/floor brush sections. The TRENCH (the open pit + stairs + end walls) is kept as-is.
//
// Usage: node tools/fill_trench_rooms.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: fill_trench_rooms.js <in> <out>'); process.exit(1); }

let lines = fs.readFileSync(inPath, 'utf8').split('\n');

// remove an inclusive marker..marker line range (the injected worldspawn brush sections)
function removeRange(startMarker, endMarker, label) {
  const s = lines.findIndex(l => l.includes(startMarker));
  if (s < 0) { console.log(`  (no ${label} section found)`); return; }
  let e = -1;
  for (let i = s; i < lines.length; i++) { if (lines[i].includes(endMarker)) { e = i; break; } }
  if (e < 0) { console.log(`  WARN: ${label} start found but no end marker`); return; }
  console.log(`  REMOVE ${label}: lines ${s + 1}-${e + 1} (${e - s + 1} lines)`);
  lines.splice(s, e - s + 1);
}
removeRange('===== TRENCH ROOMS', '===== end trench rooms', 'trench rooms');
removeRange('===== UNDERGROUND FLOOR seg1', '===== end floor seg1', 'underground floor seg1');

// ---- proven box() emitter (verbatim from add_trench_rooms.js / gen_corp_trench.js) ----
let guidCounter = 0x900;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F09-ACC9-4E0F-8A3F-${c}}`; }
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

// original SOLID corp ground slabs (x[-781,819]; south y[1148,1723], north y[2173,2748]; z[-256,0]).
const slabs = [
  '// ===== SOLID CORP FLOOR RESTORED (fill_trench_rooms.js) =====',
  '// corp south ground slab (solid)', box(-781, 819, 1148, 1723, -256, 0, 'script_floor_ceiling'),
  '// corp north ground slab (solid)', box(-781, 819, 2173, 2748, -256, 0, 'script_floor_ceiling'),
  '// ===== end solid corp floor =====',
];

// inject before the worldspawn closing brace (entity 0). Walk braces to find it.
let depth = 0, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) depth++;
  for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && wsClose === -1) { wsClose = i; } }
}
if (wsClose < 0) { console.error('ERROR: worldspawn close not found'); process.exit(2); }
console.log(`  INJECT 2 solid slabs before worldspawn close (line ${wsClose + 1}).`);

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(...slabs);
  out.push(lines[i]);
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`[fill] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
