#!/usr/bin/env node
// =============================================================================
// gen_abyss_layer.js - "Made in Abyss" vertical descent. Stamp identical enclosed
// floors BELOW the existing Bus Station trench (the trench/pit = Layer 1) and the
// stairwells that connect them. 5 floors total: L1 -240 (pit), L2 -480, L3 -720,
// L4 -960, L5 -1200 (240u pitch). Re-runnable + idempotent (strips its own -ACA2-
// marked brushes/lights + "// ACC ABYSS" tag comments; re-carves the pit floor
// only while it's still whole). `--upto N` builds only L1..LN for INCREMENTAL
// bake-gating (one layer at a time); `--revert` removes everything + restores the
// original pit floor.
//
// ---- WHY THIS IS BAKE-SAFE + PATHING-SAFE (hard-won, see memories) -----------
//  * Brushes use the EXACT box() six-plane filler-winding + hex GUID proven to
//    BAKE (gen_corp_trench.js). Real-corner windings + malformed GUIDs crash the
//    lightmapper at brush.cpp:1860 (memory led-relight-dead-end-enclosed-geometry).
//    Do NOT "clean up" the winding.
//  * EVERY descent well is a SLIM center strip whose stairs run along the WIDE (X)
//    axis and step off the bottom EASTWARD into open interior floor - so the stairs
//    NEVER end at the next layer's wall (the "zombies stuck at the bottom" bug, user
//    2026-06-21). The pit/floor carves into west + east FULL-DEPTH chunks joined by
//    a bridge on the well's far side => ONE connected surface (West-Bridge-East),
//    never bisected. (Earlier dead ends, all user-caught: a full-depth central well
//    BISECTED the trench; an SE-corner well merged with the existing east trench
//    stair = a navmesh break; a corner well ended the stairs jammed in a 2-wall
//    corner.) T-junctions are same-plane (cod2map fixes them), never the thin-lip
//    different-z cull that caused the under-room fall-through.
//  * Wells ALTERNATE south/north per descent (D1 XS, D2 XN, D3 XS, D4 XN) so a
//    floor's down-well is never where the stairs from above land. Stairs are SLIM
//    (128u Y), centered (x[-112,112], ~600u clear of the pit's trench stairs).
//  * Each layer's walls stack into one continuous sealed perimeter shaft; the floor
//    slabs subdivide it into rooms. Each room bakes dark -> 6 always-dim lights.
//
// ---- WIRING (no GSC change needed for any layer) -----------------------------
//  Every floor sits at z<=-36 inside x[-900,900] y[-400,2900] = the trench OOB-veto
//  box (_acc_bus_trench.gsc player_in_underground), so standing on any layer does
//  NOT trip the stock out-of-playable-area hard-kill. Zombies path the 16/16 stairs
//  once cod2map regenerates the navmesh. (Parallel system: _acc_exo.gsc reads the
//  layer depth and expects these z-levels -480/-720/-960/-1200 - keep them.)
//
// !! LED bake is THE GATE: build with tools/build_map.ps1 (NO -SkipLED) or
//    tools/_bake_test.ps1. Bake-gate EACH layer (--upto). If it crashes
//    (brush.cpp:1860) or the atlas over-budgets, revert to the last good --upto.
//
// Usage: node tools/gen_abyss_layer.js [--upto N]   apply L1..LN (default N=5)
//        node tools/gen_abyss_layer.js --revert      UNDO: strip all + restore pit floor
//        node tools/gen_abyss_layer.js --out <file>  write elsewhere (dry run)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');
const uptoArg = process.argv.indexOf('--upto');
const MAX_LAYER = uptoArg > 0 ? Math.max(2, Math.min(5, parseInt(process.argv[uptoArg + 1], 10) || 5)) : 5;

// The ORIGINAL pit-floor brush, verbatim from the live .map (box(-781,819,1723,2173,-256,-240)
// with its original guid). Re-inserted on --revert so reverting is byte-faithful (git can't help:
// the .map had other uncommitted WIP before this change, so `git restore` would nuke that too).
const ORIG_TRENCH_FLOOR = [
  '// corp trench floor',
  '{',
  ' guid "{7A2B9F00-ACC3-4E0C-8A3F-000000000303}"',
  ' ( 134.5 459.5 -256 ) ( 86.5 459.5 -256 ) ( 86.5 419.5 -256 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 94.5 419.5 -240 ) ( 94.5 459.5 -240 ) ( 142.5 459.5 -240 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 86.5 1723 88 ) ( 134.5 1723 88 ) ( 134.5 1723 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 819 415.5 88 ) ( 819 455.5 88 ) ( 819 455.5 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( 138.5 2173 88 ) ( 90.5 2173 88 ) ( 90.5 2173 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  ' ( -781 459.5 88 ) ( -781 419.5 88 ) ( -781 419.5 0 ) script_floor_ceiling 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0',
  '}',
];

