#!/usr/bin/env node
// =============================================================================
// prep_apex_tripletake_gdt.js - IDEMPOTENT install-side prep of the Apex
// Triple Take (APEX_BO3.gdt). v3 (user 2026-07-16 round 8: "piercing needs to
// be upgraded" - and the round-6 root cause made the class revert free):
//
//   THE DEF IS A *BULLETWEAPON* AGAIN (its native class). The v2 projectileweapon
//   GRAFT compiled/linked/played but PROVABLY NEVER CHANGED THE FIRING MODEL -
//   the gun fired HITSCAN with every proj* field inert (round-6 kill-timing test)
//   - while COSTING us the bullet-only fields: penetrateType (pierce died) and
//   the explicit flat-damage falloff. So v3 goes back to patching the PRISTINE
//   bulletweapon block (the v1 recipe) with one critical change: **shotCount 1**
//   (v1 shipped 3) - the volley's 2 side hits are script-owned MagicBullets now
//   (leaving 3 would make a trigger 3 pellets + 2 side hits = 5). Pierce =
//   penetrateType large (sniper standard, the round-8 "upgraded" ask).
//
//   The volley (2 side hits + 3-rounds-per-trigger + the <3 gate) and the VISIBLE
//   volley (3 plasma-orb movers on the acc_ttk_bolt_fx clientfield, blue/RED) live
//   in scripts/zm/zm_abandoned_cyber_city/_acc_tripletake.gsc + .csc - none of it
//   cares about the def's class.
//
// v3 STATS (user 2026-07-16; v2 numbers carried, class reverted):
//   - fireTime 0.288 -> 0.1728 (interval -40%); _up 0.13824 (PaP +25% rate)
//   - clipSize 9 base (3 volleys/mag) / 15 _up (5 volleys/mag)
//   - maxAmmo/startAmmo: 13 mags base (clipRel -> reserve 117), _up 12 (180)
//     (the "+20% reserve overall" ask; mags are integers -> +18% / +25%)
//   - shotCount 1 (v3! - the script volley owns the 2 side hits)
//   - penetrateType large (round 8 "piercing needs to be upgraded")
//   - UNLIMITED RANGE (v1 hack, back with the bulletweapon class): falloff start
//     pushed past any map scale + far floor = full damage (belt + suspenders);
//     damageRange2..5 are 0 -> immune to the "range went backwards" linker trap
//   - plasma hitscan tracers (mtl_s1_plasma_tracer, packed via the AE4)
//   - paired +10% DAMAGE lives in _acc_damage bal 0.281875 -> 0.3100625
//   - spread + orb visuals are SCRIPT-side (_acc_tripletake: acc_ttk_spread_deg
//     4deg/side, acc_ttk_bolt_vis_speed 4500, geotrail clones from STEP 0 below)
// Carried over from v1 (2026-07-11): loc normalize (head 5.0 = x2.5, body 1.0),
// move 0.93, recoil x1.25, energy fire sfx (acc_ttk_energy_fire_*), energy muzzle
// FX (fx_muz_energy_pistol_1p/3p), slide_in retarget (pack authoring bug).
//
// IDEMPOTENT: keeps a `.acc-tripletake-orig` backup of APEX_BO3.gdt and re-derives
// the block from the PRISTINE tripletake block in it each run (block-scoped splice:
// other guns' live edits are preserved untouched; the splice finder is gdf-agnostic
// so it replaces the v2 projectileweapon block on the first v3 run).
//
// USAGE:  node tools/oneshots/prep_apex_tripletake_gdt.js
// then:   gdtdb /update -> tools/oneshots/gen_tripletake_twins.js -> sync -> link
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GDT = path.join(TOOLS, 'source_data', 'zeroy', 'APEX_BO3.gdt');
const BAK = GDT + '.acc-tripletake-orig';
const UP_GDT = path.join(TOOLS, 'source_data', 'acc_apex_up.gdt');

