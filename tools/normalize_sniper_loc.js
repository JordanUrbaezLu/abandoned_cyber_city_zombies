// =============================================================================
// normalize_sniper_loc.js - force the STANDARD hit-location convention on BOTH
// sniper rips (MORS + Paladin), so headshots behave like every other box gun.
//
// WHY (user 2026-06-25): the two snipers' GDT loc* mults were inconsistent and
// wrong, so headshots were miscalculated - "one sniper does 8k while the other
// does 800". Root causes found in the install GDTs:
//   - Paladin (t8_paladin_hb50 + _up): loc ALL 1.0 incl. HEAD -> a headshot did
//     locHead(1.0) x map-headshot-factor(0.5) = 0.5x body. A headshot did HALF a
//     body shot. (The old docs/33 "all-1.0" Paladin fix never set the head tier.)
//   - MORS _up (PaP): limbs/hands still 9.0 - because normalize_mors_loc.js's LOC
//     map used WRONG field names (locRightArm vs the real locRightArmLower/Upper/
//     locRightHand), so it never touched the limbs. PaP MORS limb shots did 9x.
//
// CONVENTION (matches every stock box gun + the intended MORS head tier):
//   locHead / locHelmet      -> 5.0   (engine head mult; x our 0.5 factor = 2.5x body head)
//   every other loc* body    -> 1.0   (body = `damage`, the additive balance model holds)
//   locGun / locNone         -> left as-is (0 / 1)
// Per-gun strength stays governed by acc_weapon_balance_mult (MORS 0.66 S / Paladin
// 0.49 B) - so after this both headshots = 2.5x THAT gun's body, MORS still > Paladin
// by the intended tier gap, NOT a 10x loc accident.
//
// SAFE: edits the CURRENT install GDTs IN PLACE, loc fields ONLY - does NOT touch
// `damage`, recoil, or ammo (so it will NOT revert apply_recoil_overhaul.js /
// reduce_base_ammo.js, unlike re-running normalize_mors_loc.js which derives from
// .acc-loc-orig). Idempotent (re-running just re-sets the same values). Backs up
// each GDT once to .acc-snipeloc-bak. Install-side (GDTs aren't repo-tracked).
// Run:  node tools/normalize_sniper_loc.js   (then gdtdb /update + build)
// =============================================================================
'use strict';
const fs = require( "fs" );
const path = require( "path" );

function findSourceData() {
    const roots = [
        "C:\\Program Files (x86)\\Steam\\steamapps\\common",
        "D:\\SteamLibrary\\steamapps\\common",
        "E:\\SteamLibrary\\steamapps\\common",
        "C:\\Steam\\steamapps\\common",
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

// Which weapon blocks to normalize: any entry whose name starts with one of these
// (covers base, _up, and the box twins). Both snipers' GDTs.
const GDTS = [ "skye_s1_mors.gdt", "skye_t8_paladin_hb50.gdt" ];
const NAME_PREFIXES = [ "s1_mors", "t8_paladin_hb50" ];

const HEADER = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;
const FIELD  = /^(\s*"([a-zA-Z0-9]+)"\s+")([^"]*)("\s*)$/;

function targetFor( field ) {
    if ( !field.startsWith( "loc" ) ) return null;
    if ( field === "locGun" || field === "locNone" ) return null;   // leave 0 / 1
    if ( field === "locHead" || field === "locHelmet" ) return "5.0";
    return "1.0";   // every other body part
}

const SD = findSourceData();
let totalChanged = 0;
for ( const gdtName of GDTS ) {
    const GDT = path.join( SD, gdtName );
    if ( !fs.existsSync( GDT ) ) { console.log( `SKIP ${gdtName} (not installed)` ); continue; }
    const bak = GDT + ".acc-snipeloc-bak";
    if ( !fs.existsSync( bak ) ) fs.copyFileSync( GDT, bak );        // one-time safety snapshot

    const lines = fs.readFileSync( GDT, "utf8" ).split( /\r?\n/ );
    let weapon = null, inBlock = false, changed = 0;
    for ( let i = 0; i < lines.length; i++ ) {
        const h = lines[ i ].match( HEADER );
        if ( h ) { weapon = h[ 1 ]; inBlock = NAME_PREFIXES.some( p => weapon.startsWith( p ) ); continue; }
        if ( !inBlock ) continue;
        const m = lines[ i ].match( FIELD );
        if ( !m ) continue;
        const target = targetFor( m[ 2 ] );
        if ( target !== null && target !== m[ 3 ] ) { lines[ i ] = m[ 1 ] + target + m[ 4 ]; changed++; }
    }
    fs.writeFileSync( GDT, lines.join( "\n" ) );
    console.log( `${gdtName}: ${changed} loc field(s) normalized (head/helmet 5.0, body 1.0)` );
    totalChanged += changed;
}
console.log( `normalize_sniper_loc: ${totalChanged} total loc fields set. NEXT: gdtdb /update + build.` );
