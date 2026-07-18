#!/usr/bin/env node
// =============================================================================
// add_vault_ceiling.js - cap the Vault with a static ceiling brush.
// docs/37 §11. RE-RUNNABLE: strips any existing vault-ceiling block, then re-adds
// with the box below (so editing CEILING + re-running updates the .map).
//
// WHY: a visible structural landmark + a surface for the lockdown red FX, and (once
// LED-relit) it darkens the room by blocking sky light. Permanent worldspawn geometry.
//
// LED-SAFE construction (the lab ceilings crashed Radiant's LED lightmapper on
// coplanar faces, docs/36 / CHANGELOG): the ceiling sits BELOW the z256 wall tops
// (z[230,250]) and its sides are EMBEDDED INSIDE the 20u walls (x 1129..1734,
// y 2270..3390 - between each wall's outer/inner faces), so NO ceiling face is
// coplanar with a wall face. It still fully caps the interior (overlaps into the
// walls). Box = [x1,x2,y1,y2,z1,z2]; winding = apply_room_shrink.js addBrush.
//
// Usage:  node tools/add_vault_ceiling.js [--dry]
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// box = [x1, x2, y1, y2, z1, z2]. Vault walls: west x[1119,1139], east x[1724,1744],
// south y[2260,2280], north y[3380,3400], tops z256. Sides embedded 10u into walls.
const CEILING = { box: [1129, 1734, 2270, 3390, 230, 250], mat: 'script_floor_ceiling', guid: '{ACCVCEIL-0000-4E0C-8A3F-00000000CEIL}' };
const TAG = '// ACC vault ceiling (tools/add_vault_ceiling.js)';

// Axis-aligned box from REAL corner coords (not filler) so each face polygon is
// well-formed - the filler-coordinate winding (apply_room_shrink addBrush) produces
// degenerate faces for large/far brushes that crash Radiant's LED (brush.cpp:1860).
// Winding preserved from the working brushes (cross(P2-P1,P3-P1) points INTO solid).
function addBrush(b, mat, guid) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const [x1, x2, y1, y2, z1, z2] = b;
  const p = (x, y, z) => `( ${x} ${y} ${z} )`;
  return [
    '{', ` guid "${guid}"`,
    ` ${p(x2, y2, z1)} ${p(x1, y2, z1)} ${p(x1, y1, z1)} ${t}`, // bottom (z1)
    ` ${p(x1, y1, z2)} ${p(x1, y2, z2)} ${p(x2, y2, z2)} ${t}`, // top (z2)
    ` ${p(x1, y1, z2)} ${p(x2, y1, z2)} ${p(x2, y1, z1)} ${t}`, // y1
    ` ${p(x2, y1, z2)} ${p(x2, y2, z2)} ${p(x2, y2, z1)} ${t}`, // x2
    ` ${p(x2, y2, z2)} ${p(x1, y2, z2)} ${p(x1, y2, z1)} ${t}`, // y2
    ` ${p(x1, y2, z2)} ${p(x1, y1, z2)} ${p(x1, y1, z1)} ${t}`, // x1
    '}',
  ].join('\n');
}

// Remove the comment line + the brush block that follows it (matched braces).
function stripCeiling(lines) {
  const ci = lines.findIndex(l => l.includes(TAG));
  if (ci < 0) return lines;
  let depth = 0, end = -1;
  for (let k = ci + 1; k < lines.length; k++) {
    if (lines[k].trim() === '{') depth++;
    else if (lines[k].trim() === '}') { depth--; if (depth === 0) { end = k; break; } }
  }
  if (end < 0) { console.error('FATAL: found ceiling comment but no matching brush close'); process.exit(1); }
  return lines.slice(0, ci).concat(lines.slice(end + 1));
}

const dry = process.argv.includes('--dry');
let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

const had = lines.some(l => l.includes(TAG));
lines = stripCeiling(lines);

const e1 = lines.indexOf('// entity 1');
if (e1 < 1 || lines[e1 - 1].trim() !== '}') {
  console.error('FATAL: cannot locate worldspawn close before "// entity 1"');
  process.exit(1);
}

const block = [TAG, addBrush(CEILING.box, CEILING.mat, CEILING.guid)];
const out = lines.slice(0, e1 - 1).concat(block, lines.slice(e1 - 1)).join('\n');

console.log(`${had ? 'replacing' : 'appending'} vault ceiling brush ${CEILING.box.join(',')}`);
if (dry) { console.log('--dry: no write'); process.exit(0); }

fs.writeFileSync(MAP, out);
console.log('wrote ' + MAP);
