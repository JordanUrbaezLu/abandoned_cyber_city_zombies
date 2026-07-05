#using scripts\codescripts\struct;
#using scripts\shared\flag_shared;
#using scripts\shared\array_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\shared\laststand_shared;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_unitrigger;
#using scripts\zm\_zm_magicbox;
#using scripts\zm\_zm_powerups;

#insert scripts\shared\aat_zm.gsh;

#using_animtree( "generic" ); 

#namespace brutus; 

#precache( "model", "brutus_helmet" );
#precache( "model", "bo2_brutus_fb_death" );
#precache( "model", "perk_clip" );

#define SPAWN_FX			"_NSZ/Brutus/spawn_fx"
#precache( "fx", SPAWN_FX ); 

#define CHEST_FX			"_NSZ/Brutus/chest_fx"
#precache( "fx", CHEST_FX ); 

#define HELMET_SMOKE			"_NSZ/Brutus/helmet_smoke"
#precache( "fx", HELMET_SMOKE ); 

#define LOCK_FX			"fire/fx_fire_ground_rubble_50x50"
#precache( "fx", LOCK_FX ); 

function nsz_iprintlnbold( string )
{
	if( isDefined(level.nsz_debug) && level.nsz_debug )
		iprintlnbold( "^6NSZ Debug:^7 "+string ); 
}

function init()
{
	// ================ Begin: Variables You Can Change if You Like :Begin =====================
	level.brutus_debug = false; // [acc] inert under stage 2 (external spawns disable brutus_spawn_logic, the only reader of this flag)
	level.player_debug = false; 		// Used to set players invicible for testing 
	level.max_brutus = 2; 			// The maximum brutuss you want
	level.min_brutus_round = 5; 		//  The minimum rounds to wait until brutus spawns next
	level.max_brutus_round = 7; 		//  The max rounds to wait until brutus spawns next
	level.multiple_brutus_round = 20; 	// If you want multiple brutuss, they will spawn in multiples after this round
	level.brutus_base_health = 3500; 		// How much base health you want brutus to have. This health is multiplied by the round number. It caps at 85000 health
	level.brutus_lock_machines = false; 		// [acc] DROPPED the perk/box-lock mechanic (user choice). MUST stay false: with no *_lock prefabs placed, watch_for_machines() while(1) has no wait and hard-loops.
	// ================ End: Variables You Can Change if You Like :End =====================
	level.current_brutuses = 0; 
	level.octobomb_targets = &remove_brutus; 
	
	thread main(); 
}

function main()
{
	level flag::wait_till( "all_players_connected" ); 
	// level.nsz_debug = true; 
	level activate_brutus_spawns(); 
	// [acc] stage 2: _acc_boss drives Brutus spawns at r10/r20; disable the native cadence.
	if ( !IS_TRUE( level.acc_brutus_external_spawns ) )
		level thread brutus_spawn_logic();
	if( level.player_debug )
	{
		foreach( player in getplayers() )
			player EnableInvulnerability(); 
	}
}

function activate_brutus_spawns()
{
	level.brutus_spawn_points = []; 

	structs = struct::get_array( "brutus_spawner_spot", "targetname" ); 
	
	if ( !isDefined( structs ) || structs.size < 1 )
	{
		iPrintLnBold( "^1CANNOT FIND BRUTUS STRUCTS" );
		return;
	}
	
	foreach( point in structs )
		point thread wait_for_activation(); 
}

function wait_for_activation()
{
	if( self.script_string == "start_zone" )
		level.brutus_spawn_points[ level.brutus_spawn_points.size ] = self; 
	else
	{
		flag = self.script_string; 
		level flag::wait_till( flag ); 
		level.brutus_spawn_points[ level.brutus_spawn_points.size ] = self; 
	}
}

function brutus_spawn_logic()
{
	level endon( "intermission" );
	
	if( isDefined( level.brutus_debug ) && level.brutus_debug )
		level thread spawn_brutus(); 

	
	level.next_brutus_round = RandomIntRange( level.min_brutus_round, level.max_brutus_round+1 ); 
	nsz_iprintlnbold( "The Next brutus Round: "+level.next_brutus_round ); 
	while(1)
	{
		level waittill( "between_round_over" ); 
		if( level.round_number == level.next_brutus_round )
		{
			level.next_brutus_round = level.round_number + RandomIntRange( level.min_brutus_round, level.max_brutus_round+1 ); 
			if( isDefined(level.next_dog_round) && level.next_brutus_round == level.next_dog_round )
				level.next_brutus_round++; 
			
			while( level.current_brutuses < level.max_brutus )
			{
				wait( RandomIntRange( 1, 20 ) ); 
			
				if( level.current_brutuses < level.max_brutus && level.round_number >= level.multiple_brutus_round )
					level spawn_brutus(); 
				else if( level.current_brutuses < level.max_brutus )
				{
					level spawn_brutus(); 
					break; 
				}
			}
		}
		
	}
}

