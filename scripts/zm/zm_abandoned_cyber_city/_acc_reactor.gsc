// =============================================================================
// _acc_reactor.gsc - the "Reactor Surge": the underground CLIMAX event (docs/45).
//
// OWNER SPLIT (docs/45): the SYSTEM (this module) owns the event LOGIC + the Arm
// Plinth interactable + the tier-dialed payout. The GEOMETRY agent owns the Core
// room, the seal door, and the FX seam. INTERFACE: the §3 anchor (Plinth at
// 0,2120,-240, on the existing pit floor at the Core entrance) + a named seal
// entity "acc_reactor_seal" (OPTIONAL - the surge runs OPEN in the pit until that
// geometry lands; it is still a real "survive the horde" challenge because the
// spawned zombies persist and hunt the armer).
//
// LOOP: pay shards at the Plinth -> a timed, escalating zombie SURGE erupts from
// the pit floor (reusing acc_bus_trench::spawn_corp_surge - tagged low-payout /
// ignore_enemy_count, so it never disturbs the round count) -> survive it -> a
// TIER-DIALED payout (shards + Insta-Kill + a Mega Bottle). Each completion raises
// the tier: the next Surge costs more and pays more. You don't farm it - you raid it.
//
// All GSC, no geometry. Dvar acc_reactor_on (default 1) gates the whole feature.
// =============================================================================

#using scripts\zm\_zm_powerups;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

// Plinth model: a verified-packing stock kiosk (same family as the altar base). Placed in the
// pit, far from the perk vendor, with a distinct red REACTOR prompt - no player confusion.
#precache( "model", "p7_cai_sign_inteactive_kiosk" );

#namespace acc_reactor;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "reactor init" );
    level.acc_reactor_busy = false;        // one Surge at a time
    level.acc_reactor_used_round = false;  // once-per-round activation (user 2026-06-19)
    level thread spawn_reactor();
    level thread reactor_round_reset();
}

// Re-arm the once-per-round activation each round. Arms before watch_round_transitions fires the first
// acc_round_start (reactor::init runs mid-init), so it never misses a round.
function reactor_round_reset()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start" );
        level.acc_reactor_used_round = false;
    }
}

function spawn_reactor()
{
    level endon( "end_game" );
    wait 1.5;   // after data_shards / bus_trench / glitch_altar so models + pit risers are ready
    if ( getdvarint( "acc_reactor_on", 1 ) != 1 )
        return;

    // §3 anchor: the Arm Plinth at the Core entrance off the pit. (0,2120,-240) is on the EXISTING
    // pit floor (y < 2173 pit edge); the Core ROOM + seal door land later (parallel geometry, docs/45).
    spawn_plinth_at( ( 0, 2120, -240 ), 270 );
}

function spawn_plinth_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_cai_sign_inteactive_kiosk" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t.acc_plinth_model = m;
    t reactor_set_hint();
    t thread reactor_loop();
    acc_utility::log( "reactor: Arm Plinth spawned at " + origin );
}

// ---------------------------------------------------------------------------
// Cost / reward dial (scale with the completed-Surge tier).
// ---------------------------------------------------------------------------

// FREE to activate, once per round; survive the surge -> a flat reward to EVERYONE (user 2026-06-19).
function reactor_reward() { return getdvarint( "acc_reactor_reward", 3 ); }   // shards PER PLAYER on success

function reactor_set_hint()   // self = the plinth trigger
{
    if ( level.acc_reactor_busy )
        self SetHintString( "^1REACTOR CRITICAL^7 - surge in progress" );
    else if ( level.acc_reactor_used_round )
        self SetHintString( "^1REACTOR^7 - recharging (once per round)" );
    else
        self SetHintString( "Hold ^3[{+activate}]^7  ^1REACTOR SURGE^7 - survive for ^5" + reactor_reward() +
                            " Data Shards^7 each + Insta-Kill (once/round)" );
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

function reactor_loop()   // self = the plinth trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;

        if ( level.acc_reactor_busy )
        {
            player acc_utility::hud_msg( "^1REACTOR^7 - already critical!" );
            wait 0.4;
            continue;
        }
        if ( level.acc_reactor_used_round )
        {
            player acc_utility::hud_msg( "^1REACTOR^7 - recharging (once per round)" );
            wait 0.4;
            continue;
        }

        // FREE to activate (it's a reward event now, not a paid sink).
        self thread run_surge( player );
        wait 0.4;
    }
}

