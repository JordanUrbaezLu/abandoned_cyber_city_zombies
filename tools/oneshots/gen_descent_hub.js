#!/usr/bin/env node
// =============================================================================
// gen_descent_hub.js - "the second part of the map". Builds, BELOW the abyss bottom
// (L5, z=-1200), a LONG DARK HALLWAY running south out of the L5 south doorway, opening
// into a LARGE OPEN-AIR PLAZA - a deep pit far below the city whose top is capped with the
// stock `sky` material so you look UP at the night sky we already set (skybox_default_night).
// This plaza becomes the second hub (perks / box / PaP / kiosks get spread through it later).
//
// Pairs with gen_abyss_layer.js: that generator cuts the centered DOORWAY in the L5 south wall
// (HUB_DOOR_HALF/HUB_DOOR_H - KEEP IN SYNC). _acc_abyss_doors.gsc spawns the communal
// acc_abyss_hub_door slab (authored here) that fills the doorway until the team buys it open.
//
// ---- WHY THIS IS BAKE-SAFE (hard-won, see memories) --------------------------
//  * Brushes use the EXACT box() six-plane filler-winding + hex GUID proven to BAKE
//    (gen_abyss_layer.js / gen_corp_trench.js). Real-corner windings crash brush.cpp:1860
//    (memory led-relight-dead-end-enclosed-geometry). DO NOT "clean up" the winding.
//  * Floors are SINGLE SLABS (one brush each), never thin lips over a hollow (memory
//    single-slab-floor-over-room). Hallway + plaza floor + the doorway-threshold patch are
//    coplanar at z=-1200 so cod2map T-junctions fuse them into ONE navmesh surface.
//  * OPEN-AIR = the plaza top is a `sky`-material brush (NOT "no brush" - an uncapped hole
//    LEAKS and breaks the bake). The plaza sits SOUTH of all surface geometry (y < -560, the
//    surface Plaza's south edge) so the sky cap has clear void above it (no surface floor over
//    a sky surface). `sky` is the map's existing skybox material (worldspawn skybox_default_night);
//    this adds NO new sky and needs NO .zone line (face material).
//  * DISTINCT GUID marker -ACE0- + comment-block markers so the abyss (-ACA2-) and door (-ACD0-)
//    generators leave this alone and vice-versa.
//
// ---- WIRING (GSC, separate change) -------------------------------------------
//  _acc_bus_trench.gsc must veto the stock OOB hard-kill over this footprint (player_in_second_part)
//  AND exclude it from underground_layer() (it is NOT a trench layer - no per-layer amping here).
//
// !! GEOMETRY -> LED bake is THE GATE. After this, run gen_abyss_layer.js FIRST (refresh the L5
//    doorway), THEN this, THEN a FULL build (tools/build_map.ps1, no -SkipLED) or tools/_bake_test.ps1.
//
// Usage: node tools/gen_descent_hub.js            inject/refresh the hallway + plaza + hub door
//        node tools/gen_descent_hub.js --revert    remove it all
//        node tools/gen_descent_hub.js --out <f>   write elsewhere (dry run)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');

// ---- constants (KEEP IN SYNC with gen_abyss_layer.js HUB_DOOR_* + the L5 doorway) ----
const HUB_DOOR_HALF = 96, HUB_DOOR_H = 200;   // doorway: x[-96,96], z[fz, fz+200] in the L5 south wall
const L5_FLOOR_TOP = -1200, FLOOR_TH = 16, WALL_TH = 20;
const FLOOR_BASE = L5_FLOOR_TOP - FLOOR_TH;       // -1216
const L5_SOUTH_FACE = 1703;                       // = PIT_Y1(1723) - WALL_TH(20); the south face of the L5 south wall (the abyss footprint y1 is 1723)

// hallway: a slim enclosed (DARK) tube from the L5 doorway south to the plaza north edge
const HALL_HALF = 96;                              // interior half-width (matches the doorway)
const HALL_CEIL_BOT = L5_FLOOR_TOP + HUB_DOOR_H;   // -1000 (200u clearance = the doorway height)
const HALL_CEIL_TOP = HALL_CEIL_BOT + FLOOR_TH;    // -984

// plaza: large OPEN-AIR pit, SOUTH of the surface map so its sky cap has clear void above it
// COMPRESSED 2026-08-02 (gen_compress_lab_paradise.js value-remapped the live .map brushes
// in place - preserving the mwiii_vertigo floor re-skin. A RE-RUN of this generator would
// LOSE that face paint; prefer in-place remaps for future resizes.)
const PLZ_X1 = -700, PLZ_X2 = 700;                // interior width 1400 (was 2000)
const PLZ_Y1 = -2000, PLZ_Y2 = -600;             // interior depth 1400 (was 1600); north edge -600 is clear south of surface Plaza (y=-560)
const PLZ_SKY_BOT = -200;                         // walls rise to here (a ~1000u-deep pit); the sky cap caps it
const PLZ_SKY_TOP = PLZ_SKY_BOT + FLOOR_TH;       // -184

