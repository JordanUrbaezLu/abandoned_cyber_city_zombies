#!/usr/bin/env node
// =============================================================================
// gen_alien_swap.js - TRENCH ALIEN TAKEOVER v2, swap pass (user 2026-07-29:
// "adding models from [the alien] package to design the trench... removing
// some not all of the older placements to free up room")
//
// V1 = the CLIP-NEUTRAL subset from gen_alien_swap_data.json (designed by the
// trench-alien-takeover-v2 workflow, GDT-verified 2026-07-29): removes only
// UNCLIPPED older placements (13 - incl. the 5 BANNED-class tall_grass/weeds
// baked in at L3 since the 07-18 sweep) and adds 13 alien-biome pieces, mostly
// in-place swaps. Net entity delta 0; zero clip/navmesh changes. The 2 clipped
// removals (cryo pod + console, rows clipped=true) are V2 - they need clip
// deletes + DisconnectPaths + navmesh regen.
//
// Marker ACCSWP01; guid prefix ACCF2 (hex). Revert: --revert (restores the
// removed blocks captured at apply time + strips the added block).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const DATA = path.join(__dirname, 'gen_alien_swap_data.json');
const REMOVED_FILE = path.join(__dirname, 'gen_alien_swap.removed.json');
const MARKER = 'ACCSWP01';
const GUID_PREFIX = 'ACCF2';

function main() {
  if (process.argv.includes('--revert')) return revert();

  const data = JSON.parse(fs.readFileSync(DATA, 'utf8'));
  let body = fs.readFileSync(MAP, 'utf8');
  if (body.includes(MARKER)) die(MARKER + ' already applied - revert first');
  if (body.includes(GUID_PREFIX + '0')) die('guid prefix collision: ' + GUID_PREFIX);
  const nl = body.includes('\r\n') ? '\r\n' : '\n';

  // v1 removals: unclipped only
  const removes = data.removes.filter(r => !r.clipped);
  const removed = [];
  for (const r of removes) {
    const gi = body.indexOf(r.guid);
    if (gi < 0) die('remove guid not found: ' + r.guid + ' (' + r.model + ')');
    const s = body.lastIndexOf('{', gi - 1);
    const eNl = body.indexOf(nl + '}', gi);
    if (s < 0 || eNl < 0) die('block bounds not found for ' + r.guid);
    const e = eNl + nl.length;
    const block = body.slice(s, e + 1);
    if (!block.includes('"' + r.model + '"')) die('guard: block at ' + r.guid + ' is not ' + r.model);
    removed.push(block);
    body = body.slice(0, s) + body.slice(e + 1);
  }

  let seq = 0;
  const guid = () => '{' + GUID_PREFIX + pad(++seq, 3) + '-0000-4E0B-8A3F-' + pad(seq, 12) + '}';
  const out = [];
  out.push('// ' + MARKER + ' BEGIN - trench alien takeover v2 swap pass (2026-07-29, gen_alien_swap.js; revert: --revert)');
  for (const a of data.adds) {
    const m = (a.note || '').match(/Angles \(0 (\d+) 180\)/);
    const roll180 = !!m || /roll 180/i.test(a.note || '');
    out.push('{');
    out.push('guid "' + guid() + '"');
    out.push('"classname" "misc_model"');
    out.push('"model" "' + a.model + '"');
    out.push('"origin" "' + a.x + ' ' + a.y + ' ' + a.z + '"');
    out.push('"angles" "0 ' + a.yaw + (roll180 ? ' 180"' : ' 0"'));
    out.push('"lightingstate1" "1"');
    out.push('"lightingstate2" "1"');
    out.push('"lightingstate3" "1"');
    out.push('"lightingstate4" "1"');
    out.push('"modelscale" "1"');
    out.push('"static" "1"');
    out.push('}');
  }
  out.push('// ' + MARKER + ' END');

  fs.writeFileSync(REMOVED_FILE, JSON.stringify({ removed }, null, 1));
  fs.copyFileSync(MAP, MAP + '.acc-swp1-orig');
  fs.writeFileSync(MAP, body + nl + out.join(nl) + nl);
  console.log('[gen_alien_swap] APPLIED ' + MARKER + ': removed ' + removed.length + ' older placements, added ' + data.adds.length + ' alien pieces (net ' + (data.adds.length - removed.length) + ')');
  console.log('  v2 (clipped) rows deferred: ' + data.removes.filter(r => r.clipped).length);
}

function revert() {
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const b = body.indexOf('// ' + MARKER + ' BEGIN');
  const e = body.indexOf('// ' + MARKER + ' END');
  if (b < 0 || e < 0) die(MARKER + ' block not found');
  body = body.slice(0, b) + body.slice(e + ('// ' + MARKER + ' END').length);
  if (fs.existsSync(REMOVED_FILE)) {
    const rem = JSON.parse(fs.readFileSync(REMOVED_FILE, 'utf8'));
    body = body.trimEnd() + nl + rem.removed.join(nl) + nl;
    fs.unlinkSync(REMOVED_FILE);
    console.log('  restored ' + rem.removed.length + ' removed block(s)');
  }
  fs.writeFileSync(MAP, body.trimEnd() + nl);
  console.log('[gen_alien_swap] REVERTED ' + MARKER);
}

function pad(n, w) { return String(n).padStart(w, '0'); }
function die(m) { console.error('[gen_alien_swap] ABORT: ' + m); process.exit(1); }
main();
