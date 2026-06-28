#!/usr/bin/env node
// =============================================================================
// gen_plaza_shrink.js - TRUE shrink of the SPAWN PLAZA (start_zone) ~75% + an
// IMPLANT LAB side-room (gated, buyable door) + (later) creative obstacles.
// (user 2026-06-26: "make plaza ~70-75% smaller + more chaotic"; then "carve the
//  blocked-off south into a room w/ a buyable tight-entrance door for the implant
//  benches".)
//
// APPROACH (not value-remapping the perimeter - that crashes the LED bake on this
// irregular STOCK TEMPLATE arena): ADD a tighter inner wall ring + a room inside the
// old footprint, sealing the outer dead space. The big template floor is untouched.
//
// PLAZA interior (was ~x[-1036,1074.5] y[-540,720] ~2.66M):
//   new x[-470, 213] y[-240, 720]  (683 x 960 = ~655k = ~75% smaller).
//   West/South/North walls held (spawns + window-barricade entry + corridor mouths fix
//   them); the shrink is taken from the EAST (wall pulled 580 -> 213). Both corner exits
//   (NW Market / NE Alley) stay connected via connector corridors to the OLD wall mouths
//   at y[400,656]; the buyable doors live further out and are untouched.
//
// IMPLANT LAB room: the sealed strip SOUTH of the plaza south wall (y[-540,-240]),
//   interior x[-400,-40] y[-540,-240] (360x300). Holds the two boss-item Implant Bench
//   pads (spawned by _acc_boss_items at y~-480 - they were getting SEALED behind the new
//   plaza south wall; now they live in this room). Entered from the plaza by a TIGHT 80u
//   doorway (x[-260,-180]) in the plaza south wall, gated by a buyable slide-up door
//   (enter_implant, 1500 - wired in zm_abandoned_cyber_city.gsc zone_door_trigger_origin
//   + zone_door_thin_offset). Room/plaza are one zone (inside start_zone's volume), so no
//   separate zone setup - the door just opens the slab + navmesh.
//
// LED-safe: world brushes w/ the PROVEN gen_room_cover "filler-plane" winding + hex GUID
// (the door SLAB is a script_brushmodel = LED-exempt). BAKE-GATE EVERY RUN (_bake_test.ps1).
//
// RE-RUNNABLE: strips its own tagged blocks (worldspawn brushes + the door entities) then
// re-emits; riser relocations are idempotent (origin set by GUID). Edit tables + re-run.
//
// Usage: node tools/gen_plaza_shrink.js [--out <file>]   (default: writes the real .map)
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;

const TAG = '// ACC plaza shrink (tools/gen_plaza_shrink.js)';

// --- WORLDSPACE WALLS: [x1, x2, y1, y2, z1, z2] (script_wall) ------------------
// new W wall outer x-490 (inner -470), new E wall outer x233 (inner 213), S wall y[-260,-240].
// The S wall is SPLIT around an 80u doorway x[-260,-180] (the Implant Lab entrance) with a
// lintel above it. North reuses the existing plaza north wall (brush 22, y720..740).
const WALLS = [
  // --- plaza south wall, split around the Implant Lab doorway x[-260,-180] ---
  [-740, -260, -260, -240, 0, 256],   // S wall WEST of doorway (extended west -490 -> -740 to seal the ENLARGED lab's north, 2026-06-27)
  [-180, 233, -260, -240, 0, 256],    // S wall EAST of doorway
  [-260, -180, -260, -240, 128, 256], // doorway LINTEL (above the z0-128 slide-up door)
  // --- plaza west wall (held; split by the y[400,656] Market mouth) ---
  [-490, -470, -260, 400, 0, 256],
  [-490, -470, 656, 740, 0, 256],
  // --- plaza east wall (pulled IN to x213; split by the y[400,656] Alley mouth) ---
  [213, 233, -260, 400, 0, 256],
  [213, 233, 656, 740, 0, 256],
  // --- west connector corridor sides (new W wall -490 -> old W wall -1036) ---
  [-1036, -490, 380, 400, 0, 256],
  [-1036, -490, 656, 676, 0, 256],
  // --- east connector corridor sides (new E wall 233 -> old E wall 1074.5) ---
  [233, 1074.5, 380, 400, 0, 256],
  [233, 1074.5, 656, 676, 0, 256],
  // --- IMPLANT LAB room E/W walls (N = plaza S wall above; S = stock south wall y-540) ---
  // ENLARGED 2026-06-27: lab widened WEST from x[-400,-40] to x[-720,-40] (more room + a sensible
  // stairwell). West wall moved -400 -> -720; The Exchange staircase room sits in the new SW corner.
  [-740, -720, -540, -240, 0, 256],   // room WEST wall (enlarged: -420/-400 -> -740/-720)
  [-40, -20, -540, -240, 0, 256],     // room EAST wall
  // MAZE REMOVED (user 2026-06-26: "remove the whole maze"). The plaza is open-but-shrunk now;
  // difficulty comes from the ~75% shrink + scattered crate cover (CLIPS below), not interior walls.
];

