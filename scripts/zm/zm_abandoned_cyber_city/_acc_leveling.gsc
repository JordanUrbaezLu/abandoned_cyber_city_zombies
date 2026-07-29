// =============================================================================
// _acc_leveling.gsc - per-player LEVEL (0..10) that is the augmentation CEILING.
//
// A player's level caps BOTH tier ladders: max weapon-Overclock tier AND max Exo-Suit tier
// both equal your level. Start at LV0 (nothing tier-able); reach LV1 to unlock tier 1 of
// each; LV10 = fully maxed. XP is earned by pushing objectives (boss kills, trench dwell,
// FAST round clears) plus a small kill trickle. Full design: docs/45_leveling_system.md.
//
// DISABLED since 2026-07-24 (user: "disable for now, dev and non-dev"; was LIVE Jul 22, dev-only
// Jul 20-21). is_active() (below) is the SINGLE on/off point: it returns false, and init(), every
// grant, and the two purchase gates in _acc_exo / _acc_overclocks all read it - so the whole system
// (XP, HUD chip, tier gates) is inert in BOTH dev and normal play. Re-enable = one line in
// is_active(). The gates deny on LEVEL *before* the shard spend, so a level-locked press costs nothing.
//
// HUD: bottom-left "LV N" + XP bar, pushed via the per-player controller UI-model string
// channel `player SetControllerUIModelValue("accLevel", "<lvl>|<frac>")` - per-player,
// coop-replicated, ZERO clientfield bits (all three CF pools are full). Read in acc_hud.lua
// by CoD.AccLevel (Engine.CreateModel + subscribeToModel).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_spawner;                                  // register_zombie_death_event_callback
#using scripts\zm\_zm;                                          // register_player_damage_callback (Flawless-round detection)
#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;         // hud_msg / log

#define ACC_LVL_MAX             10
#define ACC_LVL_XP_STEP         75    // xp_to_next(l) = STEP * (l + 1)  (well-defined at LV0). HALVED
                                      // 150 -> 75 (user 2026-07-22 "too grindy"): LV10 = 4,125 XP total
                                      // (was 8,250) ~= reachable around round 20-25 for an engaged player.

// ---- XP SOURCES (all tunable; 2026-07-21 RISK/SKILL retune, docs/45 4). The prior economy let a
//      maxed-Exo player AFK-farm passive trench dwell to LV10; this retune rewards FIGHTING deep,
//      precision, survival, and boss commitment instead of presence. Camp gating = MODERATE. ----
#define ACC_LVL_XP_BOSS             250   // boss pool = this x players-in-game (4a)
#define ACC_LVL_BOSS_FLOOR_PCT      20    // % of the boss pool split EVENLY among damage-dealers; the rest by damage share (co-op fairness, user 2026-07-21)
#define ACC_LVL_XP_BRUTUS_KILLER    100   // finisher on the REAL Trench Warden (the commit-gated marquee risk)

#define ACC_LVL_XP_KILL             1     // base body kill (was 2 - dropped so risk/skill kills stand out)
#define ACC_LVL_XP_HS_KILL          2     // + on a bullet HEADSHOT kill (skill)
#define ACC_LVL_XP_DEEP_KILL_LAYER  1     // + x killer's trench layer, ANY kill made at depth (risk)

#define ACC_LVL_XP_TRENCH_BASE      3     // x layer, per dwell tick (was 6). Now combat-gated + per-round capped.
#define ACC_LVL_TRENCH_COMBAT_MS    8000  // dwell pays ONLY if you killed / took a hit within this window (kills the AFK farm)
#define ACC_LVL_TRENCH_ROUND_CAP    60    // max dwell XP banked per round (bounds the depth runaway)

#define ACC_LVL_XP_ROUND_BASE       15    // survive a round (was 25)
#define ACC_LVL_XP_ROUND_SPEED      75    // max fast-clear bonus (was 50). FORFEIT if you went down this round.
#define ACC_LVL_XP_ROUND_DEEP_LAYER 5     // + x DEEPEST layer you reached this round (risk)
// FAST-CLEAR is measured against the round's OWN spawn-limited FLOOR, not a hand-guessed par (user
// 2026-07-21 "fast clear is tough - check how zombies spawn"). Zombies can't be killed before they
// spawn, so floor = level.zombie_total (this round's count, captured at round start) x the spawn
// delay (level.zombie_vars["zombie_spawn_delay"]). ratio = active-clear-time / floor (>= 1; ~1 =
// killed as fast as they spawned = perfect). This AUTO-adapts to round, player count, and this map's
// custom spawn density (ai_limit 50, spawn-delay x0.85) - no per-round guessing.
#define ACC_LVL_ROUND_BREATHER      13    // ~sec of between-round breather in the measured cycle (subtracted -> active clear time)
#define ACC_LVL_ROUND_RATIO_FULL    150   // active/floor ratio x100: at/below 1.50x = FULL speed bonus (aggressive clear)
#define ACC_LVL_ROUND_RATIO_ZERO    350   // at/above 3.50x the spawn floor (dragged out / camped) = ZERO bonus

