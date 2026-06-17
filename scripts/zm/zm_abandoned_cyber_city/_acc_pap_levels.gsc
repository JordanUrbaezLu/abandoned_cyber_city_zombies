// =============================================================================
// _acc_pap_levels.gsc - 3-tier money-track Pack-a-Punch
//
// 3 TIERS (revamp 2026-06-16, user): the damage ladder is +50% / +100% / +150% over the
// gun's normalized base damage, and the ACTUAL PaP TRANSFORM (the "_up" asset - explosive
// M1911, akimbo PDW, gold-camo'd upgrade, etc.) is DEFERRED to tier 2. Tier 1 is a pure
// "camo + damage" pack that keeps the base gun's appearance/behavior.
//
//   TIER 0->1 (cost 5000): acc_do_first_pack - apply the gold PaP camo to the HELD gun IN
//     PLACE (NO asset swap - still the base form / base perk-twin) and record tier 1. +50% dmg.
//     The "explosive M1911 / akimbo PDW / _up" transform does NOT happen yet.
//   TIER 1->2 (cost 7500): acc_do_tier_up - NOW swap to the packed "_up" form (the matching
//     packed TWIN when holding a perk twin) WITH the gold camo, carrying ammo. This is the
//     real PaP transform. +100% dmg.
//   TIER 2->3 (cost 10000): acc_do_tier_up - in place, no asset re-swap, bump damage. +150% (MAX).
//
// ALL packs happen IN PLACE - no machine float / take-back animation, on any tier. Holding
// Use packs the held gun right there, and EVERY tier replays the first-pack in-hand "gun
// comes out" draw (user 2026-06-15; see replay_pack_draw / acc_pap_tier_anim). The stock
// machine's float pack is BLOCKED (acc_pap_validate returns false for EVERY gun).
//
//   player.acc_pap_tier[ base_weapon ] = 1..3   (keyed by acc_weapon_variants::true_base)
//   -> _acc_damage multiplies pap_tier_mult(tier) into every gun hit (1.5 / 2.0 / 2.5).
//   -> HUD shows a roman-numeral cyber-shield icon (I/II/III) for the held weapon, centered
//      on the gadget circle (bottom-right) - acc_hud.lua CoD.AccPapTierIcon via accPapTier.
//   -> each pack/tier-up prints the new tier's benefit so the player can decide.
//
// BOX GUNS MUST COME OUT STOCK (user 2026-06-15). Tier 1 is now a BASE-FORM gun (camo only),
// so we can NO LONGER lean on is_weapon_upgraded() to keep a box copy stock (that was the old
// 5-tier invariant: tier rode the "_up" asset). Two mechanisms replace it, both keyed by
// true_base:
//   - box_grab_clear_watcher (per player, on the stock "user_grabbed_weapon" notify): the
//     weapon just handed over by the Mystery Box is reset to tier 0, so a re-boxed copy of a
//     gun you previously packed is stock again.
//   - tier_possession_prune (in pap_hud_loop): clears acc_pap_tier[ base ] for any base the
//     player no longer carries ANY form of (covers wallbuy-over / slot swaps). Gated on
//     !laststand && !is_drinking && !acc_pap_busy so it never fires mid-pack / mid-down.
//
// "Can't PaP gun X" with the prompt PRESENT but a re-pack no-op = MAX TIER (3/3). Re-packing
// a maxed gun correctly REFUSES ("already max tier 3").
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\hud_util_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm;
#using scripts\zm\_zm_score;
#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;
#using scripts\zm\zm_abandoned_cyber_city\_acc_lui;

#define ACC_PAP_MAX_TIER 3
#define ACC_PAP_TIER_COST_2 7500
#define ACC_PAP_TIER_COST_3 10000

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

