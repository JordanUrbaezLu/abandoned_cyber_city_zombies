// =============================================================================
// _acc_elites.gsc - elite cyber-zombie spawn logic
//
// Design reference: docs/11_enemies.md (The Cast, Elite Quota Per Round,
// Co-op Scaling), docs/06_mechanics.md (Elite Timing).
//
// Three elite classes: Shielded (r5+), Teleporter (r11+), EMP (r21+).
// Spawning is driven by "pressure pulses" inside a round, not random spawn
// overrides, so elites feel deliberate.
//
// Also owns:
//  - The per-round reset of the elite-shard diminishing-returns counter
//    (player.acc_shards_elite_count_round, incremented by
//    acc_data_shards::grant_player for "elite_kill"-sourced grants).
//  - The EMP elite's on-hit debuff (point drain + Cyberware ability lockout)
//    via the stock player-damage callback chain.
// =============================================================================

#using scripts\shared\ai\zombie_utility;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;

// ---------------------------------------------------------------------------
// Tuning (tuned against docs/04_progression_and_skills.md difficulty table)
// ---------------------------------------------------------------------------

#define ACC_ELITE_SHIELDED_MIN_ROUND 5
#define ACC_ELITE_TELEPORTER_MIN_ROUND 11
#define ACC_ELITE_EMP_MIN_ROUND 21

#define ACC_ELITE_SHARD_REWARD 1

// EMP elite on-hit debuff (docs/11_enemies.md "Elite: EMP (Surge)").
#define ACC_ELITE_EMP_HIT_POINT_DRAIN 200
#define ACC_ELITE_EMP_HIT_DISABLE_SEC 5

#namespace acc_elites;

function init()
{
    acc_utility::log( "elites init" );

    level.acc_elite_active_count = 0;

    level thread round_pressure_loop();
    level thread watch_round_shard_counter_reset();

    // VERIFIED(acc): "zombie_killed" is only ever notified on the PLAYER (and
    // only in the insta-kill path, _zm_powerups.gsc:1463) - a level waittill
    // would hang forever. The stock per-zombie death hook is
    // zm_spawner::register_zombie_death_event_callback (_zm_spawner.gsc:2463);
    // the callback runs ON the dying zombie with the attacker as arg
    // (usage example: _zm_perk_widows_wine.gsc:134).
    zm_spawner::register_zombie_death_event_callback( &on_elite_zombie_death );

    // VERIFIED(acc): zm::register_player_damage_callback (_zm.gsc:5522-5530)
    // is the dispatched player-damage hook - player_damage_override (wired at
    // level.overridePlayerDamage, _zm.gsc:1341) runs
    // check_player_damage_callbacks as its FIRST step (_zm.gsc:5108-5110);
    // each callback runs ON the damaged player with 10 positional args, and
    // returning -1 means "damage unchanged, later callbacks still evaluate"
    // (_zm.gsc:5502-5519). An EARLIER callback returning non -1 short-circuits
    // us (e.g. the riotshield absorb path) - acceptable, those hits were
    // blocked anyway. Stock users: _zm_weap_riotshield.gsc:75,
    // _zm_weap_gravityspikes.gsc:108.
    zm::register_player_damage_callback( &on_player_damaged );
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

// The elite-shard diminishing-returns counter
// (player.acc_shards_elite_count_round, incremented by
// acc_data_shards::grant_player for "elite_kill"-sourced grants) is PER ROUND
// by design (docs/06_mechanics.md Data Shard Economy) - without this reset
// the low-round diminish became permanent once tripped. The reset lives here
// because elites own the elite-kill cadence.
function watch_round_shard_counter_reset()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        players = acc_utility::get_all_players();
        for ( i = 0; i < players.size; i++ )
        {
            players[ i ].acc_shards_elite_count_round = 0;
        }
    }
}

function elite_quota_for_round( round_number )
{
    // docs/11_enemies.md "Elite Quota Per Round": rounds 1-4 = 0, 5-10 = 1,
    // 11-19 = 2, 21-29 = 3, 30+ = 4+. The table skips round 20 (mini-boss
    // round - _acc_boss partly replaces that wave), so we hold the 11-19
    // value there rather than inventing a bigger number.
    if ( round_number < ACC_ELITE_SHIELDED_MIN_ROUND ) return 0; // 1-4
    if ( round_number <= 10 ) return 1;                          // 5-10
    if ( round_number <= 20 ) return 2;                          // 11-19 (+20)
    if ( round_number < 30 ) return 3;                           // 21-29
    return 4;                                                    // 30+
}

