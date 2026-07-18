#!/usr/bin/env node
// strip_entities.js - remove top-level entity blocks whose body matches a regex
// (e.g. a targetname pattern). Used to bisect which added feature brushes crash the
// Radiant LED bake. Removes the full { ... } block incl. nested brushes.
// Usage: node tools/strip_entities.js <in.map> <out.map> "<regex>"
const fs = require('fs');
const [, , inPath, outPath, pattern] = process.argv;
if (!inPath || !outPath || !pattern) { console.error('usage: strip_entities.js <in> <out> "<regex>"'); process.exit(1); }
const re = new RegExp(pattern);
const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const out = [];
let depth = 0, buf = null, kill = false, removed = 0;
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const opens = (line.match(/{/g) || []).length;
  const closes = (line.match(/}/g) || []).length;
  if (depth === 0 && opens > 0) { buf = []; kill = false; }
  if (buf !== null) buf.push(line); else out.push(line);
  if (buf !== null && re.test(line)) kill = true;
  depth += opens - closes;
  if (buf !== null && depth === 0) {
    if (kill) removed++; else for (const l of buf) out.push(l);
    buf = null;
  }
}
fs.writeFileSync(outPath, out.join('\n'));
console.log(`[strip] entities removed (match /${pattern}/): ${removed}`);
console.log(`[strip] lines: ${lines.length} -> ${out.length}; wrote ${outPath}`);