// --- COVER / OBSTACLES inside the plaza : [x1,x2,y1,y2,z1,z2] ------------------
// CLEARED - plain script_wall blocks replaced by creative themed PROPS (crates + kiosk
// booths). The VISUAL prop models are spawned in GSC (zm_abandoned_cyber_city.gsc
// acc_spawn_plaza_props - confirmed-packing p7_cai models); COLLISION is the CLIPS below.
const COVER = [];

// --- OBSTACLE CLIPS: invisible collision boxes under the GSC-spawned crate props ----
// [x1,x2,y1,y2,z1,z2], material 'clip'. KEEP COORDS IN SYNC with acc_spawn_plaza_props
// in zm_abandoned_cyber_city.gsc (the prop-clip drift footgun - memory prop-clips-drift).
// CRATES ONLY (user 2026-06-26: "only the little bunker things, no kiosk"). MUST stay in the
// OPEN bands (spawn y<60 / exit y>360), NEVER in a maze leg (y[60,360]) - a crate in the ~120u
// leg leaves only ~20u top/bottom = an IMPASSABLE block (the "stuck on one side" bug). All ≥25u
// off every wall (the old (160,280) crate clipped the east wall = "prop inside the box").
// SPREAD across the now-open plaza (user 2026-06-26: "spread them out, they are on top of each
// other"). SNUG to the crate model: 56x56 footprint (hx=hy=28 - the value tuned for this exact
// p7_cai_stacking_cargo_crate in add_prop_clips.js) + z0-48. Crates spawn at ANGLE 0 (axis-aligned)
// so this box matches the model silhouette. Clear of spawns/box/window/exits/risers. centers:
const CLIPS = [
  [-348, -292, 2, 58, 0, 48],      // crate @ (-320,30)  - SW
  [52, 108, 202, 258, 0, 48],      // crate @ (80,230)   - center-E
  [-108, -52, 532, 588, 0, 48],    // crate @ (-80,560)  - N center-W
];

// --- IMPLANT LAB buyable door (top-level entities) ----------------------------
// Trigger (zombie_door) + slide-up slab, in the doorway x[-260,-180] of the plaza south
// wall (thin in Y). enter_implant is wired in zm_abandoned_cyber_city.gsc.
const DOOR = {
  flag: 'enter_implant',
  slab: 'acc_door_implant',
  cost: 1500,
  triggerBox: [-260, -180, -250, -230, 0, 128], // material 'trigger'
  slabBox:    [-258, -182, -248, -232, 0, 128],  // material 'script_wall' (slides up via script_vector)
  slideVec:   '0 0 130',
};

