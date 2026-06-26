// audit_gun_ammo.js - READ-ONLY. Compare each live gun GDT's clip/maxAmmo (base + _up)
// against its original backup (.acc-ammo-orig) to see whether the reduce_base_ammo.js
// 30% cut is actually applied in the LIVE GDTs (what gdtdb /update ships). 2026-06-23.
//   node tools/audit_gun_ammo.js
const fs = require( "fs" );
const path = require( "path" );

function findSourceData() {
    const roots = [ "C:\\Program Files (x86)\\Steam\\steamapps\\common", "D:\\SteamLibrary\\steamapps\\common", "E:\\SteamLibrary\\steamapps\\common" ];
    for ( const r of roots ) { if ( !fs.existsSync( r ) ) continue;
        for ( const d of fs.readdirSync( r ) ) if ( fs.existsSync( path.join( r, d, "bin", "modlauncher.exe" ) ) ) return path.join( r, d, "source_data" ); }
    throw new Error( "source_data not found" );
}
const SD = findSourceData();

// gun: [ gdtFile, baseEntry, upEntry, intendedBaseClip, intendedUpClip ]  (intended from reduce_base_ammo docs/05)
const GUNS = [
    [ "skye_t6_five-seven.gdt", "t6_fiveseven",    "t6_fiveseven_up",    "14", "?" ],
    [ "skye_s1_asm1.gdt",       "s1_asm1",         "s1_asm1_up",         "22", "?" ],
    [ "skye_s1_tac-19.gdt",     "s1_tac19",        "s1_tac19_up",        "3",  "6" ],
    [ "skye_t6_ak47.gdt",       "t6_ak47",         "t6_ak47_up",         "21", "?" ],
    [ "skye_s1_ae4.gdt",        "s1_ae4",          "s1_ae4_up",          "25", "?" ],
    [ "skye_t8_paladin_hb50.gdt","t8_paladin_hb50","t8_paladin_hb50_up", "8",  "11" ],
    [ "skye_s4_ppsh-41.gdt",    "s4_ppsh41_base",  "s4_ppsh41_base_up",  "30", "44" ],
    [ "skye_t5_ak74u.gdt",      "t5_ak74u",        "t5_ak74u_up_zm",     "20", "40" ],
    [ "skye_t6_olympia.gdt",    "t6_olympia",      "t6_olympia_up",      "2",  "2" ],
    [ "skye_t6_galil.gdt",      "t6_galil",        "t6_galil_up",        "~",  "~" ],
    [ "skye_t6_m60.gdt",        "t6_m60",          "t6_m60_up",          "100","120" ],
    [ "skye_t6_rpd.gdt",        "t6_rpd",          "t6_rpd_up",          "60", "100" ],
    [ "skye_s1_rw1.gdt",        "s1_rw1",          "s1_rw1_up",          "8",  "12" ],   // our buff
];

const HEADER = /^\s*"([^"]+)"\s*\(\s*"([a-z]*weapon)\.gdf"\s*\)/;
const CLIP   = /^\s*"clipSize"\s+"(\d+)"/;
const AMMO   = /^\s*"maxAmmo"\s+"(\d+)"/;

function parse( file, entries ) {
    const out = {};
    if ( !fs.existsSync( file ) ) return null;
    const lines = fs.readFileSync( file, "utf8" ).split( /\r?\n/ );
    let cur = null;
    for ( const ln of lines ) {
        const h = ln.match( HEADER ); if ( h ) { cur = h[ 1 ]; continue; }
        if ( !cur || !entries.includes( cur ) ) continue;
        const c = ln.match( CLIP ); if ( c && !( out[ cur ] && out[ cur ].clip ) ) { out[ cur ] = out[ cur ] || {}; out[ cur ].clip = +c[ 1 ]; continue; }
        const a = ln.match( AMMO ); if ( a && !( out[ cur ] && out[ cur ].max ) ) { out[ cur ] = out[ cur ] || {}; out[ cur ].max = +a[ 1 ]; }
    }
    return out;
}

console.log( "GUN AMMO AUDIT  (live GDT vs .acc-ammo-orig backup)  reserve = maxAmmo x clipSize\n" );
console.log( "Gun / entry            LIVE clip/max=reserve     ORIG clip/max=reserve     state" );
console.log( "---------------------  ------------------------  ------------------------  ---------------" );
let cutNotApplied = 0, noBackup = 0;
for ( const [ f, be, ue, ibc, iuc ] of GUNS ) {
    const live = parse( path.join( SD, f ), [ be, ue ] );
    const orig = parse( path.join( SD, f + ".acc-ammo-orig" ), [ be, ue ] );
    for ( const [ ent, intended ] of [ [ be, ibc ], [ ue, iuc ] ] ) {
        const L = live && live[ ent ]; const O = orig && orig[ ent ];
        const ls = L ? `${L.clip}/${L.max}=${L.clip * L.max}` : "(missing)";
        const os = O ? `${O.clip}/${O.max}=${O.clip * O.max}` : "(no backup)";
        let state = "";
        if ( !O ) { state = "no .acc-ammo-orig"; noBackup++; }
        else if ( L && O && L.clip === O.clip && L.max === O.max ) { state = "** CUT NOT APPLIED (==orig)"; cutNotApplied++; }
        else if ( L && O ) state = "cut applied";
        if ( intended !== "?" && intended !== "~" && L && String( L.clip ) !== intended ) state += `  [intended clip ${intended}]`;
        console.log( `${( ent ).padEnd( 21 )}  ${ls.padEnd( 24 )}  ${os.padEnd( 24 )}  ${state}` );
    }
}
console.log( `\nSUMMARY: ${cutNotApplied} entries at ORIGINAL (cut NOT applied), ${noBackup} with no backup.` );
console.log( cutNotApplied > 0
    ? "=> live GDTs are LARGER than the reduce_base_ammo intent; gdtdb /update shipped these. FIX: re-run reduce_base_ammo.js + gdtdb /update + link."
    : "=> live GDTs match the cut intent; ammo is as intended." );
