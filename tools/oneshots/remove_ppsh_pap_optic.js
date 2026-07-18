// =============================================================================
// remove_ppsh_pap_optic.js - strip the MK8 reflector REFLEX SIGHT baked into the
// Pack-a-Punch PPSH-41 ("The Pale Rider"), restoring iron-sight ADS. (user 2026-06-27)
//
// The Skye Vanguard PPSH port adds an mk8 reflector optic to its PaP `_up` form via
// 9 GDT fields (reflex view/world models + tag_reflex tags + reflector ADS anims +
// hideTags that hides the irons). This tool reverts EXACTLY those 9 fields on every
// PPSH `_up` form back to the BASE gun's (no optic, irons shown), leaving every other
// PaP upgrade (clip 54, damage 280, special stock, drum mag, "The Pale Rider" name,
// upgraded muzzle FX) untouched.
//
// Targets:
//   - install  skye_s4_ppsh-41.gdt      block  s4_ppsh41_base_up      (the no-perk PaP form)
//   - repo     source_data/acc_weapon_variants.gdt  blocks s4_ppsh41_base_up_acc_*  (7 perk twins)
// Then DEPLOYS the twin GDT to install source_data and runs gdtdb /update so the change
// is in the gdtDB the linker reads. Re-runnable + idempotent (per-field, per-block).
//
// RE-RUN ME after apply_recoil_overhaul.js: that tool restores the pristine base GDT
// from its .acc-orig backup AND regenerates the twins, both of which RE-ADD this sight
// (same footgun as reduce_base_ammo.js, memory recoil-tool-reverts-ammo-cut). Order:
//   node tools/apply_recoil_overhaul.js  &&  node tools/reduce_base_ammo.js  &&  node tools/remove_ppsh_pap_optic.js
//
// Usage: node tools/remove_ppsh_pap_optic.js [--source_data "<path>"]  (auto-detects install)
// Build after: .\tools\build_map.ps1 -GscOnly   (linker only - no geometry, gdtdb already refreshed here)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const TWIN_REPO = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');

function arg(name, dflt) { const i = process.argv.indexOf('--' + name); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : dflt; }
function detectSourceData() {
  const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
  for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
  throw new Error('could not auto-detect source_data; pass --source_data "<path>"');
}

// The 9 sight fields -> their BASE-form (no-optic) values. Reverting these = iron-sight ADS.
const FIELDS = {
  adsDownAnim:          'am_s4_ppsh41_ads_down',
  adsUpAnim:            'am_s4_ppsh41_ads_up',
  attachViewModel1:     '',
  attachViewModel2:     '',
  attachViewModelTag1:  '',
  attachViewModelTag2:  '',
  attachWorldModel1:    '',
  attachWorldModelTag1: '',
  hideTags:             'tag_optic_mount',
};
const HDR = /^\t"([^"]+)" \( "[a-z]*weapon\.gdf" \)/;

// Strip the 9 fields in every block of `text` whose name passes `match`. Returns {text, blocks, changed}.
function strip(text, match) {
  const lines = text.split('\n');
  let cur = null, blocks = 0, changed = 0;
  const hit = {};
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(HDR);
    if (h) { cur = h[1]; if (match(cur)) { blocks++; hit[cur] = 0; } continue; }
    if (!cur || !match(cur)) continue;
    const fm = lines[i].match(/^\t\t"([A-Za-z0-9]+)" "/);
    if (!fm || !(fm[1] in FIELDS)) continue;
    const want = `\t\t"${fm[1]}" "${FIELDS[fm[1]]}"`;
    if (lines[i] !== want) { lines[i] = want; changed++; hit[cur]++; }
  }
  return { text: lines.join('\n'), blocks, changed, hit };
}

function editFile(file, match, label) {
  if (!fs.existsSync(file)) { console.log(`  [skip] ${label}: not found (${file})`); return false; }
  const orig = file + '.acc-optic-orig';
  if (!fs.existsSync(orig)) fs.copyFileSync(file, orig);   // one-time pristine backup
  const before = fs.readFileSync(file, 'utf8');
  const { text, blocks, changed, hit } = strip(before, match);
  if (blocks === 0) { console.log(`  [warn] ${label}: NO matching _up block found`); return false; }
  if (changed === 0) { console.log(`  [ok]   ${label}: ${blocks} block(s) already optic-free (idempotent no-op)`); return true; }
  fs.writeFileSync(file, text);
  console.log(`  [edit] ${label}: ${changed} field(s) reverted across ${blocks} block(s) -> ${Object.entries(hit).map(([k, v]) => `${k}:${v}`).join(', ')}`);
  return true;
}

(function main() {
  const SD = arg('source_data', null) || detectSourceData();
  console.log('source_data:', SD);
  const ppshInstall = path.join(SD, 'skye_s4_ppsh-41.gdt');

  console.log('\n[1/4] install base PPSH GDT (s4_ppsh41_base_up):');
  editFile(ppshInstall, (n) => n === 's4_ppsh41_base_up', 'skye_s4_ppsh-41.gdt');

  console.log('\n[2/4] repo twin GDT (s4_ppsh41_base_up_acc_*):');
  editFile(TWIN_REPO, (n) => n.startsWith('s4_ppsh41_base_up_acc_'), 'acc_weapon_variants.gdt (repo)');

  console.log('\n[3/4] deploy twin GDT -> install source_data:');
  const twinDeployed = path.join(SD, 'acc_weapon_variants.gdt');
  fs.copyFileSync(TWIN_REPO, twinDeployed);
  console.log('  copied ->', twinDeployed);

  console.log('\n[4/4] gdtdb /update (re-bake gdtDB the linker reads):');
  const gdtdb = path.join(path.dirname(SD), 'gdtdb', 'gdtdb.exe');
  if (fs.existsSync(gdtdb)) {
    try { execFileSync(gdtdb, ['/update'], { cwd: path.dirname(gdtdb), stdio: 'inherit' }); console.log('  gdtdb /update OK'); }
    catch (e) { console.log('  WARN: gdtdb /update failed - run it manually before linking: ' + e.message); }
  } else { console.log(`  NOTE: gdtdb.exe not found at ${gdtdb} - run "<tools>\\gdtdb\\gdtdb.exe" /update before linking.`); }

  console.log('\nDONE. Next: .\\tools\\build_map.ps1 -GscOnly  (linker repack; no geometry/LED).');
})();
