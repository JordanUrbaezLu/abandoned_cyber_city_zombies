// [acc] VENDORED VERBATIM from HarryBo21 Hero Weapons v2.0.0 (2026-07-24; game-rip pack,
// see CREDITS.md). Dragon Gauntlet of Siegfried server logic. Registers ZERO clientfields
// (pool-safe). Needs: nav_volume in the .map (whelp flight) + vehicle,spawner_bo3_dragon_whelp
// + _dragon_whelp gsc/csc zone lines. Weapon names: dragon_gauntlet_flamethrower / dragon_gauntlet.
#using scripts\shared\abilities\_ability_player;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\throttle_shared;
#using scripts\shared\util_shared;
#using scripts\shared\vehicle_shared;
#using scripts\shared\vehicles\_dragon_whelp;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "model", 	"wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_world" );
#precache( "model", 	"wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_upg_world" );
#precache( "fx", 	"dlc3/stalingrad/fx_fire_generic_zmb_green" );
#precache( "fx", 	"dlc3/stalingrad/fx_fire_torso_zmb_green" );

#namespace zm_weap_dragon_gauntlet;

REGISTER_SYSTEM_EX( "zm_weap_dragon_gauntlet", &__init__, undefined, undefined)

function __init__()
{
	level.w_dragon_gauntlet_flamethrower = getWeapon( "dragon_gauntlet_flamethrower" );
	level.w_dragon_gauntlet = getWeapon( "dragon_gauntlet" );
	zm_hero_weapon::register_hero_recharge_event( level.w_dragon_gauntlet_flamethrower, &dragon_gauntlet_power_override );
	zm_hero_weapon::register_hero_recharge_event( level.w_dragon_gauntlet, &dragon_gauntlet_power_override );
	callback::on_connect( &on_connect_dragon_gauntlet );
	callback::on_player_killed( &on_player_killed_dragon_gauntlet );
	zm_hero_weapon::register_hero_weapon( "dragon_gauntlet_flamethrower" );
	zm_hero_weapon::register_hero_weapon_wield_unwield_callbacks( "dragon_gauntlet_flamethrower", &wield_dragon_gauntlet_flamethrower, &unwield_dragon_gauntlet_flamethrower );
	zm_hero_weapon::register_hero_weapon_power_callbacks( "dragon_gauntlet_flamethrower", &dragon_gauntlet_power_full, &dragon_gauntlet_power_expired );
	zm_hero_weapon::register_hero_weapon( "dragon_gauntlet" );
	zm_hero_weapon::register_hero_weapon_wield_unwield_callbacks( "dragon_gauntlet", &wield_dragon_gauntlet, &unwield_dragon_gauntlet );
	zm_hero_weapon::register_hero_weapon_power_callbacks( "dragon_gauntlet", &dragon_gauntlet_power_full, &dragon_gauntlet_power_expired );
	zm::register_actor_damage_callback( &dragon_gauntlet_actor_damage_callback );
	object = new throttle();
	[ [ object ] ]->__constructor();
	level.ai_gauntlet_chop_throttle = object;
	[ [ level.ai_gauntlet_chop_throttle ] ]->initialize( 6, .05 );
}

function private on_connect_dragon_gauntlet()
{
	self endon( "disconnect" );
	self endon( "bled_out" );
	self endon( "death" );
	self endon( "dragon_gauntlet_ran_out" );
	self dragon_gauntlet_can_charge( 0 );
	self.w_dragon_gauntlet_flamethrower = level.w_dragon_gauntlet_flamethrower;
	self.w_dragon_gauntlet = level.w_dragon_gauntlet;
	self.str_dragon_spawner = "spawner_bo3_dragon_whelp";
	self.dragon_gauntlet_flamethrower_showed_hint_count = 0;
	self.dragon_gauntlet_showed_hint_count = 0;
	if ( isDefined( self.b_player_has_whelp ) && self.b_player_has_whelp )
		self.b_player_has_whelp = 0;
	
	if ( isDefined( self.vh_dragon ) )
		self kill_player_whelp();
	do
	{
		self waittill( "new_hero_weapon", weapon );
	}
	while ( weapon != self.w_dragon_gauntlet_flamethrower );
	
	self setWeaponAmmoClip( self.w_dragon_gauntlet_flamethrower, self.w_dragon_gauntlet_flamethrower.clipsize );
	self gadgetPowerSet( 0, 100 );
	
	self thread weapon_change_watcher();
}

