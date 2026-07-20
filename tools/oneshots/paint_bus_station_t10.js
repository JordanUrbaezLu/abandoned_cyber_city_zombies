#!/usr/bin/env node
// =============================================================================
// paint_bus_station_t10.js  (ONE-SHOT, marker-guarded - refuses re-apply)
//
// P0 texture-phase pilot (2026-07-18): repaint the BUS STATION (corp zone) with
// the newly installed BO6 `t10_materials.gdt` face materials + run the three
// texture-phase mechanism tests in one build:
//   1. DECAL-ON-FACE  - t10_terrain_decal_crack_asphalt_03 (materialCategory
//      "Decal" / lit_decal_plus) as the face token of ONE small floor face (the
//      east trench-rim z0 strip, 20x450u, hugging the E wall next to the
//      repainted E stair channel). If the linker rejects a Decal-category
//      material as a flat brush face, revert JUST that face; fallback recipe =
//      the CW-arrow inline chalk mesh (proven, see the power arrows).
//   2. EMISSIVE STRIP - one inline worldspawn chalk-mesh quad (VERBATIM clone of
//      the proven arrow_power_coldwar mesh structure) above the departure-board
//      TV cluster (-120..120, 1210) on the corp SOUTH wall (interior face
//      y=1168, quad 2u proud at y=1170, +y normal => cols Xmax->Xmin), material
//      mwiii_vertigo_retro_synth_cyan_tinted (lit_emissive_advanced, verified in
//      source_data\_emox\emox_mwiii_vertigo_assets.gdt). z[204,232] - ceiling-
//      adjacent, nowhere near any POWER decal (those live at y1703/y2173/x687/
//      y2193).
//   3. VK MATERIAL    - pbr_white_rough_plaster_01_mtl (lit_advanced_fullspec,
//      vk_pbr_pk1_mtl.gdt) on the restroom-nook W-wall segment
//      x[-781,-761] y[2556,2728] z[0,256]. PROVENANCE: CC0-clean - its images
//      trace to texture_assets\vk_mtl\pbr\texturehaven_white_rough_plaster_1K\*
//      = TextureHaven (Poly Haven), CC0. (The suggested pbr_concrete_bunker_
//      wall_1 candidate was REJECTED: its albedo is TexturesCom_BunkerConcrete_
//      4x4_A_1024 = Textures.com = licence-flagged, cannot ship - docs/20 s.8.)
//
// REPAINT (corp zone only, worldspawn entity 0 only - the acc_corp_bridge
// script_brushmodel + buyable doors are entities and are never touched):
//   WALLS  t7_metal_bare_graphite_matte -> t10_metal_aluminum_composite_wall_
//          paneling_01, whole-brush, for vertical brushes inside paint_region's
//          CORP box (x[-1100,1100] y[1140,2755], surface band). ABSOLUTE
//          EXCLUSION: any brush with a face on the POWER-decal breadcrumb planes
//          y=1703 / y=2173 / y=2193 / x=687 keeps its current faces (those wall
//          faces back the arrow_power_coldwar chalk meshes at y1701/y2171/x685/
//          y2195). The VK nook segment is also excluded (it gets plaster).
//   FLOOR  face-level: ONLY the z=0 TOP faces of the 4 corp surface floor
//          masses (N half y[2173,2748], S half y[1148,1723], W+E trench-rim
//          strips) -> t10_concrete_epoxy_flooring_01_gray_dirty. The floor
//          masses double as under-level ceilings/trench walls, so their side +
//          bottom faces are LEFT ALONE (trench pit floors z<0 stay dark,
//          user-locked). The E rim strip's top face is the decal test instead.
//   STAIRS the 46 marker-tagged trench stair brushes ("// corp trench W|E stair
//          ...") -> t10_stairs_concrete_clean (whole brush: treads + risers =
//          the two stair channels x[-761,-665] / x[703,799]).
//   CEIL   face-level: the single z256 underside face of the corp ceiling slab
//          (x[-781,819] y[1148,2748] z[256,272]) -> t10_ceiling_tile_01_dirty.
//   WAINSCOT: SKIPPED ENTIRELY. The corp walls are single full-height faces
//          (z[0,256] one face per segment); the only separate low wall brushes
//          are the trench parapets z[0,128]/z[0,42] - ALL of which are the
//          excluded POWER-decal walls. Token swaps cannot split a face, so
//          t10_concrete_wall_striped_03_trim has nowhere legal to land.
//
// Face tokens + mesh materials need NO .zone line (transitive - docs/20 s.3).
// Token swaps change NO windings; the strip mesh is new (nonColliding) geometry
// cloned from a bake-proven donor -> FULL build + LED bake gate still applies.
// =============================================================================
'use strict';
const fs = require('fs');

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const MARKER = 'ACC BUS STATION T10 REPAINT';

