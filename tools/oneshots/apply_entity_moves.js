#!/usr/bin/env node
// One-shot: relocate gameplay entities to their docs/03_layout.md zones.
// Perks+PaP+Bowie -> Lab; ICR-1+Sheiva+power -> Corp; Haymaker -> Alley;
// Drakon -> Roof; Frag -> Vault; Mystery Box -> Market. Chalk decal meshes
// follow their wallbuys. Refuses to double-apply.

'use strict';
const fs = require('fs');
const path = require('path');

const mapPath = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
let map = fs.readFileSync(mapPath, 'utf8');

if (map.includes('"origin" "-600 4195 0"')) {
  console.error('entity moves already applied - refusing.');
  process.exit(1);
}

// guid -> { origin, angles? }
const moves = {
  // PaP prefab -> Lab west side
  '122366A5-BD0F-46AD-B3E5-59AF52D4A611': { origin: '-700 3700 7.5' },
  // Mystery Box (box_start prefab) -> Market north wall
  'ED4EC767-A036-4B7A-BD00-F7BC323B169A': { origin: '-1881 1540 -2' },
  // Power switch prefab -> Corp east wall
  'E1B4DCC3-0D06-402E-A5C9-C3B0CA5D7B24': { origin: '790 1900 1' },
  // 9 perk machines -> Lab north wall row (west->east)
  'E53B05AB-5AF2-4C98-98EE-6EE44554B4BB': { origin: '-600 4195 0' },                                // Quick Revive
  'BDC50684-221F-499A-B256-BB5F86692F12': { origin: '-450 4195 3' },                                // Jug
  'C451BE9D-44F8-4A98-819D-2C9F1654DA6B': { origin: '-300 4195 0' },                                // Speed Cola
  '31057A41-E779-448D-B6C2-BE226858B602': { origin: '-150 4195 0' },                                // Double Tap
  'F58AB0FC-8927-4396-ADB6-DEB08DDC8875': { origin: '0 4195 0' },                                   // Stamin-Up
  '1330FD56-4040-43E2-A9F2-82B3D68FA2C2': { origin: '150 4195 0' },                                 // Mule Kick
  '7A2B9C03-ACC0-4DE1-8A3F-1F00ACCE0033': { origin: '300 4195 0' },                                 // Deadshot
  '7A2B9C0C-ACC0-4DE1-8A3F-1F00ACCE0038': { origin: '450 4195 0', angles: '0 359.999 0' },          // Widow's Wine
  '7A2B9C15-ACC0-4DE1-8A3F-1F00ACCE0043': { origin: '600 4195 0', angles: '0 359.999 0' },          // PhD Flopper
  // ICR-1 wallbuy -> Corp south wall (faces north, yaw 0)
  '7A2B9C04-ACC0-4DE1-8A3F-1F00ACCE0034': { origin: '-303 1170 53', angles: '0 0 0' },
  '7A2B9C05-ACC0-4DE1-8A3F-1F00ACCE0035': { origin: '-300 1170 56', angles: '0 0 0' },
  // Haymaker wallbuy -> Alley north wall (faces south, yaw 180 kept)
  '7A2B9C06-ACC0-4DE1-8A3F-1F00ACCE0036': { origin: '1903 1578 53' },
  '7A2B9C07-ACC0-4DE1-8A3F-1F00ACCE0037': { origin: '1900 1578 56' },
  // Bowie wallbuy -> Lab south wall
  '7A2B9C0D-ACC0-4DE1-8A3F-1F00ACCE0039': { origin: '-9.5 3070 60' },
  '7A2B9C0E-ACC0-4DE1-8A3F-1F00ACCE0040': { origin: '0 3070 60' },
  // Drakon wallbuy -> Roof south wall
  '7A2B9C0F-ACC0-4DE1-8A3F-1F00ACCE0041': { origin: '-1703 2222 53' },
  '7A2B9C10-ACC0-4DE1-8A3F-1F00ACCE0042': { origin: '-1700 2222 56' },
  // Sheiva wallbuy -> Corp south wall
  '7A2B9C16-ACC0-4DE1-8A3F-1F00ACCE0044': { origin: '297 1170 53' },
  '7A2B9C17-ACC0-4DE1-8A3F-1F00ACCE0045': { origin: '300 1170 56' },
  // Frag wallbuy -> Vault south wall
  '7A2B9C18-ACC0-4DE1-8A3F-1F00ACCE0046': { origin: '1703.5 2219.5 60' },
  '7A2B9C19-ACC0-4DE1-8A3F-1F00ACCE0047': { origin: '1700 2222 60' },
};

