// =============================================================================
// _acc_civil_protector.gsc - the ROGUE PROTECTOR: Civil Protector as the
// ROUND-20 HOSTILE BOSS (user 2026-07-02: "make him an enemy/boss now,
// preferably the round 20 boss"). v1 of this module was the round-1 ALLY test
// spawn - that is REMOVED (it proved the assets in-game 2026-07-02).
//
// HOW HE IS HOSTILE (the whole trick - docs in memory hb21-civil-protector-integration):
//   - NEW AITYPE `acc_zod_robot_boss` = install-side GDT clone of the pack's
//     GOLD aitype with ONE field changed: "team" "allies" -> "axis". Engine
//     target acquisition is team-based, so on axis he acquires PLAYERS as
//     enemies natively; zombies (also axis) ignore him and he ignores them.
//     The pack's own zodcompaniontargetservice even has an explicit
//     players-as-enemies path (leftover from the campaign robot it was ported
//     from), so the behavior tree fights players with zero BT edits.
//   - The archetype stays "zod_companion" (same anims/BT/spawn functions). The
//     COMPANION-ONLY services (follow leader / revive downed players / chase
//     powerups) all early-out on `self.b_robot_finished == 1`
//     (archetype_zod_companion.gsc manage_companion_movement) - we set that
//     permanently, so an enemy robot never "revives" the players it downed.
//   - His rifle really damages players (the pack's own no-damage guard in
//     zm_zod_robot::zod_robot_player_damage_override is dead code - it checks
//     the TYPO'd field `.archeype`). Hit strength is tuned at the SOURCE: the
//     weapon GDT's `playerDamage` field (pack shipped 1550/bullet = instakill!
//     -> 10 flat, user design) and his aitype clone fires ONE shot / 1.5s
//     (burstCount 1, fireInterval 1.5; engage band widened to 100-1500u so he
//     fires at close range). Each hit STUNS via the Phantom zap - applied in
//     _acc_elites::on_player_damaged (the per-hit-effects home) so it lands
//     under god/dev exactly like the Phantom's.
//
// CADENCE (SHARED multi-boss roster, owned by this module - boss_count/boss_roster/
// boss_type_count): a boss ROUND every 9 rounds from round 9 (dev: every 3 from round 3). The
// COUNT scales - round 9 = 1 boss, 18 = 2, 27 = 3, ... (slot+1) - and the types are dealt from a
// shuffled 4-type deck WITHOUT replacement (Phantom / Rogue Protector / Avogadro / Panzer;
// no-duplicate guard, user 2026-07-08), so a duplicate type first appears at the forced 5th slot
// (round 45). This module's debt-based director spawns the "protector" entries; the phantom/
// avogadro/panzer modules each read their own count off level.acc_boss_roster_fn. MULTIPLE bosses
// (and, from round 45 / via disabled-type re-homing, multiple of a TYPE) may be alive at once.
//
// NO SPAWNER EXISTS AT ALL (see spawn_boss): the boss is spawned DIRECTLY via
// SpawnActor("spawner_acc_zod_robot_boss", ...) - a .map actor_spawner entity
// for this axis-team aitype hard-crashed the game at load, and runtime
// Spawn("actor_spawner_...") returns undefined. Do NOT re-add either.
//
// PRESENTATION: gold model (visually distinct from a possible future ally), a
// SELF-CONTAINED slam-down entrance (ground-tell telegraph -> quake + landing
// FX + boss-excluding kill-splash + rumble - the pack's do_landing/entrance
// scene are ally-hardwired and broke live, see spawn_boss), boss music, and
// the 3D over-head nameplate + health bar (_acc_boss_nameplate, via the
// "acc_boss_spawned" notify - replaces the 2D top-screen bar per user 2026-07-02).
//
// Rewards on kill: guaranteed boss-item drop + 3000 points each + 50% Mega
// Bottle (the Trench Warden's flat set, _acc_boss.gsc watch_mini_boss_death).
// =============================================================================

#using scripts\shared\ai\archetype_utility;
#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\zm_zod_robot;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;   // shot_pulse / zap_pulse (client-side FX + report)
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;           // acc_protector_zap (the zap slow applicator)
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;     // scale_phantom_hp (HP scales EXACTLY like the Phantom)

#namespace acc_civil_protector;

#define ACC_PROTECTOR_NAME          "ROGUE PROTECTOR"   // user 2026-07-03: briefly "THE ANNIHILATOR", reverted same message - Rogue Protector is final
// UNIFIED BOSS ROTATION (user 2026-07-03; 3-boss pool 2026-07-04; 4-boss pool + no-duplicate deck
// 2026-07-08): a boss every 9 rounds from round 9 (9, 18, 27, ...); the slots are DEALT from a
// shuffled 4-type deck WITHOUT replacement (Phantom / Rogue Protector / Avogadro / Panzer),
// reshuffled per run and only when the deck empties - so rounds with up to 4 bosses are always
// all-distinct types, a repeat first becomes possible at the 5th boss slot (round 45) where it's
// forced, and no two games play the same boss sequence.
#define ACC_PROTECTOR_HP_EXP        1.09  // per-round HP exponent: the MIDDLE boss tier - Brutus 1.12 > Rogue/Panzer 1.09 > Phantom 1.06 - on the SHARED 65k/anchor-5 scale_phantom_hp scale (user 2026-07-04 1.1 -> 2026-07-08 1.11 -> 1.09 after anchor moved to r5). Live dvar acc_protector_hp_exp.
#define ACC_BOSS_FIRST_DEF          9     // BASE GAME: first boss round 9, then every 9
#define ACC_BOSS_INTERVAL_DEF       9
#define ACC_BOSS_FIRST_DEV          3     // DEV: round 3, every 3 (fast iteration)
#define ACC_BOSS_INTERVAL_DEV       3
// (HP now scales EXACTLY like the Phantom - acc_boss_phantom::scale_phantom_hp; see spawn_boss.)

