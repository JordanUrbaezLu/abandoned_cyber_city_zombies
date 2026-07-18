// =============================================================================
// _acc_movement.gsc - GLOBAL player slide mechanics (EVERY player, no item gate).
//
// Owns the base "how does moving around this map feel" layer:
//   (1) SLIDE-JUMP MOMENTUM CARRY - jumping out of a slide keeps the slide's speed
//   (2) SLIDE STEERING            - you can actually turn while sliding
//   (3) SLIDE SUSTAIN             - the slide carries ~1.25x as far
//
// WHY A SEPARATE, GLOBAL MODULE (user 2026-07-15 "no bugs between equipping all these
// things that impact players speed"):
// The momentum carry was originally duplicated inside _acc_boss_items::rocket_shield_watch
// AND _acc_mega_bottles::mega_flopper_slide_watch - so (a) it only worked if you happened
// to hold one of those two, and (b) the same fiddly state machine existed twice = two
// chances to desync and two places to fix every bug. Slide FEEL is a base mechanic of this
// map, not an item perk. So it lives here, ONCE, for everyone; the item watchers keep only
// their own speed FLAG (+ the Rocket Shield's kick/jump-height, which really are its own).
// Because the carry records ACTUAL VELOCITY, it automatically includes whatever was live
// during the slide (Rocket Shield 2x, PhD Slider 1.75x, nitro burst, Boots, Stamin-Up's
// engine base, all of it, already clamped by the 2.2x cap) with ZERO per-item wiring - and
// it can never "cancel out" another system, because it only ever reads the result.
//
// ---------------------------------------------------------------------------
// THE JANK LESSON - THE ARCHITECTURAL RULE FOR THIS FILE. DO NOT UNDO THIS.
// ---------------------------------------------------------------------------
// (user 2026-07-15, after two failed attempts: "slide and start walking you have that
// speed boost but that ramp is just janky")
//
//   SetMoveSpeedScale IS NOT A MOMENTUM LEVER. It scales INPUT-DRIVEN movement.
//
// Holding the slide's 2x scale up after the slide ends (a "grace window"), or decaying it
// down (a "release ramp"), means the player WALKS at 2x for a moment. That does not read
// as momentum - it reads as ice / unresponsiveness, and it was a balance leak too (a free
// ~1s of 2x walking after every slide). Both attempts were rejected on feel.
//
//   MOMENTUM IS VELOCITY.
//
// So: the speed-scale FLAG is ON only while IsSliding() is actually true, and the carry is
// done by SETTING VELOCITY at the jump. This works WITH the engine instead of against it:
//   - Airborne, the engine does not decelerate horizontal velocity (air accel only ADDS
//     toward wishdir), so a launch at slide speed simply flies. No scale needed.
//   - On landing, the engine's own ground friction bleeds the excess off over a few frames.
//     That natural decel IS the smooth feel the ramp was trying (and failing) to fake.
// The engine already does the smoothing for free. Our job is only to make sure the player
// LEAVES THE GROUND at the right speed.
//
// WHY THE POLL (and not a notify): the engine's slide_begin / slide_end / jump notifies are
// MP-ONLY - they never fire in ZM (CLAUDE.md). IsSliding() polled at 20Hz is the only
// observation channel we have, which is also why the pre-jump top-up exists (below).
// =============================================================================

#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_movement;

function init()
{
    acc_utility::log( "movement init (slide momentum / steering / sustain)" );
    apply_engine_slide_tuning();
}

