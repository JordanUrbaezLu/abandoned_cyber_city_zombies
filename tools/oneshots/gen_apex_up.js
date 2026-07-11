// Build PaP _up forms for the 5 Apex guns: clone each base block -> apex_X_up_zm (asset block; runtime name = apex_X_up - engine strips the _zm mode suffix),
// swap gunModel/worldModel to the _legendary_02 skin (the PaP visual - skin 02, user 2026-07-06: 'use the second where possible'; all 5 guns ship it), boost stats.
// Writes source_data/acc_apex_up.gdt (a NEW GDT; references models defined in APEX_BO3.gdt).
const fs = require('fs');
const SRC = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130/source_data';
const gdt = fs.readFileSync(SRC + '/zeroy/APEX_BO3.gdt', 'utf8');

// name, base stat -> _up stat overrides (raw PaP values; balance mult tunes effective dmg later)
const GUNS = [
  { n: 'alternator',  boost: { damage:170, minDamage:102, clipSize:26, maxAmmo:12 } },
  { n: 'beam_rifle',  boost: { damage:300, clipSize:40, maxAmmo:8 } },
  { n: 'g2a4',        boost: { damage:190, minDamage:120, clipSize:15, maxAmmo:10 } },
  { n: 'peacekeeper', boost: { damage:340, minDamage:25, clipSize:8, maxAmmo:10, shotCount:12 } },
  { n: 'prowler',     boost: { damage:135, minDamage:68, clipSize:28, maxAmmo:8 } },
];

function extractBlock(base) {
  // header: "apex_<base>_zm" ( "<gdf>" )  then { ... balanced }
  const hdrRe = new RegExp('"apex_' + base + '_zm"\\s*\\(\\s*"[a-z]+\\.gdf"\\s*\\)');
  const m = gdt.match(hdrRe);
  if (!m) throw new Error('no base block for ' + base);
  const hStart = m.index;
  const open = gdt.indexOf('{', hStart);
  let depth = 0, i = open, end = -1;
  for (; i < gdt.length; i++) { if (gdt[i] === '{') depth++; else if (gdt[i] === '}') { depth--; if (depth === 0) { end = i; break; } } }
  if (end < 0) throw new Error('unbalanced braces for ' + base);
  return { header: gdt.slice(hStart, open).trim(), body: gdt.slice(open, end + 1) };
}

function setField(body, field, val) {
  const re = new RegExp('("' + field + '"\\s+)"[^"]*"');
  if (!re.test(body)) { console.log('  WARN: field ' + field + ' not found (skipped)'); return body; }
  return body.replace(re, '$1"' + val + '"');
}

let out = '{\n';
for (const g of GUNS) {
  const { header, body } = extractBlock(g.n);
  // header: "apex_<n>_zm" ( "<gdf>.gdf" )  -> rename to _up
  const upHeader = header.replace('apex_' + g.n + '_zm"', 'apex_' + g.n + '_up_zm"');
  let b = body;
  // swap to legendary skin models (both view + world), all quoted occurrences
  b = b.split('"vm_apex_' + g.n + '"').join('"vm_apex_' + g.n + '_legendary_02"');
  b = b.split('"npc_apex_' + g.n + '"').join('"npc_apex_' + g.n + '_legendary_02"');
  // boost stats
  for (const [k, v] of Object.entries(g.boost)) b = setField(b, k, v);
  out += '\t' + upHeader + '\n' + b.split('\n').map(l => l).join('\n') + '\n';
  const dmg = (b.match(/"damage"\s+"([^"]*)"/) || [])[1];
  const clip = (b.match(/"clipSize"\s+"([^"]*)"/) || [])[1];
  console.log(`  apex_${g.n}_up_zm: dmg=${dmg} clip=${clip} model=vm_apex_${g.n}_legendary_02`);
}
out += '}\n';
fs.writeFileSync(SRC + '/acc_apex_up.gdt', out);
console.log('\nwrote acc_apex_up.gdt (' + out.split('\n').length + ' lines, 5 _up blocks)');
