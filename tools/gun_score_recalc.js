// =============================================================================
// gun_score_recalc.js - recompute BASE + PaP tier scores from ACTUALLY CURRENT
// numbers (user 2026-06-26: "use actually current numbers to calculate").
//
// Unlike compute_gun_tiers.js (which scores HAND-maintained clip/reserve/reload in
// its GUNS table), this pulls the mechanical stats (clipSize, reserve = maxAmmo x
// clip) STRAIGHT FROM THE LIVE GDTs, so a clip/reserve change (RPD, MORS, ...) is
// reflected without editing the table. It reuses compute_gun_tiers' curated inputs
// that are NOT mechanically derivable (effective DPS `e`, mobility, pen class,
// handling class, the reload value - Tac-19's is a charge time, not a GDT reload)
// and the SAME v2 scoring formula. Also DRIFT-CHECKS the hand table vs the GDT.
//
// Run:  node tools/gun_score_recalc.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const TIERS = fs.readFileSync(path.join(REPO, 'tools', 'compute_gun_tiers.js'), 'utf8');

function findSourceData() {
    const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
    for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
    return null;
}

// ---- v2 scoring formula (verbatim from compute_gun_tiers.js) ----------------
const W = { dps: 0.30, mobility: 0.16, sustain: 0.18, pen: 0.14, reserve: 0.14, handling: 0.08 };
const clamp = (x, lo, hi) => Math.max(lo, Math.min(hi, x));
const dpsScore = (e) => clamp(1 + (e - 340) / (664 - 340) * 9, 1, 10);
const mobScore = (mv) => clamp(4 + (mv - 0.80) / (1.00 - 0.80) * 6, 1, 10);
const logLerp = (x, x0, s0, x1, s1) => s0 + (s1 - s0) * (Math.log(x) - Math.log(x0)) / (Math.log(x1) - Math.log(x0));
const sustainScore = (reload, clip) => clamp(logLerp(reload / clip, 0.05, 10, 2.0, 1), 1, 10);
const PEN = { none: 2, small: 4, medium: 7, large: 10 };
const reserveScore = (r) => clamp(logLerp(r, 26, 1.5, 400, 10), 1, 10);
const HAND = { auto: 8, charge: 8, sniper: 6, semi: 5, single_sg: 5 };
const tierOf = (s) => s >= 7.7 ? 'S' : s >= 6.6 ? 'A' : s >= 5.6 ? 'B' : 'C';
function composite(e, clip, reserve, reload, move, pen, hand) {
    return dpsScore(e) * W.dps + mobScore(move) * W.mobility + sustainScore(reload, clip) * W.sustain
        + PEN[pen] * W.pen + reserveScore(reserve) * W.reserve + HAND[hand] * W.handling;
}

// ---- parse the GUNS table (curated inputs + the hand clip/reserve we drift-check) ----
function field(line, key, str) {
    const re = str ? new RegExp(key + ":\\s*'([^']*)'") : new RegExp(key + ':\\s*([\\d.]+)');
    const m = line.match(re); return m ? (str ? m[1] : parseFloat(m[1])) : undefined;
}
const guns = [];
{
    const body = TIERS.slice(TIERS.indexOf('const GUNS'), TIERS.indexOf('// ---- SPECIALS'));
    for (const line of body.split('\n')) {
        if (!/^\s*\{\s*d:/.test(line)) continue;
        const g = {
            d: field(line, 'd', true), w: field(line, 'w', true), bn: field(line, 'bn', true), c: field(line, 'c', true),
            e: field(line, 'e'), mv: field(line, 'mv'), p: field(line, 'p', true), h: field(line, 'h', true),
            cu: /cu:\s*true/.test(line), pe: /pe:\s*null/.test(line) ? null : field(line, 'pe'),
            // hand clip/reserve/reload (for the drift check) + reload (curated, reused)
            cl: field(line, 'cl'), rs: field(line, 'rs'), rl: field(line, 'rl'), pc: field(line, 'pc'), pr: field(line, 'pr'), prl: field(line, 'prl'),
        };
        if (g.d && g.w) guns.push(g);
    }
}

// ---- read LIVE GDT clip + reserve (base + PaP) ------------------------------
const SD = findSourceData();
const blocks = {};
function scan(dir) {
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) { scan(p); continue; }
        if (!e.name.endsWith('.gdt')) continue;
        const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
        let cur = null;
        for (const ln of lines) {
            const h = ln.match(/^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/);
            if (h) { cur = h[1]; blocks[cur] = blocks[cur] || {}; continue; }
            if (!cur) continue;
            const fm = ln.match(/^\s*"(clipSize|maxAmmo)"\s+"(\d+)"/);
            if (fm && blocks[cur][fm[1]] === undefined) blocks[cur][fm[1]] = parseInt(fm[2], 10);
        }
    }
}
if (SD) scan(SD);
function gdtAmmo(key, up) {
    const names = up ? [key + '_up', key + '_up_zm', key + '_base_up', key + '_base_up_zm'] : [key, key + '_zm', key + '_base', key + '_base_zm'];
    for (const n of names) if (blocks[n] && blocks[n].clipSize !== undefined) {
        const clip = blocks[n].clipSize, max = blocks[n].maxAmmo !== undefined ? blocks[n].maxAmmo : 1;
        return { clip, reserve: clip * max };
    }
    return null;
}

