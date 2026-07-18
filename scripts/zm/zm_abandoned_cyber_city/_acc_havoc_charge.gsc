// =============================================================================
// _acc_havoc_charge.gsc - HAVOC charge, v5 "script-owned timer" (user 2026-07-06:
// "why not start a 0.1 timer and keep starting it... that way you get control over the timer")
//
// THE v5 ARCHITECTURE (the user's design, adapted): the ENGINE no longer times the charge at all.
//   - Weapon def: fireDelay 0.1 - NOT the charge; it is the PRESS-GUARD. With fireDelay 0 a press
//     fires the same frame, faster than any script tick can react (a bullet would leak per press).
//     0.1s (2 server frames) gives the 50ms poll a ONE-frame head start - the minimum safe value
//     (0.05 = same-frame tie = leaked shots; was 0.15's two-frame margin, cut 2026-07-08 because a
//     Turbocharger holder feels the full fireDelay raw). The engine's tiny latch then dry-fires
//     into the ammo gate at charge start (one soft click = the turbine engaging) and is DEAD -
//     nothing pends at release, so cancel needs NO mask window.
//   - SCRIPT owns the 1.25s: on press it blanks the gun to 0/0 (the ONE fire-blocking lever GSC
//     has; 0/0 blocks both firing AND auto-reload - proven v4.3), plays the riser
//     (PlayLocalSound - def sound is off), and counts. Hold to 1.25s -> ammo restores and the
//     still-held trigger rips. Release early -> StopLocalSound + INSTANT ammo restore. True
//     instant cancel: no engine timer exists to play out.
//   - THE GAMBLE (why this is an experiment): does a held trigger RESUME firing when ammo appears
//     at restore, or does the engine demand a fresh press after its dry attempt? If it resumes:
//     v5 is strictly better than v4.4. If not: the gun charges then sits silent until re-tapped -
//     v5 fails, revert to v4.4 (backup: scratchpad _acc_havoc_charge_v44_backup.gsc + GDT
//     fireDelay 1.25 + def riser back).
//
// Edge handling:
//   - Release AFTER charged: ammo is already live; nothing pends. Next press re-gates (re-charge
//     per pull - the approved v3/v4 model).
//   - Max Ammo landing mid-charge: restore takes the LARGER reserve (never clobbers a refill).
//   - Weapon switch / death mid-charge: instant restore + riser stop.
//   - Gun truly empty (0 clip + 0 stock): no gate, no riser - natural dry-fire.
//   - Reload: works normally (ammo is REAL whenever you are not actively charging).
//
// HISTORY: v1/v2 def-swap spool (yanked viewmodel - BANNED); v3 pure engine fireDelay 1.25 (tap
// latches a phantom shot); v4.x cancel-by-masking (riser stop + dry-fire bracket; ok but the
// phantom timer still ran out invisibly). v5 removes the engine timer entirely per the user's
// script-owned-timer proposal.
//
// TURBO "delay after running" ROOT CAUSE (user 2026-07-08): the Havoc GDT ships sprintOutTime 0.98
// (vs 0.3 on every other Apex gun - it matches the long vm_..._sprint_out anim). The engine blocks
// firing until sprint-out completes, so a TURBO holder (no script charge masking it) ate a raw ~1s
// first-shot delay out of sprint - ZM auto-sprint means MOST first shots are out of sprint, which
// also explains the "first hip-fire bullet" feel. NON-turbo holders never feel the field (this
// module's 1.25s charge outlasts it).
// THE FIX = the TURBO TWIN AXIS (user: "keep 0.98 without turbocharger, faster WITH it" - a GDT
// field is baked per def, so per-player values only exist as twin swaps): all 8 normal Havoc forms
// KEEP sprintOutTime 0.98; 8 hand-cloned "_acc_[...]turbo" forms bake sprintOutTime 0.2 and are
// swapped in/out by _acc_weapon_variants::axis_turbo off self.acc_item_turbocharger (implant pokes
// reconcile, so the swap is immediate at the bench). Blocks live in acc_weapon_variants.gdt
// (scratchpad gen_havoc_turbo_twins.js); zone weaponfull lines in the .zone. The turbo twins keep
// fireDelay 0.1 - the engine press-guard this module's ammo-gate needs stays intact on every form.
// RACE GUARD: reconcile defers while self.acc_havoc_gated (set at gate engage, cleared in
// restore_gate) - a swap during the 0/0 ammo blank would destroy the gated ammo.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_HAVOC_CHARGE_MS 1250   // the full wind-up, script-timed (riser wav is 1.25s)

#namespace acc_havoc_charge;

function init()
{
    callback::on_connect( &on_player_connect );
    acc_utility::log( "havoc_charge v5: script-owned 1.25s charge (press-gate 0/0 + riser; release = instant cancel + restore)" );
}

function on_player_connect()
{
    self thread havoc_charge_loop();
}

