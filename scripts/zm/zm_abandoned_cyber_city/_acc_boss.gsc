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
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_brutus;

#insert scripts\shared\shared.gsh;

#define ACC_BOSS_MINI_FIRST_ROUND 10
#define ACC_BOSS_FULL_FIRST_ROUND 30
#define ACC_BOSS_INTERVAL 10

// Brutus mini-boss buffs + cadence (user request).
#define ACC_BOSS_MINI_HP 500000      // 10x the old 50k baseline
#define ACC_BOSS_SPEED_SCALE 1.25    // moves +25% over the round's top speed tier
#define ACC_BRUTUS_SCALE 1.5         // 50% bigger model
#define ACC_BRUTUS_FIRST_ROUND 4     // first Brutus round (user 2026-06-15, "for now")
#define ACC_BRUTUS_INTERVAL 5        // then every 5 rounds (r4, 9, 14, 19, 24, ...)

#namespace acc_boss;

function init()
{
    acc_utility::log( "boss init" );

    level thread round_hook_loop();

    // Dev/test loop: `acc_test_boss 1` in the console (works mid-match - sampled
    // every round) spawns a low-HP test Brutus every round from round 2, so the
    // Mega Bottle drop -> perk upgrade loop is testable without surviving to round 5.
    level thread test_boss_loop();
}

function test_boss_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        // Dev only: `acc_test_boss 1` spawns a low-HP test Brutus from round 2 so the
        // Mega-Bottle -> perk-upgrade loop is testable without surviving to round 5.
        if ( getdvarint( "acc_test_boss", 0 ) != 1 ) continue;
        if ( round_number < 2 ) continue;

        wait 10; // let the round get going
        acc_utility::log( "TEST BOSS (Brutus) spawning" );
        players = GetPlayers();
        for ( pi = 0; pi < players.size; pi++ )
        {
            if ( isdefined( players[ pi ] ) )
                players[ pi ] IPrintLnBold( "^1BRUTUS INBOUND ^7- kill it for ^310 Mega Bottles" );
        }
        // Low HP override + bulk Mega Bottle drop (10) so the perk loop is testable fast.
        spawn_brutus_miniboss( 1500, 10 );
    }
}

