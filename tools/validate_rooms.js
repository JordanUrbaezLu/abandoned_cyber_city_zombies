#!/usr/bin/env node
// =============================================================================
// validate_rooms.js - asserts the duplicated ACC room-geometry copies agree
// with the source-of-truth source_data/rooms.json. docs/36 Stage 0.
//
// WHY: room FOOTPRINTS are duplicated across 4 artifacts with no cross-check,
// and the PaP origin across 2 literals. A shrink that edits one but not the
// others silently desyncs the map from the generators / SVG / GSC. This catches
// that before a build. Run standalone or via tools/preflight_windows.ps1.
//
//   node tools/validate_rooms.js
//
// Exit 0 = all copies agree (warnings allowed); exit 1 = a hard mismatch.
// =============================================================================

'use strict';
const fs = require('fs');
const path = require('path');

const ROOT = path.join(__dirname, '..');
const P = (...a) => path.join(ROOT, ...a);
const read = (rel) => fs.readFileSync(P(rel), 'utf8');

const EPS = 0.5; // coords are integers or halves; real divergence is >= tens of units
const errors = [];
const warns = [];
const oks = [];
const err = (m) => errors.push(m);
const warn = (m) => warns.push(m);
const ok = (m) => oks.push(m);

const sot = JSON.parse(read('source_data/rooms.json'));

// ---- helpers ----------------------------------------------------------------
const eq = (a, b) => Math.abs(a - b) < EPS;
const boxEq = (a, b) => eq(a.x1, b.x1) && eq(a.x2, b.x2) && eq(a.y1, b.y1) && eq(a.y2, b.y2);
const fmt = (b) => `x[${b.x1},${b.x2}] y[${b.y1},${b.y2}]`;
// normalize a box so x1<x2, y1<y2 (the .map / generators don't guarantee order)
const norm = (b) => ({
  x1: Math.min(b.x1, b.x2), x2: Math.max(b.x1, b.x2),
  y1: Math.min(b.y1, b.y2), y2: Math.max(b.y1, b.y2),
});

// ---- 1. tools/gen_zone_greybox.js rooms{} (6, by short name) -----------------
function parseGreyboxRooms() {
  const src = read('tools/gen_zone_greybox.js');
  const block = src.match(/const rooms\s*=\s*\{([\s\S]*?)\};/);
  if (!block) { err('gen_zone_greybox.js: could not locate `const rooms = {...}`'); return {}; }
  const out = {};
  const re = /(\w+)\s*:\s*\{\s*x1:\s*(-?[\d.]+),\s*x2:\s*(-?[\d.]+),\s*y1:\s*(-?[\d.]+),\s*y2:\s*(-?[\d.]+)\s*\}/g;
  let m;
  while ((m = re.exec(block[1]))) {
    out[m[1]] = norm({ x1: +m[2], x2: +m[3], y1: +m[4], y2: +m[5] });
  }
  return out;
}

// ---- 2. tools/gen_map_design.js rooms[] (7, by zone) -------------------------
function parseDesignRooms() {
  const src = read('tools/gen_map_design.js');
  const block = src.match(/const rooms\s*=\s*\[([\s\S]*?)\];/);
  if (!block) { err('gen_map_design.js: could not locate `const rooms = [...]`'); return {}; }
  const out = {};
  const re = /zone:\s*'(\w+)',\s*x1:\s*(-?[\d.]+),\s*x2:\s*(-?[\d.]+),\s*y1:\s*(-?[\d.]+),\s*y2:\s*(-?[\d.]+)/g;
  let m;
  while ((m = re.exec(block[1]))) {
    out[m[1]] = norm({ x1: +m[2], x2: +m[3], y1: +m[4], y2: +m[5] });
  }
  return out;
}

// ---- 3. tools/gen_rooms.js room('label', ix0, iy0, ix1, iy1, ...) ------------
function parseGenRooms() {
  const src = read('tools/gen_rooms.js');
  const out = {};
  const re = /room\(\s*'([^']+)',\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)/g;
  let m;
  while ((m = re.exec(src))) {
    out[m[1]] = { ix0: +m[2], iy0: +m[3], ix1: +m[4], iy1: +m[5] };
  }
  return out;
}

