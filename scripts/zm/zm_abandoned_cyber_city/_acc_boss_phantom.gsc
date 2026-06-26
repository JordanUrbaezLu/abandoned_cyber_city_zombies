// =============================================================================
// _acc_boss_phantom.gsc - "Phantom" mini-boss (script-only, zero new assets)
//
// Design (user 2026-06-18): an actual recurring boss for the ~round-10 slot, distinct
// from Brutus (trench guard) and the Glitch Stalker. The user wanted a custom MODEL but
// a genuinely non-zombie mesh needs Maya/APE rigging (not headless) - so this is the
// "Cyber Phantom" combo from the model research: a PROMOTED STOCK ZOMBIE whose identity
// is built from headless cosmetic levers, NOT a mesh import. Look = HOLOGRAPHIC:
//   - CLOAKER gimmick: invisible (Ghost) while stalking at range, MATERIALIZES (Show)
//     when it closes on a player to strike, with an occasional flicker = a destabilizing
//     hologram. (The cloak IS the threat - you only see it when it's on you.)
//   - cyan eyes (the existing actor eye-tint clientfield - shared with the Glitch Stalker).
//   - distinct stock Giant BODY as the canvas (vs the charred horde). The body barely
//     shows (cloaked most of the time); the identity is the phasing + cyan eyes + name.
// A full-body cyan GLOW aura (the strongest "holographic" signal) is a Phase-2 .csc FX
// add-on (an actor-scope clientfield + PlayFXOnTag, the _acc_perk_lights pattern) - NOT in
// this file yet, to keep v1 zero-new-clientfield.
//
// AGGRESSION = STALK + OCCASIONAL TELEPORT (user 2026-06-24): the Phantom mostly stalks (cloaked walk + melee)
// and periodically BLINKS to reposition + land a single hit-and-run - it teleports rather than wanders, but is
// ~30% LESS aggressive than a Glitch Stalker (slower blink cadence + ~30% lower melee). Its flashy
// player->player CHAIN (warp from one player to the next, a hit on each) is a RANDOM SPECIAL move fired
// occasionally - NOT the constant mode. Jumpscary (cloaked arrival + screech), deliberately not a murderer.
// See phantom_teleport_loop.
//
// Built on the PROVEN script-only boss template (_acc_boss_glitch.gsc) so it inherits every
// crash/freeze dodge: NO SetScale (0xC0000005), init-gated promotion (stock clobbers HP at
// frame end), acc_boss_custom_speed (the _acc_zombie_speed keep-alive skips it - no ASM
// stomp/freeze), ignore_enemy_count (fights ALONGSIDE the wave, never gates round end /
// starves the 24-AI budget). Owns its own cadence off "acc_round_start" so _acc_boss.gsc is
// NOT edited. Disable live: `acc_phantom_enable 0`. Trace: `acc_phantom_debug 1`.
//
// CADENCE (user 2026-06-18: a boss every ~10 rounds, random pick): a ROUND-BOSS ROTATION
// slot fires every acc_phantom_interval rounds from acc_phantom_first_round and randomly
// picks from a pool (one entry now = Phantom; add future script-only bosses to the pool).
// Yields to the Subroutine Core on its sealed rounds. DECOUPLED FROM THE PURGE (user 2026-06-25):
// the Phantom NO LONGER bails while a lockdown purge is active - that coupling (a stuck purge
// holding level.acc_ldc_active) was the recurring "Phantom never spawned" cause. It now spawns on
// cadence regardless; the shared actor pool is safe because stock spawn_zombie BLOCKS until a free
// slot exists (it does not fail on saturation), and the owed-flag director keeps the slot owed until
// a Phantom actually exists.
//
// HOLOGRAPHIC GLOW AURA (v2, user 2026-06-18; RED 2026-06-24): a red energy glow wraps the boss while it
// is MATERIALIZED (off while cloaked, so it never reveals the invisible Phantom). Server sets the
// "accPhantomAura" actor clientfield (here); _acc_boss_phantom.csc PlayFX's the glow (server
// PlayFX does not render in this build). FX = the already-packed acc/light/fx_perk_glow_red.
//
// LED-SAFE: pure .gsc + .csc + existing .fx - `-GscOnly`, no .map/material/sky change.
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;   // grant_player (2 shards/player on Phantom kill)
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;   // boss_hp_player_mult (log coop HP)
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;         // acc_phantom_chain_zap (apply the chain slow Phantom-side, god-mode-safe)

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// --- Tunable defaults (every one a live acc_phantom_* dvar; mirror docs/34). ---
// ENABLED (user 2026-06-22): Phantom is a live boss in BOTH normal play and dev, first appearing at
// round 8 (then every 8 rounds - ACC_PHANTOM_INTERVAL 8 - with a one-at-a-time guard). Disable live with
// `acc_phantom_enable 0`. (RED holographic glow + cyan eyes; shares the phase theme with the Glitch
// Stalker - re-theme later if they read too similar.)
#define ACC_PHANTOM_ENABLE_DEF        1     // master on/off (1 = on in normal play; dev also runs it)
#define ACC_PHANTOM_HP                80000  // solo HP (user 2026-06-24: -20% from 100k). x boss_hp_player_mult (LOGARITHMIC): solo 80k / 2p 120k / 3p 143k / 4p 160k
#define ACC_PHANTOM_FIRST_ROUND_DEF   8     // BASE-GAME first round (round 8), then every ACC_PHANTOM_INTERVAL rounds (user 2026-06-25). DEV mode = 4 (cadence_hits branches on level.acc_dev).
#define ACC_PHANTOM_INTERVAL_DEF      8     // BASE-GAME EVERY 8 rounds (8, 16, 24, ...). DEV mode = EVERY 4 (4, 8, 12, ...) for testing - user 2026-06-25. One-at-a-time guard (run_round_boss) still prevents stacking.
#define ACC_PHANTOM_TEST_ROUND_DEF    8     // dev/test first round
// AGGRESSION MODEL (user 2026-06-24): jumpscary TELEPORTING HARASSER, not a camper and not a murderer. The
// cloaked arrival + screech is the SCARE; the LOW melee keeps it survivable. He still EARNS his guaranteed Mega
// Bottle through pressure + mobility, not raw damage. Speed stays the modest +10% gait (the TELEPORTING is what
// reads as "fast"); bumping the anim rate risks the documented non-linear catch+instakill overshoot.
#define ACC_PHANTOM_REVEAL_DIST_DEF   240   // stay invisible until THIS close, then materialize (was 400 - now he's on you)
#define ACC_PHANTOM_SPEED_MULT_DEF    1.1   // sprint-gait playback rate. User 2026-06-24: +10% from the 1.0 interim baseline (natural zombie sprint ~181 u/s, KITEABLE vs a player's ~299 sprint). CAVEAT: anim-rate->ground-speed is NON-LINEAR (1.685 once overshot badly = caught+instakilled), so 1.1 is +10% PLAYBACK, not exactly +10% u/s - verify real speed with the [SPD] probe and tune LIVE via acc_phantom_speed_mult.
#define ACC_PHANTOM_MELEE_DMG_DEF     19    // melee dealt to players: ~30% UNDER a Glitch Stalker's 27/hit (glitch = stock 60 x acc_glitch_melee_dmg_mult 0.45). User 2026-06-24 "not super lethal, 30% less than a glitch" (was 85). Stock zombie=60, our horde=45.
#define ACC_PHANTOM_FLICKER_PCT_DEF   12    // % of 0.1s ticks that blip invisible while materialized (hologram flicker)

