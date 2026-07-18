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
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;   // cyan "usable" holo on the pod

// Station model: a Cyber City white metal workbench as a body-augment chamber (stock t7_props, proven packable).
// STATION REMODEL (user 2026-07-09, docs/09): Cryogen stasis pod (58x53x114, T7-dump carve
// acc_t7_props_stations.gdt) - a body-augmentation pod, no longer the white workbench the
// Implant Bench shares. Pod ORIGIN IS MID-BODY (measured floorLift 63): spawn +63 z or it sinks.
#precache( "model", "p7_cry_cryogen_pod_exterior" );

#define ACC_EXO_MAX 10   // user 2026-06-24: 5 -> 10 tiers. Resist (+4%/t, clamped -80%; 5%->6% 2026-07-08, then 6%->4% 2026-07-13) + melee (+15%/t; halved from 30% 2026-07-18) keep scaling; the DEPTH gate past L5 is inert until the abyss has layers 6-10 (geometry, not GSC).

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
    wait 1.5;   // after data_shards so the shard economy + models are ready
    if ( getdvarint( "acc_exo_on", 1 ) != 1 )
        return;

    // Exo station MOVED to the PLAZA start room (user 2026-07-13; was the bus-station trench/Foundry under-room
    // @ (-120,1550,-240)). Plaza interior x[-470,213] y[-240,720], floor z=0. Placed at (-200,-100) on the open
    // spawn-band floor (players spawn x[-120,40] y[-90,-130]) - front-left of a spawning player, immediately
    // discoverable, and clear of the start box (100,-150), the leaderboard terminal (-340,-210) and all four
    // plaza caches. Its .map collision clip moves to match (tools/add_prop_clips.js exo_station -> a shallow z=0
    // worldspawn clip) - a GEOMETRY change, so this build needs a FULL LED bake.
    spawn_station_at( ( -200, -100, 0 ), 0 );
}

function spawn_station_at( origin, yaw )
{
    m = spawn( "script_model", origin + ( 0, 0, 63 ) );   // pod origin is mid-body (floorLift 63 from vertex bounds)
    m setmodel( "p7_cry_cryogen_pod_exterior" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );
    acc_interact_glow::glow_on( m );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (memory script-trigger-needs-ignoreteam)
    t SetCursorHint( "HINT_NOICON" );
    // Buyable-UI copy pass (2026-07-03): richer card text + the station's live tier/cost
    // feedback moved INTO this hint (station_hint_loop updates it; old hud_msg popups removed).
    t SetHintString( station_hint_text( undefined ) );   // discovery line until the keeper resolves a player at the pod
    t.acc_station_model = m;
    t thread station_loop();
    t thread station_hint_loop();

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

        // FEEDBACK CHANNEL REWORK (user 2026-07-03): hud_msg popups -> TRIGGER HINT updates, so the
        // Aetherium default card carries the tier/cost/result. The hint is written by station_hint_loop,
        // NOT here - see its header: a per-player tier written from this transaction latched the BUYER's
        // private state as the whole team's prompt. The keeper recomposes within 0.25s of this purchase,
        // so the tier still ticks up as the buyer's feedback - it is just addressed to the right player.
        // FAIL ACK (user 2026-07-15 "restore a fail message"). The keeper above made a failed press
        // COMPLETELY silent - no toast, no SFX, nothing - so you could not tell the button had even
        // registered. The ack rides hud_msg, NOT the hint, on purpose: hud_msg is a PER-PLAYER hudelem,
        // so it addresses only the presser - the shared trigger hint structurally cannot (that IS the
        // co-op bug the keeper just fixed). Same idiom _acc_emergency_drop already uses for its
        // "needs N Shards" refusal. This does NOT undo the 2026-07-03 rework: that removed the popup
        // that DISPLAYED your tier on a SUCCESSFUL trigger (the standing tier/cost still lives on the
        // hint, and success is still silent-but-visible there) - it never asked for failures to be mute.
        if ( player.acc_exo_tier >= ACC_EXO_MAX )
        {
            player acc_utility::hud_msg( "^5EXO SUIT^7 - already Tier " + ACC_EXO_MAX + "/" + ACC_EXO_MAX + " MAX" );
            wait 0.4;
            continue;
        }

        next_tier = player.acc_exo_tier + 1;
        cost = exo_cost( next_tier );
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            player acc_utility::hud_msg( "^5EXO SUIT^7 - Tier " + next_tier + " needs ^5" + cost + "^7 Data Shards" );
            wait 0.4;
            continue;
        }

        player.acc_exo_tier = next_tier;
        player PlaySound( "acc_shard_pickup" );
        acc_interact_glow::glow_off( self.acc_station_model );   // first SUCCESSFUL use ends the discovery flash (user 2026-07-17)
        acc_utility::recompute_move_speed( player );   // the slow cancellation takes effect now
        sync_exo_hud( player );                        // refresh the always-on EXO readout
        wait 0.4;
    }
}

