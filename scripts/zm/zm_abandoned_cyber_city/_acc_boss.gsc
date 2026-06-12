// =============================================================================
// _acc_boss.gsc - boss round orchestration
//
// Design reference: docs/11_enemies.md (Mini-Boss / Full Boss),
// docs/06_mechanics.md (boss rooms are the only forced-camp encounters).
//
// Round 10, 20: mini-boss replaces normal wave.
// Round 30, 40, 50+: full boss "Subroutine Core" in the Lab.
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_perks;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#define ACC_BOSS_MINI_FIRST_ROUND 10
#define ACC_BOSS_FULL_FIRST_ROUND 30
#define ACC_BOSS_INTERVAL 10

#namespace acc_boss;

function init()
{
    acc_utility::log( "boss init" );

    level thread round_hook_loop();

    // Dev/test loop: `acc_test_boss 1` in the console (or +set on launch)
    // spawns a low-HP Juggernaut Host every round from round 2, so the
    // Mega Bottle drop -> perk upgrade loop is testable without surviving
    // to round 10. Same code path as the real mini-boss.
    if ( getdvarint( "acc_test_boss", 0 ) == 1 )
    {
        level thread test_boss_loop();
    }
}

function test_boss_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        if ( round_number < 2 ) continue;

        wait 10; // let the round get going
        acc_utility::log( "TEST BOSS spawning (acc_test_boss dvar)" );
        spawn_juggernaut_host( 1500 ); // killable with the starting pistol era
    }
}

function round_hook_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        if ( round_number < ACC_BOSS_MINI_FIRST_ROUND ) continue;
        if ( round_number % ACC_BOSS_INTERVAL != 0 ) continue;

        if ( round_number >= ACC_BOSS_FULL_FIRST_ROUND )
        {
            level thread run_full_boss( round_number );
        }
        else
        {
            level thread run_mini_boss( round_number );
        }
    }
}

// ---------------------------------------------------------------------------
// Mini-boss
// ---------------------------------------------------------------------------

function run_mini_boss( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    count = ( round_number >= 20 ) ? 2 : 1;
    acc_utility::log( "mini boss round " + round_number + " spawning " + count );

    for ( i = 0; i < count; i++ )
    {
        spawn_juggernaut_host();
    }
}

function spawn_juggernaut_host( n_health_override )
{
    // Buffed-regular-zombie mini-boss: the stock mechz archetype needs DLC1
    // zone assets a usermap lacks (behavior tree / models / FX), so the
    // practical Juggernaut Host is the same proven pattern as _acc_elites:
    // spawn a normal zombie, wait for init, then promote it.
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss: no zombie_spawners, cannot spawn Juggernaut Host" );
        return;
    }

    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
    host = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( host ) )
    {
        acc_utility::log( "boss: spawn_zombie returned undefined (spawner missing script_forcespawn?)" );
        return;
    }

    // VERIFIED(acc): zombie_spawn_init runs at frame end and clobbers
    // health/maxhealth - poll the init flag before promoting (the
    // _zm_ai_faller.gsc:168 pattern, same as _acc_elites.gsc:129).
    while ( isdefined( host ) && !isdefined( host.zombie_init_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( host ) || !isalive( host ) ) return;

    host.acc_is_mini_boss = true; // boss headshot multiplier in _acc_damage

    // HP: docs/11_enemies.md mini-boss ~50k solo baseline; the test loop
    // passes a small override so the drop loop is testable at round 2.
    if ( isdefined( n_health_override ) )
    {
        host.maxhealth = n_health_override;
    }
    else
    {
        host.maxhealth = 50000;
    }
    host.health = host.maxhealth;

    // Boss durability set, mirrored from stock mechz spawn setup
    // (mechz.gsc:946-957) + the spawn-failsafe opt-out (zombie_utility:1825).
    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host.no_gib = true;
    host.ignore_nuke = true;
    host.ignore_round_spawn_failsafe = true;
    host.zombie_move_speed = "run";

    host thread watch_mini_boss_death();

    acc_utility::log( "spawned Juggernaut Host (" + host.maxhealth + " hp)" );
}

function watch_mini_boss_death()
{
    self waittill( "death", attacker );
    // Regular boss-item drop (50% chance at mini tier).
    acc_boss_items::on_boss_death( "mini", attacker, self.origin );
    // Guaranteed Mega Bottle drop to all players.
    acc_mega_bottles::on_boss_death( "mini", attacker, self.origin );
}

// ---------------------------------------------------------------------------
// Full boss "Subroutine Core"
// ---------------------------------------------------------------------------

