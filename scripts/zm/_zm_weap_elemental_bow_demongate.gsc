#using scripts\codescripts\struct;
#using scripts\shared\ai\systems\gib;
#using scripts\shared\ai\zombie_shared;
#using scripts\shared\ai\zombie_utility;
#using scripts\shared\ai_shared;
#using scripts\shared\array_shared;
#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\fx_shared;
#using scripts\shared\hud_util_shared;   // [acc] persistent on-screen void-diagnostic panel (dev only)
#using scripts\shared\math_shared;
#using scripts\shared\scene_shared;
#using scripts\shared\spawner_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;
#using scripts\zm\_util;
#using scripts\zm\_zm_bgb;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weap_elemental_bow;
#using scripts\zm\_zm_weapons;
// [acc] PaP tier lookup for the demon-gate nerf-then-scale (user 2026-07-07). This vendored pack script now
// depends on our tier module so the charged shot can read the shooter's Fire Bow PaP level.
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;
#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#precache( "model", "c_zom_chomper" );

// [acc] Fire Bow void diagnostic panel: max lines kept in the rolling on-screen trace buffer (dev only).
#define ACC_FB_DBG_MAX 16

#namespace _zm_weap_elemental_bow_demongate;

REGISTER_SYSTEM_EX( "_zm_weap_elemental_bow_demongate", &__init__, &__main__, undefined )

function __init__()
{
	level.w_bow_demongate = getweapon( "elemental_bow_demongate" );
	level.w_bow_demongate_charged = getweapon( "elemental_bow_demongate4" );
	level.a_demongate_chompers = [];
	clientfield::register( "toplayer", "elemental_bow_demongate" + "_ambient_bow_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "missile", "elemental_bow_demongate" + "_arrow_impact_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "missile", "elemental_bow_demongate4" + "_arrow_impact_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "demongate_portal_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "toplayer", "demongate_portal_rumble", 1, 1, "int" );
	clientfield::register( "scriptmover", "demongate_wander_locomotion_anim", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "demongate_attack_locomotion_anim", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "demongate_chomper_fx", VERSION_SHIP, 1, "int" );
	clientfield::register( "scriptmover", "demongate_chomper_bite_fx", VERSION_SHIP, 1, "counter" );
}

function __main__()
{
	callback::on_connect( &on_connect_bow_demongate );
	// [acc] persistent on-screen void diagnostic panel (dev only). See the acc_firebow_dbg_* block below.
	level thread acc_firebow_dbg_hud_loop();
}

// =============================================================================
// [acc] FIRE BOW VOID DIAGNOSTIC PANEL + FILE LOG (user 2026-07-11: "write super comprehensive logs so I
// can play, start a void, and you can see what's happening"; later same day: "Not UI logs but console
// logs so i can test and you can just read the logs"). CORRECTION to the earlier "console_mp.log writes
// NOTHING" belief: it DOES write on this box - the 2026-07-11 1:59 PM run produced a live log with
// "[ SCRIPTER] [msg]..." lines from IPrintLn* (docs/17 was right; the apex-era note was wrong). So every
// dbg line below is ALSO IPrintLn-mirrored into <game>\console_mp.log tagged "[BOW]" - after a test run,
// read the log and the whole story is there. The on-screen panel additionally shows the rolling last
// ACC_FB_DBG_MAX lines live. The chain, in order, should read:
//   FIRED <def> hold=<ms>ms ...      (which def the engine fired + OUR measured trigger-hold time; a
//                                     full draw says "ENGINE FULL" or "CUSTOM FULL" -> portal armed.
//                                     Since the 2026-07-11 custom charge move, a long hold portals even
//                                     when the engine fired a partial ..demongate/..2/..3 def)
//   impact -> PORTAL branch          (the charged arrow registered an impact; "FALLBACK portal" instead
//                                     means the impact event never came and the shadow tracker opened it)
//   portal OPEN tier/r/frac/z        (portal entity spawned, DoT thread launched)
//   DoT ENTER r/zband/zh             (the ticker started; zh = live round zombie health)
//   tick N ai=.. near=.. r=.. hit=..xDMG  (per second: AI in level, nearest AI's dist to portal vs the
//                                     ring radius, #hit x dmg; near > r every tick = nothing can ever
//                                     be in range - placement/radius problem, not a damage problem)
//    tN dmg -> <arch> hp=A take=D    (per target, first 3/tick: about to damage)
//    tN dmg OK <arch> hp A->B        (damage LANDED; a "dmg ->" with no "OK" = that target's damage
//                                     chain THREW - the child thread died containing it)
//   DoT END after N ticks            (clean ticker exit; ticks stopping without this = the ticker died)
// Dev-only; to remove, delete this block + its acc_firebow_dbg_log() calls and the __main__ thread line.
// =============================================================================

// Push one line into the rolling on-screen trace buffer (level-global; dev-only; no-op otherwise).
function acc_firebow_dbg_log( s )
{
	if ( !IS_TRUE( level.acc_dev ) ) return;
	// FILE MIRROR: IPrintLn lands in console_mp.log as "[ SCRIPTER] [msg][BOW] ..." (verified live
	// 2026-07-11) - this line is for the agent reading the log post-run; the panel is for the player.
	IPrintLn( "[BOW] " + s );
	if ( !isdefined( level.acc_firebow_dbg_lines ) ) level.acc_firebow_dbg_lines = [];
	if ( !isdefined( level.acc_firebow_dbg_seq ) ) level.acc_firebow_dbg_seq = 0;
	level.acc_firebow_dbg_seq++;
	level.acc_firebow_dbg_lines[ level.acc_firebow_dbg_lines.size ] = level.acc_firebow_dbg_seq + " " + s;
	// Trim to the last ACC_FB_DBG_MAX (rebuild dropping the oldest - GSC has no shift).
	if ( level.acc_firebow_dbg_lines.size > ACC_FB_DBG_MAX )
	{
		a_keep = [];
		start = level.acc_firebow_dbg_lines.size - ACC_FB_DBG_MAX;
		for ( i = start; i < level.acc_firebow_dbg_lines.size; i++ )
			a_keep[ a_keep.size ] = level.acc_firebow_dbg_lines[ i ];
		level.acc_firebow_dbg_lines = a_keep;
	}
}

function acc_firebow_dbg_render_text()
{
	s = "^3== FIRE BOW VOID TRACE ==";
	if ( isdefined( level.acc_firebow_dbg_lines ) )
	{
		for ( i = 0; i < level.acc_firebow_dbg_lines.size; i++ )
			s = s + "\n^7" + level.acc_firebow_dbg_lines[ i ];
	}
	return s;
}

// Per-player: keep a single multi-line fontstring on the left edge showing the trace buffer. One elem per
// player (co-op safe; pool-guarded per memory gsc-t7-runtime-traps - retry next tick if create* returns
// undefined). Refreshes at 10 Hz so ticks appear live.
function acc_firebow_dbg_hud_loop()
{
	level endon( "end_game" );
	if ( !IS_TRUE( level.acc_dev ) ) return;
	level flag::wait_till( "initial_blackscreen_passed" );
	for ( ;; )
	{
		txt = acc_firebow_dbg_render_text();
		players = GetPlayers();
		for ( i = 0; i < players.size; i++ )
		{
			p = players[ i ];
			if ( !isdefined( p ) || !isplayer( p ) ) continue;
			p acc_firebow_dbg_ensure_hud();
			if ( isdefined( p.acc_firebow_dbg_hud ) )
				p.acc_firebow_dbg_hud setText( txt );
		}
		wait 0.1;
	}
}

function acc_firebow_dbg_ensure_hud()
{
	if ( isdefined( self.acc_firebow_dbg_hud ) ) return;
	self.acc_firebow_dbg_hud = self hud::createFontString( "default", 0.85 );
	if ( !isdefined( self.acc_firebow_dbg_hud ) ) return;   // hudelem pool full - retry next tick
	self.acc_firebow_dbg_hud hud::setPoint( "TOP_LEFT", "TOP_LEFT", 8, 120 );
	self.acc_firebow_dbg_hud.color = ( 0.6, 1.0, 0.7 );
	self.acc_firebow_dbg_hud.alpha = 0.9;
	self.acc_firebow_dbg_hud.hidewheninmenu = true;
}

