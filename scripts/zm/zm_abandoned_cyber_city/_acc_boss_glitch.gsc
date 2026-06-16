// =============================================================================
// _acc_boss_glitch.gsc - "Glitch Stalker" mini-boss (script-only, zero assets)
//
// Design: docs/11_enemies.md ("Glitch Stalker"). A MOBILE mini-boss - the map's
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
// `acc_glitch_enable 0`. To trace it live: `acc_glitch_debug 1`. Every stat is an
// `acc_glitch_*` dvar read LIVE (no rebuild to tune) - see docs/34_flags_reference.md.
//
// CRASH-SAFETY (deliberate, see docs/11 + CLAUDE.md hard-won facts):
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;

#insert scripts\shared\shared.gsh;

// --- Tunable defaults. EVERY one is overridable live via the matching acc_glitch_*
//     dvar (read at the point of use, not cached) - this is the whole "easy slider"
//     contract. Mirror each row in docs/34_flags_reference.md. ---
#define ACC_GLITCH_ENABLE_DEF            1      // master on/off (set 0 to disable the boss entirely - gates real cadence + test spawn)
#define ACC_GLITCH_HP_MULT_DEF              3   // HP = this x the round's NORMAL zombie health (user 2026-06-15)
#define ACC_GLITCH_FIRST_ROUND_DEF          3   // first round it can spawn (user 2026-06-15)
#define ACC_GLITCH_INTERVAL_DEF            10   // then every N rounds (3, 13, 23, ...)
#define ACC_GLITCH_TEST_ROUND_DEF           3   // dev/test path: first round it spawns (user 2026-06-15)
#define ACC_GLITCH_BLINK_CD_MIN_DEF         1.0 // min seconds between blinks (2x more often, user 2026-06-15; now 6x the original 6.0s baseline)
#define ACC_GLITCH_BLINK_CD_MAX_DEF         1.665 // max seconds between blinks (2x more often; now 6x the original 10.0s baseline)
#define ACC_GLITCH_BLINK_DIST_DEF         300   // flank offset (units) from the target
#define ACC_GLITCH_RECOVERY_SEC_DEF         1.5 // post-blink vulnerability window (s)
#define ACC_GLITCH_RECOVERY_DMG_MULT_DEF    2.0 // damage multiplier while vulnerable (damage IT takes - not the damage it deals)
#define ACC_GLITCH_MELEE_DMG_MULT_DEF       0.5 // melee damage DEALT to players vs a stock zombie (0.5 = -50%, user 2026-06-15)
#define ACC_GLITCH_SPEED_MULT_DEF           1.15 // move speed vs the round's normal zombies (1.15 = +15%, user 2026-06-15)
#define ACC_GLITCH_COUNT_DEF                2   // bosses spawned per scheduled round (acc_glitch_count)

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
    if ( getdvarint( "acc_glitch_enable", ACC_GLITCH_ENABLE_DEF ) != 1 ) return;

    // Dev/test spawn: fires when acc_glitch_test 1 OR the dev sandbox is on. acc_dev is read
    // with default 1 to MATCH the entry script (zm_abandoned_cyber_city.gsc:157) - acc_dev is
    // never SetDvar'd, so a default-0 read would see 0 even in dev mode. Spawns from
    // acc_glitch_test_round (default 1).
    test = getdvarint( "acc_glitch_test", 0 );
    dev  = getdvarint( "acc_dev", 1 );
    if ( ( test == 1 || dev == 1 ) && round_number >= getdvarint( "acc_glitch_test_round", ACC_GLITCH_TEST_ROUND_DEF ) )
    {
        wait 5; // let the round get going
        run_glitch_wave( round_number );
        return;
    }

    if ( !cadence_hits( round_number ) ) return;
    if ( is_full_boss_round( round_number ) ) return; // never share a round with the Core

    run_glitch_wave( round_number );
}

// self = the boss. Make it ~25% faster than the round's NORMAL zombies. Zombie movement is
// anim-driven (the same lever the horde's _acc_zombie_speed uses), so we lock the SAME gait
// the horde is on this round (acc_zombie_speed::tier_for_round) and set the anim playback rate
// to acc_glitch_speed_mult x the horde's rate (acc_zombie_speed::rate_for_round). Same gait +
// 1.25x rate = exactly +25% ground speed. We flag self.acc_boss_custom_speed so the global
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

        self zombie_utility::set_zombie_run_cycle_override_value( acc_zombie_speed::tier_for_round( r ) );
        self ASMSetAnimationRate( rate );
        wait 1;
    }
}

