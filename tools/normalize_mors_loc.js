// =============================================================================
// normalize_mors_loc.js - install-side hit-location normalization for the MORS
// railgun sniper (skye_s1_mors.gdt), mirroring the Paladin HB50 fix (docs/33).
//
// WHY: the Skye MORS rip is MP-tuned with INFLATED loc* mults - base locTorso
// 4.0-5.5 / locHead 7.5, and the PaP form 9.5-10.0 on EVERYTHING incl. FEET (9.0).
// The engine multiplies `damage` by the hit-location field BEFORE on_ai_damage
// sees it, so at face value a BODY/FOOT shot is 5-10x `damage` and the gun
// one-shots bodies+feet to absurd rounds, AND the entire PaP "upgrade" is baked
// into the loc bump (damage is 1000 on BOTH forms). That breaks the additive
// balance model + makes acc_weapon_balance_mult meaningless.
//
// FIX (both s1_mors + s1_mors_up):
//   - torso / neck / limbs / feet  -> 1.0  (body = `damage`, additive model holds)
//   - head / helmet                -> 5.0  (standard box-gun headshot = ~2.5x body,
//                                          NOT the Paladin's all-1.0 which made head
//                                          a WEAK 0.5x - bad for a precision sniper)
//   - s1_mors_up `damage` 1000 -> 2000     (re-encode the PaP boost the loc bump used
//                                          to carry, so PaP still out-hits base 2x)
// Per-shot feel then = `damage` x acc_weapon_balance_mult (0.47): base 470 / PaP 940
// (x global). Tier scoring (docs/54) reads e=470 (cu single-target) -> B base AND PaP.
//
// ORDER: run BEFORE tools/apply_recoil_overhaul.js so the recoil tool's .acc-orig
// backup captures the NORMALIZED values (it restores from .acc-orig each run, and
// does NOT touch loc - so a pre-normalized backup is how the fix survives re-runs).
// Idempotent: backs up to .acc-loc-orig on first run, always derives from it.
// Install-side (not repo-tracked, like the Skye GDTs) - re-apply on a fresh box.
// Run:  node tools/normalize_mors_loc.js   (then gdtdb /update via the recoil tool)
// =============================================================================

const fs = require( "fs" );
const path = require( "path" );

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
const GDT = path.join( SD, "skye_s1_mors.gdt" );
if ( !fs.existsSync( GDT ) ) throw new Error( "skye_s1_mors.gdt not found - install the AW Skye pack first." );

const backup = GDT + ".acc-loc-orig";
if ( !fs.existsSync( backup ) ) fs.copyFileSync( GDT, backup );   // first run: snapshot the inflated original
const src = fs.readFileSync( backup, "utf8" );                    // always derive FROM the original

// Target loc value per field (applied to BOTH weapon blocks).
// FIXED FIELD NAMES (user 2026-06-25): the limb keys were WRONG (locRightArm vs the real
// locRightArmLower/Upper / locRightHand / locRightLegLower/Upper), so the _up limbs were NEVER
// normalized and stayed 9.0 (PaP MORS = 9x limb damage). The canonical loc normalizer is now
// tools/normalize_sniper_loc.js (in-place, both snipers, safe to re-run); this map is kept correct
// so a fresh-box run of THIS tool (which also re-encodes _up damage) can't re-introduce the bug.
const LOC = {
    locHead: "5.0", locHelmet: "5.0",                                      // headshot tier (~2.5x body)
    locNeck: "1.0", locTorsoUpper: "1.0", locTorsoMid: "1.0", locTorsoLower: "1.0",
    locLeftArmUpper: "1.0", locLeftArmLower: "1.0", locRightArmUpper: "1.0", locRightArmLower: "1.0",
    locLeftHand: "1.0", locRightHand: "1.0",
    locLeftLegUpper: "1.0", locLeftLegLower: "1.0", locRightLegUpper: "1.0", locRightLegLower: "1.0",
    locRightFoot: "1.0", locLeftFoot: "1.0",
};
// Per-weapon `damage` re-encode (the PaP boost the loc bump used to carry).
const DAMAGE = { "s1_mors_up": "2000" };

const HEADER = /^\s*"([^"]+)"\s*\(\s*"[a-z]*weapon\.gdf"\s*\)/;
const FIELD  = /^(\s*"([a-zA-Z0-9]+)"\s+")([^"]*)("\s*)$/;

const lines = src.split( /\r?\n/ );
let weapon = null, changed = 0;
for ( let i = 0; i < lines.length; i++ ) {
    const h = lines[ i ].match( HEADER );
    if ( h ) { weapon = h[ 1 ]; continue; }
    const m = lines[ i ].match( FIELD );
    if ( !m ) continue;
    const field = m[ 2 ], val = m[ 3 ];
    let target = null;
    if ( LOC[ field ] !== undefined ) target = LOC[ field ];
    else if ( field === "damage" && DAMAGE[ weapon ] !== undefined ) target = DAMAGE[ weapon ];
    if ( target !== null && target !== val ) { lines[ i ] = m[ 1 ] + target + m[ 4 ]; changed++; }
}

fs.writeFileSync( GDT, lines.join( "\n" ) );
console.log( `normalize_mors_loc: ${changed} fields set across s1_mors + s1_mors_up (loc->1.0, head->5.0, PaP damage->2000)` );
console.log( "NEXT: add MORS to apply_recoil_overhaul.js + run it (regens .acc-orig from THIS normalized GDT + gdtdb)." );
