#!/usr/bin/env node
// =============================================================================
// gen_infestation_thin.js - L4/L5 CLUTTER REDUCTION (user walk feedback
// 2026-07-29: "trench levels need like 25% reduced clutter toward lv 4 and 5
// you can almost barely move around").
//
// Removes 8 of the 28 L4/L5 floor pieces (~29%), chosen to open LANES:
// mid-floor pieces, cluster-middles, and the Gantry-stair-approach egg. Every
// HERO piece stays (hive01/hive02s, the dead brute, the consumed soldier +
// partner, the altar/niche anchors, all wall-silhouette eggs). Paradise and
// L1-L3 untouched. The matching clip entries are removed from add_prop_clips
// in the same pass (done by hand in its PROPS array - see CHANGELOG).
//
// Revert: --revert (re-appends the removed blocks captured at apply time).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const REMOVED_FILE = path.join(__dirname, 'gen_infestation_thin.removed.json');

// model + exact origin string as emitted by gen_infestation.js
const CUTS = [
  { model: 'custom_ghost_armory_alien_egg_01', origin: '560 1810 -947',   why: 'L4 mid-floor between vessel clusters (was clipped - biggest lane gain)' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '660 1850 -947',   why: 'L4 vessel W flank - middle of a 4-egg crowd, opens the E lane' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '310 1948 -947',   why: 'L4 cryo-pod flank - sits on the Gantry stair approach' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '-500 2000 -1187', why: 'L5 Field A innermost (queen S flank) - the W pocket was packed' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '-580 2120 -1187', why: 'L5 Field A hive-queen gap - W pocket relief' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '655 1885 -1187',  why: 'L5 Field B middle of 3 within 165u' },
  { model: 'custom_ghost_armory_alien_egg_01', origin: '620 2110 -1187',  why: 'L5 fountain N edge - mid-density, near the D4 approach' },
  { model: 'custom_ghost_alien_poison',        origin: '-620 1860 -1186', why: 'L5 W pocket approach stalk' },
];

function main() {
  if (process.argv.includes('--revert')) return revert();
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  if (body.indexOf('"origin" "560 1810 -947"') < 0) die('already applied (first cut origin absent)');

  const removed = [];
  for (const c of CUTS) {
    const oi = body.indexOf('"origin" "' + c.origin + '"');
    if (oi < 0) die('cut origin not found: ' + c.origin);
    // BUGFIX 2026-07-29b: the entity's opening brace is a LONE '{' LINE - a bare
    // lastIndexOf('{', oi) lands on the '{' INSIDE the guid string (guid "{HEX-...}")
    // which precedes the origin line, leaving orphaned '{' + 'guid "' fragments in the
    // map (8 unclosed braces caught by the integrity check; repaired by hand same day).
    const s = body.lastIndexOf(nl + '{' + nl, oi) + nl.length;
    if (s < nl.length) die('opening brace line not found before ' + c.origin);
    const eNl = body.indexOf(nl + '}', oi);
    if (s < 0 || eNl < 0) die('block bounds not found for ' + c.origin);
    const e = eNl + nl.length;
    const block = body.slice(s, e + 1);
    if (!block.includes('"' + c.model + '"')) die('guard: block at ' + c.origin + ' is not ' + c.model);
    if (!block.includes('misc_model')) die('guard: block at ' + c.origin + ' is not a misc_model');
    removed.push(block);
    body = body.slice(0, s) + body.slice(e + 1);
  }
  fs.writeFileSync(REMOVED_FILE, JSON.stringify({ removed }, null, 1));
  fs.copyFileSync(MAP, MAP + '.acc-thin1-orig');
  fs.writeFileSync(MAP, body);
  console.log('[thin] removed ' + removed.length + ' L4/L5 floor pieces (~29% of 28). Backup: .acc-thin1-orig');
}

function revert() {
  if (!fs.existsSync(REMOVED_FILE)) die('nothing to revert');
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const rem = JSON.parse(fs.readFileSync(REMOVED_FILE, 'utf8'));
  body = body.trimEnd() + nl + rem.removed.join(nl) + nl;
  fs.unlinkSync(REMOVED_FILE);
  fs.writeFileSync(MAP, body);
  console.log('[thin] REVERTED - ' + rem.removed.length + ' blocks re-appended');
}

function die(m) { console.error('[thin] ABORT: ' + m); process.exit(1); }
main();
