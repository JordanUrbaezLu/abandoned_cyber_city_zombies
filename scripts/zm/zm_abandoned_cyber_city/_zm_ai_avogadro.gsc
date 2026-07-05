#using scripts\zm\_zm;
#using scripts\codescripts\struct;

#using scripts\shared\aat_shared;
#using scripts\shared\ai_puppeteer_shared;
#using scripts\shared\archetype_shared\archetype_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\demo_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\lui_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scoreevents_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\visionset_mgr_shared;
#using scripts\zm\gametypes\_globallogic;
#using scripts\zm\gametypes\_globallogic_vehicle;
#using scripts\zm\_zm_behavior;
#using scripts\shared\music_shared;

#using scripts\shared\ai\systems\gib;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\shared\ai\systems\gib.gsh;
#insert scripts\shared\archetype_shared\archetype_shared.gsh;

#using scripts\zm\gametypes\_weapons;
#using scripts\zm\gametypes\_zm_gametype;
#using scripts\zm\gametypes\_globallogic_spawn;
#using scripts\zm\gametypes\_globallogic_player;

#using scripts\zm\gametypes\_shellshock;

#using scripts\zm\_util;
#using scripts\zm\_zm_attackables;
#using scripts\zm\_zm_audio;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_bgb_token;
#using scripts\zm\_zm_blockers;
#using scripts\zm\_zm_bot;
#using scripts\zm\_zm_daily_challenges;
#using scripts\zm\_zm_equipment;
#using scripts\zm\_zm_ffotd;
#using scripts\zm\_zm_game_module;
#using scripts\zm\_zm_hero_weapon;
#using scripts\zm\_zm_laststand;
#using scripts\zm\_zm_melee_weapon;
#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_pers_upgrades;
#using scripts\zm\_zm_pers_upgrades_functions;
#using scripts\zm\_zm_pers_upgrades_system;
#using scripts\zm\_zm_placeable_mine;
#using scripts\zm\_zm_player;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_stats;
#using scripts\zm\_zm_timer;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_zonemgr;
#using scripts\shared\ai_shared;
#using scripts\shared\ai\zombie_shared;

// AATs
#insert scripts\shared\aat_zm.gsh;
#using scripts\zm\aats\_zm_aat_blast_furnace;
#using scripts\zm\aats\_zm_aat_dead_wire;
#using scripts\zm\aats\_zm_aat_fire_works;
#using scripts\zm\aats\_zm_aat_thunder_wall;
#using scripts\zm\aats\_zm_aat_turned;

#using scripts\zm\craftables\_zm_craftables;

#using scripts\shared\ai\zombie_death;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\ai\zombie.gsh;
#insert scripts\zm\_zm_laststand.gsh;
#insert scripts\zm\_zm_perks.gsh;
#insert scripts\zm\_zm_utility.gsh;

#using scripts\shared\ai\systems\animation_state_machine_utility;
#using scripts\shared\ai\systems\behavior_tree_utility;
#insert scripts\shared\ai\systems\behavior.gsh;
#insert scripts\shared\ai\systems\behavior_tree.gsh;
#insert scripts\shared\ai\systems\blackboard.gsh;
#using scripts\shared\ai\systems\ai_interface;
#using scripts\shared\ai\archetype_utility;
#using scripts\shared\ai\systems\blackboard;

#precache( "fx", "zombie/fx_avogadro_linger" );
#precache( "model", "c_zom_t7_avogadro" );

#using_animtree( "generic" );

#define ATTACK_TIME_TRACK	5000
#define AVO_RANGE_TIME										500
#define AVO_STUN_STUMBLE_COOLDOWN							10000
#define AVO_BOLT_RANGE_MIN	150
#define AVO_BOLT_RANGE_MAX	2000
#define AVO_BOLT_RANGE_MIN_SQ							AVO_BOLT_RANGE_MIN * AVO_BOLT_RANGE_MIN
#define AVO_BOLT_RANGE_MAX_SQ							AVO_BOLT_RANGE_MAX * AVO_BOLT_RANGE_MAX
#define AVO_STUN_TIME										500
#define PLAYTYPE_REJECT 1
#define PLAYTYPE_QUEUE 2
#define PLAYTYPE_ROUND 3
#define PLAYTYPE_SPECIAL 4
#define PLAYTYPE_GAMEEND 5

