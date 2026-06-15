// =============================================================================
// _acc_pap_levels.gsc - 5-tier money-track Pack-a-Punch
//
// BO3 has exactly ONE upgraded asset per base weapon, so "PaP 5 times" can't be
// 5 engine upgrades. Instead: tier 1 = the first pack (swap to the "_up" gun + gold camo);
// tiers 2..5 are a numeric ladder applied as a damage MULTIPLIER read by our damage
// pipeline. Keyed on the BASE weapon. ALL packs happen IN PLACE - no machine float /
// take-back animation, on any tier. Holding Use swaps/upgrades the held gun right there,
// and EVERY tier replays the first-pack in-hand "gun comes out" draw (user 2026-06-15;
// see replay_pack_draw / acc_pap_tier_anim).
//
//   TIER 0->1: acc_do_first_pack - instant GiveWeapon of the packed form (the matching
//     packed TWIN when the held gun is a perk twin) WITH the gold PaP camo, carries ammo,
//     records tier 1, charges the stock first-pack cost. The stock machine's float pack is
//     BLOCKED (acc_pap_validate returns false for EVERY gun).
//   TIER 1->5: acc_do_tier_up - charge a SCALING cost (2500/5000/7500/10000), bump the tier
//     in place. No asset re-swap, no alt-ammo (stock AAT off via level.aat_in_use=false).
//
//   player.acc_pap_tier[ base_weapon ] = 1..5
//   -> _acc_damage multiplies pap_tier_mult(tier) into every gun hit.
//   -> HUD shows "PaP TIER x/5" for the held weapon (bottom-right, next to the gun).
//   -> each pack/tier-up prints the new tier's benefit so the player can decide.
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

// PaP has no machine float / weapon-lock on any tier - the pack/upgrade happens in hand the
// moment you finish the Use-hold (every tier replays the first-pack in-hand draw, 2026-06-15).
// This debounce just stops one completed Use-hold from re-firing the machine trigger and
// packing/tiering twice (double-charge); short, spans a single hold.
#define ACC_PAP_PACK_DEBOUNCE 1.0
#define ACC_PAP_FIRST_PACK_COST 5000   // fallback if the machine's live self.cost is unset

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

            cost = np armory_discount( tier_repack_cost( tier + 1 ) );   // 10% off with The Armory
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
// arg = player; runs when the player finishes the Use-hold. We do EVERY pack OURSELVES, IN
// PLACE and INSTANTLY (user 2026-06-14: no machine float / animation on any tier), and
// ALWAYS return false so the stock machine's float pack + take-back never runs (that
// take-back is also what raced + ate the Use press = the old "PaP stole my gun" bug).
//   - un-upgraded gun -> acc_do_first_pack: instant swap to the packed form + camo.
//   - upgraded gun     -> acc_do_tier_up: instant tier bump (no asset re-swap, no AAT).
function acc_pap_validate( player )   // self = the PaP machine trigger
{
    w = player GetCurrentWeapon();
    if ( !isdefined( w ) || w == level.weaponNone ) return false;

    // TEMP DIAG (akimbo PaP debug, 2026-06-15 - REMOVE once fixed). For the two dual-wield
    // guns, dump the upgrade resolution to screen + console_mp.log so we can see WHERE the
    // pack fails: no line = validate not reached; packed=NONE = upgrade lookup fails;
    // packed=<rdw> = lookup OK, so the failure is the give/akimbo-equip.
    if ( IsSubStr( w.name, "s1_pdw" ) || IsSubStr( w.name, "s2_m1911" ) || IsSubStr( w.name, "t5_ak74u" ) )
    {
        up = zm_weapons::get_upgrade_weapon( w );
        pf = acc_weapon_variants::packed_form( w );
        up_name = "NONE"; if ( isdefined( up ) && up != level.weaponNone ) up_name = up.name;
        pf_name = "NONE"; if ( isdefined( pf ) && pf != level.weaponNone ) pf_name = pf.name;
        player IPrintLnBold( "^3PaPDIAG held=" + w.name + " upgraded=" + zm_weapons::is_weapon_upgraded( w ) + " getup=" + up_name + " packed=" + pf_name );
    }

    if ( zm_weapons::is_weapon_upgraded( w ) )
        player thread acc_do_tier_up( w );
    else
    {
        // Pass the machine's LIVE cost (self = trigger; self.cost = 5000, or 1000 on a
        // bonfire sale) so we charge exactly what the stock prompt advertises.
        cost = ( isdefined( self.cost ) ? self.cost : ACC_PAP_FIRST_PACK_COST );
        player thread acc_do_first_pack( w, cost );
    }
    return false;    // ALWAYS block the stock float; both packs happen in-hand, instantly
}

