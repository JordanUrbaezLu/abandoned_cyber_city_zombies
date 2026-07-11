// =============================================================================
// audit_gun_damage.js - recompute EVERY gun's effective per-shot damage from the
// live data (GSC balance mults + #defines, GDT damage + hit-location mults) and
// FLAG anomalies (user 2026-06-25: "run the guns through a script so this stuff
// can't happen"). Born from the MORS/Paladin headshot bug - inconsistent GDT
// locHead silently broke headshot scaling.
//
// SOURCES (single source of truth - no hardcoded damage numbers):
//   - scripts/.../_acc_damage.gsc : ACC_GLOBAL_DMG_MULT, ACC_HEADSHOT_MULT,
//     acc_weapon_balance_mult() per-gun mults, is_weapon_headshot_excluded() set.
//   - install source_data/*.gdt   : each gun's base + _up `damage`, locHead, locHelmet.
//
// MODEL (regular zombie, no perks/Cyberware, one shot), from on_ai_damage:
//   body     = round( damage      x balance x global )
//   headshot = round( damage x locHead x hsFactor x balance x global )
//            where hsFactor = ACC_HEADSHOT_MULT (0.5) for normal guns, but the
//            map's headshot BONUS is SKIPPED for headshot-excluded guns (b_headshot
//            = false) -> for those, hsFactor = 1.0 (engine locHead still applies!).
//   => head:body ratio = excluded ? locHead : (locHead x 0.5).
//      Standard locHead 5.0 -> 2.5x body. THAT is the convention; deviations are flagged.
//   PaP uses the _up `damage`; the PaP tier ladder is ADDITIVE into the bonus sum:
//      body_pap(tier) = round( up_damage x papLadder(tier) x balance x global )
//      head_pap(tier) = round( up_damage x locHead x (papLadder(tier) + hsBonus) x balance x global )
//      papLadder = {1:1.3333, 2:1.6666, 3:1.9999}; hsBonus = excluded?0:0.5.
//   (Deadshot/Cyberware/Overclock add MORE on top in-game - not modelled here; this
//    is the BASELINE per-shot so anomalies are comparable.)
// =============================================================================
'use strict';
const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const DMG_GSC = path.join(REPO, 'scripts', 'zm', 'zm_abandoned_cyber_city', '_acc_damage.gsc');

function findSourceData() {
    const roots = ['C:\\Program Files (x86)\\Steam\\steamapps\\common', 'D:\\SteamLibrary\\steamapps\\common', 'E:\\SteamLibrary\\steamapps\\common', 'C:\\Steam\\steamapps\\common'];
    for (const r of roots) { if (!fs.existsSync(r)) continue; for (const d of fs.readdirSync(r)) { if (fs.existsSync(path.join(r, d, 'bin', 'modlauncher.exe'))) return path.join(r, d, 'source_data'); } }
    return null;
}

// Display roster (weaponKey + class). Damage/loc come from the GDTs, balance from the GSC.
// 2026-07-02: synced to the SHIPPED roster (CW swaps t9_* replaced t6_ak47/t6_m60/t6_rpd/
// t5_ak74u; PPSH = the s4_ppsh41_base VG port). Thundergun + Action Figure are special-cased
// OUTSIDE this bullet model (weaponless fling DoDamage / one-knife melee) so they are not
// rows; the Mahem's projectile DIRECT hit does ride the model (splash is separate).
const ROSTER = [
    { d: 'Five-Seven',   w: 't6_fiveseven',     c: 'Pistol'  },
    { d: 'RW1',          w: 's1_rw1',           c: 'Pistol'  },
    { d: 'AK-74u',       w: 't9_ak74u',         c: 'SMG'     },
    { d: 'Chicom CQB',   w: 't6_chicom_cqb',    c: 'SMG'     },
    { d: 'ASM1',         w: 's1_asm1',          c: 'SMG'     },
    { d: 'PPSH-41',      w: 's4_ppsh41',        c: 'SMG'     },
    { d: 'AK-47',        w: 't9_ak47',          c: 'AR'      },
    { d: 'Grav',         w: 't9_grav',          c: 'AR'      },
    { d: 'AE4',          w: 's1_ae4',           c: 'AR'      },
    { d: 'MK14',         w: 's1_mk14',          c: 'DMR'     },
    { d: 'M60',          w: 't9_m60',           c: 'LMG'     },
    { d: 'RPD',          w: 't9_rpd',           c: 'LMG'     },
    { d: 'Mahem',        w: 's1_mahem',         c: 'Launcher' },
    { d: 'China Lake',   w: 't5_china_lake',    c: 'Launcher' },
    { d: 'War Machine',  w: 't6_war_machine',   c: 'Launcher' },
    { d: 'Tac-19',       w: 's1_tac19',         c: 'Shotgun' },
    { d: 'CEL-3',        w: 's1_cel3',          c: 'Shotgun' },
    { d: 'Olympia',      w: 't6_olympia',       c: 'Shotgun' },
    { d: 'Paladin HB50', w: 't8_paladin_hb50',  c: 'Sniper'  },
    { d: 'MORS',         w: 's1_mors',          c: 'Sniper'  },
];
const PAP_LADDER = { 1: 1.3333, 2: 1.6666, 3: 1.9999 };  // +33/67/100% (acc_pap_levels pap_tier_mult)
const STD_LOCHEAD = 5.0;   // the intended box-gun convention (-> 2.5x body headshot)
const CRAZY_PERSHOT = 5000; // per-shot ceiling: above this is past the boss per-hit cap (overkill vs trash,
                            // capped vs bosses) - flagged so "too crazy" per-shot numbers get CAUGHT (user 2026-06-25).

