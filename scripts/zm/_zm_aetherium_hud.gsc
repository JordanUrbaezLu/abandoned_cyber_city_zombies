#using scripts\codescripts\struct;

#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\exploder_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\laststand_shared;
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\aat_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_score;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;
#insert scripts\zm\_zm_utility.gsh;

// Kill feed string precache
#precache( "string", "ZM_AETHERIUM_KF_ELIMINATION" );
#precache( "string", "ZM_AETHERIUM_KF_CRITICAL" );
#precache( "string", "ZM_AETHERIUM_KF_MELEE" );
#precache( "string", "ZM_AETHERIUM_KF_BURNED" );
#precache( "string", "ZM_AETHERIUM_KF_BLAST_FURNACE" );
#precache( "string", "ZM_AETHERIUM_KF_DEAD_WIRE" );
#precache( "string", "ZM_AETHERIUM_KF_FIRE_WORKS" );
#precache( "string", "ZM_AETHERIUM_KF_THUNDER_WALL" );
#precache( "string", "ZM_AETHERIUM_KF_TURNED" );
#precache( "string", "ZM_AETHERIUM_KF_ZOMBIE_DOG" );
#precache( "string", "ZM_AETHERIUM_KF_ROCKET_SHIELD" );
#precache( "string", "ZM_AETHERIUM_KF_GRENADE" );
#precache( "string", "ZM_AETHERIUM_KF_MONKEY_BOMB" );
#precache( "string", "ZM_AETHERIUM_KF_LIL_ARNIE" );
#precache( "string", "ZM_AETHERIUM_KF_RAGNAROK_DG4" );

#namespace zm_aetherium_hud;

REGISTER_SYSTEM_EX( "zm_aetherium_hud", &__init__, &__main__, undefined )

