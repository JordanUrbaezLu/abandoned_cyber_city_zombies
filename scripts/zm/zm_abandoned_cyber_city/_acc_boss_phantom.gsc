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
// NOT edited. Disable live: `acc_phantom_enable 0`. Trace via a dev build (debug prints
// ride level.acc_dev; the acc_phantom_debug dvar was removed 2026-07-16).
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
#using scripts\zm\_zm_score;                                  // add_to_player_score (round-scaled Phantom kill points)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;   // grant_player (round-scaled shards/player on Phantom kill)
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;   // boss_hp_player_mult (log coop HP)
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;         // acc_phantom_chain_zap (apply the chain slow Phantom-side, god-mode-safe)
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;     // force_playable_emergence (unlock stock melee below player_volumes - Paradise/deep trench)

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// --- Tunable defaults (every one a live acc_phantom_* dvar; mirror docs/22). ---
// ENABLED (user 2026-06-22): Phantom is a live boss in BOTH normal play and dev, first appearing at
// round 10 (then every 10 rounds - ACC_PHANTOM_INTERVAL 10 - with a one-at-a-time guard). Disable live with
// `acc_phantom_enable 0`. (RED holographic glow + cyan eyes; shares the phase theme with the Glitch
// Stalker - re-theme later if they read too similar.)
#define ACC_PHANTOM_ENABLE_DEF        1     // master on/off (1 = on in normal play; dev also runs it)
#define ACC_PHANTOM_HP                65000  // BASE solo HP at the round-5 anchor (user 2026-07-05: 56000 -> 65000). Shared by Phantom + Rogue + Avogadro (+ Panzer). COMPOUNDS per round (user 2026-06-27, scale_phantom_hp): x ACC_PHANTOM_HP_EXP^(round-anchor) THEN x boss_hp_player_mult (LOGARITHMIC coop). Was FLAT every round = the no-scaling bug. Live dvar acc_phantom_hp.
#define ACC_PHANTOM_HP_EXP            1.06   // per-round COMPOUNDING exponent (user 2026-07-04: 1.1 -> 1.08 -> 2026-07-08 1.06 after the anchor moved to r5). TIERED BOSS SCALE, all sharing base 65000 + anchor 5, differing ONLY by exponent: Brutus/Panzer 1.12 > Rogue Protector 1.09 > Phantom 1.06 (Phantom is the SOFTEST; Avogadro shares this). Phantom solo r5 65k / r10 87k / r20 156k / r30 279k / r40 500k. Live dvar acc_phantom_hp_exp.
#define ACC_PHANTOM_HP_ANCHOR         5      // round the BASE HP applies + compounding STARTS (user 2026-07-08: 10 -> 5, so ALL bosses scale from round 5; they first spawn at round 9 = base x exp^4). Live dvar acc_phantom_hp_anchor.
#define ACC_PHANTOM_FIRST_ROUND_DEF   10    // BASE-GAME first round (round 10), then every ACC_PHANTOM_INTERVAL rounds (user 2026-06-26). (Stale "DEV mode = 4" note removed 2026-07-17: that fast cadence was disabled 2026-07-12; the CURRENT dev accelerator is the one-shot round-3 spawn in phantom_due_count.)
#define ACC_PHANTOM_INTERVAL_DEF      10    // LEGACY-FALLBACK cadence only (used if the shared roster pointer isn't published yet). Live rotation is the every-9 multi-boss roster in _acc_civil_protector. DEV fallback = every 4.
#define ACC_PHANTOM_TEST_ROUND_DEF    8     // dev/test first round
// AGGRESSION MODEL (user 2026-06-24): jumpscary TELEPORTING HARASSER, not a camper and not a murderer. The
// cloaked arrival + screech is the SCARE; the LOW melee keeps it survivable. He still EARNS his guaranteed Mega
// Bottle through pressure + mobility, not raw damage. Speed stays the modest +10% gait (the TELEPORTING is what
// reads as "fast"); bumping the anim rate risks the documented non-linear catch+instakill overshoot.
#define ACC_PHANTOM_REVEAL_DIST_DEF   240   // stay invisible until THIS close, then materialize (was 400 - now he's on you)
#define ACC_PHANTOM_SPEED_MULT_DEF    1.1   // sprint-gait playback rate. User 2026-06-24: +10% from the 1.0 interim baseline (natural zombie sprint ~181 u/s, KITEABLE vs a player's ~299 sprint). CAVEAT: anim-rate->ground-speed is NON-LINEAR (1.685 once overshot badly = caught+instakilled), so 1.1 is +10% PLAYBACK, not exactly +10% u/s - verify real speed with the [SPD] probe and tune LIVE via acc_phantom_speed_mult.
#define ACC_PHANTOM_MELEE_DMG_DEF     19    // melee dealt to players: ~30% UNDER a Glitch Stalker's 27/hit (glitch = stock 60 x acc_glitch_melee_dmg_mult 0.45). User 2026-06-24 "not super lethal, 30% less than a glitch" (was 85). Stock zombie=60, our horde=45.
#define ACC_PHANTOM_SERUM_SLOW_DEF    0.7   // gait mult while inside a Phase Serum holder's aura = 30% slow (user 2026-07-11, retuned twice same day: 0.5 -> 0.6 -> 0.7; matches the boss-zap slow's unified 30%). Glitch takes 0.2 + loses its blink; the Phantom only slows - teleports keep working. Live dvar acc_phantom_serum_slow; aura radius shared via acc_phase_serum_radius.
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
#define ACC_PHANTOM_CHAIN_HOPS_DEF      4    // MAX hops per chain = one hit per player up to a full 4-player team (CAPPED to the live player count; solo = 1 hop). user 2026-06-26: 3 -> 4 so a 4-player chain reaches everyone.
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

    // FULLPROOF SPAWN ARCHITECTURE (user 2026-06-25), now DEBT-based for multi-boss rounds (user 2026-07-03).
    // Split into two halves so NOTHING can permanently stop a Phantom:
    //   round_watch      - the cheap "how many Phantoms does this round owe?" decider; on a boss round it just
    //                      ADDS that count to acc_phantom_debt (it NEVER spawns, so it can't be blocked).
    //   phantom_director - the single persistent spawner. While debt > 0 it KEEPS RETRYING the spawn (every few
    //                      seconds, across rounds), spending one Phantom of debt per successful spawn.
    // Debt only goes down on a successful spawn, so a jammed/stuck Glitch Purge (or anything else) can at most
    // DELAY a Phantom a few seconds while the actor pool is saturated - it can never drop the spawn for the rest
    // of the match (the round-7 "phantom never spawned in real games" class of bug). The purge is also
    // force-shut-down after 2 rounds (_acc_lockdown_challenge::ldc_round_cap_watch), freeing those slots regardless.
    // MULTIPLE Phantoms may be alive at once now (the one-at-a-time guard is gone) - a multi-boss round (18+) can
    // owe 2+ Phantoms, and the count comes from the shared roster (_acc_civil_protector, level.acc_boss_roster_fn).
    level.acc_phantom_debt = 0;
    level thread round_watch();
    level thread phantom_director();
}

