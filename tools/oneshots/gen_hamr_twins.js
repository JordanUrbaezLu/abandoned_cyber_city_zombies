// Hand-generate the 6 perk twins for the BO2 HAMR (t6_hamr) - recoil50 / fastreload /
// recoil50_fastreload x base+_up - mirroring gen_new_gun_twins.js but for ONE gun, so the
// hand-built twins already in acc_weapon_variants.gdt (Apex, Blast-O-Matic, wonders, ...) are
// untouched. Clones into BOTH the repo and the deployed acc_weapon_variants.gdt (identical).
//
// The x1.75 base-recoil "skill theme" is ALREADY applied to skye_t6_hamr.gdt by
// tools/prep_hamr_gdt.js (run that FIRST), so - unlike gen_new_gun_twins.js - this does NOT do a
// --inplace 1.75 baseline pass. The twins clone off the already-prepped forms: recoil50 = x0.50
// of the x1.75 base (-> ~x0.875), fastreload = reload x0.857 (Speed Cola Mega). (user 2026-07-10)
const { execFileSync } = require('child_process');
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GEN = REPO + '/tools/gen_weapon_variant_gdt.js';
const REPO_GDT = REPO + '/source_data/acc_weapon_variants.gdt';
const DEP_GDT = TOOLS + '/source_data/acc_weapon_variants.gdt';
const SRC = TOOLS + '/source_data/skye_t6_hamr.gdt';

const forms = ['t6_hamr', 't6_hamr_up'];
const twins = [
  { suffix: 'acc_recoil50',            args: ['--recoil', '0.50'] },
  { suffix: 'acc_fastreload',          args: ['--reload', '0.857'] },
  { suffix: 'acc_recoil50_fastreload', args: ['--recoil', '0.50', '--reload', '0.857'] },
];

const cnt = (f) => (fs.readFileSync(f, 'utf8').match(/"[a-z0-9_]+_acc_[a-z0-9_]+"\s*\(/g) || []).length;
for (const f of [REPO_GDT, DEP_GDT]) {
  if (fs.readFileSync(f, 'utf8').includes('"t6_hamr_acc_')) { console.error('ABORT: t6_hamr twins already present in ' + f + ' - remove them first.'); process.exit(1); }
}
console.log(`BEFORE: repo=${cnt(REPO_GDT)} deployed=${cnt(DEP_GDT)} twin entries`);

function gen(args, label) {
  try { execFileSync('node', [GEN, ...args], { stdio: 'pipe' }); }
  catch (e) { console.error(`FAIL [${label}]: ${e.stdout || ''}${e.stderr || e.message}`); process.exit(1); }
}

for (const form of forms) {
  for (const t of twins) {
    gen(['--src', SRC, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', REPO_GDT, '--append'], `${form}_${t.suffix} repo`);
    gen(['--src', SRC, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', DEP_GDT, '--append'], `${form}_${t.suffix} dep`);
    console.log(`    twin ${form}_${t.suffix}`);
  }
}
console.log(`AFTER:  repo=${cnt(REPO_GDT)} deployed=${cnt(DEP_GDT)} twin entries (expected +6 each)`);
