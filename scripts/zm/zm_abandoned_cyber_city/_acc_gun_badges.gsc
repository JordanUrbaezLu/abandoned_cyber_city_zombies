// =============================================================================
// _acc_gun_badges.gsc - unified GUN-HUD badge system (server half)
//
// One right-anchored row of chips under the ammo readout shows every enhancement
// of the HELD weapon (acc_hud.lua CoD.AccGunBadgeRow). This module owns the FLAG
// badges - on/off per held weapon, packed into ONE `acc_badges` toplayer clientfield
// bitmask. The TIER badges (PaP tier, Overclock level) are value-bearing and ride
// their own existing clientuimodels (accPapTier / accOcTier), pushed by
// _acc_pap_levels::pap_hud_loop / _acc_overclocks::oc_hud_loop - the row re-consumes
// those, so nothing here touches them.
//
// ---------------------------------------------------------------------------
// ADDING A NEW FLAG BADGE - the whole recipe:
//   1. Write a predicate: `function pred_x( cur ) { ... return true/false; }`
//      (self = the player, cur = the held weapon object). Return true to light it.
//   2. `register_badge( <bit>, &pred_x );` in init() below (next free bit; the
//      field is 6 bits = bits 0..5, so 6 flag badges before it must widen - and
//      widening means BOTH _zm_aetherium_hud.gsc AND .csc `acc_badges` registers
//      in lockstep).
//   3. Add its chip to ACC_GUN_BADGES in acc_hud.lua (icon or text), `bit = <bit>`.
// That's it - no new clientfield, no new watch loop, no HUD positioning. Every
// predicate is self-contained + independently correct, so one badge can never
// break another.
//
// WHY A POLL (0.25s), not events: badge state changes on weapon swap, perk
// gain/loss, down/revive, AND our own variant-twin swaps (_acc_weapon_variants
// reconcile GiveWeapon/SwitchToWeapon reorders + reforms the primaries list).
// Chasing all those events is fragile; a cheap change-guarded poll recomputes the
// whole mask from scratch each tick, so it is ALWAYS self-correcting and every
// order of operations converges within 0.25s (e.g. implant-then-hold OR
// hold-then-implant a Turbocharger both light the badge next tick).
//
// The `acc_badges` clientfield itself is REGISTERED in _zm_aetherium_hud.gsc/.csc
// (kept there so the toplayer-scope bit layout stays in lockstep with the other
// currency fields); this module only reads/writes it. docs/19.
// =============================================================================

#using scripts\shared\clientfield_shared;
#using scripts\shared\util_shared;
#using scripts\shared\callbacks_shared;   // on_laststand / remove_callback (MULE stable-order take override)

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;   // is_weapon_included / is_weapon_upgraded (MULE stock-filter replica) + get_player_weapondata (revive bookkeeping)
#using scripts\zm\_zm_perk_additionalprimaryweapon;   // &on_laststand - the stock take we UNREGISTER + replace with a swap-stable one

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;   // true_base() - twin/PaP-invariant weapon identity
#using scripts\zm\zm_abandoned_cyber_city\_acc_damage;            // is_energy_weapon() - Nuclear Energy's buff list (single source of truth)

#namespace acc_gun_badges;

// ---------------------------------------------------------------------------
// Registry
// ---------------------------------------------------------------------------

