#!/usr/bin/env node
// convert_bridge_to_brushmodel.js - the corp-trench BRIDGE (a thin FLOATING world slab @ z+58) renders
// TRANSPARENT in-game (user 2026-06-28: "transparent like it doesn't have a texture"). A thin floating world
// brush gets a broken/empty LED lightmap, so the surface draws see-through. Fix per memory
// brushmodel-wall-led-exempt: move the brush OUT of worldspawn into a script_brushmodel ENTITY - those are
// LED-EXEMPT (render with runtime/dynamic lighting, no baked lightmap), so the transparency goes away.
// Solidity is asserted in GSC (_acc_bus_trench.gsc solidify_corp_bridge, like the deep-prop-clip brushmodels).
// Idempotent: if acc_corp_bridge already exists, no-op.
'use strict';
const fs = require('fs');
const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
let lines = fs.readFileSync(MAP, 'utf8').split('\n');

if (lines.some(l => l.includes('"targetname" "acc_corp_bridge"'))) { console.log('[bridge] already a script_brushmodel - no-op'); process.exit(0); }

const ci = lines.findIndex(l => l.includes('corp trench BRIDGE'));
if (ci === -1) { console.error('[bridge] "corp trench BRIDGE" comment not found'); process.exit(1); }
let s = -1; for (let i = ci; i < lines.length; i++) { if (lines[i].trim() === '{') { s = i; break; } }
if (s === -1) { console.error('[bridge] brush open not found'); process.exit(1); }
let depth = 0, e = -1;
for (let i = s; i < lines.length; i++) { depth += (lines[i].match(/{/g)||[]).length - (lines[i].match(/}/g)||[]).length; if (depth === 0) { e = i; break; } }
const brush = lines.slice(s, e + 1);   // the bridge brush block { ... }

// remove the brush from worldspawn (s..e); leave the comment line, annotate it
lines[ci] = '// corp trench BRIDGE -> moved to script_brushmodel "acc_corp_bridge" (end of file): thin floating world slab baked TRANSPARENT; brushmodel is LED-exempt';
lines = [...lines.slice(0, ci + 1), ...lines.slice(e + 1)];

// build the script_brushmodel entity (brush indented one space inside)
const ent = ['// >>> ACC CORP BRIDGE (convert_bridge_to_brushmodel.js) - LED-exempt brushmodel so the thin slab renders',
  '{',
  ' "classname" "script_brushmodel"',
  ' "targetname" "acc_corp_bridge"',
  ...brush.map(l => ' ' + l),
  '}',
  '// <<< ACC CORP BRIDGE'];

while (lines.length && lines[lines.length - 1] === '') lines.pop();
lines.push(...ent, '');
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`[bridge] converted to script_brushmodel acc_corp_bridge (moved ${brush.length} brush lines out of worldspawn). Needs GSC solidify + FULL build.`);
