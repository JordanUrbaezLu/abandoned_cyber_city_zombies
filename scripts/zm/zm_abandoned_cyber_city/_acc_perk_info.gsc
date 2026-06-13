// =============================================================================
// _acc_perk_info.gsc - perk benefit descriptions shown at the machine
//
// Player-facing feature (REQUIREMENTS / docs/13_perks.md): as you walk up to a
// perk machine, a panel shows what the perk does at BASE and at MEGA tier, so
// the choice is informed. Greybox stand-in for the Phase-4 LUI tooltip; uses
// server hud font strings, shown only while a player is near a vending machine.
//
// Data source: docs/13_perks.md cost/effect table (keep in sync with it).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PERK_INFO_RANGE_SQ 28900   // 170u * 170u (show as you approach)

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
    if ( machines.size == 0 )
    {
        acc_utility::log( "perk_info: no zombie_vending machines found" );
        return;
    }
    acc_utility::log( "perk_info: tracking " + machines.size + " perk machines" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            p update_for_player( machines );
        }
        wait 0.2;
    }
}

// self = player
function update_for_player( machines )
{
    nearest_perk = undefined;
    best_sq = ACC_PERK_INFO_RANGE_SQ;

    for ( i = 0; i < machines.size; i++ )
    {
        m = machines[ i ];
        if ( !isdefined( m ) || !isdefined( m.script_noteworthy ) ) continue;
        d_sq = DistanceSquared( self.origin, m.origin );
        if ( d_sq < best_sq )
        {
            best_sq = d_sq;
            nearest_perk = m.script_noteworthy;
        }
    }

    ensure_hud( self );

    if ( !isdefined( nearest_perk ) )
    {
        set_alpha( self, 0 );
        self.acc_pinfo_cur = undefined;
        return;
    }

    if ( isdefined( self.acc_pinfo_cur ) && self.acc_pinfo_cur == nearest_perk )
        return; // already showing this one

    self.acc_pinfo_cur = nearest_perk;
    d = perk_desc( nearest_perk );
    self.acc_pinfo_title SetText( d[ "title" ] );
    self.acc_pinfo_base  SetText( "^7Base: ^5" + d[ "base" ] );
    self.acc_pinfo_mega  SetText( "^7Mega ^6(" + d[ "mega_name" ] + ")^7: ^6" + d[ "mega" ] );
    set_alpha( self, 1 );
}

function set_alpha( p, a )
{
    if ( isdefined( p.acc_pinfo_title ) ) p.acc_pinfo_title.alpha = a * 0.95;
    if ( isdefined( p.acc_pinfo_base ) )  p.acc_pinfo_base.alpha  = a * 0.9;
    if ( isdefined( p.acc_pinfo_mega ) )  p.acc_pinfo_mega.alpha  = a * 0.9;
}

function ensure_hud( p )
{
    if ( isdefined( p.acc_pinfo_title ) ) return;

    p.acc_pinfo_title = p hud::createFontString( "default", 1.7 );
    p.acc_pinfo_title hud::setPoint( "BOTTOM", "BOTTOM", 0, -176 );
    p.acc_pinfo_title.color = ( 0.4, 0.9, 1.0 );
    p.acc_pinfo_title.alpha = 0;
    p.acc_pinfo_title.hidewheninmenu = true;

    p.acc_pinfo_base = p hud::createFontString( "default", 1.3 );
    p.acc_pinfo_base hud::setPoint( "BOTTOM", "BOTTOM", 0, -154 );
    p.acc_pinfo_base.alpha = 0;
    p.acc_pinfo_base.hidewheninmenu = true;

    p.acc_pinfo_mega = p hud::createFontString( "default", 1.3 );
    p.acc_pinfo_mega hud::setPoint( "BOTTOM", "BOTTOM", 0, -134 );
    p.acc_pinfo_mega.alpha = 0;
    p.acc_pinfo_mega.hidewheninmenu = true;
}

// docs/13_perks.md table (base + Mega). Keep in sync with that doc.
function perk_desc( specialty )
{
    d = [];
    switch ( specialty )
    {
    case "specialty_armorvest":
        d[ "title" ] = "JUGGER-NOG  ^7[4000]"; d[ "mega_name" ] = "Ultimate Tank";
        d[ "base" ] = "Survive 6 hits before going down";
        d[ "mega" ] = "7 hits + immune to boss abilities"; break;
    case "specialty_quickrevive":
        d[ "title" ] = "QUICK REVIVE  ^7[2500]"; d[ "mega_name" ] = "Savior";
        d[ "base" ] = "Faster revives + 30% faster HP regen";
        d[ "mega" ] = "Revive 40% faster; +15% speed when a teammate is down"; break;
    case "specialty_fastreload":
        d[ "title" ] = "SPEED COLA  ^7[3500]"; d[ "mega_name" ] = "Sleight of Hand Expert";
        d[ "base" ] = "+50% reload, faster gun swap & perk drink";
        d[ "mega" ] = "+65% reload, +15% swap, +15% drink"; break;
    case "specialty_doubletap2":
        d[ "title" ] = "DOUBLE TAP 2.0  ^7[2000]"; d[ "mega_name" ] = "Gun Slinger";
        d[ "base" ] = "+33% fire rate, +3% damage";
        d[ "mega" ] = "+50% fire rate, +6% damage"; break;
    case "specialty_staminup":
        d[ "title" ] = "STAMIN-UP  ^7[2000]"; d[ "mega_name" ] = "The Flash";
        d[ "base" ] = "Longer, faster sprint";
        d[ "mega" ] = "+12% run, x2 walk, x4 crawl speed"; break;
    case "specialty_additionalprimaryweapon":
        d[ "title" ] = "MULE KICK  ^7[2500]"; d[ "mega_name" ] = "The Armory";
        d[ "base" ] = "Carry a third weapon";
        d[ "mega" ] = "+30% ammo, +2 lethal, +2 tactical"; break;
    case "specialty_deadshot":
        d[ "title" ] = "DEADSHOT  ^7[3500]"; d[ "mega_name" ] = "American Sniper";
        d[ "base" ] = "ADS snaps to head + 1.5x headshot damage";
        d[ "mega" ] = "1.75x headshot + no recoil"; break;
    case "specialty_widowswine":
        d[ "title" ] = "WIDOW'S WINE  ^7[4000]"; d[ "mega_name" ] = "Spiderman";
        d[ "base" ] = "Webs on melee + 50% frag/EMP boost";
        d[ "mega" ] = "Melee 1-hits, web nades 1-hit, hold 6"; break;
    case "specialty_electriccherry":
        d[ "title" ] = "AURA BLAST  ^7[2500]"; d[ "mega_name" ] = "Mega Man";
        d[ "base" ] = "Crouch+melee: 400u shockwave stun, 120s CD";
        d[ "mega" ] = "Affects bosses; 800u, 60s CD, 2 charges"; break;
    default:
        d[ "title" ] = "PERK"; d[ "mega_name" ] = "Mega";
        d[ "base" ] = "-"; d[ "mega" ] = "-"; break;
    }
    return d;
}
