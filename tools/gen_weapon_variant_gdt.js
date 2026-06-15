#!/usr/bin/env node
// =============================================================================
// gen_weapon_variant_gdt.js - clone a weapon GDT asset into a perk "twin"
//
// BO3 weapon GDTs are PLAIN TEXT. This extracts one `"<asset>" ( "bulletweapon.gdf" )`
// block from a source GDT, renames it to `<asset>_<suffix>`, and SCALES selected
// stat fields - producing the recoil / fast-fire / fast-reload / fast-swap twins
// that _acc_weapon_variants.gsc swaps in. No APE GUI needed (APE just edits this text).
//
// Usage:
//   node tools/gen_weapon_variant_gdt.js \
//     --src "<tools>\source_data\skye_s1_tac-19.gdt" \
//     --asset s1_tac19 --suffix acc_recoil70 --recoil 0.5 \
//     --out source_data/acc_weapon_variants.gdt [--append]
//
//   --recoil <f>   scale factor for kick-magnitude fields (0.5 = -50%, 0.65 = -35%)
//   --fire   <f>   scale factor for fireTime/holdFireTime (0.667 ~= +50% RoF)
//   --reload <f>   scale factor for reload-timing fields (0.88 ~= +70% over engine +50%)
//   --swap   <f>   scale factor for raise/drop (weapon-swap) timing (0.25 = -75% swap)
//   --append       insert into an existing output GDT instead of overwriting
//   --inplace      scale <asset> IN <src> (no rename) - used for the x2.5 recoil base
//
// Scales ONLY the keys in the sets below. Any factor left at 1 (default) is a no-op
// for that category, so one twin can combine several (e.g. recoil + fire + reload).
// Keeps clipSize/maxAmmo identical (the GSC swap copies clip+reserve 1:1).
// =============================================================================

const fs = require( "fs" );

// Visible recoil (hip+ads gun & view kick magnitudes). Leaves accel/speed/decay
// timing untouched so the gun still recovers normally.
const RECOIL_KEYS = new Set( [
    "hipGunKickPitchMin", "hipGunKickPitchMax", "hipGunKickYawMin", "hipGunKickYawMax",
    "adsGunKickPitchMin", "adsGunKickPitchMax", "adsGunKickYawMin", "adsGunKickYawMax",
    "hipViewKickPitchMin", "hipViewKickPitchMax", "hipViewKickYawMin", "hipViewKickYawMax",
    "adsViewKickPitchMin", "adsViewKickPitchMax", "adsViewKickYawMin", "adsViewKickYawMax",
] );
// Time between shots (lower = faster). introFireTime = the wind-up burst gun ramp.
const FIRE_KEYS = new Set( [ "fireTime", "holdFireTime", "introFireTime" ] );
// Reload animation timing. *AddTime = when ammo is inserted during the anim; scale
// them by the same factor so the insert point stays proportional to the shorter anim.
const RELOAD_KEYS = new Set( [
    "reloadTime", "reloadEmptyTime", "reloadAddTime", "reloadEmptyAddTime",
    "reloadStartTime", "reloadStartAddTime", "reloadEndTime",
    "reloadQuickTime", "reloadQuickEmptyTime", "reloadQuickAddTime", "reloadQuickEmptyAddTime",
] );
// Weapon-SWAP timing: bring-up (raise) + put-away (drop). NOT adsTrans* (that's the
// aim-down-sight transition, a separate feel - we leave it alone).
const SWAP_KEYS = new Set( [
    "raiseTime", "firstRaiseTime", "altRaiseTime", "quickRaiseTime", "emptyRaiseTime",
    "dropTime", "emptyDropTime",
] );

const KEYSETS = [
    [ RECOIL_KEYS, "recoil" ],
    [ FIRE_KEYS,   "fire" ],
    [ RELOAD_KEYS, "reload" ],
    [ SWAP_KEYS,   "swap" ],
];

function arg( name, def ) {
    const i = process.argv.indexOf( "--" + name );
    if ( i === -1 ) return def;
    const v = process.argv[ i + 1 ];
    return ( v === undefined || v.startsWith( "--" ) ) ? true : v;
}

function fmt( n ) {
    // integer in -> integer out; else trim to <=4 decimals, no trailing zeros.
    if ( Number.isInteger( n ) ) return String( n );
    return parseFloat( n.toFixed( 4 ) ).toString();
}

