// =============================================================================
// _acc_early_round_pacing.gsc - higher zombie COUNTS in rounds 1-4
//
// Design reference: docs/06_mechanics.md ("Early round pressure"),
// docs/04_progression_and_skills.md (Difficulty Curve).
//
// Rounds 1-4: +35% zombies vs stock max_zombie_func output (round 1 = +40%).
// From round 5 onward, stock counts unchanged (aside from modifiers).
//
// Move SPEED is no longer handled here - it moved to the all-round speed curve in
// _acc_zombie_speed.gsc (which replaced the Rampage Inducer, 2026-06-14). This
// module is spawn-count only now.
//
// post_zm_main() MUST run from zm_abandoned_cyber_city.gsc immediately after
// zm::main() so level.max_zombie_func is chained before the first round
// computes spawn totals.
// =============================================================================

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

// ---------------------------------------------------------------------------
// Tuning (keep in sync with docs/06_mechanics.md + docs/04_progression_and_skills.md)
// ---------------------------------------------------------------------------

#define ACC_EARLY_ROUND_MAX 4
#define ACC_EARLY_SPAWN_MULT 1.35
#define ACC_EARLY_SPAWN_MULT_R1 1.40

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
    // Spawn-count only now; the speed curve lives in _acc_zombie_speed.gsc.
    acc_utility::log( "early round pacing: init (spawn-count only)" );
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
