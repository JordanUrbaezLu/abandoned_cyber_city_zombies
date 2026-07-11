// Stopgap Apex sound fixes (user 2026-07-06, real assets pending):
//  1. Prowler/Alternator full-auto: the pack shipped only start.wav (no loop/stop). Loop the start wav for
//     continuous held-fire: set FileSpecSustain(col4) = FileSpec(col3) on the _fire_ and _lfe_ aliases.
//  2. G7 Scout (g2a4): ships ZERO sounds. Borrow the Triple Take's aliases (Apex marksman/sniper) - clone every
//     wpn_apex_tripletake_* row, rename the alias to wpn_apex_g2a4_* (keep the tripletake wav paths).
const fs = require('fs');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SA = TOOLS + '/sound_assets';
const packCsv = TOOLS + '/share/raw/sound/aliases/zm_apex_weapons.csv';
const myCsv = 'C:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_apex_weapons.csv';

let lines = fs.readFileSync(myCsv, 'utf8').split(/\r?\n/);
const header = lines[0];
let rows = lines.slice(1).filter(l => l.trim());

// 1) loop the start for prowler/alternator fire+lfe aliases
let looped = 0;
rows = rows.map(l => {
  const c = l.split(',');
  if (/^wpn_apex_(prowler|alternator)_(fire|lfe)_/.test(c[0]) && c[3] && c[3].trim() && !(c[4] && c[4].trim())) {
    c[4] = c[3];   // FileSpecSustain = FileSpec -> loops the start/lfe wav
    looped++;
    return c.join(',');
  }
  return l;
});
console.log('Prowler/Alternator: looped ' + looped + ' fire/lfe aliases (Sustain = start wav)');

// 2) G7 Scout: clone tripletake rows -> g2a4 (rename alias, keep tripletake wavs)
const packRows = fs.readFileSync(packCsv, 'utf8').split(/\r?\n/).filter(l => l.startsWith('wpn_apex_tripletake_'));
let g2a4 = [];
for (const l of packRows) {
  const c = l.split(',');
  c[0] = c[0].replace('wpn_apex_tripletake_', 'wpn_apex_g2a4_');   // rename alias only
  // verify wav(s) exist (tripletake wavs do)
  let ok = false;
  for (const col of [3, 4, 5]) { const s = (c[col] || '').trim(); if (s && fs.existsSync(SA + '/' + s.split('\\').join('/'))) ok = true; else if (s) c[col] = ''; }
  if (ok) g2a4.push(c.join(','));
}
console.log('G7 Scout: created ' + g2a4.length + ' g2a4 aliases from Triple Take wavs');

const out = [header, ...rows, ...g2a4].join('\n') + '\n';
fs.writeFileSync(myCsv, out);

// final verify: every referenced wav exists
let miss = 0;
for (const l of [...rows, ...g2a4]) { const c = l.split(','); for (const col of [3, 4, 5]) { const s = (c[col] || '').trim(); if (s && !fs.existsSync(SA + '/' + s.split('\\').join('/'))) { console.log('MISSING: ' + c[0] + ' -> ' + s); miss++; } } }
console.log(miss === 0 ? 'OK: all referenced wavs exist (' + (rows.length + g2a4.length) + ' rows)' : 'MISSING ' + miss);
