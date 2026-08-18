#!/usr/bin/env node
// !! 2026-08-02 NOTE (gen_compress_lab_paradise.js): the applied office was TRANSLATED
// -360 in y by the lab compression - the live room interior is x[-275,125] y[3888,4208],
// its doorway now cuts the NEW inner Lab N wall at y[3868,3888] (the coordinates below
// describe the ORIGINAL as-built placement and are kept for the historical record; the
// old outer-wall doorway is plugged). Do not re-run this against the compressed map.
// gen_scientist_office.js - THE SCIENTIST'S OFFICE (user 2026-07-26): a small buyable
// room behind the Lab's NORTH wall (where the old 10-alcove perk row was), themed as the
// gun-stealing Scientist boss's office (docs/44 lore hook). Contains the Exo Suit station
// (moved from the Lab floor / Plaza) + a desk with a random category-paired gun+implant
// drop (_acc_scientist_office.gsc). Door = 2000-pt buyable on the N wall (script_flag
// enter_scientist_office; the entry script's zone_door_buy_loop drives the buy).
//
// MAP SURGERY (one-shot, refuses re-apply via the marker below):
//   1. SPLIT the Lab N-wall brush (guid ...0128: x[-781,819] y[4228,4248] z[0,256]) into
//      west/east segments + a header over a 96-wide doorway at x[-123,-27] z[0,128].
//   2. ADD the room shell to worldspawn: interior x[-275,125] y[4248,4568] z[0,256],
//      20u walls, floor z[-16,0], ceiling z[256,272]. All t7_zm_der_tile_hexagon (the
//      Lab's own material - already baked, zero asset risk).
//   3. EXTEND the lab_zone info_volume with a 4th brush over the room (OOB-monitor cover;
//      same-zone room -> NO zonemgr adjacency needed, the door flag just opens the slab).
//   4. ENTITIES: door slab (acc_door_scientist, diamond plate) + its dead map trigger_use
//      (zombie_door / zombie_cost 2000 / script_flag enter_scientist_office - the entry
//      script disables it and spawns dual radius triggers at the hardcoded center) +
//      2 cool-white omni lights (foundry-light field set) + 12 misc_model statics from
//      the ALREADY-ZONED BO4 office kit (p8_zm_off_*, research 2026-07-26: every model
//      below is zone-listed AND already baked elsewhere in this map - no new zone lines).
//
// Collision for the big props lives in tools/add_prop_clips.js (sci_* entries) - re-run
// it AFTER this (its section markers are independent of ours). Usage:
//   node tools/oneshots/gen_scientist_office.js map_source/zm/zm_abandoned_cyber_city.map
'use strict';
const fs = require('fs');

const MARKER = '>>> ACC SCIENTIST OFFICE (gen_scientist_office.js)';
const mapPath = process.argv[2];
if (!mapPath) { console.error('usage: gen_scientist_office.js <map>'); process.exit(1); }
let text = fs.readFileSync(mapPath, 'utf8');
if (text.includes(MARKER)) { console.error('REFUSED: scientist office already applied (marker found)'); process.exit(2); }

const WALL_GUID = '{7A2B9D00-ACC1-4E0A-8A3F-000000000128}';   // Lab N wall x[-781,819] y[4228,4248] z[0,256]
const MAT = 't7_zm_der_tile_hexagon';
const DOOR_MAT = 't7_metal_diamond_plate_worn_wet';

let guidN = 0;
const guid = () => `{ACC5C0DE-0000-4000-8000-${String(++guidN).padStart(12, '0')}}`;

// Axis-aligned brush emitter - same plane winding as tools/add_prop_clips.js box().
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`, '}'].join('\n');
}

// ---- 1. split the N wall around the doorway (x[-123,-27], z[0,128]) --------
// LINE-BASED (the guid STRING itself starts with '{', so string-index brace
// hunting grabs the guid's own brace - found the hard way on the first run):
// the brush block is [open '{' line] [guid line] [6 face lines] ['}' line].
let lines = text.split('\n');
const gLine = lines.findIndex((l) => l.includes(WALL_GUID));
if (gLine < 0) { console.error('FATAL: N-wall guid not found - wall moved? aborting, map untouched'); process.exit(3); }
if (lines[gLine - 1].trim() !== '{') { console.error('FATAL: N-wall brush open brace not where expected'); process.exit(3); }
let wallEnd = -1;
for (let i = gLine + 1; i < gLine + 12; i++) {
  if (lines[i].trim() === '}') { wallEnd = i; break; }
}
if (wallEnd < 0) { console.error('FATAL: N-wall brush close not found'); process.exit(3); }
const wallRepl = [
  `// ${MARKER} - N wall split: W seg + E seg + doorway header (was one x[-781,819] brush)`,
  box(-781, -123, 4228, 4248, 0, 256, MAT),
  box(-27, 819, 4228, 4248, 0, 256, MAT),
  box(-123, -27, 4228, 4248, 128, 256, MAT),
];
lines.splice(gLine - 1, wallEnd - (gLine - 1) + 1, ...wallRepl.join('\n').split('\n'));

