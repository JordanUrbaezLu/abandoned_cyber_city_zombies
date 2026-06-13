// =============================================================================
// _acc_pap_levels.gsc - 5-tier money-track Pack-a-Punch
//
// BO3 has exactly ONE upgraded asset per base weapon, so "PaP 5 times" can't be
// 5 engine upgrades. Instead: tier 1 = the STOCK first pack (asset swap + camo).
// Tiers 2..5 are a numeric ladder applied as a damage MULTIPLIER read by our
// damage pipeline. Keyed on the BASE weapon (PaP swaps the held weapon object).
//
//   TIER 0->1: the stock machine's first pack. pap_taken_watcher rides the stock
//     `player notify("pap_taken")` (_zm_pack_a_punch.gsc:637) and records tier 1.
//   TIER 1->5: our own `acc_pap_tier` trigger_radius_use at the PaP origin charges
//     a SCALING cost (2500/5000/7500/10000) and bumps the tier - no asset re-swap,
//     no alt-ammo. The stock re-pack is blocked for upgraded guns via
//     level.pack_a_punch.custom_validation, and stock AAT is off (level.aat_in_use
//     = false in the entry script) so there are no turned/fireworks/etc. rerolls.
//
//   player.acc_pap_tier[ base_weapon ] = 1..5
//   -> pap_damage_cb multiplies pap_tier_mult(tier) into every gun hit.
//   -> HUD shows "PaP TIER x/5" for the held weapon (bottom-left, next to the gun).
//   -> each tier-up prints the new tier's benefit so the player can decide.
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#define ACC_PAP_MAX_TIER 5
#define ACC_PAP_TIER_COST_2 2500
#define ACC_PAP_TIER_COST_3 5000
#define ACC_PAP_TIER_COST_4 7500
#define ACC_PAP_TIER_COST_5 10000

#namespace acc_pap_levels;

function init()
{
    acc_utility::log( "pap_levels: init (max tier " + ACC_PAP_MAX_TIER + ")" );
    zm::register_actor_damage_callback( &pap_damage_cb );
    level thread player_setup_loop();
    level thread pap_tier_machine_watcher(); // multi-pack tiers 2-5, no AAT
}

// cost to move TO `tier` (the NEW tier, 2..5)
function tier_repack_cost( tier )
{
    switch ( tier )
    {
    case 2: return ACC_PAP_TIER_COST_2;
    case 3: return ACC_PAP_TIER_COST_3;
    case 4: return ACC_PAP_TIER_COST_4;
    case 5: return ACC_PAP_TIER_COST_5;
    }
    return 0;
}

// Stock PaP custom_validation hook (_zm_pack_a_punch.gsc:399-406). self = PaP
// machine, arg = player. Returning false makes the stock trigger skip an
// already-upgraded gun, so the stock machine only ever does the FIRST pack and
// the 2500 AAT reroll never fires - all re-packs route to our tier trigger.
function acc_pap_block_stock_repack( player )
{
    w = player GetCurrentWeapon();
    if ( !isdefined( w ) ) return true;
    return !zm_weapons::is_weapon_upgraded( w );
}

