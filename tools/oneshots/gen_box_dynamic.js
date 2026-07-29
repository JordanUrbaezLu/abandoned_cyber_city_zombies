#!/usr/bin/env node
// =============================================================================
// gen_box_dynamic.js - CURATED "dynamic" mystery-box odds + PaP price tiers.
//
// Supersedes compute_gun_tiers.js's SCORE-tercile box/price emission for these two
// functions (user 2026-07-05): the box no longer uses 6 discrete weight tiers. Instead
// every weapon sits on a hand-curated power RANKING and a SMOOTH geometric weight curve
// - best (rank 1) = rarest pull, probability climbs gently to the worst (rank N) = commonest.
//
//   - RARE FIXED-% entries (user 2026-07-09): the 4 wonder weapons (Thundergun / Blast-O-Matic /
//     Fire Bow / Leviathan Axe) pin at 0.3%/open, Action Figure 0.8%, Havoc 1.2% - solved into
//     weights against the gun-curve total, so they hold exactly as the curve is retuned.
//   - Guns use an 11%/step geometric curve (steepened 2026-07-09 - the top guns were too common).
//   - PaP price tier by RANK BAND + per-gun user overrides carried in RANK (so a regen
//     reproduces the LIVE pap_price_bucket, incl. the WONDER premium tier).
//
// The box draw first does a FIXED tactical pre-roll (Monkey Bomb 1.0% + Li'l Arnie 0.5%
// via acc_box_tactical_preroll); the remaining 98.5% is this weighted gun pick. So the
// printed per-open % = weight/total x 0.985; the whole distribution sums to 100%.
//
// EDIT the RANK below (reorder / add / retune the curve), then:  node tools/gen_box_dynamic.js
// Paste the two emitted functions into their GSC files (between the BEGIN/END markers) and
// rebuild GSC-only. NOTE: box name = exact box-pool entry (acc_box_weight n=="..."); key =
// the IsSubStr substring for pap_price_bucket (covers base + _up + twins).
//
// GALIL->GRAV: the Galil slot uses key `t6_galil`. If the CW-Grav migration RENAMES the
// weapon key, change `t6_galil` here (+ box pool + CSV) to the new key and re-emit.
// =============================================================================
'use strict';

