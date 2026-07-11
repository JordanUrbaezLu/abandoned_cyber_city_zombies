// =============================================================================
// _acc_boss_panzer.gsc - the PANZER boss (Spiki asset-dump mechz port, 4th roster type; renamed from PANZER SOLDAT, user 2026-07-08).
//
// Identity (user 2026-07-08): the literal Der Eisendrache PANZER chassis as our heaviest
// walker - the TANK of the roster. Tier ladder on the shared 65k/anchor-5 scale_phantom_hp
// scale: PANZER 1.09 (= the Rogue Protector tier, user 2026-07-08 final; earlier
// walked 1.12->1.13->1.14->1.12->1.09) - ladder Brutus 1.12 > Rogue/Panzer 1.09 > Phantom/Avogadro 1.06. Melee hits VERY hard
// (acc_panzer_melee_damage, default 90) + the stock
// mechz flamethrower/grenade BT attacks ride along from the pack.
//
// HISTORY: previously WORKED in-game 2026-06-19, dropped in the 2026-06-22 WIP sync, rebuilt
// 2026-07-08 from tools/_panzer_stash/ (recipe in its README.md + docs/research/
// BO3_Panzer_mechz_usermap_method.txt). THE historical "game breaks when he attacks" CTD =
// the one-sided mechz_face clientfield - fixed in the vendored scripts/zm/mechz_spiki.gsc
// (no-op face StartFunctions) + .csc (mirror-registered stock fields). Read both headers
// before touching ANY mechz surface.
//
// SPAWN = SpawnActor("archetype_zm_mechz_genesis", ...) at his OWN Plaza anchor - the central
// Plaza riser (-227.5, 350, 0), the proven 2026-06-19 spot, deliberately ~600u from the Rogue
// Protector's chest-spot anchor so the two never overlap - with a navmesh scatter that dodges
// every living boss (multi-boss rounds). NO .map spawner entity (custom-aitype .map spawners
// crashed the LED bake (Avogadro) and game load (Rogue Protector); script-only spawning also
// keeps every Panzer change a -GscOnly build). Stock blackboard init + mechzSpawnSetup + the
// pack's per-spawn init all run via the "mechz" archetype spawn functions;
// mechz_spiki::acc_setup_mechz() applies the rest.
//
// CADENCE: joins the shared boss roster as the 4th type ("panzer" in the no-duplicate deck deal,
// _acc_civil_protector::boss_roster - a repeat of any type first appears at the forced 5th slot,
// round 45) - a debt director like the other three. DEV mode instead runs a repeating test-spawn
// loop (Avogadro pattern; the roster re-homes "panzer" slots in dev). Toggle live:
// acc_panzer_enable 0. Trace: acc_panzer_debug 1.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\spawner_shared;   // run_spawn_functions - the SpawnActor spawn-func self-heal
#using scripts\shared\util_shared;

#using scripts\zm\_zm_utility;          // is_player_valid (electroball zap targeting)

#using scripts\zm\mechz_spiki;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_elites;      // acc_protector_zap - the SHARED boss zap slow (electroball impact applies it)

#insert scripts\shared\shared.gsh;

#define ACC_PANZER_ENABLE_DEF     1
#define ACC_PANZER_DISPLAY_NAME   "PANZER"   // user 2026-07-08: renamed from "PANZER SOLDAT" (nameplate + all UI)
#define ACC_PANZER_HP_EXP         1.09   // MATCHES THE ROGUE PROTECTOR (user 2026-07-08 final: "match the RP" after the 1.12/1.13/1.14 tank-tier ladder) - ladder now Brutus 1.12 > Rogue/Panzer 1.09 > Phantom/Avogadro 1.06 on the SHARED 65k/anchor-5 scale. Live dvar acc_panzer_hp_exp.
#define ACC_PANZER_TEST_ROUND     2      // DEV: first test spawn at round 2 (user 2026-07-08, was 3), keep exactly one alive (Avogadro pattern)
#define ACC_PANZER_CLEARANCE      150    // units of spawn clearance from every living boss (pick_spawn_point)

#namespace acc_boss_panzer;

