// =============================================================================
// gun_maxscale_table.js - per-gun MAX-SCALE damage table (user 2026-06-25):
// "damage per shot, damage per headshot, and DPS for each gun FULLY PaP'd and
// FULLY OVERCLOCKED" - the scale where balance outliers are easy to eyeball.
//
// SINGLE SOURCE OF TRUTH (no hardcoded damage):
//   - gamedata/weapons/zm/zm_levelcommon_weapons.csv : the live gun roster + class
//   - scripts/.../_acc_damage.gsc : ACC_GLOBAL_DMG_MULT, ACC_HEADSHOT_MULT,
//       ACC_OC_DMG_PER_TIER, acc_weapon_balance_mult(), is_weapon_headshot_excluded()
//   - scripts/.../_acc_pap_levels.gsc : ACC_PAP_MAX_TIER (+ the ladder is +33.3%/tier)
//   - install source_data/*.gdt : each gun's _up `damage`, locHead, fireTime,
//       shotCount, fireType, burstCount, burstFireDelay
//
// MODEL (regular zombie, fully PaP T3 + Weapon Overclock T10, NO perks/cyberware -
// those add MORE on top but UNIFORMLY, so they don't change the per-gun outliers).
// From on_ai_damage's additive-bonus model (bonus_factor = literal SUM of layers):
//   bonusFactor = papLadder(3) + (1 + ocTier*ocPerTier)         // PaP + OC flat-dmg layer
//   perShot(body) = round( upDmg            * bonusFactor * balance * global )   // per pellet
//   perShot(head) = round( upDmg * locHead  * bonusFactor * hsFactor * balance * global )
//     hsFactor = headshot-excluded ? 1.0 : ACC_HEADSHOT_MULT(0.5); locHead from GDT.
//   shotDmg(body) = perShot(body) * pellets   // a full trigger pull (shotguns = N pellets)
//   DPS = shotDmg(body) * sustainedShotsPerSec
//     full-auto: 1/fireTime;  burst: burstCount / ((burstCount-1)*fireTime + burstFireDelay)
//     semi/charge: 1/fireTime is a THEORETICAL cap (real is trigger/charge limited) -> flagged.
//
// Run:  node tools/gun_maxscale_table.js
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const DMG_GSC = path.join(REPO, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_damage.gsc');
const PAP_GSC = path.join(REPO, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_pap_levels.gsc');
const CSV = path.join(REPO, 'gamedata', 'weapons', 'zm', 'zm_levelcommon_weapons.csv');

function findSourceData() {
    const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
    for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
    return null;
}

// ---- constants from the GSC ------------------------------------------------
const gsc = fs.readFileSync(DMG_GSC, 'utf8');
const pgsc = fs.readFileSync(PAP_GSC, 'utf8');
function def(src, name, dflt) { const m = src.match(new RegExp('#define\\s+' + name + '\\s+([0-9.]+)')); return m ? parseFloat(m[1]) : dflt; }
const GLOBAL = def(gsc, 'ACC_GLOBAL_DMG_MULT', 2.75);
const HS_MULT = def(gsc, 'ACC_HEADSHOT_MULT', 0.5);
const OC_PER_TIER = def(gsc, 'ACC_OC_DMG_PER_TIER', 0.10);
const OC_MAX_TIER = 10;                       // clamp widened 5->10 (CHANGELOG; clientfield 4-bit). +100% at T10.
const PAP_MAX = def(pgsc, 'ACC_PAP_MAX_TIER', 3);
const PAP_LADDER_T3 = 1.0 + PAP_MAX * (1 / 3);  // +33.3%/tier -> T3 ~= 1.9999
const OC_LAYER = 1.0 + OC_MAX_TIER * OC_PER_TIER; // T10 -> 2.0
const BONUS = PAP_LADDER_T3 + OC_LAYER;           // additive bonus sum (PaP + OC), ~3.9999

// balance mults + headshot-excluded set
const balance = {};
{ const fn = gsc.slice(gsc.indexOf('function acc_weapon_balance_mult')); const b = fn.slice(0, fn.indexOf('\n}'));
  const re = /IsSubStr\(\s*weapon_name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+([0-9.]+)/g; let m; while ((m = re.exec(b))) balance[m[1]] = parseFloat(m[2]); }
const excluded = new Set();
{ const fn = gsc.slice(gsc.indexOf('function is_weapon_headshot_excluded')); const b = fn.slice(0, fn.indexOf('\n}'));
  const re = /name\s*==\s*"([^"]+)"\s*\)\s*return\s+true/g; let m; while ((m = re.exec(b))) excluded.add(m[1]); }
function balanceFor(key) { let best = null; for (const k in balance) if (key.indexOf(k) === 0 || key === k) if (!best || k.length > best.length) best = k; return best ? balance[best] : null; }

// ---- GDT blocks ------------------------------------------------------------
const FIELDS = new Set(['damage', 'locHead', 'locHelmet', 'fireTime', 'shotCount', 'fireType', 'burstCount', 'burstFireDelay']);
const SD = findSourceData();
const blocks = {};
function scanGdt(dir) {                          // recurse: CW guns live in source_data\t9_weapons\*.gdt
    for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
        const p = path.join(dir, e.name);
        if (e.isDirectory()) { scanGdt(p); continue; }
        if (!e.name.endsWith('.gdt')) continue;
        const lines = fs.readFileSync(p, 'utf8').split(/\r?\n/);
        let cur = null;
        for (const ln of lines) {
            const h = ln.match(/^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/);
            if (h) { cur = h[1]; blocks[cur] = blocks[cur] || {}; continue; }
            if (!cur) continue;
            const fm = ln.match(/^\s*"([a-zA-Z0-9]+)"\s+"([^"]*)"/);
            if (fm && FIELDS.has(fm[1]) && blocks[cur][fm[1]] === undefined) blocks[cur][fm[1]] = fm[1] === 'fireType' ? fm[2] : parseFloat(fm[2]);
        }
    }
}
if (SD) scanGdt(SD);
function upBlock(key) { for (const n of [key + '_up', key + '_up_zm', key + '_base_up', key + '_base_up_zm']) if (blocks[n] && blocks[n].damage !== undefined) return blocks[n]; return null; }

