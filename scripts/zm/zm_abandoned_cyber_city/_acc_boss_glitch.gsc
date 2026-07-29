// =============================================================================
// _acc_boss_glitch.gsc - "Glitch Stalker" mini-boss (script-only, zero assets)
//
// Design: docs/08_enemies.md ("Glitch Stalker"). A MOBILE mini-boss - the map's
// first boss that is neither pinned (Subroutine Core) nor a straight charger
// (Brutus). It is a PROMOTED STOCK ZOMBIE (same scaffold as spawn_subroutine_core
// in _acc_boss.gsc) so it needs NO new model/anim/FX assets and a fresh clone
// still links. Its signature: every few seconds it short-range TELEPORT-BLINKS to
// flank the nearest player, and for a short RECOVERY window right after each blink
// it takes BONUS DAMAGE (punish the blink). The blink reuses the exact, already
// VERIFIED(acc) teleport path the Teleporter elite uses (_acc_elites.gsc:246-275:
// GetClosestPointOnNavMesh then forceteleport - clamp to navmesh first so it never
// lands in geometry).
//
// FULLY SELF-CONTAINED + DECOUPLED: this module owns its own cadence (it listens to
// "acc_round_start" like the panzer test loop), spawn, promotion, ability, and
// death->reward. _acc_boss.gsc is NOT edited. To disable the whole boss live:
// `acc_glitch_enable 0`. To trace it: use a dev build (debug prints ride level.acc_dev;
// the acc_glitch_debug dvar was removed 2026-07-16). Every stat is an
// `acc_glitch_*` dvar read LIVE (no rebuild to tune) - see docs/22_flags_reference.md.
//
// CRASH-SAFETY (deliberate, see docs/08 + CLAUDE.md hard-won facts):
//   - NO SetScale (the confirmed 0xC0000005 live-AI crasher) and NO independent
//     ASMSetAnimationRate writer (the global _acc_zombie_speed keep-alive already
//     drives this actor's speed every sweep - a second writer would fight it).
//     The boss inherits the round speed curve; the BLINK is its mobility, not raw
//     speed. So there is nothing here that can reintroduce a known crash.
//   - Spawn is INIT-GATED (stock zombie_spawn_init clobbers health at frame end).
//   - ignore_enemy_count = true: it fights ALONGSIDE the wave and never gates round
//     end / starves the 24-AI budget, so a bugged fight can never soft-lock a round.
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;   // grant_player (1 shard to the glitch killer)
#using scripts\zm\zm_abandoned_cyber_city\_acc_leveling;      // mini-boss kill XP (docs/45)
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;   // (aura call removed 2026-07-02 - kept for shared phantom helpers/history)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;   // 3D over-head name + health bar (user 2026-07-02)
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;       // force_playable_emergence (unlock stock melee below player_volumes - Paradise/deep trench)

#insert scripts\shared\shared.gsh;

// --- Tunable defaults. EVERY one is overridable live via the matching acc_glitch_*
//     dvar (read at the point of use, not cached) - this is the whole "easy slider"
//     contract. Mirror each row in docs/22_flags_reference.md. ---
#define ACC_GLITCH_ENABLE_DEF            1      // master on/off (set 0 to disable the boss entirely - gates real cadence + test spawn)
#define ACC_GLITCH_HP_MULT_DEF              1.5 // HP = this x the round's NORMAL zombie health (user 2026-06-23: 3 -> 1.5, 3x too tanky)
#define ACC_GLITCH_FIRST_ROUND_DEF          6   // first round it spawns (user 2026-06-23: 2->8->4; 2026-07-15: 4->6 - CODIFIES REALITY, see below)
// ^ WHY 6 (user 2026-07-15, "I actually like the first round being 6"): r4 NEVER produced a Stalker.
// The frame-0 spawn refusal (see run_glitch_wave) ate the first spawn of every wave, and r4's count was
// exactly 1, so r4 delivered ZERO for the module's entire life while r6 delivered 1. "First glitch at
// round 6" IS the shipped game the user has been playing; setting first_round=6 makes the CODE honest
// about that rather than changing the feel. The spawn fix would otherwise have silently ADDED a brand
// new r4 Stalker that no one ever play-tested.
#define ACC_GLITCH_INTERVAL_DEF             2   // every 2nd round from first (user 2026-06-23: was EVERY round, 4, now 2) - count scales, see glitch_count_for_round
#define ACC_GLITCH_TEST_ROUND_DEF           2   // dev/test path: first round it spawns (matches first_round, user 2026-06-22)
#define ACC_GLITCH_BLINK_CD_MIN_DEF         1.55 // min seconds between blinks (user 2026-07-17: 1.77->1.55, cut the 07-16 pass in half - "too passive now"; 2026-07-16: 1.33->1.77; 2026-06-23: 1.0->1.33)
#define ACC_GLITCH_BLINK_CD_MAX_DEF         2.59 // max seconds between blinks (user 2026-07-17: 2.96->2.59, cut the 07-16 pass in half; 2026-07-16: 2.22->2.96; 2026-06-23: 1.665->2.22)
#define ACC_GLITCH_BLINK_DIST_DEF         300   // flank offset (units) from the target
#define ACC_GLITCH_RECOVERY_SEC_DEF         1.2 // post-blink vulnerability window (s) (was 1.5; the window now ALSO only fires on a real flank blink, never on a commit/pounce - see glitch_blink_loop)
#define ACC_GLITCH_RECOVERY_DMG_MULT_DEF    2.0 // damage multiplier while vulnerable (damage IT takes - not the damage it deals)
#define ACC_GLITCH_MELEE_DMG_MULT_DEF       0.45 // melee damage DEALT to players vs a stock zombie (user 2026-06-22: 25% less than the prior 0.6 -> 0.45)
#define ACC_GLITCH_SPEED_MULT_DEF           1.005 // anim rate vs the round's normal zombies - ONE lever drives BOTH chase speed AND melee-swing speed (ASMSetAnimationRate scales the whole state machine). 1.005 (user 2026-07-17: 0.86 -> 1.005, cut the 07-16 -25% pass in half - "too passive now"; now ~horde speed, the BLINK is its mobility; 2026-07-16: 1.15 -> 0.86, x0.75 "they swing too fast" fix). Was +15% (2026-06-15).
#define ACC_GLITCH_COUNT_DEF                3   // bosses spawned per scheduled round (acc_glitch_count, user 2026-06-17) - UNUSED, superseded by glitch_count_for_round
#define ACC_GLITCH_SPAWN_STAGGER_DEF        1.5 // seconds between Stalker spawns AND before the FIRST one. The "before the first" part is load-bearing: spawning on frame 0 of the round FAILS (see run_glitch_wave). Live dvar acc_glitch_spawn_stagger.
#define ACC_GLITCH_SPAWN_RETRIES            3   // attempts per Stalker before giving up. A single SpawnFromSpawner refusal used to silently cost a whole Stalker (user-verified 2026-07-15).
#define ACC_GLITCH_COUNT_LOG_K              2.0 // count curve: int(k*log2(round) - c), k=2.0 (user 2026-07-15, replaced LINEAR (round-2)/2). Live dvar acc_glitch_count_log_k.
#define ACC_GLITCH_COUNT_LOG_C              4.0 // count curve offset; c=4.0 anchors r6 -> 1 = the DELIVERED count the user actually played (user 2026-07-15: was 3.0, which anchored to NOMINAL counts that the frame-0 bug never delivered). Live dvar acc_glitch_count_log_c.

