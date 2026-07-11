#!/usr/bin/env node
// =============================================================================
// prowler_recoil_low_0710.js - drop the Prowler's recoil into the "Low" band (user 2026-07-10:
// "reduce/improve the recoil of the prowler to low"). Scales ALL 16 kick-magnitude fields (hip+ads,
// gun+view, pitch+yaw, min+max) by 0.65 (-35%) on EVERY block named apex_prowler* across the GDTs
// (base apex_prowler_zm + acc_apex_up apex_prowler_up_zm + the perk twins + legend variants). Scaling
// every form by the SAME factor keeps the Mega-Deadshot recoil50 twin at a consistent half of the base.
//
// WHY 0.65: docs/25 rates recoil by total ADS view-kick K = vClimb + hShake. Prowler _up was
// pitch[-40,95] (vClimb 27.5) + yaw[+-90] (hShake 90) => K 117.5 (Medium). x0.65 => K ~76.4 (Low, with
// margin: Low band is 60 < K <= 90). Re-run gen_weapon_stats.js after this to confirm the rating flips.
//
// IDEMPOTENT-ish: one-shot .acc-prowlerrecoil0710-orig backup per touched file; re-running compounds the
// x0.65 (it has no pristine-restore) - do NOT run twice. gdtdb /update after.
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const ROOTS = [path.join(TOOLS, 'source_data'), path.join(TOOLS, '_custom')].filter(fs.existsSync);

const STEM = 'apex_prowler';
const FACTOR = 0.65;
// Visible-recoil kick magnitudes (mirrors gen_weapon_variant_gdt.js RECOIL_KEYS). Leaves accel/decay/spread alone.
const RECOIL_KEYS = [
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
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
  for (const m of hdrs.reverse()) {           // bottom-up so indices stay valid
    const name = m[2];
    if (!name.startsWith(STEM)) continue;
    const start = m.index;
    const end = txt.indexOf('\n\t}', start);
    if (end === -1) continue;
    let body = txt.substring(start, end);
    const orig = body;
    for (const k of RECOIL_KEYS) {
      body = body.replace(new RegExp('("' + k + '"\\s+")([-0-9.]+)(")'), (a, pre, old, post) => {
        const nv = fmt(parseFloat(old) * FACTOR);
        if (nv !== old) fieldSets++;
        return pre + nv + post;
      });
    }
    if (body !== orig) {
      if (!changed) { const bak = f + '.acc-prowlerrecoil0710-orig'; if (!fs.existsSync(bak)) fs.copyFileSync(f, bak); changed = true; }
      txt = txt.substring(0, start) + body + txt.substring(end);
      // verbose proof for the _up form (what docs/25 reads)
      if (name === 'apex_prowler_up_zm') {
        const g = fld => { const mm = body.match(new RegExp('"' + fld + '"\\s+"([-0-9.]+)"')); return mm ? mm[1] : '?'; };
        console.log('  [' + path.basename(f) + '] ' + name + ' NOW: adsViewKick pitch[' + g('adsViewKickPitchMin') + ',' + g('adsViewKickPitchMax') + '] yaw[' + g('adsViewKickYawMin') + ',' + g('adsViewKickYawMax') + ']');
      }
    }
    blocks++;
  }
  if (changed) { fs.writeFileSync(f, txt); console.log(path.basename(f) + ': scaled recoil on apex_prowler* blocks'); }
}
console.log('\nDONE: ' + blocks + ' apex_prowler* blocks scanned, ' + fieldSets + ' recoil fields x' + FACTOR + '.');
