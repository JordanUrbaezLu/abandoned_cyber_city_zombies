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
#using scripts\zm\_zm_perk_additionalprimaryweapon;   // &on_laststand - the stock take we UNREGISTER + replace with a swap-stable one (its perk-thread take twin is overwritten in init)

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
    register_badge( 2, &pred_plasma );    // PLASMA- Plasma Generator implant + holding an energy weapon
    register_badge( 3, &pred_berzerker ); // BRZ   - Berzerker implant + holding a melee weapon it speeds up
    register_badge( 4, &pred_high_caliber ); // HICAL - High Caliber implant + holding a bullet gun it buffs
    register_badge( 5, &pred_warhead );   // WARHD - Warhead Bomber implant + holding an explosive weapon

    acc_utility::log( "gun_badges init (" + level.acc_gun_badge_defs.size + " flag badges)" );

    // MULE-KICK STICKY AT-RISK GUN (2026-07-08 stable order; 2026-07-11 sticky slot). Stock
    // take_additionalprimaryweapon picks the LAST qualifying primary in GetWeaponsListPrimaries()
    // (give-order); every GiveWeapon/TakeWeapon we do for a twin (_acc_weapon_variants) or a PaP pack
    // (_acc_pap_levels) re-appends a gun to the tail of that engine list, so the "3rd gun" flip-flops.
    // Fix: UNREGISTER stock's laststand handler (and overwrite its perk-thread take twin - second block
    // below; BOTH legs must agree or the badge lies) and run our own that removes the DESIGNATED at-risk gun
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

    // ...AND the PERK-THREAD leg (2026-07-15). Stock registers the take on TWO INDEPENDENT hooks -
    // callback::on_laststand (swapped above) AND zm_perks::register_perk_threads
    // (_zm_perk_additionalprimaryweapon.gsc:46 + :57). Swapping only the first left the second running
    // stock's give-order pick, and our boss reaches it TWICE: phase-3 EMP (_acc_boss::disable_perks_for ->
    // perk_pause_all_perks) and phase-2 power-off (disable_power_for -> stock perk_power_off -> perk_pause,
    // _zm_power.gsc:718). Both land on perk_pause, which UnsetPerks the owner then threads
    // player_thread_take( true ) (_zm_perks.gsc:1249-1255) -> take_additionalprimaryweapon() = LAST in
    // GetWeaponsListPrimaries(). So the EMP removed a DIFFERENT gun than the MULE badge advertised - the
    // exact "no idea which gun they will lose" complaint the sticky slot exists to kill - and stock's
    // unpause give thread is EMPTY, so that wrongly-picked gun is gone for good. Same class of bug as the
    // bare-HasPerk gate just fixed in _acc_mega_bottles (has_active_mega_perk / owns_or_paused): a perk
    // path that only considered the DOWN case and ignored perk_pause.
    // We OVERWRITE the struct field rather than re-register: register_perk_threads only writes when the
    // field is UNSET (_zm_perks.gsc:1933), so a re-register would silently no-op. Stock's __init__ is a
    // REGISTER_SYSTEM autoexec, so it has always run by the time acc_main calls us - the same ordering the
    // remove_callback above already depends on - but we guard anyway (same safe-by-construction rule: if
    // the struct is ever missing we simply leave stock's behavior in place instead of throwing).
    if ( isdefined( level._custom_perks ) && isdefined( level._custom_perks[ "specialty_additionalprimaryweapon" ] ) )
        level._custom_perks[ "specialty_additionalprimaryweapon" ].player_thread_take = &acc_mule_on_perk_take;
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

    // [acc] 2026-07-12: a down landing INSIDE a pack's take-all window (replay_pack_draw dwells
    // 2 server frames EMPTY-HANDED under acc_pap_busy) made the force=true resolve below run
    // against an empty primaries list - the whole mule order got wiped, NO gun was taken this
    // down, and the sticky designation re-rolled arbitrarily afterwards (a later down then took
    // an unexpected gun). Defer the take past the transaction - threaded so the laststand
    // callback chain never blocks; the window is ~2 frames, the 0.5s cap is pure paranoia.
    if ( IS_TRUE( self.acc_pap_busy ) )
    {
        self thread mule_take_when_pack_settles();
        return;
    }
    self mule_take_at_risk_guns();
}