function round_hook_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );

        // Full boss "Subroutine Core": r30, 40, 50+ (every 10 from r30). Takes
        // precedence so a full-boss round doesn't ALSO spawn Brutus.
        if ( round_number >= ACC_BOSS_FULL_FIRST_ROUND && round_number % ACC_BOSS_INTERVAL == 0 )
        {
            level thread run_full_boss( round_number );
            continue;
        }

        // Brutus mini-boss: first at ACC_BRUTUS_FIRST_ROUND, then every ACC_BRUTUS_INTERVAL
        // (r4, 9, 14, 19, ...). `(round - first) % interval` so `first` need not be a multiple
        // of `interval` (user set first = 4, 2026-06-15).
        if ( round_number >= ACC_BRUTUS_FIRST_ROUND
             && ( ( round_number - ACC_BRUTUS_FIRST_ROUND ) % ACC_BRUTUS_INTERVAL ) == 0 )
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

    // Brutus charges ALONGSIDE the normal wave (user choice): do NOT suppress the wave,
    // and he keeps his native ignore_enemy_count (he does NOT gate round end - the wave
    // does). r10 = 1 Brutus, r20 = 2, staggered a beat apart for co-op spawn safety.
    count = ( round_number >= 20 ? 2 : 1 );
    acc_utility::log( "mini boss (Brutus) round " + round_number + " spawning " + count );

    for ( i = 0; i < count; i++ )
    {
        spawn_brutus_miniboss();
        wait 1.5;
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

function spawn_brutus_miniboss( n_health_override, n_bottle_count )
{
    // Brutus (NSZ pack) IS our mini-boss. acc_boss_brutus::spawn_one() spawns one via
    // the pack (which builds his model / anims / charge / melee / helmet / death) and
    // returns the live actor; we then layer OUR systems on top.
    host = acc_boss_brutus::spawn_one();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "boss: Brutus spawn returned none" );
        return;
    }

    host.acc_is_mini_boss = true; // boss headshot multiplier in _acc_damage

    // Test boss passes a bulk bottle count; real mini-boss leaves it undefined
    // (-> 1 per player, the normal rule). Read in watch_mini_boss_death.
    if ( isdefined( n_bottle_count ) )
        host.acc_bottle_drop = n_bottle_count;

    // HP: docs/11_enemies.md mini-boss ~50k solo baseline; the test loop
    // passes a small override so the drop loop is testable at round 2.
    if ( isdefined( n_health_override ) )
    {
        host.maxhealth = n_health_override;
    }
    else
    {
        // 10x baseline (500k). docs/15: elites/bosses scale +50% per extra player.
        host.maxhealth = int( ACC_BOSS_MINI_HP * acc_coop_scaling::special_hp_mult() );
    }
    host.health = host.maxhealth;

    // Brutus sets his own durability in the pack (no_gib, ignore_nuke, ignore_enemy_count,
    // AAT / instakill / tesla / thundergun immunity). He KEEPS ignore_enemy_count, so he
    // charges ALONGSIDE the normal wave and does NOT gate round end (user choice).
    host DisableAimAssist();
    host.disableAmmoDrop = true;

    // Drives the boss health bar (_acc_health_bars listens).
    level notify( "acc_boss_spawned", host, "BRUTUS" );
    host thread watch_mini_boss_death();

    // Boss music (user request): loop the Juhani Junkala "Epic Boss Battle" track
    // while Brutus lives, slow-fade on death. Multi-Brutus safe (r20 spawns 2) - a
    // refcount starts the loop on the first spawn and fades only when the last dies.
    level thread brutus_boss_music( host );

    // Diagnostic for the "Brutus spawns then stands frozen" report (2026-06-15). OFF by
    // default; `acc_brutus_debug 1` prints, every second for ~25s, whether he acquired a
    // target, his distance to the nearest player, and whether he is actually translating.
    // That separates the candidate causes (see brutus_spawn_diag) without a rebuild.
    if ( getdvarint( "acc_brutus_debug", 0 ) != 0 )
        host thread brutus_spawn_diag();

    // Frozen-statue fallback (acc_brutus_force_resume 1, default OFF). If Brutus spawns and
    // never charges because locomotion didn't resume after his spawn anim, re-assert the
    // stock zombie-think resume sequence on the live actor a beat after spawn. Confirm the
    // cause with acc_brutus_debug FIRST: if the diag shows he has a goal but can't PATH
    // (navmesh stale after the room-shrink), this won't help - regen the navmesh per CLAUDE.md.
    if ( getdvarint( "acc_brutus_force_resume", 0 ) != 0 )
        host thread brutus_force_resume();

    // Movement fix: keep him charging STRAIGHT (forward run) instead of strafing/slowing
    // when the player circles him. Independent of the size/speed buffs (stock zombie fields
    // only, no SetScale/ASM) so it stays active even with acc_brutus_scale 0. See
    // brutus_movement_fix.
    host thread brutus_movement_fix();

    // === BRUTUS BUFFS (2026-06-14) ===========================================
    // CONFIRMED LIVE: SetScale(+50%) on the live Brutus AI HARD-CRASHES the game
    // ~1-2s after spawn (0xC0000005), with speed off and the movement fix (stock
    // fields) proven innocent. So BOTH buffs now default OFF (acc_brutus_scale /
    // acc_brutus_speed, gates below) -> a normal launch is STABLE. apply_brutus_buffs
    // stays threaded only as the live experiment harness. The straight-charge
    // movement fix (brutus_movement_fix, above) is separate and stays ON.
    // A crash-safe +50% size needs a different route (e.g. a pre-scaled model), TBD.
    host thread apply_brutus_buffs();
    // =========================================================================

    acc_utility::log( "spawned Brutus mini-boss (" + host.maxhealth + " hp)" );
}

