// =============================================================================
// _acc_lockdown_challenge.gsc - the per-round lockdown CHALLENGE room (Phase A).
//
// Full design + the adversarial-verified fixes: docs/26_lockdown_challenge_room.md.
//
// Each round _acc_lockdown lights ONE of 4 rooms RED (Vault / Alley / Helipad=roof_zone /
// Market) and notifies "acc_lockdown_room_lit". This module turns the lit room into a TRAP:
// walk into the DEFCON room and it's game time - the room commits, the outside horde is stopped
// from spawning inside, and a CONFINED wave of 30 Glitch Stalkers spawns. Kill all 30 -> the
// room clears and drops a free-for-all random boss-item. It stays committed ACROSS ROUNDS until
// cleared (the _acc_lockdown rotation pauses while level.acc_ldc_active is set).
//
// "SEPARATE GAME" isolation is FREE: every challenge glitch already has ignore_enemy_count=true
// (set by _acc_boss_glitch::spawn_glitch), so it is invisible to the round-end count AND the
// round's spawn budget. We track our OWN private kill counter (level.acc_ldc_killed), never the
// stock zombie_total. The shared cost is only the engine ACTOR pool -> capped concurrent.
//
// CONTAINMENT (all GSC-only, NO geometry, -GscOnly, zero LED risk):
//  - Outside horde: disable_zone_spawning stops risers inside the sealed room.
//  - Glitch wave: blink/charge teleports are clamped in-room + a 1Hz yank-back (_acc_boss_glitch
//    ldc_in_room / ldc_random_anchor_nav / ldc_keep_in_room), and SetGoal pins them.
//  - Players: the HARD lock-in re-CLOSES the room's 2 stock buyable border doors via the stock
//    crush-safe close (door_activate open=false -> slides the door back DOWN, solid only when the
//    doorway is player-clear). No acc_seal_<zone> brushes were ever authored (the move-door reuse
//    sidesteps the Radiant/LED-bake risk entirely). See the seal section for the move-door detail.
//    UN-BOUGHT border doors (seal_room leaves them - they're already solid walls) keep their BUY
//    trigger live, so a sealed-in player could buy one and walk out (escape bug, user 2026-06-25);
//    is_door_sealed() lets the buyable-door loop refuse those purchases while the purge is active.
//
// Live knobs: acc_lockdown_challenge_on (0 = HARDCODE-DISABLED default, user 2026-07-04 - the whole Glitch
//   Purge is OFF in every version until you `+set acc_lockdown_challenge_on 1`) / _total (50) / _concurrent (8) / _stagger (0.6) /
// _stagger_initial (0.3, fast fill at start) / _grace (1.5) / _confine (0) / acc_lockdown_reward (1) /
// _challenge_debug (0) / _challenge_force "<zone>" (dev start without the trap). Seal: acc_lockdown_lock_doors (1).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\ai\zombie_utility;

#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lockdown;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_glitch;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_decontamination;
#using scripts\zm\zm_abandoned_cyber_city\_acc_health_bars;

#insert scripts\shared\shared.gsh;   // IS_TRUE macro (used below; was missing -> xref lint fail 2026-06-24)

#define ACC_LDC_TOTAL_DEF       0     // FIXED purge-count override; 0 = AUTO = current round x ACC_LDC_ROUND_MULT (user 2026-06-23, was 15/40/50)
#define ACC_LDC_ROUND_MULT_DEF  2.0   // AUTO purge count = current round x this (acc_lockdown_challenge_mult); 2x round (user 2026-06-23, was 2.5); e.g. r10 -> 20, r20 -> 40
#define ACC_LDC_CONCURRENT_DEF  8     // glitches on-screen at once = the purge's aggression lever (user 2026-06-27: 10->8 = -20% simultaneous-hunter density = -20% purge aggressiveness; history 6->8 "super easy fix", 8->10 denser). Coop self-limits via the producer's GetFreeActorCount gate
#define ACC_LDC_STAGGER_DEF     0.6   // seconds between spawns (was 1.3) - much faster trickle so the room fills quickly at the start (user 2026-06-18)
#define ACC_LDC_GRACE_DEF       1.5
// JOIN WINDOW (user 2026-06-25): seconds the trap stays OPEN after the FIRST player trips it, so teammates can
// pile in before the doors seal. Was instant (one entry sealed everyone else out). Dvar acc_lockdown_challenge_join_window.
#define ACC_LDC_JOIN_WINDOW_DEF 2.0
#define ACC_LDC_BAR_W           170
#define ACC_LDC_BAR_H           11
// ANTI-SOFTLOCK (user 2026-06-24): seconds of ZERO progress (no kill AND no spawn) before the
// stall-watchdog force-resolves a stuck purge. A stuck purge leaves level.acc_ldc_active set, which
// PERMANENTLY blocks every boss spawn (phantom/glitch gate on it) - the "Phantom never came in coop"
// bug. 60s of total silence inside a sealed room is a genuine stall, never a live fight (kills/spawns
// reset the timer). Dvar: acc_lockdown_challenge_stall_sec.
#define ACC_LDC_STALL_SEC       60
// ROUND CAP (user 2026-06-25): force-shut-down a purge that lingers too many ROUNDS, the guaranteed escape
// valve for EVERY stuck-purge bug ("went in, died, the door never opened back up"). TWO tiers so it never robs a
// LEGIT winning fight (audit 2026-06-25): the SOFT cap fires at acc_lockdown_challenge_max_rounds (default 2)
// rounds ONLY IF the purge made no kill in the round that just ended (genuinely stalled - the user's "2 rounds"
// intent applied to stuck purges); the HARD cap fires UNCONDITIONALLY at soft+grace rounds (default 2+4=6) as the
// absolute anti-softlock backstop no fight can ever legitimately exceed. Dvars: acc_lockdown_challenge_max_rounds
// / acc_lockdown_challenge_hard_grace.
#define ACC_LDC_MAX_ROUNDS      2
#define ACC_LDC_HARD_GRACE      4

#namespace acc_lockdown_challenge;

// ---------------------------------------------------------------------------
// Lifecycle
// ---------------------------------------------------------------------------

