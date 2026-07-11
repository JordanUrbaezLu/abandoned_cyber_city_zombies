// Generate the 6 perk twins for each of the 4 CONVENTIONAL Apex guns (Peacekeeper/Alternator/
// Prowler/G7) - 24 defs into acc_weapon_variants.gdt via the canonical tools/gen_weapon_variant_gdt.js
// (recoil50 x0.50, fastreload x0.857, combo - the apply_recoil_overhaul TWIN_DIMS). Havoc = exempt
// special (energy projectile, like Mahem/Thundergun).
// _zm TRAP: the generator names blocks "<asset>_<suffix>" -> apex_X_zm_acc_Y (unreachable at runtime);
// post-pass renames every apex twin to put the mode suffix LAST: apex_X_acc_Y_zm (runtime apex_X_acc_Y).
const { execFileSync } = require('child_process');
const fs = require('fs');

const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const OUT = SD + '/acc_weapon_variants.gdt';
const GEN = REPO + '/tools/gen_weapon_variant_gdt.js';

const GUNS = ['peacekeeper', 'alternator', 'prowler', 'g2a4'];
const TWINS = [
  { suffix: 'acc_recoil50', args: ['--recoil', '0.50'] },
  { suffix: 'acc_fastreload', args: ['--reload', '0.857'] },
  { suffix: 'acc_recoil50_fastreload', args: ['--recoil', '0.50', '--reload', '0.857'] },
];

let made = 0;
for (const g of GUNS) {
  for (const form of [
    { asset: 'apex_' + g + '_zm', src: SD + '/zeroy/APEX_BO3.gdt' },
    { asset: 'apex_' + g + '_up_zm', src: SD + '/acc_apex_up.gdt' },
  ]) {
    for (const t of TWINS) {
      execFileSync('node', [GEN, '--src', form.src, '--asset', form.asset,
        '--suffix', t.suffix, ...t.args, '--out', OUT, '--append'], { stdio: 'pipe' });
      made++;
    }
  }
}
console.log('generated ' + made + ' twin defs');

// post-pass: move the _zm mode suffix LAST on every apex twin block name
let gdt = fs.readFileSync(OUT, 'utf8');
let renames = 0;
gdt = gdt.replace(/"apex_([a-z0-9_]+?)_zm_(acc_[a-z0-9_]+)"/g, (m, gun, suf) => {
  renames++;
  return '"apex_' + gun + '_' + suf + '_zm"';
});
fs.writeFileSync(OUT, gdt);
console.log('renamed ' + renames + ' block ids to _zm-last');

// verify: list the apex twin block headers
const hdrs = gdt.match(/"apex_[a-z0-9_]+_acc_[a-z0-9_]+_zm" \( "bulletweapon\.gdf" \)/g) || [];
console.log('apex twin blocks in GDT: ' + hdrs.length);
for (const h of hdrs.slice(0, 6)) console.log('  ' + h);