// self = player. 10% Armory discount (Mega Mule Kick OWNED right now - not just the
// persistent Mega flag, which survives a down - counting an EMP-paused perk as owned so a
// boss debuff doesn't drop it, a real loss does). Rounds down to a multiple of 10. Shared
// by the first pack, the tier-up, and the machine cost display.
function armory_discount( cost )
{
    if ( isdefined( self.acc_mega_perks )
         && isdefined( self.acc_mega_perks[ "specialty_additionalprimaryweapon" ] )
         && self.acc_mega_perks[ "specialty_additionalprimaryweapon" ] == true
         && ( self HasPerk( "specialty_additionalprimaryweapon" )
              || ( isdefined( self.disabled_perks ) && IS_TRUE( self.disabled_perks[ "specialty_additionalprimaryweapon" ] ) ) ) )
    {
        cost = int( cost * 0.9 );
        cost = int( cost / 10 ) * 10;
    }
    return cost;
}

// self = player. FIRST pack (tier 0->1), IN PLACE + INSTANT: swap the held gun for its
// packed form (the matching packed TWIN if it's a perk twin) with the gold PaP camo, carry
// ammo across, record tier 1. No machine float / take-back. Debounced so one Use-hold can't
// pack twice.
function acc_do_first_pack( w, cost )
{
    if ( isdefined( self.acc_tier_cd ) && GetTime() < self.acc_tier_cd )
        return;
    self.acc_tier_cd = GetTime() + int( ACC_PAP_PACK_DEBOUNCE * 1000 );

    if ( !isdefined( w ) || w == level.weaponNone ) return;

    packed = acc_weapon_variants::packed_form( w );
    // packed == w means "no upgrade exists" (already packed / non-upgradeable hold like a
    // knife or equipment) - bail WITHOUT charging so it can't be "packed".
    if ( !isdefined( packed ) || packed == level.weaponNone || packed == w ) return;

    if ( !isdefined( cost ) ) cost = ACC_PAP_FIRST_PACK_COST;
    if ( !( self zm_score::can_player_purchase( cost ) ) )
    {
        self PlaySound( "zmb_perks_packa_deny" );
        self IPrintLnBold( "^1Not enough points ^7(need " + cost + ")" );
        return;
    }
    self zm_score::minus_to_player_score( cost );

    // Instant in-hand give of the packed gun WITH the gold PaP camo (mirrors the stock give:
    // CalcWeaponOptions(camo,..) -> GiveWeapon(weapon, options) - _zm_weapons.gsc:2584/2597).
    // Carry clip+reserve across (cap-delta, clamp-at-0) so the pack keeps your ammo.
    camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    if ( !isdefined( camo ) ) camo = 0;
    options = self CalcWeaponOptions( camo, 0, 0 );

    clip  = self GetWeaponAmmoClip( w );
    stock = self GetWeaponAmmoStock( w );

    self GiveWeapon( packed, options );
    self SwitchToWeaponImmediate( packed );

    new_clip  = clip  + ( packed.clipSize - w.clipSize );
    new_stock = stock + ( packed.maxAmmo  - w.maxAmmo );
    if ( new_clip  < 0 ) new_clip  = 0;
    if ( new_stock < 0 ) new_stock = 0;
    self SetWeaponAmmoStock( packed, new_stock );
    self SetWeaponAmmoClip( packed, new_clip );
    self TakeWeapon( w );

    base = acc_weapon_variants::true_base( packed );   // tier keyed by the true base
    if ( !isdefined( self.acc_pap_tier ) ) self.acc_pap_tier = [];
    self.acc_pap_tier[ base ] = 1;

    self PlaySound( "zmb_perks_packa_ready" );          // no aat::acquire -> NO alt-ammo
    self IPrintLnBold( "^5PaP TIER 1/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( 1 ) );
}

// self = player. Charge + bump the held upgraded gun's tier (2..5), INSTANT + in place.
// Debounced so a single hold can't tier up more than once.
function acc_do_tier_up( w )
{
    if ( isdefined( self.acc_tier_cd ) && GetTime() < self.acc_tier_cd )
        return;
    self.acc_tier_cd = GetTime() + int( ACC_PAP_PACK_DEBOUNCE * 1000 );

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
    cost = self armory_discount( tier_repack_cost( next ) );   // 10% off with The Armory
    if ( !( self zm_score::can_player_purchase( cost ) ) )
    {
        self PlaySound( "zmb_perks_packa_deny" );
        self IPrintLnBold( "^1Not enough points ^7(need " + cost + ")" );
        return;
    }

    self zm_score::minus_to_player_score( cost );

    // In place, no asset re-swap / float / weapon lock. The tier bumps the moment you finish
    // the Use-hold. The held gun is the SAME asset across tiers 1..5 (only the damage mult
    // changes), so we replay the first-pack draw animation for visible feedback (user
    // 2026-06-15: "do the same exact animation we do for first time pap" on every tier).
    self.acc_pap_tier[ base ] = next;
    self replay_pack_draw( w );
    self PlaySound( "zmb_perks_packa_ready" ); // no aat::acquire -> NO alt-ammo
    self IPrintLnBold( "^5PaP TIER " + next + "/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( next ) );
}

// self = player. Replay the first-pack "gun comes out" draw on the HELD weapon so a
// tier-up reads the same as the first pack (user 2026-06-15). A tier-up keeps the SAME
// weapon asset (only the damage mult changes), so there is no model swap to see - we have
// to play an actual lower+raise. This mirrors the STOCK PaP give-back, which does
// TakeWeapon -> GiveWeapon -> SwitchToWeapon (_zm_pack_a_punch.gsc:823-831): the
// NON-immediate SwitchToWeapon is what plays the putaway+pullout animation.
// SwitchToWeaponImmediate plays NO raise/lower (it is exactly why the recoil-twin swaps are
// invisible), so it showed nothing here - that was the bug. SwitchToWeapon only animates
// when the target is not the current weapon, so we TakeWeapon first to clear it (GiveWeapon
// never auto-equips - stock always follows it with an explicit switch). Take->give->switch
// is one frame with no wait. Carries clip+reserve across. Gated by acc_pap_tier_anim
// (default 1) so it can be reverted to instant tier-ups live.
function replay_pack_draw( w )
{
    if ( getdvarint( "acc_pap_tier_anim", 1 ) == 0 ) return;
    if ( !isdefined( w ) || w == level.weaponNone ) return;
    if ( ( self GetCurrentWeapon() ) != w ) return; // only animate the gun actually in hand

    camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    if ( !isdefined( camo ) ) camo = 0;
    options = self CalcWeaponOptions( camo, 0, 0 );

    clip  = self GetWeaponAmmoClip( w );
    stock = self GetWeaponAmmoStock( w );

    self TakeWeapon( w );
    self GiveWeapon( w, options );
    self SwitchToWeapon( w );               // NON-immediate: plays the lower+raise (stock give-back)
    self SetWeaponAmmoStock( w, stock );
    self SetWeaponAmmoClip( w, clip );
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
// Tier-tracking SAFETY NET (self = player). acc_do_first_pack now records tier 1 itself
// (we block the stock float pack), so the stock "pap_taken" notify never fires in normal
// play - this watcher is a defensive fallback that still records a tier if any stock pack
// path ever runs. Harmless if it never fires.
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

// Tier for the INFO CARD. Clamps an already-upgraded-but-unrecorded gun to tier 1 - a
// belt-and-suspenders for any window where a gun reads is_weapon_upgraded but our
// acc_pap_tier hasn't been written yet (acc_do_first_pack records tier 1 synchronously, so
// this is rare now). Without it the card would render an upgraded gun as a free first pack
// even though re-packing bills tier-2 cost. Keeps the card, the machine hint, and the
// charge in agreement.
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