// rank order (best/rarest -> worst/commonest). d=display, box=acc_box_weight name, key=IsSubStr, sp=special
// APEX MIGRATION 2026-07-06: -Chicom -Paladin -China Lake -Klauser; +Peacekeeper +Havoc +Alternator +Prowler +G7 Scout.
// Ordered best/rarest -> worst/commonest by papScore/tier (compute_gun_tiers).
//
// pct: FIXED per-open % target (solved into a weight AFTER the gun curve totals). Used for the
//      4 wonder weapons (0.3% each, user 2026-07-09; was flat ~0.41%), the Action Figure (0.8%),
//      and the Havoc (1.2%, user 2026-07-09; was riding the gun curve at ~2.36%).
// price: MANUAL price-band override (user-curated, matches the live pap_price_bucket - keeps a
//      regen from clobbering the 2026-07-06/07 per-gun overrides; WONDER = the premium PaP tier).
// FIRE BOW + LEVIATHAN AXE added to the roster 2026-07-09 (they were live in GSC but missing here,
// so a regen would have DROPPED their box weights).
const RANK = [
  { d: 'Thundergun',    box: 'thundergun',          key: 'thundergun',          sp: true, pct: 0.3, price: 'WONDER' },
  { d: 'Blast-O-Matic', box: 't9_semiauto_cosplay', key: 't9_semiauto_cosplay', sp: true, pct: 0.3, price: 'WONDER' },
  { d: 'Fire Bow',      box: 'elemental_bow_demongate', key: 'elemental_bow_demongate', sp: true, pct: 0.3, price: 'WONDER' },   // HB21 demongate
  { d: 'Leviathan Axe', box: 'leviathan',           key: 'leviathan',           sp: true, pct: 0.3, price: 'WONDER' },   // WetEgg GoW melee
  { d: 'Action Figure', box: 't8_melee_figure',     key: 't8_melee_figure',     sp: true, pct: 0.8 },
  // 2026-07-09 BOX-ODDS SWAPS (user): XM4<->M60, Peacekeeper<->PPSH, CEL-3<->AK-74u, MK14<->Grav,
  // Olympia<->Five-Seven - pure rarity trades (each pair exchanged RANK slots). Price overrides pin
  // every swapped gun to its pre-swap PaP tier where the band would have moved (only AK-74u needed one).
  { d: 'XM4',           box: 't9_xm4',              key: 't9_xm4' },   // swapped with M60 2026-07-09 (rarer)
  { d: 'Peacekeeper',   box: 'apex_peacekeeper', key: 'apex_peacekeeper' },   // Apex - S, top shotgun (power-first); swapped with PPSH 2026-07-09 (rarer)
  { d: 'AK-47',         box: 't9_ak47',             key: 't9_ak47' },
  { d: 'M60',           box: 't9_m60',              key: 't9_m60' },   // swapped with XM4 2026-07-09 (commoner)
  { d: 'PPSH-41',       box: 's4_ppsh41_base',      key: 's4_ppsh41' },   // swapped with Peacekeeper 2026-07-09 (commoner)
  { d: 'Havoc',    box: 'apex_beam_rifle',  key: 'apex_beam_rifle',     sp: true, pct: 1.2 },   // Apex energy special (A), replaces China Lake
  { d: 'Mahem',         box: 's1_mahem',            key: 's1_mahem',            sp: true },
  { d: 'War Machine',   box: 't6_war_machine',      key: 't6_war_machine',      sp: true },   // BO2 drum GL (user 2026-07-09) - A-tier explosive special, one step commoner than the Mahem; band cutoffs +1 below so every existing gun keeps its tier
  // (L4 Siege / launcher_multi entry REMOVED 2026-07-26 with the gun itself.)
  { d: 'EPG-1',         box: 's1_mdl',              key: 's1_mdl',              sp: true },   // AW MDL plasma-lobber reskin (user 2026-07-25) - explosive special, TOP-priced
  { d: 'MORS',          box: 's1_mors',             key: 's1_mors' },
  { d: 'Alternator',    box: 'apex_alternator',  key: 'apex_alternator', price: 'BOT' },   // Apex - A+ PaP (trash base); BOT cost = intentional cheap-to-PaP payoff gun (user 2026-07-06)
  { d: 'AE4',           box: 's1_ae4',              key: 's1_ae4' },
  { d: 'RW1',           box: 's1_rw1',              key: 's1_rw1' },
  { d: 'CEL-3',         box: 's1_cel3',             key: 's1_cel3', price: 'TOP' },   // user 2026-07-07 BOT->TOP; swapped with AK-74u 2026-07-09 (rarer)
  { d: 'Triple Take',   box: 'apex_tripletake',     key: 'apex_tripletake', price: 'MID' },   // Apex tri-bolt energy sniper (user 2026-07-11): B tier, took the retired M16's EXACT slot (#19, MID price, weight 182) - Nuclear Energy synergy gun.
  { d: 'MK14',          box: 's1_mk14',             key: 's1_mk14', price: 'BOT' },   // user 2026-07-11 MID->BOT (3000/4500/6000 cheapest PaP); box rarity unchanged. Prior: 2026-07-07 BOT->MID; swapped with Grav 2026-07-09
  { d: 'Tac-19',        box: 's1_tac19',            key: 's1_tac19' },   // demoted S -> A-
  { d: 'AK-74u',        box: 't9_ak74u',            key: 't9_ak74u', price: 'MID' },   // swapped with Prowler 2026-07-10 (now #21, rarer); price PINNED MID (2026-07-09 CEL-3 swap; rank-21 band is MID anyway)
  { d: 'Prowler',       box: 'apex_prowler',     key: 'apex_prowler', price: 'BOT' },   // Apex - B SMG; user 2026-07-07 MID->BOT; swapped with AK-74u 2026-07-10 (now #22, commoner)
  { d: 'Streetsweeper', box: 't9_streetsweeper',    key: 't9_streetsweeper' },   // demoted A -> B
  { d: 'HAMR',          box: 't6_hamr',             key: 't6_hamr', price: 'MID' },   // BO2 LMG (user 2026-07-10): B tier, sits between the M60 (S) and RPD (C) - one notch RARER than the RPD (it's the better LMG); MID PaP price like the RPD
  { d: 'RPD',           box: 't9_rpd',              key: 't9_rpd', price: 'MID' },   // user 2026-07-07 BOT->MID
  { d: 'Olympia',       box: 't6_olympia',          key: 't6_olympia' },   // swapped with Five-Seven 2026-07-09 (rarer)
  { d: 'Grav',          box: 't9_grav',             key: 't9_grav', price: 'BOT' },   // user 2026-07-07 MID->BOT; swapped with MK14 2026-07-09 (commoner)
  { d: 'Five-Seven',    box: 't6_fiveseven',        key: 't6_fiveseven' },   // swapped with Olympia 2026-07-09 (commonest)
];

