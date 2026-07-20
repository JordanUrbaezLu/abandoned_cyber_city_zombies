#!/usr/bin/env node
// =============================================================================
// paint_p1_zones_t10.js  (ONE-SHOT, marker-guarded - refuses re-apply)
//
// P1 texture batch (2026-07-18): repaint PLAZA + MARKET + ALLEY with the BO6
// `t10_materials.gdt` material language, riding the three mechanisms P0 proved
// (tools/oneshots/paint_bus_station_t10.js + docs/20 s.14b): decal-on-face is
// LEGAL, emissive chalk-mesh strips convert, face tokens need NO .zone line.
// Region boxes are paint_region.js's authoritative zone AABBs; FROM tokens are
// the per-zone materials paint_region assigned, so every swap is token-keyed
// AND region-bounded (kills the Plaza/Helipad shared-token problem: the Helipad
// floor also wears the plaza wall token, but sits at y>=2255, far outside the
// plaza box).
//
// PLAZA (box x[-1050,1090] y[-560,760]; wall z band extended to 500 to take the
// ARMORY upper room, which was authored in the plaza wall token - gen_upper_
// room.js, loft ceiling z464 - and is repainted WITH the plaza for consistency):
//   WALLS  t7_concrete_wall_weathered_01_wet -> t10_concrete_base_wall_02_dirty
//          whole-brush (38 brushes: greybox 21-24/29/30, the 12 shrink walls,
//          bench wall, 4 basement staircase shells, 16 ARMORY brushes). The
//          FRAG-chalk wallbuy mesh backs brush 22 (the whole 2150u N wall,
//          face y720) - repainted TOO: the chalk quad floats 2u proud and
//          renders over any wall, and excluding it would seam the entire N
//          wall (P0's POWER-wall exclusions were a breadcrumb design choice,
//          not a mechanism requirement). ARMORY stair treads + floor keep
//          their global-asphalt look (out of scope, reported).
//   FLOOR  face-level z0 TOP faces only (P0 discipline - slab sides/bottoms
//          stay t7 so the basement ceiling under the plaza is untouched):
//          W/E/N arena slabs -> t10_concrete_pavement_01.
//   DECALS (accents on SMALL faces only - a decal token REPLACES the face):
//          1. SOUTH arena slab z0 top (240x120, the spawn-stub floor patch by
//             the basement stair mouth) -> t10_terrain_decal_crack_asphalt_03
//             (already referenced by P0's corp rim strip = zero new xpak cost).
//          2. Shrink-wall LINTEL y=-240 face (80x128, over the spawn->plaza
//             doorway) -> t10_dirt_grunge_leaking_02 (leak streaks).
//          No curb/edge-strip brushes exist in the plaza - these two are the
//          only small distinct faces available.
// MARKET (box x[-2165,-785] y[355,1565]):
//   WALLS  t7_metal_paint_rust_brown -> t10_brick_worn_modern_01, WALL brushes
//          only (isWall) - the 3 ceiling slabs (market + c_sp_mkt + c_mkt_corp,
//          z[256,272]) KEEP rust (corrugated-roof read; the P1 brief only
//          re-languages the walls). Includes the c_sp_mkt / c_mkt_corp corridor
//          walls (rust, market-owned per paint_region region order).
//   FLOOR  z0 TOP faces of the 3 tile slabs (main + 2 corridor floors) ->
//          t10_linoleum_tile_dirty_03.
//   GLAZED t10_brick_wall_tile_01_red band: SKIPPED - no separate stall-front
//          low brushes exist (stalls are props; P0's wainscot limit: a token
//          swap cannot split a face).
//   STRIP  ONE emissive chalk-mesh quad (ACCC0010 recipe clone, guid ACCC0011)
//          mwiii_vertigo_retro_synth_pink_tinted (verified in source_data\
//          _emox\emox_mwiii_vertigo_assets.gdt) on the N wall (face y1476,
//          quad 2u proud at y1474), x[-2010,-1730] z[200,228] - directly above
//          the kiosk island (-1870,1220); nearest M3 signage is the neon DINER
//          sign at x-1560 (170u clear), light_cage at (-1720,1150,232) is 324u
//          off the wall plane. -y normal => cols Xmin->Xmax (winding proven by
//          the ACCC0006 y1701 POWER arrows).
// ALLEY (box x[815,2255] y[355,1565]):
//   WALLS  KEEP t7_metal_painted_wall_dirty_black (the black metal IS the
//          hazard identity - no wall swap).
//   FLOOR  z0 TOP faces of the 3 asphalt slabs (main + c_sp_al + c_al_corp
//          corridor floors, the global asphalt paint_region left in this zone)
//          -> t10_asphalt_crack_02_worn.
//   DECAL  oil stain SKIPPED - no small distinct asphalt floor face exists
//          (slabs are 880x1136 / 225x256 / 500x256; skinning a whole corridor
//          floor as a decal violates the small-face rule).
//   STRIP  ONE emissive chalk-mesh quad (guid ACCC0012)
//          mwiii_vertigo_retro_synth_red_tinted_edge (verified, the _tinted_
//          edge variant exists in the emox GDT) on the E wall (face x2179.5 -
//          NOTE: the real E wall plane; the M3 "E wall" prop origins sit at
//          x<=1966, so the face is completely bare), quad 2u proud at x2177.5,
//          y[440,720] z[192,220] - the AC-unit/dumpster corner lane. -x normal
//          => cols Ymax->Ymin (winding proven by the ACCC000B x685 arrows).
//
// VK OPTION: declined - the BO6 t10 picks are P0-proven and cohesive; every VK
// candidate needs per-material baseImage provenance tracing (docs/20 s.14b: the
// library mixes CC0 cgbookcase_*/texturehaven_* with unshippable TexturesCom_*).
//
// EXCLUDED by construction: buyable doors (entities - worldspawn-only walk),
// clip/chalk/decal faces (token-keyed swaps can't match them), perk/box areas
// (no dedicated brushes wear the FROM tokens there), the under-level (face-
// level floor swaps + region z bands).
//
// Face tokens + mesh materials need NO .zone line (transitive - docs/20 s.3).
// Token swaps change NO windings; the 2 strip meshes are new (nonColliding)
// geometry cloned from a bake-proven donor -> FULL build + LED bake gate.
// =============================================================================
'use strict';
const fs = require('fs');

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const MARKER = 'ACC P1 ZONES T10 REPAINT';

