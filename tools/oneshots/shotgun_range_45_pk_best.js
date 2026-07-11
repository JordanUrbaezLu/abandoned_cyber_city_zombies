#!/usr/bin/env node
// user 2026-07-06: (a) deepen shotgun range -35% -> -45% TOTAL off original (x0.55); apply the
// extra x(0.55/0.65) to the 4 non-Peacekeeper shotguns' current (-35%) range fields. (b) Peacekeeper
// becomes the BEST-range shotgun: SET absolute max 550 / min 1100 (clearly above post-cut Tac-19 ~454).
// Hits every entry (base + _up + twins + skins). Usage: node ... [--apply]  (default dry run)
const fs = require('fs');
const path = require('path');
const SRC = path.join(process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130', 'source_data');
const APPLY = process.argv.includes('--apply');
const MULT = 0.55 / 0.65;                          // current(-35%) -> target(-45%)
const OTHERS = ['s1_tac19', 't6_olympia', 't9_streetsweeper', 's1_cel3'];
const PK = 'apex_peacekeeper';
const PK_SET = { maxDamageRange: 550, minDamageRange: 1100 };   // best-range shotgun
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

let total = 0, ent = 0;
for (const p of listGdts(SRC)) {
  let txt = fs.readFileSync(p, 'utf8');
  const re = /"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)/g;
  let m; const patches = [];
  while ((m = re.exec(txt)) !== null) {
    const name = m[1];
    const isPK = name.includes(PK);
    const isOther = OTHERS.some(k => name.includes(k));
    if (!isPK && !isOther) continue;
    const open = txt.indexOf('{', m.index);
    if (open < 0) continue;
    let depth = 0, end = -1;
    for (let i = open; i < txt.length; i++) {
      if (txt[i] === '{') depth++;
      else if (txt[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
    }
    if (end < 0) continue;
    let block = txt.slice(open, end + 1);
    if (!/"maxDamageRange"/.test(block)) continue;
    let changed = false;
    for (const fld of FIELDS) {
      const fre = new RegExp('("' + fld + '"\\s+")([\\-\\d.]+)(")');
      const fm = block.match(fre);
      if (!fm) continue;
      const oldV = parseFloat(fm[2]);
      const newV = isPK ? PK_SET[fld] : r1(oldV * MULT);
      if (newV === oldV) continue;
      console.log(`${(isPK ? 'PK  ' : 'cut ')}${path.relative(SRC, p)}  ${name.padEnd(44)} ${fld}: ${oldV} -> ${newV}`);
      block = block.replace(fre, '$1' + newV + '$3');
      changed = true; total++;
    }
    if (changed) { patches.push({ start: open, end: end + 1, block }); ent++; }
  }
  if (patches.length && APPLY) {
    for (const pt of patches.sort((a, b) => b.start - a.start))
      txt = txt.slice(0, pt.start) + pt.block + txt.slice(pt.end);
    fs.writeFileSync(p, txt);
    console.log(`  [written] ${path.relative(SRC, p)}`);
  }
}
console.log(`\n${APPLY ? 'APPLIED' : 'DRY RUN'}: ${total} field changes across ${ent} entries.`);
