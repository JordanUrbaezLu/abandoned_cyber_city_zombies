// Append a map-covering nav_volume entity to the .map (required by the Dragon Gauntlet's
// whelp vehicle - HB21 instructions: "add a nav_volume ... or itll crash").
// Box spans the full entity bounds (x[-2139,2176] y[-2150,4227] z[-1200,392]) + margin.
// Plane trick = tools/add_prop_clips.js box(): only the constrained coordinate matters,
// the free coords are arbitrary non-collinear points on the plane.
const fs = require('fs')
const p = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/map_source/zm/zm_abandoned_cyber_city.map'
let t = fs.readFileSync(p, 'utf8')
if (t.includes('acc nav_volume')) { console.log('already present - skip'); process.exit(0) }

function guid() {
  const h = n => Array.from({ length: n }, () => '0123456789ABCDEF'[Math.floor(Math.random() * 16)]).join('')
  return `{${h(8)}-${h(4)}-${h(4)}-${h(4)}-${h(12)}}`
}
const [x1, x2, y1, y2, z1, z2] = [-2400, 2400, -2400, 4500, -1300, 700]
const tex = 'volume 64 64 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0'
const brush = ['{', ` guid "${guid()}"`,
  ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${tex}`,
  ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${tex}`,
  ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${tex}`,
  ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${tex}`,
  ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${tex}`,
  ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${tex}`, '}'].join('\n')

const ent = ['// [acc] acc nav_volume - whole-map flying-nav volume for the Dragon Gauntlet whelp (2026-07-24)', '{',
  `guid "${guid()}"`, '"classname" "nav_volume"', '// brush 0', brush, '}', ''].join('\n')

t = t.replace(/\s*$/, '\n') + ent
fs.writeFileSync(p, t)
console.log('nav_volume appended; box x[%d,%d] y[%d,%d] z[%d,%d]', x1, x2, y1, y2, z1, z2)