function __init__()
{
	// Register health clientfield for each player using world (vanilla pattern)
	// ACC: pinned to 4 (4-player map). The kit's GetDvarInt("com_maxclients") loop is a
	// registration-count landmine: the .gsc and .csc MUST register the identical field list
	// (order/width/count) or the world-scope clientfield bit layout desyncs, and a large
	// maxclients dvar burns 7 world-pool bits per phantom player.
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_health_" + i, VERSION_SHIP, 7, "float" );
	}
	
	// Register packed player states clientfield (all 4 players in 1 field)
	// 8 bits total: Player 0 (bits 0-1), Player 1 (bits 2-3), Player 2 (bits 4-5), Player 3 (bits 6-7)
	// Each player uses 2 bits: 0=alive, 1=downed, 2=dead
	clientfield::register( "world", "player_states_packed", VERSION_SHIP, 8, "int" );

	// ACC (2026-07-03, user: "show the shards for each player in co-op"): per-player Data Shard
	// count BROADCAST to everyone via WORLD scope (10 bits, <=1023) - same lane as player_health_N
	// so the party-member widgets (AetheriumPartyPlayers) can show each TEAMMATE's shards. (The
	// LOCAL player's own shards stay on the private toplayer acc_shards field below.) Appended
	// AFTER player_states_packed - MUST match the .csc's world-scope order exactly.
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_shards_" + i, VERSION_SHIP, 10, "int" );
	}

	// ACC (2026-07-04, user: "add Mega Bottles + Exo Suit Lv per teammate too"): per-player MB (5 bits,
	// <=31) + EXO tier (4 bits, <=15) BROADCAST world-scope, same lane as player_shards_N, so the party
	// widgets show each TEAMMATE's count. Appended AFTER player_shards - mb 0..3 THEN exo 0..3 - and the
	// .csc MUST register in this EXACT order/width or the world-scope bit layout desyncs.
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_mb_" + i, VERSION_SHIP, 5, "int" );
	}
	for( i = 0; i < 4; i++ )
	{
		clientfield::register( "world", "player_exo_" + i, VERSION_SHIP, 4, "int" );
	}

	// ACC CURRENCIES -> the base HUD (2026-07-03, user: "incorporate all our currencies").
	// Data Shards + Mega Bottles (+ EXO tier) ride TOPLAYER-scope clientfields - per-player
	// private, a SEPARATE pool from both the FULL clientuimodel pool (docs/22) and the world
	// fields above. The .csc mirror pipes them into the "acc_shards"/"acc_mb"/"acc_exo" UI
	// models that AetheriumPlayerInfo (panel row) reads. MUST stay in lockstep with the .csc
	// (same order/width/type). Widths cap the pushed values: shards<=1023, MB<=31, EXO<=15
	// (player_currency_watch clamps).
	clientfield::register( "toplayer", "acc_shards", VERSION_SHIP, 10, "int" );
	clientfield::register( "toplayer", "acc_mb", VERSION_SHIP, 5, "int" );
	clientfield::register( "toplayer", "acc_exo", VERSION_SHIP, 4, "int" );
	// ACC (2026-07-03, user: HP text -> real max, 300 on Mega Jugg): the local player's max
	// health (100 / 250 / 300; the health clientfield is only a FRACTION). 9 bits (<=511) fits
	// 300. Appended LAST in the toplayer scope - MUST match the .csc order.
	clientfield::register( "toplayer", "acc_maxhp", VERSION_SHIP, 9, "int" );
	// ACC GUN BADGES (2026-07-08, user: "unify the gun-HUD badges"): FLAG badges for the HELD
	// weapon, ONE bitmask driving acc_hud.lua's CoD.AccGunBadgeRow (the unified chip row under
	// the ammo readout; TIER badges PaP/OC keep riding their existing accPapTier/accOcTier
	// clientuimodel fields). COMPUTED + PUSHED by _acc_gun_badges.gsc (registry of predicates,
	// threaded from _acc_main::on_player_connect); this file only REGISTERS the field so the
	// toplayer bit layout stays in lockstep with the other currency fields. Same toplayer->uimodel
	// bridge as acc_shards (the clientuimodel pool is FULL, docs/11). 6 bits = room for 6 flag
	// badges. BIT TABLE (owned by _acc_gun_badges::init) - MUST match ACC_GUN_BADGES in acc_hud.lua:
	//   bit 0 = MULE    (held gun is the one Mule Kick removes on a down; was the 1-bit acc_mule
	//                    field 2026-07-06..08 - REPLACED in-place, .csc updated in lockstep)
	//   bit 1 = TURBO   (Turbocharger implanted AND the held gun is a Havoc, _acc_boss_items item 8)
	//   bit 2 = NUKE    (Nuclear Energy implanted AND held weapon is one it buffs, item 9)
	// Appended LAST in the toplayer scope - MUST match the .csc order.
	clientfield::register( "toplayer", "acc_badges", VERSION_SHIP, 6, "int" );

	// Register on_connect callback to start per-player health monitoring
	callback::on_connect( &on_player_connect );
}

