#!/usr/bin/env node
// add_rpd_pap_sight.js [--revert] - EXPERIMENT: bolt a reflex optic onto the Pack-a-Punched RPD ONLY.
//
// Scope (nothing else touched): the install t9_rpd_up (no-perk PaP form) + the repo t9_rpd_up_acc_* twins.
// The BASE RPD and every other gun are LEFT ALONE. Fully REVERSIBLE: --revert re-empties the fields, and a
// pristine .acc-sight-orig backup of each GDT is taken on the first run.
//
// CAVEAT (honest): the BOCW RPD port is base-only - it has NO reflex ADS anim and NO optic-mount tag (only
// tag_rail), so this keeps the iron ADS anim and mounts the reflex on tag_rail. The red dot will likely sit
// OFF-CENTER and the irons stay visible (the port has no tag_sights to hide cleanly). It will not break the
// build/load (vm_t6_reflex/wm_t6_reflex already pack) - it's purely a cosmetic try-and-see. If it looks bad:
//   node tools/add_rpd_pap_sight.js --revert   then deploy twins + gdtdb /update + build -GscOnly.
'use strict';
const fs = require('fs'), path = require('path');
const REVERT = process.argv.includes('--revert');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const RPD = path.join(TOOLS, 'source_data', 't9_weapons', 'wpn_t9_lmg_rpd.gdt');
const TW = 'source_data/acc_weapon_variants.gdt';

// optic slot 1 (the RPD's slot 5 is its magazine - untouched). revert value = "".
const ON = {
    attachViewModel1:    'vm_t6_reflex',
    attachWorldModel1:   'wm_t6_reflex',
    attachViewModelTag1:  'tag_rail',
    attachWorldModelTag1: 'tag_rail',
};
const HDR = /^\t"([^"]+)" \( "[a-z]*weapon\.gdf" \)/;

function edit(file, match, label) {
    if (!fs.existsSync(file)) { console.log(`  [skip] ${label}: not found`); return 0; }
    const bak = file + '.acc-sight-orig'; if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);
    const lines = fs.readFileSync(file, 'utf8').split('\n');
    let cur = null, changed = 0;
    for (let i = 0; i < lines.length; i++) {
        const h = lines[i].match(HDR); if (h) { cur = h[1]; continue; }
        if (!cur || !match(cur)) continue;
        const fm = lines[i].match(/^\t\t"([A-Za-z0-9]+)" "/);
        if (!fm || !(fm[1] in ON)) continue;
        const cr = lines[i].endsWith('\r') ? '\r' : '';
        const want = `\t\t"${fm[1]}" "${REVERT ? '' : ON[fm[1]]}"${cr}`;
        if (lines[i] !== want) { lines[i] = want; changed++; }
    }
    if (changed) fs.writeFileSync(file, lines.join('\n'));
    console.log(`  [${REVERT ? 'revert' : 'edit'}] ${label}: ${changed} field(s)`);
    return changed;
}

let n = 0;
n += edit(RPD, (b) => b === 't9_rpd_up', 'install wpn_t9_lmg_rpd.gdt (t9_rpd_up)');
n += edit(TW, (b) => b.startsWith('t9_rpd_up_acc_'), 'repo acc_weapon_variants.gdt (t9_rpd_up_acc_*)');
console.log(`\n[rpd-sight] ${REVERT ? 'REVERTED' : 'DONE'}: ${n} field(s). Next: deploy twins GDT + gdtdb /update + build -GscOnly.`);
