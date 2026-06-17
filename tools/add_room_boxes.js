// =============================================================================
// add_room_boxes.js  (ONE-SHOT, idempotent)
//
// Mystery box = ONE moving box with a spawn node in EVERY room (user 2026-06-16).
// The map already had 3 nodes (market / corp=Bus Station / roof=Helipad). This
// tool adds the 4 missing rooms (start=Plaza, alley, vault, lab) as full box
// nodes (zbarrier_zmcore_MagicBox + treasure_chest_use struct, mirroring market),
// each tucked against a room wall. _acc_map_randomizer::roll_mystery_box_initial
// now rolls all 7; the stock teddy-bear move walks the single box among them.
//
// COLLISION FIX (walk-through box): the MagicBox model has no player clip, so
// this tool also drops one invisible `clip` script_brushmodel per node
// (acc_box_clip_<node>) at the box origin. _acc_map_randomizer::manage_box_collision
// keeps ONLY the active node's clip solid (others notsolid) so there are no
// phantom invisible blocks in the 6 rooms the box isn't currently in.
//
// Geometry/entity change => FULL build (cod2map + navmesh + linker; -SkipLED).
// Idempotent: refuses to re-run if any "acc_box_clip_" already exists.
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// New box nodes (origin tucked against a room wall, z=13.75 to match existing,
// angle faces into the room). start=Plaza, lab against west wall.
const NEW_NODES = [
  { node: 'start', org: [-300, 700, 13.75],  ang: 270 },  // Plaza, north wall
  { node: 'alley', org: [1654, 1340, 13.75], ang: 270 },  // mirror of market
  { node: 'vault', org: [1714, 2600, 13.75], ang: 180 },  // east wall
  { node: 'lab',   org: [-751, 3400, 13.75], ang: 0   },  // west wall
];

let gc = 0;
function guid() {
  gc++;
  const h = ('box' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACC5-4E0E-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush (VERBATIM winding from gen_zone_greybox.js box()).
function brush(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

// A MagicBox node = zbarrier (visual) + treasure_chest_use struct (use/location).
function magicBox(node, ox, oy, oz, ang) {
  return [
    '{',
    `guid "${guid()}"`,
    `"classname" "zbarrier_zmcore_MagicBox"`,
    `"angles" "0 ${ang} 0"`,
    `"barrieranimtime" "0"`,
    `"origin" "${ox} ${oy} ${oz}"`,
    `"script_noteworthy" "acc_box_${node}_zbarrier"`,
    `"showalternatemodel" "0"`,
    `"showupgradedmodel" "0"`,
    `"type" "zmcore_MagicBox"`,
    `"zbarrierboardanim1" "o_zombie_magic_box_fake_idle_twitch_a"`,
    `"zbarrierboardanim2" "o_zombie_magic_box_leave"`,
    `"zbarrierboardanim3" "o_zombie_magic_box_close"`,
    `"zbarrierboardanim4" "o_zombie_magic_box_teddy_rise"`,
    `"zbarrierboardanim5" "o_zombie_magic_box_teddy_rise"`,
    `"zbarrierboardmodel1" "p6_anim_zm_magic_box_fake"`,
    `"zbarrierboardmodel2" "p6_anim_zm_magic_box"`,
    `"zbarrierboardmodel3" "p6_anim_zm_magic_box"`,
    `"zbarrierboardmodel4" "tag_origin"`,
    `"zbarrierboardmodel5" "tag_origin"`,
    `"zbarriernumboards" "5"`,
    `"zbarriertearanim1" "o_zombie_magic_box_fake_idle_twitch_b"`,
    `"zbarriertearanim2" "o_zombie_magic_box_arrive"`,
    `"zbarriertearanim3" "o_zombie_magic_box_open"`,
    `"zbarriertearanim4" "o_zombie_magic_box_weapon_rise"`,
    `"zbarriertearanim5" "o_zombie_magic_box_weapon_dual_rise"`,
    '}',
    '{',
    `guid "${guid()}"`,
    `"classname" "script_struct"`,
    `"angles" "0 ${ang} 0"`,
    `"origin" "${ox} ${oy} ${oz}"`,
    `"script_noteworthy" "acc_box_${node}"`,
    `"targetname" "treasure_chest_use"`,
    `"zombie_cost" "950"`,
    `"_color" "1 0 0"`,
    '}',
  ].join('\n');
}

// Invisible collision clip at a box node (toggled solid by manage_box_collision).
function clipModel(node, ox, oy) {
  return [
    '{',
    `guid "${guid()}"`,
    `"classname" "script_brushmodel"`,
    `"targetname" "acc_box_clip_${node}"`,
    '// brush 0',
    brush(ox - 30, ox + 30, oy - 30, oy + 30, 0, 48, 'clip'),
    '}',
  ].join('\n');
}

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
if (lines.some(l => l.includes('acc_box_clip_'))) {
  console.error('add_room_boxes: acc_box_clip_ already present — refusing to re-run.');
  process.exit(0);
}

// Parse existing treasure_chest_use structs to collect ALL box origins (for clips).
const allNodes = []; // {node, ox, oy}
for (let i = 0; i < lines.length; i++) {
  const nw = lines[i].match(/^"script_noteworthy" "acc_box_([a-z]+)"$/);
  if (!nw) continue;
  // confirm this entity is the treasure_chest_use struct (not the _zbarrier)
  let s = i; while (s > 0 && lines[s] !== '{') s--;
  let e = i; while (e < lines.length && lines[e] !== '}') e++;
  const isChest = lines.slice(s, e).some(l => l === '"targetname" "treasure_chest_use"');
  if (!isChest) continue;
  const ol = lines.slice(s, e).find(l => /^"origin" "/.test(l));
  const m = ol && ol.match(/^"origin" "(-?[\d.]+) (-?[\d.]+) (-?[\d.]+)"$/);
  if (m) allNodes.push({ node: nw[1], ox: parseFloat(m[1]), oy: parseFloat(m[2]) });
}

// Build the new node entities + ALL clips (existing parsed + new).
const out = ['// ACC per-room mystery box nodes + collision clips (tools/add_room_boxes.js)'];
for (const n of NEW_NODES) {
  out.push(magicBox(n.node, n.org[0], n.org[1], n.org[2], n.ang));
  allNodes.push({ node: n.node, ox: n.org[0], oy: n.org[1] });
}
for (const n of allNodes) {
  out.push(clipModel(n.node, n.ox, n.oy));
}

while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...out, '');
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`add_room_boxes: newNodes=${NEW_NODES.length} clips=${allNodes.length} (nodes: ${allNodes.map(n => n.node).join(',')})`);
