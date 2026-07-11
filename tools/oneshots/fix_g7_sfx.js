'use strict';
// Fix G7 (apex_g2a4) silent-fire: every g2a4 fire/lfe alias's Secondary (col 9) points at an
// un-ported Triple Take / DSR-50 alias (dangling -> the T7 AliasBuilder drops the alias -> no
// sound). Repoint each to a VALID g2a4 companion (its own _lfe, which has a real wav), and
// terminate the _lfe aliases with an empty secondary. Mirrors the working alternator/prowler/
// beam chain (fire -> own lfe). Col 9 = "Secondary" (header: 1 Name..9 Secondary).
const fs = require('fs');
const F = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/acc_apex_weapons.csv';
const SEC = 8; // 0-based index of the Secondary column (9th)

// alias name -> new Secondary value
const MAP = {
  wpn_apex_g2a4_fire_npc:  'wpn_apex_g2a4_lfe_npc',
  wpn_apex_g2a4_fire_npc2: 'wpn_apex_g2a4_lfe_npc',
  wpn_apex_g2a4_fire_plr:  'wpn_apex_g2a4_lfe',
  wpn_apex_g2a4_fire_plr2: 'wpn_apex_g2a4_lfe',
  wpn_apex_g2a4_lfe:       '',
  wpn_apex_g2a4_lfe_npc:   '',
};
// only rewrite when the current secondary is one of these known-dangling refs (safety)
const DANGLING = new Set([
  'wpn_apex_tripletake_lfe_npc','wpn_apex_tripletake_fire_npc2','wpn_apex_tripletake_fire_plr2',
  'wpn_apex_tripletake_lfe','wpn_dsr50_fire_plr_decay','wpn_dsr50_fire_npc_decay',
]);

let lines = fs.readFileSync(F, 'utf8').split('\n');
let changed = 0; const log = [];
for (let i = 0; i < lines.length; i++) {
  if (!lines[i] || lines[i].startsWith('#')) continue;
  const c = lines[i].split(',');
  const name = c[0];
  if (!(name in MAP)) continue;
  const old = c[SEC] === undefined ? '' : c[SEC];
  if (old !== '' && !DANGLING.has(old)) { console.error(`UNEXPECTED sec on ${name}: "${old}" - skipped`); continue; }
  if (old === MAP[name]) continue;
  c[SEC] = MAP[name];
  lines[i] = c.join(',');
  changed++; log.push(`${name}: sec "${old}" -> "${MAP[name]}"`);
}
fs.writeFileSync(F, lines.join('\n'));
for (const l of log) console.log('  ' + l);
console.log(`OK - ${changed} rows fixed (expected 8: fire_npc, fire_npc2, fire_plr, fire_plr2, lfe x2, lfe_npc x2)`);
if (changed !== 8) { console.error('!! unexpected count - REVIEW'); process.exit(3); }