#define ACC_LVL_XP_FLAWLESS         15    // took ZERO enemy damage this round AND >= MIN_KILLS (defensive mastery) (user 2026-07-21: 40 -> 15)
#define ACC_LVL_FLAWLESS_MIN_KILLS  8
#define ACC_LVL_XP_NODOWN_MILESTONE 75    // never downed all game, each milestone round (run-long consistency)
#define ACC_LVL_NODOWN_FIRST        10
#define ACC_LVL_NODOWN_EVERY        5

// ---- OBJECTIVE / ELITE XP (added 2026-07-22, broaden the earn surface; amounts sized by frequency+risk) ----
#define ACC_LVL_XP_ELITE_RIOT       10    // Riot/Shielded elite kill (recurring priority brute)
#define ACC_LVL_XP_ELITE_GLITCH     12    // Glitch Stalker mini-boss kill (every round, 1-3x)
#define ACC_LVL_XP_ELITE_FURY       30    // Apothicon Fury kill (12x HP, deep-trench only; rare + tanky)
#define ACC_LVL_XP_REACTOR_ARMER    100   // Reactor Surge: the armer who held the pit through the 5-wave gauntlet
#define ACC_LVL_XP_REACTOR_CREW     40    //   ...each other player alive + underground at the end (3-round cooldown = no farm)
#define ACC_LVL_XP_PER_SOUL         1     // +1 per soul you bank in the abyss (user 2026-07-22; bounded by gate quotas)
#define ACC_LVL_XP_PARADISE_WIN     250   // survive + WIN the Paradise onslaught (marquee once-per-run capstone)
#define ACC_LVL_XP_DOOR             30    // open a buyable door (one-time per door; progression into new danger) (user 2026-07-22: 15 -> 30)

#precache( "lui_menu_data", "accLevel" );
#precache( "fx", "zombie/fx_aat_fireworks_burst_zmb" );   // level-up burst (stock AAT "Fireworks" pop). Zone-listed too (fx, line).
#precache( "fx", "zombie/fx_aat_fireworks_zmb" );         // LV10 capstone: the bigger full fireworks. Zone-listed too.

#namespace acc_leveling;

// ---------------------------------------------------------------------------
// THE single on/off point for the whole leveling feature. DISABLED (user 2026-07-24: "disable for
// now, dev and non-dev") - with `false` here the ENTIRE system is inert everywhere: init() registers
// nothing (no hooks/HUD pushes/callbacks, so the LV chip never shows), every grant_* no-ops, and the
// exo/overclock purchase gates short-circuit (tiers buyable ungated, exactly as pre-leveling).
// History: dev-only Jul 20-21 (returned IS_TRUE(level.acc_dev)) -> LIVE Jul 22 (returned true) ->
// OFF Jul 24. To re-enable: return true (or IS_TRUE(level.acc_dev) for dev-only testing).
// ---------------------------------------------------------------------------
function is_active()
{
    return false;
}

// Safe per-player level read for the gate call sites (returns 0 if state not yet inited -
// never compares against undefined, which throws in T7 GSC).
function player_level( player )
{
    if ( !isdefined( player ) || !isdefined( player.acc_level ) )
        return 0;
    return player.acc_level;
}

// XP required to advance FROM `lvl` to lvl+1. `lvl+1` keeps it > 0 at LV0.
function xp_to_next( lvl )
{
    return ACC_LVL_XP_STEP * ( lvl + 1 );
}