// Threaded from acc_main::init() AFTER acc_lockdown / acc_boss_glitch / acc_boss_items.
function init()
{
    // Guard vars set FIRST (safe defaults) so every downstream reader of level.acc_ldc_active
    // (_acc_lockdown / _acc_boss_glitch / _acc_boss_phantom / _acc_health_bars / _acc_reactor /
    // _acc_paradise) sees "no purge active" whether or not this system is enabled below.
    level.acc_ldc_active   = undefined;   // the committed challenge zone (guards elsewhere read this)
    level.acc_ldc_teardown = false;
    level.acc_ldc_resolved = false;
    level.acc_ldc_zombies  = [];

    // HARDCODE DISABLED (user 2026-07-04): the Glitch Purge / lockdown challenge is OFF in ALL
    // versions (normal AND dev - this gate is UNCONDITIONAL, not behind level.acc_dev) because it
    // caused too many bugs and needs more testing. Nothing arms: we return BEFORE threading
    // watch_challenge (ambient trap) / watch_force_dvar (dev force) / on_end_game_safety, so no
    // red room ever becomes a trap and no confined Glitch wave ever spawns. The DEFCON room LIGHTS
    // (_acc_lockdown rotation) still rotate as ambient flavor - only the PURGE is dead.
    // RE-ENABLE (explicit opt-in only): launch with `+set acc_lockdown_challenge_on 1`.
    if ( getdvarint( "acc_lockdown_challenge_on", 0 ) != 1 )
    {
        acc_utility::log( "lockdown challenge (GLITCH PURGE): HARDCODE DISABLED - not armed in any version (set acc_lockdown_challenge_on 1 to re-enable)" );
        return;
    }

    level thread watch_challenge();
    level thread on_end_game_safety();

    // Dev: acc_lockdown_challenge_force "<zone>" force-starts a challenge without the trap.
    level thread watch_force_dvar();
}

// Arm the trap whenever a room lights red. One challenge at a time (level.acc_ldc_active).
function watch_challenge()
{
    level endon( "end_game" );
    for ( ;; )
    {
        level waittill( "acc_lockdown_room_lit", zone );
        if ( getdvarint( "acc_lockdown_challenge_on", 0 ) != 1 ) continue;   // default OFF (hardcode-disabled, user 2026-07-04); re-enable = acc_lockdown_challenge_on 1
        if ( isdefined( level.acc_ldc_active ) ) continue;
        level thread arm_trap( zone );
    }
}

// ---------------------------------------------------------------------------
// Trap (ambient catch - decision #2)
// ---------------------------------------------------------------------------

function arm_trap( zone )
{
    level endon( "end_game" );

    // Grace: let anyone already standing in the room when it lit bolt out before it arms.
    wait( getdvarfloat( "acc_lockdown_challenge_grace", ACC_LDC_GRACE_DEF ) );

    volumes = acc_decontamination::get_zone_volumes( zone );

    for ( ;; )
    {
        // Disarm if the room is no longer the active lit room (the rotation moved on) or a
        // challenge already committed (here or elsewhere).
        if ( !isdefined( level.acc_lockdown_active ) || level.acc_lockdown_active != zone ) return;
        if ( isdefined( level.acc_ldc_active ) ) return;

        party = inside_party( volumes );
        if ( party.size > 0 )
        {
            // JOIN WINDOW (user 2026-06-25): the FIRST player to step in trips the trap, but the doors do NOT
            // seal instantly - hold for acc_lockdown_challenge_join_window seconds so teammates can pile in,
            // THEN re-capture everyone inside and seal that FULL party. Before this, one entry sealed the room
            // immediately and locked the rest of the team out. Guards are re-checked after the wait so a
            // room-rotation / commit-elsewhere mid-window bails cleanly, and an empty room (everyone bolted
            // back out during the window) just re-arms instead of sealing nobody in.
            jw = getdvarfloat( "acc_lockdown_challenge_join_window", ACC_LDC_JOIN_WINDOW_DEF );
            if ( jw > 0 )
            {
                ldc_announce( GetPlayers(), "^1LOCKDOWN SEALING^7 - get in! (" + int( jw ) + "s)" );
                wait( jw );
                if ( !isdefined( level.acc_lockdown_active ) || level.acc_lockdown_active != zone ) return;
                if ( isdefined( level.acc_ldc_active ) ) return;
                party = inside_party( volumes );   // re-capture: whoever is inside NOW is the sealed party
                if ( party.size == 0 ) continue;   // everyone left during the window -> re-arm, don't seal empty
            }
            commit_challenge( zone, party );
            return;
        }

        wait( 0.25 );
    }
}

// Valid players currently inside the room's volume = the committed party.
function inside_party( volumes )
{
    party = [];
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !zm_utility::is_player_valid( p ) ) continue;   // excludes spectators / laststand
        if ( acc_decontamination::player_in_zone_volumes( p, volumes ) )
            party[ party.size ] = p;
    }
    return party;
}

// ---------------------------------------------------------------------------
// Commit + seal
// ---------------------------------------------------------------------------

function commit_challenge( zone, party )
{
    level endon( "end_game" );

    level.acc_ldc_active      = zone;
    level.acc_ldc_killed      = 0;
    level.acc_ldc_spawned     = 0;
    level.acc_ldc_party       = party;
    level.acc_ldc_teardown    = false;
    level.acc_ldc_resolved    = false;
    level.acc_ldc_zombies     = [];
    level.acc_ldc_start_round = ( isdefined( level.round_number ) ? level.round_number : 1 );   // for the hard round-cap watchdog
    level.acc_ldc_total       = ldc_compute_total();   // round x 2 (or fixed override), captured once - can't drift mid-fight

    // CRITICAL (docs/26 §4.1): stop the OUTSIDE horde from RISING inside the sealed room.
    acc_decontamination::disable_zone_spawning( zone );

    // Belt-and-suspenders: nudge the party off any doorway footprint to the room interior BEFORE the
    // doors close, so nobody is standing where a door re-materializes. The stock close is already
    // crush-safe on its own; this is best-effort and SKIPS itself unless it can resolve a proven-safe
    // navmesh point (never SetOrigin to a raw/degenerate centroid that could itself trip the OOB kill).
    relocate_party_safe( zone, party );

    // Phase B SEAL (LED-safe, no new geometry): stock crush-safe CLOSE of the room's 2 buyable border
    // doors (moves them back DOWN into the doorway, solid only when player-clear) + a nav re-assert.
    // The real "doors slam, you're stuck" lock-in.
    seal_room( zone );
    level thread reseal_monitor( zone );

    // Optional belt-and-suspenders soft yank-back (default OFF now the doors seal). acc_lockdown_challenge_confine 1.
    if ( getdvarint( "acc_lockdown_challenge_confine", 0 ) == 1 )
        level thread confine_players( zone );

    ldc_debug( "COMMIT zone=" + zone + " party=" + party.size );

    // Per-inside-player "GLITCH PURGE X/N" HUD (server-side hud::, NOT a clientuimodel field -
    // that pool is full at 64 bits and overflow crashes at load; docs/26 §4.8).
    for ( i = 0; i < party.size; i++ )
    {
        p = party[ i ];
        if ( isdefined( p ) && isplayer( p ) ) p create_challenge_hud();
    }
    // Announce the LIVE total (was hardcoded "30" while the real count was 40 - stale; now always in sync).
    ldc_announce( party, "^1LOCKDOWN ENGAGED^7 - defeat " + ldc_total() + " Glitch Stalkers to escape" );

    level thread challenge_producer( zone );
    level thread watch_fail( zone );
    level thread ldc_stall_watch( zone );   // anti-softlock: resolve a stuck purge so it can't block bosses forever
    level thread ldc_round_cap_watch( zone );   // round-cap backstop: force-shutdown a STALLED purge (user 2026-06-25)
    level thread ldc_release_outside_horde( zone );   // coop: keep the OUTSIDE horde chasing reachable players, not frozen on the sealed-in player
}