// ---------------------------------------------------------------------------
// ENGINE SLIDE TUNING - duration + steering (user 2026-07-15: "increase slide duration to
// 1.25x current duration and make handling during slide a lot more maneuverable. Right now
// if you slide you basically can't turn").
//
// *** RETRACTION *** docs/09 used to state "BO3 exposes no per-player slide-duration lever",
// and we shipped the Rocket Shield's forward LUNGE as a substitute. That claim is FALSE at
// the global level: BO3 ships a 62-dvar `slide_*` engine family, including a literal
// duration lever and a literal steering toggle. Recovered 2026-07-15 from the Treyarch
// string table inside <tools>\bin\cod2map64.exe (descriptions below are Treyarch's OWN,
// verbatim - they sit immediately before each name in the table) and independently
// corroborated by the T7Overcharged dvar hash list (JariKCoding/T7Overcharged,
// usage/dvar_hash_list.txt, 7025 name,hash entries; 62 slide_*). The two sources are
// provably NON-CIRCULAR - each contains slide_* dvars the other lacks. That the exe table
// is the GAME movement table (not tool dvars) is proven by it carrying wallrun_* /
// doublejump_* / playerEnergy_*, which are BO3-exclusive mechanics.
//   NOTE for the next agent: scanning the RETAIL BlackOps3.exe for these names finds
//   NOTHING - that result is VOID, not negative. The retail exe is packed and T7 stores
//   dvars by HASH; the controls (bg_gravity / jump_height / cg_fov) come back empty too.
//   Don't "disprove" this that way.
//
// SETTING ENGINE MOVEMENT DVARS FROM GSC IS STOCK PRACTICE, not a hack:
// tmp/bo3_stock_ref/scripts/zm/_zm.gsc:215-225 ("New movement disabled for Zombies") does
// exactly this - unconditionally, in the ZM path, with no sv_cheats gate:
// SetDvar("doublejump_enabled",0) / ("juke_enabled",0) / ("playerEnergy_enabled",0) /
// ("wallrun_enabled",0) / ("sprintLeap_enabled",0) / ("traverse_mode",2). Our own map
// already ships one (_acc_bus_trench.gsc:281 SetDvar("bg_fallDamageMinHeight",1024),
// verified live). Nothing in stock reads or writes any slide_* dvar (no clobber risk), and
// acc_main::init() runs AFTER zm_usermap::main(), so our write lands last.
//
// THE SLIDE IS DUAL-GATED - it ends at whichever fires FIRST:
//   slide_maxTime*              "The max time in ms the player is allowed to slide for"
//   slide_min_continue_velocity "Required speed a player must sliding to continue sliding"
//   slide_friction_amount       "The amount of friction to apply while sliding"  <- drives
//                               you DOWN toward that speed floor
// CONSEQUENCE: if friction drops you under the floor BEFORE the timer expires, the SPEED
// gate is binding, the timer is slack, and raising the timer alone does NOTHING. If the
// slide does not feel ~25% longer in game, THAT is the diagnosis - the next lever is
// acc_slide_friction_scale below (hardcode it to 0.8), not a bigger timer.
//
// WHICH TIMER IS THE ZM ONE (inference, flagged): ZM disables player energy
// (_zm.gsc:220 playerEnergy_enabled 0), and slide_speedBase is documented as "The slide
// start speed IF NO PLAYER ENERGY" -> ZM almost certainly runs the BASE slide state, making
// slide_maxTimeBase the operative lever ("Reduced" is the spam-slide state, cf.
// slide_subsequentSlideTime). NOT verified, so we scale all three - they are all "max time
// to slide" and there is no downside to setting a slack one.
//
// TWO TRAPS THIS CODE IS BUILT AROUND - do not "simplify" them away:
//  (1) SetDvar on an UNREGISTERED dvar silently creates a dead SCRIPT dvar and no-ops, so
//      failure is indistinguishable from success. We therefore READ first (getdvarstring
//      returns "" when unregistered) and skip cleanly if the family is not in retail.
//  (2) DVARS PERSIST ACROSS MAP LOADS within a Steam session, so the obvious
//      SetDvar( x, getdvarfloat( x ) * 1.25 ) COMPOUNDS on every restart: 1.25 -> 1.56 ->
//      1.95 -> ... Fix: capture the PRISTINE default ONCE per Steam session into our own
//      acc_slide_orig_* dvar (which persists the same way) and always scale from THAT.
//      Idempotent no matter how many times the map is loaded.
// ---------------------------------------------------------------------------
function apply_engine_slide_tuning()
{
    // Duration: 1.25x (user 2026-07-15). Live-tunable for balance experiments.
    dur = getdvarfloat( "acc_slide_duration_scale", 1.25 );
    scale_engine_dvar( "slide_maxTimeBase", dur );      // the likely ZM lever (base slide state)
    scale_engine_dvar( "slide_maxTime", dur );          // set anyway - harmless if slack
    scale_engine_dvar( "slide_maxTimeReduced", dur );   // spam-slide state

    // The OTHER half of the dual gate. Default 1.0 = UNTOUCHED on purpose: friction changes
    // slide DISTANCE and feel, not just length, so we only reach for it if the timer alone
    // does not lengthen the slide (i.e. the speed floor is binding). 0.8 = 1/1.25.
    fric = getdvarfloat( "acc_slide_friction_scale", 1.0 );
    scale_engine_dvar( "slide_friction_amount", fric );

    // STEERING - the engine's own lever, verbatim: "Allow the player to adjust their
    // velocity to the left/right while sliding". "You basically can't turn" is exactly the
    // symptom of this shipping 0 in ZM.
    //
    // WHY THE DVAR AND NOT A SCRIPT VELOCITY-ROTATION LOOP (the obvious alternative -
    // rejected on evidence, do not re-attempt without reading this): GSC CANNOT READ THE
    // MOVEMENT STICK. T7 exposes only BOOLEAN button states (JumpButtonPressed,
    // SprintButtonPressed, ...); GetNormalizedMovement / GetNormalizedCameraMovement do not
    // exist (0 hits in the stock mirror). So a script loop could only steer toward VIEW YAW
    // = look-steering, a different and worse feel than true strafe-steering. Worse, the
    // server is capped at 20Hz (shared.gsh:263 SERVER_FRAME .05 - there is NO faster server
    // wait; `waitframe()` does not exist), so it would be 20 discrete velocity steps/sec =
    // steppy, which is the exact jank we are trying to remove. The engine dvar reads the
    // real analog stick at engine tick rate. Strictly better.
    set_engine_dvar( "slide_enable_tweak_left_right", 1 );
    // slide_deadzoneTweek ("The threshold the amount of right or left movement must overcome
    // for it to be applied") is the SENSITIVITY knob if the steering lands but feels too
    // stiff - lower = more responsive. Left at stock until the toggle is confirmed working.
}