// Threaded from the entry script's main().
function init()
{
	// Publish the SHARED per-round roster decider (function pointer, NOT a #using - that would
	// cycle _acc_boss -> _acc_boss_phantom -> here). Every boss module counts its own entries off
	// this. boss_type_count( round, "phantom" | "protector" | "avogadro" | "panzer" ) reads the cached roster (boss_roster).
	level.acc_boss_roster_fn = &boss_type_count;

	if ( !isdefined( level.acc_protector_debt ) )
		level.acc_protector_debt = 0;   // how many Rogue Protectors still owe a spawn (multi-boss rounds)

	// Boss-hit STUN lives in _acc_elites::on_player_damaged (the per-hit-effects home), NOT a
	// callback registered here: our registration lands AFTER elites' in the chain, and under GOD
	// MODE elites returns 0 which short-circuits everything after it - the stun would never fire
	// in the dev+god test setup (user 2026-07-02: "stun should still affect me in dev mode").

	level thread round_watch();
	level thread director();

	// [acc] damage-diagnostic probe (file-only LogPrint via rp_diag; the acc_protector_debug dvar
	// was removed 2026-07-16) - logs when a player is hit by
	// his bullet, so we can tell "firing but no damage lands" from "not firing" (user 2026-07-04).
	zm::register_player_damage_callback( &rp_damage_probe );

	// DEV force-spawn: console `acc_protector_spawn 1` marks the boss owed NOW (the
	// director spawns within ~3s) - same dev-console-action pattern as acc_skip_round.
	if ( IS_TRUE( level.acc_dev ) )
		level thread dev_force_spawn_watcher();

	dbg( "init ok - dev=" + ( IS_TRUE( level.acc_dev ) ? "1" : "0" )
	     + " boss round every " + getdvarint( "acc_boss_interval", ACC_BOSS_INTERVAL_DEF )
	     + " from " + getdvarint( "acc_boss_first_round", ACC_BOSS_FIRST_DEF )
	     + " (count scales: round 9=1, 18=2, 27=3, ... types dealt no-duplicate from the 4-boss deck; first repeat = slot 5/round 45)" );
}

// DEV-ONLY debug print: on-screen for the first player AND (unlike acc_utility::log's
// /# println #/ path) it lands in console_mp.log as a [ SCRIPTER] line - the runtime
// oracle for "why didn't the boss spawn" (user 2026-07-02). No-op in normal play.
function dbg( msg )
{
	acc_utility::log( "protector: " + msg );
	// re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
	if ( !IS_TRUE( level.acc_dev ) )
		return;
	players = GetPlayers();
	if ( players.size > 0 && isdefined( players[ 0 ] ) && isplayer( players[ 0 ] ) )
		players[ 0 ] IPrintLnBold( "^6[RP] " + msg );
}

// [acc] ROGUE-PROTECTOR DAMAGE DIAGNOSTIC (user 2026-07-04: "he didn't hit anyone" - zero
// damage). FILE-ONLY via LogPrint (the same channel _acc_diag.gsc uses - "console logs that
// send to a file, not UI logs"). Always on (no dvar) so it captures without touching launch
// flags; lands in the game log (games_mp.log). Read the [RPDIAG] lines after a round-1 fight.
function rp_diag( msg )
{
	LogPrint( "[RPDIAG] " + msg + "\n" );
}

// Logging-only player-damage callback (returns -1 = "no opinion", chain continues untouched).
// THE key probe: if fire_loop reports FIRED but this never logs, the MagicBullet is not applying
// damage to players (team/friendly-fire or AI-MagicBullet-vs-player issue). If it DOES log, the
// damage lands and the problem is elsewhere (e.g. god mode zeroing it after this point).
function rp_damage_probe( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "companion" ) )
	{
		rp_diag( "player HIT by RP weapon '" + weapon.name + "' raw dmg=" + iDamage
		         + " mod=" + ( isdefined( sMeansOfDeath ) ? sMeansOfDeath : "?" )
		         + " loc=" + ( isdefined( sHitLoc ) ? sHitLoc : "?" ) );
	}
	return -1;   // no opinion - never alters the real damage chain
}

function dev_force_spawn_watcher()
{
	level endon( "end_game" );
	for ( ;; )
	{
		if ( getdvarint( "acc_protector_spawn", 0 ) == 1 )
		{
			SetDvar( "acc_protector_spawn", "0" );
			dbg( "force-spawn requested (console)" );
			if ( !isdefined( level.acc_protector_debt ) )
				level.acc_protector_debt = 0;
			level.acc_protector_debt++;   // one more owed -> director spawns within ~3s
		}
		wait 0.25;
	}
}

// ---------------------------------------------------------------------------
// Cadence - the SHARED multi-boss roster (owner module) + a DEBT-based director
// ---------------------------------------------------------------------------
//
// MULTI-BOSS ROUNDS (user 2026-07-03): a boss ROUND lands every 9 rounds from round 9, and the
// COUNT scales with the slot - round 9 = 1 boss, round 18 = 2, round 27 = 3, and so on (slot+1).
// EACH boss that round is an INDEPENDENT 3-way roll: Phantom / Rogue Protector / Avogadro (user
// 2026-07-04). So a round can be one-of-each, all one type, or any mix. Boss music holds until EVERY
// boss that round is dead - the acc_boss::boss_music refcount already does that (each boss threads it).
//
// The roster is rolled ONCE per round and cached on the level (boss_roster) so BOTH boss modules -
// this one and _acc_boss_phantom, whose round_watch threads BOTH fire on the same "acc_round_start"
// notify - read an IDENTICAL roster no matter which thread rolls it first.

// How many bosses TOTAL this round? 0 if not a boss round; else slot+1 (round 9->1, 18->2, 27->3).
function boss_count( round_number )
{
	// DEV fast cadence (every ACC_BOSS_INTERVAL_DEV from ACC_BOSS_FIRST_DEV) DISABLED
	// (user 2026-07-12: "stop the bosses spawning early in dev - annoying"): dev uses the
	// REAL 9/9 schedule. The dvars still override in EITHER mode for a manual fast burst
	// (`+set acc_boss_first_round 3 +set acc_boss_interval 3`).
	first    = getdvarint( "acc_boss_first_round", ACC_BOSS_FIRST_DEF );
	interval = getdvarint( "acc_boss_interval",    ACC_BOSS_INTERVAL_DEF );
	if ( interval < 1 ) interval = 1;
	if ( round_number < first ) return 0;
	if ( ( ( round_number - first ) % interval ) != 0 ) return 0;
	return ( ( round_number - first ) / interval ) + 1;   // slot 0 -> 1 boss, slot 1 -> 2, ...
}

