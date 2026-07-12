// Decompiled by Serious. Credits to Scoba for his original tool, Cerberus, which I heavily upgraded to support remaining features, other games, and other platforms.
#insert scripts\shared\shared.gsh;
#using scripts\codescripts\struct;
#using scripts\shared\util_shared;
#using scripts\shared\clientfield_shared;
#using scripts\zm\_zm_stats;
// [acc] Krauss Refibrillator PaP revive (user 2026-07-11) needs these two stock modules.
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_laststand;

#define RETRIEVE_TRIGGER_HEIGHT 100
#define RETRIEVE_TRIGGER_RADIUS 50

#namespace _zm_weap_ballistic_knife;

// [acc] SELF-REGISTRATION (2026-07-11). Nothing in stock ever calls this file's init() (verified: stock
// _zm_weapons.gsc only takes &on_spawn / &on_spawn_retrieve_trigger pointers), so do the setup from an
// autoexec (the freezegun self-registration precedent). Two jobs:
//  1) level.ballistic_knife_autorecover default (init() below is dead code kept for pack fidelity).
//  2) Register the BERZERKER twin names as retrievable knives. Stock hardcodes watchers for
//     knife_ballistic + knife_ballistic_upgraded ONLY (_zm_weapons.gsc:509-510); while the Berzerker
//     implant is active the variant engine swaps the held knife to knife_ballistic[_upgraded]_acc_brz
//     (+35% stab speed twins, _acc_weapon_variants), and WITHOUT their own watchers a thrown brz knife
//     would never spawn its retrievable model/pickup. add_retrievable_knife_init_name just appends to
//     level.retrievable_knife_init_names, read per-player at connect - autoexec is early enough.
function autoexec acc_bk_setup()
{
	if(!isdefined(level.ballistic_knife_autorecover))
	{
		level.ballistic_knife_autorecover = 1;
	}
	zm_weapons::add_retrievable_knife_init_name( "knife_ballistic_acc_brz" );
	zm_weapons::add_retrievable_knife_init_name( "knife_ballistic_upgraded_acc_brz" );
}

// [acc] The Krauss-revive gate: is this watcher's weapon the PaP form? NAME-based (NOT
// zm_weapons::is_weapon_upgraded) because the Berzerker twin knife_ballistic_upgraded_acc_brz is a
// weaponfull clone that is NOT in the CSV upgrade table - is_weapon_upgraded() returns false for it,
// which would silently kill the revive while the implant is active. Every PaP-form name (canonical +
// twins) contains "knife_ballistic_upgraded"; no base-form name does.
function acc_bk_is_pap_form( weapon )
{
	if ( !isdefined( weapon ) || !isdefined( weapon.name ) ) return false;
	return IsSubStr( weapon.name, "knife_ballistic_upgraded" );
}

function init()
{
	if(!isdefined(level.ballistic_knife_autorecover))
	{
		level.ballistic_knife_autorecover = 1;
	}
}