// FROM tokens (paint_region.js assignments)
const FROM_PLAZA_WALL  = 't7_concrete_wall_weathered_01_wet';
const FROM_PLAZA_FLOOR = 't7_concrete_floor_garage_cracked_wet_nw';
const FROM_MKT_WALL    = 't7_metal_paint_rust_brown';
const FROM_MKT_FLOOR   = 't7_concrete_tiles_2x2_dirty_01_wet';
const FROM_ALLEY_FLOOR = 't7_asphalt_damaged_dark_wet';

// TO tokens (all verified present in the installed GDTs 2026-07-18)
const TO_PLAZA_WALL  = 't10_concrete_base_wall_02_dirty';
const TO_PLAZA_FLOOR = 't10_concrete_pavement_01';
const TO_MKT_WALL    = 't10_brick_worn_modern_01';
const TO_MKT_FLOOR   = 't10_linoleum_tile_dirty_03';
const TO_ALLEY_FLOOR = 't10_asphalt_crack_02_worn';
const TO_DECAL_CRACK = 't10_terrain_decal_crack_asphalt_03';   // P0-proven, already in map (corp rim)
const TO_DECAL_LEAK  = 't10_dirt_grunge_leaking_02';
const TO_STRIP_MKT   = 'mwiii_vertigo_retro_synth_pink_tinted';
const TO_STRIP_ALLEY = 'mwiii_vertigo_retro_synth_red_tinted_edge';

