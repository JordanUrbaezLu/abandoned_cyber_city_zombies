// =============================================================================
// _acc_modifiers.gsc - opt-in rule-change modifiers
//
// Design reference: docs/06_replayability.md (Tier 3 - Modifiers).
//
// Modifiers are toggled at map load before anything else initializes, so
// they can override subsystem behavior cleanly.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;   // express_start shard bonus via the grant funnel (coverage audit 2026-08-02)

#namespace acc_modifiers;

function pre_init()
{
    acc_utility::log( "modifiers pre_init" );

    level.acc_modifiers = [];

    // Modifiers are read from a config struct. In Phase 4 we wire this to a
    // main-menu UI; for Phase 3 we use devcommand flags.
    load_modifiers_from_config();

    apply_global_modifiers();

    log_active_modifiers();
}

function on_player_connect( player )
{
    // Per-player modifier effects (e.g. Fragility HP cut) applied on connect.
    if ( is_active( "fragility" ) )
    {
        player.maxhealth = int( player.maxhealth * 0.5 );
        player.health = player.maxhealth;
    }

    if ( is_active( "roguelike_lite" ) )
    {
        player thread roguelike_player_down_watch();
    }
}

// ---------------------------------------------------------------------------
// Config loading
// ---------------------------------------------------------------------------

function load_modifiers_from_config()
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

function is_active( name )
{
    if ( !isdefined( level.acc_modifiers ) ) return false;
    return isdefined( level.acc_modifiers[ name ] ) && level.acc_modifiers[ name ];
}

// ---------------------------------------------------------------------------
// Global application
// ---------------------------------------------------------------------------

function apply_global_modifiers()
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
        // Per-player down watcher attaches in on_player_connect - the
        // "player_downed" notify only ever fires ON the player entity
        // (_zm_laststand.gsc:270), never on level.
        level.acc_mod_roguelike = true;
    }

    if ( is_active( "express" ) )
    {
        level thread express_start();
    }

    if ( is_active( "sprint" ) )
    {
        // Consumed by _acc_zombie_speed.gsc: clamps every round's target to >=100%
        // (base-game max) and forces the sprint run cycle.
        level.acc_mod_force_sprint = true;
    }

    if ( is_active( "shortened_rounds" ) )
    {
        level.acc_mod_round_zombie_mult = 0.6;
    }
}

function log_active_modifiers()
{
    keys = getarraykeys( level.acc_modifiers );
    if ( keys.size == 0 )
    {
        acc_utility::log( "modifiers: none active" );
        return;
    }
    for ( i = 0; i < keys.size; i++ )
    {
        acc_utility::log( "modifier ACTIVE: " + keys[ i ] );
    }
}

// ---------------------------------------------------------------------------
// Modifier loops (stubs)
// ---------------------------------------------------------------------------

function draft_mode_loop()
{
    // Every 2 minutes, offer each player a 3-perk random pick.
    level endon( "end_game" );
    for ( ;; )
    {
        wait( 120 );
        acc_utility::log( "draft: offering picks" );
        // TODO(acc-ui): LUI picker.
    }
}

function shardless_handout_loop()
{
    level endon( "end_game" );
    // Round 10, 20, 30: free cyberware pick.
    // VERIFIED(acc): util::waittill_round does not exist in stock; the stock
    // round-wait pattern is level.round_number + "between_round_over"
    // (_zm.gsc:4555 notify site).
    target_rounds = array( 10, 20, 30 );
    for ( i = 0; i < target_rounds.size; i++ )
    {
        while ( level.round_number < target_rounds[ i ] )
        {
            level waittill( "between_round_over" );
        }
        acc_utility::log( "shardless: free cyberware pick at round " + target_rounds[ i ] );
        // TODO(acc-ui): picker UI, one choice per branch offered.
    }
}

// self = player. Attached from on_player_connect when roguelike_lite is on.
function roguelike_player_down_watch()
{
    level endon( "end_game" );
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "player_downed" );

        // Remove lowest-cost cyberware node from the player.
        // TODO(acc-cw): implement remove_lowest_cost_node on _acc_cyberware.
        acc_utility::log( "roguelike: downed, would remove lowest node" );

        // Stock _zm_laststand refire_player_downed() re-notifies
        // "player_downed" ~1s after a down if the player still has perks;
        // wait for the down to resolve so one down = one node removed.
        self util::waittill_any( "player_revived", "spawned_player" );
    }
}

function express_start()
{
    // VERIFIED(acc): flag, not notify - see _acc_main.gsc note.
    level flag::wait_till( "initial_blackscreen_passed" );

    // Skip to round 10 and give each player 5000 points + 5 shards.
    // VERIFIED(acc): zm_utility::zombie_goto_round (_zm_utility.gsc:5972) is
    // the stock fast-forward (resets totals, recalcs AI health, kills actives).
    level thread zm_utility::zombie_goto_round( 10 );

    for ( i = 0; i < level.players.size; i++ )
    {
        // VERIFIED(acc): add via zm_score so pers["score"] stays in sync
        // (_zm_score.gsc:521; direct += desyncs reconnect/host-migration).
        level.players[ i ] zm_score::add_to_player_score( 5000 );
        // Through the grant FUNNEL, not a raw field write (coverage audit 2026-08-02): the old
        // `= 5` bypassed the feed row + sync_shards_to_client AND would clobber a dev testing
        // stash down to 5. grant_player ADDS 5 (identical for a fresh ship run at 0), pops the
        // "+5 Data Shards" feed row, and keeps the HUD in sync.
        acc_data_shards::grant_player( level.players[ i ], 5, "modifier_express" );
    }
    acc_utility::log( "express: starting at round 10 with bonus" );
}