function on_spawn(watcher, player)
{
	player endon("death");
	player endon("disconnect");
	player endon("zmb_lost_knife");
	level endon("game_ended");
	self waittill("stationary", endpos, normal, angles, attacker, prey, bone);
	isfriendly = 0;
	if(isdefined(endpos))
	{
		retrievable_model = spawn("script_model", endpos);
		retrievable_model setmodel("wpn_t7_loot_ballistic_knife_projectile");
		retrievable_model setowner(player);
		retrievable_model.owner = player;
		retrievable_model.angles = angles;
		retrievable_model.weapon = watcher.weapon;
		if(isdefined(prey))
		{
			if(isplayer(prey) && player.team == prey.team)
			{
				isfriendly = 1;
				// [acc] KRAUSS REFIBRILLATOR (user 2026-07-11; PaP = tier-2 transform per user, revive
				// ONLY on the _upgraded form): stick a DOWNED teammate with the PaP ballistic knife and
				// they instantly, fully revive (jugg health, weapons restored, shooter credited).
				// acc_bk_is_pap_form = name gate covering the canonical PaP form + its Berzerker twin
				// (is_weapon_upgraded misses the twin - see the helper). zm_laststand::remote_revive is
				// a safe no-op if `prey` isn't actually in laststand, so a hit on a healthy teammate
				// just bounces off as before. Instant + unlimited Krauss range come free from the stock
				// revive path. Spike/design: docs/04_weapons.md (Ballistic Knife), CHANGELOG 2026-07-11.
				if ( prey != player && acc_bk_is_pap_form( watcher.weapon ) )
				{
					prey zm_laststand::remote_revive( player );
				}
			}
			else if(isai(prey) && player.team == prey.team)
			{
				isfriendly = 1;
			}
			if(!isfriendly)
			{
				// [acc] BOSS-STICK GUARD (2026-07-11): never linkto a boss/mini-boss - a boss whose exit
				// path skips the "death" notify would strand the knife model + pickup trigger on a freed
				// entity (force_drop_knives_to_ground_on_death waits on prey "death"). Bounce off like a
				// friendly hit instead; the knife still lands and stays retrievable at the boss's feet.
				if ( IS_TRUE( prey.acc_is_boss ) || IS_TRUE( prey.acc_is_mini_boss ) )
				{
					isfriendly = 1;   // reuse the friendly bounce+settle path below
					retrievable_model physicslaunch((0, 0, 1), (randomint(10), randomint(10), randomint(10)));
					normal = (0, 0, 1);
				}
				else
				{
					retrievable_model linkto(prey, bone);
					retrievable_model thread force_drop_knives_to_ground_on_death(player, prey);
				}
			}
			else if(isfriendly)
			{
				retrievable_model physicslaunch(normal, (randomint(10), randomint(10), randomint(10)));
				normal = (0, 0, 1);
			}
		}
		// [acc] KRAUSS PROXIMITY FALLBACK (2026-07-11, review defensive add): the direct revive above
		// depends on the engine reporting the downed CRAWLING teammate as `prey` - very likely but not
		// provable without a live co-op test (this ships without one). A PaP knife landing NEAR a downed
		// teammate (over-flew the low crawl silhouette, stuck the wall/floor behind) revives them too:
		// prey-independent scan of endpos. Runs ONLY when the direct path above did NOT already handle a
		// friendly player (mutual exclusion - no same-frame double remote_revive on one target), and
		// remote_revive self-guards player_is_in_laststand so healthy/off-target players are a no-op.
		if ( acc_bk_is_pap_form( watcher.weapon )
		     && ( !isdefined( prey ) || !isplayer( prey ) || player.team != prey.team ) )
		{
			a_players = GetPlayers();
			foreach ( p in a_players )
			{
				if ( !isdefined( p ) || p == player ) continue;             // disconnect-snapshot guard
				if ( !isdefined( p.team ) || p.team != player.team ) continue;
				if ( Distance( endpos, p.origin ) > 128 ) continue;
				p zm_laststand::remote_revive( player );
			}
		}
		watcher.objectarray[watcher.objectarray.size] = retrievable_model;
		if(isfriendly)
		{
			retrievable_model waittill("stationary");
		}
		retrievable_model thread drop_knives_to_ground(player);
		if(isfriendly)
		{
			player notify("ballistic_knife_stationary", retrievable_model, normal);
		}
		else
		{
			player notify("ballistic_knife_stationary", retrievable_model, normal, prey);
		}
	}
}

function on_spawn_retrieve_trigger(watcher, player)
{
	player endon("death");
	player endon("disconnect");
	player endon("zmb_lost_knife");
	level endon("game_ended");
	player waittill("ballistic_knife_stationary", retrievable_model, normal, prey);
	if(!isdefined(retrievable_model))
	{
		return;
	}
	vec_scale = 10;
	trigger_pos = [];
	if ( isdefined( prey ) && ( isPlayer( prey ) || isAI( prey ) ) )
	{
		trigger_pos[0] = prey.origin[0];
		trigger_pos[1] = prey.origin[1];
		trigger_pos[2] = prey.origin[2] + vec_scale;
	}
	else
	{
		trigger_pos[0] = retrievable_model.origin[0] + (vec_scale * normal[0]);
		trigger_pos[1] = retrievable_model.origin[1] + (vec_scale * normal[1]);
		trigger_pos[2] = retrievable_model.origin[2] + (vec_scale * normal[2]);
	}
	
	//This highlights the model
	retrievable_model clientfield::set( "retrievable", 1 );
	
    // I know it's jank but not sure why it breaks otherwhise
	if(isdefined(level.ballistic_knife_autorecover) && level.ballistic_knife_autorecover)
	{
	    trigger_pos[2] -= RETRIEVE_TRIGGER_HEIGHT / 2;
		pickup_trigger = spawn( "trigger_radius", (trigger_pos[0], trigger_pos[1], trigger_pos[2]), 0, RETRIEVE_TRIGGER_RADIUS, RETRIEVE_TRIGGER_HEIGHT );
	}
	else
	{
	    trigger_pos[2] -= RETRIEVE_TRIGGER_HEIGHT / 2;
		pickup_trigger = spawn( "trigger_radius", (trigger_pos[0], trigger_pos[1], trigger_pos[2]), 0, RETRIEVE_TRIGGER_RADIUS, RETRIEVE_TRIGGER_HEIGHT );
	}
	pickup_trigger.owner = player;
	retrievable_model.retrievabletrigger = pickup_trigger;
	// [acc] Localized hint FIX (2026-07-11 review): the pack's &"WEAPON_BALLISTIC_KNIFE_PICKUP" token
	// exists in NO .str of this project, and the isdefined() guard below it was dead code (a &"..."
	// reference is always defined) - the prompt rendered the raw token. Our tokens live in
	// localizedstrings/zm_aetherium.str, whose keys the T7 compiler prefixes with the FILENAME
	// (memory killfeed-str-prefix): REFERENCE BK_PICKUP -> in-game ZM_AETHERIUM_BK_PICKUP. Text avoids
	// the LUI cursor-hint router's catch-all words (memory lui-cursorhint-router-loose-weapon-matcher).
	pickup_trigger sethintstring( &"ZM_AETHERIUM_BK_PICKUP" );
	pickup_trigger setteamfortrigger(player.team);
	player clientclaimtrigger(pickup_trigger);
	pickup_trigger enablelinkto();
	if(isdefined(prey))
	{
		pickup_trigger linkto(prey);
	}
	else
	{
		pickup_trigger linkto(retrievable_model);
	}
	if(isdefined(level.knife_planted))
	{
		[[level.knife_planted]](retrievable_model, pickup_trigger, prey);
	}
	retrievable_model thread watch_use_trigger(pickup_trigger, retrievable_model, &pick_up, watcher.weapon, watcher.pickupsoundplayer, watcher.pickupsound);
	player thread watch_shutdown(pickup_trigger, retrievable_model);
}