// ---- pit / shared footprint (verified vs the live .map "corp trench floor" brush) ----
const PIT_X1 = -781, PIT_X2 = 819;       // footprint width (every layer uses it)
const PIT_Y1 = 1723, PIT_Y2 = 2173;      // footprint depth (the open trench band)
const PIT_FLOOR_TOP = -240, PIT_SLAB_BOT = -256;  // L1 walkable floor / its base
const TRENCH_FLOOR_GUID = '{7A2B9F00-ACC3-4E0C-8A3F-000000000303}';  // the pit-floor brush to carve

const PITCH = 240, FLOOR_TH = 16, WALL_TH = 20, STEP = 16, N_STEPS = 14;
const WELL_RUN = STEP * N_STEPS;          // 224u = the 14-step run, laid along the WIDE (X) axis
const WELL_HALF = WELL_RUN / 2;           // 112 = half the run (well centered on x=0, clear of side walls)
const WELL_YD = 128;                      // well depth in Y (against the south/north wall) = slim stair width
const F = 'script_floor_ceiling', W = 'script_wall';

// Bottom-layer (L5) SOUTH doorway -> the "second part" hallway/plaza (gen_descent_hub.js builds the
// hallway + open-air plaza BEYOND this opening; _acc_abyss_doors.gsc spawns the communal
// acc_abyss_hub_door slab that fills it). The L5 south wall is emitted with a centered gap (jambs +
// lintel) instead of a solid slab. KEEP IN SYNC with gen_descent_hub.js HUB_DOOR_* + the hub door slab.
const HUB_DOOR_HALF = 96;      // doorway half-width -> 192u opening, centered on x=0
const HUB_DOOR_H = 200;        // doorway height above the L5 floor (opening z[fz, fz+200])
const BOTTOM_LAYER = 5;        // the true bottom (z=-1200); ONLY this layer's south wall gets the doorway

// floor z of layer n: F1=-240 (pit) .. F5=-1200
function floorZ(n) { return PIT_FLOOR_TOP - (n - 1) * PITCH; }
// descent k connects L[k]->L[k+1]; its well is cut into L[k]'s floor. ALL descents run the stairs along
// the WIDE (X) axis and step off the bottom EASTWARD into open interior floor, so the stairs NEVER end at
// the next layer's wall (the "zombies stuck at the bottom" bug, user 2026-06-21). The well is a slim
// center strip against the SOUTH (XS) or NORTH (XN) wall; we ALTERNATE S/N so a floor's down-well is
// never where the stairs from above land. D1 (L1 pit) = XS, centered ~600u clear of the trench crossing
// stairs (which hug the far west x[-761,-665] / east x[703,799] walls).
// !! D1 (L1 pit) well stays CENTERED (x[-112,112]) and on the SOUTH. The south under-room (overclock)
//    door was moved WEST to x[-192,-112] and the north under-room door is center-NORTH (reachable on the
//    north bridge) - both clear of this centered south well. Do NOT move the D1 well WEST or it re-blocks
//    the overclock door (zombies can't reach it = player invincible there; user-caught 2026-06-21).
function descentCorner(k) { return (k % 2 === 1) ? 'XS' : 'XN'; }   // D1 XS, D2 XN, D3 XS, D4 XN
function wellRect(k) {
  const c = descentCorner(k);
  if (c === 'XS') return { c, x1: -WELL_HALF, x2: WELL_HALF, y1: PIT_Y1, y2: PIT_Y1 + WELL_YD };  // center, south wall
  return { c: 'XN', x1: -WELL_HALF, x2: WELL_HALF, y1: PIT_Y2 - WELL_YD, y2: PIT_Y2 };            // center, north wall
}

