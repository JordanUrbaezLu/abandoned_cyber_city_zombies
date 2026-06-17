// =============================================================================
// add_ceilings.js  (idempotent - refuses if any ACCCEIL guid already present)
//
// Cap every zone EXCEPT Lab and Plaza with a ceiling, plus the inter-room
// corridors between the capped zones (user 2026-06-17). The Lab and Plaza
// (start) stay open. Safe now that baked LED is abandoned (docs/40): ceilings
// only need cod2map + linker, no lightmapper.
//
// Ceiling = a flat script_floor_ceiling slab spanning each footprint at z[256,272]
// (bottom flush with the z256 wall tops). Footprints from source_data/rooms.json
// (outer = floor extent). Geometry change => FULL build (cod2map + linker, -SkipLED).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

const CEIL_Z1 = 256, CEIL_Z2 = 272;   // 16u slab sitting on top of the z256 walls

// Zone OUTER footprints (rooms.json) to cap. Lab + Plaza (start) EXCLUDED.
const ROOMS = [
  { id: 'market', x1: -1951,  x2: -1281,  y1: 360,  y2: 1496 },
  { id: 'alley',  x1: 1319.5, x2: 1989.5, y1: 360,  y2: 1496 },
  { id: 'corp',   x1: -781,   x2: 819,    y1: 1148, y2: 2748 },
  { id: 'vault',  x1: 1119,   x2: 1744,   y1: 2260, y2: 3400 },
  { id: 'roof',   x1: -1744,  x2: -1119,  y1: 2260, y2: 3400 },
];
// Inter-room corridors between capped zones (NOT the lab/plaza corridors).
const CORRIDORS = [
  { id: 'c_mkt_corp',  x1: -1281, x2: -781,  y1: 1200, y2: 1456 },
  { id: 'c_al_corp',   x1: 819,   x2: 1319.5,y1: 1200, y2: 1456 },
  { id: 'c_corp_vlt',  x1: 819,   x2: 1119,  y1: 2300, y2: 2556 },
  { id: 'c_corp_roof', x1: -1119, x2: -781,  y1: 2300, y2: 2556 },
];

let gc = 0;
function guid() {
  gc++;
  const h = ('ceil' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{ACCCEIL${gc}-${hx.slice(0,4)}-4E11-8A3F-${String(gc).padStart(12, '0')}}`;
}
// Axis-aligned box (verbatim winding from tools/gen_zone_greybox.js box()).
function box(x1, x2, y1, y2, z1, z2) {
  const t = 'script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ];
}

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
if (lines.some(l => l.includes('ACCCEIL'))) {
  console.error('add_ceilings: already applied (ACCCEIL present) - refusing.');
  process.exit(0);
}

// Insert into worldspawn (entity 0): right before "// entity 1".
const idx = lines.findIndex(l => l.trim() === '// entity 1');
if (idx < 0) { console.error('no "// entity 1" marker'); process.exit(1); }

const block = ['// ===== ACC zone ceilings (tools/add_ceilings.js) - all zones except Lab + Plaza ====='];
for (const r of ROOMS.concat(CORRIDORS)) {
  block.push(`// ceiling: ${r.id}`);
  block.push(...box(r.x1, r.x2, r.y1, r.y2, CEIL_Z1, CEIL_Z2));
}
lines.splice(idx - 1, 0, ...block);
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`add_ceilings: added ${ROOMS.length} room + ${CORRIDORS.length} corridor ceilings (z[${CEIL_Z1},${CEIL_Z2}])`);
