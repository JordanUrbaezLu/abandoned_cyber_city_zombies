#!/usr/bin/env node
// =============================================================================
// apply_recoil_overhaul.js - one-shot, IDEMPOTENT weapon-variant twin generator
//
// Generates the FULL perk twin matrix for the 3 box guns (base + PaP `_up`), the
// set _acc_weapon_variants.gsc swaps in. Design: docs/perk_abilities.md §3/4/7,
// docs/30/31.
//
// DIMENSIONS (independent perk effects that can stack on one held gun):
//   recoil  : none / recoil35 / recoil70   (Deadshot base -35% / Mega -70%, off the 2.5x base)
//   fastfire: Gun Slinger (Double Tap Mega) = fireTime x0.667 (+50% RoF) AND swap x0.25 (-75%)
//   reload  : Sleight of Hand Expert (Speed Cola Mega) = reloadTime x0.882 (+70% net, see below)
//
// The cross-product (minus the all-base combo) = 11 twins per gun form:
//   recoil35, recoil70, fastfire, fastreload, recoil35_fastfire, recoil70_fastfire,
//   recoil35_fastreload, recoil70_fastreload, fastfire_fastreload,
//   recoil35_fastfire_fastreload, recoil70_fastfire_fastreload
//   x (base + _up) x 5 guns = 110 twins. The GSC swap engine resolves the exact
//   combo for a player's live perk state (graceful fallback if a combo is absent).
//
// PER-GUN BASELINE BUFFS (always-on, not perk-gated): a gun's `baseline` config is applied
// IN PLACE to its base + _up forms before the twins are cloned, so the base gun AND every
// twin inherit it for free (zero extra assets). Current: TAC-19 crowd-control profile - small
// range x1.5 + FMJ penetrateType large + wider spread x1.25, traded against -15% damage (x0.85).
// See GUNS below + gen_weapon_variant_gdt.js (--range / --damage / --spread / --penetrate).
//
//   base GDT (in place):  recoil x2.5  -> 2.5x vanilla (no Deadshot)
//
// TUNING (single source; confirm magnitudes in-game, they compose with engine perk bonuses):
//   RECOIL35/70 - off the 2.5x base: 0.65 -> 1.625x vanilla, 0.30 -> 0.75x vanilla.
//   FIRE 0.667  - +50% RoF. NB: stock specialty_doubletap2 is the extra-BULLET (2.0)
//                 effect, not a fireTime change, so the twin carries the whole rate gain.
//                 If an in-game check shows doubletap2 also lowers fireTime, raise toward ~0.889.
//   SWAP 0.25   - -75% weapon-swap (raise/drop times); bundled with fastfire (same Mega flag).
//   RELOAD 0.882- net +70% reload. Speed Cola owners ALSO get the engine +50% (x0.667),
//                 which compounds: 0.882 x 0.667 ~= 0.588 = +70%. Base (non-Mega) Speed
//                 owners keep the engine +50% only (no twin). Confirm the engine bonus is a
//                 clean reloadTime multiplier in-game; this is the one lever to retune.
//
// IDEMPOTENT: keeps a `.acc-orig` backup of each Skye GDT and restores it before
// scaling, so re-running never compounds the x2.5. Re-run any time to re-derive.
//
// Usage: node tools/apply_recoil_overhaul.js [--source_data "<path>"]
//   --source_data  the Mod Tools source_data dir (auto-detected if omitted)
// =============================================================================

const fs = require( "fs" );
const path = require( "path" );
const { execFileSync } = require( "child_process" );

const REPO = path.resolve( __dirname, ".." );
const GEN = path.join( __dirname, "gen_weapon_variant_gdt.js" );
const OUT_REPO = path.join( REPO, "source_data", "acc_weapon_variants.gdt" );

const BASE_SCALE = 2.5;

