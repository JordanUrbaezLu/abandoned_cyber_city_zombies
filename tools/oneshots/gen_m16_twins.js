// Bake the 6 perk twins for the CW M16 (t9_m16) - recoil50 / fastreload /
// recoil50_fastreload x base+_up - and REMOVE the 6 G7 Scout (apex_g2a4) twins it replaces,
// keeping the twin count net-0. Clones into BOTH repo + deployed acc_weapon_variants.gdt.
// x1.75 recoil is ALREADY on skye_t9_m16.gdt (tools/prep_m16_gdt.js - run FIRST), so this does
// NOT do a --inplace baseline. (user 2026-07-11)
const { execFileSync } = require('child_process');
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GEN = REPO + '/tools/gen_weapon_variant_gdt.js';
const GDTS = [REPO + '/source_data/acc_weapon_variants.gdt', TOOLS + '/source_data/acc_weapon_variants.gdt'];
const SRC = TOOLS + '/source_data/skye_t9_m16.gdt';

const forms = ['t9_m16', 't9_m16_up'];
const twins = [
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

// 1) REMOVE the 6 apex_g2a4 (G7 Scout) twin blocks AND any pre-existing t9_m16 twins (idempotent
//    re-run: a recoil retune re-preps the base, so the old twins must be dropped + re-cloned).
const toRemove = [
  'apex_g2a4_acc_recoil50_zm', 'apex_g2a4_acc_fastreload_zm', 'apex_g2a4_acc_recoil50_fastreload_zm',
  'apex_g2a4_up_acc_recoil50_zm', 'apex_g2a4_up_acc_fastreload_zm', 'apex_g2a4_up_acc_recoil50_fastreload_zm',
  't9_m16_acc_recoil50', 't9_m16_acc_fastreload', 't9_m16_acc_recoil50_fastreload',
  't9_m16_up_acc_recoil50', 't9_m16_up_acc_fastreload', 't9_m16_up_acc_recoil50_fastreload',
];
for (const f of GDTS) {
  let text = fs.readFileSync(f, 'utf8');
  let removed = 0;
  for (const t of toRemove) { const r = removeBlock(text, t); if (r.removed) removed++; text = r.text; }
  fs.writeFileSync(f, text);
  console.log(`  removed ${removed} old (apex_g2a4 + t9_m16) twins from ${f.includes('Repositories') ? 'repo' : 'dep'}`);
}

// 2) ADD the 6 t9_m16 twins to BOTH GDTs.
for (const form of forms) {
  for (const t of twins) {
    for (const out of GDTS)
      gen(['--src', SRC, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', out, '--append'], `${form}_${t.suffix}`);
    console.log(`    twin ${form}_${t.suffix}`);
  }
}
for (const f of GDTS) console.log(`AFTER  ${f.includes('Repositories') ? 'repo' : 'dep '}: ${cnt(f)} twin entries (net 0: -6 G7 +6 M16)`);
