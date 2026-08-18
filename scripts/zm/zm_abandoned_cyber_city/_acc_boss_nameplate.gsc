// =============================================================================
// _acc_boss_nameplate.gsc - boss HUD server feed: the LUI boss health-bar rows
// (the "accBoss1..5" controller UI-model feed) + boss client-FX pulse CFs.
//
// THE 3D PLATE IS REMOVED (user 2026-07-25 "remove the 3D name plate all
// around. The only indicator will be the right side boss bar") - after a full
// day of iterations (ASCII bar -> name-only -> styled identity-color chevrons)
// the engine's hostile-name TINT (title ^-colors multiply through
// ~{1.0,0.6,0.45}: white->peach, grey->salmon, blue->near-black) made true
// HUD<->world color matching impossible, so the plate is gone entirely. The
// module name is historical; restore any plate variant from git.
//
// The actor clientfields REMAIN REGISTERED (gsc/csc lockstep - removing a
// registration shifts the CF layout, the known load-crash class):
//   "acc_bnp_name" (3 bits) - boss identity index (name_to_index below). Still
//                   SET at attach(): the .csc callback uses it to STOMP any
//                   archetype-set floating name (the HB21 robot csc names the
//                   Rogue Protector "Civil Protector" at spawn - without the
//                   stomp that pack name would float over the boss).
//   "acc_bnp_hp"   (4 bits) - SPARE (registered, never written).
// Boss identity colors live in ONE place now: acc_hud.lua ACC_BB_BOSS_COLORS
// (name-keyed; Phantom gold-orange / Warden red / Avogadro sea-teal / Rogue
// Protector green / Panzer warm-taupe / Scientist peach).
//
// THE LUI BAR ROWS (2026-07-24): up to ACC_BB_SLOTS concurrent bosses render as
// stacked NAME-over-BAR rows in acc_hud.lua (CoD.AccBossBars, upper-right under
// the HOSTILES bar). Transport = per-player controller UI-models "accBoss1..5"
// (the accLevel/accLbR* channel: ZERO clientfield bits - all three CF pools are
// FULL - co-op replicated, spectate-safe). Payload per slot:
//     "<NAME>|<pct, 5% steps>|<state>[|r<n>]"
//     state 1 = alive, 0 = killed (Lua plays a flash+fade), 2 = clear/hide
// pct is QUANTIZED and payloads carry NO per-push uniquifier except in the
// per-life repush window (the |r<n> tag) - every unique string registers a
// finite client BGCACHE configstring (2026-07-25 live-log find; see bb_push_to
// / bb_pct_of). Steady pushes are change-guarded so they differ naturally.
// Slots are first-come; overflow bosses queue and backfill when a slot frees
// (queued bosses have NO indicator until a row frees - the plate is gone). Hooks: the
// "acc_boss_spawned" notify + the Brutus/Scientist direct attach() calls.
//
// Feeding it: the existing level notify "acc_boss_spawned" (boss, name) - the
// same hook the old 2D top-screen bar consumed (_acc_health_bars, now gated
// OFF by default via acc_boss_bar_2d) - plus Brutus's direct attach() call
// (he never emits the notify: it implies boss music). The Glitch Stalker's
// direct call is deliberately commented out (no boss UI by design, docs/22).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#define ACC_BB_SLOTS         5      // concurrent LUI bar rows (accBoss1..5 - model names, precaches and the Lua widget are in LOCKSTEP; 4 -> 5 user 2026-07-24 "increase to 5 rows max" with the Scientist joining)
#define ACC_BB_FREE_DELAY_MS 1200   // ms a killed boss's row stays reserved so the Lua death flash/fade plays before a queued boss reuses it

// One controller-model name per bar row - the _acc_leaderboard accLbR* precache recipe.
#precache( "lui_menu_data", "accBoss1" );
#precache( "lui_menu_data", "accBoss2" );
#precache( "lui_menu_data", "accBoss3" );
#precache( "lui_menu_data", "accBoss4" );
#precache( "lui_menu_data", "accBoss5" );

#namespace acc_boss_nameplate;

REGISTER_SYSTEM( "acc_boss_nameplate", &__init__, undefined )