// Keep the machine's advertised price equal to the player's ACTUAL next-pack charge. The
// stock hint reads the cost LIVE every frame: an UPGRADED ("_up") gun shows self.aat_cost,
// a base/upgradeable gun shows self.cost (verified vs _zm_pack_a_punch.gsc:430-442). We can't
// reword the stock string from a usermap, but we CAN drive the number. Per-player isn't
// possible on the shared trigger, so it tracks the nearest player (solo-exact). The 10% Armory
// discount is folded in. Reads the perk field directly (no #using cycle). self unused; level loop.
//
// 3-tier mapping (revamp 2026-06-16):
//   tier 0 (stock base)      -> self.cost stays the machine's own cost (5000, or 1000 on a
//                               bonfire sale) - DON'T touch it, so bonfire sales survive.
//   tier 1 (camo'd base)     -> the NEXT pack is the transform (tier 2). The gun is still
//                               un-upgraded, so the prompt reads self.cost -> OVERRIDE it to the
//                               tier-2 price (save/restore so a leftover override never clobbers
//                               the bonfire/stock cost once a tier-0 player returns).
//   tier 2 (_up)             -> self.aat_cost = tier-3 price.
//   tier 3 (_up, MAX)        -> self.aat_cost = 0 (no re-pack; holding Use no-ops, so zeroing
//                               stops the stale tier-3 price falsely advertising a re-pack).
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
            tier = -1;
            w = undefined;
            if ( isdefined( np ) )
            {
                w = np GetCurrentWeapon();
                if ( isdefined( w ) && w != level.weaponNone )
                    tier = get_tier( np, w );
            }

            if ( is_upgraded_safe( w ) )
            {
                // tier 2/3 (_up form): stock prompt reads self.aat_cost. Clear any leftover
                // self.cost override first so a returning tier-0 player sees the real cost.
                restore_machine_cost( t );
                if ( tier < 2 ) tier = 2; // an _up gun is always >= tier 2
                if ( tier >= ACC_PAP_MAX_TIER )
                    t.aat_cost = 0; // maxed: no re-pack
                else
                    t.aat_cost = np armory_discount( tier_repack_cost( tier + 1 ) );
            }
            else if ( tier == 1 )
            {
                // tier 1 (camo'd base, still un-upgraded): stock prompt reads self.cost, but the
                // NEXT pack is the tier-2 transform - override the displayed cost to its price.
                if ( !IS_TRUE( t.acc_cost_overridden ) )
                {
                    t.acc_saved_cost = t.cost;
                    t.acc_cost_overridden = true;
                }
                t.cost = np armory_discount( tier_repack_cost( 2 ) );
            }
            else
            {
                // tier 0 / no player: stock first-pack cost owns self.cost (bonfire-safe).
                restore_machine_cost( t );
            }
        }
        wait 0.2;
    }
}

// is_weapon_upgraded with an undefined/weaponNone guard (the keeper may have no nearby player).
function is_upgraded_safe( w )
{
    if ( !isdefined( w ) || w == level.weaponNone ) return false;
    return zm_weapons::is_weapon_upgraded( w );
}