// paint_region.js zone AABBs (authoritative). Plaza wall z2 extended 300->500
// for the ARMORY upper room (loft ceiling z[448,464]); nothing else lives in
// that x/y box above z300.
const PLAZA  = { x1: -1050, x2: 1090,  y1: -560, y2: 760,  z1: -30, z2: 500 };
const MARKET = { x1: -2165, x2: -785,  y1: 355,  y2: 1565, z1: -30, z2: 300 };
const ALLEY  = { x1: 815,   x2: 2255,  y1: 355,  y2: 1565, z1: -30, z2: 300 };

const SIG = (b) => b.join(',');
// floor slabs: z0 TOP face only ({sig -> to})
const FLOOR_TOPS = {
  [SIG([-1056, -620, -560, 740, -16, 0])]:   { from: FROM_PLAZA_FLOOR, to: TO_PLAZA_FLOOR, tag: 'plaza floor' },  // arena W
  [SIG([-380, 1094.5, -560, 740, -16, 0])]:  { from: FROM_PLAZA_FLOOR, to: TO_PLAZA_FLOOR, tag: 'plaza floor' },  // arena E
  [SIG([-620, -380, -312, 740, -16, 0])]:    { from: FROM_PLAZA_FLOOR, to: TO_PLAZA_FLOOR, tag: 'plaza floor' },  // arena N
  [SIG([-620, -380, -560, -440, -16, 0])]:   { from: FROM_PLAZA_FLOOR, to: TO_DECAL_CRACK, tag: 'plaza DECAL crack' }, // arena S (accent 1)
  [SIG([-2161, -1281, 360, 1496, -16, 0])]:  { from: FROM_MKT_FLOOR,   to: TO_MKT_FLOOR,   tag: 'market floor' }, // market main
  [SIG([-1281, -1056, 400, 656, -16, 0])]:   { from: FROM_MKT_FLOOR,   to: TO_MKT_FLOOR,   tag: 'market floor' }, // c_sp_mkt
  [SIG([-1281, -781, 1200, 1456, -16, 0])]:  { from: FROM_MKT_FLOOR,   to: TO_MKT_FLOOR,   tag: 'market floor' }, // c_mkt_corp
  [SIG([1319.5, 2199.5, 360, 1496, -16, 0])]:{ from: FROM_ALLEY_FLOOR, to: TO_ALLEY_FLOOR, tag: 'alley floor' },  // alley main
  [SIG([1094.5, 1319.5, 400, 656, -16, 0])]: { from: FROM_ALLEY_FLOOR, to: TO_ALLEY_FLOOR, tag: 'alley floor' },  // c_sp_al
  [SIG([819, 1319.5, 1200, 1456, -16, 0])]:  { from: FROM_ALLEY_FLOOR, to: TO_ALLEY_FLOOR, tag: 'alley floor' },  // c_al_corp
};
// shrink-wall LINTEL over the spawn->plaza doorway: y=-240 face = leak accent
const LINTEL_SIG = SIG([-260, -180, -260, -240, 128, 256]);

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function faceAxis(p1, p2, p3) {
  for (const [ax, name] of [[0, 'x'], [1, 'y'], [2, 'z']])
    if (p1[ax] === p2[ax] && p2[ax] === p3[ax]) return { axis: name, off: p1[ax] };
  return { axis: null, off: 0 };
}
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const inBox = (r, cx, cy, cz) => cx >= r.x1 && cx <= r.x2 && cy >= r.y1 && cy <= r.y2 && cz >= r.z1 && cz <= r.z2;
const isWall = (b) => (b[5] - b[4]) > Math.min(b[1] - b[0], b[3] - b[2]);

const lines = fs.readFileSync(MAP, 'utf8').split('\n');

// ---- ONE-SHOT GUARD ---------------------------------------------------------
const NEW_TOKENS = [TO_PLAZA_WALL, TO_PLAZA_FLOOR, TO_MKT_WALL, TO_MKT_FLOOR,
  TO_ALLEY_FLOOR, TO_DECAL_LEAK, TO_STRIP_MKT, TO_STRIP_ALLEY, 'ACCC0011', 'ACCC0012'];