// ---------------------------------------------------------------------------
// STEP 0 - BOLT FX CLONES (user round 4, 2026-07-16 "make the trail and bolt
// bigger... maybe 1.25x"): the bolt visual IS the geotrail FX, and scaling it in
// place would also grow the Blast-O-Matic's bolts - so clone the LIVE (patched,
// emission-ref-blanked - see external_assets_manifest) owens .efx to acc names
// with every elemdef's sizeGraph0/1 scalar x1.25 (orb core 11.69->14.61, glow
// 30->37.5, trail puffs 23->28.75). Re-derived from the OWENS files each run, so
// re-runs never compound the scale. The clones pack transitively via the weapon's
// projTrailEffect ref exactly like the originals did - no zone line.
// ---------------------------------------------------------------------------
// FINAL (round 7, 2026-07-16 "tone this down"): 1.5x - the clones are now consumed by the
// _acc_tripletake.csc MOVER visuals (the def-side projTrailEffect refs are INERT - the grafted
// def fires HITSCAN at runtime, proven by the round-6 kill-timing test), so this is the size of
// the visible plasma orbs. History: 1.25 (round 4, def-side, never rendered) -> 3.0 (round-5
// diagnostic) -> 1.5.
const FX_SIZE_SCALE = 1.5;
const FX_SRC_DIR = path.join(TOOLS, 'share', 'raw', 'fx', '_owens_effects', 't9_semiauto_cosplay');
const FX_OUT_DIR = path.join(TOOLS, 'share', 'raw', 'fx', 'acc');
const FX_CLONES = [
  { src: 'fx_raygun_geotrail_blue_doa.efx', out: 'acc_ttk_geotrail_blue.efx' },
  { src: 'fx_raygun_geotrail_red_doa.efx',  out: 'acc_ttk_geotrail_red.efx' },
];
function cloneScaledFx() {
  fs.mkdirSync(FX_OUT_DIR, { recursive: true });
  for (const c of FX_CLONES) {
    const srcPath = path.join(FX_SRC_DIR, c.src);
    if (!fs.existsSync(srcPath)) { console.error('ABORT: ' + srcPath + ' not found (Blast-O-Matic pack installed + patched?)'); process.exit(1); }
    let fx = fs.readFileSync(srcPath, 'utf8');
    let n = 0;
    fx = fx.replace(/(sizeGraph[01]\s+)(-?\d+(?:\.\d+)?)/g, (m, pre, v) => {
      n++;
      return pre + parseFloat((parseFloat(v) * FX_SIZE_SCALE).toFixed(4));
    });
    if (n === 0) { console.error('ABORT: no sizeGraph scalars found in ' + c.src + ' (format changed?)'); process.exit(1); }
    fs.writeFileSync(path.join(FX_OUT_DIR, c.out), fx);
    console.log('fx clone: ' + c.out + ' (x' + FX_SIZE_SCALE + ' on ' + n + ' sizeGraph scalars)');
  }
}
cloneScaledFx();

if (!fs.existsSync(GDT)) { console.error('ABORT: ' + GDT + ' not found (is the Apex pack installed?)'); process.exit(1); }
if (!fs.existsSync(UP_GDT)) { console.error('ABORT: ' + UP_GDT + ' not found (apex _up GDT missing?)'); process.exit(1); }

const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);
const RECOIL_SCALE = 1.25;   // gentler than the standard x1.75 - rip kick is already high (v1 note)

