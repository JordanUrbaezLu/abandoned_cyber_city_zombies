// =============================================================================
// _acc_boss_nameplate.gsc - 3D over-head boss nameplate + health bar (server half)
//
// THE MECHANISM (user 2026-07-02: "Civil Protector somehow has a name floating
// over him in 3D - use that for all bosses instead of the 2D top-screen bar"):
// the engine renders a floating world-space name over any ACTOR the CLIENT
// calls `self SetDrawName( <string>, true )` on. Proven twice: the HB21 pack's
// zm_zod_robot.csc names the ally robot, and STOCK does the same thing on a
// zombie-model actor for the Turned AAT (_zm_aat_turned.csc:38 - an actor that
// is NOT on the players' team, so the draw renders on hostiles too). Stock's
// delivery is an ACTOR CLIENTFIELD whose .csc callback calls SetDrawName - we
// copy that recipe exactly, with TWO fields so the text can carry a LIVE
// HEALTH BAR (re-calling SetDrawName re-renders the string):
//   "acc_bnp_name" (3 bits) - boss identity index (0 = none/clear)
//   "acc_bnp_hp"   (4 bits) - health in tenths (10 = full, 0 = dead)
// The .csc half (_acc_boss_nameplate.csc) rebuilds "NAME [||||||....]" on any
// change. NAME INDICES MUST MATCH the .csc table - add new bosses to BOTH.
//
// Feeding it: the existing level notify "acc_boss_spawned" (boss, name) - the
// same hook the old 2D top-screen bar consumed (_acc_health_bars, now gated
// OFF by default via acc_boss_bar_2d) - plus direct attach() calls from the
// bosses that deliberately never emitted that notify (Brutus, Glitch).
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

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
		case "GLITCH STALKER":   return 4;
		case "ROGUE PROTECTOR":  return 5;   // the Civil Protector boss
		case "AVOGADRO":         return 6;   // the cyberhacker boss
		default:                 return 7;   // generic "BOSS"
	}
}

// Auto-attach for every boss that emits the shared notify (Phantom, Rogue
// Protector, Subroutine Core). Brutus/Glitch call attach() directly.
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

// PUBLIC: give `boss` a 3D over-head nameplate + live health bar. Gate:
// acc_boss_nameplate_on (default 1; set 0 = no 3D plates, e.g. for A/B vs the
// 2D bar via acc_boss_bar_2d 1).
function attach( boss, name )
{
	if ( getdvarint( "acc_boss_nameplate_on", 1 ) != 1 )
		return;
	if ( !isdefined( boss ) )
		return;
	// Paradise onslaught suppresses boss HUD (same rule as the old 2D bar).
	if ( IS_TRUE( level.acc_paradise_onslaught ) )
		return;

	boss clientfield::set( "acc_bnp_name", name_to_index( name ) );
	boss clientfield::set( "acc_bnp_hp", 10 );
	boss thread hp_watch();
}

function hp_watch()
{
	level endon( "end_game" );
	self endon( "death" );

	last = 10;
	for ( ;; )
	{
		wait 0.25;

		// [acc] #1 GUARD (2026-07-05): some bosses (the Avogadro) Delete() themselves WITHOUT firing the
		// engine "death" notify - their pack death() notifies "avogadro_death" then Delete()s - so the
		// endon( "death" ) above never fires and this thread survives the removal. Reading self.health on a
		// removed entity throws "removed entity is not an entity" and (per _zm_ai_avogadro.gsc:807) the
		// erroring thread keeps looping. Test isdefined( self ) FIRST (safe on a removed entity; a field
		// access is NOT) and bail so the thread ends cleanly instead of spamming the error every 0.25s.
		if ( !isdefined( self ) )
			return;

		if ( !isdefined( self.health ) || !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
			continue;

		tenths = int( self.health * 10 / self.maxhealth );
		if ( self.health > 0 && tenths < 1 ) tenths = 1;   // alive never shows an empty bar
		if ( tenths > 10 ) tenths = 10;
		if ( tenths < 0 ) tenths = 0;

		if ( tenths != last )
		{
			last = tenths;
			self clientfield::set( "acc_bnp_hp", tenths );
		}

		// The plate + this thread die with the actor ("death" endon, or the isdefined( self )
		// bail above for bosses that Delete() without "death"); the corpse's draw name goes
		// away when the body is cleaned up. No explicit clear needed.
	}
}
