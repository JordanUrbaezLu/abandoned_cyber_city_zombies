// =============================================================================
// gen_box_weapon_sounds.js - author fire + foley sound-alias rows for the
// imported Skye box guns into sound/aliases/acc_skye_box_weapons.csv.
//
// Skye packs ship the .wav files but NO alias definitions, so each gun is silent
// until its GDT-referenced aliases exist. For each configured gun this generates:
//   FIRE  - wpn_<sid>_shot_plr/_npc (one row per shot-variant wav; multiple rows
//           w/ the same Name = engine randomization) + wpn_<sid>_pap_shot_plr/_npc.
//   FOLEY - one alias per .wav in sound_assets\skye_ports\<sid>\foley\, named after
//           the wav's basename (which IS the token the GDT references, e.g.
//           wpn_s1_pdw_mag_in, wpn_t5_tishina_bolt_back). This is the "reload /
//           bolt / charge" layer that was previously missing -> guns were fire-only.
// Fire rows clone the s1_tac19 shot template; foley rows clone the fiveseven charge
// template; only Name (col0) + FileSpec (col3) are swapped. The .szc references this
// CSV; the sound build compiles it.
//
// Idempotent: removes any existing row whose Name matches one we re-emit, then adds.
// Run from repo root:  node tools/gen_box_weapon_sounds.js
//
// NOTE: `sid` is the SOUND id (folder under sound_assets\skye_ports + alias prefix),
// which drops the weapon-id underscore for some guns (t8_paladin_hb50 ->
// t8_paladinhb50, t9_nail_gun -> t9_nailgun). Shared raise/ADS/dryfire/ammo_pickup
// aliases (wpn_generic_*, wpn_ammo_pickup, wpn_ar_m14/m16, wpn_t7_camo) come from
// stock banks - we only author the gun-SPECIFIC wpn_<sid>_* set.
// =============================================================================

const fs = require( "fs" );
const path = require( "path" );

const REPO = path.resolve( __dirname, ".." );
const CSV = path.join( REPO, "sound/aliases/acc_skye_box_weapons.csv" );

// Locate the Mod Tools sound_assets dir (AppID-suffixed folder; detected via
// bin\modlauncher.exe, never folder name - mirrors apply_recoil_overhaul.js).
function findSoundAssets() {
    const roots = [
        "C:\\Program Files (x86)\\Steam\\steamapps\\common",
        "D:\\SteamLibrary\\steamapps\\common",
        "E:\\SteamLibrary\\steamapps\\common",
    ];
    for ( const r of roots ) {
        if ( !fs.existsSync( r ) ) continue;
        for ( const d of fs.readdirSync( r ) ) {
            if ( fs.existsSync( path.join( r, d, "bin", "modlauncher.exe" ) ) )
                return path.join( r, d, "sound_assets", "skye_ports" );
        }
    }
    throw new Error( "Mod Tools sound_assets\\skye_ports not found (need it to scan foley wavs)." );
}
const SA = findSoundAssets();

const seq = ( n, pfx ) => Array.from( { length: n }, ( _, i ) => `${pfx}${i + 1}.wav` );

// sid = ALIAS prefix (the wpn_<sid>_* token the GDT references); shot[] = fire wav filenames (under fire\);
// pap = PaP fire wav (under fire\). Foley is auto-scanned from foley\.
// `dir` (optional) = the on-disk sound_assets\skye_ports\<dir> FOLDER, when it differs from the alias `sid`.
// Most guns: folder == sid. Chicom is the exception: folder "t6_chicom_cqb" (underscore) but alias prefix
// "t6_chicomcqb" (no underscore) - so dir is set explicitly. Wrong dir = silent (wav path won't resolve).
const GUNS = [
    { sid: "t8_paladinhb50", shot: [ "wpn_t8_paladinhb50_shot.wav" ], pap: "wpn_t8_paladinhb50_pap_shot.wav" },
    { sid: "s4_ppsh41",      shot: seq( 30, "wpn_s4_ppsh41_shot" ),    pap: "wpn_s4_ppsh41_pap_flux.wav" },
    { sid: "t5_ak74u",       shot: seq( 5,  "wpn_t5_ak74u_shot" ),     pap: "wpn_t5_ak74u_shot1.wav" }, // no separate PaP fire wav -> reuse base
    { sid: "t9_nailgun",     shot: seq( 6,  "wpn_t9_nailgun_shot" ),   pap: "wpn_t9_nailgun_pap_flux.wav" },
    { sid: "s1_pdw",         shot: [ "wpn_s1_pdw_shot.wav" ],          pap: "wpn_s1_pdw_pap_shot.wav" },
    { sid: "s2_m1911",       shot: [ "wpn_s2_m1911_shot.wav" ],        pap: "wpn_s2_m1911_pap_shot.wav" },
    // +2 box guns (user, 2026-06-15): Olympia + Galil (BO2 ports; BO1 had GDTs only).
    // Foley auto-scanned from foley\ (Olympia: close/open/shell_in/switch; Galil: bolt_*/futz/mag_*).
    { sid: "t6_olympia",     shot: [ "wpn_t6_olympia_shot.wav" ],      pap: "wpn_t6_olympia_pap_shot.wav" },
    { sid: "t6_galil",       shot: [ "wpn_t6_galil_shot.wav" ],        pap: "wpn_t6_galil_pap_shot.wav" },
    // +2 LMGs (user, 2026-06-19): M60 + RPD (BO2 ports). Foley auto-scanned from foley\ (bolt/mag/etc.).
    { sid: "t6_m60",         shot: [ "wpn_t6_m60_shot.wav" ],          pap: "wpn_t6_m60_pap_shot.wav" },
    { sid: "t6_rpd",         shot: [ "wpn_t6_rpd_shot.wav" ],          pap: "wpn_t6_rpd_pap_shot.wav" },
    // MK14 (AW s1_mk14): semi-auto DMR box gun (user 2026-06-24). sid = s1_mk14 (no dropped underscore).
    // Foley auto-scanned from foley\ (charge/release/start/end + mag_in/out + empty_* + pre_* set).
    { sid: "s1_mk14",        shot: [ "wpn_s1_mk14_shot.wav" ],         pap: "wpn_s1_mk14_pap_shot.wav" },
    // MORS (AW s1_mors): charge-up railgun sniper (user 2026-06-24). GDT fireSound = wpn_s1_mors_shot(_pap).
    // Foley auto-scanned from foley\ (bolt_open/close + bullet_in_* set).
    { sid: "s1_mors",        shot: [ "wpn_s1_mors_shot.wav" ],         pap: "wpn_s1_mors_pap_shot.wav" },
    // Chicom CQB (user 2026-06-25): 3-round-burst SMG. alias prefix DROPS the underscore (wpn_t6_chicomcqb_*,
    // matching the GDT fireSound tokens + wav basenames) but the on-disk folder KEEPS it (t6_chicom_cqb) -> dir.
    // Foley auto-scanned from foley\ (bolt_back/forward + mag_in/out). Base + PaP fire wavs both exist (48k stereo).
    { sid: "t6_chicomcqb",   dir: "t6_chicom_cqb", shot: [ "wpn_t6_chicomcqb_shot.wav" ], pap: "wpn_t6_chicomcqb_pap_shot.wav" },
];