// Replaces stock take_additional_primary_weapon_perk on the PERK-THREAD leg (overwritten in init) so the
// perk-EMP removes the gun the badge marked instead of the give-order tail. Mirrors stock's trigger
// condition EXACTLY (_zm_perk_additionalprimaryweapon.gsc:105-111) and then routes the take through
// mule_take_at_risk_guns - the same sticky source as the badge + the down path. Two live callers:
//   perk_pause -> ( true )                    - boss phase-3 EMP + phase-2 power-off (_zm_perks.gsc:1255)
//   perk_think -> ( false, perk_str, result ) - a real perk loss (_zm_perks.gsc:947)
// NO double-take on a down: perk_think's `result` is "player_downed"/"death"/"fake_death", never perk_str
// (= "<perk>_stop"), so this leg no-ops there and acc_mule_on_laststand alone owns the down. NO double-take
// from our TWO mule vending triggers either (Lab + Paradise twin -> perk_pause_all_perks calls perk_pause
// once per trigger, and perk_pause re-fires the take because disabled_perks stays set): the second pass
// sees < 3 qualifying and no-ops, exactly how stock's own `while ( pwtcbt >= 3 )` count gate absorbs it.
function acc_mule_on_perk_take( b_pause, str_perk, str_result )   // self = player
{
    // Stock's `if ( b_pause || str_result == str_perk )`, arg-guarded. perk_pause passes ONE arg, leaving
    // str_perk/str_result UNDEFINED - stock only survives that because `||` short-circuits past the
    // comparison (a bare `string == undefined` THROWS in T7). Keep the short-circuit AND isdefined() them.
    if ( !IS_TRUE( b_pause ) &&
         !( isdefined( str_perk ) && isdefined( str_result ) && str_result == str_perk ) )
        return;

    // HasPerk is deliberately NOT gated here (unlike acc_mule_on_laststand): perk_pause UnsetPerks the
    // player BEFORE threading this (_zm_perks.gsc:1249 then :1255), so it is already false by construction
    // and a bare HasPerk would make this whole override a no-op. Stock's take_additionalprimaryweapon
    // doesn't check it either - only _retain_perks (:117), which we mirror.
    if ( IS_TRUE( self._retain_perks ) ||
         ( isdefined( self._retain_perks_array ) && IS_TRUE( self._retain_perks_array[ "specialty_additionalprimaryweapon" ] ) ) )
        return;

    // Same pack-window deferral as the down path: a force=true resolve inside replay_pack_draw's
    // empty-handed dwell wipes the mule order and takes nothing (see acc_mule_on_laststand).
    if ( IS_TRUE( self.acc_pap_busy ) )
    {
        self thread mule_take_when_pack_settles();
        return;
    }
    self mule_take_at_risk_guns();
}

function mule_take_when_pack_settles()   // self = player
{
    self endon( "disconnect" );
    // Cap raised 10 -> 40 ticks (2026-07-15): acc_pap_busy now also spans _acc_pap_levels::
    // wait_pack_settled (up to 1.5s on its timeout path), so the old 0.5s cap could fire mid-pack.
    for ( t = 0; t < 40 && IS_TRUE( self.acc_pap_busy ); t++ )
        wait 0.05;
    self mule_take_at_risk_guns();
}

function mule_take_at_risk_guns()   // self = player (the deferred body of acc_mule_on_laststand)
{
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

// PLASMA (Plasma Generator, _acc_boss_items item 9): +10% ENERGY-weapon damage while implanted. The badge
// shows while implanted AND the held weapon is an energy gun - straight from acc_damage::is_energy_weapon
// (the SINGLE source of truth the damage side reads, kept in sync automatically). The ENERGY half of the
// old Nuclear item. `acc_item_plasma` is a plain field set by _acc_boss_items::apply_plasma.
function pred_plasma( cur )
{
    if ( !IS_TRUE( self.acc_item_plasma ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    return acc_damage::is_energy_weapon( cur.name );
}

// WARHD (Warhead Bomber, _acc_boss_items item 13): +20% EXPLOSIVE damage while implanted. The badge shows
// while implanted AND the held weapon is an explosive PRIMARY (the launchers + projectile bows) - from
// acc_damage::weapon_is_explosive_gun. The buff itself is MOD-based (is_explosive_mod), so it ALSO covers
// thrown grenades / monkey / octobomb, which aren't a held "gun" and so don't light this held-weapon
// badge (same as the old Nuclear explosive note). `acc_item_warhead` set by _acc_boss_items::apply_warhead.
function pred_warhead( cur )
{
    if ( !IS_TRUE( self.acc_item_warhead ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    return acc_damage::weapon_is_explosive_gun( cur.name );
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

// HICAL (High Caliber Rounds, _acc_boss_items item 12): +25% BULLET-gun damage while implanted. Like
// NUKE/BRZ, the badge shows while the implant is in AND the held weapon is one it buffs - the ballistic
// guns, from acc_damage::weapon_is_bullet_gun (the SINGLE source of truth mirroring the damage gate's
// b_bullet && !is_energy_weapon; energy guns are Nuclear's domain, melee/launcher/bow/projectile-wonders
// never carry a bullet MOD). `acc_item_high_caliber` is a plain field set by _acc_boss_items::apply_high_caliber.
function pred_high_caliber( cur )
{
    if ( !IS_TRUE( self.acc_item_high_caliber ) ) return false;
    if ( !isdefined( cur ) || cur == level.weaponNone || !isdefined( cur.name ) ) return false;
    return acc_damage::weapon_is_bullet_gun( cur.name );
}
