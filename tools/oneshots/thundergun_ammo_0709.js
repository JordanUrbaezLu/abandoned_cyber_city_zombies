#!/usr/bin/env node
// thundergun_ammo_0709.js - fix the Thundergun rounds-vs-mags ammo typo (user 2026-07-09):
// the t5 port copied stock BO1 ROUND counts (base 2/12, Zeus 4/24) into maxAmmo/startAmmo,
// but the engine reads MAGAZINES (reserve = maxAmmo x clipSize) -> in-game 24/96 reserve.
// Fix: maxAmmo/startAmmo -> 6 on all four blocks (6x2=12 and 6x4=24 = exact stock reserves).
// Same error class + fix as the Blast-O-Matic 110 (blasto_ammo_mors_ft_0709.js).
'use strict';
const fs = require('fs');
const path = require('path');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const JOBS = [
  { file: 'night_t5_thundergun.gdt', tag: 'tg-ammo', blocks: ['thundergun_zm', 'thundergun_upgraded_zm'] },
  { file: 'acc_weapon_variants.gdt', tag: 'tg-ammo', blocks: ['thundergun_acc_fastreload_zm', 'thundergun_upgraded_acc_fastreload_zm'] },
];
for (const job of JOBS) {
  const file = path.join(SD, job.file);
  const bak = file + '.acc-' + job.tag + '-orig';
  if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);
  let txt = fs.readFileSync(file, 'utf8');
  for (const name of job.blocks) {
    const m = new RegExp('(^|\\n)\\t"' + name + '"\\s*\\(\\s*"[^"]+"\\s*\\)').exec(txt);
    if (!m) { console.error('BLOCK NOT FOUND: ' + name); process.exitCode = 1; continue; }
    const start = m.index, end = txt.indexOf('\n\t}', start);
    let body = txt.substring(start, end), n = 0;
    for (const k of ['maxAmmo', 'startAmmo']) {
      body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (a, pre, old, post) => { n++; console.log(name + ' :: ' + k + ' ' + old + ' -> 6'); return pre + '6' + post; });
    }
    if (n !== 2) { console.error('EXPECTED 2 fields on ' + name + ', got ' + n); process.exitCode = 1; }
    txt = txt.substring(0, start) + body + txt.substring(end);
  }
  fs.writeFileSync(file, txt);
}
console.log('DONE');
