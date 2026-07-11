// =============================================================================
// _acc_exo.gsc - the Exo Suit Upgrade Station (docs/29).
//
// The BODY counterpart to the per-gun Weapon Overclock: per-PLAYER, with THREE augments that scale with the
// exo tier (mirroring the gun Overclock's 3 effects). This module owns ONLY the tier STATE + the buy station
// + the HUD; the EFFECTS live at their natural chokepoints:
//   1. DEPTH-SPEED gate - acc_utility::recompute_move_speed reads player.acc_trench_layer [bus_trench watcher]
//      + player.acc_exo_tier. Tier T -> normal speed in layers 1..T; below that -20% first uncovered layer,
//      -10%/layer deeper. (So you buy tiers to reach + fight in the deeper, richer layers.)
//   2. DAMAGE RESISTANCE - _acc_elites::on_player_damaged cuts ALL incoming damage by acc_exo_resist_per_tier
//      (default 6%/tier -> -30% at T5, -60% at T10; user 2026-07-08: 5% -> 6%).
//   3. KNIFE/MELEE damage - _acc_damage::on_ai_damage adds +acc_exo_melee_per_tier per tier to the player's
//      melee hits (default +30%/tier -> +150% at T5).
//
// Tiers 0-5, costs 5/10/15/20/25 (Data Shards). resistance + melee re-added 2026-06-22 (were dropped 06-21).
// =============================================================================

#using scripts\shared\hud_util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

// Station model: a Cyber City white metal workbench as a body-augment chamber (stock t7_props, proven packable).
// STATION REMODEL (user 2026-07-09, docs/09): Cryogen stasis pod (58x53x114, T7-dump carve
// acc_t7_props_stations.gdt) - a body-augmentation pod, no longer the white workbench the
// Implant Bench shares. Pod ORIGIN IS MID-BODY (measured floorLift 63): spawn +63 z or it sinks.
#precache( "model", "p7_cry_cryogen_pod_exterior" );

#define ACC_EXO_MAX 10   // user 2026-06-24: 5 -> 10 tiers. Resist (+6%/t, clamped -80%; user 2026-07-08: 5% -> 6%) + melee (+30%/t) keep scaling; the DEPTH gate past L5 is inert until the abyss has layers 6-10 (geometry, not GSC).

#namespace acc_exo;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "exo init" );
    level.acc_exo_station_origins = [];   // [acc] proximity origins for the LUI report card (read by _acc_perk_info)
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
    sync_exo_hud( player );   // [acc] (re)create + refresh the always-on EXO tier readout
}

// ---------------------------------------------------------------------------
// Cost
// ---------------------------------------------------------------------------

