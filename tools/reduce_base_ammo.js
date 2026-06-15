// =============================================================================
// reduce_ammo.js - GLOBAL gun magazine + reserve ammo cut of 20% (user 2026-06-15).
//
// In BO3 GDTs `maxAmmo`/`startAmmo` are reserve MAGAZINE counts (6-12), so the in-game
// reserve = maxAmmo x clipSize. Reducing clipSize by 20% therefore drops BOTH the mag
// (clipSize) AND the reserve (maxAmmo x clipSize) by 20% in one edit - and the Armory
// +25% "ammo" twin (maxAmmo x1.25) then yields +25% of the REDUCED reserve automatically.
//
// SCOPE (GLOBAL ARCHITECTURE): EVERY weapon entry in every gun GDT - base AND PaP (`_up`)
// AND all recoil/fire/reload/ammo twins (base- and _up-form). The 20% applies uniformly so
// PaP keeps its relative ammo edge but the whole economy is 20% tighter, and any twin the
// held gun swaps to (Deadshot/Armory/Gun Slinger) carries the same reduced mag.
// FACTOR = 0.80 (round nearest, min 1). (Stock weapons - the laststand pistol_standard,
// knife, grenades - are not Skye GDTs and are not touched.)
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
    "acc_weapon_variants.gdt",
];

const HEADER = /^\s*"([^"]+)"\s*\(\s*"([a-z]*weapon)\.gdf"\s*\)/;   // "name" ( "bulletweapon.gdf" )
const CLIP   = /^(\s*"clipSize"\s+")(\d+)("\s*)$/;

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
    // clipSize is a weapon-only GDT field, so reduce EVERY clipSize line (all forms).
    for ( let i = 0; i < lines.length; i++ ) {
        const c = lines[ i ].match( CLIP );
        if ( !c ) continue;
        const orig = parseInt( c[ 2 ], 10 );
        let reduced = Math.round( orig * FACTOR );
        if ( reduced < 1 ) reduced = 1;
        if ( reduced !== orig ) {
            lines[ i ] = c[ 1 ] + reduced + c[ 3 ];
            changed++;
        }
    }
    fs.writeFileSync( gdt, lines.join( "\n" ) );
    totalChanged += changed;
    report.push( `  ${name}: ${changed} clipSize fields reduced x${FACTOR}` );
}

console.log( `reduce_base_ammo: ${totalChanged} clipSize fields reduced x${FACTOR} across ${GDTS.length} GDTs` );
report.forEach( ( r ) => console.log( r ) );
console.log( "\nNEXT: run gdtdb /update, then the linker. REVERT = restore *.acc-ammo-orig + gdtdb." );
