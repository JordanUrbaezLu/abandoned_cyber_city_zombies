// Strip from the HB21 hero-weapon GDTs every asset block whose (name,type) already exists
// in a STOCK tools source_data GDT (t7_beams, t7_zombie_animations, etc.) - gdtdb refuses
// duplicates. Stock copy is canonical; HB21 shipped stock rips of the same assets.
const fs = require('fs')
const path = require('path')
const SD = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data'

const HB21 = ['wpn_t7_zmb_dlc3_gauntlet_dragon.gdt', 'wpn_t7_zmb_dlc2_keeper_head.gdt', 'c_zom_dlc3_dragon.gdt', 't7_zm_hud.gdt', 'wpn_t7_zmb_zod_sword.gdt', 'zm_zod_sword_egg_apothicon.gdt', 'zm_zod_sword_egg_keeper.gdt']
const BLOCK_RE = /"([^"]+)" \( "([^"]+)\.gdf" \)/g

// index all NON-HB21 source_data GDT asset names (recursive - koentje subdir etc.)
function* walk(dir) {
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    const p = path.join(dir, e.name)
    if (e.isDirectory()) yield* walk(p)
    else if (e.name.endsWith('.gdt')) yield p
  }
}
const stockNames = new Map() // name|type -> file
for (const f of walk(SD)) {
  const base = path.basename(f)
  if (HB21.includes(base)) continue
  const t = fs.readFileSync(f, 'utf8')
  let m
  while ((m = BLOCK_RE.exec(t))) stockNames.set(m[1] + '|' + m[2], base)
}

let totalStripped = 0
for (const g of HB21) {
  const p = path.join(SD, g)
  if (!fs.existsSync(p)) continue
  let t = fs.readFileSync(p, 'utf8')
  const orig = t
  let m, hits = []
  BLOCK_RE.lastIndex = 0
  while ((m = BLOCK_RE.exec(t))) {
    const k = m[1] + '|' + m[2]
    if (stockNames.has(k)) hits.push({ name: m[1], type: m[2], vs: stockNames.get(k) })
  }
  for (const h of hits) {
    for (;;) {
      const start = t.indexOf(`"${h.name}" ( "${h.type}.gdf" )`)
      if (start < 0) break
      const braceOpen = t.indexOf('{', start)
      let depth = 0, i = braceOpen
      for (; i < t.length; i++) { if (t[i] === '{') depth++; else if (t[i] === '}') { depth--; if (depth === 0) { i++; break } } }
      const lineStart = t.lastIndexOf('\n', start) + 1
      t = t.slice(0, lineStart) + t.slice(i).replace(/^\r?\n/, '')
      totalStripped++
      console.log(`stripped ${h.type} "${h.name}" from ${g} (dupes stock ${h.vs})`)
    }
  }
  if (t !== orig) {
    if (!fs.existsSync(p + '.acc-dedup-orig')) fs.writeFileSync(p + '.acc-dedup-orig', orig)
    fs.writeFileSync(p, t)
  }
}
console.log('total stripped:', totalStripped)
