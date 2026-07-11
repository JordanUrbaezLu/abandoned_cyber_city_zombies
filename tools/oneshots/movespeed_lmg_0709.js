#!/usr/bin/env node
// =============================================================================
// movespeed_lmg_0709.js - class-standardized run speeds + LMG reserve buff (user 2026-07-09):
//   LMG + Launcher 0.9 | AR + Sniper + Marksman 0.95 | SMG + Pistol 1 | Melee 1.05
//   (Shotguns + wonders deliberately untouched - not in the user's list.)
//   LMG reserve +15% -> maxAmmo/startAmmo 4 -> 5 mags (integer mags; = +25%, the smallest step).
// Sweeps EVERY weapon-gdf block whose name starts with a class stem across source_data
// + _custom (base + _up + every twin + unused variants - harmless and keeps twins in sync).
// House pattern: one-shot .acc-movespeed0709-orig backup per touched file.
// The +10% LMG DAMAGE half is GSC-side (acc_weapon_balance_mult), not here.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const ROOTS = [path.join(TOOLS, 'source_data'), path.join(TOOLS, '_custom')].filter(fs.existsSync);

// stem -> { move, lmgAmmo } (prefix match on the block name)
const CLASSES = [
  // LMG 0.9 + reserve 4 -> 5 mags
  ['t9_m60', { move: '0.9', lmgAmmo: true }], ['t9_rpd', { move: '0.9', lmgAmmo: true }],
  // Launcher 0.9 (already 0.9 - idempotent re-assert)
  ['s1_mahem', { move: '0.9' }],
  // AR 0.95 (incl. Havoc = energy AR)
  ['t9_ak47', { move: '0.95' }], ['t9_xm4', { move: '0.95' }], ['s1_ae4', { move: '0.95' }],
  ['t9_grav', { move: '0.95' }], ['apex_beam_rifle', { move: '0.95' }],
  // Sniper / Marksman 0.95
  ['s1_mors', { move: '0.95' }], ['s1_mk14', { move: '0.95' }], ['apex_g2a4', { move: '0.95' }],
  // SMG 1
  ['s4_ppsh41', { move: '1' }], ['t9_ak74u', { move: '1' }], ['apex_prowler', { move: '1' }], ['apex_alternator', { move: '1' }],
  // Pistol 1
  ['s1_rw1', { move: '1' }], ['t6_fiveseven', { move: '1' }],
  // Melee 1.05
  ['leviathan', { move: '1.05' }], ['t8_melee_figure', { move: '1.05' }],
];

function classFor(name) {
  for (const [stem, cfg] of CLASSES) if (name.startsWith(stem)) return cfg;
  return null;
}

let files = [];
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.gdt') && !e.name.includes('orig')) files.push(p); } };
for (const r of ROOTS) walk(r);

let blocks = 0, moveSets = 0, ammoSets = 0;
for (const f of files) {
  let txt = fs.readFileSync(f, 'utf8');
  let changed = false;
  const hdrs = [...txt.matchAll(/(^|\n)\t"([^"]+)"\s*\(\s*"([^"]*weapon[^"]*\.gdf)"\s*\)/g)];
  // process bottom-up so index math stays valid across replacements
  for (const m of hdrs.reverse()) {
    const name = m[2];
    const cfg = classFor(name);
    if (!cfg) continue;
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    if (end === -1) continue;
    let body = txt.substring(start, end);
    const orig = body;
    body = body.replace(/("moveSpeedScale"\s+")([^"]*)(")/, (a, pre, old, post) => {
      if (old !== cfg.move) { moveSets++; console.log(path.basename(f) + ' :: ' + name + ' :: moveSpeedScale ' + old + ' -> ' + cfg.move); }
      return pre + cfg.move + post;
    });
    if (body === orig && !/"moveSpeedScale"/.test(body)) console.error('NO moveSpeedScale FIELD: ' + name + ' in ' + path.basename(f));
    if (cfg.lmgAmmo) {
      for (const k of ['maxAmmo', 'startAmmo']) {
        body = body.replace(new RegExp('("' + k + '"\\s+")([^"]*)(")'), (a, pre, old, post) => {
          if (old === '4') { ammoSets++; console.log(path.basename(f) + ' :: ' + name + ' :: ' + k + ' 4 -> 5'); return pre + '5' + post; }
          if (old !== '5') console.error('UNEXPECTED ' + k + '=' + old + ' on ' + name + ' (expected 4) - left unchanged');
          return a;
        });
      }
    }
    if (body !== txt.substring(start, end)) {
      if (!changed) { const bak = f + '.acc-movespeed0709-orig'; if (!fs.existsSync(bak)) fs.copyFileSync(f, bak); changed = true; }
      txt = txt.substring(0, start) + body + txt.substring(end);
    }
    blocks++;
  }
  if (changed) fs.writeFileSync(f, txt);
}
console.log('\nDONE: scanned ' + blocks + ' matching blocks, ' + moveSets + ' move changes, ' + ammoSets + ' ammo bumps');