#namespace zm_ai_avogadro;

REGISTER_SYSTEM( "zm_ai_avogadro", &init, undefined )

function init()
{
	clientfield::register( "scriptmover", "avogadro_fx", VERSION_SHIP, 1, "int" );

	callback::on_connect( &avogadro_callback );

	avogadro_fx();

	InitavogadroBehaviorsAndASM();

	spawner::add_archetype_spawn_function(	"avogadro",	&zombie_utility::zombieSpawnSetup );

	aat::register_immunity( ZM_AAT_BLAST_FURNACE_NAME,	"avogadro",	1,	1,	1 );
	aat::register_immunity( ZM_AAT_DEAD_WIRE_NAME,	"avogadro",	1,	1,	1 );
	aat::register_immunity( ZM_AAT_FIRE_WORKS_NAME,	"avogadro",	1,	1,	1 );
	aat::register_immunity( ZM_AAT_THUNDER_WALL_NAME,	"avogadro",	1,	1,	1 );
	aat::register_immunity( ZM_AAT_TURNED_NAME,	"avogadro",	1,	1,	1 );
	

	level.avogadro_hp = 2000;
	level.avogadros = 0;
	level.avogadro_spawners = GetEntArray( "avogadro_spawner", "script_noteworthy" );
	for( i = 0; i < level.avogadro_spawners.size; i ++ )
	{
		level.avogadro_spawners[i].is_enabled = 1;
		level.avogadro_spawners[i].script_forcespawn = 1;
	}
	array::thread_all( level.avogadro_spawners, &spawner::add_spawn_function, &avogadro_spawn );
	// [acc] Native every-4-6-round cadence DISABLED (user 2026-06-25). We drive spawns from our own
	// boss layer instead (acc_boss_avogadro), mirroring how _acc_boss_brutus drives the NSZ pack. This
	// ALSO removes the `level flag::wait_till("initial_blackscreen_passed")` that spawn_the_avogadro()
	// did from THIS REGISTER_SYSTEM init thread (the flag-wait-from-init crash class, memory
	// flag-waittill-register-system-crash). init() now only REGISTERS the AI; spawning is external.
	// spawn_the_avogadro();
}

function avogadro_fx()
{
	level._effect["avogadro_trail"]	= "zombie/fx_avogadro_linger";
}

//Behavior

function private InitavogadroBehaviorsAndASM()
{
	//Service
	BT_REGISTER_API( "avogadroTargetService", &avogadrotargetservice);
	BT_REGISTER_API(	"ShouldDomeleeAttackService",	&ShouldDomeleeAttackService	);
	//Condition
	BT_REGISTER_API(	"ShouldDomeleeAttack",	&ShouldDomeleeAttack 	);
	BT_REGISTER_API( "avoShouldShootBolt", 	&avoShouldShootBolt );
	//Action
	BT_REGISTER_ACTION(	"ShouldDomeleeAttackAction",	&ShouldDomeleeAttackAction,	undefined,	&melee_attack );
	BT_REGISTER_API( "avoFinishBoltShoot", 			&avoFinishBoltShoot );
	//Function
}

//
function private avogadrotargetservice( avogadro )
{
	if( level.intermission )
	{
		return;
	}

	if ( avogadro GetPathMode() == "dont move" )
	{
		return;
	}

	if (isdefined(avogadro))
	{
		players = GetPlayers();

		valid_players = [];

		foreach(player in players)
		{
			if(zm_utility::is_player_valid( player, true, false ))
			{
				valid_players[valid_players.size] = player;
			}
		}

		if(valid_players.size > 0)
		{
			closest_player = ArrayGetClosest(avogadro.origin, valid_players);

			avogadro.enemy_target = closest_player;
			avogadro.favoriteenemy = closest_player;

			avogadro SetIgnoreEnt( closest_player, false );
			avogadro GetPerfectInfo( closest_player );
			avogadro SetGoal( closest_player );
		}
		else
		{
			avogadro.enemy_target = undefined;
			avogadro.favoriteenemy = undefined;
			avogadro SetGoal( avogadro.origin );
		}
	}
}

