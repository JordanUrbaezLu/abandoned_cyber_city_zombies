#using scripts\codescripts\struct;

// AI
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_mocomp;
#using scripts\shared\ai\systems\animation_state_machine_notetracks;
#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#using scripts\shared\ai\systems\blackboard;
#using scripts\shared\ai\zombie_utility;

// Shared
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

// Zombie
#using scripts\zm\_util;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_net;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\shared\spawner_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#insert scripts\zm\_zm_weap_freezegun.gsh;

// TO DO LIST

#precache( "fx", FX_FREEZEGUN_SHATTER );
#precache( "fx", FX_FREEZEGUN_CRUMPLE );
#precache( "fx", FX_FREEZEGUN_SMOKE_CLOUD );
#precache( "fx", FX_FREEZEGUN_FREEZE_TORSO );
#precache( "fx", FX_FREEZEGUN_FREEZE_MD );
#precache( "fx", FX_FREEZEGUN_SHATTER_UPGRADED );
#precache( "fx", FX_FREEZEGUN_CRUMPLE_UPGRADED );
#precache( "fx", FX_FREEZEGUN_SHATTER_GIB );
#precache( "fx", FX_FREEZEGUN_SHATTER_GIBTRAIL );
#precache( "fx", FX_FREEZEGUN_CRUMPLE_GIB );
#precache( "fx", FX_FREEZEGUN_CRUMPLE_GIBTRAIL );
#precache( "fx", "dlc5/zmb_weapon/fx_freezegun_reload_smoke" );

#namespace zm_weap_freezegun;

function autoexec init_system()
{
	system::register( "zm_weap_freezegun", &__init__, &__main__, undefined );
}

function __init__()
{
	level.weaponZMFreezeGun = GetWeapon( "freezegun" );
	level.weaponZMFreezeGunUpgraded = GetWeapon( "freezegun_upgraded" );

	// [acc] CLIENTFIELD MISMATCH FIX (2026-07-11, third strike of this port's init):
	// registration MUST be unconditional and identical on both VMs - the .csc twin
	// registers these 4 in ITS __init__ with no gate, but the port's .gsc registered
	// them inside __main__ behind an is_weapon_included() gate whose outcome changed
	// with weapon-include timing (it flipped when the freezegun became the dev-start
	// gun) -> server registered 0 while the client registered 4 = "Server Disconnected
	// - Clientfield Mismatch" at every map start. Stock's pattern: register in
	// __init__, gate only gameplay setup. Moved here, unconditional, mirroring the .csc.
	clientfield::register( "actor", "toggle_freezegun_extremity_damage_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "toggle_freezegun_crumple", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "toggle_freezegun_torso_damage_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "actor", "toggle_freezegun_iceover", VERSION_SHIP, 1, "int" );
}

