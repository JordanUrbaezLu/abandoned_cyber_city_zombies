// =============================================================================
// respace_perk_alcoves_10.js  (ONE-SHOT, idempotent)
//
// Re-spreads the 9-machine Lab perk row into a 10-machine row to make room for a
// genuine 10th perk (Electric Cherry, specialty_combat_efficiency) WITHOUT moving
// off the north wall. The Lab interior is X=-761..799 (rooms.json lab_zone, inset
// 20u). The old row was 9 machines at X=-600..600 (pitch 150) with partitions at
// -675..675 — only ~86u/124u of slack to the side walls, NOT enough to tack on a
// 10th 150-pitch stall. So we SHIFT all 9 machines LEFT by 75u (user 2026-06-24:
// "push all the perks down to fit electric cherry, the lab has extra space left and
// right") and drop Electric Cherry into the freed RIGHT end at X=675. Centered on 0:
//   machines  X = -675,-525,-375,-225,-75, 75,225,375,525,675   (pitch 150)
//   partitions X = -600..600 step 150 (9; the two END partitions are DROPPED so all
//                  geometry stays >=60u off the side walls = no thin slivers = LED-safe)
//   doors      X = each machine X (10), targetname acc_perk_door_<spec>
// New machine = inline script_struct (model p6_zm_vending_electric_cherry_on,
// script_noteworthy specialty_combat_efficiency) — the real Electric Cherry vending
// model (base BO3; build-log verifies it packs, else swap the model token).
//
// This is brush geometry => FULL build WITH the LED bake is the gate (CLAUDE.md;
// memory led-bake-is-the-gate). Run tools/_bake_test.ps1 after, must print BAKED.
//
// Idempotent: refuses to re-run if specialty_combat_efficiency is already present.
// Mirrors tools/add_perk_alcoves.js winding/format verbatim (that geometry bakes).
// =============================================================================
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// Geometry constants — VERBATIM from add_perk_alcoves.js (the row that bakes).
const BACK_Y   = 4228;   // stall back = Lab north interior wall face
const MOUTH_Y  = 4154;   // stall mouth (south)
const STALL_TOP_Z = 150;
const DOOR_TOP_Z  = 140;
const PART_HALF   = 4;
const DOOR_HALF_Y = 4;
const HALF_W      = 71;

const NEW_SPEC = 'specialty_combat_efficiency';   // unused engine specialty for the real Electric Cherry
const CHERRY_MODEL = 'p6_zm_vending_electric_cherry_on';

// The 9 existing machines: how to find each entity + its old/new X. Prefabs match by
// model basename; inline structs match by script_noteworthy. New X = old X - 75.
const SHIFTS = [
  { kind: 'prefab', key: 'vending_revive_struct',                old: -600, neo: -675 },
  { kind: 'prefab', key: 'vending_juggernaut_struct',            old: -450, neo: -525 },
  { kind: 'prefab', key: 'vending_sleight_struct',               old: -300, neo: -375 },
  { kind: 'prefab', key: 'vending_doubletap_struct',             old: -150, neo: -225 },
  { kind: 'prefab', key: 'vending_marathon_struct',              old:    0, neo:  -75 },
  { kind: 'prefab', key: 'vending_additionalprimaryweapon_struct', old: 150, neo:  75 },
  { kind: 'inline', key: 'specialty_deadshot',                   old:  300, neo:  225 },
  { kind: 'inline', key: 'specialty_widowswine',                 old:  450, neo:  375 },
  { kind: 'inline', key: 'specialty_electriccherry',             old:  600, neo:  525 },  // PhD-over-cherry (nuke model)
];

// 10 doors (machine order, NEW X). specs left->right.
const DOOR_SPECS = [
  { x: -675, spec: 'specialty_quickrevive' },
  { x: -525, spec: 'specialty_armorvest' },
  { x: -375, spec: 'specialty_fastreload' },
  { x: -225, spec: 'specialty_doubletap2' },
  { x:  -75, spec: 'specialty_staminup' },
  { x:   75, spec: 'specialty_additionalprimaryweapon' },
  { x:  225, spec: 'specialty_deadshot' },
  { x:  375, spec: 'specialty_widowswine' },
  { x:  525, spec: 'specialty_electriccherry' },
  { x:  675, spec: NEW_SPEC },                       // Electric Cherry (the new 10th)
];

// 9 partitions at the boundaries BETWEEN the 10 machines (no end caps).
const PARTITION_X = [-600, -450, -300, -150, 0, 150, 300, 450, 600];

// Deterministic GUID generator — distinct tag prefix from add_perk_alcoves.js so we
// never collide with its (removed) GUIDs or any other entity.
let gc = 0;
function guid(tag) {
  gc++;
  const h = ('r10' + tag + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-AC10-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush — VERBATIM winding from add_perk_alcoves.js box().
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guid('b')}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// script_brushmodel door gate — VERBATIM from add_perk_alcoves.js doorEntity().
function doorEntity(spec, x1, x2, y1, y2, z1, z2) {
  const t = `script_wall 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    `guid "${guid('door')}"`,
    `"classname" "script_brushmodel"`,
    `"targetname" "acc_perk_door_${spec}"`,
    '// brush 0',
    '{',
    ` guid "${guid('doorb')}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
    '}',
  ].join('\n');
}

// The new Electric Cherry machine entity (inline script_struct, mirrors entity 43).
function cherryMachineEntity() {
  return [
    '// entity (acc electric cherry — real 10th perk, tools/respace_perk_alcoves_10.js)',
    '{',
    `guid "${guid('cherrymachine')}"`,
    '"classname" "script_struct"',
    '"angles" "0 359.999 0"',
    `"model" "${CHERRY_MODEL}"`,
    '"origin" "675 4195 0"',
    `"script_noteworthy" "${NEW_SPEC}"`,
    '"script_string" "zclassic_perks_start_room"',
    '"targetname" "zm_perk_machine"',
    '"_color" "0 1 1"',
    '}',
  ].join('\n');
}

