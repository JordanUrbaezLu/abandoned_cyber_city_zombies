// Surgically remove every GDT entry whose name contains "fastfire" from a weapon GDT file.
// Flat GDT structure (verified): file = `{` ... entries ... `}`; each entry = header line
// `"name" ( "x.gdf" )` + `{` + body pairs (NO braces) + `}`. Braces appear ONLY as lone lines.
// Validates hard and ABORTS (no write) if anything looks off. Usage: node strip_fastfire_gdt.js <file> [--write]
const fs = require('fs');
const file = process.argv[2];
const doWrite = process.argv.includes('--write');
if (!file || !fs.existsSync(file)) { console.error('missing file:', file); process.exit(2); }

const text = fs.readFileSync(file, 'utf8');
const EOL = text.includes('\r\n') ? '\r\n' : '\n';
const hadTrailingNL = /\r?\n$/.test(text);
const lines = text.split(/\r?\n/);
if (hadTrailingNL) lines.pop(); // drop the empty element from a trailing newline

const headerRe = /^\s*"([^"]+)"\s*\(\s*"[^"]*\.gdf"\s*\)\s*$/;
const isOpen = (l) => /^\s*\{\s*$/.test(l);
const isClose = (l) => /^\s*\}\s*$/.test(l);

const before = { headers: 0, ff: 0, open: 0, close: 0 };
for (const l of lines) {
  const m = l.match(headerRe);
  if (m) { before.headers++; if (m[1].includes('fastfire')) before.ff++; }
  if (isOpen(l)) before.open++;
  if (isClose(l)) before.close++;
}

const out = [];
let i = 0, removed = 0, removedLines = 0;
while (i < lines.length) {
  const m = lines[i].match(headerRe);
  if (m && m[1].includes('fastfire')) {
    let j = i + 1;
    while (j < lines.length && !isOpen(lines[j])) j++;        // to opening brace
    let depth = 0, k = j;
    for (; k < lines.length; k++) {
      if (isOpen(lines[k])) depth++;
      else if (isClose(lines[k])) { depth--; if (depth === 0) break; }
    }
    if (depth !== 0) { console.error('ABORT: unbalanced block for', m[1]); process.exit(3); }
    removed++; removedLines += (k - i + 1);
    i = k + 1;
    continue;
  }
  out.push(lines[i]); i++;
}

// validate
const after = { headers: 0, ff: 0, open: 0, close: 0 };
for (const l of out) {
  const m = l.match(headerRe);
  if (m) { after.headers++; if (m[1].includes('fastfire')) after.ff++; }
  if (isOpen(l)) after.open++;
  if (isClose(l)) after.close++;
}
const firstNonEmpty = out.find(l => l.trim() !== '');
const lastNonEmpty = [...out].reverse().find(l => l.trim() !== '');
const checks = [
  ['fastfire fully removed', after.ff === 0],
  ['headers dropped by exactly ff count', after.headers === before.headers - before.ff],
  ['braces balanced', after.open === after.close],
  ['open == headers+1 (entries + wrapper)', after.open === after.headers + 1],
  ['starts with {', firstNonEmpty === '{'],
  ['ends with }', lastNonEmpty === '}'],
  ['removed count == before.ff', removed === before.ff],
];
const bad = checks.filter(c => !c[1]);
console.log(`${file}`);
console.log(`  before: headers=${before.headers} ff=${before.ff} open=${before.open} close=${before.close}`);
console.log(`  after:  headers=${after.headers} ff=${after.ff} open=${after.open} close=${after.close}  (removed ${removed} entries / ${removedLines} lines)`);
for (const c of checks) console.log(`  [${c[1] ? 'OK ' : 'FAIL'}] ${c[0]}`);
if (bad.length) { console.error('  *** VALIDATION FAILED - NOT WRITING ***'); process.exit(1); }
if (doWrite) {
  const result = out.join(EOL) + (hadTrailingNL ? EOL : '');
  fs.writeFileSync(file, result);
  console.log('  WROTE (stripped).');
} else {
  console.log('  dry-run OK (pass --write to apply).');
}