// Spawn `acc_glitch_count` Glitch Stalkers this round, staggered a beat apart for
// co-op spawn safety (mirrors run_mini_boss in _acc_boss.gsc). One inbound announce
// per wave (not per boss).
function run_glitch_wave( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    count = getdvarint( "acc_glitch_count", ACC_GLITCH_COUNT_DEF );
    if ( count < 1 ) count = 1;

    announce_inbound( count );

    for ( i = 0; i < count; i++ )
    {
        spawn_glitch( round_number );
        wait 1.5;
    }
}

// Always-on inbound announce to every player (a boss should be unmissable - this also
// doubles as spawn proof in console_mp.log via the [ SCRIPTER] route).
function announce_inbound( count )
{
    suffix = ( count > 1 ? " x" + count : "" );
    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5GLITCH STALKER ^7inbound" + suffix );
    }
}

// True on the rounds the Glitch Stalker is scheduled. `(round - first) % interval`
// (not `round % interval`) so `first` can be ANY value, e.g. first 12 -> 12, 22, 32.
function cadence_hits( round_number )
{
    first    = getdvarint( "acc_glitch_first_round", ACC_GLITCH_FIRST_ROUND_DEF );
    interval = getdvarint( "acc_glitch_interval", ACC_GLITCH_INTERVAL_DEF );
    if ( interval < 1 ) interval = 1; // guard a bad slider (avoid mod-by-zero)

    if ( round_number < first ) return false;
    return ( ( round_number - first ) % interval ) == 0;
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

    // HP = acc_glitch_hp_mult x the round's NORMAL zombie health (user 2026-06-15, default 3x).
    // level.zombie_health is the stock per-round normal-zombie HP (the actor's post-init maxhealth
    // equals it - fallback below). Written AFTER the init-gate so stock zombie_spawn_init can't
    // clobber it. Live-tunable, no rebuild. Scales with the round automatically (no separate curve).
    mult = getdvarint( "acc_glitch_hp_mult", ACC_GLITCH_HP_MULT_DEF );
    if ( mult < 1 ) mult = 1;
    normal_hp = ( isdefined( level.zombie_health ) ? level.zombie_health : host.maxhealth );
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

    // STOCK base-zombie SKIN (BODY + HEAD, user 2026-06-15): the horde is the charred reskin, so
    // giving the boss the STOCK "Giant" zombie BODY + HEAD makes it visually distinct. On the live
    // actor (past the init-gate) this is the established idiom (nsz_brutus.gsc:668; the head
    // Detach/Attach mirrors archetype_clone.gsc / archetype_thrasher.gsc). SetModel swaps ONLY the
    // base BODY model (it leaves attachments), so we ALSO Detach the engine-attached charred HEAD
    // and Attach the stock head. Detaching by the KNOWN charred-head literal (the charred GDT head
    // field) - NOT host.head, which is undefined on a plain promoted zombie (verified); Detach of a
    // not-attached model is a safe no-op. c_zom_der_* share the SAME 'base' skeleton + gib rig as
    // charred (anims/gibs intact, verified); both models packed via xmodel lines in the .zone.
    // Toggle with acc_glitch_stock_skin 0. NO SetScale (the confirmed live-AI 0xC0000005 crasher).
    if ( getdvarint( "acc_glitch_stock_skin", 1 ) == 1 )
    {
        host SetModel( "c_zom_der_zombie_body1" );        // stock Giant body
        host Detach( "c_zom_dlc4_zombie_charred_head" );  // remove the charred head the archetype attached
        host Attach( "c_zom_der_zombie_head1" );          // attach the stock Giant head (heads self-align, no tag)
        if ( isdefined( host.gib_data ) )
            host.gib_data.head = "c_zom_der_zombie_head1"; // keep gib metadata consistent (cosmetic; no_gib is true)
    }

    // NO health bar by design (user request 2026-06-15): we deliberately do NOT emit
    // "acc_boss_spawned", so the top-screen boss bar + nameplate never appear. There is no
    // over-head marker either - the stock zombie skin is the only indicator now.

    // Behaviours.
    host thread glitch_blink_loop();      // self-endons on "death"
    host thread glitch_speed_think();     // ~25% faster than the round's normal zombies
    host thread glitch_death_watch();     // waits ON "death"
    // No over-head marker (user 2026-06-15): the STOCK zombie skin (vs the charred horde,
    // SetModel above) is the indicator now.

    gdebug( "^5Glitch Stalker^7 spawned - blinks to flank you" );
    acc_utility::log( "boss_glitch: spawned Glitch Stalker (" + host.maxhealth + " hp, round " + round_number + ")" );
}