// ---- 4. baked .map: worldspawn floor slabs (generic axis-aligned brush AABB) --
function parseWorldspawnBrushes(src) {
  const lines = src.split(/\r?\n/);
  let depth = 0, entIndex = -1, inWS = false, cur = null;
  const brushes = [];
  for (const raw of lines) {
    const t = raw.trim();
    if (t === '{') {
      depth++;
      if (depth === 1) { entIndex++; inWS = (entIndex === 0); }
      else if (depth === 2 && inWS) cur = { planes: [] };
      continue;
    }
    if (t === '}') {
      if (depth === 2 && inWS && cur) { brushes.push(cur); cur = null; }
      depth--;
      continue;
    }
    if (depth === 2 && inWS && cur && t.startsWith('(')) cur.planes.push(t);
  }
  return brushes;
}
function brushAABB(brush) {
  const xs = [], ys = [], zs = [];
  for (const pl of brush.planes) {
    const m = pl.match(/^\(\s*([^)]+?)\s*\)\s*\(\s*([^)]+?)\s*\)\s*\(\s*([^)]+?)\s*\)/);
    if (!m) continue;
    const pts = [m[1], m[2], m[3]].map((s) => s.trim().split(/\s+/).map(Number));
    if (pts.some((p) => p.length < 3 || p.some(Number.isNaN))) continue;
    for (const axis of [0, 1, 2]) {
      const [a, b, c] = [pts[0][axis], pts[1][axis], pts[2][axis]];
      if (Math.abs(a - b) < 1e-6 && Math.abs(b - c) < 1e-6) (axis === 0 ? xs : axis === 1 ? ys : zs).push(a);
    }
  }
  if (!xs.length || !ys.length || !zs.length) return null;
  return { x1: Math.min(...xs), x2: Math.max(...xs), y1: Math.min(...ys), y2: Math.max(...ys), z1: Math.min(...zs), z2: Math.max(...zs) };
}

// =============================================================================
// run the checks
// =============================================================================
const greybox = parseGreyboxRooms();
const design = parseDesignRooms();
const genrooms = parseGenRooms();

const mapSrc = read('map_source/zm/zm_abandoned_cyber_city.map');
const wsBrushes = parseWorldspawnBrushes(mapSrc);
const allBoxes = wsBrushes.map(brushAABB).filter(Boolean);
const floorBoxes = allBoxes
  .filter((b) => eq(b.z1, sot.wall.floorBottom) && eq(b.z2, sot.wall.floorTop))
  .map((b) => ({ ...b, cx: (b.x1 + b.x2) / 2, cy: (b.y1 + b.y2) / 2 }));

// Match a baked brush by full AABB (all 6 faces). Baked boxes come pre-normalized
// (brushAABB uses min/max), so pass a normalized expected box.
const box6Eq = (a, b) => eq(a.x1, b.x1) && eq(a.x2, b.x2) && eq(a.y1, b.y1) &&
  eq(a.y2, b.y2) && eq(a.z1, b.z1) && eq(a.z2, b.z2);
const findBox6 = (b) => allBoxes.find((x) => box6Eq(x, b));

// A trench zone's floor is split into 3 baked slabs (see rooms.json "trenches").
function checkTrenchSlabs(zone, want, tr) {
  const fb = sot.wall.floorTop; // 0
  const slabs = {
    'south slab': { x1: want.x1, x2: want.x2, y1: want.y1, y2: tr.y1, z1: tr.slabBottom, z2: fb },
    'north slab': { x1: want.x1, x2: want.x2, y1: tr.y2, y2: want.y2, z1: tr.slabBottom, z2: fb },
    'trench floor': { x1: want.x1, x2: want.x2, y1: tr.y1, y2: tr.y2, z1: tr.slabBottom, z2: tr.floorZ },
  };
  // norm() only orders x/y; keep z (min/max) so box6Eq's z compare is defined.
  const normZ = (b) => ({ ...norm(b), z1: Math.min(b.z1, b.z2), z2: Math.max(b.z1, b.z2) });
  for (const [label, b] of Object.entries(slabs)) {
    const want6 = normZ(b);
    if (findBox6(want6)) ok(`.map ${zone} trench ${label}`);
    else err(`.map ${zone} trench ${label}: no baked brush matching ${fmt(want6)} z[${want6.z1},${want6.z2}]`);
  }
}

