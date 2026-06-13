// =============================================================================
// _acc_perk_info.gsc - perk + Pack-a-Punch info CARD selector (drives LUI)
//
// Player-facing (REQUIREMENTS / docs/13_perks.md, docs/27_ui_plan.md): walk up
// to a perk machine (or Pack-a-Punch) and a premium card shows the NAME, PRICE,
// and BULLETED benefits (base + Mega for perks; the 5-tier ladder for PaP) so
// players can craft builds.
//
// This module is now just the BRAIN: per player it finds the nearest machine and
// the context (buy/mega/maxed/pap) and pushes a single int "card code"
// (perkIndex*4 + mode, 0 = hide) to the LUI overlay via acc_lui::set_perk_card.
// The card itself (title/price/bulleted text + styling) is RENDERED in
// ui/uieditor/menus/hud/acc_hud.lua from its perk-card lookup table - the proven
// clientuimodel-int + Lua-lookup pattern (room_manager.lua). The old all-GSC
// server-HUD card (acc_ui::card) is retired for this touchpoint (mis-aligned text
// outside the box); acc_ui remains available for any non-LUI fallback.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;

#define ACC_PERK_INFO_RANGE_SQ 28900   // 170u
#define ACC_PAP_RANGE_SQ       32400   // 180u

#namespace acc_perk_info;

function init()
{
    acc_utility::log( "perk_info: init" );
    level thread watch_players();
}

function watch_players()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    machines = [];
    for ( i = 0; i < 60; i++ )
    {
        machines = GetEntArray( "zombie_vending", "targetname" );
        if ( machines.size > 0 ) break;
        wait 0.5;
    }
    acc_utility::log( "perk_info: tracking " + machines.size + " perk machines" );

    // PaP machine origin (entity 23 in the .map). Hardcoded - dev map is stable.
    pap_org = ( -700, 3700, 7.5 );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            p update_for_player( machines, pap_org );
        }
        wait 0.2;
    }
}

// self = player
function update_for_player( machines, pap_org )
{
    nearest_id = undefined;
    best_sq = ACC_PERK_INFO_RANGE_SQ;

    for ( i = 0; i < machines.size; i++ )
    {
        m = machines[ i ];
        if ( !isdefined( m ) || !isdefined( m.script_noteworthy ) ) continue;
        d_sq = DistanceSquared( self.origin, m.origin );
        if ( d_sq < best_sq )
        {
            best_sq = d_sq;
            nearest_id = m.script_noteworthy;
        }
    }

    // PaP machine competes for the "nearest interactable" slot.
    pap_sq = DistanceSquared( self.origin, pap_org );
    if ( pap_sq < ACC_PAP_RANGE_SQ && pap_sq < best_sq )
    {
        best_sq = pap_sq;
        nearest_id = "pap";
    }

    code = 0; // 0 = hide the card
    if ( isdefined( nearest_id ) )
    {
        pidx = perk_card_index( nearest_id );
        // Context: show only what buying NOW gives you - base(0) / Mega upgrade(1)
        // / maxed(2) / PaP tier ladder(3). The Lua card renders the right bullets.
        mode = 0;
        if ( nearest_id == "pap" )
            mode = 3;
        else if ( self HasPerk( nearest_id ) )
        {
            if ( acc_mega_bottles::has_mega_perk( self, nearest_id ) )
                mode = 2;
            else
                mode = 1;
        }
        if ( pidx > 0 )
            code = pidx * 4 + mode;
    }

    if ( isdefined( self.acc_pinfo_code ) && self.acc_pinfo_code == code )
        return; // already pushed this exact card

    self.acc_pinfo_code = code;
    acc_lui::set_perk_card( self, code );
}

// Stable perk -> card index for the LUI lookup table (acc_hud.lua AccPerkCards).
// MUST match the Lua table. 0 = unknown/none.
function perk_card_index( id )
{
    switch ( id )
    {
    case "specialty_armorvest":               return 1;  // Jugger-Nog
    case "specialty_quickrevive":             return 2;  // Quick Revive
    case "specialty_fastreload":              return 3;  // Speed Cola
    case "specialty_doubletap2":              return 4;  // Double Tap 2.0
    case "specialty_staminup":                return 5;  // Stamin-Up
    case "specialty_additionalprimaryweapon": return 6;  // Mule Kick
    case "specialty_deadshot":                return 7;  // Deadshot
    case "specialty_widowswine":              return 8;  // Widow's Wine
    case "specialty_electriccherry":          return 9;  // Aura Blast
    case "pap":                               return 10; // Pack-a-Punch
    }
    return 0;
}
