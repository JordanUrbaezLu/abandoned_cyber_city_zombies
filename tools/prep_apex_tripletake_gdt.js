#!/usr/bin/env node
// =============================================================================
// prep_apex_tripletake_gdt.js - IDEMPOTENT install-side prep of the Apex
// Triple Take (APEX_BO3.gdt) so it drops into the box as the B-tier ENERGY
// sniper/marksman that REPLACES the CW M16 in that slot (user 2026-07-11).
// 3 bullets per trigger (shotCount 3, its Apex signature horizontal spread);
// counts as ENERGY for the Nuclear Energy implant (+15%) -> per-trigger damage
// lands at/slightly above the MORS per-shot at every PaP tier (docs/04).
//
// The pristine zeroy rip needs:
//   1. loc normalize (the docs/21 MP-rip trap): head/neck/helmet 10 -> head+helmet
//      5.0 (standard x2.5 headshot), neck 1.0 (M16 precedent); torso 3 / arms+hands 2 /
//      legUpper 1.5 -> ALL 1.0. So body = damage x bal x global x papMult like every gun.
//   2. SOUND retarget: the def ships fireSound/lastShotSound = wpn_bo4_paladin_fire_*
//      which exists in NO alias CSV we carry (dangling = SILENT gun, the G7 lesson).
//      Retarget to the pack's own wpn_apex_tripletake_fire_npc/_plr (real wavs; rows
//      hand-fixed into sound/aliases/acc_apex_weapons.csv - water,over + secondaries).
//   3. ammo: maxAmmo/startAmmo 10 -> 11 (clipRel 1: reserve = 5 x 11 = 55, sniper band).
//   4. move 0.86 -> 0.93 (the marksman-class standard, matching MK14 / MORS / M16).
//   5. recoil x1.25 (GENTLER than the standard x1.75): the rip already ships high kick
//      (adsViewKick ~102 total); x1.25 lands "High" like the M16/MK14 it slots beside.
//   6. _up PaP form -> acc_apex_up.gdt as `apex_tripletake_up_zm` (the _zm-LAST trap:
//      runtime name apex_tripletake_up): legendary_02 skin (gen_apex_up recipe),
//      clip 7 / maxAmmo 12 (reserve 84), damage stays 500 both forms - bal 0.2255 in
//      _acc_damage is the single damage lever, the PaP ladder does the +33/67/100%.
//
// IDEMPOTENT: keeps a `.acc-tripletake-orig` backup of APEX_BO3.gdt and re-derives the
// apex_tripletake_zm BLOCK from it each run (block-scoped: other guns' live edits -
// fix_apex_fire_sounds, havoc fireDelay - are preserved untouched).
//
// USAGE:  node tools/prep_apex_tripletake_gdt.js
// then:   gdtdb /update -> bake twins (tools/oneshots/gen_tripletake_twins.js) -> sync -> link
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GDT = path.join(TOOLS, 'source_data', 'zeroy', 'APEX_BO3.gdt');
const BAK = GDT + '.acc-tripletake-orig';
const UP_GDT = path.join(TOOLS, 'source_data', 'acc_apex_up.gdt');

if (!fs.existsSync(GDT)) { console.error('ABORT: ' + GDT + ' not found (is the Apex pack installed?)'); process.exit(1); }
if (!fs.existsSync(UP_GDT)) { console.error('ABORT: ' + UP_GDT + ' not found (apex _up GDT missing?)'); process.exit(1); }

const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);
const RECOIL_SCALE = 1.25;   // gentler than the standard x1.75 - rip kick is already high (header note 5)