// ---- roster from the CSV (always current) ----------------------------------
const GUN_CLASSES = new Set(['rifle', 'smg', 'pistol', 'shotgun', 'sniper', 'lmg']);
const NAMES = { t6_fiveseven: 'Five-Seven', s1_rw1: 'RW1', t5_ak74u: 'AK-74u', t6_chicom_cqb: 'Chicom CQB', s1_asm1: 'ASM1', s4_ppsh41_base: 'PPSH-41', t9_ak47: 'AK-47 (CW)', t9_ak74u: 'AK-74u (CW)', t9_m60: 'M60 (CW)', t9_rpd: 'RPD (CW)', t6_ak47: 'AK-47', s1_ae4: 'AE4', t6_galil: 'Galil', s1_mk14: 'MK14', t6_m60: 'M60', t6_rpd: 'RPD', s1_tac19: 'Tac-19', t6_olympia: 'Olympia', t8_paladin_hb50: 'Paladin HB50', s1_mors: 'MORS' };
const csv = fs.readFileSync(CSV, 'utf8').split(/\r?\n/).filter(l => l.trim());
const hdr = csv[0].split(',');
const iName = hdr.indexOf('weapon_name'), iClass = hdr.indexOf('class'), iBox = hdr.indexOf('in_box');
const roster = [];
for (const line of csv.slice(1)) {
    const c = line.split(',');
    const key = c[iName], cls = c[iClass];
    if (!GUN_CLASSES.has(cls)) continue;
    if (key === 'pistol_standard') continue;
    roster.push({ key, cls, d: NAMES[key] || key });
}