// Per-dimension twin levels. [ suffix-part, scale-factors ]. '' = the base level
// (no twin part). Order here == the suffix concatenation order the GSC expects
// (recoil -> fastfire -> reload), and the longest-first strip list is derived from it.
const TWIN_DIMS = [
    [ [ "", {} ], [ "recoil35", { recoil: 0.65 } ], [ "recoil70", { recoil: 0.30 } ] ],
    [ [ "", {} ], [ "fastfire", { fire: 0.667, swap: 0.25 } ] ],
    [ [ "", {} ], [ "fastreload", { reload: 0.882 } ] ],
];

// gun file + its base/PaP asset names (verified on the box 2026-06-14).
// `baseline` (optional) = always-on per-gun buffs applied to the base + _up forms IN PLACE,
// so every twin cloned from them (step 2) inherits the buff for free - no extra assets and
// the buff persists whether or not a perk twin is active. range = damage-falloff distance
// multiplier (>1 = longer effective range); penetrate = penetrateType FMJ tier
// (none/small/medium/large). See gen_weapon_variant_gdt.js for the exact fields touched.
const GUNS = [
    // TAC-19: crowd-control profile. Small range buff (x1.5 falloff distance: ~550u->~825u
    // full-damage, ~900u->~1350u min) + FMJ over-penetration (penetrateType large, max pierce)
    // + wider blast "girth" (hip spread x1.25, catches more adjacent zombies) traded against
    // -15% per-pellet damage (x0.85). Tune any factor here; bump penetrate to none/small/medium
    // to dial pierce back. shotCount 8 (per-pellet damage), adsSpread stays 0 (ADS = precise).
    { gdt: "skye_s1_tac-19.gdt",    base: "s1_tac19",     up: "s1_tac19_up",    baseline: { range: 1.5, penetrate: "large", damage: 0.85, spread: 1.25 } },
    { gdt: "skye_s1_asm1.gdt",      base: "s1_asm1",      up: "s1_asm1_up" },
    { gdt: "skye_t6_five-seven.gdt", base: "t6_fiveseven", up: "t6_fiveseven_up" },
    { gdt: "skye_t6_ak47.gdt",      base: "t6_ak47",      up: "t6_ak47_up" },
    { gdt: "skye_s1_ae4.gdt",       base: "s1_ae4",       up: "s1_ae4_up" },
];

// CLI args for a gun's always-on baseline buff (numeric factors are scaled, literals set).
function baselineArgs( b ) {
    if ( !b ) return [];
    const a = [];
    if ( b.range !== undefined )     a.push( "--range", String( b.range ) );
    if ( b.damage !== undefined )    a.push( "--damage", String( b.damage ) );
    if ( b.spread !== undefined )    a.push( "--spread", String( b.spread ) );
    if ( b.penetrate !== undefined ) a.push( "--penetrate", b.penetrate );
    return a;
}

function arg( name, def ) {
    const i = process.argv.indexOf( "--" + name );
    return i === -1 ? def : process.argv[ i + 1 ];
}

function detectSourceData() {
    const roots = [
        "C:/Program Files (x86)/Steam/steamapps/common",
        "D:/Steam/steamapps/common", "E:/Steam/steamapps/common", "C:/Steam/steamapps/common",
    ];
    for ( const r of roots ) {
        if ( !fs.existsSync( r ) ) continue;
        for ( const d of fs.readdirSync( r ) ) {
            const cand = path.join( r, d, "bin", "modlauncher.exe" );
            if ( fs.existsSync( cand ) ) return path.join( r, d, "source_data" );
        }
    }
    throw new Error( "could not auto-detect source_data; pass --source_data" );
}

function gen( args ) { execFileSync( process.execPath, [ GEN, ...args ], { stdio: "inherit" } ); }

function factorArgs( f ) {
    const a = [];
    for ( const k of [ "recoil", "fire", "reload", "swap" ] )
        if ( f[ k ] !== undefined ) a.push( "--" + k, String( f[ k ] ) );
    return a;
}