function watch_use_trigger(trigger, model, callback, weapon, playersoundonuse, npcsoundonuse)
{
	self endon("death");
	self endon("delete");
	level endon("game_ended");
	max_ammo = weapon.maxammo + 1;
	autorecover = isdefined(level.ballistic_knife_autorecover) && level.ballistic_knife_autorecover;
	while(true)
	{
		trigger waittill("trigger", player);
		if(!isalive(player))
		{
			continue;
		}
		if(!player isonground() && (!(isdefined(trigger.force_pickup) && trigger.force_pickup)))
		{
			continue;
		}
		if(isdefined(trigger.triggerteam) && player.team != trigger.triggerteam)
		{
			continue;
		}
		if(isdefined(trigger.claimedby) && player != trigger.claimedby)
		{
			continue;
		}
		ammo_stock = player getweaponammostock(weapon);
		ammo_clip = player getweaponammoclip(weapon);
		current_weapon = player getcurrentweapon();
		total_ammo = ammo_stock + ammo_clip;
		
		// see if this player hasn't reloaded yet, we make this check so you can't pick it up before your stock ammo has updated
		//	if your stock ammo hasn't updated then you'll take it but you won't get it in your reserves, it just goes away
		hasReloaded = true;
		if ( total_ammo > 0 && ammo_stock == total_ammo )
			hasReloaded = false;

		if ( total_ammo >= max_ammo || !hasReloaded )
			continue;

		if ( isdefined( playerSoundOnUse ) )
			player playLocalSound( playerSoundOnUse );
		if ( isdefined( npcSoundOnUse ) )
			player playSound( npcSoundOnUse );
			player thread [[callback]](weapon, model, trigger);
			break;
	}
}

function pick_up(weapon, model, trigger)
{
	if(self hasweapon(weapon))
	{
		current_weapon = self getcurrentweapon();
		if(current_weapon != weapon)
		{
			clip_ammo = self getweaponammoclip(weapon);
			if(!clip_ammo)
			{
				self setweaponammoclip(weapon, 1);
			}
			else
			{
				new_ammo_stock = self getweaponammostock(weapon) + 1;
				self setweaponammostock(weapon, new_ammo_stock);
			}
		}
		else
		{
			new_ammo_stock = self getweaponammostock(weapon) + 1;
			self setweaponammostock(weapon, new_ammo_stock);
		}
	}
	self zm_stats::increment_client_stat("ballistic_knives_pickedup");
	self zm_stats::increment_player_stat("ballistic_knives_pickedup");
	model destroy_ent();
	trigger destroy_ent();
}

function destroy_ent()
{
	if(isdefined(self))
	{
		self delete();
	}
}

function watch_shutdown(trigger, model)
{
	self util::waittill_any("death", "disconnect", "zmb_lost_knife");
	trigger destroy_ent();
	model destroy_ent();
}

function drop_knives_to_ground(player)
{
	player endon("death");
	player endon("zmb_lost_knife");
	for(;;)
	{
		level waittill("drop_objects_to_ground", origin, radius);
		if(distancesquared(origin, self.origin) < (radius * radius))
		{
			self physicslaunch((0, 0, 1), vectorscale((1, 1, 1), 5));
			self thread update_retrieve_trigger(player);
		}
	}
}

function force_drop_knives_to_ground_on_death(player, prey)
{
	self endon("death");
	player endon("zmb_lost_knife");
	prey waittill("death");
	self unlink();
	self physicslaunch((0, 0, 1), vectorscale((1, 1, 1), 5));
	self thread update_retrieve_trigger(player);
}

function update_retrieve_trigger(player)
{
	self endon("death");
	player endon("zmb_lost_knife");
	if(isdefined(level.custom_update_retrieve_trigger))
	{
		self [[level.custom_update_retrieve_trigger]](player);
		return;
	}
	self waittill("stationary");
	trigger = self.retrievabletrigger;
	trigger.origin = (self.origin[0], self.origin[1], self.origin[2] + 10);
	trigger linkto(self);
}