function __main__()
{
	// ACC: honor the master flag (level.acc_aetherium_hud, _acc_lui.gsc __init__). All system
	// __init__s complete before any __main__ runs (run_post_systems asserts it), so the flag is
	// guaranteed set here. Clientfield REGISTRATION stays unconditional (__init__) either way.
	if ( !IS_TRUE( level.acc_aetherium_hud ) )
		return;

	// Main initialization

	// Override perk machine cursor hints (custom Lua notification handles display)
	level thread override_perk_hints();

	// Register zombie damage callback for kill feed
	// ACC DISARMED (2026-07-03, user: "+130 Elimination ... doesn't align with how many points
	// you actually get"): the kit computed feed values from STOCK scoring formulas, but this
	// map's kill money is fully custom (_acc_points.gsc: 70/110/100 base, 70/30 co-op split,
	// DP scaling, ledger bonus). The feed is now sent from _acc_points' payout sites with the
	// REAL paid amounts (send_kill_feed/kill_feed_text there). zombie_death_callback + its
	// helpers below are kept dormant as the kit-reference; restore by re-registering:
	//     zm::register_zombie_damage_override_callback(&zombie_death_callback);

	// Start player state monitoring
	level thread monitor_player_states();

	// ACC 4-PLAYER MOCKS (dev only, user 2026-07-03): animate the world player_health_N
	// clientfields for UNOCCUPIED slots so the Lua party mocks (AetheriumHud.lua
	// ACC_MOCK_PARTY) show live bars solo. States stay 0 = all mocks alive (user 2026-06-28
	// convention). Self-limits to empty slots, so it never fights a real player's feed.
	// MOCK PARTY FEED REMOVED FROM DEV 2026-07-10 (user: "remove the random debug UI, keep the screen clean") - dev is
	// now hardcoded ON, so this drove FAKE co-op teammate rows onto the party HUD every session. Re-thread to test the
	// co-op HUD roster. (Also the crash-hunt clientfield-spam suspect - memory crash-hunt-2026-07-10-state.)
	// if ( IS_TRUE( level.acc_dev ) )
	//     level thread mock_party_feed();
}

// ACC (dev-only): fake teammate health for the party-widget mocks. Slot 1 steady-high,
// slot 2 steady-mid, slot 3 drains/refills over 5s so a bar visibly SLIDES (the old
// roster demo's pattern).
function mock_party_feed()
{
	level endon( "end_game" );

	// [acc] CHANGE-GUARD EVERY SET (crash hunt 2026-07-10): this loop wrote 12 world clientfields
	// per second forever (health + shards + mb + exo x 3 mock slots @ 4Hz), even though only slot 3's
	// health actually changes. Every clientfield::set dirties the world snapshot for retransmit, so
	// the constant-value spam was pure churn on the already-tight world-field budget (and the prime
	// suspect for the corrupted configstring + delayed native CTD, exe+0x22c8f03). Each field now
	// writes ONLY when its value changes: shards/mb/exo once at start, slot 1/2 health once, slot 3
	// health only on real 4Hz drain ticks. Visual result is identical.
	sent = [];
	for( ;; )
	{
		wait 0.25;

		n_real = GetPlayers().size;
		for( i = n_real; i < 4; i++ )
		{
			if ( i < 1 )
				continue;
			if ( i == 1 )
				v = 0.8;
			else if ( i == 2 )
				v = 0.55;
			else
				v = 0.95 - 0.8 * ( ( GetTime() % 5000 ) / 5000 );

			key = "h" + i;
			if ( !isdefined( sent[ key ] ) || sent[ key ] != v )
			{
				level clientfield::set( "player_health_" + i, v );
				sent[ key ] = v;
			}
			// Fake shards / Mega Bottles / Exo Lv for the mock teammates - CONSTANT values, so
			// one write each on the first pass (slot occupancy changes re-send via the guard).
			if ( !isdefined( sent[ "s" + i ] ) || sent[ "s" + i ] != 100 + i * 75 )
			{
				level clientfield::set( "player_shards_" + i, 100 + i * 75 );
				sent[ "s" + i ] = 100 + i * 75;
			}
			if ( !isdefined( sent[ "m" + i ] ) || sent[ "m" + i ] != i * 2 + 1 )
			{
				level clientfield::set( "player_mb_" + i, i * 2 + 1 );
				sent[ "m" + i ] = i * 2 + 1;
			}
			if ( !isdefined( sent[ "e" + i ] ) || sent[ "e" + i ] != i + 1 )
			{
				level clientfield::set( "player_exo_" + i, i + 1 );
				sent[ "e" + i ] = i + 1;
			}
		}
	}
}