function __main__()
{
	// [acc] the port's original early-return here was DOUBLY broken (2026-07-11):
	// (1) it passed a STRING to is_weapon_included, which does field access -> "string
	// is not a field object" server crash at every load (docs/14 weapons-are-objects
	// trap); (2) the condition is INVERTED vs stock's `if ( !is_weapon_included(...) )
	// return;` idiom (classic decompile corruption, memory gsc-t7-runtime-traps) - it
	// SKIPPED the whole FX/damage setup exactly when the gun IS in the map. The setup
	// below is all level-global writes, harmless when the gun is absent - so the gate
	// is simply REMOVED and this init is deterministic on every load.
	//if ( zm_weapons::is_weapon_included( level.weaponZMFreezeGun ) )
	//{
	//	return;
	//}

	//level._ZOMBIE_ACTOR_FLAG_FREEZEGUN_EXTREMITY_DAMAGE_FX = 15;
	//level._ZOMBIE_ACTOR_FLAG_FREEZEGUN_TORSO_DAMAGE_FX = 14; // Unused system

	level._effect[ "freezegun_shatter" ]				= FX_FREEZEGUN_SHATTER;
	level._effect[ "freezegun_crumple" ]				= FX_FREEZEGUN_CRUMPLE;
	level._effect[ "freezegun_smoke_cloud" ]			= FX_FREEZEGUN_SMOKE_CLOUD;
	level._effect[ "freezegun_damage_torso" ]			= FX_FREEZEGUN_FREEZE_TORSO;
	level._effect[ "freezegun_damage_sm" ]				= FX_FREEZEGUN_FREEZE_MD;
	level._effect[ "freezegun_shatter_upgraded" ]		= FX_FREEZEGUN_SHATTER_UPGRADED;
	level._effect[ "freezegun_crumple_upgraded" ]		= FX_FREEZEGUN_CRUMPLE_UPGRADED;
	level._effect[ "freezegun_reload" ] 				= "dlc5/zmb_weapon/fx_freezegun_reload_smoke";

	// [acc] user 2026-07-18 all-wonder -10% nerf, then user 2026-07-26 "Winterhowl needs a 10% nerf
	// all around as well": every cone/shatter var x0.9 AGAIN, BOTH branches (the else branch is the
	// ACTIVE set - gen_weapon_stats.js parses it; the t8 set is nerfed in lockstep so a future
	// use_t8_damage_set flip doesn't silently restore the old numbers).
	if( IS_TRUE( level.use_t8_damage_set ) )
	{
		zombie_utility::set_zombie_var( "freezegun_inner_damage",					1215 );
		zombie_utility::set_zombie_var( "freezegun_outer_damage",					608 );
		zombie_utility::set_zombie_var( "freezegun_shatter_inner_damage",			608 );
		zombie_utility::set_zombie_var( "freezegun_shatter_outer_damage",			405 );

		zombie_utility::set_zombie_var( "freezegun_inner_damage_upgraded",			2430 );
		zombie_utility::set_zombie_var( "freezegun_outer_damage_upgraded",			1215 );
		zombie_utility::set_zombie_var( "freezegun_shatter_inner_damage_upgraded",	1215 );
		zombie_utility::set_zombie_var( "freezegun_shatter_outer_damage_upgraded",	608 );
	}
	else
	{
		// [acc] History: 1000/500/500/250 -> +15% 2026-07-13 ("slight buff on the winters howl") =
		// 1150/575/575/288 -> x0.9 all-wonder nerf 2026-07-18 = 1035/518/518/259 -> x0.9 again
		// 2026-07-26 = current. The cone is a weaponless DoDamage so acc_weapon_balance_mult can't
		// reach it - the tuning lives here in the zombie_vars (see gen_weapon_stats.js note).
		zombie_utility::set_zombie_var( "freezegun_inner_damage",					932 );
		zombie_utility::set_zombie_var( "freezegun_outer_damage",					466 );
		zombie_utility::set_zombie_var( "freezegun_shatter_inner_damage",			466 );
		zombie_utility::set_zombie_var( "freezegun_shatter_outer_damage",			233 );

		zombie_utility::set_zombie_var( "freezegun_inner_damage_upgraded",			1398 );
		zombie_utility::set_zombie_var( "freezegun_outer_damage_upgraded",			699 );
		zombie_utility::set_zombie_var( "freezegun_shatter_inner_damage_upgraded",	699 );
		zombie_utility::set_zombie_var( "freezegun_shatter_outer_damage_upgraded",	466 );
	}

	// [acc] range bumped ~33% (user 2026-07-11, "increase the range a bit"): outer reach + cone width + inner
	// point-blank radius all up a third, base and upgraded, keeping the cone's proportions.
	zombie_utility::set_zombie_var( "freezegun_inner_range",					80 );   // was 60
	zombie_utility::set_zombie_var( "freezegun_outer_range",					800 );  // was 600
	zombie_utility::set_zombie_var( "freezegun_shatter_range",					240 );  // was 180
	zombie_utility::set_zombie_var( "freezegun_cylinder_radius",				160 );  // was 120

	zombie_utility::set_zombie_var( "freezegun_inner_range_upgraded",			160 );  // was 120
	zombie_utility::set_zombie_var( "freezegun_outer_range_upgraded",			1200 ); // was 900
	zombie_utility::set_zombie_var( "freezegun_shatter_range_upgraded",			400 );  // was 300
	zombie_utility::set_zombie_var( "freezegun_cylinder_radius_upgraded",		240 );  // was 180

	zm_spawner::register_zombie_damage_callback( &freezegun_damage_callback );
	zm_spawner::register_zombie_death_event_callback( &freezegun_death_callback );

	//zombie_utility::add_zombie_gib_weapon_callback
	
	// For testing FX 
	// system_elements/fx_null

	//AnimationStateNetwork::RegisterNotetrackHandlerFunction()	not sure why this was here
	InitZmBehaviorsAndASM();
	
	callback::on_connect( &freezegun_on_player_connect ); 
}

