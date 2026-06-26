// gen_perk_glow_fx.js - generate per-perk recoloured clones of the stock green
// power-up glow FX for the perk/PaP power-on glow (_acc_perk_lights).
//
// WHY: the green power-up aura (zombie/fx_powerup_on_green_zmb) is the ONE FX proven to
// render in this build (validated in-game 2026-06-18: all machines + PaP glow green). Its
// colour is pure `colorGraph` tint on white glow sprites (no green texture), so we can
// recolour it by remapping the tint triples while keeping the brightness/alpha/light curves.
// PlayFX takes no runtime tint, so we need one .efx per colour.
//
// The green tint appears as three triples: 0.25098 1 0.25098 (saturated), 0.501961 1 0.501961
// (lighter), and 0 0.458824 0 (the small light element), plus dynamicLight2 `_color 1 1 1`.
// We remap each preserving its brightness D (max) and recessive r (min): new_c = r+(D-r)*w
// for per-channel target weight w (max weight = 1). _color becomes the full-sat target.
//
// Output: <TOOLS>\share\raw\fx\acc\light\fx_perk_glow_<name>.efx (build input; packed via the
// `fx,acc/light/...` lines in zone_source. Regenerate with `node tools/gen_perk_glow_fx.js`).
//
// Usage: node tools/gen_perk_glow_fx.js ["<tools root>"]

const fs = require( 'fs' );
const path = require( 'path' );

const TOOLS = process.argv[ 2 ] ||
  'C:\\Program Files (x86)\\Steam\\steamapps\\common\\Call of Duty Black Ops III 455130';
const SRC = path.join( TOOLS, 'share', 'raw', 'fx', 'zombie', 'fx_powerup_on_green_zmb.efx' );
const OUT_DIR = path.join( TOOLS, 'share', 'raw', 'fx', 'acc', 'light' );

// name -> per-channel target weight [wr, wg, wb], max channel = 1. Matches the index map in
// _acc_perk_lights.gsc::perk_color_index (1..10) AND the level._effect map in the .csc -
// the .efx FILENAME is fx_perk_glow_<name>, so these keys are the source of truth for both.
// Recolor 2026-06-18 (user): Deadshot=blacklight, Widow's Wine=white, PhD=purple, PaP=teal.
const COLORS = {
  red:        [ 1.00, 0.06, 0.06 ],  // 1  Jugg          - red
  green:      [ 0.16, 1.00, 0.16 ],  // 2  Speed Cola    - green
  yellow:     [ 1.00, 0.85, 0.10 ],  // 3  Double Tap    - yellow
  orange:     [ 1.00, 0.42, 0.05 ],  // 4  Stamin-Up     - orange
  amber:      [ 1.00, 0.62, 0.22 ],  // 5  Mule Kick     - amber
  blue:       [ 0.12, 0.45, 1.00 ],  // 6  Quick Revive  - blue
  blacklight: [ 0.40, 0.00, 0.55 ],  // 7  Deadshot      - DARKER purple (user 2026-06-18; was bright UV violet)
  white:      [ 1.00, 1.00, 1.00 ],  // 8  Widow's Wine  - white
  purple:     [ 0.62, 0.08, 1.00 ],  // 9  PhD Flopper   - purple
  teal:       [ 0.00, 1.00, 0.90 ],  // 10 Pack-a-Punch  - brighter teal (user 2026-06-18)
  teal_dim:   [ 0.00, 1.00, 0.90 ],  //    (legacy) old Glitch Stalker body aura - kept generated but no longer referenced.
  // --- Glitch / Phantom re-theme (user 2026-06-24): glitch = MAGENTA glow, phantom = DARK PURPLE. ---
  magenta:     [ 1.00, 0.05, 0.90 ],  // 11 Glitch theme + lockdown "purge" room lights - full-bright MAGENTA (was red, user 2026-06-24).
  magenta_dim: [ 1.00, 0.05, 0.90 ],  //    Glitch Stalker BODY AURA - same magenta hue, DIMMED (BRIGHT below) = "50% less intense" than the old teal_dim (user 2026-06-24).
  dark_purple: [ 0.42, 0.00, 0.72 ],  //    Phantom BODY AURA - deep DARK PURPLE (user 2026-06-24, was red). Low max channel (0.72) reads inherently dark.
  white_dim:   [ 1.00, 1.00, 1.00 ],  // 12 Trench Data-Cache "has shards this round" indicator - DIM white (BRIGHT below). On while armed, off while looted.
};

// Per-colour brightness scale (default 1.0). Only the colour tint + cast light are scaled (not
// size/density), so a value <1 reads as a dimmer glow of the same shape/hue.
//   teal_dim 0.75    = legacy (unused now).
//   magenta_dim 0.375 = the Glitch Stalker aura at HALF the old 0.75 teal_dim -> "make the glitch glow 50% less intense" (user 2026-06-24).
//   white_dim 0.40   = a subtle indicator glow on the trench shard banks.
const BRIGHT = { teal_dim: 0.75, magenta_dim: 0.375, white_dim: 0.40 };

