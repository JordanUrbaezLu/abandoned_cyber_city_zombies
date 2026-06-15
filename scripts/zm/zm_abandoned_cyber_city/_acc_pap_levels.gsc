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
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

#define ACC_PAP_MAX_TIER 5
#define ACC_PAP_TIER_COST_2 2500
#define ACC_PAP_TIER_COST_3 5000
#define ACC_PAP_TIER_COST_4 7500
#define ACC_PAP_TIER_COST_5 10000

// Tier-up "re-pack" lock (user 2026-06-14): a tier-up shouldn't be click-and-go. The
// stock gun-into-machine VISUAL is a FILE-PRIVATE function (set_pap_zbarrier_state,
// _zm_pack_a_punch.gsc:1051) so it can't be driven from here; instead we lock the
// player's weapons for this window to give a "pack" feel - no weapon float / parallel
// trigger (which caused the old gun-steal bug, see acc_pap_validate). Tune to taste.
#define ACC_PAP_REPACK_SECONDS 2.5

#namespace acc_pap_levels;

function init()
{
    acc_utility::log( "pap_levels: init (max tier " + ACC_PAP_MAX_TIER + ")" );
    // The PaP tier damage multiplier is applied inside _acc_damage's single
    // multiplier chain (2026-06-14), NOT a separate actor-damage callback. Two
    // modifying callbacks can't coexist: stock dispatch takes the first non -1
    // and passes the original damage to each (_zm.gsc:5824), so a second callback
    // never stacked - PaP tier silently dropped on headshots/perk'd hits. get_tier
    // + pap_tier_mult below stay as the queryable source of truth for that chain.
    level thread player_setup_loop();
    level thread pap_tier_machine_watcher(); // multi-pack tiers 2-5, no AAT
    level thread pap_cost_display_keeper(); // show the real tier-up cost on the machine
}

// The stock PaP machine, for an already-upgraded weapon, prints the "re-Pack-a-Punch"
// hint with `self.aat_cost`. We can't change that wording from a usermap (stock string,
// re-written every frame), but the engine reads `self.aat_cost` LIVE, so we set it to
// the player's actual next-TIER cost (10% off for The Armory). Result: the prompt shows
// the correct price you'll be charged. Per-player isn't possible on the shared trigger,
// so it tracks the nearest player at the machine (solo-exact). Reads the Armory flag
// field directly (no #using cycle). self unused; level loop.
function pap_cost_display_keeper()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    triggers = [];
    for ( i = 0; i < 60; i++ )
    {
        triggers = GetEntArray( "pack_a_punch", "script_noteworthy" );
        if ( triggers.size > 0 ) break;
        wait 0.5;
    }
    if ( triggers.size == 0 ) return;

    for ( ;; )
    {
        for ( i = 0; i < triggers.size; i++ )
        {
            t = triggers[ i ];
            if ( !isdefined( t ) ) continue;

            np = nearest_pap_player( t.origin );
            if ( !isdefined( np ) ) continue;

            w = np GetCurrentWeapon();
            if ( !isdefined( w ) || w == level.weaponNone ) continue;
            if ( !zm_weapons::is_weapon_upgraded( w ) ) continue; // first-pack: stock self.cost

            base = acc_weapon_variants::true_base( w );   // strips _acc twin suffix so the tier follows recoil swaps
            tier = get_tier( np, w );
            if ( tier < 1 ) tier = 1;
            if ( tier >= ACC_PAP_MAX_TIER )
            {
                // Maxed: no further tier-up. The stock hint always advertises a re-pack
                // with self.aat_cost for ANY upgraded gun (no max-tier concept, and we
                // can't reword the string from a usermap), so zero the cost instead of
                // leaving the stale tier-4 price - otherwise a maxed gun falsely offers a
                // ~10000-point re-pack that holding Use silently no-ops (acc_do_tier_up).
                t.aat_cost = 0;
                continue;
            }

            cost = tier_repack_cost( tier + 1 );
            // LIVE Armory discount: require Mule Kick OWNED right now (not just the
            // persistent Mega flag, which survives a down), counting an EMP-paused perk
            // (stock disabled_perks) as owned so the discount survives a boss debuff but
            // still drops on a real loss. Field-direct (no #using cycle).
            if ( isdefined( np.acc_mega_perks )
                 && isdefined( np.acc_mega_perks[ "specialty_additionalprimaryweapon" ] )
                 && np.acc_mega_perks[ "specialty_additionalprimaryweapon" ] == true
                 && ( np HasPerk( "specialty_additionalprimaryweapon" )
                      || ( isdefined( np.disabled_perks ) && IS_TRUE( np.disabled_perks[ "specialty_additionalprimaryweapon" ] ) ) ) )
            {
                cost = int( cost * 0.9 );
                cost = int( cost / 10 ) * 10;
            }

            t.aat_cost = cost; // stock update_hint_string shows this for an upgraded gun
        }
        wait 0.2;
    }
}

