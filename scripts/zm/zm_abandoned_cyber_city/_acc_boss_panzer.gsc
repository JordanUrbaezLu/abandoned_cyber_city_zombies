// =============================================================================
// _acc_boss_panzer.gsc - the PANZER boss (Spiki asset-dump mechz port, 4th roster type; renamed from PANZER SOLDAT, user 2026-07-08).
//
// Identity (user 2026-07-08): the literal Der Eisendrache PANZER chassis as our heaviest
// walker - the TANK of the roster. Tier ladder on the shared 65k/anchor-5 scale_phantom_hp
// scale: PANZER 1.09 (= the Rogue Protector tier, user 2026-07-08 final; earlier
// walked 1.12->1.13->1.14->1.12->1.09) - ladder Brutus 1.12 > Rogue/Panzer 1.09 > Phantom/Avogadro 1.06. Melee hits VERY hard
// (acc_panzer_melee_damage, default 99 - user 2026-07-18 +10% all-Panzer damage, was 90; flame
// acc_panzer_flame_mult 1.21, electroball explosion acc_panzer_explosive_mult 1.1 in _acc_elites) + the stock
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
// round 45) - a debt director like the other three. Dev runs the SAME real roster cadence
// (the repeating dev test-spawn loop was disabled 2026-07-12). Toggle live:
// acc_panzer_enable 0. Trace via a dev build (debug prints ride level.acc_dev; the
// acc_panzer_debug dvar was removed 2026-07-16).
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
#define ACC_PANZER_HP_EXP         1.09    // user 2026-07-26: -0.01 all-boss health nerf, 1.1->1.09 (ladder Brutus 1.11 > Panzer 1.09 > Rogue 1.08 > Phantom/Avo 1.06 > Scientist 1.04). user 2026-07-25: 1.09 -> 1.1, splitting OFF the Rogue tier into his own rung (exp history: 1.12/1.13/1.14 tank-tier ladder -> "match the RP" 1.09 [2026-07-08] -> 1.1). Ladder now Brutus 1.12 > Panzer 1.1 > Rogue 1.09 > Phantom/Avogadro 1.07 > Scientist 1.05 on the SHARED 65k/anchor-5 scale. Panzer solo r5 65k / r10 105k / r20 272k / r30 704k / r40 1.83M. Live dvar acc_panzer_hp_exp.
#define ACC_PANZER_TEST_ROUND     2      // DEV: first test spawn at round 2 (user 2026-07-08, was 3), keep exactly one alive (Avogadro pattern)
#define ACC_PANZER_CLEARANCE      150    // units of spawn clearance from every living boss (pick_spawn_point)

#namespace acc_boss_panzer;