// ROUND-CAP WATCHDOG (user 2026-06-25; progress-aware per the 2026-06-25 audit). The guaranteed escape valve for
// any stuck purge, in two tiers so it can NEVER rob a legitimate, still-winning fight:
//   SOFT cap (acc_lockdown_challenge_max_rounds, default 2): once the purge has lasted this many rounds AND it
//     made NO kill during the round that just ended, it is genuinely stalled -> force shutdown. (This is the
//     user's "shut down after ~2 rounds" intent, scoped to STUCK purges - a fight that keeps killing glitches
//     keeps going.) Rounds advance during a purge because the glitches are ignore_enemy_count, so the OUTSIDE
//     wave still ends rounds and level.round_number climbs while we wait.
//   HARD cap (soft + acc_lockdown_challenge_hard_grace, default 2+4=6): fires UNCONDITIONALLY, the absolute
//     anti-softlock backstop no legitimate fight can exceed even at very high rounds.
// challenge_timeout is one-shot guarded (acc_ldc_resolved), so it races the real resolvers harmlessly. Ends with
// the purge (acc_ldc_done).
function ldc_round_cap_watch( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    start = ( isdefined( level.acc_ldc_start_round ) ? level.acc_ldc_start_round
                                                     : ( isdefined( level.round_number ) ? level.round_number : 1 ) );
    cap = getdvarint( "acc_lockdown_challenge_max_rounds", ACC_LDC_MAX_ROUNDS );
    if ( cap < 1 ) cap = 1;
    hard = cap + getdvarint( "acc_lockdown_challenge_hard_grace", ACC_LDC_HARD_GRACE );

    // Per-round kill-progress tracking: remember the kill count at the last round boundary so we can tell whether
    // the purge actually killed anything during the round that just ended.
    last_round         = ( isdefined( level.round_number ) ? level.round_number : start );
    killed_at_boundary = level.acc_ldc_killed;
    killed_last_round  = true;   // assume progress until a full round proves otherwise (don't soft-cap instantly)

    for ( ;; )
    {
        wait( 1 );
        cur = ( isdefined( level.round_number ) ? level.round_number : start );

        if ( cur != last_round )
        {
            killed_last_round  = ( level.acc_ldc_killed != killed_at_boundary );   // did we kill during the round that just ended?
            killed_at_boundary = level.acc_ldc_killed;
            last_round         = cur;
        }

        elapsed = cur - start;

        // HARD backstop: no purge may EVER outlive this, progress or not (the absolute anti-softlock guarantee).
        if ( elapsed >= hard )
        {
            ldc_debug( "round-cap: HARD backstop (" + elapsed + " >= " + hard + " rounds) -> force shutdown" );
            challenge_timeout( zone );
            return;
        }

        // SOFT cap: past the cap AND no kill in the last full round AND none so far this round = genuinely stalled.
        if ( elapsed >= cap && !killed_last_round && level.acc_ldc_killed == killed_at_boundary )
        {
            ldc_debug( "round-cap: SOFT cap (" + elapsed + " >= " + cap + " rounds, no kill last round) -> force shutdown" );
            challenge_timeout( zone );
            return;
        }
    }
}

// COOP FREEZE FIX (user 2026-06-24). When ONE player seals into the purge, they stay am_i_valid but the
// seal's DisconnectPaths cuts the navmesh to them - and stock factory_closest_player (zm_usermap_ai.gsc)
// only re-picks a zombie's target when the cached one goes INVALID, NEVER when it merely becomes UNREACHABLE
// (factory_validate_last_closest_player keeps self.last_closest_player as long as am_i_valid). So every
// regular zombie already locked onto the sealed-in player idles forever instead of switching to the
// teammates still reachable OUTSIDE - the reported "all zombies froze for the other two players" bug (NOT
// the serum; the serum only froze the in-room glitches). Each second we force any NON-purge zombie whose
// cached target is a sealed-in party member to re-pick: point it at a reachable outside player + raise
// need_closest_player so the stock factory refines to the true-closest reachable one next tick. Purge
// glitches (acc_ldc) are skipped - they MUST keep hunting the in-room player. Ends with the purge.
function ldc_release_outside_horde( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 1 );
        if ( !isdefined( level.acc_ldc_party ) || level.acc_ldc_party.size == 0 ) continue;

        outside = ldc_first_outside_player();
        if ( !isdefined( outside ) ) continue;   // nobody reachable outside (true solo / whole team sealed) - can't retarget; they idle until clear

        zombies = zombie_utility::get_round_enemy_array();
        for ( i = 0; i < zombies.size; i++ )
        {
            z = zombies[ i ];
            if ( !isdefined( z ) || !isalive( z ) ) continue;
            if ( IS_TRUE( z.acc_ldc ) ) continue;                    // purge glitch - keep it on the in-room player
            if ( !isdefined( z.last_closest_player ) ) continue;
            if ( !is_in_party( z.last_closest_player ) ) continue;   // only the ones stuck on a sealed-in player

            z.last_closest_player = outside;   // immediate reachable target (no sealed-player flicker)
            z.need_closest_player = true;      // let stock factory refine to the closest reachable next tick
        }
    }
}

// First valid player NOT in the sealed purge party (still out in the normal round). undefined when everyone
// valid is sealed in (true solo, or the whole team entered) - then there's no reachable target to hand the
// outside horde, so it can only idle until the purge clears (unavoidable from a hard seal).
function ldc_first_outside_player()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !zm_utility::is_player_valid( p ) ) continue;
        if ( is_in_party( p ) ) continue;
        return p;
    }
    return undefined;
}

