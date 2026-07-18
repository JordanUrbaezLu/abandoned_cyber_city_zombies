// =============================================================================
// align_box_clips.js  (re-runnable, idempotent)
//
// Snaps every mystery-box collision clip to its box's ACTUAL current origin
// (user 2026-06-26). Unlike place_boxes_against_walls.js it does NOT move the
// boxes - it READS where each acc_box_<node> (treasure_chest_use) struct is in
// the .map RIGHT NOW and (re)builds acc_box_clip_<node> centered on it. So after
// you drag a box anywhere in Radiant, re-run this and the invisible collision
// follows - no more "box at the back, clip in the middle".
//
// The clip is a `clip` script_brushmodel (blocks player + AI) shaped like the actual
// long wooden box, NOT a square: footprint VERIFIED against Treyarch's own box clip in
// _prefabs/zm/zm_core/buyable_magic_box_start.map = 101 long x 34 deep (local X x Y at
// yaw 0). The long axis rotates with each box's yaw (0/180 -> long along X; 90/270 ->
// long along Y), so the clip lies the same way the box model does at every node.
//
// script_brushmodel is LED-exempt, but it's still an entity/geometry change =>
// FULL build (cod2map navmesh + LED + linker). Removes any prior acc_box_clip_*.
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

let gc = 0;
function guid() {
  gc++;
  const h = ('aligncl' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACBC-4E12-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Box-shaped clip centered on (ox,oy), oriented by yaw. VERBATIM winding from place_boxes_against_walls.js.
// oz = the struct's floor z (2026-07-12: no longer hardcoded 0 - the trench chest sits at z=-240).
function clipModel(node, ox, oy, yaw, oz) {
  const t = 'clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  // Magic-box footprint (stock buyable_magic_box_start.map clip: 101 long x 34 deep) + a little margin.
  const HALF_LONG = 52, HALF_SHORT = 19;       // 104 x 38
  const y = ((Math.round(yaw) % 360) + 360) % 360;
  const longX = (y === 0 || y === 180);        // 0/180 -> long axis on X; 90/270 -> long axis on Y
  const hx = longX ? HALF_LONG : HALF_SHORT;
  const hy = longX ? HALF_SHORT : HALF_LONG;
  const [x1, x2, y1, y2, z1, z2] = [ox - hx, ox + hx, oy - hy, oy + hy, oz, oz + 64];
  return [
    '{',
    `guid "${guid()}"`,
    `"classname" "script_brushmodel"`,
    `"targetname" "acc_box_clip_${node}"`,
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
    '}',
  ].join('\n');
}

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

function entities() {
  const ents = [];
  let depth = 0, cur = null;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { depth++; if (depth === 1) cur = { open: i, kv: {} }; continue; }
    if (t === '}') { if (depth === 1 && cur) { cur.close = i; ents.push(cur); cur = null; } depth--; continue; }
    if (depth === 1 && cur) { const m = t.match(/^"([^"]+)" "([^"]*)"$/); if (m) cur.kv[m[1]] = m[2]; }
  }
  return ents;
}

// 1. read every box's CURRENT origin + yaw from its treasure_chest_use struct --
const boxes = {}; // node -> [x,y,yaw,z]
for (const e of entities()) {
  const nw = e.kv['script_noteworthy'];
  if (!nw || !/^acc_box_[a-z]+$/.test(nw)) continue;
  if (e.kv['targetname'] !== 'treasure_chest_use') continue;
  const m = e.kv['origin'] && e.kv['origin'].match(/^(-?[\d.]+) (-?[\d.]+) (-?[\d.]+)$/);
  if (!m) continue;
  const yaw = e.kv['angles'] ? parseFloat(e.kv['angles'].split(' ')[1] || '0') : 0;
  boxes[nw.replace('acc_box_', '')] = [parseFloat(m[1]), parseFloat(m[2]), yaw, parseFloat(m[3])];
}
const nodes = Object.keys(boxes);
if (!nodes.length) { console.error('align_box_clips: NO acc_box_* structs found - aborting.'); process.exit(1); }

// 2. remove any existing acc_box_clip_* entities (idempotent) ------------------
let removed = 0;
for (;;) {
  const c = entities().find(en => en.kv['targetname'] && en.kv['targetname'].startsWith('acc_box_clip_'));
  if (!c) break;
  lines.splice(c.open, c.close - c.open + 1);
  removed++;
}

// 3. append fresh clips centered on each box's real origin ---------------------
while (lines.length && lines[lines.length - 1] === '') lines.pop();
const out = ['// ACC mystery-box clips, snapped to live box origins + box-shaped (tools/align_box_clips.js)'];
for (const n of nodes) out.push(clipModel(n, boxes[n][0], boxes[n][1], boxes[n][2], boxes[n][3]));
lines.push(...out, '');

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`align_box_clips: clipsRemoved=${removed} clipsAdded=${nodes.length}`);
for (const n of nodes) {
  const y = ((Math.round(boxes[n][2]) % 360) + 360) % 360;
  const o = (y === 0 || y === 180) ? 'long-X (104x38)' : 'long-Y (38x104)';
  console.log(`  ${n.padEnd(8)} clip @ (${boxes[n][0]}, ${boxes[n][1]}, z${boxes[n][3]}) yaw ${y} -> ${o}`);
}
