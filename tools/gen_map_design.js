#!/usr/bin/env node
// Renders docs/map_design.svg from the LIVE .map source: rooms/corridors
// (geometry constants from gen_zone_greybox.js) + every gameplay entity
// (perks, wallbuys, boxes, PaP, power, doors, terminals, spawns) parsed
// from the entity lump. Re-run any time the map changes:
//   node tools/gen_map_design.js

'use strict';
const fs = require('fs');
const path = require('path');

const mapPath = path.join(__dirname, '..', 'map_source', 'zm', 'zm_abandoned_cyber_city.map');
const outPath = path.join(__dirname, '..', 'docs', 'map_design.svg');
const src = fs.readFileSync(mapPath, 'utf8');

// ---- parse entity KVP blocks (brushes skipped) -------------------------------
const ents = [];
{
  const lines = src.split('\n');
  let cur = null, depth = 0;
  for (const line of lines) {
    if (line === '{') { depth++; if (depth === 1) cur = { _planes: [] }; continue; }
    if (line === '}') { depth--; if (depth === 0 && cur) { ents.push(cur); cur = null; } continue; }
    if (depth === 1 && cur) {
      const m = line.match(/^"([^"]+)" "([^"]*)"$/);
      if (m) cur[m[1]] = m[2];
    }
    if (depth === 2 && cur && line.startsWith(' (')) cur._planes.push(line);
  }
}
function origin(e) {
  if (e.origin) {
    const [x, y, z] = e.origin.split(' ').map(Number);
    return { x, y, z };
  }
  // brush entity: derive center from the 6 axis planes (emitter order:
  // z1, z2, y1, x2, y2, x1 - first point of each plane line carries the bound)
  if (e._planes.length >= 6) {
    const first = (i, tok) => Number(e._planes[i].trim().split(/\s+/)[tok]);
    const y1 = first(2, 2), x2 = first(3, 1), y2 = first(4, 2), x1 = first(5, 1);
    return { x: (x1 + x2) / 2, y: (y1 + y2) / 2, z: 0 };
  }
  return null;
}

// ---- world geometry (gen_zone_greybox.js constants) ---------------------------
const rooms = [
  { name: 'SPAWN PLAZA', zone: 'start_zone', x1: -1056, x2: 1094.5, y1: -1073.5, y2: 928 },
  { name: 'UNDERCITY MARKET', zone: 'market_zone', x1: -2481, x2: -1281, y1: 200, y2: 1600 },
  { name: 'SERVICE ALLEY', zone: 'alley_zone', x1: 1319.5, x2: 2519.5, y1: 200, y2: 1600 },
  { name: 'CORPORATE PLAZA', zone: 'corp_zone', x1: -781, x2: 819, y1: 1148, y2: 2748 },
  { name: 'SERVER VAULT', zone: 'vault_zone', x1: 1119, x2: 2319, y1: 2200, y2: 3400 },
  { name: 'ROOFTOP HELIPAD', zone: 'roof_zone', x1: -2319, x2: -1119, y1: 2200, y2: 3400 },
  { name: 'SUBTERRANEAN LAB', zone: 'lab_zone', x1: -781, x2: 819, y1: 3048, y2: 4248 },
];
const corridors = [
  { x1: -1281, x2: -1056, y1: 400, y2: 656 },
  { x1: 1094.5, x2: 1319.5, y1: 400, y2: 656 },
  { x1: -1281, x2: -781, y1: 1200, y2: 1456 },
  { x1: 819, x2: 1319.5, y1: 1200, y2: 1456 },
  { x1: 819, x2: 1119, y1: 2300, y2: 2556 },
  { x1: -1119, x2: -781, y1: 2300, y2: 2556 },
  { x1: 819, x2: 1119, y1: 3100, y2: 3356 },
  { x1: -1119, x2: -781, y1: 3100, y2: 3356 },
];
const obstacles = [
  { label: 'debris', x1: -81, x2: 119, y1: -172, y2: 28 },
  { label: 'fountain', x1: -131, x2: 169, y1: 1798, y2: 2098 },
  { label: '', x1: -481, x2: -61, y1: 1448, y2: 1468 },
  { label: '', x1: 99, x2: 519, y1: 1598, y2: 1618 },
  { label: 'stalls', x1: -2181, x2: -2021, y1: 850, y2: 950 },
  { label: '', x1: -1961, x2: -1801, y1: 850, y2: 950 },
  { label: '', x1: -1741, x2: -1581, y1: 850, y2: 950 },
  { label: 'obstacle', x1: -1847, x2: -1591, y1: 2672, y2: 2928 },
];

