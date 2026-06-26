// =============================================================================
// compute_gun_tiers.js - THE Pack-a-Punch pricing + mystery-box weight balancer
//                        and doc generator.
//
// WHAT IT DOES (user 2026-06-23):
//   1. Scores every SCOREABLE live gun on its FULLY PACK-A-PUNCHED (PaP T3) form
//      using the multi-factor "v2 sustain" formula from docs/05_weapons.md.
//   2. Ranks the guns best -> worst by that PaP score.
//   3. Splits the ranking into THIRDS (rank terciles): top third = highest PaP
//      cost AND rarest box roll; bottom third = cheapest PaP AND commonest roll.
//      Relative split -> add/remove a gun and the boundaries reshuffle.
//   4. Applies hand OVERRIDES + places non-scoreable SPECIALS (wonder weapon /
//      launcher) + lists EXCLUDED guns with no PaP form.
//   5. GENERATES docs/54_pap_pricing_tiers.md with: the ranking, the PaP price
//      table, the mystery-box odds, AND the two GSC functions to paste:
//        - pap_price_bucket() + tier_cost()  -> _acc_pap_levels.gsc
//        - acc_box_weight()                  -> _acc_map_randomizer.gsc
//
// REBALANCE after adding/removing/retuning a gun: edit the tables below, then
//   node tools/compute_gun_tiers.js
// and paste BOTH regenerated functions into their files. Rebuild GSC-only.
//
// PaP-form stats are GDT-verified (workflow pap-form-gdt-stats, 2026-06-23).
// =============================================================================

const fs = require('fs');
const path = require('path');

const W = { dps: 0.30, mobility: 0.16, sustain: 0.18, pen: 0.14, reserve: 0.14, handling: 0.08 };
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const dpsScore = (e) => clamp(1 + (e - 340) / (664 - 340) * 9, 1, 10);
const mobScore = (mv) => clamp(4 + (mv - 0.80) / (1.00 - 0.80) * 6, 1, 10);
const logLerp = (x, x0, s0, x1, s1) =>
  s0 + (s1 - s0) * (Math.log(x) - Math.log(x0)) / (Math.log(x1) - Math.log(x0));
const sustainScore = (reload, clip) => clamp(logLerp(reload / clip, 0.05, 10, 2.0, 1), 1, 10);
const PEN = { none: 2, small: 4, medium: 7, large: 10 };
const reserveScore = (r) => clamp(logLerp(r, 26, 1.5, 400, 10), 1, 10);
const HAND = { auto: 8, charge: 8, sniper: 6, semi: 5, single_sg: 5 };
function formulaTier(s) { return s >= 7.7 ? 'S' : s >= 6.6 ? 'A' : s >= 5.6 ? 'B' : 'C'; }

const PRICE = {
  TOP: { costs: [5000, 7500, 10000] },
  MID: { costs: [4000, 6000, 8000] },
  BOT: { costs: [3000, 4500, 6000] },
};
// Mystery-box weight by price tier (HIGHER = COMMONER roll, so TOP guns are rarest). Retuned (user 2026-06-25)
// to the target: the 5 S-tier guns = 12% TOTAL, the 5 BOT-tier guns = 50% TOTAL, everything else (5 MID guns +
// the 3 specials) = the remaining ~38%. With TOP 12 / MID 29 / BOT 50 + Thundergun 3, total pool weight =
// 5*12 + 5*29 + 5*50 + 3(TG) + 29(Mahem) + 12(AF) = 499: each S gun 12/499 = 2.4% (5 -> 12.0%), each BOT gun
// 50/499 = 10.0% (5 -> 50.1%), each MID gun 29/499 = 5.8% (5 -> 29.1%), Mahem 5.8%, Action Figure 2.4%,
// Thundergun 0.6%. The per-gun ~% printed below is the GUN-pool internal split (weight/total); multiply by
// 0.985 for the real in-box odds after the fixed Monkey Bomb (1%) + Li'l Arnie (0.5%) pre-roll.
const BOX_WEIGHT = { TOP: 12, MID: 29, BOT: 50 };
const BOX_WW = 3;

