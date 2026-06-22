#!/usr/bin/env node
// bisect_brushes.js - remove a RANGE of worldspawn brushes (by appearance index)
// to binary-search which brush crashes the Radiant LED bake. Worldspawn = the FIRST
// top-level entity; its brushes are the depth-2 { } blocks inside it. All other
// entities and the worldspawn KVPs are preserved.
// Usage:  node tools/bisect_brushes.js <in.map> <out.map> <removeFrom> <removeTo>
//   (removes worldspawn brushes with index in [removeFrom, removeTo); pass -1 -1 to
//    just report the worldspawn brush count.)
const fs = require('fs');
const [, , inPath, outPath, fromS, toS] = process.argv;
if (!inPath || !outPath) { console.error('usage: bisect_brushes.js <in> <out> <removeFrom> <removeTo>'); process.exit(1); }
const removeFrom = parseInt(fromS ?? '-1', 10), removeTo = parseInt(toS ?? '-1', 10);
const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const out = [];
let depth = 0, entityIdx = -1, inWorldspawn = false, brushIdx = -1, inBrush = false, killBrush = false, kept = 0, removed = 0;
for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const opens = (line.match(/{/g) || []).length;
  const closes = (line.match(/}/g) || []).length;
  // entering a top-level entity
  if (depth === 0 && opens > 0) { entityIdx++; inWorldspawn = (entityIdx === 0); }
  // entering a brush (depth 1 -> 2) inside worldspawn
  const enteringBrush = inWorldspawn && depth === 1 && opens > 0;
  if (enteringBrush) {
    brushIdx++;
    killBrush = (brushIdx >= removeFrom && brushIdx < removeTo);
    inBrush = true;
    if (killBrush) removed++; else kept++;
  }
  // emit (unless we're inside a killed brush)
  if (!(inBrush && killBrush)) out.push(line);
  depth += opens - closes;
  // leaving the brush
  if (inBrush && depth === 1) { inBrush = false; killBrush = false; }
}
fs.writeFileSync(outPath, out.join('\n'));
console.log(`[bisect] worldspawn brushes: ${brushIdx + 1} total | kept ${kept} removed ${removed} (range [${removeFrom},${removeTo}))`);
console.log(`[bisect] wrote ${outPath}  (lines ${lines.length} -> ${out.length})`);