// ---- projection ---------------------------------------------------------------
const W = { x1: -2561, x2: 2600, y1: -1154, y2: 4330 };
const S = 0.22;
const PX = (x) => (x - W.x1) * S + 10;
const PY = (y) => (W.y2 - y) * S + 10;
const width = Math.ceil((W.x2 - W.x1) * S) + 20;
const height = Math.ceil((W.y2 - W.y1) * S) + 20 + 250; // + legend space

// ---- entity classification -----------------------------------------------------
const PERK_BY_MODEL = {
  vending_revive_struct: 'QR', vending_juggernaut_struct: 'JUG',
  vending_sleight_struct: 'SPD', vending_doubletap_struct: 'DT2',
  vending_marathon_struct: 'STM', vending_additionalprimaryweapon_struct: 'MULE',
};
const PERK_BY_SPECIALTY = {
  specialty_deadshot: 'DSHOT', specialty_widowswine: 'WIDOW',
  specialty_electriccherry: 'PHD',
};
const GUN_NAME = {
  ar_accurate: 'ICR-1', shotgun_fullauto: 'Haymaker 12', sniper_fastsemi: 'Drakon (Intervention slot)',
  ar_marksman: 'Sheiva (M14 EBR slot)', bowie_knife: 'Bowie Knife', frag_grenade: 'Frag (EMP slot)',
};

const markers = []; // {x,y,sym,color,label}
function add(e, sym, color, label) {
  const o = origin(e); if (!o) return;
  markers.push({ x: o.x, y: o.y, sym, color, label });
}

for (const e of ents) {
  const model = (e.model || '').split('/').pop().replace('.map', '');
  if (e.classname === 'misc_prefab' && PERK_BY_MODEL[model]) add(e, 'P', '#e64a9c', PERK_BY_MODEL[model]);
  else if (e.targetname === 'zm_perk_machine' && PERK_BY_SPECIALTY[e.script_noteworthy]) add(e, 'P', '#e64a9c', PERK_BY_SPECIALTY[e.script_noteworthy]);
  else if (model === 'vending_weapon_upgrade_spawnable') add(e, 'PaP', '#b14ae6', 'Pack-a-Punch');
  else if ((e.targetname === 'weapon_upgrade' || e.targetname === 'bowie_upgrade') && e.zombie_weapon_upgrade) add(e, 'W', '#3fa7ff', GUN_NAME[e.zombie_weapon_upgrade] || e.zombie_weapon_upgrade);
  else if (e.targetname === 'treasure_chest_use') add(e, 'B', '#ffb02e', 'Mystery Box (' + e.script_noteworthy.replace('acc_box_', '') + ')');
  else if (model === 'power_switch') add(e, 'PWR', '#ffe34a', 'Power Switch ' + (e.script_string || ''));
  else if (e.targetname === 'zombie_door') add(e, 'D', '#7dd84a', 'Door [' + e.zombie_cost + '] ' + e.script_flag);
  else if (e.targetname === 'acc_cyberware_kiosk') add(e, 'CW', '#4adft'.length ? '#4ae6c8' : '', 'Cyberware Kiosk');
  else if (e.targetname === 'acc_overclock_terminal') add(e, 'OC', '#4ae6c8', 'Overclock Terminal');
  else if (e.targetname === 'acc_hack_terminal') add(e, 'HK', '#4ae6c8', 'Hack Terminal');
  else if (e.targetname === 'acc_overload_terminal') add(e, 'OV', '#4ae6c8', 'Vault Overload');
  else if (e.targetname === 'acc_power_corp' || e.targetname === 'acc_power_vault') add(e, 'ED', '#ffe34a', 'Emergency Drop (' + e.targetname.replace('acc_power_', '') + ')');
  else if (e.targetname === 'acc_boss_spawn') add(e, 'BOSS', '#ff4a4a', 'Subroutine Core spawn');
  else if (e.targetname === 'acc_pap_block_server' || e.targetname === 'acc_pap_block_roof') { /* brush ent, no origin */ }
  else if (e.targetname === 'initial_spawn_points') add(e, 's', '#ffffff', null);
  else if (e.script_noteworthy === 'riser_location') add(e, 'z', '#8a5a44', null);
  else if (model === 'barricade_reciever_wood') add(e, 'BAR', '#c8c8c8', 'Window Barricade');
}