function on_player_connect()
{
	// ACC: master-flag gate (see __main__).
	if ( !IS_TRUE( level.acc_aetherium_hud ) )
		return;

	// ACC: safety clamp - only entity numbers 0..3 have a registered player_health_N world
	// clientfield (registration pinned to 4); a >=4 client would script-error on every set.
	if ( self GetEntityNumber() < 4 )
	{
		// Start per-player health monitoring thread
		self thread set_player_health_clientfield();
	}

	// Start third person toggle handler
	self thread menu_option_third_person_handler();

	// ACC: push the map's currencies (shards / mega bottles / exo tier) to this player's HUD
	self thread player_currency_watch();

	// ACC GUN BADGES: the per-player flag-badge watch moved to its own module 2026-07-08
	// (_acc_gun_badges.gsc - registry-driven predicates, threaded from _acc_main::on_player_connect).
	// This file keeps ONLY the `acc_badges` clientfield REGISTRATION (below, for toplayer bit-layout
	// lockstep with the other currency fields); the compute+push lives there now.
}

// ACC (2026-07-03): per-player currency feed for the base-HUD panel row. Change-guarded
// 0.25s poll of the same player fields the retired roster read (acc_data_shards /
// acc_mega_bottles / acc_exo_tier), clamped to the clientfield widths.
function player_currency_watch()
{
	self endon( "disconnect" );
	self notify( "acc_currency_watch" );
	self endon( "acc_currency_watch" );

	entnum = self GetEntityNumber();   // for the co-op shards broadcast (world player_shards_N)

	last_sh = -1;
	last_mb = -1;
	last_exo = -1;
	last_mhp = -1;
	while( true )
	{
		wait 0.25;

		sh = ( isdefined( self.acc_data_shards ) ? self.acc_data_shards : 0 );
		mb = ( isdefined( self.acc_mega_bottles ) ? self.acc_mega_bottles : 0 );
		exo = ( isdefined( self.acc_exo_tier ) ? self.acc_exo_tier : 0 );
		mhp = ( isdefined( self.maxhealth ) ? Int( self.maxhealth ) : 100 );   // real max HP for the HP readout
		if ( sh < 0 ) sh = 0;
		if ( sh > 1023 ) sh = 1023;
		if ( mb < 0 ) mb = 0;
		if ( mb > 31 ) mb = 31;
		if ( exo < 0 ) exo = 0;
		if ( exo > 15 ) exo = 15;
		if ( mhp < 0 ) mhp = 0;
		if ( mhp > 511 ) mhp = 511;

		if ( sh != last_sh )
		{
			self clientfield::set_to_player( "acc_shards", sh );   // private: my own panel
			// BROADCAST my shards so every client's party widget shows this player's count.
			if ( entnum < 4 )
				level clientfield::set( "player_shards_" + entnum, sh );
			last_sh = sh;
		}
		if ( mb != last_mb )
		{
			self clientfield::set_to_player( "acc_mb", mb );
			// BROADCAST my Mega Bottles so every client's party widget shows this teammate's count.
			if ( entnum < 4 )
				level clientfield::set( "player_mb_" + entnum, mb );
			last_mb = mb;
		}
		if ( exo != last_exo )
		{
			self clientfield::set_to_player( "acc_exo", exo );
			// BROADCAST my Exo Suit tier for the party widgets.
			if ( entnum < 4 )
				level clientfield::set( "player_exo_" + entnum, exo );
			last_exo = exo;
		}
		if ( mhp != last_mhp )
		{
			self clientfield::set_to_player( "acc_maxhp", mhp );
			last_mhp = mhp;
		}
	}
}

function set_world_clientfield( name, val )
{
	if( IS_EQUAL( level clientfield::get( name ), val ) )
	{
		return;
	}

	level clientfield::set( name, val );
}

