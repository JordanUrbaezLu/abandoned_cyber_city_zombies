// add_mdl_sound_aliases.js  (user 2026-07-25)
// Give the EPG-1 (s1_mdl reskin) a FIRE sound. The MDL GDT references custom Skye aliases
// (wpn_s1_mdl_shot_plr/_npc + wpn_s1_mdl_pap_shot_plr/_npc) that our sound alias table lacked,
// so the gun fired SILENT (its explosion rides the stock wpn_rpg_explo_01, audible). The Skye
// pack ships the wavs at sound_assets\skye_ports\s1_mdl\fire\{wpn_s1_mdl_shot,wpn_s1_mdl_pap_shot}.wav.
//
// This clones the 4 Mahem FIRE alias rows in sound/aliases/acc_skye_box_weapons.csv (s1_mahem is the
// same Skye AW launcher family, so its 2d _plr / 3d _npc rows are the exact template) and swaps
// s1_mahem -> s1_mdl in the alias name AND the wav path. Guaranteed 102-column format (no hand-counting).
// Idempotent. A full build (cod2map64 rebuilds the sound bank - triggered by the .zone change) picks these up.
'use strict';
const fs = require('fs');
const path = require('path');

const csv = path.join(__dirname, '..', '..', 'sound', 'aliases', 'acc_skye_box_weapons.csv');
let lines = fs.readFileSync(csv, 'utf8').split(/\r?\n/);

if (lines.some(l => l.startsWith('wpn_s1_mdl_shot_plr,'))) {
  console.log('add_mdl_sound_aliases: already present (idempotent no-op).');
  process.exit(0);
}

// the 4 Mahem FIRE aliases are our template
const wanted = ['wpn_s1_mahem_shot_plr,', 'wpn_s1_mahem_shot_npc,', 'wpn_s1_mahem_pap_shot_plr,', 'wpn_s1_mahem_pap_shot_npc,'];
const templates = wanted.map(w => lines.find(l => l.startsWith(w)));
if (templates.some(t => !t)) throw new Error('could not find all 4 Mahem fire-alias template rows in ' + csv);

// clone: s1_mahem -> s1_mdl everywhere on the row (name + FileSpec path both use s1_mahem)
const mdlRows = templates.map(t => t.split('s1_mahem').join('s1_mdl'));

// insert right after the last Mahem row so they group with the launcher block
let lastMahem = -1;
for (let i = 0; i < lines.length; i++) if (lines[i].startsWith('wpn_s1_mahem_')) lastMahem = i;
lines.splice(lastMahem + 1, 0, ...mdlRows);

fs.writeFileSync(csv, lines.join('\n'));
console.log('add_mdl_sound_aliases: inserted ' + mdlRows.length + ' EPG-1 fire aliases after the Mahem block:');
mdlRows.forEach(r => console.log('  + ' + r.split(',').slice(0, 4).join(',')));
console.log('NEXT: FULL build (cod2map64 rebuilds the sound bank via the .zone trigger). Verify no "no files for filespec".');
