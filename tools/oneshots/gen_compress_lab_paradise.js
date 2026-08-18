#!/usr/bin/env node
// =============================================================================
// gen_compress_lab_paradise.js - THE LAB + PARADISE COMPRESSION (user 2026-08-02:
// "the lab and paradise have too much open space for reasons that aren't part of
// the map anymore - make them smaller so players don't gravitate there for safety;
// lab gets more lab models to fit the area").
//
// WHAT IT DOES (one .map pass, marker ACCLPC01, refuses re-apply):
//
// PARADISE (was interior x[-1000,1000] y[-2200,-600] = 2000x1600):
//   -> NEW interior x[-700,700] y[-2000,-600] = 1400x1400 (~39% less area).
//   * The 8 gen_descent_hub.js plaza brushes (guids ...0016-...001C) are VALUE-
//     REMAPPED in place - per-face materials preserved (the floor's
//     mwiii_vertigo_retro_synth_cyan top face survives). The hallway, the
//     above-mouth brush (...001D), the hub door, all 6 plaza lights, the 2 hall
//     lights and acc_probe_hub are UNTOUCHED (all inside the new footprint -
//     zero relight churn, noir radii frozen).
//   * Every misc_model in the plaza (M6 palms/grass/ferns + the ACCINF02
//     infestation takeover) is re-homed by cluster rules:
//       |x|>=800 (wall/corner content)  -> x = sign*(|x|-300);
//           y<=-2000 (S corners) y+=200; y>=-800 (N corners) y unchanged;
//           -1300<=y<=-1000 (satellite band) y+=115; else y+=200 iff y<=-1500.
//       |x|<800: y+=200 iff y<=-1500 (heart cluster + S center);
//           the perk-gap eggs (+-450,-690) -> x=+-435 (new tighter perk row).
//   * The 10-perk row + kiosks/bench/box/PaP are handled OUTSIDE this script:
//     gen_paradise_props.js re-run (new x table) + _acc_glitch_altar.gsc edits.
//
// LAB (was interior x[-761,799] y[3068,4228] = 1560x1160):
//   -> NEW interior x[-761,799] y[3068,3868] = 1560x800 (~31% less area). The
//     dead band y[3868,4228] (the old 10-alcove perk row strip, gone since
//     2026-07-25) is SEALED plaza-shrink-style: a new inner N wall is ADDED at
//     y[3868,3888] (hexagon, doorway x[-123,-27] + header) - the original
//     envelope (outer N wall y[4228,4248], floor, ceiling, W/E walls) is
//     untouched, so rooms.json + the bake-safe outer shell stay valid.
//   * THE SCIENTIST'S OFFICE is TRANSLATED -360 in y (shell brushes, door slab +
//     trigger, 12 statics, 2 lights, probe, lab_zone volume brush 3) so its
//     doorway lands exactly in the new inner wall (interior now y[3888,4208],
//     entirely INSIDE the lab's original sealed envelope). The old doorway hole
//     in the outer N wall (x[-123,-27] z[0,128]) is PLUGGED.
//   * Everything in the sealed band moves into the compressed room: perk-row
//     staging prefabs/structs y4195->3800, LED strips y4227->3867, riser row
//     y3948->y3760..3808, roof-light row y4068->3800, neon_19 + flare pool
//     (0,4060)->(0,3830), APD turbine/canister flush to the new wall, and the
//     old E-wall industrial corner relayouts onto the new N wall / NE spur.
//   * DENSIFICATION: +17 misc_model statics (ALL already-zoned models - zero new
//     .zone lines): a W-center data island (blue generator / computer tower /
//     server comm / dragon terminal / holo), a 2nd specimen test chamber, two
//     standing console banks + server-wire sockets + a security monitor pair on
//     the new N wall, a center-south morgue/medical cluster, paper debris.
//     Clips ride tools/add_prop_clips.js (edited + re-run separately).
//
// Companion edits (SAME change, other files): add_prop_clips.js (moved + new
// clips), gen_paradise_props.js (perk row xs), _acc_glitch_altar.gsc (kiosks/
// bench/box/PaP), _acc_paradise.gsc (FX/pts/loot), _acc_bus_trench.gsc (risers),
// _acc_surface_deco.gsc (twin tables), _acc_atmosphere.gsc (flare), scientist
// office/exo/scatter/entry-script origins, gen_descent_hub.js + infestation
// data (generator SoT sync).
//
// !! GEOMETRY -> the LED bake is THE GATE: full cod2map+LED after this.
// Usage: node tools/oneshots/gen_compress_lab_paradise.js [--dry]
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const MARKER = 'ACCLPC01';
const DRY = process.argv.includes('--dry');