// ---------------------------------------------------------------------------
// Brutus boss music - loop the Juhani Junkala "Epic Boss Battle" (CC0, seamless)
// track while any Brutus is alive, then slow-fade (4s) when the LAST one dies. A
// level refcount makes it multi-Brutus safe (r20 spawns 2). Gated by
// acc_boss_music_on (default 1). Alias acc_brutus_music = BUS_FX + LOOPING
// (acc_audio.csv); PlayLoopSound/StopLoopSound(fade) on a reused level emitter.
// ---------------------------------------------------------------------------
function brutus_boss_music( host )
{
    level endon( "end_game" );

    if ( getdvarint( "acc_boss_music_on", 1 ) != 1 )
        return;

    if ( !isdefined( level.acc_brutus_music_count ) )
        level.acc_brutus_music_count = 0;

    level.acc_brutus_music_count++;

    // First Brutus of the encounter -> start the looping track (reuse one emitter).
    if ( level.acc_brutus_music_count == 1 )
    {
        if ( !isdefined( level.acc_brutus_music_ent ) )
            level.acc_brutus_music_ent = spawn( "script_origin", (0,0,0) );
        level.acc_brutus_music_ent PlayLoopSound( "acc_brutus_music" );
        acc_utility::log( "boss music ON (Brutus)" );
    }

    // Keep looping while THIS Brutus lives (poll covers death AND despawn/delete).
    while ( isdefined( host ) && isalive( host ) )
        wait( 0.5 );

    // This Brutus is down - fade only when the LAST one dies.
    level.acc_brutus_music_count--;
    if ( level.acc_brutus_music_count <= 0 )
    {
        level.acc_brutus_music_count = 0;
        if ( isdefined( level.acc_brutus_music_ent ) )
            level.acc_brutus_music_ent StopLoopSound( 4.0 );   // slow 4s fade-out
        acc_utility::log( "boss music FADE (Brutus dead)" );
    }
}

// self = the live Brutus. The +50% size and +25% speed buffs are deliberately deferred
// out of the spawn sequence. The NSZ pack hands us the actor (acc_brutus_spawned) and
// then, still in that frame, ForceTeleports it and starts its AnimScripted(%brutus_spawn)
// spawn animation; custom_find_flesh (which makes him charge) is threaded only AFTER that
// anim. Mutating the actor's SCALE or ASM ANIM-RATE across that spawn -> move transition
// is what crashed the spawn ~1-2s in (visible spawn, then CTD). We wait until he is fully
// in and charging, THEN apply the buffs. Each is dvar-gated (default ON) so a remaining
// crash can be bisected LIVE, no rebuild:
//   acc_brutus_scale 0  -> skip the +50% size (SetScale on the live AI)
//   acc_brutus_speed 0  -> skip the +25% speed think (ASM anim-rate)
// If it still crashes with BOTH at 0, the cause is the base pack spawn, not our buffs.
function apply_brutus_buffs()
{
    self endon( "death" );

    // Brutus is "active" once custom_find_flesh has acquired a target (.brutus_enemy);
    // that runs only after %brutus_spawn finishes, so this lands us safely past the
    // fragile spawn -> move transition. Cap the wait so a no-target lull still buffs him.
    t = 0;
    while ( isalive( self ) && !isdefined( self.brutus_enemy ) && t < 8 )
    {
        wait 0.25;
        t += 0.25;
    }
    if ( !isalive( self ) ) return;
    wait 0.5; // small settle margin after he is moving

    // +50% model. CONFIRMED CRASHER (2026-06-14): SetScale on the live Brutus AI ->
    // 0xC0000005 ~1-2s after spawn (isolated live: speed off + movement fix off-path).
    // Default OFF; `acc_brutus_scale 1` is for experiments only. A crash-safe size
    // needs a different route (pre-scaled model / scale before the helmet+light link).
    if ( getdvarint( "acc_brutus_scale", 0 ) != 0 )
        self SetScale( ACC_BRUTUS_SCALE );

    // +25% over the round's sprint tier (re-asserted on a cadence). boss_speed_think
    // locks the run cycle to "sprint" and scales his anim-driven movement +25% on top,
    // so he outruns even a max-speed wave.
    // NOTE: default OFF for now (size-buff isolation test, 2026-06-14) - flip with
    // `acc_brutus_speed 1` once SetScale is cleared / the movement fix lands.
    if ( getdvarint( "acc_brutus_speed", 0 ) != 0 )
        self thread boss_speed_think();
}