function dbg( msg )
{
	// Same contract as the Avogadro's dbg: key [PANZER] events log whenever level.acc_dev is on
	// (lands in console_mp.log as [SCRIPTER] via acc_utility::log + on-screen). Normal play =
	// silent (the acc_panzer_debug dvar was removed 2026-07-16 - debug rides acc_dev only).
	if ( !IS_TRUE( level.acc_dev ) )   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
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

	// DEV early test-spawn DISABLED (user 2026-07-12: "stop the panzer from spawning on round 2
	// in dev mode - it's annoying"): dev now runs the REAL roster cadence exactly like normal play
	// (Panzer takes his shared-roster slots from round 9 - _acc_civil_protector no longer re-homes
	// them in dev). dev_test_spawn() is KEPT below unreferenced - re-thread it here when Panzer
	// himself is the thing under iteration.
	level thread round_watch();
	level thread director();
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
//   2. ZAP: on explosion, every valid player inside acc_panzer_zap_radius (default 220 = +10%
//      over the 200-unit GDT explosionRadius; the explosion DAMAGE itself stays GDT-side at 200)
//      gets the SHARED boss zap slow via acc_elites::acc_protector_zap -
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
	r = getdvarfloat( "acc_panzer_zap_radius", 220 );   // [acc] ELECTROBALL +10% blast area (user 2026-07-12: 200 -> 220; explosion damage itself is the engine 115-grenade / GDT-side)
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
	// KILL-SWITCH GATE (added 2026-07-15 audit). init() returns at :80 when acc_panzer_enable is 0,
	// BEFORE it seeds this module's level state - but _acc_paradise::maybe_spawn_panzer only checks
	// acc_paradise_panzer_on, never acc_panzer_enable, so it called straight in here and consumed
	// state that was never seeded. The roster already re-homes "panzer" slots correctly
	// (_acc_civil_protector:239); Paradise was the one path that ignored the toggle.
	// Callers all handle undefined (paradise logs "Panzer spawn returned none"), and the module's own
	// cadence loops never reach here when disabled, so this gate is a no-op in normal play.
	if ( getdvarint( "acc_panzer_enable", ACC_PANZER_ENABLE_DEF ) != 1 )
	{
		dbg( "spawn_boss called while acc_panzer_enable 0 - refusing (kill-switch honoured)" );
		return undefined;
	}

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

	// HP: the SHARED boss scale with the Panzer's own TANK-tier exponent x the coop boss-HP table
	// (boss_hp_player_mult: 1p 1.00 / 2p 1.70 / 3p 2.30 / 4p 2.60 - user 2026-07-15, was a log curve).
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

	// BODY-DAMAGE REBUFF (user 2026-07-11): acc_setup_mechz just pointed actor_damage_func at the
	// STOCK MechzServerUtils::mechzDamageCallback, which scales EVERY body/limb hit to 10% while the
	// head + exposed core stay 100% - the "no headshot weakness, pure sponge" feel. Re-point it at
	// our wrapper, which delegates to stock (all side effects intact) and rebuffs ONLY the body
	// family to acc_panzer_body_scale (default 0.35). Capture the stock pointer ONCE from the field
	// acc_setup_mechz set, so we never need a MechzServerUtils #using here. See acc_mechz_damage_wrap.
	if ( !isdefined( level.acc_mechz_stock_damage_func ) )
		level.acc_mechz_stock_damage_func = boss.actor_damage_func;   // = &MechzServerUtils::mechzDamageCallback
	boss.actor_damage_func = &acc_mechz_damage_wrap;

	// --- boss identity (the shared flags - octobomb filter, sibling landing-splash exclusion,
	// _acc_zombie_speed ASM skip, corpse-cleanup skip, nuke/round-count exemption all key off
	// these; set IMMEDIATELY so there is no unflagged window) ---
	boss.is_boss               = true;
	boss.acc_is_boss           = true;
	boss.acc_is_mini_boss      = true;
	boss.acc_is_panzer         = true;   // boss-weakness identity (explosive + energy +20%, _acc_damage 0c5)
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
	boss thread dev_status();     // [PANZER] HB console logs (rides level.acc_dev) - the movement diagnostic
	boss thread goal_driver();    // no-path self-correction (see the function header)
	boss thread retarget_loop();  // closest-player targeting (see the function header)

	return boss;
}