// TELEPORT mobility (user 2026-06-24). The Phantom blinks to REPOSITION (it stalks via teleport, doesn't just
// wander) on a cadence ~30% SLOWER than the Glitch Stalker's blink (1.33-2.22s) = "30% less aggro". Each normal
// action is a single HIT-AND-RUN (blink in, one swing, blink away - never camps). The player->player CHAIN is a
// RANDOM SPECIAL move (acc_phantom_chain_chance; fires with 1+ players, hits EACH player once), NOT its constant
// mode. In solo that is a single strike on the lone player (not a re-chain). Every value a live dvar.
#define ACC_PHANTOM_TELEPORT_DEF        1    // master on/off for teleport mobility
#define ACC_PHANTOM_TP_DELAY_DEF        2.0  // grace seconds after spawn before the first teleport
#define ACC_PHANTOM_TP_CD_MIN_DEF       1.89 // min seconds of plain stalking between teleport actions. User 2026-06-24: -10% (was 2.1) = +10% AGGRO - it acts 10% more often (cadence IS how this boss's aggression is measured). Glitch blink min 1.33.
#define ACC_PHANTOM_TP_CD_MAX_DEF       2.7  // max seconds between teleport actions. User 2026-06-24: -10% (was 3.0) = +10% aggro. Glitch blink max 2.22.
#define ACC_PHANTOM_STRIKE_DIST_DEF     56   // a blink lands THIS far short of the player (melee range), the glitch-pounce idiom
#define ACC_PHANTOM_STRIKE_MIN_DEF      1.0  // min seconds it dwells in melee after a normal blink (one swing) before backing off
#define ACC_PHANTOM_STRIKE_MAX_DEF      1.4  // max dwell seconds on a normal blink
#define ACC_PHANTOM_RETREAT_DEF         1    // hit-and-run: warp away after a normal strike so it never camps a player
#define ACC_PHANTOM_RETREAT_DIST_DEF    420  // how far the back-off warp jumps from the struck player
#define ACC_PHANTOM_CHAIN_CHANCE_DEF    25   // % of teleport actions that fire the player->player CHAIN special (1+ players; one hit each)
#define ACC_PHANTOM_CHAIN_HOPS_DEF      3    // MAX hops per chain (one hit per player, warp to the next) - CAPPED to the live player count, so solo = 1 hop
#define ACC_PHANTOM_CHAIN_DWELL_MIN_DEF 0.7  // min seconds on each chain hop (the rapid combo) - time for one swing
#define ACC_PHANTOM_CHAIN_DWELL_MAX_DEF 1.1  // max seconds on each chain hop

// Subroutine Core full-boss cadence (mirror of _acc_boss.gsc) - the Phantom yields these rounds.
#define ACC_PHANTOM_FULLBOSS_FIRST    30
#define ACC_PHANTOM_FULLBOSS_INTERVAL 10

#define ACC_PHANTOM_DISPLAY_NAME "PHANTOM"

#namespace acc_boss_phantom;

// Server-side registration of the holographic GLOW-aura clientfield, IN LOCKSTEP with the
// .csc mirror (_acc_boss_phantom.csc - scope/name/version/bits/type MUST match or the bit
// layout desyncs). The server only SETS this field (on the cloak transitions in
// phantom_cloak_loop); the .csc actually PlayFX's the glow. actor scope, like accEyeTint.
// REGISTER_SYSTEM autoexec runs at the correct pre-load phase.
REGISTER_SYSTEM( "acc_phantom_aura", &aura_register, undefined )

function aura_register()
{
    // 2 bits (user 2026-06-24): 0 off / 1 red (Phantom) / 2 dimmed teal (Glitch Stalker). LOCKSTEP with the
    // .csc registration (scope/name/version/bits/type MUST match).
    clientfield::register( "actor", "accPhantomAura", VERSION_SHIP, 2, "int" );
}

