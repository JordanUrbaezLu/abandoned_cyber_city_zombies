#!/usr/bin/env node
// =============================================================================
// gen_stock_models_doc.js  (reference generator, re-runnable)
//
// Enumerates STOCK BO3 xmodels available to this install and writes a
// categorized reference: docs/27_stock_models.md  +  full flat dump
// docs/stock_models_full.txt.
//
// Sources (in priority order):
//   1. Stock SCRIPTS (<tools>\share\raw\scripts) - every model the shipped ZM/MP
//      code actually precaches / SetModels. These are the CONFIRMED-USABLE props,
//      characters, power-ups, perk machines, gore, FX-models (the ones a mapper
//      wants). Patterns: SetModel("x"), PrecacheModel("x"), precache("model","x").
//   2. Stock PREFABS (map_source\_prefabs) - "model" "x" keyvalues.
//   3. The install GDTs (<tools>\source_data\*.gdt) - "x" ( "xmodel.gdf" ); this
//      install's loose GDTs are mostly WEAPON view/world models (vm_/wm_).
//
// CAVEATS written into the doc: APE is the live "every model" browser; a name
// here is a SOURCE reference - confirm a specific model actually packs via the
// build ERRORLOG (some referenced models are DLC/SoE-fastfile-only). All stock
// assets are Workshop-publishable (you already own them via the Mod Tools).
// =============================================================================
'use strict';
const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ROOT = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SCRIPTS = ROOT + '/share/raw/scripts';
const GDT = ROOT + '/source_data';
const PREFABS = path.join(__dirname, '..', 'map_source', '_prefabs');
const OUT_MD = path.join(__dirname, '..', 'docs', '27_stock_models.md');
const OUT_TXT = path.join(__dirname, '..', 'docs', 'stock_models_full.txt');

// Pure-node recursive file walk (execSync here runs under cmd.exe, so grep/rg + shell
// quoting are unreliable - read files directly instead).
function* walk(dir, exts) {
  let ents;
  try { ents = fs.readdirSync(dir, { withFileTypes: true }); } catch (e) { return; }
  for (const e of ents) {
    const p = path.join(dir, e.name);
    if (e.isDirectory()) yield* walk(p, exts);
    else if (!exts || exts.some(x => e.name.toLowerCase().endsWith(x))) yield p;
  }
}

const names = new Set();
function harvest(dir, exts, regexes) {
  for (const f of walk(dir, exts)) {
    let txt;
    try { txt = fs.readFileSync(f, 'latin1'); } catch (e) { continue; }
    for (const re of regexes) {
      re.lastIndex = 0;
      let m;
      while ((m = re.exec(txt)) !== null) {
        const t = m[1] && m[1].trim();
        if (t && t.length > 2 && /^[A-Za-z0-9_]+$/.test(t)) names.add(t);
      }
    }
  }
}

// model-name prefixes that are unambiguously xmodels (props/vending/powerups/chars/veh/gore).
// Stock sets vending + powerup models via prefabs/tables, NOT literal setmodel() - so a
// prefix catch on quoted strings is needed to capture them.
const MODELPFX = /"((?:p7|p6|c_zom|c_zmb|c_zm|cn|ch|veh|vehicle|t6|t7|t8|gore|dest|dyn|prop|zmb|mp)_[a-z0-9_]+)"/gi;

// 1. stock scripts: SetModel / PrecacheModel / precache("model",...) + model-prefixed strings
harvest(SCRIPTS, ['.gsc', '.csc', '.gsh'], [
  /setmodel\s*\(\s*"([^"]+)"/gi,
  /precachemodel\s*\(\s*"([^"]+)"/gi,
  /precache\s*\(\s*"model"\s*,\s*"([^"]+)"/gi,
  MODELPFX,
]);
// 2. prefabs: "model" "name" (skip nested .map prefab paths) - repo prefabs + the INSTALL's
//    stock prefabs (vending_*_struct, powerups, props all reference their real xmodels here).
for (const pf of [PREFABS, ROOT + '/map_source/_prefabs']) {
  if (fs.existsSync(pf)) harvest(pf, ['.map'], [/"model"\s+"([A-Za-z0-9_]+)"/g, MODELPFX]);
}
// 3. GDT xmodels:  "name" ( "xmodel.gdf" )
harvest(GDT, ['.gdt'], [/"([A-Za-z0-9_]+)"\s*\(\s*"xmodel\.gdf"\s*\)/g]);