function reset_after_bleeding_out()
{
	self endon( "disconnect" );
	self waittill( "spawned_player" );
	self on_player_killed_dragon_gauntlet();
	self thread on_connect_dragon_gauntlet();
}

function on_player_killed_dragon_gauntlet()
{
	player = self;
	if ( IS_TRUE( player.b_player_has_whelp ) )
		player thread kill_player_whelp();
	
}

function give_dragon_gauntlet()
{
	player = self;
	player zm_weapons::weapon_give( self.w_dragon_gauntlet_flamethrower, 0, 1 );
	player thread zm_equipment::show_hint_text( "Press ^3[{+ability}]^7 to activate Gauntlet of Siegfried", 3 );
	player.dragon_power = 100;
	player.hero_power = 100;
	player gadgetPowerSet( 0, 100 );
	player zm_hero_weapon::set_hero_weapon_state( self.w_dragon_gauntlet_flamethrower, 2 );
	player setWeaponAmmoClip( self.w_dragon_gauntlet_flamethrower, self.w_dragon_gauntlet_flamethrower.clipsize );
	player.dragon_gauntlet_charged = 1;
}

function dragon_gauntlet_can_charge( b_no_dragon_charging )
{
	self.b_no_dragon_charging = b_no_dragon_charging;
}

function wield_dragon_gauntlet_flamethrower( w_dragon_gauntlet_flamethrower )
{
	if ( IS_TRUE( self.b_player_has_whelp ) )
		self kill_player_whelp();
	
	/*
	if ( !IS_TRUE( self.var_d0827e15 ) )
	{
		self.var_d0827e15 = 1;
		self zm_audio::create_and_play_dialog( "whelp", "aquire" );
	}
	*/
	self zm_hero_weapon::default_wield( w_dragon_gauntlet_flamethrower );
	self dragon_gauntlet_can_charge( 3 );
	self setWeaponAmmoClip( w_dragon_gauntlet_flamethrower, w_dragon_gauntlet_flamethrower.clipsize );
	self.dragon_power = self gadgetPowerGet( 0 );
	self.hero_power = self gadgetPowerGet( 0 );
	self disableOffhandWeapons();
	if ( isDefined( self.dragon_power ) )
		self gadgetPowerSet( 0, self.dragon_power );
	
	self.hero_power = self gadgetPowerGet( 0 );
	self notify( "stop_draining_hero_weapon" );
	if ( !isDefined( self.dragon_gauntlet_flamethrower_showed_hint_count ) || self.dragon_gauntlet_flamethrower_showed_hint_count < 3 )
	{
		self thread zm_equipment::show_hint_text( "^3[{+attack}]^7 Flamethrower", 3 );
		self.dragon_gauntlet_flamethrower_showed_hint_count = self.dragon_gauntlet_flamethrower_showed_hint_count + 1;
	}
	self thread zm_hero_weapon::continue_draining_hero_weapon( self.w_dragon_gauntlet_flamethrower );
	self.dragon_whelp_release_cooldown = getTime() + 1000;
	self thread dragon_gauntlet_release_whelp_watcher();
	self thread dragon_gauntlet_laststand_watcher( w_dragon_gauntlet_flamethrower );
	// self thread watch_for_loss( level.w_dragon_gauntlet, level.w_dragon_gauntlet_flamethrower );
}

function watch_for_loss( w_weapon, w_weapon2, whelp )
{
	self notify( "dragon_gauntet_watch_for_loss" );
	self endon( "dragon_gauntet_watch_for_loss" );
	self endon( "disconnect" );
	whelp endon( "whelp_recalled" );
	while ( self hasWeapon( w_weapon ) || self hasWeapon( w_weapon2 ) )
		WAIT_SERVER_FRAME;
	
	if ( isDefined( self.vh_dragon ) )
		self thread kill_player_whelp();
	
}