function __init__()
{
	// Actor clientfields - the .csc half registers the same set with callbacks.
	clientfield::register( "actor", "acc_bnp_name", VERSION_SHIP, 3, "int" );
	clientfield::register( "actor", "acc_bnp_hp", VERSION_SHIP, 4, "int" );
	// Per-ATTACK pulses (2-bit counters; every increment fires the .csc callback -> the FX +
	// SFX play CLIENT-side). Server-side PlayFX/PlaySound on the actor proved dead/quiet
	// live (2026-07-03) - the same reason the perk glows render client-side (docs precedent).
	//   acc_bnp_shot  = GUN shot   -> energy muzzle flash + gun report
	//   acc_bnp_zap   = ZAP burst  -> electric burst FX + spark report (the two distinct attacks)
	//   acc_bnp_mahem = BIG SHOT   -> mahem explosion boom + burst FX (the Rogue Protector's 5th shot)
	clientfield::register( "actor", "acc_bnp_shot", VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "acc_bnp_zap", VERSION_SHIP, 2, "int" );
	clientfield::register( "actor", "acc_bnp_mahem", VERSION_SHIP, 2, "int" );

	// LUI boss-bar rows (CoD.AccBossBars). Kill-switch is a hardcoded level bool (the
	// level.acc_aetherium_hud pattern, docs/22) - NEVER a new dvar. false = no LUI rows
	// anywhere (the FX pulses + name-stomp CF keep working).
	level.acc_boss_bars_lui = true;
	level.acc_bb_boss    = [];   // slot -> boss actor. NEVER the occupancy test: a Delete()d
	                             // corpse reads undefined here while the slot is still OWED
	                             // a death push - the 2026-07-25 stuck-Phantom root cause.
	level.acc_bb_live    = [];   // slot -> OCCUPANCY flag (true = a boss owns this row). THE
	                             // authoritative test; only occupy/death/release/wipe flip it.
	level.acc_bb_name    = [];   // slot -> display name string
	level.acc_bb_pct     = [];   // slot -> last pushed health percent (change guard)
	level.acc_bb_dead_at = [];   // slot -> GetTime() of the death push (row reserved for the fade)
	level.acc_bb_queue   = [];   // overflow bosses waiting for a free slot ({boss,name} structs)
	level.acc_bb_seq     = 0;    // repush-tag counter (ONLY the per-life repush window stamps
	                             // payloads unique - see bb_push_to's BGCACHE note)
	level thread bb_pump();
	// Connect AND spawn both arm a repush (the _acc_leveling pattern - review fix
	// 2026-07-24): acc_hud opens per-player on CONNECT, and a mid-game joiner watching
	// an unengaged boss (stable pct = zero change-pushes) would otherwise see no rows
	// until their first spawn. The repush thread self-dedupes (notify/endon).
	callback::on_connect( &bb_on_player_connect );
	callback::on_spawned( &bb_on_player_spawned );

	level thread boss_spawned_listener();
}

// PUBLIC: pulse one boss GUN shot to every client (muzzle flash + gun report in the .csc callback).
// self/boss = the firing actor. 2-bit wrap: consecutive values always differ, so every shot fires.
function shot_pulse( boss )
{
	if ( !isdefined( boss ) )
		return;
	if ( !isdefined( boss.acc_bnp_shot_val ) )
		boss.acc_bnp_shot_val = 0;
	boss.acc_bnp_shot_val = ( boss.acc_bnp_shot_val + 1 ) % 4;
	boss clientfield::set( "acc_bnp_shot", boss.acc_bnp_shot_val );
}

// PUBLIC: pulse one boss ZAP to every client (electric burst FX + spark report in the .csc callback).
function zap_pulse( boss )
{
	if ( !isdefined( boss ) )
		return;
	if ( !isdefined( boss.acc_bnp_zap_val ) )
		boss.acc_bnp_zap_val = 0;
	boss.acc_bnp_zap_val = ( boss.acc_bnp_zap_val + 1 ) % 4;
	boss clientfield::set( "acc_bnp_zap", boss.acc_bnp_zap_val );
}

// PUBLIC: pulse one boss MAHEM big-explosive shot (mahem explosion boom + burst FX in the .csc).
function mahem_pulse( boss )
{
	if ( !isdefined( boss ) )
		return;
	if ( !isdefined( boss.acc_bnp_mahem_val ) )
		boss.acc_bnp_mahem_val = 0;
	boss.acc_bnp_mahem_val = ( boss.acc_bnp_mahem_val + 1 ) % 4;
	boss clientfield::set( "acc_bnp_mahem", boss.acc_bnp_mahem_val );
}