// Subroutine Core full-boss cadence (mirror of _acc_boss.gsc ACC_BOSS_FULL_* ) - the
// Glitch Stalker yields on these rounds so it never piles onto the sealed Core fight.
#define ACC_GLITCH_FULLBOSS_FIRST          30
#define ACC_GLITCH_FULLBOSS_INTERVAL       10

#define ACC_GLITCH_DISPLAY_NAME "GLITCH STALKER"

#namespace acc_boss_glitch;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "boss_glitch: init (Glitch Stalker, mobile blink mini-boss, script-only)" );
    level thread round_watch();
}

// Single cadence driver. Owns its own round subscription so _acc_boss.gsc needs no
// edit; every spawn decision is one thread so a slow spawn can't stall the loop.
function round_watch()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        level thread maybe_spawn_for_round( round_number );
    }
}

// Decide + (maybe) spawn for this round. All gates are LIVE dvar reads so a console
// set takes effect on the very next round with no rebuild.
function maybe_spawn_for_round( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    // Master gate: acc_glitch_enable 0 disables the boss ENTIRELY (real + test).
    if ( getdvarint( "acc_glitch_enable", ACC_GLITCH_ENABLE_DEF ) != 1 )
        return;

    // A lockdown CHALLENGE (set by _acc_lockdown_challenge) owns the shared actor budget for
    // its sealed room. Suppress the scheduled glitch wave while one is active so the two
    // glitch waves don't stack on the engine actor cap. Undefined in normal play -> no effect.
    if ( isdefined( level.acc_ldc_active ) )
        return;

    // (Test-spawn lever removed 2026-07-16: dev runs the real boss cadence like every other boss -
    // no separate acc_glitch_test opt-in. Only acc_dev/acc_god/mock flags exist.)
    if ( !cadence_hits( round_number ) )
        return;
    // (Subroutine Core removed 2026-06-22 - no full-boss round to yield to, so the Stalker spawns every round.)

    run_glitch_wave( round_number );
}

// self = the boss. Drive its anim rate off the horde's round curve. Zombie movement is
// anim-driven (the same lever the horde's _acc_zombie_speed uses), so we lock the SAME gait
// the horde is on this round (acc_zombie_speed::tier_for_round) and set the anim playback rate
// to acc_glitch_speed_mult x the horde's rate (acc_zombie_speed::rate_for_round). The rate also
// scales its melee-SWING speed (whole-ASM playback), which is why the mult is now 1.005 - about
// the SAME as the horde (user 2026-07-17 cut the 07-16 "they swing too fast" pass in half; the blink is its mobility).
// We flag self.acc_boss_custom_speed so the global
// _acc_zombie_speed keep-alive SKIPS this actor (else the two writers fight -> speed flicker).
// Re-asserted on a cadence because round/state changes can clobber the gait override.
function glitch_speed_think()
{
    self endon( "death" );
    level endon( "end_game" );

    self.acc_boss_custom_speed = true; // _acc_zombie_speed keep-alive skips us

    for ( ;; )
    {
        if ( !isalive( self ) ) return;

        r    = acc_zombie_speed::current_round();
        mult = getdvarfloat( "acc_glitch_speed_mult", ACC_GLITCH_SPEED_MULT_DEF );
        rate = acc_zombie_speed::rate_for_round( r ) * mult;
        if ( rate < 0.1 ) rate = 0.1;
        if ( self acc_serum_suppressed() )   // Phase Serum aura: 0.36x speed (user 2026-07-22: the 0.2 "basically freezes glitches" - slow strength -20%, 80% -> 64% slow; was 1/5 from the 2026-06-29 nerf)
            rate = rate * getdvarfloat( "acc_phase_serum_slow", 0.36 );

        self zombie_utility::set_zombie_run_cycle_override_value( acc_zombie_speed::tier_for_round( r ) );
        self ASMSetAnimationRate( rate );
        wait 1;
    }
}

// PHASE SERUM suppression (user 2026-06-29): true if any alive player within acc_phase_serum_radius holds the
// Phase Serum. A Glitch Stalker in that aura is slowed to 0.36x speed (glitch_speed_think; user 2026-07-22,
// was 1/5) AND skips its blink / glitch ability (glitch_blink_loop) - "nullified" but still able to see +
// chase. self = the Stalker.
function acc_serum_suppressed()
{
    // Body lifted to acc_utility::serum_aura_active (2026-07-11) so the Phantom shares the
    // aura check (its 50% gait slow) without a circular #using (we already #using phantom).
    return acc_utility::serum_aura_active( self.origin );
}

// Spawn `acc_glitch_count` Glitch Stalkers this round, staggered a beat apart for
// co-op spawn safety (mirrors run_mini_boss in _acc_boss.gsc). NO inbound banner
// (user 2026-06-23: the "GLITCH STALKER inbound" IPrintLnBold was removed in BOTH normal
// and dev - the Stalkers just arrive; the magenta aura + stock Giant skin are the only tells).
function run_glitch_wave( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    count = glitch_count_for_round( round_number );

    for ( i = 0; i < count; i++ )
    {
        // STAGGER FIRST, SPAWN SECOND (fixed 2026-07-15, verified in game via the [CNT] probes).
        // This wait used to sit AFTER spawn_glitch, so the FIRST Stalker of EVERY wave was
        // attempted on frame 0 of the round - the same frame stock threads
        // [[level.round_spawn_func]] (_zm.gsc:4431, one line before "start_of_round") - and
        // SpawnFromSpawner refuses there, so stock spawn_zombie returned undefined
        // (zombie_utility.gsc:1469-1482). That silently cost one Stalker on EVERY glitch round;
        // at r4 count==1, so the entire wave WAS that lost spawn -> ZERO Stalkers at r4, ever
        // (user: "I never see a glitch on round 4" - correct, and this was why).
        // PROOF the delay is the fix, not the spawner: in the SAME round-4 log, the Shielded
        // elites spawned fine from the SAME single spawner - _acc_elites::spawn_elites_over_round
        // waits at the TOP of its loop, so its first spawn lands 3s in, never on frame 0. The
        // test path's `wait 5; // let the round get going` was this same workaround, applied
        // only there. Retry backstop lives in spawn_promoted_zombie.
        wait( getdvarfloat( "acc_glitch_spawn_stagger", ACC_GLITCH_SPAWN_STAGGER_DEF ) );
        spawn_glitch( round_number );
    }
}

