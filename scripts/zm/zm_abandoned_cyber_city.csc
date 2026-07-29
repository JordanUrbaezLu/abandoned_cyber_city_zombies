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

// HB21 Elemental Bows - LOCKSTEP with the .gsc #using block (clientfield registration).
// LIVE (2026-07-07) - LOCKSTEP with the .gsc block (clientfield registration). Deps installed.
#using scripts\zm\_zm_weap_elemental_bow;
#using scripts\zm\_zm_weap_elemental_bow_storm;
#using scripts\zm\_zm_weap_elemental_bow_rune_prison;
#using scripts\zm\_zm_weap_elemental_bow_wolf_howl;
#using scripts\zm\_zm_weap_elemental_bow_demongate;
// [acc] Winter's Howl freeze gun client twin (2026-07-11): the toggle_freezegun_* clientfield
// registration must lockstep with the server .gsc (mismatch otherwise). Self-registers via autoexec.
#using scripts\zm\_zm_weap_freezegun;

// [acc] HB21 Hero Weapons client twin (2026-07-24): registers the skull_* allplayers/actor
// clientfields + the gauntlet's local viewmodel FX watchers - MUST lockstep with the server
// .gsc registrations (Clientfield Mismatch otherwise). Self-registers via REGISTER_SYSTEM_EX.
#using scripts\zm\_hb21_zm_hero_weapon;

// [acc] AW 3D Printer Mystery Box client twin (2026-07-12): registers the
// exo_magicbox_dr_holo scriptmover clientfield + the dr_fx_holo duplicate-render filter -
// MUST lockstep with the server .gsc registration (Clientfield Mismatch otherwise).
// Self-registers via REGISTER_SYSTEM_EX("aw_mbox").
#using scripts\planet\_aw\_zm_aw_mysterybox;

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

// [acc] Aetherium HUD client half (see the entry .gsc note): mirrors the world-scope
// clientfield registrations IN LOCKSTEP and LuiLoads ui.uieditor.menus.HUD.AetheriumHud,
// which REDEFINES LUI.createMenu.T7Hud_zm_factory (the stock usermap ZM HUD menu key,
// docs/19) - that's the whole-HUD replacement. Kit README: #using ABOVE zm_usermap.
#using scripts\zm\_zm_aetherium_hud;

#using scripts\zm\zm_usermap;

// [acc] Civil Protector client half (HarryBo21 pack). Registers the robot_switch/robot_lights
// clientfield mirrors + the "Civil Protector" draw-name archetype hook - MUST match the entry
// .gsc #using or the clientfield registration mismatches at load.
#using scripts\zm\zm_zod_robot;

// [acc] Apothicon Fury client half (HarryBo21 pack) - meteor-spawn FX clientfield mirror.
// MUST match the entry .gsc #using or clientfield registration mismatches at load.
#using scripts\zm\zm_genesis_apothicon_fury;

// [acc] Client half of the 3D boss nameplate + health bar - REGISTER_SYSTEM mirrors the
// acc_bnp_name/acc_bnp_hp actor clientfields and renders them via SetDrawName (the floating
// name the user saw over the ally Civil Protector). MUST match the entry .gsc #using.
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_nameplate;

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

// [acc] Client half of the Avogadro electric boss (its "avogadro_fx" scriptmover clientfield +
// the linger/tesla FX). Must match the entry .gsc #using or the clientfield registration mismatches.
#using scripts\zm\zm_abandoned_cyber_city\_zm_ai_avogadro;
// Triple Take bolt visual (2026-07-16): acc_ttk_bolt_fx scriptmover clientfield -> plasma
// geotrail on the server's bolt movers (the gun's damage is hitscan; the orbs ARE the volley).
#using scripts\zm\zm_abandoned_cyber_city\_acc_tripletake;
// [acc] Interactable-station holo shimmer (2026-07-17): acc_interact_glow scriptmover
// clientfield -> duplicate-render cyan holo (the AW box material) on tagged station meshes.
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;

// [acc] Client half of the PANZER (Spiki mechz port, 2026-07-08). Registers the pack's
// 6 mechz clientfields AND mirror-registers the 11 stock server-side mechz fields (the one-sided
// "mechz_face" registration was the historical attack-CTD - see the file header). MUST stay in
// lockstep with the .gsc side (loaded via _acc_boss_panzer in the entry .gsc).
#using scripts\zm\mechz_spiki;

function main()
{
	// [acc] Register our custom LUI HUD overlay with the client LUI VM before the
	// framework boots. Dot-path matches ui/uieditor/menus/hud/acc_hud.lua and the
	// GSC #precache("lui_menu","acc_hud") / OpenLUIMenu("acc_hud").
	LuiLoad( "ui.uieditor.menus.hud.acc_hud" );

	// [acc] Leaderboard LUI (docs/40): the end_game recorder, the Plaza station fetcher,
	// and the background-agent boot (the fullscreen tab-out fix - the ONE process spawn,
	// at map load), opened on demand by _acc_leaderboard.gsc. GENERATED files
	// (tools/build_lb_lui.js) - hksc bytecode chunks (io/os) as \ddd strings, load(reader).
	LuiLoad( "ui.uieditor.menus.hud.acc_lb_rec" );
	LuiLoad( "ui.uieditor.menus.hud.acc_lb_board" );
	LuiLoad( "ui.uieditor.menus.hud.acc_lb_boot" );

	zm_usermap::main();

	include_weapons();

	util::waitforclient( 0 );
}

function include_weapons()
{
	zm_weapons::load_weapon_spec_from_table("gamedata/weapons/zm/zm_levelcommon_weapons.csv", 1);
}