// Cartesian product of the dimension levels -> [ { suffix, factors } ], minus the
// all-base (empty) combo.
function enumerateTwins() {
    let combos = [ { parts: [], f: {} } ];
    for ( const dim of TWIN_DIMS ) {
        const next = [];
        for ( const c of combos ) {
            for ( const [ sfx, f ] of dim ) {
                next.push( { parts: sfx ? c.parts.concat( sfx ) : c.parts, f: Object.assign( {}, c.f, f ) } );
            }
        }
        combos = next;
    }
    return combos.filter( ( c ) => c.parts.length > 0 )
        .map( ( c ) => ( { suffix: "acc_" + c.parts.join( "_" ), factors: c.f } ) );
}

function main() {
    const SD = arg( "source_data", null ) || detectSourceData();
    console.log( "source_data:", SD );

    const twins = enumerateTwins();
    console.log( `twin matrix: ${twins.length} combos/form x ${GUNS.length} guns x 2 forms = ${twins.length * GUNS.length * 2} twins` );

    // fresh output GDT
    if ( fs.existsSync( OUT_REPO ) ) fs.rmSync( OUT_REPO );
    fs.mkdirSync( path.dirname( OUT_REPO ), { recursive: true } );

    for ( const g of GUNS ) {
        const file = path.join( SD, g.gdt );
        if ( !fs.existsSync( file ) ) throw new Error( `missing ${file}` );
        const orig = file + ".acc-orig";

        // idempotency: snapshot once, then always start from the pristine copy.
        if ( !fs.existsSync( orig ) ) fs.copyFileSync( file, orig );
        fs.copyFileSync( orig, file );

        // 1) scale the base + PaP forms x2.5 recoil IN PLACE (the map skill baseline), plus
        // any per-gun always-on baseline buff (e.g. TAC-19 range/FMJ). The twins in step 2
        // are cloned FROM these now-modified forms, so they inherit the baseline automatically.
        const baseArgs = baselineArgs( g.baseline );
        gen( [ "--src", file, "--asset", g.base, "--recoil", String( BASE_SCALE ), ...baseArgs, "--inplace" ] );
        gen( [ "--src", file, "--asset", g.up,   "--recoil", String( BASE_SCALE ), ...baseArgs, "--inplace" ] );

        // 2) emit every twin combo off the now-2.5x base (base + _up form)
        for ( const form of [ g.base, g.up ] ) {
            for ( const t of twins ) {
                gen( [ "--src", file, "--asset", form, "--suffix", t.suffix,
                       ...factorArgs( t.factors ), "--out", OUT_REPO, "--append" ] );
            }
        }
    }

    // deploy the twin GDT to source_data (base edits are already in place there)
    const outDeployed = path.join( SD, "acc_weapon_variants.gdt" );
    fs.copyFileSync( OUT_REPO, outDeployed );
    console.log( `\ndeployed twins -> ${outDeployed}` );
    console.log( "base GDTs scaled x2.5 in place (backups at *.acc-orig). Re-run any time; idempotent." );

    // Refresh the GDT DB so the linker can find the new assets. The linker does NOT
    // do this - only GdtDBTray / the Launcher Compile / gdtdb.exe do. Skipping it =
    // "unable to locate asset in gdtdb for '<twin>'" at link. Run it here so the
    // generator is one-step: regenerate -> (this) -> link.
    const gdtdb = path.join( path.dirname( SD ), "gdtdb", "gdtdb.exe" );
    if ( fs.existsSync( gdtdb ) ) {
        try {
            execFileSync( gdtdb, [ "/update" ], { cwd: path.dirname( gdtdb ), stdio: "inherit" } );
            console.log( "gdt.db updated - safe to link now." );
        } catch ( e ) {
            console.log( "WARN: gdtdb /update failed - run it manually before linking: " + e.message );
        }
    } else {
        console.log( `NOTE: run "${gdtdb}" /update before linking (not found here).` );
    }
}

main();