function freezegun_on_player_connect()
{
	self thread wait_for_freezegun_fired(); // changed from thundergun to freezegun
}


function wait_for_freezegun_fired()
{
	self endon( "disconnect" );
	self waittill( "spawned_player" ); 

	for( ;; )
	{
		self waittill( "weapon_fired" ); 
		currentweapon = self GetCurrentWeapon(); 
		// [acc] fire the freeze cone for EVERY freezegun form (user 2026-07-11) — base, PaP
		// (freezegun_upgraded), AND the fastreload TWINS (freezegun[_upgraded]_acc_fastreload). The stock
		// ==-object check missed the twins, so a PaP'd freeze gun held with Speed Cola Mega (which swaps you
		// to a twin) did ZERO damage ("the pap version doesnt do any damage"). Same trap the Thundergun's
		// twin_thundergun_fire_shim solves. Name-substring covers all 4 forms; "_upgraded" flags PaP.
		if( isdefined( currentweapon ) && IsSubStr( currentweapon.name, "freezegun" ) )
		{
			self thread freezegun_fired( IsSubStr( currentweapon.name, "freezegun_upgraded" ) );

			view_pos = self GetTagOrigin( "tag_flash" ) - self GetPlayerViewHeight();
			view_angles = self GetTagAngles( "tag_flash" );
			playfx( level._effect[ "freezegun_smoke_cloud" ], view_pos, AnglesToForward( view_angles ), AnglesToUp( view_angles ) );
		}
	}
}


function freezegun_fired( upgraded )
{
	// ww: physics hit when firing
	PhysicsExplosionCylinder( self.origin, 600, 240, 1 );
	
	self thread freezegun_affect_ais( upgraded );
}

function freezegun_affect_ais( upgraded )
{
	if ( !IsDefined( level.freezegun_enemies ) )
	{
		level.freezegun_enemies = [];
		level.freezegun_enemies_dist_ratio = [];
	}

	self freezegun_get_enemies_in_range( upgraded );

	for ( i = 0; i < level.freezegun_enemies.size; i++ )
	{
		level.freezegun_enemies[i] thread freezegun_do_damage( upgraded, self, level.freezegun_enemies_dist_ratio[i] );
	}

	level.freezegun_enemies = [];
	level.freezegun_enemies_dist_ratio = [];
}


function freezegun_get_cylinder_radius( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_cylinder_radius_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_cylinder_radius"];
	}
}


function freezegun_get_inner_range( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_inner_range_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_inner_range"];
	}
}


function freezegun_get_outer_range( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_outer_range_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_outer_range"];
	}
}


function freezegun_get_inner_damage( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_inner_damage_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_inner_damage"];
	}
}


function freezegun_get_outer_damage( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_outer_damage_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_outer_damage"];
	}
}


function freezegun_get_shatter_range( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_shatter_range_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_shatter_range"];
	}
}