function init()
{
    level.acc_gun_badge_defs = [];

    // bit -> predicate. The bit MUST match the `bit` field of the matching entry in
    // acc_hud.lua ACC_GUN_BADGES. Order here is irrelevant (each is independent); the
    // bit number is the contract.
    register_badge( 0, &pred_mule );      // MULE  - held gun is the one Mule Kick removes on a down
    register_badge( 1, &pred_turbo );     // TURBO - Turbocharger implant + holding a Havoc
    register_badge( 2, &pred_nuclear );   // NUKE  - Nuclear Energy implant + holding a weapon it buffs

    acc_utility::log( "gun_badges init (" + level.acc_gun_badge_defs.size + " flag badges)" );

    // MULE-KICK STABLE AT-RISK GUN (user 2026-07-08): make the gun Mule Kick removes on a down INVARIANT
    // across our twin / Pack-a-Punch give-take swaps. Stock take_additionalprimaryweapon picks the LAST
    // qualifying primary in GetWeaponsListPrimaries() (give-order); every GiveWeapon/TakeWeapon we do for a
    // Deadshot / Speed Cola Mega twin (_acc_weapon_variants) or a PaP pack (_acc_pap_levels) re-appends a
    // gun to the tail of that engine list, so the "3rd gun" flip-flops (PaP your 1st gun and suddenly it is
    // the one you would lose). Fix: UNREGISTER stock's laststand handler and run our own that removes based
    // on a STABLE per-player acquisition order of LOGICAL guns (acc_weapon_variants::true_base, so a twin/_up
    // of a gun keeps the same identity => our swaps never move it). pred_mule reads the SAME order, so the
    // badge and the real removal always agree. SAFE-BY-CONSTRUCTION: the swap-out is guarded (only removes if
    // stock's callback is registered) and acc_mule_on_laststand is count-gated - if the unregister ever
    // no-ops, stock removes one gun first and our handler sees < 3 live qualifying and no-ops, i.e. it
    // degrades to today's (buggy-but-not-broken) stock behavior rather than double-taking.
    if ( isdefined( level._callbacks ) && isdefined( level._callbacks[ #"on_player_laststand" ] ) )
        callback::remove_callback( #"on_player_laststand", &zm_perk_additionalprimaryweapon::on_laststand, undefined );
    callback::on_laststand( &acc_mule_on_laststand );
}

function register_badge( bit, pred )
{
    d = spawnstruct();
    d.bit = bit;
    d.pred = pred;
    level.acc_gun_badge_defs[ level.acc_gun_badge_defs.size ] = d;
}

function on_player_connect( player )
{
    player thread badge_watch();
}

// Per-player poll: recompute the full flag mask from every registered predicate and push it on
// change. Self-correcting by construction - no event chasing, no per-badge state carried between
// ticks. Re-threaded is unnecessary (endon disconnect only); it survives down/revive so the badge
// re-evaluates live as perks/guns come and go.
function badge_watch()
{
    self endon( "disconnect" );

    last = -1;
    for ( ;; )
    {
        wait 0.25;
        if ( !isdefined( self ) ) return;

        cur = self GetCurrentWeapon();

        mask = 0;
        if ( isdefined( level.acc_gun_badge_defs ) )
        {
            for ( i = 0; i < level.acc_gun_badge_defs.size; i++ )
            {
                d = level.acc_gun_badge_defs[ i ];
                if ( self [[ d.pred ]]( cur ) )
                    mask = mask | ( 1 << d.bit );
            }
        }

        // Plain-field mirror for _acc_dev::dev_badge_probe_loop (dev-only reader; negligible write).
        self.acc_gun_badge_mask = mask;

        if ( mask != last )
        {
            self clientfield::set_to_player( "acc_badges", mask );
            last = mask;
        }
    }
}

// ---------------------------------------------------------------------------
// Predicates - self = the player, cur = the held weapon object (may be undefined /
// weaponNone / a non-gun like knife/bottle). Return true to light the badge THIS tick.
// Each must be independently correct + side-effect free.
// ---------------------------------------------------------------------------

// MULE (user 2026-07-06, "players are dying and have no idea which gun they will lose"): lights while
// the HELD gun is the one Mule Kick removes on a down. Stock stores NO field in advance -
// take_additionalprimaryweapon (_zm_perk_additionalprimaryweapon.gsc:113-148) recomputes at loss
// time: the LAST entry of GetWeaponsListPrimaries() that passes is_weapon_included || is_weapon_upgraded,
// when >= 3 qualify (skipped entirely under _retain_perks). We predict with the SAME filter.
//
// ROBUSTNESS (2026-07-08): resolve every primary to its TRUE BASE before the filter AND for the held
// comparison. Reason: _acc_weapon_variants::reconcile twins ALL primaries (not just the held one)
// whenever a Mega axis is live (Speed Cola / Deadshot Mega) - and a raw perk twin is neither
// is_weapon_included nor is_weapon_upgraded, so filtering the raw objects would drop the count below 3
// mid-Mega and blink the badge off even though the player still holds 3 guns. true_base == the raw
// object when no twin is active, so this is a no-op in the common case and stock-accurate there; when a
// twin IS active it keeps the count + the held match stable (the user's "always attached to the 3rd
// gun"). Also lets holding a twin OF the 3rd gun still light it (held object may be a different form).
function pred_mule( cur )
{
    if ( !( self HasPerk( "specialty_additionalprimaryweapon" ) ) ) return false;
    if ( IS_TRUE( self._retain_perks ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone ) return false;

    // Swap-INVARIANT at-risk gun: the LAST-acquired qualifying LOGICAL gun, from our stable order (NOT the
    // last object in the volatile engine give-order). mule_desired_at_risk_base() rebuilds/reconciles that
    // order live each call (so it is fresh even between the 0.25s polls) and returns undefined when < 3
    // qualify. This is the SAME source acc_mule_on_laststand removes from, so badge == real removal always.
    risk_base = self mule_desired_at_risk_base();
    if ( !isdefined( risk_base ) ) return false;

    cur_base = acc_weapon_variants::true_base( cur );
    if ( !isdefined( cur_base ) || cur_base == level.weaponNone ) cur_base = cur;
    return ( cur_base == risk_base );
}

// ---------------------------------------------------------------------------
// MULE-KICK STABLE AT-RISK ORDER + take override (bug fix, user 2026-07-08).
// A per-player list of the qualifying LOGICAL guns (acc_weapon_variants::true_base OBJECTS) in
// FIRST-ACQUISITION order. Because true_base(base)==true_base(twin)==true_base(_up), our twin/PaP
// give-take never changes an entry's identity - only a genuinely new or dropped gun moves the list -
// so the TAIL (last acquired) is a stable "3rd gun" that does not jump when we swap forms.
// ---------------------------------------------------------------------------

// Deduped set of the player's currently-held qualifying LOGICAL guns, using the SAME filter stock's take
// uses (is_weapon_included || is_weapon_upgraded) applied to the true_base (so a Mega twin - itself neither
// included nor upgraded - still counts as its base gun and does not drop the count below 3 mid-Mega).
function mule_present_bases()   // self = player
{
    out = [];
    prims = self GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
    {
        w = prims[ i ];
        if ( !isdefined( w ) || w == level.weaponNone ) continue;
        b = acc_weapon_variants::true_base( w );
        if ( !isdefined( b ) || b == level.weaponNone ) b = w;
        if ( !( zm_weapons::is_weapon_included( b ) || zm_weapons::is_weapon_upgraded( b ) ) ) continue;
        dup = false;
        for ( j = 0; j < out.size; j++ ) if ( out[ j ] == b ) { dup = true; break; }
        if ( !dup ) out[ out.size ] = b;
    }
    return out;
}

// Reconcile self.acc_mule_order against what the player holds NOW: drop entries no longer present, append
// newly-present ones at the tail (= acquisition order). Returns the present-bases array so callers also get
// the live count. Idempotent + swap-invariant.
function mule_reconcile_order()   // self = player
{
    if ( !isdefined( self.acc_mule_order ) ) self.acc_mule_order = [];
    present = self mule_present_bases();

    kept = [];
    for ( i = 0; i < self.acc_mule_order.size; i++ )
    {
        b = self.acc_mule_order[ i ];
        in_present = false;
        for ( j = 0; j < present.size; j++ ) if ( present[ j ] == b ) { in_present = true; break; }
        if ( in_present )
        {
            // guard against a stale duplicate slipping into the kept list
            already = false;
            for ( k = 0; k < kept.size; k++ ) if ( kept[ k ] == b ) { already = true; break; }
            if ( !already ) kept[ kept.size ] = b;
        }
    }
    for ( j = 0; j < present.size; j++ )
    {
        b = present[ j ];
        in_kept = false;
        for ( i = 0; i < kept.size; i++ ) if ( kept[ i ] == b ) { in_kept = true; break; }
        if ( !in_kept ) kept[ kept.size ] = b;
    }
    self.acc_mule_order = kept;
    return present;
}

// The stable at-risk LOGICAL gun = the most-recently-acquired qualifying gun (tail of the order), iff >= 3
// qualify. undefined otherwise (base Mule play with < 3 guns removes nothing).
function mule_desired_at_risk_base()   // self = player
{
    present = self mule_reconcile_order();
    if ( present.size < 3 || self.acc_mule_order.size == 0 ) return undefined;
    return self.acc_mule_order[ self.acc_mule_order.size - 1 ];
}

// The CURRENT held primary object whose logical identity == target_base (the concrete twin/base/_up form to
// actually TakeWeapon). undefined if not held.
function mule_find_primary_for_base( target_base )   // self = player
{
    prims = self GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
    {
        w = prims[ i ];
        if ( !isdefined( w ) || w == level.weaponNone ) continue;
        b = acc_weapon_variants::true_base( w );
        if ( !isdefined( b ) || b == level.weaponNone ) b = w;
        if ( b == target_base ) return w;
    }
    return undefined;
}

// Any held primary other than `avoid`, to SwitchToWeapon before taking the held at-risk gun (mirrors stock,
// which switches to primary_weapons_that_can_be_taken[0]).
function mule_find_switch_target( avoid )   // self = player
{
    prims = self GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
    {
        w = prims[ i ];
        if ( isdefined( w ) && w != level.weaponNone && w != avoid ) return w;
    }
    return undefined;
}

// Replaces stock _zm_perk_additionalprimaryweapon::on_laststand (unregistered in init). Same guards + same
// revive bookkeeping (the PLURAL map keyed by the taken weapon OBJECT + the SINGULAR field that
// _zm_laststand reads via level.return_additionalprimaryweapon), but picks the gun to remove from our
// STABLE acquisition order instead of "last in give-order". Loops like stock (removes while >= 3 qualify;
// normal Mule play = exactly 3 -> removes 1), always taking the current TAIL of the stable order.
function acc_mule_on_laststand()   // self = player
{
    self.weapon_taken_by_losing_specialty_additionalprimaryweapon = level.weaponNone;
    if ( !( self HasPerk( "specialty_additionalprimaryweapon" ) ) ) return;
    if ( IS_TRUE( self._retain_perks ) ||
         ( isdefined( self._retain_perks_array ) && IS_TRUE( self._retain_perks_array[ "specialty_additionalprimaryweapon" ] ) ) )
        return;   // stock retains the perk + its guns on this down

    self.weapons_taken_by_losing_specialty_additionalprimaryweapon = [];
    last_taken = level.weaponNone;

    guard = 0;
    for ( ;; )
    {
        guard++;
        if ( guard > 8 ) break;                       // hard stop (normal case runs once)

        present = self mule_reconcile_order();        // recomputed each pass: after a take, the count drops
        if ( present.size < 3 ) break;                // < 3 qualifying -> nothing (more) to take
        if ( self.acc_mule_order.size == 0 ) break;

        target_base = self.acc_mule_order[ self.acc_mule_order.size - 1 ];
        w = self mule_find_primary_for_base( target_base );
        if ( !isdefined( w ) || w == level.weaponNone ) break;

        self.weapons_taken_by_losing_specialty_additionalprimaryweapon[ w ] = zm_weapons::get_player_weapondata( self, w );
        if ( w == self GetCurrentWeapon() )
        {
            other = self mule_find_switch_target( w );
            if ( isdefined( other ) && other != level.weaponNone ) self SwitchToWeapon( other );
        }
        self TakeWeapon( w );
        last_taken = w;
        // mule_reconcile_order next pass drops the now-absent `target_base` -> tail advances if we loop again
    }

    self.weapon_taken_by_losing_specialty_additionalprimaryweapon = last_taken;
}

// TURBO: the Turbocharger implant (_acc_boss_items item 8) is Havoc-only, so the badge shows only
// while it is implanted AND the held gun is a Havoc - the SAME IsSubStr "apex_beam_rifle" test as
// _acc_havoc_charge's charge gate (covers base + _up + all 6 twins). Order-independent: whether you
// implant-then-draw or draw-then-implant, the next poll tick lights it. `acc_item_turbocharger` is a
// plain player field set by _acc_boss_items::apply_turbocharger (no #using needed to read it).
function pred_turbo( cur )
{
    if ( !IS_TRUE( self.acc_item_turbocharger ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    return ( IsSubStr( cur.name, "apex_beam_rifle" ) );
}

// NUKE (Nuclear Energy, _acc_boss_items item 9): +15% to ENERGY + EXPLOSIVE damage while implanted.
// The badge shows while implanted AND the held weapon is one Nuclear buffs. Energy guns come straight
// from acc_damage::is_energy_weapon (the SINGLE source of truth the damage side reads - keep them in
// sync automatically). The explosive half of the buff is MOD-based at damage time (grenades / monkeys /
// projectiles), which isn't a held "gun" - the one explosive PRIMARY is the Mahem launcher, so we add
// it explicitly. `acc_item_nuclear` is a plain field set by _acc_boss_items::apply_nuclear_energy.
function pred_nuclear( cur )
{
    if ( !IS_TRUE( self.acc_item_nuclear ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    if ( acc_damage::is_energy_weapon( cur.name ) ) return true;
    if ( IsSubStr( cur.name, "s1_mahem" ) ) return true;   // Mahem launcher = explosive primary
    if ( IsSubStr( cur.name, "t6_war_machine" ) ) return true;   // War Machine drum GL = explosive primary (user 2026-07-09)
    return false;
}
