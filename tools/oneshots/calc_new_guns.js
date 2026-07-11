// Replicate compute_gun_tiers.js scorer EXACTLY, then solve for the e (effDPS) + balance mult
// that lands XM4 in S (papScore >= 7.7) and Streetsweeper in A (6.6 <= papScore < 7.7).
const W = { dps: 0.30, mobility: 0.16, sustain: 0.18, pen: 0.14, reserve: 0.14, handling: 0.08 };
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const dpsScore = (e) => clamp(1 + (e - 340) / (664 - 340) * 9, 1, 10);
const mobScore = (mv) => clamp(4 + (mv - 0.80) / (1.00 - 0.80) * 6, 1, 10);
const logLerp = (x, x0, s0, x1, s1) => s0 + (s1 - s0) * (Math.log(x) - Math.log(x0)) / (Math.log(x1) - Math.log(x0));
const sustainScore = (reload, clip) => clamp(logLerp(reload / clip, 0.05, 10, 2.0, 1), 1, 10);
const PEN = { none: 2, small: 4, medium: 7, large: 10 };
const reserveScore = (r) => clamp(logLerp(r, 26, 1.5, 400, 10), 1, 10);
const HAND = { auto: 8, charge: 8, sniper: 6, semi: 5, single_sg: 5 };
const formulaTier = (s) => s >= 7.7 ? 'S' : s >= 6.6 ? 'A' : s >= 5.6 ? 'B' : 'C';
function composite(e, clip, reserve, reload, move, pen, hand) {
  return dpsScore(e) * W.dps + mobScore(move) * W.mobility + sustainScore(reload, clip) * W.sustain
    + PEN[pen] * W.pen + reserveScore(reserve) * W.reserve + HAND[hand] * W.handling;
}
// solve minimal e for a target papScore, given the fixed stats
function solveE(target, cfg) {
  let lo = 100, hi = 1200;
  for (let i = 0; i < 60; i++) {
    const mid = (lo + hi) / 2;
    const s = composite(mid, cfg.pc, cfg.pr, cfg.prl, cfg.mv, cfg.p, cfg.h);
    if (s < target) lo = mid; else hi = mid;
  }
  return (lo + hi) / 2;
}
function show(name, cfg, rawDPS, es) {
  console.log(`\n=== ${name} ===  (pc=${cfg.pc} pr=${cfg.pr} prl=${cfg.prl} mv=${cfg.mv} pen=${cfg.p} hand=${cfg.h}, rawDPS=${rawDPS})`);
  console.log('   e     papScore  tier   -> impliedMult(e/rawDPS)');
  for (const e of es) {
    const s = composite(e, cfg.pc, cfg.pr, cfg.prl, cfg.mv, cfg.p, cfg.h);
    console.log(`  ${String(Math.round(e)).padStart(4)}   ${s.toFixed(3).padStart(7)}   ${formulaTier(s).padEnd(4)}  mult=${(e / rawDPS).toFixed(4)}`);
  }
  // component breakdown at a reference e
}
function breakdown(name, e, cfg) {
  console.log(`\n--- ${name} component breakdown @ e=${Math.round(e)} ---`);
  console.log(`  dps    ${dpsScore(e).toFixed(2)} x0.30 = ${(dpsScore(e)*0.30).toFixed(3)}`);
  console.log(`  mob    ${mobScore(cfg.mv).toFixed(2)} x0.16 = ${(mobScore(cfg.mv)*0.16).toFixed(3)}`);
  console.log(`  sustain${sustainScore(cfg.prl,cfg.pc).toFixed(2)} x0.18 = ${(sustainScore(cfg.prl,cfg.pc)*0.18).toFixed(3)}  (reload/clip=${(cfg.prl/cfg.pc).toFixed(3)})`);
  console.log(`  pen    ${PEN[cfg.p]} x0.14 = ${(PEN[cfg.p]*0.14).toFixed(3)}`);
  console.log(`  reserve${reserveScore(cfg.pr).toFixed(2)} x0.14 = ${(reserveScore(cfg.pr)*0.14).toFixed(3)}`);
  console.log(`  hand   ${HAND[cfg.h]} x0.08 = ${(HAND[cfg.h]*0.08).toFixed(3)}`);
  console.log(`  TOTAL  = ${composite(e,cfg.pc,cfg.pr,cfg.prl,cfg.mv,cfg.p,cfg.h).toFixed(3)} -> ${formulaTier(composite(e,cfg.pc,cfg.pr,cfg.prl,cfg.mv,cfg.p,cfg.h))}`);
}