// ---- 2. room shell into worldspawn (insert before worldspawn's closing brace) ----
let depth = 0, started = false, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const l = lines[i].trim();
  if (l === '{') { depth++; started = true; }
  else if (l === '}') { depth--; if (started && depth === 0) { wsClose = i; break; } }
}
if (wsClose < 0) { console.error('FATAL: worldspawn close not found'); process.exit(3); }
const shell = [
  `// ${MARKER} - room shell: interior x[-275,125] y[4248,4568] z[0,256]`,
  box(-295, 145, 4248, 4588, -16, 0, MAT),     // floor
  box(-295, -275, 4248, 4588, 0, 256, MAT),    // W wall
  box(125, 145, 4248, 4588, 0, 256, MAT),      // E wall
  box(-275, 125, 4568, 4588, 0, 256, MAT),     // N wall
  box(-295, 145, 4228, 4588, 256, 272, MAT),   // ceiling
  `// ${MARKER} - end room shell`,
];
lines.splice(wsClose, 0, ...shell.join('\n').split('\n'));

// ---- 3. extend lab_zone info_volume with a brush over the room -------------
// Line-based like the wall split: from the targetname line, depth starts at 1
// (inside the entity); insert the new brush before the line where depth hits 0.
const zLine = lines.findIndex((l) => l.trim() === '"targetname" "lab_zone"');
if (zLine < 0) { console.error('FATAL: lab_zone volume not found'); process.exit(3); }
let d2 = 1, zoneClose = -1;
for (let i = zLine + 1; i < lines.length; i++) {
  const l = lines[i].trim();
  if (l === '{') d2++;
  else if (l === '}') { d2--; if (d2 === 0) { zoneClose = i; break; } }
}
if (zoneClose < 0) { console.error('FATAL: lab_zone close not found'); process.exit(3); }
const volT = 'volume 64 64 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
const zoneBrush = ['// brush 3 - ' + MARKER + ' (OOB cover over the office)',
  box(-295, 145, 4228, 4588, -16, 400, 'volume').replace(/volume 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0/g, volT)];
lines.splice(zoneClose, 0, ...zoneBrush.join('\n').split('\n'));

// ---- 4. entities appended at EOF -------------------------------------------
function ent(props, brushes) {
  const out = ['{', `guid "${guid()}"`];
  for (const [k, v] of Object.entries(props)) out.push(`"${k}" "${v}"`);
  if (brushes) for (const b of brushes) out.push(b);
  out.push('}');
  return out.join('\n');
}
const model = (m, x, y, z, yaw) => ent({
  classname: 'misc_model', model: m, origin: `${x} ${y} ${z}`, angles: `0 ${yaw} 0`,
  lightingstate1: '1', lightingstate2: '1', lightingstate3: '1', lightingstate4: '1', modelscale: '1',
});
const light = (n, x, y, z) => ent({
  classname: 'light', targetname: `acc_sci_light_${n}`, origin: `${x} ${y} ${z}`,
  PRIMARY_TYPE: 'PRIMARY_OMNI', PRIMARY_NOSHADOWMAP: '1', ENABLE_FALLOFF: '1',
  _color: '0.75 0.92 1', radius: '300', stops: '6', falloffdistance: '12',
  bake_intensity_scale: '0.35', client_server: 'ClientSide', def_tile: '1 1',
  excludeDedicated: 'Off', far_edge: '0.949999988079071', fov_outer: '90',
  // lightingstate1 '1' (NOT the foundry's '0'): the office is a surface room - it must
  // be lit in the powered state too (live fix 2026-07-26 after the white-room test).
  lightingstate1: '1', lightingstate2: '1', lightingstate3: '1', lightingstate4: '1',
  penumbraRadius: '1.5', roundness: '0.5', shadowUpdate: 'Never', shadowmapScale: '1',
  superellipse: '0.75 1 0.75 1', volumetricSampleCount: '8', name: 'light', spawnflags: '82',
});