// True on the rounds the Glitch Stalker is scheduled. `(round - first) % interval`
// (not `round % interval`) so `first` can be ANY value, e.g. first 12 -> 12, 22, 32.
function cadence_hits( round_number )
{
    // DEV: a wave EVERY round from round 1 (user 2026-07-17 - supersedes 2026-07-12's "no early
    // boss spam in dev"; the de-rez blink FX/SFX pass needs on-demand Stalkers to eyeball).
    // Count is dev-pinned to 2 in glitch_count_for_round.
    if ( IS_TRUE( level.acc_dev ) ) return true;

    first    = getdvarint( "acc_glitch_first_round", ACC_GLITCH_FIRST_ROUND_DEF );
    interval = getdvarint( "acc_glitch_interval", ACC_GLITCH_INTERVAL_DEF );
    if ( interval < 1 ) interval = 1; // guard a bad slider (avoid mod-by-zero)

    if ( round_number < first ) return false;
    return ( ( round_number - first ) % interval ) == 0;
}

// How many Glitch Stalkers spawn this round. LOG IN ROUND x LOG IN PLAYERS (user 2026-07-15).
//
//   count = max( 1, int( k*log2(round) - c ) )  x  acc_coop_scaling::elite_count_player_mult()
//   k = acc_glitch_count_log_k (2.0), c = acc_glitch_count_log_c (4.0)
//
// Replaces the LINEAR floor((round-2)/2) (user 2026-06-23), which grew forever: r30 = 14, r50 = 24
// Glitch Stalkers - and that was the PLAYER-BLIND count, identical solo and 4p.
//
// ANCHORED TO *DELIVERED* COUNTS, NOT NOMINAL ONES (user 2026-07-15, re-anchored after the frame-0
// spawn bug was found). This curve's first version used c=3.0 to match the old formula's r4/r6/r8 =
// 1/2/3 - but that bug ate the first spawn of EVERY wave, so what the game actually PRODUCED was
// 0/1/2. Matching the nominal numbers would have silently made every glitch round +1 harder than
// anything ever play-tested. c=4.0 + first_round=6 anchors r6 -> 1 and r8 -> 2: exactly what the user
// has been playing, now delivered honestly instead of by accident. Lesson: after fixing a spawn bug,
// re-tune against MEASURED counts - a formula's output was never evidence of what reached the world.
//
// The two logs COMPOUND (4p doubles the round term), which is WHY the round term must stay flat late:
// the rejected linear-round x log-player design hit 78 elites at r40 4p vs ACC_AI_LIMIT 50 - an
// elites-only wave with normal zombies starved out of the actor budget.
//
// acc_utility::acc_log2 exists because GSC HAS NO log BUILTIN and round is unbounded (the player mult
// dodges it with a 3-literal switch - only 1..4 are legal there). Both k and c are live dvars.
// acc_glitch_count is still unused (superseded).
function glitch_count_for_round( round_number )
{
    // DEV: exactly 2 per round, curve + coop mult SKIPPED (user 2026-07-17 "2 glitches spawn
    // every round when dev mode is enabled") - deterministic count for FX eyeballing. Sits above
    // the round<2 early-return so dev round 1 also delivers 2.
    if ( IS_TRUE( level.acc_dev ) ) return 2;

    if ( !isdefined( round_number ) || round_number < 2 ) return 1;

    k = getdvarfloat( "acc_glitch_count_log_k", ACC_GLITCH_COUNT_LOG_K );
    c = getdvarfloat( "acc_glitch_count_log_c", ACC_GLITCH_COUNT_LOG_C );

    n = int( ( k * acc_utility::acc_log2( round_number ) ) - c );
    if ( n < 1 ) n = 1;   // floor BEFORE the player mult so 1p never drops below one Stalker

    n = int( n * acc_coop_scaling::elite_count_player_mult() );
    if ( n < 1 ) n = 1;
    return n;
}

// Mirror of _acc_boss.gsc's full-boss cadence so the Glitch Stalker yields the round
// to the Subroutine Core (sealed-room fight) even if the user retunes its dvars to
// collide. Kept as literals to avoid a #using on _acc_boss just for two constants.
function is_full_boss_round( round_number )
{
    return ( round_number >= ACC_GLITCH_FULLBOSS_FIRST
             && ( round_number % ACC_GLITCH_FULLBOSS_INTERVAL ) == 0 );
}

// ---------------------------------------------------------------------------
// Spawn + promote
// ---------------------------------------------------------------------------

