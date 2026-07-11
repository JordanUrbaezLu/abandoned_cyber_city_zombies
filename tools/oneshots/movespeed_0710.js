#!/usr/bin/env node
// =============================================================================
// movespeed_0710.js - class-standardized run-speed RETUNE (user 2026-07-10), superseding the
// 2026-07-09 pass (movespeed_lmg_0709.js). New per-class moveSpeedScale:
//   Melee + Pistol 1.07 | SMG 1.0 (unchanged) | AR + Marksman + Sniper 0.93 | LMG + Launcher 0.86
//   (Pistol 1.0 -> 1.07 folded in per the 2026-07-10 follow-up: "same move tier as melees".)
//   Shotguns + the 3 non-melee wonders (Thundergun / Fire Bow / Blast-O-Matic) DELIBERATELY untouched
//   at 1.0 - not in the user's list (confirmed 2026-07-10), exactly as the 0709 pass left them.
// Delta vs 0709: Melee 1.05->1.07, AR/Marksman/Sniper 0.95->0.93, LMG/Launcher 0.9->0.86, +War Machine
// (t6_war_machine, added after 0709) folded into Launcher. SMG/Pistol re-assert 1.0 (idempotent normalize).
// MOVE-SPEED ONLY - no ammo bump (the 0709 LMG 4->5-mag bump is already applied; leave it).
//
// Sweeps EVERY weapon-gdf block whose name starts with a class stem across source_data + _custom
// (base + _up + every twin + unused variants - harmless, keeps twins in sync). One-shot
// .acc-movespeed0710-orig backup per touched file. FOOTGUN: re-running the OLD movespeed_lmg_0709.js
// would revert these to the 0709 values - this file is the current source of truth.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const ROOTS = [path.join(TOOLS, 'source_data'), path.join(TOOLS, '_custom')].filter(fs.existsSync);

// stem -> move (prefix match on the block name). Order irrelevant (first prefix hit wins; stems are distinct).
const CLASSES = [
  // LMG 0.86
  ['t9_m60', '0.86'], ['t9_rpd', '0.86'],
  // Launcher 0.86 (Mahem + War Machine)
  ['s1_mahem', '0.86'], ['t6_war_machine', '0.86'],
  // AR 0.93 (incl. Havoc = energy AR)
  ['t9_ak47', '0.93'], ['t9_xm4', '0.93'], ['s1_ae4', '0.93'], ['t9_grav', '0.93'], ['apex_beam_rifle', '0.93'],
  // Sniper / Marksman 0.93
  ['s1_mors', '0.93'], ['s1_mk14', '0.93'], ['apex_g2a4', '0.93'],
  // SMG 1.0 (unchanged - idempotent re-assert)
  ['s4_ppsh41', '1'], ['t9_ak74u', '1'], ['apex_prowler', '1'], ['apex_alternator', '1'],
  // Pistol 1.07 (user 2026-07-10 follow-up: same move tier as melee)
  ['s1_rw1', '1.07'], ['t6_fiveseven', '1.07'],
  // Melee 1.07
  ['leviathan', '1.07'], ['t8_melee_figure', '1.07'],
];

function moveFor(name) {
  for (const [stem, move] of CLASSES) if (name.startsWith(stem)) return move;
  return null;   // shotguns + non-melee wonders + everything else = untouched
}

let files = [];
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.gdt') && !e.name.includes('orig')) files.push(p); } };
for (const r of ROOTS) walk(r);

let blocks = 0, moveSets = 0, missing = 0;
for (const f of files) {
  let txt = fs.readFileSync(f, 'utf8');
  let changed = false;
  const hdrs = [...txt.matchAll(/(^|\n)\t"([^"]+)"\s*\(\s*"([^"]*weapon[^"]*\.gdf)"\s*\)/g)];
  // process bottom-up so index math stays valid across in-place replacements
  for (const m of hdrs.reverse()) {
    const name = m[2];
    const move = moveFor(name);
    if (!move) continue;
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    if (end === -1) continue;
    let body = txt.substring(start, end);
    const orig = body;
    body = body.replace(/("moveSpeedScale"\s+")([^"]*)(")/, (a, pre, old, post) => {
      if (old !== move) { moveSets++; console.log(path.basename(f) + ' :: ' + name + ' :: moveSpeedScale ' + old + ' -> ' + move); }
      return pre + move + post;
    });
    if (body === orig && !/"moveSpeedScale"/.test(body)) { missing++; console.error('NO moveSpeedScale FIELD: ' + name + ' in ' + path.basename(f)); }
    if (body !== txt.substring(start, end)) {
      if (!changed) { const bak = f + '.acc-movespeed0710-orig'; if (!fs.existsSync(bak)) fs.copyFileSync(f, bak); changed = true; }
      txt = txt.substring(0, start) + body + txt.substring(end);
    }
    blocks++;
  }
  if (changed) fs.writeFileSync(f, txt);
}
console.log('\nDONE: scanned ' + blocks + ' matching blocks, ' + moveSets + ' move changes' + (missing ? ', ' + missing + ' blocks MISSING the field (see errors above)' : ''));
