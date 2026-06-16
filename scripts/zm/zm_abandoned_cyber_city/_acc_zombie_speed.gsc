// =============================================================================
// _acc_zombie_speed.gsc - round-driven zombie move-speed curve (natural-gait)
//
// Replaces the old Rampage Inducer with a deterministic, EVERY-ROUND speed ramp
// (design: docs/11_enemies.md "Regular Zombie / speed curve").
//
// THE ENGINE CONSTRAINT (deep-researched 2026-06-15, see memory + docs/19):
// A BO3 normal zombie has NO continuous "move at X% speed" knob. Movement is
// ROOT-MOTION / animation-driven, so there are only two levers:
//   (1) the discrete run-cycle TIER (walk / run / sprint) - each a separate xanim
//       whose baked gait IS its ground speed (walk < run < sprint), set via
//       zombie_utility::set_zombie_run_cycle_override_value(); and
//   (2) ASMSetAnimationRate(float) - playback rate of the active tier's anim,
//       which (root motion) scales cadence AND ground distance/sec by the SAME
//       factor. So rate < 1.0 = literal SLOW-MOTION (the exact Widow's Wine slow
//       mechanism, WIDOWS_WINE_SLOW_FRACTION = 0.7). SetMoveSpeedScale is
//       PLAYER-only and does nothing to AI zombies (verified).
//
// CONSEQUENCE: you cannot get a smooth, exact-% ramp AND a natural gait. A slowed
// sprint LOOKS like slow-mo (user-rejected, twice). So this module gets "slower
// than max" from a SLOWER GAIT, and NEVER uses a rate below 1.0:
//   - Rounds 1 .. (sprint_round-1): the RUN gait (a natural JOG), playback rate
//     starting at 1.0 and creeping up jog_step % per round (a faster jog, never
//     slow-mo). The jog's intrinsic ground speed is the "slow start" (~70-80% of
//     sprint - the real value is baked into the xanim, hence approximate).
//   - Round sprint_round (default 10): the zombies break into the SPRINT gait at
//     rate 1.0 = base-game max speed. This is a deliberate, natural escalation
//     ("they start sprinting now"); sprint@1.0 comfortably exceeds the topped-out
//     jog, so the wave still steps UP (strictly monotonic).
//   - Round > sprint_round: sprint gait, rate 1.0 + sprint_step % per round above
//     (default +1%/round: R15 = 1.05, R20 = 1.10). rate > 1.0 = a faster sprint,
//     which reads fine (no slow-mo). The engine takes unbounded float here (stock
//     siegebot 1.429, apothicon 2.0), so there is NO upper clamp.
//
// Speed therefore rises EVERY round (jog creeps up, then steps to sprint, then
// sprint creeps up) and never plays below natural cadence.
//
// Tunable dvars (read live per spawn, so a console set affects new zombies):
//   acc_zspeed_sprint_round     (10)  first round the zombies use the SPRINT gait
//   acc_zspeed_jog_start_pct    (100) round-1 jog playback rate, % (100 = natural)
//   acc_zspeed_jog_step_pct     (2)   + jog playback % per round during the jog phase
//   acc_zspeed_sprint_start_pct (100) sprint playback rate at sprint_round (100 = natural)
//   acc_zspeed_sprint_step_pct  (1)   + sprint playback % per round after sprint_round
// (All rates are floored at 1.0 in code - we never animate below natural cadence.)
//
// Modifier hook: the per-run "sprint" modifier (level.acc_mod_force_sprint, set by
// _acc_modifiers.gsc) forces the SPRINT gait on every round (>= base-game max).
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_ZSPEED_SPRINT_ROUND_DEF    10   // round zombies break from jog into full sprint
#define ACC_ZSPEED_JOG_START_PCT_DEF   100  // round-1 jog playback rate (100 = natural jog cadence)
#define ACC_ZSPEED_JOG_STEP_PCT_DEF    2    // + jog playback % per round during the jog phase
#define ACC_ZSPEED_SPRINT_START_PCT_DEF 100 // sprint playback rate at sprint_round (100 = natural full sprint)
#define ACC_ZSPEED_SPRINT_STEP_PCT_DEF 1    // + sprint playback % per round after sprint_round
#define ACC_ZSPEED_KEEPALIVE_WAIT      1.5  // s between keep-alive re-assert sweeps

#namespace acc_zombie_speed;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "zombie speed: init (natural-gait: jog -> sprint @ R" +
        getdvarint( "acc_zspeed_sprint_round", ACC_ZSPEED_SPRINT_ROUND_DEF ) + ", then +" +
        getdvarint( "acc_zspeed_sprint_step_pct", ACC_ZSPEED_SPRINT_STEP_PCT_DEF ) + "%/round)" );

    callback::on_ai_spawned( &on_zombie_spawned_speed );
    level thread speed_keepalive();
}

// VERIFIED(acc): callback::on_ai_spawned dispatches with NO args ON the spawned
// actor (callbacks_shared.gsc:43-49). is_zombie() gates out dogs/bosses/specials.
function on_zombie_spawned_speed()
{
    if ( !( self zombie_utility::is_zombie() ) )
        return;

    self apply_speed_for_round( current_round() );
}

// ---------------------------------------------------------------------------
// Curve: which gait TIER, and the playback RATE (>= 1.0, never slow-mo)
// ---------------------------------------------------------------------------

function current_round()
{
    r = level.round_number;
    if ( !isdefined( r ) || r < 1 )
        return 1;
    return r;
}

function sprint_start_round()
{
    sr = getdvarint( "acc_zspeed_sprint_round", ACC_ZSPEED_SPRINT_ROUND_DEF );
    if ( sr < 1 )
        sr = 1;
    return sr;
}