// ---------- XM4: S-tier AR. raw_DPS = base 200 / fireTime 0.083 = 2410 ----------
// PaP _up: clip 70 -> 30% cut = 49; reserve = maxAmmo 10 x 49 = 490; reload 2.3; move 0.95; pen medium; hand auto.
const XM4 = { pc: 49, pr: 490, prl: 2.3, mv: 0.95, p: 'medium', h: 'auto' };
const XM4_RAWDPS = 200 / 0.083;
show('XM4 (AR)', XM4, XM4_RAWDPS, [340, 380, 420, 460, 500, 540, 585, 620]);
const xm4_Smin = solveE(7.70, XM4), xm4_Saim = solveE(7.90, XM4);
console.log(`  >> XM4 needs e>=${xm4_Smin.toFixed(0)} for S (mult ${(xm4_Smin/XM4_RAWDPS).toFixed(4)}); aim 7.90 -> e=${xm4_Saim.toFixed(0)} mult=${(xm4_Saim/XM4_RAWDPS).toFixed(4)}`);
breakdown('XM4', xm4_Saim, XM4);

// ---------- Streetsweeper: A-tier full-auto shotgun. per-pellet raw. cu-curated e ----------
// PaP _up: 12 pellets, clip 36 -> cut 25; reserve = maxAmmo 12 x 25 = 300; reload 0.9; move 1.0; pen small.
// Try hand = auto (full-auto drum) AND single_sg (shotgun convention) to see the swing.
const SS_auto = { pc: 25, pr: 300, prl: 0.9, mv: 1.00, p: 'small', h: 'auto' };
const SS_sg   = { pc: 25, pr: 300, prl: 0.9, mv: 1.00, p: 'small', h: 'single_sg' };
const SS_RAWDPS = 310 / 0.2; // per-pellet base dps (shotgun e is curated regardless)
show('Streetsweeper (hand=auto)', SS_auto, SS_RAWDPS, [300, 340, 380, 420, 460, 500, 540, 569]);
show('Streetsweeper (hand=single_sg)', SS_sg, SS_RAWDPS, [340, 400, 460, 520, 569, 600, 640]);
const ss_Amin_auto = solveE(6.60, SS_auto), ss_Amax_auto = solveE(7.70, SS_auto), ss_Aaim_auto = solveE(7.05, SS_auto);
const ss_Amin_sg = solveE(6.60, SS_sg), ss_Amax_sg = solveE(7.70, SS_sg), ss_Aaim_sg = solveE(7.05, SS_sg);
console.log(`  >> SS(auto): A band e=[${ss_Amin_auto.toFixed(0)}..${ss_Amax_auto.toFixed(0)}); aim 7.05 -> e=${ss_Aaim_auto.toFixed(0)}`);
console.log(`  >> SS(single_sg): A band e=[${ss_Amin_sg.toFixed(0)}..${ss_Amax_sg.toFixed(0)}); aim 7.05 -> e=${ss_Aaim_sg.toFixed(0)}`);
breakdown('Streetsweeper(auto)', ss_Aaim_auto, SS_auto);

// ---------- reference: existing tier neighbours (from compute_gun_tiers GUNS) ----------
console.log('\n=== reference existing guns (recompute their papScore to sanity-check) ===');
const refs = [
  ['AK-47 (S)', { pc:31, pr:279, prl:3.25, mv:0.95, p:'medium', h:'auto' }, 585],
  ['PPSH (S)', { pc:54, pr:486, prl:3.5, mv:1.00, p:'medium', h:'auto' }, 507],
  ['AK-74u (A)', { pc:40, pr:280, prl:2.8, mv:1.00, p:'medium', h:'auto' }, 414],
  ['AE4 (B)', { pc:38, pr:304, prl:2.0, mv:1.00, p:'medium', h:'auto' }, 413],
  ['Tac-19 (S,SG)', { pc:6, pr:54, prl:0.467, mv:1.00, p:'large', h:'single_sg' }, 569],
  ['Olympia (C,SG)', { pc:2, pr:42, prl:2.5, mv:1.00, p:'small', h:'single_sg' }, 255],
];
for (const [n, c, e] of refs) console.log(`  ${n.padEnd(16)} papScore=${composite(e,c.pc,c.pr,c.prl,c.mv,c.p,c.h).toFixed(2)} (${formulaTier(composite(e,c.pc,c.pr,c.prl,c.mv,c.p,c.h))})`);

// ---------- DAMAGE (power) targets: final PaP T3 body = raw_up x bal x 3.25 x papMult(2.0) ----------
console.log('\n=== DAMAGE (power) at candidate mults: T3 body = raw_up x bal x 3.25 x 2.0 ===');
const t3 = (raw, bal) => Math.round(raw * bal * 3.25 * 2.0);
console.log(`  XM4 _up raw=360. AK-47(S) T3 body=410. Candidate mults:`);
for (const bal of [0.14, 0.16, 0.175, 0.19, 0.21, 0.2338]) console.log(`    bal=${bal} -> XM4 T3 body=${t3(360,bal)}, head(x2.5)=${Math.round(t3(360,bal)*2.5)}, e=${(bal*XM4_RAWDPS).toFixed(0)}`);
console.log(`  Streetsweeper _up raw=610/pellet, 12 pellets. Tac-19(S) 713/pellet, Olympia(C) 802/pellet.`);
for (const bal of [0.10, 0.12, 0.135, 0.15, 0.17, 0.20]) console.log(`    bal=${bal} -> SS T3 body=${t3(610,bal)}/pellet, x12=${t3(610,bal)*12} point-blank`);