// ---- curve: BAND-TARGET (user 2026-07-16 - box odds ~16% top / 36% mid / 48% bad OF THE CONVENTIONAL-GUN
//      POOL). REPLACES the pinned-top mid-hump. The conventional guns are split by PRICE TIER into three
//      weight budgets (TOP = rank<=TOP_MAX, MID = <=MID_MAX, BOT = rest), each band a gentle rising geometric
//      (rarer -> commoner within the band). Bad guns stay the commonest tier but far less dominant than the
//      old geometric curve (was ~58%). The conventional pool is held at CONV_TOTAL so the specials keep their
//      prior %; as RAW per-open odds that 16/36/48 reads ~15% / 34% / 45% (wonders/specials take ~6.5%).
const BAND_TOP = 0.16, BAND_MID = 0.36, BAND_BAD = 0.48;   // conventional-pool split top/mid/bad
const G_TOP = 1.11, G_MID = 1.02, G_BAD = 1.03;            // intra-band gradients (gentle rise within each band)
const CONV_TOTAL = 4741;            // conventional pool total, held constant (grand pool stays 4993)
const GUN_SHARE = 0.985;            // 98.5% after the tactical pre-roll
const GUN_W0 = 245;                 // default acc_box_weight for an unknown/undefined gun (mid-band). (2026-07-25: define restored - the GSC-emit path referenced an undefined GUN_W0 and crashed; 245 matches the shipped default.)

// A gentle rising geometric of `n` weights summing to `budget`.
function bandCurve( n, budget, g ) {
  const raw = Array.from( { length: n }, ( _, j ) => Math.pow( g, j ) );
  const rs = raw.reduce( ( a, b ) => a + b, 0 );
  return raw.map( x => Math.round( x / rs * budget ) );
}
// Conventional weights, split by price-tier band into the 16/36/48 budgets. `ranks` = the conventional guns'
// ranks in order, so band membership tracks TOP_MAX/MID_MAX (defined below; in scope by the time this is called).
function convWeights( ranks ) {
  const nTop = ranks.filter( r => r <= TOP_MAX ).length;
  const nMid = ranks.filter( r => r > TOP_MAX && r <= MID_MAX ).length;
  const nBad = ranks.length - nTop - nMid;
  const w = [
    ...bandCurve( nTop, BAND_TOP * CONV_TOTAL, G_TOP ),
    ...bandCurve( nMid, BAND_MID * CONV_TOTAL, G_MID ),
    ...bandCurve( nBad, BAND_BAD * CONV_TOTAL, G_BAD ),
  ];
  w[ w.length - 1 ] += CONV_TOTAL - w.reduce( ( a, b ) => a + b, 0 );   // nudge the commonest gun so the pool hits CONV_TOTAL exactly
  return w;
}

// ---- price bands (by rank) ----------------------------------------------------
const TOP_MAX = 16;   // ranks 1-16  -> TOP (wonders + AF + S guns + Havoc/Mahem/War Machine/L4 Siege/EPG-1 + MORS); L4 Siege + EPG-1 added 2026-07-25, both cutoffs +2 so every pre-existing gun keeps its band
const MID_MAX = 23;   // ranks 17-23 -> MID (Alternator/AE4/RW1/AK-74u/Grav/Tac-19/Prowler);  24+ -> BOT
const priceOf = (rank) => rank <= TOP_MAX ? 'TOP' : rank <= MID_MAX ? 'MID' : 'BOT';
const COSTS = { WONDER: '10000 / 15000 / 20000', TOP: '5000 / 7500 / 10000', MID: '4000 / 6000 / 8000', BOT: '3000 / 4500 / 6000' };

