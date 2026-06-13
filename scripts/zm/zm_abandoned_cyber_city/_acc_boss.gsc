// =============================================================================
// _acc_boss.gsc - boss round orchestration
//
// Design reference: docs/11_enemies.md (Mini-Boss / Full Boss),
// docs/06_mechanics.md (boss rooms are the only forced-camp encounters).
//
// Round 10, 20: mini-boss REPLACES the normal wave (docs/11: "Spawn: replaces
// the normal round wave") - the wave budget is zeroed at round start
// (suppress_normal_wave), zombies already out remain, and the round ends when
// everything counted (Juggernaut Host included) is dead. r10 = 1 host,
// r20 = 2 simultaneous hosts.
// Round 30, 40, 50+: full boss "Subroutine Core" in the Lab - a REAL
// damageable actor spawned at the acc_boss_spawn struct and pinned in place
// (stationary by design, docs/11). Per docs/11 the full-boss fight runs
// ALONGSIDE normal waves ("constant chaff spawn during the fight"), so the
// Core neither gates round end nor consumes the wave's AI budget.
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

#insert scripts\shared\shared.gsh;

#define ACC_BOSS_MINI_FIRST_ROUND 10
#define ACC_BOSS_FULL_FIRST_ROUND 30
#define ACC_BOSS_INTERVAL 10

#namespace acc_boss;

function init()
{
    acc_utility::log( "boss init" );

    level thread round_hook_loop();

    // Dev/test loop: `acc_test_boss 1` in the console (works mid-match -
    // sampled every round) spawns a low-HP Juggernaut Host every round from
    // round 2, so the Mega Bottle drop -> perk upgrade loop is testable
    // without surviving to round 10. Same code path as the real mini-boss.
    level thread test_boss_loop();
}

function test_boss_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        if ( getdvarint( "acc_test_boss", 0 ) != 1 ) continue;
        if ( round_number < 2 ) continue;

        wait 10; // let the round get going
        acc_utility::log( "TEST BOSS spawning (acc_test_boss dvar)" );
        // NOTE: deliberately additive - the test loop never suppresses the
        // wave, only real mini-boss rounds do (run_mini_boss).
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

    // docs/11: the mini-boss REPLACES the wave. Suppress chaff first; the
    // host(s) spawned below then become the only thing gating round end
    // (they are counted - see spawn_juggernaut_host flag rationale).
    suppress_normal_wave( round_number );

    // Mini rounds are exactly 10 and 20 (round_hook_loop routes >= 30 to the
    // full boss), so this spawns 1 host at r10 and 2 simultaneous at r20.
    count = ( round_number >= 20 ? 2 : 1 );
    acc_utility::log( "mini boss round " + round_number + " spawning " + count );

    for ( i = 0; i < count; i++ )
    {
        spawn_juggernaut_host();
    }
}

// Zero the remaining wave budget so the boss round is boss-only.
// Call ONLY from a thread woken by "acc_round_start" (timing matters, below).
function suppress_normal_wave( round_number )
{
    // VERIFIED(acc): stock round_spawning sets level.zombie_total exactly once
    // at thread start (_zm.gsc:3714-3719) and is threaded BEFORE the
    // "start_of_round" notify (thread at _zm.gsc:4431, notify at :4433 - a GSC
    // thread runs to its first wait before the caller resumes). _acc_main
    // relays "acc_round_start" off "start_of_round" in the same frame, so by
    // the time we run here the total is already set and zeroing it cannot be
    // clobbered. The spawn loop then gates on it EVERY iteration:
    // `while( ... || level.zombie_total <= 0 ) wait(0.1)` (_zm.gsc:3735-3738),
    // so no new chaff spawns; zombies already out remain (typically the one
    // spawned synchronously at _zm.gsc:3808 before the notify) and the round
    // ends when everything counted is dead - round_wait polls
    // `get_current_zombie_count() > 0 || level.zombie_total > 0`
    // (_zm.gsc:4733).
    //
    // VERIFIED(acc): no insta-end race - round_wait sleeps 1s before its first
    // poll (_zm.gsc:4724) and the host below is spawned with no intervening
    // wait between this write and spawn_zombie's SpawnFromSpawner.
    //
    // Known leak (accepted): the stuck-zombie failsafe can re-queue a
    // timed-out chaff zombie via level.zombie_total++ when
    // level.put_timed_out_zombies_back_in_queue is set
    // (zombie_utility.gsc:1879-1886) - at worst one already-counted zombie
    // respawns; it cannot regrow the wave.
    acc_utility::log( "boss: suppressing normal wave for round " + round_number
        + " (zombie_total was " + level.zombie_total + ")" );
    level.zombie_total = 0;
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
        // docs/15: elites/bosses scale +50% per extra player.
        host.maxhealth = int( 50000 * acc_coop_scaling::special_hp_mult() );
    }
    host.health = host.maxhealth;

    // Boss durability set, mirrored from stock mechz spawn setup
    // (mechz.gsc:946-957). VERIFIED(acc): the boss is COUNTED toward round
    // end (no ignore_enemy_count - dying is the reward trigger; with the wave
    // suppressed it is the only round-end gate), so it must stay eligible for
    // the stock stuck-zombie failsafe (kills anything that moves <24in in 30s,
    // zombie_utility.gsc:1870) - opting out of both would let a pathing-stuck
    // boss soft-lock the round forever.
    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host.no_gib = true;
    host.ignore_nuke = true;
    // VERIFIED(acc): raw .zombie_move_speed writes skip the anim bookkeeping;
    // set_zombie_run_cycle is the stock setter.
    host zombie_utility::set_zombie_run_cycle( "run" );

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

    // Phase poller only handles transitions while the boss is alive; the
    // death watcher below is the single "acc_boss_dead" emitter.
    level thread run_boss_phases( boss, round_number );

    // VERIFIED(acc): threading the watcher before arming the waittill below is
    // race-free - GSC notifies are not latched, but "acc_boss_dead" can only
    // fire after the actor's "death" notify, which requires damage processed
    // in a later server frame, and there is no wait between these two lines.
    boss thread watch_full_boss_death();

    level waittill( "acc_boss_dead", killer, death_origin );

    reward_players( round_number );

    // Guaranteed boss-item drop + Mega Bottles, attributed to the real killer
    // (the player who landed the final blow, resolved in the death watcher).
    acc_boss_items::on_boss_death( "full", killer, death_origin );
    // Guaranteed Mega Bottle drop to all players.
    acc_mega_bottles::on_boss_death( "full", killer, death_origin );

    release_lab_exits();
}

