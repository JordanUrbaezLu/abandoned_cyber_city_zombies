#!/usr/bin/env node
// =============================================================================
// graft_cw_weapon_stats.js - copy the GAMEPLAY/BALANCE stat fields from an
// existing box gun's GDT onto its newer Cold War (t9) port GDT, so the CW model
// plays IDENTICALLY to the gun it replaces (same DPS / RPM / clip / reserve /
// reload / hit-location profile) - only the MODEL/anims/sounds change.
//
// WHY: the CW ports ship with their own (MP-tuned) stats - different damage,
// fire rate, mag, AND inflated loc* mults (the docs/33 §7 trap: locTorso!=1.0 =
// secretly stronger body shots). We want "same gun, newer model", so we graft
// the old gun's tuned gameplay fields. Asset-reference fields (xmodel, anims,
// sounds, FX, recoil, spread, movement) are LEFT as the CW values.
//
// Recoil is NOT grafted - apply_recoil_overhaul.js re-scales every twinned gun's
// base recoil x2.5 uniformly, so the CW native recoil is overwritten there.
//
// Install-side only (the Skye/CW GDTs live in <tools>\source_data, not the repo;
// see docs/33 "Reproducibility gap"). Re-runnable; run gdtdb /update after.
//
// Usage:
//   node tools/graft_cw_weapon_stats.js --tools "<modtools root>" [--gun ak47] [--dry]
// =============================================================================

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
function arg(name, def) { const i = args.indexOf('--' + name); return i >= 0 ? args[i + 1] : def; }
const DRY = args.includes('--dry');
const TOOLS = arg('tools', 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130');
const ONLY = arg('gun', null);

// gameplay fields to graft (NOT asset refs / recoil / spread / movement).
const FIELDS = [
  'damage', 'damage2', 'damage3', 'damage4', 'damage5', 'minDamage',
  'maxDamageRange', 'minDamageRange', 'damageRange2', 'damageRange3', 'damageRange4', 'damageRange5',
  'fireTime', 'fireType',
  'clipSize', 'maxAmmo', 'startAmmo',
  'reloadTime', 'reloadEmptyTime',
  'penetrateType',
  // every hit-location mult (grafting the old normalized values fixes the CW MP inflation):
  'locNone', 'locHelmet', 'locHead', 'locNeck',
  'locTorsoUpper', 'locTorsoMid', 'locTorsoLower',
  'locRightArmUpper', 'locRightArmLower', 'locRightHand',
  'locLeftArmUpper', 'locLeftArmLower', 'locLeftHand',
  'locRightLegUpper', 'locRightLegLower', 'locRightFoot',
  'locLeftLegUpper', 'locLeftLegLower', 'locLeftFoot',
  'locGroin', 'locGun',
];

// old (current) -> new (Cold War) per gun. up = PaP asset names (mind AK-74u's _up_zm).
// 2026-07-02 (new box): newGdt repointed from the old t9_wpn_ports pack (source_data\t9_weapons\,
// never transferred) to the fresh Skye CW pack files - same t9 asset ids, Skye's own models/anims.
// The ak74u OLD source (skye_t5_ak74u.gdt, BO1 pack) is NOT installed here - its published values
// are re-applied from the documented record (docs/41 + reduce_base_ammo pins) by a separate step.
const GUNS = {
  ak47:  { oldGdt: 'source_data/skye_t6_ak47.gdt',          oldBase: 't6_ak47',  oldUp: 't6_ak47_up',     newGdt: 'source_data/skye_t9_ak-47.gdt',  newBase: 't9_ak47',  newUp: 't9_ak47_up' },
  ak74u: { oldGdt: 'source_data/skye_t5_ak74u.gdt',         oldBase: 't5_ak74u', oldUp: 't5_ak74u_up_zm', newGdt: 'source_data/skye_t9_ak-74u.gdt', newBase: 't9_ak74u', newUp: 't9_ak74u_up' },
  m60:   { oldGdt: 'source_data/skye_t6_m60.gdt',           oldBase: 't6_m60',   oldUp: 't6_m60_up',      newGdt: 'source_data/skye_t9_m60.gdt',  newBase: 't9_m60',   newUp: 't9_m60_up' },
  rpd:   { oldGdt: 'source_data/skye_t6_rpd.gdt',           oldBase: 't6_rpd',   oldUp: 't6_rpd_up',      newGdt: 'source_data/skye_t9_rpd.gdt',  newBase: 't9_rpd',   newUp: 't9_rpd_up' },
};

// Return [startLine, endLineExclusive] of the asset's bulletweapon block.
function blockRange(lines, asset) {
  const head = `"${asset}" ( "bulletweapon.gdf" )`;
  let start = -1;
  for (let i = 0; i < lines.length; i++) { if (lines[i].includes(head)) { start = i; break; } }
  if (start < 0) return null;
  let end = lines.length;
  for (let i = start + 1; i < lines.length; i++) { if (/\(\s*"[a-z0-9_]+\.gdf"\s*\)/.test(lines[i])) { end = i; break; } }
  return [start, end];
}
function fieldVal(lines, range, field) {
  const re = new RegExp(`^\\s*"${field}"\\s+"([^"]*)"`);
  for (let i = range[0]; i < range[1]; i++) { const m = lines[i].match(re); if (m) return m[1]; }
  return null;
}
function setField(lines, range, field, val) {
  const re = new RegExp(`^(\\s*"${field}"\\s+)"[^"]*"`);
  for (let i = range[0]; i < range[1]; i++) { if (re.test(lines[i])) { lines[i] = lines[i].replace(re, `$1"${val}"`); return true; } }
  return false; // field absent in new block (skip - don't inject)
}

function graftForm(oldLines, oldAsset, newLines, newAsset, label) {
  const oR = blockRange(oldLines, oldAsset), nR = blockRange(newLines, newAsset);
  if (!oR) { console.log(`  ! old asset ${oldAsset} not found - skip ${label}`); return 0; }
  if (!nR) { console.log(`  ! new asset ${newAsset} not found - skip ${label}`); return 0; }
  let n = 0, changes = [];
  for (const f of FIELDS) {
    const ov = fieldVal(oldLines, oR, f);
    if (ov === null) continue;
    const cur = fieldVal(newLines, nR, f);
    if (cur === ov) continue;
    if (setField(newLines, nR, f, ov)) { changes.push(`${f}: ${cur} -> ${ov}`); n++; }
  }
  console.log(`  [${label}] ${n} field(s): ${changes.join(' | ') || '(already matched)'}`);
  return n;
}

let total = 0;
for (const [key, g] of Object.entries(GUNS)) {
  if (ONLY && ONLY !== key) continue;
  const oldPath = path.join(TOOLS, g.oldGdt);
  console.log(`=== ${key}: ${g.oldBase} -> ${g.newBase} ===`);
  if (!fs.existsSync(oldPath)) { console.log(`  ! old GDT missing: ${oldPath}`); continue; }
  const oldLines = fs.readFileSync(oldPath, 'utf8').split(/\r?\n/);
  // 2026-07-02: graft the LIVE target GDT AND its .acc-orig recoil baseline, so a future
  // apply_recoil_overhaul re-run (which restores .acc-orig) keeps the grafted stats - this
  // matches old-box history, where the .acc-orig snapshot was taken AFTER the graft. Safe
  // vs the already-applied in-place tuning: FIELDS has no recoil/spread keys, so the x1.75
  // recoil scale and hip-spread class scaling cannot double-apply.
  for (const suf of ['', '.acc-orig']) {
    const newPath = path.join(TOOLS, g.newGdt) + suf;
    if (!fs.existsSync(newPath)) { console.log(`  ! new GDT missing: ${newPath}`); continue; }
    const newLines = fs.readFileSync(newPath, 'utf8').split(/\r?\n/);
    let n = 0;
    n += graftForm(oldLines, g.oldBase, newLines, g.newBase, 'base' + suf);
    n += graftForm(oldLines, g.oldUp, newLines, g.newUp, 'PaP' + suf);
    total += n;
    if (!DRY && n > 0) fs.writeFileSync(newPath, newLines.join('\n'));
  }
  // ATTACHMENT STRIP REMOVED (2026-07-02): the old strip existed because the OLD t9_wpn_ports
  // pack's optic/laser slots referenced missing shared model_export\..\_common\ models. The
  // fresh Skye CW pack ships ALL its attachment models (mags/stocks/barrels/reflex optics -
  // verified on disk), and its mag names (vm_t9_*_mag / vm_t9_*_extmag2) do NOT all match the
  // old /_mag_/ keep-filter, so stripping would blank PaP magazines. Deviation from published
  // visuals: PaP forms show the pack's native reflex optics instead of bare irons (documented).
}
console.log(`\n${DRY ? '[DRY] ' : ''}grafted ${total} field(s) total.${DRY ? '' : ' Run gdtdb /update next.'}`);