// !!! SKY-BOX DEPENDENCY (found the hard way, live leak 2026-07-26): the map is SEALED BY
// ITS SKY ENCLOSURE (6 'sky'-material slabs, interior y<=4268 pre-office). This room extends
// to y4588 = THROUGH the north sky slab -> cod2map "restricting BSP to sky brushes ->
// leaked" (.lin trail), broken vis (black void gashes), fullbright-white bake. The applied
// fix (2026-07-26, direct .map edit alongside this generator's run): north sky slab moved
// y[4268,4300] -> y[4640,4672] AND the other four slabs' shared north-edge plane 4300 ->
// 4672 (else the shell gaps). If this generator is ever re-run from scratch, REDO that sky
// edit - grep '( -108096 4300' (5 faces) + '( -109120 4268' (1 face).
const entities = [
  `// ${MARKER} - entities: door slab + trigger + lights + BO4-office statics`,
  // Reflection probe: without one the room has no local env capture (contributes to the
  // washed-out read). gen_reflection_probes.js format - bare classname+origin.
  ent({ classname: 'reflection_probe', origin: '-75 4410 140' }),
  // Door slab fills the doorway cut; entry-script buy loop hides/notsolids it on purchase.
  ent({ classname: 'script_brushmodel', targetname: 'acc_door_scientist',
        script_vector: '0 0 130', script_transition_time: '1.5' },
      [ '// brush 0', box(-123, -27, 4228, 4248, 0, 128, DOOR_MAT) ]),
  // Dead map trigger: zone_door_buy_loop reads cost/flag/target off it, disables it, and
  // spawns dual radius buy-triggers at the hardcoded center (entry-script switch case).
  ent({ classname: 'trigger_use', targetname: 'zombie_door', target: 'acc_door_scientist',
        zombie_cost: '2000', script_flag: 'enter_scientist_office' },
      [ '// brush 0', box(-127, -23, 4220, 4256, 0, 96, 'trigger') ]),
  light(0, -190, 4420, 200),
  light(1, 10, 4420, 200),
  // The Scientist's desk + workspace (all models zone-listed + already baked in this map).
  model('p7_rus_desk_metal_vintage',        -75, 4490, 0, 180),  // HIS desk - the loot gun spawns on top (GSC)
  model('p7_zm_tra_booth_chair',            -75, 4538, 0, 180),  // desk chair, tucked behind
  model('p8_zm_off_coat_lab_rack',         -252, 4540, 0, 0),    // lab-coat rack, NW corner
  model('p8_zm_off_filing_cabinet_01',     -268, 4460, 0, 90),   // filing cabinet, W wall
  model('p8_zm_off_console_control_01',      80, 4532, 0, 180),  // control console, NE corner
  model('p8_zm_off_tank_chemical',           92, 4292, 0, 0),    // chemical tank, SE corner
  model('p8_zm_whi_hazmat_suit_floor_01',    30, 4400, 0, 35),   // crumpled hazmat suit (floor)
  model('p7_rus_debris_paper_set_01',      -150, 4400, 0, 60),   // scattered research notes
  model('p7_rus_debris_paper_set_02',       -10, 4468, 0, 300),  // more notes by the desk
  model('p8_zm_off_lightbox_xray_on',      -269, 4370, 120, 90), // lit x-ray lightbox, W wall
  model('p7_cru_monitor_holo_screen_01',    119, 4430, 130, 270),// glowing holo readout, E wall
  model('p8_zm_off_coat_lab_hanging',        40, 4254, 90, 180), // his coat on the S-wall peg
  `// ${MARKER} - end entities`,
];
while (lines.length && lines[lines.length - 1].trim() === '') lines.pop();
lines.push(...entities.join('\n').split('\n'), '');

fs.writeFileSync(mapPath, lines.join('\n'));
console.log(`[scientist-office] applied: N wall split (door x[-123,-27]), room shell, lab_zone brush 3, ${guidN} guids emitted`);