function round_watch()
{
    level endon( "end_game" );
    if ( !isdefined( level.acc_phantom_debt ) )
        level.acc_phantom_debt = 0;
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        n = phantom_due_count( round_number );
        if ( n > 0 )
            level.acc_phantom_debt += n;   // ADD (not set) - the director spends it down; carries a stale debt over
    }
}

// How many Phantoms does THIS round owe? Master gate + the manual test path + the shared roster count. NO
// spawning and NO purge check here - whether a purge is active is irrelevant to whether Phantoms are owed.
function phantom_due_count( round_number )
{
    // Master gate for NORMAL play; the dev sandbox (level.acc_dev) bypasses it so acc_dev owes Phantoms for
    // testing without forcing acc_phantom_enable's value (user 2026-06-22, one-flag dev).
    if ( getdvarint( "acc_phantom_enable", ACC_PHANTOM_ENABLE_DEF ) != 1 && !IS_TRUE( level.acc_dev ) )
        return 0;

    // (acc_phantom_test manual opt-in removed 2026-07-16: dev runs the real roster cadence like
    // normal play - no per-feature test dvar; only acc_dev/acc_god/mock flags exist.)

    // DEV: ONE Phantom on round 3 (user 2026-07-17 "have a phantom spawn on round 3" - an early
    // eyeball spawn for the yellow de-rez burst + deep warp voice). MUST sit ABOVE the roster
    // consult: the roster owns phantom scheduling in real play and returns 0 for round 3, so a
    // branch in the cadence_hits fallback would never fire. Rounds 9/18/27 still run the real
    // roster below, dev and ship alike.
    if ( IS_TRUE( level.acc_dev ) && round_number == 3 )
        return 1;

    // UNIFIED MULTI-BOSS ROSTER (user 2026-07-03): the per-round roster (owned by
    // _acc_civil_protector, published as level.acc_boss_roster_fn) says how many of THIS round's
    // bosses are Phantoms. Round 9 = 1 boss / 18 = 2 / 27 = 3, each an independent 3-way roll
    // (Phantom / Rogue Protector / Avogadro), so this can be 0..count. Fallback to the legacy every-10
    // cadence if the pointer isn't published yet (init order between the boss modules isn't fixed).
    if ( isdefined( level.acc_boss_roster_fn ) )
        return [[ level.acc_boss_roster_fn ]]( round_number, "phantom" );
    return ( cadence_hits( round_number ) ? 1 : 0 );
}

