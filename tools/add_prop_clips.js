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
// Props that LEAVE the z=-240 floor leave INVISIBLE WALLS if an old clip stays. Props default to the z=-240
// floor (CLIP_BOT/TOP below); a DEEP prop sets a per-prop `bot` (+ `top`) for its own floor. A deep WORLDSPAWN
// clip (bot < -240) CRASHES the LED bake (brush.cpp:1860, see below), so deep clips are emitted ONE of two ways:
//   - `brushmodel: true` -> a script_brushmodel ENTITY (LED-EXEMPT) in the entity list = REAL collision that bakes.
//   - no flag            -> SKIPPED (walk-through) so the map still bakes.
// The 4 ABYSS stations are clipped via brushmodel (user 2026-06-27 "all deep abyss stations"): Overclock L2 (z-480),
// Ammo Crate bookends (L2 east z-480 & L5 z-1200), Glitch Altar L3 (z-720); L4 = AK-47 wall-buy. The 4 PARADISE
// stations stay skipped for now (add `brushmodel: true` to clip them too). Coords mirror spawn_altars. Half-extents
// are SNUG estimates; if a box over/under-reaches in playtest, just nudge hx/hy + re-run + full bake.
const PROPS = [
  { x: -120, y: 1550, hx: 18, hy: 30, label: 'exo_station' },         // p7_cai_work_table_metal_03_white (work table) - Foundry/Exo room WEST side, ORIGINAL size (user 2026-06-28 reverted a brief shrink, mid-depth y1550); mirrors _acc_exo::spawn_station_at (-120,1550). EXTENTS SWAPPED hx30/hy18 -> hx18/hy30 (user 2026-06-27): this table spawns at YAW 90, so its ~60-long axis runs along Y (clip 36x in X, 60y in Y) - the old 60x/36y was the un-rotated footprint, 90deg off (table poked out the long sides). The yaw-0 PARADISE twin (paradise_exo) correctly keeps 30/18. VERIFY in-game: if the table now pokes out front/back instead, the model's native long axis is the other way - flip back to hx30/hy18.
  { x:    0, y: 2493, hx: 9, hy: 24, top: -176, label: 'reactor_plinth' }, // p7_cai_sign_inteactive_kiosk = a FLAT SCREEN panel - THIN slab 18(X)x48(Y)x64 (faces E/W at yaw 270, thin in X). Teddy-bear NORTH under-room (ORIGINAL, x[-192,192] y[2173,2517]). CENTERED at the back wall (0,2493); the bears were nudged forward to y2350 so the deep kiosk clears them behind; mirrors _acc_reactor::spawn_plinth_at (0,2493)
  { x: -360, y: 1950, hx: 28, hy: 28, top: -192, label: 'pit_cache_w' }, // p7_cai_stacking_cargo_crate - snug 56x56x48 (matches the plaza crates; user 2026-06-26 "same clips")
  { x:  360, y: 1950, hx: 28, hy: 28, top: -192, label: 'pit_cache_e' }, // p7_cai_stacking_cargo_crate - snug 56x56x48
  { x:  120, y: 1550, hx: 24, hy: 9, top: -176, label: 'perk_slot_vendor' }, // p7_cai_sign_inteactive_kiosk = same FLAT SCREEN panel as the reactor plinth. THIN slab 48(X)x18(Y)x64; faces +Y at yaw 0 so thin in Y. Foundry/Exo room EAST side, ORIGINAL size (user 2026-06-28 reverted a brief shrink, opposite the Exo station at WEST -120,1550); mirrors _acc_glitch_altar spawn_perk_slot_vendor_at (120,1550)
  { x:  400, y: 1948, hx: 28, hy: 28, bot:  -480, top:  -432, brushmodel: true, label: 'ammo_crate_l2' }, // p7_cai_stacking_cargo_crate (AMMO crate #1, _acc_ammo_crate::spawn_crate_at) - abyss L2 EAST, opposite the OC. 56x56x48. DEEP -> script_brushmodel clip, LED-exempt (user 2026-06-27: "all deep abyss stations" get clips).
  { x: -400, y: 1948, hx: 28, hy: 28, bot: -1200, top: -1152, brushmodel: true, label: 'ammo_crate_l5' }, // p7_cai_stacking_cargo_crate (AMMO crate #2) - abyss L5 WEST, the bottom before Paradise. 56x56x48. DEEP -> script_brushmodel clip, LED-exempt (user 2026-06-27).
  { x: -400, y: 1948, hx: 30, hy: 34, bot: -480, top: -400, brushmodel: true, label: 'overclock_terminal' }, // p7_cai_ticket_kiosk_theatre (acc_overclocks::spawn_terminal_at) - abyss L2 WEST, OPPOSITE the ammo crate. 60x68x80. DEEP -> script_brushmodel clip, LED-exempt (user 2026-06-27).
  { x:  400, y: 1948, hx: 30, hy: 34, bot: -1200, top: -1120, brushmodel: true, label: 'overclock_l5' }, // p7_cai_ticket_kiosk_theatre (acc_overclocks::spawn_terminal_at) - abyss L5 EAST, opposite the L5 ammo crate. 60x68x80. DEEP -> script_brushmodel clip, LED-exempt (user 2026-06-28). Emits on the next add_prop_clips.js run + LED bake (queued; the L5 OC is GSC-spawned + walk-through until then).
  // --- L3 + Paradise deep kiosks (user 2026-06-27 "add clips to those") - the last walk-through interactables, clipped at their own floors via per-prop `bot`. The sign kiosks reuse the SAME 48x18x64 thin slab as the reactor/perk-vendor (same model, spawned yaw 0 -> thin in Y); their floating core orbs are decorative (no clip). ---
  { x: -400, y: 1948, hx: 24, hy:  9, bot:  -720, top:  -656, brushmodel: true, label: 'glitch_altar_l3' },      // p7_cai_sign_inteactive_kiosk (acc_glitch_altar::spawn_altar_at, yaw 0) - abyss L3 (z=-720). 48x18x64. DEEP -> script_brushmodel clip, LED-exempt (user 2026-06-27: the gambling altar was walk-through).
  { x: -850, y: -1350, hx: 24, hy:  9, bot: -1200, top: -1136, label: 'paradise_altar' },       // p7_cai_sign_inteactive_kiosk (spawn_altar_at, yaw 0) - PARADISE (z=-1200) west-mid. 48x18x64.
  { x:  850, y: -1350, hx: 30, hy: 34, bot: -1200, top: -1120, label: 'paradise_overclock' },   // p7_cai_ticket_kiosk_theatre (spawn_terminal_at yaw 0) - PARADISE east-mid. 60x68x80, same as the L2 overclock.
  { x: -850, y: -1950, hx: 30, hy: 18, bot: -1200, top: -1120, label: 'paradise_exo' },         // p7_cai_work_table_metal_03_white (acc_exo::spawn_station_at yaw 0) - PARADISE west-south. 60x36x80, same as the Foundry exo table.
  { x:  850, y: -1950, hx: 24, hy:  9, bot: -1200, top: -1136, label: 'paradise_perk_vendor' }, // p7_cai_sign_inteactive_kiosk (acc_perks::spawn_perk_slot_vendor_at yaw 0) - PARADISE east-south. 48x18x64.
];
const CLIP_BOT = -240, CLIP_TOP = -160;   // default: sits on the z=-240 floor, 80 tall. Per-prop `top` can override
                                          // (e.g. the cargo crates use top=-192 = a snug 48-tall clip = the plaza crate height).
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

