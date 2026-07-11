// =============================================================================
// reduce_ammo.js - GLOBAL gun magazine + reserve ammo cut of 30% (user 2026-06-15).
//
// In BO3 GDTs `maxAmmo`/`startAmmo` are reserve MAGAZINE counts (6-12), so the in-game
// reserve = maxAmmo x clipSize. Reducing clipSize by 30% therefore drops BOTH the mag
// (clipSize) AND the reserve (maxAmmo x clipSize) by 30% in one edit - and the Armory
// +25% "ammo" twin (maxAmmo x1.25) then yields +25% of the REDUCED reserve automatically.
//
// SCOPE (GLOBAL ARCHITECTURE): EVERY weapon entry in every gun GDT - base AND PaP (`_up`)
// AND all recoil/reload twins (base- and _up-form). The 30% applies uniformly so
// PaP keeps its relative ammo edge but the whole economy is 30% tighter, and any twin the
// held gun swaps to (Deadshot/Speed Cola) carries the same reduced mag.
// NOTE 2026-07-04: the fastfire (Gun Slinger) + ammo (Armory) twin axes were removed; any
// *_acc_fastfire* / *_acc_ammo* keys still listed in the tables below are now INERT (they
// match no GDT entry, so the tool simply skips them - harmless, not worth pruning).
// FACTOR = 0.70 (round nearest, min 1). (Stock weapons - the laststand pistol_standard,
// knife, grenades - are not Skye GDTs and are not touched.)
//
// TWO SPECIAL CASES (added 2026-06-16, see MAXAMMO_WEAPONS / MAXAMMO_FIX below):
//   * Olympia (double-barrel, clipSize 2): clipSize is at its identity floor, so the 30%
//     reserve cut is applied to maxAmmo/startAmmo instead (clipSize x0.7 would make it 1 = a
//     single-barrel gun). Olympia + Galil were skipped when first added -> never reduced; fixed.
//   * PDW akimbo-PaP (`s1_pdw_rdw_up_zm`): Skye port shipped maxAmmo/startAmmo 920 (a data
//     error, 70-130x every peer) -> clamped to 18 mags (~300 reserve, in line with peers).
//
// TARGETED PER-GUN TUNING (CLIP_FIX / FIRETIME_FIX, user 2026-06-16): exact clip/fire-rate
// overrides for twin-less guns (AK-74u clip restore 20/40 = reserve 160/280; Nail Gun clip
// 30/40 + fire rate -25%). Damage retunes live in _acc_damage.gsc (acc_weapon_balance_mult).
//
// Idempotent: backs each GDT up to <gdt>.acc-ammo-orig on first run, and always reduces
// from that backup, so re-running yields 80% of the ORIGINAL (never compounds). REVERT =
// restore the .acc-ammo-orig files + gdtdb /update. Install-side (not repo-tracked); must
// run AFTER apply_recoil_overhaul.js (which rewrites the base GDTs). gdtdb + link after.
//
// Run from repo root:  node tools/reduce_base_ammo.js   (then gdtdb /update + linker)
// =============================================================================

const fs = require( "fs" );
const path = require( "path" );

const FACTOR = 0.70;

function findSourceData() {
    const roots = [
        "C:\\Program Files (x86)\\Steam\\steamapps\\common",
        "D:\\SteamLibrary\\steamapps\\common",
        "E:\\SteamLibrary\\steamapps\\common",
    ];
    for ( const r of roots ) {
        if ( !fs.existsSync( r ) ) continue;
        for ( const d of fs.readdirSync( r ) ) {
            if ( fs.existsSync( path.join( r, d, "bin", "modlauncher.exe" ) ) )
                return path.join( r, d, "source_data" );
        }
    }
    throw new Error( "Mod Tools source_data not found." );
}
const SD = findSourceData();

