#!/usr/bin/env node
// =============================================================================
// gen_trench_walls.js - BOSS-ARENA walls for the Bus Station trench (user 2026-06-18).
//
// A reward-boss is going in the pit; players must NOT be able to snipe him from
// the room floor or the stairs - to fight him you commit and go ALL the way down
// (the stairs), OR take the Rocket-Shield-only slab/bridge above the trench and
// drop in. So we wall the rim.
//
// Emits PARAPET wall brushes along both long rims (south y=TRENCH_Y1, north
// y=TRENCH_Y2), rising z[0,PARAPET_TOP], so a room-floor player can't see/shoot
// down into the deep pit. GAPS are left at:
//   - the two stair mouths (so you can still step onto the stairs to descend), and
//   - the slab/bridge column x[BRIDGE_X1,BRIDGE_X2] (the shield-only entry) - but
//     that column gets an UNDER-SLAB FILL z[0,BRIDGE_BOT] so a ground player can't
//     shoot UNDER the floating slab into the pit; only a jump to the slab (z BRIDGE_BOT+)
//     reaches over it.
//
// One-shot scaffolding like gen_corp_trench.js: prints brushes + splices them into
// the worldspawn entity of map_source/zm/zm_abandoned_cyber_city.map (pass the .map
// path as argv[2] to splice; no arg = print to stdout). Re-run safe via the marker.
//
// Geometry SoT: source_data/rooms.json trenches.corp + the baked bridge brush
// (guid ...901, x[-109,147] z[42,58]). Keep BRIDGE_* in sync with that brush.
// =============================================================================

'use strict';
const fs = require('fs');

// --- trench footprint (SoT rooms.json trenches.corp + gen_corp_trench) -------
const X1 = -781, X2 = 819;          // corp room E-W extent
const WALL_TH = 20;
const TRENCH_Y1 = 1723, TRENCH_Y2 = 2173;
const PARAPET_TOP = 128;            // parapet height above the room floor (z0). Tune for sightline.
const PAR_TH = 20;                  // parapet thickness (room-floor side of the rim)

// stair mouths to leave OPEN (gen_corp_trench STAIR_CHANNELS): west stair (south
// lip) x[-761,-665]; east stair (north lip) x[703,799].
const WEST_STAIR = [ -761, -665 ];
const EAST_STAIR = [ 703, 799 ];

// the Rocket-Shield slab/bridge column (baked bridge brush guid ...901)
const BRIDGE_X1 = -109, BRIDGE_X2 = 147;
const BRIDGE_BOT = 42;              // slab bottom z (fill the rim under it to here)

// stair pit-side walls (user 2026-06-18: "walls on the stairs so you cant shoot him from the stairs")
const TRENCH_FLOOR = -240;          // keep in sync with gen_corp_trench TRENCH_FLOOR
const N_STEPS = 14, STEP = 16;      // keep in sync with gen_corp_trench
const STAIR_WALL_TOP = 128;         // wall height above the room floor (clears standing eye on every step)
const SW_TH = 16;                   // wall thickness (sits in the pit, just off the stair's pit edge)

const END = X1 + WALL_TH;           // -761 : inside the west end wall
const ENDE = X2 - WALL_TH;          // 799  : inside the east end wall

// CROUCH DROP-IN openings (user 2026-06-28): a crouch-height WINDOW in the rim parapet right BESIDE each stair
// (the "wall with the bridge" = this rim parapet, which the bridge column plugs into), so a player can crouch
// through it and DROP into the trench (~240u fall = PhD-Flopper play) instead of taking the stairs. The window is
// open z[0,OPEN_TOP]; a header z[OPEN_TOP,PARAPET_TOP] above it keeps the parapet reading as a wall. OPEN_TOP 64
// < the ~72u standing hull -> must crouch (the earlier 48u in the stair wall was too short to pass - user); 56u
// wide so the ~30u hull clears it.
const OPEN_TOP = 64;
const OPEN_W = 56;
const S_CROUCH = [ WEST_STAIR[1], WEST_STAIR[1] + OPEN_W ];   // [-665,-609] in the SOUTH rim, beside the WEST stair
const N_CROUCH = [ EAST_STAIR[0] - OPEN_W, EAST_STAIR[0] ];   // [647,703]  in the NORTH rim, beside the EAST stair

let guidCounter = 0xA00;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAA00-ACCA-4E0D-8A3F-${c}}`;
}

// Six-plane axis-aligned box - identical template to tools/gen_corp_trench.js box()
// (proven parse-clean; only x1/x2/y1/y2/z1/z2 matter).
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

const out = [];
const manifest = [];
function emit(label, text) { manifest.push(label); out.push(`// ${label}`); out.push(text); }

// Split [a,b] into the sub-spans NOT covered by any [gap] in gaps[].
function spans(a, b, gaps) {
  let segs = [[a, b]];
  for (const g of gaps) {
    const next = [];
    for (const [s, e] of segs) {
      if (g[1] <= s || g[0] >= e) { next.push([s, e]); continue; }      // no overlap
      if (g[0] > s) next.push([s, g[0]]);                                 // left remainder
      if (g[1] < e) next.push([g[1], e]);                                 // right remainder
    }
    segs = next;
  }
  return segs.filter(([s, e]) => e - s > 1);
}

