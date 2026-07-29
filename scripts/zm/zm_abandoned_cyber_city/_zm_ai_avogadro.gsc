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
#using scripts\shared\ai\zombie;   // [acc] ZombieBehavior::ArchetypeZombieBlackboardInit (full blackboard incl. LOCOMOTION_SPEED_TYPE)

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

// [acc] The ONLY _acc_ dep in this vendored pack file - avogadro_damage_override needs the canonical
// Action-Figure name matcher so the knife counter can't swallow the wonder-melee weapons (see there).
// No using-cycle: nothing _acc_damage pulls in (transitively) #usings this file - verified 2026-07-15.
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;

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
	// [acc] BOLT PROJECTILE field (2026-07-06, user: "hard to see his projectile"): dedicated mover field
	// for _acc_boss_avogadro::bolt_travel's thrown bolt. The .csc callback stacks TWO fx (his linger
	// crackle + the bright tesla-bolt arc) and plays the launch/impact sounds CLIENT-side, positionally at
	// the bolt (server PlaySound on AI actors is dead in this build - _acc_boss_nameplate precedent).
	clientfield::register( "scriptmover", "acc_avo_bolt_fx", VERSION_SHIP, 1, "int" );

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
	// [acc] BUG FIX (2026-07-06): the pack BT (zm_avogadro.ai_bt, shootgroundtorpedobehavior node) gates the
	// bolt-shoot sequence on `condition_script_negate: ShouldDopunchAttack` - a script function the pack GSC
	// NEVER REGISTERED (it's not stock either; leftover from whatever AI the BT was cloned from). An
	// unregistered BT scriptFunction can never pass, so (a) the bolt branch was DEAD (range-attack anim never
	// played -> no avo_send_bolt notify -> no visible attack), and (b) whenever avoShouldShootBolt was TRUE the
	// BT deadlocked: bolt branch failed, and BOTH movebehavior and idlebehavior require NOT-avoShouldShootBolt,
	// so no branch could run -> he FROZE in place (the "never walks" bug). Registering the stub (no punch
	// attack exists -> always false; the negate node then passes) revives the bolt branch and the freeze.
	BT_REGISTER_API( "ShouldDopunchAttack",	&ShouldDopunchAttack );
	//Action
	BT_REGISTER_ACTION(	"ShouldDomeleeAttackAction",	&ShouldDomeleeAttackAction,	undefined,	&melee_attack );
	BT_REGISTER_API( "avoFinishBoltShoot", 			&avoFinishBoltShoot );
	//Function
}

// [acc] Stub for the BT's unregistered ShouldDopunchAttack condition (see the register note above).
// The Avogadro has no punch attack - always false, so the BT's negate gate always passes.
function private ShouldDopunchAttack( entity )
{
	return false;
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

		// [acc] ENEMY UPKEEP RUNS UNCONDITIONALLY (2026-07-06): this used to early-return on the machine-seek
		// override BEFORE setting enemy_target/favoriteenemy - so while _acc_boss_avogadro's hack_director had
		// a goal set (which is nearly ALWAYS), .enemy went stale/undefined, which silently killed the BT bolt
		// attack (avoShouldShootBolt needs entity.enemy) AND OrientMode("face enemy"). Enemy bookkeeping now
		// always runs; only the GOAL below switches between the machine override and the player chase.
		closest_player = undefined;
		if(valid_players.size > 0)
		{
			closest_player = ArrayGetClosest(avogadro.origin, valid_players);

			avogadro.enemy_target = closest_player;
			avogadro.favoriteenemy = closest_player;

			avogadro SetIgnoreEnt( closest_player, false );
			avogadro GetPerfectInfo( closest_player );
		}
		else
		{
			avogadro.enemy_target = undefined;
			avogadro.favoriteenemy = undefined;
		}

		// [acc] Boss HACK movement (user 2026-07-04): when _acc_boss_avogadro's hack_director wants him to
		// walk up to a machine, it sets avogadro.acc_avo_seek + .acc_avo_goal_pos; honour that goal instead
		// of chasing the closest player. It clears acc_avo_seek (false) when he should chase players again.
		// Clean hand-off (no BT re-registration): default (unset) = the stock closest-player chase.
		if ( IS_TRUE( avogadro.acc_avo_seek ) && isdefined( avogadro.acc_avo_goal_pos ) )
			avogadro SetGoal( avogadro.acc_avo_goal_pos );
		else if ( isdefined( closest_player ) )
			avogadro SetGoal( closest_player );
		else
			avogadro SetGoal( avogadro.origin );
	}
}

