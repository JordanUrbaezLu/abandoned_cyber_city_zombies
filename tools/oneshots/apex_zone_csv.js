const fs = require('fs');
const REPO = 'C:/Users/jorda/Repositories/abandoned_cyber_city_zombies';

// ---- ZONE ----
const zonePath = REPO + '/zone_source/zm_abandoned_cyber_city.zone';
let zone = fs.readFileSync(zonePath, 'utf8').split('\n');
const removed = ['t6_chicom_cqb', 't8_paladin_hb50', 's4_klauser', 't5_china_lake'];
// drop any weapon,/weaponfull, line whose asset starts with a removed gun
const dropZone = (l) => {
  const m = l.match(/^(weapon|weaponfull),([a-z0-9_]+)/);
  if (!m) return false;
  return removed.some(g => m[2] === g || m[2].startsWith(g + '_'));
};
const before = zone.length;
zone = zone.filter(l => !dropZone(l));
const droppedZone = before - zone.length;

// insert Apex weapon lines after `weapon,s1_mahem_up`
const apexZone = [
  '// Apex Legends guns (zeroy pack, user 2026-07-06 migration). Asset ids carry a baked _zm; _up forms in acc_apex_up.gdt (legend-skin PaP model). Twin-less.',
  'weapon,apex_peacekeeper_zm', 'weapon,apex_peacekeeper_zm_up',
  'weapon,apex_beam_rifle_zm',  'weapon,apex_beam_rifle_zm_up',
  'weapon,apex_alternator_zm',  'weapon,apex_alternator_zm_up',
  'weapon,apex_prowler_zm',     'weapon,apex_prowler_zm_up',
  'weapon,apex_g2a4_zm',        'weapon,apex_g2a4_zm_up',
];
const mahemIdx = zone.findIndex(l => l.trim() === 'weapon,s1_mahem_up');
if (mahemIdx < 0) throw new Error('anchor weapon,s1_mahem_up not found');
zone.splice(mahemIdx + 1, 0, ...apexZone);
fs.writeFileSync(zonePath, zone.join('\n'));
console.log(`ZONE: dropped ${droppedZone} removed-gun lines, inserted ${apexZone.length - 1} Apex weapon lines after s1_mahem_up`);

// ---- CSV ----
const csvPath = REPO + '/gamedata/weapons/zm/zm_levelcommon_weapons.csv';
let csv = fs.readFileSync(csvPath, 'utf8').split(/\r?\n/);
const b2 = csv.length;
csv = csv.filter(l => !removed.some(g => l.startsWith(g + ',')));
const droppedCsv = b2 - csv.length;
const apexCsv = [
  'apex_peacekeeper_zm,apex_peacekeeper_zm_up,,1500,shotgun,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,shotgun,,,',
  'apex_beam_rifle_zm,apex_beam_rifle_zm_up,,1500,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,',
  'apex_alternator_zm,apex_alternator_zm_up,,1300,smg,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,smg,,,',
  'apex_prowler_zm,apex_prowler_zm_up,,1300,smg,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,smg,,,',
  'apex_g2a4_zm,apex_g2a4_zm_up,,1250,rifle,,,,,TRUE,FALSE,FALSE,,,FALSE,TRUE,rifle,,,',
];
// insert after the mahem row (s1_mahem,)
const mIdx = csv.findIndex(l => l.startsWith('s1_mahem,'));
if (mIdx < 0) throw new Error('CSV anchor s1_mahem row not found');
csv.splice(mIdx + 1, 0, ...apexCsv);
fs.writeFileSync(csvPath, csv.join('\n'));
console.log(`CSV: dropped ${droppedCsv} removed-gun rows, inserted ${apexCsv.length} Apex rows after s1_mahem`);