function on_connect_bow_demongate()
{
	// [acc] CHARGE COST - REVERTED (user 2026-07-07): overriding bg_zm_dlc1_chargeShotMultipleBulletsForFullCharge
	// from the pack's shipped 2 -> 4 BROKE the full charge ("charge move does nothing"): the demon-gate weapon's
	// charge is designed around 2 bullets, so 4 made FULL charge unreachable -> the shot stayed partial
	// (elemental_bow_demongate, single chomper) and never fired elemental_bow_demongate4 (the portal). Left at the
	// pack default (2). If a higher charge cost is wanted, do it as a post-portal ammo deduction in
	// bow_demongate_open_portal (which only runs on a real full charge), NOT via this full-charge-threshold dvar.

	// [acc] WATCHERS MUST SURVIVE DEATH (user 2026-07-08 "the firebow charge move doesn't work"): the pack
	// threads its three per-player watchers ONCE at connect, and bow_base_impact_watcher / bow_base_
	// wield_watcher both `endon("death")` - so the FIRST bleed-out killed them permanently. After that a
	// full-charge shot still fired the elemental_bow_demongate4 projectile, but its impact handler (the
	// thing that opens the PORTAL) no longer existed -> "charge move does nothing" (tap-shot chompers died
	// with it too; a revived down was fine - only a real death notifies "death"). Fix: re-thread after
	// every death via the respawn loop below.
	self thread bow_demongate_watchers_respawn_loop();
	self thread acc_firebow_clip_watcher();

	// [acc] CUSTOM CHARGE MOVE (user 2026-07-11, 6th charge report - "we need a custom solution"): stop
	// trusting the engine's charge pipeline. These two threads measure the trigger HOLD TIME ourselves and
	// guarantee the portal on any full-draw arrow, whatever charge-level def the engine actually fired and
	// whether or not its projectile_impact event ever arrives. See the block comment above
	// acc_firebow_hold_tracker for the full design + why. Both endon disconnect ONLY (survive death - the
	// 2026-07-08 watcher lesson).
	self thread acc_firebow_hold_tracker();
	self thread acc_firebow_fire_watcher();
}

// =============================================================================
// [acc] CUSTOM CHARGE MOVE (user 2026-07-11, sixth "charge move does nothing" report: "I genuinely think
// we need a custom solution"). WHY: the pack's charge move rides a fragile ENGINE chain -
//   hold -> engine charge levels 1..4 -> release fires the level's weapon def -> the def must be
//   "elemental_bow_demongate4" -> its projectile must notify "projectile_impact" -> portal.
// THREE of the five prior root causes were that chain silently breaking (full-charge threshold dvar,
// SetWeaponAmmoClip writes mid-draw resetting the charge, watchers dead after bleed-out) - and ANY future
// mid-draw weapon-state poke re-breaks it invisibly. A direct zombie-BODY hit can also eat the
// projectile_impact event ("charge does nothing when zombies are near" while floor shots chomper fine).
// THE HACK (hacky is good): bypass the engine's opinion entirely -
//   1. acc_firebow_hold_tracker  - polls AttackButtonPressed while the bow is held and keeps the press
//      START time on the player. OUR clock, immune to engine charge resets.
//   2. acc_firebow_fire_watcher  - on every bow missile_fire, hold time = now - press start (read HERE,
//      at the event, not in the poll loop - the missile fires the instant the trigger releases, so the
//      press field is still set and there is no 50ms poll race). Hold >= acc_firebow_charge_hold_ms
//      (default 1200, live-tunable) OR the def is ..4 = this arrow is CHARGED: mark the projectile
//      (self.acc_fb_charged_proj) and shadow it with acc_firebow_charged_proj_tracker.
//   3. bow_demongate_impact_explosion opens the PORTAL for a marked arrow no matter which def the engine
//      fired (partial defs included); unmarked arrows keep the tap-chomper branch.
//   4. If the impact event NEVER arrives, the shadow tracker opens the portal at the arrow's last
//      tracked origin (poll till the projectile entity vanishes). acc_firebow_portal_gate_open()
//      debounces so impact handler + tracker can never double-portal one arrow.
// Engine full-charge (..4) still works and still costs its native 2 arrows; the custom path only ADDS
// portals the engine wrongly withheld. GDT ground truth: chargeShotMaxLevel 4, chargeShotMaxTime 0.8,
// fireType "Charge Shot" (wpn_t7_zmb_bow.gdt).
// =============================================================================

// The held-weapon family check (IsSubStr covers PaP-in-place + the _acc_fastreload twin).
function acc_firebow_is_holding_bow()
{
	w = self GetCurrentWeapon();
	return ( isdefined( w ) && w != level.weaponNone && isdefined( w.name ) && IsSubStr( w.name, "elemental_bow_demongate" ) );
}

// Maintain self.acc_fb_press_start (trigger-press start time while the bow is held). On release (or
// weapon switch) the finished hold is parked in acc_fb_last_hold_ms/_time for 300ms - the fire watcher
// reads whichever is live, so it never loses the measurement to poll-vs-notify frame ordering.
function acc_firebow_hold_tracker()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.05;
		if ( self acc_firebow_is_holding_bow() && self AttackButtonPressed() )
		{
			if ( !isdefined( self.acc_fb_press_start ) )
				self.acc_fb_press_start = GetTime();
		}
		else if ( isdefined( self.acc_fb_press_start ) )
		{
			self.acc_fb_last_hold_ms = GetTime() - self.acc_fb_press_start;
			self.acc_fb_last_hold_time = GetTime();
			self.acc_fb_press_start = undefined;
		}
	}
}

// On every bow shot: decide CHARGED by our own hold-time measurement (or the engine agreeing via ..4),
// mark the projectile, and launch the no-impact-event fallback shadow. Also THE fire-chain dev line.
function acc_firebow_fire_watcher()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self waittill( "missile_fire", e_proj, w_fired );
		if ( !isdefined( w_fired ) || !isdefined( w_fired.name ) ) continue;
		if ( !IsSubStr( w_fired.name, "elemental_bow_demongate" ) ) continue;

		n_hold_ms = 0;
		if ( isdefined( self.acc_fb_press_start ) )
			n_hold_ms = GetTime() - self.acc_fb_press_start;
		else if ( isdefined( self.acc_fb_last_hold_time ) && isdefined( self.acc_fb_last_hold_ms )
			 && ( GetTime() - self.acc_fb_last_hold_time ) <= 300 )
			n_hold_ms = self.acc_fb_last_hold_ms;

		n_need_ms = getdvarint( "acc_firebow_charge_hold_ms", 1200 );
		if ( n_need_ms < 200 ) n_need_ms = 200;

		b_engine_full = ( w_fired.name == "elemental_bow_demongate4" );
		b_custom_full = ( n_hold_ms >= n_need_ms );
		if ( ( b_engine_full || b_custom_full ) && isdefined( e_proj ) )
		{
			self.acc_fb_charged_proj = e_proj;
			self thread acc_firebow_charged_proj_tracker( e_proj );
		}
		acc_firebow_dbg_log( "FIRED " + w_fired.name + " hold=" + n_hold_ms + "ms"
			+ ( b_engine_full ? " ^2ENGINE FULL -> portal" : ( b_custom_full ? " ^2CUSTOM FULL (>=" + n_need_ms + ") -> portal" : " ^7tap" ) ) );
	}
}

// Shadow a charged arrow to its end of life. If the engine's projectile_impact handler opened the portal
// it clears acc_fb_charged_proj first - we stand down. If the event never arrived (e.g. the arrow died
// on a zombie body), open the portal at the last tracked origin so a full draw ALWAYS produces the move.
function acc_firebow_charged_proj_tracker( e_proj )
{
	self endon( "disconnect" );
	if ( !isdefined( e_proj ) )
		return;
	v_last = e_proj.origin;
	n_deadline = GetTime() + 4000;
	while ( isdefined( e_proj ) && GetTime() < n_deadline )
	{
		v_last = e_proj.origin;
		wait 0.05;
	}
	wait 0.1;   // give the same-frame impact handler first claim
	if ( !isdefined( self.acc_fb_charged_proj ) )
		return;   // impact handler consumed it - portal already open
	self.acc_fb_charged_proj = undefined;
	if ( !self acc_firebow_portal_gate_open() )
		return;
	acc_firebow_dbg_log( "^2FALLBACK portal (no impact event) z=" + int( v_last[ 2 ] ) );
	self thread bow_demongate_open_portal( level.w_bow_demongate_charged, v_last, undefined, ( 0, 0, 1 ) );
}

