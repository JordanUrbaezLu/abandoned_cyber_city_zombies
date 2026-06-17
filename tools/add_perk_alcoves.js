// =============================================================================
// add_perk_alcoves.js  (ONE-SHOT, idempotent)
//
// Reworks the Lab perk row into 9 door-gated alcoves so _acc_perk_doors.gsc can
// open a random 3 per round. The 9 perk machines already exist in the .map
// (6 misc_prefab vending_*_struct + 3 inline zm_perk_machine), lined up against
// the Lab north wall at Y=4195, X = -600..600 (step 150). This tool:
//   1. Builds 10 thin partition walls (worldspawn) at the X boundaries between
//      machines (x = -675..675 step 150) -> each machine sits in its own stall.
//   2. Builds 9 door gates (script_brushmodel, targetname acc_perk_door_<spec>)
//      across each stall mouth (south face). _acc_perk_doors toggles these
//      hide/notsolid (open) vs show/solid/disconnectpaths (closed) per round.
//   3. Reorients all 9 machines to face SOUTH (yaw 270) so they face the stall
//      mouth / approaching player (correct for a north-wall perk row).
// Open-top stalls (no ceiling cap) => no enclosed volume => LED-safe; partitions
// sit INSIDE the sealed Lab so they cannot leak the BSP hull. Geometry change =>
// FULL build (cod2map + navmesh + linker; -SkipLED per this map's convention).
//
// Idempotent: refuses to re-run if any "acc_perk_door_" already exists.
// =============================================================================
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// Lab geometry (source_data/rooms.json: lab_zone outer Y2=4248, 20u wall -> interior face 4228).
const BACK_Y   = 4228;   // stall back = Lab north interior wall face
const MOUTH_Y  = 4154;   // stall mouth (south, opens into the room)
const STALL_TOP_Z = 150; // partition height
const DOOR_TOP_Z  = 140; // door gate height
const PART_HALF   = 4;   // partition half-thickness (8u walls)
const DOOR_HALF_Y = 4;   // door slab half-thickness (8u)
const HALF_W      = 71;  // stall interior half-width (machine pitch 150, walls at +-75)

// The 9 perks in machine order (X = -600..600), with the door targetname specialty.
const PERKS = [
  { x: -600, spec: 'specialty_quickrevive',              kind: 'prefab', model: 'vending_revive_struct' },
  { x: -450, spec: 'specialty_armorvest',                kind: 'prefab', model: 'vending_juggernaut_struct' },
  { x: -300, spec: 'specialty_fastreload',               kind: 'prefab', model: 'vending_sleight_struct' },
  { x: -150, spec: 'specialty_doubletap2',               kind: 'prefab', model: 'vending_doubletap_struct' },
  { x:    0, spec: 'specialty_staminup',                 kind: 'prefab', model: 'vending_marathon_struct' },
  { x:  150, spec: 'specialty_additionalprimaryweapon',  kind: 'prefab', model: 'vending_additionalprimaryweapon_struct' },
  { x:  300, spec: 'specialty_deadshot',                 kind: 'machine' },
  { x:  450, spec: 'specialty_widowswine',               kind: 'machine' },
  { x:  600, spec: 'specialty_electriccherry',           kind: 'machine' },
];

// Deterministic GUID generator (counter-based, so re-runs of OTHER tools don't collide).
let gc = 0;
function guid(tag) {
  gc++;
  const h = (tag + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACC4-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush — VERBATIM winding from tools/gen_zone_greybox.js box().
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

// A script_brushmodel door gate (single box brush), matching the acc_door_* format.
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

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
if (lines.some(l => l.includes('acc_perk_door_'))) {
  console.error('add_perk_alcoves: acc_perk_door_ already present — refusing to re-run.');
  process.exit(0);
}

// --- 1. reorient the 9 machines to face south (yaw 270) -----------------------
// Walk entities; an entity is a perk machine if it has the matching model (prefab)
// or script_noteworthy (inline). Set/insert angles "0 270 0".
function setSouthFacing() {
  // Collect matches first, then apply bottom-to-top so splices don't shift indices.
  const hits = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^"model" "_prefabs\/zm\/zm_core\/(vending_[a-z_]+)\.map"$/);
    const isInline = lines[i] === '"targetname" "zm_perk_machine"';
    let isPerk = false;
    if (m && PERKS.some(p => p.model === m[1])) isPerk = true;
    if (isInline) isPerk = true;
    if (!isPerk) continue;
    let s = i; while (s > 0 && lines[s] !== '{') s--;
    let e = i; while (e < lines.length && lines[e] !== '}') e++;
    let aIdx = -1;
    for (let k = s; k <= e; k++) if (/^"angles" "/.test(lines[k])) { aIdx = k; break; }
    hits.push({ s, aIdx });
  }
  let changed = 0;
  hits.sort((a, b) => b.s - a.s); // bottom-to-top
  for (const h of hits) {
    if (h.aIdx >= 0) {
      if (lines[h.aIdx] !== '"angles" "0 270 0"') { lines[h.aIdx] = '"angles" "0 270 0"'; changed++; }
    } else {
      lines.splice(h.s + 2, 0, '"angles" "0 270 0"'); // after opening brace + guid line
      changed++;
    }
  }
  return changed;
}
const reoriented = setSouthFacing();

// --- 2. partitions (worldspawn) ----------------------------------------------
const partitions = [];
for (let xb = -675; xb <= 675; xb += 150) {
  partitions.push(box(xb - PART_HALF, xb + PART_HALF, MOUTH_Y, BACK_Y, 0, STALL_TOP_Z, 'script_wall'));
}

// Insert partitions before the worldspawn closing brace (first time depth returns to 0).
function worldspawnCloseIdx() {
  let depth = 0;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') depth++;
    else if (t === '}') { depth--; if (depth === 0) return i; }
  }
  return -1;
}
const wclose = worldspawnCloseIdx();
if (wclose < 0) { console.error('could not find worldspawn close brace'); process.exit(1); }
const partBlock = ['// ACC perk alcove partitions (tools/add_perk_alcoves.js)', ...partitions];
lines.splice(wclose, 0, ...partBlock);

// --- 3. door gates (new entities, appended at EOF) ---------------------------
const doorBlock = ['// ACC perk alcove door gates (tools/add_perk_alcoves.js) — toggled by _acc_perk_doors.gsc'];
for (const p of PERKS) {
  doorBlock.push(doorEntity(p.spec, p.x - HALF_W, p.x + HALF_W, MOUTH_Y - DOOR_HALF_Y, MOUTH_Y + DOOR_HALF_Y, 0, DOOR_TOP_Z));
}
// drop trailing empty line if present, then append, keep a trailing newline
while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...doorBlock, '');

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`add_perk_alcoves: partitions=${partitions.length} doors=${PERKS.length} machinesReoriented=${reoriented}`);
