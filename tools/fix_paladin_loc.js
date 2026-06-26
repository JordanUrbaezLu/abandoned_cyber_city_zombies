// =============================================================================
// fix_paladin_loc.js - TARGETED loc fix: Paladin HB50 headshot was WEAKER than body
// (user 2026-06-26). The BO4-port Paladin GDT ships locHead/locHelmet 1.0, so with the
// map's x0.5 headshot temper a headshot did 0.5x BODY (backwards). Every other non-shotgun
// is locHead 5.0 (-> 2.5x body); MORS (the other sniper) was already 5.0. This sets the
// Paladin to 5.0 to match.
//
// WHY a targeted script (not normalize_gun_loc): normalize re-asserts the WHOLE roster,
// which would also flip the EXCLUDED shotguns' heads to flat 1.0 - a change the user did
// NOT ask for this pass (they just calibrated the shotgun DAMAGE nerf on the current 3x
// heads). This touches ONLY t8_paladin_hb50* blocks.
//
// DURABLE: also patches the apply_recoil `.acc-orig` backup, so a future apply_recoil run
// (which restores .acc-orig before scaling recoil + re-cloning twins) keeps 5.0 instead of
// reverting to the native 1.0. Fixes: live base GDT + .acc-orig + the twins in
// acc_weapon_variants.gdt. Run:  node tools/fix_paladin_loc.js  (then gdtdb /update + build)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

function findSourceData() {
    const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
    for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
    throw new Error('source_data not found');
}
const SD = findSourceData();
const KEY = 't8_paladin_hb50';
const HEADER = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;
const LOC = /^(\s*"(locHead|locHelmet)"\s+")([^"]*)("\s*)$/;

// (file, blockFilter): scoped rewrite of locHead/locHelmet -> 5.0 for matching blocks.
function fix(file, scoped) {
    if (!fs.existsSync(file)) { console.log(`  SKIP (missing): ${path.basename(file)}`); return; }
    const lines = fs.readFileSync(file, 'utf8').split(/\r?\n/);
    let cur = null, changed = 0;
    for (let i = 0; i < lines.length; i++) {
        const h = lines[i].match(HEADER);
        if (h) { cur = h[1]; continue; }
        const inScope = scoped ? (cur && cur.indexOf(KEY) === 0) : true;
        if (!inScope) continue;
        const m = lines[i].match(LOC);
        if (m && m[3] !== '5.0') { lines[i] = m[1] + '5.0' + m[4]; changed++; }
    }
    fs.writeFileSync(file, lines.join('\n'));
    console.log(`  ${path.basename(file)}: ${changed} locHead/locHelmet field(s) -> 5.0`);
}

console.log('fix_paladin_loc -> 5.0 (2.5x body headshot):');
fix(path.join(SD, 'skye_t8_paladin_hb50.gdt'), false);              // whole file is Paladin
fix(path.join(SD, 'skye_t8_paladin_hb50.gdt.acc-orig'), false);    // durable through apply_recoil
fix(path.join(SD, 'acc_weapon_variants.gdt'), true);               // only t8_paladin_hb50* twin blocks
console.log('NEXT: gdtdb /update + build. Verify: node tools/gun_maxscale_table.js (Paladin head = 2.5x body).');
