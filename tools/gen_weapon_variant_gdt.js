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
//     --asset s1_tac19 --suffix acc_recoil40 --recoil 0.6 \
//     --out source_data/acc_weapon_variants.gdt [--append]
//
//   --recoil <f>   scale factor for kick-magnitude fields (0.6 = -40%, 0.75 = -25%)
//   --fire   <f>   scale factor for fireTime/holdFireTime (0.667 ~= +50% RoF)
//   --reload <f>   scale factor for reload-timing fields (0.88 ~= +70% over engine +50%)
//   --swap   <f>   scale factor for raise/drop (weapon-swap) timing (0.5 = -50% swap)
//   --range  <f>   scale factor for the damage-falloff DISTANCE breakpoints
//                  (maxDamageRange/minDamageRange/damageRange2..5); >1 = longer effective
//                  range (the gun holds full damage further out before falling off)
//   --damage <f>   scale factor for per-bullet damage magnitude (damage/damage2..5/minDamage);
//                  0.85 = -15% damage everywhere on the curve
//   --spread <f>   scale factor for the hip-fire SPREAD pattern width (hipSpread*Min/Max);
//                  >1 = wider blast for spread/shotgun-class guns (pellets cover a wider arc)
//   --ammo   <f>   scale factor for reserve ammo capacity (maxAmmo/startAmmo); 1.25 = +25%.
//                  INT-typed (rounded). The Mule Kick Mega "The Armory" +25%-reserve twin.
//   --penetrate <t> SET penetrateType to a literal enum tier (none/small/medium/large) - the
//                  FMJ bullet-penetration level. It is a STRING field, so it is set, not scaled.
//   --append       insert into an existing output GDT instead of overwriting
//   --inplace      scale <asset> IN <src> (no rename) - used for the x2.1 recoil base
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
// Effective RANGE = the damage-falloff DISTANCE breakpoints (world units, 1u = 1in).
// Scaling these stretches the falloff curve outward (full damage holds further, the drop-off
// starts later) WITHOUT changing damage magnitude. DISTANCE fields ONLY: do NOT add the
// damage* magnitude fields (that would be a damage buff, not range), and do NOT add
// multishotBaseDamageRange* (those are ~15000u "infinite" shotgun-pellet caps, not the
// per-bullet curve). 0-valued breakpoints (damageRange3..5 on most guns) stay 0 (no-op).
const RANGE_KEYS = new Set( [
    "maxDamageRange", "minDamageRange",
    "damageRange2", "damageRange3", "damageRange4", "damageRange5",
] );
// Per-bullet DAMAGE magnitude (NOT the falloff distance - that is RANGE_KEYS). `damage` = full
// damage out to maxDamageRange; damage2..5 = the breakpoint values; minDamage = the far floor.
// Scaling all by one factor shifts the whole damage curve uniformly (e.g. 0.85 = -15%). For a
// multi-pellet/shotgun gun this is PER-PELLET damage (shotCount pellets stack at point blank).
// HARD-WON (2026-06-14): `damage` is an INT-typed GDF field. A decimal value (e.g. 148.75)
// fails to parse and the weapon does ZERO damage in-game (verified live: every other gun uses
// integer damage; only our decimal values broke). => DAMAGE_KEYS is flagged int in KEYSETS so
// scaled results are Math.round()ed. (range/spread/recoil/timing are float - decimals fine there.)
const DAMAGE_KEYS = new Set( [
    "damage", "damage2", "damage3", "damage4", "damage5", "minDamage",
] );
// Hip-fire SPREAD PATTERN width (the cone the pellets fan into) for spread/shotgun-class guns.
// *Min = tightest (best-case) pattern, *Max = bloom cap, per stance. Scaling these up widens the
// "blast girth" so pellets cover a wider arc and catch more adjacent enemies. EXCLUDES the
// *Decay/*Add dynamics (recovery/bloom timing) and adsSpread (0 = pinpoint when aiming - left
// alone so ADS stays a precise single-target shot; hip-fire is the wide crowd-control mode).
const SPREAD_KEYS = new Set( [
    "hipSpreadStandMin", "hipSpreadMax",
    "hipSpreadDuckedMin", "hipSpreadDuckedMax",
    "hipSpreadProneMin", "hipSpreadProneMax",
    "hipSpreadSlideMin", "hipSpreadSlideMax",
] );
// Reserve AMMO capacity (Mule Kick Mega "The Armory" +25%). maxAmmo = the reserve cap the engine
// clamps stock ammo to (verified: SetWeaponAmmoStock above it is clamped, like Widow grenades);
// startAmmo = reserve granted on a fresh give. Both INT-typed (round, like damage). clipSize
// (the magazine) is intentionally NOT here - the +25% is RESERVE only. The Mega is gated by
// swapping to this twin (raised cap), then GiveMaxAmmo fills the reserve to it (armory_apply).
const AMMO_KEYS = new Set( [
    "maxAmmo", "startAmmo",
] );

// [ keyset, cli-name, roundToInt? ]. roundToInt = the GDF field is INT-typed (decimals make the
// engine read 0) so the scaled result must be Math.round()ed. `damage` + `ammo` are int.
const KEYSETS = [
    [ RECOIL_KEYS, "recoil" ],
    [ FIRE_KEYS,   "fire" ],
    [ RELOAD_KEYS, "reload" ],
    [ SWAP_KEYS,   "swap" ],
    [ RANGE_KEYS,  "range" ],
    [ DAMAGE_KEYS, "damage", true ],
    [ SPREAD_KEYS, "spread" ],
    [ AMMO_KEYS,   "ammo",   true ],
];