function dbg( msg )
{
	// Same contract as the Avogadro's dbg: key [PANZER] events log whenever level.acc_dev is on
	// (lands in console_mp.log as [SCRIPTER] via acc_utility::log + on-screen), opt-in via
	// acc_panzer_debug 1 outside dev. Normal play = silent.
	if ( getdvarint( "acc_panzer_debug", 0 ) != 1 )   // acc_dev DECOUPLED 2026-07-10 (clean screen; [PANZER] rides acc_panzer_debug now)
		return;
	acc_utility::log( "[PANZER] " + msg );
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
		if ( isdefined( players[ i ] ) )
			players[ i ] IPrintLnBold( "^1[PANZER]^7 " + msg );
}

// ---------------------------------------------------------------------------
// Init + cadence
// ---------------------------------------------------------------------------

function init()
{
	level endon( "end_game" );

	if ( getdvarint( "acc_panzer_enable", ACC_PANZER_ENABLE_DEF ) != 1 )
		return;

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3;

	if ( !isdefined( level.acc_panzer_debt ) )
		level.acc_panzer_debt = 0;
	level.acc_panzer_alive = 0;

	// Seed the pack's health-scaler base fields ONCE. mechz_spiki::mechz_health_increases()
	// (defined-but-never-called in the pack - calling it is recipe item #2, else HP=undefined)
	// reads all of these and THROWS on any undefined (T7 arithmetic-on-undefined). The DLC map's
	// original values were lost with the decompile; these are re-derived for sane armor-break
	// pacing - the BODY health is overridden per spawn by the shared roster curve anyway, and
	// the caps inside the scaler (17500/16000/7500/5000/3500 x player-mod) bound the compounding.
	if ( !isdefined( level.mechz_base_health ) )           level.mechz_base_health = 4000;
	if ( !isdefined( level.mechz_health_increase ) )       level.mechz_health_increase = 250;
	if ( !isdefined( level.var_fa14536d ) )                level.var_fa14536d = 1500;   // faceplate base
	if ( !isdefined( level.var_1a5bb9d8 ) )                level.var_1a5bb9d8 = 100;    // faceplate per-round increase
	// (lowercase spellings of the pack's level.MECHZ_POWERCAP_* fields - GSC field names are
	// case-insensitive, and the ALL-CAPS forms shadow same-named mechz.gsh macros in the lint)
	if ( !isdefined( level.mechz_powercap_cover_health ) ) level.mechz_powercap_cover_health = 750;   // read-modify-write in the scaler - MUST be pre-seeded
	if ( !isdefined( level.var_a1943286 ) )                level.var_a1943286 = 50;     // powercap-cover increase
	if ( !isdefined( level.mechz_powercap_health ) )       level.mechz_powercap_health = 500;         // read-modify-write - pre-seed
	if ( !isdefined( level.var_9684c99e ) )                level.var_9684c99e = 50;     // powercap increase
	if ( !isdefined( level.var_3f1bf221 ) )                level.var_3f1bf221 = 350;    // knee/shoulder armor base
	if ( !isdefined( level.var_158234c ) )                 level.var_158234c = 25;      // armor increase
	// Thundergun clamp: mechz_spiki::function_b8e0ce15 deals clamp(level.mechz_health, 0,
	// var_f4dc2834) * 1.25 damage per blast. The seed used to come from the pack's bow autoexec
	// (disarmed) - WITHOUT it the clamp is skipped and one Thundergun blast = 1.25x max HP =
	// instakill. Our BO1 Thundergun is live on this map, so this seed is load-bearing.
	if ( !isdefined( level.var_f4dc2834 ) )                level.var_f4dc2834 = 3062.5;

	// ELECTROBALL IMPACT + BOSS ZAP watcher (user 2026-07-08): "his zap grenades trigger the
	// boss zap slow - all bosses have it - and they need to explode on impact." One global
	// watcher covers every Panzer's grenades (see electroball_watch).
	level thread electroball_watch();

	if ( IS_TRUE( level.acc_dev ) )
	{
		dbg( "DEV mode - running repeating test-spawn loop (roster re-homes panzer slots)" );
		level thread dev_test_spawn();
	}
	else
	{
		level thread round_watch();
		level thread director();
	}
}

