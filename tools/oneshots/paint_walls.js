#!/usr/bin/env node
// paint_walls.js - reskin brush FACES by swapping their greybox placeholder material token to a stock material.
//
// WHY: greybox faces carry placeholder material tokens that render as the checker "missing material" pattern in
// game. A brush face's material token IS the GDT material name (CLAUDE.md / docs/29), so "painting" a surface =
// swapping that token for a real, shipped material. Face materials need NO `.zone` line and stock `t7_*` materials
// ship free (already in the installed fastfiles), so this is a pure `.map` token swap - then a FULL LED-baked build,
// since the surface is BSP-baked into the lightmap. (It is NOT a geometry/winding change, so it can't hit the
// brush.cpp:1860 bake crash - only the albedo the lightmapper sees changes.)
//
// The map's two greybox tokens (verified 2026-06-28 to appear ONLY as face materials, never entity keys/values):
//   script_wall            - the 1152 WALL faces
//   script_floor_ceiling   - the 1092 FLOOR + CEILING faces
// so a whole-word swap of either repaints exactly that surface set and nothing else.
//
// Usage:  node tools/paint_walls.js [FROM] [TO] [in.map] [out.map]
//   walls -> near-black (default):  node tools/paint_walls.js
//   floors+ceilings -> near-black:  node tools/paint_walls.js script_floor_ceiling t7_asphalt_damaged_dark_wet
//   revert walls to greybox:        node tools/paint_walls.js t7_asphalt_damaged_dark_wet script_wall
//   (defaults: FROM=script_wall  TO=t7_asphalt_damaged_dark_wet  in=out=repo map, in place)
// To repaint a region only (e.g. the Lab white), this whole-map swap is too blunt - use a bounds-aware tool.
'use strict';
const fs = require('fs');

const FROM = process.argv[2] || 'script_wall';                  // face token to replace
const TO   = process.argv[3] || 't7_asphalt_damaged_dark_wet';  // near-black wet asphalt (docs/29 palette #0E1115; verified stock)

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const inPath  = process.argv[4] || MAP;
const outPath = process.argv[5] || inPath;

const src = fs.readFileSync(inPath, 'utf8');
const re  = new RegExp('\\b' + FROM.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '\\b', 'g');
const hits = (src.match(re) || []).length;
if (hits === 0) {
  console.error(`[paint_walls] FROM token "${FROM}" not found in ${inPath} - already painted / wrong token? Nothing written.`);
  process.exit(1);
}
fs.writeFileSync(outPath, src.replace(re, TO));
console.log(`[paint_walls] ${FROM} -> ${TO}: ${hits} faces repainted; wrote ${outPath}`);