const FROM_WALL  = 't7_metal_bare_graphite_matte';
const FROM_IRON  = 't7_metal_worn_iron_dark';
const TO_WALL    = 't10_metal_aluminum_composite_wall_paneling_01';
const TO_FLOOR   = 't10_concrete_epoxy_flooring_01_gray_dirty';
const TO_STAIRS  = 't10_stairs_concrete_clean';
const TO_CEIL    = 't10_ceiling_tile_01_dirty';
const TO_DECAL   = 't10_terrain_decal_crack_asphalt_03';
const TO_VK      = 'pbr_white_rough_plaster_01_mtl';
const TO_STRIP   = 'mwiii_vertigo_retro_synth_cyan_tinted';

// paint_region.js CORP box (authoritative zone bounds), surface band only.
const CORP = { x1: -1100, x2: 1100, y1: 1140, y2: 2755 };
// POWER-decal breadcrumb wall planes (docs: the CW power-arrow chalk meshes sit
// 2u proud of these faces) - any brush touching one keeps ALL its faces.
const DECAL_PLANES = { y: [1703, 2173, 2193], x: [687] };
// Bounds signatures (exact) for the face-level targets.
const SIG = (b) => b.join(',');
const VK_SIG    = SIG([-781, -761, 2556, 2728, 0, 256]);   // restroom nook W-wall segment
const CEIL_SIG  = SIG([-781, 819, 1148, 2748, 256, 272]);  // corp ceiling slab
const DECAL_SIG = SIG([799, 819, 1723, 2173, -240, 0]);    // E trench-rim strip (top face = decal test)
const FLOOR_SIGS = new Set([
  SIG([-781, 819, 2173, 2748, -96, 0]),                    // N half floor mass
  SIG([-781, 819, 1148, 1723, -96, 0]),                    // S half floor mass
  SIG([-781, -761, 1723, 2173, -240, 0]),                  // W trench-rim strip
]);

const N = '(-?[\\d.]+)';
const FACE_RE = new RegExp('^\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s*\\(\\s*'+N+'\\s+'+N+'\\s+'+N+'\\s*\\)\\s+(\\S+)');
function faceAxis(p1, p2, p3) {
  for (const [ax, name] of [[0, 'x'], [1, 'y'], [2, 'z']])
    if (p1[ax] === p2[ax] && p2[ax] === p3[ax]) return { axis: name, off: p1[ax] };
  return { axis: null, off: 0 };
}
const esc = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

const lines = fs.readFileSync(MAP, 'utf8').split('\n');

// ---- ONE-SHOT GUARD ---------------------------------------------------------
if (lines.some(l => l.includes(MARKER) || /\bt10_|pbr_white_rough_plaster|mwiii_vertigo/.test(l))) {
  console.error('paint_bus_station_t10: already applied (marker/t10 token present) - refusing.');
  process.exit(1);
}

// ---- pass 1: brush walk (worldspawn only) -----------------------------------
let depth = 0, entIdx = -1, brush = null, stairArm = false;
const counts = {};
const bump = (k) => { counts[k] = (counts[k] || 0) + 1; };
// line -> replacement plan: {tok:from->to for whole line} or {faceTo} per face line
const linePlan = new Map();          // lineIdx -> { from, to }  (token swap on that line)
const isWall = (b) => (b[5] - b[4]) > Math.min(b[1] - b[0], b[3] - b[2]);

