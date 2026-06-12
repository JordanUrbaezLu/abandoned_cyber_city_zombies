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
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;

#namespace acc_main;

// Run before zm::main() so we can register callbacks the stock framework fires.
function pre_init()
{
    acc_utility::log( "pre_init start" );

    // Modifiers are read BEFORE everything else because they can mute/replace
    // subsystems (e.g. "Shardless" disables _acc_data_shards pickup logic).
    acc_modifiers::pre_init();

    // Map randomizer runs next - every other system may read rolled state.
    acc_map_randomizer::pre_init();

    callback::on_connect( &on_player_connect );
    callback::on_spawned( &on_player_spawned );
    callback::on_disconnect( &on_player_disconnect );

    acc_utility::log( "pre_init done" );
}

// Run after zm::main() has finished bootstrapping stock systems.
function init()
{
    acc_utility::log( "init start" );

    acc_early_round_pacing::init();
    acc_coop_scaling::init();

    // Decontamination must arm its acc_round_start listener before
    // watch_round_transitions below can fire the first one; it also rolls
    // the per-run seal permutation.
    acc_decontamination::init();

    // Order matters: data_shards owns the currency HUD, so it initializes before
    // cyberware / overclocks / emergency_drop which all read/write it.
    acc_data_shards::init();
    acc_cyberware::init();
    acc_overclocks::init();
    acc_elites::init();
    acc_events_hack::init();
    acc_events_overload::init();
    acc_emergency_drop::init();
    acc_boss::init();
    acc_boss_items::init();
    acc_mega_bottles::init();
    acc_weapon_abilities::init();
    // Points must init before damage so record_damage is available on the first hit.
    acc_points::init();
    // Damage hooks go last so they sit on top of any hook other modules register.
    acc_damage::init();

    level thread watch_round_transitions();

    acc_utility::log( "init complete" );
}

// NOTE: there is intentionally no client_init() here. In BO3 the client VM
// (.csc) cannot call into server scripts (.gsc) - client-side _acc_ modules
// will be separate .csc files when the LUI/HUD work lands in Phase 4.

// Per-player setup, fires when a player joins (lobby or mid-game).
function on_player_connect()
{
    self endon( "disconnect" );
    acc_utility::log_player( self, "connected" );

    acc_data_shards::on_player_connect( self );
    acc_cyberware::on_player_connect( self );
    acc_overclocks::on_player_connect( self );
    acc_modifiers::on_player_connect( self );
    acc_boss_items::on_player_connect( self );
    acc_mega_bottles::on_player_connect( self );
    acc_weapon_abilities::on_player_connect( self );
}

// Fires on every respawn (round start, revive, map load).
function on_player_spawned()
{
    self endon( "disconnect" );

    // Guard so one-time setup doesn't run multiple times.
    if ( !isdefined( self.acc_first_spawn_done ) )
    {
        self.acc_first_spawn_done = true;
        acc_utility::log_player( self, "first spawn" );
    }

    acc_data_shards::on_player_spawned( self );
    acc_cyberware::on_player_spawned( self );
}

function on_player_disconnect()
{
    acc_utility::log_player( self, "disconnected" );
    acc_data_shards::on_player_disconnect( self );
}

// Dispatches `acc_round_start` / `acc_round_end` events that subsystems listen
// for. Using a single fan-out instead of every system hooking stock events
// independently keeps ordering controllable.
function watch_round_transitions()
{
    level endon( "end_game" );

    // VERIFIED(acc): "initial_blackscreen_passed" is a FLAG (_zm.gsc:1612 init,
    // _zm.gsc:530 set) - flag::wait_till returns immediately if already set,
    // a bare waittill would hang. Stock: zm_giant.gsc:726, _zm_magicbox.gsc:2182.
    level flag::wait_till( "initial_blackscreen_passed" );
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
