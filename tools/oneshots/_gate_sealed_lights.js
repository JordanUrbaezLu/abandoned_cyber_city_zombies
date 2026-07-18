#!/usr/bin/env node
// =============================================================================
// _gate_sealed_lights.js - power-gate the SEALED-AREA lights (abyss + underground)
// so they are DARK until power, matching the surface rooms (user 2026-06-21:
// "0 light until power"). Flips lightingstate1 "1" -> "0" on every `classname "light"`
// entity whose targetname starts with `acc_abyss_l..._light_` or `acc_under_light_`.
//
// WHY a targeted .map edit instead of re-running the generators: gen_abyss_layer.js
// re-emits GEOMETRY and re-carves the descent well (which fragments the trench navmesh,
// see memory navclamp-snaps-deep-spawns-to-surface) - regenerating that just to flip a
// light KVP is needless risk. This touches ONLY the light entities' lightingstate1 value
// (no geometry / no navmesh) so it is bake-safe. The generator SOURCES were updated in
// lockstep (gen_underground_lights.js POWER_MASK, gen_abyss_layer.js lightEntity) so a
// future full regen reproduces the same masks. Plaza (acc_roof_light_plaza_*) is left
// always-on by design. Idempotent (a 0 stays 0). Then run a FULL LED build.
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const TN_RE = /^"targetname" "(acc_abyss_l\d+_light_\d+|acc_under_light_[A-Za-z0-9_]+)"/;

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let i = 0, changed = 0, scanned = 0;
while (i < lines.length) {
  if (lines[i].trim() === '{') {
    let j = i, depth = 0, isLight = false, match = false, lsLine = -1;
    for (; j < lines.length; j++) {
      const t = lines[j].trim();
      if (t === '{') depth++;
      else if (t === '}') { depth--; if (depth === 0) { j++; break; } }
      if (t === '"classname" "light"') isLight = true;
      if (TN_RE.test(t)) match = true;
      if (t === '"lightingstate1" "1"') lsLine = j;
    }
    if (isLight && match) {
      scanned++;
      if (lsLine >= 0) { lines[lsLine] = lines[lsLine].replace('"lightingstate1" "1"', '"lightingstate1" "0"'); changed++; }
    }
    i = j;
    continue;
  }
  i++;
}
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`sealed-area lights: ${scanned} matched, ${changed} flipped lightingstate1 1->0 (abyss + underground; Plaza untouched)`);
