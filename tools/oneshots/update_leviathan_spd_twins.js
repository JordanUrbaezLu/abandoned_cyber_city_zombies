#!/usr/bin/env node
// update_leviathan_spd_twins.js (2026-07-09) - retune the 3 Leviathan spd twins in place from
// +5%/tier (x0.95) to +10%/tier (x0.90 compounding) off the 0.48/0.52 base. Edits the existing
// blocks in both acc_weapon_variants.gdt copies (install + repo); reports each field change.
'use strict';
const fs = require('fs');

const OUTS = [
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/acc_weapon_variants.gdt',
  'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/source_data/acc_weapon_variants.gdt',
];
// x0.90 per tier compounding off base fireTime 0.48 / meleeTime 0.52
const TWINS = {
  leviathan_acc_spd1_zm:    { fireTime: '0.432', meleeTime: '0.468' },   // t1  x0.90
  leviathan_up_acc_spd2_zm: { fireTime: '0.389', meleeTime: '0.421' },   // t2  x0.81
  leviathan_up_acc_spd3_zm: { fireTime: '0.35',  meleeTime: '0.379' },   // t3  x0.729
};

function blockRange(lines, name) {
  const start = lines.findIndex(l => new RegExp('^\\s*"' + name + '"\\s*\\(').test(l));
  if (start < 0) throw new Error('block not found: ' + name);
  let end = -1;
  for (let i = start + 1; i < lines.length; i++) if (/^\s*\}\s*$/.test(lines[i])) { end = i; break; }
  if (end < 0) throw new Error('unterminated block: ' + name);
  return [start, end];
}

for (const out of OUTS) {
  const raw = fs.readFileSync(out, 'utf8');
  const eol = raw.includes('\r\n') ? '\r\n' : '\n';
  const lines = raw.split(/\r?\n/);
  let changed = 0;
  for (const [id, fields] of Object.entries(TWINS)) {
    const [s, e] = blockRange(lines, id);
    for (const [k, v] of Object.entries(fields)) {
      let hit = 0;
      for (let i = s + 1; i < e; i++) {
        const m = lines[i].match(new RegExp('^(\\s*)"' + k + '" "([^"]*)"(.*)$'));
        if (m) { if (m[2] !== v) { console.log(`  ${id}.${k} ${m[2]} -> ${v}`); changed++; } lines[i] = `${m[1]}"${k}" "${v}"${m[3]}`; hit++; }
      }
      if (hit !== 1) throw new Error(`${id}.${k}: matched ${hit} lines (expected 1)`);
    }
  }
  fs.writeFileSync(out, lines.join(eol));
  console.log(`== ${out} (${changed} fields changed)`);
}