// Base-form field edits applied to the PRISTINE bulletweapon block (also inherited by the
// _up clone). Every key here MUST exist in bulletweapon.gdf - setFieldsSafe throws otherwise.
const BASE_FIELDS = {
  // v1 loc normalize (docs/21 MP-rip trap): head+helmet 5.0 (x2.5), everything else 1.0
  locHead: '5', locHelmet: '5', locNeck: '1',
  locTorsoLower: '1', locTorsoMid: '1', locTorsoUpper: '1',
  locLeftArmLower: '1', locLeftArmUpper: '1', locRightArmLower: '1', locRightArmUpper: '1',
  locLeftHand: '1', locRightHand: '1', locLeftLegUpper: '1', locRightLegUpper: '1',
  moveSpeedScale: '0.93',
  // ammo economy (2026-07-16): 9-round clip = 3 volleys/mag at 3 rounds/trigger (the
  // per-trigger cost + <3 gate are _acc_tripletake.gsc). clipRel 1: reserve = 13 x 9 = 117.
  clipSize: '9',
  maxAmmo: '13', startAmmo: '13',
  // fire interval -40% (2026-07-16): 0.288 -> 0.1728 (~347 triggers/min); _up 25% faster again.
  fireTime: '0.1728',
  // v3 CRITICAL: the pristine rip ships shotCount 3 (its Apex pellet spread) - the volley's
  // side hits are SCRIPT-owned MagicBullets now, so the native shot must be ONE bullet
  // (leaving 3 would make a trigger 3 pellets + 2 side hits = an accidental 5-hit volley).
  shotCount: '1',
  // v3 PIERCE (user round 8 "piercing needs to be upgraded"): sniper-standard collateral.
  // (The pristine block ships large already - asserted here so a pack update can't drop it.
  // This field does not exist in projectileweapon.gdf - HALF the reason v3 reverted the class.)
  penetrateType: 'large',
  // UNLIMITED RANGE (v1 hack, back with the bulletweapon class): full 500 at ANY distance -
  // falloff start pushed past any map scale AND the far floor raised to full damage.
  // damageRange2..5 stay 0 -> immune to the "range went backwards" linker trap (docs/21).
  maxDamageRange: '100000', minDamageRange: '100000', minDamage: '500',
  // Plasma hitscan tracers (v1's energy tracer, packed via the AE4) - the center-line streak
  // underneath the script's plasma-orb movers (the VISIBLE volley, _acc_tripletake.gsc/.csc).
  tracerType: 'mtl_s1_plasma_tracer', enemyTracerType: 'mtl_s1_plasma_tracer',
  // v1 ENERGY identity (unchanged): pitch-shifted Havoc fire wavs + tripletake crack
  // (rows in sound/aliases/acc_apex_weapons.csv), Havoc's stock energy muzzle FX.
  fireSound: 'acc_ttk_energy_fire_npc', fireSoundPlayer: 'acc_ttk_energy_fire_plr',
  lastShotSound: 'acc_ttk_energy_fire_npc', lastShotSoundPlayer: 'acc_ttk_energy_fire_plr',
  viewFlashEffect: 'fx\\\\weapon\\\\fx_muz_energy_pistol_1p.efx',
  worldFlashEffect: 'fx\\\\weapon\\\\fx_muz_energy_pistol_3p.efx',
  // v1 pack authoring bug fix: slide_in shipped pointing at vm_bo4_paladin_slide_in (nowhere)
  slide_in: 'vm_apex_tripletake_slide_in',
};
// _up-only deltas on top of BASE_FIELDS: 15-round clip (5 volleys), reserve 12 x 15 = 180,
// fireTime 0.110592 (round 9, user 2026-07-16 "+25% rate of fire" AGAIN on the PaP form:
// 0.13824 / 1.25 - now ~543 triggers/min, +56% rate over the 0.1728 base). The RED PaP look
// rides the SCRIPT orbs (acc_ttk_bolt_fx = 2), not the def.
const UP_FIELDS = {
  clipSize: '15', maxAmmo: '12', startAmmo: '12',
  fireTime: '0.110592',
  gunModel: 'vm_apex_tripletake_legendary_02', worldModel: 'npc_apex_tripletake_legendary_02',
};

function fmt(n) { return Number.isInteger(n) ? String(n) : parseFloat(n.toFixed(4)).toString(); }

