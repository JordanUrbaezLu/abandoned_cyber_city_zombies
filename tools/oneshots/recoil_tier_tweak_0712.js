#!/usr/bin/env node
// =============================================================================
// recoil_tier_tweak_0712.js - per-gun recoil-TIER retune (user 2026-07-12).
//   AK-74u -> Medium (slight buff), MK14 -> Medium (slight buff),
//   Grav    -> Low   (buff),        CEL-3 -> Medium (recoil INCREASE / nerf to
//                                            the TOP-tier shotgun).
//
// WHY A SURGICAL ONE-SHOT (not apply_recoil_overhaul.js): the overhaul applies ONE
// uniform x1.75 base scale to every gun and a full re-run would DROP the hand-built
// twins (Blast-O-Matic / CEL-3 / Grav-Klauser swaps) - see its header. So we scale a
// PER-GUN factor surgically instead, exactly like symmetrize_cw_recoil.js.
//
// WHAT IT SCALES: the 16 visible-recoil kick fields (hip+ads x Gun+View x Pitch/Yaw
// Min/Max) - IDENTICAL to gen_weapon_variant_gdt.js RECOIL_KEYS, so the feel matches
// the overhaul's own scaling. Applied to EVERY block of each gun:
//   - base skye GDT (install-side): `<base>`, `<up>`   (+ its `.acc-orig` overhaul
//     baseline if present, so a FUTURE apply_recoil_overhaul re-run REPRODUCES the
//     tier - scaling is multiplicative, order-independent vs the x1.75 re-apply).
//   - variants GDT (repo + deployed): every `<base|up>_acc_*` twin.
// SCALING (not SETTING) is load-bearing: the `_acc_recoil50` Mega-Deadshot twins are
// already at x0.50 - a factor keeps them at half the NEW base (SETTING would wipe the
// Deadshot benefit).
//
// The doc (docs/25) reads the DEPLOYED `_up` adsViewKick -> REGENERATE it after this:
//   node tools/gen_weapon_stats.js
// Recoil rating buckets (gen_weapon_stats RECOIL_TIERS, total = vClimb+hShake deg):
//   <=60 Very Low | <=90 Low | <=120 Medium | <=160 High | else Very High
//
// IDEMPOTENT: keeps a `<file>.acc-recoiltier-orig` snapshot per edited file and always
// re-derives from it, so re-running never compounds the factor.
//
// Usage: node tools/oneshots/recoil_tier_tweak_0712.js [--tools "<modtools root>"]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const { execFileSync } = require('child_process');

const args = process.argv.slice(2);
const TOOLS = args.includes('--tools') ? args[args.indexOf('--tools') + 1]
  : (process.env.TA_TOOLS_PATH || 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130');
const SD = path.join(TOOLS, 'source_data');
const REPO = path.resolve(__dirname, '..', '..');
const VAR_REPO = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');
const VAR_DEPLOYED = path.join(SD, 'acc_weapon_variants.gdt');

// gen_weapon_variant_gdt.js RECOIL_KEYS - the exact 16 visible-recoil kick fields.
const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);

// factor scales the CURRENT (already x1.75) profile. Base ads total (vClimb+hShake):
//   ak74u/mk14/grav = 26.25+105 = 131.25 (High); cel3 = 2.5+47.5 = 50 (Very Low).
const GUNS = [
  { name: 'ak74u', gdt: 'skye_t9_ak-74u.gdt',            base: 't9_ak74u', up: 't9_ak74u_up', factor: 0.85, want: 'Medium' },
  { name: 'mk14',  gdt: 'skye_s1_mk14.gdt',              base: 's1_mk14',  up: 's1_mk14_up',  factor: 0.85, want: 'Medium' },
  { name: 'grav',  gdt: 'skye_t9_grav.gdt',              base: 't9_grav',  up: 't9_grav_up',  factor: 0.61, want: 'Low' },
  { name: 'cel3',  gdt: 'skye_s1_cel-3_cauterizer.gdt',  base: 's1_cel3',  up: 's1_cel3_up',  factor: 2.00, want: 'Medium (recoil UP - nerf)' },
];

