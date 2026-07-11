// HAVOC stepped charge, asset side (user 2026-07-06):
//  1. Slice the 1.25s charge riser into TAIL cuts (0.9375/0.625/0.3125s) so each charge step's
//     windup sound ends exactly at the first shot -> alignment by construction.
//  2. Add alias rows acc_havoc_charge_75/_50/_25 (clone of the full riser's row).
//  3. Set fireDelayAnim = vm_apex_beam_rifle_fire on the base GDT block (gun shakes while spooling).
//  4. Generate acc_havoc_chg.gdt: 8 clones (chg1..4 x base/_up) with stepped fireDelay + tail SFX.
// RUN ORDER: this runs AFTER gen_apex_up.js (clones read the CURRENT base + _up blocks).
const fs = require('fs');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const BASE_GDT = TOOLS + '/source_data/zeroy/APEX_BO3.gdt';
const UP_GDT = TOOLS + '/source_data/acc_apex_up.gdt';
const CHG_GDT = TOOLS + '/source_data/acc_havoc_chg.gdt';
const WAV = TOOLS + '/sound_assets/acc/acc_havoc_charge.wav';
const CSV = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_apex_weapons.csv';

const STEP = 0.3125;                       // 1.25 / 4
const STEPS = [                            // chgN: remaining windup + tail alias
  { n: 1, delay: 3 * STEP, alias: 'acc_havoc_charge_75' },
  { n: 2, delay: 2 * STEP, alias: 'acc_havoc_charge_50' },
  { n: 3, delay: 1 * STEP, alias: 'acc_havoc_charge_25' },
  { n: 4, delay: 0,        alias: '' },    // fully spooled: instant fire, no windup sound
];

// ---- 1. tail wav cuts (48k mono 16-bit)
const b = fs.readFileSync(WAV);
const di = b.indexOf(Buffer.from('data'));
const ds = b.readUInt32LE(di + 4);
const RATE = 48000;
for (const s of STEPS) {
  if (!s.alias) continue;
  const keepBytes = Math.min(ds, Math.round(s.delay * RATE) * 2);
  const cut = b.slice(di + 8 + (ds - keepBytes), di + 8 + ds);
  const hdr = Buffer.alloc(44);
  hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + keepBytes, 4); hdr.write('WAVE', 8);
  hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20); hdr.writeUInt16LE(1, 22);
  hdr.writeUInt32LE(RATE, 24); hdr.writeUInt32LE(RATE * 2, 28); hdr.writeUInt16LE(2, 32); hdr.writeUInt16LE(16, 34);
  hdr.write('data', 36); hdr.writeUInt32LE(keepBytes, 40);
  fs.writeFileSync(TOOLS + '/sound_assets/acc/' + s.alias + '.wav', Buffer.concat([hdr, cut]));
  console.log(s.alias + '.wav: ' + (keepBytes / 2 / RATE).toFixed(4) + 's tail');
}

// ---- 2. alias rows
let csv = fs.readFileSync(CSV, 'utf8');
const full = csv.split(/\r?\n/).find(l => l.startsWith('acc_havoc_charge,'));
if (!full) throw new Error('acc_havoc_charge row missing');
let added = 0;
for (const s of STEPS) {
  if (!s.alias || csv.includes(s.alias + ',')) continue;
  const cols = full.split(',');
  cols[0] = s.alias;
  cols[3] = 'acc\\' + s.alias + '.wav';
  csv = csv.replace(/\n?$/, '\n') + cols.join(',') + '\n';
  added++;
}
fs.writeFileSync(CSV, csv);
console.log('aliases added: ' + added);

// ---- helpers
function findBlock(text, name) {
  const m = text.match(new RegExp('"' + name + '"\\s*\\(\\s*"[a-z]+\\.gdf"\\s*\\)'));
  if (!m) throw new Error('no block ' + name);
  const open = text.indexOf('{', m.index);
  let d = 0, end = -1;
  for (let i = open; i < text.length; i++) { if (text[i] === '{') d++; else if (text[i] === '}') { d--; if (!d) { end = i; break; } } }
  return { start: m.index, open, end, header: text.slice(m.index, open).trim(), body: text.slice(open, end + 1) };
}
function setField(body, f, v) {
  const re = new RegExp('("' + f + '"\\s+)"[^"]*"');
  if (!re.test(body)) { console.log('  WARN field ' + f + ' missing'); return body; }
  return body.replace(re, '$1"' + v + '"');
}

// ---- 3. fireDelayAnim on the true base (charge shake) - the _up already regenerated from it? No:
// gen_apex_up ran BEFORE this script historically; set the anim on BOTH base gdt + up gdt directly.
let baseText = fs.readFileSync(BASE_GDT, 'utf8');
const bb = findBlock(baseText, 'apex_beam_rifle_zm');
let bBody = setField(bb.body, 'fireDelayAnim', 'vm_apex_beam_rifle_fire');
baseText = baseText.slice(0, bb.open) + bBody + baseText.slice(bb.end + 1);
fs.writeFileSync(BASE_GDT, baseText);
let upText = fs.readFileSync(UP_GDT, 'utf8');
const ub = findBlock(upText, 'apex_beam_rifle_up_zm');
let uBody = setField(ub.body, 'fireDelayAnim', 'vm_apex_beam_rifle_fire');
upText = upText.slice(0, ub.open) + uBody + upText.slice(ub.end + 1);
fs.writeFileSync(UP_GDT, upText);
console.log('fireDelayAnim = vm_apex_beam_rifle_fire (base + up)');

// ---- 4. the 8 charge-step clones
let out = '{\n';
for (const src of [
  { name: 'apex_beam_rifle_zm', text: baseText, mk: n => 'apex_beam_rifle_chg' + n + '_zm' },
  { name: 'apex_beam_rifle_up_zm', text: upText, mk: n => 'apex_beam_rifle_up_chg' + n + '_zm' },
]) {
  const blk = findBlock(src.text, src.name);
  for (const s of STEPS) {
    let body = blk.body;
    body = setField(body, 'fireDelay', s.delay === 0 ? '0' : String(s.delay));
    body = setField(body, 'fireDelayStartSound', s.alias);
    body = setField(body, 'fireDelayStartSoundPlayer', s.alias);
    const header = blk.header.replace('"' + src.name + '"', '"' + src.mk(s.n) + '"');
    out += '\t' + header + '\n' + body + '\n';
    console.log(src.mk(s.n) + ': fireDelay=' + (s.delay || 0) + ' sfx=' + (s.alias || '(none)'));
  }
}
out += '}\n';
fs.writeFileSync(CHG_GDT, out);
console.log('wrote acc_havoc_chg.gdt (8 charge-step defs)');