// Scale an ENGINE dvar to (pristine session default * mult), idempotently across map loads.
// Returns silently (and sets NOTHING) if the dvar is not registered in this build - see trap
// (1) above: a blind SetDvar there would create a dead script dvar and look like success.
function scale_engine_dvar( name, mult )
{
    if ( mult == 1.0 ) return;   // no-op scale: never touch the dvar at all

    orig_key = "acc_slide_orig_" + name;
    orig     = getdvarfloat( orig_key, -1 );   // -1 = not yet captured this Steam session
    if ( orig < 0 )
    {
        if ( getdvarstring( name, "" ) == "" )
        {
            acc_utility::log( "slide tune: " + name + " NOT REGISTERED in this build - skipped" );
            return;
        }
        orig = getdvarfloat( name, 0 );
        SetDvar( orig_key, orig );   // remember the pristine value for the rest of the Steam session
    }
    SetDvar( name, orig * mult );
    acc_utility::log( "slide tune: " + name + " " + orig + " -> " + ( orig * mult ) + " (x" + mult + ")" );
}

// Absolute set (idempotent by nature - no pristine capture needed), with the same
// registration probe so an absent dvar is logged instead of silently no-op'ing.
function set_engine_dvar( name, value )
{
    if ( getdvarstring( name, "" ) == "" )
    {
        acc_utility::log( "slide tune: " + name + " NOT REGISTERED in this build - skipped" );
        return;
    }
    SetDvar( name, value );
    acc_utility::log( "slide tune: " + name + " -> " + value );
}

// Dispatched from acc_main::on_player_spawned. Fires on EVERY respawn (round start, revive,
// map load), so the stop-notify is what keeps exactly ONE watcher per player instead of a
// new one stacking every death (each would fight the others' SetVelocity).
function on_player_spawned( player )
{
    player notify( "acc_slide_think_stop" );
    player thread slide_think();
}

// ---------------------------------------------------------------------------
// The one slide watcher.
// ---------------------------------------------------------------------------
function slide_think()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_slide_think_stop" );

    was_ground  = true;
    carry_until = 0;   // gettime() deadline - the window in which a jump still gets the carry
    carry_speed = 0;   // horizontal speed on the last sliding tick = the momentum to preserve

    for ( ;; )
    {
        wait( 0.05 );

        v        = self GetVelocity();
        onground = self IsOnGround();
        in_slide = ( self IsSliding() && onground );

        if ( in_slide )
        {
            // Record the momentum + (re)arm the jump window. carry_speed is the player's
            // ACTUAL speed, so every boost that was live during the slide is already in it.
            carry_speed = sqrt( v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ] );
            carry_until = gettime() + int( getdvarfloat( "acc_slide_jump_grace", 0.5 ) * 1000 );
        }

        armed = ( carry_speed > 0 && gettime() < carry_until );

        // (1) PRE-JUMP TOP-UP - the real fix for "the slide->jump transition is super janky".
        // A BO3 slide-jump is slide -> STAND UP (grounded, IsSliding() already false for a
        // few frames) -> jump. Ground friction clamps you back toward walk speed in that gap,
        // so you were launching SLOW and then getting jerked forward mid-air by (2). Catching
        // the jump BUTTON while still grounded lets us top the speed up BEFORE the engine
        // launches, so the arc starts fast and (2) has nothing left to fix.
        if ( armed && onground && !in_slide && self JumpButtonPressed() )
        {
            restore_speed( carry_speed );
        }

        // (2) LIFTOFF RESTORE - fallback for when the 20Hz poll misses the button press
        // entirely (a tap between two ticks). Fires within one tick of leaving the ground.
        if ( armed && was_ground && !onground && v[ 2 ] > 10 )
        {
            restore_speed( carry_speed );
        }

        was_ground = onground;
    }
}

// Scale the player's CURRENT horizontal heading back up to `want`, preserving:
//   - DIRECTION: their steering stays theirs (no rubber-banding them back down the slide line)
//   - Z: the jump's rise is untouched, so the Rocket Shield's jump-height multiply composes.
//     (Both watchers GetVelocity() FRESH immediately before they SetVelocity, so two writes in
//     the same server frame compose - each reads the other's result - instead of clobbering.)
// Only ever RAISES speed, never lowers it - so this can never cancel a boss fling, a knockback,
// or any other impulse; a player already moving faster than `want` is left completely alone.
// Braked-player floor: under half the slide speed you clearly meant to stop, so nothing
// launches you against your input.
function restore_speed( want )    // self = player
{
    v  = self GetVelocity();
    sp = sqrt( v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ] );
    if ( sp <= want * 0.5 || sp >= want ) return;
    self SetVelocity( ( v[ 0 ] * want / sp, v[ 1 ] * want / sp, v[ 2 ] ) );
}
