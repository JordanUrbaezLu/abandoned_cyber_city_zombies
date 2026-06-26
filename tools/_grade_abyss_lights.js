#!/usr/bin/env node
// =============================================================================
// _grade_abyss_lights.js - set each abyss layer's light bake_intensity_scale by DEPTH so deeper
// layers are dimmer (user 2026-06-22: "every layer down the trench should get dimmer - telegraph
// the risk you take going down"). Operates on the LIVE .map, light-KVP ONLY - no geometry / no
// navmesh regen (unlike re-running gen_abyss_layer.js, which re-carves the descent well and the
// trench navmesh, see memory navclamp-snaps-deep-spawns-to-surface). The generator SOURCE was
// updated in lockstep (gen_abyss_layer.js abyssLayerIntensity) so a future full regen matches.
//
// Curve MUST match gen_abyss_layer.js abyssLayerIntensity(): L2=0.40, L3=0.20, L4=0.10, L5=0.05
// (GEOMETRIC, halving per layer, floored at 0.03). Idempotent. Then run a FULL LED build (intensity is baked).
// =============================================================================
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
function intensity(n) { return Math.max(0.03, +(0.40 * Math.pow(0.5, n - 2)).toFixed(3)); }  // halving/level: L2 .40 L3 .20 L4 .10 L5 .05

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
let i = 0, changed = 0; const byLayer = {};
while (i < lines.length) {
  if (lines[i].trim() === '{') {
    let j = i, depth = 0, isLight = false, layer = null, biLine = -1;
    for (; j < lines.length; j++) {
      const t = lines[j].trim();
      if (t === '{') depth++;
      else if (t === '}') { depth--; if (depth === 0) { j++; break; } }
      if (t === '"classname" "light"') isLight = true;
      const m = t.match(/^"targetname" "acc_abyss_l(\d+)_light_\d+"/); if (m) layer = parseInt(m[1], 10);
      if (/^"bake_intensity_scale" "/.test(t)) biLine = j;
    }
    if (isLight && layer !== null && biLine >= 0) {
      const v = intensity(layer);
      lines[biLine] = lines[biLine].replace(/"bake_intensity_scale" "[^"]*"/, `"bake_intensity_scale" "${v}"`);
      changed++; byLayer[layer] = (byLayer[layer] || 0) + 1;
    }
    i = j;
    continue;
  }
  i++;
}
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`graded ${changed} abyss lights ${JSON.stringify(byLayer)} -> L2..L5 intensity = ${[2, 3, 4, 5].map(intensity).join(', ')}`);