let src = fs.readFileSync(MAP, 'utf8');
if (src.includes(MARKER)) { console.error('REFUSED: ' + MARKER + ' already applied.'); process.exit(2); }
const NL = src.includes('\r\n') ? '\r\n' : '\n';
let lines = src.split(/\r?\n/);

let errors = 0;
const die = (m) => { console.error('FATAL: ' + m); process.exit(3); };
const warn = (m) => { console.error('WARN: ' + m); errors++; };

// =============================================================================
// PART A - PARADISE plaza brush value-remap (guid-addressed, face-line aware).
// Winding (gen_descent_hub box()): face lines per brush = [z1, z2, y1, x2, y2, x1].
// We rewrite ONLY the defining coordinate on the 4 side-plane lines.
// =============================================================================
// old->new: X1 -1000->-700 (outer -1020->-720), X2 1000->700 (outer 1020->720),
//           Y1 -2200->-2000 (outer -2220->-2020). Y2 (-600/-580) unchanged.
const PLAZA_BRUSHES = {
  '{7A2BAB0E-ACE0-4E0C-8A3F-000000000016}': { y1: [-2220, -2020], x2: [1020, 720], y2: null, x1: [-1020, -720] },  // floor
  '{7A2BAB0E-ACE0-4E0C-8A3F-000000000017}': { y1: [-2220, -2020], x2: [1020, 720], y2: null, x1: [-1020, -720] },  // sky cap
  '{7A2BAB0E-ACE0-4E0C-8A3F-000000000018}': { y1: [-2220, -2020], x2: [1020, 720], y2: [-2200, -2000], x1: [-1020, -720] },  // S wall
  '{7A2BAB0E-ACE0-4E0C-8A3F-000000000019}': { y1: [-2200, -2000], x2: [-1000, -700], y2: null, x1: [-1020, -720] },  // W wall
  '{7A2BAB0E-ACE0-4E0C-8A3F-00000000001A}': { y1: [-2200, -2000], x2: [1020, 720], y2: null, x1: [1000, 700] },      // E wall
  '{7A2BAB0E-ACE0-4E0C-8A3F-00000000001B}': { y1: null, x2: null, y2: null, x1: [-1020, -720] },                    // N wall W seg
  '{7A2BAB0E-ACE0-4E0C-8A3F-00000000001C}': { y1: null, x2: [1020, 720], y2: null, x1: null },                      // N wall E seg
};

function remapFaceLine(line, axis, oldV, newV) {
  // axis 'x' -> value is 1st number in each point; 'y' -> 2nd number.
  const idx = axis === 'x' ? 0 : 1;
  const pts = line.match(/\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/g);
  if (!pts || pts.length !== 3) return null;
  let out = line;
  // Replace the defining value in all 3 points (it appears as the same number).
  const reNum = new RegExp('(\\(\\s*)' + (idx === 0 ? '(' + escNum(oldV) + ')(\\s+-?[\\d.]+\\s+-?[\\d.]+\\s*\\))' : '(-?[\\d.]+\\s+)(' + escNum(oldV) + ')(\\s+-?[\\d.]+\\s*\\))'), 'g');
  let count = 0;
  if (idx === 0) {
    out = out.replace(new RegExp('\\(\\s*' + escNum(oldV) + '(?=\\s)', 'g'), () => { count++; return '( ' + newV; });
  } else {
    out = out.replace(new RegExp('(\\(\\s*-?[\\d.]+\\s+)' + escNum(oldV) + '(?=\\s)', 'g'), (m, p1) => { count++; return p1 + newV; });
  }
  if (count !== 3) return null;
  return out;
}
function escNum(v) { return String(v).replace(/[.*+?^${}()|[\]\\]/g, '\\$&').replace(/^-/, '-'); }