function exo_cost( target_tier )
{
    switch ( target_tier )
    {
    // Cost ladder (SHARED with the gun Overclock, user 2026-06-24): LINEAR +4/tier = 4 x tier.
    case 1:  return getdvarint( "acc_exo_cost_t1",  4 );
    case 2:  return getdvarint( "acc_exo_cost_t2",  8 );
    case 3:  return getdvarint( "acc_exo_cost_t3",  12 );
    case 4:  return getdvarint( "acc_exo_cost_t4",  16 );
    case 5:  return getdvarint( "acc_exo_cost_t5",  20 );
    case 6:  return getdvarint( "acc_exo_cost_t6",  24 );
    case 7:  return getdvarint( "acc_exo_cost_t7",  28 );
    case 8:  return getdvarint( "acc_exo_cost_t8",  32 );
    case 9:  return getdvarint( "acc_exo_cost_t9",  36 );
    case 10: return getdvarint( "acc_exo_cost_t10", 40 );
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

    // Exo station INSIDE the Foundry under-room (ORIGINAL size, user 2026-06-28 reverted a brief shrink): interior
    // x[-192,192] y[1379,1723], floor z=-240; the buyable door is the WEST front gap x[-192,-112]. Placed on the WEST
    // side at (-120,1550) (user 2026-06-26: the Exo station + the Neural Expansion Bay vendor sit on OPPOSITE sides
    // the long way - Exo WEST, vendor EAST at (120,1550)). Its .map collision clip moves to match
    // (tools/add_prop_clips.js exo_station) - a GEOMETRY change, so this build needs a FULL LED bake.
    spawn_station_at( ( -120, 1550, -240 ), 90 );
}

function spawn_station_at( origin, yaw )
{
    m = spawn( "script_model", origin + ( 0, 0, 63 ) );   // pod origin is mid-body (floorLift 63 from vertex bounds)
    m setmodel( "p7_cry_cryogen_pod_exterior" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (memory script-trigger-needs-ignoreteam)
    t SetCursorHint( "HINT_NOICON" );
    // Buyable-UI copy pass (2026-07-03): richer card text + the station's live tier/cost
    // feedback moved INTO this hint (station_loop updates it; old hud_msg popups removed).
    t SetHintString( "Hold ^3[{+activate}]^7  ^5EXO SUIT^7 - augment: walk deeper, resist more, hit harder (Data Shards)" );
    t.acc_station_model = m;
    t thread station_loop();

    // Record the station origin so _acc_perk_info's proximity card lights up the EXO REPORT card here.
    if ( !isdefined( level.acc_exo_station_origins ) ) level.acc_exo_station_origins = [];
    level.acc_exo_station_origins[ level.acc_exo_station_origins.size ] = origin;

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

        // FEEDBACK CHANNEL REWORK (user 2026-07-03): hud_msg popups -> TRIGGER HINT updates,
        // so the Aetherium default card carries the tier/cost/result. Bounded strings (<=25).
        if ( player.acc_exo_tier >= ACC_EXO_MAX )
        {
            self SetHintString( "^5EXO SUIT^7 - Tier " + ACC_EXO_MAX + "/" + ACC_EXO_MAX + " MAX - fully augmented" );
            wait 0.4;
            continue;
        }

        next_tier = player.acc_exo_tier + 1;
        cost = exo_cost( next_tier );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            self SetHintString( "^5EXO SUIT^7 - Tier " + next_tier + " costs ^5" + cost + " Data Shards^7 - hold ^3[{+activate}]^7 to augment" );
            wait 0.4;
            continue;
        }

        player.acc_exo_tier = next_tier;
        player PlaySound( "acc_shard_pickup" );
        acc_utility::recompute_move_speed( player );   // the slow cancellation takes effect now
        sync_exo_hud( player );                        // refresh the always-on EXO readout
        // Vague (docs/31): the "Tier N/5" shows progress; effects stay qualitative. Exact %s are in docs/29.
        self SetHintString( "^5EXO SUIT^7 - Tier " + next_tier + "/" + ACC_EXO_MAX +
                            " ^7- faster, tougher, stronger melee - hold ^3[{+activate}]^7 to augment again" );
        wait 0.4;
    }
}

// ---------------------------------------------------------------------------
// Always-on HUD readout (server-side font string, mirrors _acc_data_shards' DATA SHARDS
// line). Used INSTEAD of a LUI clientfield because the clientuimodel pool is full
// (the always-on overclock "vN" took the last dead field). Sits one line under the
// DATA SHARDS count; dim at tier 0 so it's discoverable, bright once augmented. The
// DETAILED "what it does" report is the proximity card at the station (_acc_perk_info
// + acc_hud.lua), not this compact readout.
// ---------------------------------------------------------------------------
function sync_exo_hud( player )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !isdefined( player.acc_exo_tier ) ) player.acc_exo_tier = 0;

    // Top-left EXO readout RECLAIMED (user 2026-06-27): it was hidden (alpha 0) - the SQUAD roster shows the tier
    // now - but a HIDDEN server hudelem STILL occupies a slot in the SHARED, fixed per-client pool. Freeing it
    // makes room for the roster's one-row "points SH EXO MB" stats line without overflowing the ~31/client pool in
    // 4-player co-op (memory server-hudelem-pool-exhaustion-coop). The tier lives in player.acc_exo_tier; the
    // roster (_acc_health_bars::update_roster) reads it directly, so nothing visible is lost.
}
