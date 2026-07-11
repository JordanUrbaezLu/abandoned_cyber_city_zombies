const fs = require('fs');
const gdt = process.argv[2];
const names = process.argv.slice(3);
let s = fs.readFileSync(gdt, 'utf8');
fs.writeFileSync(gdt + '.acc-predup-backup', s);
let removed = 0;
for (const name of names) {
  // find:  "<name>" ( "<type>.gdf" )  ...  { ... }   (remove header line through matching close brace)
  const re = new RegExp('[ \\t]*"' + name.replace(/[.*+?^${}()|[\]\\]/g, '\\$&') + '"\\s*\\(\\s*"[^"]+"\\s*\\)\\s*', 'g');
  const m = re.exec(s);
  if (!m) { console.log('NOT FOUND: ' + name); continue; }
  // from match end, find the { ... } balanced group
  let i = m.index + m[0].length;
  while (i < s.length && s[i] !== '{') i++;
  if (s[i] !== '{') { console.log('no brace for ' + name); continue; }
  let depth = 0, j = i;
  for (; j < s.length; j++) { if (s[j] === '{') depth++; else if (s[j] === '}') { depth--; if (depth === 0) { j++; break; } } }
  // also swallow a trailing newline
  while (j < s.length && (s[j] === '\r' || s[j] === '\n')) j++;
  // and the leading whitespace/newline before the header
  let start = m.index;
  while (start > 0 && (s[start-1] === '\r' || s[start-1] === '\n' || s[start-1] === ' ' || s[start-1] === '\t')) start--;
  s = s.slice(0, start) + '\n' + s.slice(j);
  removed++;
  console.log('removed block: ' + name);
}
fs.writeFileSync(gdt, s);
console.log('done, removed ' + removed + '/' + names.length + ' blocks from ' + gdt);
