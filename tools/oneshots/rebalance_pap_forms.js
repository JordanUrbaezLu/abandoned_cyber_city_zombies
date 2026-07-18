// =============================================================================
// rebalance_pap_forms.js - per-gun PaP/base FORM stat rebalance (user 2026-06-27).
//
// Edits raw GDT stats on specific weapon FORMS (base / _up) so a change hits ONLY
// the packed (or base) version - the shared acc_weapon_balance_mult can't isolate a
// form, so we tune the form's own GDT fields. Applies to the INSTALL per-gun GDT
// (base + _up blocks) AND every matching perk-twin block in the repo
// source_data/acc_weapon_variants.gdt, then deploys the twin GDT + runs gdtdb /update.
//
// CHANGE SET (user 2026-06-27):
//   RPD  (_up):  +20% damage (390->468, min 375->450) + ~15% fire rate
//                (fireTime 0.08->0.0696; RPM 750->862. The "fastfire twin 0.0552->0.048" leg is
//                 INERT since 2026-07-04 - the fastfire twin axis was removed, so that FT-map key
//                 matches nothing now; harmless.)
//   Tac-19 (_up): -20% damage (217->174)  [shotgun per-pellet; pellets/clip/reserve unchanged]
//   Five-Seven:  _up +30% damage (350->455, min 320->416); BOTH base+_up +30% clip & reserve
//                (base clip 14->18 / maxAmmo 4 -> reserve 56->72; _up clip 21->27 / maxAmmo 7 -> reserve 147->189)
//   MORS (_up):  damage 2000->1500 (min 1000->750, keeps 50% falloff ratio)
//   AK-74u (_up): +20% damage (260->312, min 250->300)
//   Chicom (_up): -20% reserve (maxAmmo 8->6 -> reserve 448->336; closest whole-mag to -20%)
//
// PRICES/BOX RARITY UNCHANGED (user choice): compute_gun_tiers.js is deliberately NOT
// re-run, so pap_price_bucket/acc_box_weight stay as-is (RPD stays cheap+common but S-tier
// once packed, etc.). The GUNS table in compute_gun_tiers.js is now STALE on power for
// these 6 guns by design - do not regenerate docs/54 unless you intend to re-rank.
//
// IDEMPOTENT (absolute SETs + value-MAP for the two fire-rate values). Re-runnable.
// RE-RUN after apply_recoil_overhaul.js / reduce_base_ammo.js (they reset the base GDT +
// regenerate twins, reverting these). Build after: gdtdb /update (done here) + -GscOnly.
//
// Usage: node tools/rebalance_pap_forms.js [--source_data "<path>"]
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const REPO = path.join(__dirname, '..');
const TWIN_REPO = path.join(REPO, 'source_data', 'acc_weapon_variants.gdt');
function arg(n, d) { const i = process.argv.indexOf('--' + n); return i >= 0 && process.argv[i + 1] ? process.argv[i + 1] : d; }
function detectSD() { for (const r of ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common']) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } throw new Error('source_data not found; pass --source_data'); }

const SET = (v) => ['set', String(v)];
const MAP = (m) => ['map', m];
const FT = MAP({ '0.08': '0.0696', '0.0552': '0.048' });   // RPD +15% fire rate (base fireTime; the '0.0552' fastfire-twin leg is INERT since 2026-07-04 - fastfire twins removed, matches nothing)

// per-gun ops by FORM. up = base _up + *_up_acc_* twins; base = base block + *_acc_* (non-up) twins.
const G = {
  't9_rpd':        { up: { damage: SET(468), minDamage: SET(450), fireTime: FT, lastFireTime: FT } },
  's1_tac19':      { up: { damage: SET(174) } },
  't6_fiveseven':  { up: { damage: SET(455), minDamage: SET(416), clipSize: SET(27), maxAmmo: SET(7) },
                     base: { clipSize: SET(18), maxAmmo: SET(4) } },
  's1_mors':       { up: { damage: SET(1500), minDamage: SET(750) } },
  't9_ak74u':      { up: { damage: SET(312), minDamage: SET(300) } },
  't6_chicom_cqb': { up: { maxAmmo: SET(6) } },
};
const HDR = /^\t"([^"]+)" \( "[a-z]*weapon\.gdf" \)/;

