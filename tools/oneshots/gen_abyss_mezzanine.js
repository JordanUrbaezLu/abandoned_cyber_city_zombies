#!/usr/bin/env node
// =============================================================================
// gen_abyss_mezzanine.js - abyss-floor mezzanine decks (docs/30 "Infected Descent"
// enhancement, Phase 0 2026-07-12). Currently emits the L4 "GANTRY": a raised
// walkway along the NORTH wall of abyss L4 (the Specimen Vault floor, z=-960),
// reached by a 7-tread stair from the open floor. The L5 "Overlook" (W wall,
// double-jump perch) is Phase 3 - add it to PIECES/LIGHTS below when it lands.
//
// ---- WHY EVERY PIECE IS A script_brushmodel (do NOT "simplify" to worldspawn) --
// A solid WORLDSPAWN brush below z=-240 inside the enclosed abyss shaft CRASHES
// the Radiant LED bake at brush.cpp:1860 (memory led-relight-dead-end-enclosed-
// geometry). script_brushmodel entities are LED-EXEMPT (the lightmapper ignores
// them - proven by the acc_clip_* abyss station clips + the acc_ec_right_wall /
// acc_door_* visible slabs), so a deep deck/stair here carries ZERO bake risk.
// Consequences to keep in mind:
//  * NAVMESH ignores brushmodels too -> zombies can NEVER path up the stair or
//    onto the deck. The Gantry is player-only high ground BY DESIGN; its anti-camp
//    is the L4 pod-rupture vent hazard (Phase 5) sweeping the deck footprint.
//    Until Phase 5 lands the deck is a temporary free camp - known + accepted.
//  * The floor-touching stair treads are named acc_clip_* so the central sweep
//    (_acc_map_randomizer.gsc::cut_navmesh_under_prop_clips, PREFIX match on
//    "acc_clip_") DisconnectPaths()es them automatically - zombies route around
//    the stair base instead of grinding on it. No GSC change needed.
//  * The lightmapper ignoring brushmodels ALSO means the deck gets no lightmap -
//    it is lit by the baked light GRID, so the 2 lights below matter. If the deck
//    reads pitch black in the Phase-0 render test, bump INTENSITY to ~0.25 and
//    re-bake (R4 in the locked plan) before resorting to an emissive material.
//
// GEOMETRY (locked spec, docs/30):
//  * Deck: x[140,780] y[2013,2173] top z=-848 (floor+112), 16 thick. 96u clear
//    under-deck = a walk-under gallery; 112u headroom above (L3 slab bot -736).
//  * Deck x starts at 140 = 8u east of the D4 stairwell's EAST rail (x[112,132],
//    rail top -832): the rail stands 16u proud of the deck so you cannot walk
//    off the deck into the D4 well opening (a deliberate hop over it just drops
//    you onto the D4 stairs - a normal descent route, not an exploit).
//  * Rails: 40 tall / 12 thick ON the deck. South rail leaves the stair mouth
//    (x[140,228]) open; west + east ends closed; north side is the room wall.
//  * Stair: 7 treads, 16 rise / 16 run (the abyss descent-well pitch - proven
//    player-walkable), x[140,220], climbing NORTH from y=1901 to the deck edge
//    at y=2013. Solid columns from the floor (z=-960) like the descent stairs.
//  * Material: t7_metal_diamond_plate_worn_wet (stock, ships free, NO .zone
//    line) - the map's canonical "industrial metal" door-slab skin.
//  * 2 light entities over the deck (radius 200, intensity 0.15,
//    lightingstate1=0 = dark until power, matching the map convention). Lights
//    ARE baked (light grid) -> any edit here needs a FULL LED bake, never -GscOnly.
//
// Idempotent: strips its own -ACB5- marked entities + "// ACC MEZZ" tag comments
// before re-emitting (marker verified collision-free vs the live .map 2026-07-12;
// the earlier -ACB4- candidate collides with an innocent stock guid at line 4882).
// Entities are APPENDED at end-of-file (the entity list) - never touches
// worldspawn, so it cannot clobber other sessions' worldspawn appends; still
// grep your markers before every geometry build (memory concurrent-sessions-
// clobber-map-appends).
//
// Usage: node tools/oneshots/gen_abyss_mezzanine.js            apply (writes the real .map)
//        node tools/oneshots/gen_abyss_mezzanine.js --revert   UNDO: strip all -ACB5- pieces
//        node tools/oneshots/gen_abyss_mezzanine.js --out <f>  write elsewhere (dry run)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;
const REVERT = process.argv.includes('--revert');

const MAT = 't7_metal_diamond_plate_worn_wet';   // canonical industrial-metal skin (stock, free)

