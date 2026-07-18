#!/usr/bin/env node
// swap_box_to_aw_printer.js - ONE-SHOT (2026-07-12): replace the stock Der Riese zbarrier
// mystery box with PLANET's AW 3D Printer box at the same 7 locations.
//
//   node tools/oneshots/swap_box_to_aw_printer.js            (applies to map_source/zm/*.map)
//
// What it does, in one pass over map_source/zm/zm_abandoned_cyber_city.map:
//   1. DELETES the 7 zbarrier_zmcore_MagicBox entities (script_noteworthy acc_box_*_zbarrier)
//      and their 7 paired treasure_chest_use script_structs (script_noteworthy acc_box_*).
//      With ZERO treasure_chest_use structs, stock treasure_chest_init returns immediately -
//      that empty-return IS the clean stock-box disable (never touch level.enable_magic:
//      it also gates perks + fire sale).
//   2. REPLACES the 7 acc_box_clip_<node> script_brushmodel clips (chest-shaped, 96x40x64)
//      with AW-machine-shaped ones (38 deep x 64 wide x 120 tall, rotated per machine yaw).
//      SAME targetnames, so _acc_map_randomizer::solidify_all_box_clips +
//      manage_prop_clip_navmesh keep working untouched. script_brushmodel = LED-exempt.
//   3. APPENDS per location: a BAKED misc_model machine body (dlc_weapon_mystery_box_01_static),
//      the animated door-rig script_model (dlc_weapon_mystery_box_01, unique targetname
//      acc_awbox_<node> - the shipped prefab reuses ONE targetname, which would break
//      GetEnt on multi-placement), and the aw_exo_mysterybox_location script_struct the AW
//      driver reads (target -> the rig; plaza carries script_noteworthy "starting_loc" so
//      the start box is ALWAYS the plaza - pairs with the [acc] vendor bugfix in
//      scripts/planet/_aw/_zm_aw_mysterybox.gsc::__main__).
//
// GEOMETRY FACTS (from the shipped prefab zm_exo_mysterybox_location.map):
//   machine local footprint x[-20,18] y[-32,32] z[0,120]; yaw 0 = front faces +x, back at
//   local x=-20. Our old chest origins sit exactly 20u off their wall faces, so with the
//   yaw chosen to face the room, the machine back lands flush ON the wall.
//   Weapon-display struct = machine origin + R(yaw)*(4,-4) + 38z, struct yaw = machine+90
//   (weapon shown side-on, prefab convention).
//
// ONE-SHOT: refuses to run if aw_exo_mysterybox_location already exists in the .map.

'use strict';
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// node, machine origin, machine yaw (front faces room; back flush on the wall face)
const LOCS = [
  { node: 'market', x: -2121, y: 928,  z: 0,    yaw: 0,   start: false }, // W wall x=-2141
  { node: 'corp',   x: 400,   y: 2708, z: 0,    yaw: 270, start: false }, // N wall y=2728
  { node: 'roof',   x: -1899, y: 2830, z: 0,    yaw: 0,   start: false }, // W wall x=-1919
  { node: 'plaza',  x: 100,   y: -150, z: 0,    yaw: 270, start: true  }, // free-standing, front faces start-room south
  { node: 'lab',    x: 779,   y: 3650, z: 0,    yaw: 180, start: false }, // E wall x=799
  { node: 'vault',  x: 1899,  y: 2830, z: 0,    yaw: 180, start: false }, // E wall x=1919
  { node: 'trench', x: -364,  y: 2235, z: -240, yaw: 0,   start: false }, // W wall x=-384 (under-room)
];

// Local machine bounds (prefab clip brush).
const LX0 = -20, LX1 = 18, LY0 = -32, LY1 = 32, LZH = 120;

function rot(yaw, lx, ly) {
  switch (yaw) {
    case 0:   return [lx, ly];
    case 90:  return [-ly, lx];
    case 180: return [-lx, -ly];
    case 270: return [ly, -lx];
    default: throw new Error('yaw must be a multiple of 90: ' + yaw);
  }
}

function clipBounds(l) {
  const c = [rot(l.yaw, LX0, LY0), rot(l.yaw, LX1, LY0), rot(l.yaw, LX0, LY1), rot(l.yaw, LX1, LY1)];
  const xs = c.map(p => p[0]), ys = c.map(p => p[1]);
  return {
    x0: l.x + Math.min(...xs), x1: l.x + Math.max(...xs),
    y0: l.y + Math.min(...ys), y1: l.y + Math.max(...ys),
    z0: l.z, z1: l.z + LZH,
  };
}