// Locate a `"<asset>" ( "<any>.gdf" )` block (gdf-AGNOSTIC - the live tripletake block is
// bulletweapon pre-rework and projectileweapon after); returns offsets + the block text.
function findBlock(text, asset) {
  const re = new RegExp(`"${asset}"\\s*\\(\\s*"[a-z]+weapon\\.gdf"\\s*\\)`);
  const m = text.match(re);
  if (!m) return null;
  const start = m.index;
  const lineStart = text.lastIndexOf('\n', start) + 1;
  let open = text.indexOf('{', start), depth = 0, end = -1;
  for (let j = open; j < text.length; j++) {
    if (text[j] === '{') depth++;
    else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  if (end < 0) throw new Error(`unbalanced braces for ${asset}`);
  return { lineStart, start, open, end: end + 1 };
}
function blockText(text, asset) {
  const loc = findBlock(text, asset);
  if (!loc) return null;
  return text.slice(loc.lineStart, loc.end);
}

function fieldsOf(block) {
  const m = {};
  for (const x of block.matchAll(/"([A-Za-z0-9_]+)"\s+"([^"]*)"/g)) m[x[1]] = x[2];
  return m;
}

// (regex-replace with a plain replacement string is unsafe when v contains $ or \; splice manually)
function setFieldsSafe(block, fields, asset) {
  for (const [k, v] of Object.entries(fields)) {
    const re = new RegExp(`("${k}"\\s+")[^"]*(")`);
    const m = block.match(re);
    if (!m) throw new Error(`${asset}: field "${k}" not found`);
    block = block.slice(0, m.index) + m[1] + v + m[2] + block.slice(m.index + m[0].length);
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

// --- 1) backup once; the pristine BULLETWEAPON tripletake block comes from the backup ---
if (!fs.existsSync(BAK)) { fs.copyFileSync(GDT, BAK); console.log('backed up pristine -> ' + path.basename(BAK)); }
const bakText = fs.readFileSync(BAK, 'utf8');
const pristineTk = blockText(bakText, 'apex_tripletake_zm');
if (!pristineTk) { console.error('ABORT: apex_tripletake_zm not found in backup'); process.exit(1); }
if (!pristineTk.includes('bulletweapon.gdf')) { console.error('ABORT: backup block is not bulletweapon.gdf (wrong backup?)'); process.exit(1); }

// --- 2) v3: patch the pristine bulletweapon block directly (the v1 recipe) + recoil scale ---
let patched = setFieldsSafe(pristineTk, BASE_FIELDS, 'apex_tripletake_zm');
patched = scaleRecoil(patched);

// --- 3) splice into the CURRENT GDT (block-scoped; the finder is gdf-agnostic, so this
//        also replaces a leftover v2 projectileweapon block on the first v3 run) ---
let cur = fs.readFileSync(GDT, 'utf8');
const curLoc = findBlock(cur, 'apex_tripletake_zm');
if (!curLoc) { console.error('ABORT: apex_tripletake_zm not found in live GDT'); process.exit(1); }
cur = cur.slice(0, curLoc.lineStart) + patched + cur.slice(curLoc.end);
fs.writeFileSync(GDT, cur);

// --- 4) build the _up clone from the PATCHED base and upsert into acc_apex_up.gdt ---
let upBlock = patched.replace('"apex_tripletake_zm" ( "bulletweapon.gdf" )',
                              '"apex_tripletake_up_zm" ( "bulletweapon.gdf" )');
if (!upBlock.includes('"apex_tripletake_up_zm"')) throw new Error('up-clone rename failed (decl not matched)');
upBlock = setFieldsSafe(upBlock, UP_FIELDS, 'apex_tripletake_up_zm');
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

// --- 6) report ---
function show(label, blk) {
  const g = (k) => (blk.match(new RegExp(`"${k}"\\s+"([^"]*)"`)) || [])[1];
  console.log(`  ${label.padEnd(24)} dmg=${g('damage')} clip=${g('clipSize')} maxAmmo=${g('maxAmmo')} fireTime=${g('fireTime')} ` +
    `shots=${g('shotCount')} pen=${g('penetrateType')} range=${g('maxDamageRange')}/${g('minDamage')} tracer=${g('tracerType')} ` +
    `move=${g('moveSpeedScale')} locHead=${g('locHead')} fire=${g('fireSoundPlayer')} model=${g('gunModel')}`);
}
console.log('v3 Triple Take -> bulletweapon (idempotent, re-derived from .acc-tripletake-orig):');
show('apex_tripletake_zm', patched);
show('apex_tripletake_up_zm', upBlock);
console.log('\nNEXT: gdtdb /update -> tools/oneshots/gen_tripletake_twins.js -> sync -> link.');