// DEBT-based director (multi-boss safe, user 2026-07-03). Persistent for the whole match. Spends the
// Phantom debt one spawn per tick while any are owed, so a multi-boss round trickles Phantoms in a few
// seconds apart. NO one-at-a-time guard anymore - multiple Phantoms may be alive at once (same as the
// Paradise onslaught already does). Under a SATURATED actor pool stock spawn_zombie BLOCKS until a slot
// frees rather than failing, so the spawn still completes - just delayed; a spawn that does return
// undefined (cold round start) leaves the debt untouched and retries next tick. Debt can never be
// permanently suppressed, so the boss can't be silently dropped (the round-7 "never spawned" class).
function phantom_director()
{
    level endon( "end_game" );
    if ( !isdefined( level.acc_phantom_debt ) )
        level.acc_phantom_debt = 0;

    for ( ;; )
    {
        wait( getdvarint( "acc_phantom_director_period", 3 ) );

        if ( level.acc_phantom_debt <= 0 )
            continue;

        // Re-validate the master gate (it may have been toggled off after the round was marked owed).
        if ( getdvarint( "acc_phantom_enable", ACC_PHANTOM_ENABLE_DEF ) != 1 && !IS_TRUE( level.acc_dev ) )
        {
            level.acc_phantom_debt = 0;
            continue;
        }

        pdebug( "director: " + level.acc_phantom_debt + " Phantom(s) owed -> attempting spawn (round " + level.round_number + ")" );
        host = spawn_phantom( level.round_number );
        if ( isdefined( host ) && isalive( host ) )
        {
            level.acc_phantom_debt--;
            pdebug( "director: Phantom spawned -> debt " + level.acc_phantom_debt );
        }
        // else: debt unchanged -> retry next tick (the actor pool is momentarily full; never give up).
    }
}