function unwield_dragon_gauntlet_flamethrower( w_dragon_gauntlet_flamethrower )
{
	self notify( "dragon_gauntlet_flamethrower_ended" );
	self.dragon_power = self gadgetPowerGet( 0 );
	self.hero_power = self gadgetPowerGet( 0 );
	self zm_hero_weapon::default_unwield( w_dragon_gauntlet_flamethrower );
	self dragon_gauntlet_can_charge( 1 );
	self notify( "stop_draining_hero_weapon" );
	self enableOffhandWeapons();
	if ( zm_weapons::has_weapon_or_attachments( w_dragon_gauntlet_flamethrower ) )
		self setWeaponAmmoClip( w_dragon_gauntlet_flamethrower, 0 );
	
}

function wield_dragon_gauntlet( w_dragon_gauntlet )
{
	self zm_hero_weapon::default_wield( w_dragon_gauntlet );
	self dragon_gauntlet_can_charge( 3 );
	self setWeaponAmmoClip( w_dragon_gauntlet, w_dragon_gauntlet.clipsize );
	self.dragon_power = self gadgetPowerGet( 0 );
	self.hero_power = self gadgetPowerGet( 0 );
	self disableOffhandWeapons();
	if ( isDefined( self.dragon_power ) )
		self gadgetPowerSet( 0, self.dragon_power );
	
	if ( !isDefined( self.dragon_gauntlet_showed_hint_count ) || self.dragon_gauntlet_showed_hint_count < 3 )
	{
		self thread zm_equipment::show_hint_text( "^3[{+attack}]^7 or ^3[{+melee}]^7 115 Punch", 3 );
		self.dragon_gauntlet_showed_hint_count = self.dragon_gauntlet_showed_hint_count + 1;
	}
	self.hero_power = self gadgetPowerGet( 0 );
	self notify( "stop_draining_hero_weapon" );
	self thread zm_hero_weapon::continue_draining_hero_weapon( self.w_dragon_gauntlet );
	self thread dragon_gauntlet_recall_whelp_watcher();
	self thread dragon_gauntlet_melee_watcher();
	self thread dragon_gauntlet_melee_juke_watcher();
	self thread dragon_gauntlet_laststand_watcher( w_dragon_gauntlet );
	// self thread watch_for_loss( level.w_dragon_gauntlet, level.w_dragon_gauntlet_flamethrower );
}

function unwield_dragon_gauntlet( w_dragon_gauntlet )
{
	self notify( "dragon_gauntlet_ended" );
	self.dragon_power = self gadgetPowerGet( 0 );
	self.hero_power = self gadgetPowerGet( 0 );
	self zm_hero_weapon::default_unwield( w_dragon_gauntlet );
	self dragon_gauntlet_can_charge( 1 );
	self enableOffhandWeapons();
	if ( zm_weapons::has_weapon_or_attachments( w_dragon_gauntlet ) )
		self setWeaponAmmoClip( w_dragon_gauntlet, 0 );
	
	self notify( "stop_draining_hero_weapon" );
	if ( self zm_weapons::has_weapon_or_attachments( w_dragon_gauntlet ) )
		self setWeaponAmmoClip( w_dragon_gauntlet, 0 );
	
	if ( IS_TRUE( self.b_player_has_whelp ) )
	{
		self thread zm_hero_weapon::continue_draining_hero_weapon( self.w_dragon_gauntlet );
		self thread zm_hero_weapon::continue_draining_hero_weapon( self.w_dragon_gauntlet_flamethrower );
	}
}

function weapon_change_watcher()
{
	self endon( "disconnect" );
	self.e_dragon_gauntlet_sleeve = undefined;
	while ( 1 )
	{
		self waittill( "weapon_change", w_current, w_previous );
		if ( w_current === level.w_dragon_gauntlet_flamethrower )
		{
			if ( self.e_dragon_gauntlet_sleeve === "wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_upg_world" )
				self detach( self.e_dragon_gauntlet_sleeve, "j_elbow_ri" );
			
			self.e_dragon_gauntlet_sleeve = "wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_world";
			self attach( self.e_dragon_gauntlet_sleeve, "j_elbow_ri" );
		}
		else if ( w_current === level.w_dragon_gauntlet )
		{
			if ( self.e_dragon_gauntlet_sleeve === "wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_world" )
				self detach( self.e_dragon_gauntlet_sleeve, "j_elbow_ri" );
			
			self.e_dragon_gauntlet_sleeve = "wpn_t7_zmb_dlc3_gauntlet_dragon_elbow_upg_world";
			self attach( self.e_dragon_gauntlet_sleeve, "j_elbow_ri" );
		}
		else if ( isDefined( self.e_dragon_gauntlet_sleeve ) )
		{
			self detach( self.e_dragon_gauntlet_sleeve, "j_elbow_ri" );
			self.e_dragon_gauntlet_sleeve = undefined;
		}
		if ( isDefined( w_previous ) && w_previous.name !== "none" && zm_utility::is_hero_weapon( w_current ) && !zm_utility::is_hero_weapon( w_previous ) )
			self.dragon_prev_weapon = w_previous;
		
	}
}