const GDTS = [
    "skye_t6_five-seven.gdt", "skye_s1_asm1.gdt", "skye_s1_tac-19.gdt", "skye_t6_ak47.gdt",
    "skye_s1_ae4.gdt", "skye_iw6_ripper.gdt", "skye_t8_paladin_hb50.gdt", "skye_s4_ppsh-41.gdt",
    "skye_t9_nail_gun.gdt", "skye_s1_pdw.gdt", "skye_s2_m1911.gdt", "skye_t5_ak74u.gdt",
    "skye_t6_olympia.gdt", "skye_t6_galil.gdt",                       // added 2026-06-16: were skipped at gun-add → never reduced. (t6_galil KEPT as the CW Grav graft SOURCE - its cut clip 25/35 is grafted onto t9_grav; the t9_grav TWINS are pinned via CLIP_FIX below.)
    "skye_t6_m60.gdt", "skye_t6_rpd.gdt",                             // added 2026-06-19: LMGs - native clip 100 / reserve 400-1000 was wildly over (user); CLIP_FIX + MAXAMMO_FIX below
    "skye_s1_rw1.gdt",                                                // added 2026-06-23: RW1 energy pistol (twinned). CLIP_FIX/MAXAMMO_FIX below hand-tune it to 8/12 (A-tier, docs/54) - NOT the x0.7 cut (the clip-1 single-shot original would floor to 1). Mahem launcher left uncut.
    "skye_s1_mk14.gdt",                                               // added 2026-06-24: MK14 AW DMR (twinned, B-tier). Plain x0.70 clip cut: base 20->14, PaP 17->12; reserve = maxAmmo x clip = 168 / 240. No CLIP_FIX needed.
    "skye_s1_mors.gdt",                                               // added 2026-06-24: MORS -> S tier. NOT cut before; now MAXAMMO_FIX lifts reserve 60/90 -> 120/180 (clip 1 stays 1). Twins live in acc_weapon_variants.gdt (below) and are fixed there.
    "acc_weapon_variants.gdt",
];

// Weapons whose clipSize is at a hard floor (double-barrel = 2 rounds): reducing clipSize would
// destroy the gun's identity (2 -> 1 = single barrel), so cut the reserve via maxAmmo/startAmmo
// (x FACTOR) and leave clipSize alone. Same net ~30% reserve cut, achieved on the only free lever.
// PREFIX match so it covers the base, _up, AND every perk twin (t6_olympia_acc_*, t6_olympia_up_acc_*)
// now that Olympia is a twin gun - else the twins' clip 2 would floor to 1 (single barrel). 2026-06-16.
function isMaxAmmoWeapon( weapon ) { return isdef( weapon ) && weapon.indexOf( "t6_olympia" ) === 0; }
function isdef( x ) { return x !== undefined && x !== null; }
// Strip the "_acc_<combo>" twin suffix to get the base/up stem (so CLIP_FIX covers a gun's twins).
function stemOf( w ) { return isdef( w ) ? w.split( "_acc" )[ 0 ] : w; }

