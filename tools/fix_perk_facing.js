#!/usr/bin/env node
// =============================================================================
// fix_perk_facing.js (one-shot) - revert the 9 Lab perk machines to their ORIGINAL
// facing. add_perk_alcoves.js reoriented them to "0 270 0" (assuming 270=south), but
// these vending models already faced the player at the original "0 359.999 0" - so 270
// turned them the WRONG way (user 2026-06-18). This restores 359.999 on machine entities
// ONLY (model vending_*_struct OR targetname zm_perk_machine) - NOT the risers, which
// legitimately use "0 270 0".
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const VENDING = /^"model" "_prefabs\/zm\/zm_core\/vending_[a-z_]+_struct\.map"$/;
const ORIG = '"angles" "0 359.999 0"';

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const hits = [];
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (!VENDING.test(t) && t !== '"targetname" "zm_perk_machine"') continue;
  let s = i; while (s > 0 && lines[s].trim() !== '{') s--;
  let e = i; while (e < lines.length && lines[e].trim() !== '}') e++;
  hits.push({ s, e });
}
let changed = 0;
hits.sort((a, b) => b.s - a.s); // bottom-to-top (splice-safe)
for (const h of hits) {
  let aIdx = -1;
  for (let k = h.s; k <= h.e; k++) if (/^"angles" "/.test(lines[k].trim())) { aIdx = k; break; }
  if (aIdx >= 0) { if (lines[aIdx].trim() !== ORIG) { lines[aIdx] = ORIG; changed++; } }
  else { lines.splice(h.s + 2, 0, ORIG); changed++; }
}
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`fix_perk_facing: ${hits.length} machine entities found, ${changed} set to ${ORIG}`);