function run_full_boss( round_number )
{
    level endon( "end_game" );

    acc_utility::log( "FULL BOSS: Subroutine Core, round " + round_number );

    // Lock players in the Lab until boss is down. TODO(acc-geom): geometry
    // triggers to close Lab exits.

    boss = spawn_subroutine_core( round_number );
    if ( !isdefined( boss ) ) return;

    // VERIFIED(acc): must be threaded - a synchronous call would fire
    // "acc_boss_dead" before the waittill below is armed (GSC notifies are
    // not latched), hanging this thread and skipping rewards forever.
    level thread run_boss_phases( boss, round_number );

    level waittill( "acc_boss_dead" );

    reward_players( round_number );

    // Guaranteed boss-item drop. Killer is the player who landed the final
    // blow; tracked on `boss.acc_killer` when the damage pipeline kills the
    // boss (wired via _acc_damage in Phase 4).
    killer = undefined;
    if ( isdefined( boss.acc_killer ) ) killer = boss.acc_killer;
    acc_boss_items::on_boss_death( "full", killer, boss.origin );
    // Guaranteed Mega Bottle drop to all players.
    acc_mega_bottles::on_boss_death( "full", killer, boss.origin );

    release_lab_exits();
}

function spawn_subroutine_core( round_number )
{
    // TODO(acc-model): actual boss model + AI. For Phase 4 we use a big
    // hitpoint sphere with scripted attacks.
    spawn_struct = struct::get( "acc_boss_spawn", "targetname" );
    if ( !isdefined( spawn_struct ) )
    {
        acc_utility::log( "boss: no spawn struct placed" );
        return undefined;
    }

    b = spawnstruct();
    b.origin = spawn_struct.origin;
    b.maxhealth = scale_boss_hp( round_number );
    b.health = b.maxhealth;
    b.phase = 1;
    // Flag for _acc_damage.gsc so headshots get the boss multiplier.
    b.acc_is_boss = true;
    return b;
}

function scale_boss_hp( round_number )
{
    base = 50000;
    rounds_past_30 = round_number - 30;
    if ( rounds_past_30 < 0 ) rounds_past_30 = 0;
    return base + ( rounds_past_30 * 15000 );
}

// ---------------------------------------------------------------------------
// Phase progression
// ---------------------------------------------------------------------------

function run_boss_phases( boss, round_number )
{
    // Phases at 66% and 33% HP trigger "system outage" debuffs.
    max_phases = ( round_number >= 40 ) ? 4 : 3;

    while ( boss.health > 0 )
    {
        wait( 0.5 );
        current_phase = compute_phase( boss, max_phases );
        if ( current_phase > boss.phase )
        {
            boss.phase = current_phase;
            level thread on_phase_transition( boss, current_phase );
        }
    }

    level notify( "acc_boss_dead" );
}

function compute_phase( boss, max_phases )
{
    frac = boss.health / boss.maxhealth;
    if ( frac > 0.66 ) return 1;
    if ( frac > 0.33 ) return 2;
    if ( frac > 0.15 ) return 3;
    return 4;
}

function on_phase_transition( boss, phase )
{
    acc_utility::log( "boss entering phase " + phase );

    switch ( phase )
    {
    case 2:
        disable_power_for( 60 );
        break;
    case 3:
        disable_perks_for( 60 );
        break;
    case 4:
        spawn_emp_elite_add();
        break;
    }
}

// VERIFIED(acc): there is no zm_power::turn_power_off_all in stock. Power is
// the "power_on" flag; stock watch_global_power reacts to clear/set
// (_zm_power.gsc:163-169; clear site :773, set pattern zm_giant.gsc:550).
function disable_power_for( duration )
{
    if ( !( level flag::get( "power_on" ) ) )
    {
        // Power was never activated; nothing to disable, and we must not
        // grant free power when the debuff ends.
        return;
    }

    acc_utility::log( "power disabled for " + duration + "s (boss debuff)" );
    level flag::clear( "power_on" );
    wait( duration );
    level flag::set( "power_on" );
    acc_utility::log( "power restored" );
}

// VERIFIED(acc): zm_perks::perk_lose_on_damage does not exist. The stock
// pause/unpause pair is perk_pause_all_perks / perk_unpause_all_perks
// (_zm_perks.gsc:1295/:1314; stock caller _zm_power.gsc:143).
function disable_perks_for( duration )
{
    acc_utility::log( "perks disabled for " + duration + "s (boss debuff)" );
    level thread zm_perks::perk_pause_all_perks();
    wait( duration );
    level thread zm_perks::perk_unpause_all_perks();
    acc_utility::log( "perks restored" );
}

function spawn_emp_elite_add()
{
    acc_utility::log( "boss phase 4 add: EMP elite" );
    // TODO: call acc_elites::spawn_elite( "emp" ) once arg visibility is fixed.
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

function reward_players( round_number )
{
    reward = compute_shard_reward( round_number );

    for ( i = 0; i < level.players.size; i++ )
    {
        acc_data_shards::grant_player( level.players[ i ], reward, "boss" );
        // TODO(acc-oc): grant overclock re-roll voucher once voucher system exists.
    }

    acc_utility::log( "boss rewarded " + reward + " shards to each player" );
}

function compute_shard_reward( round_number )
{
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND )           return 2; // r10 mini
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND + ACC_BOSS_INTERVAL ) return 3; // r20 mini
    if ( round_number == ACC_BOSS_FULL_FIRST_ROUND )           return 4; // r30 full
    return 4; // capped
}

function release_lab_exits()
{
    // TODO(acc-geom): reopen Lab exit doors locked during the fight.
}
