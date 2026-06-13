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
// hijack for Aura Blast (see _acc_perk_aura_blast.gsc). Matching #using is in
// the entry .csc - required, or its clientfield registration mismatches.
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

//Traps
#using scripts\zm\_zm_trap_electric;

#using scripts\zm\zm_usermap;

// [acc] Custom systems. Modules live in scripts/zm/zm_abandoned_cyber_city/.
#using scripts\zm\zm_abandoned_cyber_city\_acc_main;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;
#using scripts\zm\zm_abandoned_cyber_city\_acc_coop_scaling;
#using scripts\zm\zm_abandoned_cyber_city\_acc_rampage_inducer;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_aura_blast;

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
	// VERIFIED(acc): must be set BEFORE zm_usermap::main() - the hook is
	// consumed synchronously inside the bootstrap (zm_usermap.gsc:135 DEFAULT()
	// -> load::main() -> zm::init() -> zm_weapons::init() -> _zm_weapons.gsc:678
	// [[level._zombie_custom_add_weapons]]()). DEFAULT() only assigns when
	// undefined, so pre-setting wins.
	level._zombie_custom_add_weapons =&custom_add_weapons;

	zm_usermap::main();

	// [acc] Disable stock Alternate Ammo Types (AAT) on Pack-a-Punch. Our PaP is
	// a 5-tier damage ladder (_acc_pap_levels) - we don't want the stock 2500
	// "re-pack for a random alt-ammo (turned/fireworks/etc.)" reroll. With this
	// off, aat::acquire is a no-op; re-packs route through our acc_pap_tier
	// trigger instead. (level.aat_in_use is the stock gate - _zm_weapons.gsc.)
	level.aat_in_use = false;

	// [acc] HARDCODED dev sandbox - lives in the ENTRY script (this main() provably
	// runs - the map loads) so it is independent of every _acc_ module. No dvar gate.
	// Unlimited money + Data Shards, auto-power, and OPENS THE WHOLE MAP (every door
	// + zone) so the full map is walkable/testable from spawn.
	level thread acc_hardcoded_dev();
	level thread acc_hardcoded_open_map();

	// [acc] HARDCODED: disable the decontamination zone-seal hazard. It kills any
	// player standing in a zone when it seals (rounds 1-4) - lethal on an open
	// map you're meant to roam freely. Read by _acc_decontamination::run_decon_phase.
	level.acc_disable_decon = true;

	// [acc] Register our callbacks + roll per-run map state. Runs after the
	// stock bootstrap but still inside main(), i.e. before the first game
	// tick, first player spawn, and first round calculation.
	acc_main::pre_init();

	// [acc] Aura Blast: overwrite the stock electric-cherry registration
	// (cost/hint/give/take) - must run AFTER zm_usermap::main() populated
	// level._custom_perks, BEFORE the first game tick.
	acc_perk_aura_blast::init();

	// [acc] Apply the map's custom per-perk costs (docs/13_perks.md - perk
	// customization is a headline feature). Runs before the first tick / first
	// machine read, same as the Aura Blast cost override above.
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

	// [acc] No perk cap (docs/13): all 9 perks can be held at once.
	// VERIFIED(acc): level.perk_purchase_limit is the writable stock field
	// (default 4, _zm_perks.gsc:43; consumed via can_player_purchase_perk ->
	// get_player_perk_purchase_limit, _zm_utility.gsc:5874-5889). Shipped
	// precedent: zm_alien_isolation sets 100 (zm_alien_isolation.gsc:209),
	// zm_countryside sets 15 - see docs/22_community_techniques.md.
	level.perk_purchase_limit = 9;

	level zm_perks::spare_change();

	level thread CheckForPower();
	level thread better_max_ammo();

	// [acc] Chain level.max_zombie_func BEFORE round 1 computes spawn totals.
	// ORDER IS LOAD-BEARING: coop_scaling chains AFTER early pacing so stock
	// invokes coop first (normalizes n_max to solo) before delegating down.
	acc_early_round_pacing::post_zm_main();
	acc_coop_scaling::post_zm_main();
	// [acc] Rampage Inducer chains both spawn levers (count + delay func) here,
	// before round 1 - inert until activated via the `acc_rampage` dvar / trigger.
	acc_rampage_inducer::post_zm_main();

	// [acc] All remaining custom systems spin up on their own thread. Each
	// module no-ops gracefully when its Radiant geometry doesn't exist yet,
	// so this is safe in the starting-room-only build.
	level thread acc_main::init();
}

// [acc] HARDCODED dev sandbox - entry-script level so it cannot be gated out by
// any _acc_ module init issue. Banner + permanent unlimited money + unlimited
// Data Shards + auto-power (so perks/PaP/traps are testable immediately).
function acc_hardcoded_dev()
{
	level endon( "end_game" );

	// "initial_blackscreen_passed" is a stock flag set early in the load
	// (flag::wait_till returns immediately if already set).
	level flag::wait_till( "initial_blackscreen_passed" );

	// Auto-power ON: perks, Pack-a-Punch and traps all gate on this stock flag.
	if ( !( level flag::get( "power_on" ) ) )
		level flag::set( "power_on" );

	count = 0;
	for ( ;; )
	{
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) )
				continue;

			// Unlimited money (reading .score is fine; write via the API).
			cur = 0;
			if ( isdefined( p.score ) )
				cur = p.score;
			if ( cur < 100000 )
				p zm_score::add_to_player_score( 1000000 - cur );

			// Unlimited Data Shards (Cyberware / Overclock currency). grant_player
			// clamps to the cap + syncs the HUD; "dev" source skips diminishing.
			if ( !isdefined( p.acc_data_shards ) )
				p.acc_data_shards = 0;
			if ( p.acc_data_shards < 200 )
				acc_data_shards::grant_player( p, 999, "dev" );

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

// [acc] HARDCODED open-the-whole-map. Opens every buyable door and activates the
// zone behind it, so the player can walk the entire map from spawn (no buying,
// no being stuck in the start room). Doors are zombie_door trigger_use entities
// whose `target` is a script_brushmodel slab that normally slides up on purchase.
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

	/# println( "[acc] HARDCODED: opened " + doors.size + " doors / all zones" ); #/
}

// [acc] Custom per-perk costs (docs/13_perks.md). The perk cost is read from
// level._custom_perks[specialty].cost (same field Aura Blast overrides); set it
// before the first purchase. Buying all 9 = 26,500 by design.
function set_perk_costs()
{
	if ( !isdefined( level._custom_perks ) )
		return;

	costs = [];
	costs[ "specialty_armorvest" ]               = 4000; // Jugger-Nog
	costs[ "specialty_quickrevive" ]             = 2500; // Quick Revive
	costs[ "specialty_fastreload" ]              = 3500; // Speed Cola
	costs[ "specialty_doubletap2" ]              = 2000; // Double Tap 2.0
	costs[ "specialty_staminup" ]                = 2000; // Stamin-Up
	costs[ "specialty_additionalprimaryweapon" ] = 2500; // Mule Kick
	costs[ "specialty_deadshot" ]                = 3500; // Deadshot
	costs[ "specialty_widowswine" ]              = 4000; // Widow's Wine
	// Aura Blast (specialty_electriccherry) = 2500, set in _acc_perk_aura_blast.

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