// Outlier data-error clamps (NOT a x FACTOR reduction): the Skye PDW akimbo-PaP port shipped
// maxAmmo/startAmmo 920 (70-130x every peer; the m1911 akimbo PaP uses 10). Force a sane reserve
// in line with the other PaP guns (~300 rounds = clipSize 17 x ~18 mags). Keyed by weapon entry name.
const MAXAMMO_FIX = {
    "s1_pdw_rdw_up_zm": 18,
    // LMGs: 4 magazines. With the CLIP_FIX below: M60 4x100=400 base / 4x120=480 PaP; RPD 4x60=240 / 4x100=400.
    "t6_m60": 4, "t6_m60_up": 4, "t6_rpd": 4, "t6_rpd_up": 4,
    // Five-Seven -> C (user 2026-06-21): drop the STARTER's reserve 6->4 mags (clip 14 -> reserve 84->56) to
    // push its tier score under B. Keeps clip intact for the early game; you ditch it for a box gun soon anyway.
    "t6_fiveseven": 4,
    // Tac-19 nerf (user 2026-06-21): reserve -25% (12->9 mags: base 4x9=36, PaP 7x9=63). Paired with the -9%
    // damage nerf in _acc_damage to bring it to the low-S floor WITHOUT cutting the clip (clip 4->3 would also
    // crater the reserve and drop it to A+). NOTE: perk twins keep their cloned maxAmmo (minor, only when a
    // Mega twin is active); the base/_up forms are the ones that matter for the rating.
    "s1_tac19": 9, "s1_tac19_up": 9,
    // RW1 reserve (user 2026-06-23): with CLIP_FIX 8/12 -> 7x8 = 56 base / 8x12 = 96 PaP. Hand-tuned A-tier.
    "s1_rw1": 7, "s1_rw1_up": 8,
    // MORS reserve: CUT 50% (2026-06-25) 120/180->60/90; NERF -20% (2026-06-26) ->48/72;
    // NERF -15% (user 2026-06-27) -> 41/61 (clip 1, so maxAmmo == reserve rounds). Applied to base + _up + ALL 14
    // perk twins so EVERY form carries the same reserve (else a Deadshot/Mega twin swap would clamp it). Twins live
    // in acc_weapon_variants.gdt. NOTE: compute_gun_tiers.js FORCEs MORS to TOP/S (premium PaP price + 3% box rarity).
    "s1_mors": 41, "s1_mors_up": 61,
    "s1_mors_acc_fastreload": 41, "s1_mors_acc_fastfire": 41, "s1_mors_acc_fastfire_fastreload": 41,
    "s1_mors_acc_recoil50": 41, "s1_mors_acc_recoil50_fastreload": 41, "s1_mors_acc_recoil50_fastfire": 41,
    "s1_mors_acc_recoil50_fastfire_fastreload": 41,
    "s1_mors_up_acc_fastreload": 61, "s1_mors_up_acc_fastfire": 61, "s1_mors_up_acc_fastfire_fastreload": 61,
    "s1_mors_up_acc_recoil50": 61, "s1_mors_up_acc_recoil50_fastreload": 61, "s1_mors_up_acc_recoil50_fastfire": 61,
    "s1_mors_up_acc_recoil50_fastfire_fastreload": 61,
    // Paladin reserve NERF -15% (user 2026-06-27): maxAmmo 12 -> 10 (reserve = maxAmmo x clip: base 10x8=80, PaP
    // 10x11=110; was 96/132). clip stays 8/11 (CLIP_FIX above). Closest even integer-mag cut to -15% (10.2 -> 10 =
    // -16.7%). Exact-match so EVERY form is listed (twins in acc_weapon_variants.gdt, all native maxAmmo 12).
    "t8_paladin_hb50": 10, "t8_paladin_hb50_up": 10,
    "t8_paladin_hb50_acc_fastreload": 10, "t8_paladin_hb50_acc_fastfire": 10, "t8_paladin_hb50_acc_fastfire_fastreload": 10,
    "t8_paladin_hb50_acc_recoil50": 10, "t8_paladin_hb50_acc_recoil50_fastreload": 10, "t8_paladin_hb50_acc_recoil50_fastfire": 10,
    "t8_paladin_hb50_acc_recoil50_fastfire_fastreload": 10,
    "t8_paladin_hb50_up_acc_fastreload": 10, "t8_paladin_hb50_up_acc_fastfire": 10, "t8_paladin_hb50_up_acc_fastfire_fastreload": 10,
    "t8_paladin_hb50_up_acc_recoil50": 10, "t8_paladin_hb50_up_acc_recoil50_fastreload": 10, "t8_paladin_hb50_up_acc_recoil50_fastfire": 10,
    "t8_paladin_hb50_up_acc_recoil50_fastfire_fastreload": 10,
    // WARN (2026-06-27): the .acc-ammo-orig backups are STALE re: Paladin locHead/locHelmet 5.0 (fix_paladin_loc.js)
    // and MORS _up damage 1500 / minDamage 750 (PaP-form tuning) - both tools ran AFTER reduce last snapshotted. A
    // blind re-run REVERTS them (whole-file rewrite from backup). This -15% reserve nerf was therefore applied
    // SURGICALLY to the live maxAmmo/startAmmo (not via a re-run). Before re-running reduce: refresh those backup
    // fields (or re-apply fix_paladin_loc.js + the MORS PaP tuning AFTER). See CHANGELOG 2026-06-27.
};

