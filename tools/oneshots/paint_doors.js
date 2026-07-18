#!/usr/bin/env node
// paint_doors.js [--revert] - reskin the BUYABLE ZONE doors to ONE distinct stock material so players can tell a
// door from a wall (user 2026-06-29). BUYABLE doors ONLY (acc_door_* script_brushmodels) - NOT the perk-alcove
// doors (acc_perk_door_*) or the abyss doors (acc_abyss_*), per user clarification.
//
// WHY: each of the 12 buyable doors inherited its neighbouring wall's material (asphalt / concrete / dark metal),
// so the door panel blends into the wall until the buy-trigger UI pops. A brush face's material token IS the GDT
// material name (docs/29 / CLAUDE.md), so we swap every face token inside each acc_door_* brushmodel to one
// distinct material: t7_metal_diamond_plate_worn_wet (raised diamond tread-plate - user pick). Face materials need
// NO .zone line and stock t7_* ships free. This is a material/BSP change -> needs a FULL LED-baked build (NOT
// -GscOnly). It is NOT a winding/geometry change, so it cannot hit the brush.cpp:1860 bake crash - only the albedo
// the lightmapper sees changes.
//
// Idempotent + reversible: first run backs the .map up to .acc-doors-orig; --revert restores it.
// Usage:  node tools/paint_doors.js            (paint the buyable doors)
//         node tools/paint_doors.js --revert   (restore the pre-paint .map)
'use strict';
const fs = require('fs');

const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const BAK = MAP + '.acc-doors-orig';
const TO  = 't7_metal_diamond_plate_worn_wet';   // user pick 2026-06-29: industrial diamond tread-plate (stock, ships)
const DOOR_RE = /^acc_door_/;                     // BUYABLE zone doors ONLY (excludes acc_perk_door_*, acc_abyss_*)
// face line: ( x y z ) ( x y z ) ( x y z ) MATERIAL sx sy ox oy rot flags  lightmap ...   -> capture the MATERIAL token
const FACE_RE = /^(\s*\([^)]*\)\s*\([^)]*\)\s*\([^)]*\)\s+)(\S+)(\s.*)$/;
const KEEP = new Set(['caulk','clip','trigger','origin','nodraw','portal','skybox','hint']);  // never repaint functional tokens

const REVERT = process.argv.includes('--revert');

if (REVERT) {
  if (!fs.existsSync(BAK)) { console.error('[paint_doors] no .acc-doors-orig backup to revert from. Nothing done.'); process.exit(1); }
  fs.copyFileSync(BAK, MAP);
  fs.unlinkSync(BAK);
  console.log('[paint_doors] REVERTED: restored the pre-paint .map and removed the backup.');
  process.exit(0);
}

const src = fs.readFileSync(MAP, 'utf8');
const eol = src.includes('\r\n') ? '\r\n' : '\n';
const lines = src.split(/\r?\n/);
if (!fs.existsSync(BAK)) fs.writeFileSync(BAK, src);   // pristine backup, once

let depth = 0, ent = null, changed = 0;
const doors = {};
for (let i = 0; i < lines.length; i++) {
  const t = lines[i].trim();
  if (t === '{') { depth++; if (depth === 1) ent = { cls: null, tn: null }; continue; }
  if (t === '}') { depth--; if (depth === 0) ent = null; continue; }
  if (!ent) continue;
  let m;
  if (m = lines[i].match(/"classname"\s+"([^"]+)"/)) { ent.cls = m[1]; continue; }
  if (m = lines[i].match(/"targetname"\s+"([^"]+)"/)) { ent.tn = m[1]; continue; }
  if (ent.cls === 'script_brushmodel' && ent.tn && DOOR_RE.test(ent.tn)) {
    const fm = lines[i].match(FACE_RE);
    if (fm && !KEEP.has(fm[2]) && fm[2] !== TO) {
      lines[i] = fm[1] + TO + fm[3];
      changed++;
      doors[ent.tn] = (doors[ent.tn] || 0) + 1;
    }
  }
}

fs.writeFileSync(MAP, lines.join(eol));
const n = Object.keys(doors).length;
console.log(`[paint_doors] painted ${changed} face(s) across ${n} buyable door(s) -> ${TO}`);
for (const [d, c] of Object.entries(doors).sort()) console.log(`  ${d.padEnd(28)} ${c} faces`);
if (n !== 12) console.log(`[paint_doors] NOTE: expected 12 buyable doors; found ${n}. Verify the acc_door_* set.`);
console.log('[paint_doors] NEXT: FULL build WITH the LED bake (.\\tools\\build_map.ps1, NO -GscOnly) - material change is BSP-baked.');
