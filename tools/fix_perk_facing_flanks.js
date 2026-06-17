// =============================================================================
// fix_perk_facing_flanks.js  (ONE-SHOT, idempotent)
//
// Two fixes to the Lab perk gallery (follow-up to add_perk_alcoves.js):
//  1. FACING: add_perk_alcoves.js rotated the 9 machines to yaw 270, which made
//     them face WEST (sideways). The original yaw 0 faces SOUTH (toward the player
//     approaching the stall mouth) - so revert all 9 to "0 0 0".
//  2. FLANKING WALLS: fill the gap between each lab side wall and the end of the
//     perk row with a solid block, so the whole gallery reads as a recess in the
//     back wall ("the wall moved forward"). West gap X[-761,-675], east X[675,799];
//     full stall depth Y[4154,4228], full height z[0,256].
//
// Geometry/entity change => FULL build (cod2map + linker; -SkipLED).
// Idempotent: refuses to re-run if any "{ACCPFLANK" guid already exists.
// =============================================================================
const fs = require('fs');
const path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');

const PERK_MODELS = new Set([
  'vending_revive_struct', 'vending_juggernaut_struct', 'vending_sleight_struct',
  'vending_doubletap_struct', 'vending_marathon_struct', 'vending_additionalprimaryweapon_struct',
]);

let gc = 0;
function guid() {
  gc++;
  const h = ('flank' + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{ACCPFLANK-${hx.slice(0, 4)}-4E0F-8A3F-${String(gc).padStart(12, '0')}}`;
}
function box(x1, x2, y1, y2, z1, z2, tex) {
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

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
if (lines.some(l => l.includes('{ACCPFLANK'))) {
  console.error('fix_perk_facing_flanks: already applied (ACCPFLANK present) - refusing.');
  process.exit(0);
}

// --- 1. revert the 9 perk machine angles to "0 0 0" (face south) -------------
function revertFacing() {
  const hits = [];
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(/^"model" "_prefabs\/zm\/zm_core\/(vending_[a-z_]+)\.map"$/);
    const isInline = lines[i] === '"targetname" "zm_perk_machine"';
    if (!((m && PERK_MODELS.has(m[1])) || isInline)) continue;
    let s = i; while (s > 0 && lines[s] !== '{') s--;
    let e = i; while (e < lines.length && lines[e] !== '}') e++;
    for (let k = s; k <= e; k++) if (/^"angles" "/.test(lines[k])) { hits.push(k); break; }
  }
  let changed = 0;
  for (const k of hits) {
    if (lines[k] !== '"angles" "0 0 0"') { lines[k] = '"angles" "0 0 0"'; changed++; }
  }
  return changed;
}
const reoriented = revertFacing();

// --- 2. flanking walls (worldspawn) ------------------------------------------
function worldspawnCloseIdx() {
  let depth = 0;
  for (let i = 0; i < lines.length; i++) {
    const t = lines[i].trim();
    if (t === '{') depth++;
    else if (t === '}') { depth--; if (depth === 0) return i; }
  }
  return -1;
}
const wc = worldspawnCloseIdx();
if (wc < 0) { console.error('no worldspawn close'); process.exit(1); }
const flanks = [
  '// ACC perk gallery flanking walls (tools/fix_perk_facing_flanks.js)',
  box(-761, -675, 4154, 4228, 0, 256, 'script_wall'),  // west flank
  box(675, 799, 4154, 4228, 0, 256, 'script_wall'),    // east flank
];
lines.splice(wc, 0, ...flanks);

fs.writeFileSync(MAP, lines.join('\n'));
console.log(`fix_perk_facing_flanks: machinesReoriented=${reoriented} flankWalls=2`);
