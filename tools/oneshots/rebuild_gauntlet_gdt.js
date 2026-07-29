// Restore the gauntlet GDT from .acc-dedup-orig and strip ONLY the 2 stock-duplicate
// BEAM blocks. ROOT CAUSE of the corruption: the beam names also appear as FIELD VALUES
// inside the gasweapon block (the weapon references its beams by name), and the naive
// indexOf-based stripper matched the field reference first and ate the weapon block's
// middle. Fix: anchor on the block HEADER `"name" ( "beam.gdf" )` and cut to the block
// terminator `\n\t}` (fields are \t\t-indented; `\n\t}` only occurs at block end).
const fs = require('fs')
const p = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data/wpn_t7_zmb_dlc3_gauntlet_dragon.gdt'
let t = fs.readFileSync(p + '.acc-dedup-orig', 'utf8')

for (const name of ['flamethrower_beam_dragon_gauntlet', 'flamethrower_beam_dragon_gauntlet_3p']) {
  const re = new RegExp('\\t"' + name + '" \\( "beam\\.gdf" \\)\\r?\\n\\t\\{[\\s\\S]*?\\r?\\n\\t\\}\\r?\\n', 'g')
  const before = t.length
  t = t.replace(re, '')
  console.log(name, 'removed bytes:', before - t.length)
  if (before === t.length) { console.error('header not matched for ' + name); process.exit(1) }
}

let o = 0, c = 0
for (const ch of t) { if (ch === '{') o++; if (ch === '}') c++ }
const gas = t.includes('"dragon_gauntlet_flamethrower_zm" ( "gasweapon.gdf" )')
const bullet = t.includes('"dragon_gauntlet_zm" ( "bulletweapon.gdf" )')
const beamHdr = /"\w+" \( "beam\.gdf" \)/.test(t)
console.log('braces:', o, c, '| gasweapon:', gas, '| bulletweapon:', bullet, '| beam headers left:', beamHdr)
if (o !== c || !gas || !bullet || beamHdr) { console.error('VALIDATION FAILED - not writing'); process.exit(1) }
fs.writeFileSync(p, t)
console.log('written OK')
