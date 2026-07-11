#!/usr/bin/env node
// Fix "Damage range distances went backwards" linker error introduced by
// shotgun_range_45_pk_best.js, which scaled maxDamageRange/minDamageRange x0.55 but
// LEFT damageRange2 untouched. Originally damageRange2 sat at/below minDamageRange;
// after the min cut, damageRange2 > minDamageRange => the falloff breakpoints are
// non-monotonic and the linker aborts. Fix: clamp each def's damageRange2 down to its
// own minDamageRange (== scaling dR2 by the same factor for the 3 shotguns where
// dR2==minDR originally; a safe clamp for CEL-3 where it was slightly below).
const fs = require('fs');
const path = require('path');
const SRC = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const APPLY = process.argv.includes('--apply');
const FILES = [
  'skye_s1_tac-19.gdt',
  'skye_t6_olympia.gdt',
  'skye_t9_streetsweeper.gdt',
  'skye_s1_cel-3_cauterizer.gdt',
];
const numRe = f => new RegExp('"' + f + '"\\s+"([\\-\\d.]+)"', 'g');
let totalFixed = 0;
for (const fn of FILES) {
  const p = path.join(SRC, fn);
  if (!fs.existsSync(p)) { console.log('MISSING', fn); continue; }
  let txt = fs.readFileSync(p, 'utf8');
  // collect numeric minDamageRange positions/values
  const mins = [];
  for (const m of txt.matchAll(numRe('minDamageRange'))) mins.push({ pos: m.index, val: m[1] });
  // for each numeric damageRange2, pair with the FIRST minDamageRange occurring after it (same def)
  const edits = [];
  for (const m of txt.matchAll(numRe('damageRange2'))) {
    const d2pos = m.index, d2val = parseFloat(m[1]);
    const nextMin = mins.find(x => x.pos > d2pos);
    if (!nextMin) continue;
    const minVal = parseFloat(nextMin.val);
    if (d2val > minVal) {
      // replace this exact occurrence's numeric value with the min string (verbatim, keeps format)
      const start = m.index, whole = m[0];
      const replaced = whole.replace(/("damageRange2"\s+")([\-\d.]+)(")/, '$1' + nextMin.val + '$3');
      edits.push({ start, len: whole.length, from: whole, to: replaced, d2val, minVal, minStr: nextMin.val });
    }
  }
  if (!edits.length) { console.log(`${fn}: no backwards defs`); continue; }
  console.log(`\n${fn}:`);
  for (const e of edits) console.log(`   damageRange2 ${e.d2val} -> ${e.minStr}   (minDamageRange=${e.minVal})`);
  if (APPLY) {
    // apply from the end so positions stay valid
    edits.sort((a, b) => b.start - a.start);
    for (const e of edits) txt = txt.slice(0, e.start) + e.to + txt.slice(e.start + e.len);
    fs.writeFileSync(p, txt);
    console.log(`   [written] ${edits.length} fix(es)`);
  }
  totalFixed += edits.length;
}
console.log(`\n${APPLY ? 'APPLIED' : 'DRY RUN'}: ${totalFixed} damageRange2 clamp(s) across ${FILES.length} shotgun GDTs.`);
