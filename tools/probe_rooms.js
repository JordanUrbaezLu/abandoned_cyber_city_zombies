#!/usr/bin/env node
// Reusable: extract a reliable CURRENT room model from entity ORIGINS (points parse cleanly, unlike
// the now-organic brush AABBs). Per zone: spawner-riser centroid + extent (= room interior anchor),
// the buyable-door slab positions (doorways to keep cover clear of), and PaP blockers.
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const txt = fs.readFileSync(MAP, 'utf8');

// Split into entity blocks (each "// entity N" ... matching close brace).
const lines = txt.split(/\r?\n/);
let i = lines.findIndex(l => l.startsWith('// entity '));
const ents = [];
while (i < lines.length && i >= 0) {
  while (i < lines.length && lines[i].startsWith('// entity ')) i++;
  const seg = [];
  let depth = 0, started = false;
  while (i < lines.length) {
    const l = lines[i]; seg.push(l); i++;
    const t = l.trim();
    if (t === '{') { depth++; started = true; } else if (t === '}') depth--;
    if (started && depth === 0) break;
  }
  ents.push(seg.join('\n'));
  while (i < lines.length && !lines[i].startsWith('// entity ')) i++;
}

const kv = (body, k) => { const m = body.match(new RegExp(`"${k}"\\s*"([^"]*)"`)); return m ? m[1] : null; };
const originOf = (body) => { const o = kv(body, 'origin'); if (!o) return null; const p = o.trim().split(/\s+/).map(Number); return p.length === 3 ? p : null; };
// brush AABB (for door slabs, which are brushmodels with no origin)
function brushAABB(body) {
  const re = /\(\s*(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s+(-?\d+(?:\.\d+)?)\s*\)/g;
  let m, xs = [], ys = [], zs = [];
  while ((m = re.exec(body))) { xs.push(+m[1]); ys.push(+m[2]); zs.push(+m[3]); }
  if (!xs.length) return null;
  return [Math.min(...xs), Math.max(...xs), Math.min(...ys), Math.max(...ys), Math.min(...zs), Math.max(...zs)];
}

const zones = {};
const doors = [];
for (const body of ents) {
  const tn = kv(body, 'targetname');
  if (!tn) continue;
  if (/_spawners$/.test(tn)) {
    const o = originOf(body);
    if (o) { (zones[tn] = zones[tn] || []).push(o); }
  } else if (/^acc_door_/.test(tn) || /^acc_pap_block_/.test(tn)) {
    const a = brushAABB(body);
    if (a) doors.push({ tn, a });
  }
}

const only = process.argv[2]; // optional: a zone short name to also list individual risers
console.log('=== ROOM ANCHORS (from <zone>_spawners struct origins) ===');
for (const [z, pts] of Object.entries(zones)) {
  const xs = pts.map(p => p[0]), ys = pts.map(p => p[1]);
  const cx = Math.round(xs.reduce((a, b) => a + b, 0) / xs.length);
  const cy = Math.round(ys.reduce((a, b) => a + b, 0) / ys.length);
  console.log(`  ${z}: ${pts.length} risers  centroid(${cx},${cy})  x[${Math.min(...xs)},${Math.max(...xs)}] y[${Math.min(...ys)},${Math.max(...ys)}]`);
  if (only && z.includes(only)) pts.forEach(p => console.log(`      riser (${p[0]},${p[1]},${p[2]})`));
}
console.log('\n=== DOORWAYS / PaP blockers (keep cover clear) ===');
doors.sort((a, b) => a.tn.localeCompare(b.tn));
for (const d of doors) console.log(`  ${d.tn}: x[${d.a[0]},${d.a[1]}] y[${d.a[2]},${d.a[3]}] z[${d.a[4]},${d.a[5]}]`);
console.log(`\n(${ents.length} entities scanned)`);