function freezegun_get_shatter_inner_damage( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_shatter_inner_damage_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_shatter_inner_damage"];
	}
}


function freezegun_get_shatter_outer_damage( upgraded )
{
	if ( upgraded )
	{
		return level.zombie_vars["freezegun_shatter_outer_damage_upgraded"];
	}
	else
	{
		return level.zombie_vars["freezegun_shatter_outer_damage"];
	}
}


function freezegun_get_enemies_in_range( upgraded )
{
	inner_range = freezegun_get_inner_range( upgraded );
	outer_range = freezegun_get_outer_range( upgraded );
	cylinder_radius = freezegun_get_cylinder_radius( upgraded );

	view_pos = self GetWeaponMuzzlePoint();

	// Add a 10% epsilon to the range on this call to get guys right on the edge
	zombies = array::get_all_closest( view_pos, GetAiSpeciesArray( "axis", "all" ), undefined, undefined, (outer_range * 1.1) );
	if ( !isDefined( zombies ) )
	{
		return;
	}

	freezegun_inner_range_squared = inner_range * inner_range;
	freezegun_outer_range_squared = outer_range * outer_range;
	cylinder_radius_squared = cylinder_radius * cylinder_radius;

	forward_view_angles = self GetWeaponForwardDir();
	end_pos = view_pos + VectorScale( forward_view_angles, outer_range );

/#
	if ( 2 == GetDvarInt( "scr_freezegun_debug" ) )
	{
		// push the near circle out a couple units to avoid an assert in Circle() due to it attempting to
		// derive the view direction from the circle's center point minus the viewpos 										// Debug broke some shit so no
		// (which is what we're using as our center point, which results in a zeroed direction vector)
		near_circle_pos = view_pos + VectorScale( forward_view_angles, 2 );

		Circle( near_circle_pos, cylinder_radius, (1, 0, 0), false, false, 100 );
		Line( near_circle_pos, end_pos, (0, 0, 1), 1, false, 100 );
		Circle( end_pos, cylinder_radius, (1, 0, 0), false, false, 100 );
	}
#/

	for ( i = 0; i < zombies.size; i++ )
	{
		if ( !IsDefined( zombies[i] ) || !IsAlive( zombies[i] ) )
		{
			// guy died on us
			continue;
		}

		test_origin = zombies[i] getcentroid();
		test_range_squared = DistanceSquared( view_pos, test_origin );
		if ( test_range_squared > freezegun_outer_range_squared )
		{
			zombies[i] freezegun_debug_print( "range", (1, 0, 0) );
			return; // everything else in the list will be out of range
		}

		normal = VectorNormalize( test_origin - view_pos );
		dot = VectorDot( forward_view_angles, normal );
		if ( 0 > dot )
		{
			// guy's behind us
			zombies[i] freezegun_debug_print( "dot", (1, 0, 0) );
			continue;
		}
		
		radial_origin = PointOnSegmentNearestToPoint( view_pos, end_pos, test_origin );
		if ( DistanceSquared( test_origin, radial_origin ) > cylinder_radius_squared )
		{
			// guy's outside the range of the cylinder of effect
			zombies[i] freezegun_debug_print( "cylinder", (1, 0, 0) );
			continue;
		}

		if ( 0 == zombies[i] DamageConeTrace( view_pos, self ) )
		{
			// guy can't actually be hit from where we are
			zombies[i] freezegun_debug_print( "cone", (1, 0, 0) );
			continue;
		}

		level.freezegun_enemies[level.freezegun_enemies.size] = zombies[i];
		level.freezegun_enemies_dist_ratio[level.freezegun_enemies_dist_ratio.size] = (freezegun_outer_range_squared - test_range_squared) / (freezegun_outer_range_squared - freezegun_inner_range_squared);
	}
}


function freezegun_debug_print( msg, color )
{
}

