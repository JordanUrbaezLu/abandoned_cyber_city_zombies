#!/usr/bin/env node
// gen_reflection_probes.js [--revert] - reflection_probe entities so the WET floors (asphalt/marble/tile we
// painted) mirror the neon = the cyberpunk "wet city" signal (docs/29: we shipped 0; industrial maps ship ~23).
// BAKED by the LED pass (radiant_modtools +recompute) per the mapmaking KB, so a FULL LED build captures them.
// One per zone at ~eye height + the trench. Self-contained marked block, idempotent, `--revert` removes it.
//
// Usage: node tools/gen_reflection_probes.js          inject/refresh
//        node tools/gen_reflection_probes.js --revert  remove
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const REVERT = process.argv.includes('--revert');

// [x, y, z] - one probe per zone at eye height (captures room + the neon above for the wet-floor mirror).
const PROBES = [
  [    0,  100,  80], // PLAZA
  [    0, 1950,  90], // CORP / Bus Station hub
  [-1596,  928,  80], // MARKET
  [ 1634,  928,  80], // ALLEY
  [-1444, 2830,  80], // ROOF / Helipad
  [ 1454, 2830,  80], // VAULT
  [    0, 3658,  90], // LAB
  [    0, 1950,-170], // TRENCH (under bus station)
];

let gc = 0;
function pguid(){ gc++; const c=gc.toString(16).toUpperCase().padStart(12,'0'); return `{7A2BCE05-CE05-4E0C-8A3F-${c}}`; }
function probe(x, y, z) {
  return ['{', `guid "${pguid()}"`,
    '"classname" "reflection_probe"',
    `"origin" "${x} ${y} ${z}"`,
    '}'].join('\n');
}

const BEGIN = '// >>> ACC REFLECTION PROBES (gen_reflection_probes.js) - wet-floor neon mirrors';
const END   = '// <<< ACC REFLECTION PROBES';

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
for (;;) { const b = lines.findIndex(l => l.includes(BEGIN)); if (b === -1) break;
  let e = -1; for (let i=b;i<lines.length;i++){ if(lines[i].includes(END)){e=i;break;} }
  lines = e===-1 ? [...lines.slice(0,b), ...lines.slice(b+1)] : [...lines.slice(0,b), ...lines.slice(e+1)]; }

while (lines.length && lines[lines.length-1]==='') lines.pop();
if (REVERT) { lines.push(''); fs.writeFileSync(MAP, lines.join('\n')); console.log('[probes] REVERTED: removed all reflection probes.'); process.exit(0); }

lines.push(BEGIN, ...PROBES.map(p=>probe(...p)), END, '');
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`[probes] injected ${PROBES.length} reflection probes. FULL LED build required to bake them.`);
