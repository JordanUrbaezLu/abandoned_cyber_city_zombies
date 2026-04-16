// =============================================================================
// _acc_main.gsc - orchestrator for the Abandoned Cyber City custom systems
//
// This module is the only thing the map entry script (zm_abandoned_cyber_city.gsc)
// needs to touch. It fans out to every other _acc_ module and owns the lifecycle
// (pre_init -> init -> round/player callbacks -> shutdown).
//
// Pattern stolen from stock _zm.gsc. Keep ordering stable; several modules
// depend on others being initialized first (see `init()`).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_cyberware;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;
#using scripts\zm\zm_abandoned_cyber_city\_acc_events_hack;
#using scripts\zm\zm_abandoned_cyber_city\_acc_events_overload;
#using scripts\zm\zm_abandoned_cyber_city\_acc_emergency_drop;
#using scripts\zm\zm_abandoned_cyber_city\_acc_modifiers;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_abilities;
#using scripts\zm\zm_abandoned_cyber_city\_acc_points;
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;

// Run before _zm::main() so we can register callbacks the stock framework fires.
pre_init()
{
    _acc_utility::log( "pre_init start" );

    // Modifiers are read BEFORE everything else because they can mute/replace
    // subsystems (e.g. "Shardless" disables _acc_data_shards pickup logic).
    _acc_modifiers::pre_init();

    // Map randomizer runs next - every other system may read rolled state.
    _acc_map_randomizer::pre_init();

    callback::on_connect( &on_player_connect );
    callback::on_spawned( &on_player_spawned );
    callback::on_disconnect( &on_player_disconnect );

    _acc_utility::log( "pre_init done" );
}

// Run after _zm::main() has finished bootstrapping stock systems.
init()
{
    _acc_utility::log( "init start" );

    _acc_early_round_pacing::init();

    // Order matters: data_shards owns the currency HUD, so it initializes before
    // cyberware / overclocks / emergency_drop which all read/write it.
    _acc_data_shards::init();
    _acc_cyberware::init();
    _acc_overclocks::init();
    _acc_elites::init();
    _acc_events_hack::init();
    _acc_events_overload::init();
    _acc_emergency_drop::init();
    _acc_boss::init();
    _acc_boss_items::init();
    _acc_mega_bottles::init();
    _acc_weapon_abilities::init();
    // Points must init before damage so record_damage is available on the first hit.
    _acc_points::init();
    // Damage hooks go last so they sit on top of any hook other modules register.
    _acc_damage::init();

    level thread watch_round_transitions();

    _acc_utility::log( "init complete" );
}

// Client-side counterpart. Called from .csc.
client_init()
{
    _acc_utility::log( "client_init" );
    _acc_data_shards::client_init();
    _acc_cyberware::client_init();
}

// Per-player setup, fires when a player joins (lobby or mid-game).
on_player_connect()
{
    self endon( "disconnect" );
    _acc_utility::log_player( self, "connected" );

    _acc_data_shards::on_player_connect( self );
    _acc_cyberware::on_player_connect( self );
    _acc_overclocks::on_player_connect( self );
    _acc_modifiers::on_player_connect( self );
    _acc_boss_items::on_player_connect( self );
    _acc_mega_bottles::on_player_connect( self );
    _acc_weapon_abilities::on_player_connect( self );
}

// Fires on every respawn (round start, revive, map load).
on_player_spawned()
{
    self endon( "disconnect" );

    // Guard so one-time setup doesn't run multiple times.
    if ( !isdefined( self.acc_first_spawn_done ) )
    {
        self.acc_first_spawn_done = true;
        _acc_utility::log_player( self, "first spawn" );
    }

    _acc_data_shards::on_player_spawned( self );
    _acc_cyberware::on_player_spawned( self );
}

on_player_disconnect()
{
    _acc_utility::log_player( self, "disconnected" );
    _acc_data_shards::on_player_disconnect( self );
}

// Dispatches `acc_round_start` / `acc_round_end` events that subsystems listen
// for. Using a single fan-out instead of every system hooking stock events
// independently keeps ordering controllable.
watch_round_transitions()
{
    level endon( "end_game" );

    level waittill( "initial_blackscreen_passed" );
    level notify( "acc_game_start" );

    previous_round = -1;

    for ( ;; )
    {
        // TODO(acc-verify): stock waits on "between_round_over" or similar.
        // Find the canonical name in share/raw/scripts/zm/_zm.gsc round loop.
        level waittill( "start_of_round" );

        if ( previous_round >= 0 )
        {
            level notify( "acc_round_end", previous_round );
        }

        level notify( "acc_round_start", level.round_number );
        previous_round = level.round_number;
    }
}
