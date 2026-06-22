#!/usr/bin/env node
// strip_lighting_entities.js - remove non-functional lighting-bake entities that are
// the prime suspects for the Radiant LED crash (brush.cpp:1860): volume_sun + every
// reflection_probe. (LED bake is dead here, so these never functioned - user OK'd
// removing them.) Removes each entity's FULL { ... } block including any nested brush.
// Usage: node tools/strip_lighting_entities.js <in.map> <out.map> [classname,classname]
const fs = require('fs');
const [, , inPath, outPath, classArg] = process.argv;
if (!inPath || !outPath) { console.error('usage: strip_lighting_entities.js <in> <out> [classnames]'); process.exit(1); }
const KILL = new Set((classArg || 'volume_sun,reflection_probe').split(','));

const lines = fs.readFileSync(inPath, 'utf8').split('\n');
const out = [];
let depth = 0;            // brace depth (0 = top level / between entities)
let buf = null;          // lines of the current top-level entity block
let killThis = false;
let removed = {};

for (let i = 0; i < lines.length; i++) {
  const line = lines[i];
  const opens = (line.match(/{/g) || []).length;
  const closes = (line.match(/}/g) || []).length;

  if (depth === 0 && opens > 0) {
    // entering a top-level entity block
    buf = [];
    killThis = false;
  }
  if (buf !== null) buf.push(line); else out.push(line);

  // detect classname while inside an entity
  if (buf !== null) {
    const cm = line.match(/"classname"\s+"([^"]+)"/);
    if (cm && KILL.has(cm[1])) { killThis = true; }
  }

  depth += opens - closes;

  if (buf !== null && depth === 0) {
    // closed the top-level entity
    if (killThis) { removed[buf.find(l=>/"classname"/.test(l))?.match(/"classname"\s+"([^"]+)"/)?.[1] || '?'] = (removed['x']||0); /*noop*/
      const cn = (buf.join('\n').match(/"classname"\s+"([^"]+)"/) || [])[1] || '?';
      removed[cn] = (removed[cn] || 0) + 1;
    } else {
      for (const l of buf) out.push(l);
    }
    buf = null;
  }
}
fs.writeFileSync(outPath, out.join('\n'));
console.log(`[strip] removed entities: ${JSON.stringify(removed)}`);
console.log(`[strip] lines: ${lines.length} -> ${out.length}`);
console.log(`[strip] wrote: ${outPath}`);
