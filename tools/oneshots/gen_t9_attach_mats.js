#!/usr/bin/env node
// =============================================================================
// gen_t9_attach_mats.js - define the CW attachment-DETAIL materials the BOCW pack
// never shipped, so the bullet / case / rail-mount / fast-mag / ammo-link surfaces
// render instead of showing the missing-material checker (user 2026-06-26 "fix
// whatever possible").
//
// These 5 materials are referenced by the CW weapon xmodels but are NOT in gdtDB
// (linker: "Material mtl_* was not found in gdtDB"). They're tiny metal detail
// surfaces. We CLONE a known-good gun material (the AK-47 barrel, a lit_weapon
// metal) under each missing name - it reuses the barrel's CACHED techset + metal
// textures (which already render), so no techset recompile (the docs/29 §14
// broken-shader-compile trap is avoided - this is gdtDB-only, no zone line). The
// surfaces then render as gun-metal. Pulled into the .ff via the weapon models.
//
// Idempotent. Writes <tools>\source_data\acc_t9_attach_mats.gdt. Run gdtdb /update + build after.
//
// Usage: node tools/gen_t9_attach_mats.js [--tools "<modtools root>"]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const args = process.argv.slice(2);
const TOOLS = args.includes('--tools') ? args[args.indexOf('--tools') + 1]
  : 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data');
const SRC = path.join(SD, 't9_weapons', 'wpn_t9_ar_ak47.gdt');
const DONOR = 'mtl_wpn_t9_ar_damage_barrel';   // a working lit_weapon metal material
const MISSING = [
  'mtl_attach_t9_bullet',
  'mtl_wpn_t9_bullet_case_762',
  'mtl_wpn_t9_smg_heavy_rail_mount',
  'mtl_attach_t9_fast_mag_02_ar_damage',
  'mtl_wpn_t9_lmg_slowfire_ammo_link',
];

const lines = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);
const hdr = `"${DONOR}" ( "material.gdf" )`;
let s = lines.findIndex(l => l.includes(hdr));
if (s < 0) { console.error(`ERROR: donor material ${DONOR} not found in ${SRC}`); process.exit(2); }
// block = donor header .. the matching close brace (balanced from the '{' on the next line)
let depth = 0, e = -1;
for (let i = s + 1; i < lines.length; i++) {
  for (const ch of lines[i]) { if (ch === '{') depth++; else if (ch === '}') depth--; }
  if (depth === 0) { e = i; break; }   // the line with the closing brace of the block
}
if (e < 0) { console.error('ERROR: could not find donor block end'); process.exit(2); }
const block = lines.slice(s, e + 1);   // header + { ... }

const out = ['{'];
for (const m of MISSING) {
  out.push(block.map((l, i) => i === 0 ? l.replace(hdr, `"${m}" ( "material.gdf" )`) : l).join('\n'));
}
out.push('}', '');
const dest = path.join(SD, 'acc_t9_attach_mats.gdt');
fs.writeFileSync(dest, out.join('\n'));
console.log(`gen_t9_attach_mats: cloned ${DONOR} -> ${MISSING.length} materials (${block.length} lines each) -> ${dest}`);
console.log('NEXT: gdtdb /update -> build.');
