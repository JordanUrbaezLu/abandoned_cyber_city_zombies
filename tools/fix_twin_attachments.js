#!/usr/bin/env node
// fix_twin_attachments.js [--audit] - re-sync every weapon TWIN's ATTACHMENT slots to its CURRENT base.
//
// The twins in source_data/acc_weapon_variants.gdt are clones of their base weapon GDT blocks (the perk-handling
// recoil/fast-fire/fast-reload/fast-swap + PaP variants). gen_weapon_variant_gdt.js copies the base block
// VERBATIM - but for the Cold War (t9) ports the magazine attachment (attachViewModel5/attachWorldModel5 =
// wpn_t9_<gun>_mag_view/world) was wired into the base AFTER the twins were cloned, so the twins carry EMPTY mag
// slots and render WITHOUT a magazine. Visible as "missing parts of the model" - user 2026-06-28: RPD held, and
// M60 "on reload" (a fast-reload twin swaps in for the reload anim, so the mag vanishes mid-reload). All 4 CW
// guns (ak47/ak74u/m60/rpd) are affected; some skye twins also drifted (e.g. galil world-mag emptied).
//
// FIX: read each base's attach slots (attachViewModelN/attachWorldModelN/defaultAttachment) from the INSTALLED
// base GDTs and overwrite every twin's slots to match. STAT fields are never touched. The base name is derived
// from the twin name (strip _acc_<suffix>), so t9_rpd_acc_* -> base t9_rpd and t9_rpd_up_acc_* -> base t9_rpd_up.
// --audit reports the mismatches without writing.  After a real run: the GDT is already in the install copy ->
// run `gdtdb /update`, then build.
'use strict';
const fs = require('fs'), path = require('path');
const AUDIT = process.argv.includes('--audit');
const TOOLS = 'C:/Program Files (x86)/Steam/steamapps/common/Call of Duty Black Ops III 455130';
const SRC = path.join(TOOLS, 'source_data');
const VARIANTS = 'source_data/acc_weapon_variants.gdt';

const DECL_RE   = /^\s*"([A-Za-z0-9_]+)" \( "bulletweapon\.gdf" \)/;
const ATTACH_RE = /^(\s*)"(attachViewModel\d+|attachWorldModel\d+|defaultAttachment)"\s+"([^"]*)"/;

// 1) scan the base GDTs (source_data root = skye_*.gdt, + t9_weapons = CW) -> asset -> { attachKey: value }
function gdtsIn( dir ) { return fs.existsSync( dir ) ? fs.readdirSync( dir ).filter( f => f.endsWith( '.gdt' ) ).map( f => path.join( dir, f ) ) : []; }
const baseAttach = {};
for ( const gdt of [ ...gdtsIn( SRC ), ...gdtsIn( path.join( SRC, 't9_weapons' ) ) ] ) {
    let text; try { text = fs.readFileSync( gdt, 'utf8' ); } catch ( e ) { continue; }
    if ( !text.includes( '"bulletweapon.gdf"' ) ) continue;
    let cur = null;
    for ( const ln of text.split( /\r?\n/ ) ) {
        const d = ln.match( DECL_RE );
        if ( d ) { cur = d[ 1 ]; if ( !baseAttach[ cur ] ) baseAttach[ cur ] = {}; continue; }
        if ( !cur ) continue;
        const a = ln.match( ATTACH_RE );
        if ( a ) baseAttach[ cur ][ a[ 2 ] ] = a[ 3 ];
    }
}

// 2) walk the variants GDT; set each twin's attach slots to its base's values
let lines = fs.readFileSync( VARIANTS, 'utf8' ).split( /\r?\n/ );
let base = null, changes = 0;
const perGun = {}, perKey = {}, samples = [], missing = new Set();
for ( let i = 0; i < lines.length; i++ ) {
    const d = lines[ i ].match( DECL_RE );
    if ( d ) { base = d[ 1 ].replace( /_acc_.*$/, '' ); if ( !baseAttach[ base ] ) { missing.add( base ); base = null; } continue; }
    if ( !base ) continue;
    const a = lines[ i ].match( ATTACH_RE );
    if ( !a ) continue;
    const want = baseAttach[ base ][ a[ 2 ] ];
    if ( want === undefined || want === a[ 3 ] ) continue;
    const gun = base.replace( /_up$/, '' );
    perGun[ gun ] = ( perGun[ gun ] || 0 ) + 1;
    perKey[ a[ 2 ] ] = ( perKey[ a[ 2 ] ] || 0 ) + 1;
    if ( samples.length < 14 ) samples.push( `    ${base}  ${a[ 2 ]}: "${a[ 3 ]}" -> "${want}"` );
    if ( !AUDIT ) lines[ i ] = `${a[ 1 ]}"${a[ 2 ]}" "${want}"`;
    changes++;
}
if ( !AUDIT ) fs.writeFileSync( VARIANTS, lines.join( '\n' ) );

console.log( `[twin-attach] ${AUDIT ? 'AUDIT (no write)' : 'FIXED'}: ${changes} attach field(s) ${AUDIT ? 'differ from base' : 'synced to base'}` );
console.log( '  per gun:', JSON.stringify( perGun ) );
console.log( '  per key:', JSON.stringify( perKey ) );
if ( samples.length ) { console.log( '  samples:' ); samples.forEach( s => console.log( s ) ); }
if ( missing.size ) console.log( `  (no base GDT found for: ${[ ...missing ].join( ', ' )})` );
