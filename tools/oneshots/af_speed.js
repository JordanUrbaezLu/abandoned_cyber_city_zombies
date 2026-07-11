'use strict';
// Action Figure hit speed +25% => melee timings x0.8, on the PRIMARY swing fields
// (meleeTime / meleeChargeDelay / meleeChargeTime - the FIRST occurrence per entry; the
// base entry also has a secondary 0.25/1.0/0.4 set we leave alone, matching the twin gen
// tool's scope). Applied to base t8_melee_figure + fast1/2/3. x0.8 preserves base/mult so
// this equals regenerating the twins from a 0.52 base (see gen_actionfigure_speed_twins.js).
const fs = require('fs');
const F = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/t8_weapons/wpn_t8_melee_actionfigure.gdt';
const bak = F + '.acc-hitspeed-orig';
if (!fs.existsSync(F)) { console.error('MISSING', F); process.exit(2); }
if (!fs.existsSync(bak)) fs.copyFileSync(F, bak);

let lines = fs.readFileSync(F, 'utf8').split('\n');
const HDR = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;
const ENTRY = /^t8_melee_figure(_fast[123])?$/;
const FIELDS = ['meleeTime', 'meleeChargeDelay', 'meleeChargeTime'];

function trim(n) { let s = n.toFixed(4); if (s.indexOf('.') >= 0) s = s.replace(/0+$/, '').replace(/\.$/, ''); return s; }

let cur = null;
const done = {};   // entry -> Set(field) already replaced (first occurrence only)
let total = 0;
const log = [];
for (let i = 0; i < lines.length; i++) {
  const h = lines[i].match(HDR);
  if (h) { cur = h[1]; if (ENTRY.test(cur) && !done[cur]) done[cur] = new Set(); continue; }
  if (!cur || !ENTRY.test(cur)) continue;
  for (const f of FIELDS) {
    if (done[cur].has(f)) continue;
    const m = lines[i].match(new RegExp('^(\\s*"' + f + '"\\s+")([0-9.]+)(")'));
    if (!m) continue;
    const oldV = m[2], newV = trim(parseFloat(oldV) * 0.8);
    lines[i] = m[1] + newV + m[3];
    done[cur].add(f); total++;
    log.push(`${cur}.${f}: ${oldV} -> ${newV}`);
    break; // one field per line
  }
}
fs.writeFileSync(F, lines.join('\n'));
for (const l of log) console.log('  ' + l);
console.log(`TOTAL ${total} (expected 12: 4 entries x 3 fields)`);
if (total !== 12) { console.error('!! unexpected total - REVIEW'); process.exit(3); }
