// =============================================================================
// _acc_boss_nameplate.csc - boss client FX pulses + 3D draw-name SUPPRESSOR
//
// THE 3D PLATE IS REMOVED (user 2026-07-25 "remove the 3D name plate all
// around. The only indicator will be the right side boss bar"): boss identity
// + health live SOLELY on the LUI CoD.AccBossBars rows (acc_hud.lua, fed by
// the accBoss1..5 controller UI-models from the .gsc half). History of the
// plate: ASCII text bar -> name-only -> styled chevrons + identity colors
// (all 2026-07-24) -> removed 2026-07-25 after the engine's hostile-name TINT
// (multiplies ^-colors through ~{1.0,0.6,0.45}; white->peach, blue->black)
// made true color-matching impossible. Restore any variant from git.
//
// WHY name_cb STILL CALLS SetDrawName: it renders the EMPTY string - a boss
// archetype may set its own floating name at spawn (the HB21 robot's csc sets
// "Civil Protector" - zm_zod_robot.csc:50), and without this stomp the Rogue
// Protector would show that pack name. The acc_bnp_name CF set at attach() is
// the trigger. Registrations MUST stay in gsc/csc lockstep (CF-layout safety);
// acc_bnp_hp stays SPARE (registered, never written).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "client_fx", "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p" );  // GUN muzzle flash
#precache( "client_fx", "electric/fx_elec_sparks_burst_xsm_omni_blue_os" );                // ZAP electric arc (small, one-shot)

#namespace acc_boss_nameplate;

REGISTER_SYSTEM( "acc_boss_nameplate", &__init__, undefined )

function __init__()
{
	clientfield::register( "actor", "acc_bnp_name", VERSION_SHIP, 3, "int", &name_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "acc_bnp_hp", VERSION_SHIP, 4, "int", &hp_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "acc_bnp_shot", VERSION_SHIP, 2, "int", &shot_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "acc_bnp_zap", VERSION_SHIP, 2, "int", &zap_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
	clientfield::register( "actor", "acc_bnp_mahem", VERSION_SHIP, 2, "int", &mahem_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// GUN shot pulse (server increments the counter per bullet): energy muzzle flash on the weapon-hand
// tag + the loaded NONLOOPING NPC energy-shot report, CLIENT-side (server-side PlayFX/PlaySound on
// actors is dead in this build - perk-glow precedent). self = the firing actor.
function shot_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;   // don't fire a phantom shot when the entity first snapshots in
	PlayFxOnTag( localClientNum, "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p", self, "tag_weapon_right" );
	// RW1 shot report (user 2026-07-04) - the 3D/NPC RW1 fire alias (skye_ports\s1_rw1\fire),
	// played ON the firing actor so it's positional at the boss. Already loaded (RW1 is a box gun).
	self PlaySound( localClientNum, "wpn_s1_rw1_shot_npc" );
}

// ZAP pulse (his SECOND attack): a SMALL blue electric arc at his gun hand (user 2026-07-03: the
// XLG burst on tag_origin "exploded on stun" - looked like a self-detonation; this small one-shot on
// the weapon tag reads as an electric discharge) + his own spark-burst report. The player-side 25%
// slow is applied server-side in _acc_civil_protector::zap_loop.
function zap_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;
	PlayFxOnTag( localClientNum, "electric/fx_elec_sparks_burst_xsm_omni_blue_os", self, "tag_weapon_right" );
	self PlaySound( localClientNum, "fly_bot_head_sparks_burst" );
}

// MAHEM big-explosive shot (his 5th shot): the mahem explosion report + a muzzle flash on the gun
// hand (reuses the loaded energy-shotgun muzzle FX; a dedicated explosion FX can be added once its
// asset is confirmed zoned). Sound = the 3D/NPC mahem explosion alias (s1_mahem is a box gun, loaded).
function mahem_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	if ( IS_TRUE( bInitialSnap ) )
		return;
	PlayFxOnTag( localClientNum, "_owens_effects/t9_semiauto_cosplay/fx_muz_energy_shotgun_3p", self, "tag_weapon_right" );
	self PlaySound( localClientNum, "wpn_s1_mahem_explosion_npc" );
}

// (name_for_index - the index->display-name table - REMOVED 2026-07-25 with the 3D
// plate; the .gsc name_to_index survives as the CF encoder and the LUI rows carry the
// name STRING in their payload. Restore from git with the plate if ever revived.)

// (bar_for_tenths / bnp_name_color / the styled ">> NAME <<" renderer - ALL REMOVED
// with the 3D plate, 2026-07-25. The LUI CoD.AccBossBars rows are the only boss
// indicator now. Restore from git if the plate is ever revived - and remember the
// engine hostile-name TINT that killed it: title ^-colors multiply through
// ~{1.0,0.6,0.45} on enemies, so white/grey/blue can never render true.)

// self == the boss actor (both callbacks). The plate is REMOVED - this callback's only
// job is to STOMP any archetype-set floating name (the HB21 robot csc names the Rogue
// Protector "Civil Protector" at spawn) the moment the server marks the boss (attach).
function name_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.acc_bnp_name_idx = newVal;   // kept for any future client consumer
	self SetDrawName( "" );
}

// acc_bnp_hp is SPARE (2026-07-24): registered for CF-layout lockstep, never written.
// Stored defensively; does not affect anything.
function hp_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.acc_bnp_hp = newVal;
}
