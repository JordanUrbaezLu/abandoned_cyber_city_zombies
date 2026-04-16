// =============================================================================
// _acc_elites.gsc - elite cyber-zombie spawn logic
//
// Design reference: docs/11_enemies.md (The Cast),
// docs/06_mechanics.md (Elite Timing).
//
// Three elite classes: Shielded (r5+), Teleporter (r11+), EMP (r21+).
// Spawning is driven by "pressure pulses" inside a round, not random spawn
// overrides, so elites feel deliberate.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

// ---------------------------------------------------------------------------
// Tuning (tuned against docs/04_progression_and_skills.md difficulty table)
// ---------------------------------------------------------------------------

#define ACC_ELITE_SHIELDED_MIN_ROUND 5
#define ACC_ELITE_TELEPORTER_MIN_ROUND 11
#define ACC_ELITE_EMP_MIN_ROUND 21

#define ACC_ELITE_SHARD_REWARD 1

init()
{
    _acc_utility::log( "elites init" );

    level.acc_elite_active_count = 0;

    level thread round_pressure_loop();

    // Listen for any zombie death; filter to elites and handle drops.
    level thread on_zombie_killed_loop();
}

// ---------------------------------------------------------------------------
// Round-level orchestration
// ---------------------------------------------------------------------------

round_pressure_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        quota = elite_quota_for_round( round_number );
        if ( quota <= 0 ) continue;

        level thread spawn_elites_over_round( quota, round_number );
    }
}

elite_quota_for_round( round_number )
{
    // See docs/04_progression_and_skills.md "Difficulty Curve".
    if ( round_number < ACC_ELITE_SHIELDED_MIN_ROUND ) return 0;
    if ( round_number < 10 ) return 1; // ~1 shielded per round 5-9
    if ( round_number < 20 ) return 2;
    if ( round_number < 30 ) return 3;
    return 4;
}

spawn_elites_over_round( quota, round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    // Spread the quota across the round at 20%, 50%, 80%, ... of round duration.
    // We use a hacky "wait a few seconds then spawn" model; real impl should
    // hook the stock round-clock if we want perfect timing.
    spacing_sec = 45; // TODO(acc-tune): scale with round expected length.

    for ( i = 0; i < quota; i++ )
    {
        wait( spacing_sec );
        class = pick_elite_class_for_round( round_number );
        spawn_elite( class );
    }
}

pick_elite_class_for_round( round_number )
{
    candidates = [];
    candidates[ candidates.size ] = "shielded";
    if ( round_number >= ACC_ELITE_TELEPORTER_MIN_ROUND ) candidates[ candidates.size ] = "teleporter";
    if ( round_number >= ACC_ELITE_EMP_MIN_ROUND ) candidates[ candidates.size ] = "emp";

    return candidates[ _acc_utility::acc_rand_int( candidates.size ) ];
}

// ---------------------------------------------------------------------------
// Elite spawning
// ---------------------------------------------------------------------------

spawn_elite( class_name )
{
    // TODO(acc-verify): stock zombie spawn flow is tangled.
    // Use zombie_utility::spawn_zombie on a zone spawner, then promote the
    // resulting actor to an elite by setting HP + class tags.
    spawner = pick_elite_spawner();
    if ( !isdefined( spawner ) )
    {
        _acc_utility::log( "elites: no spawner found, skipping" );
        return;
    }

    zombie = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( zombie ) ) return;

    zombie.acc_is_elite = true;
    zombie.acc_elite_class = class_name;

    switch ( class_name )
    {
    case "shielded":   promote_to_shielded( zombie );   break;
    case "teleporter": promote_to_teleporter( zombie ); break;
    case "emp":        promote_to_emp( zombie );        break;
    }

    level.acc_elite_active_count += 1;
    _acc_utility::log( "spawned elite: " + class_name );
}

pick_elite_spawner()
{
    // Prefer a spawner that's in the currently-active zone. Falls back to any
    // active spawner.
    active_spawners = zombie_utility::get_active_zombie_spawners();
    if ( active_spawners.size == 0 ) return undefined;
    return active_spawners[ _acc_utility::acc_rand_int( active_spawners.size ) ];
}

// ---------------------------------------------------------------------------
// Class-specific promotions
// ---------------------------------------------------------------------------

promote_to_shielded( z )
{
    // HP ~2x regular zombie. Front damage resistance.
    base_hp = z.maxhealth;
    z.maxhealth = base_hp * 2;
    z.health = z.maxhealth;
    z.acc_elite_front_damage_resist = 0.25; // take 25% from front

    // TODO(acc-model): attach a shield prop model and tweak color/FX.
}

promote_to_teleporter( z )
{
    // Frailer than shielded. Gets a teleport ability on cooldown.
    z.maxhealth = int( z.maxhealth * 0.8 );
    z.health = z.maxhealth;
    z thread teleporter_ability_loop();
}

teleporter_ability_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        wait( 8 + randomfloat( 4 ) ); // 8-12s cooldown

        target = _acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( target ) ) continue;

        // Teleport to a point 200-400 units from the target, ideally flanking.
        // TODO(acc-verify): use pathnode system to pick a valid nav position.
        flank_pos = target.origin + ( 300, 0, 0 );
        self forceteleport( flank_pos );
        // TODO(acc-fx): play teleport FX on both source and destination.
    }
}

promote_to_emp( z )
{
    z.maxhealth = int( z.maxhealth * 1.5 );
    z.health = z.maxhealth;
    z.acc_emp_on_hit = true;
    // Damage callback in on_player_damaged_by_emp applies disable.
}

// ---------------------------------------------------------------------------
// Death / drop handling
// ---------------------------------------------------------------------------

on_zombie_killed_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "zombie_killed", zombie, attacker );

        if ( !isdefined( zombie ) ) continue;
        if ( !isdefined( zombie.acc_is_elite ) ) continue;
        if ( !zombie.acc_is_elite ) continue;

        level.acc_elite_active_count = _acc_utility::clamp_int( level.acc_elite_active_count - 1, 0, 99 );

        // Spawn shard pickup at corpse origin.
        _acc_data_shards::spawn_pickup_at( zombie.origin, ACC_ELITE_SHARD_REWARD );

        // Subroutine T3 capstone - every 5th elite drops a random pickup.
        if ( isdefined( attacker ) && isplayer( attacker ) && isdefined( attacker.acc_cw_recursion_active ) )
        {
            attacker.acc_cw_recursion_counter += 1;
            if ( attacker.acc_cw_recursion_counter % 5 == 0 )
            {
                drop_recursion_powerup_at( zombie.origin );
            }
        }
    }
}

drop_recursion_powerup_at( origin )
{
    // TODO(acc-verify): use stock powerup drop function from _zm_powerups.
    // Options: "full_ammo", "insta_kill", "double_points", "nuke".
    _acc_utility::log( "recursion drop at " + origin );
}