// ANTI-SOFTLOCK WATCHDOG (user 2026-06-24). The win condition (challenge_clear) only fires on
// acc_ldc_killed >= total, and watch_fail only fires when nobody is up-and-inside. Between them is a
// dead zone: a challenge zombie that DIES/VANISHES without being counted (lost), the producer unable to
// spawn the full count (coop actor-budget starvation), or a stuck-alive zombie - any of these freezes
// `killed` below `total` while a player sits up-and-inside, so NEITHER resolver fires and the purge stays
// sealed forever. Because every boss gates on level.acc_ldc_active, that stuck purge silently blocks the
// Phantom + Glitch Stalker for the rest of the match (THE coop "boss never spawned" report). This watchdog
// closes the gap two ways:
//   (1) ROOM CLEAR but count short: all spawned + none alive + killed < total = the players cleared
//       everything killable (the rest were lost) -> CLEAR (earned reward).
//   (2) HARD STALL: no kill AND no spawn for ACC_LDC_STALL_SEC -> something is genuinely stuck -> CLEAR
//       (kinder than trapping; gates the next DEFCON to +cooldown so it can't immediately re-trap).
// Both routes clear acc_ldc_active, so the bosses come back. challenge_clear is one-shot guarded
// (acc_ldc_resolved), so racing the real resolvers is safe.
function ldc_stall_watch( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    timeout_ms     = getdvarint( "acc_lockdown_challenge_stall_sec", ACC_LDC_STALL_SEC ) * 1000;
    last_killed    = level.acc_ldc_killed;
    last_spawned   = level.acc_ldc_spawned;
    last_progress  = GetTime();

    for ( ;; )
    {
        wait( 2 );

        // Any kill or spawn since the last tick = the fight is live; reset the stall timer.
        if ( level.acc_ldc_killed != last_killed || level.acc_ldc_spawned != last_spawned )
        {
            last_killed   = level.acc_ldc_killed;
            last_spawned  = level.acc_ldc_spawned;
            last_progress = GetTime();
            continue;
        }

        total = ldc_total();

        // (1) Room is clear of live challenge zombies but the count fell short -> lost zombies. Win.
        if ( level.acc_ldc_spawned >= total && ldc_alive() == 0 && level.acc_ldc_killed < total )
        {
            ldc_debug( "stall-watch: room clear, killed " + level.acc_ldc_killed + "/" + total + " (lost zombies) -> force CLEAR" );
            challenge_clear( zone );
            return;
        }

        // (2) Hard stall: no progress for the timeout window -> force-resolve (anti-softlock backstop).
        if ( GetTime() - last_progress >= timeout_ms )
        {
            ldc_debug( "stall-watch: no progress for " + ( timeout_ms / 1000 ) + "s (killed " + level.acc_ldc_killed + "/" + total + ", alive " + ldc_alive() + ") -> force CLEAR (anti-softlock)" );
            challenge_clear( zone );
            return;
        }
    }
}

// The kill target for the active challenge = current round x acc_lockdown_challenge_mult (2.0 default),
// CAPTURED ONCE at commit (level.acc_ldc_total) so it never drifts if the fight spans rounds. A fixed
// acc_lockdown_challenge_total > 0 overrides it (testing). Min 1.
function ldc_compute_total()
{
    fixed = getdvarint( "acc_lockdown_challenge_total", ACC_LDC_TOTAL_DEF );   // >0 = fixed override; 0 = auto
    if ( fixed > 0 )
        return fixed;
    rnd   = ( isdefined( level.round_number ) ? level.round_number : 1 );
    mult  = getdvarfloat( "acc_lockdown_challenge_mult", ACC_LDC_ROUND_MULT_DEF );
    total = int( rnd * mult );
    if ( total < 1 ) total = 1;
    return total;
}

// Live read of the captured target (falls back to a fresh compute if somehow read before commit).
function ldc_total()
{
    if ( isdefined( level.acc_ldc_total ) ) return level.acc_ldc_total;
    return ldc_compute_total();
}

// ---------------------------------------------------------------------------
// The confined wave
// ---------------------------------------------------------------------------

function challenge_producer( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    total        = ldc_total();
    cap          = getdvarint( "acc_lockdown_challenge_concurrent", ACC_LDC_CONCURRENT_DEF );
    stagger      = getdvarfloat( "acc_lockdown_challenge_stagger", ACC_LDC_STAGGER_DEF );
    stagger_init = getdvarfloat( "acc_lockdown_challenge_stagger_initial", 0.3 );  // fast fill at the start

    while ( level.acc_ldc_spawned < total )
    {
        // Share the engine actor pool with the outside horde: cap concurrent + only spawn when
        // a slot is free (spawn_zombie itself hard-waits on GetFreeActorCount, so this just
        // avoids parking the producer in that spin under a dense horde - docs/26 §4.3).
        if ( ldc_alive() >= cap || GetFreeActorCount() < 1 )
        {
            wait( 0.25 );
            continue;
        }

        h = spawn_challenge_glitch( zone );
        if ( isdefined( h ) )
        {
            level.acc_ldc_spawned++;
            level.acc_ldc_zombies[ level.acc_ldc_zombies.size ] = h;
            h thread ldc_death_watch( zone );
        }

        // Fill the room FAST when the trap first snaps shut (user 2026-06-18 - it spawned in too slow),
        // then drop to the normal replacement trickle once the room has been filled to the cap once.
        wait( ( level.acc_ldc_spawned < cap ? stagger_init : stagger ) );
    }
}

// Build a full Glitch Stalker (reusing _acc_boss_glitch::spawn_glitch), tag it as a challenge
// zombie (so its death drops NO reward), teleport it INTO the room, and pin it to the centre.
function spawn_challenge_glitch( zone )
{
    rnd  = ( isdefined( level.round_number ) ? level.round_number : 1 );
    host = acc_boss_glitch::spawn_glitch( rnd );
    if ( !isdefined( host ) || !isalive( host ) ) return undefined;

    host.acc_ldc = true;

    // Stock this room's interior anchor origins ON the actor: _acc_boss_glitch reads them to keep
    // every blink/charge teleport in-room, and ldc_keep_in_room uses them as the escape test.
    structs = struct::get_array( zone + "_spawners", "targetname" );
    origins = [];
    for ( i = 0; i < structs.size; i++ )
        if ( isdefined( structs[ i ].origin ) )
            origins[ origins.size ] = structs[ i ].origin;
    host.acc_ldc_anchors = origins;

    // spawn_glitch spawns at a base spawner (start/corp), so teleport into the room interior.
    if ( origins.size > 0 )
    {
        a   = origins[ acc_utility::acc_rand_int( origins.size ) ];
        nav = GetClosestPointOnNavMesh( a, 100, 30 );
        if ( isdefined( nav ) )
            host forceteleport( nav );
    }
    host SetGoal( acc_lockdown::room_center_origin( zone ) );
    host thread ldc_keep_in_room();   // safety net: yank back if it ever leaves the room

    return host;
}

// Per-actor: count ONLY tagged challenge zombies; the 30th fires the clear. Killed by the
// "acc_ldc_done" teardown so culled survivors never re-enter the count.
function ldc_death_watch( zone )
{
    level endon( "acc_ldc_done" );

    self waittill( "death" );

    if ( !( isdefined( self.acc_ldc ) && self.acc_ldc ) ) return;
    if ( isdefined( level.acc_ldc_teardown ) && level.acc_ldc_teardown ) return;

    level.acc_ldc_killed++;
    ldc_update_hud();
    level notify( "acc_ldc_kill" );

    total = ldc_total();
    if ( level.acc_ldc_killed >= total )
        level thread challenge_clear( zone );
}

function ldc_alive()
{
    if ( !isdefined( level.acc_ldc_zombies ) ) return 0;

    fresh = [];
    for ( i = 0; i < level.acc_ldc_zombies.size; i++ )
    {
        z = level.acc_ldc_zombies[ i ];
        if ( isdefined( z ) && isalive( z ) )
            fresh[ fresh.size ] = z;
    }
    level.acc_ldc_zombies = fresh;
    return fresh.size;
}

