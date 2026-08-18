#!/usr/bin/env node
// =============================================================================
// gen_remove_corpses.js - remove ALL corpse models (user 2026-07-30: "I dont
// really like the dead animals/aliens models. Lets remove those.")
//
// Removes 5 misc_model entities by guid: the M6-era dead queen + 2 dead brutes
// (L5) and today's dead brute_3 (L5) + consumed soldier (L4). Their 4 clip
// entries (m6_l5_queen/brute1/brute2, inf_l5_brute) are removed from
// add_prop_clips.js PROPS by hand in the same pass. p7_foliage_*_long_dead is
// dead VINES (kept - not a corpse). Guid-anchored with the LONE-'{'-LINE rule
// (the gen_infestation_thin brace bug lesson). Revert: --revert.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const REMOVED_FILE = path.join(__dirname, 'gen_remove_corpses.removed.json');

const CUTS = [
  { guid: '{ACCDEC00-0ACC-4E0D-8A3F-000000000525}', model: 'custom_ghost_dead_queen_1' },
  { guid: '{ACCDEC00-0ACC-4E0D-8A3F-000000000526}', model: 'custom_ghost_dead_brute_1' },
  { guid: '{ACCDEC00-0ACC-4E0D-8A3F-000000000527}', model: 'custom_ghost_dead_brute_2' },
  { guid: '{ACCF1050-0000-4E0B-8A3F-000000000050}', model: 'custom_ghost_dead_brute_3' },
  { guid: '{ACCF2011-0000-4E0B-8A3F-000000000011}', model: 'custom_ghost_dead_soldier_01' },
];

function main() {
  if (process.argv.includes('--revert')) return revert();
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const removed = [];
  for (const c of CUTS) {
    const gi = body.indexOf(c.guid);
    if (gi < 0) die('guid not found: ' + c.guid + ' (' + c.model + ')');
    const s = body.lastIndexOf(nl + '{' + nl, gi) + nl.length;   // the LONE '{' line (never the in-string brace)
    if (s < nl.length) die('opening brace line not found before ' + c.guid);
    const eNl = body.indexOf(nl + '}', gi);
    if (eNl < 0) die('closing brace not found for ' + c.guid);
    const e = eNl + nl.length;
    const block = body.slice(s, e + 1);
    if (!block.includes('"' + c.model + '"') || !block.includes('misc_model')) die('guard failed at ' + c.guid);
    removed.push(block);
    body = body.slice(0, s) + body.slice(e + 1);
  }
  fs.writeFileSync(REMOVED_FILE, JSON.stringify({ removed }, null, 1));
  fs.copyFileSync(MAP, MAP + '.acc-corpse-orig');
  fs.writeFileSync(MAP, body);
  console.log('[corpses] removed ' + removed.length + ' corpse models. Backup: .acc-corpse-orig');
}

function revert() {
  if (!fs.existsSync(REMOVED_FILE)) die('nothing to revert');
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const rem = JSON.parse(fs.readFileSync(REMOVED_FILE, 'utf8'));
  fs.writeFileSync(MAP, body.trimEnd() + nl + rem.removed.join(nl) + nl);
  fs.unlinkSync(REMOVED_FILE);
  console.log('[corpses] REVERTED - ' + rem.removed.length + ' blocks re-appended');
}

function die(m) { console.error('[corpses] ABORT: ' + m); process.exit(1); }
main();