// ---- SCOREABLE roster -----------------------------------------------------
// w = IsSubStr key (pap_price_bucket, covers base+_up+twin). bn = EXACT box-pool
// base name for acc_box_weight (== match); defaults to w. effDPS from
// acc_weapon_balance_mult; base stats docs/05; PaP clip/reserve/reload GDT-verified.
// cu = curated per-shot DPS. force = pin price tier. pe = transform DPS bump.
// PaP clip/reserve are the CUT values (reduce_base_ammo 30% cut, re-applied 2026-06-23 after the
// 6-23 GDT regen wiped it; verified by tools/audit_gun_ammo.js). reserve = maxAmmo x clipSize.
const GUNS = [
  // display        weaponKey          class     effDPS clip res reload move pen      hand        cu     pc  pr  prl   transform pe  extra
  { d: 'Tac-19',       w: 's1_tac19',        c: 'Shotgun', e: 552, cl: 3,   rs: 27,  rl: 0.47, mv: 1.00, p: 'large',  h: 'single_sg', cu: true,  pc: 6,   pr: 54,  prl: 0.467, t: 'none', pe: null, boxForce: 10 },   // e 613->552 (-10% dmg nerf, mult 0.68->0.612, user 2026-06-25). S-tier box rarity ~2%; PaP price unchanged
  { d: 'M60',          w: 't9_m60',          c: 'LMG',     e: 580, cl: 100, rs: 400, rl: 9.7,  mv: 0.80, p: 'large',  h: 'auto',      cu: false, pc: 120, pr: 480, prl: 9.7,   t: 'none', pe: null, boxForce: 10 },   // S-tier box rarity ~2% (user 2026-06-25); PaP price unchanged
  { d: 'AK-74u',       w: 't9_ak74u',        c: 'SMG',     e: 518, cl: 20,  rs: 160, rl: 2.8,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 40,  pr: 280, prl: 2.8,   t: 'none', pe: null, boxForce: 29 },   // box rarity pinned to MID (user 2026-06-25); PaP price unchanged
  // Chicom CQB (BO2 t6_chicom_cqb): 3-round-burst SMG, the box's TOP-3 gun (user 2026-06-25). cu single-target/burst
  // (raw within-burst DPS overstates; e = honest ~497 sustained after the 0.1s burst delay, mult 0.25). PaP "Auto Burst"
  // 4-round, clip 56 / reserve 448 UNCUT (NOT in reduce_base_ammo) -> papScore ~8.05 = #2 (just under Tac-19), S+, TOP.
  { d: 'Chicom CQB',   w: 't6_chicom_cqb',   c: 'SMG',     e: 500, cl: 36,  rs: 180, rl: 2.1,  mv: 1.00, p: 'medium', h: 'auto',      cu: true,  pc: 56,  pr: 448, prl: 2.1,   t: 'none', pe: null },
  // Paladin HB50 (BO4 sniper): MOVED low-S -> B (user 2026-06-24). DPS cut e 624->437 (mult 0.70->0.49); clip 8 /
  // reserve 96/132 / reload 4.1 unchanged -> base ~6.14 / papScore ~6.42 (B). MORS is now the S sniper; the Paladin
  // is the cheaper mid-tier one-shot. (Its ACC_PALADIN_BOSS_MULT boss cut is separate and stays.)
  { d: 'Paladin HB50', w: 't8_paladin_hb50', c: 'Sniper',  e: 437, cl: 8,   rs: 96,  rl: 4.1,  mv: 1.00, p: 'large',  h: 'sniper',    cu: true,  pc: 11,  pr: 132, prl: 4.13,  t: 'none', pe: null },
  // PPSH-41 scores S and lands TOP naturally; force keeps it TOP if the roster shrinks.
  { d: 'PPSH-41',      w: 's4_ppsh41',       bn: 's4_ppsh41_base', c: 'SMG', e: 492, cl: 40, rs: 360, rl: 3.5, mv: 1.00, p: 'medium', h: 'auto', cu: false, pc: 54, pr: 486, prl: 3.5, t: 'none', pe: null, force: 'TOP', boxForce: 10 },   // clip/reserve SYNCED to live GDT 40/360 base, 54/486 PaP (was stale 30/270, 44/396); user 2026-06-26. S-tier; force:TOP
  { d: 'AK-47',        w: 't9_ak47',         c: 'AR',      e: 465, cl: 21,  rs: 168, rl: 3.25, mv: 0.95, p: 'medium', h: 'auto',      cu: false, pc: 31,  pr: 279, prl: 3.25,  t: 'none', pe: null },
  { d: 'AE4',          w: 's1_ae4',          c: 'AR',      e: 413, cl: 25,  rs: 200, rl: 2.0,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 38,  pr: 304, prl: 2.0,   t: 'none', pe: null },
  { d: 'ASM1',         w: 's1_asm1',         c: 'SMG',     e: 401, cl: 22,  rs: 132, rl: 2.1,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 36,  pr: 288, prl: 2.1,   t: 'none', pe: null },
  { d: 'Galil',        w: 't6_galil',        c: 'AR',      e: 412, cl: 25,  rs: 225, rl: 2.9,  mv: 0.95, p: 'medium', h: 'auto',      cu: false, pc: 35,  pr: 420, prl: 2.925, t: 'none', pe: null },
  { d: 'Five-Seven',   w: 't6_fiveseven',    c: 'Pistol',  e: 425, cl: 14,  rs: 56,  rl: 1.8,  mv: 1.00, p: 'small',  h: 'semi',      cu: true,  pc: 21,  pr: 147, prl: 1.8,   t: 'none', pe: null },
  { d: 'RPD',          w: 't9_rpd',          c: 'LMG',     e: 337, cl: 75,  rs: 300, rl: 7.5,  mv: 0.80, p: 'large',  h: 'auto',      cu: false, pc: 125, pr: 500, prl: 7.5,   t: 'none', pe: null },   // clip+reserve +25% (60/240->75/300 base, 100/400->125/500 PaP), user 2026-06-26
  // RW1: directed-energy pistol. Hand-tuned to a real magazine (reduce_base_ammo CLIP_FIX/MAXAMMO_FIX:
  // clip 8 base / 12 PaP, reserve 56/96 - ABSOLUTE, exempt from the x0.7 cut) so it EARNS A (user 2026-06-23).
  { d: 'RW1',          w: 's1_rw1',          c: 'Pistol',  e: 590, cl: 8,   rs: 56,  rl: 1.4,  mv: 1.00, p: 'small',  h: 'semi',      cu: false, pc: 12,  pr: 96,  prl: 1.4,   t: 'none', pe: null },
  { d: 'Olympia',      w: 't6_olympia',      c: 'Shotgun', e: 263, cl: 2,   rs: 26,  rl: 3.9,  mv: 1.00, p: 'small',  h: 'single_sg', cu: true,  pc: 2,   pr: 42,  prl: 2.5,   t: 'none', pe: null },   // e 525->263 (-50% dmg nerf, mult 0.9775->0.489, user 2026-06-25 max-scale outlier fix)
  // MK14 (AW s1_mk14): semi-auto DMR, B tier (user 2026-06-24). cu single-target (semi-auto raw DPS overstates).
  // e=400 + PaP clip 12 / reserve 240 -> papScore ~5.99 (B); base 14 / 168 -> ~5.90 (B). Body loc clean (no normalize).
  { d: 'MK14',         w: 's1_mk14',         c: 'DMR',     e: 400, cl: 14,  rs: 168, rl: 2.0,  mv: 0.95, p: 'medium', h: 'semi',      cu: true,  pc: 12,  pr: 240, prl: 2.0,   t: 'none', pe: null, boxForce: 29 },   // box rarity pinned to MID (user 2026-06-25); PaP price unchanged
  // MORS (AW s1_mors): charge-up railgun sniper. cu single-target (one-shot rail). RESERVE CUT 50% (user 2026-06-25):
  // 120/180 -> 60/90 (gameplay ammo nerf, reduce_base_ammo MAXAMMO_FIX). That drops its reserve score, so papScore
  // falls ~7.90 -> ~7.60 (just under the S cutoff). force:'TOP' PINS its PaP price + box weight at TOP so the cut is a
  // pure ammo nerf, NOT a price/rarity demotion (user's "MORS is the S sniper" intent). DPS e 660 / clip 1 / reload 1.2.
  { d: 'MORS',         w: 's1_mors',         c: 'Sniper',  e: 660, cl: 1,   rs: 48,  rl: 1.2,  mv: 1.00, p: 'large',  h: 'sniper',    cu: true,  pc: 1,   pr: 72,  prl: 1.2,   t: 'none', pe: null, force: 'TOP' },   // reserve -20% (60/90->48/72, user 2026-06-26); force:TOP keeps it S/TOP despite the cut
];