// Targeted per-gun clip/fire-rate tuning (user 2026-06-16) - EXACT values keyed by weapon entry
// name, applied INSTEAD of the x FACTOR clip cut (CLIP_FIX) or on top (FIRETIME_FIX). Both these
// guns are TWIN-LESS (not in acc_weapon_variants.gdt), so editing the base GDT covers every form.
//   * AK-74u: restored to its pre-cut clip (20 base / 40 PaP); with maxAmmo 8/7 that is reserve
//     160/280 - i.e. exempt from the 30% ammo cut (user wanted it "back to 20, reserve 160").
//   * Nail Gun: clip bumped to 30 base / 40 PaP, and fire rate cut -25% (RPM x0.75 = fireTime
//     / 0.75: 0.118 -> 0.157 base, 0.10 -> 0.133 PaP). Its -15% AR damage is in _acc_damage.gsc.
const CLIP_FIX = {
    "t5_ak74u": 20, "t5_ak74u_up_zm": 40,
    // Nail Gun clip 30->40 / PaP 40->50 (user 2026-06-21): a non-DPS lever to push it to S tier
    // (with the reload buff below). Reserve rises with it (maxAmmo 7/8 unchanged): base ~280, PaP ~400.
    "t9_nail_gun": 40, "t9_nail_gun_up": 50,
    // PPSH-41 (user 2026-06-21: +5 clip; user 2026-06-24: +10 MORE = all-around buff paired with the +20%
    // damage in _acc_damage). Base + PaP + their perk twins inherit via stemOf. Was the global x0.70 cut
    // (25/39), then 30/44; now 40 / 54. Reserve rises with it (reserve = maxAmmo mags x clipSize, maxAmmo 9
    // unchanged): base 9x40=360, PaP 9x54=486.
    "s4_ppsh41_base": 40, "s4_ppsh41_base_up": 54,
    // Tac-19 clip 4->3 / PaP 7->6 (user 2026-06-21): the final all-around nerf. Drops it out of S to A+
    // (clip is part of what held it in S, and reserve follows: with MAXAMMO_FIX 9, base 3x9=27, PaP 6x9=54).
    "s1_tac19": 3, "s1_tac19_up": 6,
    // M60 clip 60->100 / PaP 100->120 (user 2026-06-21): traded for the DPS cut so M60 stays S on clip+reserve.
    // RPD clip+reserve BUFF +25% (user 2026-06-26): 60/100 -> 75/125. Stem-matched -> base + _up + ALL twins;
    // with MAXAMMO_FIX 4 mags (also on the twins, all native 4), reserve scales too: 4x75=300 base, 4x125=500 PaP
    // (was 240/400). M60: base 4x100=400, PaP 4x120=480 reserve, unchanged.
    "t6_m60": 100, "t6_m60_up": 120, "t6_rpd": 75, "t6_rpd_up": 125,
    // CW (t9) ports (user 2026-06-26): keep the SAME grafted ammo as the BO1/BO2 originals they replaced.
    // PIN their twins so the global x0.70 cut does NOT re-cut the already-correct grafted clips (the base forms
    // live in the t9 GDTs which are NOT scanned; these stem-matched entries cover the t9_*_acc_* twins in the
    // variants GDT). Values == the grafted base clips: ak47 21/31, ak74u 20/40, m60 100/120, rpd 75/125.
    "t9_ak47": 21, "t9_ak47_up": 31, "t9_ak74u": 20, "t9_ak74u_up": 40,
    "t9_m60": 100, "t9_m60_up": 120, "t9_rpd": 75, "t9_rpd_up": 125,
    // Grav (CW t9_grav, MIGRATED FROM Galil t6_galil 2026-07-05): pin the twins to the GRAFTED Galil clips
    // (base 25 / PaP 35 - the already-cut Galil values graft_cw_weapon_stats copied onto t9_grav). The base
    // t9_grav GDT is NOT in GDTS (graft brought the cut clip), so this only covers the t9_grav_acc_* twins in
    // the variants GDT - without the pin the global x0.70 cut would shrink them 25->18 / 35->25 below the base.
    "t9_grav": 25, "t9_grav_up": 35,
    // Paladin clip 4->8 / PaP 7->11 (user 2026-06-21): bigger sniper mag to lift it to low S (with its
    // single-target DPS). Reserve rises with it (maxAmmo 12 unchanged): base 8x12=96, PaP 11x12=132.
    "t8_paladin_hb50": 8, "t8_paladin_hb50_up": 11,
    // RW1 (user 2026-06-23): a REAL magazine - 8 base / 12 PaP - so the directed-energy pistol earns A-tier
    // (docs/54). ABSOLUTE (not the x0.7 cut: the clip-1 single-shot original would floor to 1). Covers base +
    // _up + twins via stemOf. Replaces the standalone tools/buff_rw1_stats.js (removed). Reserve via MAXAMMO_FIX.
    "s1_rw1": 8, "s1_rw1_up": 12,
    // Chicom CQB (user 2026-06-25): NOT cut - pin clip to its native 36 / 56 so the TWINS (in
    // acc_weapon_variants.gdt) match the uncut base. skye_t6_chicom_cqb.gdt is deliberately NOT in GDTS above
    // (base/up stay 36/56), but the twins live in the variants GDT which IS scanned - without this pin they
    // default-cut to 25/39 and a perk twin would SHRINK the mag. Generous ammo is part of why it's the S+
    // top-3 gun (docs/54). maxAmmo 5/8 unchanged -> reserve 180/448 everywhere.
    "t6_chicom_cqb": 36, "t6_chicom_cqb_up": 56,
};
const FIRETIME_FIX = {
    // Nail Gun: base -25% RoF (0.157). PaP _up MATCHED to base (user 2026-06-21, was 0.133) so PaP
    // changes ONLY damage/clip/reserve, not fire rate - part of the "keep base behavior" de-explosive.
    "t9_nail_gun": "0.157", "t9_nail_gun_up": "0.157",
};

