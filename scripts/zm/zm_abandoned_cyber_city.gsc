// =============================================================================
// zm_abandoned_cyber_city.gsc - map entry script (server-side)
//
// Structure follows the stock Launcher zm template (rex/templates ZM Base)
// verbatim, because that file is proven to compile and run. Our additions are
// the three ACC hook calls marked with "[acc]" comments; everything else is
// stock template wiring. Do not "clean up" the template parts - drift from
// the known-good template is how first builds break.
//
// BO3 conventions used here (differ from WaW/BO1 - do not regress):
//   - entry scripts live in scripts/zm/, not maps/zm/
//   - zm_usermap::main() bootstraps the zombies framework (it calls
//     load::main() internally; there is no _zm::main() in BO3)
//   - function definitions require the `function` keyword
//   - stock module namespaces drop the file's leading underscore
//     (_zm_utility.gsc -> zm_utility::)
// =============================================================================

#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\compass;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_utility.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;
#using scripts\zm\_zm_score;

#using scripts\shared\ai\zombie_utility;

//Perks
#using scripts\zm\_zm_perks;
#insert scripts\zm\_zm_perks.gsh;

#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_pack_a_punch_util;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
// [acc] Stock-but-unfinished cherry module = the registered perk pipeline we
// HIJACK for PhD Flopper (see _acc_perk_phd_flopper.gsc). Matching #using is in the
// entry .csc - required, or its clientfield registration mismatches.
#using scripts\zm\_zm_perk_electric_cherry;
#using scripts\zm\_zm_perk_juggernaut;
#using scripts\zm\_zm_perk_quick_revive;
#using scripts\zm\_zm_perk_sleight_of_hand;
#using scripts\zm\_zm_perk_staminup;
#using scripts\zm\_zm_perk_widows_wine;

//Powerups
#using scripts\zm\_zm_powerup_double_points;
#using scripts\zm\_zm_powerup_carpenter;
#using scripts\zm\_zm_powerup_fire_sale;
#using scripts\zm\_zm_powerup_free_perk;
#using scripts\zm\_zm_powerup_full_ammo;
#using scripts\zm\_zm_powerup_insta_kill;
#using scripts\zm\_zm_powerup_nuke;
#using scripts\zm\_zm_power;
#using scripts\zm\_zm_perks;

//Traps
#using scripts\zm\_zm_trap_electric;

#using scripts\zm\zm_usermap;

// [acc] Custom systems. Modules live in scripts/zm/zm_abandoned_cyber_city/.
#using scripts\zm\zm_abandoned_cyber_city\_acc_main;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
// [acc] PhD Flopper (perk #9): hijacks the stock-but-unfinished _zm_perk_electric_cherry
// pipeline (registered machine + stock nuke model) and presents it as PhD Flopper -
// fall/explosive immunity + dive-to-explode nova. (The real machine model needs a
// game-rip import, which the stock nuke placeholder avoids.)
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_phd_flopper;
// [acc] Electric Cherry - the REAL 10th perk (user 2026-06-25). A from-scratch perk on the
// unused specialty_combat_efficiency (its OWN Lab alcove + real p6_zm_vending_electric_cherry
// model), so it coexists with PhD (which keeps specialty_electriccherry). REGISTER_SYSTEM
// autoexec registers it at load - this #using is what pulls it into the compile so that runs.
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_electric_cherry;
// [acc] Avogadro electric boss (BO2 port, Dick_Nixon pack). Custom AITYPE archetype_zm_avogadro
// (model+anims+behaviors+FX+sounds installed at the Mod Tools root, gitignored via the manifest).
// REGISTER_SYSTEM autoexec registers the AI; spawns are driven by _acc_boss_avogadro (native cadence
// disabled in the vendored copy). Matching #using in the entry .csc.
#using scripts\zm\zm_abandoned_cyber_city\_zm_ai_avogadro;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_avogadro;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;
// [acc] Lockdown/Glitch-Purge seal query: the buyable-door loop below (zone_door_trigger_wait) consults
// acc_lockdown_challenge::is_door_sealed so a door bordering an ACTIVE sealed purge room refuses to open
// (else a sealed-in player just buys an un-bought border door and escapes - user 2026-06-25).
#using scripts\zm\zm_abandoned_cyber_city\_acc_lockdown_challenge;

// Fix Power Lag
#precache("triggerstring", "ZOMBIE_NEED_POWER");
#precache("triggerstring", "ZOMBIE_ELECTRIC_SWITCH");
#precache("triggerstring", "ZOMBIE_ELECTRIC_SWITCH_OFF");

#precache("triggerstring", "ZOMBIE_PERK_PACKAPUNCH", "5000");
#precache("triggerstring", "ZOMBIE_PERK_PACKAPUNCH", "1000");
#precache("triggerstring", "ZOMBIE_PERK_PACKAPUNCH_AAT", "2500");
#precache("triggerstring", "ZOMBIE_PERK_PACKAPUNCH_AAT", "500");

#precache("triggerstring", "ZOMBIE_RANDOM_WEAPON_COST", "950");
#precache("triggerstring", "ZOMBIE_RANDOM_WEAPON_COST", "10");

#precache("triggerstring", "ZOMBIE_PERK_QUICKREVIVE", "500");
#precache("triggerstring", "ZOMBIE_PERK_QUICKREVIVE", "1500");
#precache("triggerstring", "ZOMBIE_PERK_FASTRELOAD", "3000");
#precache("triggerstring", "ZOMBIE_PERK_DOUBLETAP", "2000");
#precache("triggerstring", "ZOMBIE_PERK_JUGGERNAUT", "2500");
#precache("triggerstring", "ZOMBIE_PERK_MARATHON", "2000");
#precache("triggerstring", "ZOMBIE_PERK_DEADSHOT", "1500");
#precache("triggerstring", "ZOMBIE_PERK_WIDOWSWINE", "4000");
#precache("triggerstring", "ZOMBIE_PERK_ADDITIONALPRIMARYWEAPON", "4000");

#precache("triggerstring", "ZOMBIE_UNDEFINED");

//*****************************************************************************
// MAIN
//*****************************************************************************