// Spawn one Glitch Stalker and layer our systems on top.
function spawn_glitch( round_number )
{
    host = spawn_promoted_zombie();
    if ( !isdefined( host ) || !isalive( host ) )
    {
        acc_utility::log( "boss_glitch: spawn failed (no host)" );
        return;
    }

    // Mini-boss tier: drives the 2.0 boss headshot multiplier (acc_is_mini_boss read in
    // _acc_damage.gsc:661/:668).
    host.acc_is_mini_boss = true;

    // Mark as a GLITCH zombie so the Cyberware Weapon Overclock's Glitch Piercing effect does bonus
    // damage here (read in _acc_damage). Covers the standalone Glitch Stalker AND the lockdown-challenge
    // glitch zombies (they are Glitch Stalker hosts spawned through this same path).
    host.acc_is_glitch_zombie = true;

    // HP = acc_glitch_hp_mult x the round's NORMAL zombie health (user 2026-06-23, default 1.5x; was 3x).
    // Read host.maxhealth, NOT level.zombie_health (fixed 2026-07-15): spawn_promoted_zombie() returns
    // only AFTER the init gate, so host.maxhealth is the round HP WITH acc_coop_scaling's regular_hp_mult()
    // (+20%/extra player) already baked in by the level.zombie_init_done hook. level.zombie_health is the
    // SOLO value and NEVER carries that mult, so reading it made a 4p Stalker 1.5x a SOLO zombie = 0.94x a
    // 4p zombie - SOFTER than the trash it spawns among. The old comment here asserted "the actor's post-init
    // maxhealth equals it", which stopped being true when the co-op HP hook landed (2026-06-12) and is the
    // reason this went unnoticed: at 1p regular_hp_mult() is exactly 1.0, so the two are identical in every
    // solo test. A FLAT multiply on the post-init base keeps it a clean 1.5x a normal zombie at ANY player
    // count - the same contract the Shielded elite uses (_acc_elites.gsc:311-318). Do NOT multiply
    // special_hp_mult() on top: that DOUBLE-counts co-op (_acc_coop_scaling.gsc:99-106).
    // Ordering note: host.acc_is_mini_boss is set ABOVE but AFTER spawn_promoted_zombie() returned, so the
    // init hook still saw a regular zombie and applied the mult (it skips acc_is_mini_boss - coop:172).
    // Written AFTER the init-gate so stock zombie_spawn_init can't clobber it. Live-tunable, no rebuild.
    mult = getdvarfloat( "acc_glitch_hp_mult", ACC_GLITCH_HP_MULT_DEF );  // float so fractional mults (1.5) work
    if ( mult < 1.0 ) mult = 1.0;
    normal_hp = ( isdefined( host.maxhealth ) ? host.maxhealth : level.zombie_health );
    if ( !isdefined( normal_hp ) || normal_hp < 1 ) normal_hp = 100;
    host.maxhealth = int( normal_hp * mult );
    host.health = host.maxhealth;

    // Melee damage DEALT to players: HALVED (user 2026-06-15, default 0.5x). Stock
    // zombie_spawn_init sets self.meleeDamage = 60 (_zm_spawner.gsc:358) and the factory
    // melee swing does player DoDamage( self.meleeDamage, ..., "MOD_MELEE" )
    // (shared/ai/zombie.gsc:402), so scaling this one field directly cuts what the boss
    // hits for. Written AFTER the init-gate (like maxhealth above) - zombie_init_done is
    // set at _zm_spawner.gsc:389, LATER than meleeDamage:358, so stock init can't clobber
    // this. Live-tunable via acc_glitch_melee_dmg_mult, no rebuild.
    melee_mult = getdvarfloat( "acc_glitch_melee_dmg_mult", ACC_GLITCH_MELEE_DMG_MULT_DEF );
    if ( melee_mult < 0 ) melee_mult = 0;
    base_melee = ( isdefined( host.meleeDamage ) ? host.meleeDamage : 60 );
    host.meleeDamage = int( base_melee * melee_mult );
    if ( host.meleeDamage < 1 ) host.meleeDamage = 1;

    // Durability: a mobile boss that fights alongside the wave. It MOVES, so it is
    // never failsafe-culled and must NOT be pinned (no ignore_round_spawn_failsafe).
    host DisableAimAssist();
    host.disableAmmoDrop = true;
    host.no_gib = true;
    host.ignore_nuke = true;
    // Runs alongside the wave; never gates round end or eats the 24-AI budget, so a
    // bugged fight can't soft-lock the round (the deliberate-safe choice, like Brutus).
    host.ignore_enemy_count = true;

    // [acc] PARADISE/DEEP-TRENCH MELEE FIX (Paradise boss audit, user 2026-07-09): same lockout as the
    // Phantom - the host spawns TOPSIDE and its blink can take it below every player_volume (the Paradise
    // specials wave at z=-1200) before it ever touches one, so completed_emerging_into_playable_area never
    // sets and the stock BT melee branch never unlocks: it blinks onto you but never swings. Same fix as
    // the trench surge zombies (tag_trench_zombie); no-op when the flag is already set topside.
    host thread acc_bus_trench::force_playable_emergence();

    // TOXIC SKIN (user 2026-07-02; was the stock Giant body 2026-06-15): the Glitch now wears
    // WetEgg's SAT toxic zombie body (c_sat_zmb_zombie_toxic_1 - EC-style machine-only lift, see
    // tools/external_assets_manifest.ps1 "SAT Toxic Zombies"; the pack's AI system is NOT installed).
    // Same live-actor SetModel idiom as before (nsz_brutus.gsc:668). The toxic body INCLUDES its
    // head ("head" is empty in its character GDT entry), so we Detach the engine-attached charred
    // head and attach NOTHING (attaching a stock head would double-head it). Detach of a
    // not-attached model is a safe no-op. Toxic bodies ride the shared 'base' zombie skeleton
    // (WetEgg port, stock zombie xanims drive it - docs/35 lane). Zone: xmodel,c_sat_zmb_zombie_toxic_1.
    // Toggle with acc_glitch_stock_skin 0. NO SetScale (the confirmed live-AI 0xC0000005 crasher).
    if ( getdvarint( "acc_glitch_stock_skin", 1 ) == 1 )
    {
        host SetModel( "c_sat_zmb_zombie_toxic_1" );      // WetEgg toxic body (head included)
        host Detach( "c_zom_dlc4_zombie_charred_head" );  // remove the charred head the archetype attached
        // gib_data.head left as-is: the toxic head is part of the body model and no_gib is true.
    }

    // TEAL EYES (user 2026-06-17): mark the boss for the client-side eyeball recolour so its eyes
    // read teal vs the charred horde's - NO FX asset (the eye COLOUR is set via mapshaderconstant
    // on the client, see _acc_lui.csc eye_tint_cb). Colour + luminance are LIVE-tunable via
    // acc_glitch_eye_color / acc_glitch_eye_lum. Gated by acc_glitch_teal_eyes (default on).
    if ( getdvarint( "acc_glitch_teal_eyes", 1 ) == 1 )
        acc_lui::set_actor_eye_tint( host, true );

    // AURA REMOVED (user 2026-07-02, toxic-skin re-theme): the Glitch now has NO body glow - the
    // TOXIC SKIN itself (vs the charred horde) is the visual tell, replacing the 2026-06-24 dimmed
    // magenta aura (which existed because the old stock-Giant skin washed out under the dark vision
    // grade). Teal eyes stay. The accPhantomAura field remains Phantom/Core-only; clientfield value
    // 2 (glitch magenta) is now unused. Manual re-enable for A/B: `set acc_glitch_aura 1` no longer
    // does anything - re-add the set_phantom_aura call if the toxic skin proves too subtle in the dark.

    // NO health bar / nameplate by design: no "acc_boss_spawned" notify (2D bar, user
    // 2026-06-15) and NO 3D over-head nameplate either (user 2026-07-02: plates verified
    // rendering in-game here, then scoped to the REAL bosses only - Brutus / Phantom /
    // Rogue Protector; the Glitch reads as an elite, not a boss). To restore for A/B:
    // acc_boss_nameplate::attach( host, "GLITCH STALKER" );

    // Behaviours.
    host thread glitch_blink_loop();      // self-endons on "death"
    host thread glitch_speed_think();     // anim rate = horde x acc_glitch_speed_mult (1.005 - about the same as the horde; the blink is its mobility)
    host thread glitch_death_watch();     // waits ON "death"
    // Phase Serum cloak: hide acc_cloak_glitch players from this boss's CORE follow+melee
    // AI (not just blink/charge). Stock get_closest_valid_player consults this per-AI
    // override FIRST (_zm_utility.gsc:1472) to derive BOTH self.favoriteenemy (movement)
    // and self.enemy (melee), so setting it scopes the cloak to the whole Stalker.
    host.closest_player_override = &glitch_pick_uncloaked_target;
    // No over-head marker (user 2026-06-15): the STOCK zombie skin (vs the charred horde,
    // SetModel above) is the indicator now.

    gdebug( "^5Glitch Stalker^7 spawned - blinks to flank you" );
    acc_utility::log( "boss_glitch: spawned Glitch Stalker (" + host.maxhealth + " hp, round " + round_number + ")" );

    // [acc] return the live host so _acc_lockdown_challenge can tag it (acc_ldc), teleport it
    // into the sealed room, and count it on its own death watch (the scheduled cadence ignores
    // this return value). docs/26.
    return host;
}