// The per-round ROSTER: an array of "phantom"/"protector"/"avogadro"/"panzer", one entry per boss,
// dealt from a SHUFFLED DECK of the 4 types WITHOUT REPLACEMENT (user 2026-07-08: "no same boss
// spawns until it's required" - the old independent per-slot roll had no guard rails and could
// double a type as early as round 18). The deck reshuffles only when it empties, so rounds with
// 1-4 bosses (9/18/27/36) are always ALL-DISTINCT types, and the first possible duplicate is the
// 5th boss slot (round 45), where it's mathematically forced with a 4-type pool. Rolled once and
// cached (level.acc_boss_roster keyed by level.acc_boss_roster_round) so all boss modules agree
// regardless of which reads it first. Not a boss round -> empty array.
function boss_roster( round_number )
{
	if ( isdefined( level.acc_boss_roster_round ) && level.acc_boss_roster_round == round_number
	     && isdefined( level.acc_boss_roster ) )
		return level.acc_boss_roster;

	n = boss_count( round_number );

	// If the Phantom is DISABLED (acc_phantom_enable 0, non-dev) it adds 0 to its debt for any "phantom"
	// slot - which would SHRINK the round's boss count (a phantom-rolled slot just vanishes, up to a
	// zero-boss round 9). So when the Phantom is off, roll every slot to the Rogue Protector instead, so
	// the COUNT is preserved (the disabled type is RE-HOMED, not dropped). Mirrors phantom_due_count's
	// exact gate (_acc_boss_phantom.gsc). The Rogue Protector has no such disable toggle, so it always
	// absorbs. Default ships enabled, so normal play still gets the full random mix.
	phantom_off = ( getdvarint( "acc_phantom_enable", 1 ) != 1 && !IS_TRUE( level.acc_dev ) );
	// DEV re-home REMOVED (user 2026-07-12): Avogadro + Panzer no longer run dev_test_spawn
	// loops in dev - dev uses the real roster directors - so their slots stay theirs in both
	// modes. Only an explicit enable-0 dvar re-homes them now.
	avo_off     = ( getdvarint( "acc_avo_enable", 1 ) != 1 );
	panzer_off  = ( getdvarint( "acc_panzer_enable", 1 ) != 1 );

	roster = [];
	deck   = [];
	di     = 0;   // deal cursor into the current deck
	for ( i = 0; i < n; i++ )
	{
		// NO-DUPLICATE GUARD (user 2026-07-08): deal from a shuffled 4-type deck without
		// replacement; reshuffle only when it runs dry. Slots 1-4 of a round are therefore
		// always distinct types; slot 5+ (round 45+) starts a fresh deck = the first REQUIRED
		// repeat. (Fisher-Yates on the fixed type list, acc_rand_int = the codebase RNG.)
		if ( di >= deck.size )
		{
			deck = [];
			deck[ 0 ] = "phantom";
			deck[ 1 ] = "protector";
			deck[ 2 ] = "avogadro";
			deck[ 3 ] = "panzer";
			for ( j = deck.size - 1; j > 0; j-- )
			{
				k = acc_utility::acc_rand_int( j + 1 );
				tmp = deck[ j ];
				deck[ j ] = deck[ k ];
				deck[ k ] = tmp;
			}
			di = 0;
		}
		t = deck[ di ];
		di++;
		// A DISABLED type re-homes to the Rogue Protector (which has no toggle) so a disabled
		// deal never SHRINKS the round's boss count - the count-preservation rule (Phantom's
		// original gate). NOTE: re-homing deliberately BREAKS uniqueness (e.g. dev mode re-homes
		// Avogadro + Panzer, so a 3-boss dev round can be several Protectors) - count trumps
		// distinctness when types are unavailable.
		if ( t == "phantom" && phantom_off )
			t = "protector";
		if ( t == "avogadro" && avo_off )
			t = "protector";
		if ( t == "panzer" && panzer_off )
			t = "protector";
		roster[ i ] = t;
	}

	level.acc_boss_roster       = roster;
	level.acc_boss_roster_round = round_number;
	return roster;
}

// PUBLIC (via level.acc_boss_roster_fn): how many of a given TYPE the roster assigns this round.
// str_type = "phantom" | "protector" | "avogadro" | "panzer". Every boss director reads its own count off this.
function boss_type_count( round_number, str_type )
{
	roster = boss_roster( round_number );
	c = 0;
	for ( i = 0; i < roster.size; i++ )
		if ( roster[ i ] == str_type )
			c++;
	return c;
}

function round_watch()
{
	level endon( "end_game" );
	if ( !isdefined( level.acc_protector_debt ) )
		level.acc_protector_debt = 0;
	for ( ;; )
	{
		level waittill( "acc_round_start", round_number );
		n = boss_type_count( round_number, "protector" );
		total = boss_count( round_number );
		dbg( "round " + round_number + " - roster total=" + total + ", Rogue Protectors=" + n );
		if ( n > 0 )
			level.acc_protector_debt += n;   // ADD (not set): a stale debt from an unfinished round carries over
	}
}

// DEBT-based director (multi-boss safe): spawns ONE Rogue Protector per tick while any are owed, so
// a multi-boss round trickles them in ~a few seconds apart (dramatic + easy on the actor pool). No
// one-at-a-time guard anymore - multiple Rogue Protectors are allowed to be alive at once. A spawn
// that fails (pool momentarily full) leaves the debt untouched and simply retries next tick.
function director()
{
	level endon( "end_game" );
	if ( !isdefined( level.acc_protector_debt ) )
		level.acc_protector_debt = 0;
	for ( ;; )
	{
		wait 3;

		// [acc] #6 PARADISE (2026-07-05): during the finale the paradise wave OWNS Rogue Protector spawns
		// (cap 1). Pause the debt director so a carried-over debt can't drop an unauthorized second RP into
		// the arena (which would also grant an extra guaranteed boss reward). Debt is preserved for after.
		if ( IS_TRUE( level.acc_paradise_onslaught ) )
			continue;

		if ( level.acc_protector_debt <= 0 )
			continue;

		dbg( "director: " + level.acc_protector_debt + " Rogue Protector(s) owed -> attempting spawn" );
		boss = spawn_boss();
		if ( isdefined( boss ) && isalive( boss ) )
		{
			level.acc_protector_debt--;
			// Re-arm announce ONLY on success, so the NEXT owed boss announces but a FAILED retry
			// (pool full / no valid player) keeps the flag set and can't re-broadcast the banner every
			// 3s. announce() (called inside spawn_boss) sets the flag true; a fresh boss clears it here.
			level.acc_protector_announced = false;
		}
		// else: debt unchanged, retry next tick; announce stays suppressed (no banner spam on retries).
	}
}