// --- RISER RELOCATIONS: guid -> [newX, newY] (z + all else preserved) ----------
// Risers placed ON THE MAZE LEGS so zombies rise in the tight lanes with the player (user
// 2026-06-26). Leg1 = y[80,200], Leg2 = y[220,340], exit band = y[360,720]. The unmoved
// risers (dog @-227,118 ; 302 @0,243 ; 303 @-250,243 ; 306 @100,492 ; e4 @-227,492 window)
// already sit in valid legs. The generator self-check fails if any lands inside a wall/clip.
const RISER_MOVES = {
  // legs of the denser maze (M1 y60 / M2 y145 / M3 y230 / M4 y315): 2 risers per leg, clear of teeth (x10-30).
  '81023168-4386-4D63-A2D3-745C88A3E3F0': [-350, 110],  // e3   - leg1 west
  'B43026FE-2259-4E8D-9065-BD9E52403291': [150, 110],   // e1   - leg1 east
  'ACC5A000-0000-4000-8000-000000000302': [-250, 185],  // 302  - leg2 west (was in M3 band)
  'ACC5A000-0000-4000-8000-000000000303': [150, 185],   // 303  - leg2 east (was in M3 band)
  'ACC5A000-0000-4000-8000-000000000304': [-250, 295],  // 304  - leg3 west
  'ACC5A000-0000-4000-8000-000000000305': [150, 295],   // 305  - leg3 east
  'ACC5A000-0000-4000-8000-000000000308': [40, 440],    // 308  - exit band (clear of the crates)
  'ACC5A000-0000-4000-8000-000000000309': [-150, 420],  // exit band
  'ACC5A000-0000-4000-8000-000000000307': [-400, 420],  // exit band west (near Market mouth)
  'ACC5A000-0000-4000-8000-000000000301': [130, 420],   // exit band east (near Alley mouth)
  // PLAZA MYSTERY BOX (acc_box_plaza) + its zbarrier - was at (0,350), which the M3 maze wall
  // (x[-470,60] y[340,360]) ran THROUGH ("wall inside the box"). Moved to the open SE spawn band.
  '7A2B9E00-ACC2-4E0B-8A3F-0000000002A0': [100, -150],  // acc_box_plaza_zbarrier (model/collision)
  '7A2B9E00-ACC2-4E0B-8A3F-0000000002A1': [100, -150],  // acc_box_plaza struct (chest use)
  // PLAYER SPAWNS (user 2026-06-26: "everyone spawns in the back area with the box, none in a wall").
  // The 8 initial_spawn_points + info_player_start clustered into the open SE back band beside the box
  // (collision x72..128). 4x2 grid x{-200,-120,-40,40} y{-90,-130}; z preserved. The self-check confirms
  // none land in a wall/clip. (player_respawn_point is NOT moved - the Implant Bench is anchored to it.)
  '09566C95-1DB4-41D5-A33B-F30C53F9858B': [-200, -90],  // initial_spawn (int2)
  'DF2CCC54-B1CF-4B59-A45F-0E01DCA8E9EF': [-120, -90],
  '849F90F0-3A19-4074-B7A0-80CAB88DFC83': [-40, -90],
  'EFF876B5-75DF-4EE6-B13B-CFEF7DDD55C7': [40, -90],
  'D648A348-5F37-499F-9C3D-99819DE2A74E': [-200, -130], // initial_spawn (int1)
  '1F3CBEB9-1C12-4E00-B939-6D725AC8607F': [-120, -130],
  '2A47AF4D-1BCA-4F2C-B5C1-B4E15A6B4365': [-40, -130],
  '26CF8A92-3069-4735-90F2-0C9615793968': [40, -130],
  '1FD69AA1-137D-45D8-B426-838B706C3B3D': [-120, -110], // info_player_start (initial)
};

// New interior bounds (for the clearance self-check).
const PLAZA = { x1: -470, x2: 213, y1: -240, y2: 720 };
const ROOM  = { x1: -720, x2: -40, y1: -540, y2: -240 };   // enlarged WEST 2026-06-27 (-400 -> -720)

