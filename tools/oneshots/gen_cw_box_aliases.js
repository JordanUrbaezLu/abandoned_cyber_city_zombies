#!/usr/bin/env node
// =============================================================================
// gen_cw_box_aliases.js - author Cold War (t9) box-gun sound aliases for the
// AK-74u / M60 / RPD swaps, mirroring the shipped AK-47 t9 alias rows 1:1 in
// COLUMN STRUCTURE (the AK-47 block is the gold template; we clone its exact
// column count + template/secondary layout).
//
//   * 10 CORE rows per gun (fixed events): fire shot_plr/npc, shot_last_plr/npc
//     (-> shared common\wpn_t9_low_ammo.wav), pap_shot[_last]_plr/npc (-> shared
//     common\pap\wpn_pap_first.wav), shot_lfe_plr/npc. These are the aliases the
//     t9 GDT's fireSound/lastShotSound/pap fields reference -> MANDATORY.
//   * RELOAD-FOLEY rows generated from each gun's ACTUAL foley wavs
//     (sound_assets\t9_weapons\<sid>\foley\fly_<class>_*.wav). Alias name =
//     wpn_t9_<gun>_<event> where event = wav basename minus "fly_<class>_"
//     (the SAME convention the AK-47 used: fly_ar_damage_tac_mag_in ->
//     wpn_t9_ak47_tac_mag_in), so the reload xanim notetracks resolve.
//
// Idempotent: strips the now-DEAD old aliases (wpn_t5_ak74u_* / wpn_t6_m60_* /
// wpn_t6_rpd_* / wpn_t5_tishina_*) AND any prior wpn_t9_{ak74u,m60,rpd}_* rows
// before re-appending. Removing the old t6_m60 rows also escapes the known-broken
// wpn_t6_m60_pap_shot.wav (CHANGELOG: UNRECOVERABLE on full bank rebuild).
// Run tools/trim_cw_aliases.js AFTER this (drops any row whose template is absent).
//
// Usage: node tools/gen_cw_box_aliases.js [--tools "<modtools root>"]
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const args = process.argv.slice(2);
const TOOLS = args.includes('--tools') ? args[args.indexOf('--tools') + 1]
  : 'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const REPO = path.resolve(__dirname, '..');
const CSV = path.join(REPO, 'sound', 'aliases', 'acc_skye_box_weapons.csv');
const SND = path.join(TOOLS, 'sound_assets', 't9_weapons');

const GUNS = [
  { gun: 'ak74u', sid: 't9_ak74u', cls: 'smg_heavy',   start: 'wpn_smg_heavy_start.wav',    lfe: 'wpn_smg_heavy_lfe.wav' },
  { gun: 'm60',   sid: 't9_m60',   cls: 'lmg_slowfire', start: 'wpn_lmg_slowfire_start.wav', lfe: 'wpn_lmg_slowfire_lfe.wav' },
  { gun: 'rpd',   sid: 't9_rpd',   cls: 'lmg_light',    start: 'wpn_lmg_light_start.wav',    lfe: 'wpn_lmg_light_lfe.wav' },
];

const lines = fs.readFileSync(CSV, 'utf8').split('\n');

// total column count = the AK-47 template rows' width (clone it exactly)
let NCOL = 0;
for (const l of lines) { const c = l.split(','); if (/^wpn_t9_ak47_shot_plr$/.test(c[0])) { NCOL = c.length; break; } }
if (!NCOL) { console.error('ERROR: AK-47 template row wpn_t9_ak47_shot_plr not found - cannot derive column count.'); process.exit(2); }

// columns (verified vs AK-47 rows): 0 name, 3 filespec, 6 template, 8 secondary
function aliasRow(name, filespec, template, secondary) {
  const a = new Array(NCOL).fill('');
  a[0] = name; a[3] = filespec; a[6] = template; if (secondary) a[8] = secondary;
  return a.join(',');
}