function main()
{
	// [acc] DE-DUPE Pack-a-Punch (user 2026-06-25). A SECOND PaP machine was added deep in the abyss hub
	// (z=-1200) reusing the SAME "zm_pack_a_punch" zbarrier targetname as the surface PaP. Stock PaP
	// spawn_init (_zm_pack_a_punch.gsc:84) collects BOTH via GetEntArray("zm_pack_a_punch"), renames BOTH to
	// "vending_packapunch" (:131), and its later GetEnt("vending_packapunch") FATALS ("getent used with more
	// than one entity") -> the map won't LOAD. We strip the targetname off the DEEP duplicate(s) HERE, before
	// zm_usermap::main() runs PaP init, so stock sees exactly one. RUNS FIRST so it can never be too late; it
	// only touches the surplus PaP (the abyss PERK machines are left intact - they coexist fine, only PaP is
	// name-unique in stock). Self-heals every load, so it survives the .map being re-duplicated.
	acc_dedupe_pack_a_punch();

	// [acc] DE-DUPE The Exchange transfer-vault door (user 2026-06-27). The .map ships the enter_exchange door
	// DUPLICATED - TWO zombie_door trigger_use + TWO "acc_door_exchange" slabs (identical GUID, a gen_plaza_basement
	// copy-paste). zone_door_buy_loop does GetEnt(d.target="acc_door_exchange") which FATALS ("getent used with more
	// than one entity" - seen in console_mp.log SCRIPTERROR) and kills the door thread. Strip the surplus copies HERE,
	// before acc_fix_zone_doors runs, so exactly one of each survives. Self-heals every load (same idiom as PaP).
	acc_dedupe_exchange_door();

	// VERIFIED(acc): must be set BEFORE zm_usermap::main() - the hook is
	// consumed synchronously inside the bootstrap (zm_usermap.gsc:135 DEFAULT()
	// -> load::main() -> zm::init() -> zm_weapons::init() -> _zm_weapons.gsc:678
	// [[level._zombie_custom_add_weapons]]()). DEFAULT() only assigns when
	// undefined, so pre-setting wins.
	level._zombie_custom_add_weapons =&custom_add_weapons;

	// [acc] Disable stock dog/hellhound rounds entirely (user 2026-06-18). Stock
	// zm_usermap::main DEFAULTs level.dog_rounds_allowed to 1 then calls
	// zm_ai_dogs::enable_dog_rounds() -> threads dog_round_tracker (a dog round
	// every 4-7 rounds). Pre-setting 0 makes that gate fail so the tracker never
	// starts. No normal-round-pacing side effect (dogs use a separate special-round
	// counter); the 7 orphan dog_location structs stay (harmless once tracker off).
	level.dog_rounds_allowed = 0;

	zm_usermap::main();

	// [acc] Disable stock Alternate Ammo Types (AAT) on Pack-a-Punch. Our PaP is
	// a 5-tier damage ladder (_acc_pap_levels) - we don't want the stock 2500
	// "re-pack for a random alt-ammo (turned/fireworks/etc.)" reroll. With this
	// off, aat::acquire is a no-op; re-packs route through our acc_pap_tier
	// trigger instead. (level.aat_in_use is the stock gate - _zm_weapons.gsc.)
	level.aat_in_use = false;

	// [acc] Remove the Death Machine (minigun powerup) from the game (user 2026-06-22). The stock minigun
	// powerup registers during the bootstrap (zm_powerup_weapon_minigun __init__ -> add_zombie_powerup).
	// We override its per-powerup drop gate to never fire, so get_valid_powerup() always skips it
	// (_zm_powerups.gsc:379 reads level.zombie_powerups[name].func_should_drop_with_regular_powerups). A
	// poll covers the case it registers a beat after main(); it applies long before round 1's first drop.
	level thread acc_disable_minigun_powerup();

	// [acc] Optional dev/test sandbox - ALL OFF by default, so a launch with no
	// dvars is a clean consumer game (closed map, earn your own money, decon hazard
	// live). The launch scripts (PLAY_TEST_MAP.bat / tools/run_game.ps1) set these
	// for test sessions. Full reference: docs/34_flags_reference.md.
	//   +set acc_dev 1      -> unlimited money + Data Shards + Mega Bottles + dev banner
	//                          (and enables the _acc_dev module: perk cap 18, dev HUDs,
	//                          teleport / round-skip / open-doors console cmds). Power is NO
	//                          longer auto-on - flip the Bus Station switch (or `acc_auto_power 1`).
	//   +set acc_open_map 1 -> open every buyable door + both PaP blockers on spawn so
	//                          the whole map is walkable, AND disable the decontamination
	//                          zone-seal hazard (lethal to a player roaming a fully-open
	//                          map). Decon flag read by _acc_decontamination.
	// DEV MODE - ONE FLAG (user 2026-06-22). `acc_dev` is the ONLY dev switch: 1 = the full hardcoded
	// dev sandbox, 0 (the SHIP DEFAULT) = normal play. acc_resolve_dev_flags() resolves it ONCE here
	// (before any module reads it) into level.acc_dev and drives the legacy sub-dvars off that one flag,
	// so there are no per-feature dev flags to set or forget. To add a dev behavior, read level.acc_dev
	// and HARDCODE the value - do NOT add a new dvar (docs/49, CLAUDE.md "Dev/test mode - ONE flag").
	acc_resolve_dev_flags();
	if ( level.acc_dev )
	{
		level thread acc_hardcoded_dev();
		level.acc_disable_decon = true;
	}
	// [acc] BUYABLE DOORS IN BOTH MODES, NEVER AUTO-OPENED (user 2026-06-22). Doors must always be bought;
	// dev simply has unlimited money so buying is trivial there. acc_fix_zone_doors forces every
	// GENERATOR-written zombie_door trigger player-usable (TriggerIgnoreTeam - stock door_init has that
	// commented out, so our .map-written triggers otherwise show NO "Open Door" prompt and you're stuck in
	// the start zone). This REPLACES the old dev "open the whole map" auto-unlock (acc_hardcoded_open_map),
	// which is no longer called.
	level thread acc_fix_zone_doors();
	level thread acc_spawn_plaza_props();

	// [acc] GOD MODE (user 2026-06-22; reworked 2026-06-27) - independent of acc_dev. NO LONGER an
	// EnableInvulnerability loop (that blocked the entire player-damage callback, so the per-hit EFFECTS - EMP
	// debuff, trench melee scaling, the Phantom chain slow - never fired in god). It is now enforced inside
	// _acc_elites::on_player_damaged, which returns 0 damage when level.acc_god (the EFFECTS still run, the HP loss
	// is zeroed). The callback reads level.acc_god on every hit, so no per-player thread is needed here. "Only
	// damage should be impossible" - user 2026-06-27. Normal play (acc_god 0) is unaffected.

	// [acc] Register our callbacks + roll per-run map state. Runs after the
	// stock bootstrap but still inside main(), i.e. before the first game
	// tick, first player spawn, and first round calculation.
	acc_main::pre_init();

	// [acc] PhD Flopper: hijack the stock electric-cherry registration (cost/hint/give/take
	// + immunity override) - must run AFTER zm_usermap::main() populated level._custom_perks,
	// BEFORE the first game tick.
	acc_perk_phd_flopper::init();

	// [acc] Apply the map's custom per-perk costs (docs/13_perks.md - perk
	// customization is a headline feature). Runs before the first tick / first
	// machine read, same as the PhD Flopper cost override above.
	set_perk_costs();

	//Setup the levels Zombie Zone Volumes
	level.zones = [];
	level.zone_manager_init_func =&usermap_test_zone_init;
	init_zones[0] = "start_zone";
	level thread zm_zonemgr::manage_zones( init_zones );

	level.pathdist_type = PATHDIST_ORIGINAL;

	// Starting Weapon
	startingWeapon = "pistol_standard";
	weapon = getWeapon(startingweapon);
	level.start_weapon = (weapon);

	// Laststand Weapon
	laststandWeapon = "pistol_standard_upgraded";
	level.default_laststandpistol = GetWeapon(laststandWeapon);
	level.default_solo_laststandpistol = GetWeapon(laststandWeapon);

	//Start Points
	level.player_starting_points = 500;

	// [acc] BASE perk cap = 4 (user 2026-06-19): you START with 4 slots and BUY more (up to 9) with
	// Data Shards at the underground Neural Expansion Bay - the marquee trench incentive. The per-player
	// limit is applied on top of this base by acc_perks::acc_perk_slot_limit, installed as the stock
	// hook level.get_player_perk_purchase_limit (consumed by can_player_purchase_perk ->
	// get_player_perk_purchase_limit, _zm_utility.gsc:5874-5889). VERIFIED(acc): level.perk_purchase_limit
	// is the writable stock base field (default 4, _zm_perks.gsc:43).
	level.perk_purchase_limit = 4;

	level zm_perks::spare_change();

	level thread CheckForPower();
	level thread better_max_ammo();

	// [acc] Spawn COUNT chain (user 2026-06-24: coop +30%/extra-player re-added). early_round_pacing
	// chains level.max_zombie_func first (carries the modifier-round multiplier), THEN coop_scaling
	// wraps it with acc_coop_max_zombie_override (per-player count vs solo). Order IS load-bearing -
	// coop must install last so it wraps early_round_pacing -> stock default_max_zombie_func.
	acc_early_round_pacing::post_zm_main();
	acc_coop_scaling::post_zm_main();
	// [acc] Zombie speed curve has no spawn-lever chaining - it applies per zombie
	// on spawn (acc_zombie_speed::init, threaded from acc_main::init).

	// [acc] All remaining custom systems spin up on their own thread. Each
	// module no-ops gracefully when its Radiant geometry doesn't exist yet,
	// so this is safe in the starting-room-only build.
	level thread acc_main::init();

	// [acc] Avogadro electric boss DISABLED for release (user 2026-06-25): not shipping him yet.
	// The AI stays registered (the _zm_ai_avogadro #using above) but NOTHING spawns him - this is the
	// only spawn path. To bring him back, uncomment the thread below and give _acc_boss_avogadro::init()
	// a real cadence (its old acc_avo_test round-1 default is now 0, so re-enabling won't surprise-spawn
	// one on round 1).
	// level thread acc_boss_avogadro::init();
}