// ---- SPECIALS: PaP-able but OUTSIDE the formula. Hand price tier + box weight.
const SPECIALS = [
  { d: 'Thundergun', w: 'thundergun', tier: 'TOP', box: BOX_WW, why: 'wonder weapon (wind-blast, is_limited) - rarest roll of all' },
  { d: 'Mahem',      w: 's1_mahem',   tier: 'MID', box: BOX_WEIGHT.MID, why: 'explosive rocket launcher (projectile, [A] tag, aat-exempt)' },
  { d: 'Action Figure', w: 't8_melee_figure', tier: 'TOP', box: 5, why: 'melee special - PaPs IN PLACE (no _up form), +1 cleave target per tier; S-tier PaP cost (user 2026-06-25). Box weight 5 (~1%) HAND override (user 2026-06-25): rarest special after Thundergun, decoupled from its TOP price tier' },
];
// ---- EXCLUDED from PaP pricing (no _up form) but STILL in the box -> needs a box weight.
const EXCLUDED = [
];

function composite(e, clip, reserve, reload, move, pen, hand) {
  return dpsScore(e) * W.dps + mobScore(move) * W.mobility + sustainScore(reload, clip) * W.sustain
    + PEN[pen] * W.pen + reserveScore(reserve) * W.reserve + HAND[hand] * W.handling;
}