// self = the live Brutus. MOVEMENT FIX (2026-06-14): a circling player otherwise puts him
// into the slow strafe/sidestep anim - the engine's QuadrantAnimWeights (zombie_utility.gsc
// :601-607) picks a strafe whenever his FACING != his TRAVEL direction, and strafe/back
// root-motion covers ~75% less ground than the forward sprint (that IS the slowdown). The
// pack re-aims him at the player's exact origin every 0.05s with 360deg view + a 32u goal
// radius, so an orbiting player keeps his torso fixed while the goal slides sideways -> big
// yaw -> strafe. He also trips the stock stuck->cant_move check (zombie.gsc:1449-1466) while
// micro-strafing in the at-goal band -> the intermittent freeze.
//   Fix = stock zombie FIELDS only (no SetScale / no ASM anim-rate, so it cannot reintroduce
//   the spawn CTD and is independent of the size/speed buffs):
//     - alwaysRunForward -> QuadrantAnimWeights short-circuits to a pure forward run; he
//       always plays the sprint cycle and the body rotates to follow the player.
//     - goalradius/n_zombie_custom_goal_radius 64 (stays under the pack's 75u melee gate,
//       nsz_brutus.gsc:599) -> he commits to a straight approach instead of orbiting the 32u
//       band, which also stops the stuck-freeze.
//   Live kill switch: acc_brutus_runfwd 0 (read once at spawn) reverts to stock strafe.
function brutus_movement_fix()
{
    self endon( "death" );

    if ( getdvarint( "acc_brutus_runfwd", 1 ) == 0 ) return;

    // Wait until he is charging (past the fragile spawn -> move transition), the same window
    // the buffs use. Cap so a no-target lull still applies the fix.
    t = 0;
    while ( isalive( self ) && !isdefined( self.brutus_enemy ) && t < 8 )
    {
        wait 0.25;
        t += 0.25;
    }
    if ( !isalive( self ) ) return;

    // Commit to a straight charge. n_zombie_custom_goal_radius is honored by the behavior-tree
    // goal path across the pack's 20Hz goal resets; pathenemylookahead leads the path a little
    // so it doesn't snap to the raw perpendicular goal each frame (pack sets 0).
    self.goalradius = 64;
    self.n_zombie_custom_goal_radius = 64;
    self.pathenemylookahead = 64;

    for ( ;; )
    {
        // Defined (never false, per the assert at zombie_utility.gsc:603) -> pure forward run.
        self.alwaysRunForward = true;
        wait 1; // re-assert: his AnimScripted swing/spawn anims can clear locomotion fields.
    }
}