function spawn_elites_over_round( quota, round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    // Spread the quota across the round at 20%, 50%, 80%, ... of round duration.
    // We use a hacky "wait a few seconds then spawn" model; real impl should
    // hook the stock round-clock if we want perfect timing.
    spacing_sec = 38; // Moderate spawn-intensity tune 2026-06-18 (was 45).
                      // TODO(acc-tune): scale with round expected length.

    for ( i = 0; i < quota; i++ )
    {
        wait( spacing_sec );
        // VERIFIED(acc): 'class' is a reserved GSC keyword (TOKEN_CLASS) -
        // cannot be a variable name. First-compile finding 2026-06-12.
        elite_class = pick_elite_class_for_round( round_number );
        spawn_elite( elite_class );
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
//
// Every promotion multiplies HP by acc_coop_scaling::special_hp_mult() - the
// flat elite co-op curve (1.0 solo / 1.5 / 2.0 / 2.5 at 2/3/4 players;
// docs/11_enemies.md "Co-op Scaling": elites gain +50% HP per extra player,
// flatter than regular zombies so duos don't blender them). Sampled at
// promote time so mid-game joins are reflected on the next elite.
// ---------------------------------------------------------------------------

function promote_to_shielded( z )
{
    // HP ~2x regular zombie. Front damage resistance.
    base_hp = z.maxhealth;
    z.maxhealth = int( base_hp * 2 * acc_coop_scaling::special_hp_mult() );
    z.health = z.maxhealth;
    z.acc_elite_front_damage_resist = 0.25; // take 25% from front

    // TODO(acc-model): attach a shield prop model and tweak color/FX.
}

function promote_to_teleporter( z )
{
    // Frailer than shielded. Gets a teleport ability on cooldown.
    z.maxhealth = int( z.maxhealth * 0.8 * acc_coop_scaling::special_hp_mult() );
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
    z.maxhealth = int( z.maxhealth * 1.5 * acc_coop_scaling::special_hp_mult() );
    z.health = z.maxhealth;
    z.acc_emp_on_hit = true; // consumed by on_player_damaged below
}

// ---------------------------------------------------------------------------
// EMP elite on-hit debuff (docs/11_enemies.md: melee hit drains 200 points
// and locks the player's active Cyberware ability for 5s)
// ---------------------------------------------------------------------------

// Registered via zm::register_player_damage_callback in init(). Runs ON the
// damaged player (dispatch _zm.gsc:5511) for EVERY player damage event - keep
// the reject paths cheap. Return -1 = leave the damage unchanged.
function on_player_damaged( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    if ( !isdefined( iDamage ) || iDamage <= 0 ) return -1;

    // We only act on zombie MELEE. VERIFIED(acc): zombie melee on players arrives as meansofdeath
    // "MOD_MELEE" (shared/ai/zombie.gsc:402 / engine Melee()).
    if ( !isdefined( sMeansOfDeath ) || sMeansOfDeath != "MOD_MELEE" ) return -1;

    // This hook fires BEFORE player_damage_override's laststand/god-mode checks (_zm.gsc:5110 vs
    // :5137) - don't act on downed/invalid players.
    if ( !zm_utility::is_player_valid( self ) ) return -1;

    // EMP elite on-hit debuff (side effect; leaves the damage value alone).
    if ( isdefined( eAttacker ) && IS_TRUE( eAttacker.acc_emp_on_hit ) )
        self apply_emp_melee_debuff();

    // TRENCH per-layer melee bump (user 2026-06-21): a melee hit while you're in trench layer L hits
    // for +acc_trench_layer_dmg_add HP per layer (flat). This is the ONLY reliable lever - open-field zombie melee
    // deals engine Melee() WEAPON damage and ignores self.meleeDamage, so we scale the INCOMING hit
    // here. Returns the modified damage (check_player_damage_callbacks uses the first != -1 return,
    // _zm.gsc:5512); -1 = leave unchanged. Done LAST so the returned value reflects the scaling.
    scaled = acc_bus_trench::trench_melee_scaled( self, iDamage );
    if ( scaled != iDamage )
        return scaled;

    return -1; // unchanged
}

// Runs on the player. No waits - keeps the damage pipeline synchronous.
function apply_emp_melee_debuff()
{
    // Drain points, clamped so the score can't go negative
    // (minus_to_player_score subtracts blindly, _zm_score.gsc:565).
    n_drain = ACC_ELITE_EMP_HIT_POINT_DRAIN;
    if ( isdefined( self.score ) && n_drain > self.score ) n_drain = self.score; // reading score is fine; WRITES go through zm_score
    if ( n_drain > 0 )
    {
        // VERIFIED(acc): zm_score::minus_to_player_score (_zm_score.gsc:551)
        // is the sanctioned deduction path (same pattern as
        // _acc_events_hack.gsc:80); it syncs self.pers and stats internally.
        self zm_score::minus_to_player_score( n_drain );
    }

    // Active-Cyberware-ability lockout window (docs/11: "Phase Step locked
    // out"). Contract: ability runtimes (_acc_cyberware's Phase Step watcher,
    // _acc_weapon_abilities::try_activate_ability) must refuse activation
    // while gettime() < player.acc_cw_locked_until.
    self.acc_cw_locked_until = gettime() + ( ACC_ELITE_EMP_HIT_DISABLE_SEC * 1000 );
    self notify( "acc_emp_disabled", ACC_ELITE_EMP_HIT_DISABLE_SEC );
    self iprintln( "EMP surge! Cyberware locked for " + ACC_ELITE_EMP_HIT_DISABLE_SEC + "s" );
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

    // Trench-only economy (user 2026-06-19): elites are NOT a shard source by default - shards come
    // from the trench (pit caches + Trench Warden + Glitch Altar), so the topside elite drop here is
    // OFF unless re-enabled. Set `acc_elite_shard_drop 1` to restore the 1-shard corpse pickup.
    if ( getdvarint( "acc_elite_shard_drop", 0 ) )
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