// ---- bake-safe box() (verbatim from gen_corp_trench.js; DO NOT alter winding) -
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAB00-ACA2-4E0C-8A3F-${c}}`;   // -ACA2- marker => strippable on re-run
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

// ---- bake-safe light (verbatim kelson8 PRIMARY_OMNI from gen_underground_lights) ----
let lc = 0;
function lguid() { lc++; const c = lc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAB01-ACA2-4E14-8A3F-${c}}`; }
function lightEntity(tag, x, y, z, radius, intensity) {
  return ['{', `guid "${lguid()}"`,
    '"classname" "light"', `"targetname" "${tag}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    '"_color" "1 1 1"', `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    // DARK until power (user 2026-06-21): lightingstate1=0 => off pre-power (Radiant State 1), on post-power.
    '"lightingstate1" "0"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

// ---- strip prior run: -ACA2- leaf blocks, my tag comments, AND the original
//      pit-floor brush (so the carve is idempotent) + its orphan comment. -------
function strip(lines) {
  const out = [];
  let k = 0;
  while (k < lines.length) {
    const t = lines[k].trim();
    if (t.startsWith('// ACC ABYSS')) { k++; continue; }
    if (t === '// corp trench floor') { k++; continue; }   // dropped when we remove the brush
    if (t === '{') {
      let d = 0, j = k, leaf = true, marked = false;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') { d++; if (d > 1) leaf = false; }
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
        if (lines[j].includes('-ACA2-') || lines[j].includes(TRENCH_FLOOR_GUID)) marked = true;
      }
      if (leaf && marked) { k = j; continue; }   // skip the whole leaf block
      out.push(lines[k]); k++; continue;         // non-leaf (worldspawn) / unmarked: descend
    }
    out.push(lines[k]); k++;
  }
  return out;
}

// ---- find worldspawn close (entity 0) so brushes inject INSIDE it -------------
function worldspawnClose(lines) {
  let depth = 0, entityIdx = -1;
  for (let i = 0; i < lines.length; i++) {
    const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
    for (let o = 0; o < opens; o++) { if (depth === 0) entityIdx++; depth++; }
    for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && entityIdx === 0) return i; }
  }
  return -1;
}

// ---- generation -------------------------------------------------------------
const brushes = [];
const lights = ['// ACC ABYSS lights (gen_abyss_layer.js) - always dim'];
let nL = 0;
const badd = (label, txt) => { brushes.push(`// ACC ABYSS ${label}`); brushes.push(txt); };

// A layer floor at z[floorZ(n)-16, floorZ(n)], split around its down-well w into a CONNECTED
// L-shape (chunk A = main + chunk B = corner patch). w=null => full single slab (deepest layer).
function emitFloor(n, w) {
  const top = floorZ(n), base = top - FLOOR_TH, tag = (n === 1) ? 'L1 pit' : `L${n}`;
  if (!w) { badd(`${tag} floor slab (full single slab) z[${base},${top}]`, box(PIT_X1, PIT_X2, PIT_Y1, PIT_Y2, base, top, F)); return; }
  // X-running center well: west + east FULL-DEPTH chunks (carry any existing side stairs) joined by a
  // bridge on the well's far long side, so the floor stays ONE connected surface (West-Bridge-East).
  badd(`${tag} floor chunk A (west, full depth)`, box(PIT_X1, w.x1, PIT_Y1, PIT_Y2, base, top, F));
  badd(`${tag} floor chunk B (east, full depth)`, box(w.x2, PIT_X2, PIT_Y1, PIT_Y2, base, top, F));
  if (w.c === 'XS') badd(`${tag} floor chunk C (north bridge A<->B)`, box(w.x1, w.x2, w.y2, PIT_Y2, base, top, F));
  else              badd(`${tag} floor chunk C (south bridge A<->B)`, box(w.x1, w.x2, PIT_Y1, w.y1, base, top, F));
}

// Perimeter walls for layer n: from this floor up to the floor above (the ceiling), placed just
// OUTSIDE the footprint so they stack into one continuous sealed shaft (no leak below the old slabs).
function emitWalls(n) {
  const fz = floorZ(n), cz = floorZ(n - 1), tag = `L${n}`;
  badd(`${tag} wall west`,  box(PIT_X1 - WALL_TH, PIT_X1, PIT_Y1, PIT_Y2, fz, cz, W));
  badd(`${tag} wall east`,  box(PIT_X2, PIT_X2 + WALL_TH, PIT_Y1, PIT_Y2, fz, cz, W));
  // SOUTH wall: the TRUE bottom (L5) gets a centered DOORWAY (west jamb + east jamb + lintel) = the
  // exit to the "second part" hallway. Every other layer's south wall is a solid slab. The opening is
  // x[-HUB_DOOR_HALF, HUB_DOOR_HALF] z[fz, fz+HUB_DOOR_H]; gen_descent_hub.js's acc_abyss_hub_door fills it.
  if ( n === BOTTOM_LAYER ) {
    badd(`${tag} south wall WEST jamb (bottom doorway)`, box(PIT_X1 - WALL_TH, -HUB_DOOR_HALF, PIT_Y1 - WALL_TH, PIT_Y1, fz, cz, W));
    badd(`${tag} south wall EAST jamb (bottom doorway)`, box(HUB_DOOR_HALF, PIT_X2 + WALL_TH, PIT_Y1 - WALL_TH, PIT_Y1, fz, cz, W));
    badd(`${tag} south wall LINTEL (bottom doorway)`,    box(-HUB_DOOR_HALF, HUB_DOOR_HALF, PIT_Y1 - WALL_TH, PIT_Y1, fz + HUB_DOOR_H, cz, W));
  } else {
    badd(`${tag} wall south`, box(PIT_X1 - WALL_TH, PIT_X2 + WALL_TH, PIT_Y1 - WALL_TH, PIT_Y1, fz, cz, W));
  }
  badd(`${tag} wall north`, box(PIT_X1 - WALL_TH, PIT_X2 + WALL_TH, PIT_Y2, PIT_Y2 + WALL_TH, fz, cz, W));
}