// [acc] DEV MODE - the SINGLE switch (user 2026-06-22). Reads `acc_dev` ONCE, caches it in level.acc_dev
// (the canonical gate every module reads), then DRIVES the legacy sub-dvars off that one flag so modules
// that still read their own dvar (perk doors / boss-test / auto-power / variant-debug) follow dev with no
// per-feature flag to set. THIS is the place to hardcode dev values: add a SetDvar
// here (or an `if ( level.acc_dev )` branch in the relevant module) - NEVER add a new dev dvar. Runs first
// in main(), before any consumer reads them. docs/49.
//
// PUBLISH-SAFE (user 2026-06-29): both flags restored to their dvar GATES (default 0 = normal play). The shipped .ff
// plays normally; the launch scripts can still flip them on for testing (+set acc_dev 1 / the PLAY_GOD_MODE script's
// +set acc_god 1). Mocks are dev-gated (force_mocks = IS_TRUE(level.acc_dev)) so they're off in ship too.
function acc_resolve_dev_flags()
{
	// Resolved from the acc_dev dvar (default 0 = ship-safe normal play; the dev launch scripts pass +set acc_dev 1).
	// This is the canonical gate every module reads via IS_TRUE( level.acc_dev ). docs/49.
	level.acc_dev = ( getdvarint( "acc_dev", 0 ) == 1 );

	v = ( level.acc_dev ? "1" : "0" );
	SetDvar( "acc_open_map",      v );   // _acc_perk_doors reads this dvar (entry gate uses level.acc_dev)
	SetDvar( "acc_glitch_test",   v );   // _acc_boss_glitch (Glitch Stalker dev test spawn)
	SetDvar( "acc_variants_debug",v );   // on-screen weapon-variant swap readout (dev aid)
	// All 10 Lab perk alcoves OPEN in dev mode (user 2026-06-26). _acc_perk_doors::dev_all_open() reads this
	// dvar; forcing it on under dev bypasses the per-round 4-of-10 rotation so every perk is buyable while
	// testing. Normal play (acc_dev 0) leaves it at the ship default 0 -> the rotation runs as designed.
	// (Reverses the 2026-06-18 "walls close in dev too" choice; the manual `set acc_perk_doors_all_open 1`
	// override still works independently in normal play.)
	SetDvar( "acc_perk_doors_all_open", v );
	// HUDELEM POOL DIAGNOSTIC (user 2026-06-28): dev auto-enables the on-screen hudelem-pool logger
	// (acc_utility::he_check / he_log) so the 4-player mock roster surfaces "<widget> did NOT allocate -
	// POOL FULL" + the live high-water count. Normal play (acc_dev 0) leaves it off; `set acc_hudelem_debug 1` also works.
	SetDvar( "acc_hudelem_debug", v );
	// NOT driven by dev, so dev plays like the real game for these (user 2026-06-22):
	//   acc_auto_power   - flip the Bus Station power switch yourself
	//   acc_test_boss    - Brutus follows his real round-5 power cadence (brutus_power_watch), no early spawn
	//   acc_phantom_test - the Phantom ("Reaper") follows its real round-10 cadence (its master gate is
	//                      dev-bypassed in _acc_boss_phantom so the cadence still runs in dev)
	// All three stay default-off; pass them manually if you want the early test spawns.

	acc_utility::log( "DEV MODE = " + ( level.acc_dev ? "ON (acc_dev 1)" : "off - normal play" ) );

	// [acc] GOD MODE - a SEPARATE test flag from acc_dev (which deliberately has NO god, so it plays with
	// real damage). `+set acc_god 1` (the standalone PLAY_GOD_MODE launch script) makes every player
	// invulnerable so the user can test NORMAL gameplay - real perks/economy/progression, closed map -
	// without dying. Default 0; INDEPENDENT of acc_dev; changes NO existing dev/normal behavior. See
	// acc_god_watch(). This is the user's explicit "non-dev god test" ask (user 2026-06-22).
	// Resolved from the acc_god dvar (default 0 = off; the standalone PLAY_GOD_MODE launch script passes +set acc_god 1).
	// Every player INVULNERABLE when on (damage zeroed in _acc_elites::on_player_damaged; effects still fire). Ship-safe.
	level.acc_god = ( getdvarint( "acc_god", 0 ) == 1 );
	acc_utility::log( "GOD MODE = " + ( level.acc_god ? "ON (acc_god 1)" : "off" ) );
}

