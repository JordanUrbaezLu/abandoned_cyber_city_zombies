#!/usr/bin/env node
// =============================================================================
// gen_room_cover.js - tighten the rooms with standalone waist-high COVER blocks
// (break open sightlines, force weaving). Roofs were proven to crash the LED bake
// (2026-06-18), so difficulty comes from cover + selective shrink instead.
//
// RE-RUNNABLE: strips its own tagged block then re-emits, so edit COVER below + re-run.
// LED-safe construction (docs/38 §5): standalone CLOSED boxes, bottom coplanar with the
// floor at z0 (proven-safe seam), waist height (z0..COVER_H, shoot-over), kept >=96u from
// every riser/doorway and not 8u-off a wall (slivers). cover boxes bake fine; ceilings do NOT.
// Coordinates come from tools/probe_rooms.js (riser points) - the old greybox generators are stale.
//
// !! BAKE-GATE EVERY CHANGE: after running, _bake_test.ps1 the map; revert (restore the
//    .pre-cover-bak backup or re-run with the room's boxes removed) if it CRASHES. !!
//
// Usage: node tools/gen_room_cover.js [--out <file>]   (default: writes the real .map)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;

const COVER_H = 88;             // waist/chest height: shoot over, block sightline + tighten lanes
const TAG = '// ACC room cover (tools/gen_room_cover.js)';

// Per-room cover boxes: [x1, x2, y1, y2]. z is [0, COVER_H]. Derived from probe_rooms.js riser
// points so each box clears every riser (>=96u) + the doorway bands. EXPAND per room here.
const COVER = {
  // FEASIBILITY PROBE: ONE box in wide-open Plaza floor (slab x[-2018,1094] y[-1895,767]), 1100u south
  // of the nearest riser - nothing to overlap. If THIS hangs the bake, cover itself crashes the LED here.
  plaza_test: [
    [-287, -167, -1060, -940],
  ],
};

// Deterministic HEX GUID (counter-based), matching add_perk_alcoves / the rest of the map.
let gc = 0;
function guid() {
  gc++;
  const h = ('cover' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACC5-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush - VERBATIM PROVEN winding from gen_zone_greybox.js / add_perk_alcoves.box
// (the "filler-plane" winding that BAKES; the real-corner winding crashes brush.cpp:1860). Each face is
// 3 points defining the plane; only the defining axis (x1/x2/y1/y2/z1/z2) varies, the rest are fixed filler.
function boxBrush(x1, x2, y1, y2, z1, z2) {
  const t = 'script_wall 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}'].join('\n');
}

function stripTagged(lines) {
  const out = [];
  for (let k = 0; k < lines.length; k++) {
    if (lines[k].includes(TAG)) {
      // skip the tag line + the following matched brush block
      let depth = 0, started = false; k++;
      while (k < lines.length) {
        const t = lines[k].trim();
        if (t === '{') { depth++; started = true; } else if (t === '}') depth--;
        k++;
        if (started && depth === 0) break;
      }
      k--; continue;
    }
    out.push(lines[k]);
  }
  return out;
}

let lines = stripTagged(fs.readFileSync(MAP, 'utf8').split(/\r?\n/));
const e1 = lines.indexOf('// entity 1');
if (e1 < 1 || lines[e1 - 1].trim() !== '}') { console.error('FATAL: cannot find worldspawn close'); process.exit(1); }

const blocks = [];
let n = 0;
for (const [room, boxes] of Object.entries(COVER)) {
  boxes.forEach((b, idx) => {
    blocks.push(`${TAG} ${room} #${idx} [${b.join(',')}] z[0,${COVER_H}]`);
    blocks.push(boxBrush(b[0], b[1], b[2], b[3], 0, COVER_H));
    n++;
  });
}

const out = lines.slice(0, e1 - 1).concat(blocks, lines.slice(e1 - 1)).join('\n');
fs.writeFileSync(OUT, out);
console.log(`wrote ${n} cover box(es) -> ${OUT}`);