// ---------------------------------------------------------------------------
// Spawn
// ---------------------------------------------------------------------------

function spawn_boss()
{
	// SPAWN ORIGIN: ALWAYS the PLAZA (user 2026-07-05: "have the Rogue Protector spawn at plaza always").
	// Replaces the old trench-prone random-player down-trace ENTIRELY - it stranded him in the bus trench,
	// invisible + unkillable, so the boss music looped forever. Fixed anchor = the Plaza mystery-box chest
	// spot (acc_box_plaza @ 100,-150,14 in the .map): open, central, on the navmesh, always reachable + visible.
	// Live-tunable via acc_protector_spawn_* if the exact spot ever needs a nudge (no rebuild).
	if ( !isdefined( pick_target_player() ) )   // still require a live player (nobody to fight otherwise)
	{
		dbg( "no valid player - retrying" );
		return undefined;
	}
	v_ground = ( getdvarfloat( "acc_protector_spawn_x", 100 ), getdvarfloat( "acc_protector_spawn_y", -150 ), getdvarfloat( "acc_protector_spawn_z", 14 ) );
	ang      = ( 0, getdvarfloat( "acc_protector_spawn_yaw", 0 ), 0 );

	// PARADISE (review fix 2026-07-08): the arena is a separate dimension at z=-1200 and the Plaza anchor
	// (z=14) is unreachable from it - a wave-spawned RP stranded in the empty overworld and jammed the
	// finale's cap-1 gate (its count never decremented). Mirror the Avogadro's paradise branch: spawn ON
	// a living player in the arena. Normal rounds keep the fixed Plaza anchor.
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
	{
		pp = pick_target_player();
		if ( isdefined( pp ) )
		{
			v_ground = pp.origin;
			ang      = ( 0, pp.angles[ 1 ], 0 );
		}
	}

	announce();
	level thread zm_zod_robot::zod_robot_spawn_fx( v_ground );   // ground-tell FX (retires on "robot_landed")
	wait 3;

	// SPAWN, 4th iteration (2026-07-03) - stock's own DIRECT actor spawn, NO spawner anywhere:
	//   SpawnActor( "spawner_<aitype>", origin, angles, targetname, forceSpawn )
	// (stock precedent: nuketown mannequins + MP combat robot). The two spawner-entity roads are
	// both dead ends, PROVEN live: a .map actor_spawner for this axis aitype HARD-CRASHES the
	// game at load, and runtime Spawn("actor_spawner_...") returns undefined (Avogadro's dead
	// end: "[RP] FAIL: runtime Spawn(...) returned undefined"). Needs the zone line
	// aitype,spawner_acc_zod_robot_boss so the derived aitype packs without any BSP entity.
	boss = SpawnActor( "spawner_acc_zod_robot_boss", v_ground, ang, "acc_robot_boss", true );
	if ( isdefined( boss ) )
	{
		dbg( "SpawnActor OK (direct aitype spawn)" );
	}
	else
	{
		// FALLBACK: the load-proven ALLY gold spawner + a runtime team flip - stock's Thrasher
		// does exactly this (archetype_thrasher.gsc:1387 `entity.team = "axis"`).
		dbg( "SpawnActor returned undefined - trying ally-spawner + team flip" );
		if ( isdefined( level.zombie_robot_gold_spawners ) && level.zombie_robot_gold_spawners.size > 0 )
		{
			boss = level.zombie_robot_gold_spawners[ 0 ] SpawnFromSpawner( "acc_robot_boss", 1 );
			if ( isdefined( boss ) )
			{
				boss.team = "axis";
				boss ForceTeleport( v_ground );   // 1-arg form only - the proven stock signature
				dbg( "fallback OK: ally spawn + team->axis" );
			}
		}
	}
	if ( !isdefined( boss ) )
	{
		level notify( "robot_landed" );   // retire the ground-tell FX
		dbg( "FAIL: both spawn paths returned undefined - retrying" );
		return undefined;
	}

	// NOTE: no single level.acc_robot_boss ref anymore - multiple Rogue Protectors can be alive at
	// once (multi-boss rounds, user 2026-07-03). Nothing needs a global "the boss" handle: the stun
	// is applied per-boss in zap_loop(), the nameplate/music are per-actor/refcounted, and rewards
	// fire from each boss's own death_watch. We DON'T set level.ai_robot either (that's the ALLY
	// flow's handle and gates zm_zod_robot's solo-game-end override).

	// --- make the companion archetype behave as a boss ---
	boss.b_robot_finished = 1;     // KILLS the companion services: revive/follow/powerup-chase
	                               // (archetype manage_companion_movement early-outs on this)
	boss.reviving_a_player = 0;
	// COMBAT MODE EXPERIMENT (2026-07-03, "still not shooting" with weapon+enemy+standing all
	// green in the status log): the archetype spawn setup hardwires combatmode = "cover" - a
	// cover-shooter on a map with ZERO cover nodes may never satisfy the cover-flavored ASM/BT
	// routing that leads to the fire states. "no_cover" is the stock open-field combat mode.
	boss.combatmode = "no_cover";
	boss.is_boss = true;           // _acc_zombie_speed excludes is_boss actors (Brutus rule)
	boss.acc_is_mini_boss = true;  // boss headshot handling in _acc_damage where applicable
	boss.acc_is_rogue_protector = true;  // proximity-damage scaling in _acc_elites::on_player_damaged
	                                     // (bullets hit harder up close) keys off THIS marker
	boss.ignore_enemy_count = true;
	boss.ignore_nuke = true;       // a nuke power-up kills axis AI - boss is exempt (Brutus/Glitch rule)
	boss.allow_zombie_to_target_ai = 0;   // archetype spawn setup sets 1; same-team means moot, but explicit
	boss DisableAimAssist();
	boss.disableAmmoDrop = true;
	boss.can_gib_zombies = 0;

	// HP: the SHARED boss scale (base 65k + anchor 5, scale_phantom_hp) but with the Rogue
	// Protector's OWN exponent - the TIER between Brutus and the Phantom (user 2026-07-08: Brutus/Panzer
	// 1.12 > Rogue 1.09 > Phantom 1.06). Then the SAME coop boss-HP table (boss_hp_player_mult:
	// 1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60 - user 2026-07-15, was a log curve). No cap.
	// Rogue solo: r5 65k / r10 100k / r20 237k / r30 561k / r40 1.33M (anchor r5, exp 1.09; user 2026-07-08).
	rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
	hp = int( acc_boss_phantom::scale_phantom_hp( rn, getdvarfloat( "acc_protector_hp_exp", ACC_PROTECTOR_HP_EXP ) ) * acc_coop_scaling::boss_hp_player_mult() );
	boss.maxhealth = hp;
	boss.health = hp;

	// Crosshair damage numbers for hits on him (the ally test showed none - he doesn't
	// route through the zombie damage pipeline, so we feed them from his own AI damage
	// callback chain instead).
	AiUtility::AddAIOverrideDamageCallback( boss, &boss_damage_feed );

	// --- entrance: SELF-CONTAINED slam-down (2026-07-03). The pack's entrance pieces are both
	// hardwired to the ALLY flow and broke live: zod_robot_do_landing derefs level.ai_robot
	// (unset in the boss path -> "undefined is not an object", zm_zod_robot.gsc:293) and the
	// cin_zod_robot_companion_entrance scene spawns ITS OWN robot actor (the frozen duplicate
	// the user saw). So: spawn ON the telegraphed ground point, then quake + landing FX +
	// kill-splash (zod_robot_do_landing_damage is public and carries no ally refs) + rumble.
	boss PlayLoopSound( "fly_civil_protector_loop" );   // his hover-jet hum
	Earthquake( 0.55, 1.2, v_ground, 1200 );
	PlayFX( level._effect[ "robot_landing" ], v_ground );
	// Landing kill-splash: LOCAL copy of zod_robot_do_landing_damage that EXCLUDES the boss.
	// The pack's version DoDamages every AXIS AI in radius - fine for the ALLIES-team ally,
	// LETHAL for our axis-team boss standing at ground zero (live 2026-07-03: he landed,
	// splashed HIMSELF, died, the director saw a dead spawn and spawned another -> the
	// infinite spawn-die loop, complete with boss rewards every cycle).
	level thread landing_kill_splash( v_ground, boss );
	level notify( "robot_landed" );   // retires the ground-tell FX
	boss.v_robot_land_position = v_ground;
	level thread landing_rumble();
	level thread zm_zod_robot::zod_robot_play_vox( boss, "activated" );

	// --- boss presentation: 3D nameplate (via the shared notify) + boss music ---
	level notify( "acc_boss_spawned", boss, ACC_PROTECTOR_NAME );
	level thread acc_boss::boss_music( boss );
	dbg( "boss music thread started (acc_brutus_music via acc_boss::boss_music)" );

	// --- TWO ATTACKS (user 2026-07-03) + drive + death ---
	boss thread hunt_players();
	boss thread fire_loop();   // ranged: 4 chip bullets (28 base, proximity-ramped) then a REAL s1_mahem rocket; knockback per hit (_acc_elites)
	boss thread zap_loop();    // close-range: electric burst + spark report + 25% slow
	boss thread dev_boss_status();
	boss thread death_watch();

	dbg( "spawned OK - round " + rn + ", " + hp + " hp" );

	// [acc] spawn-time damage diagnostic (file-only LogPrint via rp_diag; the acc_protector_debug
	// dvar was removed 2026-07-16). These four answer most of
	// "why no damage": team must be axis (allies = friendly fire = ZERO player dmg), god must be
	// off (dev god zeroes all incoming), the fire weapon must resolve, and its playerDamage.
	w_diag = GetWeapon( "ar_standard_upgraded_companion_zm" );
	boss rp_diag( "SPAWN team=" + ( isdefined( boss.team ) ? boss.team : "?" )
	              + " level.acc_god=" + ( IS_TRUE( level.acc_god ) ? "1" : "0" )
	              + " level.acc_dev=" + ( IS_TRUE( level.acc_dev ) ? "1" : "0" )
	              + " fireWeapon=" + ( isdefined( w_diag ) ? w_diag.name : "UNDEFINED" ) );
	return boss;
}