// Containment safety net (self = a challenge zombie). Each ~1s, if it has somehow left the room
// (not within acc_lockdown_challenge_bounds_margin of ANY of its room anchors), yank it back to a
// random in-room anchor. The _acc_boss_glitch blink/charge clamps make this rare; this catches the
// rest (e.g. a knockback or a stock teleport). Ends on death or the challenge teardown.
function ldc_keep_in_room()
{
    self endon( "death" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 1 );
        if ( !isalive( self ) ) return;
        if ( !( isdefined( self.acc_ldc_anchors ) && self.acc_ldc_anchors.size > 0 ) ) return;

        if ( !point_near_anchors( self.origin, self.acc_ldc_anchors ) )
        {
            a   = self.acc_ldc_anchors[ acc_utility::acc_rand_int( self.acc_ldc_anchors.size ) ];
            nav = GetClosestPointOnNavMesh( a, 100, 40 );
            if ( isdefined( nav ) ) self forceteleport( nav );
            else self forceteleport( a );
        }
    }
}

function point_near_anchors( p, anchors )
{
    d  = getdvarint( "acc_lockdown_challenge_bounds_margin", 300 );
    d2 = d * d;
    for ( i = 0; i < anchors.size; i++ )
    {
        dx = p[ 0 ] - anchors[ i ][ 0 ];
        dy = p[ 1 ] - anchors[ i ][ 1 ];
        if ( ( dx * dx + dy * dy ) <= d2 ) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Resolve (clear / fail) - one-shot guarded, mutually exclusive
// ---------------------------------------------------------------------------

function challenge_clear( zone )
{
    if ( isdefined( level.acc_ldc_resolved ) && level.acc_ldc_resolved ) return;
    level.acc_ldc_resolved = true;
    level.acc_ldc_teardown = true;
    level notify( "acc_ldc_done" );

    ldc_debug( "CLEAR zone=" + zone );
    teardown_common( zone );

    if ( getdvarint( "acc_lockdown_reward", 1 ) == 1 )
        acc_boss_items::grant_challenge_reward( acc_lockdown::room_center_origin( zone ) );

    ldc_announce( level.acc_ldc_party, "^2LOCKDOWN CLEARED^7 - reward dropped" );

    level.acc_ldc_active = undefined;

    // Defeated: turn the DEFCON alarm OFF and gate the next one to +acc_lockdown_cooldown rounds
    // (user 2026-06-18 - so players don't think another is available, and a new one returns in ~4).
    acc_lockdown::on_defcon_cleared( ( isdefined( level.round_number ) ? level.round_number : 1 ) );
}

function challenge_fail( zone )
{
    // OUTCOME PRIORITY (audit 2026-06-25): if the kill count is already met, this is a WIN regardless of who
    // raced here first - redirect to challenge_clear (itself one-shot guarded) so the final-kill reward is never
    // forfeited by a same-frame down/timeout that grabbed the resolver first.
    if ( isdefined( level.acc_ldc_total ) && level.acc_ldc_killed >= ldc_total() ) { challenge_clear( zone ); return; }

    if ( isdefined( level.acc_ldc_resolved ) && level.acc_ldc_resolved ) return;
    level.acc_ldc_resolved = true;
    level.acc_ldc_teardown = true;
    level notify( "acc_ldc_done" );

    ldc_debug( "FAIL zone=" + zone );
    teardown_common( zone );

    ldc_announce( level.acc_ldc_party, "^1LOCKDOWN FAILED^7" );

    level.acc_ldc_active = undefined;

    // Failed (party wiped): lights off; gate the next DEFCON to a short fail cooldown so the recovering party
    // gets at least one DEFCON-free round (audit 2026-06-25 - fail used to re-light a DEFCON the very next round
    // with zero breather, unlike clear/timeout which rest acc_lockdown_cooldown).
    acc_lockdown::on_defcon_failed( ( isdefined( level.round_number ) ? level.round_number : 1 ) );
}

// TIMEOUT resolver (user 2026-06-25) - fired by ldc_round_cap_watch when a purge has been active >= the round
// cap. Same one-shot-guarded clean shutdown as clear/fail (unseal the doors, restore the room's spawns, cull the
// purge glitches, clear level.acc_ldc_active) but with NO reward (this is an abnormal/abandoned shutdown, not an
// earned clear). Gates the next DEFCON to +cooldown (like a clear, NOT like a fail) so the stuck room does NOT
// immediately re-light and re-trap the same players next round - that would just re-stick.
function challenge_timeout( zone )
{
    // OUTCOME PRIORITY (audit 2026-06-25): a met kill count is a WIN even if the round cap fired the same tick.
    if ( isdefined( level.acc_ldc_total ) && level.acc_ldc_killed >= ldc_total() ) { challenge_clear( zone ); return; }

    if ( isdefined( level.acc_ldc_resolved ) && level.acc_ldc_resolved ) return;
    level.acc_ldc_resolved = true;
    level.acc_ldc_teardown = true;
    level notify( "acc_ldc_done" );

    ldc_debug( "TIMEOUT zone=" + zone + " (active >= round cap) -> force shutdown, no reward" );
    teardown_common( zone );   // unseal doors + restore spawns + cull glitches + destroy HUD

    ldc_announce( level.acc_ldc_party, "^3LOCKDOWN RESET^7 - purge timed out" );

    level.acc_ldc_active = undefined;

    // Cooldown gate (like on_defcon_cleared) so the timed-out room does not immediately re-light/re-trap.
    acc_lockdown::on_defcon_cleared( ( isdefined( level.round_number ) ? level.round_number : 1 ) );
}

// Unseal (Phase B) + RESTORE the room's outside spawns (mandatory, or that room stays dead) +
// cull any surviving tagged zombies (their death watches are already endon'd by acc_ldc_done).
function teardown_common( zone )
{
    unseal_room( zone );                                  // re-open the doors we closed (escape valve)
    acc_decontamination::enable_zone_spawning( zone );    // restore the room's outside spawns

    if ( isdefined( level.acc_ldc_party ) )
    {
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( isdefined( p ) && isplayer( p ) ) p destroy_challenge_hud();
        }
    }

    if ( isdefined( level.acc_ldc_zombies ) )
    {
        for ( i = 0; i < level.acc_ldc_zombies.size; i++ )
        {
            z = level.acc_ldc_zombies[ i ];
            if ( isdefined( z ) && isalive( z ) )
                z Kill();
        }
    }
    level.acc_ldc_zombies = [];
}

// Always-unseal safety: if the game ends mid-challenge, restore the active room's spawns AND re-open the sealed
// doors (audit 2026-06-25 - it previously restored spawning but not the seal, contradicting its own comment) so
// a future run/round is never left with a permanently dead or sealed room.
function on_end_game_safety()
{
    level waittill( "end_game" );
    if ( isdefined( level.acc_ldc_active ) )
    {
        unseal_room( level.acc_ldc_active );                              // re-open the re-closed border doors (idempotent, null-safe)
        acc_decontamination::enable_zone_spawning( level.acc_ldc_active );
        level.acc_ldc_active = undefined;
    }
}

// ---------------------------------------------------------------------------
// Phase B door seal (LED-safe: reuses the existing buyable border doors, no new geometry)
// ---------------------------------------------------------------------------

// Each of the 4 rooms is bordered by exactly 2 stock buyable doors (acc_door_* script_brushmodels,
// verified in the current .map). We only touch doors that are OPEN (their enter_* flag set) so an
// un-bought (already-closed) door is left closed on teardown. NO acc_seal_* brushes / no .map edit
// -> -GscOnly, zero LED risk.
//
// HOW THIS MAP OPENS DOORS (the load-bearing fact, re-verified 2026-06-18): the entry script's
// acc_hardcoded_open_map (zm_abandoned_cyber_city.gsc:317) and dev_open_all_doors both open a door by
// `slab Show-inverse` = ConnectPaths(); NotSolid(); Hide() IN PLACE - the slab NEVER moves, it just
// goes invisible + non-colliding while sitting at its CLOSED origin z[0,128]. (It does carry
// script_vector "0 0 130", but the stock buy/MoveTo path is bypassed here - the map force-opens it.)
// So to RE-CLOSE = Show() + Solid() + DisconnectPaths() in place; the slab is already at z[0,128].
// We must NOT MoveTo it (that earlier "crush-safe close" via door_activate(false) slid it DOWN through
// the floor, so the room stopped locking). Crush-safety is kept by GATING Solid() on "no player is in
// the doorway" (door_player_touching) - the relocate-to-centre at commit means it's normally already
// clear, so it solidifies instantly; a player caught in it just defers the solid until they step off.
function room_doors( zone )
{
    d = [];
    switch ( zone )
    {
        case "vault_zone":  d[ 0 ] = make_door( "acc_door_vault",  "enter_vault" );  d[ 1 ] = make_door( "acc_door_lab_e",  "enter_lab_e" );  break;
        case "roof_zone":   d[ 0 ] = make_door( "acc_door_roof",   "enter_roof" );   d[ 1 ] = make_door( "acc_door_lab_w",  "enter_lab_w" );  break;
        case "alley_zone":  d[ 0 ] = make_door( "acc_door_alley",  "enter_alley" );  d[ 1 ] = make_door( "acc_door_corp_e", "enter_corp_e" ); break;
        case "market_zone": d[ 0 ] = make_door( "acc_door_market", "enter_market" ); d[ 1 ] = make_door( "acc_door_corp_w", "enter_corp_w" ); break;
    }
    return d;
}

function make_door( tn, flag )
{
    s = spawnstruct();
    s.tn = tn;
    s.flag = flag;
    return s;
}

// Public query for the buyable-door system (zm_abandoned_cyber_city::zone_door_trigger_wait). Returns true
// while this door (keyed by its enter_* script_flag) is one of the 2 border doors of the room that is RIGHT
// NOW sealed by an active purge. THE ESCAPE-BUG FIX (user 2026-06-25): seal_room only re-CLOSES border doors
// that were ALREADY OPEN; an UN-BOUGHT border door is a solid wall it leaves alone - but its BUY TRIGGER is
// still live, so a player sealed inside the Glitch Purge could just buy that door and walk straight out. The
// door loop gates its purchase on this so an un-bought border door refuses to open for the duration of the
// purge (and an outside player can't buy INTO the sealed room either). Auto-clears the instant the purge
// resolves (level.acc_ldc_active -> undefined), so the door buys normally again afterwards. Respects the
// acc_lockdown_lock_doors test knob (0 = sealing off -> don't block buys either, stay consistent).
function is_door_sealed( flag )
{
    if ( !isdefined( level.acc_ldc_active ) ) return false;
    if ( getdvarint( "acc_lockdown_lock_doors", 1 ) != 1 ) return false;

    doors = room_doors( level.acc_ldc_active );
    for ( i = 0; i < doors.size; i++ )
        if ( isdefined( doors[ i ].flag ) && doors[ i ].flag == flag ) return true;
    return false;
}

function seal_room( zone )
{
    level.acc_ldc_sealed_doors = [];
    if ( getdvarint( "acc_lockdown_lock_doors", 1 ) != 1 ) return;

    doors = room_doors( zone );
    for ( i = 0; i < doors.size; i++ )
    {
        // Only close doors that are currently OPEN (their enter_* flag set). An un-bought door is
        // already a solid wall, so leave it - and must NOT re-open it on teardown.
        if ( !( level flag::exists( doors[ i ].flag ) && level flag::get( doors[ i ].flag ) ) ) continue;

        ents = getentarray( doors[ i ].tn, "targetname" );
        for ( j = 0; j < ents.size; j++ )
        {
            e = ents[ j ];
            if ( !isdefined( e ) ) continue;

            // Re-close IN PLACE (the slab is hidden at its closed origin z[0,128], it never moved -
            // see the section comment). Show + cut nav always (both safe); Solid only when the doorway
            // is player-clear so a caught player can't be stuck/ejected (reseal_monitor finishes it).
            e Show();
            e DisconnectPaths();
            if ( !door_player_touching( e ) ) e Solid();
            level.acc_ldc_sealed_doors[ level.acc_ldc_sealed_doors.size ] = e;
        }
    }
    ldc_debug( "sealing " + level.acc_ldc_sealed_doors.size + " door(s) for " + zone );
}

// True if any player is inside the door slab's bounds (the stock crush-safe occupancy test,
// _zm_blockers::door_solid_thread:1104). Used to never Solid() a slab a player is standing in.
function door_player_touching( e )
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && p IsTouching( e ) )
            return true;
    }
    return false;
}