// Base-form field edits (also inherited by the _up clone).
const BASE_FIELDS = {
  locHead: '5', locHelmet: '5', locNeck: '1',
  locTorsoLower: '1', locTorsoMid: '1', locTorsoUpper: '1',
  locLeftArmLower: '1', locLeftArmUpper: '1', locRightArmLower: '1', locRightArmUpper: '1',
  locLeftHand: '1', locRightHand: '1', locLeftLegUpper: '1', locRightLegUpper: '1',
  moveSpeedScale: '0.93',
  maxAmmo: '11', startAmmo: '11',
  // +25% rate of fire (user 2026-07-11 "rate of fire needs to increase"): 0.36 -> 0.288
  // (~167 -> ~208 triggers/min). The paired +25% DAMAGE lives in _acc_damage bal 0.281875.
  fireTime: '0.288',
  // UNLIMITED RANGE (user 2026-07-11): the rip shipped full damage only to 2000u, decaying to
  // minDamage 300 by 5000u. Flatten the whole curve - full 500 at ANY distance: falloff start
  // pushed past any map scale AND the far floor raised to the full damage (belt + suspenders).
  // damageRange2..5 are 0 -> immune to the "damage range went backwards" linker trap (docs/21).
  maxDamageRange: '100000', minDamageRange: '100000', minDamage: '500',
  // ENERGY identity (user 2026-07-11 "energy sfx + fx like the havoc, slightly different"):
  //  - fire sound -> acc_ttk_energy_fire_{npc,plr}: the Havoc's beam-rifle fire wavs pitch-shifted
  //    +1.5..2.5 semitones with the tripletake's own crack layered as Secondary (rows built by
  //    scratchpad add_tripletake_energy_sfx.js into acc_apex_weapons.csv - sharper than the Havoc).
  //  - muzzle flash -> the Havoc's stock fx_muz_energy_pistol_1p/3p (proven packed via the Havoc;
  //    do NOT use the AE4's fx_s1_fusion_muz_flash - that is the known-waived unbundled IW FX).
  //  - tracers -> mtl_s1_plasma_tracer (the AE4's energy tracer, skye_s1_wepcommon.gdt, packed):
  //    3 plasma streaks per trigger = the "slightly different from the Havoc" look (it has a
  //    projectile trail; the tripletake gets hitscan plasma bolts).
  fireSound: 'acc_ttk_energy_fire_npc', fireSoundPlayer: 'acc_ttk_energy_fire_plr',
  lastShotSound: 'acc_ttk_energy_fire_npc', lastShotSoundPlayer: 'acc_ttk_energy_fire_plr',
  viewFlashEffect: 'fx\\\\weapon\\\\fx_muz_energy_pistol_1p.efx',
  worldFlashEffect: 'fx\\\\weapon\\\\fx_muz_energy_pistol_3p.efx',
  tracerType: 'mtl_s1_plasma_tracer', enemyTracerType: 'mtl_s1_plasma_tracer',
  // pack authoring bug: slide_in points at vm_bo4_paladin_slide_in (ships nowhere -> linker
  // "xanim not found"); slide_loop/slide_out already use the tripletake's OWN anims, and
  // vm_apex_tripletake_slide_in.XANIM_BIN ships in xanim_export\apex -> retarget.
  slide_in: 'vm_apex_tripletake_slide_in',
};
// _up-only deltas on top of BASE_FIELDS.
const UP_FIELDS = {
  clipSize: '7', maxAmmo: '12', startAmmo: '12',
  gunModel: 'vm_apex_tripletake_legendary_02', worldModel: 'npc_apex_tripletake_legendary_02',
};

function fmt(n) { return Number.isInteger(n) ? String(n) : parseFloat(n.toFixed(4)).toString(); }