// ---------------------------------------------------------------------------
// Lifecycle + cadence (the round-boss rotation slot)
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "boss_phantom: init (holographic cloaker mini-boss, script-only)" );

    // FULLPROOF SPAWN ARCHITECTURE (user 2026-06-25). Split into two halves so NOTHING can permanently stop the
    // Phantom:
    //   round_watch        - the cheap "is a Phantom DUE this round?" decider; on a due round it just raises the
    //                        OWED flag (it NEVER tries to spawn, so it can't be blocked by anything).
    //   phantom_director   - the single, persistent spawner. While a Phantom is owed and none is alive, it KEEPS
    //                        RETRYING the spawn (every few seconds, across rounds) until one actually exists.
    // The owed flag only clears two ways: a Phantom is alive, or a spawn succeeds. So a jammed/stuck Glitch Purge
    // (or anything else) can at most DELAY the Phantom a few seconds while the actor pool is saturated - it can
    // never drop the spawn for the rest of the match (the round-7 "phantom never spawned in real games" class of
    // bug). The purge is also force-shut-down after 2 rounds (_acc_lockdown_challenge::ldc_round_cap_watch), which
    // frees those actor slots regardless.
    level.acc_phantom_owed = false;
    level thread round_watch();
    level thread phantom_director();
}

function round_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        if ( phantom_round_is_due( round_number ) )
            level.acc_phantom_owed = true;   // mark only - the director fulfills it (fullproof: never one-shot)
    }
}

// Pure decision: should THIS round owe a Phantom? Master gate + the manual test path + the real cadence. NO
// spawning and NO purge check here - whether a purge is active is irrelevant to whether the Phantom is owed.
function phantom_round_is_due( round_number )
{
    // Master gate for NORMAL play; the dev sandbox (level.acc_dev) bypasses it so acc_dev owes the phantom for
    // testing without forcing acc_phantom_enable's value (user 2026-06-22, one-flag dev).
    if ( getdvarint( "acc_phantom_enable", ACC_PHANTOM_ENABLE_DEF ) != 1 && !IS_TRUE( level.acc_dev ) )
        return false;

    // MANUAL test opt-in (+set acc_phantom_test 1): owe it every round from acc_phantom_test_round on.
    test = getdvarint( "acc_phantom_test", 0 );
    if ( test == 1 && round_number >= getdvarint( "acc_phantom_test_round", ACC_PHANTOM_TEST_ROUND_DEF ) )
        return true;

    return cadence_hits( round_number );
}

// THE SINGLE PHANTOM SPAWNER (user 2026-06-25: FULLPROOF). Persistent for the whole match. Whenever a Phantom is
// OWED (a due round passed) and none is currently alive, it spawns one. Under a SATURATED actor pool (jammed
// purge / dense horde) stock spawn_zombie BLOCKS inside the spawn until a slot frees rather than failing, so the
// spawn still completes - just delayed; if the spawn ever does return undefined (the cold-round-start case), the
// director simply tries AGAIN next tick. The only escapes from "owed" are (a) a Phantom is alive, or (b) a spawn
// succeeds, so the boss can never be permanently suppressed. DECOUPLED FROM THE PURGE: it does NOT read
// level.acc_ldc_active at all. run_round_boss is called INLINE here (it carries NO endon now, so neither it nor a
// blocking spawn inside it can be torn down at round end) and returns the host on success.
function phantom_director()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait( getdvarint( "acc_phantom_director_period", 3 ) );

        if ( !IS_TRUE( level.acc_phantom_owed ) )
            continue;

        // Re-validate the master gate (it may have been toggled off after the round was marked owed).
        if ( getdvarint( "acc_phantom_enable", ACC_PHANTOM_ENABLE_DEF ) != 1 && !IS_TRUE( level.acc_dev ) )
        {
            level.acc_phantom_owed = false;
            continue;
        }

        // A Phantom already up SATISFIES the owed slot (one-at-a-time): clear owed and wait for the next due
        // round. (Clearing here is what stops an instant respawn when this living Phantom later dies.)
        if ( isdefined( level.acc_phantom_host ) && isalive( level.acc_phantom_host ) )
        {
            level.acc_phantom_owed = false;
            continue;
        }

        pdebug( "director: Phantom OWED + none alive -> attempting spawn (round " + level.round_number + ")" );
        host = run_round_boss( level.round_number );
        if ( isdefined( host ) && isalive( host ) )
        {
            level.acc_phantom_owed = false;
            pdebug( "director: Phantom spawned -> owed cleared" );
        }
        // else: stay owed -> retry next tick (the actor pool is momentarily full; never give up).
    }
}

// The ROUND-BOSS ROTATION (user 2026-06-18: random pick per cadence slot). One entry now (Phantom); add future
// script-only bosses to the pool and they join the random rotation. Called INLINE by phantom_director, so it
// carries NO endon (an endon here would attach to and tear down the persistent director thread). Returns the
// live host on success, or undefined if the spawn could not be completed (the director then retries).
function run_round_boss( round_number )
{
    // ONE at a time (user 2026-06-23): never stack a second Phantom while one is still alive (it fights alongside
    // the wave + never gates round end, so it can outlive its round). The director also guards this, belt-and-braces.
    if ( isdefined( level.acc_phantom_host ) && isalive( level.acc_phantom_host ) )
        return level.acc_phantom_host;

    pool = [];
    pool[ pool.size ] = "phantom";
    // pool[ pool.size ] = "colossus";   // <- future bosses register here
    pick = pool[ acc_utility::acc_rand_int( pool.size ) ];

    if ( pick == "phantom" )
        return spawn_phantom( round_number );
    return undefined;
}