// based off of thundergun code, marks ai as death for animscript
function freezegun_do_damage( upgraded, player, dist_ratio )
{
	if( !IsDefined( self ) || !IsAlive( self ) )
	{
		// guy died on us 
		return;
	}

	// [acc] PaP scales the freeze cone damage +50% PER TIER (user 2026-07-11): T0 x1 / T1 x1.5 / T2 x2 / T3 x2.5.
	// The freeze damage is script-driven (zombie_vars), so it bypasses the normal pap_tier_mult in _acc_damage -
	// we apply the tier scale here. Computed off the BASE damage vars (upgraded=false) so the _up form's own higher
	// vars never DOUBLE-count the tier scale: the _up transform at TIER 2 is the model + the bigger RANGE/shatter
	// reach ("pap benefits on tier 2"), and the DAMAGE is purely this clean +50%/tier ladder. acc_freeze_pap_per_tier tunes it.
	damage = Int( LerpFloat( freezegun_get_outer_damage( false ), freezegun_get_inner_damage( false ), dist_ratio ) );
	pap_tier = player acc_freeze_pap_tier();
	damage = Int( damage * ( 1.0 + ( getdvarfloat( "acc_freeze_pap_per_tier", 0.5 ) * pap_tier ) ) );

	// [acc] target-specific effectiveness (user 2026-07-11): ONE-HIT the Glitch Stalker; otherwise apply the
	// super-effective multiplier (Shielded x3, Phantom boss x2). A utility gun - base freeze damage on everything else.
	if ( self acc_freeze_is_glitch() )
		damage = self.health + 100000;   // guaranteed ONE-HIT (the Glitch is excluded from the per-hit boss cap)
	else
	{
		acc_dmg_mult = self acc_freeze_damage_mult();
		damage = Int( damage * acc_dmg_mult );
	}

	// [acc] utility slow: bosses = the headline slow (17.5%/5s; user 2026-07-18 HALVED the boss speed
	// reduction, was 35%/5s from 2026-07-11); Shielded/Glitch also get a freeze slow.
	// A re-hit RESETS the timer (acc_freeze_apply_ai_slow refreshes acc_freeze_slow_until); the slow NEVER stacks
	// (the rate is SET, not multiplied). WINTER FURY (2nd PaP tier, pap_tier >= 2; user 2026-07-13 "buff a few
	// things, not damage"): the freeze gun's crowd-control identity deepens at tier 2 - the slow lasts LONGER
	// (x1.4 duration) AND is STRONGER (boss 17.5% -> 25% - also halved 2026-07-18, was 35% -> 50%; elite
	// 50% -> 65% untouched). Pure utility, no damage change. All
	// live-tunable. pap_tier from the damage block above.
	fury_dur = ( ( pap_tier >= 2 ) ? getdvarfloat( "acc_freeze_fury_dur_mult", 1.4 ) : 1.0 );
	if ( self acc_freeze_is_boss() )
	{
		boss_rate = ( ( pap_tier >= 2 ) ? getdvarfloat( "acc_freeze_boss_slow_rate_fury", 0.75 ) : getdvarfloat( "acc_freeze_boss_slow_rate", 0.825 ) );
		self acc_freeze_apply_ai_slow( getdvarfloat( "acc_freeze_boss_slow_sec", 5.0 ) * fury_dur, boss_rate );
	}
	else if ( ( self acc_freeze_is_shielded() ) || ( self acc_freeze_is_glitch() ) )
	{
		elite_rate = ( ( pap_tier >= 2 ) ? getdvarfloat( "acc_freeze_elite_slow_rate_fury", 0.35 ) : getdvarfloat( "acc_freeze_elite_slow_rate", 0.5 ) );
		self acc_freeze_apply_ai_slow( getdvarfloat( "acc_freeze_elite_slow_sec", 3.0 ) * fury_dur, elite_rate );
	}

	self DoDamage( damage, player.origin, player, undefined, "projectile" );
	
	self freezegun_debug_print( damage, (0, 1, 0) );

	if ( self.health <= 0 )
	{
		if( isdefined(player) && isdefined(level.hero_power_update))
		{
			level thread [[level.hero_power_update]](player, self);
		}
		
		points = 10;
		if ( !dist_ratio )
		{
			points = zm_score::get_zombie_death_player_points();
		}
		else if ( 1 == dist_ratio )
		{
			points = 30;
		}
		player zm_score::player_add_points( "thundergun_fling", points );

		self.freezegun_death = true;
	}
}


