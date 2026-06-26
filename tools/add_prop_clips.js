#!/usr/bin/env node
// add_prop_clips.js - invisible collision clips around the underground interactable props.
//
// WHY: each interactable is a bare spawn("script_model")+setmodel() (no collision set), so it
// is only solid if its xmodel ships a collision LOD. The decorative ones (e.g. the Altar's
// p7_cai_sign_inteactive_kiosk) have none -> the player walks through them (user 2026-06-19).
// Fix = an invisible `clip` brush snug around each prop (collision is geometry = our lane; this
// does NOT touch the system agent's spawn GSC). Re-runnable: it strips the old PROP CLIPS section
// first, so when props re-home into the Stalls/Cages just update the coords below + re-run.
//
// COORDS MIRROR _acc_glitch_altar.gsc spawn_altars() (the live spawn call site). Keep in sync -
// the system agent moves these; re-sync + re-bake after every spawn_altars edit (audit 2026-06-19
// caught a stale-coord drift: terminal unclipped + phantom clips guarding empty air). FRAGILE by
// design - if the props keep drifting, lock the final coords or move collision to the spawn side.
//
// Usage: node tools/add_prop_clips.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: add_prop_clips.js <in> <out>'); process.exit(1); }

// props: x,y on the z=-240 floor + half-extents (snug to the model silhouette). label for comments.
// RE-SYNCED to the LIVE z=-240 spawn origins (user 2026-06-25 "make hitboxes match the models - no invisible walls"):
//   - exo_station    (230,1450) Foundry  - p7_cai_work_table_metal_03_white       (_acc_exo::spawn_station_at)
//        (room RELOCATED east to center x=350 on 2026-06-25 so its door clears the abyss well; clip +350 too)
//   - reactor_plinth   (0,2120)  pit     - p7_cai_sign_inteactive_kiosk (no LOD)  (_acc_reactor::spawn_plinth_at)
//   - pit_cache_w/e (-/+360,1950) pit    - p7_cai_stacking_cargo_crate            (_acc_glitch_altar::spawn_altars)
//   - perk_slot_vendor (-250,1820) pit                                            (_acc_glitch_altar::spawn_altars)
// REMOVED orphans: glitch_altar_base (altar -> abyss L3) + overclock_terminal (terminal -> abyss L2). Those props
// left the z=-240 floor, so their old clips were INVISIBLE WALLS in the empty Foundry. NOTE: this generator only
// clips the z=-240 level (CLIP_BOT/TOP below) - the altar (L3 z-720) + terminal (L2 z-480) are now UNCLIPPED
// (walk-through) at their deep homes; clipping those would need a per-prop z (not done - they're not invisible
// walls). Half-extents are SNUG estimates; if a box still over/under-reaches in playtest, just nudge hx/hy + re-run.
const PROPS = [
  { x:  230, y: 1450, hx: 30, hy: 18, label: 'exo_station' },         // p7_cai_work_table_metal_03_white (work table) - room moved east 2026-06-25
  { x:    0, y: 2120, hx: 24, hy: 24, label: 'reactor_plinth' },      // p7_cai_sign_inteactive_kiosk (no collision LOD)
  { x: -360, y: 1950, hx: 28, hy: 28, label: 'pit_cache_w' },         // p7_cai_stacking_cargo_crate
  { x:  360, y: 1950, hx: 28, hy: 28, label: 'pit_cache_e' },         // p7_cai_stacking_cargo_crate
  { x: -250, y: 1820, hx: 28, hy: 28, label: 'perk_slot_vendor' },    // pit
];
const CLIP_BOT = -240, CLIP_TOP = -160;   // sits on the z=-240 floor, 80 tall (covers player body height)
const MAT = 'clip';                       // invisible solid (player+AI+bullets); stock tools material, ships free, no zone line

let guidCounter = 0xD00;
function guid() { guidCounter++; const c = guidCounter.toString(16).toUpperCase().padStart(12, '0'); return `{7A2B9F0D-ACCD-4E13-8A3F-${c}}`; }
function box(x1, x2, y1, y2, z1, z2, tex) {
  const t = `${tex} 128 128 0 0 0 0 lightmap_gray 16384 16384 0 0 0 0`;
  return ['{', ` guid "${guid()}"`,
    ` ( 134.5 459.5 ${z1} ) ( 86.5 459.5 ${z1} ) ( 86.5 419.5 ${z1} ) ${t}`,
    ` ( 94.5 419.5 ${z2} ) ( 94.5 459.5 ${z2} ) ( 142.5 459.5 ${z2} ) ${t}`,
    ` ( 86.5 ${y1} 88 ) ( 134.5 ${y1} 88 ) ( 134.5 ${y1} 0 ) ${t}`,
    ` ( ${x2} 415.5 88 ) ( ${x2} 455.5 88 ) ( ${x2} 455.5 0 ) ${t}`,
    ` ( 138.5 ${y2} 88 ) ( 90.5 ${y2} 88 ) ( 90.5 ${y2} 0 ) ${t}`,
    ` ( ${x1} 459.5 88 ) ( ${x1} 419.5 88 ) ( ${x1} 419.5 0 ) ${t}`, '}'].join('\n');
}

let lines = fs.readFileSync(inPath, 'utf8').split('\n');

// strip any prior PROP CLIPS block (clean re-run)
const s = lines.findIndex(l => l.includes('===== PROP CLIPS'));
if (s >= 0) {
  let e = -1;
  for (let i = s; i < lines.length; i++) { if (lines[i].includes('===== end prop clips')) { e = i; break; } }
  if (e >= 0) { console.log(`  stripped prior PROP CLIPS (lines ${s + 1}-${e + 1})`); lines.splice(s, e - s + 1); }
}

// find worldspawn close (entity 0)
let depth = 0, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) depth++;
  for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && wsClose === -1) wsClose = i; }
}
if (wsClose < 0) { console.error('ERROR: worldspawn close not found'); process.exit(2); }

const block = ['// ===== PROP CLIPS (add_prop_clips.js) - invisible collision around underground interactables ====='];
for (const p of PROPS) {
  block.push(`// clip: ${p.label} @ (${p.x},${p.y})`);
  block.push(box(p.x - p.hx, p.x + p.hx, p.y - p.hy, p.y + p.hy, CLIP_BOT, CLIP_TOP, MAT));
}
block.push('// ===== end prop clips =====');

const out = [];
for (let i = 0; i < lines.length; i++) { if (i === wsClose) out.push(...block); out.push(lines[i]); }
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  ${PROPS.length} prop clips (mat '${MAT}', z[${CLIP_BOT},${CLIP_TOP}]) injected before worldspawn close (line ${wsClose + 1}).`);
console.log(`[clips] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