const scored = GUNS.map((g) => {
  const baseScore = composite(g.e, g.cl, g.rs, g.rl, g.mv, g.p, g.h);
  const papScore = composite(g.pe == null ? g.e : g.pe, g.pc, g.pr, g.prl, g.mv, g.p, g.h);
  return { ...g, bn: g.bn || g.w, baseScore, baseTier: formulaTier(baseScore), papScore, papTier: formulaTier(papScore) };
}).sort((a, b) => b.papScore - a.papScore);

const n = scored.length;
scored.forEach((r, i) => {
  r.rank = i + 1;
  r.tercile = (i < n / 3) ? 'TOP' : (i < 2 * n / 3) ? 'MID' : 'BOT';
  r.price = r.force || r.tercile;
  r.overridden = !!r.force && r.force !== r.tercile;
  // box weight normally tracks the price tier, but a gun can pin its BOX rarity independently
  // via boxForce (decoupled, like the specials) WITHOUT moving its PaP price (user 2026-06-25).
  r.box = r.boxForce || BOX_WEIGHT[r.price];
  r.boxOverridden = !!r.boxForce && r.boxForce !== BOX_WEIGHT[r.price];
});

// box odds across the WHOLE box pool (scoreable + specials + excluded)
const boxPool = [
  ...scored.map((r) => ({ d: r.d, bn: r.bn, box: r.box })),
  ...SPECIALS.map((s) => ({ d: s.d, bn: s.w, box: s.box })),
  ...EXCLUDED.map((x) => ({ d: x.d, bn: x.w, box: x.box })),
];
const boxTotal = boxPool.reduce((a, b) => a + b.box, 0);