function havoc_charge_loop()
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );

    charging = false;       // gate active: ammo blanked, riser playing, counting hold time
    charged = false;        // this hold reached 1.25s (ammo live, gun firing/fireable)
    charge_start = 0;
    g_weapon = undefined;   // gated weapon (restore target)
    g_clip = 0;
    g_stock = 0;
    was_holding = false;

    for ( ;; )
    {
        wait 0.05;

        now = GetTime();
        cur = self GetCurrentWeapon();
        cur_is_havoc = ( isdefined( cur ) && cur != level.weaponNone && IsSubStr( cur.name, "apex_beam_rifle" ) );
        holding = ( cur_is_havoc && IsAlive( self ) && self AttackButtonPressed() );

        // ---- TURBOCHARGER implant (boss item 8, user 2026-07-07): a Havoc-specific mod. While the
        //      owner has it implanted the Havoc fires with NO wind-up - we simply never engage the
        //      script charge gate below (the `!turbo` guard on the press edge). If it is equipped
        //      mid-charge (or a gated Havoc is re-selected while turbo'd), drop any live gate instantly
        //      so the beam rifle is live and rips like a normal auto (its GDT fireDelay 0.1 press-guard
        //      = ~no charge). Flag is set by _acc_boss_items::apply_turbocharger (plain player field). ----
        turbo = IS_TRUE( self.acc_item_turbocharger );
        if ( turbo && charging )
        {
            self StopLocalSound( "acc_havoc_charge" );
            self restore_gate( g_weapon, g_clip, g_stock );
            charging = false;
            charged = false;
        }

        // ---- abort paths: stowed / died / weapon changed while gated ----
        if ( charging && ( !cur_is_havoc || !IsAlive( self ) || !isdefined( g_weapon ) || ( isdefined( cur ) && cur != g_weapon ) ) )
        {
            self restore_gate( g_weapon, g_clip, g_stock );
            self StopLocalSound( "acc_havoc_charge" );
            charging = false;
            charged = false;
        }

        if ( holding && !was_holding && !charging && !charged && !turbo )
        {
            // ---- press edge: gate + riser + start OUR timer (skipped entirely while turbo'd) ----
            // (the engine's 0.15s press-guard latch will dry-click into the gate ~100ms from now)
            clip = self GetWeaponAmmoClip( cur );
            stock = self GetWeaponAmmoStock( cur );
            if ( clip > 0 || stock > 0 )
            {
                g_weapon = cur;
                g_clip = clip;
                g_stock = stock;
                self SetWeaponAmmoClip( cur, 0 );
                self SetWeaponAmmoStock( cur, 0 );
                self PlayLocalSound( "acc_havoc_charge" );
                charge_start = now;
                charging = true;
                // Gate marker for _acc_weapon_variants::reconcile (turbo axis, 2026-07-08): a twin swap
                // while the gun is blanked 0/0 would copy the blank ammo onto the new form AND orphan the
                // restore (the gated weapon gets taken) - reconcile defers while this is set. Cleared in
                // restore_gate (every gate teardown path funnels through it).
                self.acc_havoc_gated = true;
                // Dev print (2026-07-08 turbo hunt): if this shows AFTER implanting the Turbocharger,
                // the flag write is the break (should read the [HAVOC] skip line instead).
                // [HAVOC] charge-gate dev print REMOVED 2026-07-10 (clean screen in hardcoded dev):
                // if ( IS_TRUE( level.acc_dev ) ) self IPrintLnBold( "^5[HAVOC] charge gate ENGAGED (turbo=0)" );
            }
            // truly empty gun: no gate, no riser - let it dry-fire naturally
        }
        else if ( charging && holding && ( now - charge_start ) >= ACC_HAVOC_CHARGE_MS )
        {
            // ---- charge complete (trigger still held): ammo back -> the held trigger rips ----
            self restore_gate( g_weapon, g_clip, g_stock );
            charging = false;
            charged = true;   // stays true until release; presses can't re-gate mid-burst
        }
        else if ( charging && !holding )
        {
            // ---- released early: INSTANT cancel - stop riser, ammo back, nothing pends ----
            self StopLocalSound( "acc_havoc_charge" );
            self restore_gate( g_weapon, g_clip, g_stock );
            charging = false;
        }
        else if ( charged && !holding )
        {
            charged = false;   // burst over; next press starts a fresh charge (re-wind per pull)
        }
        else if ( holding && !was_holding && turbo )
        {
            // Turbo press edge: gate deliberately skipped - the gun fires live off its GDT 0.1s
            // press-guard. Dev print (2026-07-08 turbo hunt): if this shows but the gun STILL winds
            // up, the wind-up is engine/GDT-side, not this script.
            // [HAVOC] turbo-skip dev print REMOVED 2026-07-10 (clean screen in hardcoded dev):
            // if ( IS_TRUE( level.acc_dev ) ) self IPrintLnBold( "^5[HAVOC] turbo: charge skipped (firing live)" );
        }

        was_holding = holding;
    }
}

// Give the gated ammo back. MAX-AMMO SAFE: a Max Ammo landing while gated refills BOTH the clip and the
// reserve past what we saved at the press edge - never clobber it, take the LARGER of current-vs-saved for
// EACH (audit 2026-07-12: the clip was previously restored as-saved, discarding a mid-charge Max Ammo's clip
// refill; in the ordinary case current clip is 0 while gated, so max(0, saved) restores the saved value).
function restore_gate( w, clip, stock )
{
    self.acc_havoc_gated = false;   // gate over (every teardown path funnels here) - reconcile may swap again
    if ( !isdefined( w ) || w == level.weaponNone || !( self HasWeapon( w ) ) ) return;
    cur_clip  = self GetWeaponAmmoClip( w );
    cur_stock = self GetWeaponAmmoStock( w );
    self SetWeaponAmmoClip( w, ( cur_clip > clip ? cur_clip : clip ) );
    self SetWeaponAmmoStock( w, ( cur_stock > stock ? cur_stock : stock ) );
}