// Per-AI target picker for the Glitch Stalker (set as host.closest_player_override).
// Stock contract (_zm_utility.gsc:1474): invoked as [[ self.closest_player_override ]]( origin,
// players ) with NO self prefix - ambient self is the zombie. We strip Phase-Serum-cloaked
// players (self.acc_cloak_glitch) then DELEGATE to the map-wide level override (the private
// factory_closest_player, reachable only via the pointer), so path-distance picking stays
// identical to stock for every non-cloaked player. All players cloaked -> no target (idles).
function glitch_pick_uncloaked_target( origin, players )
{
    if ( !isdefined( players ) || players.size == 0 )
        return undefined;
    uncloaked = [];
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && !( isdefined( p.acc_cloak_glitch ) && p.acc_cloak_glitch ) )
            uncloaked[ uncloaked.size ] = p;
    }
    if ( uncloaked.size == 0 )
        return undefined;
    if ( isdefined( level.closest_player_override ) )
        return [[ level.closest_player_override ]]( origin, uncloaked );
    return arraygetclosest( origin, uncloaked );
}

// Spawn a stock-template zombie from a random base spawner and INIT-GATE it. Returns
// the live actor, or undefined on any failure (caller guards). Mirrors the proven
// path in spawn_subroutine_core (_acc_boss.gsc:421-469) / spawn_elite (_acc_elites.gsc).
// Active spawner NEAREST a random living player, so the Stalker spawns in a player's area (not a random
// open zone). level.zombie_spawners is active-zone-only. Returns undefined if no living player (the caller
// then falls back to a random active spawner).
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

function spawn_promoted_zombie()
{
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss_glitch: no zombie_spawners, cannot spawn" );
        return undefined;
    }

    // Spawn from the ACTIVE spawner NEAREST a living player, not a fully random one. level.zombie_spawners is
    // already active-zone-only (the zonemgr adds/removes spawners as zones open - _zm.gsc:3885/3918), but a
    // random pick scatters the boss across ALL currently-open zones, so a player often never saw it - esp.
    // pre-power, when it kept landing in a different open zone than the one you're standing in (user
    // 2026-06-23: "no glitch zombies in the Plaza"). Nearest-to-a-player puts it where the fight is; falls
    // back to a random active spawner if there's no living player.
    // RETRY a TRANSIENT spawn refusal (added 2026-07-15). We used to take ONE shot: stock
    // spawn_zombie returns undefined whenever SpawnFromSpawner refuses (zombie_utility.gsc:1469-1482,
    // e.g. at round-start frames), and that single failure silently cost a whole Stalker with no
    // trace in normal play. run_glitch_wave's leading stagger is the ROOT-CAUSE fix; this is the
    // backstop, because the exact frame threshold where the engine starts accepting spawns is not
    // documented anywhere and we should not depend on having guessed it right. Re-picks the spawner
    // each attempt (a living player may have moved zones). Bounded, and every attempt is ~0.5s, so
    // worst case is well inside a round; endon("acc_round_end") still cuts it if the round clears.
    core    = undefined;
    spawner = undefined;
    for ( attempt = 0; attempt < ACC_GLITCH_SPAWN_RETRIES; attempt++ )
    {
        if ( attempt > 0 )
            wait 0.5;

        spawner = nearest_spawner_to_player();
        if ( !isdefined( spawner ) )
            spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];

        core = zombie_utility::spawn_zombie( spawner );
        if ( isdefined( core ) )
            break;
    }

    if ( !isdefined( core ) )
    {
        acc_utility::log( "boss_glitch: spawn_zombie returned undefined after " + ACC_GLITCH_SPAWN_RETRIES + " attempts" );
        return undefined;
    }

    // Busy-wait the per-actor init flag: stock zombie_spawn_init runs at frame-end and
    // OVERWRITES health/maxhealth (_zm_spawner.gsc:293-311), so we must promote AFTER
    // it. Capped iteration count so a never-init actor can never hang the thread.
    n = 0;
    while ( isdefined( core ) && !isdefined( core.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( core ) || !isalive( core ) )
    {
        acc_utility::log( "boss_glitch: host died/vanished during init" );
        return undefined;
    }
    return core;
}

// ---------------------------------------------------------------------------
// Signature ability: teleport-blink to flank + post-blink vulnerability window
// ---------------------------------------------------------------------------