// tight tercile boundaries (coin-flip within 0.10)
const tight = [];
for (let i = 1; i < n; i++) if (scored[i].tercile !== scored[i - 1].tercile) {
  const gap = scored[i - 1].papScore - scored[i].papScore;
  if (gap < 0.10) tight.push({ a: scored[i - 1], b: scored[i], gap });
}

// ---- console ----
console.log('PaP PRICING + BOX ODDS - PaP-form score, ranked, rank terciles\n');
console.log('Rank  PaP  Gun             Class     PaPscore  Price  Cost                  BoxWt  ~Roll%');
console.log('----  ---  --------------  --------  --------  -----  --------------------  -----  -----');
for (const r of scored) {
  const fl = (r.cu ? ' *' : '') + (r.overridden ? ` (ovr<-${r.tercile})` : '');
  console.log(`${String(r.rank).padStart(2)}    ${r.papTier.padEnd(3)}  ${r.d.padEnd(14)}  ${r.c.padEnd(8)}  ${r.papScore.toFixed(2)}      ${r.price}    ${PRICE[r.price].costs.join(' / ').padEnd(20)}  ${String(r.box).padStart(3)}    ${(100 * r.box / boxTotal).toFixed(1)}%${fl}`);
}
for (const s of SPECIALS) console.log(`--    --   ${s.d.padEnd(14)}  special   forced    ${s.tier}    ${PRICE[s.tier].costs.join(' / ').padEnd(20)}  ${String(s.box).padStart(3)}    ${(100 * s.box / boxTotal).toFixed(1)}%`);
for (const x of EXCLUDED) console.log(`--    --   ${x.d.padEnd(14)}  excluded  no PaP    --     ${'(unpriced)'.padEnd(20)}  ${String(x.box).padStart(3)}    ${(100 * x.box / boxTotal).toFixed(1)}%`);
console.log(`\nbox pool: ${boxPool.length} weapons, total weight ${boxTotal}`);
for (const t of tight) console.log(`  ~ TIGHT ${t.a.tercile}/${t.b.tercile}: ${t.a.d} ${t.a.papScore.toFixed(2)} vs ${t.b.d} ${t.b.papScore.toFixed(2)} (gap ${t.gap.toFixed(2)})`);

// ---- BASE-form ranking (user 2026-06-25: base table too; same v2 formula on BASE stats) ----
console.log('\nBASE-FORM ranking (no PaP)\nRank  Tier  Gun             Class     BaseScore');
console.log('----  ----  --------------  --------  ---------');
[...scored].sort((a, b) => b.baseScore - a.baseScore).forEach((r, i) =>
  console.log(`${String(i + 1).padStart(2)}    ${r.baseTier.padEnd(4)}  ${r.d.padEnd(14)}  ${r.c.padEnd(8)}  ${r.baseScore.toFixed(2)}${r.cu ? ' *' : ''}`));

// ---- GSC emit ----
const pad = (s, n2) => s + ' '.repeat(Math.max(1, n2 - s.length));
function gscPap() {
  const L = ['function pap_price_bucket( weapon_name )', '{', '    if ( !isdefined( weapon_name ) ) return "BOT";', ''];
  for (const tier of ['TOP', 'MID', 'BOT']) {
    L.push(`    // ${tier}  (${PRICE[tier].costs.join(' / ')})`);
    for (const s of SPECIALS.filter((s) => s.tier === tier))
      L.push(`    if ( IsSubStr( weapon_name, "${s.w}" ) )${pad('', 18 - s.w.length)}return "${tier}";   // ${s.d} (special)`);
    for (const r of scored.filter((r) => r.price === tier))
      L.push(`    if ( IsSubStr( weapon_name, "${r.w}" ) )${pad('', 18 - r.w.length)}return "${tier}";   // ${r.d} (PaP ${r.papScore.toFixed(2)}${r.overridden ? ', pinned' : ''})`);
    L.push('');
  }
  L.push('    return "BOT";   // default: cheapest tier (also covers the no-PaP Action Figure)', '}');
  return L.join('\n');
}
function gscBox() {
  const byWt = {};
  for (const e of boxPool) (byWt[e.box] = byWt[e.box] || []).push(e);
  const L = ['function acc_box_weight( wpn )', '{', '    if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) return 5;', '    n = wpn.name;'];
  for (const wt of Object.keys(byWt).map(Number).sort((a, b) => a - b)) {
    const conds = byWt[wt].map((e) => `n == "${e.bn}"`).join(' || ');
    const names = byWt[wt].map((e) => e.d).join(', ');
    L.push(`    if ( ${conds} ) return ${wt};   // ~${(100 * wt / boxTotal).toFixed(1)}% each - ${names}`);
  }
  L.push('    return 5;   // unknown -> mid');
  L.push('}');
  return L.join('\n');
}

