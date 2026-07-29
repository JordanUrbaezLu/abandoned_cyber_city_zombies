// Verify every FileSpec wav in the trimmed discgun CSV resolves on disk,
// and flag Secondary refs that point outside the CSV (must then be stock aliases).
const fs = require('fs')
const csv = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies/sound/aliases/discgun_sounds.csv'
const T = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/sound_assets/'
const rows = fs.readFileSync(csv, 'utf8').split(/\r?\n/).slice(1).filter(Boolean)
const names = new Set(rows.map(r => r.split(',')[0]))
let bad = 0
for (const r of rows) {
  const c = r.split(',')
  for (const i of [3, 4, 5]) {
    if (c[i]) {
      const p = T + c[i].split('\\').join('/')
      if (!fs.existsSync(p)) { console.log('MISSING WAV:', c[0], c[i]); bad++ }
    }
  }
  if (c[8] && !names.has(c[8])) console.log('EXTERNAL SECONDARY (verify stock):', c[0], '->', c[8])
}
console.log(bad === 0 ? 'ALL WAVS RESOLVE' : 'BAD=' + bad)
