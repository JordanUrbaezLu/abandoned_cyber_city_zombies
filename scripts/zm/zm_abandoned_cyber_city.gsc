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
#using scripts\zm\zm_abandoned_cyber_city\_acc_early_round_pacing;
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

	// [acc] Register our callbacks + roll per-run map state. Runs after the
	// stock bootstrap but still inside main(), i.e. before the first game
	// tick, first player spawn, and first round calculation.
	acc_main::pre_init();

	// [acc] Aura Blast: overwrite the stock electric-cherry registration
	// (cost/hint/give/take) - must run AFTER zm_usermap::main() populated
	// level._custom_perks, BEFORE the first game tick.
	acc_perk_aura_blast::init();

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

	level zm_perks::spare_change();

	level thread CheckForPower();
	level thread better_max_ammo();

	// [acc] Chain level.max_zombie_func BEFORE round 1 computes spawn totals.
	acc_early_round_pacing::post_zm_main();

	// [acc] All remaining custom systems spin up on their own thread. Each
	// module no-ops gracefully when its Radiant geometry doesn't exist yet,
	// so this is safe in the starting-room-only build.
	level thread acc_main::init();
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
}

function custom_add_weapons()
{
	zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);
}