// One portal per arrow: impact handler and shadow tracker both pass through here; 500ms per-shooter gate.
function acc_firebow_portal_gate_open()
{
	if ( isdefined( self.acc_fb_portal_gate ) && GetTime() < self.acc_fb_portal_gate )
		return false;
	self.acc_fb_portal_gate = GetTime() + 500;
	return true;
}

// [acc] Thread the pack's per-player bow watchers, and RE-thread them after every real death (they
// endon "death"; a revived down never fires that notify, so no duplicate threads are possible - the
// loop only re-arms after the old set is provably dead). endon disconnect matches the pack lifecycle.
function bow_demongate_watchers_respawn_loop()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		self thread zm_weap_elemental_bow::bow_base_wield_watcher( "elemental_bow_demongate" );
		self thread zm_weap_elemental_bow::bow_base_fired_watcher( "elemental_bow_demongate", "elemental_bow_demongate4" );
		self thread zm_weap_elemental_bow::bow_base_impact_watcher( "elemental_bow_demongate", "elemental_bow_demongate4", &bow_demongate_impact_explosion );

		self waittill( "death" );           // the watchers' endon fired with this - they are gone
		self waittill( "spawned_player" );  // re-arm once the player is actually back
	}
}

// [acc] CLIP CAP (user 2026-07-07): the Fire Bow's clip is 30 arrows at base and 1st PaP, then 50 at 2nd PaP
// and beyond. PaP upgrades the bow IN PLACE (no _up weapon def), so we can't set clip per-variant in the GDT -
// instead we clamp the live clip to the tier cap here (the GDT clipSize 75 is just the ceiling). Runs for every
// player but only acts while the fire bow is held (cap = 1/game, so at most one holder). Live dvars
// acc_firebow_clip_t0..3 (defaults 30 / 30 / 50 / 50). A Max-Ammo refill briefly shows the ceiling, then clamps.
function acc_firebow_clip_watcher()
{
	self endon( "disconnect" );
	for ( ;; )
	{
		wait 0.25;
		w = self GetCurrentWeapon();
		if ( !isdefined( w ) || w == level.weaponNone || !isdefined( w.name ) || !IsSubStr( w.name, "elemental_bow_demongate" ) )
			continue;
		// [acc] NEVER clamp while the trigger is held (2026-07-08 charge hunt, THE portal root cause):
		// the bow REGENERATES arrows (GDT power_recharge_rate 0.417), so the clip creeps past the cap
		// and this clamp re-fired ~every 2.4s FOREVER - and a SetWeaponAmmoClip write mid-DRAW resets
		// the engine's charge, chopping every long hold back to level 1-2 (log-proven: releases fired
		// elemental_bow_demongate / ..2, never ..3/..4 - so the portal def was UNREACHABLE and the
		// charged move "did nothing" since integration). Defer the clamp until the trigger is free.
		if ( self AttackButtonPressed() )
			continue;
		tier = acc_pap_levels::get_tier( self, w );
		if ( tier < 0 ) tier = 0;
		if ( tier > 3 ) tier = 3;
		cap = getdvarint( "acc_firebow_clip_t" + tier, ( tier >= 2 ? 50 : 30 ) );
		if ( cap < 1 ) cap = 1;
		if ( self GetWeaponAmmoClip( w ) > cap )
			self SetWeaponAmmoClip( w, cap );
	}
}


function bow_demongate_impact_explosion( weapon, position, radius, attacker, normal )
{
	// [acc] CUSTOM CHARGE fork (2026-07-11; see the block above acc_firebow_is_holding_bow): the portal
	// opens if EITHER the engine reached full charge (def ..4) OR this arrow was marked charged by OUR
	// hold-time measurement (acc_fb_charged_proj) - so a full draw portals even when the engine's charge
	// was silently reset and it fired a partial def. `attacker` is actually the PROJECTILE (the pack
	// misnamed the param), which is exactly what the mark holds. Unmarked partials keep the tap chomper.
	b_custom_charged = ( isdefined( self.acc_fb_charged_proj ) && isdefined( attacker )
		 && attacker == self.acc_fb_charged_proj );
	if ( weapon.name == "elemental_bow_demongate4" || b_custom_charged )
	{
		self.acc_fb_charged_proj = undefined;   // consumed: the shadow tracker stands down
		if ( !self acc_firebow_portal_gate_open() )
			return;
		acc_firebow_dbg_log( "^2impact -> PORTAL branch (" + ( weapon.name == "elemental_bow_demongate4" ? "engine ..4" : "custom hold, def=" + weapon.name ) + ")" );
		self thread bow_demongate_open_portal( weapon, position, attacker, normal );
	}
	else
	{
		acc_firebow_dbg_log( "^1impact -> chomper branch (" + weapon.name + ")" );
		attacker clientfield::set( "elemental_bow_demongate" + "_arrow_impact_fx", 1 );
		self thread bow_demongate_fire_chomper( position, attacker );
	}
}

function bow_demongate_get_impact_pos( v_pos, v_norm )
{
	if ( abs( v_norm[ 2 ] ) < .2 )
	{
		v_pos = v_pos + ( v_norm * 16 );
		a_trace = bullettrace( v_pos, v_pos + vectorScale( ( 0, 0, 1 ), 64 ), 0, undefined );
		if ( a_trace[ "fraction" ] < 1 )
			v_pos = a_trace[ "position" ] - vectorScale( ( 0, 0, 1 ), 64 );
		
		a_trace = bullettrace( v_pos, v_pos - vectorScale( ( 0, 0, 1 ), 64 ), 0, undefined );
		if ( a_trace[ "fraction" ] < 1 )
			v_pos = a_trace[ "position" ] + vectorScale( ( 0, 0, 1 ), 64 );
		
	}
	else
	{
		n_z_offset = v_norm[ 2 ] * 64;
		v_pos = v_pos + ( 0, 0, n_z_offset );
	}
	return v_pos;
}