let guidSeq = 0;
function guid() {
  guidSeq++;
  return '{A3B0C4D0-ACC7-4E0B-8A3F-' + String(guidSeq).padStart(12, '0') + '}';
}

// Plane-line template cloned from the LIVE acc_box_clip_* clips (align_box_clips.js output,
// proven solid in-game): 3 points per plane share the constant coordinate; the other coords
// are inert template values.
function clipEntity(node, b) {
  return [
    '{',
    'guid "' + guid() + '"',
    '"classname" "script_brushmodel"',
    '"targetname" "acc_box_clip_' + node + '"',
    '// brush 0',
    '{',
    ' guid "' + guid() + '"',
    ` ( 134.5 459.5 ${b.z0} ) ( 86.5 459.5 ${b.z0} ) ( 86.5 419.5 ${b.z0} ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    ` ( 94.5 419.5 ${b.z1} ) ( 94.5 459.5 ${b.z1} ) ( 142.5 459.5 ${b.z1} ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    ` ( 86.5 ${b.y0} 88 ) ( 134.5 ${b.y0} 88 ) ( 134.5 ${b.y0} 0 ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    ` ( ${b.x1} 415.5 88 ) ( ${b.x1} 455.5 88 ) ( ${b.x1} 455.5 0 ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    ` ( 138.5 ${b.y1} 88 ) ( 90.5 ${b.y1} 88 ) ( 90.5 ${b.y1} 0 ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    ` ( ${b.x0} 459.5 88 ) ( ${b.x0} 419.5 88 ) ( ${b.x0} 419.5 0 ) clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`,
    '}',
    '}',
  ].join('\n');
}

function machineEntities(l) {
  const [dx, dy] = rot(l.yaw, 4, -4);          // prefab weapon-display offset
  const sx = l.x + dx, sy = l.y + dy, sz = l.z + 38;
  const structYaw = (l.yaw + 90) % 360;         // weapon shown side-on (prefab convention)
  const out = [];
  out.push([
    `// [acc] AW 3D Printer mystery box - ${l.node} (PLANET pack 2026-07-12; swap_box_to_aw_printer.js).`,
    `// Baked machine body + animated door rig + the aw_exo_mysterybox_location struct the`,
    `// driver (scripts/planet/_aw/_zm_aw_mysterybox.gsc) reads. Clip: acc_box_clip_${l.node}.`,
    '{',
    'guid "' + guid() + '"',
    '"classname" "misc_model"',
    '"model" "dlc_weapon_mystery_box_01_static"',
    `"origin" "${l.x} ${l.y} ${l.z}"`,
    `"angles" "0 ${l.yaw} 0"`,
    '"lightingstate1" "1"',
    '"lightingstate2" "1"',
    '"lightingstate3" "1"',
    '"lightingstate4" "1"',
    '"modelscale" "1"',
    '"static" "1"',
    '}',
  ].join('\n'));
  out.push([
    '{',
    'guid "' + guid() + '"',
    '"classname" "script_model"',
    '"model" "dlc_weapon_mystery_box_01"',
    `"targetname" "acc_awbox_${l.node}"`,
    `"origin" "${l.x} ${l.y} ${l.z}"`,
    `"angles" "0 ${l.yaw} 0"`,
    '"_color" "1 0 0"',
    '"client_server" "ServerSide"',
    '"lightingstate1" "1"',
    '"lightingstate2" "1"',
    '"lightingstate3" "1"',
    '"lightingstate4" "1"',
    '"modelscale" "1"',
    '"shadow_casting" "1"',
    '}',
  ].join('\n'));
  out.push([
    '{',
    'guid "' + guid() + '"',
    '"classname" "script_struct"',
    '"targetname" "aw_exo_mysterybox_location"',
    `"target" "acc_awbox_${l.node}"`,
    ...(l.start ? ['"script_noteworthy" "starting_loc"'] : []),
    `"origin" "${sx} ${sy} ${sz}"`,
    `"angles" "0 ${structYaw} 0"`,
    '"_color" "1 0 0"',
    '}',
  ].join('\n'));
  return out;
}

// ---------------------------------------------------------------------------------------

const src = fs.readFileSync(MAP, 'utf8');
if (src.includes('aw_exo_mysterybox_location')) {
  console.error('REFUSING: aw_exo_mysterybox_location already present (one-shot already applied).');
  process.exit(1);
}

const lines = src.split('\n');

// Parse top-level entity blocks: [startLine, endLine] inclusive, with raw text.
const entities = [];
let depth = 0, entStart = -1;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') {
    if (depth === 0) entStart = i;
    depth++;
  } else if (t === '}') {
    depth--;
    if (depth === 0 && entStart >= 0) {
      entities.push({ start: entStart, end: i, text: lines.slice(entStart, i + 1).join('\n') });
      entStart = -1;
    }
  }
}
if (depth !== 0) { console.error('ABORT: unbalanced braces in .map'); process.exit(1); }