const guardRe = new RegExp('\\b(' + NEW_TOKENS.map(esc).join('|') + ')\\b');
if (lines.some(l => l.includes(MARKER) || guardRe.test(l))) {
  console.error('paint_p1_zones_t10: already applied (marker/new token/guid present) - refusing.');
  process.exit(1);
}

// ---- pass 1: brush walk (worldspawn only) -----------------------------------
let depth = 0, entIdx = -1, brush = null;
const counts = {};
const bump = (k, n) => { counts[k] = (counts[k] || 0) + (n || 1); };
const linePlan = new Map();          // lineIdx -> { from, to }

for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) {
    if (depth === 0) entIdx++;
    if (depth === 1 && entIdx === 0) brush = { start: i, faces: [] };
    depth++;
  }
  const m = lines[i].match(FACE_RE);
  if (m && brush) brush.faces.push({ line: i, mat: m[10], a: faceAxis([+m[1],+m[2],+m[3]], [+m[4],+m[5],+m[6]], [+m[7],+m[8],+m[9]]) });
  for (let c = 0; c < closes; c++) {
    depth--;
    if (depth === 1 && entIdx === 0 && brush) {
      const ax = { x: [], y: [], z: [] };
      for (const f of brush.faces) if (f.a.axis) ax[f.a.axis].push(f.a.off);
      if (ax.x.length && ax.y.length && ax.z.length) {
        const b = [Math.min(...ax.x), Math.max(...ax.x), Math.min(...ax.y), Math.max(...ax.y), Math.min(...ax.z), Math.max(...ax.z)];
        const cx = (b[0] + b[1]) / 2, cy = (b[2] + b[3]) / 2, cz = (b[4] + b[5]) / 2;
        const sig = SIG(b);
        if (FLOOR_TOPS[sig]) {
          // FLOOR: z0 TOP face only (sides/bottoms stay t7 - under-level untouched)
          const t = FLOOR_TOPS[sig];
          for (const f of brush.faces) if (f.a.axis === 'z' && f.a.off === 0 && f.mat === t.from) { linePlan.set(f.line, { from: t.from, to: t.to }); bump(t.tag + ' -> ' + t.to); }
        } else if (sig === LINTEL_SIG) {
          // LINTEL: y=-240 face = leak accent, the rest = plaza wall
          for (const f of brush.faces) if (f.mat === FROM_PLAZA_WALL) {
            const to = (f.a.axis === 'y' && f.a.off === -240) ? TO_DECAL_LEAK : TO_PLAZA_WALL;
            linePlan.set(f.line, { from: FROM_PLAZA_WALL, to });
            bump((to === TO_DECAL_LEAK ? 'plaza DECAL leak -> ' : 'plaza wall -> ') + to);
          }
        } else if (inBox(PLAZA, cx, cy, cz)) {
          // PLAZA WALLS (incl. ARMORY upper room + FRAG-chalk N wall brush 22)
          for (const f of brush.faces) if (f.mat === FROM_PLAZA_WALL) { linePlan.set(f.line, { from: FROM_PLAZA_WALL, to: TO_PLAZA_WALL }); bump('plaza wall -> ' + TO_PLAZA_WALL); }
        } else if (inBox(MARKET, cx, cy, cz) && isWall(b)) {
          // MARKET WALLS (vertical brushes only - the 3 rust ceilings keep rust)
          for (const f of brush.faces) if (f.mat === FROM_MKT_WALL) { linePlan.set(f.line, { from: FROM_MKT_WALL, to: TO_MKT_WALL }); bump('market wall -> ' + TO_MKT_WALL); }
        }
        // ALLEY: floors are SIG-targeted above; walls deliberately keep
        // t7_metal_painted_wall_dirty_black (hazard identity).
        if (inBox(MARKET, cx, cy, cz) && !isWall(b) && brush.faces.some(f => f.mat === FROM_MKT_WALL))
          bump('EXCLUDED market ceiling slab (kept ' + FROM_MKT_WALL + ')');   // 3 brushes on the applied run
      }
      brush = null;
    }
  }
}

