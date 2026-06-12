// =============================================================================
// _acc_early_round_pacing.gsc - faster zombies + higher counts in rounds 1–4
//
// Design reference: docs/06_mechanics.md ("Early round pressure"),
// docs/04_progression_and_skills.md (Difficulty Curve).
//
// Rounds 1–4: +35% zombies vs stock max_zombie_func output; +15% move speed
// on spawn. From round 5 onward, stock pacing unchanged (aside from modifiers).
//
// post_zm_main() MUST run from zm_abandoned_cyber_city.gsc immediately after
// zm::main() so level.max_zombie_func is chained before the first round
// computes spawn totals.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// ---------------------------------------------------------------------------
// Tuning (keep in sync with docs/06_mechanics.md + docs/04_progression_and_skills.md)
// ---------------------------------------------------------------------------

#define ACC_EARLY_ROUND_MAX 4
#define ACC_EARLY_SPAWN_MULT 1.35
#define ACC_EARLY_SPAWN_MULT_R1 1.40
#define ACC_EARLY_SPEED_SCALE 1.15

#namespace acc_early_round_pacing;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function post_zm_main()
{
    acc_utility::log( "early round pacing: post_zm_main (chain max_zombie_func)" );

    if ( isdefined( level.max_zombie_func ) )
        level.acc_prev_max_zombie_func = level.max_zombie_func;
    else
        level.acc_prev_max_zombie_func = &zombie_utility::default_max_zombie_func;

    level.max_zombie_func = &acc_max_zombie_override;
}

function init()
{
    acc_utility::log( "early round pacing: init (on_ai_spawned speed)" );

    callback::on_ai_spawned( &on_zombie_spawned_speed );
}

// ---------------------------------------------------------------------------
// Spawn count — stock calls [[ level.max_zombie_func ]]( n_max, n_round )
// (UGX / community reference; verify in share/raw/scripts/zm/_zm.gsc if needed.)
// ---------------------------------------------------------------------------

function acc_max_zombie_override( n_max, n_round )
{
    base = [[ level.acc_prev_max_zombie_func ]]( n_max, n_round );

    mult = spawn_mult_for_round( n_round );
    if ( isdefined( level.acc_mod_round_zombie_mult ) )
        mult *= level.acc_mod_round_zombie_mult;

    // Integer ceil for positive values (avoid relying on math builtins).
    raw = base * mult;
    i = int( raw );
    if ( raw > i )
        return i + 1;
    return i;
}

function spawn_mult_for_round( round_number )
{
    if ( !isdefined( round_number ) || round_number < 1 )
        return 1;

    if ( round_number > ACC_EARLY_ROUND_MAX )
        return 1;

    if ( round_number == 1 )
        return ACC_EARLY_SPAWN_MULT_R1;

    return ACC_EARLY_SPAWN_MULT;
}

// ---------------------------------------------------------------------------
// Movement speed — applied on AI spawn (stacks with stock anim tier)
// ---------------------------------------------------------------------------

// VERIFIED(acc): callback::on_ai_spawned dispatches with NO args ON the
// spawned actor (callbacks_shared.gsc:43-49 'self thread [[callback]]()';
// dispatch site spawner_shared.gsc:583) - so zero params, use self.
// is_zombie() is a zero-param self method (zombie_utility.gsc:1320).
// ASMSetAnimationRate is the stock way to scale zombie move speed (zombie
// movement is anim-driven; Widow's Wine uses it, _zm_perk_widows_wine.gsc:443).
// Known caveat: Widow's Wine resets the rate to 1.0 when its slow expires -
// acceptable for rounds 1-4 where Widow's is rarely active.
function on_zombie_spawned_speed()
{
    if ( !( self zombie_utility::is_zombie() ) )
        return;

    // Sprint modifier: stock max-speed zombies from r1; skip our early boost.
    if ( isdefined( level.acc_mod_force_sprint ) && level.acc_mod_force_sprint )
        return;

    r = level.round_number;
    if ( !isdefined( r ) || r < 1 )
        return;

    if ( r > ACC_EARLY_ROUND_MAX )
        return;

    self ASMSetAnimationRate( ACC_EARLY_SPEED_SCALE );
}
