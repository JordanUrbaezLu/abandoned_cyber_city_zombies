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

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_HACK_ACTIVATION_COST_POINTS 500
#define ACC_HACK_REWARD_SHARDS 2

init()
{
    _acc_utility::log( "events_hack init" );

    level.acc_hack_state = "available";
    level.acc_hack_attempts_used = 0;

    level thread watch_terminal();
}

watch_terminal()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_hack_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        _acc_utility::log( "hack: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

terminal_loop()
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

        player.score -= ACC_HACK_ACTIVATION_COST_POINTS;
        level.acc_hack_state = "active";
        level.acc_hack_attempts_used += 1;

        result = run_hack_sequence( player );
        if ( result == "success" )
        {
            _acc_data_shards::grant_player( player, ACC_HACK_REWARD_SHARDS, "hack_terminal" );
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

can_attempt( player )
{
    if ( level.acc_hack_state == "locked" ) return false;
    if ( level.acc_hack_state == "consumed" ) return false;
    if ( level.acc_hack_state == "active" ) return false;
    return true;
}

player_has_parallel_processing( player )
{
    if ( !isdefined( player.acc_cw_events_retry ) ) return false;
    return player.acc_cw_events_retry == true;
}

// ---------------------------------------------------------------------------
// Three-stage hack sequence
// ---------------------------------------------------------------------------

run_hack_sequence( player )
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

build_stages( round_number )
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

stage( prompt, timer, requirement_func, count, flavor )
{
    s = spawnstruct();
    s.prompt = prompt;
    s.timer = timer;
    s.requirement = requirement_func;
    s.count = count;
    s.flavor = flavor;
    return s;
}

run_stage( player, stage )
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

count_hook( player, stage )
{
    player endon( "acc_hack_stage_done" );
    player endon( "acc_hack_stage_timeout" );
    player endon( "disconnect" );

    for ( ;; )
    {
        level waittill( "zombie_killed", zombie, attacker, mod, hit_location );

        if ( !isdefined( attacker ) || attacker != player ) continue;
        if ( !player [[ stage.requirement ]]( zombie, mod, hit_location, stage.flavor ) ) continue;

        player.acc_hack_stage_counter += 1;
    }
}

// Stage requirement functions. Return true if kill counts toward stage progress.
stage_requirement_kills( zombie, mod, hit_location, flavor )
{
    return true;
}

stage_requirement_elite_kills( zombie, mod, hit_location, flavor )
{
    if ( !isdefined( zombie.acc_is_elite ) ) return false;
    if ( !zombie.acc_is_elite ) return false;
    if ( flavor != "any" && zombie.acc_elite_class != flavor ) return false;
    return true;
}

stage_requirement_headshots( zombie, mod, hit_location, flavor )
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

spawn_penalty_wave()
{
    // ~8 zombies dumped near the terminal. Fast, aggressive.
    _acc_utility::log( "hack: penalty wave" );
    // TODO(acc-verify): use zombie_utility::spawn_zombie on the nearest spawner
    // with forced high movement speed.
}