function spawn_subroutine_core( round_number )
{
    // TODO(acc-model): boss model/FX pass is Phase 4/5 - until then the Core
    // is a promoted stock zombie pinned at the struct (real, damageable,
    // full stock damage pipeline; scripted ranged attacks still TODO).
    spawn_struct = struct::get( "acc_boss_spawn", "targetname" );
    if ( !isdefined( spawn_struct ) )
    {
        acc_utility::log( "boss: no acc_boss_spawn struct placed, cannot spawn Subroutine Core" );
        return undefined;
    }

    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss: no zombie_spawners, cannot spawn Subroutine Core" );
        return undefined;
    }
    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];

    // Chosen-struct spawn, pattern A: pass the struct as spawn_zombie's 3rd
    // arg so the relocation runs off OUR struct instead of a random
    // zombie_location.
    // VERIFIED(acc): spawn_zombie threads level.move_spawn_func on the passed
    // spawn_point immediately (zombie_utility.gsc:1518-1521). Safe here: the
    // "move_spawn_func undefined before round 1" trap doesn't apply because it
    // is defaulted to zm_utility::move_zombie_spawn_location inside stock
    // round_start (_zm.gsc:4118-4121), which ran at game start (round_think
    // threaded right after, _zm.gsc:4141) - by round 30 it is always defined.
    // VERIFIED(acc): the struct carries no script_noteworthy, so it is
    // defaulted to "spawn_location" (_zm_utility.gsc:216-219) and takes the
    // teleport-in path: Ghost -> anchor moveto struct.origin -> Show ->
    // notify "risen" (_zm_utility.gsc:255-299). The automatic random-location
    // pass (do_zombie_spawn -> move_spawn_func) early-outs because .spawn_pos
    // is already set (_zm_utility.gsc:192-196); its immediate duplicate
    // "risen" notify fires inside `thread do_zombie_spawn()` BEFORE
    // zombie_think arms its waittill (_zm_spawner.gsc:579-581) and is
    // harmlessly lost - the anchor-move path's notify (frames later, after the
    // 0.05s moveto) is the one that releases zombie_think. Pattern B
    // (._rise_spot) was rejected: it forces do_zombie_rise's ground-climbout
    // animation (_zm_spawner.gsc:2874-2879) - wrong read for a stationary
    // machine boss.
    core = zombie_utility::spawn_zombie( spawner, undefined, spawn_struct );
    if ( !isdefined( core ) )
    {
        acc_utility::log( "boss: spawn_zombie returned undefined (spawner missing script_forcespawn?)" );
        return undefined;
    }

    // VERIFIED(acc): zombie_spawn_init runs at frame end and clobbers
    // health/maxhealth (_zm_spawner.gsc:293-311) - poll the init flag before
    // promoting (the _zm_ai_faller.gsc:168 pattern, same as
    // spawn_juggernaut_host above and _acc_elites.gsc:129).
    while ( isdefined( core ) && !isdefined( core.zombie_init_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( core ) || !isalive( core ) )
    {
        acc_utility::log( "boss: Subroutine Core died/vanished during init" );
        return undefined;
    }

    core.acc_is_boss = true; // boss headshot multiplier in _acc_damage
    core.phase = 1;

    // HP: docs/11 - 50k base at round 30, +15k per round past 30.
    core.maxhealth = int( scale_boss_hp( round_number ) * acc_coop_scaling::special_hp_mult() );
    core.health = core.maxhealth;

    // Boss durability set, mirrored from stock mechz spawn setup
    // (mechz.gsc:946-957).
    core DisableAimAssist();
    core.disableAmmoDrop = true;
    core.no_gib = true;
    core.ignore_nuke = true;

    // ignore_enemy_count = true: the Core must NOT gate round end.
    // VERIFIED(acc): get_current_zombie_count/get_round_enemy_array skip any
    // actor with .ignore_enemy_count (zombie_utility.gsc:2023-2038, skip at
    // :2031); that count feeds BOTH the round-end poll (_zm.gsc:4733) and
    // round_spawning's 24-AI budget gate (_zm.gsc:3735). Per docs/11, full
    // boss rounds 30+ run the normal wave alongside the fight ("constant
    // chaff spawn") and the fight may span multiple rounds, so the Core must
    // neither hold rounds open nor starve the wave of AI slots. This is the
    // deliberate OPPOSITE of the mini-boss, which replaces the wave and IS
    // the round-end gate.
    core.ignore_enemy_count = true;

    // ignore_round_spawn_failsafe = true: the Core is stationary BY DESIGN.
    // VERIFIED(acc): round_spawn_failsafe kills any zombie that moves <24in
    // per 30s window (DistanceSquared < 576 check zombie_utility.gsc:1870;
    // level.failsafe_waittime default 30, :1830-1835; kill via dodamage
    // :1893) - a deliberately pinned actor is exactly what it hunts, so the
    // Core opts out via the check at zombie_utility.gsc:1825-1828. This is
    // only safe BECAUSE ignore_enemy_count is also set above: a boss that can
    // never be failsafe-culled must never be a round-end gate, or a bugged
    // fight could soft-lock the game.
    core.ignore_round_spawn_failsafe = true;

    // Pin it at the struct once stock think finishes (threaded - the "risen"
    // relocation takes a few frames and we must not pin before it completes).
    core thread pin_core_in_place();

    acc_utility::log( "spawned Subroutine Core (" + core.maxhealth + " hp) at acc_boss_spawn" );
    return core;
}

