// =============================================================================
// _acc_events_hack.gsc - Hack Terminal side event (Corporate Plaza)
//
// Design reference: docs/06_mechanics.md (Hack Terminal state machine).
//
// State machine:
//   Available -> Active -> (Success | Failed)
//   Success   -> Consumed (locked unless Parallel Processing = 2 attempts)
//   Failed    -> Locked (spawns penalty wave)
//
// Three back-to-back stages. Each stage has an objective + timer.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_HACK_ACTIVATION_COST_POINTS 500
#define ACC_HACK_REWARD_SHARDS 2

#namespace acc_events_hack;

function init()
{
    acc_utility::log( "events_hack init" );

    level.acc_hack_state = "available";
    level.acc_hack_attempts_used = 0;

    level thread watch_terminal();
}

function watch_terminal()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_hack_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "hack: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

function terminal_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );

        if ( !can_attempt( player ) )
        {
            player iprintln( "Hack Terminal: unavailable" );
            wait( 0.5 );
            continue;
        }

        if ( player.score < ACC_HACK_ACTIVATION_COST_POINTS )
        {
            player iprintln( "Hack Terminal: needs " + ACC_HACK_ACTIVATION_COST_POINTS + " points" );
            wait( 0.5 );
            continue;
        }

        // VERIFIED(acc): never write player.score directly - stock spends via
        // zm_score::minus_to_player_score (_zm_score.gsc:551), which also syncs
        // pers["score"], stats, the "spent_points" notify, and free-purchase
        // GobbleGum handling.
        player zm_score::minus_to_player_score( ACC_HACK_ACTIVATION_COST_POINTS );
        level.acc_hack_state = "active";
        level.acc_hack_attempts_used += 1;

        result = run_hack_sequence( player );
        if ( result == "success" )
        {
            acc_data_shards::grant_player( player, ACC_HACK_REWARD_SHARDS, "hack_terminal" );
            // TODO(acc-oc): grant a free Overclock roll voucher as documented
            // once overclock voucher system exists.
            level.acc_hack_state = "consumed";

            if ( !player_has_parallel_processing( player ) ||
                 level.acc_hack_attempts_used >= 2 )
            {
                // Stay consumed - terminal locked permanently.
            }
            else
            {
                // Allow second attempt.
                level.acc_hack_state = "available";
            }
        }
        else
        {
            level.acc_hack_state = "locked";
            level thread spawn_penalty_wave();
        }

        wait( 1.0 );
    }
}

function can_attempt( player )
{
    if ( level.acc_hack_state == "locked" ) return false;
    if ( level.acc_hack_state == "consumed" ) return false;
    if ( level.acc_hack_state == "active" ) return false;
    return true;
}

function player_has_parallel_processing( player )
{
    if ( !isdefined( player.acc_cw_events_retry ) ) return false;
    return player.acc_cw_events_retry == true;
}

// ---------------------------------------------------------------------------
// Three-stage hack sequence
// ---------------------------------------------------------------------------

function run_hack_sequence( player )
{
    stages = build_stages( level.round_number );

    for ( i = 0; i < stages.size; i++ )
    {
        stage = stages[ i ];
        player iprintln( "Hack Stage " + ( i + 1 ) + "/" + stages.size + ": " + stage.prompt );
        ok = run_stage( player, stage );
        if ( !ok )
        {
            player iprintln( "Hack FAILED" );
            return "failed";
        }
    }

    player iprintln( "Hack SUCCESS" );
    return "success";
}

function build_stages( round_number )
{
    stages = [];

    stages[ 0 ] = stage(
        "Kill 10 zombies in 40s",
        40,
        &stage_requirement_kills, 10, "any"
    );

    // Stage 2 rotates based on round. Before r11, fallback to quick-kill chaff.
    if ( round_number >= 11 )
    {
        stages[ 1 ] = stage(
            "Kill 3 Shielded elites in 60s",
            60,
            &stage_requirement_elite_kills, 3, "shielded"
        );
    }
    else
    {
        stages[ 1 ] = stage(
            "Kill 15 zombies in 30s",
            30,
            &stage_requirement_kills, 15, "any"
        );
    }

    stages[ 2 ] = stage(
        "Kill 15 zombies with headshots in 45s",
        45,
        &stage_requirement_headshots, 15, "any"
    );

    return stages;
}

