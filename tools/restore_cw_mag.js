#!/usr/bin/env node
// =============================================================================
// restore_cw_mag.js - put back the MAGAZINE attachment that graft_cw_weapon_stats.js
// over-stripped (user 2026-06-26: "reload animates an invisible object").
//
// The CW guns' ONLY attachment was attachViewModel5/attachWorldModel5 = the gun's OWN
// mag model (wpn_t9_<gun>_mag_view/world, an xmodel asset defined in the same gdt, file
// installed). graft blanked ALL attachment slots to kill the AK-47 PaP form's broken
// optic/laser refs (which point at missing model_export\..\_common\ models) - but these
// guns have no optics, just the mag, so blanking it made the mag INVISIBLE during reload.
// The mag model is present + valid, so we restore JUST attachViewModel5/attachWorldModel5;
// the optic/laser slots (1-4) stay blank. Twins inherit the attachment from the base form.
//
// Edits the live gdt AND its .acc-orig recoil baseline (so apply_recoil_overhaul re-runs
// keep the mag). Run gdtdb /update + link after. (graft_cw_weapon_stats.js is also patched
// to keep "_mag_" attachments, so a future re-graft won't re-strip it.)
//
// Usage: node tools/restore_cw_mag.js [--tools "<modtools root>"]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const args = process.argv.slice(2);
const TOOLS = args.includes('--tools') ? args[args.indexOf('--tools') + 1]
  : 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data', 't9_weapons');

const GUNS = [
  { f: 'wpn_t9_lmg_rpd.gdt',  v: 'wpn_t9_rpd_mag_view',   w: 'wpn_t9_rpd_mag_world' },
  { f: 'wpn_t9_lmg_m60.gdt',  v: 'wpn_t9_m60_mag_view',   w: 'wpn_t9_m60_mag_world' },
  { f: 'wpn_t9_smg_ak74u.gdt', v: 'wpn_t9_ak74u_mag_view', w: 'wpn_t9_ak74u_mag_world' },
  { f: 'wpn_t9_ar_ak47.gdt',  v: 'wpn_t9_ak47_mag_view',  w: 'wpn_t9_ak47_mag_world' },
];

let total = 0;
for (const g of GUNS) {
  for (const suf of ['', '.acc-orig']) {
    const p = path.join(SD, g.f + suf);
    if (!fs.existsSync(p)) continue;
    let s = fs.readFileSync(p, 'utf8'), n = 0;
    s = s.replace(/("attachViewModel5"\s+)""/g,  (m, p1) => { n++; return p1 + '"' + g.v + '"'; });
    s = s.replace(/("attachWorldModel5"\s+)""/g, (m, p1) => { n++; return p1 + '"' + g.w + '"'; });
    if (n) { fs.writeFileSync(p, s); console.log(`  ${g.f}${suf}: restored ${n} mag attach field(s)`); total += n; }
  }
}
console.log(`restore_cw_mag: ${total} field(s) restored. NEXT: gdtdb /update -> build.`);