function bow_demongate_open_portal( weapon, position, attacker, normal )
{
	position = bow_demongate_get_impact_pos( position, normal );
	v_portal_angles = vectorToAngles( normal );
	v_portal_angles = v_portal_angles + vectorScale( ( 0, 1, 0 ), 90 );
	v_portal_angles = v_portal_angles * ( 0, 1, 0 );
	e_portal = util::spawn_model( "tag_origin", position, v_portal_angles );
	e_portal clientfield::set( "demongate_portal_fx", 1 );
	e_portal.b_portal_open = 1;

	// [acc] PaP-SCALED demon-gate (user 2026-07-07; RE-ENABLED 2026-07-08 after the baseline test round):
	// the un-upgraded bow is NERFED - a SMALL blast + fewer chompers - and every PaP tier restores +
	// improves it (radius 50/65/80/95, chompers 1/1/2/3; live dvars acc_firebow_aoe_radius_t0..3 /
	// acc_firebow_chompers_t0..3), so "clears the whole round" is the PaP reward, not the base. self = the
	// shooting player; the Fire Bow cap is 1/game so the held-bow tier read is unambiguous.
	acc_tier = 0;
	if ( isdefined( self ) && isplayer( self ) )
	{
		acc_held = self GetCurrentWeapon();
		if ( isdefined( acc_held ) && isdefined( acc_held.name ) && IsSubStr( acc_held.name, "elemental_bow_demongate" ) )
			acc_tier = acc_pap_levels::get_tier( self, acc_held );
	}
	if ( acc_tier < 0 ) acc_tier = 0;
	if ( acc_tier > 3 ) acc_tier = 3;
	// radius by PaP tier. WAS 50/65/80/95 (user 2026-07-07, spec'd for the original INSTANT blast);
	// re-defaulted 110/140/170/200 on 2026-07-11 - the [BOW] log of the 2:16 PM run proved r=50 is
	// practically unreachable for a 1s-tick DoT ZONE (tick after tick of near=67..197 r=50 hit=0:
	// zombies chase the PLAYER, so they only clip the 1.3m disc for 1-2 ticks). Same ladder shape,
	// +15/tier -> +30/tier. Old values restorable live via acc_firebow_aoe_radius_t0..3.
	acc_aoe_radius   = getdvarint( "acc_firebow_aoe_radius_t" + acc_tier, ( acc_tier == 0 ? 110 : ( acc_tier == 1 ? 140 : ( acc_tier == 2 ? 170 : 200 ) ) ) );
	// chompers 1 / 1 / 2 / 3 by PaP tier (user 2026-07-07).
	acc_chomper_cap  = getdvarint( "acc_firebow_chompers_t"   + acc_tier, ( acc_tier == 0 ? 1  : ( acc_tier == 1 ? 1  : ( acc_tier == 2 ? 2  : 3   ) ) ) );
	if ( acc_aoe_radius  < 1 ) acc_aoe_radius  = 1;
	if ( acc_chomper_cap < 1 ) acc_chomper_cap = 1;

	// [acc] PORTAL DAMAGE-OVER-TIME (user 2026-07-08: "instead of killing, damage over time - 1/5 zombie
	// health every second; 1/4, 1/3, then 1/2 at max tier" + "some damage to bosses too - 1/80, 1/65,
	// 1/50, 1/40 of theirs"). Replaces BOTH the pack's original kill call - radiusDamage(position, r,
	// level.zombie_health, ...), which provably lands ZERO kills on this map (portal opened, ammo
	// consumed, nothing died at pack-stock radius 96) - and the brief 2026-07-08 instant-kill sweep.
	// Ticks 1/s while the portal FX is live: normals + elites take frac x level.zombie_health (fractions
	// 0.20 / 0.25 / 0.3333 / 0.50 by tier, dvars acc_firebow_dot_frac_t0..3); BOSSES/mini-bosses take
	// maxhealth/div (80 / 65 / 50 / 40 by tier, dvars acc_firebow_dot_boss_div_t0..3 - under the 10%
	// per-hit cap at every tier). See bow_demongate_portal_dot. Note: the DoT carries no weapon ref, so
	// the Fury bow-one-shot branch keys off the ARROW hit only.
	acc_dot_frac = getdvarfloat( "acc_firebow_dot_frac_t" + acc_tier, ( acc_tier == 0 ? 0.20 : ( acc_tier == 1 ? 0.25 : ( acc_tier == 2 ? 0.3333 : 0.50 ) ) ) );
	if ( acc_dot_frac <= 0 ) acc_dot_frac = 0.20;
	e_portal.acc_dot_on = 1;
	e_portal thread bow_demongate_portal_dot( self, position, acc_aoe_radius, acc_dot_frac, acc_tier );
	// [acc] dev breadcrumb (RE-ENABLED 2026-07-11): open_portal reached the DoT launch (i.e. the tier block
	// above did not throw) with these resolved values. If this prints, the portal entity spawned and the DoT
	// thread was launched - so any "nothing dies" is downstream in bow_demongate_portal_dot (watch the tick line).
	acc_firebow_dbg_log( "^2portal OPEN tier=" + acc_tier + " r=" + acc_aoe_radius + " frac=" + acc_dot_frac + " z=" + int( position[ 2 ] ) );

	// [acc] CHARGE COST = 3 ARROWS TOTAL (user 2026-07-08; was 5 for ~an hour same evening): the engine's
	// full charge natively consumes 2; deduct 1 MORE from the clip here - the documented SAFE path
	// (raising the engine threshold dvar bg_zm_dlc1_chargeShotMultipleBulletsForFullCharge makes full
	// charge UNREACHABLE, see the 2026-07-07 note in on_connect_bow_demongate). This runs ONLY on a real
	// full-charge portal; partial/tap shots keep costing 1. Clamped at 0.
	if ( isdefined( self ) && isplayer( self ) )
	{
		acc_w_held = self GetCurrentWeapon();
		if ( isdefined( acc_w_held ) && acc_w_held != level.weaponNone
			 && isdefined( acc_w_held.name ) && IsSubStr( acc_w_held.name, "elemental_bow_demongate" ) )
		{
			acc_clip = self GetWeaponAmmoClip( acc_w_held );
			acc_extra = 1;
			if ( acc_clip < acc_extra ) acc_extra = acc_clip;
			if ( acc_extra > 0 ) self SetWeaponAmmoClip( acc_w_held, acc_clip - acc_extra );
		}
	}
	wait .25;

	e_portal thread bow_demongate_portal_shake_players();

	if ( getDvarInt( "splitscreen_playerCount" ) > 2 )
		n_round_group_health_remaining = 4 * level.zombie_health;
	else
		n_round_group_health_remaining = 2 * level.zombie_health;

	if ( level.a_demongate_chompers.size > 12 )
		n_chompers_to_spawn = math::clamp( 2, 1, acc_chomper_cap );   // global over-cap safety, never above the tier cap
	else
	{
		n_chompers_to_spawn = int( ( ( zombie_utility::get_current_zombie_count() + level.zombie_total ) * level.zombie_health ) / n_round_group_health_remaining );

		// [acc] tier cap replaces the pack's flat 4-6 min/max (RE-ENABLED 2026-07-08 with the scaling block).
		n_chompers_to_spawn = math::clamp( n_chompers_to_spawn, 1, acc_chomper_cap );
	}
	
	n_spawn_delay = 0;
	for ( i = 0; i < n_chompers_to_spawn; i++ )
	{
		e_chomper = bow_demongate_spawn_chomper( position, v_portal_angles - vectorScale( ( 0, 1, 0 ), 90 ) );
		e_chomper thread bow_demongate_chomper_move_forward( self, position );
		n_wait_time = .1;
		n_spawn_delay = n_spawn_delay + n_wait_time;
		wait n_wait_time;
	}
	if ( n_spawn_delay < 2 )
		wait 2 - n_spawn_delay;
	
	// [acc] VOID LIFETIME (2026-07-11): this tail wait was the pack's flat 2.5s -> the whole void (FX+DoT)
	// lived ~4.75s = max 5 ticks, so even an in-ring zombie rarely accumulated a kill (log-proven, 2:16 PM
	// run). Now dvar-tunable; default 5.0 -> ~7.25s void, ~7 ticks - an entering zombie that lingers dies.
	n_tail_secs = getdvarfloat( "acc_firebow_void_tail_secs", 5.0 );
	if ( n_tail_secs < 0.5 ) n_tail_secs = 0.5;
	wait n_tail_secs;
	e_portal.acc_dot_on = 0;   // [acc] the DoT stops when the visual does (the closed notify is 2s later)
	e_portal clientfield::set( "demongate_portal_fx", 0 );
	wait 2;
	e_portal notify( "demongate_portal_closed" );
	e_portal.b_portal_open = 0;
	wait 1.6;
	e_portal delete();
}

