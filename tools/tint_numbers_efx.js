#!/usr/bin/env node
// tint_numbers_efx.js - regen recipe for the [acc] tinted clones of coolyer's BO1
// Nixie Numbers FX (docs/44). Clones a numbers .efx and retints every colorGraph
// row to a single RGB (the pack ships white 1-1-1; the tint IS the boss identity:
// cyan = Glitch/Phantom de-rez blink, red = Scientist thief aura).
//
// Usage: node tools/tint_numbers_efx.js <src.efx> <dst.efx> <r> <g> <b> [sizeScale] [world]
//   6th arg "world": strip spawnRelative + runRelToEffect from emitter flags lines so
//   particles persist in WORLD space - a moving emitter then leaves a TRAIL in its wake
//   (user 2026-07-17 "they should trail him as he runs") instead of a rigid riding aura.
// e.g.   node tools/tint_numbers_efx.js \
//          "<tools>/share/raw/fx/misc/numbers_fx/fx_misc_nix_numbers_random_directions.efx" \
//          share/raw/fx/_custom/acc/fx_acc_derez_blink.efx 0.25 0.95 1
//        node tools/tint_numbers_efx.js <src> share/raw/fx/_custom/acc/fx_acc_scientist_trail.efx 1 0.12 0.08 3
//
// Parser: tracks `colorGraph` / `sizeGraph0` / `sizeGraph1` blocks by brace depth.
// colorGraph rows "<t> <r> <g> <b>" get their RGB replaced; with the optional
// sizeScale arg, sizeGraph rows "<t> <v>" get v multiplied (the pack's curves are
// normalized 1.0, so the multiplier IS the size - user 2026-07-17 "numbers are
// tiny on him, make them 3x"). Everything else passes through byte-identical.
const fs = require('fs');
const [src, dst, r, g, b, sizeScale, worldArg] = process.argv.slice(2);
if (!src || !dst || !r || !g || !b) {
  console.error('usage: node tint_numbers_efx.js <src.efx> <dst.efx> <r> <g> <b> [sizeScale] [world]');
  process.exit(1);
}
const scale = sizeScale ? parseFloat(sizeScale) : null;
const world = (worldArg === 'world');
const lines = fs.readFileSync(src, 'utf8').split(/\r?\n/);
// Block state machine: a graph block ENDS when its braces re-balance to zero AFTER having
// opened (entered flag) - the old `depth < 0` test only fired at the ENCLOSING emitter's
// close, so a sizeGraph earlier in the emitter swallowed the colorGraph that followed it
// (regen 2026-07-17 shipped a WHITE trail: "tinted 0"). Rows only match inside open braces.
let mode = null, depth = 0, entered = false, tinted = 0, scaled = 0;
let unpinned = 0;
const out = lines.map((line) => {
  if (!mode) {
    if (world && /^\s*flags .*spawnRelative/.test(line)) {
      unpinned++;
      return line.replace(/ ?spawnRelative/, '').replace(/ ?runRelToEffect/, '');
    }
    // SIZE = the HEADER scale on the `sizeGraphN <scale>` line, NOT the curve rows: the
    // curves are normalized and CLAMP - scaling rows x3 changed nothing visibly (user
    // caught it 2026-07-18: "still look tiny and you said you made it larger").
    if (scale) {
      const sm = line.match(/^(\s*sizeGraph\d?) (-?[0-9.]+)(.*)$/);
      if (sm) { scaled++; return `${sm[1]} ${(parseFloat(sm[2]) * scale)}${sm[3]}`; }
    }
    if (/^\s*colorGraph\b/.test(line)) { mode = 'color'; depth = 0; entered = false; return line; }
    return line;
  }
  depth += (line.match(/{/g) || []).length - (line.match(/}/g) || []).length;
  if (depth >= 1) entered = true;
  let outLine = line;
  if (entered && depth >= 1 && mode === 'color') {
    const m = line.match(/^(\s*)(-?[0-9.]+) (-?[0-9.]+) (-?[0-9.]+) (-?[0-9.]+)\s*$/);
    if (m) { tinted++; outLine = `${m[1]}${m[2]} ${r} ${g} ${b}`; }
  }
  if (entered && depth <= 0) mode = null;   // this graph's braces closed - block done
  return outLine;
});
fs.mkdirSync(require('path').dirname(dst), { recursive: true });
fs.writeFileSync(dst, out.join('\n'));
console.log(`tinted ${tinted} colorGraph rows${scale ? `, scaled ${scaled} sizeGraph HEADERS x${scale}` : ''}${world ? `, unpinned ${unpinned} emitters to world space` : ''} -> ${dst}`);
