// =============================================================================
// place_boxes_against_walls.js  (re-runnable, idempotent)
//
// Fixes the "walk through every Mystery Box" + "boxes float in the open" report
// (user 2026-06-26). Two things, for all 6 box nodes (market/corp/roof/plaza/lab/vault):
//
//   1. REPOSITION each box (zbarrier + treasure_chest_use struct) flush against a
//      SOLID interior wall face (~40u off so the model clears the 20u wall), facing
//      into the room. Walls chosen clear of door gaps, spawns, wallbuys, machines,
//      PaP, boss spawn, the Vault Overload point, and the corp trench/power switch
//      (feature map: tools dump 2026-06-26; room bounds source_data/rooms.json).
//
//   2. AUTHOR a collision clip (script_brushmodel `acc_box_clip_<node>`, 60x60x48,
//      `clip` material = blocks player + AI) at each box. The MagicBox xmodel has NO
//      player clip, so without this you walk straight through. Every node ALWAYS shows
//      a box model (the real moving box, or the idle "fake" box when it's elsewhere),
//      so EVERY node gets a permanent solid clip - _acc_map_randomizer::manage_box_collision
//      keeps them all solid (no per-node toggling).
//
// script_brushmodel is LED-exempt (memory brushmodel-wall-led-exempt) so the clips
// don't affect the lightmap bake, but they DO need cod2map (navmesh) -> FULL build.
// Re-runnable: removes any existing acc_box_clip_* before re-adding.
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// Against-wall target per node: origin [x,y,z=13.75 box float] + yaw (faces INTO room:
// W wall->0/east, E wall->180/west, N wall->270/south, S wall->90/north).
const NODES = {
  plaza:  { org: [173, 250, 13.75],   yaw: 180 },  // east wall; clear of spawns(S)/grenade wallbuy(N)/corner connectors
  market: { org: [-1891, 928, 13.75], yaw: 0   },  // west wall; east wall has the 2 door gaps
  corp:   { org: [400, 2708, 13.75],  yaw: 270 },  // north wall (north half); clear of trench, wallbuys(S), NW power switch, E/W doors
  roof:   { org: [-1684, 2830, 13.75],yaw: 0   },  // west wall; east wall has door gaps
  vault:  { org: [1684, 2830, 13.75], yaw: 180 },  // east wall; clear of Overload point + west doors
  lab:    { org: [759, 3650, 13.75],  yaw: 180 },  // east wall; clear of PaP(W)/perks(N)/wallbuy(S)/boss spawn + east door gap y3100-3356
};

let gc = 0;
function guid() {
  gc++;
  const h = ('boxwall' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ACCB-4E11-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned clip box (VERBATIM winding from tools/fix_box_positions.js clipBrush()).
// Sized to FULLY envelope BOTH the live box AND the idle "fake"/teddy model it shows when the box is
// elsewhere (same zbarrier entity, same origin) - generous so an offset model origin can't leave an
// exposed edge: 80x80 footprint x 80u tall (user 2026-06-26). Square, so box facing/yaw doesn't matter.
function clipModel(node, ox, oy) {
  const t = 'clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  const [x1, x2, y1, y2, z1, z2] = [ox - 40, ox + 40, oy - 40, oy + 40, 0, 80];
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

// --- parse top-level entities -> {open, close, kv:{key:{val,line}}} -----------
function entities() {
  const ents = [];
  let depth = 0, cur = null;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { depth++; if (depth === 1) cur = { open: i, kv: {} }; continue; }
    if (t === '}') { if (depth === 1 && cur) { cur.close = i; ents.push(cur); cur = null; } depth--; continue; }
    if (depth === 1 && cur) { const m = t.match(/^"([^"]+)" "([^"]*)"$/); if (m) cur.kv[m[1]] = { val: m[2], line: i }; }
  }
  return ents;
}
function setKV(ent, key, value) {
  if (ent.kv[key]) { lines[ent.kv[key].line] = `"${key}" "${value}"`; return; }
  lines.splice(ent.open + 2, 0, `"${key}" "${value}"`); // after guid line
}

// --- 1. reposition zbarrier + struct for each node (re-parse each pass) --------
let moved = 0;
for (const [node, cfg] of Object.entries(NODES)) {
  const [x, y, z] = cfg.org;
  const originStr = `${x} ${y} ${z}`;
  const ang = `0 ${cfg.yaw} 0`;
  for (const nw of [`acc_box_${node}_zbarrier`, `acc_box_${node}`]) {
    const e = entities().find(en => en.kv['script_noteworthy'] && en.kv['script_noteworthy'].val === nw);
    if (!e) { console.error('MISSING entity', nw); continue; }
    setKV(e, 'origin', originStr);
    setKV(e, 'angles', ang);
    moved++;
  }
}

// --- 2. remove any existing acc_box_clip_* entities (idempotent) --------------
let removed = 0;
for (;;) {
  const c = entities().find(en => en.kv['targetname'] && en.kv['targetname'].val.startsWith('acc_box_clip_'));
  if (!c) break;
  lines.splice(c.open, c.close - c.open + 1);
  removed++;
}

// --- 3. append fresh clips at the new positions -------------------------------
while (lines.length && lines[lines.length - 1] === '') lines.pop();
const out = ['// ACC mystery-box collision clips, against-wall (tools/place_boxes_against_walls.js)'];
for (const [node, cfg] of Object.entries(NODES)) out.push(clipModel(node, cfg.org[0], cfg.org[1]));
lines.push(...out, '');

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`place_boxes_against_walls: repositioned=${moved} entities, clipsRemoved=${removed}, clipsAdded=${Object.keys(NODES).length} (${Object.keys(NODES).join(',')})`);