// "run" (jog) before the sprint round, "sprint" from it on. The "sprint" run
// modifier forces the sprint gait on every round.
function tier_for_round( round )
{
    if ( IS_TRUE( level.acc_mod_force_sprint ) )
        return "sprint";
    if ( round < sprint_start_round() )
        return "run";
    return "sprint";
}

// Playback rate of the active gait, floored at 1.0 so we never animate below the
// gait's natural cadence (anything < 1.0 reads as slow-motion - see header).
function rate_for_round( round )
{
    sr = sprint_start_round();

    if ( round < sr && !IS_TRUE( level.acc_mod_force_sprint ) )
    {
        // Jog phase: natural jog at round 1, creeping faster each round.
        pct = getdvarint( "acc_zspeed_jog_start_pct", ACC_ZSPEED_JOG_START_PCT_DEF ) +
              ( round - 1 ) * getdvarint( "acc_zspeed_jog_step_pct", ACC_ZSPEED_JOG_STEP_PCT_DEF );
    }
    else
    {
        // Sprint phase (or forced sprint): full sprint at sprint_round, creeping
        // faster after. Forced-sprint before sprint_round = a flat base-max sprint.
        rounds_into_sprint = round - sr;
        if ( rounds_into_sprint < 0 )
            rounds_into_sprint = 0;
        pct = getdvarint( "acc_zspeed_sprint_start_pct", ACC_ZSPEED_SPRINT_START_PCT_DEF ) +
              rounds_into_sprint * getdvarint( "acc_zspeed_sprint_step_pct", ACC_ZSPEED_SPRINT_STEP_PCT_DEF );
    }

    rate = pct / 100.0;
    if ( rate < 1.0 )       // never below natural cadence => never slow-mo
        rate = 1.0;
    return rate;
}

// ---------------------------------------------------------------------------
// Application (self = a live regular zombie)
// ---------------------------------------------------------------------------

function apply_speed_for_round( round )
{
    // [acc] ROOT-CAUSE FIX 2026-06-15 (the Brutus "spawns then stands frozen" bug, confirmed via
    // [BRUTUS-DBG]: pm=move allowed, hasPath=Y, target=Y, goalSet=Y, yet moved=0 every tick).
    // Bosses drive a CUSTOM locomotion ASM (Brutus = the zm_brutus animtable; he sets self.is_zombie
    // = true for melee, so is_zombie() does NOT exclude him). set_zombie_run_cycle_override_value()
    // + ASMSetAnimationRate() below STOMP that custom ASM, leaving him with a valid path but no
    // locomotion animation -> he never translates, and the 1.5s keepalive sweep re-froze him forever.
    // NEVER touch a boss's speed - each boss owns its own movement (Glitch Stalker already opted out
    // via acc_boss_custom_speed; this generalizes it to every boss marker so the chokepoint covers
    // BOTH the on-spawn hook and the keepalive sweep).
    if ( IS_TRUE( self.is_boss ) || IS_TRUE( self.acc_boss_custom_speed ) ||
         IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
        return;

    tier = tier_for_round( round );
    rate = rate_for_round( round );

    // (Re)lock the gait tier ONLY when it has actually drifted. A one-shot override
    // DECAYS (stock re-evaluates locomotion on round/state change and clobbers it),
    // while ASMSetAnimationRate PERSISTS - so a drifted low tier @ our rate would be
    // wrong (this is what made "round 1 super slow" before the keep-alive). The guard
    // avoids re-rolling the body variant every sweep.
    if ( self.zombie_move_speed != tier ||
         !isdefined( self.zombie_move_speed_override ) ||
         self.zombie_move_speed_override != tier )
    {
        self.zombie_move_speed_override = undefined;
        self zombie_utility::set_zombie_run_cycle_override_value( tier );
    }

    // Playback rate of the locked gait. >= 1.0 always (no slow-mo); > 1.0 past the
    // sprint round speeds the sprint up (valid unbounded float on this engine).
    self ASMSetAnimationRate( rate );

    self.acc_zspeed_round = round;
}

// ---------------------------------------------------------------------------
// Keep-alive: CONTINUOUSLY re-assert gait + rate on every live zombie. Load-bearing:
// a one-shot run-cycle override DECAYS (stock clobbers it), but ASMSetAnimationRate
// PERSISTS, so a spawn-only application drifts to the wrong gait @ our rate. The old
// Rampage Inducer hit the same decay and fixed it the same way. Skips zombies under
// an ACTIVE slow (Widow's Wine / trap own the anim rate while running, then reset it
// to 1.0 on expiry - zombie_utility.gsc:6195, _zm_perk_widows_wine.gsc:458/509) so we
// never cancel a perk the player paid for; the next sweep restores ours once it lets go.
// ---------------------------------------------------------------------------

function speed_keepalive()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait ACC_ZSPEED_KEEPALIVE_WAIT;

        r = current_round();
        team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
        zombies = GetAITeamArray( team );

        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            if ( !( z zombie_utility::is_zombie() ) ) continue;
            if ( z under_anim_slow() ) continue;   // don't fight an active slow
            if ( IS_TRUE( z.acc_boss_custom_speed ) ) continue; // boss owns its own speed think (Glitch Stalker)

            z apply_speed_for_round( r );          // drift-guarded re-lock + rate
        }
    }
}

// True while another system owns this zombie's anim rate (don't overwrite it).
function under_anim_slow()
{
    if ( IS_TRUE( self.b_widows_wine_slow ) )   return true;  // Widow's Wine web
    if ( IS_TRUE( self.b_widows_wine_cocoon ) ) return true;  // Widow's Wine cocoon
    if ( isdefined( self.a_n_slowdown_timeouts ) &&
         getarraykeys( self.a_n_slowdown_timeouts ).size > 0 )
        return true;                                          // generic trap slowdown
    return false;
}