function init()
{
    // Single on/off point (is_active). When off, the module registers NOTHING (no hooks, no HUD, no
    // callbacks) and every grant/gate is inert - so re-gating behind dev is a one-line is_active() flip.
    if ( !is_active() )
        return;

    // Level-up celebration FX = the stock AAT "Fireworks" burst (a colorful firework pop, a REWARD
    // beat - not one of the map's ambient glows, user 2026-07-21). LV10 capstone uses the bigger
    // full-fireworks. Registered for play_fx_burst.
    level._effect[ "acc_levelup_fx" ]     = "zombie/fx_aat_fireworks_burst_zmb";
    level._effect[ "acc_levelup_max_fx" ] = "zombie/fx_aat_fireworks_zmb";

    // Self-register hooks HERE (not in acc_main's shared fan-out) so ship stays clean/inert.
    callback::on_connect( &on_player_connect );
    callback::on_spawned( &on_player_spawned );
    zm_spawner::register_zombie_death_event_callback( &on_zombie_killed );
    zm::register_player_damage_callback( &on_leveling_player_damaged );   // Flawless-round + combat-recency (never alters damage)
    level thread round_xp_listener();
    level thread capture_round_zombie_total();   // snapshot each round's zombie count for the fast-clear floor

    acc_utility::log( "leveling ON (dev): LV0-" + ACC_LVL_MAX + ", caps overclock+exo tiers" );
}

// ---------------------------------------------------------------------------
// Per-player state + HUD
// ---------------------------------------------------------------------------
function ensure_state( player )
{
    // COOP CRASH GUARD (mirrors acc_data_shards::grant_player): a mid-game join can hit a
    // grant before on_connect ran, so every entry point that touches the fields inits first.
    if ( !isdefined( player.acc_level ) )       player.acc_level = 0;
    if ( !isdefined( player.acc_xp ) )          player.acc_xp    = 0;
    if ( !isdefined( player.acc_lvl_gain ) )    player.acc_lvl_gain = 0;      // XP amount of the CURRENT push only (drives the "+N XP" floater; zeroed right after the grant push)
    if ( !isdefined( player.acc_lvl_push_id ) ) player.acc_lvl_push_id = 0;   // bumped on EVERY push so the payload string is always unique (see push_level_hud)
    // risk/skill trackers (2026-07-21 retune)
    if ( !isdefined( player.acc_lvl_last_combat ) )      player.acc_lvl_last_combat = 0;       // GetTime() of last kill / hit taken (trench-dwell combat gate)
    if ( !isdefined( player.acc_lvl_trench_round ) )     player.acc_lvl_trench_round = 0;       // dwell XP banked this round (per-round cap)
    if ( !isdefined( player.acc_lvl_round_deepest ) )    player.acc_lvl_round_deepest = 0;      // deepest trench layer reached this round (risk bonus)
    if ( !isdefined( player.acc_lvl_round_kills ) )      player.acc_lvl_round_kills = 0;        // non-surge kills this round (Flawless min-kills gate)
    if ( !isdefined( player.acc_lvl_round_downs_start ) )player.acc_lvl_round_downs_start = 0;  // player.downs snapshot at round start (down-this-round check)
    if ( !isdefined( player.acc_lvl_took_enemy_dmg ) )   player.acc_lvl_took_enemy_dmg = false; // took enemy damage this round (Flawless flag)
}

function on_player_connect()
{
    self endon( "disconnect" );
    ensure_state( self );
    self push_level_hud();
}

function on_player_spawned()
{
    self endon( "disconnect" );
    ensure_state( self );
    self.acc_lvl_gain = 0;                     // never replay a stale "+N XP" floater into a fresh menu
    self push_level_hud();                     // immediate (covers an already-open menu)
    self thread repush_level_hud_per_life();   // re-push across the acc_hud close/reopen window
}

// WHY THIS EXISTS: _acc_lui::player_lui_init CLOSES + REOPENS acc_hud after EACH spawn, and a value
// pushed BEFORE that reopen does not paint into the fresh menu - which is exactly why _acc_lui
// re-threads its own watch loops (round ring / perk bar) per life. We are a separate module, so we
// mirror it. TIMING FIX (user 2026-07-20 "it only shows after first kill"): the menu opens 0.5s
// after the "initial_blackscreen_passed" FLAG, not after spawn - on the INITIAL spawn that flag is
// still seconds away when spawned_player fires, so a post-spawn-anchored window fired
// every push before the menu even existed (the first kill's grant_xp push was the first to land).
// Anchor on the flag like _acc_lui itself does: on respawns the flag is already set, wait_till
// returns instantly, and the window brackets the reopen either way. Self-cancels the prior life's
// re-pusher so the threads never stack.
function repush_level_hud_per_life()
{
    self endon( "disconnect" );
    self notify( "acc_lvl_repush" );
    self endon( "acc_lvl_repush" );

    level flag::wait_till( "initial_blackscreen_passed" );   // menu opens ~0.5s+0.1s after this

    for ( i = 0; i < 6; i++ )
    {
        wait 0.5;              // 0.5 .. 3.0s past the flag brackets the reopen + client settle
        self push_level_hud();
    }
}