// [acc] Portal DoT ticker (user 2026-07-08). self = the portal entity; e_shooter = the firing player
// (kill credit; falls back to environment damage if they disconnected mid-portal). One tick immediately
// at open, then every 1s while the portal visual is live (acc_dot_on, cleared just before the FX-off).
// Per tick, everything within n_radius takes:
//   - normal zombies + elites: n_frac x level.zombie_health (min 1) - normals die in ~1/frac seconds.
//   - BOSSES + mini-bosses (user: "some damage to bosses too"): their OWN maxhealth / n_boss_div -
//     divisors 80 / 65 / 50 / 40 by PaP tier (live dvars acc_firebow_dot_boss_div_t0..3). The proven
//     thundergun_boss_blast maxhealth-fraction pattern; every tier sits well under the 10% boss
//     per-hit cap (max tier = 2.5%/s), so the ticks are never clamped.
// Dev-mode prints per tick (only when something is in range).
function bow_demongate_portal_dot( e_shooter, v_pos, n_radius, n_frac, n_tier )
{
	self endon( "death" );
	self endon( "demongate_portal_closed" );

	n_boss_div = getdvarint( "acc_firebow_dot_boss_div_t" + n_tier, ( n_tier == 0 ? 80 : ( n_tier == 1 ? 65 : ( n_tier == 2 ? 50 : 40 ) ) ) );
	if ( n_boss_div < 1 ) n_boss_div = 1;
	// Per-tick target cap (user 2026-07-08: "the void can only hit 20 enemies max at once") - counts
	// zombies + bosses combined; anything beyond the cap inside the radius is untouched that tick.
	// Live dvar acc_firebow_dot_max_targets.
	n_max_targets = getdvarint( "acc_firebow_dot_max_targets", 20 );
	if ( n_max_targets < 1 ) n_max_targets = 1;
	// Same-floor vertical window for the HORIZONTAL radius check below (see the 2026-07-11 note in
	// the sweep) - the portal center rides ~64u above the floor, so the band must clear that plus
	// crawlers/ramps while still excluding zombies a full storey away. Live dvar acc_firebow_dot_zband.
	n_zband = getdvarint( "acc_firebow_dot_zband", 160 );
	if ( n_zband < 64 ) n_zband = 64;

	// [acc] VOID SLOW (2026-07-11, the "kill zombies near it slowly" feel fix): zombies chase the PLAYER,
	// not the portal - at walk/sprint they cross the ring in ~1-2 ticks and leave with 20-40% damage
	// (log-proven). The demon gate now SLOWS normal zombies while they're inside (the pull fantasy):
	// ASMSetAnimationRate below 1.0 = THE zombie slow lever (root motion scales cadence AND ground speed;
	// the exact Widow's Wine mechanism, see _acc_zombie_speed.gsc header - SetMoveSpeedScale is
	// player-only). acc_fb_void_slowed is honored by the speed keepalive's under_anim_slow() so the 1.5s
	// sweep doesn't cancel it; a per-zombie watchdog restores rate 1.0 on ring-exit/portal-end (the WW
	// expiry idiom - the keepalive re-asserts the round rate within 1.5s). Bosses/specials never slowed
	// (they own their locomotion - the Brutus freeze lesson). Live dvar acc_firebow_void_slow_rate
	// (default 0.4; 0 or >=1 disables).
	n_slow_rate = getdvarfloat( "acc_firebow_void_slow_rate", 0.4 );
	b_slow = ( n_slow_rate > 0 && n_slow_rate < 1 );

	// [acc] dev breadcrumb (2026-07-08 hunt): the ticker STARTED (if [BOW] portal OPEN printed but this
	// didn't, the thread died between launch and here). Also shows whether level.zombie_health is live.
	acc_firebow_dbg_log( "^3DoT ENTER r=" + n_radius + " zband=" + n_zband + " zh=" + ( isdefined( level.zombie_health ) ? level.zombie_health : "UNDEF" ) + ( b_slow ? " slow=" + n_slow_rate : "" ) );

	tick = 0;
	while ( IS_TRUE( self.acc_dot_on ) )
	{
		// GUARD level.zombie_health (fury-style, _acc_fury.gsc:289-291): arithmetic on an undefined
		// field THROWS and kills this thread silently - the fury module guards this exact read.
		n_zh = level.zombie_health;
		if ( !isdefined( n_zh ) || n_zh <= 0 ) n_zh = level.zombie_vars[ "zombie_health_start" ];
		n_dmg = int( n_zh * n_frac );
		if ( n_dmg < ( n_zh * n_frac ) ) n_dmg++;   // ceil: N full ticks always finish the kill (int() left a sliver - e.g. 5x int(0.2*953) = 950 < 953)
		if ( n_dmg < 1 ) n_dmg = 1;

		n_hit = 0;
		n_boss_hit = 0;
		n_new_slow = 0;          // zombies newly slowed by the void this tick (dev diagnostic)
		n_nearest = -1;          // dev diagnostic: distance of the CLOSEST alive AI to the portal
		// GetAITeamArray("axis") = the VERIFIED zombie-array idiom in this map (_acc_damage:1339). The
		// first cut used a 2-arg GetAiSpeciesArray form nothing else here uses - if that returned
		// undefined, .size threw and this thread died SILENTLY before its first tick (the "void does
		// nothing, no dev prints" symptom; uncaught throws kill only the thread on this box).
		a_ai = GetAITeamArray( "axis" );
		if ( !isdefined( a_ai ) ) a_ai = [];
		for ( i = 0; i < a_ai.size; i++ )
		{
			if ( ( n_hit + n_boss_hit ) >= n_max_targets ) break;   // per-tick cap reached
			z = a_ai[ i ];
			if ( !isdefined( z ) || !isalive( z ) ) continue;
			// [acc] HORIZONTAL radius + z-band (2026-07-11, THE "void kills nothing" root cause): the
			// portal center sits ~64u ABOVE the floor (bow_demongate_get_impact_pos adds +normal[2]*64 on
			// floor hits / floor-snap+64 on wall hits) while a zombie's origin is at its FEET, so the old
			// 3D Distance() check gave tier 0/1 (radius 50/65) NO reachable volume at ground level
			// (sqrt(h^2 + 64^2) > 50 for every h - the un-PaP'd void could never damage a standing zombie)
			// and cut tier 2/3 (radius 80/95) to 48/70u of real reach. Same geometry killed the pack's
			// original radiusDamage ("provably lands zero damage"). Measure the ring horizontally; gate
			// height separately (same-floor band, acc_firebow_dot_zband).
			n_z_dist = Distance2D( z.origin, v_pos );
			if ( n_nearest < 0 || n_z_dist < n_nearest ) n_nearest = int( n_z_dist );
			if ( n_z_dist > n_radius ) continue;
			if ( abs( z.origin[ 2 ] - v_pos[ 2 ] ) > n_zband ) continue;

			n_z_dmg = n_dmg;
			if ( IS_TRUE( z.acc_is_boss ) || IS_TRUE( z.acc_is_mini_boss ) )
			{
				n_z_dmg = 1;
				if ( isdefined( z.maxhealth ) && z.maxhealth > 0 )
					n_z_dmg = int( z.maxhealth / n_boss_div );
				if ( n_z_dmg < 1 ) n_z_dmg = 1;
				n_boss_hit++;
			}
			else
			{
				n_hit++;
				// Demon-gate slow while inside the ring (normals only; see the VOID SLOW note above).
				if ( b_slow && !IS_TRUE( z.acc_fb_void_slowed ) && ( z zombie_utility::is_zombie() ) )
				{
					z.acc_fb_void_slowed = 1;
					z ASMSetAnimationRate( n_slow_rate );
					z thread bow_demongate_void_slow_watchdog( self, v_pos, n_radius, n_zband );
					n_new_slow++;
				}
			}

			// Damage applied in a CHILD THREAD per target (2026-07-11 hardening, found via console_mp.log:
			// pack AI damage handlers can THROW mid-chain - mechz_spiki's undefined-bool, avogadro's
			// targetname compare, both fixed but the CLASS of bug recurs on every pack adoption). A throw
			// inside our DoDamage call stack would kill THIS ticker with it; the child thread contains the
			// blast to that one target, and the log shows its "dmg ->" line with no "dmg OK" after
			// (= that target's damage chain threw). Mark + DoDamage details in the child.
			self thread bow_demongate_dot_damage_one( z, n_z_dmg, v_pos, e_shooter, tick + 1, n_hit + n_boss_hit );
		}

		tick++;
		// THE money line (2026-07-08 hunt, re-enabled 2026-07-11 into the persistent panel): a zero-hit tick is
		// itself diagnostic. `ai` = alive AI in the level; `near` = closest AI's distance to the portal center
		// vs `r` = the DoT ring radius (near > r = the portal is out of reach of every zombie = wrong
		// placement/radius); `hit=NxDMG` = zombies damaged this tick x per-hit damage. Per-target hp
		// before/after rides the child threads' "dmg ->"/"dmg OK" lines (first 3 targets per tick).
		acc_firebow_dbg_log( "^5tick " + tick + " ai=" + a_ai.size + " near=" + n_nearest + " r=" + n_radius + " hit=" + n_hit + "x" + n_dmg + " boss=" + n_boss_hit + ( n_new_slow > 0 ? " slow+" + n_new_slow : "" ) + ( ( n_hit + n_boss_hit ) >= n_max_targets ? " CAP@" + n_max_targets : "" ) );

		wait 1;
	}
	// Ticks that stop WITHOUT this line = the ticker thread died (an exception got past the child-thread
	// containment) - that exact silent death was a 2026-07-08 root-cause class.
	acc_firebow_dbg_log( "^3DoT END after " + tick + " ticks" );
}

