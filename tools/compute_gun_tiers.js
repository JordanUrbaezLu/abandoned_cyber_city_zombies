// =============================================================================
// compute_gun_tiers.js - THE Pack-a-Punch pricing + mystery-box weight balancer
//                        and doc generator.
//
// WHAT IT DOES (user 2026-06-23):
//   1. Scores every SCOREABLE live gun on its FULLY PACK-A-PUNCHED (PaP T3) form
//      using the multi-factor "v2 sustain" formula from docs/04_weapons.md.
//   2. Ranks the guns best -> worst by that PaP score.
//   3. Splits the ranking into THIRDS (rank terciles): top third = highest PaP
//      cost AND rarest box roll; bottom third = cheapest PaP AND commonest roll.
//      Relative split -> add/remove a gun and the boundaries reshuffle.
//   4. Applies hand OVERRIDES + places non-scoreable SPECIALS (wonder weapon /
//      launcher) + lists EXCLUDED guns with no PaP form.
//   5. GENERATES docs/33_pap_pricing_tiers.md with: the ranking, the PaP price
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
  { d: 'Tac-19',       w: 's1_tac19',        c: 'Shotgun', e: 456, cl: 3,   rs: 27,  rl: 0.47, mv: 1.00, p: 'large',  h: 'single_sg', cu: true,  pc: 6,   pr: 54,  prl: 0.467, t: 'none', pe: null },   // DEMOTED S -> A- (user 2026-07-06 Apex migration): the Peacekeeper is now the top shotgun; e 569->456 -> papScore ~6.9 = A-. Damage unchanged (mult 0.5674 = 642/pellet). Was S+3% buff.
  { d: 'M60',          w: 't9_m60',          c: 'LMG',     e: 597, cl: 100, rs: 400, rl: 9.7,  mv: 0.80, p: 'large',  h: 'auto',      cu: false, pc: 120, pr: 480, prl: 9.7,   t: 'none', pe: null, boxForce: 8 },   // SPREAD +3% best-gun buff (e 580->597, mult 0.20->0.206, user 2026-06-26); boxForce 10->8 (~1.7%, S-tier rare)
  { d: 'AK-74u',       w: 't9_ak74u',        c: 'SMG',     e: 414, cl: 20,  rs: 160, rl: 2.8,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 40,  pr: 280, prl: 2.8,   t: 'none', pe: null },   // SWAPPED with AK-47 -> MID (user 2026-06-26): e 518->414 (acc_weapon_balance_mult 0.23->0.184); boxForce:29 REMOVED so box rarity follows price (MID, common)
  // Chicom CQB + Paladin HB50 REMOVED 2026-07-06 (Apex migration): swapped out for the Prowler + G7 Scout (see below).
  // PPSH-41 scores S and lands TOP naturally; force keeps it TOP if the roster shrinks.
  { d: 'PPSH-41',      w: 's4_ppsh41',       bn: 's4_ppsh41_base', c: 'SMG', e: 507, cl: 40, rs: 360, rl: 3.5, mv: 1.00, p: 'medium', h: 'auto', cu: false, pc: 60, pr: 540, prl: 3.5, t: 'none', pe: null, force: 'TOP', boxForce: 8 },   // SPREAD +3% best-gun buff (e 492->507); PaP clip 54->60 / reserve 486->540 (user 2026-07-05); boxForce 8; force:TOP
  { d: 'AK-47',        w: 't9_ak47',         c: 'AR',      e: 585, cl: 21,  rs: 168, rl: 3.25, mv: 0.95, p: 'medium', h: 'auto',      cu: false, pc: 31,  pr: 279, prl: 3.25,  t: 'none', pe: null, boxForce: 8 },   // SPREAD +3% best-gun buff (e 568->585, mult 0.227->0.2338, user 2026-06-26); boxForce 8 (~1.7%, S-tier rare). Swapped to TOP/S with AK-74u 2026-06-26
  // XM4 (Cold War t9_xm4): full-auto AR, S tier (user 2026-07-04). e = base 200/0.083 x mult 0.21 = 506 -> papScore ~7.86 = S.
  // PaP _up clip 70 / reserve 700 (maxAmmo 10 x 70) UNCUT / reload 2.3. boxForce 8 = S-tier rare roll. Balance mult in _acc_damage.
  { d: 'XM4',          w: 't9_xm4',          c: 'AR',      e: 506, cl: 24,  rs: 216, rl: 2.63, mv: 0.95, p: 'medium', h: 'auto',      cu: false, pc: 55,  pr: 550, prl: 2.3,   t: 'none', pe: null, boxForce: 8, force: 'TOP' },   // PaP clip 55 / reserve 550 (user 2026-07-04, up from the -35% cut's 46/460); base 24/216 proportional; all twins too
  // Streetsweeper (Cold War t9_streetsweeper): full-auto drum shotgun, A tier (user 2026-07-04). CURATED e=445 -> papScore ~6.94 = A
  // (shotgun crowd-DPS curated like Tac-19/Olympia; the actual damage is mult 0.135 in _acc_damage, decoupled). 12 pellets PaP.
  // PaP _up clip 36 / reserve 432 (maxAmmo 12 x 36) / reload 0.9. force:'MID' pins A-tier price.
  { d: 'Streetsweeper', w: 't9_streetsweeper', c: 'Shotgun', e: 380, cl: 6, rs: 60, rl: 0.9, mv: 1.00, p: 'medium', h: 'single_sg', cu: true, pc: 14, pr: 126, prl: 0.9, t: 'none', pe: null },   // DEMOTED A -> B (user 2026-07-06 Apex migration): e 445->380 -> papScore ~6.2 = B (below Tac-19 A-, Peacekeeper S). Damage/ammo unchanged (mult 0.0930, clip 14/reserve 126).
  // CEL-3 Cauterizer (AW s1_cel3): triple-barrel full-auto SPREAD shotgun, B tier (user 2026-07-05). CURATED crowd
  // DPS e=395 (12 pellets PaP like Streetsweeper/Tac-19; raw damage decoupled - mult 0.27 in _acc_damage). Loc
  // NORMALIZED install-side (torso/neck 1.0, .acc-loc-orig). PaP _up clip 24 / reserve 192 (maxAmmo 8 x 24) / reload 3.0 -> papScore ~6.22 = B.
  { d: 'CEL-3',        w: 's1_cel3',         c: 'Shotgun', e: 395, cl: 16,  rs: 128, rl: 3.0,  mv: 1.00, p: 'medium', h: 'single_sg', cu: true,  pc: 24,  pr: 192, prl: 3.0,   t: 'none', pe: null },
  { d: 'AE4',          w: 's1_ae4',          c: 'AR',      e: 413, cl: 25,  rs: 200, rl: 2.0,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 38,  pr: 304, prl: 2.0,   t: 'none', pe: null },
  { d: 'ASM1',         w: 's1_asm1',         c: 'SMG',     e: 401, cl: 22,  rs: 132, rl: 2.1,  mv: 1.00, p: 'medium', h: 'auto',      cu: false, pc: 36,  pr: 288, prl: 2.1,   t: 'none', pe: null },
  { d: 'Grav',         w: 't9_grav',         c: 'AR',      e: 412, cl: 25,  rs: 225, rl: 2.9,  mv: 0.95, p: 'medium', h: 'auto',      cu: false, pc: 35,  pr: 420, prl: 2.925, t: 'none', pe: null, force: 'MID' },   // Grav (CW full-auto AR): the GALIL's STATS grafted onto the CW model/sfx (user 2026-07-05, graft_cw_weapon_stats t6_galil->t9_grav - same AK-47-style "new model, same gun" migration). Identical box slot to the Galil: 220@0.08=2750 raw x mult 0.15 = ~412 eff DPS; PaP clip 35 / reserve 420 (maxAmmo 12 x 35). force:MID pins its price (as the Galil did).
  { d: 'Five-Seven',   w: 't6_fiveseven',    c: 'Pistol',  e: 412, cl: 14,  rs: 56,  rl: 1.8,  mv: 1.00, p: 'small',  h: 'semi',      cu: true,  pc: 21,  pr: 147, prl: 1.8,   t: 'none', pe: null },   // SPREAD -3% worst-gun nerf (e 425->412, mult 0.26->0.2522, user 2026-06-26)
  // ===== APEX MIGRATION 2026-07-06: Klauser removed (swapped for the Alternator). +4 Apex guns below. =====
  // Peacekeeper (Apex 11->12-pellet lever shotgun): POWER-FIRST top shotgun (user #6). bal 0.43 -> ~950/pellet T3 (highest shotgun power). e=620 curated for S (power, not raw DPS). PaP _up clip 8 / reserve 80 / reload 2.5.
  { d: 'Peacekeeper',  w: 'apex_peacekeeper', c: 'Shotgun', e: 620, cl: 6, rs: 60, rl: 2.5, mv: 1.00, p: 'large', h: 'single_sg', cu: true, pc: 8, pr: 80, prl: 2.5, t: 'none', pe: null, force: 'TOP' },
  // Prowler (Apex burst PDW, here full-auto): B SMG. bal 0.21. big clip/reserve pin it B via utility; e=354. PaP _up clip 28 / reserve 224.
  { d: 'Prowler',      w: 'apex_prowler', c: 'SMG', e: 360, cl: 20, rs: 160, rl: 2.0, mv: 1.00, p: 'medium', h: 'auto', cu: false, pc: 28, pr: 224, prl: 2.0, t: 'none', pe: null },
  // G7 Scout REMOVED 2026-07-11 (user): replaced by the CW M16 (see below), which slots in as a slightly-better-than-MK14 marksman.
  // Alternator (Apex full-auto SMG): TRASH base (bal 0.05) but A+ PaP (bal 0.27, user "trash base but A+ papped" - Klauser pattern). e=430 = PaP eff DPS. PaP _up clip 26 / reserve 312 / reload 1.9.
  { d: 'Alternator',   w: 'apex_alternator', c: 'SMG', e: 480, cl: 16, rs: 160, rl: 1.9, mv: 1.00, p: 'medium', h: 'auto', cu: false, pc: 26, pr: 312, prl: 1.9, t: 'none', pe: null },
  { d: 'RPD',          w: 't9_rpd',          c: 'LMG',     e: 327, cl: 75,  rs: 300, rl: 7.5,  mv: 0.80, p: 'large',  h: 'auto',      cu: false, pc: 125, pr: 500, prl: 7.5,   t: 'none', pe: null },   // SPREAD -3% worst-gun nerf (e 337->327, mult 0.125->0.1213, user 2026-06-26); clip+reserve +25% (75/300 base, 125/500 PaP)
  // HAMR (BO2 t6_hamr): B-tier LMG placed BETWEEN the M60 (S) and RPD (C) - user 2026-07-10. Loc + ammo normalized
  // install-side (tools/prep_hamr_gdt.js): PaP clip 100 / reserve 500 (maxAmmo 5) / reload 6.0. e=360 -> papScore ~6.27 = B.
  // Balance mult 0.208 in _acc_damage (body T3 527, between RPD 402 and M60 713). Box/price come from gen_box_dynamic (rank #24, MID).
  { d: 'HAMR',         w: 't6_hamr',         c: 'LMG',     e: 360, cl: 80,  rs: 400, rl: 6.0,  mv: 0.80, p: 'large',  h: 'auto',      cu: false, pc: 100, pr: 500, prl: 6.0,   t: 'none', pe: null },
  // RW1: directed-energy pistol. Hand-tuned to a real magazine (reduce_base_ammo CLIP_FIX/MAXAMMO_FIX:
  // clip 8 base / 12 PaP, reserve 56/96 - ABSOLUTE, exempt from the x0.7 cut) so it EARNS A (user 2026-06-23).
  { d: 'RW1',          w: 's1_rw1',          c: 'Pistol',  e: 590, cl: 8,   rs: 56,  rl: 1.4,  mv: 1.00, p: 'small',  h: 'semi',      cu: false, pc: 12,  pr: 96,  prl: 1.4,   t: 'none', pe: null },
  { d: 'Olympia',      w: 't6_olympia',      c: 'Shotgun', e: 255, cl: 2,   rs: 26,  rl: 3.9,  mv: 1.00, p: 'small',  h: 'single_sg', cu: true,  pc: 4,   pr: 84,  prl: 2.5,   t: 'none', pe: null },   // SPREAD -3% worst-gun nerf (mult 0.4743); PaP clip 2->4 / reserve 42->84 DOUBLED (user 2026-07-05) - helps its awful 2-round sustain
  // MK14 (AW s1_mk14): semi-auto DMR, B tier (user 2026-06-24). cu single-target (semi-auto raw DPS overstates).
  // e=400 + PaP clip 12 / reserve 240 -> papScore ~5.99 (B); base 14 / 168 -> ~5.90 (B). Body loc clean (no normalize).
  { d: 'MK14',         w: 's1_mk14',         c: 'DMR',     e: 388, cl: 14,  rs: 168, rl: 2.0,  mv: 0.95, p: 'medium', h: 'semi',      cu: true,  pc: 12,  pr: 240, prl: 2.0,   t: 'none', pe: null, boxForce: 29, force: 'BOT' },   // USER 2026-07-11 force:BOT -> PaP 3000/4500/6000 (cheapest tier). boxForce 29 keeps MID box rarity. SPREAD -3% worst-gun nerf (e 400->388, mult 0.30->0.291, user 2026-06-26)
  // M16 RETIRED 2026-07-11 (user): replaced by the Apex Triple Take below in the same #19/MID slot.
  // Triple Take (Apex apex_tripletake): ENERGY sniper. v2 VOLLEY REWORK (user 2026-07-16): the def is a
  // PROJECTILEWEAPON (Havoc-graft, prep_apex_tripletake_gdt.js) - a trigger = 3 flat plasma bolts COSTING
  // 3 ROUNDS (1 native + 2 _acc_tripletake.gsc side hits - all HITSCAN, bulletweapon def shotCount 1;
  // the plasma-orb "projectiles" are cosmetic movers), fireTime 0.1728 base / 0.13824 PaP (+25% rate),
  // +10% dmg (bal 0.3100625). clip 9 base / 15 PaP = 3 / 5 volleys per mag; reserve 117 / 180 (39 / 60
  // triggers) - NB the cl/rs raw-round columns overstate sustain 3x vs a 1-round-per-shot gun.
  // pen LARGE (v3, round-8 "piercing needs to be upgraded"). cu single-target (per-trigger 3-hit burst).
  { d: 'Triple Take',  w: 'apex_tripletake', c: 'Marksman', e: 822, cl: 9,  cs: 3, rs: 117, rl: 2.6,  mv: 0.93, p: 'large', h: 'semi',  cu: true,  pc: 15,  pr: 180, prl: 3.4,   t: 'none', pe: null },   // e 520 -> 650 (07-11 +25%) -> 715 (07-16 +10% volley rework) -> 822 (07-16 round-9 +15%)
  // MORS (AW s1_mors): charge-up railgun sniper. cu single-target (one-shot rail). RESERVE CUT 50% (user 2026-06-25):
  // 120/180 -> 60/90 (gameplay ammo nerf, reduce_base_ammo MAXAMMO_FIX). That drops its reserve score, so papScore
  // falls ~7.90 -> ~7.60 (just under the S cutoff). force:'TOP' PINS its PaP price + box weight at TOP so the cut is a
  // pure ammo nerf, NOT a price/rarity demotion (user's "MORS is the S sniper" intent). DPS e 660 / clip 1 / reload 1.2.
  { d: 'MORS',         w: 's1_mors',         c: 'Sniper',  e: 660, cl: 1,   rs: 48,  rl: 1.2,  mv: 1.00, p: 'large',  h: 'sniper',    cu: true,  pc: 1,   pr: 72,  prl: 1.2,   t: 'none', pe: null, force: 'TOP' },   // reserve -20% (60/90->48/72, user 2026-06-26); force:TOP keeps it S/TOP despite the cut
];

