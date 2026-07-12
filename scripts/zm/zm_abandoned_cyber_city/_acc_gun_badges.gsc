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
    register_badge( 3, &pred_berzerker ); // BRZ   - Berzerker implant + holding a melee weapon it speeds up

    acc_utility::log( "gun_badges init (" + level.acc_gun_badge_defs.size + " flag badges)" );

    // MULE-KICK STICKY AT-RISK GUN (2026-07-08 stable order; 2026-07-11 sticky slot). Stock
    // take_additionalprimaryweapon picks the LAST qualifying primary in GetWeaponsListPrimaries()
    // (give-order); every GiveWeapon/TakeWeapon we do for a twin (_acc_weapon_variants) or a PaP pack
    // (_acc_pap_levels) re-appends a gun to the tail of that engine list, so the "3rd gun" flip-flops.
    // Fix: UNREGISTER stock's laststand handler and run our own that removes the DESIGNATED at-risk gun
    // (mule_desired_at_risk_base): the gun that filled the 3rd slot keeps the designation until IT leaves
    // the loadout (replaced -> its replacement inherits; down -> cleared). Identity = acc_weapon_variants::
    // true_base (twin/_up forms of a gun are the same logical gun => our swaps never move it), and the
    // designation FREEZES during inventory transactions (PaP replay / box give / drinks - see
    // mule_state_frozen) so transient take-all windows can't scramble it. pred_mule reads the SAME
    // designation, so the badge and the real removal always agree. SAFE-BY-CONSTRUCTION: the swap-out is
    // guarded (only removes if stock's callback is registered) and acc_mule_on_laststand is count-gated -
    // if the unregister ever no-ops, stock removes one gun first and our handler sees < 3 live qualifying
    // and no-ops, i.e. it degrades to stock behavior rather than double-taking.
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

    // STICKY at-risk gun (user 2026-07-11): the gun DESIGNATED when the player filled their 3rd
    // slot, held until that specific gun leaves the loadout. mule_desired_at_risk_base() owns the
    // designation (reconciled live each call, frozen during inventory transactions) and returns
    // undefined when < 3 qualify. This is the SAME source acc_mule_on_laststand removes from, so
    // badge == real removal always.
    risk_base = self mule_desired_at_risk_base();
    if ( !isdefined( risk_base ) ) return false;

    cur_base = acc_weapon_variants::true_base( cur );
    if ( !isdefined( cur_base ) || cur_base == level.weaponNone ) cur_base = cur;
    return ( cur_base == risk_base );
}

// ---------------------------------------------------------------------------
// MULE-KICK STICKY AT-RISK GUN + take override (2026-07-08 stable order, 2026-07-11 sticky+freeze).
// Two layers:
//   1. self.acc_mule_order - the qualifying LOGICAL guns (acc_weapon_variants::true_base OBJECTS) in
//      FIRST-ACQUISITION order. Because true_base(base)==true_base(twin)==true_base(_up), our twin/PaP
//      give-take never changes an entry's identity - only a genuinely new or dropped gun moves the list.
//   2. self.acc_mule_at_risk - the STICKY DESIGNATION: set to the order's tail when the player first
//      reaches 3 qualifying guns (or right after the designated gun leaves), then held fixed while that
//      gun is carried. This is what the badge lights and the laststand take removes.
// Both are only reconciled OUTSIDE inventory transactions (mule_state_frozen) so take-all/re-give
// windows (PaP tier-3 replay, box gives, drinks) can never scramble them.
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

// True while a multi-step inventory TRANSACTION is in flight on this player - windows where
// GetWeaponsListPrimaries() is transiently WRONG (guns taken and not yet re-given). The mule
// order/designation must NOT reconcile against that phantom state. THE bug this kills (user
// 2026-07-11, "I PaP'd my Mule Kick gun and a different gun became the Mule Kick gun"):
// replay_pack_draw (_acc_pap_levels, PaP tier 2->3) takes EVERY primary, dwells 2 server frames
// empty-handed, then re-gives them in ENGINE order - a 0.25s badge-poll tick landing in that
// window dropped the whole acc_mule_order and rebuilt it in re-give order, jumping the at-risk
// gun to another weapon. Same class: the mystery-box give (acc_box_grabbing - take-at-limit
// churn + the slow raise) and every perk/Mega drink (is_drinking; replay_pack_draw increments
// it too). While frozen we keep the last known order + designation untouched; everything
// resolves on the first un-frozen tick against the settled loadout.
function mule_state_frozen()   // self = player
{
    if ( IS_TRUE( self.acc_pap_busy ) ) return true;
    if ( IS_TRUE( self.acc_box_grabbing ) ) return true;
    if ( isdefined( self.is_drinking ) && self.is_drinking > 0 ) return true;
    return false;
}

