#!/usr/bin/env node
// scale_hipspread_by_class.js [--revert] - SINGLE SOURCE OF TRUTH for per-class hip-fire spread (user 2026-06-29).
//
// Scales the 8 hipSpread PATTERN fields (Stand/Ducked/Prone/Slide Min+Max - the cone size; ADS is NOT touched)
// for each gun by its class factor, across EVERY form: base, PaP (_up), all 6 perk-twins (_acc_* + _up_acc_*;
// was 14 before the 2026-07-04 fastfire removal - this tool prefix-scans _acc_* so it adapts automatically),
// AND the .acc-orig recoil baselines (so an apply_recoil_overhaul re-run keeps it). ALWAYS scales from a pristine
// .acc-hipspread-orig backup -> idempotent + re-runnable; --revert restores x1 (vanilla) for every mapped gun.
// Pistols (s1_rw1, t6_fiveseven) + shotguns (s1_tac19, t6_olympia) are intentionally NOT mapped = unchanged.
// Supersedes scale_sniper_hipspread.js (it reuses that tool's pristine backups, so snipers re-derive to x2.5).
//
// After: deploy the repo twins GDT -> <tools>\source_data + gdtdb /update + build (game CLOSED).
'use strict';
const fs = require('fs'), path = require('path');
const REVERT = process.argv.includes('--revert');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data');
const REPO_TWINS = path.resolve('source_data/acc_weapon_variants.gdt');

// gun base-name -> hip-spread factor. weaponClass buckets, refined (the GDT "rifle" class mixes AR + MK14 + snipers).
const FACTOR = {
    s1_ae4: 1.25, t9_ak47: 1.25,                                       // AR  +25%  (NOTE: the CW Grav t9_grav is NOT here - its AR +25% hip-spread is BAKED into the base+twins by the surgical swap [scratchpad/swap_galil_grav.js], since that swap does not go through this class tool's repo-twins->deploy path. Keeping it out avoids a double-scale.)
    s1_asm1: 1.10, s4_ppsh41_base: 1.10, t6_chicom_cqb: 1.10, t9_ak74u: 1.10, // SMG +10%
    t9_m60: 1.20, t9_rpd: 1.20,                                          // LMG +20%
    s1_mk14: 1.50,                                                      // Marksman +50%
    s1_mors: 2.5, t8_paladin_hb50: 2.5,                                 // Sniper +150% (already applied; kept as source of truth)
};
const PREFIXES = Object.keys(FACTOR);
const FIELDS = new Set(['hipSpreadStandMin', 'hipSpreadMax', 'hipSpreadDuckedMin', 'hipSpreadDuckedMax', 'hipSpreadProneMin', 'hipSpreadProneMax', 'hipSpreadSlideMin', 'hipSpreadSlideMax']);
const DECL = /^\s*"([\w]+)" \( "[a-z]*weapon\.gdf" \)/;
const FIELD = /^(\s*"([A-Za-z0-9]+)"\s+")(-?[\d.]+)("\s*\r?)$/;

// longest-prefix match: which mapped gun a block (base / _up / _acc_* / _up_acc_*) belongs to.
function gunOf(name) {
    if (!name) return null;
    let best = null;
    for (const p of PREFIXES)
        if (name === p || name === p + '_up' || name.startsWith(p + '_acc_') || name.startsWith(p + '_up_acc_'))
            if (!best || p.length > best.length) best = p;
    return best;
}

function processFile(file) {
    if (!fs.existsSync(file)) return 0;
    const text0 = fs.readFileSync(file, 'utf8');
    if (!text0.includes('bulletweapon.gdf')) return 0;
    const bak = file + '.acc-hipspread-orig';
    if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);   // pristine, once
    const pri = {}; { let cur = null; for (const ln of fs.readFileSync(bak, 'utf8').split('\n')) { const d = ln.match(DECL); if (d) { cur = d[1]; continue; } const m = ln.match(FIELD); if (m && gunOf(cur) && FIELDS.has(m[2])) (pri[cur] = pri[cur] || {})[m[2]] = parseFloat(m[3]); } }
    let cur = null, changed = 0;
    const out = text0.split('\n').map(ln => {
        const d = ln.match(DECL); if (d) { cur = d[1]; return ln; }
        const m = ln.match(FIELD); if (!m) return ln;
        const g = gunOf(cur); if (!g || !FIELDS.has(m[2])) return ln;
        const base = pri[cur] && pri[cur][m[2]]; if (base === undefined) return ln;
        const nl = `${m[1]}${+(base * (REVERT ? 1 : FACTOR[g])).toFixed(4)}${m[4]}`;
        if (nl !== ln) changed++;
        return nl;
    });
    fs.writeFileSync(file, out.join('\n'));
    if (changed) console.log(`  ${path.basename(file).padEnd(34)} ${changed} field(s)`);
    return changed;
}

const gdts = (dir, re) => fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => (f.endsWith('.gdt') || f.endsWith('.gdt.acc-orig')) && (!re || re.test(f))).map(f => path.join(dir, f)) : [];
const files = [
    ...gdts(SD, /^skye_/),                       // skye gun GDTs (root) + their .acc-orig recoil baselines
    ...gdts(path.join(SD, 't9_weapons')),        // CW gun GDTs + baselines
    REPO_TWINS,                                  // the repo twins GDT (deployed after)
];
let total = 0; const seen = new Set();
for (const f of files) { if (seen.has(f)) continue; seen.add(f); total += processFile(f); }
console.log(`[hipspread-class] ${REVERT ? 'REVERTED (x1)' : 'DONE'}: ${total} field(s) changed. Deploy twins + gdtdb /update + build.`);
