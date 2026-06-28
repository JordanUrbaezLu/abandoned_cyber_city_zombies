// =============================================================================
// fix_twin_ammo_drift.js - sync every perk-twin's AMMO to its canonical form (user 2026-06-27).
//
// THE BUG: apply_recoil_overhaul.js builds the perk-twins (acc_weapon_variants.gdt) from the
// PRISTINE base GDT, but reduce_base_ammo.js (+ the RW1 CLIP_FIX / Olympia MAXAMMO_FIX) only
// cut the INSTALL base/_up blocks - never the twins. So holding a handling perk (Deadshot=recoil,
// Gun Slinger=fastfire, Speed Cola=fastreload) swaps you to a twin with the WRONG (usually higher,
// sometimes lower) clip/reserve than the same gun without the perk. Reported live: Tac-19 (3->6),
// ASM1 (22->32), AE4, MK14, Galil, MORS, Olympia, RW1 (8->1 clip / 7->40 reserve!), PPSH, Paladin.
//
// THE FIX: for every twin block <canonical>_acc_<dims>, SET clipSize / maxAmmo / startAmmo to the
// canonical form's INSTALL value (the cut/final number). fireTime/lastFireTime (fastfire = Gun
// Slinger +45% RoF) and damage are left ALONE - those twin diffs are intentional / already correct.
// Idempotent + re-runnable. Deploys the twin GDT + runs gdtdb /update.
//
// PIPELINE ORDER (re-run after these, they reset base + regenerate twins, reintroducing the drift):
//   apply_recoil_overhaul.js -> reduce_base_ammo.js -> fix_twin_ammo_drift.js (THIS)
//     -> remove_ppsh_pap_optic.js -> rebalance_pap_forms.js -> gdtdb /update + build
//   (run THIS after reduce_base_ammo so canonical = the cut value; safe after rebalance too -
//    rebalance sets both install + twins, so canonical is already final.)
//
// Usage: node tools/fix_twin_ammo_drift.js [--source_data "<path>"]
// Build after: .\tools\build_map.ps1 -GscOnly
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const TWIN_REPO = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');
const FIELDS = ['clipSize', 'maxAmmo', 'startAmmo'];
const HDR = /^\t"([^"]+)" \( "[a-z]*weapon\.gdf" \)/;
function arg(n, d) { const i = process.argv.indexOf('--' + n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
function detectSD() { for (const r of ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common']) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } throw new Error('source_data not found; pass --source_data'); }

// Read canonical (install) forms' ammo, skipping the deployed twin gdt.
function readInstall(SD) {
  const out = {};
  (function walk(d) { for (const e of fs.readdirSync(d, { withFileTypes: true })) { const p = path.join(d, e.name); if (e.isDirectory()) { walk(p); continue; } if (!e.name.endsWith('.gdt') || e.name === 'acc_weapon_variants.gdt') continue;
    let c = null; for (const ln of fs.readFileSync(p, 'utf8').split(/\r?\n/)) { const h = ln.match(HDR); if (h) { c = h[1]; out[c] = out[c] || {}; continue; } if (!c) continue; const m = ln.match(/^\t\t"([A-Za-z0-9]+)" "([^"]*)"/); if (m && FIELDS.includes(m[1]) && out[c][m[1]] === undefined) out[c][m[1]] = m[2]; } } })(SD);
  return out;
}

(function main() {
  const SD = arg('source_data', null) || detectSD();
  console.log('source_data:', SD);
  const INSTALL = readInstall(SD);

  const orig = TWIN_REPO + '.acc-ammodrift-orig'; if (!fs.existsSync(orig)) fs.copyFileSync(TWIN_REPO, orig);
  const lines = fs.readFileSync(TWIN_REPO, 'utf8').split('\n');
  let cur = null, canon = null, changed = 0; const touched = {};
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(HDR);
    if (h) {
      cur = h[1];
      const m = cur.match(/^(.*)_acc_/);
      canon = m ? INSTALL[m[1]] : null;   // canonical install form's ammo (or null if not a twin)
      continue;
    }
    if (!canon) continue;
    const fm = lines[i].match(/^\t\t"([A-Za-z0-9]+)" "([^"]*)"/);
    if (!fm || !FIELDS.includes(fm[1]) || canon[fm[1]] === undefined) continue;
    const want = `\t\t"${fm[1]}" "${canon[fm[1]]}"`;
    if (lines[i] !== want) { lines[i] = want; changed++; touched[cur] = (touched[cur] || 0) + 1; }
  }
  if (changed > 0) fs.writeFileSync(TWIN_REPO, lines.join('\n'));
  console.log(`\nsynced ${changed} ammo field(s) across ${Object.keys(touched).length} twin block(s) to canonical.`);

  console.log('\ndeploy twin GDT -> install source_data:');
  fs.copyFileSync(TWIN_REPO, path.join(SD, 'acc_weapon_variants.gdt'));
  console.log('  deployed.');

  console.log('\ngdtdb /update:');
  const gdtdb = path.join(path.dirname(SD), 'gdtdb', 'gdtdb.exe');
  if (fs.existsSync(gdtdb)) { try { execFileSync(gdtdb, ['/update'], { cwd: path.dirname(gdtdb), stdio: 'inherit' }); } catch (e) { console.log('  WARN gdtdb: ' + e.message); } }
  else console.log('  gdtdb.exe not found - run it manually.');
  console.log('\nDONE. Build: .\\tools\\build_map.ps1 -GscOnly');
})();
