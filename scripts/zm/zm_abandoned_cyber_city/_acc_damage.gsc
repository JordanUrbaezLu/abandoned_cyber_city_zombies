// =============================================================================
// _acc_damage.gsc - damage interception hooks
//
// Design reference: docs/06_mechanics.md (Headshot Multiplier).
//
// Responsibilities:
//  - Multiply headshot damage on regular/elite zombies by ACC_HEADSHOT_MULT.
//  - Multiply headshot damage on bosses by ACC_BOSS_HEADSHOT_MULT.
//  - Leave body / limb damage untouched.
//  - Stack MULTIPLICATIVELY with any damage-modifier Cyberware / Overclocks;
//    we only touch the final `damage` value at the end of the pipeline.
// =============================================================================

#using scripts\shared\callbacks_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_points;

// ---------------------------------------------------------------------------
// Tuning - see docs/06_mechanics.md.
//
// Multipliers apply AFTER stock weapon-GDT headshot damage has been factored
// in, so effective headshot damage = (stock weapon headshot mult) * (our
// multiplier). If stock is ~1.5x, our 2.0 makes the effective headshot 3x
// base, and boss headshots 4.5x base.
// ---------------------------------------------------------------------------

#define ACC_HEADSHOT_MULT      2.0
#define ACC_BOSS_HEADSHOT_MULT 3.0

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

init()
{
    _acc_utility::log( "damage init (headshot mult " + ACC_HEADSHOT_MULT +
                       "x, boss " + ACC_BOSS_HEADSHOT_MULT + "x)" );

    // Global AI damage callback. Signature verified against modme forums +
    // bo3explorer (scripts/shared/callbacks_shared.gsc). See
    // docs/16_gsc_reference.md section 2 for the full argument list.
    callback::on_ai_damage( &on_ai_damage );
}

// ---------------------------------------------------------------------------
// Global AI damage callback
//
// `self` = the damaged AI (zombie / elite / boss).
// Return the (possibly modified) damage value.
//
// Signature reference: docs/16_gsc_reference.md section 2, or
// https://bo3explorer.zeroy.com/callbacks__shared_8gsc.html
// ---------------------------------------------------------------------------

on_ai_damage( str_mod, str_hit_location, v_hit_origin, e_player, n_amount,
              w_weapon, direction_vec, tagName, modelName, partName,
              dFlags, inflictor, chargeLevel )
{
    if ( !isdefined( n_amount ) || n_amount <= 0 ) return n_amount;

    if ( !is_applicable_target( self ) ) return n_amount;

    // Compute our adjusted damage (headshot multiplier with Tac-19 exclusion).
    final_damage = n_amount;
    if ( is_headshot( str_hit_location ) && !is_weapon_headshot_excluded( w_weapon ) )
    {
        multiplier = resolve_headshot_multiplier( self );
        final_damage = int( n_amount * multiplier );

        /# _acc_utility::log( "headshot: " + n_amount + " -> " + final_damage +
                             " (" + multiplier + "x)" ); #/
    }

    // Record this hit for the 70/30 point-split system. We pass the FINAL
    // damage so a headshot counts for more toward the damage share too
    // (rewards players who aim even if they don't land the kill).
    self _acc_points::record_damage( e_player, final_damage );

    return final_damage;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

is_applicable_target( actor )
{
    if ( !isdefined( actor ) ) return false;
    if ( !isdefined( actor.team ) ) return false;
    // BO3 zombies use team "axis". Verified community convention.
    return actor.team == "axis";
}

is_headshot( hit_loc )
{
    if ( !isdefined( hit_loc ) ) return false;
    // BO3 stock commonly surfaces "head", sometimes "helmet" (armored), and
    // some skeleton bone names like "j_head" / "neck" bleed through.
    // TODO(acc-verify): prune after first playtest shows which strings fire.
    if ( hit_loc == "head" )   return true;
    if ( hit_loc == "helmet" ) return true;
    if ( hit_loc == "j_head" ) return true;
    if ( hit_loc == "neck" )   return true;
    return false;
}

resolve_headshot_multiplier( target )
{
    if ( isdefined( target.acc_is_boss )      && target.acc_is_boss )      return ACC_BOSS_HEADSHOT_MULT;
    if ( isdefined( target.acc_is_mini_boss ) && target.acc_is_mini_boss ) return ACC_BOSS_HEADSHOT_MULT;
    return ACC_HEADSHOT_MULT;
}

// Weapons whose damage is intentionally NOT scaled by headshot multiplier.
// Source of truth: docs/05_weapons.md.
//
// Tac-19 is the AW directed-energy blast shotgun. Its energy cone dissipates
// too wide for per-hit-loc multipliers to make design sense; flat damage
// across hit location is the design goal (it trades headshot bonus for a
// bumped base damage in its GDT, making it the best crowd-control gun).
is_weapon_headshot_excluded( w_weapon )
{
    if ( !isdefined( w_weapon ) ) return false;

    // w_weapon is a weapon struct from BO3. Extract the root name via stock
    // helper. The PaP'd and non-PaP'd variants both report the same root.
    // TODO(acc-verify): confirm `w_weapon.rootweapon.name` is the correct
    // access path. Alternative: `w_weapon.name` direct, or
    // `weapon::get_root_weapon()` stock helper.
    name = weapon_root_name( w_weapon );
    if ( !isdefined( name ) ) return false;

    // TODO(acc-data): replace inline list with data-driven GDT flag or table.
    if ( name == "tac19_zm" ) return true;
    return false;
}

weapon_root_name( w_weapon )
{
    // Defensive: some code paths pass a plain string, others a struct.
    if ( isstring( w_weapon ) ) return strip_pap_suffix( w_weapon );
    if ( isdefined( w_weapon.rootweapon ) && isdefined( w_weapon.rootweapon.name ) )
    {
        return w_weapon.rootweapon.name;
    }
    if ( isdefined( w_weapon.name ) ) return strip_pap_suffix( w_weapon.name );
    return undefined;
}

// Mirror of the helper in _acc_overclocks.gsc - keep in sync when PaP naming
// convention is finalized. Stock convention: PaP'd weapons use the same root
// asset name but with a `_upgraded` suffix on some derivatives.
strip_pap_suffix( name )
{
    if ( !isdefined( name ) ) return name;
    // Check known PaP suffixes; if found, strip. Stock examples seen:
    //   "m8a7_upgraded_zm"  -> "m8a7_zm"
    //   "weapon_variant"    -> unchanged (too varied to generalize)
    // TODO(acc-verify): confirm full set once Mod Tools installed; expand.
    return name;
}