// PaP blockers (brush entities - draw at known corridor spots)
const papBlocks = [
  { x: 1048, y: 3228, label: 'PaP blocker (server side)' },
  { x: -1048, y: 3228, label: 'PaP blocker (roof side)' },
];

// ---- emit SVG -------------------------------------------------------------------
const svg = [];
svg.push(`<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" font-family="Consolas, monospace">`);
svg.push(`<rect width="${width}" height="${height}" fill="#101418"/>`);
svg.push(`<text x="${width / 2}" y="28" fill="#e8e8e8" font-size="20" text-anchor="middle" font-weight="bold">ABANDONED CYBER CITY - zone + gameplay layout (generated from zm_abandoned_cyber_city.map)</text>`);

for (const c of corridors) {
  svg.push(`<rect x="${PX(c.x1)}" y="${PY(c.y2)}" width="${(c.x2 - c.x1) * S}" height="${(c.y2 - c.y1) * S}" fill="#1d2832" stroke="#3a4a58" stroke-width="1"/>`);
}
for (const r of rooms) {
  svg.push(`<rect x="${PX(r.x1)}" y="${PY(r.y2)}" width="${(r.x2 - r.x1) * S}" height="${(r.y2 - r.y1) * S}" fill="#16202a" stroke="#54a0d8" stroke-width="2"/>`);
  svg.push(`<text x="${PX((r.x1 + r.x2) / 2)}" y="${PY(r.y2) + 18}" fill="#54a0d8" font-size="13" text-anchor="middle" font-weight="bold">${r.name}</text>`);
  svg.push(`<text x="${PX((r.x1 + r.x2) / 2)}" y="${PY(r.y2) + 30}" fill="#3a5468" font-size="9" text-anchor="middle">${r.zone}</text>`);
}
for (const o of obstacles) {
  svg.push(`<rect x="${PX(o.x1)}" y="${PY(o.y2)}" width="${(o.x2 - o.x1) * S}" height="${(o.y2 - o.y1) * S}" fill="#2a3642"/>`);
}
for (const b of papBlocks) {
  svg.push(`<rect x="${PX(b.x) - 4}" y="${PY(b.y) - 12}" width="8" height="24" fill="#ff8c4a" opacity="0.9"/>`);
}

// small markers first (risers/spawns), labeled markers after
for (const m of markers.filter(m => !m.label)) {
  svg.push(`<circle cx="${PX(m.x)}" cy="${PY(m.y)}" r="${m.sym === 's' ? 3 : 2.5}" fill="${m.sym === 's' ? '#ffffff' : '#8a5a44'}" opacity="0.8"/>`);
}
const labeled = markers.filter(m => m.label);
for (const m of labeled) {
  const x = PX(m.x), y = PY(m.y);
  svg.push(`<circle cx="${x}" cy="${y}" r="8" fill="${m.color}" stroke="#000" stroke-width="1"/>`);
  svg.push(`<text x="${x}" y="${y + 3}" fill="#000" font-size="7" text-anchor="middle" font-weight="bold">${m.sym}</text>`);
}

