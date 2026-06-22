#!/usr/bin/env node
// dedup_guids.js - make every GUID in the .map unique. Our carve generators (add_under_room,
// carve_wing, carve_arena_wing) reset their guidCounter and were each run twice (south/north,
// west/east), so paired runs collide GUIDs (audit 2026-06-19: dup GUIDs = identity-tracking
// confusion + extra race-corruption surface). This keeps the FIRST occurrence of each GUID and
// re-salts every later duplicate to a fresh, collision-checked value. Well-formed hex GUIDs only
// (a MALFORMED guid is what crashes the LED bake, memory led-relight-dead-end-enclosed-geometry).
// GUIDs are cosmetic to cod2map, so geometry/bake are unaffected; this is repo hygiene.
//
// Usage: node tools/dedup_guids.js <in.map> <out.map>
'use strict';
const fs = require('fs');
const [, , inPath, outArg] = process.argv;
if (!inPath || !outArg) { console.error('usage: dedup_guids.js <in> <out>'); process.exit(1); }

let text = fs.readFileSync(inPath, 'utf8');
const RE = /guid "(\{[0-9A-Fa-f-]+\})"/g;

const all = new Set();
let m;
while ((m = RE.exec(text)) !== null) all.add(m[1]);

let counter = 0;
function freshGuid() {
  let g;
  do { counter++; g = `{DED00000-DED0-4ED0-8ED0-${counter.toString(16).toUpperCase().padStart(12, '0')}}`; } while (all.has(g));
  all.add(g);
  return g;
}

const seen = new Set();
let dups = 0;
text = text.replace(RE, (full, gid) => {
  if (seen.has(gid)) { dups++; return `guid "${freshGuid()}"`; }
  seen.add(gid);
  return full;
});

fs.writeFileSync(outArg, text);
console.log(`re-salted ${dups} duplicate GUID(s); ${seen.size} unique GUIDs remain.`);