// South rim parapet (room-floor side y[Y1-PAR_TH, Y1]); gaps at west stair + slab column + the crouch drop-in.
for (const [s, e] of spans(END, ENDE, [WEST_STAIR, [BRIDGE_X1, BRIDGE_X2], S_CROUCH])) {
  emit(`trench S rim parapet x[${s},${e}]`, box(s, e, TRENCH_Y1 - PAR_TH, TRENCH_Y1, 0, PARAPET_TOP, 'script_wall'));
}
emit(`trench S rim crouch drop-in header x[${S_CROUCH[0]},${S_CROUCH[1]}] (open z[0,${OPEN_TOP}], beside the W stair)`,
  box(S_CROUCH[0], S_CROUCH[1], TRENCH_Y1 - PAR_TH, TRENCH_Y1, OPEN_TOP, PARAPET_TOP, 'script_wall'));
// North rim parapet (room-floor side y[Y2, Y2+PAR_TH]); gaps at east stair + slab column + the crouch drop-in.
for (const [s, e] of spans(END, ENDE, [EAST_STAIR, [BRIDGE_X1, BRIDGE_X2], N_CROUCH])) {
  emit(`trench N rim parapet x[${s},${e}]`, box(s, e, TRENCH_Y2, TRENCH_Y2 + PAR_TH, 0, PARAPET_TOP, 'script_wall'));
}
emit(`trench N rim crouch drop-in header x[${N_CROUCH[0]},${N_CROUCH[1]}] (open z[0,${OPEN_TOP}], beside the E stair)`,
  box(N_CROUCH[0], N_CROUCH[1], TRENCH_Y2, TRENCH_Y2 + PAR_TH, OPEN_TOP, PARAPET_TOP, 'script_wall'));
// Under-slab fill at the slab column (both rims) z[0,BRIDGE_BOT] - blocks shooting UNDER the floating slab.
emit('trench S rim under-slab fill', box(BRIDGE_X1, BRIDGE_X2, TRENCH_Y1 - PAR_TH, TRENCH_Y1, 0, BRIDGE_BOT, 'script_wall'));
emit('trench N rim under-slab fill', box(BRIDGE_X1, BRIDGE_X2, TRENCH_Y2, TRENCH_Y2 + PAR_TH, 0, BRIDGE_BOT, 'script_wall'));

// Stair pit-side walls - block shooting the pit WHILE DESCENDING. Each stair hugs an end wall;
// its OTHER long edge faces the open pit, so we wall that edge from the pit floor up past
// standing eye for the stair's full run. You only get a clean line on the boss at the very
// bottom (where the stair opens onto the floor) = you've committed and gone all the way down.
const WSTAIR_RUN = TRENCH_Y1 + N_STEPS * STEP;   // west stair (south lip): runs y[Y1, Y1+run], pit edge = its EAST edge
emit('trench W stair pit-side wall',
  box(WEST_STAIR[1], WEST_STAIR[1] + SW_TH, TRENCH_Y1, WSTAIR_RUN, TRENCH_FLOOR, STAIR_WALL_TOP, 'script_wall'));
const ESTAIR_RUN = TRENCH_Y2 - N_STEPS * STEP;   // east stair (north lip): runs y[Y2-run, Y2], pit edge = its WEST edge
emit('trench E stair pit-side wall',
  box(EAST_STAIR[0] - SW_TH, EAST_STAIR[0], ESTAIR_RUN, TRENCH_Y2, TRENCH_FLOOR, STAIR_WALL_TOP, 'script_wall'));

const blockHdr = '// ===== ACC trench boss-arena walls (gen_trench_walls.js) =====';
const blockEnd = '// ===== end trench walls =====';
const block = [blockHdr, ...out, blockEnd].join('\n');

const mapPath = process.argv[2];
if (!mapPath) {
  console.log(block);
  console.log('\n===== MANIFEST (' + manifest.length + ' brushes) =====');
  console.log(manifest.map((m, i) => `  ${i + 1}. ${m}`).join('\n'));
  process.exit(0);
}

// Splice into worldspawn: insert right AFTER the baked bridge brush (guid ...901's
// closing brace) and BEFORE the worldspawn entity close. Idempotent via the marker.
let txt = fs.readFileSync(mapPath, 'utf8');
if (txt.indexOf(blockHdr) !== -1) {
  // replace the existing block (re-run / retune)
  const re = new RegExp(blockHdr.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '[\\s\\S]*?' + blockEnd.replace(/[.*+?^${}()|[\]\\]/g, '\\$&'));
  txt = txt.replace(re, block);
  fs.writeFileSync(mapPath, txt);
  console.log('OK replaced existing trench-walls block (' + manifest.length + ' brushes)');
  process.exit(0);
}
const lines = txt.split('\n');
// find the bridge brush close: the last line of guid ...901's brush is the -109 plane, then '}'.
let bridgePlane = -1;
for (let i = 0; i < lines.length; i++) {
  if (lines[i].indexOf('( -109 459.5 88 ) ( -109 419.5 88 ) ( -109 419.5 0 ) script_floor_ceiling') !== -1) { bridgePlane = i; break; }
}
if (bridgePlane === -1) { console.error('FAIL: bridge brush plane not found'); process.exit(1); }
// the next line after the plane is the brush-closing '}'
let insertAt = bridgePlane + 1;
while (insertAt < lines.length && lines[insertAt].trim() !== '}') insertAt++;
insertAt++; // after the brush close
lines.splice(insertAt, 0, block);
fs.writeFileSync(mapPath, lines.join('\n'));
console.log('OK spliced ' + manifest.length + ' trench-wall brushes after the bridge brush (line ' + insertAt + ')');
