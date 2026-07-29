// Substitute the 6 missing discgun wav paths with installed donors (fire = apex B3 Wingman,
// act = shipped disc foley, lfe = spike launcher lfe). Idempotent.
const fs = require('fs')
const csv = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/discgun_sounds.csv'
const BS = String.fromCharCode(92)
const j = a => a.join(BS)
const MAP = [
  [j(['wpn','energy','discgun','plr','wpn_discgun_fire.wav']), j(['apex','wpn','b3wing','wpn_apex_b3wing_fire.wav'])],
  [j(['wpn','energy','discgun','npc','wpn_discgun_fire.wav']), j(['apex','wpn','b3wing','wpn_apex_b3wing_fire_01.wav'])],
  [j(['wpn','energy','discgun','plr','wpn_discgun_act.wav']), j(['fly','weapon','reload','disc','fly_disc_cover_close.wav'])],
  [j(['wpn','energy','discgun','npc','wpn_discgun_act.wav']), j(['fly','weapon','reload','disc','fly_disc_cover_close.wav'])],
  [j(['wpn','energy','discgun','lfe','wpn_disc_gun_lfe.wav']), j(['wpn','energy','spike_launcher','lfe','wpn_spike_launcher_fire_lfe.wav'])],
]
let t = fs.readFileSync(csv, 'utf8')
for (const [from, to] of MAP) t = t.split(from).join(to)
fs.writeFileSync(csv, t)
console.log('substituted; remaining old refs:', (t.match(/energy.discgun/g) || []).length)