const lines = fs.readFileSync( CSV, "utf8" ).split( /\r?\n/ );
const header = lines[ 0 ];
const rows = lines.slice( 1 ).filter( ( l ) => l.trim().length );

const tmplShotPlr = rows.find( ( r ) => r.startsWith( "wpn_s1_tac19_shot_plr," ) );
const tmplShotNpc = rows.find( ( r ) => r.startsWith( "wpn_s1_tac19_shot_npc," ) );
const tmplFoley   = rows.find( ( r ) => r.startsWith( "wpn_t6_fiveseven_charge," ) );
if ( !tmplShotPlr || !tmplShotNpc ) throw new Error( "fire template rows (wpn_s1_tac19_shot_plr/_npc) not found in CSV" );
if ( !tmplFoley ) throw new Error( "foley template row (wpn_t6_fiveseven_charge) not found in CSV" );

const setCol = ( row, idx, val ) => { const c = row.split( "," ); c[ idx ] = val; return c.join( "," ); };
const mkRow = ( tmpl, name, filespec ) => setCol( setCol( tmpl, 0, name ), 3, filespec );

const out = [];
let nFire = 0, nFoley = 0;
for ( const g of GUNS ) {
    const dir = g.dir || g.sid;   // on-disk folder; usually == sid, override via `dir` when they differ (Chicom)
    // FIRE (shot variants randomize under one alias name; PaP fire)
    for ( const w of g.shot ) {
        const fsp = `skye_ports\\${dir}\\fire\\${w}`;
        out.push( mkRow( tmplShotPlr, `wpn_${g.sid}_shot_plr`, fsp ) );
        out.push( mkRow( tmplShotNpc, `wpn_${g.sid}_shot_npc`, fsp ) );
        nFire += 2;
    }
    const pf = `skye_ports\\${dir}\\fire\\${g.pap}`;
    out.push( mkRow( tmplShotPlr, `wpn_${g.sid}_pap_shot_plr`, pf ) );
    out.push( mkRow( tmplShotNpc, `wpn_${g.sid}_pap_shot_npc`, pf ) );
    nFire += 2;

    // FOLEY - one alias per wav under foley\, named for the wav (= the GDT token).
    const foleyDir = path.join( SA, dir, "foley" );
    if ( fs.existsSync( foleyDir ) ) {
        for ( const f of fs.readdirSync( foleyDir ).filter( ( f ) => f.toLowerCase().endsWith( ".wav" ) ) ) {
            const name = f.replace( /\.wav$/i, "" );        // basename IS the alias/token
            out.push( mkRow( tmplFoley, name, `skye_ports\\${dir}\\foley\\${f}` ) );   // dir (folder) not sid (alias prefix) - Chicom differs
            nFoley++;
        }
    } else {
        console.log( `WARN: no foley folder for ${g.sid} (${foleyDir})` );
    }
}

// Idempotent: drop any existing row whose Name we are re-emitting (handles cross-
// prefix foley like wpn_t5_tishina_* that the old sid-prefix filter missed).
const newNames = new Set( out.map( ( r ) => r.split( "," )[ 0 ] ) );
const kept = rows.filter( ( r ) => !newNames.has( r.split( "," )[ 0 ] ) );

fs.writeFileSync( CSV, [ header, ...kept, ...out ].join( "\n" ) + "\n" );
console.log( `wrote ${out.length} rows (${nFire} fire, ${nFoley} foley) for ${GUNS.length} guns: ${GUNS.map( ( g ) => g.sid ).join( ", " )}` );