let plazaBrushesDone = 0;
for (const [guid, spec] of Object.entries(PLAZA_BRUSHES)) {
  const gi = lines.findIndex((l) => l.includes(guid));
  if (gi < 0) { warn('plaza brush guid not found: ' + guid); continue; }
  // face lines are gi+1 .. gi+6 (z1, z2, y1, x2, y2, x1)
  const faceAxis = [null, null, null, 'y', 'x', 'y', 'x'];
  const faceKey = [null, null, null, 'y1', 'x2', 'y2', 'x1'];
  let ok = true;
  for (let f = 3; f <= 6; f++) {
    const m = spec[faceKey[f]];
    if (!m) continue;
    const nl2 = remapFaceLine(lines[gi + f], faceAxis[f], m[0], m[1]);
    if (nl2 === null) { warn('plaza brush ' + guid + ' face ' + faceKey[f] + ': value ' + m[0] + ' not matched x3 on line ' + (gi + f + 1)); ok = false; continue; }
    lines[gi + f] = nl2;
  }
  if (ok) plazaBrushesDone++;
}
console.log('[A] plaza brushes remapped: ' + plazaBrushesDone + '/7');

// =============================================================================
// PART B - PARADISE misc_model re-home (cluster rules; entity walk).
// =============================================================================
function paradiseXform(x, y) {
  const ax = Math.abs(x), sx = x < 0 ? -1 : 1;
  let nx = x, ny = y;
  if (ax >= 800) {
    nx = sx * (ax - 300);
    if (y <= -2000) ny = y + 200;
    else if (y >= -800) ny = y;
    else if (y >= -1300 && y <= -1000) ny = y + 115;
    else ny = (y <= -1500) ? y + 200 : y;
  } else {
    if (y <= -1500) ny = y + 200;
    if (ax === 450 && Math.abs(y + 690) < 30) nx = sx * 435;
  }
  return [nx, ny];
}

// walk top-level entities; for misc_model with origin in the paradise band, transform.
let depth = 0, entStart = -1, entKV = {}, entOriginLine = -1;
let paradiseMoved = 0;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') { depth++; if (depth === 1) { entStart = i; entKV = {}; entOriginLine = -1; } continue; }
  if (t === '}') {
    if (depth === 1 && entKV.classname === 'misc_model' && entOriginLine > 0) {
      const [x, y, z] = entKV.origin.split(/\s+/).map(Number);
      if (x >= -1100 && x <= 1100 && y >= -2300 && y <= -560 && z <= -800 && z >= -1250) {
        const [nx, ny] = paradiseXform(x, y);
        if (nx !== x || ny !== y) {
          lines[entOriginLine] = lines[entOriginLine].replace('"origin" "' + entKV.origin + '"', '"origin" "' + nx + ' ' + ny + ' ' + z + '"');
          paradiseMoved++;
        }
      }
    }
    depth--; continue;
  }
  if (depth === 1) {
    const m = t.match(/^"([^"]+)" "([^"]*)"$/);
    if (m) { entKV[m[1]] = m[2]; if (m[1] === 'origin') entOriginLine = i; }
  }
}
console.log('[B] paradise misc_models re-homed: ' + paradiseMoved);