// ---------------------------------------------------------------------------
// Electroball grenade: impact-detonation + the shared boss zap
// ---------------------------------------------------------------------------
//
// The pack's _electroball_grenade.gsc/.csc (deliberately NOT vendored - 5 extra clientfields
// for cosmetic ball behavior) were what impact-detonated the 115 grenade; without them it
// cooked its full fuse on the ground (user: "they need to explode on impact"). This owns both
// halves script-side:
//   1. IMPACT: force-Detonate on the first surface contact ("grenade_bounce", the stock
//      proximity-grenade recipe); the GDT fuse stays as the stray fallback.
//   2. ZAP: on explosion, every valid player inside acc_panzer_zap_radius (200 = the GDT
//      explosionRadius) gets the SHARED boss zap slow via acc_elites::acc_protector_zap -
//      the EXACT applicator every boss uses (user: "all bosses have it"): Battery boss item
//      absorbs it, Mega Electric Cherry Power Surge softens it to -10%, 3s refreshing window,
//      lands under god mode so dev tests always show it.
// Grenades are found by their projectile model (only the Panzer's 115 grenade uses it) via a
// 4Hz classname scan - fully decoupled from the stock launch internals (no notetrack override).

function electroball_watch()
{
	level endon( "end_game" );
	if ( IS_TRUE( level.acc_panzer_eball_watch ) )   // one global watcher, survive re-init
		return;
	level.acc_panzer_eball_watch = true;
	for ( ;; )
	{
		wait 0.25;
		grenades = GetEntArray( "grenade", "classname" );
		for ( i = 0; i < grenades.size; i++ )
		{
			g = grenades[ i ];
			if ( !isdefined( g ) || IS_TRUE( g.acc_eball_watched ) )
				continue;
			if ( !isdefined( g.model ) || g.model != "p7_zm_ctl_115_grenade_lod0" )
				continue;
			g.acc_eball_watched = true;
			dbg( "electroball: tracking grenade @ " + g.origin );
			g thread electroball_impact();
		}
	}
}

function electroball_impact()   // self = the grenade
{
	level endon( "end_game" );
	self thread electroball_bounce_detonate();
	self waittill( "explode", pos );
	if ( !isdefined( pos ) )
		return;
	r = getdvarfloat( "acc_panzer_zap_radius", 200 );
	zapped = 0;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
			continue;
		if ( DistanceSquared( pos, p.origin ) <= r * r )
		{
			p acc_elites::acc_protector_zap();   // the shared boss zap (Battery/Power-Surge aware, 3s refresh)
			zapped++;
		}
	}
	if ( zapped > 0 )
		dbg( "electroball EXPLODED @ " + pos + " - zapped " + zapped + " player(s)" );
}

function electroball_bounce_detonate()   // self = the grenade
{
	self endon( "explode" );   // fused naturally first - stand down
	level endon( "end_game" );
	self waittill( "grenade_bounce" );
	if ( isdefined( self ) )
		self Detonate();
}

// How many "panzer" slots the shared roster assigns this round (via the published pointer,
// NOT a #using of _acc_civil_protector - that would cycle). 0 if the roster isn't up yet.
function due_count( round_number )
{
	if ( getdvarint( "acc_panzer_enable", ACC_PANZER_ENABLE_DEF ) != 1 )
		return 0;
	if ( !isdefined( level.acc_boss_roster_fn ) )
		return 0;
	return [[ level.acc_boss_roster_fn ]]( round_number, "panzer" );
}

function round_watch()
{
	level endon( "end_game" );
	for ( ;; )
	{
		level waittill( "acc_round_start", round_number );
		n = due_count( round_number );
		if ( n > 0 )
		{
			level.acc_panzer_debt += n;      // ADD (a stale debt carries over), same as the other bosses
			dbg( "round " + round_number + " - " + n + " Panzer(s) owed (debt=" + level.acc_panzer_debt + ")" );
		}
	}
}

function director()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 3;
		// PARADISE: the finale owns its arena spawns - pause the debt director so a carried
		// debt can't drop an unauthorized Panzer into the arena (same rule as every boss).
		if ( IS_TRUE( level.acc_paradise_onslaught ) )
			continue;
		if ( level.acc_panzer_debt <= 0 )
			continue;
		boss = spawn_boss();
		if ( isdefined( boss ) && isalive( boss ) )
			level.acc_panzer_debt--;         // spend ONLY on success; a failed spawn retries next tick
	}
}