// ---- compute ---------------------------------------------------------------
const R = n => Math.round(n);
const rows = [], notes = [];
for (const g of roster) {
    const up = upBlock(g.key);
    const bal = balanceFor(g.key);
    if (!up) { notes.push(`${g.d} (${g.key}): no _up GDT block - skipped`); continue; }
    if (bal === null) notes.push(`${g.d} (${g.key}): NO balance mult match -> treated as UNCUT 1.0 (likely a roster/naming gap)`);
    const b = bal === null ? 1.0 : bal;
    const exq = excluded.has(g.key);
    const hsF = exq ? 1.0 : HS_MULT;
    const lh = up.locHead !== undefined ? up.locHead : 1.0;
    const pellets = up.shotCount && up.shotCount > 1 ? up.shotCount : 1;
    const ft = up.fireType || '';

    const perBody = up.damage * BONUS * b * GLOBAL;       // per pellet
    const perHead = up.damage * lh * BONUS * hsF * b * GLOBAL;
    const shotBody = perBody * pellets;                   // full trigger pull
    const shotHead = perHead * pellets;

    // sustained IN-MAG rate (ignores reload downtime), with realistic per-class ceilings so
    // semi/charge DPS isn't a fantasy 1/fireTime (the within-charge rate).
    let rate = null, rateNote = '';
    const fireTime = up.fireTime;
    if (fireTime && fireTime > 0) {
        if (/burst/i.test(ft) && up.burstCount > 1) {
            const cyc = (up.burstCount - 1) * fireTime + (up.burstFireDelay || 0);
            rate = up.burstCount / cyc; rateNote = `${up.burstCount}-brst`;
        } else if (/auto/i.test(ft)) {
            rate = 1 / fireTime; rateNote = 'auto';
        } else if (g.cls === 'sniper') {
            rate = Math.min(1 / fireTime, 1.2); rateNote = 'charge~';   // bolt/charge limited (~1.2/s)
        } else {
            rate = Math.min(1 / fireTime, 7.5); rateNote = 'semi~';     // trigger limited (~7.5/s)
        }
    }
    const dps = rate != null ? shotBody * rate : null;
    rows.push({ ...g, bal: b, upDmg: up.damage, lh, pellets, ft: ft || '?', rateNote,
        shotBody: R(shotBody), shotHead: R(shotHead), dps: dps != null ? R(dps) : null });
}

rows.sort((a, b) => b.shotHead - a.shotHead);   // sort by per-headshot = the cleanest comparable outlier signal

// ---- output ----------------------------------------------------------------
console.log(`\nMAX-SCALE damage  (fully PaP T${PAP_MAX} + Weapon Overclock T${OC_MAX_TIER}, regular zombie, no perks/cyberware)`);
console.log(`bonus factor = PaP ${PAP_LADDER_T3.toFixed(2)} + OC ${OC_LAYER.toFixed(2)} = ${BONUS.toFixed(2)}   |   global x${GLOBAL}   |   headshot temper x${HS_MULT}   |   boss per-hit cap 5000`);
console.log(`DMG/shot = a full trigger pull (shotguns x pellets, point-blank). DPS = IN-MAG sustained (ignores reload).\n`);
const H = ['Gun', 'Class', 'Fire', 'bal', 'pel', 'DMG/shot', 'DMG/head', 'DPS(in-mag)'];
const W = [14, 8, 8, 6, 4, 9, 9, 11];
const fmt = a => '| ' + a.map((x, i) => String(x).padEnd(W[i])).join(' | ') + ' |';
console.log(fmt(H));
console.log('|' + W.map(w => '-'.repeat(w + 2)).join('|') + '|');
for (const x of rows) console.log(fmt([x.d, x.cls, x.rateNote, x.bal, x.pellets, x.shotBody.toLocaleString(), x.shotHead.toLocaleString(), x.dps != null ? x.dps.toLocaleString() : '?']));
console.log('\nFire: auto=full-auto, N-brst=burst, semi~=trigger-capped ~7.5/s, charge~=bolt/charge-capped ~1.2/s.');
console.log('Per-shot/head are EXACT (GDT). DPS ignores reload (in-mag upper bound). Perks/Cyberware/abilities add MORE on top (uniform).');
if (notes.length) { console.log('\nNOTES:'); for (const n of notes) console.log('  - ' + n); }
console.log('');
