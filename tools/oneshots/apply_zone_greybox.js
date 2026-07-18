#!/usr/bin/env node
// One-shot splicer for gen_zone_greybox.js output into the .map.
// Usage: node tools/gen_zone_greybox.js > tmp/greybox_gen.txt
//        node tools/apply_zone_greybox.js
// DO NOT re-run after the greybox has landed - it checks for markers and
// refuses to double-apply.

'use strict';
const fs = require('fs');
const path = require('path');

const repo = path.join(__dirname, '..');
const mapPath = path.join(repo, 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const genPath = path.join(repo, 'tmp', 'greybox_gen.txt');

const gen = fs.readFileSync(genPath, 'utf8');
const sections = {};
let cur = null;
for (const line of gen.split('\n')) {
  const m = line.match(/^===== (SECTION \d|MANIFEST)/);
  if (m) { cur = m[1]; sections[cur] = []; continue; }
  if (cur) sections[cur].push(line);
}
const sec = n => sections[`SECTION ${n}`].join('\n').trim();

let map = fs.readFileSync(mapPath, 'utf8');
if (map.includes('market_zone')) {
  console.error('greybox already applied (market_zone present) - refusing.');
  process.exit(1);
}

// --- 1. replace brush 23 (spawn west perimeter) -------------------------------
const b23 = /\/\/ brush 23\n\{\n guid "\{7A2B9C0A-ACC0-4DE1-8A3F-1F00ACCB0023\}"\n(?:[^\n]*\n){6}\}/;
if (!b23.test(map)) { console.error('brush 23 anchor not found'); process.exit(1); }
map = map.replace(b23, '// brush 23\n' + sec(1).replace(/^=====.*\n/, ''));

// --- 2. replace brush 24 (spawn east perimeter) -------------------------------
const b24 = /\/\/ brush 24\n\{\n guid "\{7A2B9C0B-ACC0-4DE1-8A3F-1F00ACCB0024\}"\n(?:[^\n]*\n){6}\}/;
if (!b24.test(map)) { console.error('brush 24 anchor not found'); process.exit(1); }
map = map.replace(b24, '// brush 24\n' + sec(2).replace(/^=====.*\n/, ''));

// --- 3. insert new worldspawn brushes before entity 0's closing brace ----------
const ent1 = map.indexOf('// entity 1\n');
if (ent1 < 0) { console.error('entity 1 anchor not found'); process.exit(1); }
const closeIdx = map.lastIndexOf('}\n', ent1); // worldspawn closing brace line
map = map.slice(0, closeIdx) + sec(3) + '\n' + map.slice(closeIdx);

// --- 4. append new entities at EOF ---------------------------------------------
if (!map.endsWith('\n')) map += '\n';
map += sec(4) + '\n';

fs.writeFileSync(mapPath, map);
console.log('applied. brushes/entities spliced.');
