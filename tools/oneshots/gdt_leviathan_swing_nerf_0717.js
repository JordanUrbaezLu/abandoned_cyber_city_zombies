#!/usr/bin/env node
// One-shot 2026-07-17: Leviathan Axe -8% SWING SPEED nerf (user: "8% swing speed nerf",
// alongside the same-day ~15% boss hits-to-kill nerf in _acc_damage.gsc).
// fireTime + meleeTime x1.08 on ALL NINE axe defs, preserving every tier/Berzerker ratio:
//   WetEgg pack GDT (install-side _custom): leviathan_zm + leviathan_up_zm  0.55/0.52 -> 0.594/0.5616
//   acc_weapon_variants.gdt (install + repo): the 3 spd twins + the 4 _brz twins.
// meleeChargeTime (0.2) untouched - the established swing lever is meleeTime+fireTime
// (gen_leviathan_spd_twins.js / gdt_balance_0709.js precedent).
// Run from repo root: node tools/oneshots/gdt_leviathan_swing_nerf_0717.js
// After: <tools>\gdtdb\gdtdb.exe /update  ->  .\tools\build_map.ps1 -GscOnly
'use strict';
const fs = require('fs');

const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const REPO  = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';

const LEV_BASE = { fireTime: '0.594',  meleeTime: '0.5616' };  // 0.55 / 0.52  x1.08
const VARIANT_BLOCKS = {
  leviathan_acc_spd1_zm:        { fireTime: '0.5378', meleeTime: '0.5054' },  // 0.498 / 0.468
  leviathan_up_acc_spd2_zm:     { fireTime: '0.4871', meleeTime: '0.4547' },  // 0.451 / 0.421
  leviathan_up_acc_spd3_zm:     { fireTime: '0.4417', meleeTime: '0.4093' },  // 0.409 / 0.379
  leviathan_acc_brz_zm:         { fireTime: '0.4482', meleeTime: '0.416'  },  // 0.415 / 0.3852
  leviathan_acc_spd1_brz_zm:    { fireTime: '0.4072', meleeTime: '0.3744' },  // 0.377 / 0.3467
  leviathan_up_acc_spd2_brz_zm: { fireTime: '0.3694', meleeTime: '0.3369' },  // 0.342 / 0.3119
  leviathan_up_acc_spd3_brz_zm: { fireTime: '0.3359', meleeTime: '0.3032' },  // 0.311 / 0.2807
};

const JOBS = [
  { file: `${TOOLS}/_custom/wetegg/leviathanaxe/leviathanaxe.gdt`,
    blocks: { leviathan_zm: LEV_BASE, leviathan_up_zm: LEV_BASE } },
  { file: `${TOOLS}/source_data/acc_weapon_variants.gdt`, blocks: VARIANT_BLOCKS },
  { file: `${REPO}/source_data/acc_weapon_variants.gdt`,  blocks: VARIANT_BLOCKS },
];

for (const job of JOBS) {
  const raw = fs.readFileSync(job.file, 'utf8');
  // acc_weapon_variants.gdt has MIXED line endings (LF body + CRLF appended twin payloads) -
  // split AFTER each \n keeping every line's own terminator, so nothing is normalized.
  const lines = raw.split(/(?<=\n)/);
  const bak = job.file + '.acc-levi-swing0717-orig';
  if (!fs.existsSync(bak)) fs.writeFileSync(bak, raw);

  let cur = null, edited = {}, changed = 0;
  for (let i = 0; i < lines.length; i++) {
    const body = lines[i].replace(/\r?\n$/, '');
    const term = lines[i].slice(body.length);
    const head = body.match(/^\s*"([^"]+)"\s*\(\s*"[^"]*"\s*\)/);
    if (head) { cur = job.blocks[head[1]] ? head[1] : null; continue; }
    if (!cur) continue;
    if (/^\s*\}/.test(body)) { cur = null; continue; }
    const kv = body.match(/^(\s*)"([^"]+)" "([^"]*)"(.*)$/);
    if (!kv) continue;
    const want = job.blocks[cur][kv[2]];
    if (want !== undefined && kv[3] !== want) {
      lines[i] = `${kv[1]}"${kv[2]}" "${want}"${kv[4]}` + term;
      (edited[cur] = edited[cur] || []).push(`${kv[2]} ${kv[3]} -> ${want}`);
      changed++;
    }
  }
  fs.writeFileSync(job.file, lines.join(''));
  console.log(`== ${job.file} (${changed} fields)`);
  for (const b of Object.keys(job.blocks)) {
    console.log(`   ${b}: ` + (edited[b] ? edited[b].join(', ') : 'no change (already applied?)'));
  }
}
console.log('[levi-swing-0717] DONE. Next: <tools>\\gdtdb\\gdtdb.exe /update -> .\\tools\\build_map.ps1 -GscOnly');