// self = the Juggernaut Host. Keep it 25% faster than the CURRENT round speed: pin the
// run cycle to "sprint" (the round's top base tier) and scale its movement +25% on top via
// ASMSetAnimationRate (zombie movement is root-motion / anim-driven - the same lever the
// zombie speed curve in _acc_zombie_speed.gsc and Widow's Wine use).
// Re-asserted on a 2s cadence: round transitions / state changes (and Widow's Wine) can
// reset a one-shot anim rate - so the Host stays above the round speed.
// NOTE: mini-bosses spawn only at rounds 10/20, where the wave tops out at sprint x1.15
// (round 20, per the zombie speed curve), so +25% (x1.25) still outruns the wave.
function boss_speed_think()
{
    self endon( "death" );

    for ( ;; )
    {
        // Lock to the sprint tier if it ever drifts below (it normally won't - the Host
        // owns its own run-cycle override, set on spawn).
        if ( self.zombie_move_speed != "sprint" )
            self zombie_utility::set_zombie_run_cycle( "sprint" );

        // +25% over whatever the sprint tier's base move speed is this round.
        self ASMSetAnimationRate( ACC_BOSS_SPEED_SCALE );
        wait 2;
    }
}

// self = the live Brutus. Diagnostic ONLY (acc_brutus_debug 1) for the "spawns then stands
// frozen" report (2026-06-15). Prints to all players once a second for ~25s: target
// acquired?, has a custom goal?, distance to the nearest player, and how far he moved in the
// last second. Read the output to pin the cause without a rebuild:
//   - target=N the whole time           -> custom_find_flesh never acquires (no valid target)
//   - target=Y goal=Y but moved ~0      -> he has a goal but can't path: navmesh/spawn-spot
//        is off the mesh (likely stale navmesh after the room-shrink) - regen navmesh
//        (cod2map64, see CLAUDE.md) and/or move the brutus_spawner_spot struct onto the mesh
//   - target=Y goal=Y and moved > 0     -> he IS translating (freeze is elsewhere/intermittent)
//   - target=N AND no anim at all       -> stuck in the AnimScripted(%brutus_spawn) state /
//        Brutus anims didn't load (verify the NSZ external pack: check_external_assets.ps1)
function brutus_spawn_diag()
{
    self endon( "death" );

    last = self.origin;
    for ( i = 0; i < 25; i++ )
    {
        wait 1;
        if ( !isalive( self ) ) return;

        players = GetPlayers();
        best = 999999999;
        for ( p = 0; p < players.size; p++ )
        {
            if ( !isdefined( players[ p ] ) ) continue;
            d = Distance( self.origin, players[ p ].origin );
            if ( d < best ) best = d;
        }

        moved = Distance( self.origin, last );
        last = self.origin;

        has_enemy = ( isdefined( self.brutus_enemy ) ? "Y" : "N" );
        has_goal  = ( isdefined( self.v_zombie_custom_goal_pos ) ? "Y" : "N" );

        msg = "^3[brutus diag] target=" + has_enemy + " goal=" + has_goal
            + " distPlayer=" + int( best ) + " movedLastSec=" + int( moved );
        for ( p = 0; p < players.size; p++ )
            if ( isdefined( players[ p ] ) ) players[ p ] IPrintLn( msg );
    }
}

// self = the live Brutus. Frozen-statue fallback (gated by acc_brutus_force_resume, OFF by
// default). Re-asserts the stock zombie-think resume sequence a beat after spawn so that, if
// locomotion never resumed after AnimScripted(%brutus_spawn), he is unstuck: SetGoal +
// PathMode("move allowed") - the exact calls boss_think makes (_zm_spawner.gsc:588-589). The
// pack's custom_find_flesh still drives the real chase goal (v_zombie_custom_goal_pos); this
// only unlocks pathing. Idempotent + safe on an already-charging Brutus. Does NOT help if the
// goal is simply unreachable (off-mesh / stale navmesh) - that needs a navmesh regen.
function brutus_force_resume()
{
    self endon( "death" );
    wait 1.5; // past the spawn anim + the buff/movement-fix settle window
    if ( !isalive( self ) ) return;
    self PathMode( "move allowed" );
    self SetGoal( self.origin );
}

