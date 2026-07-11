// Hand-generate the 6 perk twins each for XM4 + Streetsweeper (recoil50 / fastreload /
// recoil50_fastreload x base+_up), mirroring apply_recoil_overhaul.js but ONLY for these 2 guns
// (so Blast-O-Matic's hand-built twins are untouched). Applies the map's recoil x1.75 baseline in
// place first, then clones twins into BOTH the repo and deployed acc_weapon_variants.gdt.
const { execFileSync } = require('child_process');
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GEN = REPO + '/tools/gen_weapon_variant_gdt.js';
const REPO_GDT = REPO + '/source_data/acc_weapon_variants.gdt';
const DEP_GDT = TOOLS + '/source_data/acc_weapon_variants.gdt';
const BASE_SCALE = '1.75';

const guns = [
  { src: TOOLS + '/source_data/skye_t9_xm4.gdt',          base: 't9_xm4',          up: 't9_xm4_up' },
  { src: TOOLS + '/source_data/skye_t9_streetsweeper.gdt', base: 't9_streetsweeper', up: 't9_streetsweeper_up' },
];
// twin combos after the fastfire removal (mirror TWIN_DIMS: recoil50 x fastreload)
const twins = [
  { suffix: 'acc_recoil50',            args: ['--recoil', '0.50'] },
  { suffix: 'acc_fastreload',          args: ['--reload', '0.857'] },
  { suffix: 'acc_recoil50_fastreload', args: ['--recoil', '0.50', '--reload', '0.857'] },
];

const cnt = (f) => (fs.readFileSync(f, 'utf8').match(/"[a-z0-9_]+_acc_[a-z0-9_]+"\s*\(/g) || []).length;
console.log(`BEFORE: repo=${cnt(REPO_GDT)} deployed=${cnt(DEP_GDT)} twin entries`);

function gen(args, label) {
  try { execFileSync('node', [GEN, ...args], { stdio: 'pipe' }); }
  catch (e) { console.error(`FAIL [${label}]: ${e.stdout || ''}${e.stderr || e.message}`); process.exit(1); }
}

for (const g of guns) {
  // 1) recoil x1.75 baseline IN PLACE on the deployed skye GDT (base + _up). gen keeps a .acc-orig backup.
  gen(['--src', g.src, '--asset', g.base, '--recoil', BASE_SCALE, '--inplace'], `${g.base} baseline`);
  gen(['--src', g.src, '--asset', g.up,   '--recoil', BASE_SCALE, '--inplace'], `${g.up} baseline`);
  console.log(`  baseline x1.75 applied: ${g.base} + ${g.up}`);
  // 2) clone the 6 twins off the now-scaled forms into BOTH repo + deployed twin GDTs (identical entries)
  for (const form of [g.base, g.up]) {
    for (const t of twins) {
      gen(['--src', g.src, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', REPO_GDT, '--append'], `${form}_${t.suffix} repo`);
      gen(['--src', g.src, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', DEP_GDT, '--append'], `${form}_${t.suffix} dep`);
      console.log(`    twin ${form}_${t.suffix}`);
    }
  }
}
console.log(`AFTER:  repo=${cnt(REPO_GDT)} deployed=${cnt(DEP_GDT)} twin entries (expected +12 each)`);