function unseal_room( zone )
{
    if ( !isdefined( level.acc_ldc_sealed_doors ) ) return;

    for ( i = 0; i < level.acc_ldc_sealed_doors.size; i++ )
    {
        e = level.acc_ldc_sealed_doors[ i ];
        if ( !isdefined( e ) ) continue;

        // Re-OPEN exactly how the map opened it (Hide/NotSolid/ConnectPaths in place) so players leave.
        e Hide();
        e NotSolid();
        e ConnectPaths();
    }
    level.acc_ldc_sealed_doors = [];
}

// Re-assert the seal every ~1s, crush-safely: Show + cut nav always; (re)Solid only when the doorway
// is player-clear. This also COMPLETES any door left un-solid at seal time (a player was standing in
// it) the moment they step off, and re-cuts a stray ConnectPaths. Ends before unseal (teardown
// notifies acc_ldc_done before unseal_room re-connects the paths).
function reseal_monitor( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    for ( ;; )
    {
        wait( 1 );
        if ( !isdefined( level.acc_ldc_sealed_doors ) ) continue;
        for ( i = 0; i < level.acc_ldc_sealed_doors.size; i++ )
        {
            e = level.acc_ldc_sealed_doors[ i ];
            if ( !isdefined( e ) ) continue;
            e Show();
            e DisconnectPaths();
            if ( !door_player_touching( e ) ) e Solid();
        }
    }
}