let txt = fs.readFileSync(MAP, 'utf8');
const NL = txt.includes('\r\n') ? '\r\n' : '\n';
let lines = txt.split(/\r?\n/);

if (lines.some(l => l.includes(NEW_SPEC))) {
  console.error('respace_perk_alcoves_10: ' + NEW_SPEC + ' already present — refusing to re-run.');
  process.exit(0);
}

// --- helper: consume N brace-balanced { ... } blocks starting at line index `from`
// (first block must open with a line whose trimmed content STARTS with '{'). Returns
// the index of the line AFTER the Nth block's closing brace.
function consumeBlocks(idx, n) {
  let consumed = 0;
  let i = idx;
  while (consumed < n) {
    // skip blank/comment lines between blocks
    while (i < lines.length && lines[i].trim() !== '{') i++;
    if (i >= lines.length) throw new Error('ran out of lines consuming block ' + consumed);
    let depth = 0;
    do {
      const t = lines[i].trim();
      if (t === '{') depth++;
      else if (t === '}') depth--;
      i++;
    } while (depth > 0 && i < lines.length);
    consumed++;
  }
  return i;
}

// --- 1. machine origins: shift each entity's origin X (scoped to its entity block) --
function shiftMachineOrigins() {
  let changed = 0;
  for (const s of SHIFTS) {
    // find the identifying line
    let ki = -1;
    for (let i = 0; i < lines.length; i++) {
      if (s.kind === 'prefab' && lines[i] === `"model" "_prefabs/zm/zm_core/${s.key}.map"`) { ki = i; break; }
      if (s.kind === 'inline' && lines[i] === `"script_noteworthy" "${s.key}"`) { ki = i; break; }
    }
    if (ki < 0) throw new Error('machine not found: ' + s.key);
    // find the entity's brace bounds around ki
    let st = ki; while (st > 0 && lines[st] !== '{') st--;
    let en = ki; while (en < lines.length && lines[en] !== '}') en++;
    let done = false;
    for (let k = st; k <= en; k++) {
      const m = lines[k].match(/^"origin" "(-?\d+(?:\.\d+)?) 4195 (-?\d+(?:\.\d+)?)"$/);
      if (m) {
        if (parseFloat(m[1]) !== s.old) throw new Error(`origin X mismatch for ${s.key}: expected ${s.old}, got ${m[1]}`);
        lines[k] = `"origin" "${s.neo} 4195 ${m[2]}"`;
        changed++; done = true; break;
      }
    }
    if (!done) throw new Error('origin line not found for ' + s.key);
  }
  return changed;
}

// --- 2. insert the Electric Cherry machine after the PhD/cherry (specialty_electriccherry) entity --
function insertCherryMachine() {
  let ki = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i] === '"script_noteworthy" "specialty_electriccherry"') { ki = i; break; }
  }
  if (ki < 0) throw new Error('PhD cherry machine (specialty_electriccherry) not found for insertion anchor');
  let en = ki; while (en < lines.length && lines[en] !== '}') en++;   // closing brace of that entity
  lines.splice(en + 1, 0, cherryMachineEntity());
}

// --- 3. replace the partition block (comment + 10 brushes) with comment + 9 brushes --
function replacePartitions() {
  const ci = lines.findIndex(l => l.includes('ACC perk alcove partitions'));
  if (ci < 0) throw new Error('partition block comment not found');
  const end = consumeBlocks(ci + 1, 10);   // 10 old partition brushes
  const newBrushes = PARTITION_X.map(xb =>
    box(xb - PART_HALF, xb + PART_HALF, MOUTH_Y, BACK_Y, 0, STALL_TOP_Z, 'script_wall'));
  const block = ['// ACC perk alcove partitions (tools/respace_perk_alcoves_10.js — 10-machine row)', ...newBrushes];
  lines.splice(ci, end - ci, ...block);
}

// --- 4. replace the door block (comment + 9 door entities) with comment + 10 doors --
function replaceDoors() {
  const ci = lines.findIndex(l => l.includes('ACC perk alcove door gates'));
  if (ci < 0) throw new Error('door block comment not found');
  const end = consumeBlocks(ci + 1, 9);    // 9 old door entities
  const newDoors = DOOR_SPECS.map(p =>
    doorEntity(p.spec, p.x - HALF_W, p.x + HALF_W, MOUTH_Y - DOOR_HALF_Y, MOUTH_Y + DOOR_HALF_Y, 0, DOOR_TOP_Z));
  const block = ['// ACC perk alcove door gates (tools/respace_perk_alcoves_10.js) — toggled by _acc_perk_doors.gsc', ...newDoors];
  lines.splice(ci, end - ci, ...block);
}

// Apply BOTTOM-to-TOP so earlier splices don't shift later line indices:
// doors (~5572) -> machines (~3496-3583) -> partitions (~1290).
const nDoorsBefore = (txt.match(/acc_perk_door_/g) || []).length;
replaceDoors();
const nMachines = shiftMachineOrigins();
insertCherryMachine();
replacePartitions();

fs.writeFileSync(MAP, lines.join(NL));
console.log(`respace_perk_alcoves_10: machinesShifted=${nMachines} cherryMachine=1 partitions=${PARTITION_X.length} doors=${DOOR_SPECS.length} (was ${nDoorsBefore} door refs)`);