function freezegun_set_extremity_damage_fx()
{
	self clientfield::set( "toggle_freezegun_extremity_damage_fx", 1);
}


function freezegun_clear_extremity_damage_fx()
{
	self clientfield::set( "toggle_freezegun_extremity_damage_fx", 0 );
}


function freezegun_set_torso_damage_fx()
{
	self clientfield::set( "toggle_freezegun_torso_damage_fx", 1 );
}


function freezegun_clear_torso_damage_fx()
{
	self clientfield::set( "toggle_freezegun_torso_damage_fx", 0 );
}


function freezegun_damage_response( player, amount )
{
	// [acc] bosses skip the stock gait-slow (set_zombie_run_cycle) + iceover - those assume a stock
	// zombie body/.zombie_move_speed. Bosses get the ASMSetAnimationRate freeze slow instead (do_damage).
	if ( self acc_freeze_is_boss() ) return;

	if ( IsDefined( self.freezegun_damage_response_func ) )
	{
		if ( self [[ self.freezegun_damage_response_func ]]( player, amount ) )
		{
			return;
		}
	}

	self.freezegun_damage += amount;

	new_move_speed = self.zombie_move_speed;

	percent_dmg = self enemy_percent_damaged_by_freezegun();
	
	if ( 0.66 <= percent_dmg )
	{
		new_move_speed = "walk";
	}
	else if ( 0.33 <= percent_dmg )
	{
		if ( "sprint" == self.zombie_move_speed )
		{
			new_move_speed = "run";
		}
		else
		{
			new_move_speed = "walk";
		}
	}

	if ( !self.isdog && self.zombie_move_speed != new_move_speed )
	{
		zombie_utility::set_zombie_run_cycle( new_move_speed );
	}

	self thread freezegun_set_extremity_damage_fx();
}



// call this when we skip out of freezegun_death() to run the things we skipped in zombie_death_event()
function freezegun_run_skipped_death_events()
{
	//self thread zm_audio::do_zombies_playvocals( "death", self.animname );
	self thread zombie_utility::zombie_eye_glow_stop();
}

function freezegun_damage_callback( mod, HIT_LOCATION, hit_origin, player, amount, weapon, direction_vec, tagName, modelName, partName, dFlags, inflictor, chargeLevel )
{
	if ( self is_freezegun_damage_name( self.damageweapon ) && self.damageMod != "MOD_MELEE" )
	{
		self thread freezegun_damage_response( player, amount );
	}
	return false;
}

function freezegun_death_callback( attacker )
{
	if ( self acc_freeze_is_boss() ) return;   // [acc] no iceblock/shatter on a boss (custom model + hp cap)
	if ( IS_TRUE( self.freezegun_death ) )
	{
		self freezegun_run_skipped_death_events();

	// the line above already tests for this.
		//self.freezegun_death = true;
		self.skip_death_notetracks = true;
		self.skipAutoRagdoll = true;
	
		self PlaySound( "wpn_freezegun_impact_zombie" );
	
		if( RandomIntRange(0,101) >= 88 )
		{
	    	zm_audio::create_and_play_dialog( "kill", "freeze" );
		}

		//self thread setup_radius_damage();

		weap = self.damageweapon;
		self thread setup_iceblock( attacker, weap );


		//self clientfield::set( "toggle_freezegun_explosion", 1 );
	}
}

