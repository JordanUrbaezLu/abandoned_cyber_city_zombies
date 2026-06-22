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
// Yields to the Subroutine Core on its sealed rounds.
//
// HOLOGRAPHIC GLOW AURA (v2, user 2026-06-18): a cyan energy glow wraps the boss while it is
// MATERIALIZED (off while cloaked, so it never reveals the invisible Phantom). Server sets the
// "accPhantomAura" actor clientfield (here); _acc_boss_phantom.csc PlayFX's the glow (server
// PlayFX does not render in this build). FX = the already-packed cyan acc/light/fx_perk_glow_teal.
//
// LED-SAFE: pure .gsc + .csc + existing .fx - `-GscOnly`, no .map/material/sky change.
// =============================================================================

#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

// --- Tunable defaults (every one a live acc_phantom_* dvar; mirror docs/34). ---
// REMOVED FOR NOW (user 2026-06-19): the Phantom reads as a redundant, less-aggressive Glitch
// Stalker (both cyan + phase/"blink" + tanky), so it's disabled by default while the Panzer takes
// the ~round-10 boss slot. Module kept intact + recoverable - flip this to 1 (or `acc_phantom_enable 1`)
// to bring it back, ideally re-themed to be distinct from the Glitch first.
#define ACC_PHANTOM_ENABLE_DEF        0     // master on/off (0 = removed for now; see note above)
#define ACC_PHANTOM_HP_MULT_DEF       10    // HP = this x the round's NORMAL zombie health
#define ACC_PHANTOM_FIRST_ROUND_DEF   10    // first rotation slot round
#define ACC_PHANTOM_INTERVAL_DEF      10    // then every N rounds
#define ACC_PHANTOM_TEST_ROUND_DEF    8     // dev/test first round
// SCARY pass (user 2026-06-19): he gives a guaranteed Mega Bottle, so he has to EARN it -
// hits hard, moves fast, and stays cloaked until he's almost on you (a startling reveal).
#define ACC_PHANTOM_REVEAL_DIST_DEF   240   // stay invisible until THIS close, then materialize (was 400 - now he's on you)
#define ACC_PHANTOM_SPEED_MULT_DEF    1.4   // move speed vs the round's normal zombies (relentless - hard to kite)
#define ACC_PHANTOM_MELEE_DMG_DEF     85    // melee dealt to players (stock zombie = 60/our horde = 45) - downs a no-Jug player in 2
#define ACC_PHANTOM_FLICKER_PCT_DEF   12    // % of 0.1s ticks that blip invisible while materialized (hologram flicker)

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
    clientfield::register( "actor", "accPhantomAura", VERSION_SHIP, 1, "int" );
}

// ---------------------------------------------------------------------------
// Lifecycle + cadence (the round-boss rotation slot)
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "boss_phantom: init (holographic cloaker mini-boss, script-only)" );
    level thread round_watch();
}

function round_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
        level thread maybe_spawn_for_round( round_number );
    }
}

function maybe_spawn_for_round( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    if ( getdvarint( "acc_phantom_enable", ACC_PHANTOM_ENABLE_DEF ) != 1 ) return;
    if ( isdefined( level.acc_ldc_active ) ) return;   // lockdown challenge owns the actor budget

    // Dev/test: fires under acc_phantom_test OR the dev sandbox (acc_dev default 1, matches the
    // entry script + the Glitch), from acc_phantom_test_round.
    test = getdvarint( "acc_phantom_test", 0 );
    dev  = getdvarint( "acc_dev", 1 );
    if ( ( test == 1 || dev == 1 ) && round_number >= getdvarint( "acc_phantom_test_round", ACC_PHANTOM_TEST_ROUND_DEF ) )
    {
        wait 5;
        run_round_boss( round_number );
        return;
    }

    if ( !cadence_hits( round_number ) ) return;
    if ( is_full_boss_round( round_number ) ) return;  // yield to the sealed Subroutine Core

    run_round_boss( round_number );
}

// The ROUND-BOSS ROTATION (user 2026-06-18: random pick per ~10-round slot). One entry now
// (Phantom); add future script-only bosses to the pool and they join the random rotation.
function run_round_boss( round_number )
{
    level endon( "end_game" );
    level endon( "acc_round_end" );

    pool = [];
    pool[ pool.size ] = "phantom";
    // pool[ pool.size ] = "colossus";   // <- future bosses register here
    pick = pool[ acc_utility::acc_rand_int( pool.size ) ];

    if ( pick == "phantom" )
        spawn_phantom( round_number );
}

