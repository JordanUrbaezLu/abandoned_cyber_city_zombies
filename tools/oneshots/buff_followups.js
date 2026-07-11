'use strict';
// Same-day (2026-07-07) per-gun follow-up damage tweaks, token-keyed (whitespace-robust).
const fs = require('fs');
const F = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc';
let lines = fs.readFileSync(F, 'utf8').split('\n');

// token -> [expectedOld, new]
const MAP = {
  apex_alternator_up: ['0.6534',  '0.71874'],   // +10% MORE (user)
  apex_alternator:    ['0.165',   '0.1815'],     // +10% MORE (user)
  t9_streetsweeper:   ['0.08184', '0.106392'],   // +30% (user)
  apex_beam_rifle:    ['0.3289',  '0.36179'],     // Havoc +10% MORE (user)
};
const hits = {}; for (const t of Object.keys(MAP)) hits[t] = 0;

for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/IsSubStr\(\s*weapon_name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+([0-9.]+)\s*;/);
  if (!m || !(m[1] in MAP)) continue;
  const [oldV, newV] = MAP[m[1]];
  if (m[2] !== oldV) { console.error(`MISMATCH ${m[1]}: expected ${oldV} got ${m[2]}`); process.exit(2); }
  lines[i] = lines[i].replace(`return ${oldV};`, `return ${newV};`);
  hits[m[1]]++;
}
let bad = false;
for (const t of Object.keys(MAP)) if (hits[t] !== 1) { console.error(`TOKEN ${t} matched ${hits[t]}x`); bad = true; }
if (bad) process.exit(3);
fs.writeFileSync(F, lines.join('\n'));
for (const t of Object.keys(MAP)) console.log(`  ${t}: ${MAP[t][0]} -> ${MAP[t][1]}`);
console.log('OK');
