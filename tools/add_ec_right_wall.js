// =============================================================================
// add_ec_right_wall.js  (ONE-SHOT, idempotent)
//
// Closes the OPEN right side of the Electric Cherry alcove (the rightmost stall in
// the Lab perk row, machine at X=675). respace_perk_alcoves_10.js intentionally
// DROPPED the row's two END-CAP partitions to keep all geometry >=60u off the side
// walls (thin slivers crash the LED bake). The side effect: nothing walls off the
// right of Electric Cherry, so a player can walk AROUND its closed door and buy it
// (user 2026-06-25: "there is no wall on right side of electric cherry... add one").
//
// FIX: a SOLID fill block from the EC stall's right edge (X=746 = machine 675 + HALF_W 71)
// to the Lab EAST interior wall (X=799), spanning the alcove depth (Y 4154..4228) at the
// partition height (Z 0..150). It BUTTS the east wall (X=799) and north wall (Y=4228) with
// coincident faces - EXACTLY how the alcove back brushes butt the north wall, which bakes
// fine - so there is NO thin gap/sliver behind it (unlike a thin end-cap partition at X=750,
// which would leave a 45u sliver to the wall = the reason the end caps were dropped).
//
// Brush geometry => FULL build WITH the LED bake is the gate (CLAUDE.md; memory
// led-bake-is-the-gate). Run tools/_bake_test.ps1 after; must print BAKED.
// box() winding is VERBATIM from respace_perk_alcoves_10.js (that row bakes).
//
// Idempotent: refuses to re-run if the marker comment is already present.
// =============================================================================
const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
// DEPRECATED 2026-06-25: a WORLD brush here HANGS the LED bake (thin nook near the east wall:
// butt=winding crash @9s, free-standing partition=lightmap hang @55s). The EC right wall now ships
// as a script_brushmodel entity `acc_ec_right_wall` (hand-authored in the .map door block, forced
// solid by _acc_perk_doors::seal_ec_right_wall) - brushmodels are EXCLUDED from the lightmapper, so
// they can't break the bake. This tool is kept only for history; it refuses to run (the marker below
// matches the shipped brushmodel's targetname).
const MARKER = 'acc_ec_right_wall';

// EC alcove geometry (confirmed against the .map 2026-06-25).
const EC_X       = 675;   // Electric Cherry machine origin X
const HALF_W     = 71;    // stall half-width (machine -> stall edge) = respace HALF_W
const LAB_EAST_X = 799;   // Lab east interior wall face
const MOUTH_Y    = 4154;  // stall mouth (south) = respace MOUTH_Y
const BACK_Y     = 4228;  // stall back (north) = respace BACK_Y / Lab north wall face
const TOP_Z      = 150;   // partition height = respace STALL_TOP_Z

const WALL_X1 = EC_X + HALF_W;   // 746 — right edge of the EC stall/door
const WALL_X2 = LAB_EAST_X;      // 799 — butt the Lab east wall (coincident, sliver-free)

// Deterministic GUID — distinct tag prefix so it never collides with other generators.
let gc = 0;
function guid(tag) {
  gc++;
  const h = ('ecw' + tag + gc).split('').reduce((a, c) => (a * 33 + c.charCodeAt(0)) >>> 0, 5381);
  const hx = h.toString(16).toUpperCase().padStart(8, '0').slice(0, 8);
  return `{${hx}-ECW1-4E0D-8A3F-${String(gc).padStart(12, '0')}}`;
}

// Axis-aligned box brush — VERBATIM winding from respace_perk_alcoves_10.js box().
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return [
    '{',
    ` guid "${guid('b')}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`,
    '}',
  ].join('\n');
}

let txt = fs.readFileSync(MAP, 'utf8');
const NL = txt.includes('\r\n') ? '\r\n' : '\n';
let lines = txt.split(/\r?\n/);

if (lines.some(l => l.includes(MARKER))) {
  console.error('add_ec_right_wall: already present — refusing to re-run.');
  process.exit(0);
}

// Insert right after the perk-alcove partition block (same worldspawn brush list).
function consumeBlocks(idx, n) {
  let consumed = 0, i = idx;
  while (consumed < n) {
    while (i < lines.length && lines[i].trim() !== '{') i++;
    if (i >= lines.length) throw new Error('ran out of lines consuming block ' + consumed);
    let depth = 0;
    do {
      const tk = lines[i].trim();
      if (tk === '{') depth++; else if (tk === '}') depth--;
      i++;
    } while (depth > 0 && i < lines.length);
    consumed++;
  }
  return i;
}

const ci = lines.findIndex(l => l.includes('ACC perk alcove partitions'));
if (ci < 0) throw new Error('partition block comment not found');
const end = consumeBlocks(ci + 1, 9);   // the 9 partition brushes

const wall = box(WALL_X1, WALL_X2, MOUTH_Y, BACK_Y, 0, TOP_Z, 'script_wall');
lines.splice(end, 0, MARKER, wall);

fs.writeFileSync(MAP, lines.join(NL));
console.log(`add_ec_right_wall: inserted EC right wall X=${WALL_X1}..${WALL_X2} Y=${MOUTH_Y}..${BACK_Y} Z=0..${TOP_Z}`);
