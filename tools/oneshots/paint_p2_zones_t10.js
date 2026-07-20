#!/usr/bin/env node
// =============================================================================
// paint_p2_zones_t10.js  (ONE-SHOT, marker-guarded - refuses re-apply)
//
// P2 = FINAL texture batch (2026-07-18): repaint VAULT + HELIPAD + LAB +
// PARADISE + the user-approved ABYSS per-floor bands, riding the P0/P1-proven
// mechanisms (docs/20 s.14b/s.14c): face-token swaps need NO .zone line, decal-
// class materials are legal face tokens, emissive chalk-mesh quads convert.
// Every swap here is SIGNATURE-EXACT (brush bounds from the live .map, verified
// by scan 2026-07-18) + token-keyed + region-asserted + worldspawn-only, so the
// 13 buyable doors / soul doors / corp bridge / perk alcove doors / ec_right_
// wall (all entities) are excluded by construction.
//
// VAULT (x[815,1945] y[2255,3465]):
//   FLOOR  z0 TOP faces of the 3 diamond slabs (main + S corridor + N/lab
//          corridor) t7_metal_diamond_plate_worn_wet -> t10_stone_marble_black_
//          01. THE BATCH'S BIGGEST RISK: the diamond token is shared 4 ways
//          (vault floor / corp bridge / L4 gantry / the 13 repainted buyable
//          doors). Bridge + doors are ENTITIES (excluded); the gantry is
//          worldspawn but at z[-960,-808] (outside every target sig). Safety
//          proof = global diamond count must drop by EXACTLY 3 (verified by
//          verify_p2 diff + the token-count table).
//   WALLS  keep t7_metal_panel_2x1_stainless_steel_brushed (untouched).
// HELIPAD (roof, x[-1945,-785] y[2255,3465]):
//   FLOOR  z0 TOP faces of the 3 weathered-concrete slabs (t7_concrete_wall_
//          weathered_01_wet used as floor) -> t10_asphalt_mid_01. FINDING: NO
//          asphalt-pad brush exists anywhere in the roof region (scanned - the
//          whole floor is the weathered token), so "pad faces keep their token"
//          is vacuous; the pad is INSTEAD drawn by the 3 painted-line marks.
//   MARKS  3 FLAT floor chalk-mesh quads (1u proud @ z1, +z normal winding:
//          cols Xmin->Xmax, rows Ymin->Ymax so du x dv = +z) forming an H in
//          the open E-central bay x[-1344,-1184] y[2400,2560]: uprights
//          t10_terrain_decal_painted_line_solid_single_01 (ACCC0013/14),
//          crossbar t10_terrain_decal_painted_line_thick_02 (ACCC0015 - NOTE:
//          the briefed *_solid_thick_02 name does NOT exist in t10_materials.
//          gdt; thick_02 is the real entry). Clearances verified vs every roof
//          clip + unclipped prop: bomber-wreck clip E edge x-1425 (81u), crate
//          pair y2575 (15u), dry weed x-1360 (16u), E wall x-1139 (45u), the S
//          edge kit y<=2392. No ring-lane obstruction (nonColliding, 1u proud).
//   WALLS  keep t7_concrete_wall_poured_thick_01_wet. Parapet striped band
//          SKIPPED: no separate parapet brushes exist (every roof wall is one
//          full-height z[0,256] brush; s.14b - token swaps cannot split faces).
// LAB (x[-781,819] y[3048,4248]):
//   WALLS  whole-brush hex (t7_zm_der_tile_hexagon) -> t10_concrete_painted_01_
//          white: 6 perimeter wall brushes + the 9 alcove divider fins
//          (x+-604..596 grid, y[4154,4228] z[0,150]). FLOOR + CEILING keep hex
//          (clean-tech read, deliberate). The five-seven wallbuy chalk
//          (ACCC0001, S wall y3070) floats 2u proud and renders over the white
//          (P1 FRAG-wall precedent). The 10 acc_perk_door_* + acc_ec_right_wall
//          are entities - untouched hex on purpose (doors read distinct).
//   STRIPS ACCC0016 mwiii_vertigo_retro_synth_cyan_tinted along the perk-row N
//          wall ABOVE the 10 alcoves: y4226 (2u proud of face y4228), x[-604,
//          604] z[200,228] - fins top at z150, alcove doors z[0,140], machines
//          ~128 tall at y4195: ALL below/clear (verified from the entity scan).
//          ACCC0017 mwiii_vertigo_retro_synth_purple_tinted near the PaP corner
//          on the W wall: x-759 (2u proud of face x-761), y[3580,3860] z[200,
//          228] - the PaP prefab sits at (-700,3700,7.5) ~130u tall, 39u off
//          the wall; the lab Overclock trigger was REMOVED 2026-06-25 (trench-
//          only system) so there is nothing else to clear. +x normal => cols
//          Ymin->Ymax (du x dv rule; donors prove -y/+y/-x, this is the 4th).
// PARADISE (plaza x[-1020,1020] y[-2220,-580] floor top z-1200):
//   ARENA  the single plaza floor slab's z-1200 TOP face hex ->
//          mwiii_vertigo_retro_synth_cyan (BASE cyan, verified as its own
//          material block in emox_mwiii_vertigo_assets.gdt line 3098 - NOT the
//          _tinted variant) = the full emissive neon-grid arena floor. Slab
//          sides/bottom + ALL walls + hall floor/walls KEEP hex. Riser/kiosk/
//          vendor clips are entities (excluded by construction).
//   TRIM   ACCC0018 mwiii_vertigo_retro_synth_purple_tinted on the north hall-
//          mouth wall ABOVE the mouth: y-602 (2u proud of face y-600), x[-96,
//          96] z[-996,-968] - the mouth opening tops out at z-1000, the strip
//          crowns it; perk row (y-820) is 220u south. -y normal => Xmin->Xmax.
// ABYSS BANDS (user-approved 2026-07-18; iron DOMINANT - partial repaint only,
// trench/L1 untouched, ZERO lights added). STRUCTURAL CONSTRAINT found by scan:
// every N/S long perimeter wall carries a COINCIDENT-PLANE overlap with an iron
// stairwell seal/rail brush in the center band x[-112,112] (e.g. L2 N wall vs
// the D2 stairwell N wall [-112,112,2173,2193,-720,-256]) - painting a long
// wall would z-fight iron in that band, so the bands ride coincidence-FREE
// walls per floor:
//   L2  W+E walls (z[-480,-240]) -> t10_metal_aluminum_painted_01_panels_grey
//       (valid DERIVED GDT entry [parent t10_metal_aluminum_painted_01_panels]
//       + grey colorTint - same derived-entry class as the shipped ghost-pack
//       models). ~22% of the perimeter.
//   L3  W+E walls (z[-720,-480]) -> t10_me_rock_cave_wall_01_tile. PLUS the
//       _reveal MECHANISM TEST: ONE small face - the D3 stairwell EAST rail
//       [112,132,1723,1851,-720,-496] room-facing x132 face (128x224u, visible
//       from the L3 east bay) -> t10_dirt_roots_01_reveal (lit_decal_reveal_
//       plus - the reveal/blend class is UNPROVEN as a standalone face token;
//       if the linker complains, revert just that face + record the verdict).
//   L4  E wall only (z[-960,-720]) -> t10_plaster_peeling_04_white_dirty = the
//       wall flanking the specimen-gantry NE block (gantry deck x[140,780]
//       y[2013,2173] IS diamond plate - kept). The N wall behind the gantry is
//       the D4-coincidence wall -> skipped (noted); AK-47 chalk S wall safe.
//   L5  SOUTH wall (W jamb + E jamb + lintel, z[-1200,-960]) -> t10_stone_
//       cliff_wall_01 - frames the Paradise doorway in raw stone (the snake
//       arch + sconces + runes hang in front). 35% of the perimeter; the M60
//       chalk (ACCC0005, y1725 on the W jamb) floats proud + renders over it
//       (P1 FRAG precedent). Jambs are coincidence-free (D3 seal stops at
//       z-960); the hub-door entity + threshold patch abut, never overlap.
//
// VK OPTION: declined again - every pick above is stock-BO6 t10 / emox, all
// verified as GDT entries 2026-07-18; no VK provenance tracing needed.
// EXCLUDED by construction: wallbuy/POWER/arrow chalk + ACCC meshes (token-
// keyed swaps can't match them), door/entity brushes (worldspawn-only),
// decal-carrying faces (none of the target sigs carry one - P0's decal + P1's
// crack/leak accents live in plaza/corp, outside every P2 region).
//
// Face tokens + mesh materials need NO .zone line (transitive - docs/20 s.3).
// Token swaps change NO windings; the 6 strip/mark meshes are new nonColliding
// geometry cloned from the bake-proven ACCC0010/0011 donor -> FULL build + LED
// bake gate.
// =============================================================================
'use strict';
const fs = require('fs');

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const MARKER = 'ACC P2 ZONES T10 REPAINT';

