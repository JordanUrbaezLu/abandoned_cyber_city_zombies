// ============================================================================
// [acc] HarryBo21 Hero Weapons framework v2.0.0 (CLIENT) - VENDORED + ADAPTED
// (2026-07-24). MUST stay in lockstep with the .gsc twin's adaptation list:
//   1. Only Dragon Gauntlet + Skull modules #using'd (gravityspikes/glaive/
//      annihilator/margwa stripped - scriptmover + toplayer CF pools are FULL).
//   2. "hudItems.hero_weapon_icon" clientuimodel CF + the luiLoad of HB21's
//      D-pad widget STRIPPED (we don't ship that .lua; gsc setter also removed -
//      an asymmetric registration = fatal "Clientfield Mismatch" at load).
// ============================================================================
#using scripts\codescripts\struct;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;

// SPECIALISTS (ACC subset - see header)
#using scripts\zm\_zm_weap_dragon_gauntlet;
#using scripts\zm\_zm_weap_keeper_skull;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace hb21_zm_hero_weapon;

REGISTER_SYSTEM_EX( "hb21_zm_hero_weapon", &__init__, &__main__, undefined )

function __init__()
{
	// [acc] hero_weapon_icon CF + luiLoad stripped (header note 2).
}

function __main__()
{

}