// Legacy fallback cadence (used by phantom_due_count only if level.acc_boss_roster_fn isn't published
// yet - i.e. _acc_civil_protector::init hasn't run). Every-10 in normal play (dev every 4). The live
// rotation is the shared roster in _acc_civil_protector (boss_count/boss_roster).
function cadence_hits( round_number )
{
    // DEV fast cadence (4/4) DISABLED (user 2026-07-12: no early boss spam in dev): dev uses
    // the real 10/10 fallback. Manual override in either mode: +set acc_phantom_first_round /
    // acc_phantom_interval.
    first    = getdvarint( "acc_phantom_first_round", ACC_PHANTOM_FIRST_ROUND_DEF );
    interval = getdvarint( "acc_phantom_interval",    ACC_PHANTOM_INTERVAL_DEF );
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

// Phantom HP COMPOUNDS per round (user 2026-06-27): base * exp^(round-anchor). Phantom is the SOFTEST tier
// at exp 1.06; the unified scale shares base 65000 + anchor 5 across all bosses, differing only by exponent
// (Brutus/Panzer 1.12 > Rogue 1.09 > Phantom/Avogadro 1.06). Anchored at round 5 (user 2026-07-08: was 10 -
// "all boss scaling starts on round 5"); the roster bosses first spawn at round 9 = base x exp^4. GSC has no
// pow builtin - small integer-exponent loop (past = round - anchor). Coop player mult applied SEPARATELY at the caller.
// exp_override lets a DIFFERENT boss share this exact scale (same base 65000 + anchor 5) with its
// own per-round exponent - the Rogue Protector passes 1.09 here (user 2026-07-08: Brutus/Panzer 1.12 >
// Rogue 1.09 > Phantom 1.06). Omitted = the Phantom's own acc_phantom_hp_exp (1.06).
function scale_phantom_hp( round_number, exp_override )
{
    base   = getdvarint( "acc_phantom_hp", ACC_PHANTOM_HP );
    exp    = ( isdefined( exp_override ) ? exp_override : getdvarfloat( "acc_phantom_hp_exp", ACC_PHANTOM_HP_EXP ) );
    anchor = getdvarint( "acc_phantom_hp_anchor", ACC_PHANTOM_HP_ANCHOR );

    past = round_number - anchor;
    if ( past < 0 ) past = 0;   // before debut -> just the base

    mult = 1.0;
    for ( i = 0; i < past; i++ )
        mult = mult * exp;
    return int( base * mult );
}

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
    // NO level.acc_phantom_host anymore (user 2026-07-03 multi-boss): multiple Phantoms can be alive
    // at once. Nothing needs a single "the Phantom" handle - each runs its own cloak/teleport/death
    // threads on self, the nameplate + music are per-actor/refcounted, and callers (Paradise) capture
    // the return value directly. Concurrency is bounded by the per-round roster count (director debt).

    // ROUND scaling (scale_phantom_hp - user 2026-06-27: the Phantom did NOT scale at all before, fixed
    // 56k every round = "dies easy late"; now COMPOUNDS x1.1/round, matching zombies) THEN the
    // player mult (boss_hp_player_mult() = an explicit table, 1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60 - user
    // 2026-07-15, was 1 + 0.5*log2(n) = 1/1.5/1.79/2.0; the old LINEAR 100k*pc -> 400k at 4p was "crazy",
    // and 2.60 stays well under that). Tune live: acc_phantom_hp_exp / acc_boss_coop_hp_2p|_3p|_4p.
    // Written AFTER the init-gate (stock clobbers HP).
    host.maxhealth = int( scale_phantom_hp( round_number ) * acc_coop_scaling::boss_hp_player_mult() );
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

    // [acc] PARADISE/DEEP-TRENCH MELEE FIX (Paradise boss audit, user 2026-07-09): the host spawns
    // TOPSIDE at a normal spawner, then BLINKS to players. When the players are BELOW every
    // player_volume (Paradise z=-1200 / deep trench), the host warps down before ever touching a
    // volume -> completed_emerging_into_playable_area never sets -> the stock BT's melee branch never
    // unlocks (_zm_behavior.gsc:1118 inPlayableArea) -> the Phantom stalks + stands in your face but
    // NEVER swings (only the chain-special's direct DoDamage landed). Same lockout + same fix as the
    // trench surge zombies (tag_trench_zombie); no-op when the flag is already set topside.
    host thread acc_bus_trench::force_playable_emergence();

    // MULTI-PLAYER MELEE FIX (user 2026-06-26): force the stock AI to target whoever the Phantom LAST warped
    // onto, so its melee lands on EACH player it strikes - not just one acquired enemy. Without this the stock
    // AI held a single self.enemy and the blinks to other players never connected a swing -> "Phantom only
    // damages one player even with 4". Stock get_closest_valid_player consults this per-AI override
    // (_zm_utility.gsc:1474) to derive BOTH self.favoriteenemy (movement) and self.enemy (melee). Same proven
    // mechanism the Glitch Stalker uses; the target is updated every blink in phantom_blink_to.
    host.closest_player_override = &phantom_pick_target_override;

    // Canvas: TOXIC SKIN (user 2026-07-02; was the stock Giant body) - WetEgg's SAT toxic body
    // variant 2 (the Glitch wears variant 1; same pack, EC-style model-only lift). The Phantom is
    // cloaked most of the time, so the body is just the brief-materialize silhouette. The toxic
    // body INCLUDES its head - Detach the charred head, attach nothing. Same live-actor SetModel
    // idiom as the Glitch Stalker. Zone: xmodel,c_sat_zmb_zombie_toxic_2. NO SetScale.
    if ( getdvarint( "acc_phantom_stock_skin", 1 ) == 1 )
    {
        host SetModel( "c_sat_zmb_zombie_toxic_2" );
        host Detach( "c_zom_dlc4_zombie_charred_head" );
        // gib_data.head left as-is: the toxic head is part of the body model.
    }

    // NEON YELLOW aura (user 2026-07-02, toxic-skin re-theme; was dark purple 2026-06-24): the
    // Phantom KEEPS its materialize-glow but in neon yellow - clientfield value 3 (new), so the
    // Subroutine Core (which shares this field and defaults to colour 1) stays dark purple.
    // FX map lives in _acc_boss_phantom.csc::aura_cb.
    host.acc_aura_color = 3;

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
// via ent.acc_aura_color (2026-07-02 map): 1 = dark purple (Subroutine Core - the default, it never
// sets a colour) / 2 = dimmed magenta (unused - ex-Glitch) / 3 = NEON YELLOW (the Phantom sets 3 at
// setup). The .csc maps the value to the matching FX - all consumers share this one field.
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
    // [acc] 2026-07-17: the Phantom's OWN voice - acc_phantom_warp = the same warp wav pitched
    // DOWN 3.5-5 semitones + louder + longer range (acc_audio.csv). It no longer borrows the
    // Glitch's alias, so the two bosses are sonically distinct: high warp = Glitch, deep = Phantom.
    ent PlaySound( "acc_phantom_warp" );
}