// Landing kill-splash (zod_robot_do_landing_damage minus the self-kill): every axis AI in
// radius EXCEPT any BOSS dies with a ragdoll fling away from the impact. Skipping ALL bosses (not
// just the one landing) is the multi-boss fix (user 2026-07-03): on a 2+/3+ boss round two Rogue
// Protectors can slam down within 350u of each other, and the pack's splash would DoDamage the
// other boss to death (the same self-kill loop, just aimed at a sibling). Any Phantom / Brutus /
// Subroutine Core caught in the blast is spared too - bosses never die to another boss's entrance.
function landing_kill_splash( v_origin, e_boss )
{
	level endon( "end_game" );
	n_radius = 350;
	a_ai = GetAITeamArray( "axis" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai_zombie = a_ai[ i ];
		if ( !isdefined( ai_zombie ) || !isalive( ai_zombie ) )
			continue;
		if ( isdefined( e_boss ) && ai_zombie == e_boss )
			continue;   // never splash the boss who is landing
		if ( IS_TRUE( ai_zombie.is_boss ) || IS_TRUE( ai_zombie.acc_is_boss ) || IS_TRUE( ai_zombie.acc_is_mini_boss ) )
			continue;   // and never splash ANY other boss (sibling Rogue Protector / Phantom / Brutus)
		if ( DistanceSquared( ai_zombie.origin, v_origin ) > n_radius * n_radius )
			continue;

		v_fling = ai_zombie.origin - v_origin;
		v_fling = v_fling + ( 0, 0, 15 );
		v_fling = VectorNormalize( v_fling );
		v_fling = ( v_fling[ 0 ], v_fling[ 1 ], abs( v_fling[ 2 ] ) );
		v_fling = VectorScale( v_fling, 60 );

		ai_zombie DoDamage( ai_zombie.health + 10000, ai_zombie.origin );
		ai_zombie StartRagdoll();
		ai_zombie LaunchRagdoll( v_fling );
	}
}

// Heavy-impact rumble for the slam-down (mirrors the tail of the pack's do_landing).
function landing_rumble()
{
	level endon( "end_game" );
	for ( i = 0; i < 5; i++ )
	{
		players = GetPlayers();
		for ( j = 0; j < players.size; j++ )
		{
			if ( isdefined( players[ j ] ) && isplayer( players[ j ] ) )
				players[ j ] PlayRumbleOnEntity( "damage_heavy" );
		}
		wait 0.1;
	}
}