function set_player_health_clientfield()
{
	self endon( "disconnect" );
	self notify( "set_player_health_clientfield" );
	self endon( "set_player_health_clientfield" );

	// ACC perf rework: the kit polled every server frame (50ms), rebuilt the field-name string
	// each tick, and deduped via `level clientfield::get` (a builtin call whose returned value
	// may be the QUANTIZED 7-bit float - comparing it to the raw fraction can miss, re-setting
	// every frame). Hoist the name once, cache the last raw value WE pushed, poll at 0.1s (the
	// retired roster's health cadence - visually identical for a bar).
	field_name = "player_health_" + self GetEntityNumber();
	last_health = -1;
	while( true )
	{
		wait 0.1;
		health = ( zm_utility::is_player_valid( self ) ? float( self.health / self.maxhealth ) : 0 );
		if ( health != last_health )
		{
			level clientfield::set( field_name, health );
			last_health = health;
		}
	}
}

function override_perk_hints()
{
	// Wait for game to start
	level flag::wait_till("initial_blackscreen_passed");
	
	// Don't modify perk triggers - keep hints active so cursorHintText model is populated
	// Lua will handle hiding default cursor hint visual and showing custom notification
}

//=============================================================================
// KILL FEED SYSTEM
//=============================================================================

function zombie_death_callback( death, inflictor, attacker, damage, flags, mod, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
	// ACC perf: this override callback is THREADED on EVERY zombie damage event (stock
	// _zm.gsc:5847-5857; returns are ignored), not just kills - bail before the 9-branch
	// chain on the overwhelmingly common non-lethal hit.
	if ( !IS_TRUE( death ) )
		return false;

	// Process both regular zombies and zombie dogs
	if( IsDefined( self ) && IS_EQUAL( self.team, level.zombie_team ) )
	{
		// Handle Rocket Shield kills FIRST (explosive projectile damage)
		if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && ( weapon.name == "zod_riotshield" || weapon.name == "zod_riotshield_upgraded" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_ROCKET_SHIELD";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Grenade kills (frag grenades ONLY - ACC fix: the kit's IsSubStr(name,"grenade")
		// hijacked Widow's Wine kills ("sticky_grenade_widows_wine") and any grenade-named
		// weapon away from the AAT/melee/headshot classification below)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && weapon.name == "frag_grenade" )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_GRENADE";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Monkey Bomb kills
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && weapon.name == "cymbal_monkey" )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_MONKEY_BOMB";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Li'l Arnie kills (BO3 octobomb)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && ( weapon.name == "octobomb" || weapon.name == "octobomb_upgraded" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_LIL_ARNIE";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Ragnarok DG-4 kills (gravity spikes specialist weapon)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( weapon ) && weapon.name == "hero_gravityspikes_melee" )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = level.zombie_vars["zombie_score_bonus_burn"];
			text = &"ZM_AETHERIUM_KF_RAGNAROK_DG4";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle zombie dog kills (check character model)
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IsDefined( self.model ) && IsSubStr( self.model, "hellhound" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			points = 0;
			text = &"ZM_AETHERIUM_KF_ZOMBIE_DOG";
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
		// Handle Fireworks weapon model kills (attacker is the floating weapon model)
		else if( death && IsDefined( attacker ) && IsDefined( attacker.b_aat_fire_works_weapon ) && attacker.b_aat_fire_works_weapon )
		{
			// Attacker is the Fireworks weapon model - credit the owner
			if( IsDefined( attacker.owner ) && IsPlayer( attacker.owner ) )
			{
				player_points = zm_score::get_zombie_death_player_points();
				points = level.zombie_vars["zombie_score_bonus_burn"];
				text = &"ZM_AETHERIUM_KF_FIRE_WORKS";
				
				player_points += points;
				player_points *= level.zombie_vars[attacker.owner.team]["zombie_point_scalar"];
				
				// Send to the player who owns the Fireworks weapon
				attacker.owner LuiNotifyEvent( &"score_event", 2, text, player_points );
			}
		}
		// Handle turned zombie kills (when turned zombie kills another zombie via melee)
		else if( death && IsDefined( attacker ) && IsDefined( attacker.aat_turned ) && attacker.aat_turned )
		{
			// Attacker is a turned zombie - need to find the player who turned it
			// Check all players to see who has this weapon with turned AAT
			players = GetPlayers();
			foreach( player in players )
			{
				// Check if this player could have turned the zombie
				// (turned zombies are within range of player who turned them)
				if( Distance( attacker.origin, player.origin ) < 2000 )
				{
					player_points = zm_score::get_zombie_death_player_points();
					points = level.zombie_vars["zombie_score_bonus_burn"];
					text = &"ZM_AETHERIUM_KF_TURNED";
					
					player_points += points;
					player_points *= level.zombie_vars[player.team]["zombie_point_scalar"];
					
					// Send to the player who turned the zombie
					player LuiNotifyEvent( &"score_event", 2, text, player_points );
					break; // Only credit one player
				}
			}
		}
		// Handle normal zombie kills (including AAT kills) - exclude dogs
		else if( death && IsDefined( attacker ) && IsPlayer( attacker ) && IS_EQUAL( self.team, level.zombie_team ) && IS_EQUAL( self.archetype, "zombie" ) )
		{
			player_points = zm_score::get_zombie_death_player_points();
			kill_bonus = get_kill_type_bonus( mod, sHitLoc, weapon, attacker, player_points );
			points = kill_bonus[0];
			text = kill_bonus[1];
			
			// Double points for insta-kill melee
			if( level.zombie_vars[attacker.team]["zombie_powerup_insta_kill_on"] == 1 && mod == "MOD_UNKNOWN" )
			{
				points *= 2;
			}
			
			player_points += points;
			player_points *= level.zombie_vars[attacker.team]["zombie_point_scalar"];
			
			// Send LUI notification to player
			attacker LuiNotifyEvent( &"score_event", 2, text, player_points );
		}
	}
	
	return false;
}