function opsFor(name, twin) {
  for (const key in G) {
    const g = G[key];
    if (!twin) {
      if (name === key) return g.base || null;
      if (name === key + '_up') return g.up || null;
    } else {
      if (name.startsWith(key + '_up_acc_')) return g.up || null;
      if (name.startsWith(key + '_acc_')) return g.base || null;   // base (non-up) twins
    }
  }
  return null;
}

function editFile(file, twin, label) {
  if (!fs.existsSync(file)) return { changed: 0, blocks: 0, found: false };
  const lines = fs.readFileSync(file, 'utf8').split('\n');
  let cur = null, ops = null, changed = 0; const blocks = new Set();
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(HDR);
    if (h) { cur = h[1]; ops = opsFor(cur, twin); continue; }
    if (!ops) continue;
    const fm = lines[i].match(/^\t\t"([A-Za-z0-9]+)" "([^"]*)"/);
    if (!fm || !(fm[1] in ops)) continue;
    const [type, arg2] = ops[fm[1]];
    let want = null;
    if (type === 'set') want = `\t\t"${fm[1]}" "${arg2}"`;
    else if (type === 'map' && fm[2] in arg2) want = `\t\t"${fm[1]}" "${arg2[fm[2]]}"`;
    if (want && lines[i] !== want) { lines[i] = want; changed++; blocks.add(cur); }
  }
  if (changed > 0) fs.writeFileSync(file, lines.join('\n'));   // callers back up to .acc-balance-orig first
  console.log(`  ${label}: ${changed} field edit(s) across ${blocks.size} block(s)`);
  return { changed, blocks: blocks.size, found: true };
}

(function main() {
  const SD = arg('source_data', null) || detectSD();
  console.log('source_data:', SD);

  console.log('\n[1/4] perk-twin GDT (repo acc_weapon_variants.gdt):');
  // backup once, then edit
  const torig = TWIN_REPO + '.acc-balance-orig'; if (!fs.existsSync(torig)) fs.copyFileSync(TWIN_REPO, torig);
  editFile(TWIN_REPO, true, 'acc_weapon_variants.gdt (repo)');

  console.log('\n[2/4] install per-gun GDTs (base + _up blocks):');
  function walk(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
      const p = path.join(dir, e.name);
      if (e.isDirectory()) { walk(p); continue; }
      if (!e.name.endsWith('.gdt')) continue;
      if (e.name === 'acc_weapon_variants.gdt') continue;   // handled by deploy
      const before = fs.readFileSync(p, 'utf8');
      // quick skip: only touch files that contain one of our base/_up block names
      if (!Object.keys(G).some((k) => before.includes(`\t"${k}" ( "`) || before.includes(`\t"${k}_up" ( "`))) continue;
      const orig = p + '.acc-balance-orig'; if (!fs.existsSync(orig)) fs.copyFileSync(p, orig);
      editFile(p, false, path.basename(p));
    }
  }
  walk(SD);

  console.log('\n[3/4] deploy twin GDT -> install source_data:');
  fs.copyFileSync(TWIN_REPO, path.join(SD, 'acc_weapon_variants.gdt'));
  console.log('  deployed.');

  console.log('\n[4/4] gdtdb /update:');
  const gdtdb = path.join(path.dirname(SD), 'gdtdb', 'gdtdb.exe');
  if (fs.existsSync(gdtdb)) { try { execFileSync(gdtdb, ['/update'], { cwd: path.dirname(gdtdb), stdio: 'inherit' }); } catch (e) { console.log('  WARN gdtdb: ' + e.message); } }
  else console.log('  gdtdb.exe not found - run it manually.');
  console.log('\nDONE. Build: .\\tools\\build_map.ps1 -GscOnly');
})();