// Deterministic HEX GUID (counter-based) - matches add_perk_alcoves / gen_room_cover.
let gc = 0;
function guid() {
  gc++;
  const h = ('plaza' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACC6-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush - VERBATIM proven winding from gen_room_cover.js / add_perk_alcoves.box
// ("filler-plane" winding that BAKES). Only the defining axis varies; rest are fixed filler.
function boxBrush(x1, x2, y1, y2, z1, z2, mat) {
  const m = mat || 'script_wall';
  const t = `${m} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}'].join('\n');
}

function doorEntities() {
  const [tx1, tx2, ty1, ty2, tz1, tz2] = DOOR.triggerBox;
  const [sx1, sx2, sy1, sy2, sz1, sz2] = DOOR.slabBox;
  const trig = [
    `${TAG} implant-door trigger (${DOOR.flag}, ${DOOR.cost})`,
    '{', ` guid "${guid()}"`,
    ' "classname" "trigger_use"',
    ' "targetname" "zombie_door"',
    ` "target" "${DOOR.slab}"`,
    ` "zombie_cost" "${DOOR.cost}"`,
    ` "script_flag" "${DOOR.flag}"`,
    boxBrush(tx1, tx2, ty1, ty2, tz1, tz2, 'trigger'),
    '}',
  ].join('\n');
  const slab = [
    `${TAG} implant-door slab (${DOOR.slab})`,
    '{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "${DOOR.slab}"`,
    ` "script_vector" "${DOOR.slideVec}"`,
    ' "script_transition_time" "1.5"',
    boxBrush(sx1, sx2, sy1, sy2, sz1, sz2, 'script_wall'),
    '}',
  ].join('\n');
  return [trig, slab];
}

function stripTagged(lines) {
  const out = [];
  for (let k = 0; k < lines.length; k++) {
    if (lines[k].includes(TAG)) {
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

function moveRisers(lines) {
  let moved = 0;
  for (const [g, [nx, ny]] of Object.entries(RISER_MOVES)) {
    const gi = lines.findIndex(l => l.includes('"{' + g + '}"') || l.includes('{' + g + '}'));
    if (gi < 0) { console.error(`WARN: riser guid ${g} not found`); continue; }
    for (let k = gi + 1; k < lines.length; k++) {
      if (lines[k].trim() === '}') break;
      const m = lines[k].match(/^(\s*)"origin" "(-?[\d.]+) (-?[\d.]+) (-?[\d.]+)"\s*$/);
      if (m) { lines[k] = `${m[1]}"origin" "${nx} ${ny} ${m[4]}"`; moved++; break; }
    }
  }
  return moved;
}

// Worldspawn close finder (a banner comment now sits between it and "// entity 1").
function findWorldspawnClose(lines) {
  const wsKv = lines.findIndex(l => l.includes('"classname" "worldspawn"'));
  if (wsKv < 0) return -1;
  let open = -1;
  for (let i = wsKv; i >= 0; i--) { if (lines[i].trim() === '{') { open = i; break; } }
  if (open < 0) return -1;
  let depth = 0;
  for (let i = open; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') depth++;
    else if (t === '}') { depth--; if (depth === 0) return i; }
  }
  return -1;
}

// ---- clearance self-check: warn if a spawn/riser origin is buried in a wall/cover box,
//      or outside the new playable footprint. Reads the FINAL lines (post-move). --------
function selfCheck(lines) {
  const boxes = WALLS.concat(COVER).concat(CLIPS); // [x1,x2,y1,y2,z1,z2]
  const inBox = (x, y, b) => x > b[0] && x < b[1] && y > b[2] && y < b[3];
  const inFoot = (x, y) => (x > PLAZA.x1 && x < PLAZA.x2 && y > PLAZA.y1 && y < PLAZA.y2) ||
                           (x > ROOM.x1 && x < ROOM.x2 && y > ROOM.y1 && y < ROOM.y2);
  // parse top-level entities
  let depth = 0, cur = null, warns = 0;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { depth++; if (depth === 1) cur = { kv: {}, g: '' }; continue; }
    if (t === '}') {
      if (depth === 1 && cur) {
        const tn = cur.kv.targetname || '', cls = cur.kv.classname || '', nw = cur.kv.script_noteworthy || '';
        const isSpawnish = ['start_zone_spawners', 'initial_spawn_points', 'player_respawn_point', 'zombie_dog_spawner'].includes(tn) || cls === 'info_player_start' || nw.startsWith('acc_box_plaza');
        if (isSpawnish && cur.kv.origin) {
          const [x, y] = cur.kv.origin.split(/\s+/).map(Number);
          for (const b of boxes) if (inBox(x, y, b)) { console.error(`WARN buried: ${tn || cls} @ ${x},${y} inside box [${b}]`); warns++; }
          if (!inFoot(x, y)) { console.error(`WARN outside footprint: ${tn || cls} @ ${x},${y}`); warns++; }
        }
        cur = null;
      }
      depth--; continue;
    }
    if (depth === 1 && cur) { const m = t.match(/^"([^"]+)" "([^"]*)"$/); if (m) cur.kv[m[1]] = m[2]; }
  }
  // (Maze removed 2026-06-26, so the old clip-in-maze-band guard is gone - crates may sit anywhere
  //  open now. The buried-in-wall/clip + out-of-footprint checks above still guard placement.)
  console.log(warns ? `selfCheck: ${warns} WARNING(s)` : 'selfCheck: clean (no buried/out-of-footprint spawns or risers)');
}

let lines = stripTagged(fs.readFileSync(MAP, 'utf8').split(/\r?\n/));
const movedRisers = moveRisers(lines);

const wsClose = findWorldspawnClose(lines);
if (wsClose < 1) { console.error('FATAL: cannot find worldspawn close'); process.exit(1); }

// worldspawn brushes (walls + cover) inserted BEFORE the worldspawn close
const wsBlocks = [];
WALLS.forEach((b, i) => {
  wsBlocks.push(`${TAG} wall #${i} [${b.join(',')}]`);
  wsBlocks.push(boxBrush(b[0], b[1], b[2], b[3], b[4], b[5]));
});
COVER.forEach((b, i) => {
  wsBlocks.push(`${TAG} cover #${i} [${b.join(',')}]`);
  wsBlocks.push(boxBrush(b[0], b[1], b[2], b[3], b[4], b[5]));
});
CLIPS.forEach((b, i) => {
  wsBlocks.push(`${TAG} obstacle clip #${i} [${b.join(',')}]`);
  wsBlocks.push(boxBrush(b[0], b[1], b[2], b[3], b[4], b[5], 'clip'));
});

// door entities inserted AFTER the worldspawn close (top-level)
const entBlocks = doorEntities();

let out = lines.slice(0, wsClose).concat(wsBlocks, [lines[wsClose]], entBlocks, lines.slice(wsClose + 1));
fs.writeFileSync(OUT, out.join('\n'));
selfCheck(out);
console.log(`wrote ${WALLS.length} walls + ${COVER.length} cover + door (trigger+slab), moved ${movedRisers} risers -> ${OUT}`);
