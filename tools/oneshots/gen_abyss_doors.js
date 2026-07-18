// gen_abyss_doors.js - UPRIGHT GATE at each abyss descent stairway (user 2026-06-22).
// One script_brushmodel vertical DOOR per descent (D1..D4), standing in the stairwell's WEST
// entry (the only walk-in). _acc_abyss_doors.gsc drives these as SOUL BOXES now (user 2026-06-25):
// each opens when the team banks 100 zombie souls on that layer, then hide()/notsolid()/connectpaths()
// the door (the proven _acc_perk_doors mechanism) so players AND zombies can then descend.
//
// WHY the WEST face: every descent well (gen_abyss_layer.js emitWellWalls) is a slim center
// strip whose stairs run W->E; the SOUTH/NORTH/EAST sides are already sealed with a 128u
// jump-proof railing, and the WEST face (x = wellRect.x1 = -112) is left OPEN as the stair
// ENTRY. So an UPRIGHT door across that west face is the correct, door-shaped gate (the earlier
// horizontal floor-cap read wrong). Door height = 128 = the railing height (cz..cz+128), so it
// is jump-proof and flush with the rails. It sits on the approach floor just WEST of the well,
// clear of the treads.
//
// GEOMETRY IS LED-BAKED -> run a FULL build (cod2map+LED) or tools/_bake_test.ps1 after this.
// Bake-safe: reuses the EXACT box() winding from gen_abyss_layer.js (the abyss memory: a wrong
// brush winding crashes brush.cpp:1860). DISTINCT GUID marker -ACD0- so gen_abyss_layer.js's
// own -ACA2- strip/regen leaves these alone (and vice-versa).
//
// Usage: node tools/gen_abyss_doors.js              inject/refresh the 4 gate doors
//        node tools/gen_abyss_doors.js --revert     remove them
//        node tools/gen_abyss_doors.js --out <file> write elsewhere (dry run)

const fs = require('fs');
const path = require('path');

const MAP = path.join(__dirname, '..', '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');   // (fixed 2026-07-13: the oneshots/ move left this one '..' short - the doors gen had never run since the move)
const revert = process.argv.includes('--revert');
const outArg = process.argv.indexOf('--out');
const OUT = outArg > 0 ? process.argv[outArg + 1] : MAP;

// ---- footprint constants (verbatim from gen_abyss_layer.js) ------------------
const PIT_Y1 = 1723, PIT_Y2 = 2173;
const PIT_FLOOR_TOP = -240, PITCH = 240;
const WELL_HALF = 112;      // well x[-112,112] (the 14-step run / 2); x1 = -112 = the WEST entry face
const WELL_YD = 128;        // well depth in Y against the south/north wall
const DOOR_TH = 12;         // door slab thickness (thin), seated just WEST of the entry
const DOOR_H = 224;         // door height above the floor = FLOOR-TO-CEILING (user 2026-07-13: the old
                           // 128 left a ~96u gap under the 224u ceiling -> a double-jump cleared the door
                           // into the next descent WITHOUT banking souls). 224 = the layer headroom, so the
                           // slab seals flush to the ceiling. MUST match the stairwell railing height in
                           // gen_abyss_layer.js::emitWellWalls (rail = cz + 224).
// DOOR SKIN (user 2026-07-13 "the doors to the trench need the correct models"): the soul-door
// slabs were greybox script_wall. Skin them t7_metal_diamond_plate_worn_wet - the map's CANONICAL
// buyable-door material (memory buyable-door-design-convention: every door slab uses this worn
// diamond-plate metal so it reads as a shutter vs the t7_metal_worn_iron_dark shaft walls).
const W = 't7_metal_diamond_plate_worn_wet';

