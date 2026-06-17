#!/usr/bin/env node
// =============================================================================
// fix_led_safe_geometry.js - rewrite the 4 LED-crash brush groups (seals, perk
// flank walls, mystery-box collision clips) into LED-SAFE form so the Radiant
// lightmapper (brush.cpp:1860 SANITY CHECK FAILURE) bakes the full map clean.
//
// Root cause (bisected 2026-06-16, docs/40): these recent generator brushes used
//  (a) FILLER-coordinate winding (134.5/459.5 placeholder points) - the seal
//      generator itself warns this crashes LED for large/far brushes; and/or
//  (b) thin SLIVER gaps / coplanar just-touching faces against neighbour walls
//      (8u seal insets, z250-vs-z256, clip faces flush on the wall interior face).
// Fix = REAL-corner winding (planes() below, from add_lockdown_seals.js) + extend
// each brush to PENETRATE its neighbour wall ~10u (deep CSG merge, no boundary
// sliver). Verified neighbour faces: lab W wall interior x-761 (wall -781..-761),
// lab E wall interior x799 (799..819), vault W wall 1119..1139, vault E wall
// 1724..1744, seal corridors c_corp_vlt y[2300,2556] / c_vlt_lab y[3100,3356].
//
// The vault ceiling (ACCVCEIL) is already embedded 10u into the walls (real-corner)
// so it is left as-is. RE-RUNNABLE: each brush is matched by guid + rewritten.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

// Real-corner winding (cross(P2-P1,P3-P1) points INTO solid) - LED-safe.
function planes(box, mat) {
  const t = `${mat} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  const [x1, x2, y1, y2, z1, z2] = box;
  const p = (x, y, z) => `( ${x} ${y} ${z} )`;
  return [
    ` ${p(x2, y2, z1)} ${p(x1, y2, z1)} ${p(x1, y1, z1)} ${t}`, // bottom
    ` ${p(x1, y1, z2)} ${p(x1, y2, z2)} ${p(x2, y2, z2)} ${t}`, // top
    ` ${p(x1, y1, z2)} ${p(x2, y1, z2)} ${p(x2, y1, z1)} ${t}`, // y1
    ` ${p(x2, y1, z2)} ${p(x2, y2, z2)} ${p(x2, y2, z1)} ${t}`, // x2
    ` ${p(x2, y2, z2)} ${p(x1, y2, z2)} ${p(x1, y2, z1)} ${t}`, // y2
    ` ${p(x1, y2, z2)} ${p(x1, y1, z2)} ${p(x1, y1, z1)} ${t}`, // x1
  ];
}

// guid-substring -> { box:[x1,x2,y1,y2,z1,z2], mat }. box clips penetrate their
// wall side 10u (offset 40 on the wall side, 30 elsewhere). z clip = [0,48].
const TARGETS = [
  // lockdown seals: penetrate vault W wall (x->1129) + both corridor side walls (y +/-10 past opening)
  { key: 'ACCSLVA1', box: [1095, 1129, 2290, 2566, 0, 250], mat: 'script_wall' },
  { key: 'ACCSLVB1', box: [1095, 1129, 3090, 3366, 0, 250], mat: 'script_wall' },
  // perk gallery flank walls: ABUT exactly - lab wall face on the outer side, the
  // adjacent partition face on the inner side, NO overlap (the original overshot 4u
  // INTO partition P1/P10 = sliver fragment). z250 NOT z256 (a top coplanar with the
  // z256 wall tops crashes LED, docs/36). P1 west face x-679; P10 east face x679.
  { key: 'ACCPFLANK-FDA6-4E0F-8A3F-000000000001', box: [-761, -679, 4154, 4228, 0, 250], mat: 'script_wall' },
  { key: 'ACCPFLANK-FDA6-4E0F-8A3F-000000000002', box: [679, 799, 4154, 4228, 0, 250], mat: 'script_wall' },
  // mystery-box collision clips (market,corp,roof,start,alley = N wall +Y; vault = E wall +X; lab = W wall -X)
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000001', box: [-1646, -1586, 1416, 1486, 0, 48], mat: 'clip' }, // market
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000002', box: [610, 670, 2668, 2738, 0, 48], mat: 'clip' },     // corp
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000003', box: [-1305.25, -1245.25, 3320, 3390, 0, 48], mat: 'clip' }, // roof
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000004', box: [-330, -270, 660, 730, 0, 48], mat: 'clip' },     // start
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000005', box: [1624, 1684, 1416, 1486, 0, 48], mat: 'clip' },   // alley
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000006', box: [1664, 1734, 2570, 2630, 0, 48], mat: 'clip' },   // vault
  { key: 'ACCBXPOS-8732-4E10-8A3F-000000000007', box: [-771, -701, 3370, 3430, 0, 48], mat: 'clip' },   // lab
];

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let fixed = 0;
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (!t.startsWith('guid ')) continue;
  const hit = TARGETS.find(tg => t.includes(tg.key));
  if (!hit) continue;
  // brush layout: this guid line, then exactly 6 plane lines, then '}'
  const np = planes(hit.box, hit.mat);
  if (lines[i + 7].trim() !== '}') { console.error('UNEXPECTED brush shape at guid', hit.key, '- line', i + 7, '=', lines[i + 7]); process.exit(1); }
  for (let k = 0; k < 6; k++) lines[i + 1 + k] = np[k];
  fixed++;
}
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`fix_led_safe_geometry: rewrote ${fixed}/${TARGETS.length} brushes (real-corner winding + wall penetration)`);
if (fixed !== TARGETS.length) { console.error('WARNING: not all targets matched!'); process.exit(1); }