const HALL_Y_S = PLZ_Y2 + WALL_TH;               // -580: hallway south end meets the plaza north wall's north face
const HALL_Y_N = L5_SOUTH_FACE;                  // 1703: hallway north end at the L5 doorway

const F = 'script_floor_ceiling', W = 'script_wall', SKY = 'sky';

// ---- bake-safe box() (VERBATIM winding from gen_abyss_layer.js - DO NOT alter) ----
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAB0E-ACE0-4E0C-8A3F-${c}}`;   // -ACE0- marker => distinct from abyss -ACA2- / doors -ACD0-
}
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
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
  ].join('\n');
}

// ---- bake-safe light (VERBATIM kelson8 PRIMARY_OMNI from gen_abyss_layer.js) ----
let lc = 0;
function lguid() { lc++; const c = lc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAB0F-ACE0-4E14-8A3F-${c}}`; }
function lightEntity(tag, x, y, z, radius, intensity) {
  return ['{', `guid "${lguid()}"`,
    '"classname" "light"', `"targetname" "${tag}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    '"_color" "1 1 1"', `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    // DARK until power (matches the abyss): lightingstate1=0 => off pre-power, on post-power.
    '"lightingstate1" "0"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

// ---- worldspawn brushes (hallway + plaza) ------------------------------------
const worldBrushes = [];
const wb = (label, txt) => { worldBrushes.push(`// ACC HUB ${label}`); worldBrushes.push(txt); };

// Doorway threshold floor patch (fills the 20u gap in the L5 south wall band so the floor is
// continuous L5 -> threshold -> hallway; without it you step over a 16u floorless slot).
wb('doorway threshold floor', box(-HUB_DOOR_HALF, HUB_DOOR_HALF, L5_SOUTH_FACE, L5_SOUTH_FACE + WALL_TH, FLOOR_BASE, L5_FLOOR_TOP, F));

// Hallway: floor + ceiling (DARK, enclosed) + 2 side walls. y[HALL_Y_S, HALL_Y_N].
wb('hallway floor (single slab)',   box(-HALL_HALF, HALL_HALF, HALL_Y_S, HALL_Y_N, FLOOR_BASE, L5_FLOOR_TOP, F));
wb('hallway ceiling',               box(-HALL_HALF, HALL_HALF, HALL_Y_S, HALL_Y_N, HALL_CEIL_BOT, HALL_CEIL_TOP, F));
wb('hallway wall west',             box(-HALL_HALF - WALL_TH, -HALL_HALF, HALL_Y_S, HALL_Y_N, FLOOR_BASE, HALL_CEIL_TOP, W));
wb('hallway wall east',             box(HALL_HALF, HALL_HALF + WALL_TH, HALL_Y_S, HALL_Y_N, FLOOR_BASE, HALL_CEIL_TOP, W));

// Plaza: single-slab floor (outer footprint, under the walls too) + perimeter walls rising to the
// sky cap + the OPEN-AIR `sky` cap. North wall has the hallway mouth (gap x[-96,96] z[-1200,-1000]).
wb('plaza floor (single slab)',     box(PLZ_X1 - WALL_TH, PLZ_X2 + WALL_TH, PLZ_Y1 - WALL_TH, PLZ_Y2 + WALL_TH, FLOOR_BASE, L5_FLOOR_TOP, F));
wb('plaza SKY cap (open-air)',      box(PLZ_X1 - WALL_TH, PLZ_X2 + WALL_TH, PLZ_Y1 - WALL_TH, PLZ_Y2 + WALL_TH, PLZ_SKY_BOT, PLZ_SKY_TOP, SKY));
wb('plaza wall south',              box(PLZ_X1 - WALL_TH, PLZ_X2 + WALL_TH, PLZ_Y1 - WALL_TH, PLZ_Y1, FLOOR_BASE, PLZ_SKY_TOP, W));
wb('plaza wall west',               box(PLZ_X1 - WALL_TH, PLZ_X1, PLZ_Y1, PLZ_Y2, FLOOR_BASE, PLZ_SKY_TOP, W));
wb('plaza wall east',               box(PLZ_X2, PLZ_X2 + WALL_TH, PLZ_Y1, PLZ_Y2, FLOOR_BASE, PLZ_SKY_TOP, W));
wb('plaza wall north WEST seg',     box(PLZ_X1 - WALL_TH, -HALL_HALF, PLZ_Y2, PLZ_Y2 + WALL_TH, FLOOR_BASE, PLZ_SKY_TOP, W));
wb('plaza wall north EAST seg',     box(HALL_HALF, PLZ_X2 + WALL_TH, PLZ_Y2, PLZ_Y2 + WALL_TH, FLOOR_BASE, PLZ_SKY_TOP, W));
wb('plaza wall north ABOVE mouth',  box(-HALL_HALF, HALL_HALF, PLZ_Y2, PLZ_Y2 + WALL_TH, HALL_CEIL_BOT, PLZ_SKY_TOP, W));

// ---- trailing entities (lights + the hub door slab) --------------------------
const trailing = [];

// Plaza insurance lights (open-air gets dim moonlight, but it is a deep pit + a HUB you must see in).
// 6 dim pools on a 3x2 grid; post-power only (lightingstate1=0). Tune later if too bright/dark.
const PLZ_LZ = L5_FLOOR_TOP + 100;   // -1100
let nL = 0;
for (const px of [-600, 0, 600]) for (const py of [-1000, -1800]) {
  trailing.push(lightEntity(`acc_hub_plaza_light_${nL}`, px, py, PLZ_LZ, 500, 0.25)); nL++;
}
// Hallway: 2 VERY dim pools so the long dark tube stays navigable without losing the dark mood.
for (const hy of [400, 1100]) {
  trailing.push(lightEntity(`acc_hub_hall_light_${nL}`, 0, hy, PLZ_LZ, 250, 0.10)); nL++;
}

// Communal hub door: an UPRIGHT script_brushmodel filling the L5 doorway opening (x[-96,96],
// y[1703,1723], z[-1200,-1000]). _acc_abyss_doors.gsc starts it show/solid/disconnectpaths and,
// once the team pays 100 shards + 100k points AND everyone gathers, hide/notsolid/connectpaths.
const hubDoorEntity = [
  '{',
  ` guid "${guid()}"`,
  ' "classname" "script_brushmodel"',
  ' "targetname" "acc_abyss_hub_door"',
  ' // brush 0 (communal gate to the second part - fills the L5 south doorway)',
  box(-HUB_DOOR_HALF, HUB_DOOR_HALF, L5_SOUTH_FACE, L5_SOUTH_FACE + WALL_TH, L5_FLOOR_TOP, HALL_CEIL_BOT, W).split('\n').map(l => ' ' + l).join('\n'),
  '}',
].join('\n');

// ---- markers ----------------------------------------------------------------
const WS_BEGIN = '// >>> ACC HUB WORLDSPAWN (gen_descent_hub.js) - hallway + open-air plaza brushes';
const WS_END   = '// <<< ACC HUB WORLDSPAWN';
const ENT_BEGIN = '// >>> ACC HUB ENTITIES (gen_descent_hub.js) - plaza/hall lights + communal hub door';
const ENT_END   = '// <<< ACC HUB ENTITIES';

// ---- idempotent strip of my prior marked blocks -----------------------------
function stripBlocks(lines, beginMark, endMark) {
  for (;;) {
    const b = lines.findIndex((l) => l.includes(beginMark));
    if (b === -1) break;
    let e = -1;
    for (let i = b; i < lines.length; i++) { if (lines[i].includes(endMark)) { e = i; break; } }
    if (e === -1) { lines = [...lines.slice(0, b), ...lines.slice(b + 1)]; continue; }
    lines = [...lines.slice(0, b), ...lines.slice(e + 1)];
  }
  return lines;
}

// ---- find worldspawn close (entity 0) so brushes inject INSIDE it ------------
function worldspawnClose(lines) {
  let depth = 0, entityIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
    for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; depth++; }
    for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && entityIdx === 0) return i; }
  }
  return -1;
}