function get_kill_type_bonus( mod, hit_location, weapon, attacker, player_points = undefined )
{
	ret_val = array( 0, &"ZM_AETHERIUM_KF_ELIMINATION" );
	
	// Check for AAT kills - different AATs use different damage types:
	// - Blast Furnace, Dead Wire, Turned: MOD_UNKNOWN
	// - Thunder Wall: MOD_IMPACT
	// - Fireworks: weapon projectile damage (various types)
	if( IsDefined( attacker ) && IsDefined( weapon ) )
	{
		weapon = aat::get_nonalternate_weapon( weapon );
		aat_name = attacker.aat[weapon];
		
		// Check if this kill was caused by an AAT
		if( IsDefined( aat_name ) )
		{
			// Thunder Wall uses MOD_IMPACT damage
			if( aat_name == "zm_aat_thunder_wall" && mod == "MOD_IMPACT" )
			{
				ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
				ret_val[1] = &"ZM_AETHERIUM_KF_THUNDER_WALL";
				return ret_val;
			}
			// Most AATs use MOD_UNKNOWN - only show when AAT triggers
			else if( mod == "MOD_UNKNOWN" )
			{
				switch( aat_name )
				{
					case "zm_aat_blast_furnace":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_BLAST_FURNACE";
						return ret_val;
					
					case "zm_aat_dead_wire":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_DEAD_WIRE";
						return ret_val;
					
					case "zm_aat_turned":
						ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
						ret_val[1] = &"ZM_AETHERIUM_KF_TURNED";
						return ret_val;
					
					default:
						break;
				}
			}
		}
	}
	
	// Melee kill
	if( mod == "MOD_MELEE" )
	{
		ret_val[0] = level.zombie_vars["zombie_score_bonus_melee"];
		ret_val[1] = &"ZM_AETHERIUM_KF_MELEE";
		return ret_val;
	}
	
	// Burned kill
	if( mod == "MOD_BURNED" )
	{
		ret_val[0] = level.zombie_vars["zombie_score_bonus_burn"];
		ret_val[1] = &"ZM_AETHERIUM_KF_BURNED";
		return ret_val;
	}
	
	// Hit location bonuses
	if( IsDefined( hit_location ) )
	{
		switch( hit_location )
		{
			case "head":
			case "helmet":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_head"];
				ret_val[1] = &"ZM_AETHERIUM_KF_CRITICAL";
				break;
			
			case "neck":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_neck"];
				ret_val[1] = &"ZM_AETHERIUM_KF_ELIMINATION";
				break;
			
			case "torso_upper":
			case "torso_lower":
				ret_val[0] = level.zombie_vars["zombie_score_bonus_torso"];
				ret_val[1] = &"ZM_AETHERIUM_KF_ELIMINATION";
				break;
			
			default:
				break;
		}
	}
	
	return ret_val;
}