// =============================================================================
// PART C - LAB: entity moves (matched by exact origin + model/targetname).
// =============================================================================
// [matchKey, matchValue, oldOrigin, newOrigin, (optional) newAngles]
const LAB_MOVES = [
  // perk-row STAGING (machines spawn here pre-blackscreen, then the opening scatter
  // relocates them - keep them inside the playable room): y4195 -> 3800.
  ['model', '_prefabs/zm/zm_core/vending_juggernaut_struct.map', '-525 4195 3', '-525 3800 3'],
  ['model', '_prefabs/zm/zm_core/vending_sleight_struct.map', '-375 4195 0', '-375 3800 0'],
  ['model', '_prefabs/zm/zm_core/vending_doubletap_struct.map', '-225 4195 0', '-225 3800 0'],
  ['model', '_prefabs/zm/zm_core/vending_marathon_struct.map', '-75 4195 0', '-75 3800 0'],
  ['model', '_prefabs/zm/zm_core/vending_additionalprimaryweapon_struct.map', '75 4195 0', '75 3800 0'],
  ['model', '_prefabs/zm/zm_core/vending_revive_struct.map', '-675 4195 0', '-675 3800 0'],
  ['model', 'p7_zm_vending_ads', '225 4195 0', '225 3800 0'],
  ['model', 'p7_zm_vending_widows_wine', '375 4195 0', '375 3800 0'],
  ['model', 'p7_zm_vending_nuke', '525 4195 0', '525 3800 0'],
  ['model', 'electric_cherry_model', '675 4195 0', '675 3800 0'],
  // LED strips onto the new inner N wall face (y3868, model hugs at -1)
  ['model', 'p7_sky_light_led_01_b_blue', '-525 4227 175', '-525 3867 175'],
  ['model', 'p7_sky_light_led_01_b_blue', '-225 4227 175', '-225 3867 175'],
  ['model', 'p7_sky_light_led_01_b_blue', '225 4227 175', '225 3867 175'],
  ['model', 'p7_sky_light_led_01_b_blue', '525 4227 175', '525 3867 175'],
  // riser row y3948 -> in front of the new N band (>=45u off every clip)
  ['targetname', 'lab_zone_spawners', '-381 3948 0', '-381 3760 0'],
  ['targetname', 'lab_zone_spawners', '-191 3948 0', '-110 3790 0'],
  ['targetname', 'lab_zone_spawners', '14 3948 0', '14 3808 0'],
  ['targetname', 'lab_zone_spawners', '219 3948 0', '219 3808 0'],
  ['targetname', 'lab_zone_spawners', '419 3948 0', '419 3808 0'],
  // roof-light row y4068 -> y3800 (same radii/intensity - noir freeze respected)
  ['targetname', 'acc_roof_light_lab_2', '-601 4068 200', '-601 3800 200'],
  ['targetname', 'acc_roof_light_lab_5', '-188 4068 200', '-188 3800 200'],
  ['targetname', 'acc_roof_light_lab_8', '226 4068 200', '226 3800 200'],
  ['targetname', 'acc_roof_light_lab_11', '639 4068 200', '639 3800 200'],
  // neon pool light (pairs with the _acc_atmosphere purple flare - GSC edited too)
  ['targetname', 'acc_neon_19', '0 4060 175', '0 3830 175'],
  // APD island: turbine + canister flush the new wall (mesh extends -y from origin)
  ['model', 'p8_zm_whi_apd_turbine', '160 3856 0', '160 3868 0'],
  ['model', 't10_zm_aether_canister_on', '100 3870 0', '100 3860 0'],
  // old E-wall industrial corner -> new N wall row + NE spur (clips follow in
  // add_prop_clips.js; yaw 90 -> 0 where the unit now backs the N wall)
  ['model', 'p8_zm_off_console_control_01', '774 3852 0', '330 3846 0', '0 0 0'],
  ['model', 'p8_zm_off_console_control_02', '774 3960 0', '520 3846 0', '0 0 0'],
  ['model', 'p8_zm_off_filing_cabinet_01', '777 3898 0', '718 3852 0', '0 0 0'],
  ['model', 'p8_zm_off_tank_chemical', '690 3880 0', '724 3792 0'],
  ['model', 'p8_zm_off_tank_chemical', '690 3965 0', '735 3737 0'],
  ['model', 'p8_zm_off_morgue_table', '620 3920 0', '-190 3240 0', '0 90 0'],
  ['model', 'p8_zm_off_locker_military_open', '600 3835 0', '610 3852 0'],
  ['model', 'p8_zm_off_locker_military_closed', '648 3835 0', '658 3852 0'],
];

