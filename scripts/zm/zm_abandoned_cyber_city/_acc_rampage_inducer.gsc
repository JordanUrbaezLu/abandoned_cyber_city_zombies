// =============================================================================
// _acc_rampage_inducer.gsc - Rampage Inducer (sprinting zombies + faster spawns)
//
// Typical zombies "Rampage Inducer" functionality: once activated, EVERY
// zombie sprints (regardless of round) and the wave spawns faster / denser.
// Activation:
//   - dvar `acc_rampage 1` (toggle on; `0` toggles back off) - for testing.
//   - an in-map trigger_use named "acc_rampage_inducer" if one is placed.
//
// Two spawn levers (both gated on level.acc_rampage_active, installed in
// post_zm_main so they're chained before round 1 computes anything):
//   - level.max_zombie_func        -> more zombies on screen at once
//   - level.func_get_zombie_spawn_delay -> shorter gap between spawns. NOTE:
//     stock RECOMPUTES level.zombie_vars["zombie_spawn_delay"] every round from
//     this func ptr (_zm.gsc:4502), so we must chain the FUNCTION (not poke the
//     value) for the speed-up to persist past the round it was turned on.
//
// Sprint: set_zombie_run_cycle_override_value("sprint") LOCKS the move speed -
// any later stock set_zombie_run_cycle is stored-not-applied while the override
// is set (zombie_utility.gsc:2078-2082), which is exactly the permanent-sprint
// behavior we want. Deactivate restores via set_zombie_run_cycle_restore_from_override.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_RAMPAGE_MAX_MULT   1.5    // +50% max simultaneous zombies
#define ACC_RAMPAGE_DELAY_MULT 0.25   // spawn interval x0.25 (~4x faster)
#define ACC_RAMPAGE_DELAY_MIN  0.1    // never below this many seconds

#namespace acc_rampage_inducer;

// ---------------------------------------------------------------------------
// Lifecycle - post_zm_main() runs synchronously from the entry script main()
// (after coop_scaling) so both spawn levers are chained before round 1.
// ---------------------------------------------------------------------------

function post_zm_main()
{
    acc_utility::log( "rampage: post_zm_main (chain spawn count + spawn delay)" );

    if ( isdefined( level.max_zombie_func ) )
        level.acc_rampage_prev_max_func = level.max_zombie_func;
    else
        level.acc_rampage_prev_max_func = &zombie_utility::default_max_zombie_func;
    level.max_zombie_func = &acc_rampage_max_override;

    // Defined by stock zm init (_zm.gsc:307) before this runs; guard anyway.
    if ( isdefined( level.func_get_zombie_spawn_delay ) )
    {
        level.acc_rampage_prev_delay_func = level.func_get_zombie_spawn_delay;
        level.func_get_zombie_spawn_delay = &acc_rampage_delay_override;
    }
}

function init()
{
    acc_utility::log( "rampage inducer: init" );

    level.acc_rampage_active = false;

    callback::on_ai_spawned( &on_zombie_spawned_rampage );

    level thread spawn_device();          // physical in-map device to interact with
    level thread watch_dvar_toggle();
    level thread watch_activation_triggers();
}

// Script-spawn a physical Rampage Inducer device (no Radiant rebuild needed):
// a kiosk model + a use trigger NAMED "acc_rampage_inducer" so the existing
// watch_activation_triggers()/rampage_trigger_think() adopt it (they set the
// hint + activate()). Walk up and hold Use to turn the rampage on.
function spawn_device()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // SPAWN PLAZA floor spot, inside start_zone (x[-1056..1094.5] y[-1073.5..928]),
    // forward-left of the player spawn (info_player_start ~(-227.5,-476.5)) and clear
    // of the spawn points + window barricade. Faces -Y toward the spawn so players see
    // the kiosk front as they spawn in.
    org = ( -600, 200, 14 );

    model = Spawn( "script_model", org );
    model.angles = ( 0, 270, 0 );
    model SetModel( "p7_zm_vending_nuke" ); // already loaded by our .map; reads as a kiosk
    model.targetname = "acc_rampage_inducer_model";
    level.acc_rampage_device_model = model;

    // radius 48 (>=40 engine min), height 72; lifted +30 to centre on the torso.
    trig = Spawn( "trigger_radius_use", org + ( 0, 0, 30 ), 0, 48, 72 );
    trig.targetname = "acc_rampage_inducer"; // adopted by watch_activation_triggers
    trig TriggerIgnoreTeam();
    level.acc_rampage_device_trig = trig;

    acc_utility::log( "rampage: spawned in-map device" );
}