// [acc] God mode no longer uses a per-player EnableInvulnerability loop (removed 2026-06-27). It is enforced by a
// damage-zeroing branch in _acc_elites::on_player_damaged so the per-hit EFFECTS (EMP debuff, trench melee scaling,
// the Phantom chain slow) STILL fire under god - EnableInvulnerability suppressed the whole callback. See main().

// [acc] Dev sandbox, threaded from main() only when level.acc_dev. Lives in the entry script so it runs
// independently of every _acc_ module init. Unlimited money + 25 starting Data Shards + Mega Bottles +
// banner. NO god mode and NO auto power-on - the user tests with regular gameplay/damage and flips the
// power switch themselves (user 2026-06-22). No-op in normal play. (The auto-power block below stays as a
// dormant manual shortcut: it only fires if someone explicitly sets acc_auto_power 1; dev no longer does.)
function acc_hardcoded_dev()
{
	level endon( "end_game" );

	// "initial_blackscreen_passed" is a stock flag set early in the load
	// (flag::wait_till returns immediately if already set).
	level flag::wait_till( "initial_blackscreen_passed" );

	// OPTIONAL auto power-on, OFF by default (user 2026-06-18): power now comes from the
	// Bus Station (corp) power switch the player flips - the stock switch handler
	// (_zm_power.gsc:106 + :115) runs the two calls below itself (perk_unpause_all_perks +
	// turn_power_on_and_open_doors), which lights perks + buyable, sets the "power_on" flag
	// (-> PaP powers, traps arm, doors open) AND triggers the fog settle (apply_fog polls
	// power_on). So nothing here is needed in normal play. Kept behind `acc_auto_power 1` as a
	// dev shortcut to skip hunting for the switch (replicates exactly what the flip does).
	if ( getdvarint( "acc_auto_power", 0 ) == 1 && !( level flag::get( "power_on" ) ) )
	{
		wait 1.5;   // let the power system + perk machines finish registering powered-items
		level thread zm_perks::perk_unpause_all_perks();
		level zm_power::turn_power_on_and_open_doors();
		acc_utility::log( "auto power-on (dev): replicated switch (perks lit + buyable, PaP/traps on, fog settles)" );
	}

	count = 0;
	for ( ;; )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) )
				continue;

			// (No god mode - the user tests with regular gameplay/damage, user 2026-06-22.)

			// Unlimited money (reading .score is fine; write via the API).
			cur = 0;
			if ( isdefined( p.score ) )
				cur = p.score;
			if ( cur < 100000 )
				p zm_score::add_to_player_score( 1000000 - cur );

			// Data Shards: START dev with 25 (ONE-SHOT), then let the real trench economy run - NOT the
			// old per-second 999 pin, which made testing a shard SPEND impossible (user 2026-06-22).
			// grant_player clamps to the cap + syncs the HUD; "dev" source skips diminishing.
			if ( !isdefined( p.acc_data_shards ) )
				p.acc_data_shards = 0;
			if ( !IS_TRUE( p.acc_dev_shards_granted ) )
			{
				p.acc_dev_shards_granted = true;
				acc_data_shards::grant_player( p, 25, "dev" );
			}

			// Mega Bottles topped up so perk Mega-upgrades are testable WITHOUT
			// having to kill the boss (own the perk, hold a bottle, look at its
			// machine -> "Hold for Mega upgrade").
			if ( !isdefined( p.acc_mega_bottles ) )
				p.acc_mega_bottles = 0;
			if ( p.acc_mega_bottles < 5 )
				p acc_mega_bottles::grant_bottle( 25, "dev" );

			// On-screen status banner (first ~15 s) including acc_main init state.
			if ( count < 15 )
			{
				init_state = ( IS_TRUE( level.acc_init_complete ) ? "^2COMPLETE" : "^3pending" );
				p IPrintLnBold( "^2[ACC] DEV BUILD LIVE ^7- map open, power on, systems: " + init_state );
			}
		}
		count++;
		wait 1;
	}
}