// self = player. Publishes "<lvl>|<frac>|<gain>|<push_id>" to the accLevel controller UI-model.
//
// push_id makes EVERY push a UNIQUE string - this is load-bearing, not cosmetic (user 2026-07-21
// "UI still doesn't show when no XP is given yet"): the model only DELIVERS on a value CHANGE,
// and a freshly (re)opened acc_hud menu reads no construction-time value from a client-created
// controller-model node. So identical re-pushes ("0|0|0" over and over) never painted the fresh
// menu - the first XP grant was the first push that actually CHANGED the string, which is exactly
// the "only shows after first kill" symptom. With push_id stamped per push, every re-push in the
// per-life window is a change event and the chip paints at LV0/no-XP.
//
// gain = the XP amount of THIS push only (the "+N XP" floater). grant_xp zeroes it right after
// its push, so re-pushes/spawn pushes carry 0 and a fresh menu never replays a stale floater
// (the widget also keys the flash on gain>0 AND a new push_id).
function push_level_hud()
{
    ensure_state( self );

    frac = 0;
    if ( self.acc_level >= ACC_LVL_MAX )
    {
        frac = 1;
    }
    else
    {
        need = xp_to_next( self.acc_level );
        if ( need > 0 )
            frac = self.acc_xp / need;   // int/int -> float 0..1
    }
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;

    self.acc_lvl_push_id++;   // unique string per push (see header) - never remove this
    self SetControllerUIModelValue( "accLevel",
        self.acc_level + "|" + frac + "|" + self.acc_lvl_gain + "|" + self.acc_lvl_push_id );
}

// self = player. Level-up ack: HUD toast + a 3D WORLD sound + a white sparkle burst on the player
// (user 2026-07-21). Both the sound and the FX emanate from the player's position so NEARBY players
// perceive the level-up too. Stays wait-free (grant_xp runs on the wait-free round path): hud_msg
// threads its own fade, PlaySoundAtPosition is a non-blocking broadcast, and the FX is threaded off
// `level` (play_fx_burst waits its lifetime internally + spawns its own host, so it must not run inline).
function level_up_feedback()
{
    b_max = ( self.acc_level >= ACC_LVL_MAX );

    // LV10 = "Fully Augmented" PRESTIGE capstone (user 2026-07-21: pure-gating rewards + a payoff
    // moment, no power grants). A distinct toast + the bigger full-fireworks + the sound.
    if ( b_max )
        self acc_utility::hud_msg( "^5FULLY AUGMENTED^7 - Level " + ACC_LVL_MAX + " MAX" );
    else
        self acc_utility::hud_msg( "^5LEVEL UP^7 - Level " + self.acc_level );

    // 3D positional one-shot broadcast to all clients (the PlaySoundAtPosition idiom _acc_damage
    // uses for the Riot clang). Alias acc_level_up -> sound/aliases/acc_audio.csv (+1.5dB re-encode).
    PlaySoundAtPosition( "acc_level_up", self.origin );

    // CELEBRATION FX = the stock AAT "Fireworks" (a colorful firework pop, "not just a white glow").
    // `level thread` mirrors the derez_burst call site (play_fx_burst waits its lifetime + spawns its
    // own host, so it must not run inline on the wait-free grant path). Height/life tunable.
    fx_key  = ( b_max ? "acc_levelup_max_fx" : "acc_levelup_fx" );
    fx_life = ( b_max ? 2.5 : 1.5 );
    level thread acc_utility::play_fx_burst( fx_key, self.origin + ( 0, 0, 52 ), fx_life );
}