// ---- recompute -------------------------------------------------------------
const rows = [], drift = [];
for (const g of guns) {
    const base = gdtAmmo(g.w, false), pap = gdtAmmo(g.w, true);
    if (!base || !pap) { drift.push(`${g.d} (${g.w}): GDT base/PaP block not found - using HAND clip/reserve`); }
    const bClip = base ? base.clip : g.cl, bRes = base ? base.reserve : g.rs;
    const pClip = pap ? pap.clip : g.pc, pRes = pap ? pap.reserve : g.pr;
    const eUse = g.pe == null ? g.e : g.pe;
    const baseScore = composite(g.e, bClip, bRes, g.rl, g.mv, g.p, g.h);
    const papScore = composite(eUse, pClip, pRes, g.prl, g.mv, g.p, g.h);
    rows.push({ ...g, bClip, bRes, pClip, pRes, baseScore, papScore });
    // drift: hand table vs live GDT
    if (base && (g.cl !== bClip || g.rs !== bRes)) drift.push(`${g.d} base: table cl/rs ${g.cl}/${g.rs} != GDT ${bClip}/${bRes}`);
    if (pap && (g.pc !== pClip || g.pr !== pRes)) drift.push(`${g.d} PaP : table pc/pr ${g.pc}/${g.pr} != GDT ${pClip}/${pRes}`);
}
rows.sort((a, b) => b.papScore - a.papScore);

// ---- output ----------------------------------------------------------------
console.log('\nGUN TIER SCORES - recomputed from LIVE GDT clip/reserve + current balance-DPS (v2 formula)');
console.log('S >= 7.7 | A >= 6.6 | B >= 5.6 | C < 5.6.   * = curated DPS (shotgun crowd / sniper single-target).\n');
const H = ['Gun', 'Class', 'effDPS', 'base clip/res', 'PaP clip/res', 'BASE', '', 'PaP', ''];
const Wd = [14, 8, 7, 14, 14, 5, 3, 5, 3];
const fmt = a => '| ' + a.map((x, i) => String(x).padEnd(Wd[i])).join(' | ') + ' |';
console.log(fmt(H));
console.log('|' + Wd.map(w => '-'.repeat(w + 2)).join('|') + '|');
for (const r of rows) console.log(fmt([
    r.d + (r.cu ? ' *' : ''), r.c, r.e, `${r.bClip} / ${r.bRes}`, `${r.pClip} / ${r.pRes}`,
    r.baseScore.toFixed(2), tierOf(r.baseScore), r.papScore.toFixed(2), tierOf(r.papScore)]));
console.log('\nDRIFT (compute_gun_tiers hand table vs live GDT):');
if (!drift.length) console.log('  none - the hand table matches the live GDT (scores == compute_gun_tiers).');
else for (const d of drift) console.log('  ! ' + d);
console.log('');
