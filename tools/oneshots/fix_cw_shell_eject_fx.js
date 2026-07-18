#!/usr/bin/env node
// fix_cw_shell_eject_fx.js [--dry] - repoint the Cold War guns' missing t9 shell-eject (brass-casing) FX to
// caliber-matched STOCK MWR brass ejects on disk (_scobalula\shellejects\mwr\). The BOCW ports reference
// fx\t9_wpn_fx\shell_eject\t9_shell_eject_*.efx which isn't installed -> linker "Effect not found" + no brass
// ejects (user 2026-06-28). Covers BOTH the base/PaP forms (install t9 GDTs) AND the perk-twins
// (source_data/acc_weapon_variants.gdt): the twins CLONE the base, so a base-only fix leaves them pointing at
// the dead FX (caught by the QA errorlog 2026-06-29: t9_*_acc_fastfire still "Effect not found"). Idempotent.
// Install-side + repo (twins). After: deploy twins GDT -> <tools>\source_data -> gdtdb /update -> build -GscOnly.
'use strict';
const fs = require('fs'), path = require('path');
const DRY = process.argv.includes('--dry');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const FXDIR = path.join(TOOLS, 'share', 'raw', 'fx');
const SEP2 = '\\\\';   // GDT path separator = two backslash chars

// gun -> caliber-matched stock MWR brass-eject FX (path under share\raw\fx, fwd slashes)
const STOCK = {
    ak47:  '_scobalula/shellejects/mwr/h1_shell_eject_762x39.efx',     // 7.62x39
    ak74u: '_scobalula/shellejects/mwr/h1_shell_eject_545x39.efx',     // 5.45x39
    m60:   '_scobalula/shellejects/mwr/h1_shell_eject_762x51.efx',     // 7.62x51 NATO
    rpd:   '_scobalula/shellejects/mwr/h1_shell_eject_762x39_rpd.efx', // 7.62x39 (RPD belt)
};
const BASE_GDT = { ak47: 'wpn_t9_ar_ak47.gdt', ak74u: 'wpn_t9_smg_ak74u.gdt', m60: 'wpn_t9_lmg_m60.gdt', rpd: 'wpn_t9_lmg_rpd.gdt' };
const gdtValue = (stock) => 'fx' + SEP2 + stock.replace(/\//g, SEP2);
const diskOK   = (stock) => fs.existsSync(path.join(FXDIR, stock.replace(/\//g, path.sep)));
const DECL_RE  = /^\s*"([A-Za-z0-9_]+)" \( "bulletweapon\.gdf" \)/;
const EJECT_RE = /("[A-Za-z]*EjectEffect"\s+")([^"]*)"/g;

// Walk a GDT; for each block, gunOf(blockName) decides which stock FX to use (null = skip). Only rewrites the
// broken t9_wpn_fx value, so already-fixed refs are no-ops.
function repoint(text, gunOf) {
    const lines = text.split('\n'); let cur = null, n = 0;
    for (let i = 0; i < lines.length; i++) {
        const d = lines[i].match(DECL_RE); if (d) { cur = d[1]; continue; }
        const gun = gunOf(cur); if (!gun) continue;
        lines[i] = lines[i].replace(EJECT_RE, (m, pre, val) => { if (!val.includes('t9_wpn_fx')) return m; n++; return pre + gdtValue(STOCK[gun]) + '"'; });
    }
    return { text: lines.join('\n'), n };
}

let total = 0;
// 1) base + PaP forms: one gun per install GDT
for (const [gun, file] of Object.entries(BASE_GDT)) {
    const p = path.join(TOOLS, 'source_data', 't9_weapons', file);
    if (!fs.existsSync(p)) { console.log(`  ! GDT missing: ${file}`); continue; }
    if (!diskOK(STOCK[gun])) { console.log(`  ! stock FX missing on disk, skip ${file}`); continue; }
    const { text, n } = repoint(fs.readFileSync(p, 'utf8'), () => gun);
    if (n && !DRY) fs.writeFileSync(p, text);
    console.log(`  ${file.padEnd(24)} ${n} eject FX -> ${STOCK[gun].split('/').pop()}`);
    total += n;
}
// 2) perk-twins: gun derived from the block name (t9_<gun>_acc_* / t9_<gun>_up_acc_*)
const TW = 'source_data/acc_weapon_variants.gdt';
const gunOfTwin = (name) => { const m = name && name.match(/^t9_(ak47|ak74u|m60|rpd)_/); return m ? m[1] : null; };
const { text: tw, n: tn } = repoint(fs.readFileSync(TW, 'utf8'), gunOfTwin);
if (tn && !DRY) fs.writeFileSync(TW, tw);
console.log(`  acc_weapon_variants.gdt (twins)  ${tn} eject FX`);
total += tn;

console.log(`[cw-shelleject] ${DRY ? 'DRY (no write)' : 'DONE'}: ${total} FX ref(s) repointed.` + (DRY ? '' : ' Next: deploy twins GDT + gdtdb /update + build -GscOnly.'));
