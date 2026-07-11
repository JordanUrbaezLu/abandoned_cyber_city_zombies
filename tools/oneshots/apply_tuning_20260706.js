#!/usr/bin/env node
// One-off tuning pass (user 2026-07-06):
//   1. CEL-3 clip + mags -50%          (clipSize x0.5, maxAmmo x0.5)
//   2. ALL shotguns range -25%         (maxDamageRange/minDamageRange x0.75)
//   3. AK-47 reserve +25%              (maxAmmo x1.25, rounded)
// Patches EVERY matching entry (base + _up + perk twins) across ALL deployed
// source_data GDTs - same IsSubStr philosophy as acc_weapon_balance_mult.
// Usage: node apply_tuning_20260706.js [--apply]   (default = dry run)
const fs = require('fs');
const path = require('path');
const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SRC = path.join(TOOLS, 'source_data');
const APPLY = process.argv.includes('--apply');

const SHOTGUNS = ['s1_tac19', 't6_olympia', 't9_streetsweeper', 's1_cel3', 'apex_peacekeeper'];

// key -> list of {field, mult, int}
function rulesFor(entryName) {
  const r = [];
  if (SHOTGUNS.some(k => entryName.includes(k))) {
    r.push({ field: 'maxDamageRange', mult: 0.75, int: false });
    r.push({ field: 'minDamageRange', mult: 0.75, int: false });
  }
  if (entryName.includes('s1_cel3')) {
    r.push({ field: 'clipSize', mult: 0.5, int: true });
    r.push({ field: 'maxAmmo', mult: 0.5, int: true });
  }
  if (entryName.includes('t9_ak47')) {
    r.push({ field: 'maxAmmo', mult: 1.25, int: true });
  }
  return r;
}

function listGdts(dir) {
  let out = [];
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) out = out.concat(listGdts(p));          // e.g. source_data/zeroy/APEX_BO3.gdt
    else if (e.name.endsWith('.gdt')) out.push(p);
  }
  return out;
}

let totalChanges = 0;
for (const p of listGdts(SRC)) {
  const f = path.relative(SRC, p);
  let txt = fs.readFileSync(p, 'utf8');
  let fileChanged = false;

  // walk top-level entries: "name" ( "template.gdf" ) { ... }
  const entryRe = /"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)/g;
  let m;
  const patches = [];   // {start,end,newBlock} - apply in reverse
  while ((m = entryRe.exec(txt)) !== null) {
    const name = m[1];
    const rules = rulesFor(name);
    if (!rules.length) continue;
    const open = txt.indexOf('{', m.index);
    if (open < 0) continue;
    let depth = 0, end = -1;
    for (let i = open; i < txt.length; i++) {
      if (txt[i] === '{') depth++;
      else if (txt[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
    }
    if (end < 0) continue;
    let block = txt.slice(open, end + 1);
    let blockChanged = false;
    for (const rule of rules) {
      const fre = new RegExp('("' + rule.field + '"\\s+")([\\-\\d.]+)(")');
      const fm = block.match(fre);
      if (!fm) continue;                            // field absent on this entry (e.g. wallbuy struct) - skip
      const oldV = parseFloat(fm[2]);
      let newV = oldV * rule.mult;
      newV = rule.int ? Math.max(1, Math.round(newV)) : Math.round(newV * 10) / 10;
      if (newV === oldV) continue;
      console.log(`${f}  ${name}  ${rule.field}: ${oldV} -> ${newV}`);
      block = block.replace(fre, '$1' + newV + '$3');
      blockChanged = true;
      totalChanges++;
    }
    if (blockChanged) { patches.push({ start: open, end: end + 1, block }); fileChanged = true; }
  }
  if (fileChanged && APPLY) {
    for (const pt of patches.sort((a, b) => b.start - a.start))
      txt = txt.slice(0, pt.start) + pt.block + txt.slice(pt.end);
    fs.writeFileSync(p, txt);
    console.log(`  [written] ${f}`);
  }
}
console.log(`\n${APPLY ? 'APPLIED' : 'DRY RUN'}: ${totalChanges} field changes.`);
