#!/usr/bin/env node
// Shotgun range: deepen the nerf from -25% to -35% TOTAL off the pre-nerf value (user 2026-07-06).
// Current deployed = original x0.75; target = original x0.65 -> multiply CURRENT by 0.65/0.75.
// Hits every shotgun entry that carries the range fields (base + _up + perk twins + legend skins).
// Usage: node shotgun_range_35.js [--apply]   (default = dry run)
const fs = require('fs');
const path = require('path');
const SRC = path.join(process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130', 'source_data');
const APPLY = process.argv.includes('--apply');
const MULT = 0.65 / 0.75;                     // current(x0.75) -> target(x0.65)
const SHOTGUNS = ['s1_tac19', 't6_olympia', 't9_streetsweeper', 's1_cel3', 'apex_peacekeeper'];
const FIELDS = ['maxDamageRange', 'minDamageRange'];

function listGdts(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(listGdts(p));
    else if (e.name.endsWith('.gdt')) out.push(p);
  }
  return out;
}
const r1 = v => Math.round(v * 10) / 10;

let total = 0, entries = 0;
for (const p of listGdts(SRC)) {
  let txt = fs.readFileSync(p, 'utf8');
  const re = /"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)/g;
  let m; const patches = [];
  while ((m = re.exec(txt)) !== null) {
    const name = m[1];
    if (!SHOTGUNS.some(k => name.includes(k))) continue;
    const open = txt.indexOf('{', m.index);
    if (open < 0) continue;
    let depth = 0, end = -1;
    for (let i = open; i < txt.length; i++) {
      if (txt[i] === '{') depth++;
      else if (txt[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
    }
    if (end < 0) continue;
    let block = txt.slice(open, end + 1);
    if (!/"maxDamageRange"/.test(block)) continue;   // skip anim/attachment sub-entries
    let changed = false;
    for (const fld of FIELDS) {
      const fre = new RegExp('("' + fld + '"\\s+")([\\-\\d.]+)(")');
      const fm = block.match(fre);
      if (!fm) continue;
      const oldV = parseFloat(fm[2]);
      const newV = r1(oldV * MULT);
      const orig = r1(oldV / 0.75);               // implied pre-nerf value, for the log
      if (newV === oldV) continue;
      console.log(`${path.relative(SRC, p)}  ${name.padEnd(40)} ${fld}: ${oldV} -> ${newV}   (orig ~${orig} x0.65)`);
      block = block.replace(fre, '$1' + newV + '$3');
      changed = true; total++;
    }
    if (changed) { patches.push({ start: open, end: end + 1, block }); entries++; }
  }
  if (patches.length && APPLY) {
    for (const pt of patches.sort((a, b) => b.start - a.start))
      txt = txt.slice(0, pt.start) + pt.block + txt.slice(pt.end);
    fs.writeFileSync(p, txt);
    console.log(`  [written] ${path.relative(SRC, p)}`);
  }
}
console.log(`\n${APPLY ? 'APPLIED' : 'DRY RUN'}: ${total} field changes across ${entries} entries.`);
