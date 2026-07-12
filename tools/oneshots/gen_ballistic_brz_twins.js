// Ballistic Knife Berzerker +35% STAB-speed twins (user 2026-07-11).
// Clones the 2 pmr360 projectileweapon defs (wpn_t7_loot_ballistic_knife.gdt) into a STANDALONE
// acc_ballistic_knife_twins.gdt (separate GDT so parallel sessions editing acc_weapon_variants.gdt are
// never clobbered - the acc_freezegun_twins.gdt / acc_war_machine_twins.gdt precedent), scaling ONLY the
// MELEE timing keys x1/1.35 (meleeTime 0.65 -> 0.4815, meleeChargeTime 1 -> 0.7407):
//   - Berzerker speeds the STAB (the knife's own GDT melee - meleeAnim/meleeDamage); the THROW cadence
//     (fireTime 0.5) is deliberately untouched (the item is the MELEE-speed implant, user framing).
//   - x1/1.35 = the exact brz factor the Leviathan brz twins use (leviathan_acc_spd1 meleeTime
//     0.468 -> 0.3467 in acc_weapon_variants.gdt).
// Wiring that pairs with this (already in repo): variant engine (_acc_weapon_variants.gsc variant_guns +
// form_bakes_suffix knife brz-only gate + variant_up_name irregular), zone weaponfull lines, the twin
// retrievable-knife watchers (_zm_weap_ballistic_knife.gsc autoexec). Base GDT accu = default.accu
// (verified - no freezegun-style silent-drop risk).
// IDEMPOTENT: regenerates the twins GDT from the base GDT every run. RE-RUN after any pack reinstall,
// then `gdtdb /update` (cwd = <tools>\gdtdb) + linker.
const fs = require('fs');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const BASE = SD + '/wpn_t7_loot_ballistic_knife.gdt';
const TWINS = SD + '/acc_ballistic_knife_twins.gdt';
const MELEE_FIELDS = ['meleeTime', 'meleeChargeTime'];
const MULT = 1 / 1.35;
const MAP = [
  ['knife_ballistic_zm', 'knife_ballistic_acc_brz_zm'],
  ['knife_ballistic_upgraded_zm', 'knife_ballistic_upgraded_acc_brz_zm'],
];

const base = fs.readFileSync(BASE, 'latin1');

function extractBlock(text, name) {
  const idx = text.indexOf('\t"' + name + '" (');
  if (idx < 0) throw new Error('block not found: ' + name);
  let i = text.indexOf('{', idx), d = 0, e = -1;
  for (; i < text.length; i++) { const c = text[i]; if (c === '{') d++; else if (c === '}') { d--; if (d === 0) { e = i; break; } } }
  if (e < 0) throw new Error('no close: ' + name);
  let le = text.indexOf('\n', e); le = le < 0 ? text.length : le + 1;
  return text.slice(idx, le);
}

let out = '{\n';
for (const [src, dst] of MAP) {
  let block = extractBlock(base, src);
  block = block.replace('"' + src + '"', '"' + dst + '"');   // rename the header (first occurrence only)
  const changes = [];
  for (const f of MELEE_FIELDS) {
    const re = new RegExp('("' + f + '" ")([0-9.]+)(")');
    const m = block.match(re);
    if (!m) { changes.push(f + '=ABSENT'); continue; }
    const scaled = (parseFloat(m[2]) * MULT).toFixed(4);
    block = block.replace(re, '$1' + scaled + '$3');
    changes.push(f + ' ' + m[2] + ' -> ' + scaled);
  }
  out += block;
  console.error(dst + ': ' + changes.join(', '));
}
out += '}\n';
fs.writeFileSync(TWINS, out, 'latin1');
console.error('wrote ' + TWINS + ' (' + out.length + ' bytes). Next: gdtdb /update, then linker.');
