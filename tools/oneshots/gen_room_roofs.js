#!/usr/bin/env node
// =============================================================================
// gen_room_roofs.js - roof the non-Plaza rooms (Plaza stays open). Each room gets a
// CEILING slab flush on the z256 perimeter walls + interior LIGHT entities (an unlit
// enclosed room bakes BLACK, not a crash). Plaza (start_zone) is deliberately omitted.
//
// LED: ceilings DO bake with the PROVEN gen_zone_greybox filler-plane winding + a HEX GUID
// (the old add_vault_ceiling real-corner winding + malformed GUID is what crashed brush.cpp:1860
// - corrected 2026-06-18). Light = the verified kelson8 PRIMARY_OMNI block (docs/38 §4.1).
//
// !! INCREMENTAL + BAKE-GATED: the lightmap atlas budget is finite. Add ROOMS one at a time
//    (comment the others out), _bake_test.ps1 each, revert any room that crashes/over-budgets. !!
// RE-RUNNABLE: strips its tagged worldspawn block + its light entities, then re-emits.
//
// Usage: node tools/gen_room_roofs.js [--out <file>]   (default: writes the real .map)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;

const CEIL_Z1 = 256, CEIL_Z2 = 272;      // ceiling sits on the z256 perimeter wall tops
const TAG = '// ACC room roofs (tools/gen_room_roofs.js)';
const LTAG_RE = /"targetname" "acc_roof_light_/;

// LIGHTING (user 2026-06-18/19: "a ton more light inside", then "add a dim light - still hard to see
// but you can see - then way brighter when power is on"). TWO light sets per grid point, gated by
// lighting STATE so the scene is DIM before power and BRIGHT after:
//
//   *** BO3 lighting-state OFF-BY-ONE (verified vs stock zm_giant_light.map + util_shared.gsc, 2026-06-19) ***
//   GSC set_lighting_state(N) displays Radiant State N+1 == the light field "lightingstate(N+1)".
//   There is NO "lightingstate0" key (absent from t7.def.json - do not emit it). Our entry script
//   (zm_abandoned_cyber_city.gsc CheckForPower) runs set_lighting_state(0) pre-power then
//   set_lighting_state(1) on power_on, so:
//       pre-power  = GSC state 0 = Radiant State 1 = lightingstate1
//       post-power = GSC state 1 = Radiant State 2 = lightingstate2
//   => DIM set carries lightingstate1="1" (lit pre-power) + 2/3/4="0"  (the BARELY-visible floor)
//      BRIGHT set carries lightingstate1="0" (dark pre-power) + 2/3/4="1" (the powered-on look)
//   (The old single set with lightingstate1..4 all "1" was lit in BOTH states => the flip did nothing.)
//   All tunable - re-run gen_room_roofs.js + FULL build (LED, no -SkipLED) to retune.
const LIGHT_RADIUS    = 320;   // BRIGHT (post-power) per-light reach (was 150 - too small for these big rooms)
const LIGHT_INTENSITY = 1.3;   // BRIGHT bake_intensity_scale. Overlapping grid lights add up; raise if still dim.
const DIM_RADIUS      = 220;   // DIM (pre-power) reach. 260->220 (tighter pools = dimmer). DO NOT go below ~210: LIGHT_Z=200, so a smaller radius can't reach the z=0 floor -> pitch black/unnavigable.
const DIM_INTENSITY   = 0.02;  // DIM bake_intensity_scale. 0.30->0.15->0.06->0.02 (user 2026-06-19: "almost pitch black INSIDE" pre-power - barely a trace). If rooms unnavigable raise toward 0.03.
const GRID_SPACING    = 420;   // target spacing between grid lights (smaller = denser = brighter/more even)
const GRID_INSET      = 180;   // keep grid lights this far off the walls
const LIGHT_Z         = 200;   // height below the z256 ceiling (lights the room downward)

// lightingstateN masks [s1,s2,s3,s4] (see off-by-one note above).
const BRIGHT_MASK = [ '0', '1', '1', '1' ];  // OFF pre-power (state0=ls1), ON post-power (state1=ls2)
const DIM_MASK    = [ '1', '0', '0', '0' ];  // ON pre-power only (the faint navigable floor)
const ALWAYS_MASK = [ '1', '1', '1', '1' ];  // lit in EVERY state (the Plaza safe-haven set below)

// PITCH-BLACK INTERIOR PRE-POWER (user 2026-06-21: "still too light... just do 0 until power").
// When false, the interior ROOMS emit NO pre-power (DIM) light at all -> each sealed room bakes
// PURE BLACK until power, then the BRIGHT set lights it on the power switch. The 0.02 dim floor
// read "still too light" to the user, who wants 0, so the whole DIM set is dropped. Set true to
// restore the faint navigable floor (and re-run gen_room_roofs.js + a FULL LED build).
const EMIT_DIM_PREPOWER = false;