// Reload-time overrides (seconds), keyed by weapon entry. Nail Gun 2.6 -> 2.0 (user 2026-06-21): a
// non-DPS lever to lift it to S tier without buffing damage. Sets both reloadTime + reloadEmptyTime.
const RELOAD_FIX = {
    "t9_nail_gun": "2.0", "t9_nail_gun_up": "2.0",
};

// Weapons whose projectile EXPLOSION fields get zeroed (user 2026-06-21). The Nail Gun PaP (_up) shipped
// an explosive transform (explosionInnerDamage 1300 / Outer 1000 / Radius 144) the user disliked: keep the
// base NAIL behavior the whole time so PaP only upgrades damage/clip/reserve. Base already has 0. Durable
// here (re-applied from the .acc-ammo-orig backup every run) instead of a hand-edit that a re-run would revert.
const EXPLOSION_ZERO = { "t9_nail_gun_up": true };

const HEADER   = /^\s*"([^"]+)"\s*\(\s*"([a-z]*weapon)\.gdf"\s*\)/;   // "name" ( "bulletweapon.gdf" )
const CLIP     = /^(\s*"clipSize"\s+")(\d+)("\s*)$/;
const MAXAMMO  = /^(\s*"(?:maxAmmo|startAmmo)"\s+")(\d+)("\s*)$/;      // reserve = maxAmmo x clipSize
const FIRETIME = /^(\s*"fireTime"\s+")([\d.]+)("\s*)$/;               // seconds/shot; RPM = 60/fireTime
const RELOAD   = /^(\s*"(?:reloadTime|reloadEmptyTime)"\s+")([\d.]+)("\s*)$/;  // seconds
const EXPLODE  = /^(\s*"(?:explosionInnerDamage|explosionOuterDamage|explosionRadius)"\s+")([\d.]+)("\s*)$/;  // projectile AoE

let totalChanged = 0;
const report = [];