// ---- L4 Gantry constants (locked spec; see header) ----
const L4_FLOOR = -960;                    // L4 walkable floor top
const DECK_TOP = L4_FLOOR + 112;          // -848
// SEALED TO THE FLOOR (user 2026-07-12 "obstacles you can just crawl under and zombies
// can't get you"): the original 16-thick deck left a 96u under-gallery - zombies are
// taller than the gap so it was a physics-proof hide spot. The deck is now a SOLID block
// floor->top (same walkable top, no underside). Same fix on the L5 Overlook below.
const DECK_BOT = L4_FLOOR;                // solid: no crawl space
const RAIL_TOP = DECK_TOP + 40;           // -808
const DECK_X1 = 140, DECK_X2 = 780;       // 8u east of the D4 well east rail (x132)
const DECK_Y1 = 2013, DECK_Y2 = 2173;     // 160 deep, flush to the north wall plane
const STAIR_X1 = 140, STAIR_X2 = 220;     // 80-wide treads
const STAIR_Y0 = 1901;                    // first tread's south edge (7 x 16 = 112 run -> y2013)
const N_TREADS = 7, RISE = 16, RUN = 16;  // 16/16 = the proven abyss descent-well pitch
const MOUTH_X2 = 228;                     // south rail starts here -> stair mouth x[140,228] open

// ---- bake-safe box() (verbatim filler-winding from gen_abyss_layer.js; DO NOT alter) ----
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAB03-ACB5-4E0C-8A3F-${c}}`;   // -ACB5- marker => strippable on re-run
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

// A VISIBLE solid script_brushmodel entity (the acc_ec_right_wall / add_prop_clips
// brushmodelEntity shape, but with a render material instead of 'clip'). Solid at
// load, LED-exempt, navmesh-swept via the acc_clip_ prefix.
function brushmodelEntity(label, x1, x2, y1, y2, z1, z2) {
  return ['{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "acc_clip_${label}"`,
    box(x1, x2, y1, y2, z1, z2, MAT), '}'].join('\n');
}