// PLAZA "safe haven" (user 2026-06-19: "almost pitch black INSIDE; feel safe OUTSIDE until power is on").
// The open/roofless Plaza (start_zone) is NOT sky-lit (default_night sky + black volume_sun global_fill),
// so pre-power it was as dark as the rooms. Light it ALWAYS-ON (both states) so OUTSIDE reads as a lit safe
// haven while the roofed rooms go almost black pre-power. NO ceiling (Plaza stays open). FULL LED build.
const PLAZA_FOOTPRINT = [ -1100, 1110, -600, 760 ];  // start_zone player_volume
const PLAZA_RADIUS    = 360;
const PLAZA_INTENSITY = 0.55;  // moderate safe wash: brighter than the 0.02 room trace, below the 1.3 powered flood

// Fill a ceiling footprint with an evenly-spaced grid of light origins (>=1, center for tiny rooms).
function gridLights( x1, x2, y1, y2 ) {
  const cx = ( x1 + x2 ) / 2, cy = ( y1 + y2 ) / 2;
  const ix1 = x1 + GRID_INSET, ix2 = x2 - GRID_INSET, iy1 = y1 + GRID_INSET, iy2 = y2 - GRID_INSET;
  if ( ix2 <= ix1 || iy2 <= iy1 ) return [ [ Math.round( cx ), Math.round( cy ), LIGHT_Z ] ];
  const nx = Math.max( 1, Math.round( ( ix2 - ix1 ) / GRID_SPACING ) + 1 );
  const ny = Math.max( 1, Math.round( ( iy2 - iy1 ) / GRID_SPACING ) + 1 );
  const out = [];
  for ( let i = 0; i < nx; i++ ) for ( let j = 0; j < ny; j++ ) {
    const x = nx === 1 ? cx : ix1 + ( ix2 - ix1 ) * i / ( nx - 1 );
    const y = ny === 1 ? cy : iy1 + ( iy2 - iy1 ) * j / ( ny - 1 );
    out.push( [ Math.round( x ), Math.round( y ), LIGHT_Z ] );
  }
  return out;
}

// Per non-Plaza room: ceiling footprint [x1,x2,y1,y2] + interior light origins [x,y,z].
// Footprints from riser extents (probe_rooms.js) padded to the perimeter walls. Start with VAULT
// only (validated to bake); uncomment the rest as each passes its bake-gate.
const ROOFS = {
  vault:  { ceil: [1119, 1939, 2280, 3400],   lights: [[1300, 2550, 200], [1750, 2550, 200], [1300, 3150, 200], [1750, 3150, 200]] },
  roof:   { ceil: [-1939, -1119, 2280, 3400], lights: [[-1750, 2550, 200], [-1300, 2550, 200], [-1750, 3150, 200], [-1300, 3150, 200]] },
  market: { ceil: [-2161, -1281, 360, 1496],  lights: [[-2000, 600, 200], [-1450, 600, 200], [-2000, 1250, 200], [-1450, 1250, 200]] },
  alley:  { ceil: [1319, 1990, 360, 1496],    lights: [[1450, 600, 200], [1850, 600, 200], [1450, 1250, 200], [1850, 1250, 200]] },
  // BIG rooms (atlas-budget risk):
  corp:   { ceil: [-781, 819, 1148, 2748],    lights: [[-400, 1400, 200], [400, 1400, 200], [-400, 1950, 200], [400, 1950, 200], [-400, 2500, 200], [400, 2500, 200]] },
  lab:    { ceil: [-781, 819, 3048, 4248],    lights: [[-400, 3300, 200], [400, 3300, 200], [-400, 3750, 200], [400, 3750, 200], [-400, 4150, 200], [400, 4150, 200]] },

  // CORRIDORS / connecting hallways (the gaps the room bounding-boxes miss - "hallways into rooms",
  // user 2026-06-18). Each ABUTS the two room ceilings edge-to-edge (no overlapping coplanar slabs).
  c_sp_mkt:    { ceil: [-1281, -1000, 420, 760],  lights: [[-1140, 600, 200]] },   // Plaza <-> Market
  c_sp_al:     { ceil: [1000, 1281, 420, 760],    lights: [[1140, 600, 200]] },    // Plaza <-> Alley
  c_mkt_corp:  { ceil: [-1281, -781, 1180, 1560], lights: [[-1030, 1370, 200]] },  // Market <-> Bus Station
  c_al_corp:   { ceil: [819, 1281, 1180, 1560],   lights: [[1050, 1370, 200]] },   // Alley <-> Bus Station
  c_corp_roof: { ceil: [-1119, -781, 2300, 2660], lights: [[-950, 2480, 200]] },   // Bus Station <-> Helipad
  c_corp_vlt:  { ceil: [819, 1119, 2300, 2660],   lights: [[969, 2480, 200]] },    // Bus Station <-> Vault
  c_roof_lab:  { ceil: [-1119, -781, 3100, 3460], lights: [[-950, 3280, 200]] },   // Helipad <-> Lab
  c_vlt_lab:   { ceil: [819, 1119, 3100, 3460],   lights: [[969, 3280, 200]] },    // Vault <-> Lab
  spine:       { ceil: [-350, 350, 780, 1180],    lights: [[0, 900, 200], [0, 1080, 200]] }, // Plaza -> Bus Station central spine
  east_strip:  { ceil: [1990, 2250, 360, 1560] }, // walled strip E of the Alley (abuts alley ceiling; lights via grid)
};

