// =============================================================================
// reduce_ammo.js - GLOBAL gun magazine + reserve ammo cut of 30% (user 2026-06-15).
//
// In BO3 GDTs `maxAmmo`/`startAmmo` are reserve MAGAZINE counts (6-12), so the in-game
// reserve = maxAmmo x clipSize. Reducing clipSize by 30% therefore drops BOTH the mag
// (clipSize) AND the reserve (maxAmmo x clipSize) by 30% in one edit - and the Armory
// +25% "ammo" twin (maxAmmo x1.25) then yields +25% of the REDUCED reserve automatically.
//
// SCOPE (GLOBAL ARCHITECTURE): EVERY weapon entry in every gun GDT - base AND PaP (`_up`)
// AND all recoil/fire/reload/ammo twins (base- and _up-form). The 30% applies uniformly so
// PaP keeps its relative ammo edge but the whole economy is 30% tighter, and any twin the
// held gun swaps to (Deadshot/Armory/Gun Slinger) carries the same reduced mag.
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
    "skye_t6_olympia.gdt", "skye_t6_galil.gdt",                       // added 2026-06-16: were skipped at gun-add → never reduced
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
const MAXAMMO_FIX = { "s1_pdw_rdw_up_zm": 18 };

// Targeted per-gun clip/fire-rate tuning (user 2026-06-16) - EXACT values keyed by weapon entry
// name, applied INSTEAD of the x FACTOR clip cut (CLIP_FIX) or on top (FIRETIME_FIX). Both these
// guns are TWIN-LESS (not in acc_weapon_variants.gdt), so editing the base GDT covers every form.
//   * AK-74u: restored to its pre-cut clip (20 base / 40 PaP); with maxAmmo 8/7 that is reserve
//     160/280 - i.e. exempt from the 30% ammo cut (user wanted it "back to 20, reserve 160").
//   * Nail Gun: clip bumped to 30 base / 40 PaP, and fire rate cut -25% (RPM x0.75 = fireTime
//     / 0.75: 0.118 -> 0.157 base, 0.10 -> 0.133 PaP). Its -15% AR damage is in _acc_damage.gsc.
const CLIP_FIX = {
    "t5_ak74u": 20, "t5_ak74u_up_zm": 40,
    "t9_nail_gun": 30, "t9_nail_gun_up": 40,
};
const FIRETIME_FIX = {
    "t9_nail_gun": "0.157", "t9_nail_gun_up": "0.133",
};

const HEADER   = /^\s*"([^"]+)"\s*\(\s*"([a-z]*weapon)\.gdf"\s*\)/;   // "name" ( "bulletweapon.gdf" )
const CLIP     = /^(\s*"clipSize"\s+")(\d+)("\s*)$/;
const MAXAMMO  = /^(\s*"(?:maxAmmo|startAmmo)"\s+")(\d+)("\s*)$/;      // reserve = maxAmmo x clipSize
const FIRETIME = /^(\s*"fireTime"\s+")([\d.]+)("\s*)$/;               // seconds/shot; RPM = 60/fireTime

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
        }
    }
    fs.writeFileSync( gdt, lines.join( "\n" ) );
    totalChanged += changed;
    report.push( `  ${name}: ${changed} ammo fields adjusted (clipSize x${FACTOR}; olympia/pdw via maxAmmo)` );
}

console.log( `reduce_base_ammo: ${totalChanged} clipSize fields reduced x${FACTOR} across ${GDTS.length} GDTs` );
report.forEach( ( r ) => console.log( r ) );
console.log( "\nNEXT: run gdtdb /update, then the linker. REVERT = restore *.acc-ammo-orig + gdtdb." );
