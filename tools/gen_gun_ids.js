// gen_gun_ids.js - keep the weapon-usage gun-ID map in sync from ONE registry (docs/41).
//
// Source of truth: tools/gun_ids.json (append-only name->id registry).
// Live oracle:     _acc_map_randomizer.gsc box_weapons[] (minus the 2 tacticals).
//
// Does three things:
//   1. COMPLETENESS AUDIT (mirrors gen_weapon_stats.js): every live box gun must have
//      an id. A NEW live gun is auto-appended at max+1 and the registry is rewritten
//      (+ a warning). A registry name that's no longer live is kept as a tombstone
//      (its id is never reused). Aborts only on an internal inconsistency.
//   2. Regenerates the GSC acc_gun_id() IF-block between the markers in
//      _acc_weapon_usage.gsc (idempotent - safe to run any time).
//   3. Emits backend/leaderboard/gun_ids.json (id -> display name) so the Worker can
//      label /stats/guns without the game rebuilding.
//
// Run: node tools/gen_gun_ids.js   (add to the build if desired; it's build-time only).
// Exit non-zero on any hard failure.

const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const REG_PATH = path.join(__dirname, 'gun_ids.json');
const RAND_PATH = path.join(ROOT, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_map_randomizer.gsc');
const GSC_PATH = path.join(ROOT, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_weapon_usage.gsc');
const WORKER_PATH = path.join(ROOT, 'backend', 'leaderboard', 'worker.js');

const BEGIN = '// <<< BEGIN GENERATED gun-id map (tools/gen_gun_ids.js from tools/gun_ids.json) - DO NOT hand-edit >>>';
const END = '// <<< END GENERATED gun-id map >>>';
const W_BEGIN = '// <<< BEGIN GENERATED gun-id labels (tools/gen_gun_ids.js) - DO NOT hand-edit >>>';
const W_END = '// <<< END GENERATED gun-id labels >>>';
const BW_BEGIN = '// <<< BEGIN GENERATED gun-box-weight (tools/gen_gun_ids.js from _acc_map_randomizer.gsc acc_box_weight) - DO NOT hand-edit >>>';
const BW_END = '// <<< END GENERATED gun-box-weight >>>';

function die(msg) { console.error('[gen_gun_ids] FAIL: ' + msg); process.exit(1); }

// --- 1. load the registry + parse the live box list ------------------------------
const reg = JSON.parse(fs.readFileSync(REG_PATH, 'utf8'));
const ids = reg.ids;                              // { name: id }
const tacticals = new Set(reg._tactical_not_guns || []);

const randSrc = fs.readFileSync(RAND_PATH, 'utf8');
const boxNoComments = randSrc.replace(/\/\/[^\n]*/g, '');   // strip line comments first (gen_weapon_stats idiom)
const bwBody = (boxNoComments.match(/box_weapons\s*=\s*array\(([\s\S]*?)\);/) || [])[1];
if (!bwBody) die('could not isolate box_weapons array in _acc_map_randomizer.gsc');
const boxList = [...bwBody.matchAll(/"([^"]+)"/g)].map(m => m[1]);
if (boxList.length < 25) die('box_weapons parse got only ' + boxList.length + ' entries (regex drift?)');
const liveGuns = boxList.filter(n => !tacticals.has(n));

// --- 2. completeness: auto-append new live guns; warn on tombstones ---------------
let changed = false;
let maxId = Math.max(0, ...Object.values(ids));
for (const g of liveGuns) {
  if (!(g in ids)) {
    maxId += 1;
    ids[g] = maxId;
    changed = true;
    console.warn('[gen_gun_ids] NEW live gun "' + g + '" -> appended id ' + maxId + '. Add a _display label in tools/gun_ids.json.');
  }
}
const tombstones = Object.keys(ids).filter(n => !liveGuns.includes(n));
if (tombstones.length) {
  console.warn('[gen_gun_ids] registry names NOT in the live box pool (kept as tombstones, ids frozen): ' + tombstones.join(', '));
}
// sanity: no duplicate ids
const seen = new Map();
for (const [n, id] of Object.entries(ids)) {
  if (seen.has(id)) die('duplicate id ' + id + ' for "' + n + '" and "' + seen.get(id) + '" - registry is append-only, ids must be unique');
  seen.set(id, n);
}
if (changed) {
  reg.ids = ids;
  fs.writeFileSync(REG_PATH, JSON.stringify(reg, null, 2) + '\n', 'utf8');
  console.warn('[gen_gun_ids] rewrote tools/gun_ids.json with the new id(s).');
}

// --- 3. regenerate the GSC IF-block ----------------------------------------------
// Emit in ASCENDING id order (stable, human-readable), column-aligned. Each `if`
// line carries its own 4-space indent; the markers keep the module's indentation.
const entries = Object.entries(ids).sort((a, b) => a[1] - b[1]);
const nameCol = Math.max(...entries.map(([n]) => n.length)) + 2;
const ifLines = entries.map(([n, id]) => {
  const lit = '"' + n + '"';
  const pad = ' '.repeat(Math.max(1, nameCol - n.length));
  return `    if ( n == ${lit} )${pad}return ${id};`;
});

let gsc = fs.readFileSync(GSC_PATH, 'utf8');
const bIdx = gsc.indexOf(BEGIN);
const eIdx = gsc.indexOf(END);
if (bIdx < 0 || eIdx < 0 || eIdx < bIdx) die('could not find the GENERATED markers in _acc_weapon_usage.gsc');
const before = gsc.slice(0, bIdx);                  // ends with the BEGIN line's leading indent
const afterStart = gsc.indexOf('\n', eIdx) + 1;     // start of the line AFTER the END marker
const after = gsc.slice(afterStart);
gsc = before + BEGIN + '\n' + ifLines.join('\n') + '\n    ' + END + '\n' + after;
fs.writeFileSync(GSC_PATH, gsc, 'utf8');

// --- 4. INLINE the id->name label map into worker.js (between markers) -------------
// Inlined (not a JSON import) so the dashboard "paste worker.js only" deploy path
// keeps working. Emit as a compact const literal, ids ascending, id 0 first.
const display = reg._display || {};
const labelPairs = [['0', display['0'] || 'Other']];
for (const [n, id] of entries) labelPairs.push([String(id), (display[String(id)] || n).replace(/"/g, '\\"')]);
const labelBody =
  'const GUN_IDS = { ids: {\n' +
  labelPairs.map(([id, name]) => `  "${id}": "${name}"`).join(',\n') +
  '\n} };';

let worker = fs.readFileSync(WORKER_PATH, 'utf8');
const wb = worker.indexOf(W_BEGIN);
const we = worker.indexOf(W_END);
if (wb < 0 || we < 0 || we < wb) die('could not find the GENERATED label markers in worker.js');
const wBefore = worker.slice(0, wb);
const wAfterStart = worker.indexOf('\n', we) + 1;
worker = wBefore + W_BEGIN + '\n' + labelBody + '\n' + W_END + '\n' + worker.slice(wAfterStart);
fs.writeFileSync(WORKER_PATH, worker, 'utf8');

// --- 5. INLINE the id->box-weight + starting-gun sets into worker.js ----------------
// The box draw weight per gun (acc_box_weight in _acc_map_randomizer.gsc) IS the
// availability model behind the pref-index metric (docs/41 §3.6): a gun held a lot
// only because it's offered a lot must be discounted. We inline the nominal FULL-POOL
// weights (the pool actually shrinks as guns are collected + Clover shifts odds, so
// this is the baseline offer rate, documented as nominal). Joined by name to the id
// registry so a rebalance of acc_box_weight re-syncs here on the next generator run.
const wfBody = (boxNoComments.match(/function\s+acc_box_weight\s*\([^)]*\)\s*\{([\s\S]*?)\n\}/) || [])[1];
if (!wfBody) die('could not isolate acc_box_weight() in _acc_map_randomizer.gsc');
const weightByName = {};
for (const m of wfBody.matchAll(/n\s*==\s*"([^"]+)"\s*\)\s*return\s+(\d+)/g)) weightByName[m[1]] = parseInt(m[2], 10);
const BW_DEFAULT = 245;   // acc_box_weight's "unknown -> a mid gun" fallback (bumped 52->245 with the 2026-07-16 16/36/48 reshape)
const bwPairs = [];
for (const [n, id] of entries) {
  if (tombstones.includes(n)) continue;   // retired guns aren't in the live pool -> no offer rate
  let w = weightByName[n];
  if (w === undefined) { w = BW_DEFAULT; console.warn('[gen_gun_ids] no acc_box_weight entry for live gun "' + n + '" -> default ' + BW_DEFAULT); }
  bwPairs.push([String(id), w]);
}
const startingIds = (reg._starting || []).map(n => ids[n]).filter(x => x != null);
const bwBodyOut =
  '// Nominal full-pool box draw weight per gun id (docs/41 pref-index). Missing id = no box\n' +
  '// offer path (e.g. id 0 "other"); pref_index is then null. Auto-synced from GSC.\n' +
  'const GUN_BOX_WEIGHT = {\n' +
  bwPairs.map(([id, w]) => `  "${id}": ${w}`).join(',\n') +
  '\n};\n' +
  '// Gun ids that are ALSO a free/starting weapon (never drawn from the box to be acquired) ->\n' +
  '// pref_index is confounded upward for them; the endpoint flags is_starting so a reader discounts it.\n' +
  'const GUN_STARTING = new Set([' + startingIds.join(', ') + ']);';

const bwb = worker.indexOf(BW_BEGIN);
const bwe = worker.indexOf(BW_END);
if (bwb < 0 || bwe < 0 || bwe < bwb) die('could not find the GENERATED gun-box-weight markers in worker.js');
const bwBefore = worker.slice(0, bwb);
const bwAfterStart = worker.indexOf('\n', bwe) + 1;
worker = bwBefore + BW_BEGIN + '\n' + bwBodyOut + '\n' + BW_END + '\n' + worker.slice(bwAfterStart);
fs.writeFileSync(WORKER_PATH, worker, 'utf8');

console.log('[gen_gun_ids] OK: ' + liveGuns.length + ' live guns, ' + entries.length + ' registry ids (incl. tombstones); GSC block + worker.js labels + box-weight map regenerated.');
