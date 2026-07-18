// Bake the 6 perk twins for the Apex Triple Take (apex_tripletake) - recoil50 / fastreload /
// recoil50_fastreload x base+_up - into BOTH repo + deployed acc_weapon_variants.gdt.
//
// v2 (2026-07-16 projectile rework): the Triple Take is now a *projectileweapon.gdf* (grafted by
// tools/oneshots/prep_apex_tripletake_gdt.js - run FIRST), so this follows the HAVOC twin recipe
// (gen_havoc_twins.js: gen_weapon_variant_gdt.js refuses projectileweapon, clone + scale the
// canonical TWIN_DIMS fields ourselves). Old bullet-era twins are removed GDF-AGNOSTICALLY, so
// re-running over either generation is idempotent.
// THE _zm TRAP (apex memory): twin names put the _zm mode suffix LAST
// (apex_tripletake[_up]_acc_<combo>_zm -> runtime apex_tripletake[_up]_acc_<combo>).
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = process.env.TA_TOOLS_PATH || 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GDTS = [REPO + '/source_data/acc_weapon_variants.gdt', TOOLS + '/source_data/acc_weapon_variants.gdt'];

// base form lives in the pack GDT; the _up form in acc_apex_up.gdt (both PATCHED projectileweapon blocks)
const FORMS = [
  { asset: 'apex_tripletake_zm',    stem: 'apex_tripletake',    src: TOOLS + '/source_data/zeroy/APEX_BO3.gdt' },
  { asset: 'apex_tripletake_up_zm', stem: 'apex_tripletake_up', src: TOOLS + '/source_data/acc_apex_up.gdt' },
];

// canonical TWIN_DIMS (apply_recoil_overhaul.js): recoil50 x0.50, fastreload x0.857
const RECOIL_KEYS = ['hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax'];
const RELOAD_KEYS = ['reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime'];
const TWINS = [
  { suffix: 'acc_recoil50', recoil: 0.50, reload: 1 },
  { suffix: 'acc_fastreload', recoil: 1, reload: 0.857 },
  { suffix: 'acc_recoil50_fastreload', recoil: 0.50, reload: 0.857 },
];

// gdf-AGNOSTIC block finder (bullet-era twins say bulletweapon.gdf, v2 twins projectileweapon.gdf)
function findBlock(text, name) {
  const m = text.match(new RegExp('"' + name + '"\\s*\\(\\s*"[a-z]+weapon\\.gdf"\\s*\\)'));
  if (!m) return null;
  const lineStart = text.lastIndexOf('\n', m.index) + 1;
  const open = text.indexOf('{', m.index);
  let d = 0, end = -1;
  for (let i = open; i < text.length; i++) { if (text[i] === '{') d++; else if (text[i] === '}') { d--; if (!d) { end = i; break; } } }
  return { lineStart, index: m.index, open, end: end + 1, header: text.slice(m.index, open).trim(), body: text.slice(open, end + 1) };
}
function removeBlock(text, name) {
  const b = findBlock(text, name);
  if (!b) return { text, removed: false };
  let e = b.end;
  while (e < text.length && (text[e] === '\n' || text[e] === '\r')) e++;   // eat the trailing newline(s)
  return { text: text.slice(0, b.lineStart) + text.slice(e), removed: true };
}
function scale(body, keys, f) {
  if (f === 1) return body;
  for (const k of keys) {
    body = body.replace(new RegExp('("' + k + '"\\s+)"([^"]*)"'), (m, pre, v) => {
      const n = parseFloat(v);
      if (isNaN(n) || n === 0) return m;
      return pre + '"' + String(Math.round(n * f * 10000) / 10000) + '"';
    });
  }
  return body;
}

const cnt = (f) => (fs.readFileSync(f, 'utf8').match(/"[a-z0-9_]+_acc_[a-z0-9_]+"\s*\(/g) || []).length;
for (const f of GDTS) console.log(`BEFORE ${f.includes('Repositories') ? 'repo' : 'dep '}: ${cnt(f)} twin entries`);

for (const out of GDTS) {
  let text = fs.readFileSync(out, 'utf8');

  // 1) remove any existing tripletake twins (bullet-era OR previous v2 run - idempotent)
  let removed = 0;
  for (const form of FORMS) for (const t of TWINS) {
    const r = removeBlock(text, `${form.stem}_${t.suffix}_zm`);
    if (r.removed) removed++;
    text = r.text;
  }

  // 2) clone the patched projectileweapon blocks, scale the twin dims, insert before the outer brace
  let added = '';
  for (const form of FORMS) {
    const blk = findBlock(fs.readFileSync(form.src, 'utf8'), form.asset);
    if (!blk) { console.error(`ABORT: ${form.asset} not found in ${form.src} (run prep_apex_tripletake_gdt.js first)`); process.exit(1); }
    if (!blk.header.includes('bulletweapon.gdf')) { console.error(`ABORT: ${form.asset} is ${blk.header} - expected bulletweapon.gdf (v3 class revert - run the v3 prep first)`); process.exit(1); }
    for (const t of TWINS) {
      const newName = `${form.stem}_${t.suffix}_zm`;   // _zm LAST -> runtime strips it
      let body = blk.body;
      body = scale(body, RECOIL_KEYS, t.recoil);
      body = scale(body, RELOAD_KEYS, t.reload);
      added += '\t' + blk.header.replace(`"${form.asset}"`, `"${newName}"`) + '\n' + body + '\n';
    }
  }
  const insert = text.lastIndexOf('}');   // append inside the trailing outer brace
  text = text.slice(0, insert) + added + text.slice(insert);
  fs.writeFileSync(out, text);
  console.log(`  ${out.includes('Repositories') ? 'repo' : 'dep '}: removed ${removed} old twins, added 6 projectileweapon twins`);
}
for (const f of GDTS) console.log(`AFTER  ${f.includes('Repositories') ? 'repo' : 'dep '}: ${cnt(f)} twin entries (net 0)`);
