// =============================================================================
// _acc_modifiers.gsc - opt-in rule-change modifiers
//
// Design reference: docs/07_replayability.md (Tier 3 - Modifiers).
//
// Modifiers are toggled at map load before anything else initializes, so
// they can override subsystem behavior cleanly.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

pre_init()
{
    _acc_utility::log( "modifiers pre_init" );

    level.acc_modifiers = [];

    // Modifiers are read from a config struct. In Phase 4 we wire this to a
    // main-menu UI; for Phase 3 we use devcommand flags.
    load_modifiers_from_config();

    apply_global_modifiers();

    log_active_modifiers();
}

on_player_connect( player )
{
    // Per-player modifier effects (e.g. Fragility HP cut) applied on connect.
    if ( is_active( "fragility" ) )
    {
        player.maxhealth = int( player.maxhealth * 0.5 );
        player.health = player.maxhealth;
    }
}

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

load_modifiers_from_config()
{
    // TODO(acc-config): parse a config file or UI struct. For now we flip
    // them via a dvar ("acc_mod_<name> 1" enables a modifier) so you can test
    // via in-game console:
    //   /set acc_mod_code_red 1
    //   /set acc_mod_shardless 1
    all = array(
        "code_red",
        "limited_liability",
        "fragility",
        "bleed_out",
        "draft_mode",
        "shardless",
        "one_shot",
        "roguelike_lite",
        "express",
        "sprint",
        "shortened_rounds"
    );

    for ( i = 0; i < all.size; i++ )
    {
        name = all[ i ];
        if ( getdvarint( "acc_mod_" + name, 0 ) == 1 )
        {
            level.acc_modifiers[ name ] = true;
        }
    }
}

is_active( name )
{
    if ( !isdefined( level.acc_modifiers ) ) return false;
    return isdefined( level.acc_modifiers[ name ] ) && level.acc_modifiers[ name ];
}

// ---------------------------------------------------------------------------
// Global application
// ---------------------------------------------------------------------------

apply_global_modifiers()
{
    if ( is_active( "code_red" ) )
    {
        level.acc_mod_elite_rate_mult = 1.5;
        level.acc_mod_zombie_hp_mult = 1.2;
    }

    if ( is_active( "limited_liability" ) )
    {
        level.acc_mod_no_jug = true;
    }

    if ( is_active( "bleed_out" ) )
    {
        level.acc_mod_bleed_out_mult = 0.5;
    }

    if ( is_active( "draft_mode" ) )
    {
        level.acc_mod_draft_mode = true;
        level thread draft_mode_loop();
    }

    if ( is_active( "shardless" ) )
    {
        level.acc_mod_shardless = true;
        level thread shardless_handout_loop();
    }

    if ( is_active( "one_shot" ) )
    {
        level.acc_mod_one_overclock_slot = true;
    }

    if ( is_active( "roguelike_lite" ) )
    {
        level.acc_mod_roguelike = true;
        level thread roguelike_down_hook();
    }

    if ( is_active( "express" ) )
    {
        level thread express_start();
    }

    if ( is_active( "sprint" ) )
    {
        level.acc_mod_force_sprint = true;
    }

    if ( is_active( "shortened_rounds" ) )
    {
        level.acc_mod_round_zombie_mult = 0.6;
    }
}

log_active_modifiers()
{
    keys = getarraykeys( level.acc_modifiers );
    if ( keys.size == 0 )
    {
        _acc_utility::log( "modifiers: none active" );
        return;
    }
    for ( i = 0; i < keys.size; i++ )
    {
        _acc_utility::log( "modifier ACTIVE: " + keys[ i ] );
    }
}

// ---------------------------------------------------------------------------
// Modifier loops (stubs)
// ---------------------------------------------------------------------------

draft_mode_loop()
{
    // Every 2 minutes, offer each player a 3-perk random pick.
    level endon( "end_game" );
    for ( ;; )
    {
        wait( 120 );
        _acc_utility::log( "draft: offering picks" );
        // TODO(acc-ui): LUI picker.
    }
}

shardless_handout_loop()
{
    level endon( "end_game" );
    // Round 10, 20, 30: free cyberware pick.
    target_rounds = array( 10, 20, 30 );
    for ( i = 0; i < target_rounds.size; i++ )
    {
        level util::waittill_round( target_rounds[ i ] ); // TODO(acc-verify): stock helper?
        _acc_utility::log( "shardless: free cyberware pick at round " + target_rounds[ i ] );
        // TODO(acc-ui): picker UI, one choice per branch offered.
    }
}

roguelike_down_hook()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "player_downed", player );
        // Remove lowest-cost cyberware node from the player.
        // TODO(acc-cw): implement remove_lowest_cost_node on _acc_cyberware.
        _acc_utility::log( "roguelike: downed, would remove lowest node" );
    }
}

express_start()
{
    level waittill( "initial_blackscreen_passed" );

    // Skip to round 10 and give each player 5000 points + 5 shards.
    // TODO(acc-verify): stock round-fast-forward helper exists? Otherwise loop
    // call round_spawn_failsafe with synthetic round increments.
    for ( i = 0; i < level.players.size; i++ )
    {
        level.players[ i ].score += 5000;
        level.players[ i ].acc_data_shards = 5;
    }
    _acc_utility::log( "express: starting at round 10 with bonus" );
}
