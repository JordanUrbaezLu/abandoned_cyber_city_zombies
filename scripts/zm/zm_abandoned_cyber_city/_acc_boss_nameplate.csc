// =============================================================================
// _acc_boss_nameplate.csc - 3D over-head boss nameplate + health bar (client half)
//
// Mirrors _acc_boss_nameplate.gsc's two actor clientfields and renders them via
// the engine's floating actor name: `self SetDrawName( <string>, true )` - the
// exact stock recipe from the Turned AAT (_zm_aat_turned.csc:38, an actor NOT
// on the players' team) and the HB21 pack's ally robot (zm_zod_robot.csc).
// Re-calling SetDrawName re-renders the string, so pushing a new hp value
// redraws the bar live: `ROGUE PROTECTOR [|||||||---]`.
//
// NAME INDICES MUST MATCH _acc_boss_nameplate.gsc name_to_index(). 0 = clear.
// The boss's own archetype may set a name at spawn (the robot's csc sets
// "Civil Protector") - our callback simply overwrites it.
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

function name_for_index( idx )
{
	switch ( idx )
	{
		case 1: return "PHANTOM";
		case 2: return "PANZER";   // 2026-07-08: repurposed dead SUBROUTINE CORE slot (renamed from PANZER SOLDAT same day) - MUST match _acc_boss_nameplate.gsc name_to_index
		case 3: return "TRENCH WARDEN";
		case 4: return "GLITCH STALKER";
		case 5: return "ROGUE PROTECTOR";
		case 6: return "AVOGADRO";
		default: return "BOSS";
	}
}

// Prebuilt 0..10 bar string. (The 2026-07-03 two-row/25-segment/colored restyle was
// REVERTED same day - "looks worse" in the engine's draw-name renderer; this single-row
// 10-segment format is the user-approved look.)
function bar_for_tenths( tenths )
{
	fill = "";
	for ( i = 0; i < tenths; i++ )
		fill = fill + "|";
	rest = "";
	for ( i = tenths; i < 10; i++ )
		rest = rest + "-";
	return "^1[" + fill + "^7" + rest + "^1]";
}

// self == the boss actor (both callbacks).
function name_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.acc_bnp_name_idx = newVal;
	redraw();
}

function hp_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
	self.acc_bnp_hp = newVal;
	redraw();
}

function redraw()
{
	idx = ( isdefined( self.acc_bnp_name_idx ) ? self.acc_bnp_name_idx : 0 );
	if ( idx == 0 )
	{
		self SetDrawName( "" );
		return;
	}
	hp = ( isdefined( self.acc_bnp_hp ) ? self.acc_bnp_hp : 10 );
	self SetDrawName( "^7" + name_for_index( idx ) + " " + bar_for_tenths( hp ), true );
}