// [acc] CUSTOM buyable zone doors (user 2026-06-22, FIXED). The stock map-placed zombie_door triggers show
// NO buy prompt on this map (generator-written triggers - their usability/team filter never gets set, and a
// map trigger_use can't simply be re-enabled because the zone system keeps re-disabling it). FIX = the SAME
// thing the working trench/abyss doors do: disable each dead stock trigger and SPAWN our own
// trigger_radius_use at the door's real world center (hardcoded per door in zone_door_trigger_origin, since a
// map brush's .origin is (0,0,0) - no origin brush). Runs in BOTH modes - doors are never auto-opened; dev
// just has unlimited money.
// DEV-ONLY on-screen door log. No-op in normal play (gated on level.acc_dev), so nothing prints for a
// shipping/real game; flip dev on to see the door diagnostics again.
// Door setup tracing. ROUTED TO THE LOG (user 2026-06-27): was IPrintLnBold (on-screen "[accdoor]" spam in
// dev); now goes to acc_utility::log so the info is kept but the screen stays clean. Doors are confirmed
// working, so the on-screen readout is no longer needed.
function acc_door_dbg( msg )
{
	acc_utility::log( msg );
}

function acc_fix_zone_doors()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );
	wait 1;   // let stock door_init finish (it flag::init's the script_flags we set on purchase)
	doors = GetEntArray( "zombie_door", "targetname" );
	level.acc_door_dbg = [];   // DEBUG: each spawned trigger's {flag, org} for the live distance readout
	n = 0;
	flags = "";
	for ( i = 0; i < doors.size; i++ )
	{
		d = doors[ i ];
		if ( !isdefined( d ) )
			continue;
		level thread zone_door_buy_loop( d );
		n++;
		flags = flags + " " + ( isdefined( d.script_flag ) ? d.script_flag : "?noflag?" );
	}
	// DISABLED (user 2026-06-27): the periodic on-screen "[doordbg]" readout was dev clutter. The doors are
	// confirmed working, so the readout is retired (zone_door_debug stays in the file, just not threaded).
	// Re-enable by restoring this line if door triggers ever need live distance debugging again.
	// if ( IS_TRUE( level.acc_dev ) )   // door debug = DEV ONLY (no on-screen text in normal play)
	// 	level thread zone_door_debug();
	acc_door_dbg( "[accdoor] " + n + " doors found:" + flags );
	acc_utility::log( "zone doors: " + n + " ->" + flags );
}

// [acc] Plaza crates = cover obstacles AND Data Caches (user 2026-06-28: "make them give shards, 1 each, refill
// every round"). Same p7_cai_stacking_cargo_crate prop as the trench caches, but spawned via
// acc_data_shards::spawn_cache_at so each is now a hold-USE shard source: grants 1 Data Shard, depletes when
// looted, re-arms at the next round start (with the dim-white "armed" glow). COLLISION is STILL the matching
// 'clip' brushes in the .map (tools/gen_plaza_shrink.js CLIPS) - KEEP THESE COORDS IN SYNC (prop-clip drift
// footgun, memory prop-clips-drift-invisible-walls). spawn_cache_at re-uses the same SetModel path + same origin
// + default angle 0, so the crates look/collide identically to the old decorative props (user 2026-06-26 "only
// the little bunker/crate things" design preserved) - they just grant shards now. NOTE: in CO-OP the shared
// "one cache per player per round" anti-hog cap (acc_cache_one_per_player) spans these + the 2 trench caches;
// SOLO is exempt, so all 3 are grabbable each round there.
function acc_spawn_plaza_props()
{
	level endon( "end_game" );
	// spawn_cache_at needs level.acc_shards_cache_model (set in acc_data_shards::init); poll so this is
	// independent of module init order (data_shards::init always runs via acc_main, so this clears fast).
	while ( !isdefined( level.acc_shards_cache_model ) )
		wait 0.05;
	// CRATES ONLY, in the OPEN exit band (NEVER in a maze leg - a crate there blocks the ~120u corridor =
	// "stuck on one side"). SPREAD across the open plaza. ANGLE 0 (axis-aligned, spawn_cache_at's default) so
	// each crate matches its axis-aligned 56x56 clip. Coords MUST match tools/gen_plaza_shrink.js CLIPS.
	// count = 1 -> 1 Data Shard each (cache_yield clamps; no round scaling at the default acc_cache_scale_rounds).
	acc_data_shards::spawn_cache_at( ( -320,  30, 0 ), 1 );
	acc_data_shards::spawn_cache_at( (   80, 230, 0 ), 1 );
	acc_data_shards::spawn_cache_at( (  -80, 560, 0 ), 1 );
	acc_utility::log( "plaza props: 3 crate Data Caches spawned (1 shard each, refill/round)" );
}
function acc_spawn_prop( model, org, yaw )
{
	m = spawn( "script_model", org );
	m.angles = ( 0, yaw, 0 );
	m setmodel( model );
}

// One buyable zone door - EXACT copy of the working _acc_abyss_doors pattern (user 2026-06-22): DISABLE the
// dead stock map trigger and SPAWN our own trigger_radius_use at the door's real world center. We cannot read
// that center from d.origin (a map brush with no origin brush reports (0,0,0) = the map center - that was the
// bug), and a map trigger_use can't just be "made usable" because the zone system re-disables it. So the
// position is HARDCODED per door from the .map brush geometry (zone_door_trigger_origin, via
// tools/door_centers.js). On buy: charge points, set the script_flag (activates the zone adjacency), and clear
// the door slab (hide/notsolid/connectpaths so players pass + zombies path through).
function zone_door_buy_loop( d )
{
	level endon( "end_game" );

	cost = ( isdefined( d.zombie_cost ) ? int( d.zombie_cost ) : 1000 );
	clip = ( isdefined( d.target ) ? GetEnt( d.target, "targetname" ) : undefined );
	org  = zone_door_trigger_origin( d );
	flag = ( isdefined( d.script_flag ) ? d.script_flag : "?noflag?" );

	if ( !isdefined( org ) )   // unknown door (no hardcoded center) - leave it to the stock path, don't break it
	{
		acc_door_dbg( "[accdoor] " + flag + " - NO HARDCODED ORG, skipped" );
		return;
	}

	if ( isdefined( clip ) )   // ensure CLOSED (barrier solid + nav cut) until bought
	{
		clip solid();
		clip disconnectpaths();
	}

	d TriggerEnable( false );   // the dead stock trigger; our spawned ones drive the buy
	d.acc_bought = false;
	d.acc_trigs  = [];

	// Spawn a buy-trigger on BOTH sides of the doorway's thin axis. The door SLAB sits between the two zones;
	// a single trigger at the door CENTER is occluded by the slab from the approach side -> no prompt (the bug,
	// confirmed by logs: player 24u away, inside radius, trigger never fired). One of the two offset triggers
	// is always on the player's side with a clear path. Whichever fires opens the door + retires both.
	off = zone_door_thin_offset( d );
	spawn_zone_door_trigger( d, org + off, cost, clip, flag, "+" );
	spawn_zone_door_trigger( d, org - off, cost, clip, flag, "-" );

	acc_door_dbg( "[accdoor] " + flag + " 2 trigs @ " + int( org[0] ) + "," + int( org[1] ) + "," + int( org[2] ) );
}