function pick_target_player()
{
	candidates = [];
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[ i ] ) && zm_utility::is_player_valid( players[ i ] ) )
			candidates[ candidates.size ] = players[ i ];
	}
	if ( candidates.size == 0 )
		return undefined;
	return candidates[ acc_utility::acc_rand_int( candidates.size ) ];
}

// Once per owed cycle (the director retries spawn_boss every 3s under a full
// actor pool - without the guard this would spam every retry).
function announce()
{
	if ( IS_TRUE( level.acc_protector_announced ) )
		return;
	level.acc_protector_announced = true;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isdefined( p ) && isplayer( p ) )
			p IPrintLnBold( "^1" + ACC_PROTECTOR_NAME + " ^7- Civil Protection unit compromised..." );
	}
}

// ---------------------------------------------------------------------------
// Combat drive - keep him pressing the closest player. The BT does the actual
// fighting (shoot / cover / juke); we just keep the goal + favoriteenemy fresh
// so he advances instead of holding his landing spot (his companion movement
// service is disabled via b_robot_finished).
// ---------------------------------------------------------------------------

// RELENTLESS CHASE (user 2026-07-03: "he needs to move towards players like all enemies
// do, and he needs to be pretty fast"). The old stop-and-shoot pacing is OBSOLETE - the
// script fire loop (MagicBullet) shoots fine while moving, so he now hunts flat-out:
//   - goal re-pinned to the closest player every 0.5s (zombie-style pursuit);
//   - SPRINT LOCK: his BT's walk/sprint chooser (zodcompanionkeepscurrentmovementmode)
//     compares his distance to `v_robot_land_position` - >512u away means SPRINT. Pinning
//     the "land position" to a point far below the map keeps that check permanently true,
//     so the BT holds his fast sprint gait full-time.
function hunt_players()
{
	self endon( "death" );
	level endon( "end_game" );

	self.acc_hunt_moving = true;

	for ( ;; )
	{
		self.v_robot_land_position = ( 0, 0, -100000 );   // sprint lock (see header)

		target = undefined;
		best = 999999999;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			d = DistanceSquared( self.origin, p.origin );
			if ( d < best )
			{
				best = d;
				target = p;
			}
		}

		if ( isdefined( target ) )
		{
			self.favoriteenemy = target;
			// [acc] #8 (2026-07-05): removed the dead "freeze while gun cooling" branch. It gated on
			// self.acc_protector_cooling, which the rewritten fire_loop (4 bullets + 1 explosive) never
			// sets, so the branch was permanently false and he chased anyway. Now he unconditionally
			// chases - the behavior that was actually happening all along (no gameplay change).
			self SetGoal( target.origin, 1 );
		}

		wait 0.5;
	}
}

// DEV status logger (user 2026-07-03 "add logs if you need to"): every 3s for ~36s after
// spawn, print the fire-decision inputs - weapon equipped? engine enemy committed? distance?
// still locomoting? Whatever still blocks the trigger shows up here.
function dev_boss_status()
{
	self endon( "death" );
	level endon( "end_game" );
	if ( !IS_TRUE( level.acc_dev ) )   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
		return;

	for ( i = 0; i < 12; i++ )
	{
		str_weap = "NONE";
		if ( isdefined( self.weapon ) )
			str_weap = self.weapon.name;
		n_dist = -1;
		str_see = "-";
		str_shoot = "-";
		if ( isdefined( self.enemy ) )
		{
			n_dist = int( Distance( self.origin, self.enemy.origin ) );
			str_see = ( self CanSee( self.enemy ) ? "1" : "0" );
			str_shoot = ( self CanShootEnemy() ? "1" : "0" );
		}
		dbg( "status: weap=" + str_weap
		     + " enemy=" + ( isdefined( self.enemy ) ? "YES" : "no" )
		     + " dist=" + n_dist
		     + " see=" + str_see + " shoot=" + str_shoot
		     + " ammo=" + ( isdefined( self.bulletsInClip ) ? self.bulletsInClip : -1 )
		     + " moving=" + ( IS_TRUE( self.acc_hunt_moving ) ? "1" : "0" ) );
		wait 3;
	}
}

// ---------------------------------------------------------------------------
// SCRIPT-DRIVEN FIRE (2026-07-03, the hack that ships): every soft gate was proven
// green live (weapon equipped, enemy committed, standing, LOS - "see=1") yet the
// engine's CanShootEnemy() verdict stays 0 permanently ("shoot=0"), so his BT's
// shoot actions never run and no script lever flips that engine check. So WE pull
// the trigger: one MagicBullet per interval from his muzzle at the target - a REAL
// bullet from his real gun with HIM as attacker, so it carries the weapon's
// playerDamage 10, routes through the player-damage chain (god mode respected).
// (The STUN is separate - it rides the close-range zap in zap_loop, not the bullets.)
// Stock precedent for the builtin: _zm_aat_fire_works.gsc MagicBullet(w, from, to, ent).
// Cadence: acc_protector_fire_interval (1.5s). Aim: chest with a small random
// spread - most shots land at close/mid range (the design: chip + stun pressure).
// ---------------------------------------------------------------------------

