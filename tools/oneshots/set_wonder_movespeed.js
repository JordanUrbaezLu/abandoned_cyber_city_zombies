// Thundergun -> LMG move speed (0.86), Fire Bow -> AR move speed (0.93) (user 2026-07-11).
// BLOCK-SCOPED: only the named weapon blocks are touched (the bow GDT holds 7 bows - we change ONLY the
// demongate/fire bow). Covers base + _up + EVERY fastreload twin ("don't miss any twins"). Idempotent
// (re-setting to the same value is a no-op). GDT field change -> run gdtdb /update (PowerShell) + link after.
const fs = require('fs');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';

// [file, blockName, moveSpeedScale]
const EDITS = [
  // Thundergun = LMG tier 0.86
  ['night_t5_thundergun.gdt', 'thundergun_zm',                              '0.86'],
  ['night_t5_thundergun.gdt', 'thundergun_upgraded_zm',                     '0.86'],
  ['acc_weapon_variants.gdt', 'thundergun_acc_fastreload_zm',               '0.86'],
  ['acc_weapon_variants.gdt', 'thundergun_upgraded_acc_fastreload_zm',      '0.86'],
  // Fire Bow (demongate ONLY) = AR tier 0.93
  ['wpn_t7_zmb_bow.gdt',      'elemental_bow_demongate_zm',                 '0.93'],
  ['acc_weapon_variants.gdt', 'elemental_bow_demongate_acc_fastreload_zm',  '0.93'],
];

function blockRange(text, name) {
  const idx = text.indexOf('\t"' + name + '" (');
  if (idx < 0) throw new Error('block not found: ' + name);
  let i = text.indexOf('{', idx), d = 0, e = -1;
  for (; i < text.length; i++) { const c = text[i]; if (c === '{') d++; else if (c === '}') { d--; if (d === 0) { e = i + 1; break; } } }
  if (e < 0) throw new Error('no close brace: ' + name);
  return [idx, e];
}

const byFile = {};
for (const [f, n, v] of EDITS) (byFile[f] = byFile[f] || []).push([n, v]);

for (const f of Object.keys(byFile)) {
  const p = SD + '/' + f;
  let text = fs.readFileSync(p, 'latin1');
  for (const [name, val] of byFile[f]) {
    const [s, e] = blockRange(text, name);           // re-search each time (offsets shift after an edit)
    const block = text.slice(s, e);
    const m = block.match(/"moveSpeedScale" "([^"]*)"/);
    if (!m) { console.error('!! NO moveSpeedScale field in ' + name); continue; }
    const nb = block.replace(/"moveSpeedScale" "[^"]*"/, '"moveSpeedScale" "' + val + '"');
    text = text.slice(0, s) + nb + text.slice(e);
    console.error(f + ' :: ' + name + '  moveSpeedScale ' + m[1] + ' -> ' + val);
  }
  fs.writeFileSync(p, text, 'latin1');
}
console.error('done - 6 blocks (Thundergun x4 @0.86, Fire Bow x2 @0.93)');