// inline labels: anchor away from the containing room's center; stagger
// vertically when markers share a row (the Lab perk line).
function roomCenterX(m) {
  for (const r of rooms) {
    if (m.x >= r.x1 && m.x <= r.x2 && m.y >= r.y1 && m.y <= r.y2) return (r.x1 + r.x2) / 2;
  }
  return W.x1 + (W.x2 - W.x1) / 2;
}
const rowSeen = {};
for (const m of labeled) {
  const x = PX(m.x), y = PY(m.y);
  if (m.sym === 'P') {
    // perk row: short label UNDER the marker, alternating two depths
    const key = Math.round(y / 20);
    rowSeen[key] = (rowSeen[key] || 0) + 1;
    const dy = 16 + (rowSeen[key] % 2) * 11;
    svg.push(`<text x="${x}" y="${y + dy}" fill="#cfd8e0" font-size="8.5" text-anchor="middle">${m.label}</text>`);
    continue;
  }
  let anchor = m.x < roomCenterX(m) ? 'end' : 'start';
  if (PX(m.x) > width - 150) anchor = 'end';      // don't clip the canvas edge
  if (PX(m.x) < 150) anchor = 'start';
  const dx = anchor === 'start' ? 11 : -11;
  svg.push(`<text x="${x + dx}" y="${y + 3}" fill="#cfd8e0" font-size="8.5" text-anchor="${anchor}">${m.label}</text>`);
}

// legend
const legendY = height - 235;
svg.push(`<rect x="10" y="${legendY}" width="${width - 20}" height="225" fill="#161c22" stroke="#3a4a58"/>`);
const L = [
  ['#e64a9c', 'P', 'Perk machine (9: QR/Jug/Speed/DT2/Stamin/Mule in Lab row + Deadshot + Widow’s Wine + PhD Flopper)'],
  ['#b14ae6', 'PaP', 'Pack-a-Punch (Lab; approach blocked per run on one side - orange bars)'],
  ['#3fa7ff', 'W', 'Wallbuy (ICR-1 + Sheiva in Corp, Haymaker in Alley, Drakon on Roof, Frag in Vault, Bowie in Lab)'],
  ['#ffb02e', 'B', 'Mystery Box location (Market / Corp / Roof - initial rolled per run)'],
  ['#7dd84a', 'D', 'Buyable door [cost] - flag opens the zone behind it'],
  ['#ffe34a', 'PWR/ED', 'Power switch (Corp + Vault, one live per run) / Emergency Drop trigger'],
  ['#4ae6c8', 'CW/OC/HK/OV', 'Cyberware Kiosk + Overclock Terminal (Lab) / Hack Terminal (Corp) / Vault Overload'],
  ['#ff4a4a', 'BOSS', 'Subroutine Core spawn (Lab, r30+) - mini-boss roams from r10/r20'],
  ['#ffffff', 's / z', 'white = player spawns - brown = zombie risers (4 per zone + dog spot)'],
];
L.forEach((row, i) => {
  const y = legendY + 22 + i * 22;
  svg.push(`<circle cx="28" cy="${y - 3}" r="7" fill="${row[0]}" stroke="#000"/>`);
  svg.push(`<text x="28" y="${y}" fill="#000" font-size="6.5" text-anchor="middle" font-weight="bold">${row[1].split('/')[0]}</text>`);
  svg.push(`<text x="44" y="${y}" fill="#cfd8e0" font-size="11">${row[2]}</text>`);
});

svg.push('</svg>');
fs.writeFileSync(outPath, svg.join('\n'));
console.log(`wrote ${outPath} (${width}x${height}, ${markers.length} markers, ${labeled.length} labeled)`);
