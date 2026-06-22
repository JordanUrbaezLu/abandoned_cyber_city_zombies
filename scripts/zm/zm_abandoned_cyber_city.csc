// =============================================================================
// zm_abandoned_cyber_city.csc - map entry script (client-side)
//
// Mirrors the stock Launcher zm template verbatim. The client VM cannot call
// into .gsc files, so there are NO _acc_ usings here - our systems are
// server-authoritative for now. Client-side _acc_ modules (.csc) arrive with
// the LUI/HUD work in Phase 4; until then feedback uses server-driven
// iprintln/clientfield paths.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\audio_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\_load;
#using scripts\zm\_zm_weapons;

//Perks
#using scripts\zm\_zm_pack_a_punch;
#using scripts\zm\_zm_perk_additionalprimaryweapon;
#using scripts\zm\_zm_perk_doubletap2;
#using scripts\zm\_zm_perk_deadshot;
// [acc] Client half of the PhD Flopper pipeline (stock _zm_perk_electric_cherry
// owns the client clientfield + FX) - must match the entry .gsc #using or the
// clientfield registration mismatches at load.
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

// [acc] Client half of the LUI pipeline foundation - its REGISTER_SYSTEM
// autoexec registers the clientuimodel mirror (see _acc_lui.csc).
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;

// [acc] Client half of the perk/PaP power-on glow - its REGISTER_SYSTEM autoexec
// registers the "accPerkGlow" clientfield mirror + PlayFX's the glow (see
// _acc_perk_lights.csc / .gsc). Client-side FX is the path that renders here.
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;

// [acc] Client half of the Phantom holographic glow aura - its REGISTER_SYSTEM autoexec
// registers the "accPhantomAura" actor clientfield mirror + PlayFXOnTag's the cyan glow
// while the Phantom is materialized (see _acc_boss_phantom.csc / .gsc).
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_phantom;

function main()
{
	// [acc] Register our custom LUI HUD overlay with the client LUI VM before the
	// framework boots. Dot-path matches ui/uieditor/menus/hud/acc_hud.lua and the
	// GSC #precache("lui_menu","acc_hud") / OpenLUIMenu("acc_hud").
	LuiLoad( "ui.uieditor.menus.hud.acc_hud" );

	zm_usermap::main();

	include_weapons();

	util::waitforclient( 0 );
}

function include_weapons()
{
	zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);
}
