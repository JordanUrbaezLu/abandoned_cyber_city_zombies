#!/usr/bin/env node
// add_power_switches.js - DUAL-SWITCH power for the Bus Station (user 2026-06-18).
// 1) Relocate the existing corp power_switch prefab out of the trench it now floats
//    in (790,1900,1 -> 790,1600,1 = SOUTH-EAST, solid south slab).
// 2) Append a SECOND power_switch prefab at the NORTH-WEST (-750,2300,1, facing E).
// 3) Append two trigger_use brushes (targetname "acc_power_switch", script_int 1/2)
//    over each lever. _acc_power.gsc gates power behind BOTH (deletes stock OR).
// Usage: node tools/add_power_switches.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_power_switches.js <in> <out>'); process.exit(1); }
let g = 0x500;
function guid() { g++; return `{7A2B9F00-ACC5-4E0C-8A3F-${g.toString(16).toUpperCase().padStart(12, '0')}}`; }
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
function prefab(origin, angles, sstr) {
  return ['{', `guid "${guid()}"`, '"classname" "misc_prefab"', `"angles" "${angles}"`,
    '"model" "_prefabs/zm/zm_core/power_switch.map"', `"origin" "${origin}"`, `"script_string" "${sstr}"`, '}'].join('\n');
}
function trigUse(name, sint, x1, x2, y1, y2, z1, z2) {
  return ['{', `guid "${guid()}"`, '"classname" "trigger_use"', `"targetname" "${name}"`, `"script_int" "${sint}"`,
    box(x1, x2, y1, y2, z1, z2, 'trigger'), '}'].join('\n');
}
let src = fs.readFileSync(inPath, 'utf8');
const before = src;
src = src.replace('"origin" "790 1900 1"', '"origin" "790 1600 1"');
if (src === before) { console.error('ERROR: switch A origin "790 1900 1" not found - aborting.'); process.exit(2); }
const additions = [
  '// ===== DUAL POWER SWITCH (re-add 2026-06-18, tools/add_power_switches.js) =====',
  '// Switch B - NORTH-WEST of trench, facing east',
  prefab('-750 2300 1', '0 90 0', 'corp'),
  '// Power relay trigger A (south-east, over relocated switch A @ 790 1600)',
  trigUse('acc_power_switch', '1', 730, 850, 1540, 1660, 0, 100),
  '// Power relay trigger B (north-west, over switch B @ -750 2300)',
  trigUse('acc_power_switch', '2', -810, -690, 2240, 2360, 0, 100),
  '',
].join('\n');
src = src.replace(/\s*$/, '\n') + additions;
fs.writeFileSync(outArg, src);
console.log('relocated switch A -> 790 1600 1; added switch B prefab + 2 acc_power_switch trigger_use brushes');
