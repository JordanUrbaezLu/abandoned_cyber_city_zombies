// =============================================================================
// _acc_lui.gsc - LUI client pipeline FOUNDATION (server half)
//
// Stands up the map's custom LUI HUD overlay (ui/uieditor/menus/hud/acc_hud.lua)
// and the clientuimodel data bridge that drives it. This is the substrate every
// future premium-UI touchpoint rides on (perk-icon glow, Data Shards counter,
// Cyberware indicators, boss bar - see docs/27_ui_plan.md, docs/28_lui_pipeline.md).
//
// Pattern (verified vs stock _zm_perk_deadshot.gsc/.csc + shipped usermaps
// zm_alien_isolation / zm_building / zm_countryside): REGISTER_SYSTEM so the
// clientfield registers at the correct pre-load phase, IN LOCKSTEP with the .csc
// mirror (_acc_lui.csc) - a gsc/csc registration order/width mismatch corrupts
// the field and hangs the load. Server registers + sets; client only mirrors the
// registration (no callback). clientuimodel scope is auto-piped to the LUI model.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\clientfield_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\system_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;
#insert scripts\shared\version.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#precache( "lui_menu", "acc_hud" );

#namespace acc_lui;

REGISTER_SYSTEM( "acc_lui", &__init__, undefined )

function __init__()
{
    // Must match the .csc mirror EXACTLY (scope/name/version/bits/type) AND in the
    // SAME ORDER - the bit layout is assigned in registration order.
    clientfield::register( "clientuimodel", "accLuiTest", VERSION_SHIP, 4, "int" );
    // Perk/PaP info card selector: code = perkIndex*4 + mode (0 = hide). Max 10*4+3
    // = 43 -> 6 bits. Decoded + rendered by acc_hud.lua's perk-card lookup table.
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 6, "int" );
    // Pack-a-Punch current tier (0..5) of the held weapon, pushed when near PaP so
    // the card shows only the NEXT tier (not the whole ladder). 3 bits (0..7).
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int" );
    // Mega-perk bitmask: bit i set => perk (i+1) is Mega'd (perk_card_index order,
    // 1..9). 9 bits. acc_hud.lua glows the matching perk-bar slot.
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 9, "int" );
    callback::on_connect( &on_player_connect );
}

// Push the contextual perk/PaP card selector to a player's LUI overlay.
// code 0 hides the card; otherwise perkIndex*4 + mode (see _acc_perk_info).
function set_perk_card( player, code )
{
    player clientfield::set_player_uimodel( "accPerkCard", code );
}

// Push the held weapon's current PaP tier (0..5) so the card renders the NEXT tier.
function set_pap_tier( player, tier )
{
    if ( !isdefined( tier ) || tier < 0 ) tier = 0;
    if ( tier > 5 ) tier = 5;
    player clientfield::set_player_uimodel( "accPapTier", tier );
}

// Push the Mega-perk bitmask (bit i = perk i+1 is Mega'd) so the HUD glows them.
function set_mega_mask( player, mask )
{
    if ( !isdefined( mask ) || mask < 0 ) mask = 0;
    player clientfield::set_player_uimodel( "accMegaMask", mask );
}

function on_player_connect()
{
    self thread player_lui_init();
}

// Open the always-on overlay for this player and light the foundation banner so
// we can confirm in-game that the whole LUI pipeline loaded.
function player_lui_init()
{
    self endon( "disconnect" );
    level flag::wait_till( "initial_blackscreen_passed" );
    wait 0.5; // let the client HUD settle before opening our overlay

    self.acc_lui_menu = self OpenLUIMenu( "acc_hud" );
    wait 0.1; // menu must instantiate client-side before we push model data
    self clientfield::set_player_uimodel( "accLuiTest", 1 );

    acc_utility::log( "lui: overlay opened + banner set for a player" );
}
