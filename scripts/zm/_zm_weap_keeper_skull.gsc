// ============================================================================
// [acc] VENDORED + ADAPTED from HarryBo21 Hero Weapons v2.0.0 (2026-07-24; game-rip
// pack, CREDITS.md). Skull of Nan Sapwe server logic. ACC adaptations (LOCKSTEP with
// the .csc twin or the map dies with "Clientfield Mismatch"):
//   1. skull_beam_fx / skull_torch_fx moved "toplayer" -> "allplayers": the toplayer
//      CF pool is FULL (memory toplayer-clientfield-pool-full; +4 bits = silent load
//      crash). allplayers had only 2 registrations. Setters converted
//      set_to_player->set / get_to_player->get (fields live on the player ent).
//   2. "thrasher_skull_fire" actor CF registration DELETED (no thrashers on this
//      map; every call site is gated by IS_TRUE(b_is_thrasher) = dead code, and the
//      actor pool is tight - memory actor-clientfield-bit-budget).
// ============================================================================
#using scripts\codescripts\struct;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai_shared;
#using scripts\shared\animation_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\flagsys_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\zm\_util;
#using scripts\zm\_zm;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weap_annihilator;
#using scripts\zm\_zm_weapons;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace keeper_skull;

#using_animtree( "generic" );

REGISTER_SYSTEM_EX( "keeper_skull", &__init__, &__main__, undefined )

function __init__()
{
	clientfield::register( "allplayers", "skull_beam_fx", VERSION_SHIP, 2, "int" );   // [acc] toplayer pool full
	clientfield::register( "allplayers", "skull_torch_fx", VERSION_SHIP, 2, "int" );  // [acc] toplayer pool full
	clientfield::register( "allplayers", "skull_beam_3p_fx", VERSION_SHIP, 2, "int" );
	clientfield::register( "allplayers", "skull_torch_3p_fx", VERSION_SHIP, 2, "int" );
	clientfield::register( "allplayers", "skull_emissive", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "death_ray_shock_eye_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "entranced", VERSION_SHIP, 1, "int" );
	// [acc] thrasher_skull_fire actor CF deleted (no thrashers; call sites all b_is_thrasher-gated dead code)
	clientfield::register( "actor", "zombie_explode", VERSION_SHIP, 1, "int" );
	level.w_skull_gun = getWeapon( "skull_gun" );
	level.w_skull_gun_upg = getWeapon( "skull_gun_1" );
	zm_hero_weapon::register_hero_weapon( "skull_gun" );
	zm_hero_weapon::register_hero_weapon( "skull_gun_1" );
}

function __main__()
{
	callback::on_connect( &on_player_connect_skull );
}

function on_player_connect_skull()
{
	self flag::init( "has_skull" );
	self.skull_ammo = 100;
	self.b_skull_beam_active = 0;
	self.b_skull_torch_active = 0;
	self.b_skull_beam_ending = 0;
	self thread skull_beam_watcher();
	self thread skull_torch_watcher();
	self thread watch_weapon_change();
	self thread skull_fx_watcher();
	self thread skull_wield_watcher();
	self thread skull_full_charge_watcher();
	self thread skull_ammo_watcher();
	self thread watch_player_death();
}

function watch_player_death()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		self waittill( "bled_out" );
		if ( self flag::get( "has_skull" ) )
			self flag::clear( "has_skull" );
		
	}
}

function skull_ammo_watcher()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		if ( self hasWeapon( level.w_skull_gun ) )
		{
			self.skull_ammo = self gadgetPowerGet( 0 );
			if ( self.skull_ammo == 100 )
				self setWeaponAmmoClip( level.w_skull_gun, 100 );
			
		}
		wait .05;
	}
}

function skull_full_charge_watcher()
{
	self endon( "disconnect" );
	
	b_skull_charged = 1;
	while ( 1 )
	{
		n_skull_charge = self gadgetPowerGet( 0 );
		if ( n_skull_charge == 100 && b_skull_charged == 0 )
		{
			if ( !self laststand::player_is_in_laststand() )
			{
				self notify( "skull_weapon_fully_charged" );
				b_skull_charged = 1;
				wait 30 ;
			}
		}
		else if ( n_skull_charge < 100 )
			b_skull_charged = 0;
		
		wait 1;
	}
}