// self = the live Glitch Stalker. Copies the VERIFIED(acc) elite teleport pattern
// (_acc_elites.gsc:246-275) - clamp the flank point to the navmesh FIRST, then
// forceteleport - so the blink can never land in geometry/off-mesh. Every timing/
// distance value is a live dvar.
function glitch_blink_loop()
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        wait blink_cooldown();

        if ( !isalive( self ) ) return;

        // PHASE SERUM (user 2026-06-29): a Stalker inside a serum-holder's aura LOSES its blink (glitch ability) -
        // it can still chase + melee, just at 1/5 speed (glitch_speed_think) with no teleport. Skip the blink.
        if ( self acc_serum_suppressed() )
        {
            gdebug( "blink suppressed (Phase Serum aura)" );
            continue;
        }

        target = acc_utility::get_closest_uncloaked_player( self.origin ); // Li'l Arnie cloak honored
        if ( !isdefined( target ) ) continue;

        // [acc] ENGAGEMENT GATE (user 2026-06-18): if we are already ON the target, do NOT blink away -
        // COMMIT to the melee swing. This kills the "it attacks me then teleports off, almost like a
        // glitch" bug AND makes standing still dangerous (we stay and hit you instead of fleeing). It is
        // re-checked every tick, so a target that flees past the range simply gets chased again (no stale
        // pin). Distance-only: EnemyInMeleeRange is NOT a real builtin - a bare call would FATAL at load.
        if ( Distance( self.origin, target.origin ) <= getdvarint( "acc_glitch_engage_dist", 160 ) )
        {
            gdebug( "commit (engaged - no blink)" );
            continue;
        }

        // [acc] PUNISH STANDING STILL (user 2026-06-18): a target that barely moved since our last tick,
        // is NOT downed (laststand), and isn't already being pounced by another Stalker (throttle) -> we
        // POUNCE: blink to a point just short of them along OUR approach vector so we land in melee; the
        // gate above then keeps us there. glitch_target_stationary runs FIRST (it must record lastpos
        // every tick); claim_pounce (which stamps the throttle) only runs when actually camping.
        camping = false;
        if ( self glitch_target_stationary( target ) && !IS_TRUE( target.laststand ) )
            camping = claim_pounce( target );

        if ( isdefined( self.acc_ldc ) && self.acc_ldc )
        {
            // CHALLENGE: blink TOWARD the in-room player (SMALL offsets only, never the 300u flank) so the
            // destination stays inside the sealed room - ldc_in_room-checked, random anchor as the safe
            // fallback. This is the big "lockdown was super easy" fix: they press you instead of scattering.
            flank_pos = self ldc_aggressive_blink( target );
        }
        else if ( camping )
        {
            flank_pos = GetClosestPointOnNavMesh( pounce_point( self.origin, target.origin ), 100, 30 );
        }
        else
        {
            flank_pos = GetClosestPointOnNavMesh( target.origin + blink_offset(), 100, 30 ); // 300u reposition flank
        }
        if ( !isdefined( flank_pos ) ) continue; // no valid navmesh point -> skip this blink

        // [acc] de-rez burst at BOTH ends of the blink (docs/44 workstream A) - the departure
        // burst is the tell that it moved, the arrival burst is the "where". Combat blinks only;
        // the hidden spawn-drive forceteleport (~L668) stays FX-less so the reveal isn't spoiled.
        acc_utility::derez_burst( self.origin );
        self forceteleport( flank_pos );
        acc_utility::derez_burst( self.origin );
        // [acc] teleport "warp" SFX EMITTED BY the zombie. `self PlaySound` attaches the sound to the
        // AI entity (the same call the Brutus pack uses for its vocals), so it is a true 3D world sound
        // that originates at the zombie and follows him - inaudible when he's far, louder up close,
        // exactly like a zombie cry. The distance falloff itself is the alias's 3D curve
        // (DistMin/DistMaxDry/DistMaxWet in acc_audio.csv). Gated by acc_glitch_warp_snd (default on).
        if ( getdvarint( "acc_glitch_warp_snd", 1 ) != 0 )
            self PlaySound( "acc_glitch_warp" );
        self notify( "acc_glitch_phasein" ); // cancel any in-flight phase-in (blinks can fire faster than one finishes)
        self thread glitch_phase_in();

        // [acc] 2x-damage-taken window fires ONLY on a real repositioning flank - NOT on a pounce (else a
        // camper steps back and free-shoots a stationary, currently-vulnerable boss = the cheese we are
        // fixing). A committed/adjacent boss never reaches here (it `continue`d at the gate), so it is
        // never marked vulnerable while pressing the attack.
        if ( !camping )
            self thread glitch_vulnerable_window();

        gdebug( ( camping ? "pounce" : "blink" ) );
    }
}

// self = the boss. The OLD "just hide it" version still showed the standstill whenever the
// AI's post-teleport re-path took longer than the reveal cap (it would un-hide a still-frozen
// actor). This version is the EXAGGERATED fix (user 2026-06-17): it not only hides the boss,
// it physically DRIVES it toward the nearest player while hidden - navmesh-clamped micro-
// teleports at acc_glitch_charge_speed - so the boss actually CLOSES the gap during the
// invisible window instead of standing where it blinked. Once it is within acc_glitch_reveal_dist
// of a player we stop driving it and hand control back to the zombie AI, then reveal ONLY once
// the AI has started moving on its own (origin drift) - so the player always sees it already
// charging, never standing. The AI's re-path pause is spent entirely hidden. Ghost()/Show()
// toggle RENDERING ONLY (still fully hittable, no FX asset, no crash surface). A hard cap
// (acc_glitch_phasein_max) guarantees it can never stay invisible. Cancelled by the next blink
// (endon below). Gated by `acc_glitch_fx` (default on).
function glitch_phase_in()
{
    self endon( "death" );
    self endon( "acc_glitch_phasein" ); // a fresh blink cancels an in-flight phase-in

    if ( getdvarint( "acc_glitch_fx", 1 ) != 1 ) return; // leave it visible the whole time

    self Ghost(); // vanish the instant we blink in - the whole re-path standstill happens HIDDEN

    cap        = getdvarfloat( "acc_glitch_phasein_max", 2.5 );  // hard invisibility failsafe (s)
    charge_spd = getdvarint( "acc_glitch_charge_speed", 591 );   // units/sec the hidden charge closes the gap (user 2026-07-17: 506->591, cut the 07-16 pass in half - "too passive now"; 2026-07-16: 675->506; 2026-06-23: 900->675)
    reveal_d   = getdvarint( "acc_glitch_reveal_dist", 140 );    // reveal/hand back to the AI this close to a player. 140 (was 240) = INSIDE the engage range so it actually presses the attack instead of un-hiding far out and re-blinking before contact (user 2026-06-18). Live dvar.
    if ( charge_spd < 0 ) charge_spd = 0;
    step     = charge_spd * 0.05; // distance per 20Hz tick
    moved_sq = 12 * 12;           // units^2 of self-driven AI travel that counts as "it's moving"

    charging = true;
    anchor   = self.origin;
    t = 0;
    while ( t < cap )
    {
        if ( !isalive( self ) ) return;

        target = acc_utility::get_closest_uncloaked_player( self.origin ); // Li'l Arnie cloak honored
        if ( isdefined( target ) )
        {
            dist = Distance( self.origin, target.origin );

            if ( charging && dist > reveal_d )
            {
                // EXAGGERATED: physically pull the boss toward the player while hidden. Each step is
                // navmesh-clamped (never lands in geometry / off-mesh) and faces the player.
                dir  = VectorNormalize( target.origin - self.origin );
                want = self.origin + dir * step;
                nav  = GetClosestPointOnNavMesh( want, 60, 30 );
                if ( isdefined( nav ) )
                {
                    // [acc] Challenge zombie: never charge-teleport OUT of the sealed room - skip
                    // the step if the nav point left it (the AI walks the last bit instead).
                    ldc_ok = true;
                    if ( isdefined( self.acc_ldc ) && self.acc_ldc )
                        ldc_ok = self ldc_in_room( nav );

                    if ( ldc_ok )
                    {
                        face = VectorToAngles( target.origin - nav );
                        self forceteleport( nav, ( 0, face[ 1 ], 0 ) );
                    }
                }
            }
            else
            {
                // Close enough - stop driving it and let the zombie AI take back over. Reveal only once
                // it has actually MOVED on its own (origin drift from where we dropped it), so it appears
                // already charging, never standing. The AI's re-path pause happens here, still hidden.
                if ( charging )
                {
                    charging = false;
                    anchor   = self.origin;
                }
                if ( DistanceSquared( self.origin, anchor ) > moved_sq )
                    break; // AI is moving -> safe to reveal
            }
        }

        wait 0.05;
        t += 0.05;
    }

    if ( isalive( self ) )
        self Show(); // always end visible
}