const BLOCK_RE = /^\s*"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)/;
const FIELD_RE = /^(\s*")([A-Za-z0-9]+)("\s+")(-?[\d.]+)("\s*)$/;

// A block belongs to `g` iff its asset name is the base/up form or one of their twins.
function blockGun(name, guns) {
  for (const g of guns) {
    if (name === g.base || name === g.up ||
        name.startsWith(g.base + '_acc_') || name.startsWith(g.up + '_acc_')) return g;
  }
  return null;
}

const round4 = (n) => Math.round(n * 1e4) / 1e4;

// Scale RECOIL_KEYS in every block belonging to one of `guns`, deriving from the
// pristine snapshot. Returns { changed, blocks } or null if the source is missing.
function scaleFile(livePath, guns) {
  if (!fs.existsSync(livePath)) return null;
  const backup = livePath + '.acc-recoiltier-orig';
  if (!fs.existsSync(backup)) fs.copyFileSync(livePath, backup);   // one-time pristine snapshot
  const src = fs.readFileSync(backup, 'utf8');
  const eol = src.includes('\r\n') ? '\r\n' : '\n';
  const lines = src.split(/\r?\n/);

  let cur = null, changed = 0; const blocks = new Set();
  for (let i = 0; i < lines.length; i++) {
    const bm = lines[i].match(BLOCK_RE);
    if (bm) { cur = blockGun(bm[1], guns); if (cur) blocks.add(bm[1]); continue; }
    if (!cur) continue;
    const fm = lines[i].match(FIELD_RE);
    if (fm && RECOIL_KEYS.has(fm[2])) {
      const v = round4(parseFloat(fm[4]) * cur.factor);
      lines[i] = `${fm[1]}${fm[2]}${fm[3]}${v}${fm[5]}`;
      changed++;
    }
  }
  fs.writeFileSync(livePath, lines.join(eol));
  return { changed, blocks: blocks.size };
}

let touched = 0;
// 1) per-gun base skye GDT (live) + its overhaul baseline (.acc-orig, if present).
for (const g of GUNS) {
  for (const suf of ['', '.acc-orig']) {
    const p = path.join(SD, g.gdt + suf);
    const r = scaleFile(p, [g]);
    if (r) { console.log(`  ${g.gdt}${suf}: x${g.factor} -> ${r.changed} field(s) in ${r.blocks} block(s)`); touched++; }
  }
}
// 2) variants GDT (repo copy) - all four guns in ONE pass, then deploy to source_data.
const rv = scaleFile(VAR_REPO, GUNS);
if (rv) { console.log(`  acc_weapon_variants.gdt (repo): -> ${rv.changed} field(s) in ${rv.blocks} twin block(s)`); touched++; }
if (fs.existsSync(VAR_REPO) && fs.existsSync(SD)) { fs.copyFileSync(VAR_REPO, VAR_DEPLOYED); console.log(`  deployed variants -> ${VAR_DEPLOYED}`); }

console.log(`\nrecoil_tier_tweak: ${touched} file(s) rescaled.`);

// 3) refresh the GDT DB so the linker sees the edits (same step apply_recoil_overhaul does).
const gdtdb = path.join(TOOLS, 'gdtdb', 'gdtdb.exe');
if (fs.existsSync(gdtdb)) {
  try { execFileSync(gdtdb, ['/update'], { cwd: path.dirname(gdtdb), stdio: 'inherit' }); console.log('gdt.db updated - safe to link.'); }
  catch (e) { console.log('WARN: gdtdb /update failed - run it manually before linking: ' + e.message); }
} else {
  console.log(`NOTE: run "${gdtdb}" /update before linking (not found here).`);
}
console.log('NEXT: node tools/gen_weapon_stats.js  (regen docs/25) -> .\\tools\\build_map.ps1 -GscOnly');
