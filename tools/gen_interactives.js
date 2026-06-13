#!/usr/bin/env node
// One-shot map pass 3: buyable doors, 3 inline mystery boxes, interaction
// triggers, second power switch, PaP blockers, boss spawn struct.
// Anatomy sources: _zm_blockers door recipe + box_start.map zbarrier KVPs
// (verbatim from shipped zm_alien_isolation) + power-switch dossier - see
// tmp/wf/truth_*.txt. Refuses to double-apply.

'use strict';
const fs = require('fs');
const path = require('path');

const mapPath = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
let map = fs.readFileSync(mapPath, 'utf8');
if (map.includes('zombie_door')) {
  console.error('interactives already applied - refusing.');
  process.exit(1);
}

let guidN = 0x200;
function guid() {
  guidN++;
  return `{7A2B9E00-ACC2-4E0B-8A3F-${guidN.toString(16).toUpperCase().padStart(12, '0')}}`;
}

function brushBox(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '// brush 0',
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

function kvpEnt(kvps, brush) {
  const lines = ['{', `guid "${guid()}"`];
  for (const [k, v] of Object.entries(kvps)) lines.push(`"${k}" "${v}"`);
  if (brush) lines.push(brush);
  lines.push('}');
  return lines.join('\n');
}

const ents = [];

// --- mystery boxes (inline zbarrier + struct pairs; KVPs verbatim from
// shipped box_start.map, only noteworthy pair + origin/angles changed) -----
function magicBox(tag, origin, angles) {
  const zb = {
    classname: 'zbarrier_zmcore_MagicBox',
    angles, barrieranimtime: '0', origin,
    script_noteworthy: `${tag}_zbarrier`,
    showalternatemodel: '0', showupgradedmodel: '0',
    type: 'zmcore_MagicBox',
    zbarrierboardanim1: 'o_zombie_magic_box_fake_idle_twitch_a',
    zbarrierboardanim2: 'o_zombie_magic_box_leave',
    zbarrierboardanim3: 'o_zombie_magic_box_close',
    zbarrierboardanim4: 'o_zombie_magic_box_teddy_rise',
    zbarrierboardanim5: 'o_zombie_magic_box_teddy_rise',
    zbarrierboardmodel1: 'p6_anim_zm_magic_box_fake',
    zbarrierboardmodel2: 'p6_anim_zm_magic_box',
    zbarrierboardmodel3: 'p6_anim_zm_magic_box',
    zbarrierboardmodel4: 'tag_origin',
    zbarrierboardmodel5: 'tag_origin',
    zbarriernumboards: '5',
    zbarriertearanim1: 'o_zombie_magic_box_fake_idle_twitch_b',
    zbarriertearanim2: 'o_zombie_magic_box_arrive',
    zbarriertearanim3: 'o_zombie_magic_box_open',
    zbarriertearanim4: 'o_zombie_magic_box_weapon_rise',
    zbarriertearanim5: 'o_zombie_magic_box_weapon_dual_rise',
  };
  const st = {
    classname: 'script_struct', angles, origin,
    script_noteworthy: tag,
    targetname: 'treasure_chest_use',
    zombie_cost: '950',
    _color: '1 0 0',
  };
  return [kvpEnt(zb), kvpEnt(st)];
}

const marketBox = magicBox('acc_box_market', '-1881 1540 13.75', '0 270 0');
ents.push(...magicBox('acc_box_corp', '640 2690 13.75', '0 270 0'));
ents.push(...magicBox('acc_box_roof', '-1419 3340 13.75', '0 270 0'));

// --- buyable doors: trigger_use + script_brushmodel slab per corridor -----
const DOORS = [
  { id: 'market', dx1: -1176, dx2: -1160, y1: 420, y2: 636, cost: 750, flag: 'enter_market' },
  { id: 'alley', dx1: 1199, dx2: 1215, y1: 420, y2: 636, cost: 750, flag: 'enter_alley' },
  { id: 'corp_w', dx1: -1039, dx2: -1023, y1: 1220, y2: 1436, cost: 1000, flag: 'enter_corp_w' },
  { id: 'corp_e', dx1: 1061, dx2: 1077, y1: 1220, y2: 1436, cost: 1000, flag: 'enter_corp_e' },
  { id: 'vault', dx1: 961, dx2: 977, y1: 2320, y2: 2536, cost: 1250, flag: 'enter_vault' },
  { id: 'roof', dx1: -958, dx2: -942, y1: 2320, y2: 2536, cost: 1250, flag: 'enter_roof' },
  { id: 'lab_e', dx1: 961, dx2: 977, y1: 3120, y2: 3336, cost: 1500, flag: 'enter_lab_e' },
  { id: 'lab_w', dx1: -958, dx2: -942, y1: 3120, y2: 3336, cost: 1500, flag: 'enter_lab_w' },
];
for (const d of DOORS) {
  // purchase trigger (both sides reach it - spans 64 around the slab)
  ents.push(kvpEnt(
    {
      classname: 'trigger_use',
      targetname: 'zombie_door',
      target: `acc_door_${d.id}`,
      zombie_cost: String(d.cost),
      script_flag: d.flag,
    },
    brushBox(d.dx1 - 24, d.dx2 + 24, d.y1, d.y2, 0, 128, 'trigger')
  ));
  // door slab (slides up out of the doorway on purchase)
  ents.push(kvpEnt(
    {
      classname: 'script_brushmodel',
      targetname: `acc_door_${d.id}`,
      script_vector: '0 0 130',
      script_transition_time: '1.5',
    },
    brushBox(d.dx1, d.dx2, d.y1, d.y2, 0, 128, 'script_wall')
  ));
}

// --- PaP approach blockers (randomizer hides one per run) ------------------
ents.push(kvpEnt(
  { classname: 'script_brushmodel', targetname: 'acc_pap_block_server' },
  brushBox(1040, 1056, 3120, 3336, 0, 256, 'script_wall')
));
ents.push(kvpEnt(
  { classname: 'script_brushmodel', targetname: 'acc_pap_block_roof' },
  brushBox(-1056, -1040, 3120, 3336, 0, 256, 'script_wall')
));

// --- interaction triggers ---------------------------------------------------
function useTrigger(targetname, x1, x2, y1, y2) {
  return kvpEnt(
    { classname: 'trigger_use', targetname },
    brushBox(x1, x2, y1, y2, 0, 96, 'trigger')
  );
}
ents.push(useTrigger('acc_cyberware_kiosk', -740, -676, 3520, 3584));   // Lab west
ents.push(useTrigger('acc_overclock_terminal', 676, 740, 3520, 3584)); // Lab east
ents.push(useTrigger('acc_hack_terminal', 319, 383, 1980, 2044));      // Corp
ents.push(useTrigger('acc_overload_terminal', 1680, 1744, 2780, 2844));// Vault
ents.push(useTrigger('acc_power_corp', 735, 799, 1950, 2014));         // beside corp switch
ents.push(useTrigger('acc_power_vault', 2235, 2299, 2850, 2914));      // beside vault switch

// --- structs ------------------------------------------------------------------
ents.push(kvpEnt({
  classname: 'script_struct', origin: '1712 2900 0',
  targetname: 'acc_overload_point', _color: '1 0 0',
}));
ents.push(kvpEnt({
  classname: 'script_struct', origin: '19 3648 0',
  targetname: 'acc_boss_spawn', _color: '1 0 0',
}));

// --- second power switch (Vault) - stock prefab, side-tagged -----------------
ents.push(kvpEnt({
  classname: 'misc_prefab',
  angles: '0 270 0',
  model: '_prefabs/zm/zm_core/power_switch.map',
  origin: '2292 2800 1',
  script_string: 'vault',
}));

// === splice ====================================================================

// 1. replace entity 24 (box_start prefab) with the market box zbarrier; the
//    market box struct rides along right after.
const ent24 = /\{\nguid "\{ED4EC767-A036-4B7A-BD00-F7BC323B169A\}"\n"classname" "misc_prefab"\n"angles" "0 180 0"\n"model" "_prefabs\/zm\/zm_mysterybox\/box_start\.map"\n"origin" "[^"]*"\n\}/;
if (!ent24.test(map)) { console.error('entity 24 (box_start) anchor not found'); process.exit(1); }
map = map.replace(ent24, marketBox[0] + '\n// entity 24b\n' + marketBox[1]);

// 2. tag the corp power switch prefab with its side.
const corpSwitch = '"model" "_prefabs/zm/zm_core/power_switch.map"\n"origin" "790 1900 1"';
if (!map.includes(corpSwitch)) { console.error('corp power switch anchor not found'); process.exit(1); }
map = map.replace(corpSwitch, corpSwitch + '\n"script_string" "corp"');

// 3. append everything else.
if (!map.endsWith('\n')) map += '\n';
let en = 84;
for (const e of ents) {
  map += `// entity ${en}\n${e}\n`;
  en++;
}

fs.writeFileSync(mapPath, map);
console.log(`applied: market box swap + ${ents.length} new entities (84..${en - 1})`);
