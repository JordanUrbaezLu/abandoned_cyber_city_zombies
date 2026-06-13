// =============================================================================
// _acc_pap_levels.gsc - 5-tier money-track Pack-a-Punch
//
// BO3 has exactly ONE upgraded asset per base weapon, so "PaP 5 times" can't be
// 5 engine upgrades. Instead: tier 1 = the STOCK first pack (asset swap + camo +
// AAT). Tiers 2..5 are a numeric ladder applied as a damage MULTIPLIER read by
// our damage pipeline. Each pack fires `player notify("pap_taken")`
// (_zm_pack_a_punch.gsc:637), incl. re-packs - so re-packing the same gun walks
// the tier up. Keyed on the BASE weapon (PaP swaps the held weapon object).
//
//   attacker.acc_pap_tier[ base_weapon ] = 1..5
//   -> pap_damage_cb multiplies pap_tier_mult(tier) into every gun hit.
//   -> HUD shows "PaP TIER x/5" for the held weapon (bottom-right).
//   -> each pack prints the new tier's benefit so the player can decide.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PAP_MAX_TIER 5

#namespace acc_pap_levels;

function init()
{
    acc_utility::log( "pap_levels: init (max tier " + ACC_PAP_MAX_TIER + ")" );
    zm::register_actor_damage_callback( &pap_damage_cb );
    level thread player_setup_loop();
}

function player_setup_loop()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;
            if ( IS_TRUE( p.acc_pap_setup_done ) ) continue;

            p.acc_pap_setup_done = true;
            if ( !isdefined( p.acc_pap_tier ) ) p.acc_pap_tier = [];
            p thread pap_taken_watcher();
            p thread pap_hud_loop();
        }
        wait 1;
    }
}

// ---------------------------------------------------------------------------
// Tier tracking - rides the stock PaP "pap_taken" notify (self = player)
// ---------------------------------------------------------------------------

function pap_taken_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "pap_taken" );
        wait 0.2; // let the weapon swap settle so GetCurrentWeapon is the packed gun

        w = self GetCurrentWeapon();
        if ( !isdefined( w ) ) continue;
        base = zm_weapons::get_base_weapon( w );

        if ( !isdefined( self.acc_pap_tier ) ) self.acc_pap_tier = [];
        cur = ( isdefined( self.acc_pap_tier[ base ] ) ? self.acc_pap_tier[ base ] : 0 );
        if ( cur >= ACC_PAP_MAX_TIER )
        {
            self IPrintLnBold( "^5PACK-A-PUNCH ^7- already at ^6max tier " + ACC_PAP_MAX_TIER );
            continue;
        }

        cur++;
        self.acc_pap_tier[ base ] = cur;
        self IPrintLnBold( "^5PaP TIER " + cur + "/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( cur ) );
    }
}

function get_tier( player, weapon )
{
    if ( !isdefined( weapon ) || !isdefined( player.acc_pap_tier ) ) return 0;
    base = zm_weapons::get_base_weapon( weapon );
    if ( !isdefined( player.acc_pap_tier[ base ] ) ) return 0;
    return player.acc_pap_tier[ base ];
}

// Tier 1 = the stock asset upgrade itself (no extra mult). Tiers 2..5 layer on
// a flat extra damage multiplier on top of the stock-PaP'd gun.
function pap_tier_mult( tier )
{
    switch ( tier )
    {
    case 2: return 1.25;
    case 3: return 1.55;
    case 4: return 1.90;
    case 5: return 2.30;
    }
    return 1.0; // tier 0 (not packed) or 1 (stock upgrade only)
}

function tier_benefit( tier )
{
    switch ( tier )
    {
    case 1: return "Pack-a-Punched (camo + alt-ammo). Pack again to raise the tier.";
    case 2: return "+25% weapon damage";
    case 3: return "+55% weapon damage";
    case 4: return "+90% weapon damage";
    case 5: return "+130% weapon damage (MAX)";
    }
    return "";
}

// ---------------------------------------------------------------------------
// Damage multiplier (modifying actor-damage callback; self = victim)
// ---------------------------------------------------------------------------

function pap_damage_cb( inflictor, attacker, damage, flags, meansofdeath, weapon, vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
    if ( !isdefined( attacker ) || !isplayer( attacker ) ) return -1;
    if ( !isdefined( damage ) || damage <= 0 ) return -1;
    if ( !isdefined( weapon ) ) return -1;

    mult = pap_tier_mult( get_tier( attacker, weapon ) );
    if ( mult == 1.0 ) return -1; // no change

    return int( damage * mult );
}

// ---------------------------------------------------------------------------
// HUD: held weapon's tier, bottom-right
// ---------------------------------------------------------------------------

function pap_hud_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    self.acc_pap_hud = self hud::createFontString( "default", 1.4 );
    self.acc_pap_hud hud::setPoint( "BOTTOM_LEFT", "BOTTOM_LEFT", 14, -55 );
    self.acc_pap_hud.alignX = "left";
    self.acc_pap_hud.alignY = "middle";
    self.acc_pap_hud.color = ( 0.7, 0.45, 1.0 );
    self.acc_pap_hud.alpha = 0;
    self.acc_pap_hud.hidewheninmenu = true;

    for ( ;; )
    {
        wait 0.25;
        if ( !isdefined( self ) ) return;

        tier = get_tier( self, self GetCurrentWeapon() );
        if ( tier > 0 )
        {
            self.acc_pap_hud SetText( "^5PaP TIER " + tier + "/" + ACC_PAP_MAX_TIER );
            self.acc_pap_hud.alpha = 0.9;
        }
        else
        {
            self.acc_pap_hud.alpha = 0;
        }
    }
}
