// =============================================================================
// fix_box_positions.js  (re-runnable)
//
// Repositions all 7 mystery-box nodes so each sits FLUSH against a room wall
// (~30u off the interior face so the box model clears, not clipping INTO the
// wall) and faces into the room. Moves the matching collision clip brushmodel
// (acc_box_clip_<node>) with it. Fixes: start/vault/lab were clipping walls;
// market/alley/corp/roof were floating / not against a wall.
//
// For each node it updates: the zbarrier_zmcore_MagicBox (origin+angles), the
// treasure_chest_use struct (origin+angles), and regenerates the clip brush at
// the new origin. Geometry/entity change => FULL build.
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// new origin [x,y,z] + yaw (faces into room: N wall->270/south, E wall->180/west,
// W wall->0/east). z kept at 13.75 (box float height).
// 2026-06-17: moved to CLEAR, OPEN floor in each zone (the old "30u off the wall
// face" positions clipped INTO walls, which also buried the collision clip so the
// box read as walk-through). Centre-ish of each zone interior, kept clear of the
// corp trench, the lab PaP/boss/perk-gallery, and the plaza spawn cluster. yaw 0.
const NODES = {
  market: { org: [-1616, 928,  13.75], yaw: 0 },   // market centre
  alley:  { org: [1654.5, 928, 13.75], yaw: 0 },   // alley centre
  corp:   { org: [19, 1400,    13.75], yaw: 0 },    // bus station, south of the trench
  vault:  { org: [1431.5, 2830,13.75], yaw: 0 },    // vault centre
  roof:   { org: [-1431.5, 2830,13.75],yaw: 0 },    // helipad centre
  start:  { org: [19, 350,     13.75], yaw: 0 },    // plaza, north of the spawn cluster
  lab:    { org: [19, 3300,    13.75], yaw: 0 },    // lab, south of PaP/boss/gallery
};

let gc = 0;
function guid() {
  gc++;
  const h = ('boxpos' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  return `{ACCBXPOS-${h.toString(16).toUpperCase().padStart(8, '0').slice(0, 4)}-4E10-8A3F-${String(gc).padStart(12, '0')}}`;
}
function clipBrush(ox, oy) {
  const t = 'clip 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  const [x1, x2, y1, y2, z1, z2] = [ox - 30, ox + 30, oy - 30, oy + 30, 0, 48];
  return [
    '// brush 0', '{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ];
}

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);

// parse top-level entities -> {open, close, kv:{key:lineIdx}, brushOpen, brushClose}
function entities() {
  const ents = [];
  let depth = 0, cur = null, brush = null;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') { depth++; if (depth === 1) cur = { open: i, kv: {}, brushOpen: -1, brushClose: -1 }; else if (depth === 2 && cur && cur.brushOpen < 0) cur.brushOpen = i; continue; }
    if (t === '}') { if (depth === 2 && cur) cur.brushClose = i; else if (depth === 1 && cur) { cur.close = i; ents.push(cur); cur = null; } depth--; continue; }
    if (depth === 1 && cur) { const m = t.match(/^"([^"]+)" "([^"]*)"$/); if (m) cur.kv[m[1]] = { val: m[2], line: i }; }
  }
  return ents;
}

function setKV(ent, key, value) {
  if (ent.kv[key]) { lines[ent.kv[key].line] = `"${key}" "${value}"`; return true; }
  // insert after the guid line (open+1)
  lines.splice(ent.open + 2, 0, `"${key}" "${value}"`);
  return false;
}

// Apply per node. Do it in passes re-parsing each time (line indices shift on insert).
let moved = 0, clipsMoved = 0;
for (const [node, cfg] of Object.entries(NODES)) {
  const [x, y, z] = cfg.org;
  const ang = `0 ${cfg.yaw} 0`;
  const originStr = `${x} ${y} ${z}`;

  // zbarrier + struct (share script_noteworthy acc_box_<node>_zbarrier / acc_box_<node>)
  for (const nw of [`acc_box_${node}_zbarrier`, `acc_box_${node}`]) {
    const e = entities().find(en => en.kv['script_noteworthy'] && en.kv['script_noteworthy'].val === nw
      && !(en.kv['targetname'] && en.kv['targetname'].val.startsWith('acc_box_clip_')));
    if (!e) { console.error('missing entity', nw); continue; }
    setKV(e, 'origin', originStr);
    setKV(e, 'angles', ang);
    moved++;
  }

  // clip brushmodel: rewrite its brush at the new origin
  const c = entities().find(en => en.kv['targetname'] && en.kv['targetname'].val === `acc_box_clip_${node}`);
  if (!c || c.brushOpen < 0 || c.brushClose < 0) { console.error('missing clip', node); continue; }
  // replace the brush block. The brush is preceded by a "// brush 0" comment line.
  let bStart = c.brushOpen;
  if (lines[bStart - 1].trim().startsWith('// brush')) bStart -= 1;
  const newBrush = clipBrush(x, y);
  lines.splice(bStart, c.brushClose - bStart + 1, ...newBrush);
  clipsMoved++;
}

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`fix_box_positions: entities(origin+angles)=${moved} clipsMoved=${clipsMoved}`);