function ShouldDomeleeAttackService( entity )
{
	if(isDefined( entity.last_melee_time ) && ( GetTime() - entity.last_melee_time ) < ATTACK_TIME_TRACK)
	{
		return false;
	}
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}

	if( DistanceSquared( entity.origin, entity.enemy.origin ) > (75 * 75) )
	{
		return false;
	}

	yaw = abs( zombie_utility::getYawToEnemy() );

	if( ( yaw > 45 ) )
	{
		return false;
	}
	entity.do_melee_attack = 1;
	return true;
}

function ShouldDomeleeAttack(entity)
{
	if ( IS_TRUE( entity.do_melee_attack ) )
	{
		return true;
	}
	
	return false;	
}

function private avoShouldShootBolt( entity )
{
	if( !IsDefined( entity.enemy ) )
    {
		return false;
	}
	time = GetTime();
	if( time < entity.next_bolt_time )
	{
		return false;
	}
	
	enemy_dist_sq = DistanceSquared( entity.origin, entity.enemy.origin );
	
	if(	!(enemy_dist_sq >= (150*150) && enemy_dist_sq <= (1200*1200) && entity avoCanSeeBoltTarget( entity.enemy )) )
	{
		return false;
	}
	
	return true;
}

function private avoCanSeeBoltTarget( enemy )
{
	entity = self; 
	origin_point = entity GetTagOrigin( "tag_weapon_right" );
	target_point = enemy.origin + (0,0,48);

	forward_vect = AnglesToForward( self.angles );
	vect_to_enemy = target_point - origin_point;
	
	if( VectorDot(forward_vect, vect_to_enemy) <= 0 ) //player behind RAZ
	{
		return false;
	}
	
	//Check if the enemy is inside my sight rect range
	right_vect = AnglesToRight( self.angles );
	
	projected_distance = VectorDot(vect_to_enemy, right_vect);
	

	if(abs(projected_distance) > 50)
	{
		return false;
	}

	trace = BulletTrace( origin_point, target_point, false, self );
	
	if( trace[ "position" ] === target_point )
	{
		return true;
	}
	
	return false;
}

function ShouldDomeleeAttackAction( behavior_tree_entity, asm_state_name)
{
	
    animationStateNetworkUtility::RequestState( behavior_tree_entity, asm_state_name );
	
    return BHTN_RUNNING;
}

function melee_attack( behavior_tree_entity, asm_state_name )
{
	//level thread debug_service();
	behavior_tree_entity.do_melee_attack = undefined;
    return BHTN_SUCCESS;    
}

function private avoFinishBoltShoot( entity )
{
	entity.next_bolt_time = GetTime() + 20000;
}

//

function avogadro_callback()
{
	zm_perks::register_perk_damage_override_func( &avogadro_damage_callback );
}

function avogadro_damage_callback( inflictor, attacker, damage, flags, mod, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
    // [acc] CRASH GUARD (user 2026-07-04): this is a level.perk_damage_override, so it runs on EVERY
    // player-damage event (registered via on_connect, REGISTER_SYSTEM init). Reading attacker.targetname
    // on an UNDEFINED attacker (a 2-arg DoDamage self-kill like the decontamination seal, or fall/
    // environmental damage) threw a runtime script error on the inline damage path. isdefined-guard it -
    // same guard _acc_elites::on_player_damaged and _acc_damage use for this exact read. (The Avogadro
    // boss never spawns on this map, so the branch is never true anyway - this just stops the crash.)
    if( isdefined( attacker ) && attacker.targetname == "avogadro")
    {
    	//IPrintLnBold("hi");
    	//IPrintLnBold(inflictor);
        attacker.enemy shellShock( "avogadro_shock", 1.25 );
		visionset_mgr::activate( "overlay", "zm_trap_electric", attacker.enemy, 1.25, 1.25 );
		return damage;                    
    }
}