function cadence_hits( round_number )
{
    // DEV mode (level.acc_dev) spawns the Phantom every 4 rounds (4, 8, 12, ...) for faster testing; base game
    // every 8 (8, 16, 24, ...) - user 2026-06-25. Hardcoded off the one dev flag (no new dvar - dev-mode rule);
    // the acc_phantom_first_round / acc_phantom_interval dvars still override either default for live tuning.
    dev          = IS_TRUE( level.acc_dev );
    def_first    = ( dev ? 4 : ACC_PHANTOM_FIRST_ROUND_DEF );
    def_interval = ( dev ? 4 : ACC_PHANTOM_INTERVAL_DEF );

    first    = getdvarint( "acc_phantom_first_round", def_first );
    interval = getdvarint( "acc_phantom_interval", def_interval );
    if ( interval < 1 ) interval = 1;
    if ( round_number < first ) return false;
    return ( ( round_number - first ) % interval ) == 0;
}

function is_full_boss_round( round_number )
{
    return ( round_number >= ACC_PHANTOM_FULLBOSS_FIRST
             && ( round_number % ACC_PHANTOM_FULLBOSS_INTERVAL ) == 0 );
}

function announce_inbound()
{
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5" + ACC_PHANTOM_DISPLAY_NAME + " ^7- something is phasing in..." );
    }
}

// ---------------------------------------------------------------------------
// Spawn + promote
// ---------------------------------------------------------------------------

function spawn_phantom( round_number )
{
    host = spawn_promoted_zombie();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        pdebug( "spawn FAILED r" + round_number + " (no host from spawn_promoted_zombie)" );
        return;
    }

    host.acc_is_mini_boss = true;   // boss headshot mult + corpse-cleanup skip + speed-keepalive skip
    host.acc_is_phantom = true;     // tag for the chain-special slow detection in _acc_elites::on_player_damaged
    level.acc_phantom_host = host;  // one-at-a-time guard ref (every-round cadence; run_round_boss checks isalive)

    // LOGARITHMIC HP scaling by player count (user 2026-06-24: the old LINEAR 100k*pc -> 400k at 4p was
    // "crazy"). boss_hp_player_mult() = 1 + 0.5*log2(n) -> solo 80k / 2p 120k / 3p 143k / 4p 160k (base
    // ACC_PHANTOM_HP is -20%). Tune live: acc_boss_coop_hp_log_k. Written AFTER the init-gate (stock clobbers HP).
    host.maxhealth = int( ACC_PHANTOM_HP * acc_coop_scaling::boss_hp_player_mult() );
    host.health = host.maxhealth;

    // LOW melee (user 2026-06-24): jumpscary, not a murderer - per-hit is ~30% UNDER a Glitch Stalker (default
    // 19, see ACC_PHANTOM_MELEE_DMG_DEF). Bosses are excluded from the trench-melee override (apply_speed_for_round
    // returns early on acc_is_mini_boss / acc_boss_custom_speed), so this value sticks - nothing resets it to the
    // 45/60 horde melee. Set AFTER the init-gate (stock writes meleeDamage=60 at spawn).
    host.meleeDamage = getdvarint( "acc_phantom_melee_dmg", ACC_PHANTOM_MELEE_DMG_DEF );

    // Durability: a mobile boss alongside the wave; never pinned (it moves), never gates round end.
    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host.no_gib = true;
    host.ignore_nuke = true;
    host.ignore_enemy_count = true;
    host.acc_boss_custom_speed = true; // _acc_zombie_speed keep-alive skips us (we drive gait)

    // Canvas: stock Giant body (distinct from the charred horde). The Phantom is cloaked most
    // of the time, so the body is just the brief-materialize silhouette. Same proven reskin idiom
    // as the Glitch Stalker. NO SetScale.
    if ( getdvarint( "acc_phantom_stock_skin", 1 ) == 1 )
    {
        host SetModel( "c_zom_der_zombie_body1" );
        host Detach( "c_zom_dlc4_zombie_charred_head" );
        host Attach( "c_zom_der_zombie_head1" );
        if ( isdefined( host.gib_data ) )
            host.gib_data.head = "c_zom_der_zombie_head1";
    }

    // Cyan/teal eyes via the EXISTING actor eye-tint clientfield (shared color, no new .csc).
    if ( getdvarint( "acc_phantom_eyes", 1 ) == 1 )
        acc_lui::set_actor_eye_tint( host, true );

    // THE BOSS treatment (user 2026-06-18): named boss health bar + boss music. The Phantom is
    // the real ~round-10 boss, so it gets both (Brutus was down-leveled to a music-less, bar-less
    // mini-boss). Bar = the acc_boss_spawned notify; music = the shared acc_boss::boss_music loop.
    level notify( "acc_boss_spawned", host, ACC_PHANTOM_DISPLAY_NAME );
    level thread acc_boss::boss_music( host );

    announce_inbound();

    host thread phantom_cloak_loop();      // the holographic cloak/flicker (self-endons on death)
    host thread phantom_speed_think();
    host thread phantom_teleport_loop();   // teleport-harass: chain player->player, hit-and-run (user 2026-06-24)
    host thread phantom_death_watch();

    pdebug( "^5Phantom^7 spawned (" + host.maxhealth + " hp, round " + round_number + ")" );

    return host;   // [acc] the Paradise onslaught (_acc_paradise) captures the host to count concurrent finale Phantoms
}