function skull_beam_watcher()
{
	self endon( "disconnect" );
	
	while ( 1 )
	{
		self util::waittill_attack_button_pressed();
		if ( self has_skull_gun() )
		{
			if ( !self.b_skull_beam_active && !self isMeleeing() )
			{
				self clientfield::set( "skull_beam_fx", 1 );
				self clientfield::set( "skull_beam_3p_fx", 1 );
				self skull_kill_zombies();
				while ( self util::attack_button_held() && self has_skull_gun() && !self.b_skull_beam_active && self.skull_ammo )
				{
					if ( !self.b_skull_beam_ending )
						self thread skull_beam_end_watcher();
					
					self skull_kill_zombies();
					wait .05;
				}
				self.b_skull_beam_ending = 0;
				self clientfield::set( "skull_beam_fx", 0 );
				self clientfield::set( "skull_beam_3p_fx", 0 );
			}
		}
		wait .05;
		self thread skull_reset_torch();
	}
}

function skull_beam_end_watcher()
{
	self endon( "disconnect" );
	self.b_skull_beam_ending = 1;
	wait .1;
	if ( self util::attack_button_held() && !self.b_skull_beam_active )
	{
		self clientfield::set( "skull_beam_fx", 2 );
		self clientfield::set( "skull_beam_3p_fx", 2 );
	}
}

function skull_kill_zombies()
{
	a_zombies = getAiTeamArray( level.zombie_team );
	a_targets = util::get_array_of_closest( self.origin, a_zombies, undefined, 8, 500 );
	for ( i = 0; i < a_targets.size; i++ )
	{
		if ( isAlive( a_targets[ i ] ) )
		{
			if ( a_targets[ i ].b_skull_beam_hit !== 1 && self skull_can_kill_zombie( a_targets[ i ] ) && ( !IS_TRUE( a_targets[ i ].thrasherconsumed ) ) )
			{
				a_targets[ i ].b_skull_beam_hit = 1;
				self thread skull_kill_zombie( a_targets[ i ] );
				wait .05;
			}
		}
	}
}

function skull_zombie_barrier_failsafe()
{
	self notify( "skull_zombie_barrier_failsafe" );
	self endon( "skull_zombie_barrier_failsafe" );
	self endon( "death" );
	if ( IS_TRUE( self.isinmantleaction ) )
		is_mantling = 1;
	
	wait .05;
	self waittill( "skull_beam_hit_ended" );
	if ( !( isDefined( is_mantling ) && is_mantling ) && !self zm::in_enabled_playable_area() )
	{
		if ( isDefined( self.chunk ) && isDefined( self.first_node.zbarrier ) )
		{
			if ( self.first_node.zbarrier getZbarrierPieceState( self.chunk ) == "opening" )
				self.first_node.zbarrier setZbarrierPieceState( self.chunk, "open" );
			else
				self.first_node.zbarrier setZbarrierPieceState( self.chunk, "closed" );
			
		}
	}
	else if ( isDefined( is_mantling ) && is_mantling && isDefined( self.first_node ) && isDefined( self.saved_attacking_spot_index ) )
	{
		forwardvec = anglestoforward( self.first_node.angles );
		correct_origin = self.first_node.attack_spots[ self.saved_attacking_spot_index ] + ( forwardvec * 75 );
		correct_origin = getClosestPointOnNavMesh( correct_origin );
		self forceTeleport( correct_origin, self getAngles() );
	}
}

