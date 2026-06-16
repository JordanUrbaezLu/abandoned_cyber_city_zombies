#!/usr/bin/env node
// gen_rooms.js - ONE-SHOT: inject sealed greybox room shells for Vault +
// Helipad into the worldspawn of the .map (docs/29 §13).
//
// WHY: those two zones are fully wired (zone graph, doors+slabs, spawners, power
// switch, wallbuys) but have NO room geometry - opening their doors reveals void.
// This adds a CLOSED box shell (floor + ceiling + 4 walls) per room so the map has
// physical, skinned space there and compiles clean (a closed box cannot leak).
//
// IMPORTANT (finish in Radiant): the boxes are CLOSED - the door openings are NOT
// cut, so the rooms aren't reachable yet. In Radiant, carve a doorway through the
// wall where each sliding slab sits (Vault: west wall ~x984-1000 at y~2480-2540 for
// enter_vault + y~3120-3180 for enter_lab_e; Roof: east wall ~x-1000..-984 at the
// mirror positions), then recompile. Boxes are inset to NOT overlap the door slabs.
//
// Winding is copied verbatim from a known-valid box brush in this map (the
// acc_door_vault slab), so the 6 planes are guaranteed correctly oriented.
// Geometry only - no coordinate guesswork on existing brushes. Build-test after.
//
// Usage: node tools/gen_rooms.js   (from repo root; edits the .map in place, once)

const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

const UV = '128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';

// Axis-aligned solid box [X0,X1]x[Y0,Y1]x[Z0,Z1] (X0<X1, etc.). The 6-plane winding
// matches the verified acc_door_vault slab box exactly.
function box(x0, y0, z0, x1, y1, z1, mat, guid) {
  const P = (ax, ay, az, bx, by, bz, cx, cy, cz) =>
    ` ( ${ax} ${ay} ${az} ) ( ${bx} ${by} ${bz} ) ( ${cx} ${cy} ${cz} ) ${mat} ${UV}`;
  return [
    `{`,
    ` guid "${guid}"`,
    P(x1, y1, z0, x0, y1, z0, x0, y0, z0), // bottom (z=Z0)
    P(x0, y0, z1, x0, y1, z1, x1, y1, z1), // top    (z=Z1)
    P(x0, y0, z1, x1, y0, z1, x1, y0, z0), // -Y     (y=Y0)
    P(x1, y0, z1, x1, y1, z1, x1, y1, z0), // +X     (x=X1)
    P(x1, y1, z1, x0, y1, z1, x0, y1, z0), // +Y     (y=Y1)
    P(x0, y1, z1, x0, y0, z1, x0, y0, z0), // -X     (x=X0)
    `}`,
  ].join('\n');
}

// One closed room = floor + ceiling + 4 perimeter walls (16u thick). Interior is
// [ix0,ix1]x[iy0,iy1]x[0,128]; walls/floor/ceiling wrap it.
function room(label, ix0, iy0, ix1, iy1, wallMat, floorMat, ceilMat, g) {
  const T = 16, H = 128, ox0 = ix0 - T, oy0 = iy0 - T, ox1 = ix1 + T, oy1 = iy1 + T;
  let n = 0; const gid = () => `{ACCB00${(g + (n++)).toString(16).toUpperCase().padStart(2, '0')}-0000-4E0C-8A3F-0000000004A0}`;
  return [
    `// ACC room shell: ${label} (docs/29 §13) - CLOSED box; cut doorways in Radiant`,
    `// brush floor`,    box(ox0, oy0, -16, ox1, oy1, 0,   floorMat, gid()),
    `// brush ceiling`,  box(ox0, oy0, H,   ox1, oy1, H+16, ceilMat,  gid()),
    `// brush wall W`,    box(ox0, oy0, 0,   ix0, oy1, H,   wallMat,  gid()),
    `// brush wall E`,    box(ix1, oy0, 0,   ox1, oy1, H,   wallMat,  gid()),
    `// brush wall S`,    box(ix0, oy0, 0,   ix1, iy0, H,   wallMat,  gid()),
    `// brush wall N`,    box(ix0, iy1, 0,   ix1, oy1, H,   wallMat,  gid()),
  ].join('\n');
}

// Footprints from docs/29 §13 (inset east/west of the door slabs to avoid overlap).
const vault = room('Vault',
  1000, 2490, 2400, 3170,
  't7_metal_painted_wall_dirty_grey', 't7_metal_grate_flooring', 't7_metal_painted_wall_dirty_grey', 0x10);
const roof = room('Helipad',
  -2400, 2490, -1000, 3170,
  't7_concrete_bare_weathered_01', 't7_asphalt_damaged_dark_wet', 't7_concrete_bare_weathered_01', 0x20);

const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

// Re-run guard (docs/36 Stage 0): this script WRITES the .map in place and has
// no idempotency, so a second run double-injects the shells. Refuse if the
// distinctive shell comment is already present.
if (lines.some((l) => l.includes('ACC room shell: Vault'))) {
  console.error('FATAL: room shells already injected (found "ACC room shell: Vault") - refusing to double-inject.');
  process.exit(1);
}

const e1 = lines.indexOf('// entity 1');
if (e1 < 1) { console.error('FATAL: could not find // entity 1 (worldspawn boundary)'); process.exit(1); }
const wsClose = e1 - 1;
if (lines[wsClose].trim() !== '}') { console.error(`FATAL: line before // entity 1 is not '}' (got: ${JSON.stringify(lines[wsClose])})`); process.exit(1); }

// Insert the room brushes just before worldspawn's closing brace.
lines.splice(wsClose, 0, vault, roof);
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`Injected Vault + Roof room shells into worldspawn (before line ${e1}).`);
console.log(`Each room = 6 brushes (floor, ceiling, 4 walls), closed (no door gaps yet).`);