function dragon_gauntlet_laststand_watcher( weapon )
{
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "disconnect" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "stop_draining_hero_weapon" );
	// self endon( "hash_9b74f71e" );
	self notify( "dragon_gauntlet_laststand_watcher" );
	self endon( "dragon_gauntlet_laststand_watcher" );
	while ( 1 )
	{
		if ( !self laststand::player_is_in_laststand() )
		{
			if ( IS_TRUE( self.dragon_gauntlet_available ) && self.hero_power < 98 )
			{
				self.hero_power = 98;
				self gadgetPowerSet( 0, 98 );
				self.hero_power = 98;
				self.dragon_power = 98;
			}
			self setWeaponAmmoClip( weapon, weapon.clipsize );
		}
		wait 1;
	}
}

function dragon_gauntlet_release_whelp_watcher()
{
	self endon( "disconnect" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "player_whelp_released" );
	self notify( "dragon_gauntlet_release_whelp_watcher" );
	self endon( "dragon_gauntlet_release_whelp_watcher" );
	while ( self adsButtonPressed() )
		wait .05;
	
	while ( !( isDefined( self.b_player_has_whelp ) && self.b_player_has_whelp ) )
	{
		time = getTime();
		if ( isDefined( self.dragon_whelp_release_cooldown ) && time < self.dragon_whelp_release_cooldown )
		{
			wait .05;
			continue;
		}
		if ( self gadgetPowerGet( 0 ) <= 3 )
		{
			wait .05;
			continue;
		}
		if ( self adsButtonPressed() && self getCurrentWeapon() === self.w_dragon_gauntlet_flamethrower )
		{
			self disableWeaponCycling();
			self dragon_gauntlet_spawn_whelp();
			self thread watch_for_loss( level.w_dragon_gauntlet, level.w_dragon_gauntlet_flamethrower, self.vh_dragon );
			self.dragon_power = self gadgetPowerGet( 0 );
			self switchToWeapon( self.w_dragon_gauntlet );
			while ( self getCurrentWeapon() !== self.w_dragon_gauntlet )
				wait .05;
			
			self enableWeaponCycling();
			level notify( "whelp_released", self );
			self notify( "player_whelp_released" );
		}
		wait .05;
	}
}

function is_in_array( item, array )
{
	if ( isDefined( array ) )
	{
		foreach ( key, index in array )
		{
			if ( index == item )
				return 1;
			
		}
	}
	return 0;
}

function dragon_gauntlet_recall_whelp_watcher()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "whelp_recalled" );
	while ( self adsButtonPressed() )
	{
		/*
		if ( ( isDefined( level.var_163a43e4 ) && is_in_array( self, level.var_163a43e4 ) ) )
		{
			continue;
		}
		*/
		wait .05;
	}
	while ( 1 )
	{
		time = getTime();
		if ( IS_TRUE( self.dragon_whelp_recall_cooldown ) )
		{
			wait .05;
			continue;
		}
		if ( self gadgetPowerGet( 0 ) <= 3 )
		{
			wait .05;
			continue;
		}
		if ( self adsButtonPressed() && self getCurrentWeapon() === self.w_dragon_gauntlet || !isAlive( self.vh_dragon ) )
		{
			self disableWeaponCycling();
			self kill_player_whelp();
			self.dragon_power = self gadgetPowerGet( 0 );
			self switchToWeapon( self.w_dragon_gauntlet_flamethrower );
			while ( self getCurrentWeapon() !== self.w_dragon_gauntlet_flamethrower )
				wait .05;
			
			self enableWeaponCycling();
			self notify( "whelp_recalled" );
		}
		wait .05;
	}
}