// Active spawner NEAREST a random living player (NOT a fully-random one). This is the SAME fix the
// Glitch Stalker got (_acc_boss_glitch.gsc::nearest_spawner_to_player, 2026-06-23): level.zombie_spawners
// is already active-zone-only, but a RANDOM pick scatters the boss across ALL currently-open zones, so a
// player often never saw it (esp. pre-power, when it kept landing in a different open zone than the one you
// stand in). Combined with the Phantom's CLOAK (invisible until 240u) + 100k HP + the one-at-a-time guard,
// that random pick was why the Phantom "never spawned" in normal play (user 2026-06-24): the one Phantom that
// did spawn landed somewhere you weren't, stayed invisible, never died, and blocked every later round. Falls
// back to a random active spawner if there is no living player. Memory: custom-spawn-near-player-not-random.
function nearest_spawner_to_player()
{
    players = GetPlayers();
    living  = [];
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && isalive( p ) )
            living[ living.size ] = p;
    }
    if ( living.size == 0 )
        return undefined;

    target = living[ acc_utility::acc_rand_int( living.size ) ];

    best   = undefined;
    best_d = undefined;
    for ( i = 0; i < level.zombie_spawners.size; i++ )
    {
        sp = level.zombie_spawners[ i ];
        if ( !isdefined( sp ) )
            continue;
        d = DistanceSquared( target.origin, sp.origin );
        if ( !isdefined( best_d ) || d < best_d )
        {
            best_d = d;
            best   = sp;
        }
    }
    return best;
}

// Spawn a stock-template zombie from the active base spawner NEAREST a player and INIT-GATE it (clone of the
// Glitch / Subroutine Core path). Returns the live actor or undefined.
function spawn_promoted_zombie()
{
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
        return undefined;

    // SPAWN WITH RETRY (user 2026-06-24, the proven "never spawned" root cause - live console_mp.log r1:
    // "spawn_zombie returned undefined" at the SAME ms = SpawnFromSpawner came back with no live actor, NOT an
    // actor-budget wait). The Phantom fires the instant "acc_round_start" notifies, but stock spawn_zombie's
    // SpawnFromSpawner(0,true) (level.overrideZombieSpawn is never set, so that branch is taken) only succeeds
    // once the round's spawn system is ACTIVE - it has flagged/allocated the spawner. The Glitch (first round
    // 4) and elites spawn MID-round so they inherit a warm spawner; the Phantom at the cold round-start instant
    // does not. So we (a) set script_forcespawn ourselves (zombie_utility.gsc:1538 returns undefined without it)
    // and (b) RETRY for a few seconds until the spawn system is live. This is deterministic at ANY round incl.
    // r1. A SATURATED actor pool (jammed purge / dense horde) makes stock spawn_zombie BLOCK until a slot frees
    // rather than fail, so the spawn still completes - just delayed. The undefined return this loop guards is the
    // COLD-ROUND-START case; whenever we do return undefined, phantom_director re-calls us next tick (the spawn
    // stays OWED until it succeeds - fullproof).
    core         = undefined;
    attempts     = 0;
    max_attempts = 20;   // ~20s window; succeeds on attempt 0 mid-round, retries only at a cold round start
    while ( attempts < max_attempts )
    {
        spawner = nearest_spawner_to_player();
        if ( !isdefined( spawner ) )
            spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
        spawner.script_forcespawn = true;   // REQUIRED or spawn_zombie returns undefined (stock "MUST BE SET FORCESPAWN")

        core = zombie_utility::spawn_zombie( spawner );
        if ( isdefined( core ) )
            break;

        attempts++;
        wait 1;
    }
    if ( !isdefined( core ) )
    {
        pdebug( "spawn_zombie undefined after " + max_attempts + " attempts" );
        return undefined;
    }

    n = 0;
    while ( isdefined( core ) && !isdefined( core.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( core ) || !isalive( core ) )
        return undefined;
    return core;
}

// ---------------------------------------------------------------------------
// Holographic cloak: invisible while stalking, materialize to strike, flicker when visible.
// Ghost()/Show() toggle RENDERING only - the Phantom is ALWAYS solid + hittable + meleeing,
// so cloaked = "you can't see it coming," not "it can't hurt you." Single Ghost/Show writer.
// ---------------------------------------------------------------------------

function phantom_cloak_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    self.acc_phantom_shown = true;
    self.acc_phantom_mat   = true;          // materialized-state latch (drives the aura toggle)
    set_phantom_aura( self, true );         // spawns materialized -> aura on

    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        // Cloak disabled -> always visible + aura on.
        if ( getdvarint( "acc_phantom_cloak", 1 ) != 1 )
        {
            if ( !self.acc_phantom_shown ) { self Show(); self.acc_phantom_shown = true; }
            if ( !self.acc_phantom_mat )   { self.acc_phantom_mat = true; set_phantom_aura( self, true ); }
            wait 0.25;
            continue;
        }

        target = acc_utility::get_closest_uncloaked_player( self.origin ); // honor Li'l Arnie cloak
        reveal = getdvarint( "acc_phantom_reveal_dist", ACC_PHANTOM_REVEAL_DIST_DEF );
        near   = ( isdefined( target ) && Distance( self.origin, target.origin ) <= reveal );

        // The GLOW AURA tracks the MATERIALIZED state (near), NOT the per-tick flicker - the cyan
        // energy field stays steady while the body phases, and it's OFF while cloaked so a floating
        // glow never reveals the invisible Phantom. Set only on the transition.
        if ( near != self.acc_phantom_mat )
        {
            self.acc_phantom_mat = near;
            set_phantom_aura( self, near );
            if ( near )
                materialize_scare( self );   // screech on the cloaked->visible reveal
        }

        if ( near )
        {
            // Materialized to strike, but FLICKER (brief invisible blips) = unstable hologram.
            flick = getdvarint( "acc_phantom_flicker_pct", ACC_PHANTOM_FLICKER_PCT_DEF );
            if ( flick > 0 && acc_utility::acc_rand_int( 100 ) < flick )
            { self Ghost(); self.acc_phantom_shown = false; }
            else
            { self Show();  self.acc_phantom_shown = true; }
        }
        else
        {
            // Far -> fully cloaked (stalking).
            if ( self.acc_phantom_shown ) { self Ghost(); self.acc_phantom_shown = false; }
        }

        wait 0.1;
    }
}

