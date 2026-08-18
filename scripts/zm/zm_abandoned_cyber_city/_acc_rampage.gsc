// =============================================================================
// _acc_rampage.gsc - RAMPAGE INDUCER v2 (user 2026-08-03)
//
// A power-breaker station on the Plaza->Alley connector the players can TOGGLE during
// rounds 1-4. While ON,
// the round-based speed curve is evaluated at round+7 for EXACTLY four enemy classes:
// normal zombies, Glitch Stalkers, armored (Shielded) elites, and the Scientist. NOTHING
// else changes (user: "All it does is make zombies, glitch, armored zombies and the
// scientist faster. Nothing else.") - no spawn-count/spawn-delay levers, no other boss.
// Once round ACC_RAMPAGE_LOCK_ROUND (5) starts, the toggle SEALS at whatever state it
// was left on for the rest of the match.
//
// STATE SURFACE: level.acc_rampage_on (plain level boolean, set ONLY here). The speed
// layer reads it via acc_zombie_speed::effective_round() (= current_round() + 7 while
// ON), consumed by exactly the four target call sites - see _acc_zombie_speed.gsc.
//
// WHY THIS DESIGN (the 2026-06-13/14 Rampage Inducer died in 6 iterations - CHANGELOG
// 22797..21159 - and each failure mode is dodged here BY CONSTRUCTION):
//   1. "sprints a few seconds then stops": a leftover acc_rampage dvar watcher polled the
//      dvar and deactivated the device 1s later. -> NO dvar toggle exists at all; the
//      station is the only writer of level.acc_rampage_on.
//   2. One-way toggle (`if(active) continue`). -> every use flips the state.
//   3. Raw ASMSetAnimationRate(1.7) overshoot + a competing pacing writer netting it out.
//      -> no new rate writers ANYWHERE: the existing curve consumers just read a +7 round.
//   4. One-shot sprint override decayed on stock locomotion re-evals ("stops after a
//      minute"). -> the existing 1.5s keep-alive re-asserts every sweep; a toggle
//      retro-applies to live AI within one sweep, both directions.
//   5. The keep-alive sweep froze Brutus (stomped his custom ASM). -> the boss guard in
//      apply_speed_for_round still skips every boss marker; Phantom (fixed gait), Brutus,
//      Avogadro, Rogue, Panzer, Fury are untouched because their speed paths never call
//      effective_round().
//
// Station recipe = the proven _acc_leaderboard::station_setup() clone (script-spawned
// model + trigger_radius_use, no baked geometry). Model = p7_zm_ver_powerbreaker, grounded
// (see the MODEL note above the defines; the original floating Berzerker-skull reuse was
// rejected in the 2026-08-03 playtest). Hints keep RAMPAGE as the router guard word (LUI
// cursor-hint catch-alls hijack hints containing shop-words - memory
// lui-cursorhint-router-loose-weapon-matcher).
// =============================================================================

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;   // set_glow: the red state pulse rides the accPerkGlow CF
#using scripts\zm\zm_abandoned_cyber_city\_acc_zombie_speed;  // rampage_bonus (single source of the +7 default; no cycle - zombie_speed reads the raw level flag)

#insert scripts\shared\shared.gsh;   // IS_TRUE

// MODEL (user 2026-08-03 playtest: "look through models and select one that makes sense...
// this current model is already used for things... I don't want it floating"): the skull was
// the Berzerker pickup's model AND floated. Now p7_zm_ver_powerbreaker - a freestanding
// 93x16x112u industrial breaker slab (zone:912; used elsewhere ONLY as inert abyss deco,
// _acc_abyss_deco spawns it flush at exact floor z = proven base pivot). A breaker you THROW
// is the one prop whose semantics ARE the toggle. NO #precache needed - zone-line-only
// models script-spawn fine (the _acc_abyss_deco/_acc_surface_deco pattern).

#define ACC_RAMPAGE_ORIGIN      ( 1020, 412, 0 )  // Plaza->Alley connector, S wall (user: "place it on the path to alley from plaza") - slab south face ~4u off the y=400 inner wall plane, ~200u before the enter_alley door, corridor N side left clear; every walk to the Alley passes it
#define ACC_RAMPAGE_MODEL_Z     0                 // GROUNDED (user: "I don't want it floating") - base pivot sits flush
#define ACC_RAMPAGE_SCALE       1                 // real-size breaker slab (93x16x112)
#define ACC_RAMPAGE_YAW         180               // slab parallel to the S wall (93u run along x; the panel normal is on the thin +-y axis - if the in-game look shows the slab's BACK to the corridor, flip this to 0)
#define ACC_RAMPAGE_LOCK_ROUND  5                 // round the toggle SEALS (user: "once round 5 hits you cant toggle anymore")
#define ACC_RAMPAGE_DEBOUNCE_MS 2000   // trigger_radius_use refires EVERY FRAME while held - 500ms let a held
                                       // +activate flip-flop the state (+ banner spam) twice a second
                                       // (verify-pass catch 2026-08-03); 2s = one toggle per deliberate press

#namespace acc_rampage;

function init()
{
    level.acc_rampage_on = false;
    level.acc_rampage_debounce_until = 0;
    level thread station_setup();
    acc_utility::log( "rampage: station init (lock at round " + ACC_RAMPAGE_LOCK_ROUND + ")" );
}