function ShouldDomeleeAttackService( entity )
{
	if ( IS_TRUE( entity.acc_avo_no_melee ) )   // [acc] our boss disables the pack BT melee (0-dmg stun-only design; allowmelee/canattack don't gate this custom chain)
		return false;
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
	if ( IS_TRUE( entity.acc_avo_no_melee ) )   // [acc] boss: never melee (see ShouldDomeleeAttackService)
		return false;
	if ( IS_TRUE( entity.do_melee_attack ) )
	{
		return true;
	}
	
	return false;	
}

// [acc] entity.acc_avo_bolt_block (2026-07-06): each BT eval records WHY the bolt is not firing
// ("none" = firing / ready). Pure diagnostics - _acc_boss_avogadro's dev heartbeat prints it, so a
// playtest log shows exactly which gate starves the attack (cooldown vs range vs LOS vs no enemy).
function private avoShouldShootBolt( entity )
{
	if ( IS_TRUE( entity.acc_avo_no_bolt ) )   // [acc] script kill-switch (paradise / future use)
	{
		entity.acc_avo_bolt_block = "disabled";
		return false;
	}
	if( !IsDefined( entity.enemy ) )
    {
		entity.acc_avo_bolt_block = "no_enemy";
		return false;
	}
	time = GetTime();
	if( time < entity.next_bolt_time )
	{
		entity.acc_avo_bolt_block = "cooldown";
		return false;
	}

	enemy_dist_sq = DistanceSquared( entity.origin, entity.enemy.origin );

	if( enemy_dist_sq < AVO_BOLT_RANGE_MIN_SQ || enemy_dist_sq > AVO_BOLT_RANGE_MAX_SQ )
	{
		entity.acc_avo_bolt_block = "range";
		return false;
	}
	if( !( entity avoCanSeeBoltTarget( entity.enemy ) ) )
	{
		entity.acc_avo_bolt_block = "los";
		return false;
	}

	entity.acc_avo_bolt_block = "none";
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

	// [acc] SIGHT RECT REMOVED (2026-07-06 playtest: bolt starved on block=los nearly the whole fight):
	// the pack also required the enemy within +/-50u LATERALLY of his exact facing - an orbiting player
	// almost never sat in that strip, so he virtually never threw. The behind-check above + the world
	// trace below stay; the range_in state's mocomp_force_face_enemy snaps him onto the target during
	// the throw anim anyway, so precise pre-aim is pointless.

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
	// [acc] CADENCE (2026-07-06): pack hardcoded a 20s cooldown - way too slow for the "annoying
	// stun-harasser" design (the 3s slow would fully expire between shots). Dvar-tunable, default 0.75s
	// (user playtest ladder: 3.0 "so slow" -> 1.5 -> "2x faster" -> 0.75; the throw anim itself - now at
	// 2x playback via acc_avo_anim_rate - spaces the real cadence): a chased player stays near-permanently
	// slowed, and every zap is a VISIBLE thrown bolt. Live-tune acc_avo_bolt_cd (secs).
	entity.next_bolt_time = GetTime() + int( getdvarfloat( "acc_avo_bolt_cd", 0.75 ) * 1000 );
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
    // same guard _acc_elites::on_player_damaged and _acc_damage use for this exact read.
    // [acc] 2026-07-11 (console_mp.log: "pair 'undefined' and 'avogadro' has unmatching types"): the
    // 2026-07-04 guard checked attacker but NOT attacker.targetname - `undefined == "string"` THROWS in
    // T7 (memory gsc-t7-runtime-traps), and most attackers (players, zombies) carry no targetname.
    if( isdefined( attacker ) && isdefined( attacker.targetname ) && attacker.targetname == "avogadro")
    {
        // [acc] LIVE NOW (2026-07-06): the boss's zaps deal real chip damage with attacker=boss
        // (_acc_boss_avogadro::zap_damage), so this branch actually RUNS on every zap. The pack body was a
        // double runtime bomb: it shellshocked `attacker.enemy` (can be undefined or a DIFFERENT player
        // than the victim -> method-on-undefined throw on the inline damage path) with "avogadro_shock"
        // (a shock asset the pack does NOT ship/zone). Retargeted to SELF (stock dispatches these
        // overrides ON the damaged player, _zm.gsc:5235) with the stock-shipped "electrocution" shock
        // (zm tesla/teleporter precedent) + the zm_trap_electric overlay (REGISTER_SYSTEM-registered by
        // _zm_trap_electric, pulled in by zm_usermap). This is the on-hit "I got zapped" screen tell.
        // 0.75s (not the pack's 1.25): with the aura ticking at 0.5s and bolts at ~2s, a 1.25s shock
        // would chain into a PERMANENT wobble while near him - the tell must sting, not blind.
        shock_sec = getdvarfloat( "acc_avo_shock_sec", 0.75 );
        self shellShock( "electrocution", shock_sec );
        visionset_mgr::activate( "overlay", "zm_trap_electric", self, shock_sec, shock_sec );
        return damage;                    // identity (chain is isdefined-based; other overrides still run)
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
    // [acc] 4p guard (2026-07-06 coop sweep): GetPlayers() can be empty in the same tick as a mass
    // quit/host-migration; players[0].origin then throws and ends the match. Caller handles undefined.
    if ( players.size == 0 || !isdefined( players[ 0 ] ) )
        return undefined;
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

// [acc] SPAWN-DIAGNOSTIC LOG (user 2026-07-04): IPrintLnBold to every player so each spawn step is
// visible ON-SCREEN and in console_mp.log (routes as [SCRIPTER] lines - the one log channel the
// launch runbook confirms actually shows up; the /# println #/ dev-block log does NOT). Used to
// pinpoint exactly which spawn step a CTD dies on. Silence with `level.avo_no_log = true`.
function avo_log( msg )
{
	// DEV-ONLY (user 2026-07-05): the on-screen [AVO] spawn diagnostics show ONLY in dev mode
	// (level.acc_dev - the acc_avo_debug dvar was removed 2026-07-16). level.avo_no_log was never
	// assigned anywhere, so this used to IPrintLnBold ~7 lines to
	// EVERY player on each Avogadro spawn in normal play. acc_dev is the one flag that gates it now.
	if ( !IS_TRUE( level.acc_dev ) )   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
		return;
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		if ( isdefined( players[i] ) )
			players[i] IPrintLnBold( "^5[AVO]^7 " + msg );
	}
}

// [acc] SPAWN ENTRY (user 2026-07-04): now accepts an OPTIONAL pre-spawned actor so our driver can
// spawn him via SpawnActor("spawner_zm_avogadro", ...) - the LED-bake-SAFE Rogue Protector recipe -
// instead of the pack's spawn_zombie( spawner ), which needs a .map actor_spawner_zm_avogadro entity
// that CRASHES the Radiant LED bake (map_source note ~L3969). Pass the SpawnActor result as
// `pre_spawned`; omit it for the legacy native path. `skip_cinematic` skips the 806u-up ForceTeleport
// + rise_anim entrance (the bare spawn test just leaves him where SpawnActor put him). Every risky
// step is bracketed by avo_log so a mid-setup crash shows its last reached step. Returns the actor.
function avogadro_spawn( pre_spawned, skip_cinematic )
{
	if ( isdefined( pre_spawned ) )
	{
		avo_log( "avogadro_spawn: using PRE-SPAWNED actor (SpawnActor path)" );
		avogadro = pre_spawned;
	}
	else
	{
		avo_log( "avogadro_spawn: native spawn_zombie path" );
		avogadro = zombie_utility::spawn_zombie( level.avogadro_spawners[0] );
	}

	if ( !isdefined( avogadro ) )
	{
		avo_log( "^1avogadro_spawn: actor UNDEFINED after spawn - ABORT" );
		return undefined;
	}
	avo_log( "step A: actor defined, origin=" + avogadro.origin );

	// [acc] #7 LEAK FIX (2026-07-05): only synthesize a spawn point when the cinematic entrance will
	// actually consume it. choose_a_spawn() has no map-placed avogadro_spawn_loc struct to return, so it
	// spawn()s a script_origin on the host player - a real entity. The SpawnActor boss path passes
	// skip_cinematic=true and never touches s_struct, so calling this there leaked one script_origin per
	// spawn (worst in the dev respawn loop). Guard it; the cinematic block below Delete()s it after use.
	s_struct = undefined;
	if ( !IS_TRUE( skip_cinematic ) )
		s_struct = choose_a_spawn();

	// [acc] LOCOMOTION FIX (user 2026-07-05): the pack did ONLY these 3 blackboard lines and OMITTED
	// LOCOMOTION_SPEED_TYPE, so the ASM had no walk/run state to enter -> he never moved (melee still
	// worked because it's a DIRECT state request, not blackboard-driven). ArchetypeZombieBlackboardInit
	// does all 3 of those PLUS LOCOMOTION_SPEED_TYPE / arms / legs / variant + the post-AnimScripted
	// blackboard re-init callback (stock; mechz calls it the same way). The archetype "avogadro" doesn't
	// auto-run it (engine only does that for ARCHETYPE_ZOMBIE), hence the hand-call.
	avogadro ZombieBehavior::ArchetypeZombieBlackboardInit();
	avo_log( "step B: blackboard init (full ArchetypeZombieBlackboardInit incl. locomotion)" );

	avogadro.stumble_stun_cooldown_time = GetTime();
	avogadro thread death();
	avogadro thread zombie_spawn_init();

	// [acc] PACK BOLT ATTACK HANDLERS DISABLED (user 2026-07-04): avo_range_attack -> shoot_bolt does 90
	// dmg + shellShock (conflicts with our "0-damage stun-lock" design) and do_bolt_attack (below) fires
	// MagicBullet(GetWeapon("avogadro_bolt")) which CRASHES if that weapon isn't loaded (weapon-none
	// crash). Both pack handlers stay removed - but as of 2026-07-06 the BT's "avo_send_bolt" anim notify
	// DOES have a listener again: _acc_boss_avogadro::bolt_listener (0-dmg visible bolt + 30% slow on
	// impact), so the throw animation, bolt projectile, SFX and stun are one synced event.
	// avogadro thread avo_range_attack();
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
	avo_log( "step C: fields + AI threads set, is_alive=1, hp=" + avogadro.health );

	if(IS_TRUE(level.enable_avogadro_theme))
	{
		level thread zm_audio::sndMusicSystem_PlayState("avogadro_theme");
	}

	avogadro thread avogadro_vfx();
	avo_log( "step D: electric vfx threaded" );

	if ( !IS_TRUE( skip_cinematic ) && isdefined( s_struct ) )
	{
		avo_log( "step E: cinematic entrance (ForceTeleport +806u -> rise_anim)" );
		avogadro ForceTeleport( s_struct.origin + ( 0, 0, 806.568 ) , s_struct.angles, 1 );
		avogadro AnimScripted( "rise_anim", avogadro.origin, avogadro.angles, "ai_zombie_avogadro_arrival" );
		avogadro zombie_shared::DoNoteTracks( "rise_anim" );
		avo_log( "step E done: rise_anim complete, origin=" + avogadro.origin );
		// [acc] #7 LEAK FIX (2026-07-05): the entrance has now consumed s_struct - Delete the synthesized
		// script_origin choose_a_spawn() spawned. Guard on the script_origin classname so a future
		// MAP-placed avogadro_spawn_loc struct (a non-entity) is never passed to Delete().
		if ( isdefined( s_struct ) && isdefined( s_struct.classname ) && s_struct.classname == "script_origin" )
			s_struct Delete();
	}
	else
	{
		avo_log( "step E SKIPPED (bare spawn test - actor stays at SpawnActor origin)" );
	}

	avogadro.damage_taunt_time = GetTime();
	avogadro.next_bolt_time = GetTime();
	// avogadro thread do_bolt_attack();   // [acc] DISABLED - see the note above avo_range_attack (crash + damage risk)
	avo_log( "^2avogadro_spawn: COMPLETE - fully set up at " + avogadro.origin );

	return avogadro;
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
	// [acc] presence crackle moved CLIENT-side (acc_avo_crackle_lp, off the avogadro_fx CF in _zm_ai_avogadro.csc); server PlayLoopSound on this AI actor is dead in this build (sfx sweep 2026-07-21).
	self waittill("avogadro_death");
	// [acc] GUARD (user 2026-07-05): death() Delete()s self immediately after this notify, so self (and the
	// LinkTo'd fx) can already be a removed entity here - isdefined-guard every access to avoid the crash.
	if ( isdefined( lingerfx ) )
		lingerfx clientfield::set( "avogadro_fx", 0 );
	if ( isdefined( self ) )
		self StopLoopSound();
	wait(1);
	if ( isdefined( lingersfx ) )
		lingersfx Delete();
	if ( isdefined( lingerfx ) )
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
    	// [acc] WONDER-MELEE PASS-THROUGH (review 2026-07-15) - MUST stay above the knife counter.
    	// Stock REPLACES our actor-damage callback's value with this function's return (_zm.gsc:5633 runs
    	// check_actor_damage_callbacks, then :5748 does `final_damage = [[ self.actor_damage_func ]]( ... )`),
    	// so the counter below - which DISCARDS the incoming `damage` by design - was also swallowing the two
    	// melee weapons that already carry their OWN designed per-boss hits-to-kill out of
    	// acc_damage::on_ai_damage: the Leviathan Axe (maxhealth/17|14|12|8 by PaP tier) and the Action Figure
    	// (maxhealth/acc_af_boss_hits, 33). Both collapsed to 100 hits here, which INVERTED the whole design -
    	// the deliberately melee-WEAK boss became the melee weapons' WORST target (axe: 8 hits on every other
    	// boss, 100 on him) - and lied on the HUD, since on_ai_damage had already fed the crosshair the real
    	// (up to 12.5x larger) number before we overwrote the HP it actually removed. Return theirs untouched.
    	// NOT excluded (deliberate): the bare knife, the Berzerker knife and the ballistic-knife STAB. They ARE
    	// knives - exactly what the counter is for (docs/22: "weak to melee") - and none has a designed boss
    	// hits-to-kill (acc_damage routes the ballistic stab to the capped-chip chain like any other boss), so
    	// there is no design to void; the flat 1/100 IS their intent on this boss.
    	// The Leviathan needs the DUAL-SURFACE resolve that acc_damage:429-436 documents: a fireType-Melee
    	// weapon's swing does NOT reliably report itself as the damage-event `weapon`, so also check the
    	// attacker's HELD weapon (melee-gated - we're already inside the MOD_MELEE branch, so offhands, whose
    	// throws never change GetCurrentWeapon, can't be misattributed to the axe in hand).
    	if ( acc_damage::is_action_figure_weapon( weapon ) )
    		return damage;
    	if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "leviathan" ) )
    		return damage;
    	if ( isdefined( attacker ) && isplayer( attacker ) )
    	{
    		lev_held = attacker GetCurrentWeapon();
    		if ( isdefined( lev_held ) && lev_held != level.weaponNone && isdefined( lev_held.name )
    		     && IsSubStr( lev_held.name, "leviathan" ) )
    			return damage;
    	}

    	// [acc] KNIFE COUNTER (user 2026-07-05): he is WEAK to knifing - each knife does a FLAT 1/100 of his
    	// MAX health, so EXACTLY acc_avo_knife_hits (100) knives kill him at ANY round (independent of the
    	// incoming knife damage or his scaled HP). High-risk close-range counter (you eat the stun-lock to get in).
    	hits = getdvarint( "acc_avo_knife_hits", 100 );
    	if ( hits < 1 ) hits = 1;
    	mh = ( isdefined( self.maxhealth ) ? self.maxhealth : self.health );
    	damage = int( mh / hits );
    	if ( damage < 1 ) damage = 1;
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
	    // [acc] BULLET IMMUNITY REMOVED (user 2026-07-04): the BO2 Avogadro took damage ONLY from melee -
	    // this else-branch zeroed ALL non-melee damage. As a real boss he must be killable by GUNS (map
	    // rule: no bullet-sponge, a PaP'd weapon should drop him). Pass the incoming damage through; the
	    // hurt vox above stays. HP is Phantom-tier (huge), so it's still a proper boss fight.
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
			// [acc] H1 (review 2026-07-04): guard the attacker - self.attacker is engine-maintained and
			// can be undefined (non-attributed death), which would throw method-on-undefined on this
			// guaranteed death path. Our real boss rewards come from _acc_boss_avogadro::grant_drops anyway.
			if ( isdefined( self.attacker ) )
				self.attacker thread death_rewards(self.attacker);
			self.is_alive = 0;
			self PlaySound("avogadro_death");
			if( isdefined( level.musicSystem.currentState ) && level.musicSystem.currentState == "avogadro_theme" )
			{
				level thread zm_audio::sndMusicSystem_StopAndFlush();
				music::setmusicstate("none");
			}
			level.avogadros = 0;
			// [acc] C1 CRITICAL (review 2026-07-04): self.sfx is NEVER assigned (not in this pack, not in
			// stock), so this method-on-undefined threw on EVERY kill - aborting death() BEFORE Delete(),
			// leaving a frozen dead boss that kept zapping + re-hacking forever. Guarded. (The linger loop
			// sound is already stopped by avogadro_vfx's own StopLoopSound.)
			if ( isdefined( self.sfx ) )
				self.sfx StopLoopSound();
			self AnimScripted( "exit_anim", self.origin, self.angles, "ai_zombie_avogadro_exit" );
			self StopSounds();
			self PlaySound("vox_avogadro_depart_0"+randomintrange(1,7));
			self zombie_shared::DoNoteTracks( "exit_anim" );
			self.allowdeath = true;
			wait(0.05);
			self notify("avogadro_death");
			self Delete();
			return;   // [acc] STOP (user 2026-07-05): after Delete the old while(1) looped back to read self.health on the REMOVED entity every 0.01s = the "removed entity is not an entity" error wall (endon("death") never fires; the pack notifies "avogadro_death"). The redundant Delete cascade below is now dead code.
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
	// [acc] NO rewards during the Paradise final battle (review 2026-07-15, rule from user 2026-06-26): the
	// wave Avogadro (_acc_paradise::maybe_spawn_avogadro) is a THREAT, not a loot pinata. The generic horde
	// drops are blocked by acc_paradise::block_powerup_drop, but that hook is only consulted on the random
	// on-kill path - zm_powerups::specific_powerup_drop spawns DIRECTLY and bypasses it, so this forced drop
	// has to be gated here, exactly like nsz_brutus.gsc:738 and _acc_elites::drop_recursion_powerup_at. This
	// was the last forced drop in the codebase still missing the guard: a free Max Ammo trivially defeated
	// the finale's ammo-scarcity pressure (the whole point of the single scripted 1:45 Max Ammo in
	// _acc_paradise). The 1000 points go with it - suppressing boss POINTS on the onslaught is what the
	// sibling reward paths already do (_acc_boss::grant_unified_boss_reward and this boss's own
	// _acc_boss_avogadro::grant_drops both early-return on the same flag). Self-clears on win/wipe.
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
		return;

	self zm_score::add_to_player_score( 1000 );
	powerup = zm_powerups::get_valid_powerup();
	power_up_origin = level.avogadro_death_origin;
	if( isdefined( power_up_origin ) )
	{
		level thread zm_powerups::specific_powerup_drop( "full_ammo", power_up_origin );
	}
	// [acc] REMOVED the buggy `wait(2); power_up_origin Delete();` (user 2026-07-04): power_up_origin is
	// level.avogadro_death_origin, a VECTOR (set in death()), so Delete() on a non-entity throws at
	// runtime. It only began firing now that the boss can actually die (bullet immunity removed). The
	// full_ammo drop above is a kept bonus; the real boss rewards (item/bottle/shards) come from
	// _acc_boss_avogadro::grant_drops.
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