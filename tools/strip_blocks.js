#!/usr/bin/env node
// strip_blocks.js - remove the innermost { ... } block(s) containing a line matching
// a regex (e.g. a guid). Works at any brace depth (worldspawn brushes or entities).
// Usage: node tools/strip_blocks.js <in.map> <out.map> "<regex>"
const fs = require('fs');
const [, , inPath, outPath, pattern] = process.argv;
if (!inPath || !outPath || !pattern) { console.error('usage: strip_blocks.js <in> <out> "<regex>"'); process.exit(1); }
const re = new RegExp(pattern);
const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
const stack = [];
let removed = 0;
for (let i = 0; i < lines.length; i++) {
  const opens = (lines[i].match(/{/g) || []).length;
  const closes = (lines[i].match(/}/g) || []).length;
  for (let o = 0; o < opens; o++) stack.push({ start: i, match: false });
  if (re.test(lines[i]) && stack.length) stack[stack.length - 1].match = true;
  for (let c = 0; c < closes; c++) {
    const blk = stack.pop();
    if (blk && blk.match) { for (let j = blk.start; j <= i; j++) remove[j] = true; removed++; }
  }
}
const out = lines.filter((_, i) => !remove[i]);
fs.writeFileSync(outPath, out.join('\n'));
console.log(`[strip_blocks] removed ${removed} block(s) matching /${pattern}/  (lines ${lines.length} -> ${out.length})`);