// ---------------------------------------------------------------------------
// PUBLIC: grant XP to a player. Free function (mirrors acc_data_shards::grant_player). Safe
// to call from anywhere/anytime - self-guards on dev and inits state.
// ---------------------------------------------------------------------------
function grant_xp( player, amount, source_tag )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !isdefined( amount ) || amount <= 0 ) return;
    if ( !is_active() ) return;   // system off -> no XP (init also gates; belt + suspenders)

    ensure_state( player );
    if ( player.acc_level >= ACC_LVL_MAX )
        return;   // capped; ignore further XP (no floater either - nothing was gained)

    player.acc_xp += amount;
    player.acc_lvl_gain = amount;   // this push carries the gain -> the widget flashes "+N XP"

    leveled = false;
    while ( player.acc_level < ACC_LVL_MAX && player.acc_xp >= xp_to_next( player.acc_level ) )
    {
        player.acc_xp -= xp_to_next( player.acc_level );
        player.acc_level += 1;
        leveled = true;
    }
    if ( player.acc_level >= ACC_LVL_MAX )
        player.acc_xp = 0;   // clamp the remainder once maxed (bar reads full)

    if ( leveled )
        player level_up_feedback();

    player push_level_hud();
    player.acc_lvl_gain = 0;   // only the grant push carries the amount - any later push (spawn/
                               // re-open re-push, which now always delivers via push_id) must not
                               // re-flash a stale "+N XP"
}

// ---------------------------------------------------------------------------
// Convenience grants for the EXTERNAL hook sites (_acc_boss, _acc_bus_trench). #define is
// file-local in this GSC dialect, so these keep the XP amounts owned by this module - the
// call sites never spell a magic number.
// ---------------------------------------------------------------------------
function grant_boss_xp( player )
{
    grant_xp( player, ACC_LVL_XP_BOSS, "boss" );
}

// Finisher bonus for landing the kill on the REAL Trench Warden Brutus - who is damage-immune
// unless you commit into the trench with him, so this can ONLY be earned by taking the map's
// marquee risk (user 2026-07-21). Caller (_acc_boss::watch_mini_boss_death) already excludes the
// Paradise Brutus (no_reward path).
function grant_brutus_killer_xp( player )
{
    grant_xp( player, ACC_LVL_XP_BRUTUS_KILLER, "brutus_kill" );
}

// Objective / elite XP wrappers (added 2026-07-22). #define is file-local, so external hook sites
// (elites, glitch, reactor, abyss doors, paradise, entry-script doors) call these instead of literals.
function grant_elite_xp( player, kind )   // kind: "riot" | "glitch" | "fury"
{
    amt = ACC_LVL_XP_ELITE_RIOT;
    if ( kind == "glitch" )    amt = ACC_LVL_XP_ELITE_GLITCH;
    else if ( kind == "fury" ) amt = ACC_LVL_XP_ELITE_FURY;
    grant_xp( player, amt, "elite_" + kind );
}

function grant_reactor_xp( player, is_armer )
{
    grant_xp( player, ( IS_TRUE( is_armer ) ? ACC_LVL_XP_REACTOR_ARMER : ACC_LVL_XP_REACTOR_CREW ), "reactor" );
}

function grant_soul_xp( player, n_souls )   // +1 XP per soul banked
{
    if ( !isdefined( n_souls ) || n_souls < 1 ) n_souls = 1;
    grant_xp( player, ACC_LVL_XP_PER_SOUL * n_souls, "soul" );
}

function grant_paradise_win_xp( player )
{
    grant_xp( player, ACC_LVL_XP_PARADISE_WIN, "paradise_win" );
}

function grant_door_xp( player )
{
    grant_xp( player, ACC_LVL_XP_DOOR, "door" );
}

