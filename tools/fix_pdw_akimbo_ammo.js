// fix_pdw_akimbo_ammo.js - re-applies the PDW akimbo-PaP ammo fix to the Skye GDT.
//
// WHY: the Skye `skye_s1_pdw.gdt` ships two errors on the akimbo Pack-a-Punch forms that make the
// PaP'd PDW read "15 left mag / 17 right mag / 18 reserve" instead of the docs/05 17 / 17 / 306:
//   1. off-hand `s1_pdw_ldw_up_zm` clipSize = 15  (must match the main's 17 - akimbo shares a mag size)
//   2. main `s1_pdw_rdw_up_zm` maxAmmo/startAmmo = 18.  Single-wield reserve = maxAmmo(mags) x clipSize,
//      but for AKIMBO the engine treats maxAmmo as ROUNDS 1:1 (18 -> 18 reserve), so we set it to the
//      ROUND value 306 to land the intended 18 mags x 17 = 306 reserve. (See memory akimbo-maxammo-units-quirk.)
//
// GSC `SetWeaponAmmoClip/Stock` are CLAMPED to these data caps, so the fix MUST be in the GDT (not GSC).
// The GDT is the external/gitignored Skye pack, so this tool makes the fix reproducible: run it AFTER
// reduce_base_ammo.js (which would otherwise reset these), then `gdtdb /update` + link. Idempotent.
//
//   Run from repo root:  node tools/fix_pdw_akimbo_ammo.js   (then <tools>\gdtdb\gdtdb.exe /update + linker)

const fs = require("fs");

// Mod-tools root: AppID-suffixed folder detected by bin\modlauncher.exe (never folder name).
const STEAM = "C:/Program Files (x86)/Steam/steamapps/common";
let root = null;
for (const d of fs.readdirSync(STEAM)) {
  if (fs.existsSync(`${STEAM}/${d}/bin/modlauncher.exe`)) { root = `${STEAM}/${d}`; break; }
}
if (!root) { console.error("Mod Tools root not found"); process.exit(1); }
const GDT = `${root}/source_data/skye_s1_pdw.gdt`;
if (!fs.existsSync(GDT)) { console.error("GDT not found: " + GDT); process.exit(1); }

let s = fs.readFileSync(GDT, "utf8");

// Set "<field>" "<value>" inside the block of the named weapon (first occurrence after its header,
// before the next weapon header). Idempotent.
function setField(weapon, field, val) {
  const hdr = s.indexOf(`"${weapon}" (`);
  if (hdr < 0) { console.log(`  SKIP (weapon ${weapon} not in GDT)`); return; }
  const nextHdr = s.indexOf('" ( "', hdr + weapon.length + 4);
  const end = nextHdr < 0 ? s.length : nextHdr;
  const re = new RegExp(`("${field}"\\s+")(\\d+)(")`);
  const block = s.slice(hdr, end);
  const m = block.match(re);
  if (!m) { console.log(`  ${weapon}: "${field}" not found`); return; }
  if (m[2] === String(val)) { console.log(`  ${weapon} ${field}: already ${val}`); return; }
  s = s.slice(0, hdr) + block.replace(re, `$1${val}$3`) + s.slice(end);
  console.log(`  ${weapon} ${field}: ${m[2]} -> ${val}`);
}

console.log("PDW akimbo-PaP ammo fix (docs/05: clip 17 / reserve 306):");
setField("s1_pdw_ldw_up_zm", "clipSize", 17);   // off-hand mag 15 -> 17
setField("s1_pdw_rdw_up_zm", "maxAmmo", 306);   // shared reserve cap (akimbo = rounds)
setField("s1_pdw_rdw_up_zm", "startAmmo", 306);
fs.writeFileSync(GDT, s);
console.log("done -> now run  <tools>\\gdtdb\\gdtdb.exe /update  then link.");
