// Install-side GDT edits for the 3-gun change (2026-07-05).
//  1. CEL-3 (skye_s1_cel-3_cauterizer.gdt): normalize the MP-inflated loc mults (torso+neck) to 1.0
//     on BOTH base + _up so per-pellet body = damage x bal x global (runbook docs/33 loc trap). Head is
//     headshot-excluded for shotguns so it is left as-is.
//  2. Klauser (skye_s4_klauser.gdt): PaP _up ammo buff - clipSize 48->64, maxAmmo 8->14 (reserve 384->896).
// Each edit asserts an EXACT replacement count (aborts on mismatch) + keeps a one-time .acc-*-orig backup.
const fs = require('fs');
const SRC = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';

function backup(file, suffix) {
  const bak = file + suffix;
  if (!fs.existsSync(bak)) { fs.copyFileSync(file, bak); console.log('  backup -> ' + bak.split('/').pop()); }
  else console.log('  backup exists (kept): ' + bak.split('/').pop());
}
function apply(file, edits) {
  let txt = fs.readFileSync(file, 'utf8');
  for (const [re, rep, want, label] of edits) {
    const n = (txt.match(re) || []).length;
    if (n !== want) throw new Error(`ABORT ${file.split('/').pop()} "${label}": matched ${n}, expected ${want}`);
    txt = txt.replace(re, rep);
    console.log(`  ${label}: ${n} replaced`);
  }
  fs.writeFileSync(file, txt);
}

// ---- CEL-3 loc normalize ----
const cel = SRC + '/skye_s1_cel-3_cauterizer.gdt';
console.log('CEL-3 loc-normalize:');
backup(cel, '.acc-loc-orig');
apply(cel, [
  [/("locNeck"\s+)"2\.125"/g,       '$1"1"', 1, 'locNeck base 2.125->1'],
  [/("locNeck"\s+)"3\.125"/g,       '$1"1"', 1, 'locNeck up 3.125->1'],
  [/("locTorsoUpper"\s+)"1\.25"/g,  '$1"1"', 1, 'locTorsoUpper base 1.25->1'],
  [/("locTorsoUpper"\s+)"2\.25"/g,  '$1"1"', 1, 'locTorsoUpper up 2.25->1'],
  [/("locTorsoMid"\s+)"1\.1"/g,     '$1"1"', 1, 'locTorsoMid up 1.1->1'],
]);

// ---- Klauser PaP ammo buff ----
const kl = SRC + '/skye_s4_klauser.gdt';
console.log('Klauser _up ammo buff:');
backup(kl, '.acc-ammo-orig');
apply(kl, [
  [/("clipSize"\s+)"48"/g, '$1"64"', 1, 'clipSize 48->64 (_up)'],
  [/("maxAmmo"\s+)"8"/g,   '$1"14"', 1, 'maxAmmo 8->14 (_up)'],
]);

console.log('\nGDT edits complete.');
