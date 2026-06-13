#!/usr/bin/env node
// =============================================================================
// gen_zone_greybox.js - one-shot generator for the 7-zone greybox expansion
// of map_source/zm/zm_abandoned_cyber_city.map.
//
// Emits .map text fragments to stdout (sections separated by markers); the
// fragments are pasted into the .map by hand/Edit. The .map stays the
// authoritative source - this script is a scaffolding tool, NOT a build step.
// Re-running it after the .map has diverged would clobber hand edits; don't.
//
// Geometry plan (docs/03_layout.md zone graph, greybox boxes):
//   start_zone (existing arena)   x[-1056,1094.5]  y[-1073.5,928]
//   market_zone (Undercity Mkt)   x[-2481,-1281]   y[200,1600]
//   alley_zone  (Service Alley)   x[1319.5,2519.5] y[200,1600]
//   corp_zone   (Corporate Plaza) x[-781,819]      y[1148,2748]
//   vault_zone  (Server Vault)    x[1119,2319]     y[2200,3400]
//   roof_zone   (Rooftop Helipad) x[-2319,-1119]   y[2200,3400]
//   lab_zone    (Subterranean Lab)x[-781,819]      y[3048,4248]
// 8 corridors = the 8 zone-graph edges (no direct Spawn<->Corp or Corp<->Lab).
// =============================================================================

'use strict';

const WALL_TH = 20;
const WALL_H = 256;
const FLOOR_TOP = 0;
const FLOOR_BOT = -16;
const VOL_TOP = 400;