// Set the holographic glow-aura clientfield (the .csc PlayFX's it). Cloak-aware: on=materialized.
// Gated by acc_phantom_aura (default 1); when off, force-clears any existing aura. COLOUR is per-actor
// (user 2026-06-24): ent.acc_aura_color 1 = red (Phantom, default) / 2 = dimmed teal (Glitch Stalker sets
// it before calling). The .csc maps the value to the matching FX - so both bosses share this one field.
function set_phantom_aura( ent, on )
{
    if ( !isdefined( ent ) ) return;
    if ( getdvarint( "acc_phantom_aura", 1 ) != 1 )
    {
        ent clientfield::set( "accPhantomAura", 0 );
        return;
    }
    color = 1;   // default red (Phantom)
    if ( isdefined( ent.acc_aura_color ) )
        color = ent.acc_aura_color;
    ent clientfield::set( "accPhantomAura", ( IS_TRUE( on ) ? color : 0 ) );
}

// The cloaked->visible REVEAL scare: a warp screech the instant he materializes on you (reuses the
// confirmed Glitch warp alias). Cooldown'd (2s) so dancing at the reveal edge can't machine-gun it.
// Gated by acc_phantom_screech.
function materialize_scare( ent )
{
    if ( !isdefined( ent ) ) return;
    if ( getdvarint( "acc_phantom_screech", 1 ) != 1 ) return;

    now = GetTime();
    if ( isdefined( ent.acc_phantom_last_screech ) && ( now - ent.acc_phantom_last_screech ) < getdvarint( "acc_phantom_screech_cd", 1200 ) )
        return;
    ent.acc_phantom_last_screech = now;
    ent PlaySound( "acc_glitch_warp" );
}

// Drive the gait every sweep (the global keep-alive skips mini-bosses). Clone of
// glitch_speed_think. NEVER rate < 1.0 (no slow-mo); NO SetScale.
function phantom_speed_think()
{
    self endon( "death" );
    level endon( "end_game" );

    self.acc_boss_custom_speed = true;

    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        // FIXED sprint-gait speed, CONSTANT every round (user 2026-06-24) - NOT scaled to the round's horde
        // gait. Zombie movement is anim-driven (see the _acc_zombie_speed header) and anim-rate -> ground
        // speed is NON-LINEAR, so the rate is TUNED BY MEASUREMENT (the [SPD] probe), not math.
        // acc_phantom_speed_mult is the live rate; 1.0 = natural zombie sprint (~181 u/s). Target = your
        // sprint +2% (dial it up live, watch PH in the probe, then bake the value).
        rate = getdvarfloat( "acc_phantom_speed_mult", ACC_PHANTOM_SPEED_MULT_DEF );
        if ( rate < 0.1 ) rate = 0.1;

        self zombie_utility::set_zombie_run_cycle_override_value( "sprint" );
        self ASMSetAnimationRate( rate );
        wait 1;
    }
}

// ---------------------------------------------------------------------------
// Teleport mobility (user 2026-06-24, refined): the Phantom STALKS most of the time (normal AI walk + melee)
// and periodically BLINKS to reposition - so it teleports rather than wanders, but it is NOT mega-aggressive.
// The cadence is ~30% SLOWER than the Glitch Stalker's blink (1.33-2.22s), i.e. "~30% less aggro". A normal
// teleport action is a single HIT-AND-RUN (blink into melee, one swing, blink away - never camps). The flashy
// player->player CHAIN is a RANDOM SPECIAL (acc_phantom_chain_chance %; fires with 1+ players, ONE hit per
// player - solo = a single strike), fired occasionally - NOT the constant mode. Reuses the VERIFIED(acc)
// teleport pattern (GetClosestPointOnNavMesh -> forceteleport) so a
// blink can never land off-mesh / in geometry. Cloaked arrivals + screech = the JUMPSCARE; low melee = not a
// murderer. Live toggles: acc_phantom_teleport, acc_phantom_tp_cd_*, acc_phantom_chain_*, acc_phantom_retreat.
// ---------------------------------------------------------------------------
function phantom_teleport_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    wait getdvarfloat( "acc_phantom_tp_delay", ACC_PHANTOM_TP_DELAY_DEF );   // grace after spawn

    last_target = undefined;
    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        // STALK GAP: no teleport this whole window - the Phantom just walks + melees via the normal AI. Longer
        // than the glitch's blink cd (1.33-2.22s) so it is ~30% LESS aggressive and does NOT constantly teleport.
        wait phantom_rand_range( getdvarfloat( "acc_phantom_tp_cd_min", ACC_PHANTOM_TP_CD_MIN_DEF ),
                                 getdvarfloat( "acc_phantom_tp_cd_max", ACC_PHANTOM_TP_CD_MAX_DEF ) );
        if ( !isalive( self ) ) return;

        if ( getdvarint( "acc_phantom_teleport", ACC_PHANTOM_TELEPORT_DEF ) != 1 )
            continue;

        valid = valid_target_players();
        if ( valid.size == 0 )
            continue;   // whole team downed/invalid - nothing to harass; keep stalking cloaked

        // SPECIAL MOVE: the player->player CHAIN, fired RANDOMLY (not every cycle). Fires with 1+ players up
        // (was 2+, user 2026-06-26): a lone player still faces the stun special (and it's now testable SOLO in
        // god mode - the whole point of the Phantom-side zap apply). phantom_chain hits EACH player exactly once
        // (hops capped to the live player count), so in SOLO it is a SINGLE strike on the lone player instead of
        // re-chaining the same target 3x (user 2026-06-26). acc_phantom_chaining marks the window so
        // _acc_elites::on_player_damaged knows a connecting melee is the CHAIN SPECIAL -> it zaps the hit player
        // (-25% slow + SFX; Mega Electric Cherry immune).
        if ( valid.size >= 1 &&
             acc_utility::acc_rand_int( 100 ) < getdvarint( "acc_phantom_chain_chance", ACC_PHANTOM_CHAIN_CHANCE_DEF ) )
        {
            self.acc_phantom_chaining = true;
            last_target = phantom_chain( last_target );
            self.acc_phantom_chaining = false;
            continue;
        }

        // NORMAL action: a single HIT-AND-RUN - blink into melee on a random valid player (excluding the last
        // when 2+), let one swing land, then blink away so it never camps. Then back to the stalk gap above.
        target = pick_chain_target( valid, last_target );
        last_target = target;
        phantom_blink_to( target );
        wait phantom_rand_range( getdvarfloat( "acc_phantom_strike_min", ACC_PHANTOM_STRIKE_MIN_DEF ),
                                 getdvarfloat( "acc_phantom_strike_max", ACC_PHANTOM_STRIKE_MAX_DEF ) );
        if ( !isalive( self ) ) return;
        phantom_back_off( target );
    }
}

