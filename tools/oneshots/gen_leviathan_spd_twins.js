#!/usr/bin/env node
// gen_leviathan_spd_twins.js (2026-07-09) - Leviathan Axe PaP-tier SPEED twins (+5% swing/tier).
// Clones leviathan_zm / leviathan_up_zm from the WetEgg pack GDT into acc_weapon_variants.gdt
// (install + repo copies), renamed with the _acc_spdN token (_zm LAST - the apex _zm trap),
// scaling meleeTime (the real melee swing lever) + fireTime x0.95 per tier off the 0.48/0.52 base:
//   leviathan_acc_spd1_zm    (clone of base) fireTime 0.456  meleeTime 0.494   (tier 1)
//   leviathan_up_acc_spd2_zm (clone of _up)  fireTime 0.433  meleeTime 0.469   (tier 2)
//   leviathan_up_acc_spd3_zm (clone of _up)  fireTime 0.412  meleeTime 0.446   (tier 3)
'use strict';
const fs = require('fs');

const SRC = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/_custom/wetegg/leviathanaxe/leviathanaxe.gdt';
const OUTS = [
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/acc_weapon_variants.gdt',
  'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/source_data/acc_weapon_variants.gdt',
];
const TWINS = [
  { src: 'leviathan_zm',    id: 'leviathan_acc_spd1_zm',    fireTime: '0.456', meleeTime: '0.494' },
  { src: 'leviathan_up_zm', id: 'leviathan_up_acc_spd2_zm', fireTime: '0.433', meleeTime: '0.469' },
  { src: 'leviathan_up_zm', id: 'leviathan_up_acc_spd3_zm', fireTime: '0.412', meleeTime: '0.446' },
];

// extract a "<name>" ( "...gdf" ) block: header line .. its closing "}" line
function extractBlock(lines, name) {
  const head = new RegExp('^\\s*"' + name + '"\\s*\\(');
  const start = lines.findIndex(l => head.test(l));
  if (start < 0) throw new Error('block not found: ' + name);
  let end = -1;
  for (let i = start + 1; i < lines.length; i++) {
    if (/^\s*\}\s*$/.test(lines[i])) { end = i; break; }
  }
  if (end < 0) throw new Error('unterminated block: ' + name);
  return lines.slice(start, end + 1);
}

const srcLines = fs.readFileSync(SRC, 'utf8').split(/\r?\n/);
const blocks = TWINS.map(t => {
  const b = extractBlock(srcLines, t.src).slice();
  b[0] = b[0].replace('"' + t.src + '"', '"' + t.id + '"');
  let fSet = 0, mSet = 0;
  for (let i = 1; i < b.length; i++) {
    b[i] = b[i]
      .replace(/^(\s*)"fireTime" "[^"]*"/, (_, w) => { fSet++; return `${w}"fireTime" "${t.fireTime}"`; })
      .replace(/^(\s*)"meleeTime" "[^"]*"/, (_, w) => { mSet++; return `${w}"meleeTime" "${t.meleeTime}"`; });
  }
  if (fSet !== 1 || mSet !== 1) throw new Error(`${t.id}: fireTime x${fSet} meleeTime x${mSet} (expected 1 each)`);
  return b.join('\n');
});

for (const out of OUTS) {
  const raw = fs.readFileSync(out, 'utf8');
  const eol = raw.includes('\r\n') ? '\r\n' : '\n';
  if (TWINS.some(t => raw.includes('"' + t.id + '"'))) { console.log('SKIP (already present): ' + out); continue; }
  // GDT file = "{" ... "}" - insert the new blocks before the final closing brace
  const closeIdx = raw.lastIndexOf('}');
  if (closeIdx < 0) throw new Error('no closing brace: ' + out);
  const payload = blocks.join('\n').split('\n').join(eol) + eol;
  const next = raw.slice(0, closeIdx) + payload + raw.slice(closeIdx);
  fs.writeFileSync(out, next);
  console.log('APPENDED 3 leviathan spd twins -> ' + out);
}