function dragon_gauntlet_melee_watcher()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "dragon_gauntlet_flamethrower_ended" );
	self endon( "dragon_gauntlet_ended" );
	self endon( "whelp_recalled" );
	self notify( "dragon_gauntlet_melee_watcher" );
	self endon( "dragon_gauntlet_melee_watcher" );
	while ( 1 )
	{
		self util::waittill_any( "weapon_melee", "weapon_melee_power" );
		source_origin = self getTagOrigin( "tag_weapon_right" );
		physicsExplosionCylinder( source_origin, 96, 48, 1.5 );
		self thread dragon_gauntlet_melee_attack( source_origin, 128 );
		wait .05;
	}
}

function dragon_gauntlet_melee_juke_watcher()
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "dragon_gauntlet_flamethrower_ended" );
	self endon( "dragon_gauntlet_ended" );
	self endon( "whelp_recalled" );
	self notify( "dragon_gauntlet_melee_juke_watcher" );
	self endon( "dragon_gauntlet_melee_juke_watcher" );
	for ( ;; )
	{
		self waittill( "weapon_melee_juke", weapon );
		if ( weapon === self.w_dragon_gauntlet )
		{
			self playSound( "zmb_rocketshield_start" );
			self dragon_gauntlet_melee_juke_attack( weapon );
			self playSound( "zmb_rocketshield_end" );
			self notify( "dragon_gauntlet_melee_juke" );
		}
	}
}

function dragon_gauntlet_melee_juke_attack( weapon )
{
	self endon( "disconnect" );
	self endon( "death" );
	self endon( "bled_out" );
	self endon( "dragon_gauntlet_ran_out" );
	self endon( "dragon_gauntlet_flamethrower_ended" );
	self endon( "dragon_gauntlet_ended" );
	self endon( "whelp_recalled" );
	self endon( "weapon_melee" );
	self endon( "weapon_melee_power" );
	self endon( "weapon_melee_charge" );
	self notify( "dragon_gauntlet_melee_juke_attack" );
	self endon( "dragon_gauntlet_melee_juke_attack" );
	start_time = getTime();
	while ( ( start_time + 1000 ) > getTime() )
	{
		self playRumbleOnEntity( "zod_shield_juke" );
		forward = anglesToForward( self getplayerangles() );
		velocity = self getVelocity();
		predicted_pos = self.origin + ( velocity * .1 );
		self thread dragon_gauntlet_melee_attack( predicted_pos, 96 );
		wait .1;
	}
}

function dragon_gauntlet_melee_attack( source_origin, radius )
{
	player = self;
	a_enemies_in_range = array::get_all_closest( source_origin, getAiTeamArray( level.zombie_team ), undefined, undefined, radius );
	if ( !isDefined( a_enemies_in_range ) || a_enemies_in_range.size <= 0 )
		return;
	
	foreach ( key, enemy in a_enemies_in_range )
	{
		if ( !isDefined( enemy ) || IS_TRUE( enemy.b_dragon_gauntlet_meleed ) )
			continue;
		
		range_sq = distanceSquared( enemy.origin, source_origin );
		radius_sq = radius * radius;
		enemy.b_dragon_gauntlet_meleed = 1;
		if ( range_sq > radius_sq )
			continue;
		
		[ [ level.ai_gauntlet_chop_throttle ] ]->waitInQueue( enemy );
		if ( isDefined( enemy ) && isAlive( enemy ) )
		{
			enemy doDamage( enemy.health + 6000, source_origin, player, undefined, undefined, "MOD_MELEE", 0, level.w_dragon_gauntlet );
			if ( isVehicle( enemy ) )
				continue;
			
			if ( enemy.health <= 0 )
			{
				n_random_x = randomFloatRange( -3, 3 );
				n_random_y = randomFloatRange( -3, 3 );
				player thread zm_audio::create_and_play_dialog( "whelp", "punch" );
				enemy startRagdoll( 1 );
				enemy launchRagdoll( 100 * ( vectorNormalize( ( enemy.origin - self.origin ) + ( n_random_x, n_random_y, 100 ) ) ), "torso_lower" );
			}
		}
	}
}