// ---------------------------------------------------------------------------
// Hit-location damage wrapper - body rebuff + headshot bonus (user 2026-07-11)
// ---------------------------------------------------------------------------
//
// TWO tunings live here (bullets + MOD_PROJECTILE direct hits; splash-only mods keep stock handling;
// MELEE passes through untouched - acc_damage::on_ai_damage's fractional value is FINAL, see inline):
//   1. BODY REBUFF - stock scales torso/limb hits to 10%; we rebuff to acc_panzer_body_scale (0.35).
//      (Bullets only - projectile body hits keep stock's flat 0.5x.)
//   2. HEADSHOT - stock gates the head weak spot behind the (on our map, fat) faceplate; we make the
//      head a weak spot for every AIMED shot (bullet or projectile direct) and pay
//      acc_panzer_head_scale (0.9x; radius 36 around j_faceplate + head/helmet/neck hitlocs). See inline.
//
// WHY: stock MechzServerUtils::mechzDamageCallback scales EVERY body/limb hit to 10%
// (MECHZ_BODY_DAMAGE_SCALE 0.1) while a head hit + the exposed power core stay at 100% and
// explosives at 50%. In-game that reads as "he has no headshot weakness, he's just a sponge"
// (docs/08) - because center-mass (the biggest, most natural target) does 1/10th damage and the
// head does base (not a BONUS) damage, so there's no headshot "pop" to reward. The 0.1 lives in a
// stock #define inside a STOCK function we don't own (can't edit it), so instead we WRAP the
// callback: run stock first (preserving ALL its side effects - part destruction, faceplate/powercap
// tracking, hit markers, pain audio, scoring, the explosive-reaction path) and then rebuff ONLY the
// 0.1 body family up to acc_panzer_body_scale (default 0.35). Head / exposed-core / explosive
// returns are left byte-for-byte stock, so the head is still ~3x better than the body - the weak
// spot survives, the body just stops being useless.
//
// HOW WE ISOLATE THE BODY FAMILY WITHOUT REPLICATING THE STOCK SWITCH: stock's only hit-location
// scales are { 0, 0.1, 0.5, 1.0 }, each times the weapon-class modifier { 0.5, 0.65, 0.75, 1.0 }.
// Dividing the stock RESULT by that same weapon-modified base recovers the PURE hit scale exactly
// (level.mechz_damage_override is NOT registered on this map, so nothing else skews the base). The
// 0.1 family maxes at 0.1; the next family (0.5) floors at 0.25 - so a 0.2 threshold cleanly
// separates "body" from "weak spot / explosive". No new dev flag - acc_panzer_body_scale is a
// live-balance tuning dvar (default baked below); set it 0.1 to restore exact stock behavior.
function acc_mechz_damage_wrap( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex )
{
	// self = the mechz. Delegate to stock FIRST - it does every side effect (part destruction,
	// faceplate/powercap tracking, hit markers, scoring, explosive reaction) and returns the scaled hit.
	result = self [[ level.acc_mechz_stock_damage_func ]]( inflictor, attacker, damage, dFlags, mod, weapon, point, dir, hitLoc, offsetTime, boneIndex );
	if ( !isdefined( result ) || result <= 0 )
		return result;   // flyin-gate / elemental-bow / no-damage returns - untouched

	// SPLASH mods keep their stock path (flat 0.5 explosive family) - but a MOD_PROJECTILE DIRECT hit is
	// head-eligible below (user 2026-07-12: "a lot of guns cant even hit him in the head" - the projectile-
	// class guns, Thundergun/Blast-O-Matic/energy launchers, are MOD_PROJECTILE, and STOCK gives them NO
	// head path at all while the faceplate exists + only a 12u tag_eye window after; the old early-return
	// here locked that in. Splash-only mods still can't headshot - correct, you don't aim splash).
	projectile_direct = ( isdefined( mod ) && mod == "MOD_PROJECTILE" );
	if ( acc_mechz_is_splash_mod( mod ) && !projectile_direct )
		return result;

	// MELEE PASS-THROUGH (audit fix 2026-07-15): this wrapper is BULLET-scoped by design (see the header;
	// the originating change shipped "bullet-only"), but MOD_MELEE is neither a bullet NOR a splash mod, so
	// it fell through the guard above into the body path - and stock _zm.gsc runs actor_damage_func (:5748)
	// AFTER check_actor_damage_callbacks (:5633), so we were silently RE-SCALING a value acc_damage::
	// on_ai_damage had already declared FINAL. The Leviathan Axe and Action Figure deal a FRACTION of MAX
	// health (maxhealth/N = "N hits to kill ANY boss regardless of HP" - docs/04, docs/08): stock's switch
	// DEFAULTs a melee hitLoc into the 0.1x body family and our rebuff paid it back to only 0.35x, so a
	// tier-3 axe took ~23 swings instead of its designed 8 and the figure ~94 instead of 33 - while
	// feed_dmg_number had already shown the player the DESIGNED number. Return the INCOMING damage so
	// on_ai_damage's value stands verbatim (stock ran above, so its side effects - part destruction,
	// faceplate chip, hit marker, pain audio, scoring - are all intact; we only refuse its SCALE). This
	// also deliberately skips the head block below: melee NEVER headshots on this map (_acc_damage.gsc,
	// user 2026-06-23). Knife/bowie ride the normal scaled chain and stay backstopped by the map-wide 10%
	// ACC_BOSS_PER_HIT_CAP_PCT per-hit boss cap, so undoing the 0.1x here can't cheese him.
	// acc_panzer_melee_scale = live rollback lever (1.0 = honour on_ai_damage; 0.1 ~= old stock feel).
	// NOTE: distinct from acc_panzer_melee_damage, which is damage the Panzer DEALS to players.
	if ( isdefined( mod ) && IsSubStr( mod, "MELEE" ) )
		return damage * getdvarfloat( "acc_panzer_melee_scale", 1.0 );

	ref = acc_mechz_weapon_mod( damage, weapon );   // stock's post-weapon-modifier base, pre hit-scale
	if ( ref <= 0 )
		return result;

	// HEADSHOT (user 2026-07-11; RE-TUNED 2026-07-12: "weak headshot damage + a lot of guns can't hit the
	// head"): stock gates the head weak spot BEHIND the faceplate, and OUR faceplate is a fat pool
	// (level.var_fa14536d 1500+, vs stock's 50), so with the helmet ON the engine never even reports
	// hitLoc "head" - face hits come in as torso_upper (stock tracks plate chip there) or helmet/neck
	// (stock switch DEFAULTs those to the 0.1x body family!). We make the head a weak spot for every
	// aimed shot, faceplate or not:
	//   - hitLoc head/helmet/neck counts directly (helmet/neck ARE the head the player aimed at);
	//   - else proximity to the j_faceplate tag (the exact tag stock uses). RADIUS 36 (was 21): the tag
	//     is the INTERIOR head joint but impact points land on the helmet SURFACE, 10-25u out - 21 only
	//     caught dead-center face shots (jaw/side/top-of-helmet hits fell through to 0.1x = the "can't
	//     hit his head" report). 36 covers the whole helmet, still well clear of chest/shoulder tags.
	//     Height-guarded so a missing tag falling back to the feet origin can't false-positive a leg shot.
	// Pays acc_panzer_head_scale (default 0.9x - user 2026-07-12 "make the headshot damage 0.9",
	// dialed down from the 2.0 set earlier the same session; still ~2.6x a body shot, so the head
	// stays the best target). Stock still chips the faceplate as a side effect, so the helmet
	// visually breaks - it's just no longer a hard gate on landing headshots.
	is_head = ( isdefined( hitLoc ) && ( hitLoc == "head" || hitLoc == "helmet" || hitLoc == "neck" ) );
	if ( !is_head )
	{
		face = self GetTagOrigin( "j_faceplate" );
		hr   = getdvarfloat( "acc_panzer_head_radius", 36 );
		if ( isdefined( face ) && ( face[ 2 ] - self.origin[ 2 ] ) > 20 && DistanceSquared( face, point ) <= hr * hr )
			is_head = true;
	}
	if ( is_head )
		return ref * getdvarfloat( "acc_panzer_head_scale", 0.9 );

	// Projectile DIRECT body hit: leave stock's 0.5x untouched (only the head window above is new for them).
	if ( projectile_direct )
		return result;

	// BODY: rebuff the stock 0.1 family up to acc_panzer_body_scale; leave the exposed-core weak spot
	// (0.5/1.0) stock. The 0.1 family maxes at 0.1, the next family (0.5) floors at 0.25 -> a 0.2 cut is clean.
	scale = result / ref;
	if ( scale >= 0.2 )
		return result;         // exposed core - leave stock behavior intact
	body_scale = getdvarfloat( "acc_panzer_body_scale", 0.35 );
	return result * ( body_scale / 0.1 );   // 0.1 = stock MECHZ_BODY_DAMAGE_SCALE (0.35 -> x3.5)
}

