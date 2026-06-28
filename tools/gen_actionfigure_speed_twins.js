#!/usr/bin/env node
// gen_actionfigure_speed_twins.js - clone the t8_melee_figure GDT entry into faster "speed twin" weapons for
// the Action Figure's per-PaP-tier SWING-SPEED system (user 2026-06-27).
//
// WHY meleeTime (not fireTime): the Action Figure is a MELEE weapon (`fireType "Melee"`), so the engine
// IGNORES fireTime and gates the swing on the MELEE timing - meleeTime (swing duration) + meleeChargeDelay
// (wind-up) + meleeChargeTime. There is no runtime swing-speed setter, so each PaP tier swaps the held figure
// to a pre-baked faster twin (mirrors the gun "fastfire" twins, but on melee timing). Verified live: scaling
// these 3 fields made the swing visibly faster; fireTime did nothing.
//
// SPEED PER TIER (additive, user 2026-06-27 "33%"): T1 +33% (1.33x), T2 +66% (1.66x), T3 +99% (1.99x).
// Each twin's melee timings = base / mult. Edit TIERS below + re-run to retune.
//
// Re-runnable: strips any prior _fast* clones first, then re-clones from the (normal-speed) base entry. Run
// `gdtdb.exe /update` AFTER (the linker won't), then add weaponfull,<twin> zone lines + the swap in
// _acc_pap_levels::acc_pap_actionfigure. Usage: node tools/gen_actionfigure_speed_twins.js <path-to.gdt>
'use strict';
const fs = require('fs');
const GDT = process.argv[2];
if (!GDT) { console.error('usage: gen_actionfigure_speed_twins.js <wpn_t8_melee_actionfigure.gdt>'); process.exit(1); }

const BASE = 't8_melee_figure';
const BASE_MELEE_TIME = 0.65, BASE_CHARGE_DELAY = 0.16, BASE_CHARGE_TIME = 0.2;   // the base entry's normal-speed values
const TIERS = [
  { name: BASE + '_fast1', mult: 1.33 },   // PaP tier 1: +33%
  { name: BASE + '_fast2', mult: 1.66 },   // PaP tier 2: +66%
  { name: BASE + '_fast3', mult: 1.99 },   // PaP tier 3: +99%
];

let lines = fs.readFileSync(GDT, 'utf8').split('\n');

function blockEnd(openBraceIdx) {   // idx of the matching close brace for the `{` at openBraceIdx
  let depth = 0;
  for (let j = openBraceIdx; j < lines.length; j++) {
    depth += (lines[j].match(/{/g) || []).length - (lines[j].match(/}/g) || []).length;
    if (depth === 0) return j;
  }
  return -1;
}

// strip any prior _fast* clone entries (clean re-run)
for (;;) {
  const h = lines.findIndex(l => /"t8_melee_figure_fast\d" \( "bulletweapon\.gdf" \)/.test(l));
  if (h < 0) break;
  let i = h + 1; while (lines[i].trim() !== '{') i++;
  lines.splice(h, blockEnd(i) - h + 1);
}

// extract the base entry block (header + its brace block)
const hdr = lines.findIndex(l => l.includes(`"${BASE}" ( "bulletweapon.gdf" )`));
if (hdr < 0) { console.error(`ERROR: base entry "${BASE}" not found`); process.exit(2); }
let bi = hdr + 1; while (lines[bi].trim() !== '{') bi++;
const block = lines.slice(hdr, blockEnd(bi) + 1);

// build the clones
const clones = [];
for (const t of TIERS) {
  const f = 1 / t.mult;
  const mt = (BASE_MELEE_TIME * f).toFixed(4);
  const cd = (BASE_CHARGE_DELAY * f).toFixed(4);
  const ct = (BASE_CHARGE_TIME * f).toFixed(4);
  clones.push(...block.map(l => l
    .replace(`"${BASE}" ( "bulletweapon.gdf" )`, `"${t.name}" ( "bulletweapon.gdf" )`)
    .replace('"meleeTime" "0.65"', `"meleeTime" "${mt}"`)
    .replace('"meleeChargeDelay" "0.16"', `"meleeChargeDelay" "${cd}"`)
    .replace('"meleeChargeTime" "0.2"', `"meleeChargeTime" "${ct}"`)));
  console.log(`  ${t.name}: ${t.mult}x -> meleeTime ${mt}  (chargeDelay ${cd}, chargeTime ${ct})`);
}

// insert the clones just before the file's final closing brace
let close = lines.length - 1; while (close > 0 && lines[close].trim() !== '}') close--;
fs.writeFileSync(GDT, [...lines.slice(0, close), ...clones, ...lines.slice(close)].join('\n'));
console.log(`wrote ${TIERS.length} speed twins (${block.length} lines each). Now run gdtdb /update + add zone lines + the swap.`);