function cadence_hits( round_number )
{
    first    = getdvarint( "acc_phantom_first_round", ACC_PHANTOM_FIRST_ROUND_DEF );
    interval = getdvarint( "acc_phantom_interval", ACC_PHANTOM_INTERVAL_DEF );
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
        acc_utility::log( "boss_phantom: spawn failed (no host)" );
        return;
    }

    host.acc_is_mini_boss = true;   // boss headshot mult + corpse-cleanup skip + speed-keepalive skip

    // MASSIVE HP scaling with the round (written AFTER the init-gate). Live-tunable.
    mult = getdvarint( "acc_phantom_hp_mult", ACC_PHANTOM_HP_MULT_DEF );
    if ( mult < 1 ) mult = 1;
    normal_hp = ( isdefined( level.zombie_health ) ? level.zombie_health : host.maxhealth );
    if ( !isdefined( normal_hp ) || normal_hp < 1 ) normal_hp = 100;
    host.maxhealth = int( normal_hp * mult );
    host.health = host.maxhealth;

    // SCARY: hits HARD. Bosses are excluded from the trench-melee override (apply_speed_for_round
    // returns early on acc_is_mini_boss / acc_boss_custom_speed), so this value sticks - nothing
    // resets it to the 45/60 horde melee. Set AFTER the init-gate (stock writes meleeDamage=60 at
    // spawn). Combined with the cloak (you don't see him coming), even 2 hits is a down.
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

    host thread phantom_cloak_loop();   // the holographic cloak/flicker (self-endons on death)
    host thread phantom_speed_think();
    host thread phantom_death_watch();

    pdebug( "^5Phantom^7 spawned (" + host.maxhealth + " hp, round " + round_number + ")" );
    acc_utility::log( "boss_phantom: spawned (" + host.maxhealth + " hp, round " + round_number + ")" );
}

// Spawn a stock-template zombie from a random base spawner and INIT-GATE it (clone of the
// Glitch / Subroutine Core path). Returns the live actor or undefined.
function spawn_promoted_zombie()
{
    if ( !isdefined( level.zombie_spawners ) || level.zombie_spawners.size == 0 )
    {
        acc_utility::log( "boss_phantom: no zombie_spawners, cannot spawn" );
        return undefined;
    }

    spawner = level.zombie_spawners[ acc_utility::acc_rand_int( level.zombie_spawners.size ) ];
    core = zombie_utility::spawn_zombie( spawner );
    if ( !isdefined( core ) )
    {
        acc_utility::log( "boss_phantom: spawn_zombie returned undefined" );
        return undefined;
    }

    n = 0;
    while ( isdefined( core ) && !isdefined( core.zombie_init_done ) && n < 100 )
    {
        util::wait_network_frame();
        n++;
    }
    if ( !isdefined( core ) || !isalive( core ) )
    {
        acc_utility::log( "boss_phantom: host died/vanished during init" );
        return undefined;
    }
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
// Gated by acc_phantom_aura (default 1); when off, force-clears any existing aura.
function set_phantom_aura( ent, on )
{
    if ( !isdefined( ent ) ) return;
    if ( getdvarint( "acc_phantom_aura", 1 ) != 1 )
    {
        ent clientfield::set( "accPhantomAura", 0 );
        return;
    }
    ent clientfield::set( "accPhantomAura", ( IS_TRUE( on ) ? 1 : 0 ) );
}

// The cloaked->visible REVEAL scare: a warp screech the instant he materializes on you (reuses the
// confirmed Glitch warp alias). Cooldown'd (2s) so dancing at the reveal edge can't machine-gun it.
// Gated by acc_phantom_screech.
function materialize_scare( ent )
{
    if ( !isdefined( ent ) ) return;
    if ( getdvarint( "acc_phantom_screech", 1 ) != 1 ) return;

    now = GetTime();
    if ( isdefined( ent.acc_phantom_last_screech ) && ( now - ent.acc_phantom_last_screech ) < 2000 )
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

        r    = acc_zombie_speed::current_round();
        mult = getdvarfloat( "acc_phantom_speed_mult", ACC_PHANTOM_SPEED_MULT_DEF );
        rate = acc_zombie_speed::rate_for_round( r ) * mult;
        if ( rate < 0.1 ) rate = 0.1;

        self zombie_utility::set_zombie_run_cycle_override_value( acc_zombie_speed::tier_for_round( r ) );
        self ASMSetAnimationRate( rate );
        wait 1;
    }
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

    drop_origin = self.origin;

    acc_boss_items::on_boss_death( "mini", attacker, drop_origin );
    acc_mega_bottles::on_boss_death( "mini", attacker, drop_origin );

    pdebug( "^2Phantom down^7" );
    acc_utility::log( "boss_phantom: Phantom killed" );
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