for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  // Arm ONLY on tread markers - NOT the pit-side wall markers: the E pit-side
  // wall IS the x687 STAIRS-decal wall (must keep its faces), and painting only
  // the W one would be asymmetric, so both pit-side walls stay worn iron.
  if (/^\/\/ corp trench [WE] stair /.test(t)) stairArm = true; // arm for the NEXT brush
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) {
    if (depth === 0) entIdx++;
    if (depth === 1 && entIdx === 0) brush = { start: i, faces: [], stair: stairArm };
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
        const cx = (b[0] + b[1]) / 2, cy = (b[2] + b[3]) / 2;
        const inCorp = cx >= CORP.x1 && cx <= CORP.x2 && cy >= CORP.y1 && cy <= CORP.y2;
        const sig = SIG(b);
        const onDecalPlane = brush.faces.some(f =>
          (f.a.axis === 'y' && DECAL_PLANES.y.includes(f.a.off)) ||
          (f.a.axis === 'x' && DECAL_PLANES.x.includes(f.a.off)));
        if (brush.stair && inCorp) {
          // STAIRS: whole brush iron -> t10 stairs. No decal-plane guard here:
          // only E tread N1 touches a decal plane (its y2173 face, BURIED against
          // the pit north wall mass) and the y2171 decal quads live at x[136,280]
          // while the stair is x[703,799] - skipping it would leave one iron step
          // atop a concrete stair. The decal-carrying WALL brushes are not treads
          // and the pit-side walls are not armed.
          for (const f of brush.faces) if (f.mat === FROM_IRON) { linePlan.set(f.line, { from: FROM_IRON, to: TO_STAIRS }); bump('stairs ' + TO_STAIRS); }
        } else if (inCorp && sig === VK_SIG) {
          // VK TEST: restroom nook wall segment -> TextureHaven plaster (CC0).
          for (const f of brush.faces) if (f.mat === FROM_WALL) { linePlan.set(f.line, { from: FROM_WALL, to: TO_VK }); bump('vk ' + TO_VK); }
        } else if (inCorp && sig === CEIL_SIG) {
          // CEILING: only the z256 underside face.
          for (const f of brush.faces) if (f.a.axis === 'z' && f.a.off === 256 && f.mat === FROM_WALL) { linePlan.set(f.line, { from: FROM_WALL, to: TO_CEIL }); bump('ceil ' + TO_CEIL); }
        } else if (inCorp && sig === DECAL_SIG) {
          // DECAL TEST: only the z0 top face of the E trench-rim strip.
          for (const f of brush.faces) if (f.a.axis === 'z' && f.a.off === 0 && f.mat === FROM_IRON) { linePlan.set(f.line, { from: FROM_IRON, to: TO_DECAL }); bump('decal ' + TO_DECAL); }
        } else if (inCorp && FLOOR_SIGS.has(sig)) {
          // FLOOR: only the z0 top faces of the surface floor masses.
          for (const f of brush.faces) if (f.a.axis === 'z' && f.a.off === 0 && f.mat === FROM_IRON) { linePlan.set(f.line, { from: FROM_IRON, to: TO_FLOOR }); bump('floor ' + TO_FLOOR); }
        } else if (inCorp && !onDecalPlane && isWall(b) && b[4] >= -30 && b[5] <= 256) {
          // WALLS: whole-brush graphite -> t10 paneling (surface band only).
          for (const f of brush.faces) if (f.mat === FROM_WALL) { linePlan.set(f.line, { from: FROM_WALL, to: TO_WALL }); bump('wall ' + TO_WALL); }
        } else if (inCorp && onDecalPlane) {
          if (brush.faces.some(f => f.mat === FROM_WALL)) bump('EXCLUDED power-decal wall brush (kept ' + FROM_WALL + ')');
        }
      }
      brush = null;
      stairArm = false;
    }
  }
}

// ---- pass 2: apply token swaps ---------------------------------------------
let swapped = 0;
for (const [li, plan] of linePlan) {
  const re = new RegExp('\\b' + esc(plan.from) + '\\b');
  if (!re.test(lines[li])) { console.error(`paint_bus_station_t10: line ${li + 1} lost its ${plan.from} token - aborting, nothing written.`); process.exit(1); }
  lines[li] = lines[li].replace(re, plan.to);
  swapped++;
}

// ---- pass 3: insert the emissive strip mesh ---------------------------------
// VERBATIM structural clone of the proven arrow_power_coldwar chalk meshes
// (contents nonColliding + lightmap_gray + 2x2 mesh, donor lightmap floats).
// +y normal (viewer faces south wall) => cols Xmax->Xmin (winding rule from the
// y2195 POWER parapet meshes). 352x28u @ y1170 (2u proud of the y1168 face).
const stripAnchor = lines.findIndex(l => l.includes('>>> ACC HUB WORLDSPAWN'));
if (stripAnchor < 0) { console.error('paint_bus_station_t10: strip anchor comment not found - aborting, nothing written.'); process.exit(1); }
const strip = [
  `// ===== ${MARKER} (P0 pilot, 2026-07-18) =====`,
  '// Mechanism test 2: emissive strip - departure-board synth-cyan band on the corp S wall',
  '// (above the tv_vintage_on cluster at x-120..120 y1210; NOT over any POWER decal).',
  ' {',
  '  guid "{ACCC0010-0000-4DE1-8A3F-1F00ACCC0010}"',
  '  mesh',
  '  {',
  '  contents nonColliding;',
  '  toolFlags;',
  `   ${TO_STRIP}`,
  '   lightmap_gray',
  '   2 2 0 8',
  '   (',
  '\tv 176 1170 204 t 0 -0 -1.0001428 -6.7082205',
  '\tv 176 1170 232 t 0 -1024 -0.99985725 -9.0415535',
  '   )',
  '   (',
  '\tv -176 1170 204 t 1024 -0 0.87485725 -6.7084455',
  '\tv -176 1170 232 t 1024 -1024 0.87514287 -9.0417786',
  '   )',
  '  }',
  ' }',
];
lines.splice(stripAnchor, 0, ...strip);
bump('strip ' + TO_STRIP + ' (1 mesh)');

fs.writeFileSync(MAP, lines.join('\n'));
console.log('[paint_bus_station_t10] applied:');
for (const k of Object.keys(counts).sort()) console.log(`  ${k} : ${counts[k]} faces`);
console.log(`  TOTAL token swaps: ${swapped} face lines + 1 inserted mesh`);
console.log('  FULL build + LED bake gate required (strip mesh = new geometry).');