// DEV: from ACC_PANZER_TEST_ROUND on, keep exactly one Panzer alive - respawns ~12s after a
// kill so every dev run can re-fight him ("test like a real game", the Avogadro pattern).
function dev_test_spawn()
{
	level endon( "end_game" );
	for ( ;; )
	{
		if ( IS_TRUE( level.acc_paradise_onslaught ) ) { wait 12; continue; }
		rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
		if ( rn >= ACC_PANZER_TEST_ROUND && level.acc_panzer_alive <= 0 )
			spawn_boss();
		wait 12;
	}
}

// ---------------------------------------------------------------------------
// Spawn
// ---------------------------------------------------------------------------

function host_player()
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
		if ( isdefined( players[ i ] ) )
			return players[ i ];
	return undefined;
}

// Multi-boss spawn de-stacking (user 2026-07-08: "more than one can spawn on rounds with
// multiple bosses - handle it cleanly"): the debt directors already trickle spawns one per
// ~3s tick (never same-frame), and every boss carries the is_boss/acc_is_* flags so no
// entrance AoE can hurt a sibling - the remaining problem is two bosses SHARING A SPOT.
// Fix: query the navmesh in a ring around the anchor (the pack's own spawn_mechz recipe,
// PositionQuery_Source_Navigation) and pick a random point that keeps ACC_PANZER_CLEARANCE
// units from every LIVING boss - so a second Panzer (or an RP that wandered over) is dodged,
// not telefragged. Falls back gracefully: any clear point > any queried point > the anchor.
function pick_spawn_point( anchor )
{
	queryResult = PositionQuery_Source_Navigation( anchor, 0, 220, 40, 32 );
	if ( !isdefined( queryResult ) || queryResult.data.size == 0 )
		return anchor;

	// Living bosses to keep clear of (any type - all carry the shared flags).
	bosses = [];
	a_ai = GetAISpeciesArray( "all" );
	for ( i = 0; i < a_ai.size; i++ )
	{
		ai = a_ai[ i ];
		if ( !isdefined( ai ) || !isalive( ai ) )
			continue;
		if ( IS_TRUE( ai.is_boss ) || IS_TRUE( ai.acc_is_boss ) || IS_TRUE( ai.acc_is_mini_boss ) )
			bosses[ bosses.size ] = ai;
	}

	clear = [];
	for ( i = 0; i < queryResult.data.size; i++ )
	{
		p = queryResult.data[ i ].origin;
		ok = true;
		for ( j = 0; j < bosses.size; j++ )
		{
			if ( DistanceSquared( p, bosses[ j ].origin ) < ACC_PANZER_CLEARANCE * ACC_PANZER_CLEARANCE )
			{
				ok = false;
				break;
			}
		}
		if ( ok )
			clear[ clear.size ] = p;
	}

	if ( clear.size > 0 )
		return clear[ RandomInt( clear.size ) ];
	// Every queried point is crowded (bosses parked on the riser) - any navmesh point still
	// beats the raw anchor; the AI push-apart handles the rest.
	return queryResult.data[ RandomInt( queryResult.data.size ) ].origin;
}