function spawn_the_avogadro()
{
	level flag::wait_till( "initial_blackscreen_passed" );
	wait 1;
	level.next_avogadro_round = level.round_number + randomintrange( 4, 6 );
	//IPrintLnBold("Avo will spawn in next on"+level.next_avogadro_round);

	self endon("disconnect");
	while(1)
	{
		self waittill( "between_round_over" ); 
		if( level.round_number == level.next_avogadro_round )
		{

			level.next_avogadro_round = level.round_number + randomintrange( 5, 7 );
			//IPrintLnBold(level.avogadros);
			if( level.avogadros == 0)
			{
				wait( RandomIntRange( 1, 2 ) ); 		
				//IPrintLnBold("spawn the avo");
		    	avogadro_spawn();
			}
		    wait(1);
		}
		wait(3);	
	}
}

function choose_a_spawn()
{
    valid_spots = [];
    structs = struct::get_array( "avogadro_spawn_loc", "script_noteworthy" );
    foreach( struct in structs )
    {
        if( zm_utility::is_point_inside_enabled_zone( struct.origin ) )
        {
            valid_spots[ valid_spots.size ] = struct;
        }
    }
    players = array::randomize( GetPlayers() );
    spot = ArrayGetClosest( players[0].origin, valid_spots );

    // [acc] FALLBACK (user 2026-06-25): no map-placed avogadro_spawn_loc struct (we don't place
    // them - the spawn is script-driven to keep the .map bakeable). Synthesize a spawn point on the
    // host player, exactly like NSZ Brutus does. avogadro_spawn() ForceTeleports to spot.origin + 806z
    // then rise-anims DOWN, so a player-origin spot makes him drop in right on top of the players.
    if ( !isdefined( spot ) && players.size > 0 && isdefined( players[0] ) )
    {
        spot = spawn( "script_origin", players[0].origin );
        spot.angles = players[0].angles;
    }
    return spot;
}

function avogadro_spawn()
{
	avogadro = zombie_utility::spawn_zombie( level.avogadro_spawners[0] );

	s_struct = choose_a_spawn();
	
	//self PlaySound("incoming_alarm");
	Blackboard::CreateBlackBoardForEntity( avogadro );
	// USE UTILITY BLACKBOARD
	avogadro AiUtility::RegisterUtilityBlackboardAttributes();

	// CREATE INTERFACE
	ai::CreateInterfaceForEntity( avogadro );


	avogadro.stumble_stun_cooldown_time = GetTime();
	avogadro thread death(); 
	avogadro thread zombie_spawn_init();

	avogadro thread avo_range_attack();
	avogadro.health = level.avogadro_hp;
	avogadro.maxhealth = avogadro.health;
	avogadro BloodImpact( "none" ); 
	avogadro.no_damage_points = false; 
	//self.closest_player_override = &get_favorite_enemy;
	avogadro.allowpain = false;
	avogadro.allowmelee = false; 
	avogadro.needs_run_update = true; 
	avogadro.no_powerups = true; 
	avogadro.canattack = false; 
	avogadro DetachAll();
	avogadro.is_on_fire = true;
	avogadro.variant_type = 0; 
	avogadro.zombie_move_speed = level.zombie_move_speed; 
	avogadro.zombie_arms_position = "down"; 
	avogadro.ignore_nuke = true; 
	avogadro OrientMode( "face enemy" );
	avogadro SetCanDamage( 1 );
	avogadro AnimMode( "normal" );
	avogadro.ignore_enemy_count = true;
	avogadro PushActors( true );
	avogadro.lightning_chain_immune = true;
	avogadro.headpain = true; 
	avogadro.tesla_damage_func = &new_tesla_damage_func; 
	avogadro.thundergun_fling_func = &new_thundergun_fling_func; 
	avogadro.thundergun_knockdown_func = &new_knockdown_damage; 
	avogadro.instakill_func = &anti_instakill; 
	avogadro.actor_damage_func = &avogadro_damage_override;
	avogadro.non_attack_func_takes_attacker = 1;
	avogadro thread zm_spawner::zombie_death_event( avogadro );
	avogadro thread aat_override();
	//avogadro thread melee_time_track();
	avogadro.is_alive = 1;
	level.avogadros = 1;

	if(IS_TRUE(level.enable_avogadro_theme))
	{
		level thread zm_audio::sndMusicSystem_PlayState("avogadro_theme");
	}

	avogadro thread avogadro_vfx();

	//IPrintLnBold("avo spawned");
	avogadro ForceTeleport( s_struct.origin + ( 0, 0, 806.568 ) , s_struct.angles, 1 ); 
	avogadro AnimScripted( "rise_anim", avogadro.origin, avogadro.angles, "ai_zombie_avogadro_arrival" );
	avogadro zombie_shared::DoNoteTracks( "rise_anim" );
	avogadro.damage_taunt_time = GetTime();
	avogadro.next_bolt_time = GetTime();
	avogadro thread do_bolt_attack();
}

