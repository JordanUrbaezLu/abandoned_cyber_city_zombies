#!/usr/bin/env node
// =============================================================================
// gen_remove_pighead.js - remove the L5 jade snake fountain (user 2026-07-30:
// "There is still a pig heade model i want removed... trench 5th floor opposit
// side of ammo crate" = p7_ram_snake_fountain_01_jade at (620,2000,-1200), the
// wide-snouted ZNS snake head). Its clip entry (pillar_l5_fountain) is removed
// from add_prop_clips.js PROPS in the same pass. The OTHER ram_snake pieces
// (W jade statue, columns, sconces, niche nests) STAY - only this one was
// called out. Guid-anchored, lone-'{'-line rule. Revert: --revert.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const REMOVED_FILE = path.join(__dirname, 'gen_remove_pighead.removed.json');
const CUT = { guid: '{ACCDEC00-0ACC-4E0D-8A3F-000000000479}', model: 'p7_ram_snake_fountain_01_jade' };

function main() {
  if (process.argv.includes('--revert')) return revert();
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const gi = body.indexOf(CUT.guid);
  if (gi < 0) die('guid not found (already removed?)');
  const s = body.lastIndexOf(nl + '{' + nl, gi) + nl.length;
  if (s < nl.length) die('opening brace line not found');
  const eNl = body.indexOf(nl + '}', gi);
  if (eNl < 0) die('closing brace not found');
  const e = eNl + nl.length;
  const block = body.slice(s, e + 1);
  if (!block.includes('"' + CUT.model + '"') || !block.includes('misc_model')) die('guard failed');
  fs.writeFileSync(REMOVED_FILE, JSON.stringify({ removed: [block] }, null, 1));
  fs.copyFileSync(MAP, MAP + '.acc-pighead-orig');
  fs.writeFileSync(MAP, body.slice(0, s) + body.slice(e + 1));
  console.log('[pighead] removed ' + CUT.model + ' @ (620,2000,-1200). Backup: .acc-pighead-orig');
}

function revert() {
  if (!fs.existsSync(REMOVED_FILE)) die('nothing to revert');
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const rem = JSON.parse(fs.readFileSync(REMOVED_FILE, 'utf8'));
  fs.writeFileSync(MAP, body.trimEnd() + nl + rem.removed.join(nl) + nl);
  fs.unlinkSync(REMOVED_FILE);
  console.log('[pighead] REVERTED');
}

function die(m) { console.error('[pighead] ABORT: ' + m); process.exit(1); }
main();