// Index table - MUST MATCH _acc_boss_nameplate.csc names[]. 0 = off.
function name_to_index( name )
{
	if ( !isdefined( name ) ) return 7;
	switch ( name )
	{
		case "PHANTOM":          return 1;
		case "PANZER":           return 2;   // 2026-07-08: repurposed the dead SUBROUTINE CORE slot - the 3-bit field is FULL and the Core's run_full_boss has been unreachable since 2026-06-22 (its notify now renders the generic 7 "BOSS" if ever resurrected). Widening the field needs LOCKSTEP gsc+csc registration edits. (Renamed from PANZER SOLDAT same day, user.)
		case "TRENCH WARDEN":    return 3;
		case "THE SCIENTIST":    return 4;   // 2026-07-24: repurposed the never-used GLITCH STALKER slot (the Glitch is unplated BY DESIGN, its attach is commented out - _acc_boss_glitch.gsc; the Panzer/Core precedent). The Scientist joins the boss UI per user "add the scientist in as well".
		case "ROGUE PROTECTOR":  return 5;   // the Civil Protector boss
		case "AVOGADRO":         return 6;   // the cyberhacker boss
		default:                 return 7;   // generic "BOSS"
	}
}

// Auto-attach for every boss that emits the shared notify (Phantom, Rogue
// Protector, Panzer, Avogadro; the Subroutine Core's emitter is unreachable
// dead code since 2026-06-22). Brutus calls attach() directly instead.
function boss_spawned_listener()
{
	level endon( "end_game" );
	for ( ;; )
	{
		level waittill( "acc_boss_spawned", boss, name );
		if ( isdefined( boss ) )
			attach( boss, name );
	}
}

// PUBLIC: register `boss` with the boss HUD - claims a CoD.AccBossBars LUI row
// (the ONLY boss indicator since 2026-07-25) + stomps any archetype-set floating
// name via the acc_bnp_name CF. Gate: acc_boss_nameplate_on (default 1; 0 = no
// boss HUD at all - grandfathered lever, docs/22).
function attach( boss, name )
{
	if ( getdvarint( "acc_boss_nameplate_on", 1 ) != 1 )
		return;
	if ( !isdefined( boss ) )
		return;
	// PARADISE ONSLAUGHT NO LONGER SUPPRESSES THE ROWS (user 2026-07-29 "bosses in
	// paradise get a health bar, same implementation as above trench"). The 2026-06-25
	// suppression protected the old TOP-CENTER 2D bar from stomping the survival
	// countdown; the LUI rows live upper-right and cap at ACC_BB_SLOTS, and the finale
	// wave maxes at 5 concurrent (Warden/Phantom/RP/Panzer/Avogadro) = exactly the row
	// budget. Boss MUSIC stays suppressed (_acc_boss::boss_music gates itself - the
	// "115" anthem owns the finale audio).

	// 3D plate REMOVED (2026-07-25): this CF set no longer renders a title - the .csc
	// callback SetDrawName("")s the actor, stomping pack-set names (the Rogue
	// Protector's "Civil Protector"). acc_bnp_hp is spare (registered, never written).
	boss clientfield::set( "acc_bnp_name", name_to_index( name ) );

	// LUI bar row: every attached boss claims a CoD.AccBossBars row. Routing through
	// attach() means BOTH feed paths (notify + Brutus/Scientist direct) and all the
	// gates above (dvar, Paradise onslaught) apply to the rows for free.
	bb_attach( boss, name );
}

// (hp_watch - the per-boss 4Hz hp-tenths streamer - REMOVED 2026-07-24: acc_bnp_hp is
// SPARE now (registered on both sides, never written); health lives on the LUI bars via
// bb_pump. Restore from git if the tenths stream is ever needed. Its hard-won
// !isdefined(self) Delete-without-death guard lives on in bb_is_dead below.)

// =============================================================================
// LUI boss-bar rows (2026-07-24) - the "accBoss1..5" controller UI-model feed.
//
// Server-owned slot lifecycle: attach() -> bb_attach() claims the lowest free
// slot (or queues on overflow); bb_pump() polls every live slot at 4 Hz and
// pushes "<NAME>|<pct>|<state>|<seq>" to EVERY player's controller model on
// change; death pushes state 0 (the Lua row flashes + fades), then the slot
// stays reserved ACC_BB_FREE_DELAY_MS before a queued boss backfills it.
// Death detection mirrors every despawn path the roster has (recon 2026-07-24):
// engine death (isalive false / health<=0), Delete()-without-death (Avogadro,
// Scientist escape, Paradise cleanup -> !isdefined), and the Avogadro's
// allowdeath=false rising exit (poll .is_alive == 0 - memory
// rising-death-boss-airborne-drop). The rows RUN through the Paradise onslaught
// since 2026-07-29 (user; the old wipe-on-flag contract is retired - docs/30).
// =============================================================================

