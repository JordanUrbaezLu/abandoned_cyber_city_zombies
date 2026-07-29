// ============================================================================
// [acc] HarryBo21 Hero Weapons framework v2.0.0 - VENDORED + ADAPTED (2026-07-24).
// Source: hb21_specialist_weapons_v2.0.0.rar (game-rip pack, install-side; see
// tools/external_assets_manifest.ps1 + CREDITS.md "HarryBo21 Hero Weapons").
// ACC adaptations vs the shipped file (keep this list in sync with the .csc twin):
//   1. ONLY the Dragon Gauntlet + Skull of Nan Sapwe modules are #using'd.
//      Annihilator / Gravity Spikes / Glaive (+ margwa) are STRIPPED - gravityspikes
//      wants 5 scriptmover bits and glaive 3 toplayer bits and BOTH pools are FULL
//      (memories scriptmover-clientfield-pool-full / toplayer-clientfield-pool-full;
//      registering them = silent varying-point load crash). Do NOT re-add a module
//      here without paying its clientfield bill first.
//   2. The "hudItems.hero_weapon_icon" clientuimodel CF + its set are STRIPPED
//      (we don't ship HB21's D-pad LUI widget; the Aetherium HUD has no hero icon
//      slot yet - follow-up if wanted). get_index() kept for reference.
//   3. [acc] box-grab enhancer added: stock _zm_magicbox.gsc ALREADY routes hero
//      weapons through its own give_hero_weapon (line ~1951, verified vs
//      tmp/bo3_stock_ref) but does NOT drop a previously-held hero or arm the
//      gadget state machine. acc_hero_box_grab_watch() finishes the job on the
//      stock "user_grabbed_weapon" notify (settle on the notify ARG - memory
//      box-grab-defer-weapon-reconcile). NO stock-script override needed.
// ============================================================================
#using scripts\codescripts\struct;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

// SPECIALISTS (ACC subset - see header note 1)
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_weap_dragon_gauntlet;
#using scripts\zm\_zm_weap_keeper_skull;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace hb21_zm_hero_weapon;

#precache( "fx", "zombie/fx_powerup_on_green_zmb" );

REGISTER_SYSTEM_EX( "hb21_zm_hero_weapon", &__init__, &__main__, undefined )

function __init__()
{
	// [acc] hero_weapon_icon clientuimodel CF stripped (header note 2).
	setup_hero_triggers();
}

function __main__()
{
	// [acc] box-grab enhancer (header note 3).
	callback::on_connect( &acc_on_connect_hero_box );
}

function acc_on_connect_hero_box()
{
	self thread acc_hero_box_grab_watch();
}

// [acc] Finish the stock box hero-give: drop any OLD hero weapon (stock weapon_give
// stacks a second one), then arm the gadget (state 2 = ready) + full power. The skull
// and gauntlet modules' own on_connect watchers take it from there.
function acc_hero_box_grab_watch()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "user_grabbed_weapon", w_grabbed );
		if ( !isdefined( w_grabbed ) || w_grabbed == level.weaponNone )
			continue;
		if ( !zm_utility::is_hero_weapon( w_grabbed ) )
			continue;

		// Drop any other hero still in the inventory (stock give doesn't).
		a_weapons = self getWeaponsList();
		for ( i = 0; i < a_weapons.size; i++ )
		{
			w = a_weapons[ i ];
			if ( isdefined( w ) && w != w_grabbed && zm_utility::is_hero_weapon( w ) )
			{
				self zm_hero_weapon::set_hero_weapon_state( w, 0 );
				self takeWeapon( w );
			}
		}

		self zm_utility::set_player_hero_weapon( w_grabbed );
		self zm_hero_weapon::set_hero_weapon_state( w_grabbed, 2 );
		self gadgetPowerSet( 0, 100 );
	}
}

function setup_hero_triggers()
{
	a_triggers = getEntArray( "hb21_hero_weapons", "targetname" );
	if ( !isDefined( a_triggers ) || a_triggers.size < 1 )
		return;

	for ( i = 0; i < a_triggers.size; i++ )
		a_triggers[ i ] thread hero_weapon_trigger( getWeapon( a_triggers[ i ].script_string ) );

}

function hero_weapon_trigger( w_weapon )
{
	n_lua_index = get_index( w_weapon.name );

	self setHintstring( "Press & hold ^3&&1^7 for " + makeLocalizedString( w_weapon.displayname ) );

	s_struct = struct::get( self.target, "targetname" );
	e_model = util::spawn_model( getWeaponWorldModel( w_weapon ), s_struct.origin, s_struct.angles );
	e_model thread hero_wobble();

	while ( 1 )
	{
		self waittill( "trigger", e_player );

		if ( IS_TRUE( e_player.hero_taking ) )
			continue;

		if ( e_player hasWeapon( w_weapon ) )
			continue;

		e_player thread give_hero_weapon( w_weapon, n_lua_index );
	}
}

function get_index( str_weapon )
{
	switch ( str_weapon )
	{
		case "hero_gravityspikes_melee" :
			return 1;
		case "skull_gun" :
			return 2;
		case "dragon_gauntlet_flamethrower" :
			return 3;
		default :
			return 0;

	}
}

function give_hero_weapon( w_weapon, n_lua_index )
{
	if ( IS_TRUE( self.hero_taking ) )
		return;

	if ( self hasWeapon( w_weapon ) )
		return;

	n_lua_index = get_index( w_weapon.name );

	self thread hero_weapon_trigger_failsafe();
	w_old_hero = self zm_utility::get_player_hero_weapon();
	if ( isDefined( w_old_hero ) && w_old_hero != level.weaponNone )
	{
		self zm_hero_weapon::set_hero_weapon_state( w_old_hero, 0 );
		self takeWeapon( w_old_hero );
		self zm_utility::set_player_hero_weapon( undefined );
	}

	// [acc] hero_weapon_icon uimodel set stripped (unregistered = script error).
	w_previous = self getCurrentWeapon();
	self zm_weapons::weapon_give( w_weapon );
	self gadgetPowerSet( 0, 99 );
	self switchToWeapon( w_weapon );
	self waittill( "weapon_change_complete" );
	self setLowReady( 1 );
	self switchToWeapon( w_previous );
	self util::waittill_any_timeout( 1.0, "weapon_change_complete" );
	self setLowReady( 0 );
	self gadgetPowerSet( 0, 100 );
	self zm_hero_weapon::set_hero_weapon_state( w_weapon, 2 );
	self notify( "hero_weapon_change_complete" );
}

function hero_weapon_trigger_failsafe()
{
	self endon( "disconnect" );
	self.hero_taking = 1;
	self util::waittill_any( "player_downed", "death", "hero_weapon_change_complete", "disconnect" );
	self.hero_taking = 0;
}

function hero_wobble()
{
	playFxOnTag( "zombie/fx_powerup_on_green_zmb", self, "tag_weapon" );

	while ( isdefined( self ) )
	{
		n_wait_time = randomFloatRange( 2.5, 5 );
		n_yaw = randomInt( 360 );
		if ( n_yaw > 300 )
			n_yaw = 300;
		else if ( n_yaw < 60 )
			n_yaw = 60;

		n_yaw = self.angles[ 1 ] + n_yaw;
		n_new_angles = ( -60 + randomint( 120 ), n_yaw, -45 + randomInt( 90 ) );
		self rotateTo( n_new_angles, n_wait_time, n_wait_time * .5, n_wait_time * .5 );
		wait randomFloat( n_wait_time - .1 );
	}
}