for ( const name of GDTS ) {
    const gdt = path.join( SD, name );
    if ( !fs.existsSync( gdt ) ) { report.push( `  SKIP (missing): ${name}` ); continue; }

    const backup = gdt + ".acc-ammo-orig";
    if ( !fs.existsSync( backup ) ) fs.copyFileSync( gdt, backup );   // first run: snapshot original
    const src = fs.readFileSync( backup, "utf8" );                    // always reduce FROM original

    const lines = src.split( /\r?\n/ );
    let changed = 0;
    let weapon = null;   // track current weapon block so maxAmmo edits are per-weapon
    for ( let i = 0; i < lines.length; i++ ) {
        const h = lines[ i ].match( HEADER );
        if ( h ) { weapon = h[ 1 ]; continue; }

        // clipSize: a CLIP_FIX override wins; else reduce x FACTOR (except double-barrel floor).
        // CLIP_FIX is matched on the STEM (strip the "_acc_<combo>" twin suffix) so a fixed gun's
        // twins inherit the same clip as its base/up form (else AK-74u twins would drop 20->14).
        const c = lines[ i ].match( CLIP );
        if ( c ) {
            const orig = parseInt( c[ 2 ], 10 );
            let val = null;
            if ( CLIP_FIX[ stemOf( weapon ) ] !== undefined ) val = CLIP_FIX[ stemOf( weapon ) ];
            else if ( !isMaxAmmoWeapon( weapon ) ) { val = Math.round( orig * FACTOR ); if ( val < 1 ) val = 1; }
            if ( val !== null && val !== orig ) { lines[ i ] = c[ 1 ] + val + c[ 3 ]; changed++; }
            continue;
        }

        // maxAmmo/startAmmo: only edited for the floor weapons (x FACTOR) or the outlier-fix weapons.
        const m = lines[ i ].match( MAXAMMO );
        if ( m ) {
            const orig = parseInt( m[ 2 ], 10 );
            let val = null;
            if ( MAXAMMO_FIX[ weapon ] !== undefined && orig > 0 ) val = MAXAMMO_FIX[ weapon ];
            else if ( isMaxAmmoWeapon( weapon ) ) { val = Math.round( orig * FACTOR ); if ( val < 1 ) val = 1; }
            if ( val !== null && val !== orig ) { lines[ i ] = m[ 1 ] + val + m[ 3 ]; changed++; }
            continue;
        }

        // fireTime: exact FIRETIME_FIX override (fire-rate retune; e.g. Nail Gun -25% RoF).
        const ft = lines[ i ].match( FIRETIME );
        if ( ft && FIRETIME_FIX[ weapon ] !== undefined ) {
            const val = FIRETIME_FIX[ weapon ];
            if ( val !== ft[ 2 ] ) { lines[ i ] = ft[ 1 ] + val + ft[ 3 ]; changed++; }
            continue;
        }

        // reload override (e.g. Nail Gun 2.6 -> 2.0 to reach S without a DPS buff).
        const rl = lines[ i ].match( RELOAD );
        if ( rl && RELOAD_FIX[ weapon ] !== undefined ) {
            const val = RELOAD_FIX[ weapon ];
            if ( val !== rl[ 2 ] ) { lines[ i ] = rl[ 1 ] + val + rl[ 3 ]; changed++; }
            continue;
        }

        // explosion zero: kill the projectile AoE for de-explosived weapons (Nail Gun PaP _up).
        const ex = lines[ i ].match( EXPLODE );
        if ( ex && EXPLOSION_ZERO[ weapon ] && ex[ 2 ] !== "0" ) {
            lines[ i ] = ex[ 1 ] + "0" + ex[ 3 ]; changed++;
        }
    }
    fs.writeFileSync( gdt, lines.join( "\n" ) );
    totalChanged += changed;
    report.push( `  ${name}: ${changed} ammo fields adjusted (clipSize x${FACTOR}; olympia/pdw via maxAmmo)` );
}

console.log( `reduce_base_ammo: ${totalChanged} clipSize fields reduced x${FACTOR} across ${GDTS.length} GDTs` );
report.forEach( ( r ) => console.log( r ) );
console.log( "\nNEXT: run gdtdb /update, then the linker. REVERT = restore *.acc-ammo-orig + gdtdb." );