// ---- parse the GSC (single source of truth) --------------------------------
const gsc = fs.readFileSync(DMG_GSC, 'utf8');
function parseDefine(name, dflt) { const m = gsc.match(new RegExp('#define\\s+' + name + '\\s+([0-9.]+)')); return m ? parseFloat(m[1]) : dflt; }
const GLOBAL = parseDefine('ACC_GLOBAL_DMG_MULT', 2.5);
const HS_MULT = parseDefine('ACC_HEADSHOT_MULT', 0.5);

const balance = {};
{
    const fn = gsc.slice(gsc.indexOf('function acc_weapon_balance_mult'));
    const body = fn.slice(0, fn.indexOf('\n}'));
    const re = /IsSubStr\(\s*weapon_name,\s*"([^"]+)"\s*\)\s*\)\s*return\s+([0-9.]+)/g;
    let m; while ((m = re.exec(body)) !== null) balance[m[1]] = parseFloat(m[2]);
}
const excluded = new Set();
{
    const fn = gsc.slice(gsc.indexOf('function is_weapon_headshot_excluded'));
    const body = fn.slice(0, fn.indexOf('\n}'));
    const re = /name\s*==\s*"([^"]+)"\s*\)\s*return\s+true/g;
    let m; while ((m = re.exec(body)) !== null) excluded.add(m[1]);
}
function balanceFor(key) { for (const k in balance) if (key.indexOf(k) === 0 || key === k) return balance[k]; return 1.0; }

// ---- read the GDTs ---------------------------------------------------------
const SD = findSourceData();
let gdtBlocks = {};   // blockName -> {damage, locHead, locHelmet}
if (SD) {
    for (const f of fs.readdirSync(SD)) {
        if (!f.endsWith('.gdt')) continue;
        const lines = fs.readFileSync(path.join(SD, f), 'utf8').split(/\r?\n/);
        let cur = null;
        for (const ln of lines) {
            const h = ln.match(/^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/);
            if (h) { cur = h[1]; gdtBlocks[cur] = gdtBlocks[cur] || {}; continue; }
            if (!cur) continue;
            const fm = ln.match(/^\s*"([a-zA-Z0-9]+)"\s+"([^"]*)"/);
            if (fm && (fm[1] === 'damage' || fm[1] === 'locHead' || fm[1] === 'locHelmet'))
                if (gdtBlocks[cur][fm[1]] === undefined) gdtBlocks[cur][fm[1]] = parseFloat(fm[2]);
        }
    }
}
function block(key, up) {
    // suffix soup: some ports name the PaP form _up, some _up_zm, some _base_up (user 2026-06-25).
    const names = up
        ? [key + '_up', key + '_up_zm', key + '_base_up', key + '_base_up_zm']
        : [key, key + '_zm', key + '_base', key + '_base_zm'];
    for (const n of names) if (gdtBlocks[n] && gdtBlocks[n].damage !== undefined) return gdtBlocks[n];
    return null;
}