// Third Person Camera Toggle Handler (BO6 Overhaul Pattern)
function menu_option_third_person_handler()
{
	self endon( "disconnect" );
	self notify( "menu_option_third_person_handler" );
	self endon( "menu_option_third_person_handler" );
	
	while( true )
	{
		self waittill( "menuresponse", menu, response );
		
		split_string = strtok( response, "|" );
		option_name = split_string[0];
		option_value = split_string[1];
		
		if( IS_EQUAL( menu, "StartMenu_Main" ) && IS_EQUAL( option_name, "ui_menu_option_third_person" ) )
		{
			if( int( option_value ) == 1 )
			{
				// Enable third person with proper camera positioning
				// Range: 120 (camera distance from player - closer)
				// Height Offset: 30 (camera height above player)
				self setclientthirdperson( 1, 120, 30 );
			}
			else
			{
				// Disable third person
				self setclientthirdperson( 0 );
			}
		}
	}
}
function monitor_player_states()
{
	level endon( "end_game" );
	
	// Track last state to avoid unnecessary updates.
	// ACC fix: the kit initialized these to -1 and then OR'd ALL FOUR into the packed field -
	// in any sub-4-player game the unconnected slots' -1 made packed_value NEGATIVE (out of
	// range for the 8-bit clientfield; empty slots decoded as the undefined state 3). Init to
	// 0 ("alive" - harmless: absent slots are hidden by playerScoreShown in the Lua) and mask
	// each state to 2 bits when packing.
	level.player_last_states = [];
	level.player_last_states[0] = 0;
	level.player_last_states[1] = 0;
	level.player_last_states[2] = 0;
	level.player_last_states[3] = 0;
	
	while( true )
	{
		players = GetPlayers();
		state_changed = false;
		
		foreach( player in players )
		{
			entityNum = player GetEntityNumber();
			
			// Determine player state
			player_state = 0; // Default: Alive
			
			// Check dead/spectator FIRST (highest priority)
			if( player.sessionstate == "spectator" || 
			    player.sessionstate == "intermission" || 
			    player.sessionstate == "dead" )
			{
				player_state = 2; // Dead/Spectator
			}
			// Then check downed
			else if( player laststand::player_is_in_laststand() )
			{
				player_state = 1; // Downed
			}
			// else: player_state = 0 (Alive)
			
			// Only update if state changed
			if( player_state != level.player_last_states[entityNum] )
			{
				level.player_last_states[entityNum] = player_state;
				state_changed = true;
			}
		}
		
		// Pack all 4 player states into a single integer and send once
		// (ACC: & 3 masks keep the packed value in the 8-bit field's range no matter what a
		// slot holds - belt-and-suspenders with the 0-init fix above.)
		if( state_changed )
		{
			packed_value = 0;
			packed_value = packed_value | ( ( level.player_last_states[0] & 3 ) << 0 );  // Player 0: bits 0-1
			packed_value = packed_value | ( ( level.player_last_states[1] & 3 ) << 2 );  // Player 1: bits 2-3
			packed_value = packed_value | ( ( level.player_last_states[2] & 3 ) << 4 );  // Player 2: bits 4-5
			packed_value = packed_value | ( ( level.player_last_states[3] & 3 ) << 6 );  // Player 3: bits 6-7

			level clientfield::set( "player_states_packed", packed_value );
		}
		
		wait( 0.5 ); // Check twice per second
	}
}