function run_surge( player )   // self = the plinth trigger
{
    self endon( "death" );
    level endon( "end_game" );

    level.acc_reactor_busy = true;
    level.acc_reactor_used_round = true;   // one activation per round (success OR fail)
    self reactor_set_hint();

    waves = getdvarint( "acc_reactor_waves", 3 );
    per   = getdvarint( "acc_reactor_wave_count", 6 );   // fixed wave size (no more tier scaling)
    gap   = getdvarfloat( "acc_reactor_wave_interval", 6.0 );

    level notify( "acc_reactor_started" );
    seal_close();
    if ( acc_data_shards::is_player_alive( player ) )
        player acc_utility::hud_msg( "^1REACTOR SURGE^7 - SURVIVE!" );

    for ( i = 0; i < waves; i++ )
    {
        // Reuse the pit-surge machinery: erupts `per` zombies from the pit floor risers, tagged
        // low-payout + ignore_enemy_count (so the round count is untouched). The trench-aggro
        // system beelines/sprints them at the armer.
        level thread acc_bus_trench::spawn_corp_surge( per );
        if ( acc_data_shards::is_player_alive( player ) )
            player acc_utility::hud_msg( "^1REACTOR^7 - wave " + ( i + 1 ) + "/" + waves );
        wait( gap );
    }

    wait 2;   // let the last wave commit before we judge survival
    seal_open();
    level.acc_reactor_busy = false;
    self reactor_set_hint();
    level notify( "acc_reactor_ended" );

    // Payout ONLY if the armer SURVIVED IN THE DANGER ZONE - alive AND still underground (else you could
    // arm it, climb out of the pit to safety, and collect free). acc_reactor_require_pit 0 relaxes it.
    survived = acc_data_shards::is_player_alive( player ) &&
               ( getdvarint( "acc_reactor_require_pit", 1 ) == 0 || acc_bus_trench::player_in_underground( player ) );
    if ( !survived )
    {
        if ( acc_data_shards::is_player_alive( player ) )
            player acc_utility::hud_msg( "^1REACTOR FAILED^7 - you abandoned the core (stay in the pit!)" );
        level notify( "acc_reactor_failed" );
        return;
    }

    // Success: EVERYONE gets reactor_reward() shards + a shared Insta-Kill (user 2026-06-19).
    reward = reactor_reward();
    players = level.players;
    for ( i = 0; i < players.size; i++ )
        acc_data_shards::grant_player( players[ i ], reward, "reactor" );
    level thread zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
    player PlaySound( "acc_shard_pickup" );
    player acc_utility::hud_msg( "^2REACTOR STABILIZED^7 - everyone +" + reward + " Data Shards + Insta-Kill!" );
}

// ---------------------------------------------------------------------------
// Sealed-arena hook (docs/45 §5). If the parallel geometry agent has placed a seal door
// (script_brushmodel targetname "acc_reactor_seal") that listens for these notifies, the Core
// seals during a Surge. Until that geometry lands, getentarray is empty => harmless no-op and
// the surge runs OPEN in the pit. NEVER hard-depends on the unbuilt Core room.
// ---------------------------------------------------------------------------

function seal_close()
{
    doors = getentarray( "acc_reactor_seal", "targetname" );
    for ( i = 0; i < doors.size; i++ )
        doors[ i ] notify( "acc_reactor_seal_close" );
}

function seal_open()
{
    doors = getentarray( "acc_reactor_seal", "targetname" );
    for ( i = 0; i < doors.size; i++ )
        doors[ i ] notify( "acc_reactor_seal_open" );
}