// A DEEP clip emitted as a script_brushmodel ENTITY (lives in the entity list, AFTER the worldspawn close). The
// LED lightmapper IGNORES script_brushmodels (memory brushmodel-wall-led-exempt + the shipped acc_ec_right_wall /
// acc_door_implant precedents in this .map), so an abyss-depth `clip` here gives REAL collision WITHOUT the
// worldspawn-clip bake crash (brush.cpp:1860). It is solid at load - static, no GSC needed (same as the EC wall).
// Two guids: one for the entity, one for the nested brush (box() emits the brush wrapper + 6 planes).
function brushmodelEntity(label, x1, x2, y1, y2, z1, z2, tex) {
  const brush = box(x1, x2, y1, y2, z1, z2, tex);   // "{ guid... 6 planes }"
  return ['{', ` guid "${guid()}"`,
    ' "classname" "script_brushmodel"',
    ` "targetname" "acc_clip_${label}"`,
    brush, '}'].join('\n');
}

let lines = fs.readFileSync(inPath, 'utf8').split('\n');

// strip any prior PROP CLIPS blocks (clean re-run) - BOTH the worldspawn block AND the brushmodel-entity block
// (the brushmodel headers contain "PROP CLIPS"/"end prop clips" as substrings, so this loop catches both).
for (;;) {
  const s = lines.findIndex(l => l.includes('===== PROP CLIPS'));
  if (s < 0) break;
  let e = -1;
  for (let i = s; i < lines.length; i++) { if (lines[i].includes('===== end prop clips')) { e = i; break; } }
  if (e < 0) { console.error('ERROR: unterminated PROP CLIPS block'); process.exit(2); }
  console.log(`  stripped prior PROP CLIPS block (lines ${s + 1}-${e + 1})`);
  lines.splice(s, e - s + 1);
}

