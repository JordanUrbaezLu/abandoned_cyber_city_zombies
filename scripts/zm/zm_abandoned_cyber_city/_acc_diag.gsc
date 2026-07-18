// =============================================================================
// _acc_diag.gsc - FILE-ONLY runtime diagnostics heartbeat (user 2026-07-04)
//
// Born from the "Failed to allocate from state pool" round-25/26 crash hunt: we
// had NO runtime data on what accumulates over a long game (the crash sessions
// weren't even logged). This module LogPrint's a compact census line every
// acc_diag_interval (30s) - NO on-screen prints (user: "No UI logs, just
// logging the game info to a file"). LogPrint is the stock file-log builtin
// (ai_shared.gsc:719 precedent) and writes to the engine game log
// (g_log, games_mp.log) - run_game.ps1 enables it alongside logfile.
//
// WHAT EACH FIELD MEANS (leak forensics):
//   t=        server ms since load (GetTime())
//   rd=       current round
//   pl=       connected players
//   ai=       live axis AI (horde + elites + furies + bosses) - actor budget
//   ents=     TOTAL entities (GetEntArray().size) - THE server-leak fingerprint:
//             a monotonic climb here = something spawns entities and never frees
//   sm=       script_model count (attached/dropped props ride this class)
//   corpse=   GetCorpseArray().size - lingering bodies (no_gib pile-up check)
//   fury=     live Apothicon Furies (level.acc_furies census)
//   octo=     live octobombs (level.octobombs, thrown Li'l Arnies)
//   debtP/F=  Rogue Protector / Phantom spawn debts (should be 0 off boss rounds)
//   d(...)    delta vs the previous heartbeat for the two key counters
//
// HOW TO READ A LEAK: server-side leak = ents/sm/corpse climbing every line
// while frames decay. If ALL server counters stay flat but frames still decay,
// the leak is CLIENT-side (LUI/FX) - that contrast is exactly what this line
// exists to prove. The 2026-07-04 state-pool crash was client-side (LUI UITimer
// leaks, memory lui-uitimer-leaks-state-pool); this heartbeat is the tripwire
// for the next one.
//
// Zero UI, ~1 file line / 30s, negligible cost. Always on (not dev-gated) so a
// "real play" session is also covered; disable live with acc_diag_interval 0.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;   // zm::register_player_damage_callback (player-damage debug logger)

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_diag;

function init()
{
	level thread diag_heartbeat();

	// Reusable PLAYER-DAMAGE debug logger (user 2026-07-04: "add logs on how players are damaged
	// if we ever have to debug something, inside console_mp.log"). Rides level.acc_dev (a dev
	// build logs, ship is silent - only dev/god/mock flags exist, 2026-07-16). Logs big hits a
	// player takes - attacker, weapon, raw damage, mod, hit location, resulting HP - the exact
	// data we lacked when the Rogue Protector was "one-shotting" / doing zero.
	zm::register_player_damage_callback( &dmg_debug_probe );
}

// self = the damaged player. Returns -1 = "no opinion" (NEVER alters the damage chain - it only
// observes). Routes via IPrintLnBold because that is the ONLY channel that reliably reaches
// console_mp.log (as "[ SCRIPTER] ..."); LogPrint goes to games_mp.log (needs +set g_log, which
// the play launchers don't all set) and the /# println #/ dev block doesn't route reliably -
// same rationale as _acc_utility's drops logger. Gated so it's silent in normal play.
function dmg_debug_probe( eInflictor, eAttacker, iDamage, iDFlags, sMeansOfDeath, weapon, vPoint, vDir, sHitLoc, psOffsetTime )
{
	// Silent in ship (it once shipped default-ON and spammed "[DMG] ..." on-screen whenever a
	// player took a big hit - user 2026-07-04). Dev builds log hits >= the threshold below; the
	// old acc_dmg_debug/acc_dmg_debug_min dvar levers were removed 2026-07-16.
	if ( !IS_TRUE( level.acc_dev ) )   // re-coupled to acc_dev 2026-07-16 (only dev/god/mock flags exist)
		return -1;
	if ( iDamage < 40 )   // log threshold (was the acc_dmg_debug_min dvar; hardcoded 2026-07-16 - no per-feature levers)
		return -1;

	atk = "world";
	if ( isdefined( eAttacker ) )
	{
		if ( isplayer( eAttacker ) )                    atk = "player:" + eAttacker.name;
		else if ( isdefined( eAttacker.archetype ) )    atk = "ai:" + eAttacker.archetype;
		else                                            atk = "ent";
	}

	self IPrintLnBold( "^3[DMG] " + ( isdefined( self.name ) ? self.name : "?" )
	                   + " took " + iDamage + " from " + atk
	                   + " wpn=" + ( isdefined( weapon ) && isdefined( weapon.name ) ? weapon.name : "?" )
	                   + " mod=" + ( isdefined( sMeansOfDeath ) ? sMeansOfDeath : "?" )
	                   + " loc=" + ( isdefined( sHitLoc ) ? sHitLoc : "?" )
	                   + " hp=" + ( isdefined( self.health ) ? self.health : -1 ) );
	return -1;   // observe only - never change the damage
}

function diag_heartbeat()
{
	level endon( "end_game" );
	level flag::wait_till( "initial_blackscreen_passed" );

	last_ents = 0;
	last_sm   = 0;

	for ( ;; )
	{
		interval = getdvarfloat( "acc_diag_interval", 30 );
		if ( interval <= 0 )
		{
			wait 5;   // disabled - idle cheaply, keep polling the dvar
			continue;
		}
		wait( interval );

		// --- census (every builtin here is stock-verified: GetEntArray, GetAITeamArray,
		// GetCorpseArray (zombie_utility.gsc:2253), GetPlayers) ---
		a_ents   = GetEntArray();
		a_sm     = GetEntArray( "script_model", "classname" );
		a_ai     = GetAITeamArray( "axis" );
		a_corpse = GetCorpseArray();

		n_fury = 0;
		if ( isdefined( level.acc_furies ) )
		{
			foreach ( e in level.acc_furies )
				if ( isdefined( e ) && IsAlive( e ) ) n_fury++;
		}
		n_octo = 0;
		if ( isdefined( level.octobombs ) )
		{
			foreach ( ob in level.octobombs )
				if ( isdefined( ob ) ) n_octo++;
		}

		debt_p = ( isdefined( level.acc_protector_debt ) ? level.acc_protector_debt : 0 );
		debt_f = ( isdefined( level.acc_phantom_debt )   ? level.acc_phantom_debt   : 0 );

		line = "[ACCDIAG] t=" + GetTime()
		     + " rd=" + ( isdefined( level.round_number ) ? level.round_number : 0 )
		     + " pl=" + GetPlayers().size
		     + " ai=" + a_ai.size
		     + " ents=" + a_ents.size
		     + " sm=" + a_sm.size
		     + " corpse=" + a_corpse.size
		     + " fury=" + n_fury
		     + " octo=" + n_octo
		     + " debtP=" + debt_p
		     + " debtF=" + debt_f
		     + " d(ents)=" + ( a_ents.size - last_ents )
		     + " d(sm)=" + ( a_sm.size - last_sm );

		last_ents = a_ents.size;
		last_sm   = a_sm.size;

		// FILE-ONLY: LogPrint -> the engine game log (needs \n; no screen output at all).
		LogPrint( line + "\n" );
		// Belt-and-suspenders: the dev println channel too (harmless when it doesn't route).
		acc_utility::log( line );
	}
}