// Undo a tier-1 self.cost override so the machine's own cost (5000, or a bonfire 1000)
// shows again for a tier-0 first pack.
function restore_machine_cost( t )
{
    if ( IS_TRUE( t.acc_cost_overridden ) )
    {
        t.cost = t.acc_saved_cost;
        t.acc_cost_overridden = false;
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

// cost to move TO `tier` (the NEW tier, 2..3)
function tier_repack_cost( tier )
{
    switch ( tier )
    {
    case 2: return ACC_PAP_TIER_COST_2;
    case 3: return ACC_PAP_TIER_COST_3;
    }
    return 0;
}

// Stock PaP custom_validation hook (_zm_pack_a_punch.gsc:399-406). self = PaP machine,
// arg = player; runs when the player finishes the Use-hold. We do EVERY pack OURSELVES, IN
// PLACE and INSTANTLY (user 2026-06-14: no machine float / animation on any tier), and
// ALWAYS return false so the stock machine's float pack + take-back never runs (that
// take-back is also what raced + ate the Use press = the old "PaP stole my gun" bug).
//
// Routed by the player's CURRENT tier on the held gun (3-tier revamp 2026-06-16):
//   - tier 0 -> acc_do_first_pack: gold camo on the base gun + record tier 1. NO transform.
//   - tier 1 -> acc_do_tier_up (->2): swap to the packed "_up" form (the real transform) + camo.
//   - tier 2 -> acc_do_tier_up (->3): in-place damage bump, no asset re-swap.
//   - tier 3 -> acc_do_tier_up: refuses (already max).
function acc_pap_validate( player )   // self = the PaP machine trigger
{
    w = player GetCurrentWeapon();
    if ( !isdefined( w ) || w == level.weaponNone ) return false;

    if ( get_tier( player, w ) <= 0 )
    {
        // Pass the machine's LIVE cost (self = trigger; self.cost = 5000, or 1000 on a
        // bonfire sale) so we charge exactly what the stock prompt advertises for tier 1.
        cost = ( isdefined( self.cost ) ? self.cost : ACC_PAP_FIRST_PACK_COST );
        player thread acc_do_first_pack( w, cost );
    }
    else
        player thread acc_do_tier_up( w );

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

// self = player. FIRST pack (tier 0->1), IN PLACE + INSTANT. The 3-tier revamp DEFERS the
// "_up" transform to tier 2, so this pack does NOT swap the asset - it applies the gold PaP
// camo to the HELD gun (base form, or base perk-twin) and records tier 1 (+50% damage). The
// gun keeps its base appearance/behavior; the explosive/akimbo/_up form arrives at tier 2.
// Debounced so one Use-hold can't pack twice.
function acc_do_first_pack( w, cost )
{
    if ( isdefined( self.acc_tier_cd ) && GetTime() < self.acc_tier_cd )
        return;
    self.acc_tier_cd = GetTime() + int( ACC_PAP_PACK_DEBOUNCE * 1000 );

    if ( !isdefined( w ) || w == level.weaponNone ) return;

    // Only PACKABLE guns: a hold with no upgrade path (knife / equipment / already-packed)
    // must NOT be chargeable. packed_form() returns the weapon UNCHANGED when there is no
    // upgrade, so packed==w means "nothing to pack".
    packed = acc_weapon_variants::packed_form( w );
    if ( !isdefined( packed ) || packed == level.weaponNone || packed == w ) return;

    if ( !isdefined( cost ) ) cost = ACC_PAP_FIRST_PACK_COST;
    if ( !( self zm_score::can_player_purchase( cost ) ) )
    {
        self PlaySound( "zmb_perks_packa_deny" );
        self IPrintLnBold( "^1Not enough points ^7(need " + cost + ")" );
        return;
    }
    self zm_score::minus_to_player_score( cost );

    base = acc_weapon_variants::true_base( w );   // tier keyed by the true base
    if ( !isdefined( self.acc_pap_tier ) ) self.acc_pap_tier = [];
    self.acc_pap_tier[ base ] = 1;

    // Apply the gold PaP camo to the held gun (NO asset swap). replay_pack_draw re-gives the
    // held weapon WITH the camo options (tier 1 is now recorded) AND plays the draw; when the
    // draw anim is disabled it early-returns, so fall back to a direct camo re-give so tier 1
    // always gets its camo.
    self.acc_pap_busy = true;
    if ( getdvarint( "acc_pap_tier_anim", 1 ) != 0 )
        self replay_pack_draw( w );
    else
        self apply_pap_camo( w );
    self.acc_pap_busy = false;

    self PlaySound( "zmb_perks_packa_ready" );          // no aat::acquire -> NO alt-ammo
    self IPrintLnBold( "^5PaP TIER 1/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( 1 ) );
}

// self = player. Charge + bump the held gun's tier (2 or 3), INSTANT + in place.
//   tier 1 -> 2: the REAL PaP transform - swap to the packed "_up" form (the matching packed
//                TWIN if holding a perk twin) WITH gold camo, carrying ammo.
//   tier 2 -> 3: damage-only bump, no asset re-swap (replays the draw for feedback).
// Debounced so a single hold can't tier up more than once.
function acc_do_tier_up( w )
{
    if ( isdefined( self.acc_tier_cd ) && GetTime() < self.acc_tier_cd )
        return;
    self.acc_tier_cd = GetTime() + int( ACC_PAP_PACK_DEBOUNCE * 1000 );

    base = acc_weapon_variants::true_base( w );   // strips _acc twin suffix so the tier follows recoil swaps
    if ( !isdefined( self.acc_pap_tier ) ) self.acc_pap_tier = [];
    // Effective current tier: stored value, but an already-"_up" gun is at least tier 2.
    cur = ( isdefined( self.acc_pap_tier[ base ] ) ? self.acc_pap_tier[ base ] : 1 );
    if ( zm_weapons::is_weapon_upgraded( w ) && cur < 2 ) cur = 2;

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

    self.acc_pap_busy = true;
    if ( next == 2 )
    {
        // TIER 1 -> 2: the real transform. Swap the held base gun for its packed "_up" form
        // (or matching packed twin) WITH gold camo, carrying ammo. Bail WITHOUT charging if no
        // packed form resolves (should not happen - first pack already proved one exists).
        if ( !acc_do_transform( w, base ) )
        {
            self.acc_pap_busy = false;
            return;
        }
    }
    else
    {
        // TIER 2 -> 3: same "_up" asset, damage-only bump. Replay the draw for visible feedback
        // (user 2026-06-15: "do the same exact animation we do for first time pap" on every tier).
        self replay_pack_draw( w );
    }

    self zm_score::minus_to_player_score( cost );
    self.acc_pap_tier[ base ] = next;
    self.acc_pap_busy = false;
    self PlaySound( "zmb_perks_packa_ready" ); // no aat::acquire -> NO alt-ammo
    self IPrintLnBold( "^5PaP TIER " + next + "/" + ACC_PAP_MAX_TIER + " ^7- " + tier_benefit( next ) );
}

// self = player. Apply the gold PaP camo to the HELD gun in place (no asset swap), carrying
// ammo. Used by the tier-1 first pack when the draw anim is disabled (acc_pap_tier_anim 0) -
// replay_pack_draw applies the camo itself when the anim is on.
function apply_pap_camo( w )
{
    if ( !isdefined( w ) || w == level.weaponNone ) return;
    if ( ( self GetCurrentWeapon() ) != w ) return;

    camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    if ( !isdefined( camo ) ) camo = 0;
    options = self CalcWeaponOptions( camo, 0, 0 );

    clip  = self GetWeaponAmmoClip( w );
    stock = self GetWeaponAmmoStock( w );
    self GiveWeapon( w, options );
    self SwitchToWeaponImmediate( w );
    self SetWeaponAmmoStock( w, stock );
    self SetWeaponAmmoClip( w, clip );
}

// self = player. The tier-1 -> tier-2 asset transform: swap the held gun for its packed "_up"
// form (the matching packed TWIN when holding a perk twin) WITH the gold PaP camo, carrying
// clip+reserve across (cap-delta, clamp-at-0). Mirrors the stock PaP give (CalcWeaponOptions
// -> GiveWeapon(weapon, options), _zm_weapons.gsc:2584/2597). Returns true on a real swap,
// false if no upgrade resolves (caller must not charge). NOTE: the tier is recorded by the
// CALLER after the charge succeeds, so don't write acc_pap_tier here.
function acc_do_transform( w, base )
{
    if ( !isdefined( w ) || w == level.weaponNone ) return false;

    packed = acc_weapon_variants::packed_form( w );
    if ( !isdefined( packed ) || packed == level.weaponNone || packed == w ) return false;

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

    return true;
}

// self = player. Replay the first-pack "gun comes out" draw on a tier-up (user 2026-06-15).
//
// APPROACH (user's idea, 2026-06-15): a tier-up keeps the SAME packed asset, and every in-place
// re-deploy attempt either showed nothing (re-giving the already-held weapon is a no-op) or
// swapped the player onto their OTHER gun (giving the un-packed base conflicts with the held
// packed gun, and taking the current gun auto-switches to the next one). The robust fix:
//   - SNAPSHOT every primary + its ammo,
//   - TAKE THEM ALL (player is empty-handed for a split second, so there is nothing for the
//     engine to fall back to),
//   - GIVE THE PACKED GUN BACK FIRST and switch to it - a FRESH give plays the first-raise/
//     re-cock, exactly like the first pack,
//   - RESTORE the other guns WITHOUT switching, so the packed gun stays in hand.
// No base form -> no weapon-family conflict; everything is taken -> no auto-switch target.
//
// Camo: the gold PaP camo is an OPTION (not baked into the asset), so we re-apply it to the
// packed gun and to any OTHER upgraded gun on restore (all PaP'd guns share the one camo index).
// Ammo is saved/restored per gun. Wrapped in increment_is_drinking()/disable_player_move_states()
// like the stock knuckle crack so the variant reconcile loop + player input can't fight the swap.
// Gated by acc_pap_tier_anim (default 1) so tier-ups can be reverted to instant live (set 0).
// Tune knob: the empty-handed dwell is EMPTY_FRAMES below.
function replay_pack_draw( w )
{
    if ( getdvarint( "acc_pap_tier_anim", 1 ) == 0 ) return;
    if ( !isdefined( w ) || w == level.weaponNone ) return;
    if ( ( self GetCurrentWeapon() ) != w ) return; // only animate the gun actually in hand

    camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    if ( !isdefined( camo ) ) camo = 0;
    pap_options = self CalcWeaponOptions( camo, 0, 0 );

    // Snapshot every primary + ammo. Include the held gun even if the primaries list omits the
    // starting-pistol slot (mirrors reconcile()'s same guard).
    prims = self GetWeaponsListPrimaries();
    have_w = false;
    for ( i = 0; i < prims.size; i++ ) { if ( prims[ i ] == w ) have_w = true; }
    if ( !have_w ) prims[ prims.size ] = w;

    saved_w = [];
    saved_clip = [];
    saved_stock = [];
    for ( i = 0; i < prims.size; i++ )
    {
        p = prims[ i ];
        if ( !isdefined( p ) || p == level.weaponNone ) continue;
        n = saved_w.size;
        saved_w[ n ] = p;
        saved_clip[ n ] = self GetWeaponAmmoClip( p );
        saved_stock[ n ] = self GetWeaponAmmoStock( p );
    }

    self zm_utility::increment_is_drinking();
    self zm_utility::disable_player_move_states( true );

    // Take EVERY primary - now the held gun has nothing to auto-switch onto when removed.
    for ( i = 0; i < saved_w.size; i++ )
        self TakeWeapon( saved_w[ i ] );

    // Brief empty-handed dwell so the takes process and the packed gun re-gives FRESH (a
    // same-frame take+give collapses to a no-op = no draw).
    EMPTY_FRAMES = 2;
    for ( i = 0; i < EMPTY_FRAMES; i++ ) WAIT_SERVER_FRAME;
    if ( !isdefined( self ) ) return;

    // Packed gun back FIRST + raise it -> the first-raise/re-cock plays (fresh give).
    self GiveWeapon( w, pap_options );
    self SwitchToWeaponImmediate( w );

    // Restore the rest (camo for any upgraded gun, ammo for all), WITHOUT switching, so the
    // packed gun stays in hand.
    for ( i = 0; i < saved_w.size; i++ )
    {
        p = saved_w[ i ];
        if ( !isdefined( p ) || p == level.weaponNone ) continue;
        if ( p != w )
        {
            // Re-apply the gold camo to any PaP'd gun (tier >= 1) - NOT just engine-upgraded
            // ones: a tier-1 gun is a camo'd BASE form (is_weapon_upgraded false) and must keep
            // its camo across the take/restore.
            if ( get_tier( self, p ) >= 1 )
                self GiveWeapon( p, pap_options );
            else
                self GiveWeapon( p );
        }
        self SetWeaponAmmoStock( p, saved_stock[ i ] );
        self SetWeaponAmmoClip( p, saved_clip[ i ] );
    }

    self zm_utility::enable_player_move_states();
    self zm_utility::decrement_is_drinking();
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
            p thread box_grab_clear_watcher();   // box guns must come out stock (3-tier revamp)
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

// self = player. The Mystery Box must hand over a STOCK gun (user 2026-06-15). Tier 1 is now a
// camo'd BASE form, so is_weapon_upgraded() can no longer keep a re-boxed copy stock - this
// watcher resets the tier of whatever base the box just gave. Stock fires "user_grabbed_weapon"
// on the player when they take a box weapon (_zm_magicbox.gsc:809); after the give settles the
// box weapon is the current weapon, so clearing that base's tier makes the copy stock again.
function box_grab_clear_watcher()
{
    self endon( "disconnect" );

    for ( ;; )
    {
        self waittill( "user_grabbed_weapon" );
        self util::waittill_any_timeout( 1.0, "weapon_change_complete" ); // let the box give settle
        if ( !isdefined( self ) ) return;

        w = self GetCurrentWeapon();
        if ( !isdefined( w ) || w == level.weaponNone ) continue;
        // A box gun is always a BASE form (the box never rolls our "_up" twins). Only clear base
        // forms so a rare BGB crate-power box upgrade isn't wrongly zeroed.
        if ( zm_weapons::is_weapon_upgraded( w ) ) continue;

        base = acc_weapon_variants::true_base( w );
        if ( isdefined( self.acc_pap_tier ) && isdefined( self.acc_pap_tier[ base ] ) )
            self.acc_pap_tier[ base ] = 0;
    }
}

// self = player. Clear acc_pap_tier[ base ] for any base the player no longer carries ANY form
// of (covers wallbuy-over / slot swaps that leave a stale tier so a future stock copy of that
// base would falsely read PaP'd). The box-grab clear above handles re-boxing the SAME base; this
// catches everything else. Gated so it never fires during a pack / perk drink / laststand -
// windows where the primaries list is transiently incomplete and a legit tier would be dropped.
function prune_lost_tiers()
{
    if ( !isdefined( self.acc_pap_tier ) ) return;
    if ( IS_TRUE( self.laststand ) || IS_TRUE( self.acc_pap_busy ) ) return;
    if ( isdefined( self.is_drinking ) && self.is_drinking > 0 ) return;

    held = [];
    guns = self GetWeaponsListPrimaries();
    eq = self GetCurrentWeapon();
    if ( isdefined( eq ) && eq != level.weaponNone ) guns[ guns.size ] = eq;
    for ( i = 0; i < guns.size; i++ )
    {
        g = guns[ i ];
        if ( !isdefined( g ) || g == level.weaponNone ) continue;
        b = acc_weapon_variants::true_base( g );
        if ( isdefined( b ) && b != level.weaponNone ) held[ b ] = true;
    }

    keys = getarraykeys( self.acc_pap_tier );
    for ( i = 0; i < keys.size; i++ )
    {
        k = keys[ i ];
        if ( self.acc_pap_tier[ k ] <= 0 ) continue;
        if ( !IS_TRUE( held[ k ] ) ) self.acc_pap_tier[ k ] = 0;
    }
}

// PaP tier for `weapon` on `player` (0..3). Twin-aware (keyed by acc_weapon_variants::true_base
// so the tier follows recoil/fire swaps). 3-tier revamp: a BASE gun reads its stored tier
// directly (0 = stock / box-fresh, 1 = camo'd first pack) - the box-grab clear + possession prune
// keep a box copy at 0, so a base gun never shows phantom PaP. An engine-"_up" gun is the tier-2
// transform form or higher; clamp up defensively if our record ever lagged behind the asset.
function get_tier( player, weapon )
{
    if ( !isdefined( weapon ) || weapon == level.weaponNone || !isdefined( player.acc_pap_tier ) ) return 0;
    base = acc_weapon_variants::true_base( weapon );   // twin-aware: tier follows recoil/fire swaps
    stored = ( isdefined( player.acc_pap_tier[ base ] ) ? player.acc_pap_tier[ base ] : 0 );
    if ( zm_weapons::is_weapon_upgraded( weapon ) && stored < 2 ) return 2;
    return stored;
}

// Tier for the INFO CARD. get_tier already clamps an "_up" gun to >= 2, so this is now a thin
// pass-through (kept for callers / future divergence).
function get_card_tier( player, weapon )
{
    return get_tier( player, weapon );
}

// PaP damage ladder (3-tier revamp 2026-06-16): +50% / +100% / +150% over the gun's normalized
// base damage. Returned as a layer for _acc_damage's ADDITIVE bonus_sum (a "+50%" = a 1.5 layer;
// bonus_factor is the literal sum of layers, _acc_damage.gsc:427-430). The "% is the only damage
// lever" model (user 2026-06-16): acc_weapon_balance_mult normalizes every form (base/_up/twin)
// per gun, so the "_up" transform's own raw damage doesn't double-count - this ladder IS the PaP
// damage progression.
function pap_tier_mult( tier )
{
    switch ( tier )
    {
    case 1: return 1.5;
    case 2: return 2.0;
    case 3: return 2.5;
    }
    return 1.0; // tier 0 (not packed)
}

function tier_benefit( tier )
{
    switch ( tier )
    {
    case 1: return "+50pct damage + camo. Pack again to TRANSFORM the gun (tier 2).";
    case 2: return "+100pct damage + upgraded form (explosive / akimbo / etc.)";
    case 3: return "+150pct damage (MAX)";
    }
    return "";
}

// NOTE: the PaP tier damage multiplier formerly lived here as pap_damage_cb (a
// modifying actor-damage callback). It was consolidated into _acc_damage's
// multiplier chain on 2026-06-14 - see the init() comment and the PaP layer in
// _acc_damage::on_ai_damage. get_tier + pap_tier_mult above remain the source of
// truth that chain reads.

// ---------------------------------------------------------------------------
// HUD: held weapon's tier -> accPapTier clientuimodel (roman-numeral icon, bottom-right)
// ---------------------------------------------------------------------------

function pap_hud_loop()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // The held weapon's PaP tier is shown as a roman-numeral cyber-shield icon (I/II/III)
    // by acc_hud.lua's CoD.AccPapTierIcon, centered over the gadget HUD circle (bottom-right).
    // It's driven by the accPapTier clientuimodel, which we push here every 0.25s on change
    // (icon hidden at tier 0). This REPLACED the old bottom-right "PaP TIER x/3" font string
    // (user 2026-06-16) - the same get_tier value perk_info pushes for the PaP card, so the
    // two writers never disagree. set_pap_tier clamps; prune keeps box-fresh bases at 0.
    last_pushed = -1;

    for ( ;; )
    {
        wait 0.25;
        if ( !isdefined( self ) ) return;

        self prune_lost_tiers();   // keep box-fresh / dropped bases at tier 0

        tier = get_tier( self, self GetCurrentWeapon() );
        if ( tier != last_pushed )
        {
            acc_lui::set_pap_tier( self, tier );
            last_pushed = tier;
        }
    }
}
