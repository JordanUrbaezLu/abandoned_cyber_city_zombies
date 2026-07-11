#!/usr/bin/env node
// =============================================================================
// swap_galil_grav.js (ONE-SHOT, idempotent) - CW Grav migration, install-side.
//
// "New model, same gun" (AK-47 pattern): graft the Galil's tuned stats onto the
// CW Grav GDT (t9_grav), then SURGICALLY swap the 6 Galil perk-twins for 6 Grav
// twins in acc_weapon_variants.gdt - WITHOUT a full apply_recoil_overhaul re-run
// (which would drop Klauser's hand-added twins). Every other gun's twins stay
// byte-identical. Splices IN PLACE into BOTH the repo AND the install variants
// GDT (they are diverged: repo=full-ammo, install=reduced - not our concern).
//
// The Grav is fully handled here (no reduce/normalize/hipspread whole-roster runs):
//   - clip 25/35 + loc + dmg/rpm/reload  -> grafted from the Galil (already tuned)
//   - recoil x1.75 baseline + hip-spread x1.25 (AR class) -> BAKED into base+twins
//   - reduce_base_ammo CLIP_FIX pins t9_grav 25/35 so a FUTURE full reduce won't re-cut.
//
// Idempotent: .acc-orig snapshots the grafted-NATIVE base; every re-run restores it
// first, so recoil/spread never compound. Run:  node <this>  (then gdtdb /update).
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path'), { execFileSync } = require('child_process');

const REPO  = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SD    = path.join(TOOLS, 'source_data');
const GEN   = path.join(REPO, 'tools/gen_weapon_variant_gdt.js');
const GRAFT = path.join(REPO, 'tools/graft_cw_weapon_stats.js');
const GRAV  = path.join(SD, 'skye_t9_grav.gdt');
const ORIG  = GRAV + '.acc-orig';
const VARIANTS = [path.join(REPO, 'source_data/acc_weapon_variants.gdt'), path.join(SD, 'acc_weapon_variants.gdt')];
const TEMP  = path.join(__dirname, 'grav_twins_tmp.gdt');

function node(args) { execFileSync(process.execPath, args, { stdio: 'inherit' }); }
function gen(args)  { node([GEN, ...args]); }

// brace-matched removal of a `"<name>" ( "bulletweapon.gdf" )` block (decl line -> closing brace + EOL).
function removeBlock(text, name) {
  const decl = `"${name}" ( "bulletweapon.gdf" )`;
  const idx = text.indexOf(decl);
  if (idx < 0) return { text, removed: false };
  const lineStart = text.lastIndexOf('\n', idx) + 1;
  let i = text.indexOf('{', idx), depth = 0, end = -1;
  for (let j = i; j < text.length; j++) { const c = text[j]; if (c === '{') depth++; else if (c === '}') { depth--; if (depth === 0) { end = j; break; } } }
  if (end < 0) throw new Error('unbalanced braces for ' + name);
  let after = end + 1;
  if (text[after] === '\r') after++;
  if (text[after] === '\n') after++;
  return { text: text.slice(0, lineStart) + text.slice(after), removed: true };
}

if (!fs.existsSync(GRAV)) throw new Error('missing ' + GRAV);
const combos = ['acc_fastreload', 'acc_recoil50', 'acc_recoil50_fastreload'];

// 1. restore grafted-native base if a prior run left it scaled (idempotency)
if (fs.existsSync(ORIG)) { fs.copyFileSync(ORIG, GRAV); console.log('restored skye_t9_grav.gdt from .acc-orig (grafted-native)'); }

// 2. graft the Galil's tuned stats -> t9_grav (live)
console.log('\n== graft Galil stats -> t9_grav ==');
node([GRAFT, '--gun', 'grav', '--tools', TOOLS]);

// 3. snapshot the grafted-NATIVE base once (baseline for idempotent re-scaling)
if (!fs.existsSync(ORIG)) { fs.copyFileSync(GRAV, ORIG); console.log('snapshot grafted-native base -> skye_t9_grav.gdt.acc-orig'); }

// 4. bake the AR baseline feel into base + _up (twins clone from these): hip-spread x1.25, recoil x1.75
console.log('\n== bake hip-spread x1.25 + recoil x1.75 on base + _up ==');
for (const asset of ['t9_grav', 't9_grav_up']) {
  gen(['--src', GRAV, '--asset', asset, '--spread', '1.25', '--inplace']);
  gen(['--src', GRAV, '--asset', asset, '--recoil', '1.75', '--inplace']);
}

// 5. generate the 6 fresh grav twins into a TEMP GDT
if (fs.existsSync(TEMP)) fs.rmSync(TEMP);
const TWINS = [
  { suffix: 'acc_recoil50',            args: ['--recoil', '0.50'] },
  { suffix: 'acc_fastreload',          args: ['--reload', '0.857'] },
  { suffix: 'acc_recoil50_fastreload', args: ['--recoil', '0.50', '--reload', '0.857'] },
];
for (const form of ['t9_grav', 't9_grav_up'])
  for (const t of TWINS)
    gen(['--src', GRAV, '--asset', form, '--suffix', t.suffix, ...t.args, '--out', TEMP, '--append']);

// pull the 6 block texts out of the TEMP envelope ( { <blocks> } )
let tmp = fs.readFileSync(TEMP, 'utf8');
tmp = tmp.slice(tmp.indexOf('{') + 1, tmp.lastIndexOf('}'));   // inner content = the 6 blocks
const gravBlocks = tmp.replace(/^\s+/, '').replace(/\s+$/, '');

// 6. splice into BOTH variants GDTs in place: purge old galil + any grav twins, insert the 6 grav blocks
console.log('\n== splice grav twins into both variants GDTs (in place) ==');
for (const f of VARIANTS) {
  let text = fs.readFileSync(f, 'utf8');
  let purged = 0;
  for (const stem of ['t6_galil', 't6_galil_up', 't9_grav', 't9_grav_up'])
    for (const c of combos) { const r = removeBlock(text, `${stem}_${c}`); text = r.text; if (r.removed) purged++; }
  // insert before the final closing brace of the envelope
  const close = text.lastIndexOf('}');
  const eol = text.includes('\r\n') ? '\r\n' : '\n';
  text = text.slice(0, close).replace(/\s+$/, '') + eol + gravBlocks + eol + '}' + eol;
  fs.writeFileSync(f, text);
  console.log(`  ${f}: purged ${purged}, inserted 6`);
  // clear stale ammo snapshot so a FUTURE reduce_base_ammo re-snapshots the grav twins
  const stale = f + '.acc-ammo-orig';
  if (fs.existsSync(stale)) { fs.rmSync(stale); console.log('    cleared ' + path.basename(stale)); }
}
fs.rmSync(TEMP);

console.log('\nDONE. NEXT: gdtdb /update, then build (-GscOnly). No reduce/normalize/hipspread run needed (grav fully baked).');