for (const [zone, r] of Object.entries(sot.rooms)) {
  if (typeof r !== 'object' || !r.outer) continue;
  const want = norm(r.outer);

  // 2. gen_map_design (all 7)
  if (!design[zone]) err(`gen_map_design.js: missing room for ${zone}`);
  else if (!boxEq(design[zone], want)) err(`gen_map_design.js ${zone} = ${fmt(design[zone])} != SoT ${fmt(want)}`);
  else ok(`gen_map_design.js ${zone}`);

  // 1. gen_zone_greybox (6 - start excluded)
  if (r.inGenZoneGreybox) {
    const g = greybox[r.shortName];
    if (!g) err(`gen_zone_greybox.js: missing room '${r.shortName}' (${zone})`);
    else if (!boxEq(g, want)) err(`gen_zone_greybox.js ${r.shortName} = ${fmt(g)} != SoT ${fmt(want)}`);
    else ok(`gen_zone_greybox.js ${r.shortName}`);
  } else if (greybox[r.shortName]) {
    warn(`gen_zone_greybox.js unexpectedly defines '${r.shortName}' (${zone} marked inGenZoneGreybox:false)`);
  }

  // 4. baked .map floor slab
  const tr = sot.trenches && sot.trenches[r.shortName];
  if (tr) {
    // Trench zone: the single floor slab was replaced by south/north/trench
    // slabs (rooms.json "trenches"). Verify those instead.
    checkTrenchSlabs(zone, want, tr);
  } else {
    const exact = floorBoxes.find((b) => boxEq(b, want));
    if (exact) {
      ok(`.map floor ${zone}`);
    } else {
      const inside = floorBoxes.filter((b) => b.cx > want.x1 && b.cx < want.x2 && b.cy > want.y1 && b.cy < want.y2);
      if (inside.length) err(`.map ${zone}: no floor slab matching SoT ${fmt(want)}; nearest candidate ${fmt(inside[0])}`);
      else warn(`.map ${zone}: no z[${sot.wall.floorBottom},${sot.wall.floorTop}] floor slab found at SoT footprint ${fmt(want)} (start uses the original template floor; verify manually)`);
    }

    // informational: extra overlapping floor shells inside this room
    const overlapping = floorBoxes.filter((b) => b.cx > want.x1 && b.cx < want.x2 && b.cy > want.y1 && b.cy < want.y2 && !boxEq(b, want));
    if (overlapping.length) warn(`.map ${zone}: ${overlapping.length} extra overlapping floor shell(s) inside the room (e.g. ${fmt(overlapping[0])}) - see genRoomsShells conflict in rooms.json`);
  }
}

// 3. gen_rooms shells (vault/roof) vs SoT genRoomsShells
for (const [zone, s] of Object.entries(sot.genRoomsShells || {})) {
  if (zone.startsWith('_')) continue;
  const g = genrooms[s.label];
  if (!g) { err(`gen_rooms.js: missing room('${s.label}', ...)`); continue; }
  const i = s.genRoomsInterior;
  if (eq(g.ix0, i.ix0) && eq(g.iy0, i.iy0) && eq(g.ix1, i.ix1) && eq(g.iy1, i.iy1)) ok(`gen_rooms.js '${s.label}' shell`);
  else err(`gen_rooms.js '${s.label}' = (${g.ix0},${g.iy0},${g.ix1},${g.iy1}) != SoT genRoomsInterior (${i.ix0},${i.iy0},${i.ix1},${i.iy1})`);

  // confirm the baked shell floor matches bakedOuter
  const bo = norm(s.bakedOuter);
  if (floorBoxes.find((b) => boxEq(b, bo))) ok(`.map gen_rooms shell floor ${zone}`);
  else warn(`.map: no floor slab matching ${s.label} gen_rooms shell bakedOuter ${fmt(bo)}`);
}

// 5. PaP origin: 2 literals must equal SoT papOrigin
const pap = sot.papOrigin;
{
  // Path corrected 2026-07-15 (audit): the generator was moved to tools/oneshots/ but this read()
  // still pointed at tools/ - an ENOENT throw that failed the whole room-geometry lint (and so
  // preflight) on every run.
  const am = read('tools/oneshots/apply_entity_moves.js');
  const m = am.match(/'122366A5-BD0F-46AD-B3E5-59AF52D4A611':\s*\{\s*origin:\s*'(-?[\d.]+) (-?[\d.]+) (-?[\d.]+)'/);
  if (!m) err('apply_entity_moves.js: could not find the PaP-prefab move origin');
  else if (eq(+m[1], pap.x) && eq(+m[2], pap.y) && eq(+m[3], pap.z)) ok('apply_entity_moves.js PaP origin');
  else err(`apply_entity_moves.js PaP origin = (${m[1]},${m[2]},${m[3]}) != SoT (${pap.x},${pap.y},${pap.z})`);
}
{
  const pi = read('scripts/zm/zm_abandoned_cyber_city/_acc_perk_info.gsc');
  const m = pi.match(/pap_org\s*=\s*\(\s*(-?[\d.]+),\s*(-?[\d.]+),\s*(-?[\d.]+)\s*\)/);
  if (!m) err('_acc_perk_info.gsc: could not find the pap_org fallback literal');
  else if (eq(+m[1], pap.x) && eq(+m[2], pap.y) && eq(+m[3], pap.z)) ok('_acc_perk_info.gsc PaP fallback origin');
  else err(`_acc_perk_info.gsc pap_org = (${m[1]},${m[2]},${m[3]}) != SoT (${pap.x},${pap.y},${pap.z})`);
}

// ---- report -----------------------------------------------------------------
console.log(`validate_rooms: ${oks.length} ok, ${warns.length} warn, ${errors.length} error (SoT: source_data/rooms.json)`);
for (const w of warns) console.log(`  WARN  ${w}`);
for (const e of errors) console.log(`  ERROR ${e}`);
if (errors.length) {
  console.log('FAIL - a room-geometry copy diverged from source_data/rooms.json. Sync it (edit the SoT first), then re-run.');
  process.exit(1);
}
console.log('PASS - all room-geometry copies agree with the source of truth.');
