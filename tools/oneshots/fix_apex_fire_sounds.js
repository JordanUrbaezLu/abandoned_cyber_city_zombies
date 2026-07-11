// Convert Alternator + Prowler from LOOP-fire (loop wavs never shipped; prowler even points at
// wpn_bo4_cordite_* aliases we don't carry) to PER-SHOT fire using the start-wav aliases that DO exist.
// Edits the installed APEX_BO3.gdt base blocks (scoped by block line ranges). Run BEFORE gen_apex_up.js
// so the _up clones inherit the fix. (user 2026-07-06: "sfx wasn't triggering on every shot")
const fs = require('fs');
const P = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/zeroy/APEX_BO3.gdt';
let text = fs.readFileSync(P, 'utf8');

const FIX = [
  { gun: 'alternator', fire: 'wpn_apex_alternator_fire' },
  { gun: 'prowler',    fire: 'wpn_apex_prowler_fire' },
];

for (const f of FIX) {
  // bound the base block: from its header to the next block header
  const hdr = new RegExp('"apex_' + f.gun + '_zm"\\s*\\(\\s*"[a-z]+\\.gdf"\\s*\\)');
  const m = text.match(hdr);
  if (!m) throw new Error('no block for ' + f.gun);
  const start = m.index;
  const next = text.slice(start + 10).search(/"apex_[a-z0-9_]+"\s*\(\s*"[a-z]+\.gdf"\s*\)/);
  const end = next < 0 ? text.length : start + 10 + next;
  let block = text.slice(start, end);

  const set = (field, val) => {
    const re = new RegExp('("' + field + '"\\s+)"[^"]*"');
    if (!re.test(block)) { console.log(`  WARN ${f.gun}: field ${field} not found`); return; }
    block = block.replace(re, '$1"' + val + '"');
  };
  set('fireSound', f.fire + '_npc');
  set('fireSoundPlayer', f.fire + '_plr');
  set('loopFireSound', '');
  set('loopFireSoundPlayer', '');
  set('loopFireEndSound', '');
  set('loopFireEndSoundPlayer', '');

  text = text.slice(0, start) + block + text.slice(end);
  console.log(`${f.gun}: per-shot fire = ${f.fire}_plr/_npc, loop fields blanked`);
}
fs.writeFileSync(P, text);
console.log('APEX_BO3.gdt updated');