// floor z of layer n: F1=-240 (pit) .. F4=-960
function floorZ(n) { return PIT_FLOOR_TOP - (n - 1) * PITCH; }
// descent k connects L[k]->L[k+1]; its well is cut into L[k]'s floor. D1 XS, D2 XN, D3 XS, D4 XN.
function descentCorner(k) { return (k % 2 === 1) ? 'XS' : 'XN'; }
function wellRect(k) {
  const c = descentCorner(k);
  if (c === 'XS') return { x1: -WELL_HALF, x2: WELL_HALF, y1: PIT_Y1, y2: PIT_Y1 + WELL_YD };  // south wall
  return { x1: -WELL_HALF, x2: WELL_HALF, y1: PIT_Y2 - WELL_YD, y2: PIT_Y2 };                  // north wall
}

// ---- bake-safe box() (VERBATIM from gen_abyss_layer.js - DO NOT alter the winding) ----
let guidCounter = 0x10;
function guid() {
  guidCounter++;
  const c = guidCounter.toString(16).toUpperCase().padStart(12, '0');
  return `{7A2BAB0D-ACD0-4E0C-8A3F-${c}}`;   // -ACD0- marker => strippable on re-run, distinct from abyss -ACA2-
}
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

// One script_brushmodel UPRIGHT door entity standing in descent k's WEST stair entry,
// targetname acc_abyss_door_<k>. Spans the well's Y width, 128 tall, 12 thick, on the
// approach floor just west of the entry face (x = w.x1).
function gateEntity(k) {
  const w = wellRect(k);
  const cz = floorZ(k);                 // the TOP floor of this descent (where the player walks up)
  const x2 = w.x1;                      // west entry face (= -WELL_HALF = -112)
  const x1 = w.x1 - DOOR_TH;            // 12u thick, just WEST of the entry (clear of the treads)
  const z1 = cz;                        // stands on the top floor
  const z2 = cz + DOOR_H;               // = railing height (jump-proof, flush with the side rails)
  return [
    `{`,
    ` guid "${guid()}"`,
    ` "classname" "script_brushmodel"`,
    ` "targetname" "acc_abyss_door_${k}"`,
    ` // brush 0 (upright stair-entry door, descent ${k})`,
    box(x1, x2, w.y1, w.y2, z1, z2, W).split('\n').map(l => ' ' + l).join('\n'),
    `}`,
  ].join('\n');
}

const BEGIN = '// >>> ACC ABYSS DOORS (gen_abyss_doors.js) - buyable descent gate doors';
const END = '// <<< ACC ABYSS DOORS';

let src = fs.readFileSync(MAP, 'utf8');

// Strip any prior block (idempotent) - matches the old "gate caps" header too so a re-run
// cleanly replaces the floor-cap version with the upright doors.
const reNew = new RegExp(`\\n?${BEGIN.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}[\\s\\S]*?${END.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}\\n?`, 'g');
const reOld = /\n?\/\/ >>> ACC ABYSS DOORS[\s\S]*?\/\/ <<< ACC ABYSS DOORS\n?/g;
src = src.replace(reNew, '\n').replace(reOld, '\n');

if (!revert) {
  const gates = [1, 2, 3, 4].map(gateEntity).join('\n');
  const block = `${BEGIN}\n${gates}\n${END}\n`;
  // Insert just before the final closing brace of the file (after the last entity).
  const lastBrace = src.lastIndexOf('}');
  if (lastBrace < 0) { console.error('no closing brace in .map'); process.exit(1); }
  src = src.slice(0, lastBrace + 1) + '\n' + block + src.slice(lastBrace + 1);
}

fs.writeFileSync(OUT, src);
console.log(`${revert ? 'reverted' : 'wrote'} abyss UPRIGHT doors -> ${OUT}`);
if (!revert) for (const k of [1, 2, 3, 4]) {
  const w = wellRect(k);
  console.log(`  acc_abyss_door_${k}: WEST entry x[${w.x1 - DOOR_TH},${w.x1}] y[${w.y1},${w.y2}] z[${floorZ(k)},${floorZ(k) + DOOR_H}] (${descentCorner(k)})`);
}