// ---- SPECIALS: PaP-able but OUTSIDE the formula. Hand price tier + box weight.
const SPECIALS = [
  { d: 'Thundergun', w: 'thundergun', tier: 'TOP', box: BOX_WW, why: 'wonder weapon (wind-blast, is_limited) - rarest roll of all' },
  { d: 'Mahem',      w: 's1_mahem',   tier: 'TOP', box: 8, why: 'explosive rocket launcher (projectile, [A] tag, aat-exempt). TOP price + rare roll; box weight now SUPERSEDED by gen_box_dynamic.js (rank 10, ~1.94%)' },
  { d: 'Havoc', w: 'apex_beam_rifle', tier: 'TOP', box: 8, why: 'Apex energy PROJECTILE rifle (full-auto), A-tier energy special replacing China Lake (user 2026-07-06). Projectile -> twin-exempt, energy special like the Blast-O-Matic. Box weight from gen_box_dynamic.js' },
  { d: 'Action Figure', w: 't8_melee_figure', tier: 'TOP', box: 5, why: 'melee special - PaPs IN PLACE (no _up form), +1 cleave target per tier; S-tier PaP cost (user 2026-06-25). Box weight 5 (~1%) HAND override (user 2026-06-25): rarest special after Thundergun, decoupled from its TOP price tier' },
  // [acc] #5 FIX (2026-07-05): the Blast-O-Matic was MISSING from this table, so a regen DROPPED its hand-added
  // TOP price line and it fell through to BOT (cheapest) - a wonder-class special fully packable for 13,500
  // instead of 22,500. Pinned TOP like the other specials so a future regen keeps it. box:5 matches its prior
  // effective roll (it hit acc_box_weight's default `return 5`), so a future box regen won't shift its odds.
  { d: 'Blast-O-Matic', w: 't9_semiauto_cosplay', tier: 'TOP', box: 5, why: 'is_wonder_weapon energy blaster (projectile special, hand-built twins) - TOP PaP price like the other specials; box weight 5 preserves its current default roll' },
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

const docPath = path.join(__dirname, '..', 'docs', '33_pap_pricing_tiers.md');
fs.writeFileSync(docPath, doc);
console.log(`\nwrote ${path.relative(path.join(__dirname, '..'), docPath)}`);