// [acc] One tick's damage to ONE target, ALWAYS in its own thread (see the call site - exception
// containment). The EXACT damage mark (thundergun_boss_blast side-channel, one-shot consumed by
// _acc_damage::on_ai_damage) makes the tick land VERBATIM - without it the map's global x3.25 damage
// buff would rescale the spec fractions past the user's design. Mark + DoDamage both run in this same
// server frame (a spawned thread executes synchronously until its first wait), so no other hit can
// ride the mark.
function bow_demongate_dot_damage_one( z, n_dmg, v_pos, e_shooter, n_tick, n_idx )
{
	if ( !isdefined( z ) || !isalive( z ) )
		return;
	b_log = ( n_idx <= 3 );   // per-target detail for the first 3 targets each tick (log-volume cap)
	n_pre = ( isdefined( z.health ) ? z.health : -1 );
	str_arch = ( isdefined( z.archetype ) ? ( "" + z.archetype ) : "?" );
	if ( b_log )
		acc_firebow_dbg_log( " t" + n_tick + " dmg -> " + str_arch + " hp=" + n_pre + " take=" + n_dmg );
	z.acc_tg_exact_dmg = n_dmg;
	// Full 8-arg DoDamage = the pack's own chomper-vs-mechz idiom (this file, chomper_attack_mechz_target).
	// The bare 3-arg form landed ZERO on the mechz (log-proven 2026-07-11: take=812, hp 65000->65000) -
	// his hitloc-gated damage wrap drops MOD-less weaponless hits; MOD_PROJECTILE_SPLASH + the bow weapon
	// pass his filters, and the exact-damage mark still forces the tick value on the normal-zombie path.
	if ( isdefined( e_shooter ) && isplayer( e_shooter ) )
		z DoDamage( n_dmg, v_pos, e_shooter, e_shooter, undefined, "MOD_PROJECTILE_SPLASH", 0, level.w_bow_demongate );
	else
		z DoDamage( n_dmg, v_pos, undefined, undefined, undefined, "MOD_PROJECTILE_SPLASH", 0, level.w_bow_demongate );
	n_post = ( ( isdefined( z ) && isdefined( z.health ) ) ? z.health : 0 );
	if ( b_log )
		acc_firebow_dbg_log( " t" + n_tick + " dmg OK " + str_arch + " hp " + n_pre + "->" + n_post + ( ( isdefined( z ) && !isalive( z ) ) ? " ^2DEAD" : "" ) );
}

// [acc] VOID SLOW watchdog (self = a slowed zombie). Owns the restore END-TO-END so a slowed zombie can
// never be stranded slow-mo (the notetrack-Ghost-pairs lesson: every scripted state change carries its
// own timed restorer). Polls until the zombie leaves the ring or the portal's DoT ends, then hands the
// anim rate back at 1.0 - the WW-expiry idiom; _acc_zombie_speed's keepalive re-asserts the proper round
// rate within 1.5s (its under_anim_slow() honors acc_fb_void_slowed while we hold it).
function bow_demongate_void_slow_watchdog( e_portal, v_pos, n_radius, n_zband )
{
	self endon( "death" );
	while ( IS_TRUE( self.acc_fb_void_slowed ) )
	{
		if ( !isdefined( e_portal ) || !IS_TRUE( e_portal.acc_dot_on )
			 || Distance2D( self.origin, v_pos ) > n_radius
			 || abs( self.origin[ 2 ] - v_pos[ 2 ] ) > n_zband )
			break;
		wait 0.25;
	}
	self bow_demongate_void_unslow();
}

function bow_demongate_void_unslow()
{
	self.acc_fb_void_slowed = undefined;
	if ( isalive( self ) )
		self ASMSetAnimationRate( 1.0 );
}

function bow_demongate_portal_shake_players()
{
	self endon( "demongate_portal_closed" );
	while ( 1 )
	{
		foreach ( e_player in level.activeplayers )
		{
			if ( isDefined( e_player ) && !IS_TRUE( e_player.b_bow_portal_rumbling ) )
			{
				if ( distanceSquared( e_player.origin, self.origin ) < 9216 )
					e_player thread bow_demongate_portal_shake_player( self );
				
			}
		}
		WAIT_SERVER_FRAME;
	}
}

function bow_demongate_portal_shake_player( e_portal )
{
	self endon( "disconnect" );
	self endon( "bled_out" );
	self.b_bow_portal_rumbling = 1;
	self clientfield::set_to_player( "demongate_portal_rumble", 1 );
	while ( distanceSquared( self.origin, e_portal.origin ) < 9216 && IS_TRUE( e_portal.b_portal_open ) )
		WAIT_SERVER_FRAME;
	
	self.b_bow_portal_rumbling = 0;
	self clientfield::set_to_player( "demongate_portal_rumble", 0 );
}

function bow_demongate_fire_chomper( position, attacker )
{
	v_angles = anglesToForward( attacker.angles ) * -1;
	e_chomper = bow_demongate_spawn_chomper( position, v_angles );
	wait( 0.1 );
	e_chomper thread bow_demongate_chomper_start_attack( self );
}

function bow_demongate_spawn_chomper( position, v_angles )
{
	e_chomper = util::spawn_model( "c_zom_chomper", position, v_angles );
	e_chomper clientfield::set( "demongate_chomper_fx", 1 );
	e_chomper flag::init( "chomper_attacking" );
	e_chomper flag::init( "demongate_chomper_despawning" );
	if ( getDvarInt( "splitscreen_playerCount" ) > 2 )
		n_round_group_health_remaining = 4 * level.zombie_health;
	else
		n_round_group_health_remaining = 2 * level.zombie_health;
	
	e_chomper.n_chomper_round_group_health_remaining = n_round_group_health_remaining;
	e_chomper.b_look_for_target = 1;
	e_chomper thread demongate_chomper_failsafe();
	n_free_chomp_count = 0;
	n_chomp_total = level.a_demongate_chompers.size - 12;
	if ( n_chomp_total > 0 )
	{
		foreach ( e_chomper_b in level.a_demongate_chompers )
		{
			if ( !e_chomper_b flag::get( "chomper_attacking" ) && !IS_TRUE( e_chomper_b.b_chomper_stalking ) )
			{
				e_chomper_b.n_timer = 3;
				n_free_chomp_count++;
				if ( n_free_chomp_count > n_chomp_total )
					break;
				
			}
		}
	}
	if ( !isDefined( level.a_demongate_chompers ) )
		level.a_demongate_chompers = [];
	else if ( !isArray( level.a_demongate_chompers ) )
		level.a_demongate_chompers = array( level.a_demongate_chompers );
	
	level.a_demongate_chompers[ level.a_demongate_chompers.size ] = e_chomper;
	return e_chomper;
}

function bow_demongate_chomper_despawn()
{
	self flag::set( "demongate_chomper_despawning" );
	if ( !IS_TRUE( self.b_chomper_despawning ) )
	{
		self.b_chomper_despawning = 1;
		if ( !isDefined( level.n_chomper_last_despawn_time ) )
			level.n_chomper_last_despawn_time = getTime();
		else if ( level.n_chomper_last_despawn_time == getTime() )
			wait( randomFloatRange( 0.1, 0.2 ) );
		
		level.n_chomper_last_despawn_time = getTime();
		self moveTo( self.origin + vectorScale( ( 0, 0, 1 ), 96 ), 1.4 );
		self rotatePitch( -90, .4 );
		wait 1.4;
		self moveTo( self.origin, .1 );
		self clientfield::set( "demongate_chomper_fx", 0 );
		wait 3;
		self notify( "demongate_chomper_despawned" );
		level.a_demongate_chompers = array::exclude( level.a_demongate_chompers, self );
		self delete();
	}
}

