// HAVOC charge-up (user 2026-07-06): 1s hold-to-fire wind-up via the native fireDelay field
// (War Machine-style), with the pack's own 1.00s wpn_apex_beam_rifle_press wav as the charge SFX.
// Edits the APEX_BO3.gdt BASE block - run gen_apex_up.js after so the _up clone inherits.
const fs = require('fs');
const P = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/zeroy/APEX_BO3.gdt';
let text = fs.readFileSync(P, 'utf8');

const hdr = /"apex_beam_rifle_zm"\s*\(\s*"[a-z]+\.gdf"\s*\)/;
const m = text.match(hdr);
if (!m) throw new Error('no beam_rifle block');
const start = m.index;
const next = text.slice(start + 10).search(/"apex_[a-z0-9_]+"\s*\(\s*"[a-z]+\.gdf"\s*\)/);
const end = next < 0 ? text.length : start + 10 + next;
let block = text.slice(start, end);

const SET = {
  fireDelay: '1',                                       // 1s of holding fire before the first shot
  fireDelayStartSound: 'wpn_apex_beam_rifle_press',     // world/3p charge cue
  fireDelayStartSoundPlayer: 'wpn_apex_beam_rifle_press', // 1p charge cue (wav is exactly 1.00s)
};
for (const [f, v] of Object.entries(SET)) {
  const re = new RegExp('("' + f + '"\\s+)"[^"]*"');
  if (!re.test(block)) { console.log('WARN: ' + f + ' not found'); continue; }
  block = block.replace(re, '$1"' + v + '"');
  console.log(f + ' = ' + v);
}
text = text.slice(0, start) + block + text.slice(end);
fs.writeFileSync(P, text);
console.log('APEX_BO3.gdt: Havoc charge-up applied');