// Locate a `"<asset>" ( "bulletweapon.gdf" )` block; returns [lineStart, blockEnd) offsets.
function findBlock(text, asset) {
  const decl = `"${asset}" ( "bulletweapon.gdf" )`;
  const start = text.indexOf(decl);
  if (start < 0) return null;
  const lineStart = text.lastIndexOf('\n', start) + 1;
  let open = text.indexOf('{', start), depth = 0, end = -1;
  for (let j = open; j < text.length; j++) {
    if (text[j] === '{') depth++;
    else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  if (end < 0) throw new Error(`unbalanced braces for ${asset}`);
  return { lineStart, start, open, end: end + 1 };
}

function setFields(block, fields, asset) {
  for (const [k, v] of Object.entries(fields)) {
    const re = new RegExp(`("${k}"\\s+")[^"]*(")`);
    if (!re.test(block)) throw new Error(`${asset}: field "${k}" not found`);
    block = block.replace(re, `$1${v}$2`);
  }
  return block;
}

function scaleRecoil(block) {
  return block.replace(/"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"/g, (m, key, val) => {
    if (!RECOIL_KEYS.has(key)) return m;
    const v = parseFloat(val);
    return v === 0 ? m : `"${key}" "${fmt(v * RECOIL_SCALE)}"`;
  });
}

// --- 1) backup once, re-derive the base block from the backup every run ---
if (!fs.existsSync(BAK)) { fs.copyFileSync(GDT, BAK); console.log('backed up pristine -> ' + path.basename(BAK)); }
const bakText = fs.readFileSync(BAK, 'utf8');
const bakLoc = findBlock(bakText, 'apex_tripletake_zm');
if (!bakLoc) { console.error('ABORT: apex_tripletake_zm not found in backup'); process.exit(1); }
let pristine = bakText.slice(bakLoc.lineStart, bakLoc.end);

// --- 2) patch the base block, splice into the CURRENT GDT (block-scoped) ---
let patched = setFields(pristine, BASE_FIELDS, 'apex_tripletake_zm');
patched = scaleRecoil(patched);
let cur = fs.readFileSync(GDT, 'utf8');
const curLoc = findBlock(cur, 'apex_tripletake_zm');
if (!curLoc) { console.error('ABORT: apex_tripletake_zm not found in live GDT'); process.exit(1); }
cur = cur.slice(0, curLoc.lineStart) + patched + cur.slice(curLoc.end);
fs.writeFileSync(GDT, cur);

// --- 3) build the _up clone from the PATCHED base and upsert into acc_apex_up.gdt ---
let upBlock = patched.replace('"apex_tripletake_zm" ( "bulletweapon.gdf" )',
                              '"apex_tripletake_up_zm" ( "bulletweapon.gdf" )');
upBlock = setFields(upBlock, UP_FIELDS, 'apex_tripletake_up_zm');
let upText = fs.readFileSync(UP_GDT, 'utf8');
const upLoc = findBlock(upText, 'apex_tripletake_up_zm');
if (upLoc) {
  upText = upText.slice(0, upLoc.lineStart) + upBlock + upText.slice(upLoc.end);
  console.log('replaced existing apex_tripletake_up_zm in acc_apex_up.gdt');
} else {
  const closer = upText.lastIndexOf('}');   // outer GDT brace - insert the block before it
  if (closer < 0) throw new Error('acc_apex_up.gdt: no closing brace');
  upText = upText.slice(0, closer) + upBlock + '\n' + upText.slice(closer);
  console.log('appended apex_tripletake_up_zm to acc_apex_up.gdt');
}
fs.writeFileSync(UP_GDT, upText);

// --- 4) report ---
function show(label, blk) {
  const g = (k) => (blk.match(new RegExp(`"${k}"\\s+"([^"]*)"`)) || [])[1];
  console.log(`  ${label.padEnd(22)} dmg=${g('damage')} shots=${g('shotCount')} clip=${g('clipSize')} maxAmmo=${g('maxAmmo')} ` +
    `move=${g('moveSpeedScale')} locHead=${g('locHead')} locTorso=${g('locTorsoUpper')} fire=${g('fireSoundPlayer')} ` +
    `adsVK(P${g('adsViewKickPitchMax')} Y${g('adsViewKickYawMax')}/${g('adsViewKickYawMin')}) model=${g('gunModel')}`);
}
console.log('prepped Triple Take (idempotent, block re-derived from .acc-tripletake-orig):');
show('apex_tripletake_zm', patched);
show('apex_tripletake_up_zm', upBlock);
console.log('\nNEXT: gdtdb /update -> tools/oneshots/gen_tripletake_twins.js -> sync -> link.');