// --- categorize -------------------------------------------------------------
const CATS = [
  ['Perk machines / vending', n => /vending|p7_zm_vending/i.test(n)],
  ['Power-ups', n => /power_?up/i.test(n)],
  ['Characters / zombies / boss', n => /^c_zom|^c_zmb|^cn_|^ch_|zombie|charred|brutus|margwa|mechz|panzer|keeper|parasite|spider|^c_t7_|^c_zm/i.test(n)],
  ['Props / world objects', n => /^p7_|^p6_|^prop_|^t[5-9]_|^dyn_|^dest_|^bo3_|^gp_|^mp_|table|chair|barrel|crate|sign|debris|door|fence|locker|machine|box/i.test(n)],
  ['Weapons — world models (placeable pickup)', n => /^wm_|_world$|^wpn_/i.test(n)],
  ['Vehicles', n => /^veh_|vehicle|^car_|^truck/i.test(n)],
  ['Gore / body parts', n => /gore|guts|body_part|dismember|limb|torso|^viscera/i.test(n)],
  ['FX / animated models', n => /^fxanim_|^fx_/i.test(n)],
  ['Weapons — VIEW models (first-person; NOT placeable)', n => /^vm_/i.test(n)],
];
function categorize(n) { for (const [label, fn] of CATS) if (fn(n)) return label; return 'Other / uncategorized'; }

const buckets = {};
for (const [label] of CATS) buckets[label] = [];
buckets['Other / uncategorized'] = [];
for (const n of names) buckets[categorize(n)].push(n);
const order = CATS.map(c => c[0]).concat(['Other / uncategorized']);
for (const k of order) buckets[k].sort();

// --- write full flat dump ---------------------------------------------------
const all = [...names].sort();
fs.writeFileSync(OUT_TXT, all.join('\n') + '\n');

// --- write the doc ----------------------------------------------------------
const L = [];
L.push('# 44 — Stock BO3 xmodel reference (usable models)');
L.push('');
L.push('> **Auto-generated** by `tools/gen_stock_models_doc.js` from this install\'s stock scripts + GDTs.');
L.push('> Re-run after a Mod Tools update. Full flat list: `docs/stock_models_full.txt`.');
L.push('');
L.push(`**${all.length} distinct stock model names** found across stock script references + GDTs.`);
L.push('');
L.push('## How to use this');
L.push('- **All stock models are Workshop-publishable** — they ship inside the Mod Tools, so you already have the rights (no IP review needed). This is the safest model source.');
L.push('- A name here is a **source reference**. Confirm a *specific* model actually packs into the `.ff` by checking the build **ERRORLOG** (some referenced models are DLC/Shadows-of-Evil-fastfile-only and won\'t resolve in a base usermap). The build log is the oracle — see `stock-pickup-model-safety`.');
L.push('- **Placing a model:** Radiant-placed `script_model`/prefab needs **no** `.zone` line; a script `SetModel("name")` on a runtime-spawned model needs `xmodel,name` in the `.zone` (unless it\'s a powerup/perk-bottle that stock runtime-loads).');
L.push('- **Browse the COMPLETE universe live in APE** (Asset Property Editor → xmodel) — that is the only truly exhaustive list; this doc covers everything the stock code + GDTs reference.');
L.push('- To use one for a **boss item**, give me the name — I wire it into the item pool + `.zone` and build.');
L.push('');
L.push('## Categories');
L.push('');
for (const k of order) {
  const list = buckets[k];
  if (!list.length) continue;
  L.push(`### ${k}  (${list.length})`);
  L.push('');
  // chunk into comma lists for readability
  L.push('```');
  L.push(list.join('  '));
  L.push('```');
  L.push('');
}
fs.writeFileSync(OUT_MD, L.join('\n'));
console.log(`stock models: ${all.length} unique. md=${OUT_MD} txt=${OUT_TXT}`);
for (const k of order) if (buckets[k].length) console.log(`  ${buckets[k].length}\t${k}`);