function dragon_gauntlet_power_override( e_player, ai_enemy )
{
	if ( e_player laststand::player_is_in_laststand() )
		return;
	
	if ( ai_enemy.damageweapon === level.w_dragon_gauntlet_flamethrower || ai_enemy.damageweapon === level.w_dragon_gauntlet )
		return;
	
	if ( IS_TRUE( e_player.b_player_has_whelp ) )
		return;
	
	if ( e_player.b_no_dragon_charging === 0 )
		return;
	
	if ( IS_TRUE( e_player.disable_hero_power_charging ) )
		return;
	
	e_player.dragon_power = e_player gadgetPowerGet( 0 );
	if ( isDefined( e_player ) && isDefined( e_player.dragon_power ) )
	{
		if ( isDefined( ai_enemy.heroweapon_kill_power ) )
		{
			n_perk_factor = 1;
			if ( e_player hasPerk( "specialty_overcharge" ) )
				n_perk_factor = getDvarFloat( "gadgetPowerOverchargePerkScoreFactor" );
			
			if ( isDefined( ai_enemy.damageweapon ) )
			{
				weapon = ai_enemy.damageweapon;
				if ( isSubStr( weapon.name, "elemental_bow_demongate" ) || isSubStr( weapon.name, "elemental_bow_run_prison" ) || isSubStr( weapon.name, "elemental_bow_storm" ) || isSubStr( weapon.name, "elemental_bow_wolf_howl" ) )
					n_perk_factor = .25;
				
			}
			e_player.dragon_power = e_player.dragon_power + ( n_perk_factor * ai_enemy.heroweapon_kill_power );
			e_player.dragon_power = math::clamp( e_player.dragon_power, 0, 100 );
			if ( e_player.dragon_power >= e_player.hero_power_prev )
			{
				e_player gadgetPowerSet( 0, e_player.dragon_power );
				e_player clientfield::set_player_uimodel( "zmhud.swordEnergy", e_player.dragon_power / 100 );
				e_player clientfield::increment_uimodel( "zmhud.swordChargeUpdate" );
			}
		}
	}
}

function dragon_gauntlet_power_expired( weapon )
{
	self zm_hero_weapon::default_power_empty( weapon );
	self notify( "stop_draining_hero_weapon" );
	self notify( "dragon_gauntlet_ran_out" );
	self.dragon_power = 0;
	self.hero_power = 0;
	if ( IS_TRUE( self.b_player_has_whelp ) )
		self kill_player_whelp();
	
	current_weapon = self getCurrentWeapon();
	if ( self hasWeapon( weapon ) && current_weapon === weapon )
		self setWeaponAmmoClip( weapon, 0 );
	
	if ( current_weapon === self.w_dragon_gauntlet_flamethrower || current_weapon === self.w_dragon_gauntlet )
	{
		if ( isDefined( self.dragon_prev_weapon ) && !isSubStr( self.dragon_prev_weapon.name, "minigun" ) )
			self switchToWeapon( self.dragon_prev_weapon );
		else
			self zm_weapons::switch_back_primary_weapon();
		
	}
}

function dragon_gauntlet_power_full( weapon )
{
	self thread zm_equipment::show_hint_text( "Press ^3[{+ability}]^7 to activate Gauntlet of Siegfried", 3 );
	self zm_hero_weapon::set_hero_weapon_state( weapon, 2 );
	self dragon_gauntlet_can_charge( 2 );
	self setWeaponAmmoClip( weapon, weapon.clipsize );
	if ( !IS_TRUE( self.dragon_gauntlet_charged ) )
		self thread zm_audio::create_and_play_dialog( "whelp", "ready" );
	
	self.dragon_gauntlet_charged = 0;
}

function dragon_gauntlet_spawn_whelp()
{
	if ( IS_TRUE( self.b_player_has_whelp ) || isDefined( self.vh_dragon ) )
		return;
	
	self.b_player_has_whelp = 1;
	spawn_pos = self getTagOrigin( "tag_dragon_world" );
	spawn_angles = self getTagAngles( "tag_dragon_world" );
	vh_whelp = spawnVehicle( self.str_dragon_spawner, spawn_pos, spawn_angles );
	if ( isDefined( vh_whelp ) )
	{
		self.vh_dragon = vh_whelp;
		vh_whelp ai::set_ignoreme( 1 );
		vh_whelp setIgnorePauseWorld( 1 );
		vh_whelp.owner = self;
		self thread zm_audio::create_and_play_dialog( "whelp", "command" );
		vh_whelp thread whelp_hide_pop();
		vh_whelp thread whelp_failsafe();
		self thread recall_whelp_on_laststand();
	}
	self.dragon_whelp_recall_cooldown = getTime() + 1000;
}