// The at-risk LOGICAL gun. STICKY-SLOT semantics (user 2026-07-11: "once you have a mule kick
// gun that spot IS the mule kick spot"): the gun that fills the 3rd slot is DESIGNATED at-risk
// (self.acc_mule_at_risk) and KEEPS the designation while it is still carried in any form
// (twin/_up share its true_base identity). It moves ONLY when that specific gun leaves the
// loadout: replaced at the box/wallbuy -> the replacement inherits the slot (re-designated at
// the tail = newest acquisition); taken on a down / racked -> cleared, the next 3rd gun starts
// fresh. Replacing any OTHER gun never moves it (the old tail-of-acquisition rule handed the
// designation to every new gun - the user's original complaint). undefined while < 3 qualify.
function mule_desired_at_risk_base( force )   // self = player
{
    // Mid-transaction: report "nothing at risk" WITHOUT touching order or designation. The
    // laststand take passes force=true (a down must remove a gun even if it lands inside a
    // drink/box window - stock's own take ran unguarded in exactly that spot).
    if ( !IS_TRUE( force ) && self mule_state_frozen() )
        return undefined;

    present = self mule_reconcile_order();

    // The designated gun genuinely LEFT the loadout (replaced, racked, taken on a down):
    // clear it so a fresh designation happens below. NOTE this checks presence, not count -
    // a count DIP alone (mid box-replace: old gun taken, new not yet given) must never move
    // the designation off a gun the player still carries.
    if ( isdefined( self.acc_mule_at_risk ) && !mule_base_in_list( self.acc_mule_at_risk, present ) )
        self.acc_mule_at_risk = undefined;

    if ( present.size < 3 || self.acc_mule_order.size == 0 )
        return undefined;

    // Sticky: the designated gun is still carried -> it stays the at-risk gun, no matter
    // what was bought, boxed, twinned, or PaP'd since.
    if ( isdefined( self.acc_mule_at_risk ) )
        return self.acc_mule_at_risk;

    // (Re)designate: first time reaching 3 qualifying guns, or the previous at-risk gun just
    // left. The newest acquisition (tail of the stable order) takes the slot.
    self.acc_mule_at_risk = self.acc_mule_order[ self.acc_mule_order.size - 1 ];
    return self.acc_mule_at_risk;
}

function mule_base_in_list( base, list )
{
    for ( i = 0; i < list.size; i++ ) if ( list[ i ] == base ) return true;
    return false;
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
// STICKY designation (mule_desired_at_risk_base - the SAME source the badge lights) instead of "last in
// give-order". Loops like stock (removes while >= 3 qualify; normal Mule play = exactly 3 -> removes 1);
// each pass re-resolves, so a 4+ gun state designates + takes a fresh tail per pass, down to 2.
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

        // Sticky-aware target, force=true: a down must take even inside a drink/transaction
        // window (stock's own take ran unguarded in exactly this spot). Same source as the
        // badge, so the gun the HUD marked is the gun that gets removed. Re-resolved each
        // pass: after a take the sticky clears (gun absent) and, if 4+ guns leave >= 3
        // qualifying, a fresh tail is designated and taken too.
        target_base = self mule_desired_at_risk_base( true );
        if ( !isdefined( target_base ) ) break;       // < 3 qualifying -> nothing (more) to take
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
        // next pass: mule_desired_at_risk_base sees the taken gun absent -> clears the sticky
        // designation and (only if >= 3 still qualify) designates + takes a fresh tail.
    }

    self.acc_mule_at_risk = undefined;   // hygiene: never let a taken gun linger as the designation
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

// BRZ (Berzerker, _acc_boss_items item 11): +35% melee swing speed at 5% max HP per connecting
// melee. Like NUKE, the badge shows while implanted AND the held weapon is one the item speeds up:
// the two HELD melee weapons - Leviathan Axe (all tiers/twins, "leviathan" substring) and Action
// Figure (base + fast + _brz ladders, "t8_melee_figure" substring) - the SAME name tests
// acc_damage::berzerker_melee_weapon runs on the held gun (kept in sync by construction). The
// item's third surface (regular knife bash via the acc_berzerker_melee MELEE-SLOT def) is
// deliberately NOT a badge trigger: the slot is armed while holding ANY gun, so lighting on it
// would pin the badge on permanently - the user's spec is "the badge shows on your melee weapons".
// `acc_item_berzerker` is a plain field set by _acc_boss_items::apply_berzerker.
function pred_berzerker( cur )
{
    if ( !IS_TRUE( self.acc_item_berzerker ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    if ( IsSubStr( cur.name, "leviathan" ) ) return true;        // Leviathan Axe, every tier + brz twin
    if ( IsSubStr( cur.name, "t8_melee_figure" ) ) return true;  // Action Figure, base/fast/_brz ladders
    if ( IsSubStr( cur.name, "knife_ballistic" ) ) return true;  // Ballistic Knife (user 2026-07-11): its held STAB is a real melee the item speeds (+35% via the _acc_brz twins) + taxes - base/PaP/twins via substring
    return false;
}