// Random seconds until the next blink (min..max), guarded against an inverted slider.
function blink_cooldown()
{
    cmin = getdvarfloat( "acc_glitch_blink_cd_min", ACC_GLITCH_BLINK_CD_MIN_DEF );
    cmax = getdvarfloat( "acc_glitch_blink_cd_max", ACC_GLITCH_BLINK_CD_MAX_DEF );
    if ( cmax < cmin ) cmax = cmin; // tolerate min > max input
    return cmin + randomfloat( cmax - cmin );
}

// A 4-way (axis-aligned) flank offset at the configured distance. No trig (cheap +
// safe); GetClosestPointOnNavMesh clamps it to a real point regardless of direction.
function blink_offset()
{
    dist = getdvarint( "acc_glitch_blink_dist", ACC_GLITCH_BLINK_DIST_DEF );
    r = acc_utility::acc_rand_int( 4 );
    if ( r == 0 ) return ( dist, 0, 0 );
    if ( r == 1 ) return ( dist * -1, 0, 0 );
    if ( r == 2 ) return ( 0, dist, 0 );
    return ( 0, dist * -1, 0 );
}

// ---------------------------------------------------------------------------
// Aggression / anti-cheese helpers (user 2026-06-18). GSC has no "is the player moving" query, so
// "stationary" = the SAME target's XY barely changed between two blink-loop ticks (~1.0-1.665s apart).
// ---------------------------------------------------------------------------

// self = the boss. Records the target's XY on self each tick; returns true if it moved <=
// acc_glitch_still_thresh since our last reading of the SAME target. Resets on a target switch so a
// coop target swap is never misread as "still".
function glitch_target_stationary( target )
{
    thr  = getdvarint( "acc_glitch_still_thresh", 48 );
    thr2 = thr * thr;
    cur  = target.origin;

    still = false;
    if ( isdefined( self.acc_glitch_tgt ) && self.acc_glitch_tgt == target && isdefined( self.acc_glitch_tgt_lastpos ) )
    {
        dx = cur[ 0 ] - self.acc_glitch_tgt_lastpos[ 0 ];
        dy = cur[ 1 ] - self.acc_glitch_tgt_lastpos[ 1 ];
        still = ( ( dx * dx + dy * dy ) <= thr2 );
    }
    self.acc_glitch_tgt         = target;
    self.acc_glitch_tgt_lastpos = cur;
    return still;
}

// A point acc_glitch_pounce_dist short of `to`, along the from->to (boss->player) vector - i.e. on the
// approacher's OWN reachable side, in melee range. NOT behind the player's facing (a corner camper faces
// the wall, so a behind-facing offset would clamp the boss out of range). Caller nav-clamps it.
function pounce_point( from, to )
{
    d   = getdvarint( "acc_glitch_pounce_dist", 56 );
    dir = VectorNormalize( to - from );
    return to - dir * d;
}

// Throttle so a whole PACK can't teleport-stack one camper: returns true (and stamps the target) only if
// no Stalker has pounced THIS target within acc_glitch_pounce_cooldown ms. Time-based, so no release is
// needed - a dead/teleported pouncer never holds the slot.
function claim_pounce( target )
{
    cd = getdvarint( "acc_glitch_pounce_cooldown", 1867 );   // ms (user 2026-07-17: 2133->1867, cut the 07-16 pass in half - "too passive now"; 2026-07-16: 1600->2133; 2026-06-23: 1200->1600)
    if ( isdefined( target.acc_glitch_last_pounce ) && ( gettime() - target.acc_glitch_last_pounce ) < cd )
        return false;
    target.acc_glitch_last_pounce = gettime();
    return true;
}

// ---------------------------------------------------------------------------
// Lockdown-CHALLENGE containment helpers (no-op for normal glitch bosses). The challenge
// (_acc_lockdown_challenge) tags its zombies self.acc_ldc + stocks self.acc_ldc_anchors with the
// sealed room's interior spawn-anchor origins. These keep every blink/charge teleport in-room.
// ---------------------------------------------------------------------------

// True if XY point p is within acc_lockdown_challenge_bounds_margin of ANY of this actor's room
// anchors (the anchors are interior risers, so "near an anchor" == "in the sealed room"). Defaults
// true when no anchors are set (non-challenge actor) so normal play is never constrained.
function ldc_in_room( p )
{
    if ( !( isdefined( self.acc_ldc_anchors ) && self.acc_ldc_anchors.size > 0 ) ) return true;

    d  = getdvarint( "acc_lockdown_challenge_bounds_margin", 300 );
    d2 = d * d;
    for ( i = 0; i < self.acc_ldc_anchors.size; i++ )
    {
        a  = self.acc_ldc_anchors[ i ];
        dx = p[ 0 ] - a[ 0 ];
        dy = p[ 1 ] - a[ 1 ];
        if ( ( dx * dx + dy * dy ) <= d2 ) return true;
    }
    return false;
}

