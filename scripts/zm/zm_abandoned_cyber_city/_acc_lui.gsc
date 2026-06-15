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
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

#precache( "lui_menu", "acc_hud" );

#namespace acc_lui;

REGISTER_SYSTEM( "acc_lui", &__init__, undefined )

function __init__()
{
    // Must match the .csc mirror EXACTLY (scope/name/version/bits/type) AND in the
    // SAME ORDER - the bit layout is assigned in registration order.
    clientfield::register( "clientuimodel", "accLuiTest", VERSION_SHIP, 4, "int" );
    // Perk/PaP info card selector: code = perkIndex*4 + mode (0 = hide), +64 when the
    // viewing player holds The Armory (Mule Kick Mega) so the card shows the 10%-off
    // price. Max 10*4+3+64 = 107 -> 7 bits. Decoded + rendered by acc_hud.lua.
    clientfield::register( "clientuimodel", "accPerkCard", VERSION_SHIP, 7, "int" );
    // Pack-a-Punch current tier (0..5) of the held weapon, pushed when near PaP so
    // the card shows only the NEXT tier (not the whole ladder). 3 bits (0..7).
    clientfield::register( "clientuimodel", "accPapTier", VERSION_SHIP, 3, "int" );
    // Mega-perk bitmask: bit i set => perk (i+1) is Mega'd (perk_card_index order,
    // 1..9). 9 bits. acc_hud.lua glows the matching perk-bar slot.
    clientfield::register( "clientuimodel", "accMegaMask", VERSION_SHIP, 9, "int" );
    // Damage number: value = min(dmg,99999)*2 + parity. acc_hud.lua shows it near
    // the crosshair (you aim at the zombie, so it reads on-target). The parity bit
    // flips every push so an identical number still re-triggers the popup. 18 bits.
    clientfield::register( "clientuimodel", "accDmgNum", VERSION_SHIP, 18, "int" );
    // Owned-perk bitmask: bit i set => the player OWNS perk (i+1) (perk_card_index
    // order, 1..9), regardless of Mega. Pairs with accMegaMask so the LUI overlay
    // can pick the icon: owned+mega => teal (Mega), owned+!mega => red (base),
    // !owned => hide. 9 bits. Driven by perk_state_watch(). Appended LAST so the
    // existing fields' bit layout is untouched (must match _acc_lui.csc order).
    clientfield::register( "clientuimodel", "accOwnedMask", VERSION_SHIP, 9, "int" );
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

// Push the owned-perk bitmask (bit i = player owns perk i+1). See accOwnedMask reg.
function set_owned_mask( player, mask )
{
    if ( !isdefined( mask ) || mask < 0 ) mask = 0;
    player clientfield::set_player_uimodel( "accOwnedMask", mask );
}

// Push a crosshair damage number. `value` = min(dmg,99999)*2 + parity (the caller
// owns the parity flip so identical numbers re-pop). 0 hides the number.
function set_dmg_num( player, value )
{
    if ( !isdefined( value ) || value < 0 ) value = 0;
    player clientfield::set_player_uimodel( "accDmgNum", value );
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

    // Drive the perk-icon overlay (owned/mega bitmasks -> acc_hud.lua CoD.AccPerkBar) and
    // suppress the stock perk bar (instant zero-flash hide on perk gain + 0.25s re-assert).
    self thread perk_state_watch();
    self thread stock_perk_hud_suppressor();

    acc_utility::log( "lui: overlay opened + banner set for a player" );
}

// Per-player loop: track which perks the player OWNS and which are Mega'd and push
// BOTH bitmasks to the LUI overlay, which picks the art (owned+mega => teal Mega,
// owned+!mega => red base, !owned => hide). Slice scope (2026-06-14): the overlay
// only renders Jugger-Nog (bit 0) today, but the masks already carry all 9 perks in
// perk_card_index order, so expanding to the rest is Lua + image work only - no GSC
// change here. Cheap: a 0.25s poll that pushes a clientfield only when a mask flips.
function perk_state_watch()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // perk_card_index order (1..9): index N -> bit (N-1). MUST match _acc_perk_info
    // perk_card_index() and acc_hud.lua AccPerkCards.
    specialties = array(
        "specialty_armorvest",               // 1 Jugger-Nog       -> bit 0
        "specialty_quickrevive",             // 2 Quick Revive     -> bit 1
        "specialty_fastreload",              // 3 Speed Cola       -> bit 2
        "specialty_doubletap2",              // 4 Double Tap       -> bit 3
        "specialty_staminup",                // 5 Stamin-Up        -> bit 4
        "specialty_additionalprimaryweapon", // 6 Mule Kick        -> bit 5
        "specialty_deadshot",                // 7 Deadshot         -> bit 6
        "specialty_widowswine",              // 8 Widow's Wine     -> bit 7
        "specialty_electriccherry"           // 9 Aura Blast (WIP) -> bit 8
    );

    last_owned = -1;
    last_mega  = -1;

    for ( ;; )
    {
        owned = 0;
        mega  = 0;
        for ( i = 0; i < specialties.size; i++ )
        {
            sp = specialties[ i ];
            // owns_or_paused (not bare HasPerk) so a boss EMP-pause of the perk does
            // NOT flicker the icon off mid-fight (mirrors has_active_mega_perk intent).
            if ( acc_mega_bottles::owns_or_paused( self, sp ) )
            {
                owned = owned | ( 1 << i );
                if ( acc_mega_bottles::has_mega_perk( self, sp ) )
                    mega = mega | ( 1 << i );
            }
        }

        // Re-assert stock perk-bar suppression. The common BUY case is already ZERO-flash
        // (stock_perk_hud_suppressor clears it the same frame the perk is gained); this
        // 0.25s re-assert just covers the rarer unpause / edge re-gives.
        self clear_stock_perk_hud();

        if ( owned != last_owned )
        {
            set_owned_mask( self, owned );
            last_owned = owned;
        }
        if ( mega != last_mega )
        {
            set_mega_mask( self, mega );
            last_mega = mega;
        }

        wait 0.25;
    }
}

