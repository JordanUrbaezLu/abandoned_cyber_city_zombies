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

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#namespace acc_lui;

REGISTER_SYSTEM( "acc_lui", &__init__, undefined )

function __init__()
{
    // SAME fields, SAME order, SAME widths as _acc_lui.gsc - lockstep or the
    // clientuimodel bit layout desyncs.
    clientfield::register( "clientuimodel", "accLuiTest", VERSION_SHIP, 4, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 7, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 9, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
    clientfield::register( "clientuimodel", "accDmgNum", VERSION_SHIP, 18, "int", undefined, !CF_HOST_ONLY, !CF_CALLBACK_ZERO_ON_NEW_ENT );
}