function skull_kill_zombie( ai_zombie )
{
	self endon( "disconnect" );
	ai_zombie endon( "death" );
	if ( ai_zombie.archetype === "zombie" || IS_TRUE( ai_zombie.b_is_thrasher ) )
	{
		ai_zombie thread zombie_utility::zombie_eye_glow_stop();
		ai_zombie clientfield::set( "death_ray_shock_eye_fx", 1 );
		if ( isAlive( ai_zombie ) && !IS_TRUE( ai_zombie.b_is_thrasher ) )
		{
			if ( ai_zombie isPlayingAnimScripted() )
			{
				ai_zombie stopAnimScripted( .3 );
				wait .1;
			}
			ai_zombie thread scene::play( "cin_zm_dlc1_zombie_dth_deathray_04", ai_zombie );
			ai_zombie thread skull_zombie_barrier_failsafe();
		}
	}
	n_spores_hit = 0;
	while ( self util::attack_button_held() && self has_skull_gun() && !self.b_skull_beam_active && self.skull_ammo )
	{
		if ( IS_TRUE( ai_zombie.b_is_spider ) )
		{
			self skull_reduce_power( 1 );
			ai_zombie doDamage( ai_zombie.health, ai_zombie.origin, self );
			break;
		}
		ai_zombie.b_skull_beam_hit = 1;
		if ( ai_zombie.archetype === "zombie" || IS_TRUE( ai_zombie.b_is_thrasher ) )
		{
			ai_zombie thread zm_audio::zmbaivox_playvox( ai_zombie, "skull_scream", 1, 11 );
			wait 1;
		}
		else
			wait 3;
		
		if ( self util::attack_button_held() && self has_skull_gun() && !self.b_skull_beam_active && self.skull_ammo )
		{
			if ( ai_zombie.archetype === "zombie" )
			{
				ai_zombie clientfield::set( "death_ray_shock_eye_fx", 0 );
				self notify( "skullweapon_killed_zombie" );
				ai_zombie zombie_utility::zombie_head_gib( self );
				ai_zombie playSound( "evt_zombie_skull_breathe" );
			}
			wait .05;
			if ( IS_TRUE( ai_zombie.b_is_thrasher ) )
			{
				if ( n_spores_hit == 0 )
					ai_zombie clientfield::set( "thrasher_skull_fire", 1 );
				
				if ( n_spores_hit < ai_zombie.thrasherspores.size )
				{
					if ( !ai_zombie.thrasherisberserk )
						ai_zombie.thrasherragecount = 0;
					
					e_spore = ai_zombie.thrasherspores[ n_spores_hit ];
					self skull_reduce_power( 3 );
					ai_zombie doDamage( e_spore.health, ai_zombie gettagorigin( e_spore.tag ), self );
					n_spores_hit++;
					ai_zombie.thrasherragecount = 0;
				}
			}
			else
			{
				self skull_reduce_power( 2 );
				ai_zombie thread skull_zombie_explodes_intopieces();
				ai_zombie clientfield::set( "zombie_explode", 1 );
				ai_zombie doDamage( ai_zombie.health, ai_zombie.origin, self );
			}
		}
	}
	ai_zombie.b_skull_beam_hit = 0;
	if ( ai_zombie.archetype === "zombie" || IS_TRUE( ai_zombie.b_is_thrasher ) )
	{
		ai_zombie notify( "skull_beam_hit_ended" );
		ai_zombie thread scene::stop( "cin_zm_dlc1_zombie_dth_deathray_04" );
		ai_zombie thread zombie_utility::zombie_eye_glow();
		ai_zombie clientfield::set( "death_ray_shock_eye_fx", 0 );
		if ( isDefined( ai_zombie.b_is_thrasher ) && ai_zombie.b_is_thrasher )
			ai_zombie clientfield::set( "thrasher_skull_fire", 0 );
		
	}
}

function skull_zombie_explodes_intopieces()
{
	wait .05;
	if ( isDefined( self ) )
	{
		if ( math::cointoss() )
			gibserverutils::gibhead( self );
		
		if ( math::cointoss() )
			gibserverutils::gibleftarm( self );
		
		if ( math::cointoss() )
			gibserverutils::gibrightarm( self );
		
		if ( math::cointoss() )
			gibserverutils::giblegs( self );
		
		self zombie_utility::zombie_gut_explosion();
	}
}

