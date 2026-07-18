#!/usr/bin/env node
// fix_inverted_gunkick_pitch.js [--dry] - fix INVERTED gun-kick PITCH ranges in the Cold War gun GDTs.
//
// THE BUG (user 2026-06-26 + 2026-06-29, "base RPD scope goes off-center when shooting; only gun with this"):
// the BOCW RPD port ships adsGunKickPitch Max = -35 < Min = -10 - an INVERTED, all-negative range.
// apply_recoil_overhaul scales it x1.75 -> Max = -61.25 < Min = -17.5. Because the range is inverted/biased to
// one sign, the gun MODEL pitches hard the same direction every shot, so the ADS reticle/scope drifts off-centre
// (symmetric yaw alone can't, and symmetrize_cw_recoil.js intentionally leaves PITCH alone since a normal
// upward kick is fine - only this inverted pitch is the bug). The RPD's Min (-17.5) already matches the M60's
// correct +/-17.5; the Max is the corrupted value.
//
// THE FIX: wherever GunKickPitch Max < Min (inverted), set Max = -Min -> a symmetric range on the Min's
// magnitude (RPD ADS -> +/-17.5, matching the M60). Valid ranges (Max >= Min, e.g. AK-74u +8.75/+26.25, the
// RPD's own non-inverted hip) are LEFT ALONE. Applied to the 4 CW install GDTs (live + .acc-orig baseline, so a
// recoil-overhaul re-run stays fixed) AND the perk-twins (source_data/acc_weapon_variants.gdt). Idempotent.
// After: deploy the twins GDT to <tools>\source_data -> gdtdb /update -> build_map.ps1 -GscOnly.
'use strict';
const fs = require('fs'), path = require('path');
const DRY = process.argv.includes('--dry');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data', 't9_weapons');
// ADS pitch ONLY - that is the "scope drifts off-centre when aiming" bug the user reported. HIP pitch is left
// alone (it never aligns a scope, several guns have intentional asymmetric hip kick, and the RPD's hip range is
// already valid: +52.5/-43.75). Scoping to ADS keeps this to the RPD (the only gun with an inverted ADS range).
const PAIRS = [['adsGunKickPitchMin','adsGunKickPitchMax']];

function fixFile(p, label) {
    if (!fs.existsSync(p)) return 0;
    let lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
    let changed = 0;
    for (const [minK, maxK] of PAIRS) {
        const reMin = new RegExp(`^(\\s*"${minK}"\\s+")(-?[\\d.]+)("\\s*)$`);
        const reMax = new RegExp(`^(\\s*"${maxK}"\\s+")(-?[\\d.]+)("\\s*)$`);
        const minIdx = [], maxIdx = [];
        lines.forEach((l, i) => { if (reMin.test(l)) minIdx.push(i); if (reMax.test(l)) maxIdx.push(i); });
        const n = Math.min(minIdx.length, maxIdx.length);   // one min + one max per weapon block, same order
        for (let k = 0; k < n; k++) {
            const minVal = parseFloat(lines[minIdx[k]].match(reMin)[2]);
            const maxVal = parseFloat(lines[maxIdx[k]].match(reMax)[2]);
            if (maxVal >= minVal) continue;                 // valid range -> only fix INVERTED (Max < Min)
            const want = +(-minVal).toFixed(4);             // Max = -Min : symmetric on the (correct) Min magnitude
            const nl = lines[maxIdx[k]].replace(reMax, `$1${want}$3`);
            if (nl !== lines[maxIdx[k]]) { lines[maxIdx[k]] = nl; changed++; }
        }
    }
    if (changed && !DRY) fs.writeFileSync(p, lines.join('\n'));
    if (changed) console.log(`  ${label}: ${changed} inverted pitch Max -> symmetric`);
    return changed;
}

let total = 0;
for (const f of ['wpn_t9_ar_ak47.gdt','wpn_t9_smg_ak74u.gdt','wpn_t9_lmg_m60.gdt','wpn_t9_lmg_rpd.gdt'])
    for (const suf of ['', '.acc-orig']) total += fixFile(path.join(SD, f + suf), f + suf);
total += fixFile('source_data/acc_weapon_variants.gdt', 'acc_weapon_variants.gdt (twins)');
console.log(`[inverted-pitch] ${DRY ? 'DRY (no write)' : 'DONE'}: ${total} field(s) fixed.` + (DRY ? '' : ' Next: deploy twins GDT + gdtdb /update + build -GscOnly.'));