// Splash/explosive/projectile MODs get their own dedicated stock handling in mechzDamageCallback -
// our bullet head/body tuning must NOT touch them (guarded: string == undefined THROWS in T7).
function acc_mechz_is_splash_mod( mod )
{
	if ( !isdefined( mod ) )
		return false;
	return ( mod == "MOD_GRENADE" || mod == "MOD_GRENADE_SPLASH" || mod == "MOD_PROJECTILE" || mod == "MOD_PROJECTILE_SPLASH" || mod == "MOD_EXPLOSIVE" );
}

// Mirror of stock mechzWeaponDamageModifier (mechz.gsc) - kept in lockstep so the scale inference
// above divides by the EXACT base stock used. Stock constants; update here only if Treyarch's ever change.
function acc_mechz_weapon_mod( damage, weapon )
{
	if ( isdefined( weapon ) && isdefined( weapon.name ) )
	{
		if ( IsSubStr( weapon.name, "shotgun_fullauto" ) )  return damage * 0.5;
		if ( IsSubStr( weapon.name, "lmg_cqb" ) )           return damage * 0.65;
		if ( IsSubStr( weapon.name, "lmg_heavy" ) )         return damage * 0.65;
		if ( IsSubStr( weapon.name, "shotgun_precision" ) ) return damage * 0.65;
		if ( IsSubStr( weapon.name, "shotgun_semiauto" ) )  return damage * 0.75;
	}
	return damage;
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
	if ( !IS_TRUE( level.acc_dev ) )   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
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
	a_dmg = boss.acc_damage_contrib;   // leveling XP damage-share ledger (docs/45 4a) - polled with org, same reap race
	while ( isdefined( boss ) && isalive( boss ) )
	{
		org = boss.origin;
		a_dmg = boss.acc_damage_contrib;
		wait 0.25;
	}
	if ( isdefined( boss ) )
		a_dmg = boss.acc_damage_contrib;   // final refresh: the killing blow lands after the last poll

	level.acc_panzer_alive--;
	if ( level.acc_panzer_alive < 0 )
		level.acc_panzer_alive = 0;

	dbg( "down @ " + org );
	grant_drops( org, a_dmg );
}

function grant_drops( org, a_dmg )
{
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
		return;
	if ( !isdefined( org ) )
		return;
	// Shared boss reward (user 2026-07-05: every boss identical) - 1 item + 1 Mega Bottle +
	// round-scaled pts + int(round/3) shards, per player. spawn_pickup floor-snaps the drop.
	// a_dmg = the boss's damage ledger (leveling XP damage-share, docs/45 4a; undefined -> flat XP).
	acc_boss::grant_unified_boss_reward( org, undefined, a_dmg );
}

function announce( text )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
		if ( isdefined( players[ i ] ) )
			players[ i ] iprintln( text );
}