function spawn_boss()
{
	if ( !isdefined( host_player() ) )
	{
		dbg( "no valid player - retrying" );
		return undefined;
	}

	// SPAWN ORIGIN (user 2026-07-08: "he needs to spawn in Plaza, since it's outside - and NOT
	// on the Rogue Protector's spot"): the Panzer gets his OWN Plaza anchor, the central Plaza
	// riser @ (-227.5, 350, 0) - the exact spot the 2026-06-19 integration spawned him at
	// (proven on-navmesh + open sky), ~600u from the RP's chest-spot anchor (100,-150,14) so
	// the two bosses never share a doorstep. pick_spawn_point() then navmesh-scatters around
	// the anchor AND dodges every living boss, so multi-boss rounds (two Panzers, or Panzer +
	// RP wandering over) never stack spawns. Live-tunable via acc_panzer_spawn_* (no rebuild).
	anchor = ( getdvarfloat( "acc_panzer_spawn_x", -227.5 ), getdvarfloat( "acc_panzer_spawn_y", 350 ), getdvarfloat( "acc_panzer_spawn_z", 0 ) );
	ang    = ( 0, getdvarfloat( "acc_panzer_spawn_yaw", 0 ), 0 );
	org    = pick_spawn_point( anchor );
	where  = "Plaza riser";
	// PARADISE: the arena is a separate dimension at z=-1200 and the Plaza anchor is
	// unreachable from it - spawn ON a living player instead (the every-boss rule).
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
	{
		pp = host_player();
		if ( isdefined( pp ) ) { org = pp.origin; ang = ( 0, pp.angles[ 1 ], 0 ); where = "Paradise arena"; }
	}

	// Refresh the pack's per-round health fields BEFORE setup reads them (recipe item #2:
	// defined-but-never-called in the pack -> HP undefined without this; round-gated inside).
	mechz_spiki::mechz_health_increases();

	// HP: the SHARED boss scale with the Panzer's own TANK-tier exponent x the log coop mult.
	// level.mechz_health must carry the SAME number: acc_setup_mechz copies it onto the actor,
	// and the live mechz-damage formulas (vendored elemental bows, Thundergun function_b8e0ce15)
	// all read level.mechz_health - an out-of-sync value skews every special-weapon hit.
	rn = ( isdefined( level.round_number ) ? level.round_number : 1 );
	hp = int( acc_boss_phantom::scale_phantom_hp( rn, getdvarfloat( "acc_panzer_hp_exp", ACC_PANZER_HP_EXP ) ) * acc_coop_scaling::boss_hp_player_mult() );
	if ( hp < 1 )
		hp = 1;
	level.mechz_health = hp;

	// SPAWN: direct aitype spawn, the Rogue Protector/Avogadro recipe. archetype_zm_mechz_genesis
	// is the aitype the old .map spawner classname (actor_archetype_zm_mechz_genesis, proven
	// in-game 2026-06-19) resolved to; zone-listed explicitly (no BSP entity pulls it in).
	// 4th arg = targetname: MUST be defined (tomb_spawn_function compares it - `!=` on undefined
	// THROWS) and MUST NOT be "mechz_tomb" (that enables the broken claw feature).
	boss = SpawnActor( "archetype_zm_mechz_genesis", org, ang, "acc_panzer", true );
	if ( !isdefined( boss ) )
	{
		// Retry at a player origin - navmesh-guaranteed (actor pool can also be full; the
		// director retries the whole spawn next tick anyway).
		p = host_player();
		if ( isdefined( p ) && DistanceSquared( p.origin, org ) > 1 )
		{
			dbg( "SpawnActor undefined at " + org + " (" + where + ") - retrying at player origin" );
			org = p.origin; ang = ( 0, p.angles[ 1 ], 0 ); where = where + "->player-retry";
			boss = SpawnActor( "archetype_zm_mechz_genesis", org, ang, "acc_panzer", true );
		}
	}
	if ( !isdefined( boss ) )
	{
		dbg( "FAIL: SpawnActor(archetype_zm_mechz_genesis) returned undefined at " + org );
		return undefined;
	}

	// Let the "mechz" archetype spawn functions (stock blackboard init + mechzSpawnSetup +
	// the pack's function_3d5df242) finish before our overrides land on top.
	wait 0.1;
	if ( !isdefined( boss ) || !isalive( boss ) )
	{
		dbg( "FAIL: actor died during archetype setup" );
		return undefined;
	}

	// SPAWN-FUNC SELF-HEAL (user 2026-07-08 playtest: "he doesn't move" - attacked in place but
	// never walked). Root cause: the "mechz" archetype spawn functions are dispatched by
	// spawner::spawn_think for SPAWNER-spawned AI - a direct SpawnActor can miss the dispatch
	// entirely, and stock ArchetypeMechzBlackboardInit (registered there) IS the locomotion
	// blackboard: without it the BT still attacks (distance conditions pass) but every movement
	// state is starved. Same class of bug as the Avogadro's manual blackboard-init call (memory
	// gsc-t7-runtime-traps: "SpawnActor'd custom aitype needs blackboard init to locomote").
	// flameTrigger (stock mechzSpawnSetup) + is_mechz (pack init) double as ran-markers; when
	// missing, spawner::run_spawn_functions() (PUBLIC - and registered function POINTERS run
	// fine even though their targets are private) fires the exact list spawn_think would have:
	// blackboard init -> mechzSpawnSetup -> tomb_spawn_function -> our function_3d5df242.
	ran = ( isdefined( boss.flameTrigger ) && IS_TRUE( boss.is_mechz ) );
	dbg( "post-spawn: spawnfuncs_ran=" + ( ran ? "1" : "0" )
	     + " flameTrigger=" + ( isdefined( boss.flameTrigger ) ? "1" : "0" )
	     + " is_mechz=" + ( IS_TRUE( boss.is_mechz ) ? "1" : "0" ) );
	if ( !ran )
	{
		dbg( "archetype spawn funcs did NOT run - self-healing via spawner::run_spawn_functions" );
		boss thread spawner::run_spawn_functions();
		wait 0.25;   // it contains a waittillframeend - give it real frames
		if ( !isdefined( boss ) || !isalive( boss ) )
		{
			dbg( "FAIL: actor died during spawn-func self-heal" );
			return undefined;
		}
		dbg( "self-heal result: flameTrigger=" + ( isdefined( boss.flameTrigger ) ? "1" : "0" )
		     + " is_mechz=" + ( IS_TRUE( boss.is_mechz ) ? "1" : "0" ) );
	}

	// The pack's per-ai block from spawn_mechz (damage callbacks, part healths, ambient vox) -
	// see the [acc] header on acc_setup_mechz for what it applies and what it deliberately skips.
	boss mechz_spiki::acc_setup_mechz();

	// --- boss identity (the shared flags - octobomb filter, sibling landing-splash exclusion,
	// _acc_zombie_speed ASM skip, corpse-cleanup skip, nuke/round-count exemption all key off
	// these; set IMMEDIATELY so there is no unflagged window) ---
	boss.is_boss               = true;
	boss.acc_is_boss           = true;
	boss.acc_is_mini_boss      = true;
	boss.acc_boss_custom_speed = true;   // _acc_zombie_speed skips him (no ASM stomp); his rate is OURS below
	boss.ignore_enemy_count    = true;   // fights ALONGSIDE the wave, never gates round end
	boss.ignore_nuke           = true;   // (mechzSpawnSetup also sets this - explicit for the audit greps)
	boss.disableAmmoDrop       = true;

	// SPEED: bare ASMSetAnimationRate - anim playback scales the root motion, so rate = ground-
	// speed multiplier on his run gait. User ladder 2026-07-08: 2.0 "incredibly fast, like
	// buggy" -> 1.15 (the Avogadro value) -> 1.1 -> 1.09 -> 1.10 (+0.01 buff, user 2026-07-09).
	// NEVER set_zombie_run_cycle_override_value on a custom ASM (froze Brutus). Side effect by
	// design: his attack anims ride the same rate. Live-tunable, applies on next spawn.
	boss ASMSetAnimationRate( getdvarfloat( "acc_panzer_anim_rate", 1.10 ) );

	boss.maxhealth = hp;
	boss.health    = hp;

	dbg( "spawned @ " + org + " (" + where + ") - round " + rn + ", " + hp + " hp" );
	// PANZER dev "ACTIVE + hp" banner REMOVED 2026-07-10 (clean screen in hardcoded dev); the 3D nameplate + boss music below are the tell.
	// if ( IS_TRUE( level.acc_dev ) )
	//	announce( "^1PANZER ACTIVE^7 (" + where + ") - " + hp + " hp" );

	// --- presentation: 3D nameplate (index 2, the repurposed SUBROUTINE CORE slot) + music ---
	level notify( "acc_boss_spawned", boss, ACC_PANZER_DISPLAY_NAME );
	level thread acc_boss::boss_music( boss );

	level thread boss_life( boss );
	boss thread dev_status();     // [PANZER] HB console logs (dev / acc_panzer_debug) - the movement diagnostic
	boss thread goal_driver();    // no-path self-correction (see the function header)
	boss thread retarget_loop();  // closest-player targeting (see the function header)

	return boss;
}