// ---- compute weights + odds ---------------------------------------------------
// Curve entries first (positional geometric curve over the non-pct entries), then solve the
// pct-fixed entries against the curve total:  f_i = pct_i / (GUN_SHARE*100) is the fraction of
// the whole pool entry i must own, so total T = C / (1 - sum(f_i)) and w_i = f_i * T.
RANK.forEach( ( r, i ) => { r.rank = i + 1; } );   // assign ranks first - convWeights needs them for band membership
const CONV_W = convWeights( RANK.filter( r => r.pct === undefined ).map( r => r.rank ) );
let gunIdx = 0;
RANK.forEach((r) => {
  if (r.pct === undefined) { r.w = CONV_W[ gunIdx ]; gunIdx++; }
  r.price = r.price || priceOf(r.rank);
});
const curveTotal = RANK.filter(r => r.pct === undefined).reduce((a, b) => a + b.w, 0);
const fixedFrac  = RANK.filter(r => r.pct !== undefined).reduce((a, r) => a + r.pct / (GUN_SHARE * 100), 0);
const solvedT    = curveTotal / (1 - fixedFrac);
RANK.filter(r => r.pct !== undefined).forEach(r => { r.w = Math.max(1, Math.round(r.pct / (GUN_SHARE * 100) * solvedT)); });
const total = RANK.reduce((a, b) => a + b.w, 0);
const FIRST_CURVE_RANK = RANK.findIndex(r => r.pct === undefined) + 1;   // best conventional gun's rank (for the doc)
RANK.forEach(r => r.pct = r.w / total * GUN_SHARE * 100);

// ---- emit GSC: acc_box_weight -------------------------------------------------
function gscBox() {
  const L = [
    'function acc_box_weight( wpn )',
    '{',
    '    if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) return ' + GUN_W0 + ';   // default = a mid gun',
    '    n = wpn.name;',
  ];
  for (const r of RANK)
    L.push(`    if ( n == "${r.box}" )${' '.repeat(Math.max(1, 22 - r.box.length))}return ${r.w};   // ${r.pct.toFixed(2)}% - #${r.rank} ${r.d}`);
  L.push('    return ' + GUN_W0 + ';   // unknown -> a mid gun');
  L.push('}');
  return L.join('\n');
}

// ---- emit GSC: pap_price_bucket -----------------------------------------------
function gscPap() {
  const L = ['function pap_price_bucket( weapon_name )', '{', '    if ( !isdefined( weapon_name ) ) return "BOT";', ''];
  for (const tier of ['WONDER', 'TOP', 'MID', 'BOT']) {
    L.push(`    // ${tier}  (${COSTS[tier]})`);
    for (const r of RANK.filter(r => r.price === tier))
      L.push(`    if ( IsSubStr( weapon_name, "${r.key}" ) )${' '.repeat(Math.max(1, 22 - r.key.length))}return "${tier}";   // #${r.rank} ${r.d}${r.sp ? ' (special)' : ''}`);
    L.push('');
  }
  L.push('    return "BOT";   // default: cheapest tier');
  L.push('}');
  return L.join('\n');
}

