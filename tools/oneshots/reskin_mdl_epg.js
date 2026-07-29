// reskin_mdl_epg.js  (user 2026-07-25)
// Retune + repaint the install-side Skye MDL GDT (skye_s1_mdl.gdt) into the "EPG-1" - a neon
// plasma energy-LOBBER: a slow high-arc TIMED-fuse airburst grenade launcher, distinct from the
// Mahem (LoS impact rocket) and War Machine (impact frag drum).
//
// WHY a one-shot (not a raw GDT hand-edit): the Skye pack GDTs are INSTALL-SIDE + gitignored and
// REVERT on any pack reinstall ([[gdt-edit-build-workflow]] / [[asset-portability-rules]]). This
// script is the tracked, idempotent re-apply - run it after any Skye reinstall, then gdtdb /update.
//
// Edits (both the base s1_mdl block AND the PaP s1_mdl_up block):
//   ARC:   projectileSpeed 3500 -> 1400 (grenade-class gravity then gives the slow high floaty lob)
//   IDENTITY: _up projImpactExplode 1 -> 0 (keep the TIMED-fuse lob identity through PaP, not impact)
//   BALANCE: normalize the BASE raw UP to the _up raw so ONE acc_weapon_balance_mult (0.68, a <1 reduction like
//            every other gun) covers both and the +33/67/100% PaP tier ladder is the SOLE damage progression
//            (the Mahem model): base explosionInnerDamage 450 -> 900, base damage 200 -> 600 (outer 125 / radius
//            200 already equal). Equal base/_up raw avoids the _up-raw x papMult DOUBLE-COUNT; the HIGHER 900 raw
//            keeps bal below 1 (both the convention and the docs/25 generator expect bal <= 1).
//   +50% BUFF (user 2026-07-26, "buff the EPG 1 by 50% damage clip and reserve"): applied RAW-side so bal
//            stays 0.68 (<1 convention). SEQUENTIAL swaps after the normalization above, so a fresh Skye
//            reinstall converges through both stages: inner 450 -> 900 -> 1350, damage 200 -> 600 -> 900,
//            outer 125 -> 188; clipSize 6 -> 9 on BOTH blocks; base reserve maxAmmo/startAmmo 18 -> 27
//            (clipRel 0 = ROUNDS); the _up reserve is UNTOUCHED on purpose - it is clip-RELATIVE
//            (ammoCountClipRelative 1, maxAmmo 12 = MAGAZINES, memory ammocountcliprelative-reserve-units),
//            so 12 mags x the new 9-clip = 108 rounds = +50% of the old 72 automatically.
//   NEON FX (all VERIFIED present in share\raw\fx 2026-07-25 - repainting away from fx_exp_rocket_default_sm
//            ALSO removes a not-in-raw ref): explosion -> fx_exp_grenade_emp (blue EMP burst),
//            trail -> fx_trail_rocket_emp, view/world muzzle -> fx_muz_energy_shotgun_1p/_3p (incl. the
//            _up's _ug_zmb muzzle variants, folded onto the same energy muzzle).
//
// Usage:  node tools/oneshots/reskin_mdl_epg.js        (then gdtdb /update + linker; done by build_map.ps1)
'use strict';
const fs = require('fs');
const path = require('path');

function resolveToolsRoot() {
  const libs = [
    'C:\\Program Files (x86)\\Steam\\steamapps\\common',
    'D:\\Steam\\steamapps\\common', 'E:\\Steam\\steamapps\\common', 'C:\\Steam\\steamapps\\common',
  ];
  for (const lib of libs) {
    if (!fs.existsSync(lib)) continue;
    for (const d of fs.readdirSync(lib)) {
      if (!/^Call of Duty Black Ops III/.test(d)) continue;
      const full = path.join(lib, d);
      if (fs.existsSync(path.join(full, 'bin', 'modlauncher.exe'))) return full;
    }
  }
  throw new Error('Could not auto-detect the Mod Tools root (no folder with bin\\modlauncher.exe).');
}

