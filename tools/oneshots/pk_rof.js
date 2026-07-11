'use strict';
// Peacekeeper rate of fire +25%  ->  fireTime 0.2 -> 0.16, ONLY inside apex_peacekeeper
// entries (base / _up / 6 perk twins), NOT the unused legend_* or any other weapon in
// these shared install GDTs. Backs each file up to <file>.acc-pk-rof-orig first.
const fs = require('fs');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const FILES = [
  SD + '/zeroy/APEX_BO3.gdt',        // apex_peacekeeper_zm  (base)
  SD + '/acc_apex_up.gdt',           // apex_peacekeeper_up_zm
  SD + '/acc_weapon_variants.gdt',   // 6 perk twins
];
const OLD = '"fireTime" "0.2"', NEW = '"fireTime" "0.16"';
const ALLOW = /^apex_peacekeeper(_up)?(_acc_(recoil50|fastreload|recoil50_fastreload))?_zm$/;
const HDR = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;

let grand = 0;
for (const f of FILES) {
  if (!fs.existsSync(f)) { console.error('MISSING', f); process.exit(2); }
  const bak = f + '.acc-pk-rof-orig';
  if (!fs.existsSync(bak)) fs.copyFileSync(f, bak);
  let lines = fs.readFileSync(f, 'utf8').split('\n');
  let cur = null, depth = 0, changed = 0;
  const touched = [];
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(HDR);
    if (h) { cur = h[1]; depth = 0; }
    // track brace depth so `cur` only applies within its block
    depth += (lines[i].match(/{/g) || []).length - (lines[i].match(/}/g) || []).length;
    if (cur && ALLOW.test(cur) && lines[i].includes(OLD)) {
      lines[i] = lines[i].replace(OLD, NEW);
      changed++; touched.push(cur);
    }
  }
  fs.writeFileSync(f, lines.join('\n'));
  grand += changed;
  console.log(`${f.split('/').pop()}: ${changed} fireTime edits [${touched.join(', ')}]`);
}
console.log(`TOTAL ${grand} (expected 8: base + up + 6 twins)`);
if (grand !== 8) { console.error('!! unexpected total - REVIEW'); process.exit(3); }