// ---- compute + flag --------------------------------------------------------
const rows = [], anomalies = [];
function r(n) { return Math.round(n); }
for (const g of ROSTER) {
    const bal = balanceFor(g.w), exq = excluded.has(g.w);
    const base = block(g.w, false), up = block(g.w, true);
    if (!base) { anomalies.push(`${g.d} (${g.w}): GDT base block NOT FOUND`); continue; }
    const dmg = base.damage, lh = base.locHead, lhm = base.locHelmet, updmg = up ? up.damage : null;
    const hsFactor = exq ? 1.0 : HS_MULT;
    const hsRatio = lh * hsFactor;
    const body = r(dmg * bal * GLOBAL);
    const head = r(dmg * lh * hsFactor * bal * GLOBAL);
    const pBody = updmg != null ? r(updmg * PAP_LADDER[3] * bal * GLOBAL) : null;
    // headshot temper is now a SEPARATE multiplicative factor (matches the on_ai_damage fix) -> PaP head
    // = PaP body x (locHead x hsFactor) = a clean 2.5x, NOT the old additive (ladder + 0.5) x locHead balloon.
    const pHead = updmg != null ? r(updmg * lh * PAP_LADDER[3] * hsFactor * bal * GLOBAL) : null;
    rows.push({ ...g, bal, dmg, lh, updmg, exq, body, head, hsRatio, pBody, pHead });

    // anomaly checks
    if (!exq && lh !== STD_LOCHEAD) anomalies.push(`${g.d}: locHead ${lh} (NON-STANDARD) -> headshot ${hsRatio.toFixed(2)}x body, expected ${(STD_LOCHEAD*HS_MULT).toFixed(1)}x`);
    if (exq && lh !== 1.0) anomalies.push(`${g.d}: headshot-EXCLUDED but locHead ${lh} -> heads still ${lh.toFixed(1)}x body (set locHead 1.0 for truly flat)`);
    if (lhm !== undefined && lhm !== lh) anomalies.push(`${g.d}: locHead ${lh} != locHelmet ${lhm} (head/helmet mismatch)`);
    if (hsRatio < 1.0) anomalies.push(`${g.d}: HEADSHOT WEAKER THAN BODY (${hsRatio.toFixed(2)}x) - locHead too low`);
    if (updmg != null && updmg <= dmg) anomalies.push(`${g.d}: PaP _up damage ${updmg} <= base ${dmg} (no GDT PaP boost; relies on tier ladder only)`);
    const peak = Math.max(body, head, pBody || 0, pHead || 0);
    if (peak > CRAZY_PERSHOT) anomalies.push(`${g.d}: per-shot peaks at ${peak} (> ${CRAZY_PERSHOT}) - past the boss per-hit cap; overkill vs trash, capped vs bosses`);
    if (updmg == null) anomalies.push(`${g.d}: no _up (PaP) GDT block found`);
    if (balance[g.w] === undefined && balanceFor(g.w) === 1.0) anomalies.push(`${g.d}: no acc_weapon_balance_mult entry -> default 1.0 (uncut!)`);
}

// ---- output ----------------------------------------------------------------
console.log(`\nGun damage audit  (global x${GLOBAL}, headshot mult ${HS_MULT}, PaP shown at MAX tier 3 x${PAP_LADDER[3].toFixed(2)})`);
console.log(`Source: _acc_damage.gsc + ${SD ? 'install GDTs' : 'GDTs NOT FOUND (damage cols blank)'}\n`);
const H = ['Gun', 'Class', 'bal', 'rawDmg', 'locHead', 'HS x', 'BODY', 'HEADSHOT', 'PaP BODY', 'PaP HEAD'];
const fmt = (a) => '| ' + a.map((x, i) => String(x).padEnd([12, 7, 5, 6, 7, 5, 6, 8, 8, 8][i])).join(' | ') + ' |';
console.log(fmt(H));
console.log('|' + H.map((_, i) => '-'.repeat([12, 7, 5, 6, 7, 5, 6, 8, 8, 8][i] + 2)).join('|') + '|');
for (const x of rows) console.log(fmt([x.d, x.c, x.bal, x.dmg, x.lh + (x.exq ? '*' : ''), x.hsRatio.toFixed(2), x.body, x.head, x.pBody ?? '?', x.pHead ?? '?']));
console.log('\n* = headshot-excluded (no map headshot bonus; engine locHead still applies)');
console.log('\n!! The "PaP BODY/HEAD" columns here are APPROXIMATE (base raw x a flat ladder) and can be WRONG:');
console.log('   the real PaP weapon is the GDT "_up" entry with its OWN raw damage (verified 2026-07-04). For');
console.log('   accurate PaP-form numbers use  node tools/gen_weapon_stats.js  (reads each _up entry live +');
console.log('   self-checks -> docs/41). The BODY/HEADSHOT (base, unpacked) columns above are correct.');
console.log('\nANOMALIES (' + anomalies.length + '):');
if (!anomalies.length) console.log('  none - all guns consistent.');
else for (const a of anomalies) console.log('  ⚠ ' + a);
console.log('');
