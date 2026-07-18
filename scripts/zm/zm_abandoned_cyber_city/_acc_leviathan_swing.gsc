// =============================================================================
// _acc_leviathan_swing.gsc - Leviathan Axe HOLD-TO-AUTO-SWING (user 2026-07-15: "hold down
// shoot and you can auto swing at max speed of weapon").
//
// WHY SCRIPT, NOT GDT: fireType "Melee" executes its swing ONLY on a fresh attack-button EDGE.
// continuousFire 1 makes the engine re-FIRE while held (the visible per-cycle "flinch") but
// every re-fire's melee attack is rejected inside engine code we cannot reach - proven live
// 2026-07-15 with fireTime both BELOW and ABOVE meleeTime. So the split is: the ENGINE keeps
// the first (edge) swing with its real animation, and THIS module performs the follow-up
// swings while the button stays held - every w.fireTime seconds it picks the closest living
// axis AI in a forward cone with line of sight and deals MOD_MELEE damage WITH THE AXE AS THE
// DAMAGE WEAPON. That routes through the exact same _acc_damage "LEVIATHAN AXE - PER-ENEMY
// hits-to-kill" block as a real swing (the block resolves axe hits by weapon NAME + melee MOD,
// not by engine internals - _acc_damage.gsc ~:415), so PaP tiers, Berzerker tax, points,
// insta-kill and the boss hit-counts all behave identically to tap swings.
//
// The GDT keeps continuousFire 1 + fireTime = meleeTime + 0.03 (2026-07-15): the engine's
// per-cycle re-fire flinch is the visual swing pulse, on the SAME cadence this script hits at,
// and fireTime is the single cadence source both sides read.
//
// Scope: LEVIATHAN-ONLY (name-gated; covers every _acc spd/brz twin + both PaP forms). Pure
// damage dealing - no engine/weapon state is touched, so nothing here can wedge the gun
// (contrast the havoc ammo gate). Tap play is untouched: a tap never holds past one fireTime,
// so the script never fires for it.
//
// Tuning dvars (live): acc_lev_swing_range (84 - the melee reach of the scripted follow-ups),
// acc_lev_swing_dot (0.5 - forward-cone tightness; higher = narrower).
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_leviathan_swing;

function init()
{
    callback::on_connect( &on_player_connect );
    acc_utility::log( "leviathan_swing: hold-to-auto-swing loop armed (engine edge swing + scripted follow-ups)" );
}

function on_player_connect()
{
    self thread autoswing_loop();
}

function autoswing_loop()   // self = player
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    was_holding = false;
    next_ms = 0;

    for ( ;; )
    {
        wait 0.05;

        cur = self GetCurrentWeapon();
        is_lev = ( isdefined( cur ) && cur != level.weaponNone
                   && isdefined( cur.name ) && IsSubStr( cur.name, "leviathan" ) );
        holding = ( is_lev && IsAlive( self ) && !IS_TRUE( self.laststand )
                    && self AttackButtonPressed() );

        if ( !holding )
        {
            was_holding = false;
            continue;
        }

        // Cadence = the held form's own fireTime (meleeTime + 0.03 in the GDT), so PaP-tier /
        // Berzerker twins auto-swing proportionally faster with zero script knowledge of tiers.
        interval = 0.5;
        if ( isdefined( cur.fireTime ) && cur.fireTime > 0.1 ) interval = cur.fireTime;

        now = GetTime();
        if ( !was_holding )
        {
            // Press EDGE: the engine's own melee performs THIS swing (real anim + damage).
            // The script takes over one interval later if the button is still down.
            was_holding = true;
            next_ms = now + int( interval * 1000 );
            continue;
        }

        if ( now < next_ms ) continue;
        next_ms = now + int( interval * 1000 );

        // Scripted follow-up swing: closest living axis AI, forward cone, line of sight.
        z = self pick_swing_target( getdvarfloat( "acc_lev_swing_range", 84 ),
                                    getdvarfloat( "acc_lev_swing_dot", 0.5 ) );
        if ( isdefined( z ) )
        {
            // Nominal 100: the _acc_damage leviathan block REPLACES the amount with its
            // per-enemy fractional hits-to-kill value (weapon name resolves the axe path).
            //
            // HITLOC "torso_lower", NOT "none" (fix 2026-07-15): "none" is the normal stock convention
            // for scripted DoDamage (_zm_weap_gravityspikes.gsc), but the PANZER is the exception -
            // stock mechzDamageCallback wraps its ENTIRE hit-location switch in `if( hitloc !== "none" )`
            // (mechz.gsc:1146) and MOD_MELEE matches neither of the two branches after it
            // (MOD_PROJECTILE / MOD_PROJECTILE_SPLASH), so a "none" melee fell through to
            // mechz.gsc:1448 `return 0` = every held follow-up did ZERO damage to him while still
            // showing damage numbers and charging the 5% Berzerker blood tax. A real engine swing
            // always reports a real hitloc, which is why TAP worked and HOLD didn't.
            // WHY torso_lower specifically: it hits the switch's `default:` case (mechz.gsc:1244) =
            // a bare `return damage * MECHZ_BODY_DAMAGE_SCALE` - no GetPartName( .., boneIndex ) call
            // (DoDamage supplies NO boneIndex, and stock's torso_upper case DOES call it) and no
            // faceplate/headlamp point math on our synthetic `point`. That lands the same 0.1 body
            // family a real body swing lands, so acc_boss_panzer::acc_mechz_damage_wrap rebuffs it to
            // acc_panzer_body_scale (0.35) exactly like a tap - the designed Panzer model is honored,
            // not bypassed. Bonus: normal zombies now score the torso kill bonus (+10) and gib their
            // arm like a tap swing does, instead of "none" falling to the no-bonus default.
            z DoDamage( 100, self.origin, self, self, "torso_lower", "MOD_MELEE", 0, cur );
        }
    }
}

// self = player. The closest living axis AI within `range` units, inside the forward view cone
// (dot vs `mindot`), with a clear sight line from the eye. undefined = whiffed swing (no damage).
function pick_swing_target( range, mindot )
{
    eye = self GetEye();
    fwd = AnglesToForward( self GetPlayerAngles() );
    range_sq = range * range;

    best = undefined;
    best_d = range_sq + 1;

    zoms = GetAITeamArray( "axis" );
    for ( i = 0; i < zoms.size; i++ )
    {
        z = zoms[ i ];
        if ( !isdefined( z ) || !IsAlive( z ) ) continue;

        chest = z.origin + ( 0, 0, 40 );
        dv = chest - eye;
        d = LengthSquared( dv );
        if ( d > range_sq || d >= best_d ) continue;
        if ( VectorDot( VectorNormalize( dv ), fwd ) < mindot ) continue;
        if ( !SightTracePassed( eye, chest, false, self ) ) continue;

        best = z;
        best_d = d;
    }
    return best;
}