// Stairs for descent k (well w in L[k]'s floor): from floorZ(k) down to floorZ(k+1). SLIM tread;
// 14 steps descending from the OPEN (chunk-B) edge toward the corner so you walk straight down.
function emitStairs(k, w) {
  const topZ = floorZ(k), botZ = floorZ(k + 1);
  // Treads run along X (the wide axis), filling the well's Y (slim 128u). Enter from the WEST open edge
  // (high), descend EAST, and step off the bottom EASTWARD into open interior floor (x ~ +112, far from
  // any wall) so zombies disperse instead of jamming a corner.
  for (let s = 1; s <= N_STEPS; s++) {
    const tread = topZ - STEP * s;                 // topZ-16 (high, west) .. topZ-224 (low, east)
    const xA = w.x1 + STEP * (s - 1), xB = w.x1 + STEP * s;
    badd(`D${k} stair ${s} (z=${tread})`, box(xA, xB, w.y1, w.y2, botZ, tread, F));
  }
}

// Make descent k's well a fully ENCLOSED stairwell - a "door to go down levels" you can ONLY enter by
// walking down the stairs, NEVER by jumping off a side ledge (user 2026-06-22). The FIRST pass only sealed
// BELOW the floor, so the opening in the floor was still wide open to jump into (the screenshot bug). The
// stairs run W->E inside the slim well; we wall the THREE non-entry sides both BELOW the floor (so a zombie
// on the treads can't fall out the side) AND as a jump-proof RAILING ABOVE the floor (rail=128u > any
// jump/mantle, so nothing on this layer's floor can drop in):
//   - SOUTH + NORTH (the long sides): full wall fz .. (cz+rail). One of them is the perimeter side (already
//     walled) -> redundant but harmless; doing both keeps XS/XN uniform.
//   - EAST (the short EXIT side): railing ONLY above the floor (cz .. cz+rail). The stairs step off the
//     BOTTOM eastward onto the next layer, so the east must stay OPEN below the floor (do NOT seal it).
//   - WEST (x=w.x1) = the stair ENTRY (step down onto the top tread): left OPEN.
// Bake-safe box() six-plane winding (DO NOT alter).
function emitWellWalls(k, w) {
  const fz = floorZ(k + 1), cz = floorZ(k), rail = cz + 128;   // next floor -> railing top above this floor
  badd(`D${k} stairwell SOUTH wall (seal+rail)`, box(w.x1, w.x2, w.y1 - WALL_TH, w.y1, fz, rail, W));
  badd(`D${k} stairwell NORTH wall (seal+rail)`, box(w.x1, w.x2, w.y2, w.y2 + WALL_TH, fz, rail, W));
  badd(`D${k} stairwell EAST rail (top only; bottom exits east)`, box(w.x2, w.x2 + WALL_TH, w.y1, w.y2, cz, rail, W));
}

// Depth-dimming curve (user 2026-06-22): each layer DOWN is dimmer, to telegraph the rising risk of
// descending. STEEPENED to GEOMETRIC (HALVING per layer, user "scale even more per trench level") so the
// dark closes in fast: L2 0.40 -> L3 0.20 -> L4 0.10 -> L5 0.05 (deepest = 1/8 of the top, was 1/4 on the
// old linear curve), floored at 0.03 (still above the room near-black so it stays barely navigable).
// KEEP IN SYNC with tools/_grade_abyss_lights.js (the targeted .map editor that applies this).
function abyssLayerIntensity(n) { return Math.max(0.03, +(0.40 * Math.pow(0.5, n - 2)).toFixed(3)); }

