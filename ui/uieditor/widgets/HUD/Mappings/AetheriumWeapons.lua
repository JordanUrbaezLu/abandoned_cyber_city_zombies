-- Shared weapon data table (icon + description)
-- This is used by both loadout display and cursor hints
--
-- ACC: the kit's zm_weapon_ports rifles (sat_ar_* entries + their i_mtl_sat_icon_weapon_*_ao
-- icons) were REMOVED - that art isn't shipped in the Aetherium asset pack, so the entries
-- could only ever render blank. Our Skye guns intentionally have NO entries yet: an unmapped
-- weapon falls back to ["default"] = blacktransparent icon + the engine-localized name text
-- (the Loadout name comes from currentWeapon.weaponName, not this table), which reads fine.
-- To give a gun real art later: add ["<weapon_codename>"] = { ingame_name, icon, description }
-- (the lookup strips _upgraded/_upg/_zm/_up suffixes) - the kit wiki's How-To-Add-Weapons flow.
CoD.AetheriumWeaponData = {
	-- ============ ACC box/wall guns (2026-07-03, user: every gun needs a 2D HUD image) ============
	-- Icons are the ports' own wall-CHALK drawings (white outline art, shipped in each pack's
	-- source_data GDT, gdtdb-indexed, zone-listed in the AETHERIUM block). Four guns have NO
	-- per-gun art anywhere - they use a LOOKALIKE chalk (marked) - and MAHEM uses a stock-name
	-- guess (marked needs-verify). Variant/akimbo suffixes are stripped by GetWeaponIcon.
	["t6_fiveseven"] = {
		ingame_name = "Five-Seven",
		icon = "i_t6_wpn_pistol_b2023r_wall_chalk_c",   -- LOOKALIKE (B23R chalk; no Five-Seven art in the pack)
		description = "Semi-automatic pistol"
	},
	["t9_semiauto_cosplay"] = {
		ingame_name = "Blast-O-Matic",
		icon = "i_semiauto_cosplay_chaulk_new_c",
		description = "DOA energy blaster"
	},
	["s1_tac19"] = {
		ingame_name = "Tac-19",
		icon = "i_uts_19_wall_chalk_c",
		description = "Full-auto shotgun"
	},
	["t9_ak47"] = {
		ingame_name = "AK-47",
		icon = "i_weapon_vm_ar_t9damage_wall_chalk_c",
		description = "Hard-hitting assault rifle"
	},
	["s1_ae4"] = {
		ingame_name = "AE4",
		icon = "i_dear_wall_chalk_c",
		description = "Directed-energy assault rifle"
	},
	["s4_ppsh41_base"] = {
		ingame_name = "PPSh-41",
		icon = "i_ppapa41_wall_chalk_c",
		description = "High rate-of-fire SMG"
	},
	["t9_ak74u"] = {
		ingame_name = "AK-74u",
		icon = "i_weapon_vm_sm_t9heavy_wall_chalk_c",
		description = "Compact SMG"
	},
	["t8_paladin_hb50"] = {
		ingame_name = "Paladin HB50",
		icon = "i_t8_wpn_sniper_paladin_hb50_wall_chalk_c",
		description = "Bolt-action .50 cal"
	},
	["t6_olympia"] = {
		ingame_name = "Olympia",
		icon = "i_t6_wpn_shotty_olympia_wall_chalk_c",
		description = "Double-barrel shotgun"
	},
	["t9_grav"] = {
		ingame_name = "Grav",
		icon = "i_wpn_vm_ar_t9season6_wall_chalk_c",
		description = "Full-auto assault rifle"
	},
	-- [acc] 2026-07-05: these 4 box guns were MISSING from the table (fell to ["default"] = blank,
	-- so the loadout showed no chalk - the bare blue panel, which read as a faint "dark blue outline").
	-- All 4 chalk images verified WHITE outlines in their pack GDTs (audited via the source .tiff/.png).
	["t9_xm4"] = {
		ingame_name = "XM4",
		icon = "i_weapon_vm_ar_t9standard_wall_chalk_c",
		description = "Full-auto assault rifle"
	},
	["t9_streetsweeper"] = {
		ingame_name = "Streetsweeper",
		icon = "i_weapon_vm_sh_t9fullauto_wall_chalk_c",
		description = "Full-auto drum shotgun"
	},
	["s1_cel3"] = {
		ingame_name = "CEL-3 Cauterizer",
		icon = "i_weapon_vm_sh_t9fullauto_wall_chalk_c",   -- LOOKALIKE (reuses the Streetsweeper full-auto shotgun chalk; no CEL-3 art in the AW pack), user 2026-07-05
		description = "Triple-barrel spread shotgun"
	},
	["t6_chicom_cqb"] = {
		ingame_name = "Chicom CQB",
		icon = "i_t6_wpn_smg_chicom_wall_chalk_c",
		description = "3-round-burst SMG"
	},
	["s4_klauser"] = {
		ingame_name = "Klauser",
		icon = "i_t6_wpn_pistol_kard_wall_chalk_c",   -- LOOKALIKE (Kard chalk; no Klauser art in skye_s4_klauser.gdt)
		description = "Semi-automatic pistol"
	},
	["s1_mk14"] = {
		ingame_name = "MK14",
		icon = "i_t6_wpn_ar_m14_wall_chalk_c",   -- LOOKALIKE (BO2 M14 chalk)
		description = "Semi-auto battle rifle"
	},
	["s1_mors"] = {
		ingame_name = "MORS",
		icon = "i_t8_wpn_sniper_sdm_wall_chalk_c",   -- LOOKALIKE (SDM chalk; no MORS art)
		description = "Rail-charged sniper"
	},
	["t9_m60"] = {
		ingame_name = "M60",
		icon = "i_weapon_vm_lm_t9slowfire_wall_chalk_c",
		description = "Heavy LMG"
	},
	["t9_rpd"] = {
		ingame_name = "RPD",
		icon = "i_weapon_vm_lm_t9rpapa_wall_chalk_c",
		description = "Belt-fed LMG"
	},
	["t6_hamr"] = {
		ingame_name = "HAMR",
		icon = "i_t6_wpn_lmg_hamr_wall_chalk_c",   -- HAMR's own BO2 wall-chalk (skye_t6_hamr.gdt), zone-listed in the AETHERIUM block
		description = "High-capacity LMG"
	},
	["s1_rw1"] = {
		ingame_name = "RW1",
		icon = "i_t8_wpn_pistol_rk7_garrison_wall_chalk_c",   -- LOOKALIKE (RK7 chalk; no RW1 art)
		description = "Rail pistol"
	},
	["s1_mahem"] = {
		ingame_name = "MAHEM",
		icon = "t7_icon_weapon_launcher_standard_kf",   -- STOCK-NAME GUESS (no launcher chalk exists) - needs in-game verify
		description = "Guided launcher"
	},
	["t6_war_machine"] = {
		ingame_name = "War Machine",
		icon = "t7_icon_weapon_launcher_standard_kf",   -- same launcher icon as the Mahem (no GL chalk art exists)
		description = "Drum grenade launcher"
	},
	-- Apex Legends guns (user 2026-07-06 migration). LOOKALIKE chalk icons (Apex pack ships no 2D chalk art);
	-- all reuse icons from guns still in the roster (guaranteed packed). Keyed by the base _zm name.
	["apex_peacekeeper"] = {
		ingame_name = "Peacekeeper",
		icon = "i_weapon_vm_sh_t9fullauto_wall_chalk_c",   -- LOOKALIKE (Streetsweeper shotgun chalk)
		description = "Lever-action shotgun"
	},
	["apex_beam_rifle"] = {
		ingame_name = "Havoc",
		icon = "i_weapon_vm_ar_t9standard_wall_chalk_c",   -- LOOKALIKE (XM4 AR chalk)
		description = "Havoc energy rifle (1s charge-up)"
	},
	["apex_alternator"] = {
		ingame_name = "Alternator",
		icon = "i_weapon_vm_ar_t9standard_wall_chalk_c",   -- LOOKALIKE (XM4 chalk; SMG)
		description = "Full-auto SMG"
	},
	["apex_prowler"] = {
		ingame_name = "Prowler",
		icon = "i_weapon_vm_ar_t9standard_wall_chalk_c",   -- LOOKALIKE (XM4 chalk; burst PDW)
		description = "Burst PDW"
	},
	["t9_m16"] = {
		ingame_name = "M16",
		icon = "i_t6_wpn_ar_m14_wall_chalk_c",   -- LOOKALIKE (MK14 marksman chalk; M16 replaces the G7 Scout, 2026-07-11)
		description = "Burst tactical rifle"
	},
	["thundergun"] = {
		ingame_name = "Thundergun",
		icon = "i_wpn_t5_asl_thundergun_wall_chalk_c",
		description = "WHO'S NEXT?!"
	},
	-- New wonders (2026-07-07): no 2D chalk art ships in either pack -> blank icon (the
	-- ["default"] treatment) but a proper name + flavour line. Lookup strips _up/_zm forms.
	["elemental_bow_demongate"] = {
		ingame_name = "Fire Bow",
		icon = "blacktransparent",
		description = "Elemental fury of the demon gate"
	},
	["leviathan"] = {
		ingame_name = "Leviathan Axe",
		icon = "blacktransparent",
		description = "The frost of Midgard, thrown and returned"
	},
	-- t8_melee_figure (Action Figure) intentionally unmapped: no 2D art exists in its pack
	-- (hashed ximage_* textures only) -> falls to ["default"] blank + name text.

	-- Pistols
	["pistol_standard"] = {
		ingame_name = "WEAPON_PISTOL_STANDARD",
		icon = "t7_icon_weapon_pistol_standard_kf",
		description = "Semi-automatic pistol"
	},
	["pistol_standard_upgraded"] = {
		ingame_name = "WEAPON_PISTOL_STANDARD",
		icon = "t7_icon_weapon_pistol_standard_kf",
		description = "Semi-automatic pistol"
	},
	-- Equipment
	["frag_grenade"] = {
		ingame_name = "ZMWEAPON_M2FRAGGRENADE",
		icon = "i_mtl_sat_ui_icon_lethal_grenade_frag",
		description = "Lethal explosive device"
	},
	["cymbal_monkey"] = {
		ingame_name = "Cymbal Monkey",
		icon = "i_mtl_sat_ui_icon_zm_support_cymball_monkey",
		description = "Attracts zombies with music"
	},
	["octobomb"] = {
		ingame_name = "Li'l Arnie",
		icon = "i_mtl_hud_octobomb",
		description = "Li'l Arnie - Summons a tentacle beast"
	},
	-- Hero Weapons
	["hero_gravityspikes_melee"] = {
		ingame_name = "Ragnarok DG-4",
		icon = "t7_icon_weapon_hero_mercenary_pu",
		description = "WHAT GOES UP... MUST COME DOWN!"
	},
	-- Default Bo3 Mappings
	["zod_rocketshield"] = {
		ingame_name = "Rocket Shield",
		icon = "riotshield_zm_icon",
		description = "WHAT GOES UP... MUST COME DOWN!"
	},
	-- Default NO IMAGE / NO DESC entry
	["default"] = {
		icon = "blacktransparent",
		description = ""
	}
}