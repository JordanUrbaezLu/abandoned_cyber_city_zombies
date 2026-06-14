#!/usr/bin/env node
// apply_zone_materials.js - ONE-SHOT per-zone material pass (docs/29 Phase 2, §12.1).
//
// The global Phase-1 flip painted every wall face with one dark concrete and every
// floor with one wet concrete. This tool differentiates the 7 zones: it classifies
// each FACE by its own centroid (nearest zone center, from the zones' spawn risers)
// and swaps the GLOBAL wall/floor material token for that zone's material.
//
// Why PER-FACE (not per-brush): the greybox uses large brushes that span multiple
// zones (one wall brush can have faces from x=86 to x=2519), so a brush-centroid
// classification lumps big shared walls into one zone. Classifying each face by its
// own position localizes the skin correctly. LIMITATION: a single large face that
// itself spans zones (e.g. one big floor quad) still gets one material by its
// centroid - truly per-zone floors need the brush split in Radiant.
//
// SAFE: only rewrites face lines whose material is exactly the current global
// wall/floor token (tool textures, info_volume "volume" faces, clips, probes are
// untouched); never edits coordinates -> geometry is byte-identical. All target
// material names are byte-verified present in the stock t7_*.gdt files.
//
// Usage: node tools/apply_zone_materials.js   (from repo root; edits the .map in place)

const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

const GLOBAL_WALL  = 't7_concrete_bare_weathered_01_dark';
const GLOBAL_FLOOR = 't7_concrete_floor_garage_cracked_wet_nw';

// Zone centers = avg of each zone's spawn risers (verified from the .map). Walls/
// floors are byte-verified stock t7 materials chosen per the zone moods in docs/29 §5.
const ZONES = [
  { name: 'spawn',  cx: -228,  cy: 212,  wall: 't7_concrete_bare_weathered_01_dark',         floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'market', cx: -1881, cy: 940,  wall: 't7_brick_worn_dirty_red_wet',                floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'alley',  cx: 1920,  cy: 900,  wall: 't7_metal_painted_wall_dirty_black',          floor: 't7_asphalt_damaged_dark_wet_nw' },
  { name: 'corp',   cx: 79,    cy: 1948, wall: 't7_metal_panel_2x1_stainless_steel_matte',   floor: 't7_concrete_floor_garage_cracked_wet_nw' },
  { name: 'vault',  cx: 1719,  cy: 2800, wall: 't7_metal_painted_wall_dirty_grey',           floor: 't7_metal_grate_flooring' },
  { name: 'roof',   cx: -1719, cy: 2740, wall: 't7_concrete_bare_weathered_01',              floor: 't7_asphalt_damaged_dark_wet' },
  { name: 'lab',    cx: 19,    cy: 3648, wall: 't7_metal_panel_2x1_stainless_steel_brushed', floor: 't7_metal_floor_lab_panels' },
];

function nearestZone(x, y) {
  let best = ZONES[0], bestD = Infinity;
  for (const z of ZONES) {
    const d = (x - z.cx) ** 2 + (y - z.cy) ** 2;
    if (d < bestD) { bestD = d; best = z; }
  }
  return best;
}

// Face line: ( x y z ) ( x y z ) ( x y z ) <material> <uv...> lightmap_gray <...>
const FACE_RE = /^(\s*\([^)]*\)\s*\([^)]*\)\s*\([^)]*\)\s+)(\S+)(\s+.*)$/;
const POINT_RE = /\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/g;

const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const counts = {};
ZONES.forEach(z => counts[z.name] = { wall: 0, floor: 0 });
let totalWall = 0, totalFloor = 0;

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(FACE_RE);
  if (!m) continue;
  const isWall = m[2] === GLOBAL_WALL;
  const isFloor = m[2] === GLOBAL_FLOOR;
  if (!isWall && !isFloor) continue;

  // centroid of this face's 3 plane points
  let p, sx = 0, sy = 0, n = 0; POINT_RE.lastIndex = 0;
  while ((p = POINT_RE.exec(lines[i])) !== null) { sx += parseFloat(p[1]); sy += parseFloat(p[2]); n++; }
  if (n === 0) continue;
  const z = nearestZone(sx / n, sy / n);

  if (isWall)  { lines[i] = m[1] + z.wall  + m[3]; counts[z.name].wall++;  totalWall++;  }
  else         { lines[i] = m[1] + z.floor + m[3]; counts[z.name].floor++; totalFloor++; }
}

fs.writeFileSync(MAP, lines.join('\n'));

console.log(`wall faces re-skinned: ${totalWall}  |  floor faces re-skinned: ${totalFloor}`);
for (const z of ZONES) console.log(`  ${z.name.padEnd(7)} wall=${counts[z.name].wall}  floor=${counts[z.name].floor}  (${z.wall} / ${z.floor})`);