// ---- emit docs/54 ---------------------------------------------------------------
// (2026-07-09: this script now OWNS docs/54 - the old compute_gun_tiers.js emission was
// stale since the 2026-07-05 dynamic-curve switch and never reflected the WONDER tier.)
function doc54() {
  const L = [
    '# 54 - Pack-a-Punch Pricing & Mystery-Box Odds',
    '',
    '> **GENERATED FILE - do NOT hand-edit.** Regenerate with `node tools/oneshots/gen_box_dynamic.js`',
    '> after adding/removing/retuning any gun (it prints the two GSC functions to paste AND',
    '> rewrites this doc). Source of truth: [tools/gen_box_dynamic.js](../tools/gen_box_dynamic.js)',
    '> (supersedes `compute_gun_tiers.js` for pricing/odds since 2026-07-05).',
    '> Consumers: `_acc_pap_levels.gsc` (`pap_price_bucket`/`tier_cost`) + `_acc_map_randomizer.gsc` (`acc_box_weight`).',
    '',
    '## The rule',
    '',
    'Every box entry sits on a hand-curated power RANKING (best -> worst). A gun\'s PaP cost and its',
    'box rarity both scale with that rank - you pay more to upgrade a stronger gun, and you roll it',
    'less often.',
    '',
    '- **Rare specials are FIXED per-open % targets** (user 2026-07-09): the 4 wonder weapons',
    '  (Thundergun / Blast-O-Matic / Fire Bow / Leviathan Axe) pin at **0.3%**, the Action Figure at',
    '  **0.8%**, the Havoc at **1.2%**. Their weights are solved against the gun-curve total.',
    '- **Conventional guns are split by price tier into 16/36/48 weight budgets** (user 2026-07-16): top guns',
    '  (ranks ' + FIRST_CURVE_RANK + '-14) take 16% of the conventional pool, mid = 36%, bad (bottom) = 48% - each a gentle rise.',
    '  Bad guns stay the commonest tier but far less dominant than the old geometric curve (was ~58%).',
    '- **PaP price tier by rank band** (+ per-gun user overrides, carried in the RANK table).',
    '- The box draw first runs the FIXED tactical pre-roll (**Monkey Bomb 1.0% + Li\'l Arnie 0.5%**);',
    '  the remaining 98.5% is the weighted gun pick, so per-open % = weight/total x 0.985.',
    '- The box never repeats a gun you own -> live odds re-normalize as you collect.',
    '',
    '| Price tier | PaP cost T1 / T2 / T3 | Cumulative |',
    '|---|---|--:|',
    '| **WONDER** | 10000 / 15000 / 20000 | 45,000 |',
    '| **TOP** | 5000 / 7500 / 10000 | 22,500 |',
    '| **MID** | 4000 / 6000 / 8000 | 18,000 |',
    '| **BOT** | 3000 / 4500 / 6000 | 13,500 |',
    '',
    '## Current ranking (' + RANK.length + ' box entries, pool total weight ' + total + ')',
    '',
    '| Rank | Weapon | Price tier | PaP cost T1/T2/T3 | Box weight | Per-open % |',
    '|--:|---|:--:|---|--:|--:|',
  ];
  for (const r of RANK)
    L.push(`| ${r.rank} | **${r.d}**${r.sp ? ' (special)' : ''} | **${r.price}** | ${COSTS[r.price]} | ${r.w} | ${r.pct.toFixed(2)}% |`);
  L.push('| - | Monkey Bomb (tactical pre-roll) | - | - | - | 1.00% |');
  L.push('| - | Li\'l Arnie (tactical pre-roll) | - | - | - | 0.50% |');
  L.push('');
  L.push('Lucky Horseshoe (Clover) box luck layers OVER these weights at draw time');
  L.push('(`acc_box_clover_weight`: rares +' + 16 + ' weight ~= +0.4%/open each, funded from the commons).');
  L.push('');
  return L.join('\n') + '\n';
}

// ---- output -------------------------------------------------------------------
console.log('CURATED DYNAMIC BOX ODDS + PaP PRICE BANDS  (pool total weight ' + total + ', conventional guns = 16/36/48 band-target)\n');
console.log('Rk  Weapon           Price   BoxWt   Per-open %');
let sum = 0;
for (const r of RANK) { sum += r.pct; console.log(String(r.rank).padStart(2) + '  ' + r.d.padEnd(15) + ' ' + r.price.padEnd(6) + '  ' + String(r.w).padStart(5) + '   ' + r.pct.toFixed(2).padStart(5) + '%'); }
console.log('    Monkey Bomb / Lil Arnie (tactical pre-roll)  1.00% / 0.50%');
console.log('    TOTAL = ' + (sum + 1.5).toFixed(2) + '%');
const fs = require('fs');
const path = require('path');
fs.writeFileSync(path.join(__dirname, '..', '..', 'docs', '33_pap_pricing_tiers.md'), doc54());   // __dirname = tools/oneshots -> repo root is two up
console.log('\n[doc] wrote docs/33_pap_pricing_tiers.md');
console.log('\n// ===== GSC #1: paste into _acc_map_randomizer.gsc (between BEGIN/END GENERATED) =====\n');
console.log(gscBox());
console.log('\n// ===== GSC #2: paste into _acc_pap_levels.gsc (between BEGIN/END GENERATED) =====\n');
console.log(gscPap());
