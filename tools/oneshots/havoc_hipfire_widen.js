#!/usr/bin/env node
// Havoc (apex_beam_rifle) hipfire -25% ACCURACY = hip-spread x1.25 (WIDER cone), user 2026-07-06.
// Patches EVERY apex_beam_rifle entry (base + _up + chg1..4 both forms + legend skins) across all GDTs.
// Usage: node havoc_hipfire_widen.js [--apply]   (default = dry run)
const fs = require('fs');
const path = require('path');
const SRC = path.join(process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130', 'source_data');
const APPLY = process.argv.includes('--apply');
const MULT = 1.25;
// The hip-spread cone fields. NOT touching ADS spread (adsSpread) or gunkick/recoil.
const FIELDS = ['hipSpreadStandMin', 'hipSpreadDuckedMin', 'hipSpreadProneMin',
  'hipSpreadMax', 'hipSpreadDuckedMax', 'hipSpreadProneMax', 'hipSpreadFireAdd'];

function listGdts(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(listGdts(p));
    else if (e.name.endsWith('.gdt')) out.push(p);
  }
  return out;
}
function round1(v) { return Math.round(v * 10) / 10; }

let total = 0, entriesHit = 0;
for (const p of listGdts(SRC)) {
  let txt = fs.readFileSync(p, 'utf8');
  const re = /"(apex_beam_rifle[^"]*)"\s*\(\s*"[^"]*\.gdf"\s*\)/g;
  let m; const patches = [];
  while ((m = re.exec(txt)) !== null) {
    const name = m[1];
    const open = txt.indexOf('{', m.index);
    if (open < 0) continue;
    let depth = 0, end = -1;
    for (let i = open; i < txt.length; i++) {
      if (txt[i] === '{') depth++;
      else if (txt[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
    }
    if (end < 0) continue;
    let block = txt.slice(open, end + 1);
    if (!/"hipSpreadStandMin"/.test(block)) continue;   // skip anim/attachment sub-entries
    let changed = false;
    for (const fld of FIELDS) {
      const fre = new RegExp('("' + fld + '"\\s+")([\\-\\d.]+)(")');
      const fm = block.match(fre);
      if (!fm) continue;
      const oldV = parseFloat(fm[2]);
      const newV = round1(oldV * MULT);
      if (newV === oldV) continue;
      console.log(`${path.relative(SRC, p)}  ${name}  ${fld}: ${oldV} -> ${newV}`);
      block = block.replace(fre, '$1' + newV + '$3');
      changed = true; total++;
    }
    if (changed) { patches.push({ start: open, end: end + 1, block }); entriesHit++; }
  }
  if (patches.length && APPLY) {
    for (const pt of patches.sort((a, b) => b.start - a.start))
      txt = txt.slice(0, pt.start) + pt.block + txt.slice(pt.end);
    fs.writeFileSync(p, txt);
    console.log(`  [written] ${path.relative(SRC, p)}`);
  }
}
console.log(`\n${APPLY ? 'APPLIED' : 'DRY RUN'}: ${total} field changes across ${entriesHit} entries.`);