// FROM tokens
const FROM_DIAMOND = 't7_metal_diamond_plate_worn_wet';
const FROM_ROOFFLR = 't7_concrete_wall_weathered_01_wet';
const FROM_HEX     = 't7_zm_der_tile_hexagon';
const FROM_IRON    = 't7_metal_worn_iron_dark';

// TO tokens (ALL verified in the installed GDTs 2026-07-18: t10_materials.gdt /
// emox_mwiii_vertigo_assets.gdt; panels_grey is a derived entry, see header)
const TO_VAULT_FLOOR = 't10_stone_marble_black_01';
const TO_ROOF_FLOOR  = 't10_asphalt_mid_01';
const TO_LAB_WALL    = 't10_concrete_painted_01_white';
const TO_PARA_FLOOR  = 'mwiii_vertigo_retro_synth_cyan';          // BASE cyan (emissive), not _tinted
const TO_L2_BAND     = 't10_metal_aluminum_painted_01_panels_grey';
const TO_L3_BAND     = 't10_me_rock_cave_wall_01_tile';
const TO_L3_REVEAL   = 't10_dirt_roots_01_reveal';                // mechanism test, 1 face
const TO_L4_BAND     = 't10_plaster_peeling_04_white_dirty';
const TO_L5_BAND     = 't10_stone_cliff_wall_01';
const TO_MARK_LINE   = 't10_terrain_decal_painted_line_solid_single_01';
const TO_MARK_THICK  = 't10_terrain_decal_painted_line_thick_02'; // no *_solid_thick_02 exists
const TO_STRIP_CYAN  = 'mwiii_vertigo_retro_synth_cyan_tinted';   // P0-proven (ACCC0010) = zero new xpak
const TO_STRIP_PURP  = 'mwiii_vertigo_retro_synth_purple_tinted';

