// HAND-BUILD the 6 Havoc perk twins (Blast-O-Matic recipe: gen_weapon_variant_gdt.js refuses
// projectileweapon.gdf, so clone + scale the same canonical TWIN_DIMS fields ourselves).
// Charge fields (fireDelay 1.25 + acc_havoc_charge riser + fireDelayAnim) ride the clone as-is,
// so twins keep the exact spool-up feel. Names put the _zm mode suffix LAST (runtime strip).
const fs = require('fs');
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const OUT = SD + '/acc_weapon_variants.gdt';

// canonical TWIN_DIMS (apply_recoil_overhaul.js): recoil50 x0.50, fastreload x0.857
const RECOIL_KEYS = ['hipGunKickPitchMin', 'hipGunKickPitchMax', 'hipGunKickYawMin', 'hipGunKickYawMax',
  'adsGunKickPitchMin', 'adsGunKickPitchMax', 'adsGunKickYawMin', 'adsGunKickYawMax',
  'hipViewKickPitchMin', 'hipViewKickPitchMax', 'hipViewKickYawMin', 'hipViewKickYawMax',
  'adsViewKickPitchMin', 'adsViewKickPitchMax', 'adsViewKickYawMin', 'adsViewKickYawMax'];
const RELOAD_KEYS = ['reloadTime', 'reloadEmptyTime', 'reloadAddTime', 'reloadEmptyAddTime',
  'reloadStartTime', 'reloadStartAddTime', 'reloadEndTime',
  'reloadQuickTime', 'reloadQuickEmptyTime', 'reloadQuickAddTime', 'reloadQuickEmptyAddTime'];
const TWINS = [
  { suffix: 'acc_recoil50', recoil: 0.50, reload: 1 },
  { suffix: 'acc_fastreload', recoil: 1, reload: 0.857 },
  { suffix: 'acc_recoil50_fastreload', recoil: 0.50, reload: 0.857 },
];

function findBlock(text, name) {
  const m = text.match(new RegExp('"' + name + '"\\s*\\(\\s*"projectileweapon\\.gdf"\\s*\\)'));
  if (!m) throw new Error('no projectileweapon block ' + name);
  const open = text.indexOf('{', m.index);
  let d = 0, end = -1;
  for (let i = open; i < text.length; i++) { if (text[i] === '{') d++; else if (text[i] === '}') { d--; if (!d) { end = i; break; } } }
  return { header: text.slice(m.index, open).trim(), body: text.slice(open, end + 1) };
}
function scale(body, keys, f) {
  if (f === 1) return body;
  for (const k of keys) {
    body = body.replace(new RegExp('("' + k + '"\\s+)"([^"]*)"'), (m, pre, v) => {
      const n = parseFloat(v);
      if (isNaN(n)) return m;
      return pre + '"' + String(Math.round(n * f * 10000) / 10000) + '"';
    });
  }
  return body;
}

const SRC = {
  'apex_beam_rifle_zm': fs.readFileSync(SD + '/zeroy/APEX_BO3.gdt', 'utf8'),
  'apex_beam_rifle_up_zm': fs.readFileSync(SD + '/acc_apex_up.gdt', 'utf8'),
};
let out = fs.readFileSync(OUT, 'utf8');
const insert = out.lastIndexOf('}');   // append inside the trailing brace
let added = '';
for (const [asset, text] of Object.entries(SRC)) {
  const blk = findBlock(text, asset);
  const stem = asset.replace(/_zm$/, '');           // apex_beam_rifle / apex_beam_rifle_up
  for (const t of TWINS) {
    const newName = stem + '_' + t.suffix + '_zm';  // _zm LAST -> runtime strips it
    let body = blk.body;
    body = scale(body, RECOIL_KEYS, t.recoil);
    body = scale(body, RELOAD_KEYS, t.reload);
    const header = blk.header.replace('"' + asset + '"', '"' + newName + '"');
    added += '\t' + header + '\n' + body + '\n';
    console.log(newName);
  }
}
out = out.slice(0, insert) + added + out.slice(insert);
fs.writeFileSync(OUT, out);
const n = (out.match(/"apex_beam_rifle[a-z0-9_]*_acc_[a-z0-9_]+_zm" \( "projectileweapon\.gdf" \)/g) || []).length;
console.log('havoc twin blocks now in GDT: ' + n);