function pap_tier_machine_watcher()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // Route re-packs to us (the stock 2500 AAT reroll is suppressed).
    if ( isdefined( level.pack_a_punch ) )
        level.pack_a_punch.custom_validation = &acc_pap_block_stock_repack;

    // Stock PaP use trigger: trigger_radius_use, script_noteworthy=="pack_a_punch".
    triggers = [];
    for ( i = 0; i < 60; i++ )
    {
        all = GetEntArray( "trigger_radius_use", "classname" );
        triggers = [];
        for ( j = 0; j < all.size; j++ )
        {
            if ( isdefined( all[ j ].script_noteworthy )
                 && all[ j ].script_noteworthy == "pack_a_punch" )
                triggers[ triggers.size ] = all[ j ];
        }
        if ( triggers.size > 0 ) break;
        wait 0.5;
    }
    if ( triggers.size == 0 )
    {
        acc_utility::log( "pap_levels: no pack_a_punch trigger; tier re-pack unavailable" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
        level thread pap_tier_trigger_think( triggers[ i ] );
    acc_utility::log( "pap_levels: tier re-pack trigger on " + triggers.size + " machine(s)" );
}

function pap_tier_trigger_think( t_stock )
{
    level endon( "end_game" );

    t = Spawn( "trigger_radius_use", t_stock.origin, 0, 40, 80 );
    t.targetname = "acc_pap_tier";
    t TriggerIgnoreTeam();
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t thread pap_tier_visibility( t_stock );

    for ( ;; )
    {
        t waittill( "trigger", player );
        if ( !isdefined( player ) || !isplayer( player ) ) continue;

        w = player GetCurrentWeapon();
        if ( !isdefined( w ) ) continue;
        if ( !zm_weapons::is_weapon_upgraded( w ) ) continue; // only PaP'd guns tier up

        base = zm_weapons::get_base_weapon( w );
        if ( !isdefined( player.acc_pap_tier ) ) player.acc_pap_tier = [];
        // engine-PaP'd but unseen by us == tier 1 (the first paid bump isn't free).
        cur = ( isdefined( player.acc_pap_tier[ base ] ) ? player.acc_pap_tier[ base ] : 1 );

        if ( cur >= ACC_PAP_MAX_TIER )
        {
            player IPrintLnBold( "^5PACK-A-PUNCH ^7- already ^6max tier " + ACC_PAP_MAX_TIER );
            wait 0.5;
            continue;
        }

        next = cur + 1;
        cost = tier_repack_cost( next );

        if ( !( player zm_score::can_player_purchase( cost ) ) )
        {
            t PlaySound( "zmb_perks_packa_deny" );
            player IPrintLnBold( "^1Not enough points ^7(need " + cost + ")" );
            wait 0.5;
            continue;
        }

        player zm_score::minus_to_player_score( cost );
        player.acc_pap_tier[ base ] = next;
        t PlaySound( "zmb_perks_packa_ready" ); // no aat::acquire -> NO alt-ammo
        player IPrintLnBold( "^5PaP TIER " + next + "/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( next ) );

        wait 0.6;
    }
}

// self = our parallel trigger. t_stock = the stock PaP trigger (hidden per player
// for upgraded guns so its 2500 hint never competes with ours).
function pap_tier_visibility( t_stock )
{
    level endon( "end_game" );
    self endon( "death" );

    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; i < players.size; i++ )
        {
            p = players[ i ];
            show = false;
            held_upgraded = false;
            if ( isdefined( p ) && isplayer( p ) )
            {
                w = p GetCurrentWeapon();
                if ( isdefined( w ) && zm_weapons::is_weapon_upgraded( w ) )
                {
                    held_upgraded = true;
                    base = zm_weapons::get_base_weapon( w );
                    tier = 1;
                    if ( isdefined( p.acc_pap_tier ) && isdefined( p.acc_pap_tier[ base ] ) )
                        tier = p.acc_pap_tier[ base ];
                    if ( tier < ACC_PAP_MAX_TIER )
                    {
                        cost = tier_repack_cost( tier + 1 );
                        self SetHintString( "Hold ^3&&1^7 for PaP Tier " + ( tier + 1 )
                                            + "/" + ACC_PAP_MAX_TIER + " [Cost: " + cost + "]" );
                        show = true;
                    }
                }
            }
            self SetInvisibleToPlayer( p, !show );
            if ( isdefined( t_stock ) )
                t_stock SetInvisibleToPlayer( p, held_upgraded );
        }
        wait 0.25;
    }
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
    case 2: return "+25pct weapon damage";
    case 3: return "+55pct weapon damage";
    case 4: return "+90pct weapon damage";
    case 5: return "+130pct weapon damage (MAX)";
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