function setup_iceblock( player, weap )
{
	wait( 3 );
	// [acc] FIX pass 2 (2026-07-12, live "undefined is not an entity" storm): the frozen corpse
	// can be REAPED (round cleanup / corpse cap) during the 3s wait - every self deref below then
	// threw and killed the thread. Return BEFORE the radius-damage latch is set (nothing to
	// unlatch); same guard again before the +1s Delete.
	if ( !isdefined( self ) )
		return;
	SetPlayerIgnoreRadiusDamage( true );
	self Hide();

	// [acc] FIX (2026-07-12, live SCRIPTERROR storm): weap = self.damageweapon is a weapon
	// OBJECT - comparing it to a string THROWS in T7 ("pair 'entity' and 'freezegun_upgraded'
	// has unmatching types 'pointer' and 'string'"), killing this thread 3s after EVERY
	// freezegun kill: the iceblock never shattered (no radiusDamage) and never Delete()d, and
	// the exception spammed console_mp.log. Compare by NAME, substring like the fire path
	// (:175) so the _acc_fastreload twin's upgraded form counts as upgraded too.
	upgraded = ( isdefined( weap ) && isdefined( weap.name ) && IsSubStr( weap.name, "freezegun_upgraded" ) );
	self radiusDamage( self.origin, freezegun_get_shatter_range( upgraded ), freezegun_get_shatter_inner_damage( upgraded ), freezegun_get_shatter_outer_damage( upgraded ), player, "MOD_EXPLOSIVE", weap );

	SetPlayerIgnoreRadiusDamage( false );
	wait( 1 );
	if ( isdefined( self ) )
		self Delete();
}


function is_freezegun_damage()
{
	return isdefined( self.damageweapon ) && (self.damageweapon == level.weaponZMFreezeGun || self.damageweapon == level.weaponZMFreezeGunUpgraded) && ( self.damagemod == "MOD_EXPLOSIVE" || self.damagemod == "MOD_PROJECTILE" );
}

function is_freezegun_damage_name( weapon )
{
	return isdefined(weapon) && (weapon.name == "freezegun" || weapon.name == "freezegun_upgraded");
}


function is_freezegun_shatter_damage()
{
	return isdefined( self.damagemod == "MOD_EXPLOSIVE" && IsDefined( self.damageweapon ) && (self.damageweapon == level.weaponZMFreezeGun || self.damageweapon == level.weaponZMFreezeGunUpgraded ) );
}


function should_do_freezegun_death()
{
	return is_freezegun_damage();
}


function enemy_damaged_by_freezegun()
{
	return 0 < self.freezegun_damage;
}


function enemy_percent_damaged_by_freezegun()
{
	return self.freezegun_damage / self.maxhealth;
}


function enemy_killed_by_freezegun()
{
	return isdefined(self.freezegun_death) && self.freezegun_death;
}

function private InitZmBehaviorsAndASM()
{
	BehaviorTreeNetworkUtility::RegisterBehaviorTreeScriptAPI( "zombiewasKilledByFreezeGun", &wasKilledByFreezeGun );
}

function wasKilledByFreezeGun( behaviorTreeEntity )
{
	if ( behaviorTreeEntity acc_freeze_is_boss() ) return false;   // [acc] no iceover on a boss
	if( IS_TRUE( behaviorTreeEntity.freezegun_death ) && behaviorTreeEntity.freezegun_death )
	{
		behaviorTreeEntity clientfield::set( "toggle_freezegun_iceover", 1 );
		behaviorTreeEntity clientfield::set( "toggle_freezegun_crumple", 1 );
		behaviorTreeEntity thread freezegun_set_extremity_damage_fx();
		behaviorTreeEntity thread freezegun_set_torso_damage_fx();
		return true;
	}
	return false;
}

