// Winter's Howl (freezegun) move speed + fastreload wonder twins (user 2026-07-11).
//  (1) sets moveSpeedScale 1.07 on the base + _up blocks (wpn_t8_zmb_freezegun.gdt) - the pistol/melee
//      mobility tier the user asked for (a utility slow-gun you kite with).
//  (2) clones the 2 fastreload wonder twins (reload fields x0.857 - the exact fastreload recipe) into a
//      STANDALONE acc_freezegun_twins.gdt (a separate GDT so parallel sessions editing acc_weapon_variants.gdt
//      are never clobbered - the acc_war_machine_twins.gdt precedent). Twins inherit the 1.07 move speed.
// IDEMPOTENT (the moveSpeedScale replace always lands on 1.07). RE-RUN after any freezegun asset reinstall
// (the rar ships moveSpeedScale 1) - then `gdtdb /update` (PowerShell) + linker.
const fs = require('fs');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const BASE = SD + '/wpn_t8_zmb_freezegun.gdt';
const TWINS = SD + '/acc_freezegun_twins.gdt';
const MOVE = '1.07';
const RELOAD_FIELDS = ['reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime'];
const MULT = 0.857;
const MAP = [
  ['freezegun_zm', 'freezegun_acc_fastreload_zm'],
  ['freezegun_upgraded_zm', 'freezegun_upgraded_acc_fastreload_zm'],
];

let base = fs.readFileSync(BASE, 'latin1');

// (1) move speed 1.07 on every moveSpeedScale in the GDT (only the 2 weapon blocks carry the field).
const nMove = (base.match(/"moveSpeedScale" "/g) || []).length;
base = base.replace(/("moveSpeedScale" ")[^"]*(")/g, '$1' + MOVE + '$2');

// (1b) accuracy -> default.accu. **THE SILENT-DROP FIX (2026-07-11):** the pack shipped
// aiVsAiAccuracyGraph "ray_gun.accu" / aiVsPlayerAccuracyGraph "pistol.accu", which made the linker
// SILENTLY DROP the entire weapon (base + twins NOT packed into the .ff -> GetWeapon("freezegun") = none
// -> the gun was NEVER in the box OR the dev loadout - "I never got it"). No linker error is logged (memory
// silent-weapon-conversion-kill-dangling-refs). Every projectileweapon that DOES pack (Fire Bow, Havoc) uses
// default.accu, so we repoint to that. Verify after build: assetinfo must list `weapon,freezegun_zm`.
const nAccu = (base.match(/"aiVs(?:Ai|Player)AccuracyGraph" "/g) || []).length;
base = base.replace(/("aiVsAiAccuracyGraph" ")[^"]*(")/g, '$1default.accu$2');
base = base.replace(/("aiVsPlayerAccuracyGraph" ")[^"]*(")/g, '$1default.accu$2');

// (1c) reload 35% FASTER on the base + _up (user 2026-07-11): reloadTime/reloadEmptyTime -> 2.47
// (pack ships 3.8; 3.8 x 0.65 = -35%). ABSOLUTE set (idempotent - not a multiply, so re-runs don't compound).
// The fastreload TWINS then clone off this base -> 2.47 x 0.857 = ~2.12s (Speed Cola Mega on top of the 35%).
const RELOAD_35 = '2.47';
const nReload = (base.match(/"reload(?:Empty)?Time" "/g) || []).length;
base = base.replace(/("reloadTime" ")[^"]*(")/g, '$1' + RELOAD_35 + '$2');
base = base.replace(/("reloadEmptyTime" ")[^"]*(")/g, '$1' + RELOAD_35 + '$2');

fs.writeFileSync(BASE, base, 'latin1');
console.error('moveSpeedScale ' + MOVE + ' on ' + nMove + ' block(s); accuracy -> default.accu on ' + nAccu + ' field(s); reloadTime -> ' + RELOAD_35 + ' on ' + nReload + ' field(s)');

function extractBlock(text, name) {
  const idx = text.indexOf('\t"' + name + '" (');
  if (idx < 0) throw new Error('block not found: ' + name);
  let i = text.indexOf('{', idx), d = 0, e = -1;
  for (; i < text.length; i++) { const c = text[i]; if (c === '{') d++; else if (c === '}') { d--; if (d === 0) { e = i; break; } } }
  if (e < 0) throw new Error('no close: ' + name);
  let le = text.indexOf('\n', e); le = le < 0 ? text.length : le + 1;
  return text.slice(idx, le);
}

// (2) clone the 2 fastreload twins (base already carries moveSpeed 1.07 -> twins inherit it).
let out = '{\n';
for (const [src, dst] of MAP) {
  let block = extractBlock(base, src);
  const occ = block.split('"' + src + '"').length - 1;
  block = block.replace('"' + src + '"', '"' + dst + '"');   // rename the header (first occurrence only)
  const changes = [];
  for (const f of RELOAD_FIELDS) {
    const re = new RegExp('("' + f + '" ")([0-9.]+)(")');
    const m = block.match(re);
    if (!m) { changes.push(f + '=ABSENT'); continue; }
    const nv = (parseFloat(m[2]) * MULT).toFixed(4).replace(/0+$/, '').replace(/\.$/, '');
    block = block.replace(re, '$1' + nv + '$3');
    changes.push(f + ': ' + m[2] + ' -> ' + nv);
  }
  console.error(dst + '  (src name occ=' + occ + ')  |  ' + changes.join(', '));
  out += block;
}
out += '}\n';
fs.writeFileSync(TWINS, out, 'latin1');
console.error('wrote acc_freezegun_twins.gdt (2 fastreload twin blocks)');
