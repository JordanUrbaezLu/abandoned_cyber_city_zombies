#!/usr/bin/env node
// =============================================================================
// prep_hamr_gdt.js - one-shot, IDEMPOTENT install-side prep of the BO2 HAMR
// (skye_t6_hamr.gdt) so it drops into the box as a proper B-tier LMG that sits
// BETWEEN the M60 (S) and the RPD (C). (user 2026-07-10)
//
// The pristine Skye rip ships THREE problems for our additive damage model + LMG band:
//   1. MP-tuned hit-location mults (the docs/21 "MP-rip loc trap"): locNeck 4.0 on BOTH
//      forms, plus locTorsoMid 2.0 / locTorsoUpper 3.0 on the _up form. The engine
//      multiplies `damage` by the loc mult BEFORE on_ai_damage sees it, so a PaP torso
//      shot would be ~3x what `damage` implies. Normalize every loc mult to 1.0 (leave
//      locHead 5.0 = the standard x2.5 headshot) so body = damage x bal x global x papMult,
//      exactly like the M60/RPD (whose t9 GDTs already ship clean 1.0 torso mults).
//   2. An absurd magazine: PaP clip 250 / reserve 1000 (maxAmmo 4). Trim to clip 100 /
//      reserve 500 (maxAmmo 5) - between the RPD (75/625) and M60 (120/600), and matched
//      base form (80/400). Keeps the fast reload as the HAMR's identity.
//   3. No map "skill-theme" recoil: every conventional gun carries the x1.75 base recoil
//      (apply_recoil_overhaul), halved at runtime by Mega Deadshot. Scale the 16 kick keys
//      x1.75 so the HAMR isn't secretly the easiest LMG to control.
//   + reload 4.25 -> 6.0 (empty 4.8 -> 6.5): still the fastest-reloading LMG (M60 9.7 / RPD
//     7.5), the one comfort perk that separates it, but not trivial.
//
// IDEMPOTENT: keeps a pristine `.acc-hamr-orig` backup and ALWAYS re-derives from it, so a
// re-run reproduces the same result (never double-scales the recoil / double-trims ammo).
// The HAMR base GDT + this backup live install-side (NOT repo-tracked, like every Skye GDT);
// only this tool is committed. After running: `gdtdb /update`, then bake twins, then link.
//
// USAGE:  node tools/prep_hamr_gdt.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GDT = path.join(TOOLS, 'source_data', 'skye_t6_hamr.gdt');
const BAK = GDT + '.acc-hamr-orig';

if (!fs.existsSync(GDT)) { console.error('ABORT: ' + GDT + ' not found (is the HAMR pack installed?)'); process.exit(1); }

// The map's x1.75 base-recoil "skill theme" (apply_recoil_overhaul.js scales exactly these 16 keys).
const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);
const RECOIL_SCALE = 1.75;

// Absolute field SETs per block (loc-normalize + ammo trim + reload retune).
const COMMON = { locNeck: '1.0', reloadTime: '6', reloadEmptyTime: '6.5' };
const BASE_FIELDS = Object.assign({}, COMMON, { clipSize: '80',  maxAmmo: '5', startAmmo: '5' });
const UP_FIELDS   = Object.assign({}, COMMON, { clipSize: '100', maxAmmo: '5', startAmmo: '5',
                                                locTorsoMid: '1.0', locTorsoUpper: '1.0' });

function fmt(n) { return Number.isInteger(n) ? String(n) : parseFloat(n.toFixed(4)).toString(); }

function editBlock(fullText, asset, fields) {
  const decl = `"${asset}" ( "bulletweapon.gdf" )`;
  const start = fullText.indexOf(decl);
  if (start < 0) throw new Error(`asset ${asset} not found`);
  let open = fullText.indexOf('{', start), depth = 0, end = -1;
  for (let j = open; j < fullText.length; j++) {
    if (fullText[j] === '{') depth++;
    else if (fullText[j] === '}') { depth--; if (depth === 0) { end = j; break; } }
  }
  if (end < 0) throw new Error(`unbalanced braces for ${asset}`);
  let block = fullText.slice(open, end + 1);
  // absolute field sets (first occurrence within this block)
  for (const [k, v] of Object.entries(fields)) {
    const re = new RegExp(`("${k}"\\s+")[^"]*(")`);
    if (!re.test(block)) throw new Error(`${asset}: field "${k}" not found`);
    block = block.replace(re, `$1${v}$2`);
  }
  // recoil x1.75 (scale magnitude; 0 stays 0)
  block = block.replace(/"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"/g, (m, key, val) => {
    if (!RECOIL_KEYS.has(key)) return m;
    const v = parseFloat(val);
    return v === 0 ? m : `"${key}" "${fmt(v * RECOIL_SCALE)}"`;
  });
  return fullText.slice(0, open) + block + fullText.slice(end + 1);
}

// 1) pristine backup on first run; ALWAYS re-derive from it (idempotent)
if (!fs.existsSync(BAK)) { fs.copyFileSync(GDT, BAK); console.log('backed up pristine -> ' + path.basename(BAK)); }
let text = fs.readFileSync(BAK, 'utf8');

// 2) edit both bulletweapon blocks
text = editBlock(text, 't6_hamr', BASE_FIELDS);
text = editBlock(text, 't6_hamr_up', UP_FIELDS);
fs.writeFileSync(GDT, text);

// 3) echo the resulting key fields for eyeball verification
function show(asset) {
  const s = text.indexOf(`"${asset}" ( "bulletweapon.gdf" )`);
  let open = text.indexOf('{', s), depth = 0, end = -1;
  for (let j = open; j < text.length; j++) { if (text[j] === '{') depth++; else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } } }
  const blk = text.slice(open, end + 1);
  const g = (k) => (blk.match(new RegExp(`"${k}"\\s+"([^"]*)"`)) || [])[1];
  console.log(`  ${asset.padEnd(12)} clip=${g('clipSize')} maxAmmo=${g('maxAmmo')} reload=${g('reloadTime')}/${g('reloadEmptyTime')} ` +
    `locNeck=${g('locNeck')} locTorsoMid=${g('locTorsoMid')} locTorsoUpper=${g('locTorsoUpper')} locHead=${g('locHead')} ` +
    `adsViewKick(P${g('adsViewKickPitchMax')}/${g('adsViewKickPitchMin')} Y${g('adsViewKickYawMax')}/${g('adsViewKickYawMin')})`);
}
console.log('prepped skye_t6_hamr.gdt (idempotent, from .acc-hamr-orig):');
show('t6_hamr');
show('t6_hamr_up');
console.log('\nNEXT: gdtdb /update -> bake twins (gen_hamr_twins.js) -> sync -> link.');