// Best-effort: move the committed party to a PROVEN-safe interior point before the doors close, so no
// player is standing in a doorway when collision re-materializes. Guards against the room_center_origin
// degenerate case (returns (0,0,0) when a zone has no spawners -> SetOrigin there = instant OOB kill)
// and against an in-geometry centroid by snapping to navmesh first; if neither check passes it leaves
// players where they are (the stock crush-safe close protects them anyway). Never moves a laststand
// player (you must not teleport a downed player).
function relocate_party_safe( zone, party )
{
    center = acc_lockdown::room_center_origin( zone );
    if ( center[ 0 ] == 0 && center[ 1 ] == 0 && center[ 2 ] == 0 ) return;  // degenerate centroid -> do NOT teleport

    nav = GetClosestPointOnNavMesh( center, 200, 60 );
    if ( !isdefined( nav ) ) return;                                          // no proven floor point -> leave players put

    // FAN OUT in co-op (user 2026-06-26): SetOrigin'ing EVERY player to the SAME point stacks their capsules
    // on one spot; the engine's overlap-ejection then shoves them through the (not-yet-sealed) doorway/wall ->
    // OOB kill ("teleported into the surge, spawn on each other, die"). Give each a DISTINCT slot on a ring
    // around the proven-safe centre floor point. Ring spacing (80u for 2 players, ~57u for 4) clears the ~16u
    // player capsules; offsets are small + horizontal so everyone stays on the room's flat floor.
    base   = nav + ( 0, 0, 16 );                                             // feet-above-floor, never embedded
    radius = 40;

    movers = [];
    for ( i = 0; i < party.size; i++ )
    {
        p = party[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !zm_utility::is_player_valid( p ) ) continue;                   // skip spectators / laststand
        movers[ movers.size ] = p;
    }

    for ( i = 0; i < movers.size; i++ )
    {
        if ( movers.size <= 1 )
            dest = base;                                                     // solo: the centre point is fine
        else
        {
            ang  = i * ( 360.0 / movers.size );                             // even ring slots, one per player
            dest = base + ( radius * cos( ang ), radius * sin( ang ), 0 );
        }
        movers[ i ] SetOrigin( dest );
    }
}

// ---------------------------------------------------------------------------
// Optional soft confinement (default OFF - the door seal above is the real lock-in) + fail detection
// ---------------------------------------------------------------------------

// Belt-and-suspenders only (acc_lockdown_challenge_confine 1): poll the party and yank anyone who
// somehow ends up outside back to the room centre. The door seal makes this unnecessary in normal play.
function confine_players( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    volumes = acc_decontamination::get_zone_volumes( zone );
    center  = acc_lockdown::room_center_origin( zone );

    for ( ;; )
    {
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( !zm_utility::is_player_valid( p ) ) continue;   // don't yank a downed player
            if ( !acc_decontamination::player_in_zone_volumes( p, volumes ) )
                p SetOrigin( center + ( 0, 0, 16 ) );
        }
        wait( 0.25 );
    }
}

// Fail (unseal + tear down) when the purge becomes UNWINNABLE. The hard part is distinguishing a RECOVERABLE
// down (a player in laststand who can still self-revive or be revived) from a real wipe - the headline bug
// (user 2026-06-25) was that this aborted the WHOLE purge the instant the only inside player hit laststand,
// even with Quick Revive about to self-rez 2.5s later, culling every glitch and leaving them in a dead room.
//
// Decision tree, per poll, over the party members still INSIDE the room volume (the "inside" gate is
// load-bearing - a coop member who bled out then respawned OUTSIDE the seal is valid again but locked out of
// the fight, and must NOT keep the purge alive; that was the 2026-06-24 "sealed forever" bug):
//   - someone UP and inside        -> still fighting, keep going.
//   - someone DOWN (laststand) inside, and NO outside teammate exists to rescue them (solo, or the whole team
//     is sealed in) -> KEEP the purge alive so they can self-revive / be revived from inside (the headline fix:
//     do not abort a self-revivable down). is_player_valid(p, false, true) = valid IGNORING laststand.
//   - otherwise (a real wipe, everyone respawned outside, OR a downed-inside player WITH an outside teammate
//     who could come rescue them) -> FAIL: unseal the doors (rescue/escape valve) + cull glitches + no reward.
// The fail is DEBOUNCED (2 consecutive polls) so a sub-second transient - e.g. the sole standing player
// clipping the doorway during the ~1s the seal is still solidifying - can never false-abort a live fight.
function watch_fail( zone )
{
    level endon( "end_game" );
    level endon( "acc_ldc_done" );

    volumes      = acc_decontamination::get_zone_volumes( zone );
    fail_strikes = 0;

    for ( ;; )
    {
        wait( 0.5 );

        live = [];
        for ( i = 0; i < level.acc_ldc_party.size; i++ )
        {
            p = level.acc_ldc_party[ i ];
            if ( isdefined( p ) && isplayer( p ) )
                live[ live.size ] = p;
        }
        if ( live.size == 0 )
        {
            challenge_fail( zone );   // everyone disconnected - definitive, no debounce
            return;
        }

        any_fighting           = false;   // someone UP and inside
        any_recoverable_inside = false;   // someone in laststand but still inside (could be saved)
        for ( i = 0; i < live.size; i++ )
        {
            p = live[ i ];
            if ( !acc_decontamination::player_in_zone_volumes( p, volumes ) ) continue;   // must be inside the seal
            if ( zm_utility::is_player_valid( p ) )                                        // UP and inside
            {
                any_fighting = true;
                break;
            }
            if ( zm_utility::is_player_valid( p, false, true ) )                           // valid except for laststand
                any_recoverable_inside = true;
        }

        if ( any_fighting ) { fail_strikes = 0; continue; }   // someone up AND inside, still clearing it

        // A downed-inside player with NO outside rescuer (solo / whole team sealed): keep it alive for the
        // self-revive / inside-revive. With an outside rescuer available, fall through and unseal so they
        // can come in (the door opening IS the rescue path in coop, where you can't self-revive).
        if ( any_recoverable_inside && !outside_player_alive() ) { fail_strikes = 0; continue; }

        // Unwinnable-or-rescuable-from-outside -> FAIL, debounced.
        fail_strikes++;
        if ( fail_strikes >= 2 )
        {
            challenge_fail( zone );
            return;
        }
    }
}

function outside_player_alive()
{
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( isdefined( p ) && isplayer( p ) && zm_utility::is_player_valid( p ) && !is_in_party( p ) )
            return true;
    }
    return false;
}

