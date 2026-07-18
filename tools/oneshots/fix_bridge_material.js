#!/usr/bin/env node
// fix_bridge_material.js - the corp-trench BRIDGE (a flat slab @ z+58 over the trench) got the Corp zone's
// FLOOR material (dark marble) in the per-zone art pass and blended into the dark trench -> read as "missing"
// (user 2026-06-28). Repaint just that ONE brush (the block after the "corp trench BRIDGE" comment) to a
// readable diamond-plate walkway, scoped so the rest of the Corp marble floor is untouched. Material change ->
// FULL LED build. Idempotent (swaps whatever the bridge currently is to TO).
'use strict';
const fs = require('fs');
const MAP = 'map_source/zm/zm_abandoned_cyber_city.map';
const TO = 't7_metal_diamond_plate_worn_wet';   // grated metal walkway - clearly reads as a bridge, contrasts the dark trench
const FROMS = [ 't7_stone_marble_dark_01', 't7_asphalt_damaged_dark_wet', 't7_metal_worn_iron_dark' ]; // whatever it currently is

let lines = fs.readFileSync(MAP, 'utf8').split('\n');
const ci = lines.findIndex(l => l.includes('corp trench BRIDGE'));
if (ci === -1) { console.error('[bridge] "corp trench BRIDGE" comment not found'); process.exit(1); }
let s = -1; for (let i = ci; i < lines.length; i++) { if (lines[i].trim() === '{') { s = i; break; } }
if (s === -1) { console.error('[bridge] brush open not found'); process.exit(1); }
let depth = 0, e = -1;
for (let i = s; i < lines.length; i++) { depth += (lines[i].match(/{/g)||[]).length - (lines[i].match(/}/g)||[]).length; if (depth === 0) { e = i; break; } }
let n = 0;
for (let i = s; i <= e; i++) for (const F of FROMS) if (lines[i].includes(F)) { lines[i] = lines[i].split(F).join(TO); n++; break; }
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`[bridge] repainted ${n} faces -> ${TO} on the corp-trench bridge brush (lines ${s}-${e})`);
