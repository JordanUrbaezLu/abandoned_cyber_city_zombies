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
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
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

#namespace acc_elites;

function init()
{
    acc_utility::log( "elites init" );

    level.acc_elite_active_count = 0;

    level thread round_pressure_loop();

    // VERIFIED(acc): "zombie_killed" is only ever notified on the PLAYER (and
    // only in the insta-kill path, _zm_powerups.gsc:1463) - a level waittill
    // would hang forever. The stock per-zombie death hook is
    // zm_spawner::register_zombie_death_event_callback (_zm_spawner.gsc:2463);
    // the callback runs ON the dying zombie with the attacker as arg
    // (usage example: _zm_perk_widows_wine.gsc:134).
    zm_spawner::register_zombie_death_event_callback( &on_elite_zombie_death );
}

// ---------------------------------------------------------------------------
// Round-level orchestration
// ---------------------------------------------------------------------------

function round_pressure_loop()
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

function elite_quota_for_round( round_number )
{
    // See docs/04_progression_and_skills.md "Difficulty Curve".
    if ( round_number < ACC_ELITE_SHIELDED_MIN_ROUND ) return 0;
    if ( round_number < 10 ) return 1; // ~1 shielded per round 5-9
    if ( round_number < 20 ) return 2;
    if ( round_number < 30 ) return 3;
    return 4;
}

function spawn_elites_over_round( quota, round_number )
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

function pick_elite_class_for_round( round_number )
{
    candidates = [];
    candidates[ candidates.size ] = "shielded";
    if ( round_number >= ACC_ELITE_TELEPORTER_MIN_ROUND ) candidates[ candidates.size ] = "teleporter";
    if ( round_number >= ACC_ELITE_EMP_MIN_ROUND ) candidates[ candidates.size ] = "emp";

    return candidates[ acc_utility::acc_rand_int( candidates.size ) ];
}

// ---------------------------------------------------------------------------
// Elite spawning
// ---------------------------------------------------------------------------

function spawn_elite( class_name )
{
    spawner = pick_elite_spawner();
    if ( !isdefined( spawner ) )
    {
        acc_utility::log( "elites: no spawner found, skipping" );
        return;
    }

    zombie = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( zombie ) ) return;

    // VERIFIED(acc): zombie_spawn_init (_zm_spawner.gsc:295) runs as a
    // frame-end spawn func ('waittillframeend', spawner_shared.gsc:581) and
    // resets health/maxhealth - promoting before it completes gets clobbered.
    // Wait pattern from _zm_ai_faller.gsc:168-171.
    while ( isdefined( zombie ) && !isdefined( zombie.zombie_init_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( zombie ) || !isalive( zombie ) ) return;

    zombie.acc_is_elite = true;
    zombie.acc_elite_class = class_name;

    switch ( class_name )
    {
    case "shielded":   promote_to_shielded( zombie );   break;
    case "teleporter": promote_to_teleporter( zombie ); break;
    case "emp":        promote_to_emp( zombie );        break;
    }

    level.acc_elite_active_count += 1;
    acc_utility::log( "spawned elite: " + class_name );
}

function pick_elite_spawner()
{
    // VERIFIED(acc): get_active_zombie_spawners does not exist in stock.
    // level.zombie_spawners is the stock spawner list - stock round_spawning
    // itself picks array::random( level.zombie_spawners ) (_zm.gsc:3804);
    // zone-aware placement is handled downstream by the zombie_location system.
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        return undefined;
    }
    return level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
}

// ---------------------------------------------------------------------------
// Class-specific promotions
// ---------------------------------------------------------------------------

function promote_to_shielded( z )
{
    // HP ~2x regular zombie. Front damage resistance.
    base_hp = z.maxhealth;
    z.maxhealth = base_hp * 2;
    z.health = z.maxhealth;
    z.acc_elite_front_damage_resist = 0.25; // take 25% from front

    // TODO(acc-model): attach a shield prop model and tweak color/FX.
}

function promote_to_teleporter( z )
{
    // Frailer than shielded. Gets a teleport ability on cooldown.
    z.maxhealth = int( z.maxhealth * 0.8 );
    z.health = z.maxhealth;
    z thread teleporter_ability_loop();
}

function teleporter_ability_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        wait( 8 + randomfloat( 4 ) ); // 8-12s cooldown

        target = acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( target ) ) continue;

        // VERIFIED(acc): clamp the computed point to the navmesh first -
        // stock pattern shared/ai/zombie.gsc:1192-1212 (GetClosestPointOnNavMesh
        // then ForceTeleport); raw offsets can land inside geometry/off-mesh.
        flank_pos = GetClosestPointOnNavMesh( target.origin + ( 300, 0, 0 ), 100, 30 );
        if ( !isdefined( flank_pos ) )
        {
            continue;
        }
        self forceteleport( flank_pos );
        // TODO(acc-fx): play teleport FX on both source and destination.
    }
}

function promote_to_emp( z )
{
    z.maxhealth = int( z.maxhealth * 1.5 );
    z.health = z.maxhealth;
    z.acc_emp_on_hit = true;
    // Damage callback in on_player_damaged_by_emp applies disable.
}

// ---------------------------------------------------------------------------
// Death / drop handling
// ---------------------------------------------------------------------------

// Registered via zm_spawner::register_zombie_death_event_callback in init().
// Runs ON the dying zombie (self) with the attacker as the only arg
// (dispatch: _zm_spawner.gsc:2344 'self [[ callback ]]( attacker )').
function on_elite_zombie_death( attacker )
{
    if ( !isdefined( self.acc_is_elite ) || !self.acc_is_elite )
    {
        return;
    }

    level.acc_elite_active_count = acc_utility::clamp_int( level.acc_elite_active_count - 1, 0, 99 );

    // Spawn shard pickup at corpse origin.
    acc_data_shards::spawn_pickup_at( self.origin, ACC_ELITE_SHARD_REWARD );

    // Subroutine T3 capstone - every 5th elite drops a random pickup.
    if ( isdefined( attacker ) && isplayer( attacker ) && isdefined( attacker.acc_cw_recursion_active ) )
    {
        attacker.acc_cw_recursion_counter += 1;
        if ( attacker.acc_cw_recursion_counter % 5 == 0 )
        {
            drop_recursion_powerup_at( self.origin );
        }
    }
}

function drop_recursion_powerup_at( origin )
{
    // VERIFIED(acc): zm_powerups::specific_powerup_drop( name, drop_spot )
    // (_zm_powerups.gsc:688; stock call pattern _zm_ai_dogs.gsc:292). All four
    // names are registered powerups (the powerup modules are #using'd by our
    // entry script, matching stock maps).
    options = [];
    options[ options.size ] = "full_ammo";
    options[ options.size ] = "insta_kill";
    options[ options.size ] = "double_points";
    options[ options.size ] = "nuke";

    name = options[ acc_utility::acc_rand_int( options.size ) ];
    level thread zm_powerups::specific_powerup_drop( name, origin );
    acc_utility::log( "recursion drop at " + origin );
}