// TRUE once `boss` should no longer show a live bar. Order matters: the
// !isdefined test MUST come first (any field access on a removed entity throws).
function bb_is_dead( boss )
{
	if ( !isdefined( boss ) )
		return true;
	if ( isdefined( boss.is_alive ) && boss.is_alive == 0 )
		return true;   // Avogadro logical death during the airborne exit rise
	if ( isdefined( boss.health ) && boss.health <= 0 )
		return true;
	if ( !isalive( boss ) )
		return true;
	return false;
}

// Health percent in 5% STEPS (2..100 while alive - the "alive never shows an empty
// bar" floor, same rule as the plate's old tenths). Divide BEFORE scaling: GSC
// int/int yields a float, and health*100 could overflow int32 on deep-round pools.
// WHY QUANTIZED (live log find, 2026-07-25): every UNIQUE payload string registers
// a BGCACHE configstring on the client (console_mp.log "Registering configstring
// index N with data PHANTOM|67|1|147" - 594 registrations in ~3 min of boss
// fighting, indices only rarely reused). That pool is finite and its exhaustion
// class is a known CTD (docs/22 #6). 5% steps cap the distinct strings per boss
// life at ~22, and identical strings re-register nothing.
function bb_pct_of( boss )
{
	if ( !isdefined( boss.health ) || !isdefined( boss.maxhealth ) || boss.maxhealth <= 0 )
		return 100;
	pct = int( ( boss.health / boss.maxhealth ) * 100 );
	if ( pct > 100 ) pct = 100;
	if ( pct < 0 ) pct = 0;
	pct = int( pct / 5 ) * 5;
	if ( boss.health > 0 && pct < 2 ) pct = 2;
	return pct;
}

// Lowest slot that is neither live nor reserved for a death fade; -1 = none.
// OCCUPANCY = the acc_bb_live flag, NEVER isdefined(acc_bb_boss[i]) - a Delete()d
// boss's reference reads undefined while its slot still owes the death push.
function bb_free_slot()
{
	for ( i = 0; i < ACC_BB_SLOTS; i++ )
	{
		if ( !IS_TRUE( level.acc_bb_live[ i ] ) && !isdefined( level.acc_bb_dead_at[ i ] ) )
			return i;
	}
	return -1;
}

// Called from attach() for every plated boss (gates already applied there).
function bb_attach( boss, name )
{
	if ( !IS_TRUE( level.acc_boss_bars_lui ) )
		return;
	if ( !isdefined( boss ) )
		return;
	if ( !isdefined( name ) )
		name = "BOSS";

	// Dedupe: a boss already slotted or queued never gets a second row (attach()
	// can be reached twice for one actor if a module both notifies and calls in).
	for ( i = 0; i < ACC_BB_SLOTS; i++ )
	{
		if ( isdefined( level.acc_bb_boss[ i ] ) && level.acc_bb_boss[ i ] == boss )
			return;
	}
	for ( i = 0; i < level.acc_bb_queue.size; i++ )
	{
		q = level.acc_bb_queue[ i ];
		if ( isdefined( q ) && isdefined( q.boss ) && q.boss == boss )
			return;
	}

	slot = bb_free_slot();
	if ( slot >= 0 )
	{
		bb_occupy( slot, boss, name );
	}
	else
	{
		q = SpawnStruct();
		q.boss = boss;
		q.name = name;
		level.acc_bb_queue[ level.acc_bb_queue.size ] = q;
	}
}

function bb_occupy( slot, boss, name )
{
	level.acc_bb_boss[ slot ]    = boss;
	level.acc_bb_live[ slot ]    = true;
	level.acc_bb_name[ slot ]    = name;
	level.acc_bb_pct[ slot ]     = bb_pct_of( boss );
	level.acc_bb_dead_at[ slot ] = undefined;
	bb_push_all( slot, name, level.acc_bb_pct[ slot ], 1 );
}