let gc = 0;
function guid() {
  gc++;
  const h = ('roof' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  return `{${h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8)}-ACC7-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Proven filler-plane box winding (bakes). script_floor_ceiling (horizontal slab).
function ceilBrush(x1, x2, y1, y2) {
  const t = 'script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${CEIL_Z1} ) ( 86.5 459.5 ${CEIL_Z1} ) ( 86.5 419.5 ${CEIL_Z1} ) ${t}`,
    ` ( 94.5 419.5 ${CEIL_Z2} ) ( 94.5 459.5 ${CEIL_Z2} ) ( 142.5 459.5 ${CEIL_Z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}'].join('\n');
}

// Verified kelson8 PRIMARY_OMNI light entity (docs/38 §4.1). White (no tint - user prefers base colors).
// `tag` = full targetname (must start with acc_roof_light_ so strip() catches it on re-run);
// `mask` = [s1,s2,s3,s4] lightingstate values (see off-by-one note up top).
function lightEntity(tag, x, y, z, radius, intensity, mask) {
  return ['{', `guid "${guid()}"`,
    '"classname" "light"', `"targetname" "${tag}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    '"_color" "1 1 1"', `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    `"lightingstate1" "${mask[0]}"`, `"lightingstate2" "${mask[1]}"`, `"lightingstate3" "${mask[2]}"`, `"lightingstate4" "${mask[3]}"`,
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

// Strip ALL prior roof artifacts (deduping any accumulated duplicates): every roof comment line + every
// LEAF brace-block whose guid carries our -ACC7- marker (ceiling brushes AND light entities). The OLD
// version only removed the first ceiling per run, so re-runs stacked duplicate coplanar slabs (an LED
// hazard) - this marker-based removal is order-independent + idempotent, so one run collapses the dupes.
function strip(lines) {
  const MARK = '-ACC7-';
  const out = [];
  for (let k = 0; k < lines.length; k++) {
    const t = lines[k].trim();
    if (t.includes(TAG) || t.startsWith('// roof ceiling:')) continue;   // drop roof comment lines
    if (t === '{') {
      let d = 0, leaf = true, marked = false, j = k;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') { d++; if (d > 1) leaf = false; }
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
        if (lines[j].includes(MARK)) marked = true;
      }
      if (leaf && marked) { k = j - 1; continue; }   // drop this whole roof leaf-block (ceiling/light)
    }
    out.push(lines[k]);
  }
  return out;
}

let lines = strip(fs.readFileSync(MAP, 'utf8').split(/\r?\n/));

// ceilings -> before worldspawn close (first depth-return-to-0)
let depth = 0, wclose = -1;
for (let i = 0; i < lines.length; i++) { const t = lines[i].trim(); if (t === '{') depth++; else if (t === '}') { depth--; if (depth === 0) { wclose = i; break; } } }
const ceilBlock = [TAG], lightBlock = [TAG + ' lights'];
let nC = 0, nL = 0;
for (const [room, r] of Object.entries(ROOFS)) {
  ceilBlock.push(`// roof ceiling: ${room} [${r.ceil.join(',')}]`, ceilBrush(...r.ceil)); nC++;
  // Fill the ceiling footprint with a GRID. At EACH grid point emit TWO lights gated by lighting
  // state: a DIM one lit pre-power (faint floor) + a BRIGHT one lit post-power (the powered look).
  // user 2026-06-18: "a ton more light"; 2026-06-19: "dim before power, way brighter when on".
  const grid = gridLights(...r.ceil);
  grid.forEach((L, idx) => {
    lightBlock.push(lightEntity(`acc_roof_light_${room}_${idx}`,     L[0], L[1], L[2], LIGHT_RADIUS, LIGHT_INTENSITY, BRIGHT_MASK)); nL++;
    // DIM (pre-power) floor light - omitted when EMIT_DIM_PREPOWER is false so the room is pure
    // black until power (user 2026-06-21). The BRIGHT light above stays (lights the room on power).
    if ( EMIT_DIM_PREPOWER )
    {
      lightBlock.push(lightEntity(`acc_roof_light_dim_${room}_${idx}`, L[0], L[1], L[2], DIM_RADIUS, DIM_INTENSITY, DIM_MASK)); nL++;
    }
  });
}
// PLAZA safe-haven lights: always-on (both states), NO ceiling (Plaza stays open). Lit pre-power so OUTSIDE
// feels safe while the roofed rooms are almost black. targetname acc_roof_light_* so strip() cleans it on re-run.
gridLights( ...PLAZA_FOOTPRINT ).forEach((L, idx) => {
  lightBlock.push(lightEntity(`acc_roof_light_plaza_${idx}`, L[0], L[1], L[2], PLAZA_RADIUS, PLAZA_INTENSITY, ALWAYS_MASK)); nL++;
});
lines.splice(wclose, 0, ...ceilBlock);
while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...lightBlock, '');

fs.writeFileSync(OUT, lines.join('\n'));
console.log(`wrote ${nC} ceiling(s) + ${nL} light(s) -> ${OUT}`);