// ================================================================================
// [acc] Abandoned Cyber City integration (2026-07-11): freezegun = a UTILITY wonder
// weapon whose main job is SLOWING. Boss slow is the headline use; super-effective vs
// the Shielded elite + Glitch Stalker; regular zombies keep the authentic Winter's Howl
// gait-slow -> iceover -> shatter (stock pack path). The AI slow mirrors the Fire Bow
// void slow (_zm_weap_elemental_bow_demongate): a flag + ASMSetAnimationRate(<1.0),
// honored by _acc_zombie_speed::under_anim_slow(), with a watchdog that restores rate
// 1.0 on expiry. Magnitudes/durations are dvar-tunable (acc_freeze_*).
// ================================================================================

function acc_freeze_is_boss()
{
	return IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss );
}

function acc_freeze_is_shielded()
{
	return IS_TRUE( self.acc_is_shielded );
}

function acc_freeze_is_glitch()
{
	return IS_TRUE( self.acc_is_glitch_zombie );
}

function acc_freeze_is_phantom()
{
	return IS_TRUE( self.acc_is_phantom );
}

// Damage multiplier vs the "super effective" targets. The Glitch Stalker is handled separately (ONE-HIT,
// in freezegun_do_damage) so it never reaches this. Shielded x3 (the freeze AoE ignores the front armor);
// the Phantom boss x2 (user 2026-07-11 - the freeze catches its phasing).
function acc_freeze_damage_mult()
{
	if ( self acc_freeze_is_shielded() ) return getdvarfloat( "acc_freeze_vs_shielded", 3.0 );
	if ( self acc_freeze_is_phantom() )  return getdvarfloat( "acc_freeze_vs_phantom", 2.0 );
	if ( self acc_freeze_is_glitch() )   return getdvarfloat( "acc_freeze_vs_glitch", 3.0 );
	return 1.0;
}

// PaP tier (0..3) of the freeze gun the SHOOTER holds. The map keys player.acc_pap_tier by the weapon's
// true_base (acc_weapon_variants::true_base); EVERY freezegun form (base / _up / fastreload twins) resolves
// to level.weaponZMFreezeGun (= GetWeapon("freezegun"), set in __init__), so that object IS the tier key -
// no _acc_weapon_variants #using needed. 0 = unpacked. Used to scale the freeze cone +50%/tier.
function acc_freeze_pap_tier()   // self = the shooting player
{
	if ( !isdefined( self ) || !isplayer( self ) ) return 0;
	if ( !isdefined( self.acc_pap_tier ) ) return 0;
	if ( !isdefined( self.acc_pap_tier[ level.weaponZMFreezeGun ] ) ) return 0;
	return self.acc_pap_tier[ level.weaponZMFreezeGun ];
}

// Apply the freeze move-slow to ANY ai (boss/elite/special). Mirrors the Fire Bow void slow:
// flag + ASMSetAnimationRate(<1.0) (honored by under_anim_slow so the speed sweep won't fight it);
// a watchdog restores rate 1.0 on expiry. Re-hitting REFRESHES the timer (no watchdog stacking).
function acc_freeze_apply_ai_slow( duration, rate )
{
	if ( !isdefined( self ) || !IsAlive( self ) ) return;
	self.acc_freeze_slow_until = GetTime() + int( duration * 1000 );
	if ( IS_TRUE( self.acc_freeze_slowed ) ) return;   // already slowed - the live watchdog reads the refreshed timer
	self.acc_freeze_slowed = 1;
	self ASMSetAnimationRate( rate );
	self thread acc_freeze_slow_watchdog();
}

function acc_freeze_slow_watchdog()
{
	self endon( "death" );
	while ( isdefined( self ) && IsAlive( self ) && isdefined( self.acc_freeze_slow_until ) && GetTime() < self.acc_freeze_slow_until )
		wait 0.1;
	if ( isdefined( self ) )
	{
		self.acc_freeze_slowed = undefined;
		self.acc_freeze_slow_until = undefined;
		if ( IsAlive( self ) )
			self ASMSetAnimationRate( 1.0 );
	}
}