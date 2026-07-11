// Surgically cut clipSize on XM4 (-35%) + Streetsweeper (-50%) across base + _up + their 6 twins each.
// reserve = clipSize x maxAmmo (maxAmmo untouched), so reserve drops by the same %. Only touches the
// clipSize line inside each matching entry block - nothing else, no whole-file rewrite.
const fs = require('fs');
const REPO = 'c:/Users/jorda/Repositories/abandoned_cyber_city_zombies';
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';

// new clipSize by gun + form (base vs _up). Twins inherit their form's value.
function clipFor(name) {
  if (/^t9_xm4_up/.test(name))          return 46;   // 70 x 0.65 = 45.5 -> 46
  if (/^t9_xm4($|_)/.test(name))        return 20;   // 30 x 0.65 = 19.5 -> 20
  if (/^t9_streetsweeper_up/.test(name)) return 18;  // 36 x 0.50 = 18
  if (/^t9_streetsweeper($|_)/.test(name)) return 6; // 12 x 0.50 = 6
  return null;
}
const headerRe = /^\s*"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)\s*$/;
const clipRe   = /^(\s*"clipSize"\s+")(\d+)("\s*)$/;

function cutFile(path) {
  if (!fs.existsSync(path)) { console.log(`  SKIP (missing): ${path}`); return; }
  const t = fs.readFileSync(path, 'utf8');
  const eol = t.includes('\r\n') ? '\r\n' : '\n';
  const hadNL = /\r?\n$/.test(t);
  const lines = t.split(/\r?\n/); if (hadNL) lines.pop();
  let cur = null, changes = [];
  for (let i = 0; i < lines.length; i++) {
    const h = lines[i].match(headerRe);
    if (h) { cur = clipFor(h[1]) === null ? null : { name: h[1], want: clipFor(h[1]) }; continue; }
    if (cur) {
      const c = lines[i].match(clipRe);
      if (c) {
        const old = +c[2];
        if (old !== cur.want) { lines[i] = c[1] + cur.want + c[3]; changes.push(`${cur.name}: ${old}->${cur.want}`); }
        cur = null; // one clipSize per entry
      }
    }
  }
  fs.writeFileSync(path, lines.join(eol) + (hadNL ? eol : ''));
  console.log(`  ${path.replace(REPO + '/', '').replace(TOOLS + '/', 'DEPLOYED/')}: ${changes.length} clipSize edits`);
  for (const c of changes) console.log(`      ${c}`);
}

console.log('== base guns (deployed skye GDTs) ==');
cutFile(TOOLS + '/source_data/skye_t9_xm4.gdt');
cutFile(TOOLS + '/source_data/skye_t9_streetsweeper.gdt');
console.log('== twins (repo + deployed acc_weapon_variants.gdt) ==');
cutFile(REPO + '/source_data/acc_weapon_variants.gdt');
cutFile(TOOLS + '/source_data/acc_weapon_variants.gdt');