function nearest_pap_player( origin )
{
    best = 16900; // 130u - PaP machines are larger than perk vendors
    np = undefined;
    players = GetPlayers();
    for ( i = 0; i < players.size; i++ )
    {
        p = players[ i ];
        if ( !isdefined( p ) || !isplayer( p ) ) continue;
        d = DistanceSquared( p.origin, origin );
        if ( d < best ) { best = d; np = p; }
    }
    return np;
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

// Stock PaP custom_validation hook (_zm_pack_a_punch.gsc:399-406). self = PaP machine,
// arg = player; called when the player holds Use on the machine. This is now the ONLY
// tier-up path. The old design spawned a PARALLEL trigger at the machine's origin, which
// raced the stock take-back and ATE the Use press, so the packed gun could not be grabbed
// - the "PaP stole my gun" bug (worst on the 2nd gun). Behaviour:
//   - un-upgraded gun -> return true: the stock machine does its normal FIRST pack
//     (asset swap + float + take-back), completely uninterfered with.
//   - upgraded gun -> we do the TIER-UP in place (charge the scaling cost, bump the tier;
//     NO asset re-swap, NO float) and return FALSE so the stock re-pack does nothing -
//     there is no floating gun to fail to grab. (aat_in_use=false -> no AAT either.)
function acc_pap_validate( player )
{
    w = player GetCurrentWeapon();
    if ( !isdefined( w ) ) return false;

    if ( !zm_weapons::is_weapon_upgraded( w ) )
        return true; // first pack -> let the stock machine handle it (float + take-back)

    player thread acc_do_tier_up( w );
    return false;    // block the stock re-pack; tier up in place, nothing to steal
}

// self = player. Charge + bump the held upgraded gun's tier. Time-debounced so a single
// hold can't tier up more than once.
function acc_do_tier_up( w )
{
    if ( isdefined( self.acc_tier_cd ) && GetTime() < self.acc_tier_cd )
        return;
    // Debounce spans the whole re-pack window so a held Use / re-trigger can't start a
    // second pack (double-charge / double-tier) before this one finishes.
    self.acc_tier_cd = GetTime() + int( ACC_PAP_REPACK_SECONDS * 1000 ) + 500;

    base = acc_weapon_variants::true_base( w );   // strips _acc twin suffix so the tier follows recoil swaps
    if ( !isdefined( self.acc_pap_tier ) ) self.acc_pap_tier = [];
    // engine-PaP'd but unseen by us == tier 1 (the first paid bump isn't free).
    cur = ( isdefined( self.acc_pap_tier[ base ] ) ? self.acc_pap_tier[ base ] : 1 );

    if ( cur >= ACC_PAP_MAX_TIER )
    {
        self IPrintLnBold( "^5PACK-A-PUNCH ^7- already ^6max tier " + ACC_PAP_MAX_TIER );
        return;
    }

    next = cur + 1;
    cost = tier_repack_cost( next );
    // The Armory (Mega Mule Kick): 10% off the tier-up cost at point of sale. Require Mule
    // Kick OWNED now (not just the persistent Mega flag, which survives a down), counting an
    // EMP-paused perk (stock disabled_perks) as owned so the discount survives a boss debuff
    // but still drops on a real loss. Read the fields directly (self = player; no #using).
    if ( isdefined( self.acc_mega_perks )
         && isdefined( self.acc_mega_perks[ "specialty_additionalprimaryweapon" ] )
         && self.acc_mega_perks[ "specialty_additionalprimaryweapon" ] == true
         && ( self HasPerk( "specialty_additionalprimaryweapon" )
              || ( isdefined( self.disabled_perks ) && IS_TRUE( self.disabled_perks[ "specialty_additionalprimaryweapon" ] ) ) ) )
    {
        cost = int( cost * 0.9 );
        cost = int( cost / 10 ) * 10;
    }
    if ( !( self zm_score::can_player_purchase( cost ) ) )
    {
        self PlaySound( "zmb_perks_packa_deny" );
        self IPrintLnBold( "^1Not enough points ^7(need " + cost + ")" );
        return;
    }

    self zm_score::minus_to_player_score( cost );

    // Re-pack "animation": lock the player's weapons for a short pack window so a tier-up
    // reads as a real pack, not click-and-go. No weapon float / parallel trigger (the old
    // gun-steal bug, see acc_pap_validate), so the gun stays in hand throughout. Plain
    // wait -> a mid-pack down still re-enables weapons after it.
    self PlaySound( "zmb_perks_packa_upgrade" ); // machine "working" sting (silent/no-op if alias absent)
    self DisableWeapons();
    wait ACC_PAP_REPACK_SECONDS;
    self EnableWeapons();

    self.acc_pap_tier[ base ] = next;
    self PlaySound( "zmb_perks_packa_ready" ); // no aat::acquire -> NO alt-ammo
    self IPrintLnBold( "^5PaP TIER " + next + "/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( next ) );
}

function pap_tier_machine_watcher()
{
    level endon( "end_game" );
    level flag::wait_till( "initial_blackscreen_passed" );

    // All machine use routes through our validation (first pack via stock, tier-ups in
    // place). NO parallel trigger -> no take-back theft. We do NOT touch the stock
    // visibility loop, so the machine's own hint shows normally and there is no flicker
    // (no second trigger to fight).
    if ( isdefined( level.pack_a_punch ) )
    {
        level.pack_a_punch.custom_validation = &acc_pap_validate;
        acc_utility::log( "pap_levels: tier-up via custom_validation (no parallel trigger)" );
    }
    else
        acc_utility::log( "pap_levels: level.pack_a_punch undefined; tier-up unavailable" );
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
        base = acc_weapon_variants::true_base( w );   // strips _acc twin suffix so the tier follows recoil swaps

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
    base = acc_weapon_variants::true_base( weapon );   // twin-aware: tier follows recoil swaps
    if ( !isdefined( player.acc_pap_tier[ base ] ) ) return 0;
    return player.acc_pap_tier[ base ];
}

// Tier for the INFO CARD. Clamps an already-upgraded-but-unrecorded gun to tier 1 -
// for the ~0.2s window after a first pack (before pap_taken_watcher records tier 1)
// get_tier still returns 0, which the card would render as a free first pack even
// though re-packing then bills tier-2 cost. Mirror the hint keeper's clamp so the
// card, the machine hint, and the charge all agree.
function get_card_tier( player, weapon )
{
    tier = get_tier( player, weapon );
    if ( tier < 1 && isdefined( weapon ) && weapon != level.weaponNone
         && zm_weapons::is_weapon_upgraded( weapon ) )
        tier = 1;
    return tier;
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

// NOTE: the PaP tier damage multiplier formerly lived here as pap_damage_cb (a
// modifying actor-damage callback). It was consolidated into _acc_damage's
// multiplier chain on 2026-06-14 - see the init() comment and the PaP layer in
// _acc_damage::on_ai_damage. get_tier + pap_tier_mult above remain the source of
// truth that chain reads.

// ---------------------------------------------------------------------------
// HUD: held weapon's tier, bottom-right
// ---------------------------------------------------------------------------

function pap_hud_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    self.acc_pap_hud = self hud::createFontString( "default", 1.4 );
    // Bottom-RIGHT, just above the stock ammo counter (was -175 = too high, -100 = ammo
    // overlapped it). -130 sits clear, next to the gun.
    self.acc_pap_hud hud::setPoint( "BOTTOM_RIGHT", "BOTTOM_RIGHT", -20, -130 );
    self.acc_pap_hud.alignX = "right";
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