// Boss-kill XP, DAMAGE-WEIGHTED (user 2026-07-21: "XP points on bosses is distributed by damage
// allocation... proportional"). a_contrib = the dying boss's acc_damage_contrib ledger - the
// EXISTING per-victim damage tracker _acc_points::record_damage maintains on every damage path
// (final post-multiplier damage, players only, capped at maxhealth per player) - captured by the
// death watcher BEFORE the corpse is reaped. Pool = ACC_LVL_XP_BOSS x DAMAGE-DEALERS (solo unchanged
// at 250; a non-participant's slice lapses, never transfers), split 20% even floor + 80% by damage.
// Returns true if shares were paid; false = no usable ledger (e.g. scripted/ally kill recorded no
// player damage, or ship where XP is off) -> the caller falls back to the flat per-player grant.
function grant_boss_xp_shares( a_contrib )
{
    if ( !is_active() ) return false;   // system off -> caller's flat fallback (also inert via grant_xp)
    if ( !isdefined( a_contrib ) || a_contrib.size <= 0 ) return false;

    keys = GetArrayKeys( a_contrib );

    // Collect the valid contributors once (re-verify player + damage, record_damage's own rule).
    contribs = [];
    total = 0;
    for ( i = 0; i < keys.size; i++ )
    {
        rec = a_contrib[ keys[ i ] ];
        if ( isdefined( rec ) && isdefined( rec.damage ) && rec.damage > 0
             && isdefined( rec.player ) && isplayer( rec.player ) )
        {
            contribs[ contribs.size ] = rec;
            total += rec.damage;
        }
    }
    if ( total <= 0 || contribs.size <= 0 ) return false;

    // PARTICIPATION FLOOR (user 2026-07-21 co-op fairness): FLOOR_PCT of the pool is split EVENLY
    // among everyone who dealt any damage; the rest stays DAMAGE-WEIGHTED. So a high-DPS carry still
    // earns most, but a revive/support teammate who chipped in isn't starved of the augmentation
    // ceiling. Solo: floor + weighted both go to the one player = the whole pool (unchanged at 250).
    // Pool is sized by DAMAGE-DEALERS, not all connected players (adversarial-review fix 2026-07-21):
    // a non-participant's 250 slice simply LAPSES - it never transfers, so soloing a boss in a
    // 4-player game pays the solo value (250), not a 4x windfall.
    pool          = ACC_LVL_XP_BOSS * contribs.size;
    floor_pool    = int( pool * ACC_LVL_BOSS_FLOOR_PCT / 100 );
    weighted_pool = pool - floor_pool;
    floor_each    = int( floor_pool / contribs.size );

    for ( i = 0; i < contribs.size; i++ )
    {
        rec = contribs[ i ];
        // Divide FIRST (damage/total is a 0..1 float) then scale by the small pool, so the
        // intermediate never overflows int32 (a high-round boss's capped damage is in the millions).
        share = floor_each + int( weighted_pool * ( rec.damage / total ) );
        if ( share > 0 )
            grant_xp( rec.player, share, "boss" );
    }
    return true;
}

// Trench-dwell XP - now REWARDS FIGHTING DEEP, not standing deep (user 2026-07-21 review). Two guards
// close the old maxed-Exo AFK farm: (1) a COMBAT GATE - you must have killed or taken a hit within
// ACC_LVL_TRENCH_COMBAT_MS, else a safe pocket pays nothing; (2) a PER-ROUND CAP so depth is a bonus,
// not an unbounded runaway. Still deeper = more (x layer). Called each dwell tick from _acc_bus_trench.
function grant_trench_xp( player, layer )
{
    if ( !isdefined( layer ) || layer < 1 ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !is_active() ) return;   // grant_xp also guards; early-out before the field reads
    ensure_state( player );

    // (1) combat recency - no fighting here lately => no dwell XP (kills the standing-still farm)
    if ( GetTime() - player.acc_lvl_last_combat > ACC_LVL_TRENCH_COMBAT_MS ) return;

    // (2) per-round cap - dwell tops up, it doesn't carry the run
    if ( player.acc_lvl_trench_round >= ACC_LVL_TRENCH_ROUND_CAP ) return;
    amount = ACC_LVL_XP_TRENCH_BASE * layer;
    room = ACC_LVL_TRENCH_ROUND_CAP - player.acc_lvl_trench_round;
    if ( amount > room ) amount = room;

    player.acc_lvl_trench_round += amount;
    grant_xp( player, amount, "trench" );
}

// ---------------------------------------------------------------------------
// XP source: zombie kills (own additive death callback; no edit to _acc_points). self = zombie.
// ---------------------------------------------------------------------------
function on_zombie_killed( attacker )
{
    if ( !isdefined( attacker ) || !isplayer( attacker ) )
        return;
    ensure_state( attacker );

    // Any kill counts as "in combat" (unlocks trench dwell XP - see grant_trench_xp).
    attacker.acc_lvl_last_combat = GetTime();

    // Killer's DEPTH (risk). Read the maintained trench-layer field directly (set by the bus_trench
    // watcher) so we need NO #using of _acc_bus_trench (which already #uses us - avoids a using cycle).
    layer = ( isdefined( attacker.acc_trench_layer ) ? attacker.acc_trench_layer : 0 );
    if ( layer > attacker.acc_lvl_round_deepest )
        attacker.acc_lvl_round_deepest = layer;

    // Surge/drip zombies used to be SKIPPED for XP; now they PAY (surviving the trench's threat IS
    // the risk, user 2026-07-21) - but they do NOT count toward the round-kill tally (they're excluded
    // from the round count by design, so they must not inflate the Flawless min-kills gate).
    is_surge = ( isdefined( self.acc_trench_zombie ) && self.acc_trench_zombie );
    if ( !is_surge )
        attacker.acc_lvl_round_kills++;

    xp = ACC_LVL_XP_KILL;                       // base
    xp += ACC_LVL_XP_DEEP_KILL_LAYER * layer;   // + risk: killed at depth
    if ( is_bullet_headshot( self ) )           // + skill: precision
        xp += ACC_LVL_XP_HS_KILL;

    grant_xp( attacker, xp, "kill" );

    // Apothicon Fury (12x-HP deep-trench elite) routes through this normal death callback and is tagged
    // acc_is_fury at spawn (_acc_fury.gsc). Additive elite bonus on top of the base kill. Skip the
    // no-reward gauntlet variants (reactor/paradise threat spawns) so they can't be farmed.
    if ( IS_TRUE( self.acc_is_fury ) && !IS_TRUE( self.acc_no_shard_reward ) )
        grant_elite_xp( attacker, "fury" );
}