// ---------------------------------------------------------------------------
// Spawn levers (no-op passthrough until activated)
// ---------------------------------------------------------------------------

function acc_rampage_max_override( n_max, n_round )
{
    base = [[ level.acc_rampage_prev_max_func ]]( n_max, n_round );

    if ( !IS_TRUE( level.acc_rampage_active ) )
        return base;

    raw = base * ACC_RAMPAGE_MAX_MULT;
    i = int( raw );
    if ( raw > i )
        return i + 1;
    return i;
}

function acc_rampage_delay_override( n_round )
{
    base = 2.0;
    if ( isdefined( level.acc_rampage_prev_delay_func ) )
        base = [[ level.acc_rampage_prev_delay_func ]]( n_round );

    if ( !IS_TRUE( level.acc_rampage_active ) )
        return base;

    scaled = base * ACC_RAMPAGE_DELAY_MULT;
    if ( scaled < ACC_RAMPAGE_DELAY_MIN )
        scaled = ACC_RAMPAGE_DELAY_MIN;
    return scaled;
}

// ---------------------------------------------------------------------------
// Sprint application
// ---------------------------------------------------------------------------

// callback::on_ai_spawned dispatches with no args ON the actor (see
// _acc_early_round_pacing for the verified contract). Lock new zombies to
// sprint while the inducer is active.
function on_zombie_spawned_rampage()
{
    if ( !IS_TRUE( level.acc_rampage_active ) )
        return;
    if ( !( self zombie_utility::is_zombie() ) )
        return;

    // Force the SPRINT run cycle = the engine's max base move speed (a rampage inducer
    // makes base zombies sprint; we do NOT scale past that). Clear any stale override
    // first so set_zombie_run_cycle actually re-applies (it early-returns if an override
    // is already set, zombie_utility.gsc:2078).
    self.zombie_move_speed_override = undefined;
    self zombie_utility::set_zombie_run_cycle_override_value( "sprint" );
}

function sprint_all_live_zombies()
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zombies = GetAITeamArray( team );
    for ( i = 0; i < zombies.size; i++ )
    {
        z = zombies[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        if ( !( z zombie_utility::is_zombie() ) ) continue;
        z.zombie_move_speed_override = undefined; // clear stale, then force sprint
        z zombie_utility::set_zombie_run_cycle_override_value( "sprint" );
    }
}

