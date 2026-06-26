// door_centers.js - print the real world-center of every buyable zone door (zombie_door) in the .map.
//
// WHY: a map-placed brush entity (trigger_use / script_brushmodel) with no origin brush reports
// .origin = (0,0,0), NOT its centroid (see memory map-brush-origin-zero). So to spawn a buyable buy-trigger
// AT a door, you cannot read door.origin - you must hardcode the door's world center. This parses the .map
// brush geometry and prints `script_flag => trigger ( x, y, z )` so you can paste the values into
// zm_abandoned_cyber_city.gsc::zone_door_trigger_origin. Re-run if any door brush moves.
//
// Usage: node tools/door_centers.js

const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
const num = s => s.split(/[()\s]+/).filter(Boolean).map(Number);

for (let i = 0; i < lines.length; i++) {
  if (!/"classname"\s+"trigger_use"/.test(lines[i])) continue;
  let flag = null, planes = [];
  for (let j = i; j < i + 40 && j < lines.length; j++) {
    const fl = lines[j].match(/"script_flag"\s+"([^"]+)"/);
    if (fl) flag = fl[1];
    if (/^\s*\(.*\)\s*\(.*\)\s*\(.*\)\s+\w/.test(lines[j])) planes.push(lines[j]);
    if (planes.length >= 6) break;
  }
  if (!flag || planes.length < 6) continue;
  // box() winding: p1 z=z1(3rd), p2 z=z2(3rd), p3 y=y1(2nd), p4 x=x2(1st), p5 y=y2(2nd), p6 x=x1(1st)
  const z1 = num(planes[0])[2], z2 = num(planes[1])[2];
  const y1 = num(planes[2])[1], y2 = num(planes[4])[1];
  const x2 = num(planes[3])[0], x1 = num(planes[5])[0];
  const cx = (x1 + x2) / 2, cy = (y1 + y2) / 2, cz = Math.min(z1, z2) + 40;
  console.log(`  case "${flag}":`.padEnd(34) + `return ( ${cx}, ${cy}, ${cz} );`);
}
