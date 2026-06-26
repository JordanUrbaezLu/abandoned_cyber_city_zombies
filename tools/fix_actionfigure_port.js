// fix_actionfigure_port.js - patch T0nic's BO4 Action Figure melee port (t8_melee_figure) for BO3
// linker-cleanliness. IDEMPOTENT (safe to re-run). The pack itself is a gitignored external asset
// (see tools/external_assets_manifest.ps1 + CREDITS.md); this script re-applies the two fixes a fresh
// install needs, the same pattern as tools/fix_pdw_akimbo_ammo.js.
//
// T0nic's readme warns "there may be a couple things you'll want to fix". The BO3 linker flags exactly two
// (it still packs a .ff, but the model material + melee sound are broken):
//   FIX 1  weaponfile t8_actionfigure_melee sets sharedWeaponSounds "melee_sounds" - a BO4 sound bank that
//          does NOT exist in BO3 -> "'melee_sounds' is not a valid sharedweaponsounds asset". Repoint to the
//          stock "fist" melee sound (the sibling weaponfile t8_melee_figure already uses it cleanly).
//   FIX 2  the view/world xmodel references a 6th material xmaterial_1cc1a388339cec8 the port never exported
//          -> "Material xmaterial_1cc1a388339cec8 was not found in gdtDB". Clone an existing material
//          (xmaterial_f663c30e9bbf8c8) under that name so the surface resolves (it borrows that texture set).
//
// Order: install pack -> `node tools/fix_actionfigure_port.js` -> gdtdb /update -> build.
// Usage: node tools/fix_actionfigure_port.js [path-to-wpn_t8_melee_actionfigure.gdt]
//   (no arg -> auto-detect <tools>/source_data/t8_weapons/wpn_t8_melee_actionfigure.gdt via modlauncher.exe)
const fs = require('fs');

function findGdt() {
  if (process.argv[2]) return process.argv[2];
  const roots = [
    'C:/Program Files (x86)/Steam/steamapps/common',
    'D:/Steam/steamapps/common', 'E:/Steam/steamapps/common', 'C:/Steam/steamapps/common',
  ];
  for (const lib of roots) {
    if (!fs.existsSync(lib)) continue;
    for (const d of fs.readdirSync(lib)) {
      if (!/Call of Duty Black Ops III/i.test(d)) continue;
      const root = lib + '/' + d;
      if (!fs.existsSync(root + '/bin/modlauncher.exe')) continue;
      const gdt = root + '/source_data/t8_weapons/wpn_t8_melee_actionfigure.gdt';
      if (fs.existsSync(gdt)) return gdt;
    }
  }
  return null;
}

const SRC_MAT = 'xmaterial_f663c30e9bbf8c8'; // existing material to clone
const NEW_MAT = 'xmaterial_1cc1a388339cec8'; // the missing material the model needs

const gdt = findGdt();
if (!gdt || !fs.existsSync(gdt)) {
  console.error('FAIL: GDT not found. Install the Action Figure pack into the Mod Tools first, or pass the GDT path explicitly.');
  process.exit(1);
}
let s = fs.readFileSync(gdt, 'utf8');
let changed = false;

// FIX 1 - sound
if (s.indexOf('"sharedWeaponSounds" "melee_sounds"') !== -1) {
  s = s.split('"sharedWeaponSounds" "melee_sounds"').join('"sharedWeaponSounds" "fist"');
  changed = true;
  console.log('FIX 1 applied: sharedWeaponSounds melee_sounds -> fist');
} else {
  console.log('FIX 1 skip: no "melee_sounds" reference (already patched).');
}

// FIX 2 - clone the missing material
if (s.indexOf('"' + NEW_MAT + '"') === -1) {
  const header = '"' + SRC_MAT + '" ( "material.gdf" )';
  const hi = s.indexOf(header);
  if (hi < 0) { console.error('FAIL FIX 2: source material ' + SRC_MAT + ' not found in GDT.'); process.exit(1); }
  const ob = s.indexOf('{', hi);
  let depth = 0, end = -1;
  for (let i = ob; i < s.length; i++) {
    if (s[i] === '{') depth++;
    else if (s[i] === '}') { depth--; if (depth === 0) { end = i; break; } }
  }
  if (end < 0) { console.error('FAIL FIX 2: no matching brace for ' + SRC_MAT + '.'); process.exit(1); }
  const lineStart = s.lastIndexOf('\n', hi) + 1;
  const block = s.slice(lineStart, end + 1).split(SRC_MAT).join(NEW_MAT);
  const lastBrace = s.lastIndexOf('}');
  s = s.slice(0, lastBrace) + block + '\n' + s.slice(lastBrace);
  changed = true;
  console.log('FIX 2 applied: cloned material ' + SRC_MAT + ' -> ' + NEW_MAT);
} else {
  console.log('FIX 2 skip: ' + NEW_MAT + ' already present (already patched).');
}

if (changed) {
  fs.writeFileSync(gdt, s);
  console.log('PATCHED: ' + gdt);
  console.log('NEXT: run gdtdb /update, then build (tools/build_map.ps1 -GscOnly).');
} else {
  console.log('No changes needed - GDT already fully patched.');
}
