#!/usr/bin/env node
// =============================================================================
// symmetrize_cw_recoil.js - CENTER the horizontal (yaw) gun-kick of the Cold War
// (t9) ports so the reticle doesn't drift off-center while firing (user 2026-06-26:
// "RPD recoil goes away from center when you aim in").
//
// THE PROBLEM: the BOCW gun models ship ASYMMETRIC / INVERTED ads+hip GunKickYaw
// (RPD +15/-5, M60 +10/-15 inverted, AK-74u +10/-5 native), so the gun kicks one
// direction harder than the other = a consistent sideways drift. apply_recoil_overhaul
// then SCALES it x1.75, amplifying the drift. (Pitch / vertical kick is LEFT ALONE -
// the "shoots up" is normal recoil; only the left/right bias is the bug.)
//
// THE FIX: rewrite each weapon block's GunKickYaw Min/Max to -m / +m where
// m = average of the two magnitudes (preserves the gun's recoil ENERGY, just centers
// it). Applied to the `.acc-orig` BASELINE (the recoil-overhaul source of truth) so a
// re-run stays symmetric, AND to the live gdt so the current build is fixed immediately.
// Idempotent (already-symmetric guns like the AK-47 are unchanged). Run
// apply_recoil_overhaul.js AFTER this to regenerate base+_up+twins from the fixed baseline.
//
// Usage: node tools/symmetrize_cw_recoil.js [--tools "<modtools root>"]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const args = process.argv.slice(2);
const TOOLS = args.includes('--tools') ? args[args.indexOf('--tools') + 1]
  : 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data', 't9_weapons');

const FILES = ['wpn_t9_ar_ak47.gdt', 'wpn_t9_smg_ak74u.gdt', 'wpn_t9_lmg_m60.gdt', 'wpn_t9_lmg_rpd.gdt'];
const PAIRS = [['adsGunKickYawMin', 'adsGunKickYawMax'], ['hipGunKickYawMin', 'hipGunKickYawMax']];

function symmetrize(file) {
  if (!fs.existsSync(file)) return 0;
  let lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
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
      const m = +(((Math.abs(minVal) + Math.abs(maxVal)) / 2)).toFixed(4);
      const newMin = lines[minIdx[k]].replace(reMin, `$1${-m}$3`);
      const newMax = lines[maxIdx[k]].replace(reMax, `$1${m}$3`);
      if (newMin !== lines[minIdx[k]]) { lines[minIdx[k]] = newMin; changed++; }
      if (newMax !== lines[maxIdx[k]]) { lines[maxIdx[k]] = newMax; changed++; }
    }
  }
  if (changed) fs.writeFileSync(file, lines.join('\n'));
  return changed;
}

let total = 0;
for (const f of FILES) {
  for (const suf of ['', '.acc-orig']) {
    const p = path.join(SD, f + suf);
    const c = symmetrize(p);
    if (c) { console.log(`  ${f}${suf}: centered ${c} yaw field(s)`); total += c; }
  }
}
console.log(`symmetrize_cw_recoil: ${total} yaw field(s) centered. NEXT: apply_recoil_overhaul.js -> reduce_base_ammo.js -> gdtdb /update -> build.`);