// The CHAIN SPECIAL (random, fired by phantom_teleport_loop): warp player->player, ONE hit on EACH player in
// the game, a rapid hit-and-run combo across the team. CHAINS TO EACH PLAYER ONCE (user 2026-06-26): the hop
// count is capped to the number of distinct valid players and every hop targets a player NOT YET HIT this
// chain, so the special sweeps each player exactly once instead of re-striking the same one. In SOLO that is a
// SINGLE hop on the lone player (it no longer re-chains the solo player 3x - the user's fix); in coop it warps
// player->player, one hit each, up to acc_phantom_chain_hops (the MAX, still bounded by the live player count).
// This is the signature flashy move - used OCCASIONALLY, never the constant behavior. Returns the last player
// hit so the caller's "don't immediately repeat" exclusion carries over.
function phantom_chain( last_target )
{
    max_hops = getdvarint( "acc_phantom_chain_hops", ACC_PHANTOM_CHAIN_HOPS_DEF );
    if ( max_hops < 1 ) max_hops = 1;

    hit  = [];            // players already struck THIS chain (each player is hit at most once)
    prev = last_target;
    for ( h = 0; h < max_hops; h++ )
    {
        if ( !isalive( self ) ) return prev;
        live = valid_target_players();   // refresh each hop (players move / down / revive)
        if ( live.size == 0 ) return prev;

        // Players not yet hit in this chain. When this is empty, every valid player has already taken a hop, so
        // the chain is DONE - this is what stops the solo (1-player) chain after a SINGLE strike instead of
        // re-warping onto the same player for the remaining hops.
        fresh = players_not_yet_hit( live, hit );
        if ( fresh.size == 0 )
            return prev;

        target = pick_chain_target( fresh, prev );
        prev = target;
        hit[ hit.size ] = target;
        phantom_blink_to( target );

        // CHAIN-SPECIAL SLOW, applied from the Phantom side (user 2026-06-25): the blink teleport-strikes ONTO the
        // player, so the chain connects on arrival - apply the -25% zap directly (gated on a generous melee range)
        // INSTEAD of relying on the player-damage callback. This makes the special's stun land even in GOD MODE
        // (EnableInvulnerability suppresses the damage event, so the old on_player_damaged path never fired there) -
        // so the speed effect is testable while invulnerable. Mega Electric Cherry immunity is still honored inside
        // acc_phantom_chain_zap. acc_phantom_slow_sec / acc_phantom_speed_mult tune the feel.
        if ( isdefined( target ) && isalive( target ) &&
             DistanceSquared( self.origin, target.origin ) <= ( 160 * 160 ) )
            target acc_elites::acc_phantom_chain_zap();

        wait phantom_rand_range( getdvarfloat( "acc_phantom_chain_dwell_min", ACC_PHANTOM_CHAIN_DWELL_MIN_DEF ),
                                 getdvarfloat( "acc_phantom_chain_dwell_max", ACC_PHANTOM_CHAIN_DWELL_MAX_DEF ) );
    }
    return prev;
}

// Players in `live` that are NOT already in the `hit` list, so a chain visits each player at most once (the
// solo case collapses to a single hop - the lone player is in `hit` after hop 0, so fresh is then empty).
function players_not_yet_hit( live, hit )
{
    out = [];
    for ( i = 0; i < live.size; i++ )
    {
        already = false;
        for ( j = 0; j < hit.size; j++ )
            if ( live[ i ] == hit[ j ] ) { already = true; break; }
        if ( !already )
            out[ out.size ] = live[ i ];
    }
    return out;
}

// One strike-warp: teleport into melee on our own reachable side (nav-clamped; VERIFIED(acc) pattern) + the
// arrival screech. Shared by the normal single blink and every chain hop.
function phantom_blink_to( target )
{
    if ( !isdefined( target ) ) return;
    strike = GetClosestPointOnNavMesh( phantom_strike_point( self.origin, target.origin ), 100, 30 );
    if ( !isdefined( strike ) )
        strike = GetClosestPointOnNavMesh( target.origin, 140, 50 );
    if ( !isdefined( strike ) ) return;
    self forceteleport( strike );
    materialize_scare( self );   // arrival screech (cooldownned; shared with the cloak-reveal scare)
}

