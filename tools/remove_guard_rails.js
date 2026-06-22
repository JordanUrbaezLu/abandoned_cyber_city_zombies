#!/usr/bin/env node
// remove_guard_rails.js - delete the trench stair guard-rail brushes (user wants them
// gone; gen_corp_trench.js keeps re-emitting them on every trench regen). Matches by the
// "// corp trench ... guard rail" comment + the brush block that follows, so it's robust
// to the floor-depth / step-count changes that move the rail bounds.
// Usage: node tools/remove_guard_rails.js <in.map> <out.map|--dry>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: remove_guard_rails.js <in> <out|--dry>'); process.exit(1); }
const dry = (outArg === '--dry');
const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const remove = new Array(lines.length).fill(false);
let removed = 0;
for (let i = 0; i < lines.length; i++) {
  if (/^\s*\/\//.test(lines[i]) && /guard rail/i.test(lines[i])) {
    let j = i + 1;
    while (j < lines.length && !/\{/.test(lines[j])) j++;     // next brush open
    if (j >= lines.length) continue;
    let d = 0, k = j;
    for (; k < lines.length; k++) { d += (lines[k].match(/{/g) || []).length - (lines[k].match(/}/g) || []).length; if (d === 0) break; }
    for (let m = i; m <= k; m++) remove[m] = true;
    removed++;
    console.log(`  REMOVE guard-rail block: lines ${i + 1}-${k + 1}`);
  }
}
console.log(`[rails] removed ${removed} guard-rail block(s).`);
if (removed !== 2) { console.error(`ERROR: expected 2 guard rails, removed ${removed} - aborting.`); process.exit(2); }
if (!dry) { fs.writeFileSync(outArg, lines.filter((_, i) => !remove[i]).join('\n')); console.log(`[rails] wrote ${outArg}`); }
else console.log('[rails] --dry: nothing written.');