// A navmesh point AT a random in-room anchor - the blink destination for a challenge zombie.
function ldc_random_anchor_nav()
{
    if ( !( isdefined( self.acc_ldc_anchors ) && self.acc_ldc_anchors.size > 0 ) ) return undefined;

    a   = self.acc_ldc_anchors[ acc_utility::acc_rand_int( self.acc_ldc_anchors.size ) ];
    nav = GetClosestPointOnNavMesh( a, 100, 40 );
    if ( isdefined( nav ) ) return nav;
    return a;
}

// Aggressive-but-CONTAINED challenge blink: aim NEAR the (provably in-room) player using only SMALL
// offsets - never the 300u flank, which could clamp past a sealed door and still pass the loose
// ldc_in_room radius test (docs/26 §4.5). Every candidate is ldc_in_room-checked before it's accepted;
// if none near the player is in-room we fall back to a guaranteed-in-room anchor, so containment holds.
function ldc_aggressive_blink( target )
{
    // 1) just short of the player along our approach vector (lands in melee, on our side).
    cand = GetClosestPointOnNavMesh( pounce_point( self.origin, target.origin ), 100, 30 );
    if ( isdefined( cand ) && self ldc_in_room( cand ) ) return cand;

    // 2) a couple of short side-flanks of the player, kept in-room.
    d = getdvarint( "acc_glitch_ldc_blink_dist", 90 );
    cand = GetClosestPointOnNavMesh( target.origin + ( d, 0, 0 ), 100, 30 );
    if ( isdefined( cand ) && self ldc_in_room( cand ) ) return cand;
    cand = GetClosestPointOnNavMesh( target.origin + ( d * -1, 0, 0 ), 100, 30 );
    if ( isdefined( cand ) && self ldc_in_room( cand ) ) return cand;
    cand = GetClosestPointOnNavMesh( target.origin + ( 0, d, 0 ), 100, 30 );
    if ( isdefined( cand ) && self ldc_in_room( cand ) ) return cand;
    cand = GetClosestPointOnNavMesh( target.origin + ( 0, d * -1, 0 ), 100, 30 );
    if ( isdefined( cand ) && self ldc_in_room( cand ) ) return cand;

    // 3) last resort: a guaranteed-in-room anchor (containment).
    return self ldc_random_anchor_nav();
}

// self = the boss. Marks it vulnerable for the recovery window; _acc_damage reads
// self.acc_glitch_vulnerable and adds the bonus-damage layer while it is set. Threaded
// so the blink cooldown timing stays independent of the window length.
function glitch_vulnerable_window()
{
    self endon( "death" );

    self.acc_glitch_vulnerable = true;
    wait getdvarfloat( "acc_glitch_recovery_sec", ACC_GLITCH_RECOVERY_SEC_DEF );
    self.acc_glitch_vulnerable = false;
}

// ---------------------------------------------------------------------------
// Death -> rewards
// ---------------------------------------------------------------------------

// self = the boss. NO `endon("death")` here (we wait ON death). Reward (user 2026-06-22): the KILLER gets
// 1 Data Shard - NO boss-item drop, NO Mega Bottle. Those stay exclusive to the rare Brutus / Phantom; the
// Glitch Stalker spawns every round (1-3x), so item/bottle drops would flood the player.
function glitch_death_watch()
{
    self waittill( "death", attacker );

    if ( !isdefined( self ) )
        return;

    // Clean up the corpse like a normal zombie (user 2026-06-19: "glitch bodies on the ground"). The
    // Glitch Stalker is a RESKINNED zombie with NO death anim, but it carries acc_is_mini_boss (for the
    // headshot mult), which makes _acc_corpse_cleanup SKIP it - so without this its body LINGERS, and the
    // lockdown challenge spawns ~30 of them -> entity bloat (a crash suspect). Threaded BEFORE the reward
    // so the reward below still captures self.origin first (the Delete is one frame later).
    self thread cleanup_glitch_corpse();

    // [acc] NO per-kill shard for purge-spawned (acc_ldc) OR reactor-surge-spawned (acc_no_shard_reward)
    // Stalkers - else a 30-wave purge drops 30 rewards, and the reactor surge would pay for its own threats
    // (user 2026-06-24: reactor specials don't pay, same as the glitch purge). docs/26 §4.6. Corpse still cleaned above.
    if ( ( isdefined( self.acc_ldc ) && self.acc_ldc ) ||
         ( isdefined( self.acc_no_shard_reward ) && self.acc_no_shard_reward ) )
        return;

    self.acc_glitch_vulnerable = false; // belt-and-suspenders: no dangling bonus state

    // Reward (user 2026-06-22): the Glitch Stalker is a FREQUENT mini-boss (every round, 1-3 of them), so it
    // NO LONGER drops boss items or grants Mega Bottles - those stay exclusive to the RARE bosses (Brutus,
    // Phantom). Instead the KILLER (the player who landed the kill) gets exactly 1 Data Shard.
    if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        acc_data_shards::grant_player( attacker, 1, "glitch_kill" );
        acc_leveling::grant_elite_xp( attacker, "glitch" );   // [acc] leveling: mini-boss kill bonus (docs/45; follows the shard's gating)
    }

    gdebug( "^2Glitch Stalker down^7 - +1 Data Shard to killer" );
    acc_utility::log( "boss_glitch: Glitch Stalker killed" );
}

// Delete the Glitch Stalker corpse - it is SKIPPED by _acc_corpse_cleanup (acc_is_mini_boss) but has no
// death anim, so it would otherwise linger as a "glitch body" (and pile up in the lockdown challenge).
// Mirrors _acc_corpse_cleanup::corpse_linger_remove: de-collide + hide NOW, brief wait for the engine to
// finish death processing (notetracks/drops), then Delete to free the actor slot.
function cleanup_glitch_corpse()
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

// On-screen trace for live debugging without the console. Rides IS_TRUE( level.acc_dev ) -
// visible in a dev build, silent in ship (the acc_glitch_debug / acc_variants_debug dvars
// were removed 2026-07-16; docs/22 §E).
function gdebug( msg )
{
    if ( !IS_TRUE( level.acc_dev ) ) return;   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)

    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5[glitch] ^7" + msg );
    }
}