// GOAL DRIVER (playtest round 2, 2026-07-08: HB showed favoriteenemy SET + path "move allowed" +
// gait run + spawn funcs ran... and moved=0 forever). The BT's movebehavior is gated on
// locomotionBehaviorCondition = HasPath(): stock mechzTargetService goals him at
// GetClosestPointOnNavMesh( player.origin, 64, 30 ) - and when that strict projection finds no
// point (needs 30u of clearance from every navmesh EDGE within 64u of the player; our greybox
// mesh is ribbon-cut by clips), it SILENTLY falls back to SetGoal( his own origin ) = at-goal =
// no path = the BT idles forever while staring at you. This driver watches HasPath() and, when
// it's been false with a live target, re-goals him with PROGRESSIVELY LOOSER projections
// (64/30 -> 128/15 -> 256/0 -> raw player origin) - the Avogadro machine-goal lesson
// ("navmesh-project every AI goal") taken one step further. It only ever intervenes while
// HasPath() is false, so a healthy stock goal is never fought.
function goal_driver()
{
	self endon( "death" );
	level endon( "end_game" );
	fail_streak = 0;
	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( self HasPath() )
		{
			if ( fail_streak > 2 )
				dbg( "goal_driver: path RESTORED after " + fail_streak + " no-path ticks" );
			fail_streak = 0;
			continue;
		}
		t = self.favoriteenemy;
		if ( !isdefined( t ) )
			continue;
		fail_streak++;
		if ( fail_streak < 2 )
			continue;   // give the stock service (500-1000ms cadence) one beat to recover on its own

		// Loosening ladder: stock-strict first, then wider search / thinner edge clearance,
		// then anywhere-on-mesh, then the raw origin as the last resort.
		goal = GetClosestPointOnNavMesh( t.origin, 64, 30 );
		how  = "64/30";
		if ( !isdefined( goal ) ) { goal = GetClosestPointOnNavMesh( t.origin, 128, 15 ); how = "128/15"; }
		if ( !isdefined( goal ) ) { goal = GetClosestPointOnNavMesh( t.origin, 256, 0 );  how = "256/0"; }
		if ( !isdefined( goal ) ) { goal = t.origin;                                      how = "raw"; }
		self SetGoal( goal );
		if ( fail_streak == 2 || ( fail_streak % 20 ) == 0 )   // log the entry + a 10s pulse, not 2Hz spam
			dbg( "goal_driver: NO PATH (streak " + fail_streak + ") - re-goaled via " + how + " @ " + goal );
	}
}

