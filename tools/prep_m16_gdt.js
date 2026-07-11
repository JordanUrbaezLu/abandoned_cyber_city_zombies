#!/usr/bin/env node
// =============================================================================
// prep_m16_gdt.js - IDEMPOTENT install-side prep of the Cold War M16
// (skye_t9_m16.gdt) so it drops into the box as a B-tier marksman/tactical rifle
// that is SLIGHTLY BETTER than the MK14 - it REPLACES the G7 Scout in that slot.
// (user 2026-07-11)
//
// The pristine Skye CW rip needs:
//   1. loc normalize: locNeck 4.0 on BOTH forms -> 1.0 (the docs/21 MP-rip trap; torso is
//      already clean 1.0 here, locHead 5.0 kept = the standard x2.5 headshot). So body =
//      damage x bal x global x papMult, exactly like every other gun.
//   2. PaP mag trim: the _up ships clip 70 / reserve 560 (maxAmmo 8) - huge for a marksman.
//      Trim to clip 40 / reserve 280 (maxAmmo 7) - a strong full-auto tactical rifle mag but
//      not a bullet-hose. Base (burst) stays clip 30 / reserve 210.
//   3. move 0.95 -> 0.93 (the marksman-class move standard, matching MK14 / MORS).
//   4. recoil x1.40 (a GENTLER-than-standard scale): the pristine CW rip already ships MP-HIGH kick
//      (base ~100 total vs most guns' ~50), so the usual x1.75 would land it "Very High" - harsher than
//      the MK14 it's meant to edge out. x1.40 lands it at "High", comparable to the MK14. Halved at
//      runtime by Mega Deadshot (-> ~Low), same as every other gun.
//
// KEPT authentic: base = 3-round BURST (burstCount 3), _up = FULL-AUTO (burstCount 1) - the
// real CW M16 "Skullsplitter" PaP. reload 3.03 / 3.8 unchanged.
//
// IDEMPOTENT: keeps a pristine `.acc-m16-orig` backup and ALWAYS re-derives from it. The base
// GDT + backup live install-side (NOT repo-tracked); only this tool is committed. After running:
// `gdtdb /update`, then bake twins, then link.
//
// USAGE:  node tools/prep_m16_gdt.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const TOOLS = process.env.TA_TOOLS_PATH ||
  'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const GDT = path.join(TOOLS, 'source_data', 'skye_t9_m16.gdt');
const BAK = GDT + '.acc-m16-orig';

if (!fs.existsSync(GDT)) { console.error('ABORT: ' + GDT + ' not found (is the CW pack installed?)'); process.exit(1); }

const RECOIL_KEYS = new Set([
  'hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax',
]);
const RECOIL_SCALE = 1.40;   // gentler than the standard x1.75 - the M16 base recoil is already MP-high (see header note 4)

const COMMON = { locNeck: '1.0', moveSpeedScale: '0.93' };
const BASE_FIELDS = Object.assign({}, COMMON);                                          // burst form: keep clip 30 / maxAmmo 7
const UP_FIELDS   = Object.assign({}, COMMON, { clipSize: '40', maxAmmo: '7', startAmmo: '7' });

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
  for (const [k, v] of Object.entries(fields)) {
    const re = new RegExp(`("${k}"\\s+")[^"]*(")`);
    if (!re.test(block)) throw new Error(`${asset}: field "${k}" not found`);
    block = block.replace(re, `$1${v}$2`);
  }
  block = block.replace(/"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"/g, (m, key, val) => {
    if (!RECOIL_KEYS.has(key)) return m;
    const v = parseFloat(val);
    return v === 0 ? m : `"${key}" "${fmt(v * RECOIL_SCALE)}"`;
  });
  return fullText.slice(0, open) + block + fullText.slice(end + 1);
}

if (!fs.existsSync(BAK)) { fs.copyFileSync(GDT, BAK); console.log('backed up pristine -> ' + path.basename(BAK)); }
let text = fs.readFileSync(BAK, 'utf8');
text = editBlock(text, 't9_m16', BASE_FIELDS);
text = editBlock(text, 't9_m16_up', UP_FIELDS);
fs.writeFileSync(GDT, text);

function show(asset) {
  const s = text.indexOf(`"${asset}" ( "bulletweapon.gdf" )`);
  let open = text.indexOf('{', s), depth = 0, end = -1;
  for (let j = open; j < text.length; j++) { if (text[j] === '{') depth++; else if (text[j] === '}') { depth--; if (depth === 0) { end = j; break; } } }
  const blk = text.slice(open, end + 1);
  const g = (k) => (blk.match(new RegExp(`"${k}"\\s+"([^"]*)"`)) || [])[1];
  console.log(`  ${asset.padEnd(11)} fire=${g('fireType')} burst=${g('burstCount')} clip=${g('clipSize')} maxAmmo=${g('maxAmmo')} ` +
    `move=${g('moveSpeedScale')} locNeck=${g('locNeck')} locHead=${g('locHead')} adsVK(P${g('adsViewKickPitchMax')}/${g('adsViewKickPitchMin')} Y${g('adsViewKickYawMax')}/${g('adsViewKickYawMin')})`);
}
console.log('prepped skye_t9_m16.gdt (idempotent, from .acc-m16-orig):');
show('t9_m16');
show('t9_m16_up');
console.log('\nNEXT: gdtdb /update -> bake twins (gen_m16_twins.js) -> sync -> link.');