// Offset OUT past the slab along the doorway's THIN axis. Most doors are thin in X; the 2 under-room doors
// are thin in Y. 60u clears the ~64u-wide doorway brush so each trigger sits in open space on its side.
function zone_door_thin_offset( d )
{
	if ( isdefined( d.script_flag ) && ( d.script_flag == "enter_under_lab" || d.script_flag == "enter_under_plaza" || d.script_flag == "enter_implant" ) )
		return ( 0, 60, 0 );   // doorways thin in Y (the door slab spans X) -> offset the buy triggers along Y
	return ( 60, 0, 0 );
}

function spawn_zone_door_trigger( d, pos, cost, clip, flag, side )
{
	t = spawn( "trigger_radius_use", pos, 0, 96, 100 );
	t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger (memory script-trigger-needs-ignoreteam)
	t SetCursorHint( "HINT_NOICON" );
	t SetHintString( "Hold ^3[{+activate}]^7  Open Door  ^2[Cost: " + cost + "]" );

	d.acc_trigs[ d.acc_trigs.size ] = t;

	dbg = spawnstruct();   // DEBUG: register for the live distance readout
	dbg.flag = flag + side;
	dbg.org  = pos;
	level.acc_door_dbg[ level.acc_door_dbg.size ] = dbg;

	t thread zone_door_trigger_wait( d, cost, clip, flag );
}