// Whole-machine coverage + intensity (user 2026-06-18). The source FX is a small spherical
// aura at tag_origin (= machine base), so only the BOTTOM lit. We enlarge the glow sprites
// so one aura envelops the ~70u-tall cabinet, lift the emission up the body, thicken it
// (density), brighten the cast light, and widen the cull box so nothing clips. All tunable -
// re-run `node tools/gen_perk_glow_fx.js` + rebuild -GscOnly to retune.
const SIZE_MULT   = 1.9;   // glow-sprite size multiplier (vertical/× coverage; ~1.5-2.0). 1.6->1.9 (user 2026-06-18: tops weren't lit).
const DENSITY     = 2;     // emitDensity. 3->2 (with the longer life below, fewer particles still fill it; avoids over-bright).
const LIFT_Z      = 40;    // raise emission this many units so the glow centres higher up the body. 25->40 (lift it so the TOP glows; user 2026-06-18).
const LIGHT_BOOST = 1.8;   // dynamic-light _color over-bright (stronger coloured cast light). 1.5->1.8 (more light).
const LIFE_MULT   = 5;     // STEADY GLOW (user 2026-06-18): lengthen every particle's life Nx so sprites PERSIST and fade slowly
                           // instead of rapidly spawning/dying (= the "sparkle/twinkle"). Bigger = steadier/less flicker.

// Geometry/intensity reshape - colour-independent, applied to the source ONCE before recolour.
function reshape( text ) {
  return text
    // bigger glow sprites (matches only the `sizeGraph0|1 <N>` DECLARATION lines; the graph
    // body number-pairs live on their own lines and never start with `sizeGraph`).
    .replace( /(sizeGraph[01] )([\d.]+)/g, ( m, k, v ) => k + fmt( parseFloat( v ) * SIZE_MULT ) )
    // STEADY GLOW, not sparkle (user 2026-06-18: "just glows rather than sparkle, the sparkles move too much"):
    //   (a) kill gravity so sprites don't drift up/down - they hold in place
    .replace( /gravity [\d.-]+ [\d.-]+/g, 'gravity 0 0' )
    //   (b) lengthen every particle's lifespan Nx so they persist as a steady glow instead of twinkling
    .replace( /lifeSpanMsec ([\d.]+) ([\d.]+)/g, ( m, a, b ) =>
      'lifeSpanMsec ' + Math.round( parseFloat( a ) * LIFE_MULT ) + ' ' + Math.round( parseFloat( b ) * LIFE_MULT ) )
    // denser emission (every element ships `emitDensity 1 0`)
    .split( 'emitDensity 1 0' ).join( 'emitDensity ' + DENSITY + ' 0' )
    // lift the whole aura up the cabinet (every element spawns at base z by default)
    .split( 'spawnOrgZ 0 0' ).join( 'spawnOrgZ ' + LIFT_Z + ' 0' )
    // widen the cull box so the enlarged FX is not frustum/bound clipped
    .split( 'efBoundingBoxMin -40 -40 -40' ).join( 'efBoundingBoxMin -120 -120 -20' )
    .split( 'efBoundingBoxMax 40 40 40' ).join( 'efBoundingBoxMax 120 120 140' );
}

function fmt( n ) {
  // trim to 6 decimals, drop trailing zeros, keep at least "0"/"1"
  let s = n.toFixed( 6 ).replace( /0+$/, '' ).replace( /\.$/, '' );
  return s === '' ? '0' : s;
}

function mixTriple( rec, D, w, B ) {
  return w.map( ( wc ) => fmt( ( rec + ( D - rec ) * wc ) * B ) ).join( ' ' );
}

function recolor( text, w, B ) {
  return text
    .split( '0.25098 1 0.25098' ).join( mixTriple( 0.25098, 1, w, B ) )
    .split( '0.501961 1 0.501961' ).join( mixTriple( 0.501961, 1, w, B ) )
    .split( '0 0.458824 0' ).join( mixTriple( 0, 0.458824, w, B ) )
    // dynamic-light cast colour, over-brightened (LIGHT_BOOST) for a stronger coloured glow; B dims it.
    .split( '_color 1 1 1' ).join( '_color ' + w.map( ( c ) => fmt( c * LIGHT_BOOST * B ) ).join( ' ' ) );
}

const srcRaw = fs.readFileSync( SRC, 'utf8' );
const src = reshape( srcRaw );   // geometry + intensity reshape, applied ONCE before recolour
fs.mkdirSync( OUT_DIR, { recursive: true } );

let n = 0;
for ( const [ name, w ] of Object.entries( COLORS ) ) {
  const B = ( BRIGHT[ name ] !== undefined ) ? BRIGHT[ name ] : 1.0;
  const out = recolor( src, w, B );
  const dst = path.join( OUT_DIR, 'fx_perk_glow_' + name + '.efx' );
  fs.writeFileSync( dst, out );
  console.log( 'wrote ' + dst + '  [' + w.join( ', ' ) + ']' + ( B !== 1.0 ? '  @' + ( B * 100 ) + '%' : '' ) );
  n++;
}
console.log( '\ndone: ' + n + ' perk-glow .efx written to ' + OUT_DIR );