function kv(ent, key) {
  const m = ent.text.match(new RegExp('^"' + key + '"\\s+"([^"]*)"', 'm'));
  return m ? m[1] : undefined;
}

const toDelete = [];   // entity indices
const toReplace = new Map(); // entity index -> replacement text
let zb = 0, chests = 0, clips = 0;

for (let e = 0; e < entities.length; e++) {
  const ent = entities[e];
  const cls = kv(ent, 'classname');
  const nw = kv(ent, 'script_noteworthy');
  const tn = kv(ent, 'targetname');
  if (cls === 'zbarrier_zmcore_MagicBox' && nw && /^acc_box_\w+_zbarrier$/.test(nw)) {
    toDelete.push(e); zb++;
  } else if (cls === 'script_struct' && tn === 'treasure_chest_use') {
    toDelete.push(e); chests++;
  } else if (cls === 'script_brushmodel' && tn && /^acc_box_clip_(\w+)$/.test(tn)) {
    const node = tn.replace('acc_box_clip_', '');
    const loc = LOCS.find(l => l.node === node);
    if (!loc) { console.error('ABORT: clip for unknown node ' + node); process.exit(1); }
    toReplace.set(e, clipEntity(node, clipBounds(loc)));
    clips++;
  }
}

if (zb !== 7 || chests !== 7 || clips !== 7) {
  console.error(`ABORT: expected 7/7/7, found zbarriers=${zb} chests=${chests} clips=${clips}`);
  process.exit(1);
}

// Rebuild the file. Deleted entities also drop their contiguous IMMEDIATELY-preceding
// comment lines (they describe the deleted chest). Replaced entities keep surrounding text.
const drop = new Set();
for (const e of toDelete) {
  for (let i = entities[e].start; i <= entities[e].end; i++) drop.add(i);
  for (let i = entities[e].start - 1; i >= 0 && lines[i].trim().startsWith('//'); i--) drop.add(i);
}
const replaceAt = new Map(); // startLine -> {endLine, text}
for (const [e, text] of toReplace) replaceAt.set(entities[e].start, { end: entities[e].end, text });

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (replaceAt.has(i)) {
    out.push(replaceAt.get(i).text);
    i = replaceAt.get(i).end;
    continue;
  }
  if (drop.has(i)) continue;
  out.push(lines[i]);
}

// Append the 21 machine entities.
out.push('// =========================================================================');
out.push('// [acc] AW 3D PRINTER MYSTERY BOX (PLANET pack, 2026-07-12) - the 7 machine');
out.push('// locations replacing the stock Der Riese zbarrier chests (deleted above by');
out.push('// tools/oneshots/swap_box_to_aw_printer.js). Driver: scripts/planet/_aw/.');
out.push('// =========================================================================');
for (const l of LOCS) out.push(...machineEntities(l));

const result = out.join('\n') + (src.endsWith('\n') && !out[out.length - 1].endsWith('\n') ? '\n' : '');

// Backup, then write.
const bak = MAP + '.pre-aw-box-swap.bak';
fs.writeFileSync(bak, src);
fs.writeFileSync(MAP, result);

// Verify.
const chk = fs.readFileSync(MAP, 'utf8');
const count = (re) => (chk.match(re) || []).length;
console.log('deleted zbarriers:', zb, '| deleted chest structs:', chests, '| reshaped clips:', clips);
console.log('aw_exo_mysterybox_location:', count(/"aw_exo_mysterybox_location"/g), '(want 7)');
console.log('treasure_chest_use left:', count(/"treasure_chest_use"/g), '(want 0)');
console.log('zbarrier_zmcore_MagicBox left:', count(/zbarrier_zmcore_MagicBox/g), '(want 0)');
console.log('acc_box_clip_* left:', count(/"acc_box_clip_\w+"/g), '(want 7)');
console.log('starting_loc:', count(/"starting_loc"/g), '(want 1)');
console.log('backup:', bak);