// Departure-side warp SFX with its own 0.8s cooldown (review 2026-07-17): chain hops warp
// back-to-back (~0.7-1.1s dwell, up to 4 hops) and the pitched-down wav plays ~25% LONGER than
// the source, so ungated departures stack into mud - the alias row ships no LimitCount, nothing
// engine-side caps it. Emitter life 3s (the wav is short) instead of play_sound_at_origin's 12s
// jingle default, so a phantom at warp cadence holds ~1 emitter, not 6 (see acc_emitter_cleanup).
function phantom_warp_snd( ent )
{
    if ( !isdefined( ent ) ) return;
    if ( getdvarint( "acc_phantom_warp_snd", 1 ) == 0 ) return;
    now = GetTime();
    if ( isdefined( ent.acc_phantom_last_warp_snd ) && ( now - ent.acc_phantom_last_warp_snd ) < 800 )
        return;
    ent.acc_phantom_last_warp_snd = now;
    acc_utility::play_sound_at_origin( ent.origin, "acc_phantom_warp", 3 );
}

// Drive the gait every sweep (the global keep-alive skips mini-bosses). Clone of
// glitch_speed_think. NEVER rate < 1.0 (no slow-mo) - sole exception: the Phase Serum
// aura's deliberate 30% slow below. NO SetScale.
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
        // PHASE SERUM aura (user 2026-07-11): 30% gait slow near a serum holder - the Glitch concept
        // (acc_serum_suppressed) but a MILDER penalty (glitch = 1/5 + no blink; Phantom keeps its
        // teleports, only the run slows). The deliberate exception to "never rate < 1.0".
        if ( acc_utility::serum_aura_active( self.origin ) )
            rate = rate * getdvarfloat( "acc_phantom_serum_slow", ACC_PHANTOM_SERUM_SLOW_DEF );
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
        // (-25% slow + SFX; Mega Electric Cherry softens it to -10%, no longer full immunity - user 2026-07-03).
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
        // so the speed effect is testable while invulnerable. Mega Electric Cherry now SOFTENS the stun to -10%
        // (not full immunity) inside acc_phantom_chain_zap. acc_phantom_slow_sec / acc_phantom_speed_mult tune the feel.
        if ( isdefined( target ) && isalive( target ) &&
             DistanceSquared( self.origin, target.origin ) <= ( 160 * 160 ) )
        {
            target acc_elites::acc_phantom_chain_zap();
            // CHAIN HIT, dealt DIRECTLY (user 2026-06-26 "saps everyone, only damages one"): the rapid hops
            // never let the stock AI swing, so the chain SAPPED each player but only the AI's one enemy took
            // damage. Apply the per-hop melee hit ourselves as MOD_MELEE - the SAME means-of-death the stock
            // zombie melee uses, so Jugg / Exo resist / trench melee scaling / downing all apply normally
            // (_acc_elites::on_player_damaged handles it). Now the chain damages EACH player it warps onto.
            target DoDamage( getdvarint( "acc_phantom_melee_dmg", ACC_PHANTOM_MELEE_DMG_DEF ), self.origin, self, self, 0, "MOD_MELEE" );
        }

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
            // [acc] 4p guard (2026-07-06 sweep, found by two independent reviews): hit[] holds raw
            // player refs across the per-hop dwell wait; a struck player disconnecting between hops
            // leaves an undefined entry and `entity == undefined` THROWS on the next hop.
            if ( isdefined( hit[ j ] ) && live[ i ] == hit[ j ] ) { already = true; break; }
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
    self.acc_phantom_target = target;   // lock the stock AI's melee/movement onto whoever we warp onto (multi-player fix; read by phantom_pick_target_override)
    strike = GetClosestPointOnNavMesh( phantom_strike_point( self.origin, target.origin ), 100, 30 );
    if ( !isdefined( strike ) )
        strike = GetClosestPointOnNavMesh( target.origin, 140, 50 );
    if ( !isdefined( strike ) ) return;
    // [acc] de-rez burst at both ends of the warp (docs/44 workstream A) - fires on the normal
    // strike AND every chain hop (this fn is the shared warp primitive). The departure burst is
    // deliberate even while cloaked: it telegraphs "incoming" without showing WHERE, arrival + screech do.
    // "phantom" style = NEON-YELLOW numbers (matches its aura) + sparks layer; departure spot also gets
    // the deep pitched-down warp SFX as a STATIC emitter (play_sound_at_origin - a self PlaySound would
    // teleport WITH the boss, collapsing both ends into one sound at the arrival).
    phantom_warp_snd( self );
    acc_utility::derez_burst( self.origin, "phantom" );
    self forceteleport( strike );
    acc_utility::derez_burst( self.origin, "phantom" );
    // [acc] audio pass 2 (user 2026-07-17 "can't really hear the teleport"): the ARRIVAL is the
    // near-player moment, so it plays UNCONDITIONALLY on the boss ent every warp - it was riding
    // materialize_scare's 1.2s cooldown, which silently ate chain-hop arrivals. materialize_scare
    // stays for the cloak-reveal path only (same voice, so reveals + warps still sound identical).
    if ( getdvarint( "acc_phantom_warp_snd", 1 ) != 0 )
        self PlaySound( "acc_phantom_warp" );
}

