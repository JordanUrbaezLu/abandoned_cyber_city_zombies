// Bake the 6 perk twins for the Apex Triple Take (apex_tripletake) - recoil50 / fastreload /
// recoil50_fastreload x base+_up - and REMOVE the 6 CW M16 (t9_m16) twins it replaces,
// keeping the twin count net-0. Clones into BOTH repo + deployed acc_weapon_variants.gdt.
// Recoil x1.25 is ALREADY on APEX_BO3.gdt (tools/prep_apex_tripletake_gdt.js - run FIRST).
// THE _zm TRAP (apex memory): the generator names clones `<asset>_<suffix>` which puts the
// baked _zm suffix FIRST (apex_tripletake_zm_acc_recoil50) - the engine strips _zm only when
// it is LAST, so every block is RENAMED to `apex_tripletake[_up]_acc_<combo>_zm` (runtime
// apex_tripletake[_up]_acc_<combo>) after generation, matching the 5 shipped apex guns.
// (user 2026-07-11)
const { execFileSync } = require('child_process');
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GEN = REPO + '/tools/gen_weapon_variant_gdt.js';
const GDTS = [REPO + '/source_data/acc_weapon_variants.gdt', TOOLS + '/source_data/acc_weapon_variants.gdt'];

// base form lives in the pack GDT; the _up form in acc_apex_up.gdt
const FORMS = [
  { asset: 'apex_tripletake_zm',    stem: 'apex_tripletake',    src: TOOLS + '/source_data/zeroy/APEX_BO3.gdt' },
  { asset: 'apex_tripletake_up_zm', stem: 'apex_tripletake_up', src: TOOLS + '/source_data/acc_apex_up.gdt' },
];
const TWINS = [
  { suffix: 'acc_recoil50',            args: ['--recoil', '0.50'] },
  { suffix: 'acc_fastreload',          args: ['--reload', '0.857'] },
  { suffix: 'acc_recoil50_fastreload', args: ['--recoil', '0.50', '--reload', '0.857'] },
];

// Remove a brace-matched `"<name>" ( "bulletweapon.gdf" )` block (+ trailing whitespace) from a GDT string.
function removeBlock(text, name) {
  const decl = `"${name}" ( "bulletweapon.gdf" )`;
  const start = text.indexOf(decl);
  if (start < 0) return { text, removed: false };
  const lineStart = text.lastIndexOf('\n', start) + 1;
  let open = text.indexOf('{', start), depth = 0, end = -1;
  for (let j = open; j < text.length; j++) { if (text[j] === '{') depth++; else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } } }
  let e = end + 1;
  while (e < text.length && (text[e] === '\n' || text[e] === '\r')) e++;   // eat the trailing newline(s)
  return { text: text.slice(0, lineStart) + text.slice(e), removed: true };
}

const cnt = (f) => (fs.readFileSync(f, 'utf8').match(/"[a-z0-9_]+_acc_[a-z0-9_]+"\s*\(/g) || []).length;
for (const f of GDTS) console.log(`BEFORE ${f.includes('Repositories') ? 'repo' : 'dep '}: ${cnt(f)} twin entries`);

function gen(args, label) {
  try { execFileSync('node', [GEN, ...args], { stdio: 'pipe' }); }
  catch (e) { console.error(`FAIL [${label}]: ${e.stdout || ''}${e.stderr || e.message}`); process.exit(1); }
}

// 1) REMOVE the 6 t9_m16 twins AND any pre-existing tripletake twins (idempotent re-run).
const toRemove = [
  't9_m16_acc_recoil50', 't9_m16_acc_fastreload', 't9_m16_acc_recoil50_fastreload',
  't9_m16_up_acc_recoil50', 't9_m16_up_acc_fastreload', 't9_m16_up_acc_recoil50_fastreload',
];
for (const f of FORMS) for (const t of TWINS) toRemove.push(`${f.stem}_${t.suffix}_zm`);
for (const f of GDTS) {
  let text = fs.readFileSync(f, 'utf8');
  let removed = 0;
  for (const t of toRemove) { const r = removeBlock(text, t); if (r.removed) removed++; text = r.text; }
  fs.writeFileSync(f, text);
  console.log(`  removed ${removed} old (t9_m16 + stale tripletake) twins from ${f.includes('Repositories') ? 'repo' : 'dep'}`);
}

// 2) ADD the 6 apex_tripletake twins to BOTH GDTs, renaming to the _zm-LAST form.
for (const form of FORMS) {
  for (const t of TWINS) {
    for (const out of GDTS) {
      gen(['--src', form.src, '--asset', form.asset, '--suffix', t.suffix, ...t.args, '--out', out, '--append'], `${form.asset}_${t.suffix}`);
      // rename the fresh clone: apex_tripletake[_up]_zm_acc_<combo> -> apex_tripletake[_up]_acc_<combo>_zm
      let text = fs.readFileSync(out, 'utf8');
      const wrong = `"${form.asset}_${t.suffix}"`, right = `"${form.stem}_${t.suffix}_zm"`;
      if (!text.includes(wrong)) { console.error(`FAIL: expected clone ${wrong} not found in ${out}`); process.exit(1); }
      fs.writeFileSync(out, text.replace(wrong, right));
    }
    console.log(`    twin ${form.stem}_${t.suffix}_zm`);
  }
}
for (const f of GDTS) console.log(`AFTER  ${f.includes('Repositories') ? 'repo' : 'dep '}: ${cnt(f)} twin entries (net 0: -6 M16 +6 Triple Take)`);