// strip dead old aliases + any prior generated t9 rows for these 3 guns
const stripRe = /^(wpn_t5_ak74u_|wpn_t5_tishina_|wpn_t6_m60_|wpn_t6_rpd_|wpn_t9_ak74u_|wpn_t9_m60_|wpn_t9_rpd_)/;
const out = [];
for (const l of lines) { if (stripRe.test(l.split(',')[0])) continue; out.push(l); }
while (out.length && out[out.length - 1].trim() === '') out.pop();

const SHARED_LOW = 't9_weapons\\common\\wpn_t9_low_ammo.wav';
const SHARED_PAP = 't9_weapons\\common\\pap\\wpn_pap_first.wav';
const added = [];
for (const g of GUNS) {
  const P  = (f) => `t9_weapons\\${g.sid}\\${f}`;
  const PF = (f) => `t9_weapons\\${g.sid}\\foley\\${f}`;
  const n  = (e) => `wpn_t9_${g.gun}_${e}`;
  // 10 CORE rows. The fire shot LAYERS the gun's _lfe (bass/boom) wav as its Secondary so every shot carries
  // low-end WEIGHT - the CW models ship a per-gun _lfe that the GDT never plays on its own, leaving the guns
  // thin (user 2026-06-26 "sfx sounded a bit off / not as good"). The LFE is a separate freq band from the
  // mid/high shot, so it adds punch without muddying. (The AK-47 was hand-authored separately + already liked.)
  added.push(aliasRow(n('shot_plr'),          P(g.start),  'wpn_t9_shot_plr', n('shot_lfe_plr')));
  added.push(aliasRow(n('shot_npc'),          P(g.start),  'wpn_t9_shot_npc', n('shot_lfe_npc')));
  added.push(aliasRow(n('shot_last_plr'),     SHARED_LOW,  'wpn_t9_shot_plr', n('shot_plr')));
  added.push(aliasRow(n('shot_last_npc'),     SHARED_LOW,  'wpn_t9_shot_npc', n('shot_npc')));
  added.push(aliasRow(n('pap_shot_plr'),      SHARED_PAP,  'wpn_t9_pap_shot_plr', n('shot_plr')));
  added.push(aliasRow(n('pap_shot_npc'),      SHARED_PAP,  'wpn_t9_pap_shot_npc', n('shot_npc')));
  added.push(aliasRow(n('pap_shot_last_plr'), SHARED_PAP,  'wpn_t9_pap_shot_plr', n('shot_last_plr')));
  added.push(aliasRow(n('pap_shot_last_npc'), SHARED_PAP,  'wpn_t9_pap_shot_npc', n('shot_last_npc')));
  added.push(aliasRow(n('shot_lfe_plr'),      P(g.lfe),    'wpn_t9_shot_plr', 'wpn_t9_shotgun_decay_plr'));
  added.push(aliasRow(n('shot_lfe_npc'),      P(g.lfe),    'wpn_t9_shot_npc', 'wpn_t9_assault_dist_npc'));
  // RELOAD-FOLEY rows from the gun's actual foley wavs
  let fwavs = [];
  try { fwavs = fs.readdirSync(path.join(SND, g.sid, 'foley')).filter(f => new RegExp('^fly_' + g.cls + '_.*\\.wav$').test(f)); }
  catch (e) { console.error(`  ! could not read foley dir for ${g.sid}: ${e.message}`); }
  fwavs.sort();
  for (const w of fwavs) {
    const ev = w.replace(new RegExp('^fly_' + g.cls + '_'), '').replace(/\.wav$/, '');
    added.push(aliasRow(n(ev), PF(w), 'wpn_t9_reload_plr'));
  }
  console.log(`${g.gun} (${g.sid}): 10 core + ${fwavs.length} foley = ${10 + fwavs.length} rows`);
}

out.push('# === BOCW Cold War ports: AK-74u / M60 / RPD (gen_cw_box_aliases.js, user 2026-06-26) ===');
out.push(...added);
out.push('');
fs.writeFileSync(CSV, out.join('\n'));
console.log(`column width matched to AK-47 template: ${NCOL} cols`);
console.log(`wrote ${added.length} alias rows -> ${CSV}`);