// FIRE PATTERN (user 2026-07-04): 4 chip bullets, then ONE big mahem explosive, then a
// acc_protector_mahem_cooldown (3s) pause before the next cycle. He keeps CHASING the whole time
// (the old "freeze while cooling" was removed 2026-07-05 - it was never wired up); the counterplay
// window is the gap between explosive volleys. Get Jugg (250 HP) to survive a concentrated burst.
function fire_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	// ZERO-DAMAGE BUG FIX (user 2026-07-04, confirmed in console_mp.log): GetWeapon(
	// "ar_standard_upgraded_companion_zm" ) returns the 'none' weapon at RUNTIME - the weapon is
	// AI-only (pulled into the .ff via the boss aitype's primaryweapon1, NOT registered in the
	// level weapon table that GetWeapon queries), so `MagicBullet( none, ... )` threw
	// "MagicBullet called with weapon 'none'" EVERY 1.5s and NO bullet ever fired -> he did zero
	// damage since the fire loop was written. The boss aitype equips this weapon, so the ENGINE-
	// resolved object is on self.weapon - use THAT (valid) instead of the string lookup.
	w = self.weapon;
	if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
		w = GetWeapon( "ar_standard_upgraded_companion_zm" );   // last-ditch fallback (may be none - guarded at fire)
	b_announced = false;
	n_shots = 0;

	for ( ;; )
	{
		// ONE bullet every 1.25s, NO burst/cooldown (user 2026-07-04: "it shouldn't be a burst -
		// he should shoot one bullet every 1.25 seconds"). Steady chip pressure at 25/bullet.
		wait getdvarfloat( "acc_protector_fire_interval", 2.5 );

		// Target: the engine-committed enemy if it's a valid player, else the closest valid player.
		target = undefined;
		if ( isdefined( self.enemy ) && isplayer( self.enemy ) && zm_utility::is_player_valid( self.enemy ) )
			target = self.enemy;
		else if ( isdefined( self.favoriteenemy ) && isplayer( self.favoriteenemy ) && zm_utility::is_player_valid( self.favoriteenemy ) )
			target = self.favoriteenemy;
		if ( !isdefined( target ) )
		{
			rp_diag( "fire: NO TARGET (enemy/favoriteenemy not a valid player)" );
			continue;
		}

		n_dist_diag = Distance( self.origin, target.origin );
		if ( n_dist_diag > getdvarfloat( "acc_protector_fire_range", 1500 ) )
		{
			rp_diag( "fire: OUT OF RANGE dist=" + int( n_dist_diag ) + " > " + int( getdvarfloat( "acc_protector_fire_range", 1500 ) ) );
			continue;
		}
		if ( !( self CanSee( target ) ) )
		{
			rp_diag( "fire: NO LOS to " + target.name + " dist=" + int( n_dist_diag ) );
			continue;
		}

		// Muzzle: tag_flash (the gun muzzle, if the attached weapon exposes it) -> the rig's
		// right weapon hand tag (aitype worldModelTagRight, guaranteed) -> chest fallback.
		str_tag = "tag_flash";
		v_muzzle = self GetTagOrigin( "tag_flash" );
		if ( !isdefined( v_muzzle ) )
		{
			str_tag = "tag_weapon_right";
			v_muzzle = self GetTagOrigin( "tag_weapon_right" );
		}
		if ( !isdefined( v_muzzle ) )
		{
			str_tag = "";
			v_muzzle = self.origin + ( 0, 0, 55 );   // chest-height fallback (no fx here - a
			                                          // body-centred burst reads as a self-explosion)
		}

		// Chest aim + small spread: hits most of the time up close, occasional misses at range.
		v_aim = target.origin + ( 0, 0, 45 );
		v_aim = v_aim + ( acc_utility::acc_rand_int( 17 ) - 8, acc_utility::acc_rand_int( 17 ) - 8, acc_utility::acc_rand_int( 11 ) - 5 );

		// Re-resolve the weapon each shot in case self.weapon populated late, and HARD-GUARD:
		// never call MagicBullet with a 'none' weapon (that was the crash - it must not recur).
		if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
		{
			if ( isdefined( self.weapon ) && self.weapon != level.weaponNone && isdefined( self.weapon.name ) && self.weapon.name != "none" )
				w = self.weapon;
		}
		if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || w.name == "none" )
		{
			rp_diag( "fire: SKIP - no valid weapon (self.weapon=" + ( isdefined( self.weapon ) && isdefined( self.weapon.name ) ? self.weapon.name : "undef" ) + ")" );
			continue;
		}

		// ATTACK PATTERN (user 2026-07-04): 4 bullet shots, then ONE big explosive (mahem-style),
		// then a 3s cooldown, repeat. n_shots counts 1..4 = bullets; the 5th tick = the explosive.
		n_shots++;
		if ( n_shots <= 4 )
		{
			// NORMAL BULLET (25 explosive splash) + RW1 report + energy muzzle flash (client pulse;
			// server-side FX/sound on actors is dead in this build).
			MagicBullet( w, v_muzzle, v_aim, self );
			acc_boss_nameplate::shot_pulse( self );
			rp_diag( "fire: bullet " + n_shots + "/4 at " + target.name + " dist=" + int( n_dist_diag ) );
		}
		else
		{
			// 5th = the ROCKET: a real, VISIBLE s1_mahem projectile (player damage capped in
			// _acc_elites' rocket lane), then a cooldown before the next 4-bullet cycle.
			mahem_shot( target, v_muzzle, v_aim, w );
			n_shots = 0;
			wait getdvarfloat( "acc_protector_mahem_cooldown", 3.0 );
		}

		if ( !b_announced )
		{
			b_announced = true;
			dbg( "fire loop ACTIVE (4 bullets + 1 explosive @ " + getdvarfloat( "acc_protector_fire_interval", 2.5 ) + "s)" );
		}
	}
}

// The 5th shot: the ROCKET. Since 2026-07-09 ("his rocket launcher doesn't look like it works")
// this fires a REAL s1_mahem projectile via MagicBullet - the SoE Mahem is in the ZM levelcommon
// weapon table, so GetWeapon resolves it at runtime and the shot carries the launcher's own rocket
// model, smoke trail, explosion FX and boom SOUND (everything the old invisible scripted
// RadiusDamage lacked). Its raw playerDamage is the 3100 one-shot that forced the scripted
// explosion in the first place - that is now HARD-CAPPED player-side to acc_protector_mahem_dmg
// (55) in _acc_elites::on_player_damaged (the rocket lane; big knockback rides the same hit).
// Zombies caught in the blast just die - the boss only chips himself (65k+ hp) if he point-blanks.
// The scripted RadiusDamage survives only as the fallback if s1_mahem ever fails to resolve.
function mahem_shot( target, v_muzzle, v_aim, w )
{
	w_rocket = GetWeapon( "s1_mahem" );
	if ( isdefined( w_rocket ) && w_rocket != level.weaponNone && isdefined( w_rocket.name ) && w_rocket.name != "none" )
	{
		MagicBullet( w_rocket, v_muzzle, v_aim, self );   // a real rocket from his muzzle at the target
		acc_boss_nameplate::mahem_pulse( self );          // client-side: launch boom + muzzle flash on the boss
		rp_diag( "fire: ROCKET (s1_mahem projectile, player dmg capped in _acc_elites) at " + ( isdefined( target ) ? target.name : "?" ) );
		return;
	}

	// FALLBACK ONLY (s1_mahem unresolvable): the pre-2026-07-09 invisible-but-exact scripted blast.
	dmg    = getdvarint( "acc_protector_mahem_dmg", 69 );   // [acc] RP ROCKET +25% (user 2026-07-12: 55 -> 69; matches the _acc_elites cap)
	radius = getdvarint( "acc_protector_mahem_radius", 180 );
	dmg_min = int( dmg / 3 );
	RadiusDamage( v_aim, radius, dmg, dmg_min, self, "MOD_PROJECTILE_SPLASH", w );
	if ( isdefined( level._effect[ "robot_landing" ] ) )
		PlayFX( level._effect[ "robot_landing" ], v_aim );
	acc_boss_nameplate::mahem_pulse( self );
	rp_diag( "fire: MAHEM fallback RadiusDamage (" + dmg + " dmg, r" + radius + ") - s1_mahem did not resolve" );
}