function skull_torch_watcher()
{
	self endon( "disconnect" );
	
	while ( 1 )
	{
		if ( self util::ads_button_held() )
		{
			if ( !self has_skull_gun() )
			{
				while ( self adsButtonPressed() )
					wait .05;
				
			}
			else if ( self.skull_ammo && !self attackButtonPressed() && !self.b_skull_beam_active && !self isMeleeing() )
			{
				if ( !self.b_skull_torch_active )
				{
					self.b_skull_torch_active = 1;
					self clientfield::set( "skull_torch_fx", 1 );
					self clientfield::set( "skull_torch_3p_fx", 1 );
					self clientfield::set( "skull_emissive", 1 );
					self thread skull_torch_end_watcher();
				}
				a_zombies = getAiTeamArray( level.zombie_team );
				a_targets = util::get_array_of_closest( self.origin, a_zombies, undefined, undefined, 500 );
				foreach ( key, ai_zombie in a_targets )
				{
					if ( ai_zombie.b_skull_pacify_hit !== 1 && self skull_can_pacify_zombie( ai_zombie ) && ai_zombie.completed_emerging_into_playable_area === 1 && ( !( isDefined( ai_zombie.thrasherconsumed ) && ai_zombie.thrasherconsumed ) )  )
					{
						self thread skull_pacify_zombie( ai_zombie );
						self notify( "skullweapon_mesmerized_zombie" );
					}
				}
				wait .05;
			}
			else
			{
				self.b_skull_torch_active = 0;
				self clientfield::set( "skull_torch_fx", 0 );
				self clientfield::set( "skull_torch_3p_fx", 0 );
				self clientfield::set( "skull_emissive", 0 );
			}
		}
		else
		{
			self.b_skull_torch_active = 0;
			if ( self clientfield::get( "skull_torch_fx" ) )
				self clientfield::set( "skull_torch_fx", 0 );
			
			if ( self clientfield::get( "skull_torch_3p_fx" ) )
				self clientfield::set( "skull_torch_3p_fx", 0 );
			
			if ( self clientfield::get( "skull_emissive" ) )
				self clientfield::set( "skull_emissive", 0 );
			
		}
		wait .05;
	}
}

function skull_torch_end_watcher()
{
	self endon( "disconnect" );
	self endon( "weapon_change" );
	wait .1;
	if ( self util::ads_button_held() && !self.b_skull_beam_active )
	{
		self clientfield::set( "skull_torch_fx", 2 );
		self clientfield::set( "skull_torch_3p_fx", 2 );
	}
}

function skull_pacify_zombie( ai_zombie )
{
	self endon( "disconnect" );
	ai_zombie endon( "death" );
	while ( self util::ads_button_held() && self.skull_ammo && self skull_can_pacify_zombie( ai_zombie ) && !self.b_skull_beam_ending && self has_skull_gun() )
	{
		if ( ai_zombie.b_skull_pacify_hit !== 1 )
		{
			ai_zombie.b_skull_pacify_hit = 1;
			if ( !( isDefined( ai_zombie.b_is_spider ) && ai_zombie.b_is_spider ) )
			{
				ai_zombie thread zombie_utility::zombie_eye_glow_stop();
				ai_zombie clientfield::set( "entranced", 1 );
				ai_zombie thread skull_zombie_do_pacify_scene();
			}
			else
			{
				ai_zombie setGoal( ai_zombie.origin );
				ai_zombie ai::set_ignoreall( 1 );
			}
		}
		wait .05;
	}
	ai_zombie.b_skull_pacify_hit = 0;
	ai_zombie ai::set_ignoreall( 0 );
	if ( !( isDefined( ai_zombie.b_is_spider ) && ai_zombie.b_is_spider ) )
	{
		ai_zombie thread zombie_utility::zombie_eye_glow();
		ai_zombie clientfield::set( "entranced", 0 );
		ai_zombie notify( "skull_pacify_hit_ended" );
		if ( ai_zombie isPlayingAnimScripted() )
			ai_zombie stopAnimScripted( 0.3 );
		
	}	
}

function skull_zombie_do_pacify_scene()
{
	self endon( "death" );
	self endon( "skull_pacify_hit_ended" );
	n_index = randomIntRange( 1, 7 );
	while ( 1 )
	{
		self thread animation::play( "ai_zm_dlc2_zombie_pacified_by_skullgun_" + n_index, self );
		wait( getAnimLength( "ai_zm_dlc2_zombie_pacified_by_skullgun_" + n_index ) );
	}
}