// CLOSEST-PLAYER RETARGET (user 2026-07-09: "he only chases one person the whole time"). The pack's
// mechzTargetService is SUPPOSED to re-pick get_closest_valid_player every service tick, but live
// coop shows him locked on one player for his whole life - so WE own targeting the same way the
// Rogue Protector's hunt_players does: every 0.5s pick the closest valid player and, when the pick
// CHANGES, re-goal immediately through the goal_driver's projection ladder (only on a change, so a
// healthy stock goal is never fought tick-to-tick). Respects the pack's two targeting suspensions:
// ignoreall (trap attack window) and the ignore_player array (post-claw-grab bookkeeping).
function retarget_loop()
{
	self endon( "death" );
	level endon( "end_game" );

	for ( ;; )
	{
		wait 0.5;
		if ( !isdefined( self ) || !isalive( self ) )
			return;
		if ( IS_TRUE( self.ignoreall ) )
			continue;   // pack trap-attack / scripted-ignore window - don't fight it

		best = undefined;
		best_d = 999999999;
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !zm_utility::is_player_valid( p ) )
				continue;
			skip = false;
			if ( isdefined( self.ignore_player ) )   // the pack's post-grab ignore list
			{
				for ( j = 0; j < self.ignore_player.size; j++ )
				{
					if ( isdefined( self.ignore_player[ j ] ) && self.ignore_player[ j ] == p )
					{
						skip = true;
						break;
					}
				}
			}
			if ( skip )
				continue;
			d = DistanceSquared( self.origin, p.origin );
			if ( d < best_d )
			{
				best_d = d;
				best = p;
			}
		}
		if ( !isdefined( best ) )
			continue;
		if ( isdefined( self.favoriteenemy ) && self.favoriteenemy == best )
			continue;   // already on the closest player - nothing to do

		self.favoriteenemy = best;
		// Re-goal NOW so the switch is visible immediately (the same loosening ladder as goal_driver).
		goal = GetClosestPointOnNavMesh( best.origin, 64, 30 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( best.origin, 128, 15 );
		if ( !isdefined( goal ) ) goal = GetClosestPointOnNavMesh( best.origin, 256, 0 );
		if ( !isdefined( goal ) ) goal = best.origin;
		self SetGoal( goal );
		dbg( "retarget: -> " + ( isdefined( best.name ) ? best.name : "player" ) + " (" + int( Distance( self.origin, best.origin ) ) + "u)" );
	}
}