// Region sanity boxes (centroid asserts - a matched sig outside its zone aborts)
const BOX = {
  VAULT:    { x1: 815,   x2: 1945, y1: 2255,  y2: 3465, z1: -30,   z2: 300 },
  ROOF:     { x1: -1945, x2: -785, y1: 2255,  y2: 3465, z1: -30,   z2: 300 },
  LAB:      { x1: -790,  x2: 830,  y1: 3040,  y2: 4256, z1: -20,   z2: 280 },
  PARADISE: { x1: -1030, x2: 1030, y1: -2230, y2: -570, z1: -1220, z2: -1180 },
  ABYSS:    { x1: -810,  x2: 850,  y1: 1690,  y2: 2200, z1: -1216, z2: -236 },
};

const SIG = (b) => b.join(',');
// sel: 'all' = every face wearing FROM; {axis,off} = only that face (still FROM-keyed)
const TARGETS = {
  // ---- VAULT floors (z0 top faces only - slab sides/bottoms stay diamond) ----
  [SIG([1119, 1939, 2260, 3400, -16, 0])]: { sel: { axis: 'z', off: 0 }, from: FROM_DIAMOND, to: TO_VAULT_FLOOR, box: 'VAULT', tag: 'vault floor', want: 1 },
  [SIG([819, 1119, 2300, 2556, -16, 0])]:  { sel: { axis: 'z', off: 0 }, from: FROM_DIAMOND, to: TO_VAULT_FLOOR, box: 'VAULT', tag: 'vault floor', want: 1 },
  [SIG([819, 1119, 3100, 3356, -16, 0])]:  { sel: { axis: 'z', off: 0 }, from: FROM_DIAMOND, to: TO_VAULT_FLOOR, box: 'VAULT', tag: 'vault floor', want: 1 },
  // ---- HELIPAD floors (z0 top faces only) ----
  [SIG([-1939, -1119, 2260, 3400, -16, 0])]: { sel: { axis: 'z', off: 0 }, from: FROM_ROOFFLR, to: TO_ROOF_FLOOR, box: 'ROOF', tag: 'helipad floor', want: 1 },
  [SIG([-1119, -781, 2300, 2556, -16, 0])]:  { sel: { axis: 'z', off: 0 }, from: FROM_ROOFFLR, to: TO_ROOF_FLOOR, box: 'ROOF', tag: 'helipad floor', want: 1 },
  [SIG([-1119, -781, 3100, 3356, -16, 0])]:  { sel: { axis: 'z', off: 0 }, from: FROM_ROOFFLR, to: TO_ROOF_FLOOR, box: 'ROOF', tag: 'helipad floor', want: 1 },
  // ---- LAB walls (whole-brush): 6 perimeter + 9 alcove fins ----
  [SIG([-781, 819, 3048, 3068, 0, 256])]:  { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([-781, 819, 4228, 4248, 0, 256])]:  { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([-781, -761, 3068, 3100, 0, 256])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([-781, -761, 3356, 4228, 0, 256])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([799, 819, 3068, 3100, 0, 256])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([799, 819, 3356, 4228, 0, 256])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab wall', want: 6 },
  [SIG([-604, -596, 4154, 4228, 0, 150])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([-454, -446, 4154, 4228, 0, 150])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([-304, -296, 4154, 4228, 0, 150])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([-154, -146, 4154, 4228, 0, 150])]: { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([-4, 4, 4154, 4228, 0, 150])]:      { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([146, 154, 4154, 4228, 0, 150])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([296, 304, 4154, 4228, 0, 150])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([446, 454, 4154, 4228, 0, 150])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  [SIG([596, 604, 4154, 4228, 0, 150])]:   { sel: 'all', from: FROM_HEX, to: TO_LAB_WALL, box: 'LAB', tag: 'lab alcove fin', want: 6 },
  // ---- PARADISE arena floor (the single slab's z-1200 TOP face only) ----
  [SIG([-1020, 1020, -2220, -580, -1216, -1200])]: { sel: { axis: 'z', off: -1200 }, from: FROM_HEX, to: TO_PARA_FLOOR, box: 'PARADISE', tag: 'paradise arena floor (EMISSIVE)', want: 1 },
  // ---- ABYSS bands (whole-brush; coincidence-free walls only, see header) ----
  [SIG([-801, -781, 1723, 2173, -480, -240])]: { sel: 'all', from: FROM_IRON, to: TO_L2_BAND, box: 'ABYSS', tag: 'L2 band W wall', want: 6 },
  [SIG([819, 839, 1723, 2173, -480, -240])]:   { sel: 'all', from: FROM_IRON, to: TO_L2_BAND, box: 'ABYSS', tag: 'L2 band E wall', want: 6 },
  [SIG([-801, -781, 1723, 2173, -720, -480])]: { sel: 'all', from: FROM_IRON, to: TO_L3_BAND, box: 'ABYSS', tag: 'L3 band W wall', want: 6 },
  [SIG([819, 839, 1723, 2173, -720, -480])]:   { sel: 'all', from: FROM_IRON, to: TO_L3_BAND, box: 'ABYSS', tag: 'L3 band E wall', want: 6 },
  [SIG([112, 132, 1723, 1851, -720, -496])]:   { sel: { axis: 'x', off: 132 }, from: FROM_IRON, to: TO_L3_REVEAL, box: 'ABYSS', tag: 'L3 REVEAL test face (D3 rail)', want: 1 },
  [SIG([819, 839, 1723, 2173, -960, -720])]:   { sel: 'all', from: FROM_IRON, to: TO_L4_BAND, box: 'ABYSS', tag: 'L4 band E wall (gantry flank)', want: 6 },
  [SIG([-801, -96, 1703, 1723, -1200, -960])]: { sel: 'all', from: FROM_IRON, to: TO_L5_BAND, box: 'ABYSS', tag: 'L5 band S wall W jamb', want: 6 },
  [SIG([96, 839, 1703, 1723, -1200, -960])]:   { sel: 'all', from: FROM_IRON, to: TO_L5_BAND, box: 'ABYSS', tag: 'L5 band S wall E jamb', want: 6 },
  [SIG([-96, 96, 1703, 1723, -1000, -960])]:   { sel: 'all', from: FROM_IRON, to: TO_L5_BAND, box: 'ABYSS', tag: 'L5 band S wall lintel', want: 6 },
};
const EXPECT_SWAPS = 146;   // 3+3+90+1+49

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function faceAxis(p1, p2, p3) {
  for (const [ax, name] of [[0, 'x'], [1, 'y'], [2, 'z']])
    if (p1[ax] === p2[ax] && p2[ax] === p3[ax]) return { axis: name, off: p1[ax] };
  return { axis: null, off: 0 };
}
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
const inBox = (r, cx, cy, cz) => cx >= r.x1 && cx <= r.x2 && cy >= r.y1 && cy <= r.y2 && cz >= r.z1 && cz <= r.z2;

const lines = fs.readFileSync(MAP, 'utf8').split('\n');

// ---- ONE-SHOT GUARD ---------------------------------------------------------
const NEW_TOKENS = [TO_VAULT_FLOOR, TO_ROOF_FLOOR, TO_LAB_WALL, TO_PARA_FLOOR,
  TO_L2_BAND, TO_L3_BAND, TO_L3_REVEAL, TO_L4_BAND, TO_L5_BAND, TO_MARK_LINE,
  TO_MARK_THICK, TO_STRIP_PURP, 'ACCC0013', 'ACCC0014', 'ACCC0015', 'ACCC0016',
  'ACCC0017', 'ACCC0018'];
const guardRe = new RegExp('\\b(' + NEW_TOKENS.map(esc).join('|') + ')\\b');
if (lines.some(l => l.includes(MARKER) || guardRe.test(l))) {
  console.error('paint_p2_zones_t10: already applied (marker/new token/guid present) - refusing.');
  process.exit(1);
}

// ---- pass 1: brush walk (worldspawn only), signature match ------------------
let depth = 0, entIdx = -1, brush = null;
const counts = {};
const bump = (k, n) => { counts[k] = (counts[k] || 0) + (n || 1); };
const linePlan = new Map();          // lineIdx -> { from, to }
const hitSigs = new Map();           // sig -> matched face count

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
        const sig = SIG(b);
        const t = TARGETS[sig];
        if (t) {
          const cx = (b[0] + b[1]) / 2, cy = (b[2] + b[3]) / 2, cz = (b[4] + b[5]) / 2;
          if (!inBox(BOX[t.box], cx, cy, cz)) { console.error(`paint_p2_zones_t10: sig ${sig} centroid outside ${t.box} box - aborting, nothing written.`); process.exit(1); }
          if (hitSigs.has(sig)) { console.error(`paint_p2_zones_t10: sig ${sig} matched a SECOND brush - ambiguous, aborting, nothing written.`); process.exit(1); }
          let n = 0;
          for (const f of brush.faces) {
            if (f.mat !== t.from) continue;
            if (t.sel !== 'all' && !(f.a.axis === t.sel.axis && f.a.off === t.sel.off)) continue;
            linePlan.set(f.line, { from: t.from, to: t.to });
            n++;
          }
          hitSigs.set(sig, n);
          bump(t.tag + ' -> ' + t.to, n);
        }
      }
      brush = null;
    }
  }
}