function stage( prompt, timer, requirement_func, count, flavor )
{
    s = spawnstruct();
    s.prompt = prompt;
    s.timer = timer;
    s.requirement = requirement_func;
    s.count = count;
    s.flavor = flavor;
    return s;
}

function run_stage( player, stage )
{
    // Start a kill counter tracked per-player, reset per stage.
    player.acc_hack_stage_counter = 0;

    // Hook zombie_killed: increment counter if this stage's requirement matches.
    level thread count_hook( player, stage );

    elapsed = 0;
    while ( elapsed < stage.timer )
    {
        wait( 0.5 );
        elapsed += 0.5;
        if ( player.acc_hack_stage_counter >= stage.count )
        {
            player notify( "acc_hack_stage_done" );
            return true;
        }
    }
    player notify( "acc_hack_stage_timeout" );
    return false;
}

// VERIFIED(acc): there is no level-wide "zombie_killed" notify in stock (the
// only notify site is on the PLAYER, no args, insta-kill path only -
// _zm_powerups.gsc:1463). The stock per-kill hook is
// zm_spawner::register_zombie_death_event_callback (_zm_spawner.gsc:2463),
// invoked ON the dying zombie with the attacker as arg; mod/hit-location live
// on the zombie (self.damagemod / self.damagelocation, _zm_spawner.gsc:1790).
function count_hook( player, stage )
{
    level.acc_hack_count_player = player;
    level.acc_hack_count_stage = stage;
    zm_spawner::register_zombie_death_event_callback( &acc_hack_zombie_death_watch );

    player util::waittill_any_return( "acc_hack_stage_done", "acc_hack_stage_timeout", "disconnect" );

    zm_spawner::deregister_zombie_death_event_callback( &acc_hack_zombie_death_watch );
    level.acc_hack_count_player = undefined;
    level.acc_hack_count_stage = undefined;
}

// self == the zombie that died (_zm_spawner::check_zombie_death_event_callbacks).
function acc_hack_zombie_death_watch( attacker )
{
    player = level.acc_hack_count_player;
    stage = level.acc_hack_count_stage;
    if ( !isdefined( player ) || !isdefined( stage ) ) return;
    if ( !isdefined( attacker ) || attacker != player ) return;
    if ( !player [[ stage.requirement ]]( self, self.damagemod, self.damagelocation, stage.flavor ) ) return;

    player.acc_hack_stage_counter += 1;
}

// Stage requirement functions. Return true if kill counts toward stage progress.
function stage_requirement_kills( zombie, mod, hit_location, flavor )
{
    return true;
}

function stage_requirement_elite_kills( zombie, mod, hit_location, flavor )
{
    if ( !isdefined( zombie.acc_is_elite ) ) return false;
    if ( !zombie.acc_is_elite ) return false;
    if ( flavor != "any" && zombie.acc_elite_class != flavor ) return false;
    return true;
}

function stage_requirement_headshots( zombie, mod, hit_location, flavor )
{
    // Hit location strings confirmed via damage-hook research. See
    // docs/16_gsc_reference.md section 2. "head" and "helmet" are the
    // common BO3 zombies variants.
    if ( !isdefined( hit_location ) ) return false;
    return hit_location == "head" || hit_location == "helmet";
}

// ---------------------------------------------------------------------------
// Penalty wave on failure
// ---------------------------------------------------------------------------

function spawn_penalty_wave()
{
    // ~8 zombies dumped near the terminal. Fast, aggressive.
    acc_utility::log( "hack: penalty wave" );
    // TODO(acc-verify): use zombie_utility::spawn_zombie on the nearest spawner
    // with forced high movement speed.
}