// Hit-and-run back-off after a NORMAL strike: warp away from the struck player so the Phantom never camps (the
// cloak loop re-hides it at range). Skipped if acc_phantom_retreat is off.
function phantom_back_off( target )
{
    if ( !isdefined( target ) ) return;
    if ( getdvarint( "acc_phantom_retreat", ACC_PHANTOM_RETREAT_DEF ) != 1 ) return;
    retreat = GetClosestPointOnNavMesh( phantom_retreat_point( target.origin ), 160, 50 );
    if ( isdefined( retreat ) )
    {
        // [acc] de-rez the hit-and-run exit too (docs/44) - departure burst + warp SFX only. No
        // arrival burst: the retreat point is where it re-cloaks, and marking it would hand the
        // player a free tracking beacon on a boss whose identity is "you lost it".
        phantom_warp_snd( self );
        acc_utility::derez_burst( self.origin, "phantom" );
        self forceteleport( retreat );
    }
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

// Per-AI melee/movement target override (host.closest_player_override). Stock contract
// (_zm_utility.gsc:1474): called as [[ self.closest_player_override ]]( origin, players ) with NO self prefix
// (ambient self = the Phantom); stock uses the return to set BOTH self.favoriteenemy (movement) and
// self.enemy (melee). We return the CURRENT blink target (set every blink in phantom_blink_to) so the AI
// chases + swings at whoever the Phantom just warped onto, rotating across the whole team instead of meleeing
// one stale enemy. THE fix for "Phantom only damages one player" (user 2026-06-26). Before the first blink /
// if the target invalidates (downed/disconnected), fall back to the map-wide path-distance picker, then closest.
function phantom_pick_target_override( origin, players )
{
    if ( !isdefined( players ) || players.size == 0 )
        return undefined;
    // CRITICAL: only ever return a player ALREADY in the passed-in `players` array. Stock get_closest_valid_player
    // pre-culls `players` to am_i_valid entries (which INCLUDES the .ignoreme flag), then loops re-checking the
    // returned player WITH NO WAIT, ArrayRemoveValue-ing it if invalid. Returning a player stock had culled (e.g. a
    // teammate cloaked via Cyberware Ghost Protocol -> zm_utility::increment_ignoreme, still alive+standing so
    // is_player_alive() passes) makes that ArrayRemoveValue a no-op, players.size never reaches 0, and we'd hand
    // back the same player forever => infinite loop = SERVER HANG in co-op. Membership-check t against `players`
    // (mirrors the Glitch Stalker override) so the return is always a valid, in-set player.
    t = self.acc_phantom_target;
    if ( isdefined( t ) )
    {
        for ( i = 0; i < players.size; i++ )
            if ( players[ i ] == t )
                return t;
    }
    if ( isdefined( level.closest_player_override ) )
        return [[ level.closest_player_override ]]( origin, players );
    return arraygetclosest( origin, players );
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

    // [acc] 4p guard (2026-07-06 sweep): the isdefined(self) below acknowledges the corpse can be
    // gone right after the death notify - but drop_origin then deref'd self.origin unguarded anyway.
    // Bail entirely: a throw here ends the whole match; a skipped reward on an already-reaped corpse
    // does not.
    if ( !isdefined( self ) )
        return;

    self Show();                                  // un-cloak so the corpse renders
    self clientfield::set( "accPhantomAura", 0 ); // kill the glow aura (cloak loop endon'd on death)

    // (No one-at-a-time guard ref to clear anymore - the debt-based director owns spawn accounting, and
    // multiple Phantoms may be alive at once, user 2026-07-03 multi-boss.)

    drop_origin = self.origin;

    // Phantom reward (user 2026-06-22): GUARANTEED full set - 1 item drop + 1 Mega Bottle to every player +
    // a ROUND-SCALED payout to EVERY player (user 2026-06-29): round x 500 points + round x 1 Data Shards
    // (round 10 = 5,000 points + 10 shards; round 20 = 10,000 + 20; scales with the round the Phantom is killed on).
    // SUPPRESSED during the Paradise onslaught (user 2026-06-27 + 2026-06-29 audit): the finale is a SURVIVE-
    // don't-farm gauntlet with up to 4 Phantoms cycling, so a per-kill payout would break it. The WHOLE block
    // sits behind the !acc_paradise_onslaught gate -> Paradise-fight Phantoms grant NONE of this (points/shards/item).
    // Mirrors the onslaught's block_powerup_drop + the reward-free Paradise Brutus path (host.acc_no_shard_reward).
    // Shared boss reward (user 2026-07-05: every boss identical) - 1 item + 1 bottle + round*300 pts +
    // int(round/3) shards, to every player. Paradise-suppression is handled inside the shared fn.
    acc_boss::grant_unified_boss_reward( drop_origin );

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
    if ( !IS_TRUE( level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5[phantom] ^7" + msg );
    }
}
