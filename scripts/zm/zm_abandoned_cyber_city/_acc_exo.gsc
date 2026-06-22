// =============================================================================
// _acc_exo.gsc - the Exo Suit Upgrade Station (docs/47).
//
// The BODY counterpart to the per-gun Weapon Overclock: per-PLAYER, and its sole job is to gate trench
// DEPTH. The trench descends in 5 layers, each slower (the per-layer slow lives in
// acc_utility::recompute_move_speed, which reads player.acc_trench_layer [set by the bus_trench watcher]
// + player.acc_exo_tier [owned here]). Each exo tier cancels the slow ONE layer deeper:
//   tier T -> normal speed in layers 1..T ; below that, -20% at the first uncovered layer, -10% per
//   layer deeper. So you buy exo tiers to reach (and fight in) the deeper, richer layers.
//
// This module owns ONLY the tier STATE + the buy station. Tiers 0-5, costs 5/10/15/20/25 (Data Shards).
// =============================================================================

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

// Station model: a freestanding metal bench (stock t7 prop; the old Cyberware kiosk model, now free).
#precache( "model", "p7_cai_work_table_metal_03_white" );

#namespace acc_exo;

#define ACC_EXO_MAX 5

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "exo init" );
    level thread spawn_station();
}

function on_player_connect( player )
{
    if ( !isdefined( player.acc_exo_tier ) )
        player.acc_exo_tier = 0;
}

function on_player_spawned( player )
{
    // Re-apply move speed on (re)spawn: SetMoveSpeedScale resets to 1 every spawn, so the exo's
    // trench-slow cancellation (and the trench slow itself) must be recomputed or it's lost after
    // death/revive. recompute reads acc_trench_layer (0 at a surface spawn) + acc_exo_tier.
    acc_utility::recompute_move_speed( player );
}

// ---------------------------------------------------------------------------
// Cost
// ---------------------------------------------------------------------------

function exo_cost( target_tier )
{
    switch ( target_tier )
    {
    case 1: return getdvarint( "acc_exo_cost_t1", 5 );
    case 2: return getdvarint( "acc_exo_cost_t2", 10 );
    case 3: return getdvarint( "acc_exo_cost_t3", 15 );
    case 4: return getdvarint( "acc_exo_cost_t4", 20 );
    case 5: return getdvarint( "acc_exo_cost_t5", 25 );
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Station
// ---------------------------------------------------------------------------

function spawn_station()
{
    level endon( "end_game" );
    wait 1.5;   // after data_shards + bus_trench so the trench + models are ready
    if ( getdvarint( "acc_exo_on", 1 ) != 1 )
        return;

    // In the trench pit (guaranteed floor, layer 1), east side - clear of the perk vendor (-250,1820),
    // caches (+/-360,1950) and reactor (0,2120). docs/47: ideally the surface entrance; move to a
    // docs/45 anchor when the geometry agent provides a landing above the pit.
    spawn_station_at( ( 250, 1800, -240 ), 180 );
}

function spawn_station_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_cai_work_table_metal_03_white" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (memory script-trigger-needs-ignoreteam)
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5EXO SUIT^7 - upgrade to walk deeper (Data Shards)" );
    t.acc_station_model = m;
    t thread station_loop();
    acc_utility::log( "exo: station spawned at " + origin );
}

function station_loop()   // self = the station trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;
        if ( !isdefined( player.acc_exo_tier ) ) player.acc_exo_tier = 0;

        if ( player.acc_exo_tier >= ACC_EXO_MAX )
        {
            player acc_utility::hud_msg( "^5EXO SUIT^7 - fully augmented (Tier " + ACC_EXO_MAX + "/" + ACC_EXO_MAX + ")" );
            wait 0.4;
            continue;
        }

        next_tier = player.acc_exo_tier + 1;
        cost = exo_cost( next_tier );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            player acc_utility::hud_msg( "^5EXO SUIT^7 - Tier " + next_tier + " costs ^5" + cost + " Data Shards" );
            wait 0.4;
            continue;
        }

        player.acc_exo_tier = next_tier;
        player PlaySound( "acc_shard_pickup" );
        acc_utility::recompute_move_speed( player );   // the slow cancellation takes effect now
        player acc_utility::hud_msg( "^5EXO SUIT^7 - Tier " + next_tier + "/" + ACC_EXO_MAX +
                                     " ^7- walk normal down to layer " + next_tier );
        wait 0.4;
    }
}