function spawn_brutus()
{
	level.current_brutuses++; 
	nsz_iprintlnbold( "Current brutuss: "+level.current_brutuses ); 
	spawner = GetEnt( "zombie_brutus", "script_noteworthy" ); 
	// [acc] external spawns appear promptly on the boss round (skip the 5-20s random delay).
	if ( IS_TRUE( level.acc_brutus_external_spawns ) )
		wait( 0.5 );
	else
		wait( RandomIntRange( 5, 20 ) );
	nsz_iprintlnbold( "brutus Spawned" );
	spot = choose_a_spawn();
	if( !isDefined( spot ) )
	{
		// [acc] FALLBACK: the lab brutus_spawner_spot was not found/activated (e.g. its script_string
		// door-flag never fired). Instead of silently NOT spawning - the "Brutus never appears" symptom
		// - synthesize a spot ON the host player so he ALWAYS shows up.
		nsz_iprintlnbold( "^1 no activated brutus_spawner_spot - FALLBACK to host player origin" );
		fb_players = getplayers();
		if ( fb_players.size > 0 && isdefined( fb_players[0] ) )
		{
			spot = spawn( "script_origin", fb_players[0].origin );
			spot.angles = fb_players[0].angles;
		}
		else
		{
			nsz_iprintlnbold( "^1 No Available Spots For brutus" );
			level.current_brutuses--;
			return;
		}
	}
	
	if( level flag::exists( "dog_round" ) && level flag::get("dog_round" ) )
	{
		nsz_iprintlnbold( "^1 It is a dog Round Spawn him next round" ); 
		level.current_brutuses--; 
		level.next_brutus_round = level.round_number + 1; 
		return; 
	}
	
	playsound_to_players( "brutus_prespawn" ); 
	wait(3); 
	playsound_to_players( "brutus_vox_spawn" ); 
	playsound_to_players( "brutus_spawn_short" ); 
	
	brutus = zombie_utility::spawn_zombie( spawner );
	// [acc] 2026-06-15: mark him a boss IMMEDIATELY (before any thread/callback runs) so our
	// zombie-speed system (_acc_zombie_speed.gsc) never grabs him. is_zombie() is true on Brutus
	// (set for melee), so without this our keepalive sweep stomps his locomotion ASM and freezes
	// him in place (valid path, moved=0). is_boss is re-set later at its original site too (idempotent).
	brutus.is_boss = true;
	brutus.acc_boss_custom_speed = true;
	brutus attach_helmet();
	brutus attach_light(); 
	brutus thread zombie_spawn_init();
	brutus thread boss_footsteps(); 
	brutus thread melee_track(); 
	brutus thread note_tracker(); 
	brutus thread new_death(); 
	brutus thread aat_override(); 
	brutus thread zombie_utility::round_spawn_failsafe();
	
	// [acc] Brutus HP is OVERWRITTEN by _acc_boss::spawn_brutus_miniboss (the compounding
	// scale_mini_boss_hp: 56000 x 1.12^(round-10) x coop, NO cap) right after this returns, so this
	// pack value + its old 85000 cap never reach gameplay. Cap REMOVED here too (user 2026-07-04:
	// "there shouldn't be a cap") so even a re-enabled pack path is uncapped. Provisional value only.
	n_players = getplayers();
	n_players = n_players.size;
	brutus.health = level.brutus_base_health*level.round_number*n_players;
	brutus.deathanim = %brutus_death;
	brutus BloodImpact( "normal" ); 
	brutus.no_damage_points = true; 
	brutus.allowpain = false; 
	brutus.ignoreall = true; 
	brutus.ignoreme = true; 
	brutus.allowmelee = false; 
	brutus.needs_run_update = true; 
	brutus.no_powerups = true; 
	brutus.canattack = false; 
	brutus detachAll(); 
	brutus.goalRadius = 32; 
	brutus.is_on_fire = true; 
	brutus.gibbed = true; 
	brutus.variant_type = 0; 
	brutus.zombie_move_speed = "sprint"; 
	brutus.zombie_arms_position = "down"; 
	brutus.ignore_nuke = true; 
	brutus.instakill_func = &anti_instakill; 
	brutus.ignore_enemy_count = true; 
	brutus PushActors( true );
	brutus.lightning_chain_immune = true; 
	brutus.tesla_damage_func = &new_tesla_damage_func; 
	brutus.thundergun_fling_func = &new_thundergun_fling_func; 
	brutus.thundergun_knockdown_func = &new_knockdown_damage; 
	brutus.is_boss = true; 
	
	brutus thread track_helmet(); 
	
	// [acc] hand the live actor to our boss module (_acc_boss_brutus::spawn_one), which
	// layers on our health bar + 10x HP + Mega-Bottle/boss-item rewards + boss music.
	level.acc_brutus_last = brutus;
	level notify( "acc_brutus_spawned" );

	// [acc] Clamp the spawn spot onto the navmesh before teleporting (robustness). The stock pack
	// used the RAW spot.origin (no clampToNavmeshLocation); if a spot is ever off-mesh Brutus lands
	// off the navmesh and can't generate a path. GetClosestPointOnNavMesh snaps him onto a real point.
	nav_spot = GetClosestPointOnNavMesh( spot.origin, 256, 64 );
	if ( !isdefined( nav_spot ) )
		nav_spot = spot.origin;

	brutus ForceTeleport( nav_spot, spot.angles, 1 );
	brutus AnimScripted( "note_notify", brutus.origin, brutus.angles, %brutus_spawn );
	PlayFx( SPAWN_FX, brutus.origin );
	Earthquake( 0.4, 4, brutus.origin, 5000 );
	wait( GetAnimLength( %brutus_spawn ) );

	// brutus thread debug_health();
	brutus thread custom_find_flesh();   // pack-native chase (writes v_zombie_custom_goal_pos)
	if( level.brutus_lock_machines )
		brutus thread watch_for_machines();
}

