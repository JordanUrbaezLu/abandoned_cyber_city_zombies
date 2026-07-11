#!/usr/bin/env node
// =============================================================================
// reload_balance_0709.js - SURGICAL reload retune (user 2026-07-09), house pattern:
// per-file .acc-reload0709-orig backup once, then scale/set reload fields in
// EXACT-NAMED blocks in the LIVE install GDTs (base + _up + every twin), so the
// base gun and all perk twins keep their relative factors (fastreload = x0.857).
//
//   Havoc  x1.15 (nerf 15%)   AK-74u x0.70 (buff 30%)   AE4  x1.50 (nerf 50%)
//   XM4    x1.50 (nerf 50%)   PPSH   x0.50 (buff 50%)   Olympia x0.70 (buff 30%)
//   Prowler x0.80 (buff 20%)  Thundergun reloadEmptyTime -> 4.2 (twins 4.2x0.857)
//
// Skipped on purpose: s4_ppsh41_drum(_up) + apex *_legend_0*_zm blocks (not zoned,
// never ship). Scales the same RELOAD_KEYS set gen_weapon_variant_gdt.js owns.
// The 5 tool-managed skye guns also get baseline {reload} entries in
// apply_recoil_overhaul.js so a future full re-run reproduces this pass.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';

const RELOAD_KEYS = [
  'reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime',
];

// file -> [ [blockName, {scale: f}] or [blockName, {set: {key: val}}] ]
const EDITS = {
  'skye_s1_ae4.gdt': [
    ['s1_ae4', { scale: 1.5 }], ['s1_ae4_up', { scale: 1.5 }],
  ],
  'skye_t9_xm4.gdt': [
    ['t9_xm4', { scale: 1.5 }], ['t9_xm4_up', { scale: 1.5 }],
  ],
  'skye_s4_ppsh-41.gdt': [
    ['s4_ppsh41_base', { scale: 0.5 }], ['s4_ppsh41_base_up', { scale: 0.5 }],
  ],
  'skye_t6_olympia.gdt': [
    ['t6_olympia', { scale: 0.7 }], ['t6_olympia_up', { scale: 0.7 }],
  ],
  'skye_t9_ak-74u.gdt': [
    ['t9_ak74u', { scale: 0.7 }], ['t9_ak74u_up', { scale: 0.7 }],
  ],
  'zeroy/APEX_BO3.gdt': [
    ['apex_beam_rifle_zm', { scale: 1.15 }],
    ['apex_prowler_zm', { scale: 0.8 }],
  ],
  'acc_apex_up.gdt': [
    ['apex_beam_rifle_up_zm', { scale: 1.15 }],
    ['apex_prowler_up_zm', { scale: 0.8 }],
  ],
  'night_t5_thundergun.gdt': [
    ['thundergun_zm', { set: { reloadEmptyTime: '4.2' } }],
    ['thundergun_upgraded_zm', { set: { reloadEmptyTime: '4.2' } }],
  ],
  'acc_weapon_variants.gdt': [],
};

// twin blocks in acc_weapon_variants.gdt (exact names from the 2026-07-09 inventory)
const V = EDITS['acc_weapon_variants.gdt'];
const combos3 = ['acc_fastreload', 'acc_recoil50', 'acc_recoil50_fastreload'];
for (const form of ['s1_ae4', 's1_ae4_up']) for (const c of combos3) V.push([`${form}_${c}`, { scale: 1.5 }]);
for (const form of ['t9_xm4', 't9_xm4_up']) for (const c of combos3) V.push([`${form}_${c}`, { scale: 1.5 }]);
for (const form of ['s4_ppsh41_base', 's4_ppsh41_base_up']) for (const c of combos3) V.push([`${form}_${c}`, { scale: 0.5 }]);
for (const form of ['t6_olympia', 't6_olympia_up']) for (const c of combos3) V.push([`${form}_${c}`, { scale: 0.7 }]);
for (const form of ['t9_ak74u', 't9_ak74u_up']) for (const c of combos3) V.push([`${form}_${c}`, { scale: 0.7 }]);
// apex twins carry the _zm suffix AFTER the combo token
for (const form of ['apex_prowler', 'apex_prowler_up'])
  for (const c of combos3) V.push([`${form}_${c}_zm`, { scale: 0.8 }]);
const havocCombos = combos3.concat(['acc_turbo', 'acc_recoil50_turbo', 'acc_fastreload_turbo', 'acc_recoil50_fastreload_turbo']);
for (const form of ['apex_beam_rifle', 'apex_beam_rifle_up'])
  for (const c of havocCombos) V.push([`${form}_${c}_zm`, { scale: 1.15 }]);
// thundergun fastreload twins: empty = 4.2 x 0.857
V.push(['thundergun_acc_fastreload_zm', { set: { reloadEmptyTime: '3.5994' } }]);
V.push(['thundergun_upgraded_acc_fastreload_zm', { set: { reloadEmptyTime: '3.5994' } }]);

const round4 = (x) => String(parseFloat(x.toFixed(4)));

let totalBlocks = 0, totalFields = 0;
for (const [rel, blocks] of Object.entries(EDITS)) {
  const file = path.join(SD, rel);
  if (!fs.existsSync(file)) { console.error(`MISSING FILE: ${file}`); process.exitCode = 1; continue; }
  const bak = file + '.acc-reload0709-orig';
  if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);

  let txt = fs.readFileSync(file, 'utf8');
  for (const [name, op] of blocks) {
    const hdr = new RegExp('(^|\\n)\\t"' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"\\s*\\(\\s*"[^"]+"\\s*\\)');
    const m = hdr.exec(txt);
    if (!m) { console.error(`BLOCK NOT FOUND: ${name} in ${rel}`); process.exitCode = 1; continue; }
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    if (end === -1) { console.error(`BLOCK END NOT FOUND: ${name} in ${rel}`); process.exitCode = 1; continue; }
    let body = txt.substring(start, end);
    let fields = 0;

    if (op.scale !== undefined) {
      for (const k of RELOAD_KEYS) {
        body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (all, pre, val, post) => {
          const num = parseFloat(val);
          if (!isFinite(num) || num === 0) return all;   // 0 / empty stays as-is
          fields++;
          return pre + round4(num * op.scale) + post;
        });
      }
    }
    if (op.set !== undefined) {
      for (const [k, v] of Object.entries(op.set)) {
        body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (all, pre, _val, post) => { fields++; return pre + v + post; });
      }
    }
    txt = txt.substring(0, start) + body + txt.substring(end);
    totalBlocks++; totalFields += fields;
    console.log(`${rel} :: ${name} -> ${fields} field(s) ${op.scale !== undefined ? 'x' + op.scale : 'set'}`);
  }
  fs.writeFileSync(file, txt);
}
console.log(`\nDONE: ${totalBlocks} blocks, ${totalFields} fields. Backups: *.acc-reload0709-orig`);