// ---------------------------------------------------------------------------
// Per-player hint on a SHARED trigger (the nearest-player keeper)
//
// acc_exo_tier is PER-PLAYER but SetHintString is ONE ENTITY-GLOBAL string on the single station
// trigger, so writing it from the transaction (as station_loop used to) LATCHED the last buyer's
// private tier as the whole TEAM's prompt: a Tier-10 player's press left "Tier 10/10 MAX - fully
// augmented" pinned for a teammate standing at Tier 0, telling them the map's core body-upgrade
// sink was finished and quoting them no price. The buy itself was always correct (station_loop
// reads `player`), so this was purely a display leak - and invisible SOLO, where the latched
// string is always your own truth. Same constraint _acc_perk_info:55 documents for the perk wall
// ("the shown price can't be per-player on a shared trigger").
//
// Fix = the keeper the Paradise PaP already proves (acc_pap_levels::paradise_pap_hint_loop): poll
// the player AT the pod and recompose from THEIR tier. Not perfect - two players inside the same
// trigger share the nearest one's string - but that is the best a one-string entity allows, and it
// beats a stale latch from a player who may be across the map. The per-player EXO REPORT card
// (_acc_perk_info: code 108+exo_tier) stays the exact per-player readout; the hint now agrees with
// it instead of contradicting it.
// ---------------------------------------------------------------------------

function station_hint_loop()   // self = the station trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        ht = station_hint_text( nearest_station_player( self.origin ) );
        // Only re-SetHintString when the TEXT changes (mirrors paradise_pap_hint_loop's
        // acc_last_pap_hint guard). The set is bounded - 10 tier/cost lines + MAX + the idle
        // discovery line = 12 strings - so it cannot overflow the 250-triggerstring cache; but an
        // unguarded 4x/sec set re-registers the same string every tick (pure waste, and the
        // looped-live-value anti-pattern that crashed the soul box).
        if ( !isdefined( self.acc_last_exo_hint ) || self.acc_last_exo_hint != ht )
        {
            self SetHintString( ht );
            self.acc_last_exo_hint = ht;
        }
        wait 0.25;
    }
}

// NOTE (memory lui-cursorhint-router-loose-weapon-matcher): ZMCursorHintNew.lua's isMysteryBoxWeapon
// hijacks any hint carrying "hold"+"for" with no buy/cost keyword into a blank Weapon card. Every
// string below is safe by construction - none contains the substring "for" ("fully"/"faster" do not),
// and the tier line also carries "costs". Keep it that way if this copy is ever reworded.
function station_hint_text( player )
{
    if ( !isdefined( player ) )
        return "Hold ^3[{+activate}]^7  ^5EXO SUIT^7 - augment: walk deeper, resist more, hit harder (Data Shards)";

    tier = ( isdefined( player.acc_exo_tier ) ? player.acc_exo_tier : 0 );
    if ( tier >= ACC_EXO_MAX )
        return "^5EXO SUIT^7 - Tier " + ACC_EXO_MAX + "/" + ACC_EXO_MAX + " MAX - fully augmented";

    // Carries the benefit copy as well as the price: once the keeper is live a player who walks up
    // BECOMES the nearest player, so the discovery line above is replaced before they can read it -
    // this line is the only one a buyer actually sees. Vague (docs/31): "Tier N/10" shows progress,
    // effects stay qualitative (exact %s are in docs/29); the DETAILED report is the proximity card.
    return "^5EXO SUIT^7 - Tier " + tier + "/" + ACC_EXO_MAX + " ^7- faster, tougher, stronger melee - next costs ^5" +
           exo_cost( tier + 1 ) + " Data Shards^7 - hold ^3[{+activate}]^7 to augment";
}

function nearest_station_player( origin )
{
    best = 10000;   // 100u - covers the whole 64u-radius / 80u-tall use trigger (feet-to-trigger-origin ~75u at the rim)
    np = undefined;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        // Same gate station_loop buys through: a DOWNED teammate lying at the pod can't augment,
        // so they must not claim the hint away from the player actually standing there to buy.
        if ( !acc_data_shards::is_player_alive( p ) ) continue;
        d = DistanceSquared( p.origin, origin );
        if ( d < best ) { best = d; np = p; }
    }
    return np;
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