function attach_light()
{
	fire_angles = self.angles; 
	fire_angles_forward = anglesToForward( fire_angles );
	fire_init = self.origin+(0,0,57);
	impact = fire_init + vectorScale( fire_angles_forward, 9 );
	light = spawn( "script_model", impact ); 
	light SetModel( "tag_origin" ); 
	light.angles = self.angles; 
	light EnableLinkTo(); 
	light LinkTo( self, "j_spineupper" ); 
	PlayFxOnTag( CHEST_FX, light, "tag_origin" ); 
	
	self.light = light; 
}

function aat_override()
{
	while( isDefined(self) )
	{
		archetype = self.archetype; 
		self.aat_cooldown_start[ZM_AAT_BLAST_FURNACE_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_DEAD_WIRE_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_FIRE_WORKS_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_THUNDER_WALL_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.aat_cooldown_start[ZM_AAT_TURNED_NAME] = GetTime() ;  // always force the cooldown to be less than current time
		self.no_powerups = true; 
		self.b_octobomb_infected = true; 
		
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_trigger[ self.archetype ] = true;
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_direct[ self.archetype ] = true;
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_indirect[ self.archetype ] = true;
		
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_trigger[ self.archetype ] = true;
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_direct[ self.archetype ] = true;
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_indirect[ self.archetype ] = true;
		
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_trigger[ self.archetype ] = true;
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_result_direct[ self.archetype ] = true;
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_result_indirect[ self.archetype ] = true;
		
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_trigger[ self.archetype ] = true;
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_direct[ self.archetype ] = true;
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_indirect[ self.archetype ] = true;
		
		level.aat[ ZM_AAT_TURNED_NAME ].immune_trigger[ self.archetype ] = true;
		level.aat[ ZM_AAT_TURNED_NAME ].immune_result_direct[ self.archetype ] = true;
		level.aat[ ZM_AAT_TURNED_NAME ].immune_result_indirect[ self.archetype ] = true;
		
		wait(0.05); 
	}
	
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_trigger[ archetype ] = false;
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_direct[ archetype ] = false;
		level.aat[ ZM_AAT_FIRE_WORKS_NAME ].immune_result_indirect[ archetype ] = false;
		
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_trigger[ archetype ] = false;
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_direct[ archetype ] = false;
		level.aat[ ZM_AAT_BLAST_FURNACE_NAME ].immune_result_indirect[ archetype ] = false;
		
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_trigger[ archetype ] = false;
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_result_direct[ archetype ] = false;
		level.aat[ ZM_AAT_DEAD_WIRE_NAME ].immune_result_indirect[ archetype ] = false;
		
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_trigger[ archetype ] = false;
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_direct[ archetype ] = false;
		level.aat[ ZM_AAT_THUNDER_WALL_NAME ].immune_result_indirect[ archetype ] = false;
		
		level.aat[ ZM_AAT_TURNED_NAME ].immune_trigger[ archetype ] = false;
		level.aat[ ZM_AAT_TURNED_NAME ].immune_result_direct[ archetype ] = false;
		level.aat[ ZM_AAT_TURNED_NAME ].immune_result_indirect[ archetype ] = false;
}

function debug_health()
{
	while(1)
	{
		self.health = 100000; 
		wait(0.05); 
	}
}

function custom_find_flesh()
{
	self endon( "death" ); 
	self endon( "locking_target" ); 

	while(1)
	{
		if( isDefined(self.brutus_enemy) && zm_utility::is_player_valid(self.brutus_enemy) && isDefined(self.brutus_enemy.brutus_track_countdown) && self.brutus_enemy.brutus_track_countdown > 0 )
		{
			self.brutus_enemy.brutus_track_countdown -= 0.05;
			self.v_zombie_custom_goal_pos = self.brutus_enemy.origin; 
		}
		else
		{
			nsz_iprintlnbold( "^3Aquiring New Brutus Target" ); 
			players = GetPlayers(); 
			targets = array::get_all_closest( self.origin, players ); 
			
			for( i=0;i<targets.size;i++ )
			{
				if( zm_utility::is_player_valid( targets[i] ) )
				{
					self.brutus_enemy = targets[i]; 
					self.v_zombie_custom_goal_pos = self.brutus_enemy.origin; 
					
					nsz_iprintlnbold( "^2Aquired New Brutus Target" ); 
					if( !isDefined(targets[i].brutus_track_countdown) )
						targets[i].brutus_track_countdown = 2; 
					if( isDefined(targets[i].brutus_track_countdown) && targets[i].brutus_track_countdown <= 0 )
						targets[i].brutus_track_countdown = 2; 
					break; 
				}
			}
		}
		wait(0.05); 
	}
}

function watch_for_machines()
{
	self endon( "death" ); 
	
	while(1)
	{
		// [acc] HANG GUARD (user 2026-07-03): the ONLY wait() below sits inside the for-loop, so if
		// no "brutus_lock" structs exist (this map dropped the lock mechanic - locks.size==0) the outer
		// while(1) would spin with zero yield = hard engine hang (the exact trap the file header warns
		// about). This whole thread is already gated OFF (brutus_lock_machines=false, never set true),
		// but yield unconditionally here so it's a landmine no more - even if the flag is ever flipped.
		wait( 0.05 );

		locks = struct::get_array( "brutus_lock", "targetname" );
		targets = array::get_all_closest( self.origin, locks );
		if( !isDefined( locks ) || locks.size < 1 )
			continue;

		for( i=0;i<locks.size;i++ )
		{
			if( targets[i].script_noteworthy == "perk_machine" && !isDefined(targets[i].alread_locked) && Distance2d(self.origin, targets[i].origin) < 300 && BulletTracePassed( self.origin,targets[i].origin,false,self ) )
			{
				perk_trig = get_perk_trig( targets[i].script_string ); 
				if( perk_trig.power_on )
				{
					targets[i].alread_locked = true; 
					nsz_iprintlnbold( "^2Acquired New Brutus Lock Perk" ); 
					self waittill_perk_lock_complete( targets[i] ); 
					self thread custom_find_flesh();
				}
			}
			
			if( targets[i].script_noteworthy == "magic_box" && !isDefined(targets[i].alread_locked) && Distance2d(self.origin, targets[i].origin) < 300 && BulletTracePassed( self.origin,targets[i].origin,false,self ) )
			{
				box = get_closest_box( targets[i].origin ); 
				// iprintlnbold( box.zbarrier zm_magicbox::get_magic_box_zbarrier_state() ); 
				if( box.zbarrier.state == "initial" || box.zbarrier.state == "close" )
				{
					targets[i].alread_locked = true; 
					nsz_iprintlnbold( "^2Acquired New Brutus Lock Magic Box" ); 
					self waittill_box_lock_complete( targets[i], box ); 
					self thread custom_find_flesh();
				}
			}
			wait(0.05); 
		}
	}

}

function get_perk_trig( perk )
{
	perk_trigs = GetEntArray( "zombie_vending", "targetname" ); 
	foreach( trig in perk_trigs )
	{
		if( trig.script_noteworthy == perk )
			return trig; 
	}
}

function get_closest_box( org )
{
	box = ArrayGetClosest( org, level.chests );
	return box; 
}

function waittill_perk_lock_complete( lock_struct )
{
	self notify( "locking_target" ); 
	
	while( Distance2d(lock_struct.origin, self.origin) > 55 )
	{
		self.v_zombie_custom_goal_pos = lock_struct.origin; 
		wait(0.05); 
	}
	
	fx = struct::get_array( lock_struct.target, "targetname" ); 
	fx = array::get_all_closest( lock_struct.origin, fx ); 
	self OrientMode( "face point", undefined, undefined, fx[0].origin ); 
	self util::waittill_any_timeout(0.5, "orientdone" );
	
	self AnimScripted( "note_notify", self.origin, self.angles, %brutus_lock_perk ); 
	wait( GetAnimLength( %brutus_lock_perk )/2 ); 
	// lock_struct.alread_locked = true; 
	foreach( spot in fx )
	{
		nsz_iprintlnbold( "^2Light Fire" ); 
		spot.model = spawn( "script_model", spot.origin ); 
		spot.model SetModel( "tag_origin" ); 
		PlayFxOnTag( LOCK_FX, spot.model, "tag_origin" ); 
	}
	
	nsz_iprintlnbold( "^2Locked: "+lock_struct.script_string ); 
	trig = get_perk_trig( lock_struct.script_string ); 
	if( !isDefined(trig) )
		iprintlnbold( "^1No Perk Trig" ); 
	trig SetTeamForTrigger( "axis" ); 
	// iprintlnbold( trig.origin ); 
	trig.machine PlayLoopSound( "brutus_lock_loop" ); 
	trig SetInvisibleToAll(); 
	t_use = Spawn( "trigger_radius_use", trig.origin, 0, 60, 80 );
	t_use TriggerIgnoreTeam();
	t_use SetVisibleToAll();
	t_use SetTeamForTrigger( "none" );
	t_use UseTriggerRequireLookAt();
	t_use SetCursorHint( "HINT_NOICON" );
	t_use SetHintString( "Press and Hold ^3&&1^7 to Unlock [Cost: 2000]" ); 
	
	t_use.perk_trigger = trig; 
	t_use.fx = fx; 
	t_use.cost = 2000; 
	t_use.lock_struct = lock_struct; 
	
	t_use thread locked_think(); 
}

function waittill_box_lock_complete( lock_struct, box_trig )
{
	self notify( "locking_target" );
	
	while( Distance2d(lock_struct.origin, self.origin) > 35 )
	{
		self.v_zombie_custom_goal_pos = lock_struct.origin; 
		wait(0.05); 
	}
	
	self AnimScripted( "note_notify", self.origin, self.angles, %brutus_lock_box ); 
	wait( GetAnimLength( %brutus_lock_box )/2 ); 
	// lock_struct.alread_locked = true; 
	fx = struct::get_array( lock_struct.target, "targetname" ); 
	foreach( spot in fx )
	{
		nsz_iprintlnbold( "^2Light Fire" ); 
		spot.model = spawn( "script_model", spot.origin ); 
		spot.model SetModel( "tag_origin" ); 
		PlayFxOnTag( LOCK_FX, spot.model, "tag_origin" ); 
	}
		
	trig = box_trig; 
	// machine = getentarray( level._custom_perks[ perk ].radiant_machine_name, "targetname");
	
	// trig SetInvisibleToAll(); 
	trig notify( "kill_chest_think" ); 
	thread zm_unitrigger::unregister_unitrigger(trig.unitrigger_stub);
	if( trig.zbarrier.state == "open" )
		trig.zbarrier thread zm_magicbox::set_magic_box_zbarrier_state("close");
	t_use = Spawn( "trigger_radius_use", trig.origin, 0, 40, 80 );
	t_use TriggerIgnoreTeam();
	t_use SetVisibleToAll();
	t_use SetTeamForTrigger( "none" );
	t_use UseTriggerRequireLookAt();
	t_use SetCursorHint( "HINT_NOICON" );
	t_use SetHintString( "Press and Hold ^3&&1^7 to Unlock [Cost: 2000]" ); 
	
	t_use.fx = fx; 
	t_use.cost = 2000; 
	t_use.lock_struct = lock_struct; 
	t_use.sound_ent = t_use.fx[0].model; 
	t_use.sound_ent PlayLoopSound( "brutus_lock_loop" ); 
	
	t_use thread locked_think( trig ); 
}

function locked_think( trig )
{
	while(1)
	{
		self waittill( "trigger", player ); 
		if( player.score >= self.cost )
		{
			player zm_score::minus_to_player_score( self.cost ); 
			PlaySoundAtPosition( "zmb_cha_ching", self.origin ); 
			if( isDefined(self.perk_trigger) )
				self.perk_trigger.machine StopLoopSound(2); 
			if( isDefined(self.sound_ent) )
				self.sound_ent StopLoopSound(2); 
			wait(0.05); 
			if( isDefined(self.perk_trigger) )
				self.perk_trigger SetTeamForTrigger( "allies" ); 
			foreach( fx in self.fx )
				fx.model delete(); 
			self.lock_struct.alread_locked = undefined; 
			self delete(); 
			if( isDefined(trig) )
			{
				trig thread zm_magicbox::treasure_chest_think(); 
				trig.zbarrier thread zm_magicbox::set_magic_box_zbarrier_state("initial"); 
			}
		}
		else 
			PlaySoundAtPosition( "nsz_deny", player.origin ); 
	}
}

function IS_TRUE( statement )
{
	if( isDefined(statement) && statement )
		return true; 
	return false; 
}

function choose_a_spawn()
{
	// nsz_iprintlnbold( "^5 Choose a Spot" ); 
	players = getplayers(); 
	players = array::randomize( players ); 
	player = players[0]; 
	
	if ( !isDefined( level.brutus_spawn_points ) || level.brutus_spawn_points.size < 1 )
		nsz_iprintlnbold( "^1 No brutus Spots Are Init" ); 
	
	option = ArrayGetClosest( player.origin, level.brutus_spawn_points ); 
	// nsz_iprintlnbold( option.script_string ); 
	
	return option; 
}

function boss_think()
{
	self endon( "death" ); 
	assert( !self.isdog );
	
	self.ai_state = "zombie_think";
	self.find_flesh_struct_string = "find_flesh";

	self SetGoal( self.origin );
	self PathMode( "move allowed" );
	self.zombie_think_done = true;
}

function boss_footsteps()
{
	self endon( "death" ); 
	
	while(1)
	{
		self waittill( "footstep" ); 
		Earthquake( 0.2, 1, self.origin ,750 );
		// PlayRumbleOnPosition( "grenade_rumble", self.origin );  fix later
		self Playsound( "brutus_step_0"+randomintrange(0,2) ); 
	}
}

function melee_track()
{
	self endon( "death" ); 
	
	while(1)
	{
		// [acc] guard: brutus_enemy is set by custom_find_flesh a few frames AFTER spawn;
		// dereferencing it before then floods script errors and crashes the game (&& short-
		// circuits, same pattern the pack uses at custom_find_flesh).
		if( isdefined( self.brutus_enemy ) && Distance2d( self.brutus_enemy.origin, self.origin ) < 75 && BulletTracePassed( self.brutus_enemy.origin, self.origin, 0, self, self.brutus_enemy )  )
		{
			self AnimScripted( "note_notify", self.origin, self.angles, %brutus_swing ); 
			wait( GetAnimLength( %brutus_swing ) ); 
		}
		wait(0.05); 
	}
}

function note_tracker()
{
	self endon( "death" ); 
	
	while(1)
	{
		self waittill( "note_notify", note ); 
		if( note == "swing" )
		{
			chance =  RandomIntRange(0,2); 
			self PlaySound( "brutus_swing_0"+chance ); 
			PlaySoundAtPosition( "brutus_vox_swing", self.origin ); 
			players = getplayers(); 
			foreach( player in players )
			{
				if( Distance2d(player.origin, self.origin) < 150 && self.brutus_enemy == player )
				{
					Earthquake( .25, 3, player.origin, 50 ); 
					player shellShock( "frag_grenade_mp", 1 ); 
					player DoDamage( 75, player.origin, self ); 
				}
			}
		}
		if( note == "spawn_complete" )
		{
			self playsound( "brutus_spawn" ); 
			Earthquake( 0.4, 4, self.origin, 1000 ); 
		}
		if( note == "summon" )
		{
			self playsound( "brutus_spawn" ); 
			PlaySoundAtPosition( "brutus_vox_yell", self.origin ); 
		}
		
		if( note == "lock" )
		{
			self playsound( "brutus_lock" ); 
			PlaySoundAtPosition( "brutus_vox_swing", self.origin ); 
			self playsound( "brutus_clang" ); 
		}
		
	}
}

function new_death()
{
	self waittill( "death" );
	// [acc] FIX 2026-06-15: guard self.light - it is only set if create_fire()/the
	// chest-FX setup ran (nsz_brutus.gsc:269). If Brutus died before that, this threw
	// "undefined is not an entity".
	if ( isdefined( self.light ) )
		self.light delete();
	// [acc] HELMET ORPHAN FIX 2026-07-04: self.helmet (a script_model attached at half-health) is
	// freed ONLY by track_helmet, which carries self endon("death") - so a Brutus killed during the
	// ~5-8s helmet-launch window (or one-shot from above half HP) reaps that thread before its
	// delete, orphaning the helmet script_model forever (survives round transitions/kill-alls, piles
	// up over a multi-boss game). new_death fires unconditionally on death, so free it here too;
	// isdefined guards the double-delete on the normal path (delete() nils the ref).
	if ( isdefined( self.helmet ) )
		self.helmet delete();
	level.current_brutuses--;
	PlayFx( SPAWN_FX, self.origin ); 
	
	// [acc] NO drops during the Paradise final battle (user 2026-06-26): the paradise Brutus is a THREAT, not a
	// loot pinata - suppress the last-Brutus power-up drop while the onslaught is running (the generic horde drops
	// are blocked by acc_paradise::block_powerup_drop; this forced drop bypasses that hook, so gate it here too).
	if( level.current_brutuses < 1 && !IS_TRUE( level.acc_paradise_onslaught ) )
		thread zm_powerups::specific_powerup_drop( undefined, self.origin);
	
	self PlaySound( "brutus_helmet" ); 
	self PlaySound( "brutus_defeated_0"+randomintrange(0,3) ); 
	self PlaySound( "brutus_death" ); 
	nsz_iprintlnbold( "^2Brutus Died" ); 
	clone = spawn( "script_model", self.origin ); 
	clone.angles = self.angles; 
	clone SetModel( "bo2_brutus_fb" ); 
	self hide(); 
	clone UseAnimTree( #animtree ); 
	clone AnimScripted( "placeholder", clone.origin, clone.angles, %brutus_death );
	wait( GetAnimLength(%brutus_death) );
	// [acc] FIX 2026-06-15: after the death-anim wait the real Brutus actor may already
	// have been reaped by the engine (zombie cleanup / round end) -> self delete() threw
	// "undefined is not an entity". Guard it; the visual clone (also guarded) is what the
	// player actually sees during the death anim.
	if ( isdefined( self ) )
		self delete();
	wait(30);
	if ( isdefined( clone ) )
		clone delete();
}

function attach_helmet()
{
	self.helmet = spawn( "script_model", self GetTagOrigin("j_head") ); 
	self.helmet SetModel( "brutus_helmet" ); 
	self.helmet.angles = self GetTagAngles("j_head"); 
	self.helmet EnableLinkTo(); 
	self.helmet LinkTo( self, "j_head" ); 
}

function playsound_to_players(sound)
{
	players = getplayers(); 
	foreach( player in players )
		player PlayLocalSound( sound );
}

function track_helmet()
{
	// [acc] FIX 2026-06-15: this thread had NO endon("death"). It busy-waits on
	// self.health, then drives self / self.helmet across several waits. If Brutus
	// dies mid-loop the actor (and j_head tag) go undefined and every line below
	// threw "undefined is not an entity/object" (log lines 728/730/731/732).
	// endon("death") kills the thread the instant he dies; the isdefined guards
	// cover the case where the helmet was never attached / already removed.
	self endon( "death" );

	pop_off = self.health/2;
	while(self.health > pop_off )
		wait(0.05);

	self PlaySound( "brutus_helmet" );
	self PlaySound( "brutus_vox_yell" );

	if ( isdefined( self.helmet ) )
	{
		self.helmet Unlink();
		self.helmet Launch( (0,0,200), (0,200,200) );
	}

	PlayFxOnTag( HELMET_SMOKE, self, "j_head" );

	// [acc] GUARD 2026-07-02: "cannot cast undefined to string" here (user session, stack :759/:746).
	// %brutus_headpain resolves UNDEFINED when the brutus_bundle scriptbundle / brutus xanims are not
	// in the loaded zone - on this box the NSZ GDT had never been imported into source_data (now
	// installed as source_data\nsz_brutus.gdt, the docs/research "APE GDT import" gate), so the anims
	// were missing from gdtdb -> the FF. Guarded so a missing anim degrades to "no head-pain anim"
	// (helmet launch + smoke + enrage still happen) instead of killing this thread with an exception.
	a_pain = %brutus_headpain;
	a_enrage = %brutus_enrage;
	if ( isdefined( a_pain ) )
	{
		self AnimScripted( "note_notify", self.origin, self.angles, a_pain, undefined, undefined, undefined, .1 );
		wait( GetAnimLength( a_pain ) );
	}
	if ( isdefined( a_enrage ) )
		self AnimScripted( "note_notify", self.origin, self.angles, a_enrage, undefined, undefined, undefined, .2 );
	wait(5);
	if ( isdefined( self.helmet ) )
		self.helmet delete();
}

function anti_instakill( player, mod, hit_location )
{
	return true; 
}

function new_thundergun_fling_func( player )
{
	// [acc] 2026-07-03: route through the map's FRACTIONAL boss-blast system
	// (_acc_damage::thundergun_boss_blast via the level pointer - no #using needed in this
	// vendored file): each blast = Brutus MAXHEALTH / divisor (20 base, -3 per Thundergun
	// PaP tier -> 17/14/11). Behavior otherwise unchanged: same no-ragdoll hook slot the
	// NSZ pack installed (nsz spawn :233); the old flat 5000 stays as the fallback if the
	// damage module isn't up yet.
	if ( isdefined( level.acc_tg_boss_blast ) )
	{
		self [[ level.acc_tg_boss_blast ]]( player );
		return;
	}
	self DoDamage( 5000, self.origin, player );
}

function new_tesla_damage_func( origin, player )
{
	self DoDamage( 4000, self.origin, player ); 
}

function new_knockdown_damage( player, gib )
{
	self DoDamage( 1000, self.origin, player ); 
}

// [acc] CRASH FIX (user 2026-07-03): octobomb-target filter (level.octobomb_targets), invoked by
// stock _zm_weap_octobomb.gsc every targeting cycle for EVERY thrown Li'l Arnie. The pack's original
// body did `foreach( zom in ai ) ArrayRemoveValue( ai, zom, false );` - MUTATING the very array it was
// iterating, which invalidates the foreach iterator (undefined behavior in T7 GSC). It was harmless
// only while no boss was present; the instant a boss (is_boss - Brutus, and now the Rogue Protector)
// is in the zombie array it takes the ArrayRemoveValue branch, and with several Arnies out at once
// (4-player spam) it fires constantly -> iterator corruption -> crash. Fix: build a NEW array of the
// non-boss AI (never touch the array being iterated). Also drops any undefined entry so the octobomb's
// ArraySortClosest never sees a stale ref.
function remove_brutus( ai )
{
	filtered = [];
	foreach( zom in ai )
	{
		// Exclude EVERY boss marker the map uses, not just is_boss (user 2026-07-03). Brutus + the
		// Rogue Protector set .is_boss, but the Phantom / Glitch Stalker / Juggernaut Host / Paradise
		// host set only .acc_is_mini_boss, and the Subroutine Core only .acc_is_boss. If they slip
		// through, the stock octobomb (do_tentacle_grab) runs octo_gib + DoDamage(health) + StartRagdoll
		// + LaunchRagdoll on the LIVE mini-boss mid-scripted-animation -> instakill/gib/ragdoll of a boss
		// that has no gib setup and whose threads keep running on a ragdolled-but-alive actor (entity
		// corruption). Same family as the remove_brutus mutate-during-foreach crash - filter them all out.
		if( isDefined( zom )
			&& !isDefined( zom.is_boss )
			&& !IS_TRUE( zom.acc_is_boss )
			&& !IS_TRUE( zom.acc_is_mini_boss ) )
			filtered[ filtered.size ] = zom;
	}
	return filtered;
}

// set up zombie walk cycles ================================================================================
function zombie_spawn_init()
{
	self.targetname = "zombie_boss";
	self.script_noteworthy = undefined;

	//A zombie was spawned - recalculate zombie array
	zm_utility::recalc_zombie_array();
	self.animname = "zombie_boss"; 		
	
	//pre-spawn gamemodule init
	// if(isdefined(zm_utility::get_gamemode_var("pre_init_zombie_spawn_func")))
	// {
		// self [[zm_utility::get_gamemode_var("pre_init_zombie_spawn_func")]]();
	// }
	 
	self.ignoreme = false;
	self.allowdeath = true; 			// allows death during animscripted calls
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
	
	// might need this so co-op zombie players cant block zombie pathing
//	self PushPlayer( true ); 
//	self.meleeRange = 128; 
//	self.meleeRangeSq = anim.meleeRange * anim.meleeRange; 

	self setPhysParams( 15, 0, 72 );
	self.goalradius = 32;
	
	self.disableArrivals = true; 
	self.disableExits = true; 
	self.grenadeawareness = 0;
	self.badplaceawareness = 0;

	self.ignoreSuppression = true; 	
	self.suppressionThreshold = 1; 
	self.noDodgeMove = true; 
	self.dontShootWhileMoving = true;
	self.pathenemylookahead = 0;


	self.holdfire			= true;	//no firing - performance gain

	self.badplaceawareness = 0;
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
	self zm_utility::disable_react(); // SUMEET - zombies dont use react feature.

	// if ( isdefined( level.zombie_health ) )
	// {
		// self.maxhealth = level.zombie_health; 
		
		// if( IsDefined(level.a_zombie_respawn_health[ self.archetype ] ) && level.a_zombie_respawn_health[ self.archetype ].size > 0 )
		// {
			// self.health = level.a_zombie_respawn_health[ self.archetype ][0];
			// ArrayRemoveValue(level.a_zombie_respawn_health[ self.archetype ], level.a_zombie_respawn_health[ self.archetype ][0]);		
		// }
		// else
		// {
			// self.health = level.zombie_health;
		// }	 
	// }
	// else
	// {
		// self.maxhealth = level.zombie_vars["zombie_health_start"]; 
		// self.health = self.maxhealth; 
	// }

	self.freezegun_damage = 0;

	//setting avoidance parameters for zombies
	self setAvoidanceMask( "avoid none" );

	// wait for zombie to teleport into position before pathing
	self PathMode( "dont move" );

	// level thread zombie_death_event( self );

	// We need more script/code to get this to work properly
//	self add_to_spectate_list();
//	self random_tan(); 
	self zm_utility::init_zombie_run_cycle(); 
	self thread boss_think(); 
	// self thread zombie_utility::zombie_gib_on_damage(); 
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
	
	// if ( !isdefined( self.no_eye_glow ) || !self.no_eye_glow )
	// {
		// if ( !IS_TRUE( self.is_inert ) )
		// {
			// self thread zombie_utility::delayed_zombie_eye_glow();	// delayed eye glow for ground crawlers (the eyes floated above the ground before the anim started)
		// }
	// }
	self.deathFunction = &zm_spawner::zombie_death_animscript;
	self.flame_damage_time = 0;

	self.meleeDamage = 60;	// 45
	self.no_powerups = true;
	
	// self zombie_history( "zombie_spawn_init -> Spawned = " + self.origin );

	self.thundergun_knockdown_func = level.basic_zombie_thundergun_knockdown;
	self.tesla_head_gib_func = &zm_spawner::zombie_tesla_head_gib;

	self.team = level.zombie_team;
	
	// No sight update
	self.updateSight = false;

	// self.heroweapon_kill_power = ZM_ZOMBIE_HERO_WEAPON_KILL_POWER;
	// self.sword_kill_power = ZM_ZOMBIE_HERO_WEAPON_KILL_POWER;

	if ( isDefined(level.achievement_monitor_func) )
	{
		self [[level.achievement_monitor_func]]();
	}

	// gamemodule post init
	// if(isdefined(zm_utility::get_gamemode_var("post_init_zombie_spawn_func")))
	// {
		// self [[zm_utility::get_gamemode_var("post_init_zombie_spawn_func")]]();
	// }

	if ( isDefined( level.zombie_init_done ) )
	{
		self [[ level.zombie_init_done ]]();
	}
	self.zombie_init_done = true;

	self notify( "zombie_init_done" );
}