function is_in_party( player )
{
    if ( !isdefined( level.acc_ldc_party ) ) return false;
    for ( i = 0; i < level.acc_ldc_party.size; i++ )
        // [acc] 4p guard (2026-07-06 sweep): the party is a snapshot held for the whole challenge; a
        // disconnected member's entry is undefined and `entity == undefined` THROWS. Every other party
        // consumer already isdefined-guards - this was the one raw compare (polled 1/s per zombie).
        if ( isdefined( level.acc_ldc_party[ i ] ) && level.acc_ldc_party[ i ] == player ) return true;
    return false;
}

// ---------------------------------------------------------------------------
// Dev / debug / feedback (real server-side X/30 HUD lands in Increment 3)
// ---------------------------------------------------------------------------

function watch_force_dvar()
{
    level endon( "end_game" );
    for ( ;; )
    {
        forced = getdvarstring( "acc_lockdown_challenge_force" );
        if ( isdefined( forced ) && forced != "" && !isdefined( level.acc_ldc_active ) )
        {
            SetDvar( "acc_lockdown_challenge_force", "" );
            party = inside_party( acc_decontamination::get_zone_volumes( forced ) );
            if ( party.size == 0 ) party = GetPlayers();   // dev: just use everyone
            commit_challenge( forced, party );
        }
        wait( 1 );
    }
}

// Per-inside-player objective HUD: "GLITCH PURGE" label + a bar that FILLS as you progress + a
// "killed / total" number. Top-centre, under the zone-name banner. The bar is a single "white" icon
// (the squad-roster idiom), NOT hud::createBar - pool-frugal + leak-free in co-op. self = player.
function create_challenge_hud()
{
    if ( isdefined( self.acc_ldc_label ) ) return;   // already built

    total = ldc_total();

    self.acc_ldc_label = self hud::createFontString( "objective", 1.3 );
    // [acc] 4p guard (2026-07-06 coop sweep): hud::create* returns undefined when the shared hudelem
    // pool is full (demonstrated 4p condition) - the writes below would throw. Bail on each failed
    // create; ldc_update_hud/destroy_challenge_hud already tolerate undefined fields, and purge
    // commit is exactly when the pool is most saturated (3 elems x up to 4 sealed players).
    if ( !isdefined( self.acc_ldc_label ) )
        return;
    self.acc_ldc_label hud::setPoint( "TOP", "TOP", 0, 62 );
    self.acc_ldc_label.alignX = "center";
    self.acc_ldc_label.alignY = "top";
    self.acc_ldc_label.color = ( 1, 0.15, 0.15 );
    self.acc_ldc_label.alpha = 0.95;
    self.acc_ldc_label.hidewheninmenu = true;
    self.acc_ldc_label SetText( "^1GLITCH PURGE" );

    // Bar = ONE "white" icon (NOT hud::createBar = 3 hudelems), left-anchored from the centered x so it fills
    // rightward; width = barw * frac each update (user 2026-06-27 audit: matches the squad roster's pool-frugal
    // pattern - frees 2 hudelems/player AND removes the createBar barFrame child that destroy_challenge_hud never
    // freed = a per-player-per-purge hudelem leak that progressively starved the shared co-op HUD pool).
    self.acc_ldc_bar = self hud::createIcon( "white", 1, ACC_LDC_BAR_H );   // start empty (killed=0); first update fills it
    if ( !isdefined( self.acc_ldc_bar ) )   // [acc] pool-full guard (see label above)
        return;
    self.acc_ldc_bar hud::setPoint( "TOP", "TOP", -( ACC_LDC_BAR_W / 2 ), 84 );   // left edge of the centered bar
    self.acc_ldc_bar.alignX = "left";
    self.acc_ldc_bar.alignY = "top";
    self.acc_ldc_bar.color = ( 0.9, 0.15, 0.15 );
    self.acc_ldc_bar.alpha = 0.9;
    self.acc_ldc_bar.hidewheninmenu = true;
    self.acc_ldc_bar.acc_barw = ACC_LDC_BAR_W;   // full width; ldc_update_hud sets the live shader width = barw * frac
    self.acc_ldc_bar.acc_w = 1;

    self.acc_ldc_num = self hud::createFontString( "default", 1.0 );
    if ( !isdefined( self.acc_ldc_num ) )   // [acc] pool-full guard (see label above)
        return;
    self.acc_ldc_num hud::setPoint( "TOP", "TOP", 0, 98 );
    self.acc_ldc_num.alignX = "center";
    self.acc_ldc_num.alignY = "top";
    self.acc_ldc_num.color = ( 1, 1, 1 );
    self.acc_ldc_num.alpha = 0.95;
    self.acc_ldc_num.hidewheninmenu = true;
    self.acc_ldc_num SetText( "0 / " + total );
}

function destroy_challenge_hud()
{
    if ( isdefined( self.acc_ldc_label ) ) { self.acc_ldc_label Destroy(); self.acc_ldc_label = undefined; }
    if ( isdefined( self.acc_ldc_bar ) ) { self.acc_ldc_bar Destroy(); self.acc_ldc_bar = undefined; }   // single icon now - no .bar/.barFrame children to leak
    if ( isdefined( self.acc_ldc_num ) ) { self.acc_ldc_num Destroy(); self.acc_ldc_num = undefined; }
}

// Push the live count to every inside player's bar + number (called on each kill).
function ldc_update_hud()
{
    if ( !isdefined( level.acc_ldc_party ) ) return;

    total  = ldc_total();
    killed = level.acc_ldc_killed;
    frac   = ( total > 0 ? ( killed / total ) : 1 );   // bar fills as you clear toward 30

    for ( i = 0; i < level.acc_ldc_party.size; i++ )
    {
        p = level.acc_ldc_party[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        if ( !isdefined( p.acc_ldc_bar ) ) continue;

        // Icon-bar fill: width = barw * frac, re-shadered only when it changes (same idiom as the squad roster).
        bw = int( p.acc_ldc_bar.acc_barw * frac + 0.5 );
        if ( bw < 1 ) bw = 1;
        if ( !isdefined( p.acc_ldc_bar.acc_w ) || p.acc_ldc_bar.acc_w != bw )
        {
            p.acc_ldc_bar setShader( "white", bw, ACC_LDC_BAR_H );
            p.acc_ldc_bar.acc_w = bw;
        }
        if ( isdefined( p.acc_ldc_num ) )
            p.acc_ldc_num SetText( killed + " / " + total );
    }
}

function ldc_announce( party, msg )
{
    if ( !isdefined( party ) ) return;
    for ( i = 0; i < party.size; i++ )
        if ( isdefined( party[ i ] ) && isplayer( party[ i ] ) )
            party[ i ] IPrintLnBold( msg );
}

function ldc_debug( msg )
{
    acc_utility::log( "ldc: " + msg );
    if ( !( isdefined( level.acc_dev ) && level.acc_dev ) && getdvarint( "acc_lockdown_challenge_debug", 0 ) != 1 ) return;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
        if ( isdefined( players[ i ] ) && isplayer( players[ i ] ) )
            players[ i ] IPrintLnBold( "[ldc] " + msg );
}