// ---- pass 2: apply token swaps ----------------------------------------------
let swapped = 0;
for (const [li, plan] of linePlan) {
  const re = new RegExp('\\b' + esc(plan.from) + '\\b');
  if (!re.test(lines[li])) { console.error(`paint_p1_zones_t10: line ${li + 1} lost its ${plan.from} token - aborting, nothing written.`); process.exit(1); }
  lines[li] = lines[li].replace(re, plan.to);
  swapped++;
}

// ---- pass 3: insert the two emissive strip meshes ---------------------------
// VERBATIM structural clones of the proven arrow/ACCC0010 chalk meshes
// (contents nonColliding + lightmap_gray + 2x2 mesh, donor lightmap floats).
const stripAnchor = lines.findIndex(l => l.includes('>>> ACC HUB WORLDSPAWN'));
if (stripAnchor < 0) { console.error('paint_p1_zones_t10: strip anchor comment not found - aborting, nothing written.'); process.exit(1); }
const strips = [
  `// ===== ${MARKER} (P1 batch, 2026-07-18) =====`,
  '// Market neon band: synth-pink strip on the market N wall (face y1476) above the',
  '// kiosk island (-1870,1220); clear of all M3 signage (nearest = DINER sign x-1560).',
  '// -y normal => cols Xmin->Xmax (ACCC0006 donor winding).',
  ' {',
  '  guid "{ACCC0011-0000-4DE1-8A3F-1F00ACCC0011}"',
  '  mesh',
  '  {',
  '  contents nonColliding;',
  '  toolFlags;',
  `   ${TO_STRIP_MKT}`,
  '   lightmap_gray',
  '   2 2 0 8',
  '   (',
  '\tv -2010 1474 200 t 0 -0 -1.0001428 -6.7082205',
  '\tv -2010 1474 228 t 0 -1024 -0.99985725 -9.0415535',
  '   )',
  '   (',
  '\tv -1730 1474 200 t 1024 -0 0.87485725 -6.7084455',
  '\tv -1730 1474 228 t 1024 -1024 0.87514287 -9.0417786',
  '   )',
  '  }',
  ' }',
  '// Alley hazard band: synth-red edge strip on the alley E wall (face x2179.5, bare -',
  '// all M3 "E wall" props sit at x<=1966), above the AC-unit/dumpster lane y[440,720].',
  '// -x normal => cols Ymax->Ymin (ACCC000B donor winding).',
  ' {',
  '  guid "{ACCC0012-0000-4DE1-8A3F-1F00ACCC0012}"',
  '  mesh',
  '  {',
  '  contents nonColliding;',
  '  toolFlags;',
  `   ${TO_STRIP_ALLEY}`,
  '   lightmap_gray',
  '   2 2 0 8',
  '   (',
  '\tv 2177.5 720 192 t 0 -0 -1.0001428 -6.7082205',
  '\tv 2177.5 720 220 t 0 -1024 -0.99985725 -9.0415535',
  '   )',
  '   (',
  '\tv 2177.5 440 192 t 1024 -0 0.87485725 -6.7084455',
  '\tv 2177.5 440 220 t 1024 -1024 0.87514287 -9.0417786',
  '   )',
  '  }',
  ' }',
];
lines.splice(stripAnchor, 0, ...strips);
bump('strip ' + TO_STRIP_MKT + ' (1 mesh)');
bump('strip ' + TO_STRIP_ALLEY + ' (1 mesh)');

fs.writeFileSync(MAP, lines.join('\n'));
console.log('[paint_p1_zones_t10] applied:');
for (const k of Object.keys(counts).sort()) console.log(`  ${k} : ${Math.round(counts[k])}`);
console.log(`  TOTAL token swaps: ${swapped} face lines + 2 inserted meshes`);
console.log('  FULL build + LED bake gate required (strip meshes = new geometry).');