// Was the killing blow a BULLET headshot? Melee never headshots on this map, and shotguns / wonder
// weapons are headshot-excluded by design - a plain bullet head/neck hit is the precision signal.
function is_bullet_headshot( zombie )
{
    if ( !isdefined( zombie.damagelocation ) || !isdefined( zombie.damagemod ) )
        return false;
    if ( zombie.damagemod != "MOD_RIFLE_BULLET" && zombie.damagemod != "MOD_PISTOL_BULLET" )
        return false;
    loc = zombie.damagelocation;
    return ( loc == "head" || loc == "helmet" || loc == "neck" );
}

// ---------------------------------------------------------------------------
// XP source: round survival, scaled by CLEAR SPEED (the anti-camping lever). Fast clear ->
// bonus up to ACC_LVL_XP_ROUND_SPEED; camping past par -> BASE only. docs/45 4c.
//
// Timing: acc_round_end(N) fires at the START of round N+1 (emitted just before
// acc_round_start(N+1) in _acc_main), so the measured span is the full round-N cycle
// (active phase + between-round breather). It is consistent per round; par accounts for it.
// ---------------------------------------------------------------------------
function round_xp_listener()
{
    level endon( "end_game" );

    for ( ;; )
    {
        level waittill( "acc_round_start", rn );
        start_ms   = GetTime();
        this_round = rn;
        reset_round_trackers();   // snapshot downs + clear per-round risk/skill state for all players

        level waittill( "acc_round_end", prev_round );
        // KEEP THIS AWARD PATH WAIT-FREE. _acc_main emits acc_round_end THEN acc_round_start
        // back-to-back on one start_of_round; T7 notify runs waiters synchronously to their next
        // suspension, so we re-park on acc_round_start (loop top) before it fires - that is the only
        // reason no round is missed. If grant_xp / push_level_hud / level_up_feedback ever gains a
        // `wait`, this listener would suspend here and MISS the very next acc_round_start, silently
        // desyncing all later round-XP pairing. Currently every call in the chain is wait-free.
        award_round_survival_xp( this_round, GetTime() - start_ms );
    }
}

// Snapshot each round's TOTAL zombie count for the fast-clear floor. Stock notifies "zombie_total_set"
// the instant it sets level.zombie_total = get_zombie_count_for_round(...) (_zm.gsc:3717-3719), BEFORE
// the spawn loop decrements it - so a parked listener reads the full round count. (Reading it later is
// wrong: level.zombie_total counts DOWN as zombies spawn.) On a special/boss round that doesn't fire
// the notify, we keep the last value; the award guards a 0 as "no speed bonus".
function capture_round_zombie_total()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "zombie_total_set" );
        if ( isdefined( level.zombie_total ) )
            level.acc_lvl_round_zombie_total = level.zombie_total;
    }
}