function watch_mini_boss_death()
{
    self waittill( "death", attacker );

    // Capture origin now - the corpse can be cleaned up moments after death.
    drop_origin = self.origin;
    n_bottles = ( isdefined( self.acc_bottle_drop ) ? self.acc_bottle_drop : 1 );

    // Regular boss-item drop (50% chance at mini tier).
    acc_boss_items::on_boss_death( "mini", attacker, drop_origin );

    if ( n_bottles <= 1 )
    {
        // Guaranteed Mega Bottle drop to all players (1 each, the normal rule).
        acc_mega_bottles::on_boss_death( "mini", attacker, drop_origin );
    }
    else
    {
        // Test boss: bulk drop so every perk can be Mega'd in one go.
        for ( i = 0; i < level.players.size; i++ )
        {
            p = level.players[ i ];
            if ( isdefined( p ) && isplayer( p ) )
                p acc_mega_bottles::grant_bottle( n_bottles, "test_boss" );
        }
    }
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

    // Boss health bar + nameplate (_acc_health_bars listens).
    level notify( "acc_boss_spawned", core, "SUBROUTINE CORE" );

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
    // Ultimate Tank holders are immune: power-off routes through perk_power_off
    // -> perk_pause -> UnsetPerk on every owner (_zm_power.gsc:699/:718,
    // _zm_perks.gsc:1249). Re-grant the immune players' perks across the next
    // few network frames (powered items unset one network-frame apart,
    // _zm_power.gsc:485). NOTE: power_on is a single global flag, so an immune
    // player's electric traps still go dark - only OWNED perks are preserved.
    level thread protect_immune_players_during_debuff();
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
    // Ultimate Tank holders are immune (same UnsetPerk path, _zm_perks.gsc:1249).
    level thread protect_immune_players_during_debuff();
    wait( duration );
    level thread zm_perks::perk_unpause_all_perks();
    acc_utility::log( "perks restored" );
}

// Ultimate Tank (Jug Mega) boss-ability immunity (docs/13_perks.md). Re-assert
// immune players' perks for ~2s so the debuff's UnsetPerk cascade (one powered
// item per network frame) can't stick on them. Clearing disabled_perks[perk]
// makes the trailing global unpause/repower a no-op for these players.
function protect_immune_players_during_debuff()
{
    level endon( "end_game" );

    for ( n = 0; n < 20; n++ )
    {
        for ( i = 0; i < level.players.size; i++ )
        {
            p = level.players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            // Ultimate-Tank EMP immunity is a LIVE Jug effect: require the player to
            // currently HOLD Juggernog, not just the persistent Mega flag (it survives a
            // down by design), so a player who lost Jug doesn't keep unearned immunity.
            if ( acc_mega_bottles::has_active_mega_perk( p, "specialty_armorvest" ) )
                p restore_immune_player_perks();
        }
        util::wait_network_frame();
    }
}

// self = an Ultimate-Tank player. Re-Set every registered perk this player
// owned-but-was-paused, mirroring stock perk_unpause's re-grant block
// (_zm_perks.gsc:1278-1290), and clear disabled_perks so the global unpause skips them.
function restore_immune_player_perks()
{
    if ( !isdefined( self.disabled_perks ) ) return;
    if ( !isdefined( level._custom_perks ) ) return;

    a_keys = GetArrayKeys( level._custom_perks );
    for ( i = 0; i < a_keys.size; i++ )
    {
        perk = a_keys[ i ];
        if ( !IS_TRUE( self.disabled_perks[ perk ] ) ) continue;

        self.disabled_perks[ perk ] = false;            // unpause/repower now skips us
        self SetPerk( perk );                           // builtin: re-grant the perk
        self zm_perks::set_perk_clientfield( perk, 1 ); // PERK_STATE_OWNED = 1

        // Jug HP must be re-applied (UnsetPerk dropped the jugg add).
        self zm_perks::perk_set_max_health_if_jugg( perk, false, false );

        // Re-run the perk's custom give-thread if it has one (mirrors stock).
        if ( isdefined( level._custom_perks[ perk ].player_thread_give ) )
            self thread [[ level._custom_perks[ perk ].player_thread_give ]]();
    }
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