// Zero the 9 stock perk-bar LUI model fields (hudItems.perks.<key>) for this player, which
// HIDES the stock perk-bar icons (we draw our own CoD.AccPerkBar). Cosmetic ONLY - perk
// EFFECTS come from engine SetPerk, not this model. Asset-name overrides CANNOT hide these
// (usermap zone loads last, base zone wins). Field names verified vs stock _zm_perks.gsh
// PERK_CLIENTFIELD_* (aliases: staminup->marathon, fastreload->sleight_of_hand,
// deadshot->dead_shot, additionalprimaryweapon->additional_primary_weapon).
function clear_stock_perk_hud()
{
    fields = array(
        "hudItems.perks.juggernaut",                // Jugger-Nog
        "hudItems.perks.quick_revive",              // Quick Revive
        "hudItems.perks.sleight_of_hand",           // Speed Cola
        "hudItems.perks.doubletap2",                // Double Tap
        "hudItems.perks.marathon",                  // Stamin-Up
        "hudItems.perks.additional_primary_weapon", // Mule Kick
        "hudItems.perks.dead_shot",                 // Deadshot
        "hudItems.perks.widows_wine",               // Widow's Wine
        "hudItems.perks.electric_cherry"            // Aura Blast
    );
    for ( i = 0; i < fields.size; i++ )
        self clientfield::set_player_uimodel( fields[ i ], 0 );
}

// ZERO-FLASH stock perk-bar hide. Stock give_perk sets the perk's HUD clientfield to OWNED
// then fires "perk_acquired" in the SAME server frame with no wait in between
// (_zm_perks.gsc:756 -> :780), so clearing the fields on that notify lands in the same
// frame - the client's end-of-frame snapshot never carries the OWNED value, so the stock
// icon never appears (no flash). perk_state_watch's 0.25s re-assert covers the rarer
// unpause path that does NOT fire perk_acquired.
function stock_perk_hud_suppressor()
{
    self endon( "disconnect" );
    level endon( "end_game" );
    for ( ;; )
    {
        self waittill( "perk_acquired" );
        self clear_stock_perk_hud();
    }
}