// SECOND ATTACK - close-range ZAP (user 2026-07-03: "he has two attacks, shooting and zapping").
// When a valid player is within acc_protector_zap_range (350u) with LOS, every
// acc_protector_zap_interval (3s) he discharges: a big electric burst enveloping him (client
// zap_pulse -> _acc_boss_nameplate.csc) + the 25% move slow on the target (acc_elites::
// acc_protector_zap, which also plays the zap SFX on the player + is Mega-Electric-Cherry-immune).
// This is the DISTINCT second move: shooting is his ranged pressure, zapping punishes getting close.
function zap_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait getdvarfloat( "acc_protector_zap_interval", 3.0 );

		// Weapon for the pulse's RadiusDamage attribution (the boss's own equipped weapon; valid
		// object, unlike a GetWeapon string lookup - same lesson as the fire loop).
		w_zap = self.weapon;
		if ( !isdefined( w_zap ) || w_zap == level.weaponNone )
			w_zap = GetWeapon( "ar_standard_upgraded_companion_zm" );

		// PASSIVE PULSE (user 2026-07-04: "if he gets close he stuns people"): a RADIUS discharge
		// around him - EVERY valid player within acc_protector_zap_range (250) is stunned + takes
		// acc_protector_pulse_dmg (10). No LOS gate (it's a proximity burst, not an aimed attack).
		n_range = getdvarfloat( "acc_protector_zap_range", 250 );
		players = GetPlayers();
		any = false;
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			if ( DistanceSquared( self.origin, p.origin ) > n_range * n_range )
				continue;
			any = true;
			p acc_elites::acc_protector_zap();          // player-side: 25% slow (3s) + zap SFX (god-safe)
		}
		if ( !any )
			continue;

		acc_boss_nameplate::zap_pulse( self );          // boss-side: electric burst FX + spark report
		// 10 AOE damage on top of the stun (dvar acc_protector_pulse_dmg; 0 = stun-only). Scripted
		// RadiusDamage so it's exact + god-safe; the boss (attacker) is never self-hit.
		pulse_dmg = getdvarint( "acc_protector_pulse_dmg", 10 );
		if ( pulse_dmg > 0 )
			RadiusDamage( self.origin, n_range, pulse_dmg, pulse_dmg, self, "MOD_GRENADE_SPLASH", w_zap );
	}
}

// ---------------------------------------------------------------------------
// Damage plumbing
// ---------------------------------------------------------------------------

// AI-damage callback ON the boss: feed the crosshair damage number to the shooter
// (must return the damage unchanged - the archetype's own gib/head callbacks chain).
function boss_damage_feed( inflictor, attacker, damage, flags, meansOfDeath, weapon, point, dir, hitLoc, offsetTime, boneIndex, modelIndex )
{
	if ( isdefined( attacker ) && isplayer( attacker ) )
	{
		// Melee gate added 2026-07-06 to match the main on_ai_damage feed (melee never headshots,
		// user 2026-06-23) - a knife to the boss's head no longer tints teal. Head tint itself is
		// hit-loc only (no shotgun exclusion), same as the main feed's b_head_display.
		b_head = ( isdefined( hitLoc ) && IsInArray( array( "head", "neck", "helmet" ), hitLoc )
		           && !acc_damage::is_melee_mod( meansOfDeath ) );
		// feed_dmg_number is public + self-guarding (no-ops when the damage-number HUD isn't up).
		acc_damage::feed_dmg_number( attacker, int( damage ), b_head );
	}
	return damage;
}

// (His OUTGOING bullet damage vs players is tuned in the weapon GDT `playerDamage`
// field - install-side, both companion weapon entries: 10 flat, one shot / 1.5s via
// the boss aitype's burstCount 1 + fireInterval 1.5 - NOT via a damage-value
// callback; see the module header for why an opinionated callback is dangerous.)

// (Boss-hit STUN: applied PER-BOSS in zap_loop() -> acc_elites::acc_protector_zap() on the
// close-range zap, NOT on bullet hits (bullets are pure chip damage). It's driven from the boss's
// own thread, so it lands under god/dev exactly like the Phantom's, and each Rogue Protector on a
// multi-boss round zaps independently. -25% slow 3s; Mega Electric Cherry softens it to -10%.)

// ---------------------------------------------------------------------------
// Death + rewards (the Trench Warden's flat set: item + points + 50% bottle)
// ---------------------------------------------------------------------------

function death_watch()
{
	level endon( "end_game" );

	self waittill( "death", attacker );

	// COOP CRASH GUARD: the corpse can be reaped the same frame the death notify fires (4p corpse churn) -
	// any self deref then throws "not an entity" and ends the whole match (same race phantom_death_watch
	// guards). Fall back to the killer's origin so the reward still pays out when the corpse is already gone.
	if ( isdefined( self ) )
	{
		self StopLoopSound();   // kill the hover-jet hum (PlayLoopSound at spawn) - it otherwise loops on the corpse forever
		drop_origin = self.origin;
	}
	else if ( isdefined( attacker ) && isplayer( attacker ) )
	{
		drop_origin = attacker.origin;
	}
	else
	{
		return;   // no corpse and no killer to anchor the drop - nothing safe to reference
	}
	acc_utility::log( "protector boss: KILLED (round " + level.round_number + ")" );

	// NO drops during the Paradise final battle (2026-07-09 parity audit): the RP was the ONLY boss whose
	// death reward still fired in the arena - Panzer/Avogadro/Phantom/Brutus all suppress theirs there (the
	// documented survive-not-farm finale: power-ups + shards are blocked too). Align with the others.
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
		return;

	// Shared boss reward (user 2026-07-05: every boss identical - this FIXES the Rogue Protector granting
	// ZERO shards): 1 item + 1 bottle + round*300 pts + int(round/3) shards, to every player.
	acc_boss::grant_unified_boss_reward( drop_origin );
}