// ---- bake-safe light (verbatim kelson8 PRIMARY_OMNI from gen_abyss_layer.js) ----
let lc = 0;
function lguid() { lc++; const c = lc.toString(16).toUpperCase().padStart(12, '0'); return `{7A2BAB04-ACB5-4E14-8A3F-${c}}`; }
function lightEntity(tag, x, y, z, radius, intensity) {
  return ['{', `guid "${lguid()}"`,
    '"classname" "light"', `"targetname" "${tag}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    '"_color" "1 1 1"', `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    // DARK until power (map convention): lightingstate1=0 => off pre-power, on post-power.
    '"lightingstate1" "0"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

// ---- generation (WORLDSPAWN geometry, user 2026-07-13) ----------------------
// BUG-3 FIX: the L4 Gantry is now REAL worldspawn geometry, not a script_brushmodel.
// cod2map's navmesh generator IGNORES brushmodels (radiant\configs\navmesh.json), so
// the old brushmodel deck was player-only high ground zombies could never reach = a
// guaranteed safe camp even though the balcony hands out a gift. Emitting the deck +
// stairs INSIDE the worldspawn entity makes cod2map (a) generate navmesh over the
// 16/16 stairs + deck (the SAME proven pitch as the abyss descent wells zombies path
// down) and (b) cut navmesh around the rails - so zombies climb up and threaten campers.
// TRADE-OFF (user accepted, was flagged "be cautious"): deep worldspawn geometry is the
// brush.cpp:1860 LED-bake-crash risk the brushmodel form dodged. Mitigations: the deck
// is a SOLID staircase+platform (no enclosed void / dead-end pocket), it reuses the
// verbatim gen_abyss_layer filler-winding box() that provably bakes, and the FULL LED
// bake is the hard gate. If the bake CRASHES, revert (`--revert`) and fall back to a
// camp health-drain (the _acc_bus_trench::bridge_drain_watcher pattern).
const wsBrushes = [];
const addWs = (label, x1, x2, y1, y2, z1, z2) => {
  wsBrushes.push(`// ACC MEZZ ${label}`);
  wsBrushes.push(box(x1, x2, y1, y2, z1, z2, MAT));   // box() stamps a -ACB5- guid => strippable
};

// Deck + rails (rails sit ON the deck; south rail leaves the stair mouth open). Rails are
// worldspawn too so cod2map cuts navmesh around them (zombies stay on the deck, don't grind).
addWs('L4 gantry deck', DECK_X1, DECK_X2, DECK_Y1, DECK_Y2, DECK_BOT, DECK_TOP);
addWs('L4 gantry rail SOUTH (east of the stair mouth)', MOUTH_X2, DECK_X2, DECK_Y1, DECK_Y1 + 12, DECK_TOP, RAIL_TOP);
addWs('L4 gantry rail WEST end', DECK_X1, DECK_X1 + 12, DECK_Y1 + 12, DECK_Y2, DECK_TOP, RAIL_TOP);
addWs('L4 gantry rail EAST end', DECK_X2 - 12, DECK_X2, DECK_Y1, DECK_Y2, DECK_TOP, RAIL_TOP);

// Stair: 7 solid treads climbing NORTH from the open floor to the deck's south edge.
for (let s = 1; s <= N_TREADS; s++) {
  const yA = STAIR_Y0 + RUN * (s - 1), yB = STAIR_Y0 + RUN * s;
  const top = L4_FLOOR + RISE * s;                       // -944 .. -848 (= deck top)
  addWs(`L4 gantry stair ${s} (top z=${top})`, STAIR_X1, STAIR_X2, yA, yB, L4_FLOOR, top);
}

// NO deck lights (user 2026-07-12 "you added lights which I didn't even want" - the abyss
// stays pitch black; the 10 added lights were also the post-spawn CTD culprit). lightEntity()
// is kept above for reference but must NOT be called without an explicit user ask.

// ---- L5 "OVERLOOK" REMOVED (user 2026-07-13) --------------------------------
// The west-wall double-jump perch near the L5 ammo crate was a zombie-proof safe camp
// with NO reward on it (its intended corrosive-tide anti-camp had a safe-lane hole at
// its south end). User verdict: delete it outright rather than rebuild. The old deck/
// rail/step constants + emit calls are gone; --revert / re-run no longer re-adds them.

// ---- strip prior run: any {...} block whose OWN guid line contains -ACB5-, at ANY
// nesting depth (old TOP-LEVEL brushmodel entities from the pre-2026-07-13 form AND
// worldspawn-nested brushes from a prior worldspawn run). Standalone-brace delimited;
// guid braces sit inside quotes on their own line so they never equal a bare { or }. ----
function strip(lines) {
  const kept = [];
  let i = 0;
  while (i < lines.length) {
    const t = lines[i].trim();
    if (t.startsWith('// ACC MEZZ')) { i++; continue; }   // drop marker comments
    if (t === '{' && i + 1 < lines.length && lines[i + 1].includes('-ACB5-')) {
      // this block is ours - skip it whole (find its matching close by brace depth)
      let d = 0, j = i;
      for (; j < lines.length; j++) {
        const tj = lines[j].trim();
        if (tj === '{') d++;
        else if (tj === '}') { d--; if (d === 0) { j++; break; } }
      }
      i = j; continue;
    }
    kept.push(lines[i]); i++;   // keep everything else (incl. the worldspawn open/close + its other brushes)
  }
  return kept;
}

const rawLines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let lines = strip(rawLines);

if (REVERT) {
  while (lines.length && lines[lines.length - 1] === '') lines.pop();
  lines.push('');
  fs.writeFileSync(OUT, lines.join('\n'));
  console.log(`[mezz] REVERTED: stripped all -ACB5- mezzanine geometry. wrote ${OUT} (${rawLines.length} -> ${lines.length} lines)`);
  process.exit(0);
}

// Inject the Gantry worldspawn brushes BEFORE the worldspawn (entity 0) close brace.
// wsClose = the first line where standalone-brace depth returns to 0 = worldspawn's '}'.
let depth = 0, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') depth++;
  else if (t === '}') { depth--; if (depth === 0 && wsClose === -1) { wsClose = i; break; } }
}
if (wsClose < 0) { console.error('[mezz] ERROR: worldspawn close brace not found'); process.exit(2); }

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) {
    out.push('// ACC MEZZ (gen_abyss_mezzanine.js) ===== BEGIN L4 gantry (WORLDSPAWN) =====');
    out.push(...wsBrushes);
    out.push('// ACC MEZZ ===== END =====');
  }
  out.push(lines[i]);
}
fs.writeFileSync(OUT, out.join('\n'));
console.log(`[mezz] L4 Gantry (WORLDSPAWN): deck x[${DECK_X1},${DECK_X2}] y[${DECK_Y1},${DECK_Y2}] top z=${DECK_TOP}; ${N_TREADS} treads from y=${STAIR_Y0}; 3 rails; injected before worldspawn close (line ${wsClose + 1}). L5 Overlook removed.`);
console.log(`[mezz] wrote ${OUT} (${rawLines.length} -> ${out.length} lines). Revert: node tools/oneshots/gen_abyss_mezzanine.js --revert`);
