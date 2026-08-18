// =============================================================================
// _acc_lui.csc - LUI client pipeline FOUNDATION (client half)
//
// Mirror registration of the clientuimodel clientfield(s) the server (_acc_lui.gsc)
// sets. For "clientuimodel" scope the engine auto-pipes the value into the LUI
// model the Lua widget subscribes to, so NO callback handler is needed here - but
// the bare register MUST exist client-side (and match the server's scope/name/
// version/bits/type EXACTLY) or the model never exists client-side and the Lua
// subscribeToModel silently never fires.
//
// REGISTER_SYSTEM (same as the .gsc) guarantees this registers at the same
// pre-load phase as the server, keeping the field bit-layout in lockstep.
// Pattern verified vs stock scripts\zm\_zm_perk_deadshot.csc:48 and
// scripts\zm\_load.csc:130. The actual LUI menu is loaded by the entry
// zm_abandoned_cyber_city.csc via LuiLoad("ui.uieditor.menus.hud.acc_hud").
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace acc_lui;

REGISTER_SYSTEM( "acc_lui", &__init__, undefined )

function __init__()
{
    // SAME fields, SAME order, SAME widths as _acc_lui.gsc - lockstep or the
    // clientuimodel bit layout desyncs.
    clientfield::register( "clientuimodel", "accOcTier", VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );  // [acc] OC tier (repurposed from dead accLuiTest; same 4-bit slot/order)
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 7, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 10, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );   // 9->10 for Electric Cherry (lockstep w/ .gsc)
    clientfield::register( "clientuimodel", "accDmgNum", VERSION_SHIP, 18, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accOwnedMask", VERSION_SHIP, 10, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );  // 9->10 for Electric Cherry (lockstep w/ .gsc)
    clientfield::register( "clientuimodel", "accPowerupMask", VERSION_SHIP, 7, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accRoundRing", VERSION_SHIP, 7, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accArea", VERSION_SHIP, 5, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );  // area-banner id 0..17 (2026-08-02; widened 4->5 for the armory/sci_office/implant sub-areas - lockstep w/ .gsc, appended LAST)

    // [acc] ACTOR-scope eye-tint marker for the Glitch Stalker (teal eyes, NO FX asset).
    // This is a DIFFERENT clientfield pool from the clientuimodel fields above (the actor
    // scope has its own bit budget, so it does not touch the near-full clientuimodel pool),
    // and it is the only acc actor-scope field, so its actor-scope bit index is identical on
    // both VMs. MUST match _acc_lui.gsc EXACTLY (scope/name/version/bits/type). The server
    // sets it 1 on the boss; this client callback recolours ONLY that actor's eyeball material
    // (mapshaderconstant) so the horde's eyes are untouched.
    clientfield::register( "actor", "accEyeTint", VERSION_SHIP, 1, "int", &eye_tint_cb, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}

// self = the marked actor (Glitch Stalker). newVal 1 => recolour its eyes; 0 => leave stock.
function eye_tint_cb( localClientNum, oldVal, newVal, bNewEnt, bInitialSnap, fieldName, bWasTimeJump )
{
    if ( !isdefined( newVal ) || newVal == 0 ) return;
    self thread acc_eye_tint_loop( localClientNum );
}

// Recolour THIS actor's eyeball material to the live acc_glitch_eye_color value. We drive the
// EXACT stock eye-colour path - mapshaderconstant( ..., "scriptVector2", 0, luminance, colour )
// is what stock's own zombie_eyes_clientfield_cb (_zm.csc) uses to light the eye material - we
// just feed it our (luminance, colour) instead of the defaults. Re-applied on a 1s poll so the
// colour is LIVE-TUNABLE in-game (no rebuild), matching the rest of the boss's acc_glitch_*
// dvars: change acc_glitch_eye_color until it reads teal, and drop acc_glitch_eye_lum if the
// map's dark colour-grade (VisionSetNaked) washes a full-luminance eye toward white. No FX.
function acc_eye_tint_loop( localClientNum )
{
    self endon( "entityshutdown" );
    self endon( "death" );

    self util::waittill_dobj( localClientNum ); // the eyeball material exists once the model dobj is loaded

    for ( ;; )
    {
        color = getdvarfloat( "acc_glitch_eye_color", 0.5 ); // teal target (TUNE live until it reads teal)
        lum   = getdvarfloat( "acc_glitch_eye_lum", 1.0 );   // lower if the dark grade washes it to white
        self.zombie_eyeball_color_override = color;          // so any stock re-apply keeps our colour
        self mapshaderconstant( localClientNum, 0, "scriptVector2", 0, lum, color );
        wait 1;
    }
}