// find worldspawn close (entity 0)
let depth = 0, wsClose = -1;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length, closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) depth++;
  for (let c = 0; c < closes; c++) { depth--; if (depth === 0 && wsClose === -1) wsClose = i; }
}
if (wsClose < 0) { console.error('ERROR: worldspawn close not found'); process.exit(2); }

// SHALLOW clips -> worldspawn `clip` brushes (injected BEFORE the worldspawn close). DEEP clips (bot < -240) ->
// either a script_brushmodel ENTITY (if `brushmodel: true`, injected AFTER the worldspawn close = the entity list)
// or skipped (walk-through). A deep WORLDSPAWN `clip` brush inside the enclosed abyss box CRASHES the Radiant LED
// bake (exit 0xC0000005 / brush.cpp:1860, memory led-relight-dead-end-enclosed-geometry); the script_brushmodel is
// LED-EXEMPT so it bakes. The shallow z[-240,-160] clips bake fine as plain worldspawn brushes.
const block = ['// ===== PROP CLIPS (add_prop_clips.js) - invisible collision around underground interactables ====='];
const entityBlock = ['// ===== PROP CLIPS (brushmodel) - deep abyss-depth clips as LED-exempt script_brushmodels ====='];
let nWs = 0, nBm = 0, nSkip = 0;
for (const p of PROPS) {
  const deep = (p.bot !== undefined && p.bot < CLIP_BOT);
  const z1 = (p.bot !== undefined ? p.bot : CLIP_BOT), z2 = (p.top !== undefined ? p.top : CLIP_TOP);
  const x1 = p.x - p.hx, x2 = p.x + p.hx, y1 = p.y - p.hy, y2 = p.y + p.hy;

  if (deep && p.brushmodel) {
    entityBlock.push(`// clip(brushmodel): ${p.label} @ (${p.x},${p.y}) z[${z1},${z2}]`);
    entityBlock.push(brushmodelEntity(p.label, x1, x2, y1, y2, z1, z2, MAT));
    nBm++;
    continue;
  }
  if (deep) {
    // Deep but NOT opted into a brushmodel (e.g. the Paradise stations) - skipped (walk-through) so the map still
    // bakes. Add `brushmodel: true` to its PROPS entry to give it real collision.
    console.log(`  SKIP deep clip '${p.label}' (z=${p.bot}): no brushmodel flag (still walk-through).`);
    nSkip++;
    continue;
  }
  block.push(`// clip: ${p.label} @ (${p.x},${p.y})`);
  block.push(box(x1, x2, y1, y2, z1, z2, MAT));
  nWs++;
}
block.push('// ===== end prop clips =====');
entityBlock.push('// ===== end prop clips (brushmodel) =====');

const out = [];
for (let i = 0; i < lines.length; i++) {
  if (i === wsClose) out.push(...block);                   // worldspawn brushes: BEFORE the worldspawn close brace
  out.push(lines[i]);
  if (i === wsClose && nBm > 0) out.push(...entityBlock);  // brushmodel entities: AFTER the close brace (entity list)
}
fs.writeFileSync(outArg, out.join('\n'));
console.log(`  ${nWs} worldspawn clip(s) + ${nBm} brushmodel clip(s) injected (mat '${MAT}'); ${nSkip} deep clip(s) skipped (no brushmodel flag).`);
console.log(`[clips] lines ${lines.length} -> ${out.length}; wrote ${outArg}`);
