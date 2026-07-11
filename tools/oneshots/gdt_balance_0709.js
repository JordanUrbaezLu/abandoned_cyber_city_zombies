#!/usr/bin/env node
// One-shot 2026-07-09 balance pass on install GDTs (+ repo copy of the variants GDT).
//  - leviathan_zm / leviathan_up_zm: fireTime 0.6 -> 0.48, meleeTime 0.65 -> 0.52 (+25% swing speed)
//  - t9_xm4 base/_up + 6 perk twins: fireTime -> 0.07; reload -> 2.0s (empty/add/quick scaled
//    proportionally; fastreload twins keep their 0.857 factor on the NEW base values)
'use strict';
const fs = require('fs');

const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const REPO  = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';

// per-block field -> new value (only replaces fields that EXIST in the block; reports misses)
const XM4_BASE = { fireTime:'0.07', reloadTime:'2', reloadAddTime:'1.11', reloadEmptyTime:'2.479', reloadEmptyAddTime:'1.49' };
const XM4_UP   = { fireTime:'0.07', reloadTime:'2', reloadAddTime:'1.096', reloadEmptyTime:'2.174', reloadEmptyAddTime:'1.096',
                   reloadQuickTime:'2', reloadQuickAddTime:'1.096', reloadQuickEmptyTime:'2.174', reloadQuickEmptyAddTime:'1.096' };
// fastreload twins = new values x 0.857 (the factor the live twins were generated with)
const XM4_BASE_FR = { fireTime:'0.07', reloadTime:'1.714', reloadAddTime:'0.951', reloadEmptyTime:'2.125', reloadEmptyAddTime:'1.277' };
const XM4_UP_FR   = { fireTime:'0.07', reloadTime:'1.714', reloadAddTime:'0.939', reloadEmptyTime:'1.863', reloadEmptyAddTime:'0.939',
                      reloadQuickTime:'1.714', reloadQuickAddTime:'0.939', reloadQuickEmptyTime:'1.863', reloadQuickEmptyAddTime:'0.939' };
const LEV = { fireTime:'0.48', meleeTime:'0.52' };

const JOBS = [
  { file: `${TOOLS}/_custom/wetegg/leviathanaxe/leviathanaxe.gdt`,
    blocks: { leviathan_zm: LEV, leviathan_up_zm: LEV } },
  { file: `${TOOLS}/source_data/skye_t9_xm4.gdt`,
    blocks: { t9_xm4: XM4_BASE, t9_xm4_up: XM4_UP } },
  { file: `${TOOLS}/source_data/acc_weapon_variants.gdt`, variants: true },
  { file: `${REPO}/source_data/acc_weapon_variants.gdt`, variants: true },
];
const VARIANT_BLOCKS = {
  t9_xm4_acc_recoil50: XM4_BASE, t9_xm4_acc_fastreload: XM4_BASE_FR, t9_xm4_acc_recoil50_fastreload: XM4_BASE_FR,
  t9_xm4_up_acc_recoil50: XM4_UP, t9_xm4_up_acc_fastreload: XM4_UP_FR, t9_xm4_up_acc_recoil50_fastreload: XM4_UP_FR,
};

for (const job of JOBS) {
  const blocks = job.variants ? VARIANT_BLOCKS : job.blocks;
  const raw = fs.readFileSync(job.file, 'utf8');
  const eol = raw.includes('\r\n') ? '\r\n' : '\n';
  const lines = raw.split(eol);
  const bak = job.file + '.acc-balance0709-orig';
  if (!fs.existsSync(bak)) fs.writeFileSync(bak, raw);

  let cur = null, edited = {}, changed = 0;
  for (let i = 0; i < lines.length; i++) {
    const head = lines[i].match(/^\s*"([^"]+)"\s*\(\s*"[^"]*"\s*\)/);
    if (head) { cur = blocks[head[1]] ? head[1] : null; continue; }
    if (!cur) continue;
    if (/^\s*\}/.test(lines[i])) { cur = null; continue; }
    const kv = lines[i].match(/^(\s*)"([^"]+)" "([^"]*)"(.*)$/);
    if (!kv) continue;
    const want = blocks[cur][kv[2]];
    if (want !== undefined && kv[3] !== want) {
      lines[i] = `${kv[1]}"${kv[2]}" "${want}"${kv[4]}`;
      (edited[cur] = edited[cur] || []).push(`${kv[2]} ${kv[3]} -> ${want}`);
      changed++;
    }
  }
  fs.writeFileSync(job.file, lines.join(eol));
  console.log(`== ${job.file} (${changed} fields)`);
  for (const b of Object.keys(blocks)) {
    if (edited[b]) console.log(`   ${b}: ${edited[b].join(', ')}`);
    else console.log(`   ${b}: NO CHANGES (block missing or already set!)`);
  }
}
