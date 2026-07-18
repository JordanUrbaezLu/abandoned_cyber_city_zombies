#!/usr/bin/env node
// scale_sniper_hipspread.js [--factor 2.5] [--revert] - scale the HIP-FIRE SPREAD of the two snipers
// (MORS s1_mors + Paladin t8_paladin_hb50) across ALL forms (base, PaP _up) AND every perk-twin, so they're
// inaccurate from the hip (user 2026-06-29: "+150% hip spread on snipers" = x2.5).
//
// Scales the 8 hipSpread PATTERN fields only - Stand/Ducked/Prone/Slide Min + Max (the cone size) - NOT the
// *Add/*Decay dynamics (matches gen_weapon_variant_gdt.js SPREAD_KEYS). It ALWAYS scales from a pristine
// .acc-hipspread-orig backup (taken once), so it is idempotent + re-runnable with a different --factor, and
// --revert restores x1. Targets the install sniper GDTs (live + .acc-orig recoil baseline, so a recoil-overhaul
// re-run keeps the change) + the repo twins GDT. After: deploy twins -> <tools>\source_data + gdtdb /update + build.
'use strict';
const fs = require('fs'), path = require('path');
const arg = (n, d) => { const i = process.argv.indexOf('--' + n); return i >= 0 && process.argv[i + 1] && !process.argv[i + 1].startsWith('--') ? process.argv[i + 1] : d; };
const REVERT = process.argv.includes('--revert');
const FACTOR = REVERT ? 1 : parseFloat(arg('factor', '2.5'));
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SD = path.join(TOOLS, 'source_data');
const PREFIXES = ['s1_mors', 't8_paladin_hb50'];
const FIELDS = new Set(['hipSpreadStandMin', 'hipSpreadMax', 'hipSpreadDuckedMin', 'hipSpreadDuckedMax', 'hipSpreadProneMin', 'hipSpreadProneMax', 'hipSpreadSlideMin', 'hipSpreadSlideMax']);
const DECL = /^\s*"([\w]+)" \( "[a-z]*weapon\.gdf" \)/;
const FIELD = /^(\s*"([A-Za-z0-9]+)"\s+")(-?[\d.]+)("\s*\r?)$/;
const isSniper = (n) => !!n && PREFIXES.some(p => n === p || n === p + '_up' || n.startsWith(p + '_acc_') || n.startsWith(p + '_up_acc_'));

function processFile(file, label) {
    if (!fs.existsSync(file)) return 0;
    const bak = file + '.acc-hipspread-orig';
    if (!fs.existsSync(bak)) fs.copyFileSync(file, bak);   // pristine backup, once
    // pristine map from the backup: { block: { field: value } }
    const pri = {}; let cur = null;
    for (const ln of fs.readFileSync(bak, 'utf8').split('\n')) {
        const d = ln.match(DECL); if (d) { cur = d[1]; continue; }
        const m = ln.match(FIELD); if (m && isSniper(cur) && FIELDS.has(m[2])) (pri[cur] = pri[cur] || {})[m[2]] = parseFloat(m[3]);
    }
    // rewrite the LIVE file's hipSpread lines = pristine x factor (idempotent: always from pristine)
    cur = null; let changed = 0;
    const out = fs.readFileSync(file, 'utf8').split('\n').map(ln => {
        const d = ln.match(DECL); if (d) { cur = d[1]; return ln; }
        const m = ln.match(FIELD); if (!m || !isSniper(cur) || !FIELDS.has(m[2])) return ln;
        const base = pri[cur] && pri[cur][m[2]]; if (base === undefined) return ln;
        const nl = `${m[1]}${+(base * FACTOR).toFixed(4)}${m[4]}`;
        if (nl !== ln) changed++;
        return nl;
    });
    fs.writeFileSync(file, out.join('\n'));
    if (changed) console.log(`  ${label}: ${changed} hipSpread field(s)`);
    return changed;
}

let total = 0;
for (const g of ['skye_s1_mors.gdt', 'skye_t8_paladin_hb50.gdt'])
    for (const suf of ['', '.acc-orig']) total += processFile(path.join(SD, g + suf), g + suf);
total += processFile('source_data/acc_weapon_variants.gdt', 'acc_weapon_variants.gdt (twins)');
console.log(`[sniper-hipspread] ${REVERT ? 'REVERTED (x1)' : 'DONE x' + FACTOR}: ${total} field(s). Next: deploy twins GDT + gdtdb /update + build.`);
