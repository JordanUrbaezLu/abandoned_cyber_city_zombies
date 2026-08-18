#!/usr/bin/env node
// =============================================================================
// gen_infestation.js - THE INFESTATION GRADIENT (user direction 2026-07-29)
//
// Bakes the glowing-egg infestation into the .map as misc_model statics:
//   --batch 1  = the descent gradient L1-L5 (68 placements + 1 DELETE: the
//                orphan hive01 squatting in the D4 landing keep-clear is
//                removed and re-homed to the L5 W wall). Marker ACCINF01.
//   --batch 2  = the Paradise takeover (61 placements: centerpiece heart nest,
//                hall-mouth jaws, corner broods, wall growths, satellite
//                nests). Marker ACCINF02.
//   --revert 1|2 = strip that batch's appended block (between its BEGIN/END
//                marker comments) and, for batch 1, restore the deleted
//                hive01 block (captured at apply time in *.removed.json).
//
// Placement tables live in gen_infestation_data.json (same folder - produced
// by the 2026-07-29 infestation-gradient-design workflow; every row was
// keep-clear-verified against the abyss geography ledger). Design rules the
// data honors: glow-core-first clusters (proven emissive or fungus-FX anchor
// per cluster), non-solid models ONLY (zero _col bins among candidates ->
// zero clips, zero navmesh churn, zero G_Spawn - baked statics), NO lights
// below the trench lip ever (abyss CTD lockout), ceiling pieces carry roll
// 180 via their note ("roll 180" -> angles "0 <yaw> 180").
//
// Entity shape = byte-clone of the shipped egg misc_model template
// (lightingstate1..4 all 1, modelscale 1, static 1). Guid prefix ACCF1 (hex-
// only; ACCINF contains non-hex chars) - collision pre-checked.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const DATA = path.join(__dirname, 'gen_infestation_data.json');
const GUID_PREFIX = 'ACCF1';

function main() {
  const args = process.argv.slice(2);
  const revertIdx = args.indexOf('--revert');
  const batchIdx = args.indexOf('--batch');
  if (revertIdx >= 0) return revert(args[revertIdx + 1]);
  if (batchIdx < 0) die('usage: gen_infestation.js --batch 1|2  (or --revert 1|2)');
  const batch = args[batchIdx + 1];
  if (batch !== '1' && batch !== '2') die('batch must be 1 or 2');

  const marker = 'ACCINF0' + batch;
  const data = JSON.parse(fs.readFileSync(DATA, 'utf8'));
  const rows = batch === '1' ? data.batch1 : data.batch2;
  const src = fs.readFileSync(MAP, 'utf8');
  if (src.includes(marker)) die(marker + ' already applied - refuse to re-apply. Revert first.');
  const nl = src.includes('\r\n') ? '\r\n' : '\n';

  let body = src;
  const removed = [];

  // batch 1: perform the deletes (guid-addressed, model-verified)
  if (batch === '1') {
    for (const d of data.deletes) {
      const gi = body.indexOf(d.guid);
      if (gi < 0) die('delete target guid not found: ' + d.guid);
      // NB: the guid string itself starts with '{' - the entity's opening brace
      // is the previous one, and the closing brace is the next line-start '}'.
      const s = body.lastIndexOf('{', gi - 1);
      const eNl = body.indexOf(nl + '}', gi);
      if (s < 0 || eNl < 0) die('delete block bounds not found for ' + d.guid);
      const e = eNl + nl.length; // index of the '}' itself
      const block = body.slice(s, e + 1);
      if (!block.includes('"' + d.model + '"')) die('delete guard: block at ' + d.guid + ' is not model ' + d.model);
      removed.push(block);
      body = body.slice(0, s) + body.slice(e + 1);
      // drop a now-dangling comment line directly above, if it names the model (cosmetic)
    }
    fs.writeFileSync(path.join(__dirname, 'gen_infestation_batch1.removed.json'), JSON.stringify({ removed }, null, 1));
  }

  if (body.includes(GUID_PREFIX) && !src.includes('ACCINF0' + (batch === '1' ? '2' : '1')))
    { if (batch === '1') die('guid prefix ' + GUID_PREFIX + ' already in map - collision'); }

  let seq = batch === '1' ? 0 : 500; // batch2 guids start at 500 - no overlap
  const guid = () => '{' + GUID_PREFIX + pad(++seq, 3) + '-0000-4E0B-8A3F-' + pad(seq, 12) + '}';

  const out = [];
  out.push('// ' + marker + ' BEGIN - infestation ' + (batch === '1' ? 'descent gradient L1-L5' : 'Paradise takeover') + ' (2026-07-29, gen_infestation.js; revert: --revert ' + batch + ')');
  for (const r of rows) {
    const roll180 = /roll 180/i.test(r.note || '');
    out.push('{');
    out.push('guid "' + guid() + '"');
    out.push('"classname" "misc_model"');
    out.push('"model" "' + r.model + '"');
    out.push('"origin" "' + r.x + ' ' + r.y + ' ' + r.z + '"');
    out.push('"angles" "0 ' + r.yaw + (roll180 ? ' 180"' : ' 0"'));
    out.push('"lightingstate1" "1"');
    out.push('"lightingstate2" "1"');
    out.push('"lightingstate3" "1"');
    out.push('"lightingstate4" "1"');
    out.push('"modelscale" "1"');
    out.push('"static" "1"');
    out.push('}');
  }
  out.push('// ' + marker + ' END');

  fs.copyFileSync(MAP, MAP + '.acc-inf' + batch + '-orig');
  fs.writeFileSync(MAP, body + nl + out.join(nl) + nl);
  console.log('[gen_infestation] APPLIED ' + marker + ': ' + rows.length + ' misc_models' + (batch === '1' ? ', ' + removed.length + ' deleted (hive01 re-home)' : ''));
  console.log('  backup: ' + MAP + '.acc-inf' + batch + '-orig');
}

function revert(batch) {
  if (batch !== '1' && batch !== '2') die('revert needs 1 or 2');
  const marker = 'ACCINF0' + batch;
  let body = fs.readFileSync(MAP, 'utf8');
  const nl = body.includes('\r\n') ? '\r\n' : '\n';
  const b = body.indexOf('// ' + marker + ' BEGIN');
  const e = body.indexOf('// ' + marker + ' END');
  if (b < 0 || e < 0) die(marker + ' block not found');
  body = body.slice(0, b) + body.slice(e + ('// ' + marker + ' END').length);
  if (batch === '1') {
    const remFile = path.join(__dirname, 'gen_infestation_batch1.removed.json');
    if (fs.existsSync(remFile)) {
      const rem = JSON.parse(fs.readFileSync(remFile, 'utf8'));
      body = body.trimEnd() + nl + rem.removed.join(nl) + nl;
      fs.unlinkSync(remFile);
      console.log('  restored ' + rem.removed.length + ' deleted block(s)');
    }
  }
  fs.writeFileSync(MAP, body.trimEnd() + nl);
  console.log('[gen_infestation] REVERTED ' + marker);
}

function pad(n, w) { return String(n).padStart(w, '0'); }
function die(m) { console.error('[gen_infestation] ABORT: ' + m); process.exit(1); }
main();