// String-valued fields that are SET to a literal (not scaled). FMJ/penetration is a string
// enum ("none"/"small"/"medium"/"large"), so it's a substitution, not a multiply. Map of
// CLI flag -> GDT field name. Extend this if a future twin needs another literal field.
const LITERAL_FIELDS = { penetrate: "penetrateType" };

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

// Transform a single `\t\t"key" "value"` field line. `literals` (field -> string) SETS a
// string field outright (penetrateType); checked first so it works regardless of the old
// value's shape. Otherwise, if the key is in an in-scope numeric set, the value is SCALED.
// `scales` = { recoil, fire, reload, swap, range }; a factor of 1 means "skip this set".
function scaleLine( line, scales, literals ) {
    // Literal-set path (string fields, e.g. penetrateType "none" -> "medium"). Matches any
    // `"key" "value"` line; only fires for keys explicitly listed in `literals`, so numeric
    // fields fall through to the scale path below untouched.
    if ( literals ) {
        const lm = line.match( /^(\s*)"([A-Za-z0-9_]+)"\s+"[^"]*"\s*$/ );
        if ( lm && literals[ lm[ 2 ] ] !== undefined )
            return { line: `${lm[ 1 ]}"${lm[ 2 ]}" "${literals[ lm[ 2 ] ]}"`, scaled: 1 };
    }
    const m = line.match( /^(\s*)"([A-Za-z0-9_]+)"\s+"(-?\d+(?:\.\d+)?)"\s*$/ );
    if ( !m ) return { line, scaled: 0 };
    const [ , indent, key, valStr ] = m;
    let scale = null, asInt = false;
    for ( const [ keys, name, isInt ] of KEYSETS ) {
        if ( keys.has( key ) && scales[ name ] !== 1 ) { scale = scales[ name ]; asInt = isInt === true; break; }
    }
    if ( scale === null ) return { line, scaled: 0 };
    const v = parseFloat( valStr );
    if ( v === 0 ) return { line, scaled: 0 };   // 0 stays 0
    let nv = v * scale;
    if ( asInt ) nv = Math.round( nv );          // INT-typed field: a decimal makes the gun do 0 dmg
    return { line: `${indent}"${key}" "${fmt( nv )}"`, scaled: 1 };
}

// Transform every in-scope field in a block (scale numerics, set literals); optionally
// rename the asset decl.
function scaleBlock( block, asset, newName, scales, literals ) {
    let scaled = 0;
    const out = block.split( /\r?\n/ ).map( ( line ) => {
        if ( newName && line.includes( `"${asset}" ( "bulletweapon.gdf" )` ) )
            return line.replace( `"${asset}"`, `"${newName}"` );
        const r = scaleLine( line, scales, literals );
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
        range:  parseFloat( arg( "range", "1" ) ),
        damage: parseFloat( arg( "damage", "1" ) ),
        spread: parseFloat( arg( "spread", "1" ) ),
        ammo:   parseFloat( arg( "ammo", "1" ) ),
    };
    // Literal string fields to SET (e.g. --penetrate medium -> penetrateType "medium").
    const literals = {};
    for ( const [ flag, field ] of Object.entries( LITERAL_FIELDS ) ) {
        const v = arg( flag, null );
        if ( v !== null && v !== true ) literals[ field ] = v;
    }
    const inplace = arg( "inplace", false ) === true;
    const append = arg( "append", false ) === true;
    const litTag = Object.keys( literals ).length ? `, ${Object.entries( literals ).map( ( [ k, v ] ) => `${k}=${v}` ).join( ", " )}` : "";
    const tag = `recoil x${scales.recoil}, fire x${scales.fire}, reload x${scales.reload}, swap x${scales.swap}, range x${scales.range}, damage x${scales.damage}, spread x${scales.spread}, ammo x${scales.ammo}${litTag}`;

    if ( !src || !asset ) {
        console.error( "usage: --src <gdt> --asset <name> [--recoil f] [--fire f] [--reload f] [--swap f]\n  twin:    --suffix <s> --out <gdt> [--append]\n  inplace: --inplace   (scales <asset> in <src>, rewrites <src>)" );
        process.exit( 2 );
    }

    const text = fs.readFileSync( src, "utf8" );
    const blk = extractBlock( text, asset );

    // ---- in-place: scale the asset's fields inside the source GDT (no rename) ----
    if ( inplace ) {
        const { text: scaledBlock, scaled } = scaleBlock( blk.text, asset, null, scales, literals );
        const result = text.slice( 0, blk.lineStart ) + scaledBlock + text.slice( blk.end + 1 );
        fs.writeFileSync( src, result );
        console.log( `in-place scaled ${asset} in ${src}  (${tag}, ${scaled} fields)` );
        return;
    }

    // ---- twin: extract, rename to <asset>_<suffix>, scale, write/append ----
    const suffix = arg( "suffix" ), out = arg( "out" );
    if ( !suffix || !out ) { console.error( "twin mode needs --suffix and --out" ); process.exit( 2 ); }
    const newName = asset + "_" + suffix;
    const { text: twin, scaled } = scaleBlock( blk.text, asset, newName, scales, literals );

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