// ---- doc ----
const inTier = (tier) => [...scored.filter((r) => r.price === tier).map((r) => r.d), ...SPECIALS.filter((s) => s.tier === tier).map((s) => `${s.d} (special)`)];
const sum = (a) => a.reduce((x, y) => x + y, 0);
const rankRows = [
  ...scored.map((r) => `| ${r.rank} | **${r.d}** | ${r.c} | ${r.papScore.toFixed(2)} | **${r.price}**${r.overridden ? ' ¹' : ''} | ${PRICE[r.price].costs.join(' / ')} | ${r.box} (~${(100 * r.box / boxTotal).toFixed(1)}%) |`),
  ...SPECIALS.map((s) => `| — | **${s.d}** | special | — | **${s.tier}** ² | ${PRICE[s.tier].costs.join(' / ')} | ${s.box} (~${(100 * s.box / boxTotal).toFixed(1)}%) |`),
  ...EXCLUDED.map((x) => `| — | **${x.d}** | excluded ³ | — | — | (no PaP) | ${x.box} (~${(100 * x.box / boxTotal).toFixed(1)}%) |`),
].join('\n');

const doc = `# 54 - Pack-a-Punch Pricing & Mystery-Box Odds

> **GENERATED FILE - do NOT hand-edit.** Regenerate with \`node tools/compute_gun_tiers.js\`
> after adding/removing/retuning any gun. Source of truth: [tools/compute_gun_tiers.js](../tools/compute_gun_tiers.js).
> Consumers: \`_acc_pap_levels.gsc\` (\`pap_price_bucket\`/\`tier_cost\`) + \`_acc_map_randomizer.gsc\` (\`acc_box_weight\`).

## The rule

A gun's PaP cost **and** its box rarity both scale with how good it is **at its packed
ceiling** - you pay more to upgrade a stronger gun, and you roll it less often.

1. Each scoreable gun is scored by the docs/05 "v2 sustain" formula on its **PaP T3
   form stats** (PaP magazine + reserve; DPS is the uniform-scaled base value).
2. Guns are **ranked best -> worst** and split into **thirds**: top third = **TOP**
   (most expensive PaP, rarest roll), middle = **MID**, bottom = **BOT** (cheapest, commonest).
3. Hand **overrides** pin a gun; non-scoreable **specials** (wonder weapon, launcher) are
   placed by hand; guns with **no PaP form** are excluded from pricing but still get a box weight.

Relative split -> add/remove a gun and the tercile boundaries reshuffle automatically.

| Price tier | PaP cost T1 / T2 / T3 | Cumulative | Box weight (higher = commoner) |
|---|---|--:|---|
| **TOP** | ${PRICE.TOP.costs.join(' / ')} | ${sum(PRICE.TOP.costs).toLocaleString()} | ${BOX_WEIGHT.TOP} (rare) · WW = ${BOX_WW} |
| **MID** | ${PRICE.MID.costs.join(' / ')} | ${sum(PRICE.MID.costs).toLocaleString()} | ${BOX_WEIGHT.MID} |
| **BOT** | ${PRICE.BOT.costs.join(' / ')} | ${sum(PRICE.BOT.costs).toLocaleString()} | ${BOX_WEIGHT.BOT} (common) |

## Current ranking (${n} scoreable + ${SPECIALS.length} special + ${EXCLUDED.length} excluded; box pool ${boxPool.length}, total weight ${boxTotal})

| Rank | Gun | Class | PaP score | Price tier | PaP cost T1/T2/T3 | Box weight (~roll) |
|--:|---|---|--:|:--:|---|---|
${rankRows}

¹ hand override (pinned despite rank tercile). ² special (outside the formula, tier set by hand).
³ no \`_up\` form -> can't be Pack-a-Punched; still rolls from the box at the listed weight.

**Price tiers:** TOP = ${inTier('TOP').join(', ')} · MID = ${inTier('MID').join(', ')} · BOT = ${inTier('BOT').join(', ')}
${tight.map((t) => `\n> ⚠ **Tight ${t.a.tercile}/${t.b.tercile} boundary:** ${t.a.d} (${t.a.papScore.toFixed(2)}) vs ${t.b.d} (${t.b.papScore.toFixed(2)}), gap ${t.gap.toFixed(2)}.`).join('')}

## GSC #1 - paste into \`_acc_pap_levels.gsc\` (between the BEGIN/END GENERATED markers)

\`\`\`gsc
${gscPap()}

// Per-step PaP cost: price tier x PaP tier (1..3). docs/54.
function tier_cost( bucket, tier )
{
    if ( bucket == "TOP" )
    {
        switch ( tier ) { case 1: return ${PRICE.TOP.costs[0]}; case 2: return ${PRICE.TOP.costs[1]}; case 3: return ${PRICE.TOP.costs[2]}; }
    }
    else if ( bucket == "MID" )
    {
        switch ( tier ) { case 1: return ${PRICE.MID.costs[0]}; case 2: return ${PRICE.MID.costs[1]}; case 3: return ${PRICE.MID.costs[2]}; }
    }
    else   // "BOT" and default
    {
        switch ( tier ) { case 1: return ${PRICE.BOT.costs[0]}; case 2: return ${PRICE.BOT.costs[1]}; case 3: return ${PRICE.BOT.costs[2]}; }
    }
    return 0;
}
\`\`\`

## GSC #2 - paste into \`_acc_map_randomizer.gsc\` (between the BEGIN/END GENERATED markers)

Box weight: higher = commoner roll (best guns rarest). Matched by EXACT box-pool name (\`==\`),
re-normalized live as you collect guns (the box never repeats one you own).

\`\`\`gsc
${gscBox()}
\`\`\`

## How to rebalance after a roster change

1. Edit the \`GUNS\` / \`SPECIALS\` / \`EXCLUDED\` tables in
   [tools/compute_gun_tiers.js](../tools/compute_gun_tiers.js). PaP clip/reserve come from
   the gun's Skye GDT \`_up\` entry: reserve = \`maxAmmo\` x \`clipSize\`.
2. Run \`node tools/compute_gun_tiers.js\` (regenerates THIS doc).
3. Paste **GSC #1** into \`_acc_pap_levels.gsc\` and **GSC #2** into \`_acc_map_randomizer.gsc\`
   (each between its \`<<< BEGIN/END GENERATED >>>\` markers).
4. Rebuild GSC-only: \`.\\tools\\build_map.ps1 -GscOnly\`.

## Notes

- **PaP DPS = base value** (PaP scales DPS ~x2.5 *uniformly*; only PaP clip/reserve move).
- **\\* curated DPS**: snipers scored single-target, shotguns on crowd (docs/05 special rules).
- **RW1** shipped clipSize 1 (single-shot charge) which scored ~B; hand-tuned to a real magazine
  (clip 8 base / 12 PaP via reduce_base_ammo CLIP_FIX) so it earns A (~7.15).
- PaP-form clip/reserve GDT-verified (workflow \`pap-form-gdt-stats\`, 2026-06-23).
`;

const docPath = path.join(__dirname, '..', 'docs', '54_pap_pricing_tiers.md');
fs.writeFileSync(docPath, doc);
console.log(`\nwrote ${path.relative(path.join(__dirname, '..'), docPath)}`);
