// =============================================================================
// _acc_perk_info.gsc - perk + Pack-a-Punch info CARD at the machine
//
// Player-facing (REQUIREMENTS / docs/13_perks.md, docs/27_ui_plan.md): walk up
// to a perk machine (or Pack-a-Punch) and a polished card shows the NAME, PRICE,
// and BULLETED benefits (base + Mega for perks; the 5-tier ladder for PaP) so
// players can craft builds. Rendering is the reusable acc_ui::card component.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_ui;

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

    if ( !isdefined( nearest_id ) )
    {
        self acc_ui::card_hide();
        self.acc_pinfo_cur = undefined;
        return;
    }

    if ( isdefined( self.acc_pinfo_cur ) && self.acc_pinfo_cur == nearest_id )
        return; // already showing this card

    self.acc_pinfo_cur = nearest_id;
    self show_card( nearest_id );
}

// self = player
function show_card( id )
{
    d = card_data( id );

    lines = [];
    base = d[ "base_bullets" ];
    for ( i = 0; i < base.size; i++ )
        lines[ lines.size ] = "^5- ^7" + base[ i ];

    if ( d[ "mega_name" ] != "" )
    {
        lines[ lines.size ] = "^6MEGA: " + d[ "mega_name" ];
        mega = d[ "mega_bullets" ];
        for ( i = 0; i < mega.size; i++ )
            lines[ lines.size ] = "^6- ^7" + mega[ i ];
    }

    is_pap = ( id == "pap" );

    title_color = ( 0.55, 0.85, 1.0 ); // cyber-cyan for perks
    if ( is_pap )
        title_color = ( 0.7, 0.4, 1.0 ); // purple for PaP

    price = "";
    if ( d[ "price" ] != "" )
        price = "^7Cost: ^2" + d[ "price" ] + " Points";
    else if ( is_pap )
        price = "^7Re-pack at the machine to raise tier";

    self acc_ui::card_show( d[ "title" ], title_color, price, lines );
}

// ---------------------------------------------------------------------------
// Card content (docs/13_perks.md + _acc_pap_levels). Keep bullets terse.
// ---------------------------------------------------------------------------

function card_data( id )
{
    d = [];
    d[ "price" ] = "";
    d[ "mega_name" ] = "";
    d[ "base_bullets" ] = [];
    d[ "mega_bullets" ] = [];

    switch ( id )
    {
    case "specialty_armorvest":
        d[ "title" ] = "JUGGER-NOG"; d[ "price" ] = "4000"; d[ "mega_name" ] = "Ultimate Tank";
        d[ "base_bullets" ] = array( "Survive 6 melee hits (vs 3)", "Built for training + tanking" );
        d[ "mega_bullets" ] = array( "7 hits before going down", "Immune to boss abilities" ); break;
    case "specialty_quickrevive":
        d[ "title" ] = "QUICK REVIVE"; d[ "price" ] = "2500"; d[ "mega_name" ] = "Savior";
        d[ "base_bullets" ] = array( "Faster teammate revives", "+30% HP regen after damage", "Solo: self-revive" );
        d[ "mega_bullets" ] = array( "Revive 40% faster", "+15% speed near a downed ally" ); break;
    case "specialty_fastreload":
        d[ "title" ] = "SPEED COLA"; d[ "price" ] = "3500"; d[ "mega_name" ] = "Sleight of Hand Expert";
        d[ "base_bullets" ] = array( "+50% reload speed", "~30% faster weapon swap", "~40% faster perk drink" );
        d[ "mega_bullets" ] = array( "+65% reload", "+15% swap, +15% drink" ); break;
    case "specialty_doubletap2":
        d[ "title" ] = "DOUBLE TAP 2.0"; d[ "price" ] = "2000"; d[ "mega_name" ] = "Gun Slinger";
        d[ "base_bullets" ] = array( "+33% fire rate", "+3% weapon damage" );
        d[ "mega_bullets" ] = array( "+50% fire rate", "+6% damage total" ); break;
    case "specialty_staminup":
        d[ "title" ] = "STAMIN-UP"; d[ "price" ] = "2000"; d[ "mega_name" ] = "The Flash";
        d[ "base_bullets" ] = array( "Longer sprint reserve", "Faster sprint speed" );
        d[ "mega_bullets" ] = array( "+12% run, longer sprint", "x2 walk, x4 crawl speed" ); break;
    case "specialty_additionalprimaryweapon":
        d[ "title" ] = "MULE KICK"; d[ "price" ] = "2500"; d[ "mega_name" ] = "The Armory";
        d[ "base_bullets" ] = array( "Carry a 3rd primary weapon" );
        d[ "mega_bullets" ] = array( "+30% ammo per gun", "+2 lethal, +2 tactical" ); break;
    case "specialty_deadshot":
        d[ "title" ] = "DEADSHOT"; d[ "price" ] = "3500"; d[ "mega_name" ] = "American Sniper";
        d[ "base_bullets" ] = array( "ADS snaps to the head", "1.5x headshot damage", "No snap on bosses" );
        d[ "mega_bullets" ] = array( "1.75x headshot damage", "Zero weapon recoil" ); break;
    case "specialty_widowswine":
        d[ "title" ] = "WIDOW'S WINE"; d[ "price" ] = "4000"; d[ "mega_name" ] = "Spiderman";
        d[ "base_bullets" ] = array( "Webs trap zombies on melee", "+50% frag dmg, +25% radius", "+50% EMP grenade" );
        d[ "mega_bullets" ] = array( "Melee 1-hits zombies", "Web nades 1-hit, hold 6" ); break;
    case "specialty_electriccherry":
        d[ "title" ] = "AURA BLAST"; d[ "price" ] = "2500"; d[ "mega_name" ] = "Mega Man";
        d[ "base_bullets" ] = array( "Crouch+melee: 400u shockwave", "3s stun, 120s cooldown", "Full bosses immune" );
        d[ "mega_bullets" ] = array( "Affects bosses too", "800u, 60s CD, 2 charges" ); break;
    case "pap":
        d[ "title" ] = "PACK-A-PUNCH";
        d[ "base_bullets" ] = array(
            "Pack the same gun to climb tiers:",
            "T1: upgrade (camo + alt-ammo)",
            "T2: +25% weapon damage",
            "T3: +55% weapon damage",
            "T4: +90% weapon damage",
            "T5: +130% damage (MAX)" );
        break;
    default:
        d[ "title" ] = "PERK"; d[ "base_bullets" ] = array( "-" ); break;
    }
    return d;
}