function do_bolt_attack()
{
	self endon("death");
	while(1)
	{
		self waittill("avo_send_bolt");
		base_target_pos = self.enemy.origin;
		v_velocity = self.enemy GetVelocity();
		base_target_pos = base_target_pos + ( v_velocity * 1.5 );
		
		target_pos_offset_x = math::randomsign() * randomint( 32 );
		target_pos_offset_y = math::randomsign() * randomint( 32 );
		
		target_pos = base_target_pos + ( target_pos_offset_x, target_pos_offset_y, 0 );

		dir = VectorToAngles( target_pos - self.origin );

		dir = AnglesToForward( dir );
		
		launch_offset = (dir * 5);

		launch_pos = self GetTagOrigin( "tag_weapon_right" ) + launch_offset;

		dist = Distance( launch_pos, target_pos );

		velocity = dir * dist;
		
		velocity = velocity + (0,0,120);

		self PlaySound("avogadro_attack");

		MagicBullet(GetWeapon("avogadro_bolt"), self GetTagOrigin("tag_weapon_right") , self.enemy.origin , self);
		//self MagicGrenadeType( GetWeapon( "tank_rock" ), launch_pos, velocity );
	}
}

function avogadro_vfx()
{
	lingerfx = Spawn("script_model", self GetTagOrigin("j_spine4"));
	lingerfx SetModel("tag_origin");
	lingerfx LinkTo( self, "j_spine4" );
	lingerfx clientfield::set( "avogadro_fx", 1 );
	lingersfx = Spawn("script_origin",lingerfx.origin);
	lingersfx LinkTo(self,"tag_origin");
	self PlayLoopSound("avogadro_loop");
	self waittill("avogadro_death");
	lingerfx clientfield::set( "avogadro_fx", 0 );
	self StopLoopSound();
	wait(1);
	lingersfx Delete();
	lingerfx Delete();
}

function debug()
{
	self endon("disconnect");
	while(1)
	{
		//IPrintLnBold(self.origin);
		wait(0.05);
	}
}

function avo_range_attack()
{
	self endon("death");
	self endon("exit");
	while(1)
	{
		self waittill("avo_send_bolt");
		enemy = self.enemy;
		self thread shoot_bolt( enemy );
	}
}

function shoot_bolt( enemy )
{
	source_pos = self gettagorigin( "j_wrist_ri" );
	target_pos = enemy GetTagOrigin("j_head");
	bolt = spawn( "script_model", source_pos );
	bolt setmodel( "tag_origin" );
	bolt.lifetime = 5;
	//self playsound( "zmb_avogadro_attack" );
	//fx = playfxontag( level._effect[ "avogadro_bolt" ], bolt, "tag_origin" );
	bolt MoveTo( target_pos, 0 , 2 );
	wait(bolt.lifetime);
	bolt.owner = self;
	bolt check_bolt_impact( enemy );
	bolt delete();
}