// Round-survival XP, now INDIVIDUAL + risk/skill-weighted (user 2026-07-21 review). Each player gets:
// base + (clear-speed bonus, forfeited if you went down) + (deepest-layer risk bonus) + (Flawless
// bonus) + (no-down streak milestone). A safe-corner hider or a carried player no longer collects the
// same as an L5 diver who stayed up.
function award_round_survival_xp( round_num, dur_ms )
{
    // FAST-CLEAR vs the round's spawn-limited FLOOR (see the #defines). active = measured cycle minus
    // the between-round breather; floor = this round's zombie count x the spawn delay (the soonest the
    // round CAN end). ratio = active/floor (>= 1). Full bonus at ratio <= RATIO_FULL, zero at >= ZERO.
    active = ( dur_ms - ACC_LVL_ROUND_BREATHER * 1000 ) / 1000;   // seconds of active killing
    if ( active < 1 ) active = 1;

    n_total   = ( isdefined( level.acc_lvl_round_zombie_total ) ? level.acc_lvl_round_zombie_total : 0 );
    delay     = ( isdefined( level.zombie_vars ) && isdefined( level.zombie_vars[ "zombie_spawn_delay" ] ) ? level.zombie_vars[ "zombie_spawn_delay" ] : 1.0 );
    floor_sec = n_total * delay;   // spawn-limited minimum clear time

    speed_frac = 0;
    if ( floor_sec > 1 )
    {
        ratio_x100 = int( active * 100 / floor_sec );   // (active / floor) x100
        if ( ratio_x100 <= ACC_LVL_ROUND_RATIO_FULL )
            speed_frac = 1;
        else if ( ratio_x100 < ACC_LVL_ROUND_RATIO_ZERO )
            speed_frac = ( ACC_LVL_ROUND_RATIO_ZERO - ratio_x100 ) / ( ACC_LVL_ROUND_RATIO_ZERO - ACC_LVL_ROUND_RATIO_FULL );
        // else camped -> speed_frac stays 0
    }
    speed_bonus = int( ACC_LVL_XP_ROUND_SPEED * speed_frac );   // clear-speed (skill), team metric

    is_nodown_milestone = ( round_num >= ACC_LVL_NODOWN_FIRST
                            && ( ( round_num - ACC_LVL_NODOWN_FIRST ) % ACC_LVL_NODOWN_EVERY ) == 0 );

    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        ensure_state( p );

        xp = ACC_LVL_XP_ROUND_BASE;

        // SPEED bonus, but only if YOU stayed up (a downed / carried player forfeits the skill bonus)
        downs_now = ( isdefined( p.downs ) ? p.downs : 0 );
        downed_this_round = ( downs_now > p.acc_lvl_round_downs_start );
        if ( !downed_this_round )
            xp += speed_bonus;

        // RISK: how DEEP you spent the round (deepest layer reached)
        xp += ACC_LVL_XP_ROUND_DEEP_LAYER * p.acc_lvl_round_deepest;

        // FLAWLESS: took ZERO enemy damage this round AND actually fought (min kills). Intentional
        // risk-damage (fall tax, Berzerker/PhD self-damage) never sets the flag, so committing to
        // risk does not break flawless.
        if ( !IS_TRUE( p.acc_lvl_took_enemy_dmg ) && p.acc_lvl_round_kills >= ACC_LVL_FLAWLESS_MIN_KILLS )
            xp += ACC_LVL_XP_FLAWLESS;

        // NO-DOWN STREAK: never downed the whole game, crossing a milestone round (run-long consistency)
        if ( is_nodown_milestone && downs_now == 0 )
            xp += ACC_LVL_XP_NODOWN_MILESTONE;

        grant_xp( p, xp, "round" );
    }
}

// Snapshot / clear the per-round risk+skill trackers at the START of each round, for every player.
function reset_round_trackers()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        ensure_state( p );
        p.acc_lvl_round_downs_start = ( isdefined( p.downs ) ? p.downs : 0 );
        p.acc_lvl_round_deepest     = ( isdefined( p.acc_trench_layer ) ? p.acc_trench_layer : 0 );
        p.acc_lvl_round_kills       = 0;
        p.acc_lvl_took_enemy_dmg    = false;
        p.acc_lvl_trench_round      = 0;
    }
}

// Registered via zm::register_player_damage_callback (init, dev-only). Runs ON the damaged player
// (self). Sets the Flawless flag + combat-recency ONLY on ENEMY (axis AI) damage - so the trench fall
// tax (MOD_FALLING), Berzerker/PhD self-damage, and any ally source do NOT break flawless or count as
// combat. MUST return -1 (never alters damage): the first non -1 return in the chain would starve god
// mode (memory player-damage-callbacks-return-minus-one).
function on_leveling_player_damaged( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
    if ( isdefined( iDamage ) && iDamage > 0
         && isdefined( eAttacker ) && isdefined( eAttacker.team ) && eAttacker.team == "axis" )
    {
        ensure_state( self );
        self.acc_lvl_took_enemy_dmg = true;
        self.acc_lvl_last_combat    = GetTime();   // taking a hit counts as fighting (trench dwell gate)
    }
    return -1;
}
