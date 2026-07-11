#!/usr/bin/env node
// =============================================================================
// prowler_reload_1s_0711.js - snap the Prowler's reload to ~1s (user 2026-07-11: "decrease prowler
// reload speed to 1s"). The docs/25 reload column shows the _up reloadTime (partial) = 1.6s; scaling
// ALL reload-timing fields by 0.625 sets reloadTime 1.6 -> 1.0 (empty 1.84 -> 1.15, addTime 0.8 -> 0.5),
// keeping the partial:empty ratio. Applied to EVERY apex_prowler* block (base + _up + twins + legend
// variants) so the Speed-Cola fastreload twin stays a consistent x0.857 of the new base
// (1.3712 -> 0.857). Mirror gen_weapon_variant_gdt.js RELOAD_KEYS. Zero-valued fields stay zero.
//
// After this: update PAP_RELOAD['Prowler'] 1.6 -> 1.0 in gen_weapon_stats.js, regen docs/25,
// gdtdb /update, -GscOnly relink. One-shot .acc-prowlerreload0711-orig backup; do NOT run twice
// (no pristine-restore - re-running compounds the x0.625).
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const ROOTS = [path.join(TOOLS, 'source_data'), path.join(TOOLS, '_custom')].filter(fs.existsSync);

const STEM = 'apex_prowler';
const FACTOR = 0.625;   // 1.6 -> 1.0 reloadTime
const RELOAD_KEYS = [
  'reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime',
];
const fmt = v => String(Math.round(v * 1e4) / 1e4);

let files = [];
const walk = d => { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) walk(p); else if (e.name.endsWith('.gdt') && !e.name.includes('orig')) files.push(p); } };
for (const r of ROOTS) walk(r);

let blocks = 0, fieldSets = 0;
for (const f of files) {
  let txt = fs.readFileSync(f, 'utf8');
  let changed = false;
  const hdrs = [...txt.matchAll(/(^|\n)\t"([^"]+)"\s*\(\s*"([^"]*weapon[^"]*\.gdf)"\s*\)/g)];
  for (const m of hdrs.reverse()) {
    const name = m[2];
    if (!name.startsWith(STEM)) continue;
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    if (end === -1) continue;
    let body = txt.substring(start, end);
    const orig = body;
    for (const k of RELOAD_KEYS) {
      body = body.replace(new RegExp('("' + k + '"\\s+")([-0-9.]+)(")'), (a, pre, old, post) => {
        const nv = fmt(parseFloat(old) * FACTOR);
        if (nv !== old) fieldSets++;
        return pre + nv + post;
      });
    }
    if (body !== orig) {
      if (!changed) { const bak = f + '.acc-prowlerreload0711-orig'; if (!fs.existsSync(bak)) fs.copyFileSync(f, bak); changed = true; }
      txt = txt.substring(0, start) + body + txt.substring(end);
      if (name === 'apex_prowler_up_zm' || name === 'apex_prowler_up_acc_fastreload_zm') {
        const g = fld => { const mm = body.match(new RegExp('"' + fld + '"\\s+"([-0-9.]+)"')); return mm ? mm[1] : '?'; };
        console.log('  [' + path.basename(f) + '] ' + name + ' NOW: reloadTime=' + g('reloadTime') + ' reloadEmptyTime=' + g('reloadEmptyTime') + ' reloadAddTime=' + g('reloadAddTime'));
      }
    }
    blocks++;
  }
  if (changed) { fs.writeFileSync(f, txt); console.log(path.basename(f) + ': scaled reload on apex_prowler* blocks'); }
}
console.log('\nDONE: ' + blocks + ' apex_prowler* blocks scanned, ' + fieldSets + ' reload fields x' + FACTOR + '.');