function skull_can_pacify_zombie( ai_zombie )
{
	if ( distance2dSquared( self.origin, ai_zombie.origin ) <= 250000 )
		return 1;
	
	return 0;
}

function skull_can_kill_zombie( ai_zombie )
{
	ai_zombie endon( "death" );
	if ( self util::is_player_looking_at( ai_zombie.origin, .85, 0 ) )
		return 1;
	
	if ( self util::is_player_looking_at( ai_zombie getCentroid(), 0.85, 0 ) )
		return 1;
	
	return 0;
}
/*
function function_3f3f64e9( e_prop )
{
	if ( self util::is_player_looking_at( e_prop.origin, .85, 0 ) )
		return 1;
	
	if ( self util::is_player_looking_at( e_prop getCentroid(), 0.85, 0 ) )
		return 1;
	
	return 0;
}
*/
function skull_wield_watcher()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		if ( !self has_skull_gun() )
		{
			self waittill( "weapon_change" );
			if ( self.sessionstate != "spectator" )
			{
				w_current = self getCurrentWeapon();
				if ( isDefined( w_current ) && zm_utility::is_hero_weapon( w_current ) )
				{
					self.b_using_skull = 1;
					self thread skull_unwield_watcher();
					wait( 1 );
				}
			}
		}
		if ( self has_skull_gun() && ( isDefined( self.b_using_skull ) && self.b_using_skull ) )
		{
			if ( self.sessionstate != "spectator" )
			{
				self setWeaponAmmoClip( level.w_skull_gun, int( self.skull_ammo ) );
				if ( self util::ads_button_held() || self util::attack_button_held() )
				{
					if ( self.skull_ammo > 0 )
						self gadgetPowerSet( 0, self.skull_ammo - .15 );
					else
					{
						self gadgetPowerSet( 0, 0 );
						self setWeaponAmmoClip( level.w_skull_gun, 0 );
						self zm_weapons::switch_back_primary_weapon( undefined, 1 );
						self.b_using_skull = 0;
					}
				}
			}
		}
		wait .05;
	}
}

function skull_unwield_watcher()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		if ( self weaponSwitchButtonPressed() )
		{
			self.b_using_skull = 0;
			self gadgetPowerSet( 0, self.skull_ammo - 2 );
			self setWeaponAmmoClip( level.w_skull_gun, 0 );
			self gadgetDeactivate( 0, level.w_skull_gun );
			break;
		}
		wait .05;
	}
}

function has_skull_gun()
{
	w_current = self getCurrentWeapon();
	if ( w_current == level.w_skull_gun || w_current == level.w_skull_gun_upg )
		return 1;
	
	return 0;
}

function watch_weapon_change()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		if ( self weaponSwitchButtonPressed() || self.skull_ammo < 1 )
			self skull_reset_torch();
		
		wait .05;
	}
}

function skull_fx_watcher()
{
	self endon( "disconnect" );
	while ( 1 )
	{
		self waittill( "weapon_change_complete" );
		self skull_reset_torch();
	}
}

function skull_reset_torch()
{
	if ( self clientfield::get( "skull_beam_fx" ) )
		self clientfield::set( "skull_beam_fx", 0 );
	else if ( self clientfield::get( "skull_torch_fx" ) )
	{
		self clientfield::set( "skull_torch_fx", 0 );
		self clientfield::set( "skull_torch_3p_fx", 0 );
		self clientfield::set( "skull_emissive", 0 );
	}
	if ( self clientfield::get( "skull_beam_3p_fx" ) )
		self clientfield::set( "skull_beam_3p_fx", 0 );
	else if ( self clientfield::get( "skull_torch_3p_fx" ) )
		self clientfield::set( "skull_torch_3p_fx", 0 );
	
}

function skull_reduce_power( n_cost )
{
	if ( self.skull_ammo >= n_cost )
		self gadgetPowerSet( 0, self.skull_ammo - n_cost );
	else
	{
		self gadgetPowerSet( 0, 0 );
		self.b_using_skull = 0;
	}
}