// Hit-and-run back-off after a NORMAL strike: warp away from the struck player so the Phantom never camps (the
// cloak loop re-hides it at range). Skipped if acc_phantom_retreat is off.
function phantom_back_off( target )
{
    if ( !isdefined( target ) ) return;
    if ( getdvarint( "acc_phantom_retreat", ACC_PHANTOM_RETREAT_DEF ) != 1 ) return;
    retreat = GetClosestPointOnNavMesh( phantom_retreat_point( target.origin ), 160, 50 );
    if ( isdefined( retreat ) )
        self forceteleport( retreat );
}

// All currently-valid (alive, spawned, NOT downed/laststand, not spectating) players - the teleport targets.
// Excluding downed players is what keeps the Phantom from teleport-finishing a bleeding-out teammate (it is a
// harasser, not an executioner). Uses the shared zm_utility::is_player_valid wrapper.
function valid_target_players()
{
    out = [];
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( acc_data_shards::is_player_alive( p ) )
            out[ out.size ] = p;
    }
    return out;
}

// Pick a random player from `valid`, dropping `avoid` (the last one struck) when 2+ remain so coop play
// CHAINS player->player. Falls back to the full set if culling would leave nobody.
function pick_chain_target( valid, avoid )
{
    pool = valid;
    if ( valid.size > 1 && isdefined( avoid ) )
    {
        culled = [];
        for ( i = 0; i < valid.size; i++ )
            if ( valid[ i ] != avoid )
                culled[ culled.size ] = valid[ i ];
        if ( culled.size > 0 )
            pool = culled;
    }
    return pool[ acc_utility::acc_rand_int( pool.size ) ];
}

// A point acc_phantom_strike_dist short of the player along OUR approach vector (boss->player) - lands in
// melee on our own reachable side (the glitch pounce idiom). Caller nav-clamps it.
function phantom_strike_point( from, to )
{
    d   = getdvarint( "acc_phantom_strike_dist", ACC_PHANTOM_STRIKE_DIST_DEF );
    dir = VectorNormalize( to - from );
    return to - dir * d;
}

// An axis-aligned point acc_phantom_retreat_dist from the struck player (random of 4 directions; no trig -
// the caller nav-clamps it to a real point regardless of direction). The solo "back off" destination.
function phantom_retreat_point( player_origin )
{
    d = getdvarint( "acc_phantom_retreat_dist", ACC_PHANTOM_RETREAT_DIST_DEF );
    r = acc_utility::acc_rand_int( 4 );
    if ( r == 0 ) return player_origin + ( d, 0, 0 );
    if ( r == 1 ) return player_origin + ( d * -1, 0, 0 );
    if ( r == 2 ) return player_origin + ( 0, d, 0 );
    return player_origin + ( 0, d * -1, 0 );
}

// A float in [lo, hi] (engine randomfloat is [0,hi)); tolerates an inverted range.
function phantom_rand_range( lo, hi )
{
    if ( hi < lo ) hi = lo;
    return lo + randomfloat( hi - lo );
}

// ---------------------------------------------------------------------------
// Death -> rewards (standard mini-boss tier: boss-item roll + Mega Bottle).
// ---------------------------------------------------------------------------

function phantom_death_watch()
{
    self waittill( "death", attacker );

    if ( isdefined( self ) )
    {
        self Show();                                  // un-cloak so the corpse renders
        self clientfield::set( "accPhantomAura", 0 ); // kill the glow aura (cloak loop endon'd on death)
    }

    // Clear the one-at-a-time guard ref so the NEXT round's cadence can spawn a fresh Phantom. The guard
    // (run_round_boss) also checks isalive(), but clearing it explicitly here removes any reliance on a
    // dead-actor edge case and documents the lifecycle (user 2026-06-24 no-spawn fix).
    if ( isdefined( level.acc_phantom_host ) && level.acc_phantom_host == self )
        level.acc_phantom_host = undefined;

    drop_origin = self.origin;

    // Phantom reward (user 2026-06-22): GUARANTEED full set - 1 item drop + 1 Mega Bottle to every player +
    // 5 Data Shards to every player. (Brutus gets the SAME set but with 3 shards, also 100%; see _acc_boss.gsc.)
    acc_boss_items::grant_challenge_reward( drop_origin );            // 1 item, guaranteed (free-for-all pool drop)
    acc_mega_bottles::on_boss_death( "mini", attacker, drop_origin ); // 1 Mega Bottle to every player
    phantom_shards = getdvarint( "acc_phantom_shard_reward", 5 );
    if ( phantom_shards > 0 )
    {
        for ( pi = 0; pi < level.players.size; pi++ )
            acc_data_shards::grant_player( level.players[ pi ], phantom_shards, "phantom" );
    }

    pdebug( "^2Phantom down^7" );

    // Free the actor slot. acc_is_mini_boss makes _acc_corpse_cleanup SKIP this body (it "owns its death
    // visuals"), so without an explicit delete the corpse lingers FOREVER - and the Phantom now spawns EVERY
    // round, so the corpses pile up and permanently eat actor slots until the spawn budget starves. Mirrors
    // _acc_boss_glitch::cleanup_glitch_corpse. Threaded AFTER the rewards above (which captured drop_origin).
    if ( isdefined( self ) )
        self thread cleanup_phantom_corpse();
}

// Hide + delete the Phantom corpse to free the actor slot (it is skipped by _acc_corpse_cleanup via
// acc_is_mini_boss). De-collide + Ghost NOW, a beat for the engine to finish death processing, then Delete.
function cleanup_phantom_corpse()
{
    self NotSolid();
    self Ghost();
    wait( 0.05 );
    if ( isdefined( self ) )
        self Delete();
}

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------

function pdebug( msg )
{
    if ( getdvarint( "acc_phantom_debug", 0 ) != 1 ) return;
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5[phantom] ^7" + msg );
    }
}