function restore_all_live_zombies()
{
    team = ( isdefined( level.zombie_team ) ? level.zombie_team : "axis" );
    zombies = GetAITeamArray( team );
    for ( i = 0; i < zombies.size; i++ )
    {
        z = zombies[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        if ( !isdefined( z.zombie_move_speed_override ) ) continue;
        z zombie_utility::set_zombie_run_cycle_restore_from_override();
    }
}

// ---------------------------------------------------------------------------
// Activation / deactivation
// ---------------------------------------------------------------------------

function activate()
{
    if ( IS_TRUE( level.acc_rampage_active ) )
        return;

    level.acc_rampage_active = true;
    // Tell early-round pacing to defer its speed boost to us (it checks this).
    level.acc_mod_force_sprint = true;

    // Apply the shorter delay to the CURRENT round right now (next-round
    // recompute already routes through our override).
    if ( isdefined( level.func_get_zombie_spawn_delay ) && isdefined( level.round_number ) )
        level.zombie_vars[ "zombie_spawn_delay" ] = [[ level.func_get_zombie_spawn_delay ]]( level.round_number );

    sprint_all_live_zombies();

    // KEEP-ALIVE: the sprint override decays over time (stock re-evaluates zombie
    // locomotion on round transitions / state changes and can clobber a one-shot
    // override - user saw "sprints then stops after ~a minute"). Re-assert sprint on
    // every live zombie on a short cadence for as long as the inducer is on, so it
    // PERSISTS. New spawns are still caught by on_zombie_spawned_rampage immediately.
    level notify( "acc_rampage_keepalive" );   // kill any prior loop (belt-and-suspenders)
    level thread rampage_keepalive();

    announce( "^1RAMPAGE INDUCER ACTIVATED" );
    acc_utility::log( "rampage: ACTIVATED" );
}

// Re-assert sprint on all live zombies while active. Self-terminates when the
// inducer is toggled off (level.acc_rampage_active=false) or a new activate()
// supersedes it (acc_rampage_keepalive notify) or the game ends.
function rampage_keepalive()
{
    level endon( "end_game" );
    level endon( "acc_rampage_keepalive" );

    while ( IS_TRUE( level.acc_rampage_active ) )
    {
        sprint_all_live_zombies();
        wait 2;
    }
}

function deactivate()
{
    if ( !IS_TRUE( level.acc_rampage_active ) )
        return;

    level.acc_rampage_active = false;
    level.acc_mod_force_sprint = undefined;

    if ( isdefined( level.func_get_zombie_spawn_delay ) && isdefined( level.round_number ) )
        level.zombie_vars[ "zombie_spawn_delay" ] = [[ level.func_get_zombie_spawn_delay ]]( level.round_number );

    restore_all_live_zombies();

    announce( "^3Rampage Inducer deactivated" );
    acc_utility::log( "rampage: deactivated" );
}

function announce( msg )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        if ( isdefined( players[ i ] ) )
            players[ i ] IPrintLnBold( msg );
    }
}

// ---------------------------------------------------------------------------
// Activation sources
// ---------------------------------------------------------------------------

// dvar `acc_rampage`: 1 = on, 0 = off. Polled so it works mid-match and can
// toggle both ways for testing.
function watch_dvar_toggle()
{
    level endon( "end_game" );

    for ( ;; )
    {
        // ACTIVATE-ONLY. The old deactivate-when-dvar==0 branch FOUGHT the device
        // toggle: acc_rampage defaults to 0, so it deactivated a device-activated
        // rampage ~1s later -> "zombies sprint for a few seconds then go back to
        // normal" + the device hint never flipped to OFF. The device (rampage_trigger_think)
        // is the sole toggle now; the dvar can still force it ON for console testing.
        want_on = ( getdvarint( "acc_rampage", 0 ) == 1 );
        if ( want_on && !IS_TRUE( level.acc_rampage_active ) )
            activate();
        wait 1;
    }
}

// Optional in-map device: a trigger_use named "acc_rampage_inducer". None is
// placed yet (GSC-only build), so this no-ops gracefully until one exists.
function watch_activation_triggers()
{
    level endon( "end_game" );

    triggers = [];
    for ( i = 0; i < 30; i++ )
    {
        triggers = GetEntArray( "acc_rampage_inducer", "targetname" );
        if ( triggers.size > 0 ) break;
        wait 0.5;
    }
    if ( triggers.size == 0 ) return;

    for ( i = 0; i < triggers.size; i++ )
        level thread rampage_trigger_think( triggers[ i ] );
    acc_utility::log( "rampage: " + triggers.size + " in-map activation trigger(s)" );
}

function rampage_trigger_think( trig )
{
    level endon( "end_game" );

    trig SetCursorHint( "HINT_NOICON" );
    trig SetHintString( "Hold ^3&&1^7 to activate the Rampage Inducer" );

    for ( ;; )
    {
        trig waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;

        // TOGGLE: each use flips the inducer on/off (the user must be able to turn it OFF).
        if ( IS_TRUE( level.acc_rampage_active ) )
        {
            deactivate();
            trig SetHintString( "Hold ^3&&1^7 to activate the Rampage Inducer" );
        }
        else
        {
            activate();
            trig SetHintString( "Rampage ^1ON^7 - Hold ^3&&1^7 to deactivate" );
        }
        wait 0.6; // debounce the hold
    }
}