// ---- completeness assert: every target found with the exact face count ------
for (const sig of Object.keys(TARGETS)) {
  const t = TARGETS[sig];
  if (!hitSigs.has(sig)) { console.error(`paint_p2_zones_t10: target NOT FOUND [${sig}] (${t.tag}) - aborting, nothing written.`); process.exit(1); }
  if (hitSigs.get(sig) !== t.want) { console.error(`paint_p2_zones_t10: target [${sig}] (${t.tag}) matched ${hitSigs.get(sig)} faces, expected ${t.want} - aborting, nothing written.`); process.exit(1); }
}
if (linePlan.size !== EXPECT_SWAPS) { console.error(`paint_p2_zones_t10: planned ${linePlan.size} swaps, expected ${EXPECT_SWAPS} - aborting, nothing written.`); process.exit(1); }

// ---- pass 2: apply token swaps ----------------------------------------------
let swapped = 0;
for (const [li, plan] of linePlan) {
  const re = new RegExp('\\b' + esc(plan.from) + '\\b');
  if (!re.test(lines[li])) { console.error(`paint_p2_zones_t10: line ${li + 1} lost its ${plan.from} token - aborting, nothing written.`); process.exit(1); }
  lines[li] = lines[li].replace(re, plan.to);
  swapped++;
}