let labMoved = 0;
for (const [k, v, oldO, newO, newAng] of LAB_MOVES) {
  // find the entity block whose kv matches k=v AND origin=oldO
  let found = 0;
  depth = 0; let s = -1; let kv = {}; let oLine = -1; let aLine = -1;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { depth++; if (depth === 1) { s = i; kv = {}; oLine = -1; aLine = -1; } continue; }
    if (t === '}') {
      if (depth === 1 && kv[k] === v && kv.origin === oldO) {
        found++;
        if (found === 1) {
          lines[oLine] = lines[oLine].replace('"origin" "' + oldO + '"', '"origin" "' + newO + '"');
          if (newAng && aLine > 0) lines[aLine] = lines[aLine].replace(/"angles" "[^"]*"/, '"angles" "' + newAng + '"');
          labMoved++;
        }
      }
      depth--; continue;
    }
    if (depth === 1) {
      const m = t.match(/^"([^"]+)" "([^"]*)"$/);
      if (m) { kv[m[1]] = m[2]; if (m[1] === 'origin') oLine = i; if (m[1] === 'angles') aLine = i; }
    }
  }
  if (found === 0) warn('LAB move target not found: ' + k + '=' + v + ' @ ' + oldO);
  if (found > 1) warn('LAB move target ambiguous (' + found + ' hits): ' + k + '=' + v + ' @ ' + oldO);
}
console.log('[C] lab entities moved: ' + labMoved + '/' + LAB_MOVES.length);