function zone_door_trigger_wait( d, cost, clip, flag )
{
	level endon( "end_game" );
	for ( ;; )
	{
		self waittill( "trigger", player );
		if ( !isdefined( player ) || !isplayer( player ) )
			continue;
		acc_door_dbg( "[accdoor] " + flag + " USED (cost " + cost + ")" );
		if ( IS_TRUE( d.acc_bought ) )
			return;
		// [acc] GLITCH-PURGE SEAL (user 2026-06-25): a door bordering the room that is currently sealed by
		// an active lockdown purge must NOT open - else a player sealed inside just buys an un-bought border
		// door and walks straight out (the reported escape bug). Refuse with the no-purchase deny; the gate
		// auto-lifts the moment the purge resolves, so the door buys normally afterwards.
		if ( acc_lockdown_challenge::is_door_sealed( flag ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		if ( !( player zm_score::can_player_purchase( cost ) ) )
		{
			player PlaySound( "zmb_no_purchase" );
			continue;
		}
		player zm_score::minus_to_player_score( cost );
		player PlaySound( "zmb_cha_ching" );
		d.acc_bought = true;

		if ( isdefined( d.script_flag ) && level flag::exists( d.script_flag ) )
			level flag::set( d.script_flag );
		if ( isdefined( clip ) )
		{
			clip hide();
			clip notsolid();
			clip connectpaths();
		}
		// retire BOTH triggers (clear the prompt on the now-open door)
		for ( i = 0; i < d.acc_trigs.size; i++ )
		{
			if ( isdefined( d.acc_trigs[ i ] ) )
			{
				d.acc_trigs[ i ] SetHintString( "" );
				d.acc_trigs[ i ] TriggerEnable( false );
			}
		}
		acc_door_dbg( "[accdoor] " + flag + " OPENED" );
		return;
	}
}

// Hardcoded buy-trigger origin per door (the door brush's own world center + 40z), because a map brush's
// .origin is (0,0,0) - no origin brush. Extracted from the .map brush geometry by tools/door_centers.js;
// re-run that if any door brush moves. Keyed by the door's script_flag.
function zone_door_trigger_origin( d )
{
	if ( !isdefined( d.script_flag ) )
		return undefined;
	switch ( d.script_flag )
	{
	case "enter_under_lab":   return ( 0, 2161, -200 );
	case "enter_under_plaza": return ( -160, 1735, -200 );
	case "enter_implant":     return ( -220, -240, 50 );   // Plaza Implant Lab door (doorway x[-260,-180] in the plaza south wall)
	case "enter_exchange":    return ( -380, -376, 50 );   // The Exchange staircase-room EAST doorway, SW corner of the enlarged Implant Lab (tools/gen_plaza_basement.js); X-thin -> default (60,0,0) offset
	case "enter_market":      return ( -1168, 528, 40 );
	case "enter_alley":       return ( 1207, 528, 40 );
	case "enter_corp_w":      return ( -1031, 1328, 40 );
	case "enter_corp_e":      return ( 1069, 1328, 40 );
	case "enter_vault":       return ( 969, 2428, 40 );
	case "enter_roof":        return ( -950, 2428, 40 );
	case "enter_lab_e":       return ( 969, 3228, 40 );
	case "enter_lab_w":       return ( -950, 3228, 40 );
	}
	return undefined;
}

// DEBUG (user 2026-06-22): live nearest-buy-trigger readout. Every 2s prints on the local player's screen:
// how many triggers spawned, the nearest one's flag + distance, and the player's own XYZ. Walk to a door:
//   - dist drops near 0 but NO prompt  -> the trigger is there but not usable (different bug)
//   - dist stays large at the door     -> the hardcoded coord is wrong / trigger spawned elsewhere
//   - "0 buy-triggers spawned"         -> acc_fix_zone_doors found no doors / all skipped (no org)
// Toggle off with `acc_door_debug 0`. REMOVE this once the doors are confirmed working.
function zone_door_debug()
{
	level endon( "end_game" );
	for ( ;; )
	{
		wait 2;
		if ( getdvarint( "acc_door_debug", 1 ) != 1 )
			continue;
		players = GetPlayers();
		if ( players.size == 0 )
			continue;
		p = players[ 0 ];
		if ( !isdefined( p ) )
			continue;
		if ( !isdefined( level.acc_door_dbg ) || level.acc_door_dbg.size == 0 )
		{
			p IPrintLnBold( "[doordbg] 0 buy-triggers spawned!" );
			continue;
		}
		pos = p.origin;
		bestd = 9999999;
		bestf = "?";
		for ( i = 0; i < level.acc_door_dbg.size; i++ )
		{
			dd = Distance( pos, level.acc_door_dbg[ i ].org );
			if ( dd < bestd )
			{
				bestd = dd;
				bestf = level.acc_door_dbg[ i ].flag;
			}
		}
		p IPrintLnBold( "[doordbg] " + level.acc_door_dbg.size + " trigs | nearest " + bestf + " " + int( bestd ) + "u" + ( bestd < 96 ? " <<IN-RANGE - prompt should show" : "" ) + " | you " + int( pos[0] ) + "," + int( pos[1] ) + "," + int( pos[2] ) );
	}
}

// [acc] Open-the-whole-map, gated on `acc_open_map` at the call site in main().
// Opens every buyable door and activates the zone behind it, so the player can
// walk the entire map from spawn (no buying, no being stuck in the start room).
// Doors are zombie_door trigger_use entities whose `target` is a script_brushmodel
// slab that normally slides up on purchase. No-op in normal play (flag unset).
function acc_hardcoded_open_map()
{
	level endon( "end_game" );

	level flag::wait_till( "initial_blackscreen_passed" );
	wait 3; // let stock blocker init + zone adjacency init finish first

	doors = GetEntArray( "zombie_door", "targetname" );
	for ( i = 0; i < doors.size; i++ )
	{
		door = doors[ i ];
		if ( !isdefined( door ) )
			continue;

		// Activate the zone behind this door (the adjacency flag set on purchase).
		// Stock door_init flag::init's script_flag during load; guard anyway so a
		// timing edge can never make flag::set fatal under abort_on_error.
		if ( isdefined( door.script_flag ) && level flag::exists( door.script_flag ) )
			level flag::set( door.script_flag );

		// Physically clear the door slab so the opening is passable + pathable.
		if ( isdefined( door.target ) )
		{
			slab = GetEnt( door.target, "targetname" );
			if ( isdefined( slab ) )
			{
				slab ConnectPaths();
				slab NotSolid();
				slab Hide();
			}
		}

		// No buy prompt - it is already open.
		door TriggerEnable( false );
	}

	// [acc] Per-run PaP blocker brushes. The map randomizer (apply_pap_approach)
	// leaves ONE of acc_pap_block_server / acc_pap_block_roof solid every run to
	// gate the Pack-a-Punch approach. These are bare script_brushmodels (NO
	// trigger, NO script_flag), so the zombie_door loop above never touches them -
	// that is the "one door that never opens", and it walls off the Mystery Box on
	// the runs the box rolls to the blocked side. Open BOTH (inverse of the
	// randomizer's block: Hide / NotSolid / ConnectPaths) so the whole map - box
	// included - is always reachable while we dev-test. Runs at blackscreen+3s,
	// after apply_pap_approach has already applied the per-run block, so this wins.
	pap_names = array( "acc_pap_block_server", "acc_pap_block_roof" );
	pap_opened = 0;
	for ( i = 0; i < pap_names.size; i++ )
	{
		blockers = GetEntArray( pap_names[ i ], "targetname" );
		for ( j = 0; j < blockers.size; j++ )
		{
			b = blockers[ j ];
			if ( !isdefined( b ) )
				continue;
			b Hide();
			b NotSolid();
			b ConnectPaths();
			pap_opened++;
		}
	}

	/# println( "[acc] HARDCODED: opened " + doors.size + " doors / all zones + " +
	            pap_opened + " PaP blocker(s)" ); #/
}

// [acc] Custom per-perk costs (docs/13_perks.md). The perk cost is read from
// level._custom_perks[specialty].cost (the same field the PhD Flopper module
// sets); set it before the first purchase. Buying all 9 = 27,500 by design
// (Double Tap 3,000).
function set_perk_costs()
{
	if ( !isdefined( level._custom_perks ) )
		return;

	costs = [];
	costs[ "specialty_armorvest" ]               = 4000; // Jugger-Nog
	costs[ "specialty_quickrevive" ]             = 2500; // Quick Revive
	costs[ "specialty_fastreload" ]              = 3500; // Speed Cola
	costs[ "specialty_doubletap2" ]              = 3000; // Double Tap 2.0 (extra bullet = ~2x dmg; 5000 -> 3000 user 2026-06-25)
	costs[ "specialty_staminup" ]                = 2000; // Stamin-Up
	costs[ "specialty_additionalprimaryweapon" ] = 2500; // Mule Kick
	costs[ "specialty_deadshot" ]                = 3500; // Deadshot
	costs[ "specialty_widowswine" ]              = 4000; // Widow's Wine
	costs[ "specialty_combat_efficiency" ]       = 3000; // Electric Cherry (real 10th perk, _acc_perk_electric_cherry); also set in register_perk_basic_info
	// PhD Flopper (over specialty_electriccherry) = 2500, set in _acc_perk_phd_flopper.

	keys = GetArrayKeys( costs );
	for ( i = 0; i < keys.size; i++ )
	{
		perk = keys[ i ];
		if ( isdefined( level._custom_perks[ perk ] ) )
			level._custom_perks[ perk ].cost = costs[ perk ];
	}
}

function CheckForPower()
{
	level util::set_lighting_state(0);
	// VERIFIED(acc): "power_on" is a FLAG (_zm.gsc:1615 init, _zm_power.gsc:730
	// set) - a bare waittill misses an already-set flag. Stock waiters use the
	// flag API (zm_giant.gsc:427, _zm_traps.gsc:273).
	level flag::wait_till( "power_on" );
	// Mask to the CURRENT pre-power darkness BEFORE flipping the lightmap to bright, so there is neither a
	// FLASH of full brightness NOR a dip to pitch-black (user 2026-06-22: "stay the same darkness, don't go
	// darker"). NOT pure black - acc_power_light_start matches the dark you already have (default warm1 ~18%;
	// swap live to dial it in). _acc_atmosphere::apply_vision then SLOW-ramps that start -> default.
	if ( getdvarint( "acc_power_light_ramp_on", 1 ) == 1 )
	{
		VisionSetNaked( getdvarstring( "acc_power_light_start", "acc_grade_warm1" ), 0 );
		wait 0.05;
	}
	level util::set_lighting_state(1);
}

function better_max_ammo()
{
	while(1)
	{
		level waittill( "zmb_max_ammo_level" );
		foreach(player in GetPlayers())
		{
			player.ScreecherPrimaryWeapons = player GetWeaponsListPrimaries();
			foreach(gun in player.ScreecherPrimaryWeapons)
			{
				weap = GetWeapon(gun.name);
				player SetWeaponAmmoClip(gun, weap.clipSize);
			}
		}
	}
}

function usermap_test_zone_init()
{
	level flag::init( "always_on" );
	level flag::set( "always_on" );

	// [acc] 7-zone graph (docs/03_layout.md). VERIFIED(acc): an info_volume
	// alone does nothing - a zone only exists once zone_init runs, reached
	// via add_adjacent_zone / the manage_zones init list (_zm_zonemgr.gsc:288,
	// :595). Each flag below is set by the matching buyable door's
	// script_flag KVP on purchase (stock _zm_blockers.gsc:952-959); the
	// zone behind a door activates on the next ~1s zonemgr scan after buy.
	zm_zonemgr::add_adjacent_zone( "start_zone",  "market_zone", "enter_market" );
	zm_zonemgr::add_adjacent_zone( "start_zone",  "alley_zone",  "enter_alley" );
	zm_zonemgr::add_adjacent_zone( "market_zone", "corp_zone",   "enter_corp_w" );
	zm_zonemgr::add_adjacent_zone( "alley_zone",  "corp_zone",   "enter_corp_e" );
	zm_zonemgr::add_adjacent_zone( "corp_zone",   "vault_zone",  "enter_vault" );
	zm_zonemgr::add_adjacent_zone( "corp_zone",   "roof_zone",   "enter_roof" );
	zm_zonemgr::add_adjacent_zone( "vault_zone",  "lab_zone",    "enter_lab_e" );
	zm_zonemgr::add_adjacent_zone( "roof_zone",   "lab_zone",    "enter_lab_w" );
}

function custom_add_weapons()
{
	zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);
}

