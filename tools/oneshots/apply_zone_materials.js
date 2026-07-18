#!/usr/bin/env node
// apply_zone_materials.js - per-zone wall/floor materials (docs/29 Phase 2, §12.1).
//
// Classifies each wall/floor FACE by its own position (nearest zone center) and
// assigns that zone's stock material. Re-runnable / idempotent: it matches ANY
// material in WALL_SET/FLOOR_SET (old + current names) and rewrites to the chosen
// valid material, so it corrects earlier passes too.
//
// CRITICAL (learned the hard way): the assigned names MUST be real
// `( "material.gdf" )` definitions in a stock GDT - NOT image/variant names like
// `..._dark` / `..._nw` / `..._black`, which are textures, not materials, and
// render as the missing-material checker. AND every stock material used on a face
// must get a `material,<name>` line in the .zone (run tools/gen_material_zone.js or
// see docs/29 §12.1) or it won't be packed into the usermap .ff -> also checker.
//
// Usage: node tools/apply_zone_materials.js   (from repo root; edits .map in place)

const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// All wall / floor material names that may currently be on faces (old invalid +
// new valid) - so a re-run reclassifies cleanly. Sets are disjoint.
const WALL_SET = new Set([
  't7_concrete_bare_weathered_01_dark', 't7_concrete_bare_weathered_01', 't7_concrete_bare_dark_01',
  't7_brick_worn_dirty_red_wet', 't7_metal_painted_wall_dirty_black', 't7_metal_painted_wall_dirty_grey',
  't7_metal_panel_2x1_stainless_steel_matte', 't7_metal_panel_2x1_stainless_steel_brushed',
  't7_metal_bare_stainless_steel_brushed', 't7_metal_diamond_plate_panel_worn',
]);
const FLOOR_SET = new Set([
  't7_concrete_floor_garage_cracked_wet_nw', 't7_asphalt_damaged_dark_wet', 't7_asphalt_damaged_dark_wet_nw',
  't7_metal_grate_flooring', 't7_metal_floor_lab_panels',
]);

// Zone centers = avg spawn risers. Walls/floors are VALID stock material.gdf
// definitions (verified) chosen per the docs/29 §5 moods.
const ZONES = [
  { name: 'spawn',  cx: -228,  cy: 212,  wall: 't7_concrete_bare_dark_01',              floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'market', cx: -1881, cy: 940,  wall: 't7_brick_worn_dirty_red_wet',           floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'alley',  cx: 1920,  cy: 900,  wall: 't7_metal_painted_wall_dirty_grey',      floor: 't7_asphalt_damaged_dark_wet' },
  { name: 'corp',   cx: 79,    cy: 1948, wall: 't7_metal_bare_stainless_steel_brushed', floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'vault',  cx: 1719,  cy: 2800, wall: 't7_metal_diamond_plate_panel_worn',     floor: 't7_metal_grate_flooring' },
  { name: 'roof',   cx: -1719, cy: 2740, wall: 't7_concrete_bare_weathered_01',         floor: 't7_asphalt_damaged_dark_wet' },
  { name: 'lab',    cx: 19,    cy: 3648, wall: 't7_metal_bare_stainless_steel_brushed', floor: 't7_metal_floor_lab_panels' },
];

function nearestZone(x, y) {
  let best = ZONES[0], bestD = Infinity;
  for (const z of ZONES) { const d = (x - z.cx) ** 2 + (y - z.cy) ** 2; if (d < bestD) { bestD = d; best = z; } }
  return best;
}

const FACE_RE = /^(\s*\([^)]*\)\s*\([^)]*\)\s*\([^)]*\)\s+)(\S+)(\s+.*)$/;
const POINT_RE = /\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/g;

const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const counts = {}; ZONES.forEach(z => counts[z.name] = { wall: 0, floor: 0 });
let totalWall = 0, totalFloor = 0;

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) continue;
  const isWall = WALL_SET.has(m[2]), isFloor = FLOOR_SET.has(m[2]);
  if (!isWall && !isFloor) continue;
  let p, sx = 0, sy = 0, n = 0; POINT_RE.lastIndex = 0;
  while ((p = POINT_RE.exec(lines[i])) !== null) { sx += parseFloat(p[1]); sy += parseFloat(p[2]); n++; }
  if (n === 0) continue;
  const z = nearestZone(sx / n, sy / n);
  if (isWall) { lines[i] = m[1] + z.wall + m[3]; counts[z.name].wall++; totalWall++; }
  else        { lines[i] = m[1] + z.floor + m[3]; counts[z.name].floor++; totalFloor++; }
}

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`wall faces: ${totalWall}  |  floor faces: ${totalFloor}`);
for (const z of ZONES) console.log(`  ${z.name.padEnd(7)} wall=${counts[z.name].wall} floor=${counts[z.name].floor}  (${z.wall} / ${z.floor})`);
