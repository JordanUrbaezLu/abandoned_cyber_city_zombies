#!/usr/bin/env node
// gen_neon_lights.js [--revert] - per-ZONE colored NEON accent lights: the cyberpunk "pools of saturated
// colour in darkness" look (docs/29 §5 per-zone palette). POWER-GATED (lightingstate1=0 -> dark pre-power,
// ignite on power) exactly like the abyss/hub lights, so flipping the switches transforms the map.
//
// Self-contained + REVERTABLE: one marked entity block (>>> ACC NEON LIGHTS ... <<<), idempotent strip on
// re-run, `--revert` removes it cleanly. BAKED into the lightmap -> needs a FULL LED build (no geometry, so
// it can't hit brush.cpp:1860). Reuses the VERBATIM kelson8/hub PRIMARY_OMNI entity proven to bake.
//
// Usage: node tools/gen_neon_lights.js          inject/refresh the neon lights
//        node tools/gen_neon_lights.js --revert  remove them
'use strict';
const fs = require('fs'), path = require('path');
const MAP = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const REVERT = process.argv.includes('--revert');

// neon palette (RGB 0..1) - ONE UNIQUE colour per zone, no repeats (user 2026-06-28).
const CYAN='0 1 1', BLUE='0.15 0.4 1', MAGENTA='1 0 1', RED='1 0.08 0.08',
      ORANGE='1 0.45 0.05', GREEN='0.15 1 0.25', PURPLE='0.6 0.2 1', YELLOW='1 0.85 0.15', WHITE='1 1 1';

// [x, y, z, color, radius, intensity]  - a FEW saturated pools per zone, darkness between (noir). Each zone is
// ONE colour. These are the VISIBLE colour (the source is a light entity = no on-map sprite); the FX glow ORBS
// that used to show floating in the rooms were removed (_acc_atmosphere.gsc apply_fx, user "don't show the source").
const LIGHTS = [
  // PLAZA (spawn) - CYAN
  [   0,  220, 150, CYAN,    440, 0.85], [-520, 520, 150, CYAN,    380, 0.6 ], [ 520, -160, 150, CYAN,    360, 0.55],
  // CORP / Bus Station (hub) - BLUE (corporate)
  [   0, 1450, 175, BLUE,    470, 0.9 ], [   0,2450, 175, BLUE,    470, 0.75], [-660,1950, 175, BLUE,    380, 0.55], [ 660,1950,175, BLUE, 380, 0.65],
  // MARKET - MAGENTA (dead-stall signage)
  [-1596, 760, 150, MAGENTA, 440, 0.9 ], [-1850,1160,150, MAGENTA, 380, 0.7 ], [-1300, 480, 150, MAGENTA, 360, 0.6 ],
  // ALLEY - RED (hazard)
  [ 1500, 700, 150, RED,     400, 0.8 ], [ 1860,1160,150, RED,     360, 0.55],
  // ROOF / Helipad - ORANGE (edge lights)
  [-1444,2560, 150, ORANGE,  460, 0.7 ], [-1720,3120,150, ORANGE,  380, 0.55],
  // VAULT - GREEN (cold server/data glow)
  [ 1300,2500, 150, GREEN,   420, 0.75], [ 1680,3120,150, GREEN,   360, 0.6 ], [ 1454,2830,150, GREEN,  380, 0.65],
  // LAB - PURPLE (cyberware tech)
  [ -360,3480, 175, PURPLE,  400, 0.75], [  360,3480,175, PURPLE,  400, 0.75], [   0,4060,175, PURPLE, 420, 0.65],
  // TRENCH (under bus station) - YELLOW (industrial caution)
  [    0,1950,-180, YELLOW,  440, 0.6 ], [    0,1500,-180, YELLOW,  360, 0.5 ],
];

let gc = 0;
function lguid(){ gc++; const c=gc.toString(16).toUpperCase().padStart(12,'0'); return `{7A2BCE0E-CE04-4E14-8A3F-${c}}`; }
function lightEntity(i, x, y, z, color, radius, intensity) {
  return ['{', `guid "${lguid()}"`,
    '"classname" "light"', `"targetname" "acc_neon_${i}"`,
    `"origin" "${x} ${y} ${z}"`,
    '"PRIMARY_TYPE" "PRIMARY_OMNI"', '"PRIMARY_NOSHADOWMAP" "1"', '"ENABLE_FALLOFF" "1"',
    `"_color" "${color}"`, `"radius" "${radius}"`, '"stops" "6"', '"falloffdistance" "12"',
    `"bake_intensity_scale" "${intensity}"`, '"client_server" "ClientSide"', '"def_tile" "1 1"',
    '"excludeDedicated" "Off"', '"far_edge" "0.949999988079071"', '"fov_outer" "90"',
    // DARK until power (lightingstate1=0); ignite post-power - matches the map's dim-until-power design.
    '"lightingstate1" "0"', '"lightingstate2" "1"', '"lightingstate3" "1"', '"lightingstate4" "1"',
    '"penumbraRadius" "1.5"', '"roundness" "0.5"', '"shadowUpdate" "Never"', '"shadowmapScale" "1"',
    '"superellipse" "0.75 1 0.75 1"', '"volumetricSampleCount" "8"', '"name" "light"', '"spawnflags" "82"',
    '}'].join('\n');
}

const BEGIN = '// >>> ACC NEON LIGHTS (gen_neon_lights.js) - per-zone colored accent pools, power-gated';
const END   = '// <<< ACC NEON LIGHTS';

let lines = fs.readFileSync(MAP, 'utf8').split(/\r?\n/);
// idempotent strip of any prior block
for (;;) { const b = lines.findIndex(l => l.includes(BEGIN)); if (b === -1) break;
  let e = -1; for (let i=b;i<lines.length;i++){ if(lines[i].includes(END)){e=i;break;} }
  lines = e===-1 ? [...lines.slice(0,b), ...lines.slice(b+1)] : [...lines.slice(0,b), ...lines.slice(e+1)]; }

while (lines.length && lines[lines.length-1]==='') lines.pop();
if (REVERT) { lines.push(''); fs.writeFileSync(MAP, lines.join('\n')); console.log('[neon] REVERTED: removed all neon lights.'); process.exit(0); }

const block = [BEGIN, ...LIGHTS.map((L,i)=>lightEntity(i, ...L)), END];
lines.push(...block, '');
fs.writeFileSync(MAP, lines.join('\n'));
console.log(`[neon] injected ${LIGHTS.length} power-gated colored lights across 7 zones + trench. FULL LED build required.`);