// ---- pass 3: insert the 6 chalk meshes (ACCC0010/0011 donor clones) ---------
// Winding rule (proven by every ACCC donor): mesh normal = du x dv where du =
// col0->col1, dv = row0->row1. Wall strips: dv=+z. Flat marks: du=+x, dv=+y => +z.
const stripAnchor = lines.findIndex(l => l.includes('>>> ACC HUB WORLDSPAWN'));
if (stripAnchor < 0) { console.error('paint_p2_zones_t10: strip anchor comment not found - aborting, nothing written.'); process.exit(1); }
function meshBlock(guidTag, mat, cols) {
  // cols = [[x,y,z of row0],[x,y,z of row1]] per column (2 columns)
  return [
    ' {',
    `  guid "{${guidTag}-0000-4DE1-8A3F-1F00${guidTag}}"`,
    '  mesh',
    '  {',
    '  contents nonColliding;',
    '  toolFlags;',
    `   ${mat}`,
    '   lightmap_gray',
    '   2 2 0 8',
    '   (',
    `\tv ${cols[0][0].join(' ')} t 0 -0 -1.0001428 -6.7082205`,
    `\tv ${cols[0][1].join(' ')} t 0 -1024 -0.99985725 -9.0415535`,
    '   )',
    '   (',
    `\tv ${cols[1][0].join(' ')} t 1024 -0 0.87485725 -6.7084455`,
    `\tv ${cols[1][1].join(' ')} t 1024 -1024 0.87514287 -9.0417786`,
    '   )',
    '  }',
    ' }',
  ];
}
const strips = [
  `// ===== ${MARKER} (P2 final batch, 2026-07-18) =====`,
  '// Helipad H mark (flat floor paint, 1u proud, +z normal: cols Xmin->Xmax rows Ymin->Ymax).',
  '// E-central roof bay, clear of the bomber clip (E edge x-1425), crates (y2575), dry weed (x-1360).',
  ...meshBlock('ACCC0013', TO_MARK_LINE,  [[[-1344, 2400, 1], [-1344, 2560, 1]], [[-1320, 2400, 1], [-1320, 2560, 1]]]),
  ...meshBlock('ACCC0014', TO_MARK_LINE,  [[[-1208, 2400, 1], [-1208, 2560, 1]], [[-1184, 2400, 1], [-1184, 2560, 1]]]),
  ...meshBlock('ACCC0015', TO_MARK_THICK, [[[-1320, 2468, 1], [-1320, 2492, 1]], [[-1208, 2468, 1], [-1208, 2492, 1]]]),
  '// Lab perk-row crown: synth-cyan band on the N wall (face y4228) ABOVE the 10 alcoves',
  '// (fins top z150, doors z<=140, machines ~128 @ y4195). -y normal => cols Xmin->Xmax.',
  ...meshBlock('ACCC0016', TO_STRIP_CYAN, [[[-604, 4226, 200], [-604, 4226, 228]], [[604, 4226, 200], [604, 4226, 228]]]),
  '// Lab PaP corner: synth-purple band on the W wall (face x-761) above the PaP prefab (-700,3700).',
  '// +x normal => cols Ymin->Ymax (du x dv rule).',
  ...meshBlock('ACCC0017', TO_STRIP_PURP, [[[-759, 3580, 200], [-759, 3580, 228]], [[-759, 3860, 200], [-759, 3860, 228]]]),
  '// Paradise hall-mouth trim: synth-purple strip crowning the north mouth (face y-600, opening',
  '// tops at z-1000). -y normal => cols Xmin->Xmax.',
  ...meshBlock('ACCC0018', TO_STRIP_PURP, [[[-96, -602, -996], [-96, -602, -968]], [[96, -602, -996], [96, -602, -968]]]),
];
lines.splice(stripAnchor, 0, ...strips);
bump('mark ' + TO_MARK_LINE + ' (2 meshes)', 2);
bump('mark ' + TO_MARK_THICK + ' (1 mesh)', 1);
bump('strip ' + TO_STRIP_CYAN + ' (1 mesh)', 1);
bump('strip ' + TO_STRIP_PURP + ' (2 meshes)', 2);

fs.writeFileSync(MAP, lines.join('\n'));
console.log('[paint_p2_zones_t10] applied:');
for (const k of Object.keys(counts).sort()) console.log(`  ${k} : ${Math.round(counts[k])}`);
console.log(`  TOTAL token swaps: ${swapped} face lines + 6 inserted meshes`);
console.log('  FULL build + LED bake gate required (mark/strip meshes = new geometry).');