// NO lights below the pit (user 2026-06-22 "remove the lights in the trenches completely, only from L2 and on -
// Bus Station trench is fine with lights"). emitLights is only called for L2..L5 (the abyss descent), so
// returning 0 makes the WHOLE abyss pitch black - lit only by what little spills down the wells. The Bus
// Station trench itself = L1 (the pit), which gets no abyss lights here anyway, so its lighting is untouched.
// (Restore the depth-descending pools with `return Math.max(0, 5 - n)` if you want them back.)
function lightsForLayer(n) { return 0; }

function emitLights(n) {
  const lz = floorZ(n) + 100, LR = 250, LI = abyssLayerIntensity(n);
  const count = lightsForLayer(n);
  // Spread `count` pools evenly across the centre (x[-350,350]) at the layer's y-mid, over the descent stairs,
  // radius 250 so the wide x-edges stay dark. count 0 => emit nothing (pitch-black layer).
  for ( let i = 0; i < count; i++ ) {
    const x = ( count === 1 ) ? 0 : Math.round( -350 + ( 700 * i ) / ( count - 1 ) );
    lights.push( lightEntity( `acc_abyss_l${n}_light_${nL}`, x, 1948, lz, LR, LI ) ); nL++;
  }
}

// L1 (pit): carve the EXISTING trench floor around D1's well + the stairs down into L2.
const d1 = wellRect(1);
emitFloor(1, d1);
emitStairs(1, d1);
emitWellWalls(1, d1);
// L2..MAX: floor (split around its own down-well unless deepest), walls, lights, + down-well stairs.
for (let n = 2; n <= MAX_LAYER; n++) {
  const hasDown = (n <= MAX_LAYER - 1);
  const w = hasDown ? wellRect(n) : null;
  emitFloor(n, w);
  emitWalls(n);
  emitLights(n);
  if (hasDown) emitStairs(n, w);
  if (hasDown) emitWellWalls(n, w);
}

// ---- assemble ---------------------------------------------------------------
const rawLines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let lines = strip(rawLines);   // removes all -ACA2- brushes/lights + "// ACC ABYSS" + (if present) the pit-floor brush

if (REVERT) {
  // UNDO: my additions are gone (stripped). Restore the original pit-floor brush at its old spot
  // (just before the "// corp trench west end wall"), else fall back to before worldspawn close.
  let at = lines.findIndex((l) => l.trim() === '// corp trench west end wall');
  if (at === -1) at = worldspawnClose(lines);
  if (at === -1) { console.error('ERROR: cannot find re-insert point for the pit floor.'); process.exit(2); }
  const o = [...lines.slice(0, at), ...ORIG_TRENCH_FLOOR, ...lines.slice(at)];
  while (o.length && o[o.length - 1] === '') o.pop();
  o.push('');
  fs.writeFileSync(OUT, o.join('\n'));
  console.log(`[abyss] REVERTED: stripped all abyss layers + restored the original pit floor.`);
  console.log(`[abyss] wrote ${OUT} (${rawLines.length} -> ${o.length} lines). Re-apply: node tools/gen_abyss_layer.js`);
  process.exit(0);
}

const wsClose = worldspawnClose(lines);
if (wsClose === -1) { console.error('ERROR: worldspawn close not found.'); process.exit(2); }

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) {
    out.push(`// ACC ABYSS (gen_abyss_layer.js) ===== BEGIN brushes (L1..L${MAX_LAYER}) =====`);
    out.push(...brushes);
    out.push('// ACC ABYSS ===== END brushes =====');
  }
  out.push(lines[i]);
}
while (out.length && out[out.length - 1] === '') out.pop();
out.push(...lights, '');
fs.writeFileSync(OUT, out.join('\n'));

const wells = [];
for (let k = 1; k < MAX_LAYER; k++) wells.push(`D${k}:${descentCorner(k)}(${floorZ(k)}->${floorZ(k + 1)})`);
console.log(`[abyss] built L1..L${MAX_LAYER}; floors ${Array.from({ length: MAX_LAYER }, (_, i) => floorZ(i + 1)).join('/')}`);
console.log(`[abyss] descents (alternating corners, slim stairs): ${wells.join('  ')}`);
console.log(`[abyss] ${nL} lights; deepest = L${MAX_LAYER} (full slab, no down-well). wrote ${OUT} (${lines.length} -> ${out.length} lines)`);