function extractBlock( text, asset ) {
    const decl = `"${asset}" ( "bulletweapon.gdf" )`;
    const start = text.indexOf( decl );
    if ( start === -1 ) throw new Error( `asset "${asset}" ( "bulletweapon.gdf" ) not found in source` );
    // find the opening brace after the decl, then brace-match to its close.
    let i = text.indexOf( "{", start );
    if ( i === -1 ) throw new Error( "no opening brace after asset decl" );
    let depth = 0, end = -1;
    for ( let j = i; j < text.length; j++ ) {
        const c = text[ j ];
        if ( c === "{" ) depth++;
        else if ( c === "}" ) { depth--; if ( depth === 0 ) { end = j; break; } }
    }
    if ( end === -1 ) throw new Error( "unbalanced braces in asset block" );
    const lineStart = text.lastIndexOf( "\n", start ) + 1;   // start of the decl line
    return { text: text.slice( lineStart, end + 1 ), lineStart, end };
}

// Scale a single `\t\t"key" "value"` field line if its key is in any in-scope set.
// `scales` = { recoil, fire, reload, swap }; a factor of 1 means "skip this set".
function scaleLine( line, scales ) {
    const m = line.match( /^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/ );
    if ( !m ) return { line, scaled: 0 };
    const [ , indent, key, valStr ] = m;
    let scale = null;
    for ( const [ keys, name ] of KEYSETS ) {
        if ( keys.has( key ) && scales[ name ] !== 1 ) { scale = scales[ name ]; break; }
    }
    if ( scale === null ) return { line, scaled: 0 };
    const v = parseFloat( valStr );
    if ( v === 0 ) return { line, scaled: 0 };   // 0 stays 0
    return { line: `${indent}"${key}" "${fmt( v * scale )}"`, scaled: 1 };
}

// Scale every in-scope field in a block; optionally rename the asset decl.
function scaleBlock( block, asset, newName, scales ) {
    let scaled = 0;
    const out = block.split( /\r?\n/ ).map( ( line ) => {
        if ( newName && line.includes( `"${asset}" ( "bulletweapon.gdf" )` ) )
            return line.replace( `"${asset}"`, `"${newName}"` );
        const r = scaleLine( line, scales );
        scaled += r.scaled;
        return r.line;
    } );
    return { text: out.join( "\n" ), scaled };
}

function main() {
    const src = arg( "src" ), asset = arg( "asset" );
    const scales = {
        recoil: parseFloat( arg( "recoil", "1" ) ),
        fire:   parseFloat( arg( "fire", "1" ) ),
        reload: parseFloat( arg( "reload", "1" ) ),
        swap:   parseFloat( arg( "swap", "1" ) ),
    };
    const inplace = arg( "inplace", false ) === true;
    const append = arg( "append", false ) === true;
    const tag = `recoil x${scales.recoil}, fire x${scales.fire}, reload x${scales.reload}, swap x${scales.swap}`;

    if ( !src || !asset ) {
        console.error( "usage: --src <gdt> --asset <name> [--recoil f] [--fire f] [--reload f] [--swap f]\n  twin:    --suffix <s> --out <gdt> [--append]\n  inplace: --inplace   (scales <asset> in <src>, rewrites <src>)" );
        process.exit( 2 );
    }

    const text = fs.readFileSync( src, "utf8" );
    const blk = extractBlock( text, asset );

    // ---- in-place: scale the asset's fields inside the source GDT (no rename) ----
    if ( inplace ) {
        const { text: scaledBlock, scaled } = scaleBlock( blk.text, asset, null, scales );
        const result = text.slice( 0, blk.lineStart ) + scaledBlock + text.slice( blk.end + 1 );
        fs.writeFileSync( src, result );
        console.log( `in-place scaled ${asset} in ${src}  (${tag}, ${scaled} fields)` );
        return;
    }

    // ---- twin: extract, rename to <asset>_<suffix>, scale, write/append ----
    const suffix = arg( "suffix" ), out = arg( "out" );
    if ( !suffix || !out ) { console.error( "twin mode needs --suffix and --out" ); process.exit( 2 ); }
    const newName = asset + "_" + suffix;
    const { text: twin, scaled } = scaleBlock( blk.text, asset, newName, scales );

    // The extracted block carries source indentation (1 tab decl / 2 tab fields) -
    // just wrap it in the GDT `{ }` envelope.
    let result;
    if ( append && fs.existsSync( out ) ) {
        const cur = fs.readFileSync( out, "utf8" ).replace( /\s*\}\s*$/, "" ); // strip closing brace
        if ( cur.includes( `"${newName}" ( "bulletweapon.gdf" )` ) )
            throw new Error( `${newName} already in ${out} - remove it first` );
        result = cur.replace( /\s*$/, "" ) + "\n" + twin + "\n}\n";
    } else {
        result = "{\n" + twin + "\n}\n";
    }
    fs.writeFileSync( out, result );
    console.log( `wrote ${newName} -> ${out}  (${tag}, ${scaled} fields scaled)` );
}

main();
