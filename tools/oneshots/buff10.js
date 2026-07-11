'use strict';
// +10% damage buff to every LIVE gun's acc_weapon_balance_mult, keyed by the gun's
// IsSubStr guard token (NOT by the numeric literal - 0.15 & 0.21 each appear on two
// lines, one of which must stay). Excludes: Thundergun, Blast-O-Matic, Mahem, CEL-3
// (user), + ASM1 (retired/inert) & China Lake (not in game).
const fs = require('fs');
const F = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/scripts/zm/zm_abandoned_cyber_city/_acc_damage.gsc';
let lines = fs.readFileSync(F, 'utf8').split('\n');

// token -> [oldValue, newValue]  (newValue = round(old*1.10) at the token's own precision)
const MAP = {
  apex_alternator_up: ['0.594', '0.6534'],
  apex_alternator:    ['0.15',  '0.165'],
  apex_peacekeeper:   ['0.344', '0.3784'],
  apex_prowler:       ['0.41',  '0.451'],
  apex_g2a4:          ['0.522', '0.5742'],
  apex_beam_rifle:    ['0.299', '0.3289'],
  t6_fiveseven:       ['0.2522','0.27742'],
  s1_tac19:           ['0.4539','0.49929'],
  t6_olympia:         ['0.3794','0.41734'],
  t9_streetsweeper:   ['0.0744','0.08184'],
  t9_ak47:            ['0.2689','0.29579'],
  t9_xm4:             ['0.21',  '0.231'],
  t9_grav:            ['0.15',  '0.165'],
  s1_ae4:             ['0.31',  '0.341'],
  s4_ppsh41:          ['0.2225','0.24475'],
  t6_chicom_cqb:      ['0.2575','0.28325'],
  t9_ak74u:           ['0.184', '0.2024'],
  t8_paladin_hb50:    ['0.1385','0.15235'],
  t9_m60:             ['0.206', '0.2266'],
  t9_rpd:             ['0.1092','0.12012'],
  s1_rw1:             ['0.132', '0.1452'],
  s1_mk14:            ['0.2619','0.28809'],
  s1_mors:            ['0.2123','0.23353'],
};

const hits = {};
for (const tok of Object.keys(MAP)) hits[tok] = 0;

for (let i = 0; i < lines.length; i++) {
  const ln = lines[i];
  const m = ln.match(/IsSubStr\(\s*weapon_name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+([0-9.]+)\s*;/);
  if (!m) continue;
  const tok = m[1];
  if (!(tok in MAP)) continue;              // not a buffed gun (excluded / not in map)
  const [oldV, newV] = MAP[tok];
  if (m[2] !== oldV) {
    console.error(`MISMATCH ${tok}: expected ${oldV} got ${m[2]} (line ${i+1})`);
    process.exit(2);
  }
  // replace ONLY the `return <old>;` occurrence (first on the line; comment copies lack the `return ` prefix)
  lines[i] = ln.replace(`return ${oldV};`, `return ${newV};`);
  hits[tok]++;
}

let bad = false;
for (const tok of Object.keys(MAP)) {
  if (hits[tok] !== 1) { console.error(`TOKEN ${tok} matched ${hits[tok]} times (expected 1)`); bad = true; }
}
if (bad) process.exit(3);

fs.writeFileSync(F, lines.join('\n'));
console.log('OK - buffed', Object.keys(MAP).length, 'guns +10%');
for (const tok of Object.keys(MAP)) console.log(`  ${tok}: ${MAP[tok][0]} -> ${MAP[tok][1]}`);