// self = the Core actor. Stationary-boss pin (docs/11: forced-camp encounter).
function pin_core_in_place()
{
    self endon( "death" );

    // VERIFIED(acc): until "risen" completes the actor is already frozen by
    // zombie_spawn_init's PathMode("dont move") (_zm_spawner.gsc:319), and
    // zombie_think then re-enables movement - SetGoal(self.origin) +
    // PathMode("move allowed") + self.zombie_think_done = true
    // (_zm_spawner.gsc:588-590). Pinning earlier would be overridden, so poll
    // the flag (it is set once and never cleared; the same flag gates the
    // stock behavior tree, _zm_behavior.gsc:1146).
    while ( isdefined( self ) && !IS_TRUE( self.zombie_think_done ) )
    {
        util::wait_network_frame();
    }
    if ( !isdefined( self ) || !isalive( self ) ) return;

    // VERIFIED(acc): both are actor builtins stock calls on zombie-archetype
    // actors - SetGoal (_zm_spawner.gsc:588), PathMode("dont move")
    // (_zm_spawner.gsc:319, shared/ai/zombie.gsc:1144, and
    // archetype_apothicon_fury.gsc:582 with the comment "prevent
    // pathfinding"). Goal-at-own-origin + no pathing = pinned; melee-range
    // behavior still comes from the zombie behavior tree.
    self SetGoal( self.origin );
    self PathMode( "dont move" );
}

// self = the Core actor. Single emitter of "acc_boss_dead" (exactly once -
// one waittill("death") per boss; run_boss_phases no longer notifies).
function watch_full_boss_death()
{
    self waittill( "death", attacker );

    killer = undefined;
    if ( isdefined( self.acc_killer ) )
    {
        // _acc_damage stamps the final-blow player here when its pipeline
        // processed the killing hit (Phase 4 wiring) - prefer it because the
        // raw "death" attacker can be a non-player inflictor (grenade, trap).
        killer = self.acc_killer;
    }
    else if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        killer = attacker;
    }

    // Capture origin NOW - the corpse entity can be removed by stock corpse
    // cleanup soon after death; the payload keeps the reward path safe.
    level notify( "acc_boss_dead", killer, self.origin );
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
    level endon( "end_game" );
    level endon( "acc_boss_dead" );

    // Phases at 66% and 33% HP trigger "system outage" debuffs.
    max_phases = ( round_number >= 40 ? 4 : 3 );

    // Poll health for phase transitions while the boss is ALIVE only; death
    // is owned by watch_full_boss_death (a real actor fires "death" - this
    // loop must not double-emit "acc_boss_dead").
    while ( isdefined( boss ) && isalive( boss ) && boss.health > 0 )
    {
        wait( 0.5 );
        if ( !isdefined( boss ) || !isalive( boss ) ) break;

        current_phase = compute_phase( boss, max_phases );
        if ( current_phase > boss.phase )
        {
            boss.phase = current_phase;
            level thread on_phase_transition( boss, current_phase );
        }
    }
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