const lines = map.split('\n');
let applied = 0;
for (let i = 0; i < lines.length; i++) {
  const m = lines[i].match(/^guid "\{([0-9A-F-]+)\}"$/);
  if (!m || !moves[m[1]]) continue;
  const mv = moves[m[1]];
  for (let j = i + 1; j < lines.length && lines[j] !== '}'; j++) {
    if (mv.origin && lines[j].startsWith('"origin"')) lines[j] = `"origin" "${mv.origin}"`;
    if (mv.angles && lines[j].startsWith('"angles"')) lines[j] = `"angles" "${mv.angles}"`;
  }
  applied++;
}
if (applied !== Object.keys(moves).length) {
  console.error(`expected ${Object.keys(moves).length} entity moves, applied ${applied} - aborting`);
  process.exit(1);
}
map = lines.join('\n');

// chalk decal meshes: brush guid -> { col1x, col2x, y }   (col1 carries t 0.., col2 t 1024..)
const chalks = {
  '7A2B9C02-ACC0-4DE1-8A3F-1F00ACCB0020': { col1: -276.25, col2: -318.25, y: 1170 },   // icr1 -> corp
  '7A2B9C11-ACC0-4DE1-8A3F-1F00ACCB0025': { col1: 23.75, col2: -18.25, y: 3070 },      // bowie -> lab
  '7A2B9C12-ACC0-4DE1-8A3F-1F00ACCB0026': { col1: -1676.25, col2: -1718.25, y: 2222 }, // drakon -> roof
  '7A2B9C13-ACC0-4DE1-8A3F-1F00ACCB0027': { col1: 323.75, col2: 281.75, y: 1170 },     // shiva -> corp
  '7A2B9C14-ACC0-4DE1-8A3F-1F00ACCB0028': { col1: 1723.75, col2: 1681.75, y: 2222 },   // frag -> vault
};

let chalkApplied = 0;
for (const [g, c] of Object.entries(chalks)) {
  const re = new RegExp(
    `(guid "\\{${g}\\}"[\\s\\S]*?2 2 0 8\\n)` +
    `   \\(\\n\\tv [^\\n]*\\n\\tv [^\\n]*\\n   \\)\\n` +
    `   \\(\\n\\tv [^\\n]*\\n\\tv [^\\n]*\\n   \\)`
  );
  if (!re.test(map)) { console.error(`chalk ${g} not matched`); process.exit(1); }
  map = map.replace(re,
    `$1   (\n` +
    `\tv ${c.col1} ${c.y} 32.5 t 0 -0 -1.0001428 -6.7082205\n` +
    `\tv ${c.col1} ${c.y} 74.5 t 0 -1024 -0.99985725 -9.0415535\n` +
    `   )\n` +
    `   (\n` +
    `\tv ${c.col2} ${c.y} 32.5 t 1024 -0 0.87485725 -6.7084455\n` +
    `\tv ${c.col2} ${c.y} 74.5 t 1024 -1024 0.87514287 -9.0417786\n` +
    `   )`
  );
  chalkApplied++;
}

fs.writeFileSync(mapPath, map);
console.log(`applied: ${applied} entity moves, ${chalkApplied} chalk moves.`);