function check_bolt_impact( enemy )
{
	if ( zm_utility::is_player_valid( enemy ) )
	{
		target_pos = enemy GetTagOrigin("j_head");
		dist_sq = distancesquared( self.origin, target_pos );
		if ( dist_sq < 4096 )
		{
			passed = bullettracepassed( self.origin, target_pos, 0, undefined );
			if ( passed )
			{
				enemy shellShock( "frag_grenade_mp", 3 );
				visionset_mgr::activate( "overlay", "zm_trap_electric", enemy, 1.25, 1.25 );
				enemy dodamage( 90, enemy.origin );
			}
		}
	}
}

function aat_override()
{
	self endon("death");
	while( isDefined(self) )
	{
		self.aat_cooldown_start[ZM_AAT_BLAST_FURNACE_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_DEAD_WIRE_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_FIRE_WORKS_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_THUNDER_WALL_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_TURNED_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		wait(0.05); 
	}
}

//IPrintLnBold( "Samantha Sez: No Powerup For You!" );

function avogadro_damage_override( inflictor, attacker, damage, flags, mod, weapon, vpoint, vdir, hitloc, poffsettime, boneindex )
{
    //IPrintLnBold(self.health);

    //IPrintLnBold(mod);

    if(IsDefined(mod) && mod == "MOD_MELEE")
    {
    	time = GetTime();
		if( time > self.damage_taunt_time && damage < self.health && self.is_alive == 1 )
		{
			self StopSounds();
			self PlaySound("vox_avogadro_hurt_0"+randomintrange(1,4));
			self PlaySound("avogadro_hurt");
	    	self.damage_taunt_time = GetTime() + 10000;
		}
		else
	    {
	    	//IPrintLnBold("damn it failed");
	    }
    	damage = damage;
    	return damage;
    }
    else
    {
    	time = GetTime();
		if( time > self.damage_taunt_time && self.is_alive == 1 )
		{
			self StopSounds();
			self PlaySound("vox_avogadro_damage_0"+randomintrange(1,9));
	    	self.damage_taunt_time = GetTime() + 10000;
		}
		else
	    {
	    	//IPrintLnBold("damn it failed");
	    }
	    damage = 0;
	    return damage;
    }

    return damage;
}

function anti_instakill( player, mod, hit_location )
{
	return true; 
}

function new_thundergun_fling_func( player )
{ 
	self DoDamage( 0, self.origin, player );
}

function new_tesla_damage_func( origin, player )
{
	self DoDamage( 0, self.origin, player ); 
}

function new_knockdown_damage( player, gib )
{
	self DoDamage( 0, self.origin, player ); 
}

function death()
{
	self endon("death");
	self endon("exit");
	while( 1 )
	{
		if(self.health < 2)
		{
			//IPrintLnBold( "avo died Died" );
			level.avogadro_death_origin = self.origin;
			self.attacker thread death_rewards(self.attacker);
			self.is_alive = 0;
			self PlaySound("avogadro_death");
			if( isdefined( level.musicSystem.currentState ) && level.musicSystem.currentState == "avogadro_theme" )
			{
				level thread zm_audio::sndMusicSystem_StopAndFlush();
				music::setmusicstate("none");
			}
			level.avogadros = 0;
			self.sfx StopLoopSound();
			self AnimScripted( "exit_anim", self.origin, self.angles, "ai_zombie_avogadro_exit" );
			self StopSounds();
			self PlaySound("vox_avogadro_depart_0"+randomintrange(1,7));
			self zombie_shared::DoNoteTracks( "exit_anim" );
			self.allowdeath = true;
			wait(0.05);
			self notify("avogadro_death");
			self Delete();
			if(isDefined(self))
			{
				//IPrintLnBold("avo is still alive");
				self Delete();
				if(isDefined(self))
				{
					//IPrintLnBold("avo is still alive");
					self Delete();
				}
				else if(!isDefined(self))
				{
					//IPrintLnBold("avo is still gone!");
				}
			}
			else if(!isDefined(self))
			{
				//IPrintLnBold("avo is still gone!");
			}
		}
		wait(0.01);
	}
}

function death_rewards(attacker)
{
	self zm_score::add_to_player_score( 1000 );
	powerup = zm_powerups::get_valid_powerup();
	power_up_origin = level.avogadro_death_origin;
	if( isdefined( power_up_origin ) )
	{
		level thread zm_powerups::specific_powerup_drop( "full_ammo", power_up_origin );
	}
	wait(2);
	power_up_origin Delete();
}

function zombie_spawn_init()
{
	self.targetname = "avogadro";
	self.script_noteworthy = undefined;

	//A zombie was spawned - recalculate zombie array
	zm_utility::recalc_zombie_array();
	self.animname = "zombie_boss"; 		
	
	//pre-spawn gamemodule init
	// if(isdefined(zm_utility::get_gamemode_var("pre_init_zombie_spawn_func")))
	// {
		// self [[zm_utility::get_gamemode_var("pre_init_zombie_spawn_func")]]();
	// }
	self.allowdeath = false; 			// allows death during animscripted calls
	self.force_gib = true; 		// needed to make sure this guy does gibs
	self.is_zombie = true; 			// needed for melee.gsc in the animscripts
	self allowedStances( "stand" );
	
	//needed to make sure zombies don't distribute themselves amongst players
	self.attackerCountThreatScale = 0;
	//reduce the amount zombies favor their current enemy
	self.currentEnemyThreatScale = 0;
	//reduce the amount zombies target recent attackers
	self.recentAttackerThreatScale = 0;
	//zombies dont care about whether players are in cover
	self.coverThreatScale = 0;
	//make sure zombies have 360 degree visibility
	self.fovcosine = 0;
	self.fovcosinebusy = 0;
	
	self.zombie_damaged_by_bar_knockdown = false; // This tracks when I can knock down a zombie with a bar

	self.gibbed = false; 
	self.head_gibbed = false;
	
	self setPhysParams( 15, 0, 72 );
	self.goalradius = 32;
	
	self.disableArrivals = true; 
	self.disableExits = true;
	self.ignoreSuppression = true; 	
	self.suppressionThreshold = 1; 
	self.noDodgeMove = true; 
	self.dontShootWhileMoving = true;
	self.pathenemylookahead = 0;


	self.holdfire			= true;

	self.badplaceawareness = 1;
	self.grenadeawareness = 1;
	self.chatInitialized = false;
	self.missingLegs = false;

	if ( !isdefined( self.zombie_arms_position ) )
	{
		if(randomint( 2 ) == 0)
			self.zombie_arms_position = "up";
		else
			self.zombie_arms_position = "down";
	}
	
	self.a.disablepain = true;
	self zm_utility::disable_react();

	self.freezegun_damage = 0;

	self setAvoidanceMask( "avoid none" );

	self PathMode( "dont move" );
	self zm_utility::init_zombie_run_cycle(); 
	self thread zm_spawner::zombie_damage_failsafe();
	
	self thread zm_spawner::enemy_death_detection();

	if(IsDefined(level._zombie_custom_spawn_logic))
	{
		if(IsArray(level._zombie_custom_spawn_logic))
		{
			for(i = 0; i < level._zombie_custom_spawn_logic.size; i ++)
			{
			self thread [[level._zombie_custom_spawn_logic[i]]]();
			}
		}
		else
		{
			self thread [[level._zombie_custom_spawn_logic]]();
		}
	}
	
	self.deathFunction = &zm_spawner::zombie_death_animscript;
	self.flame_damage_time = 0;

	self.meleeDamage = 60;	// 45
	
	self.tesla_head_gib_func = &zm_spawner::zombie_tesla_head_gib;

	self.team = level.zombie_team;
	
	self.updateSight = false;

	if ( isDefined(level.achievement_monitor_func) )
	{
		self [[level.achievement_monitor_func]]();
	}

	if ( isDefined( level.zombie_init_done ) )
	{
		self [[ level.zombie_init_done ]]();
	}
	self.zombie_init_done = true;

	assert( !self.isdog );
	
	self.ai_state = "zombie_think";
	self.find_flesh_struct_string = "find_flesh";

	self SetGoal( self.origin );
	self PathMode( "move allowed" );
	self.zombie_think_done = true;

	self notify( "zombie_init_done" );
}

function avogadro_thinks()
{
	self endon( "death" ); 
	
}