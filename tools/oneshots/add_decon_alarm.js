'use strict';
// Add acc_decon_alarm to acc_audio.csv by cloning the known-good acc_shard_pickup row
// (identical column structure -> bank-safe), pointed at an installed siren wav, 2D for a
// non-positional klaxon (played via zm_utility::play_sound_2D). Placeholder wav is game-rip
// (civil_protector pack) - flagged for a CC0 swap before publish.
const fs = require('fs');
const F = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_audio.csv';
let lines = fs.readFileSync(F, 'utf8').split(/\r?\n/);
const headerCols = lines[0].split(',').length;

const idx = lines.findIndex(l => l.startsWith('acc_shard_pickup,'));
if (idx < 0) { console.error('template acc_shard_pickup not found'); process.exit(2); }
if (lines.some(l => l.startsWith('acc_decon_alarm,'))) { console.error('acc_decon_alarm already exists - aborting'); process.exit(3); }

const c = lines[idx].split(',');
c[0] = 'acc_decon_alarm';
c[3] = 'zmb\\ai\\civil_protector\\police_box_siren.wav';
// flip the single channel token 3d -> 2d for a non-positional klaxon
let flipped = 0;
for (let i = 0; i < c.length; i++) if (c[i] === '3d') { c[i] = '2d'; flipped++; }
const row = c.join(',');
if (c.length !== headerCols) { console.error(`column mismatch: ${c.length} vs header ${headerCols}`); process.exit(4); }

// insert right after the shard row (keep SFX grouped)
lines.splice(idx + 1, 0, row);
fs.writeFileSync(F, lines.join('\n'));
console.log(`added acc_decon_alarm (${c.length} cols, header ${headerCols}, channel-flips ${flipped})`);
console.log(row.slice(0, 90) + ' ...');
