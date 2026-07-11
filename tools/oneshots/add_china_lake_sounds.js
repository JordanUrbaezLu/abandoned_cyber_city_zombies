// Hand-add China Lake sound aliases (like the Mahem: NOT in gen_box_weapon_sounds GUNS because its
// reload foley token is "shell_in" (singular) mapping TWO wavs shell_in1/shell_in2 - the auto-scanner
// names by wav basename so it can't produce that. Clone the SAME template rows the generator uses.
const fs = require('fs');
const path = require('path');
const CSV = path.resolve(__dirname, '../../../../../../Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_skye_box_weapons.csv');
// safer: absolute repo path
const CSV2 = 'C:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_skye_box_weapons.csv';
const file = fs.existsSync(CSV2) ? CSV2 : CSV;

let txt = fs.readFileSync(file, 'utf8');
const lines = txt.replace(/\n+$/,'').split('\n');
const find = (name) => { const r = lines.find(l => l.split(',')[0] === name); if (!r) throw new Error('template not found: ' + name); return r; };
const tmplShotPlr = find('wpn_s1_tac19_shot_plr');
const tmplShotNpc = find('wpn_s1_tac19_shot_npc');
const tmplFoley   = find('wpn_t6_fiveseven_charge');
const setCol = (row, i, v) => { const c = row.split(','); c[i] = v; return c.join(','); };
const mk = (tmpl, name, fsp) => setCol(setCol(tmpl, 0, name), 3, fsp);

if (lines.some(l => l.startsWith('wpn_t5_china_lake_'))) { console.log('China Lake rows already present - skipping.'); process.exit(0); }

const F = (w) => `skye_ports\\t5_china_lake\\fire\\${w}`;
const L = (w) => `skye_ports\\t5_china_lake\\foley\\${w}`;
const add = [
  mk(tmplShotPlr, 'wpn_t5_china_lake_shot_plr',     F('wpn_t5_china_lake_shot.wav')),
  mk(tmplShotNpc, 'wpn_t5_china_lake_shot_npc',     F('wpn_t5_china_lake_shot.wav')),
  mk(tmplShotPlr, 'wpn_t5_china_lake_pap_shot_plr', F('wpn_t5_china_lake_pap_shot.wav')),
  mk(tmplShotNpc, 'wpn_t5_china_lake_pap_shot_npc', F('wpn_t5_china_lake_pap_shot.wav')),
  mk(tmplFoley,   'wpn_t5_china_lake_bolt_back',    L('wpn_t5_china_lake_bolt_back.wav')),
  mk(tmplFoley,   'wpn_t5_china_lake_bolt_forward', L('wpn_t5_china_lake_bolt_forward.wav')),
  mk(tmplFoley,   'wpn_t5_china_lake_shell_in',     L('wpn_t5_china_lake_shell_in1.wav')),  // shell_in maps 2 wavs
  mk(tmplFoley,   'wpn_t5_china_lake_shell_in',     L('wpn_t5_china_lake_shell_in2.wav')),  // (same alias -> randomized)
  mk(tmplFoley,   'wpn_t5_china_lake_sight_flip',   L('wpn_t5_china_lake_sight_flip.wav')),
];
const colCount = tmplShotPlr.split(',').length;
for (const r of add) if (r.split(',').length !== colCount) throw new Error('column count mismatch on: ' + r.split(',')[0]);
fs.writeFileSync(file, [...lines, ...add].join('\n') + '\n');
console.log(`appended ${add.length} China Lake rows (cols ${colCount}). Names:`);
add.forEach(r => console.log('  ' + r.split(',')[0]));