let guidCounter = 0x100;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2B9D00-ACC1-4GEN-8A3F-${c}}`.replace('4GEN', '4E0A');
}

// Six-plane axis-aligned box, plane point patterns cloned from template brush
// 18 (proven parse-clean in this map already for brushes 19-24).
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
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

const rooms = {
  market: { x1: -2481, x2: -1281, y1: 200, y2: 1600 },
  alley: { x1: 1319.5, x2: 2519.5, y1: 200, y2: 1600 },
  corp: { x1: -781, x2: 819, y1: 1148, y2: 2748 },
  vault: { x1: 1119, x2: 2319, y1: 2200, y2: 3400 },
  roof: { x1: -2319, x2: -1119, y1: 2200, y2: 3400 },
  lab: { x1: -781, x2: 819, y1: 3048, y2: 4248 },
};

// Corridors all run east-west. {x1,x2} span between the two room floor edges,
// {y1,y2} is the 256-wide opening.
const corridors = [
  { id: 'c_sp_mkt', x1: -1281, x2: -1056, y1: 400, y2: 656 },
  { id: 'c_sp_al', x1: 1094.5, x2: 1319.5, y1: 400, y2: 656 },
  { id: 'c_mkt_corp', x1: -1281, x2: -781, y1: 1200, y2: 1456 },
  { id: 'c_al_corp', x1: 819, x2: 1319.5, y1: 1200, y2: 1456 },
  { id: 'c_corp_vlt', x1: 819, x2: 1119, y1: 2300, y2: 2556 },
  { id: 'c_corp_roof', x1: -1119, x2: -781, y1: 2300, y2: 2556 },
  { id: 'c_vlt_lab', x1: 819, x2: 1119, y1: 3100, y2: 3356 },
  { id: 'c_roof_lab', x1: -1119, x2: -781, y1: 3100, y2: 3356 },
];

// Wall gaps: room -> wall side -> list of [gapY1,gapY2] (E/W walls only; all
// corridors are east-west so N/S room walls stay solid).
const gaps = {
  market: { east: [[400, 656], [1200, 1456]] },
  alley: { west: [[400, 656], [1200, 1456]] },
  corp: { west: [[1200, 1456], [2300, 2556]], east: [[1200, 1456], [2300, 2556]] },
  vault: { west: [[2300, 2556], [3100, 3356]] },
  roof: { east: [[2300, 2556], [3100, 3356]] },
  lab: { west: [[3100, 3356]], east: [[3100, 3356]] },
};

function segments(lo, hi, cuts) {
  // Split [lo,hi] removing each [a,b] in cuts. cuts assumed sorted, inside range.
  const segs = [];
  let cur = lo;
  for (const [a, b] of cuts) {
    if (a > cur) segs.push([cur, a]);
    cur = b;
  }
  if (cur < hi) segs.push([cur, hi]);
  return segs;
}

const brushes = [];

// --- room floors + walls -----------------------------------------------------
for (const [name, r] of Object.entries(rooms)) {
  brushes.push({ label: `${name} floor`, text: box(r.x1, r.x2, r.y1, r.y2, FLOOR_BOT, FLOOR_TOP, 'script_floor_ceiling') });
  // south + north walls (always solid)
  brushes.push({ label: `${name} wall S`, text: box(r.x1, r.x2, r.y1, r.y1 + WALL_TH, 0, WALL_H, 'script_wall') });
  brushes.push({ label: `${name} wall N`, text: box(r.x1, r.x2, r.y2 - WALL_TH, r.y2, 0, WALL_H, 'script_wall') });
  // west + east walls with corridor gaps
  const wallY1 = r.y1 + WALL_TH, wallY2 = r.y2 - WALL_TH;
  const g = gaps[name] || {};
  for (const [seg1, seg2] of segments(wallY1, wallY2, (g.west || []).sort((a, b) => a[0] - b[0]))) {
    brushes.push({ label: `${name} wall W seg`, text: box(r.x1, r.x1 + WALL_TH, seg1, seg2, 0, WALL_H, 'script_wall') });
  }
  for (const [seg1, seg2] of segments(wallY1, wallY2, (g.east || []).sort((a, b) => a[0] - b[0]))) {
    brushes.push({ label: `${name} wall E seg`, text: box(r.x2 - WALL_TH, r.x2, seg1, seg2, 0, WALL_H, 'script_wall') });
  }
}

// --- corridors: floor + 2 side walls ------------------------------------------
for (const c of corridors) {
  brushes.push({ label: `${c.id} floor`, text: box(c.x1, c.x2, c.y1, c.y2, FLOOR_BOT, FLOOR_TOP, 'script_floor_ceiling') });
  brushes.push({ label: `${c.id} wall S`, text: box(c.x1, c.x2, c.y1, c.y1 + WALL_TH, 0, WALL_H, 'script_wall') });
  brushes.push({ label: `${c.id} wall N`, text: box(c.x1, c.x2, c.y2 - WALL_TH, c.y2, 0, WALL_H, 'script_wall') });
}

// --- training obstacles (docs/03 per-zone notes) -------------------------------
// spawn debris pile (small loop anchor)
brushes.push({ label: 'spawn debris pile', text: box(-81, 119, -172, 28, 0, 64, 'script_wall') });
// corp fountain (big safe loop)
brushes.push({ label: 'corp fountain', text: box(-131, 169, 1798, 2098, 0, 48, 'script_wall') });
// corp S-curve (two staggered walls, south half)
brushes.push({ label: 'corp s-curve A', text: box(-481, -61, 1448, 1468, 0, 128, 'script_wall') });
brushes.push({ label: 'corp s-curve B', text: box(99, 519, 1598, 1618, 0, 128, 'script_wall') });
// market stall row (three stalls)
brushes.push({ label: 'market stall 1', text: box(-2181, -2021, 850, 950, 0, 96, 'script_wall') });
brushes.push({ label: 'market stall 2', text: box(-1961, -1801, 850, 950, 0, 96, 'script_wall') });
brushes.push({ label: 'market stall 3', text: box(-1741, -1581, 850, 950, 0, 96, 'script_wall') });
// roof central obstacle (best late train)
brushes.push({ label: 'roof obstacle', text: box(-1847, -1591, 2672, 2928, 0, 64, 'script_wall') });

// --- spawn perimeter splits (existing brushes 23/24 get corridor gaps) --------
const spawnWestLo = box(-1056, -1036, -1073.5, 400, 0, WALL_H, 'script_wall');
const spawnWestHi = box(-1056, -1036, 656, 928, 0, WALL_H, 'script_wall');
const spawnEastLo = box(1074.5, 1094.5, -1073.5, 400, 0, WALL_H, 'script_wall');
const spawnEastHi = box(1074.5, 1094.5, 656, 928, 0, WALL_H, 'script_wall');

// --- entities: zone volumes + spawner structs ----------------------------------
const zoneOf = {
  market: 'market_zone', alley: 'alley_zone', corp: 'corp_zone',
  vault: 'vault_zone', roof: 'roof_zone', lab: 'lab_zone',
};

// half-corridor volume coverage: corridor id -> [westZone, eastZone]
const corridorZones = {
  c_sp_mkt: ['market_zone', 'start_zone'],
  c_sp_al: ['start_zone', 'alley_zone'],
  c_mkt_corp: ['market_zone', 'corp_zone'],
  c_al_corp: ['corp_zone', 'alley_zone'],
  c_corp_vlt: ['corp_zone', 'vault_zone'],
  c_corp_roof: ['roof_zone', 'corp_zone'],
  c_vlt_lab: ['lab_zone', 'vault_zone'],
  c_roof_lab: ['roof_zone', 'lab_zone'],
};

function volumeBrush(x1, x2, y1, y2) {
  const t = 'volume 64 64 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0';
  return [
    '{',
    ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${FLOOR_BOT} ) ( 86.5 459.5 ${FLOOR_BOT} ) ( 86.5 419.5 ${FLOOR_BOT} ) ${t}`,
    ` ( 94.5 419.5 ${VOL_TOP} ) ( 94.5 459.5 ${VOL_TOP} ) ( 142.5 459.5 ${VOL_TOP} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

const entities = [];

for (const [name, r] of Object.entries(rooms)) {
  const zone = zoneOf[name];
  // volume = room box + half of each adjacent corridor
  const volBrushes = [volumeBrush(r.x1, r.x2, r.y1, r.y2)];
  for (const c of corridors) {
    const [westZone, eastZone] = corridorZones[c.id];
    const mid = (c.x1 + c.x2) / 2;
    if (westZone === zone) volBrushes.push(volumeBrush(c.x1, mid, c.y1, c.y2));
    if (eastZone === zone) volBrushes.push(volumeBrush(mid, c.x2, c.y1, c.y2));
  }
  entities.push({
    label: `${zone} info_volume`,
    text: [
      '{',
      `guid "${guid()}"`,
      '"classname" "info_volume"',
      '"script_noteworthy" "player_volume"',
      `"target" "${zone}_spawners"`,
      `"targetname" "${zone}"`,
      ...volBrushes.flatMap((b, i) => [`// brush ${i}`, b]),
      '}',
    ].join('\n'),
  });

  // 4 riser spawners at quarter points + 1 dog location at center
  const qx = [r.x1 + (r.x2 - r.x1) * 0.25, r.x1 + (r.x2 - r.x1) * 0.75];
  const qy = [r.y1 + (r.y2 - r.y1) * 0.25, r.y1 + (r.y2 - r.y1) * 0.75];
  let n = 0;
  for (const sx of qx) {
    for (const sy of qy) {
      n++;
      entities.push({
        label: `${zone} riser ${n}`,
        text: [
          '{',
          `guid "${guid()}"`,
          '"classname" "script_struct"',
          '"angles" "0 270 0"',
          `"origin" "${sx} ${sy} 0"`,
          '"script_noteworthy" "riser_location"',
          '"script_string" "find_flesh"',
          `"targetname" "${zone}_spawners"`,
          '"_color" "1 0 0"',
          '}',
        ].join('\n'),
      });
    }
  }
  entities.push({
    label: `${zone} dog location`,
    text: [
      '{',
      `guid "${guid()}"`,
      '"classname" "script_struct"',
      `"origin" "${(r.x1 + r.x2) / 2} ${(r.y1 + r.y2) / 2} 0"`,
      '"script_noteworthy" "dog_location"',
      `"targetname" "${zone}_spawners"`,
      '"_color" "1 0 0"',
      '}',
    ].join('\n'),
  });
}

// also add 2 extra risers in the existing start_zone arena's new reachable
// area? No - start_zone already has template spawners. Skip.

// --- output -------------------------------------------------------------------
const out = [];
out.push('===== SECTION 1: replacement for existing brush 23 (spawn west perimeter, split for corridor) =====');
out.push(spawnWestLo);
out.push('// brush 29');
out.push(spawnWestHi);
out.push('===== SECTION 2: replacement for existing brush 24 (spawn east perimeter, split for corridor) =====');
out.push(spawnEastLo);
out.push('// brush 30');
out.push(spawnEastHi);
out.push('===== SECTION 3: new worldspawn brushes (insert before worldspawn closing brace) =====');
let bn = 31;
const manifest = [];
for (const b of brushes) {
  manifest.push(`brush ${bn} = ${b.label}`);
  out.push(`// brush ${bn}`);
  out.push(b.text);
  bn++;
}
out.push('===== SECTION 4: new entities (append at end of file) =====');
let en = 48;
for (const e of entities) {
  manifest.push(`entity ${en} = ${e.label}`);
  out.push(`// entity ${en}`);
  out.push(e.text);
  en++;
}
out.push('===== MANIFEST =====');
out.push(manifest.join('\n'));
console.log(out.join('\n'));