const gdtPath = path.join(resolveToolsRoot(), 'source_data', 'skye_s1_mdl.gdt');
if (!fs.existsSync(gdtPath)) throw new Error('skye_s1_mdl.gdt not found (install the Skye pack first): ' + gdtPath);

let txt = fs.readFileSync(gdtPath, 'utf8');
const orig = txt;

// one-time backup (never overwrite the pristine original)
const backup = gdtPath + '.acc-epg-orig';
if (!fs.existsSync(backup)) fs.writeFileSync(backup, txt);

// exact "field" "value" -> "field" "value" swaps (idempotent: replace() is a no-op if the old string is gone)
const swaps = [
  // arc
  ['"projectileSpeed" "3500"',                                    '"projectileSpeed" "1400"'],
  // keep the timed-lob identity through PaP (only the _up block has impactExplode 1)
  ['"projImpactExplode" "1"',                                     '"projImpactExplode" "0"'],
  // normalize BASE raw UP to _up (450/200 are base-only; _up already 900/600) -> both end at 900/600, bal stays <1
  ['"explosionInnerDamage" "450"',                               '"explosionInnerDamage" "900"'],
  ['"damage" "200"',                                             '"damage" "600"'],
  // neon FX repaint (explosion + trail: both blocks share the value)
  ['"projExplosionEffect" "fx/explosions/fx_exp_rocket_default_sm.efx"', '"projExplosionEffect" "fx/explosions/fx_exp_grenade_emp.efx"'],
  ['"projTrailEffect" "fx/weapon/fx_trail_grenade.efx"',         '"projTrailEffect" "fx/weapon/fx_trail_rocket_emp.efx"'],
  // muzzle: base weapon FX + the _up _ug_zmb variants -> the same energy muzzle
  ['"viewFlashEffect" "fx/weapon/fx_muz_rocket_xm_1p.efx"',      '"viewFlashEffect" "fx/weapon/fx_muz_energy_shotgun_1p.efx"'],
  ['"viewFlashEffect" "fx/zombie/fx_muz_rocket_xm_1p_ug_zmb.efx"', '"viewFlashEffect" "fx/weapon/fx_muz_energy_shotgun_1p.efx"'],
  ['"worldFlashEffect" "fx/weapon/fx_muz_rocket_xm_3p.efx"',     '"worldFlashEffect" "fx/weapon/fx_muz_energy_shotgun_3p.efx"'],
  ['"worldFlashEffect" "fx/zombie/fx_muz_rocket_xm_3p_ug_zmb.efx"', '"worldFlashEffect" "fx/weapon/fx_muz_energy_shotgun_3p.efx"'],
  // +50% BUFF (user 2026-07-26) - MUST stay AFTER the normalization swaps above (second stage of the
  // 450->900->1350 / 200->600->900 chains; see the header). Damage raw-side keeps bal 0.68 <1.
  ['"explosionInnerDamage" "900"',                               '"explosionInnerDamage" "1350"'],
  ['"damage" "600"',                                             '"damage" "900"'],
  ['"explosionOuterDamage" "125"',                               '"explosionOuterDamage" "188"'],
  // clip 6 -> 9 (both blocks); base reserve rounds 18 -> 27; the _up's clip-relative
  // 12-magazine reserve scales to 108 rounds via the new clip on its own
  ['"clipSize" "6"',                                             '"clipSize" "9"'],
  ['"maxAmmo" "18"',                                             '"maxAmmo" "27"'],
  ['"startAmmo" "18"',                                           '"startAmmo" "27"'],
];

let changed = 0;
for (const [from, to] of swaps) {
  if (txt.includes(from)) { txt = txt.split(from).join(to); changed++; }
}

if (txt !== orig) {
  fs.writeFileSync(gdtPath, txt);
  console.log('reskin_mdl_epg: applied ' + changed + ' field group(s) to ' + gdtPath);
  console.log('  backup: ' + backup + (fs.existsSync(backup) ? ' (kept)' : ''));
  console.log('  NEXT: gdtdb /update  +  linker (build_map.ps1 handles both).');
} else {
  console.log('reskin_mdl_epg: already applied (idempotent no-op). ' + gdtPath);
}
