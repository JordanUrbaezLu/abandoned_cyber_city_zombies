// Generate source_data/acc_riotshield_reskin.gdt: 6 xmodel blocks that SHADOW the stock
// SOE rocket-shield model names (view/world + dmg1/dmg2 states), all pointing at Logical's
// cyberpunk shield mesh. Usermap ff loads after common -> our same-name assets win
// (customizationtable-shadow precedent). Template block = logical_m_shield_full from the
// installed logical_models_crafting.gdt.
const fs = require('fs')
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130'
const src = fs.readFileSync(TOOLS + '/source_data/logical_models_crafting.gdt', 'utf8')

const m = src.match(/\t"logical_m_shield_full" \( "xmodel\.gdf" \)\r?\n\t\{[\s\S]*?\n\t\}/)
if (!m) throw new Error('template block not found')
const template = m[0]

const NAMES = [
  'wpn_t7_zmb_zod_rocket_shield_view',
  'wpn_t7_zmb_zod_rocket_shield_world',
  'wpn_t7_zmb_zod_rocket_shield_dmg1_view',
  'wpn_t7_zmb_zod_rocket_shield_dmg1_world',
  'wpn_t7_zmb_zod_rocket_shield_dmg2_view',
  'wpn_t7_zmb_zod_rocket_shield_dmg2_world',
]

let out = '{\n'
for (const n of NAMES) {
  let b = template.replace('"logical_m_shield_full"', '"' + n + '"')
  // view variants: mark viewmodel usage (converter streaming hint)
  if (n.endsWith('_view')) {
    b = b.replace('"usage_view" "0"', '"usage_view" "1"')
    b = b.replace('"usage_weapon" "0"', '"usage_weapon" "1"')
  } else {
    b = b.replace('"usage_weapon" "0"', '"usage_weapon" "1"')
  }
  out += b + '\n'
}
out += '}\n'

const hdr = ''
const repo = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/source_data/acc_riotshield_reskin.gdt'
fs.writeFileSync(repo, hdr + out)
fs.writeFileSync(TOOLS + '/source_data/acc_riotshield_reskin.gdt', hdr + out)
console.log('wrote', NAMES.length, 'blocks; bytes:', out.length)
