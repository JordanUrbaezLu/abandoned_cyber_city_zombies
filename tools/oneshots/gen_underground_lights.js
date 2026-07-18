#!/usr/bin/env node
// =============================================================================
// gen_underground_lights.js - baked ALWAYS-DIM lights for the enclosed underground rooms
// (Foundry, Stalls, Cages, Reactor Core). They bake pitch-black (sealed, no sky, black volume_sun
// global_fill), so each needs interior light entities.
//
// USER 2026-06-19: "I want the lights dim down here ALWAYS - power on or off it's dim." So unlike
// the surface (gen_room_roofs.js dim->bright power reveal), the underground uses ONE always-on set
// lit in EVERY lighting state (mask "1 1 1 1"), at a single low intensity. No power flip down here.
//
// Uses the proven kelson8 PRIMARY_OMNI light block, placed below the z=-96 ceiling throwing down to
// the z=-240 floor. !! LED bake is the GATE: full build_map.ps1 (no -SkipLED). Atlas budget finite -
// trim lights if the bake crashes/over-budgets. Re-runnable (strips its -ACC8- marked entities).
//
// Usage: node tools/gen_underground_lights.js [--out <file>]   (default: writes the real .map)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;

const LIGHT_Z      = -150;   // below the z=-96 ceiling; throws down to the z=-240 floor (room z[-240,-96])
const LIGHT_RADIUS = 260;
const GRID_SPACING = 300;    // smaller = denser
const GRID_INSET   = 80;     // keep lights off the walls (small enough that the shallow south concourse still gets a row, not 1 center light)
const ALWAYS_MASK  = ['1', '1', '1', '1'];  // lit in EVERY lighting state => dim whether power is on or off
const POWER_MASK   = ['0', '1', '1', '1'];  // DARK pre-power (state0=ls1), lit post-power (user 2026-06-21:
                                            // "0 light until power" - the sealed areas now power-gate like the
                                            // surface rooms instead of being always-on).

// enclosed underground rooms: footprint [x1,x2,y1,y2] + the (single) DIM bake_intensity_scale.
// "dim but navigable" ~0.35; the Reactor Core stays a touch darker. Re-run + FULL build to retune.
// `z` overrides LIGHT_Z (the open pit has no z=-96 ceiling, so its lights sit lower over the floor).
const ROOMS = {
  foundry: { box: [-192, 192, 1379, 1723], dim: 0.35 },
  stalls:  { box: [-720, -192, 1379, 1700], dim: 0.35 },
  cages:   { box: [192, 758, 1379, 1700], dim: 0.35 },
  core:    { box: [-384, 384, 2189, 2732], dim: 0.25 },  // the reactor arena (expanded) - deliberately darker
  pit:     { box: [-665, 703, 1723, 2173], dim: 0.3, z: -180 },  // OPEN danger hub (caches/vendor/event) - was pitch-black (audit P1)
  concourse: { box: [-720, 758, 1163, 1379], dim: 0.35 },  // south corridor linking Stalls/Foundry/Cages
  arena_w:   { box: [-720, -384, 2280, 2640], dim: 0.3 },   // north wing off the arena (west)
  arena_e:   { box: [384, 758, 2280, 2640], dim: 0.3 },     // north wing off the arena (east)
};

let gc = 0;
function guid() {
  gc++;
  const h = ('ulit' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  return `{${h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8)}-ACC8-4E14-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Verified kelson8 PRIMARY_OMNI light entity (identical to gen_room_roofs::lightEntity). White, no tint.
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

function gridLights(x1, x2, y1, y2) {
  const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2;
  const ix1 = x1 + GRID_INSET, ix2 = x2 - GRID_INSET, iy1 = y1 + GRID_INSET, iy2 = y2 - GRID_INSET;
  if (ix2 <= ix1 || iy2 <= iy1) return [[Math.round(cx), Math.round(cy)]];
  const nx = Math.max(1, Math.round((ix2 - ix1) / GRID_SPACING) + 1);
  const ny = Math.max(1, Math.round((iy2 - iy1) / GRID_SPACING) + 1);
  const out = [];
  for (let i = 0; i < nx; i++) for (let j = 0; j < ny; j++) {
    const x = nx === 1 ? cx : ix1 + (ix2 - ix1) * i / (nx - 1);
    const y = ny === 1 ? cy : iy1 + (iy2 - iy1) * j / (ny - 1);
    out.push([Math.round(x), Math.round(y)]);
  }
  return out;
}

// strip prior -ACC8- marked light leaf-blocks + the tag comment (re-runnable).
function strip(lines) {
  const MARK = '-ACC8-', TAG = '// ACC underground lights';
  const out = [];
  for (let k = 0; k < lines.length; k++) {
    const t = lines[k].trim();
    if (t.includes(TAG)) continue;
    if (t === '{') {
      let d = 0, leaf = true, marked = false, j = k;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') { d++; if (d > 1) leaf = false; }
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
        if (lines[j].includes(MARK)) marked = true;
      }
      if (leaf && marked) { k = j - 1; continue; }
    }
    out.push(lines[k]);
  }
  return out;
}

let lines = strip(fs.readFileSync(MAP, 'utf8').split(/\r?\n/));
const block = ['// ACC underground lights (tools/gen_underground_lights.js) - DARK until power (POWER_MASK)'];
let nL = 0;
for (const [room, r] of Object.entries(ROOMS)) {
  const z = (r.z !== undefined ? r.z : LIGHT_Z);
  gridLights(...r.box).forEach((L, idx) => {
    block.push(lightEntity(`acc_under_light_${room}_${idx}`, L[0], L[1], z, LIGHT_RADIUS, r.dim, POWER_MASK)); nL++;
  });
}
while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...block, '');
fs.writeFileSync(OUT, lines.join('\n'));
console.log(`wrote ${nL} ALWAYS-DIM underground light(s) across ${Object.keys(ROOMS).length} rooms -> ${OUT}`);