// =============================================================================
// PART D - SCIENTIST OFFICE translate (dy = -360): shell brushes + volume brush
// (guid-addressed y-plane rewrite) and entities (origin >= y3888 band).
// =============================================================================
const DY = -360;
// Office brushes by guid: shell floor/W/E/N/ceiling = ...0004-0008, volume = ...0009,
// door slab brush = ...0010, trigger brush = ...0012. All use the box() winding
// (face lines: z1, z2, y1, x2, y2, x1) - shift the two y-plane lines by DY.
const OFFICE_BRUSH_GUIDS = [
  '{ACC5C0DE-0000-4000-8000-000000000004}',
  '{ACC5C0DE-0000-4000-8000-000000000005}',
  '{ACC5C0DE-0000-4000-8000-000000000006}',
  '{ACC5C0DE-0000-4000-8000-000000000007}',
  '{ACC5C0DE-0000-4000-8000-000000000008}',
  '{ACC5C0DE-0000-4000-8000-000000000009}',
  '{ACC5C0DE-0000-4000-8000-000000000010}',
  '{ACC5C0DE-0000-4000-8000-000000000012}',
];
function shiftYPlaneLine(line, dy) {
  // y-plane line: the 2nd number of each of the 3 points is the SAME y value.
  const pts = line.match(/\(\s*(-?[\d.]+)\s+(-?[\d.]+)\s+(-?[\d.]+)\s*\)/g);
  if (!pts || pts.length !== 3) return null;
  const ys = pts.map((p) => Number(p.match(/\(\s*-?[\d.]+\s+(-?[\d.]+)/)[1]));
  if (ys[0] !== ys[1] || ys[1] !== ys[2]) return null;
  const oldY = ys[0], newY = oldY + dy;
  let count = 0;
  const out = line.replace(new RegExp('(\\(\\s*-?[\\d.]+\\s+)' + escNum(oldY) + '(?=\\s)', 'g'), (m, p1) => { count++; return p1 + newY; });
  return count === 3 ? out : null;
}
let officeBrushesDone = 0;
for (const guid of OFFICE_BRUSH_GUIDS) {
  const gi = lines.findIndex((l) => l.includes(guid));
  if (gi < 0) { warn('office brush guid not found: ' + guid); continue; }
  let ok = true;
  for (const f of [3, 5]) {  // y1 + y2 face lines
    const nl2 = shiftYPlaneLine(lines[gi + f], DY);
    if (nl2 === null) { warn('office brush ' + guid + ' face@+' + f + ' not a y-plane'); ok = false; continue; }
    lines[gi + f] = nl2;
  }
  if (ok) officeBrushesDone++;
}
console.log('[D] office brushes translated: ' + officeBrushesDone + '/' + OFFICE_BRUSH_GUIDS.length);

// Office point entities: statics + lights + probe, x[-320,170] y[4240,4600].
let officeEntsMoved = 0;
depth = 0; let kv2 = {}, oLine2 = -1;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') { depth++; if (depth === 1) { kv2 = {}; oLine2 = -1; } continue; }
  if (t === '}') {
    if (depth === 1 && oLine2 > 0 && kv2.origin) {
      const cls = kv2.classname || '';
      if (cls === 'misc_model' || cls === 'light' || cls === 'reflection_probe') {
        const [x, y, z] = kv2.origin.split(/\s+/).map(Number);
        if (x >= -320 && x <= 170 && y >= 4240 && y <= 4600) {
          lines[oLine2] = lines[oLine2].replace('"origin" "' + kv2.origin + '"', '"origin" "' + x + ' ' + (y + DY) + ' ' + z + '"');
          officeEntsMoved++;
        }
      }
    }
    depth--; continue;
  }
  if (depth === 1) {
    const m = t.match(/^"([^"]+)" "([^"]*)"$/);
    if (m) { kv2[m[1]] = m[2]; if (m[1] === 'origin') oLine2 = i; }
  }
}
console.log('[D] office point entities translated: ' + officeEntsMoved + ' (expect 15: 12 statics + 2 lights + probe)');
if (officeEntsMoved !== 15) warn('office entity count mismatch: ' + officeEntsMoved + ' != 15');

// =============================================================================
// PART E - LAB worldspawn adds: inner N wall (with doorway) + old-doorway plug.
// Same proven filler winding as gen_scientist_office box().
// =============================================================================
let guidN = 0;
const gguid = () => '{ACCA9000-0000-4000-8000-' + String(++guidN).padStart(12, '0') + '}';
if (src.includes('ACCA9000')) die('guid prefix ACCA9000 already in map - collision');
const HEX = 't7_zm_der_tile_hexagon';
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${gguid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`, '}'].join('\n');
}
const wsAdds = [
  `// >>> ${MARKER} LAB INNER N WALL (gen_compress_lab_paradise.js) - seals the dead`,
  '// perk-alcove band y[3888,4228]; the Scientist Office (translated -360) now sits',
  '// INSIDE the old envelope. Doorway x[-123,-27] z[0,128] = the office door slab.',
  box(-781, -123, 3868, 3888, 0, 256, HEX),   // W segment
  box(-27, 819, 3868, 3888, 0, 256, HEX),     // E segment
  box(-123, -27, 3868, 3888, 128, 256, HEX),  // doorway header
  box(-123, -27, 4228, 4248, 0, 128, HEX),    // PLUG: old office doorway in the outer N wall
  `// <<< ${MARKER} LAB INNER N WALL`,
];

// insert before worldspawn close (entity 0)
{
  let d = 0, started = false, wsClose = -1;
  for (let i = 0; i < lines.length; i++) {
    const l = lines[i].trim();
    if (l === '{') { d++; started = true; }
    else if (l === '}') { d--; if (started && d === 0) { wsClose = i; break; } }
  }
  if (wsClose < 0) die('worldspawn close not found');
  lines.splice(wsClose, 0, ...wsAdds.join('\n').split('\n'));
}
console.log('[E] lab inner N wall + plug: 4 brushes added');