// PUBLIC: gracefully drop `boss`'s bar row (or queue entry) WITHOUT the kill
// flash - a state-2 hide - for despawns that are NOT deaths (the Scientist's
// ESCAPE Delete()s him alive; a kill-pop there would read as a false kill).
// Call BEFORE the Delete(). Freed slots backfill from the queue in bb_pump.
function bb_release( boss )
{
	if ( !isdefined( boss ) )
		return;
	for ( i = 0; i < ACC_BB_SLOTS; i++ )
	{
		if ( isdefined( level.acc_bb_boss[ i ] ) && level.acc_bb_boss[ i ] == boss )
		{
			level.acc_bb_boss[ i ]    = undefined;
			level.acc_bb_live[ i ]    = false;
			level.acc_bb_dead_at[ i ] = undefined;
			bb_push_all( i, "", 0, 2 );
			return;
		}
	}
	fresh = [];
	for ( i = 0; i < level.acc_bb_queue.size; i++ )
	{
		q = level.acc_bb_queue[ i ];
		if ( isdefined( q ) && isdefined( q.boss ) && q.boss != boss )
			fresh[ fresh.size ] = q;
	}
	level.acc_bb_queue = fresh;
}

// Push one slot's payload to every connected player.
function bb_push_all( slot, name, pct, state )
{
	players = GetPlayers();
	for ( i = 0; i < players.size; i++ )
	{
		p = players[ i ];
		if ( isdefined( p ) && isplayer( p ) )
			bb_push_to( p, slot, name, pct, state );
	}
}

// Payload = "<NAME>|<pct>|<state>" with NO per-push uniquifier (BGCACHE find,
// 2026-07-25: every unique string burns a client configstring registration -
// the old always-bumped seq made EVERY push a fresh registration, ~594 in 3
// minutes of boss fighting; identical strings cost nothing). Steady-state
// pushes are naturally unique when it matters (the pct change-guard means
// consecutive alive pushes always differ; a death/clear push differs from the
// alive value it replaces). The ONE case needing forced uniqueness - identical
// re-sends into a freshly reopened menu - passes `tag` (the repush window).
function bb_push_to( player, slot, name, pct, state, tag )
{
	payload = name + "|" + pct + "|" + state;
	if ( isdefined( tag ) )
		payload = payload + "|" + tag;
	player SetControllerUIModelValue( "accBoss" + ( slot + 1 ), payload );
}

// Wipe every row + the queue. state 2 = hide immediately (no death flash).
// CURRENTLY UNCALLED (2026-07-29): its one caller was bb_pump's paradise-onslaught
// tick, retired when the user asked for bars through the finale - kept for any
// future suppression window (it is the only correct all-rows teardown).
function bb_wipe_all()
{
	for ( i = 0; i < ACC_BB_SLOTS; i++ )
	{
		had = ( IS_TRUE( level.acc_bb_live[ i ] ) || isdefined( level.acc_bb_dead_at[ i ] ) );
		level.acc_bb_boss[ i ]    = undefined;
		level.acc_bb_live[ i ]    = false;
		level.acc_bb_dead_at[ i ] = undefined;
		if ( had )
			bb_push_all( i, "", 0, 2 );
	}
	level.acc_bb_queue = [];
}