// Spawn a stock-template zombie from a random base spawner and INIT-GATE it. Returns
// the live actor, or undefined on any failure (caller guards). Mirrors the proven
// path in spawn_subroutine_core (_acc_boss.gsc:421-469) / spawn_elite (_acc_elites.gsc).
function spawn_promoted_zombie()
{
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss_glitch: no zombie_spawners, cannot spawn" );
        return undefined;
    }

    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
    core = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( core ) )
    {
        acc_utility::log( "boss_glitch: spawn_zombie returned undefined (spawner missing script_forcespawn?)" );
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

        target = acc_utility::get_closest_player_to( self.origin );
        if ( !isdefined( target ) ) continue;

        flank_pos = GetClosestPointOnNavMesh( target.origin + blink_offset(), 100, 30 );
        if ( !isdefined( flank_pos ) ) continue; // no valid navmesh point -> no blink

        self forceteleport( flank_pos );
        // [acc] teleport "warp" SFX EMITTED BY the zombie. `self PlaySound` attaches the sound to the
        // AI entity (the same call the Brutus pack uses for its vocals), so it is a true 3D world sound
        // that originates at the zombie and follows him - inaudible when he's far, louder up close,
        // exactly like a zombie cry. The distance falloff itself is the alias's 3D curve
        // (DistMin/DistMaxDry/DistMaxWet in acc_audio.csv). Gated by acc_glitch_warp_snd (default on).
        if ( getdvarint( "acc_glitch_warp_snd", 1 ) != 0 )
            self PlaySound( "acc_glitch_warp" );
        self thread glitch_blink_fx();
        self thread glitch_vulnerable_window();
        gdebug( "blink" );
    }
}

// self = the boss. Asset-free "glitch" tell: a brief visibility FLICKER as it phases
// in after a blink. Ghost()/Show() are the stock zombie spawn-in render builtins
// (_zm_utility.gsc teleport-in path) - they toggle RENDERING ONLY, never collision or
// damage, so the boss stays fully hittable through the flicker and there is no new FX
// asset (fresh-clone safe) and no crash surface. Gated by `acc_glitch_fx` (default on).
// A real glitch/teleport FX is the Phase 5 art upgrade (drop it in here).
function glitch_blink_fx()
{
    self endon( "death" );

    if ( getdvarint( "acc_glitch_fx", 1 ) != 1 ) return;

    for ( i = 0; i < 3; i++ )
    {
        self Ghost();
        wait 0.05;
        self Show();      // always end a cycle visible
        wait 0.05;
    }
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

// self = the boss. NO `endon("death")` here (we wait ON death). Mini reward tier:
// 50% boss-item drop + 1 Empty Mega Bottle to every player (_acc_boss_items /
// _acc_mega_bottles). Capture the origin BEFORE the corpse is cleaned up.
function glitch_death_watch()
{
    self waittill( "death", attacker );

    drop_origin = self.origin;
    self.acc_glitch_vulnerable = false; // belt-and-suspenders: no dangling bonus state

    acc_boss_items::on_boss_death( "mini", attacker, drop_origin );
    acc_mega_bottles::on_boss_death( "mini", attacker, drop_origin );

    gdebug( "^2Glitch Stalker down^7 - Mega Bottle dropped" );
    acc_utility::log( "boss_glitch: Glitch Stalker killed" );
}

// ---------------------------------------------------------------------------
// Debug
// ---------------------------------------------------------------------------

// On-screen trace for live debugging without the console. Gated on `acc_glitch_debug 1`
// (default off). Mirrors the acc_variants_debug pattern (docs/34 §E).
function gdebug( msg )
{
    if ( getdvarint( "acc_glitch_debug", 0 ) != 1 ) return;

    for ( i = 0; i < level.players.size; i++ )
    {
        p = level.players[ i ];
        if ( isdefined( p ) && isplayer( p ) )
            p IPrintLnBold( "^5[glitch] ^7" + msg );
    }
}