function whelp_hide_pop()
{
	self endon( "death" );
	self ghost();
	wait .15;
	self show();
}

function recall_whelp_on_laststand()
{
	self notify( "dragon_recall_death" );
	self endon( "dragon_recall_death" );
	self waittill( "entering_last_stand" );
	self thread kill_player_whelp();
}

function kill_player_whelp()
{
	self notify( "dragon_recall_death" );
	self.b_player_has_whelp = 0;
	if ( isDefined( self.vh_dragon ) )
	{
		vh_whelp = self.vh_dragon;
		vh_whelp notify( "dragon_recall_death" );
		vh_whelp.dragon_recall_death = 1;
		vh_whelp kill();
	}
}

function whelp_failsafe()
{
	while ( isDefined( self ) )
	{
		if ( !isDefined( self.owner ) || self.owner laststand::player_is_in_laststand() )
		{
			self.dragon_recall_death = 1;
			self kill();
		}
		wait .25;
	}
}

function dragon_gauntlet_actor_damage_callback( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, shitloc, psoffsettime, boneindex, surfacetype )
{
	if ( isDefined( attacker ) && isplayer( attacker ) )
	{
		if ( isDefined( weapon ) && weapon === level.w_dragon_gauntlet_flamethrower )
		{
			if ( meansofdeath === "MOD_BURNED" )
			{
				self.weapon_specific_fire_death_torso_fx = "dlc3/stalingrad/fx_fire_torso_zmb_green";
				self.weapon_specific_fire_death_sm_fx = "dlc3/stalingrad/fx_fire_generic_zmb_green";
				if ( self.archetype === "zombie" || ( isDefined( level.zombie_vars[ attacker.team ] ) && ( isDefined( level.zombie_vars[ attacker.team ][ "zombie_insta_kill" ] ) && level.zombie_vars[ attacker.team ][ "zombie_insta_kill" ] ) ) )
				{
					damage = self.health + 6000;
					attacker thread zm_audio::create_and_play_dialog( "whelp", "flamethrower_kill" );
					return damage;
				}
			}
			if ( meansofdeath === "MOD_MELEE" && ( !( isDefined( self.b_dragon_gauntlet_meleed ) && self.b_dragon_gauntlet_meleed ) ) )
			{
				damage = self.health + 6000;
				self.deathfunction = &zombie_killed_by_whelp;
				return damage;
			}
		}
		if ( isDefined( weapon ) && weapon === level.w_dragon_gauntlet )
		{
			if ( meansofdeath === "MOD_MELEE" && ( !( isDefined( self.b_dragon_gauntlet_meleed ) && self.b_dragon_gauntlet_meleed ) ) )
			{
				damage = self.health + 6000;
				self.deathfunction = &zombie_killed_by_gauntlet_melee;
				return damage;
			}
		}
	}
	return -1;
}

function zombie_killed_by_gauntlet_melee( einflictor, attacker, idamage, smeansofdeath, weapon, vdir, shitloc, psoffsettime )
{
	n_random_x = randomFloatRange( -3, 3 );
	n_random_y = randomFloatRange( -3, 3 );
	self startRagdoll( 1 );
	self launchRagdoll( 100 * ( vectorNormalize( ( self.origin - attacker.origin ) + ( n_random_x, n_random_y, 100 ) ) ), "torso_lower" );
}

function zombie_killed_by_whelp( einflictor, attacker, idamage, smeansofdeath, weapon, vdir, shitloc, psoffsettime )
{
	gibserverutils::gibhead( self );
	n_random_x = randomFloatRange( -3, 3 );
	n_random_y = randomFloatRange( -3, 3 );
	self startRagdoll( 1 );
	self launchRagdoll( 100 * ( vectorNormalize( ( self.origin - attacker.origin ) + ( n_random_x, n_random_y, 100 ) ) ), "torso_lower" );
}