// =============================================================================
// PART F - LAB densification statics (all models already zone-listed; entity
// shape = the proven infestation/deco misc_model template).
// =============================================================================
const NEW_STATICS = [
  // W-center data island (breaks the big empty west field; clips: lab_gen_blue /
  // lab_comp_tower / lab_server_comm / lab_dragon_terminal in add_prop_clips.js)
  ['p7_ris_generator_lg_01_blue', -440, 3480, 0, 0],
  ['p7_zm_sta_computer_tower_01', -450, 3560, 0, 0],
  ['p7_zm_moo_server_comm_02', -370, 3545, 0, 180],
  ['p7_zm_sta_dragon_network_data_terminal', -300, 3510, 0, 270],
  ['p7_cru_monitor_holo_screen_01', -380, 3555, 140, 90],
  // 2nd specimen test chamber, NW corner backing the new N wall (yaw 90 = long axis X)
  ['p8_zm_off_test_chamber', -680, 3841, 1, 90],
  ['p8_zm_off_test_chamber_cover', -604, 3864, 24, 0],
  // new N wall: standing console banks + wire sockets + security monitor pair
  ['p8_zm_off_console_standing_02', -500, 3839, 0, 180],
  ['p8_zm_off_console_standing_01', -270, 3841, 0, 0],
  ['p8_zm_off_server_wires_socke_a', -350, 3862, 150, 0],
  ['p8_zm_off_server_wires_socke_b', 60, 3862, 150, 0],
  ['p8_zm_off_monitor_security_mount_01', 140, 3855, 98, 0],
  ['p8_zm_off_monitor_security_screen_on', 140, 3835, 151, 0],
  ['p7_cru_monitor_holo_screen_01', 0, 3862, 140, 180],
  // center-south medical cluster (with the relocated morgue table @ (-190,3240))
  ['p8_zm_off_medical_cart_main', -115, 3240, 0, 90],   // yaw 90 = the M2 cart orientation the hx13/hy18 clip is shaped for
  ['p8_zm_whi_hazmat_suit_floor_01', -260, 3300, 0, 200],
  ['p7_rus_debris_paper_set_01', -300, 3250, 0, 120],
  ['p7_rus_debris_paper_set_02', 100, 3720, 0, 250],
];
const statOut = ['// >>> ' + MARKER + ' LAB DENSIFICATION STATICS (gen_compress_lab_paradise.js)'];
for (const [model, x, y, z, yaw] of NEW_STATICS) {
  statOut.push('{', 'guid "' + gguid() + '"', '"classname" "misc_model"',
    '"model" "' + model + '"', '"origin" "' + x + ' ' + y + ' ' + z + '"',
    '"angles" "0 ' + yaw + ' 0"',
    '"lightingstate1" "1"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"modelscale" "1"', '"static" "1"', '}');
}
statOut.push('// <<< ' + MARKER + ' LAB DENSIFICATION STATICS');
console.log('[F] lab densification statics: ' + NEW_STATICS.length);

// =============================================================================
// write out
// =============================================================================
while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...statOut, '');

if (errors > 0 && !DRY) die(errors + ' warnings - refusing to write. Fix matchers first.');
if (DRY) { console.log('[dry] no write. warnings: ' + errors); process.exit(errors ? 1 : 0); }

fs.copyFileSync(MAP, MAP + '.acc-lpc-orig');
fs.writeFileSync(MAP, lines.join(NL) + NL);
console.log('APPLIED ' + MARKER + '. backup: ' + MAP + '.acc-lpc-orig');
console.log('NEXT: edit+rerun gen_paradise_props.js, add_prop_clips.js, GSC wiring, then FULL LED bake.');
