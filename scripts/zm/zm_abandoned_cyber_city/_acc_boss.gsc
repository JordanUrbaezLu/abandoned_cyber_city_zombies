// =============================================================================
// _acc_boss.gsc - boss round orchestration
//
// Design reference: docs/11_enemies.md (Mini-Boss / Full Boss),
// docs/06_mechanics.md (boss rooms are the only forced-camp encounters).
//
// Round 10, 20: mini-boss replaces normal wave.
// Round 30, 40, 50+: full boss "Subroutine Core" in the Lab.
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#define ACC_BOSS_MINI_FIRST_ROUND 10
#define ACC_BOSS_FULL_FIRST_ROUND 30
#define ACC_BOSS_INTERVAL 10

init()
{
    _acc_utility::log( "boss init" );

    level thread round_hook_loop();
}

round_hook_loop()
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

run_mini_boss( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    count = ( round_number >= 20 ) ? 2 : 1;
    _acc_utility::log( "mini boss round " + round_number + " spawning " + count );

    for ( i = 0; i < count; i++ )
    {
        spawn_juggernaut_host();
    }
}

spawn_juggernaut_host()
{
    // TODO(acc-verify): spawn a zombie actor, buff HP ~10x elite, make
    // stagger-immune to normal weapon damage, vulnerable to wonder weapon
    // / elemental overclocks.
    //
    // When spawned, flag the actor for our damage module:
    //   host.acc_is_mini_boss = true;
    // so _acc_damage.gsc applies the boss headshot multiplier.
    //
    // On death, call:
    //   host thread watch_mini_boss_death();
    // which triggers the boss-item drop (50% chance for mini-boss tier).
    _acc_utility::log( "spawned Juggernaut Host" );
}

watch_mini_boss_death()
{
    self waittill( "death", attacker );
    // Regular boss-item drop (50% chance at mini tier).
    _acc_boss_items::on_boss_death( "mini", attacker, self.origin );
    // Guaranteed Mega Bottle drop to all players.
    _acc_mega_bottles::on_boss_death( "mini", attacker, self.origin );
}

// ---------------------------------------------------------------------------
// Full boss "Subroutine Core"
// ---------------------------------------------------------------------------

run_full_boss( round_number )
{
    level endon( "end_game" );

    _acc_utility::log( "FULL BOSS: Subroutine Core, round " + round_number );

    // Lock players in the Lab until boss is down. TODO(acc-geom): geometry
    // triggers to close Lab exits.

    boss = spawn_subroutine_core( round_number );
    if ( !isdefined( boss ) ) return;

    run_boss_phases( boss, round_number );

    level waittill( "acc_boss_dead" );

    reward_players( round_number );

    // Guaranteed boss-item drop. Killer is the player who landed the final
    // blow; tracked on `boss.acc_killer` when the damage pipeline kills the
    // boss (wired via _acc_damage in Phase 4).
    killer = undefined;
    if ( isdefined( boss.acc_killer ) ) killer = boss.acc_killer;
    _acc_boss_items::on_boss_death( "full", killer, boss.origin );
    // Guaranteed Mega Bottle drop to all players.
    _acc_mega_bottles::on_boss_death( "full", killer, boss.origin );

    release_lab_exits();
}

spawn_subroutine_core( round_number )
{
    // TODO(acc-model): actual boss model + AI. For Phase 4 we use a big
    // hitpoint sphere with scripted attacks.
    spawn_struct = struct::get( "acc_boss_spawn", "targetname" );
    if ( !isdefined( spawn_struct ) )
    {
        _acc_utility::log( "boss: no spawn struct placed" );
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

scale_boss_hp( round_number )
{
    base = 50000;
    rounds_past_30 = round_number - 30;
    if ( rounds_past_30 < 0 ) rounds_past_30 = 0;
    return base + ( rounds_past_30 * 15000 );
}

// ---------------------------------------------------------------------------
// Phase progression
// ---------------------------------------------------------------------------

run_boss_phases( boss, round_number )
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

compute_phase( boss, max_phases )
{
    frac = boss.health / boss.maxhealth;
    if ( frac > 0.66 ) return 1;
    if ( frac > 0.33 ) return 2;
    if ( frac > 0.15 ) return 3;
    return 4;
}

on_phase_transition( boss, phase )
{
    _acc_utility::log( "boss entering phase " + phase );

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

disable_power_for( duration )
{
    // TODO(acc-verify): use _zm_power::turn_power_off_all() or equivalent.
    _acc_utility::log( "power disabled for " + duration + "s (boss debuff)" );
    wait( duration );
    _acc_utility::log( "power restored" );
}

disable_perks_for( duration )
{
    // TODO(acc-verify): _zm_perks::perk_lose_on_damage or manual lockout.
    _acc_utility::log( "perks disabled for " + duration + "s (boss debuff)" );
    wait( duration );
    _acc_utility::log( "perks restored" );
}

spawn_emp_elite_add()
{
    _acc_utility::log( "boss phase 4 add: EMP elite" );
    // TODO: call _acc_elites::spawn_elite( "emp" ) once arg visibility is fixed.
}

// ---------------------------------------------------------------------------
// Rewards
// ---------------------------------------------------------------------------

reward_players( round_number )
{
    reward = compute_shard_reward( round_number );

    for ( i = 0; i < level.players.size; i++ )
    {
        _acc_data_shards::grant_player( level.players[ i ], reward, "boss" );
        // TODO(acc-oc): grant overclock re-roll voucher once voucher system exists.
    }

    _acc_utility::log( "boss rewarded " + reward + " shards to each player" );
}

compute_shard_reward( round_number )
{
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND )           return 2; // r10 mini
    if ( round_number == ACC_BOSS_MINI_FIRST_ROUND + ACC_BOSS_INTERVAL ) return 3; // r20 mini
    if ( round_number == ACC_BOSS_FULL_FIRST_ROUND )           return 4; // r30 full
    return 4; // capped
}

release_lab_exits()
{
    // TODO(acc-geom): reopen Lab exit doors locked during the fight.
}
