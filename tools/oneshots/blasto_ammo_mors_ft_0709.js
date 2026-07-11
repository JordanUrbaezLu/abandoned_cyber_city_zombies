#!/usr/bin/env node
// =============================================================================
// blasto_ammo_mors_ft_0709.js - two surgical GDT fixes (user 2026-07-09):
//  1. Blast-O-Matic PaP ammo DATA ERROR: t9_semiauto_cosplay_up maxAmmo/startAmmo=110
//     was authored as ROUNDS but the engine reads MAGAZINES (reduce_base_ammo.js header:
//     reserve = maxAmmo x clipSize) -> in-game reserve 20x110=2200. Same error class as
//     the PDW maxAmmo=920 already clamped by MAXAMMO_FIX. Fix: 110 -> 6 mags (6x20=120
//     rounds, the porter's ~110-round intent; base form 5x12=60 is sane, untouched).
//     Applied to the _up block + its 3 hand-built twins.
//  2. MORS fire-rate buff: fireTime 0.064 -> 0.05 on base + _up + all 6 twins
//     (the +10% damage half of the buff is GSC-side: acc_weapon_balance_mult).
// House pattern: one-shot .acc-<tag>-orig backup per file before editing.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';

// file -> tag -> [ [block, {set:{field:value}}] ]
const JOBS = [
  {
    file: 'owens_weapons/bocw/wpn_t9_shotgun_semiauto_cb_cosplay.gdt', tag: 'blasto-ammo',
    edits: [['t9_semiauto_cosplay_up', { maxAmmo: '6', startAmmo: '6' }]],
  },
  {
    file: 'skye_s1_mors.gdt', tag: 'mors-ft',
    edits: [['s1_mors', { fireTime: '0.05' }], ['s1_mors_up', { fireTime: '0.05' }]],
  },
  {
    file: 'acc_weapon_variants.gdt', tag: 'blasto-ammo-mors-ft',
    edits: [
      ['t9_semiauto_cosplay_up_acc_recoil50', { maxAmmo: '6', startAmmo: '6' }],
      ['t9_semiauto_cosplay_up_acc_fastreload', { maxAmmo: '6', startAmmo: '6' }],
      ['t9_semiauto_cosplay_up_acc_recoil50_fastreload', { maxAmmo: '6', startAmmo: '6' }],
      ['s1_mors_acc_fastreload', { fireTime: '0.05' }],
      ['s1_mors_acc_recoil50', { fireTime: '0.05' }],
      ['s1_mors_acc_recoil50_fastreload', { fireTime: '0.05' }],
      ['s1_mors_up_acc_fastreload', { fireTime: '0.05' }],
      ['s1_mors_up_acc_recoil50', { fireTime: '0.05' }],
      ['s1_mors_up_acc_recoil50_fastreload', { fireTime: '0.05' }],
    ],
  },
];

for (const job of JOBS) {
  const file = path.join(SD, job.file);
  if (!fs.existsSync(file)) { console.error('MISSING FILE: ' + file); process.exitCode = 1; continue; }
  const bak = file + '.acc-' + job.tag + '-orig';
  if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);
  let txt = fs.readFileSync(file, 'utf8');
  for (const [name, sets] of job.edits) {
    const hdr = new RegExp('(^|\\n)\\t"' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"\\s*\\(\\s*"[^"]+"\\s*\\)');
    const m = hdr.exec(txt);
    if (!m) { console.error('BLOCK NOT FOUND: ' + name + ' in ' + job.file); process.exitCode = 1; continue; }
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    let body = txt.substring(start, end);
    let n = 0;
    for (const [k, v] of Object.entries(sets)) {
      const before = body;
      body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (all, pre, old, post) => { n++; console.log(job.file + ' :: ' + name + ' :: ' + k + ' ' + old + ' -> ' + v); return pre + v + post; });
      if (body === before) { console.error('FIELD NOT FOUND: ' + k + ' on ' + name); process.exitCode = 1; }
    }
    txt = txt.substring(0, start) + body + txt.substring(end);
  }
  fs.writeFileSync(file, txt);
}
console.log('DONE');