function demongate_chomper_failsafe()
{
	self endon( "demongate_chomper_despawning" );
	self.n_timer = 0;
	while ( self.n_timer < 3 )
	{
		if ( !self flag::get( "chomper_attacking" ) && !IS_TRUE( self.b_chomper_stalking ) )
			self.n_timer = self.n_timer + .05;
		
		WAIT_SERVER_FRAME;
	}
	while ( self flag::get( "chomper_attacking" ) )
		wait .1;
	
	self thread bow_demongate_chomper_despawn();
}

function bow_demongate_chomper_move_forward( e_player, portal_origin )
{
	self.b_chomper_stalking = 1;
	self.origin = self.origin + ( 0, 0, randomIntRange( int( -51.2 ), int( 51.2 ) ) );
	self.angles = ( self.angles[ 0 ] + ( randomIntRange( -30, 30 ) ), self.angles[ 1 ] + ( randomIntRange( -45, 45 ) ), self.angles[ 2 ] );
	v_target_org = self.origin + ( anglesToForward( self.angles ) * 96 );
	self.angles = ( 0, self.angles[ 1 ], 0 );
	self moveTo( v_target_org, .4 );
	wait .4;
	self.b_chomper_stalking = 0;
	self bow_demongate_chomper_start_attack( e_player );
}

function bow_demongate_chomper_start_attack( e_player )
{
	self bow_demongate_chomper_acquire_new_target( e_player );
	if ( isDefined( self.target_enemy ) )
		self bow_demongate_chomper_think( e_player );
	else
		self thread bow_demongate_chomper_search( e_player );
	
}

function bow_demongate_chomper_search( e_player )
{
	self endon( "demongate_chomper_despawning" );
	self endon( "death" );
	if ( !isDefined( self ) )
		return;
	if ( self flag::get( "demongate_chomper_despawning" ) )
		return;
	
	self flag::clear( "chomper_attacking" );
	self clientfield::set( "demongate_wander_locomotion_anim", 1 );
	n_target_x = randomFloatRange( 5, 15 );
	n_target_y = randomFloatRange( 15, 45 );
	n_target_z = randomFloatRange( 15, 45 );
	n_target_x = ( randomInt( 100 ) < 50 ? n_target_x : n_target_x * -1 );
	n_target_y = ( randomInt( 100 ) < 50 ? n_target_y : n_target_y * -1 );
	n_target_z = ( randomInt( 100 ) < 50 ? n_target_z : n_target_z * -1 );
	if ( zm_utility::is_player_valid( e_player ) )
	{
		v_target_angles = e_player.angles;
		v_target_pos = e_player getEye();
	}
	else
	{
		v_target_angles = self.angles;
		v_target_pos = self.origin;
	}
	v_pos = ( v_target_angles[ 0 ] + n_target_x, v_target_angles[ 1 ] + n_target_y, v_target_angles[ 2 ] + n_target_z );
	v_norm = vectorNormalize( anglesToForward( v_pos ) );
	a_trace = physicsTraceEx( v_target_pos, v_target_pos + ( v_norm * 512 ), vectorScale( ( -1, -1, -1 ), 16 ), vectorScale( ( 1, 1, 1 ), 16 ) );
	v_target_org = a_trace[ "position" ] + ( v_norm * -32 );
	n_dist = distance( self.origin, v_target_org );
	n_time = n_dist / 48;
	v_rotate = v_target_org - self.origin;
	v_rotate = ( 0, v_rotate[ 1 ], 0 );
	
	if ( !isDefined( level.n_chomper_last_despawn_time ) )
		level.n_chomper_last_despawn_time = getTime();
	else if ( level.n_chomper_last_despawn_time == getTime() )
		wait( randomFloatRange( .1, .2 ) );
	
	level.n_chomper_last_despawn_time = getTime();
	self moveTo( v_target_org, n_time );
	self rotateTo( vectorToAngles( v_rotate ), n_time * .5 );
	self thread bow_demongate_chomper_find_flesh( e_player );
	self util::waittill_any_timeout( n_time * 2, "movedone", "demongate_chomper_found_target", "demongate_chomper_despawning", "death" );
	if ( isDefined( self.target_enemy ) )
	{
		self clientfield::set( "demongate_wander_locomotion_anim", 0 );
		self bow_demongate_chomper_think( e_player );
	}
	else
		self thread bow_demongate_chomper_search( e_player );
	
}

function bow_demongate_chomper_find_flesh( e_player )
{
	self endon( "demongate_chomper_despawning" );
	self endon( "demongate_chomper_found_target" );
	self endon( "movedone" );
	self endon( "death" );
	while ( !isDefined( self.target_enemy ) )
	{
		wait .2;
		self thread bow_demongate_chomper_acquire_new_target( e_player );
	}
}

function bow_demongate_chomper_think( e_player )
{
	n_target_enemy_health = self.target_enemy.health;
	self bow_demongate_chomper_move_to_player();
	if ( zm_weap_elemental_bow::is_bow_impact_valid( self.target_enemy ) )
	{
		n_variant = randomIntRange( 1, 7 );
		b_is_crawler = self.target_enemy.missinglegs;
		self.target_enemy.b_is_bow_hit = 1;
		self.b_look_for_target = 0;
		self.n_chomper_round_group_health_remaining = self.n_chomper_round_group_health_remaining - n_target_enemy_health;
		self thread bow_demongate_chomper_eat_zombie( n_variant, b_is_crawler );
		self thread bow_demongate_chomper_do_bite_fx();
		self thread bow_demongate_chomper_attack_target( e_player );
		if ( IS_TRUE( self.target_enemy.isdog ) || isVehicle( self.target_enemy ) )
			n_wait_time = .8;
		
		else if ( self.target_enemy.archetype === "mechz" )
		{
			n_wait_time = 2.6;
			self.n_chomper_round_group_health_remaining = 0;
		}
		else
		{
			n_wait_time = randomFloatRange( 2, 3 );
			self.target_enemy setPlayerCollision( 0 );
		}
		self.target_enemy util::waittill_notify_or_timeout( "death", n_wait_time );
		self notify( "chomper_reached_target" );
		self bow_demongate_chomper_eat_zombie_scene( n_variant, b_is_crawler );
		if ( self.n_chomper_round_group_health_remaining < 1 )
		{
			self thread bow_demongate_chomper_despawn();
			return;
		}
	}
	else if ( isDefined( self.target_enemy ) )
		self.target_enemy.b_hunted_by_chomper = 0;
	
	self flag::clear( "chomper_attacking" );
	self thread bow_demongate_chomper_start_attack( e_player );
}

function bow_demongate_chomper_do_bite_fx()
{
	self endon( "death" );
	self endon( "chomper_reached_target" );
	if ( self.target_enemy.archetype === "mechz" )
	{
		while ( 1 )
		{
			self clientfield::increment( "demongate_chomper_bite_fx", 1 );
			wait( 1 );
		}
	}
	else
	{
		while ( 1 )
		{
			self waittill( "chomper_bite" );
			self clientfield::increment( "demongate_chomper_bite_fx", 1 );
		}
	}
}

function bow_demongate_chomper_eat_zombie( n_variant, b_is_crawler )
{
	self.target_enemy endon( "death" );
	if ( IS_TRUE( self.target_enemy.isdog ) )
		self.target_enemy ai::set_ignoreall( 1 );
	else if ( self.target_enemy.archetype === "mechz" )
		self thread bow_demongate_chomper_eat_mechz();
	else if ( isVehicle( self.target_enemy ) )
		self.target_enemy.ignoreall = 1;
	else if ( IS_TRUE( b_is_crawler ) )
		self.target_enemy scene::play( "ai_zm_dlc1_zombie_demongate_chomper_attack_crawler", array( self.target_enemy, self ) );
	else
	{
		self.target_enemy scene::init( "ai_zm_dlc1_zombie_demongate_chomper_attack_0" + n_variant, array( self.target_enemy, self ) );
		self.target_enemy scene::play( "ai_zm_dlc1_zombie_demongate_chomper_attack_0" + n_variant, array( self.target_enemy, self ) );
	}
}