// [acc] Disable the Death Machine (minigun) powerup so it never drops (user 2026-06-22). The stock
// minigun powerup is registered during the load bootstrap; once level.zombie_powerups["minigun"] exists
// we swap its drop gate to acc_minigun_never_drop (returns false), so get_valid_powerup() skips it on
// every roll (_zm_powerups.gsc:379). Poll briefly in case registration lands a frame after main().
function acc_disable_minigun_powerup()
{
	level endon( "end_game" );
	for ( i = 0; i < 60; i++ )
	{
		if ( isdefined( level.zombie_powerups ) && isdefined( level.zombie_powerups[ "minigun" ] ) )
		{
			level.zombie_powerups[ "minigun" ].func_should_drop_with_regular_powerups = &acc_minigun_never_drop;
			return;
		}
		wait 0.5;
	}
}

// Drop gate that always refuses - installed on the minigun powerup so the Death Machine never spawns.
function acc_minigun_never_drop()
{
	return false;
}

// [acc] De-dupe Pack-a-Punch so the map can LOAD (user 2026-06-25). Stock supports exactly ONE PaP - it
// hardcodes the targetname "vending_packapunch" (_zm_pack_a_punch.gsc:131) and later GetEnt()s it (single),
// which FATALS if two PaP zbarriers exist. A 2nd PaP got added in the abyss hub (z=-1200) with the same
// "zm_pack_a_punch" targetname as the surface PaP. We keep the HIGHEST-z PaP (the surface machine) and strip
// the targetname off the rest so stock's GetEntArray("zm_pack_a_punch") (spawn_init, :84) sees exactly one.
// Called FIRST in main(), before zm_usermap::main() runs PaP init. The zbarrier is a static map/prefab entity
// (baked into the BSP), so it is queryable here. Idempotent + self-healing: re-runs every load, so it keeps
// working even if the .map is re-duplicated by concurrent edits. Only touches PaP (perk machines coexist fine).
function acc_dedupe_pack_a_punch()
{
	paps = GetEntArray( "zm_pack_a_punch", "targetname" );
	if ( !isdefined( paps ) || paps.size <= 1 )
		return;

	// Keep the surface PaP = the one with the GREATEST z (the abyss duplicate sits at z=-1200).
	keep = paps[ 0 ];
	for ( i = 1; i < paps.size; i++ )
	{
		if ( isdefined( paps[ i ] ) && isdefined( paps[ i ].origin ) && paps[ i ].origin[ 2 ] > keep.origin[ 2 ] )
			keep = paps[ i ];
	}

	n = 0;
	for ( i = 0; i < paps.size; i++ )
	{
		if ( isdefined( paps[ i ] ) && paps[ i ] != keep )
		{
			paps[ i ].targetname = "acc_dup_pap_disabled";   // stock GetEntArray("zm_pack_a_punch") no longer finds it
			paps[ i ] Hide();        // user 2026-06-25: REMOVE the Paradise PaP visually too (not just disable) - back to one working Lab PaP
			paps[ i ] NotSolid();
			n++;
		}
	}
	/# println( "[acc] de-duped PaP: kept surface machine (z=" + keep.origin[ 2 ] + "), disabled " + n + " duplicate(s)" ); #/
}

// De-dupe The Exchange transfer-vault door (see the call site in main()). Two fixes: (1) rename surplus
// "acc_door_exchange" SLABS off the GetEnt key so GetEnt("acc_door_exchange") resolves to exactly one (kills the
// fatal); (2) rename+disable surplus zombie_door buy TRIGGERS so acc_fix_zone_doors threads ONE buy loop for the
// door (no double prompt / double charge). Self-heals every load.
function acc_dedupe_exchange_door()
{
	slabs = GetEntArray( "acc_door_exchange", "targetname" );
	for ( i = 1; i < slabs.size; i++ )
		if ( isdefined( slabs[ i ] ) )
			slabs[ i ].targetname = "acc_door_exchange_dupe";

	trigs = GetEntArray( "zombie_door", "targetname" );
	seen = false;
	for ( i = 0; i < trigs.size; i++ )
	{
		if ( !isdefined( trigs[ i ] ) ) continue;
		if ( !isdefined( trigs[ i ].target ) || trigs[ i ].target != "acc_door_exchange" ) continue;
		if ( seen )
		{
			trigs[ i ].targetname = "zombie_door_dupe";   // hidden from acc_fix_zone_doors' GetEntArray("zombie_door")
			trigs[ i ] TriggerEnable( false );
		}
		else
			seen = true;
	}
}
