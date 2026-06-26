// =============================================================================
// normalize_gun_loc.js - enforce ONE hit-location convention on EVERY roster gun
// so headshots are consistent (user 2026-06-25, from the audit_gun_damage.js
// anomaly pass). Supersedes normalize_sniper_loc.js (which fixed only the 2 snipers).
//
// CONVENTION (matches the box-gun standard the audit expects):
//   - headshot-NORMAL guns:  locHead / locHelmet -> 5.0   (-> 2.5x body headshot)
//   - headshot-EXCLUDED guns (is_weapon_headshot_excluded: Tac-19, Olympia):
//                            locHead / locHelmet -> 1.0   (truly FLAT - the engine loc
//                            still applies even though the map skips the headshot bonus,
//                            so 1.0 is the only value that makes "excluded" = flat)
//   - every other body loc:  -> 1.0
//   - locGun / locNone:      left as-is (0 / 1)
// Plus a per-_up `damage` re-encode (PaP forms that shipped with NO GDT boost):
//   - t8_paladin_hb50_up* -> 2000  (was 1000 = base; every other gun's _up out-damages
//                                   its base, so the Paladin PaP now does too, like MORS).
//
// SAFE: edits the install GDTs IN PLACE; loc fields + the listed _up damage ONLY (does
// NOT touch base damage, recoil, or ammo). Idempotent. Backs up each GDT once to
// .acc-gunloc-bak. Install-side (GDTs aren't repo-tracked - re-run on a fresh box).
// Run:  node tools/normalize_gun_loc.js   (then gdtdb /update + build; verify with
//       node tools/audit_gun_damage.js -> should report 0 anomalies)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

function findSourceData() {
    const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
    for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
    throw new Error('Mod Tools source_data not found.');
}

const ROSTER = ['t6_fiveseven', 's1_rw1', 't5_ak74u', 's1_asm1', 's4_ppsh41', 't6_ak47', 't6_galil', 's1_ae4', 's1_mk14', 't6_m60', 't6_rpd', 's1_tac19', 't6_olympia', 't8_paladin_hb50', 's1_mors', 't6_chicom_cqb'];
const DAMAGE_REENCODE = [{ prefix: 't8_paladin_hb50_up', value: '2000' }];

// read the headshot-excluded set from the GSC (single source of truth)
const DMG_GSC = path.join(__dirname, '..', 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_damage.gsc');
const excluded = new Set();
{
    const gsc = fs.readFileSync(DMG_GSC, 'utf8');
    const fn = gsc.slice(gsc.indexOf('function is_weapon_headshot_excluded'));
    const body = fn.slice(0, fn.indexOf('\n}'));
    let m; const re = /name\s*==\s*"([^"]+)"\s*\)\s*return\s+true/g;
    while ((m = re.exec(body)) !== null) excluded.add(m[1]);
}

function rosterKeyFor(blockName) {
    for (const k of ROSTER) if (blockName === k || blockName.indexOf(k + '_') === 0) return k;
    return null;
}
function locTarget(field, isExcluded) {
    if (!field.startsWith('loc')) return null;
    if (field === 'locGun' || field === 'locNone') return null;
    if (field === 'locHead' || field === 'locHelmet') return isExcluded ? '1.0' : '5.0';
    return '1.0';
}
function dmgTarget(blockName) {
    for (const d of DAMAGE_REENCODE) if (blockName.indexOf(d.prefix) === 0) return d.value;
    return null;
}

const HEADER = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;
const FIELD = /^(\s*"([a-zA-Z0-9]+)"\s+")([^"]*)("\s*)$/;

const SD = findSourceData();
let totalChanged = 0, gunsTouched = {};
for (const gdtName of fs.readdirSync(SD)) {
    if (!gdtName.endsWith('.gdt')) continue;
    const GDT = path.join(SD, gdtName);
    const lines = fs.readFileSync(GDT, 'utf8').split(/\r?\n/);
    let key = null, blockName = null, isExq = false, changed = 0;
    for (let i = 0; i < lines.length; i++) {
        const h = lines[i].match(HEADER);
        if (h) { blockName = h[1]; key = rosterKeyFor(blockName); isExq = key ? excluded.has(key) : false; continue; }
        if (!key) continue;
        const m = lines[i].match(FIELD);
        if (!m) continue;
        const field = m[2];
        let target = locTarget(field, isExq);
        if (target === null && field === 'damage') target = dmgTarget(blockName);
        if (target !== null && target !== m[3]) { lines[i] = m[1] + target + m[4]; changed++; gunsTouched[key] = (gunsTouched[key] || 0) + 1; }
    }
    if (changed > 0) {
        const bak = GDT + '.acc-gunloc-bak';
        if (!fs.existsSync(bak)) fs.copyFileSync(GDT, bak);
        fs.writeFileSync(GDT, lines.join('\n'));
        console.log(`${gdtName}: ${changed} field(s) normalized`);
        totalChanged += changed;
    }
}
console.log(`\nnormalize_gun_loc: ${totalChanged} fields across ${Object.keys(gunsTouched).length} guns:`);
for (const k of Object.keys(gunsTouched)) console.log(`  ${k}${excluded.has(k) ? ' (excluded->1.0)' : ' ->5.0'}: ${gunsTouched[k]}`);
console.log('NEXT: gdtdb /update + build; verify with node tools/audit_gun_damage.js');