function bow_demongate_chomper_eat_mechz()
{
	e_mechz = self.target_enemy;
	self endon( "death" );
	self endon( "chomper_reached_target" );
	e_mechz endon( "death" );
	while ( 1 )
	{
		n_target_distance = isDefined( e_mechz.has_faceplate ) && ( e_mechz.has_faceplate ? 6 : 1 );
		n_target_pos = anglesToForward( self.target_enemy.angles ) * n_target_distance;
		self.origin = self.target_enemy getTagOrigin( "j_faceplate" ) + n_target_pos;
		self.angles = vectorToAngles( n_target_pos * -1 );
		WAIT_SERVER_FRAME;
	}
}

function bow_demongate_chomper_eat_zombie_scene( n_variant, b_is_crawler )
{
	if ( isDefined( self.target_enemy ) && self.target_enemy.archetype === "mechz" )
	{
		self.target_enemy thread bow_demongate_chomper_eat_mechz_scene();
		return;
	}
	if ( isDefined( self.target_enemy ) && !IS_TRUE( self.target_enemy.isdog ) )
	{
		if ( IS_TRUE( b_is_crawler ) )
			self.target_enemy thread scene::stop( "ai_zm_dlc1_zombie_demongate_chomper_attack_crawler" );
		else
			self.target_enemy thread scene::stop( "ai_zm_dlc1_zombie_demongate_chomper_attack_0" + n_variant );
		
	}
	if ( IS_TRUE( b_is_crawler ) )
		self thread scene::stop( "ai_zm_dlc1_zombie_demongate_chomper_attack_crawler" );
	else
		self thread scene::stop( "ai_zm_dlc1_zombie_demongate_chomper_attack_0" + n_variant );
	
}

function bow_demongate_chomper_eat_mechz_scene()
{
	self endon( "death" );
	self.b_mechz_hit_by_chomper = 1;
	wait 16;
	self.b_mechz_hit_by_chomper = 0;
}

function bow_demongate_chomper_move_to_player()
{
	self flag::set( "chomper_attacking" );
	v_eye_pos = self.target_enemy getEye();
	n_dist = distance( self.origin, v_eye_pos );
	n_loop_count = 1;
	n_coin = ( math::cointoss() ? 1 : -1 );
	self clientfield::set( "demongate_attack_locomotion_anim", 1 );
	while ( n_dist > 32 && isDefined( self.target_enemy ) && isalive( self.target_enemy ) )
	{
		v_eye_pos = self.target_enemy getEye();
		n_time = n_dist / 640;
		n_incriment = 1 / n_loop_count;
		n_scale = vectorScale( ( 0, 0, 1 ), 160 ) * n_incriment;
		v_offset = ( anglesToRight( vectorToAngles( v_eye_pos - self.origin ) ) ) * 256;
		v_offset = v_offset * n_incriment;
		v_offset = v_offset * n_coin;
		v_target_pos = ( v_eye_pos + v_offset ) + n_scale;
		v_rotate = v_target_pos - self.origin;
		v_rotate = ( 0, v_rotate[ 1 ], 0 );
		
		if ( !isDefined( level.n_chomper_last_despawn_time ) )
			level.n_chomper_last_despawn_time = getTime();
		else if ( level.n_chomper_last_despawn_time == getTime() )
			wait randomFloatRange( .1, .2 );
		
		level.n_chomper_last_despawn_time = getTime();
		self moveTo( v_target_pos, n_time );
		self rotateTo( vectorToAngles( v_rotate ), n_time * .5 );
		n_time = n_time * .3;
		n_time = ( n_time < .1 ? .1 : n_time );
		wait n_time;
		n_loop_count++;
		n_dist = distance( self.origin, v_eye_pos );
	}
	self clientfield::set( "demongate_attack_locomotion_anim", 0 );
	if ( isDefined( self.target_enemy ) && isalive( self.target_enemy ) )
		self.origin = v_eye_pos;
	
}

function bow_demongate_chomper_attack_target( e_player )
{
	e_target = self.target_enemy;
	e_target endon( "death" );
	if ( e_target.archetype === "mechz" )
	{
		self thread bow_demongate_chomper_attack_mechz_target( e_player );
		return;
	}
	n_damage = e_target.health;
	self waittill( "chomper_reached_target" );
	e_target setPlayerCollision( 1 );
	e_target.b_hunted_by_chomper = 0;
	e_target.b_is_bow_hit = 0;
	if ( zm_utility::is_player_valid( e_player ) )
		e_chomper_target = e_player;
	else
		e_chomper_target = undefined;
	
	e_target doDamage( n_damage, e_target.origin, e_chomper_target, e_chomper_target, undefined, "MOD_UNKNOWN", 0, level.w_bow_demongate );
	gibserverutils::gibhead( e_target );
}

function bow_demongate_chomper_attack_mechz_target( e_player )
{
	e_target = self.target_enemy;
	e_target endon( "death" );
	
	n_max_mechz_health = level.mechz_health;
	
	n_damage = ( n_max_mechz_health * .2 ) / .2;
	if ( zm_utility::is_player_valid( e_player ) )
		e_chomper_target = e_player;
	else
		e_chomper_target = undefined;
	
	e_target doDamage( n_damage, e_target.origin, e_chomper_target, e_chomper_target, undefined, "MOD_PROJECTILE_SPLASH", 0, level.w_bow_demongate );
	self waittill( "chomper_reached_target" );
	e_target.b_hunted_by_chomper  = 0;
	e_target.b_is_bow_hit = 0;
}

function bow_demongate_chomper_acquire_new_target( e_player )
{
	if ( self flag::get( "demongate_chomper_despawning" ) )
		return;
	
	self.target_enemy = undefined;
	v_target_org = self.origin;
	n_target_radius = 1024;
	if ( IS_TRUE( self.b_look_for_target ) )
	{
		if ( zm_utility::is_player_valid( e_player ) )
			v_target_org = e_player.origin;
		
		n_target_radius = 1024;
	}
	a_ai_enemies = getAiTeamArray( level.zombie_team );
	a_valid_enemies = arraySortClosest( a_ai_enemies, v_target_org, a_ai_enemies.size, 0, n_target_radius );
	a_valid_enemies = array::filter( a_valid_enemies, 0, &zm_weap_elemental_bow::is_bow_impact_valid );
	a_valid_enemies = array::filter( a_valid_enemies, 0, &bow_demongate_chomper_validate_target, self );
	if ( a_valid_enemies.size )
	{
		e_favorite_enemy = a_valid_enemies[ 0 ];
		e_favorite_enemy.b_hunted_by_chomper = 1;
		self.target_enemy = e_favorite_enemy;
		self notify( "demongate_chomper_found_target" );
	}
}

function bow_demongate_chomper_validate_target( e_favorite_enemy, e_chomper )
{
	// [acc] Chompers eat NORMAL zombies ONLY (user 2026-07-07): specials / elites / bosses are the AoE's job -
	// the charged blast still hits glitch / shielded / Apothicon Fury + bosses (the fury x8 rides that path),
	// but the roaming chompers ignore them. Returning false drops them from acquire_new_target's filter lists.
	if ( IS_TRUE( e_favorite_enemy.acc_is_glitch_zombie ) || IS_TRUE( e_favorite_enemy.acc_is_shielded )
	     || IS_TRUE( e_favorite_enemy.b_is_apothicon_fury ) || IS_TRUE( e_favorite_enemy.acc_is_boss )
	     || IS_TRUE( e_favorite_enemy.acc_is_mini_boss ) )
		return false;
	return !( IS_TRUE( e_favorite_enemy.b_hunted_by_chomper ) && ( ( isDefined( e_favorite_enemy.completed_emerging_into_playable_area ) && e_favorite_enemy.completed_emerging_into_playable_area ) || !isDefined( e_favorite_enemy.completed_emerging_into_playable_area ) ) && ( e_favorite_enemy.archetype === "zombie" && IS_TRUE( e_favorite_enemy.completed_emerging_into_playable_area ) ) || ( e_favorite_enemy.archetype !== "zombie" ) && bulletTracePassed( e_favorite_enemy getEye(), e_chomper.origin, 0, e_chomper ) );
}