function station_setup()
{
    level endon( "end_game" );

    m = spawn( "script_model", ACC_RAMPAGE_ORIGIN + ( 0, 0, ACC_RAMPAGE_MODEL_Z ) );
    m setmodel( "p7_zm_ver_powerbreaker" );
    m SetScale( ACC_RAMPAGE_SCALE );
    m.angles = ( 0, ACC_RAMPAGE_YAW, 0 );
    acc_interact_glow::glow_on( m );

    // Raised trigger origin gives the use-cursor something to land on; TriggerIgnoreTeam is
    // REQUIRED or the trigger is never usable (stock _zm_perks:1523). Radius 64 >= the
    // breaker's 46.5u max half-extent + 15 (station-trigger-radius rule; 61.5 needed).
    t = spawn( "trigger_radius_use", ACC_RAMPAGE_ORIGIN + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( hint_for_state() );

    level thread lock_watcher( t, m );
    level thread pulse_think( m );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;
        if ( GetTime() < level.acc_rampage_debounce_until ) continue;
        level.acc_rampage_debounce_until = GetTime() + ACC_RAMPAGE_DEBOUNCE_MS;

        // The AUTHORITATIVE round-5 gate lives here in the use loop (the lock_watcher only
        // handles hint/glow cosmetics - a player holding the trigger exactly as round 5
        // starts must still be refused).
        if ( locked() )
        {
            player PlaySound( "zmb_no_purchase" );
            t SetHintString( hint_for_state() );
            continue;
        }

        level.acc_rampage_on = !IS_TRUE( level.acc_rampage_on );
        player PlaySound( "zmb_cha_ching" );
        t SetHintString( hint_for_state() );

        // Every-toggle announcement (the jukebox NOW-PLAYING pattern - NOT announce_once,
        // this is a state change, not a recurring info banner).
        foreach ( p in GetPlayers() )
        {
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( IS_TRUE( level.acc_rampage_on ) )
                p IPrintLnBold( "^1RAMPAGE ^2ON^7 - the horde runs " + rampage_bonus() + " rounds faster" );
            else
                p IPrintLnBold( "^1RAMPAGE^7 ^1OFF^7 - the horde runs at normal speed" );
        }
        acc_utility::log( "rampage: toggled -> " + ( IS_TRUE( level.acc_rampage_on ) ? "ON" : "OFF" )
                          + " by " + player.name + " (round " + level.round_number + ")" );
    }
}

// Cosmetics-only at the seal: freeze the hint into its locked form and kill the invite
// glow. The use-loop's locked() check is the real gate.
function lock_watcher( t, m )
{
    level endon( "end_game" );

    while ( !locked() )
        level waittill( "between_round_over" );

    t SetHintString( hint_for_state() );
    acc_interact_glow::glow_off( m );
    acc_utility::log( "rampage: SEALED " + ( IS_TRUE( level.acc_rampage_on ) ? "ON" : "OFF" )
                      + " at round " + level.round_number );
}

// PULSING RED state light while RAMPAGE is ON (user 2026-08-03 "pulsing red fx to signify
// that rampage is on. Off it looses its red fx light"). Rides the proven CLIENT-rendered
// perk-glow pipeline - acc_perk_lights::set_glow on the breaker scriptmover, colour 1 = the
// Jugg RED aura (fx_perk_glow_red, already client-precached) - because a bare server
// PlayFX never renders (memory server-playfx-does-not-render) and the scriptmover
// clientfield pool is FULL (no new CF; accPerkGlow is an existing registration, and
// set_glow is public "for ANY scriptmover ent" - the lockdown purge-room precedent).
// Pulse = 1/0 toggle at ~1 Hz. Runs for the whole match: a SEALED-ON station keeps
// pulsing (the light signifies the rampage STATE, not the toggle's usability - the
// interact shimmer is what lock_watcher kills at the seal).
function pulse_think( m )
{
    level endon( "end_game" );

    was_on = false;
    for ( ;; )
    {
        if ( !isdefined( m ) ) return;
        if ( IS_TRUE( level.acc_rampage_on ) )
        {
            acc_perk_lights::set_glow( m, 1 );   // red aura ON-beat
            wait 0.55;
            if ( !isdefined( m ) ) return;
            acc_perk_lights::set_glow( m, 0 );   // off-beat = the pulse
            wait 0.4;
            was_on = true;
        }
        else
        {
            if ( was_on )
            {
                acc_perk_lights::set_glow( m, 0 );   // one transition write, then stay silent
                was_on = false;
            }
            wait 0.5;
        }
    }
}

function locked()
{
    // undefined round = pre-round-1 load window = rounds 1-4 territory (unlocked).
    return ( isdefined( level.round_number ) && level.round_number >= ACC_RAMPAGE_LOCK_ROUND );
}

function rampage_bonus()
{
    return acc_zombie_speed::rampage_bonus();   // single source of truth (define + dvar live in the speed
                                                // module) - never re-inline the default (drift trap)
}

// RAMPAGE is the router guard word (unique, non-shop) - keep hints free of ' for '/'open'/
// 'cost'/'pack'/'punch'/'mystery'/perk names or the LUI cursor-hint catch-alls swallow them.
function hint_for_state()
{
    if ( locked() )
    {
        if ( IS_TRUE( level.acc_rampage_on ) )
            return "^1RAMPAGE^7 sealed at round " + ACC_RAMPAGE_LOCK_ROUND + " - stuck ^2ON^7";
        return "^1RAMPAGE^7 sealed at round " + ACC_RAMPAGE_LOCK_ROUND + " - stuck ^1OFF^7";
    }
    if ( IS_TRUE( level.acc_rampage_on ) )
        return "Hold ^3[{+activate}]^7 to toggle ^1RAMPAGE^7 (currently ^2ON^7 - faster horde)";
    return "Hold ^3[{+activate}]^7 to toggle ^1RAMPAGE^7 (currently ^1OFF^7 - faster horde)";
}