// The central 4 Hz slot poller - one level thread owns every slot's lifecycle
// (there are no per-boss threads in this system; hp_watch is gone).
function bb_pump()
{
	level endon( "end_game" );

	if ( !IS_TRUE( level.acc_boss_bars_lui ) )
		return;

	for ( ;; )
	{
		wait 0.25;

		// (The paradise-onslaught bb_wipe_all() tick lived here 2026-07-24..29; the rows
		// now RUN through the finale - see the attach() note. bb_wipe_all is kept below
		// for any future suppression window.)

		// Prune queued bosses that died (or were Delete()d) while waiting.
		fresh = [];
		for ( i = 0; i < level.acc_bb_queue.size; i++ )
		{
			q = level.acc_bb_queue[ i ];
			if ( isdefined( q ) && isdefined( q.boss ) && !bb_is_dead( q.boss ) )
				fresh[ fresh.size ] = q;
		}
		level.acc_bb_queue = fresh;

		for ( i = 0; i < ACC_BB_SLOTS; i++ )
		{
			// Dying row: hold it through the Lua fade, then free (the free-slot
			// branch below backfills next tick).
			if ( isdefined( level.acc_bb_dead_at[ i ] ) )
			{
				if ( GetTime() - level.acc_bb_dead_at[ i ] >= ACC_BB_FREE_DELAY_MS )
				{
					level.acc_bb_dead_at[ i ] = undefined;
					// BELT-AND-BRACES (user 2026-07-24 "the phantom bar never went away"):
					// hard-hide the row (state 2) now that the fade window is over, so a
					// death payload that was missed/mis-ordered client-side can NEVER
					// strand a visible row. A queued boss's state-1 backfill push re-arms
					// the row right after (pushes deliver in order, or coalesce to the
					// last - correct either way).
					bb_push_all( i, "", 0, 2 );
				}
				continue;
			}

			if ( !IS_TRUE( level.acc_bb_live[ i ] ) )
			{
				// FREE slot (death-freed, bb_release'd, or never used): backfill from
				// the overflow queue. Centralized here (2026-07-24, with bb_release) so
				// EVERY free path backfills, not just the death cooldown.
				if ( level.acc_bb_queue.size > 0 )
				{
					q = level.acc_bb_queue[ 0 ];
					rest = [];
					for ( j = 1; j < level.acc_bb_queue.size; j++ )
						rest[ rest.size ] = level.acc_bb_queue[ j ];
					level.acc_bb_queue = rest;
					if ( isdefined( q ) && isdefined( q.boss ) && !bb_is_dead( q.boss ) )
						bb_occupy( i, q.boss, q.name );
				}
				continue;
			}

			// LIVE slot. NOTE the boss reference may read UNDEFINED here even though
			// the slot is live: a Delete()d corpse's reference is undefined, and the
			// Phantom's corpse deletes 0.05s after death - FASTER than this 4Hz tick.
			// THE 2026-07-25 STUCK-PHANTOM ROOT CAUSE: the old code tested
			// !isdefined(acc_bb_boss[i]) as "free slot" BEFORE the death check, so a
			// fast-deleted corpse was swallowed as an empty slot and its death push
			// NEVER fired (live log: "PHANTOM|2|1" then "[phantom] Phantom down" and
			// no "PHANTOM|0|0" ever - while the slow-despawning AVOGADRO pushed
			// "AVOGADRO|0|0" fine). Occupancy now rides acc_bb_live, so the deleted
			// reference falls through to bb_is_dead's !isdefined -> death push.
			boss = level.acc_bb_boss[ i ];
			if ( bb_is_dead( boss ) )
			{
				// Death push: the Lua row plays its white flash + fade-out.
				level.acc_bb_boss[ i ]    = undefined;
				level.acc_bb_live[ i ]    = false;
				level.acc_bb_dead_at[ i ] = GetTime();
				bb_push_all( i, level.acc_bb_name[ i ], 0, 0 );
				continue;
			}

			pct = bb_pct_of( boss );
			if ( pct != level.acc_bb_pct[ i ] )
			{
				level.acc_bb_pct[ i ] = pct;
				bb_push_all( i, level.acc_bb_name[ i ], pct, 1 );
			}
		}
	}
}

// self = player. Re-push every row across the acc_hud close/reopen window each
// life - the exact _acc_leveling::repush_level_hud_per_life shape (anchor on the
// blackscreen FLAG, not spawn: on the initial spawn the menu doesn't exist yet).
// Non-live slots re-paint as state 2 so a reopened menu never shows a stale row.
function bb_on_player_connect()
{
	self endon( "disconnect" );
	self thread bb_repush_per_life();
}

function bb_on_player_spawned()
{
	self endon( "disconnect" );
	self thread bb_repush_per_life();
}

function bb_repush_per_life()
{
	self endon( "disconnect" );
	self notify( "acc_bb_repush" );
	self endon( "acc_bb_repush" );

	if ( !IS_TRUE( level.acc_boss_bars_lui ) )
		return;

	level flag::wait_till( "initial_blackscreen_passed" );   // menu opens ~0.5s after this

	for ( k = 0; k < 6; k++ )
	{
		wait 0.5;
		for ( i = 0; i < ACC_BB_SLOTS; i++ )
		{
			// The ONLY pushes that carry a uniquifier tag: identical re-sends must
			// still count as a model CHANGE to paint a freshly reopened menu (the
			// accLevel push_id lesson). ~30 tagged strings per life, bounded.
			level.acc_bb_seq++;
			if ( IS_TRUE( level.acc_bb_live[ i ] ) )
				bb_push_to( self, i, level.acc_bb_name[ i ], level.acc_bb_pct[ i ], 1, "r" + level.acc_bb_seq );
			else
				bb_push_to( self, i, "", 0, 2, "r" + level.acc_bb_seq );
		}
	}
}
