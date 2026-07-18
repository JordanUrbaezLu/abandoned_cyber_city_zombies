#!/usr/bin/env node
// =============================================================================
// add_lockdown_seals.js - append stage-2 lockdown DOOR-SEAL brushes to the .map.
// docs/37 §11. RE-RUNNABLE: strips the existing seal block, then re-adds (so editing
// SEALS + re-running updates the .map).
//
// Hidden-by-default script_brushmodels that _acc_lockdown.gsc toggles solid
// (show+solid+disconnectpaths) to LOCK a room and notsolid (hide+notsolid+
// connectpaths) to UNLOCK it - the _acc_map_randomizer::apply_pap_approach pattern.
// The module hides them at init() so they are inert until a lockdown fires.
//
// LED-SAFE construction (added z256 brushes crashed Radiant's LED, docs/36):
// seal tops stop at z250 (BELOW the z256 wall tops, not coplanar), bottoms rest on
// the floor at z0 (the one coplanar case that is verified fine), and the y-sides are
// inset 8u off the corridor walls. box=[x1,x2,y1,y2,z1,z2]; winding = apply_room_shrink.js.
//
// SCOPE: the Vault. Two doorways, BOTH on its west wall (x=1119): corp<->vault
// (corridor c_corp_vlt y[2300,2556]) and vault<->lab (corridor c_vlt_lab y[3100,3356]).
//
// Usage:  node tools/add_lockdown_seals.js [--dry]
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const HEADER = '// ===== ACC stage-2 lockdown door seals (tools/add_lockdown_seals.js) =====';

// box = [x1, x2, y1, y2, z1, z2]
const SEALS = [
  { tag: 'acc_seal_vault_zone', label: 'vault<->corp door', box: [1095, 1115, 2308, 2548, 0, 250], eg: 'ACCSLVA0', bg: 'ACCSLVA1' },
  { tag: 'acc_seal_vault_zone', label: 'vault<->lab door',  box: [1095, 1115, 3108, 3348, 0, 250], eg: 'ACCSLVB0', bg: 'ACCSLVB1' },
];

// Axis-aligned box from REAL corner coords (not filler) so each face polygon is
// well-formed - the filler-coordinate winding crashes Radiant's LED brush sanity
// check (brush.cpp:1860) for large/far brushes. Winding preserved from the working
// brushes (cross(P2-P1,P3-P1) points INTO the solid).
function planes(box, mat) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const [x1, x2, y1, y2, z1, z2] = box;
  const p = (x, y, z) => `( ${x} ${y} ${z} )`;
  return [
    ` ${p(x2, y2, z1)} ${p(x1, y2, z1)} ${p(x1, y1, z1)} ${t}`, // bottom (z1)
    ` ${p(x1, y1, z2)} ${p(x1, y2, z2)} ${p(x2, y2, z2)} ${t}`, // top (z2)
    ` ${p(x1, y1, z2)} ${p(x2, y1, z2)} ${p(x2, y1, z1)} ${t}`, // y1
    ` ${p(x2, y1, z2)} ${p(x2, y2, z2)} ${p(x2, y2, z1)} ${t}`, // x2
    ` ${p(x2, y2, z2)} ${p(x1, y2, z2)} ${p(x1, y2, z1)} ${t}`, // y2
    ` ${p(x1, y2, z2)} ${p(x1, y1, z2)} ${p(x1, y1, z1)} ${t}`, // x1
  ];
}

function entityBlock(seal) {
  const out = [];
  out.push(`// ACC lockdown seal: ${seal.label}`);
  out.push('{');
  out.push(`guid "{${seal.eg}-0000-4E0C-8A3F-00000000SEAL}"`);
  out.push('"classname" "script_brushmodel"');
  out.push(`"targetname" "${seal.tag}"`);
  out.push('// brush 0');
  out.push('{');
  out.push(` guid "{${seal.bg}-0000-4E0C-8A3F-00000000SEAL}"`);
  for (const p of planes(seal.box, 'script_wall')) out.push(p);
  out.push('}');
  out.push('}');
  return out.join('\n');
}

const dry = process.argv.includes('--dry');
let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

// Strip the existing seal block (header comment -> EOF; the seals are appended last).
const hi = lines.findIndex(l => l.includes(HEADER));
const had = hi >= 0;
if (had) lines = lines.slice(0, hi);
while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();

const block = ['', HEADER];
for (const s of SEALS) block.push(entityBlock(s));
const out = lines.concat(block, ['']).join('\n');

console.log(`${had ? 'replacing' : 'appending'} ${SEALS.length} seal brush entit${SEALS.length === 1 ? 'y' : 'ies'} (acc_seal_vault_zone)`);
if (dry) { console.log('--dry: no write'); process.exit(0); }

fs.writeFileSync(MAP, out);
console.log('wrote ' + MAP);