// ---- assemble ---------------------------------------------------------------
let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
lines = stripBlocks(lines, WS_BEGIN, WS_END);
lines = stripBlocks(lines, ENT_BEGIN, ENT_END);

if (REVERT) {
  while (lines.length && lines[lines.length - 1] === '') lines.pop();
  lines.push('');
  fs.writeFileSync(OUT, lines.join('\n'));
  console.log(`[hub] REVERTED: stripped the hallway + plaza + hub door. wrote ${OUT}`);
  process.exit(0);
}

const wsClose = worldspawnClose(lines);
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) {
    out.push(WS_BEGIN);
    out.push(...worldBrushes);
    out.push(WS_END);
  }
  out.push(lines[i]);
}
while (out.length && out[out.length - 1] === '') out.pop();
out.push(ENT_BEGIN, ...trailing, hubDoorEntity, ENT_END, '');
fs.writeFileSync(OUT, out.join('\n'));

console.log(`[hub] built: hallway y[${HALL_Y_S},${HALL_Y_N}] x[${-HALL_HALF},${HALL_HALF}] (dark tube)`);
console.log(`[hub] plaza interior x[${PLZ_X1},${PLZ_X2}] y[${PLZ_Y1},${PLZ_Y2}] floor z=${L5_FLOOR_TOP}, OPEN-AIR sky cap z=${PLZ_SKY_BOT} (~${PLZ_SKY_BOT - L5_FLOOR_TOP}u-deep pit)`);
console.log(`[hub] ${nL} lights; acc_abyss_hub_door slab fills the L5 doorway. wrote ${OUT} (${lines.length} -> ${out.length} lines)`);
console.log(`[hub] REMINDER: run gen_abyss_layer.js FIRST (L5 doorway), then this, then a FULL LED-baked build.`);
