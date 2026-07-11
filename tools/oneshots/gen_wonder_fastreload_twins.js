// Clone the 5 fastreload-only wonder/special twins (Mahem x2, Thundergun x2, Fire Bow x1).
// Delta = the 4 reload fields x0.857 (the exact fastreload recipe measured from t9_ak47's twins).
const fs = require('fs');

const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const FILES = {
  mahem: TOOLS + '/skye_s1_mahem.gdt',
  tg: TOOLS + '/night_t5_thundergun.gdt',
  bow: TOOLS + '/wpn_t7_zmb_bow.gdt',
  twins: TOOLS + '/acc_weapon_variants.gdt',
};

const MAP = [
  ['mahem', 's1_mahem', 's1_mahem_acc_fastreload'],
  ['mahem', 's1_mahem_up', 's1_mahem_up_acc_fastreload'],
  ['tg', 'thundergun_zm', 'thundergun_acc_fastreload_zm'],
  ['tg', 'thundergun_upgraded_zm', 'thundergun_upgraded_acc_fastreload_zm'],
  ['bow', 'elemental_bow_demongate_zm', 'elemental_bow_demongate_acc_fastreload_zm'],
];

const RELOAD_FIELDS = ['reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime'];
const MULT = 0.857;

const srcs = {};
for (const k of Object.keys(FILES)) srcs[k] = fs.readFileSync(FILES[k], 'latin1');

function extractBlock(text, name) {
  const idx = text.indexOf('\t"' + name + '" (');
  if (idx < 0) throw new Error('block not found: ' + name);
  let i = text.indexOf('{', idx), d = 0, e = -1;
  for (; i < text.length; i++) { const c = text[i]; if (c === '{') d++; else if (c === '}') { d--; if (d === 0) { e = i; break; } } }
  if (e < 0) throw new Error('no close: ' + name);
  let le = text.indexOf('\n', e); le = le < 0 ? text.length : le + 1;
  return text.slice(idx, le);
}

let out = '';
for (const [srcKey, srcName, newName] of MAP) {
  let block = extractBlock(srcs[srcKey], srcName);
  const occ = block.split('"' + srcName + '"').length - 1;
  if (occ !== 1) throw new Error(srcName + ' occurs ' + occ + 'x in its block (expected 1 - self-reference?)');
  block = block.replace('"' + srcName + '"', '"' + newName + '"');
  const changes = [];
  for (const f of RELOAD_FIELDS) {
    const re = new RegExp('("' + f + '" ")([0-9.]+)(")');
    const m = block.match(re);
    if (!m) { changes.push(f + '=ABSENT'); continue; }   // some defs may lack a field - report, don't fail
    const nv = (parseFloat(m[2]) * MULT).toFixed(4).replace(/0+$/, '').replace(/\.$/, '');
    block = block.replace(re, '$1' + nv + '$3');
    changes.push(f + ': ' + m[2] + ' -> ' + nv);
  }
  console.error(newName, '<-', srcName, '|', changes.join(', '));
  out += block;
}

let twins = srcs.twins;
const lastBrace = twins.lastIndexOf('}');
twins = twins.slice(0, lastBrace) + out + twins.slice(lastBrace);
fs.writeFileSync(FILES.twins, twins, 'latin1');
console.error('appended 5 wonder fastreload twin blocks to acc_weapon_variants.gdt');