// DEV HEARTBEAT (user 2026-07-08: "add console logs so you can see what the issue is") - the
// Avogadro HB recipe. Every 2.5s a [PANZER] line describes his whole state; lands on-screen +
// in console_mp.log as [SCRIPTER] via dbg(). How to READ it:
//   moved  = units covered since the last HB. 0 with a live enemy = locomotion broken -> STUCK?
//   path   = engine PathMode ("move allowed" is healthy; "dont move" = something froze him)
//   favEnemy/enemy = the two targeting fields (stock mechzTargetService drives favoriteenemy;
//            both "none" = TARGETING is the problem, not locomotion)
//   ft/mechz = the spawn-func ran-markers (flameTrigger / is_mechz; 0 0 after the self-heal =
//            run_spawn_functions ALSO failed - escalate to replicating the blackboard init)
function dev_status()
{
	self endon( "death" );
	level endon( "end_game" );
	if ( getdvarint( "acc_panzer_debug", 0 ) != 1 )   // acc_dev DECOUPLED 2026-07-10 (clean screen; [PANZER] rides acc_panzer_debug now)
		return;
	last = self.origin;
	for ( ;; )
	{
		wait 2.5;
		if ( !isdefined( self ) )
			return;
		moved = int( Distance( self.origin, last ) );
		last  = self.origin;
		pm    = self GetPathMode();
		fe    = "none";
		if ( isdefined( self.favoriteenemy ) )
			fe = "" + int( Distance( self.origin, self.favoriteenemy.origin ) ) + "u";
		en    = "none";
		if ( isdefined( self.enemy ) )
			en = "" + int( Distance( self.origin, self.enemy.origin ) ) + "u";
		has_target = ( isdefined( self.favoriteenemy ) || isdefined( self.enemy ) );
		stuck = ( ( moved < 10 && has_target ) ? " ^1STUCK?^7" : "" );
		// Path probes (playtest round 2): haspath = the EXACT BT movement gate
		// (locomotionBehaviorCondition); proj = would the stock-strict goal projection around the
		// target succeed right now (64/30 - the silent parking failure); atgoal = parked-at-self.
		hp_ok = ( ( self HasPath() ) ? "1" : "0" );
		ag    = ( ( self IsAtGoal() ) ? "1" : "0" );
		proj  = "n/a";
		if ( isdefined( self.favoriteenemy ) )
			proj = ( isdefined( GetClosestPointOnNavMesh( self.favoriteenemy.origin, 64, 30 ) ) ? "1" : "0" );
		dbg( "HB pos=" + self.origin + " moved=" + moved + " path=" + pm
		     + " haspath=" + hp_ok + " atgoal=" + ag + " proj=" + proj
		     + " favEnemy=" + fe + " enemy=" + en
		     + " ft=" + ( isdefined( self.flameTrigger ) ? "1" : "0" )
		     + " mechz=" + ( IS_TRUE( self.is_mechz ) ? "1" : "0" )
		     + " gait=" + ( isdefined( self.zombie_move_speed ) ? self.zombie_move_speed : "?" )
		     + " hp=" + self.health + stuck );
	}
}

// ---------------------------------------------------------------------------
// Lifecycle + death rewards
// ---------------------------------------------------------------------------

// Poll-isalive (not waittill "death"): robust whether the pack's death anim Delete()s the
// actor or the corpse lingers, and it keeps a per-boss last origin so multi-Panzer rounds
// never drop at a sibling's death spot (the Avogadro M3 lesson).
function boss_life( boss )
{
	level endon( "end_game" );
	level.acc_panzer_alive++;

	org = boss.origin;
	while ( isdefined( boss ) && isalive( boss ) )
	{
		org = boss.origin;
		wait 0.25;
	}

	level.acc_panzer_alive--;
	if ( level.acc_panzer_alive < 0 )
		level.acc_panzer_alive = 0;

	dbg( "down @ " + org );
	grant_drops( org );
}

function grant_drops( org )
{
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
		return;
	if ( !isdefined( org ) )
		return;
	// Shared boss reward (user 2026-07-05: every boss identical) - 1 item + 1 Mega Bottle +
	// round-scaled pts + int(round/3) shards, per player. spawn_pickup floor-snaps the drop.
	acc_boss::grant_unified_boss_reward( org );
}

function announce( text )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
		if ( isdefined( players[ i ] ) )
			players[ i ] iprintln( text );
}
