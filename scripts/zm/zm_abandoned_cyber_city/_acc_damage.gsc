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

#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_points;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;

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

#namespace acc_damage;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "damage init (headshot mult " + ACC_HEADSHOT_MULT +
                       "x, boss " + ACC_BOSS_HEADSHOT_MULT + "x)" );

    // VERIFIED(acc): callback::on_ai_damage is registered-but-never-dispatched
    // in stock (no GSC fire site for #"on_ai_damage" exists in the entire
    // mirror, and its dispatcher discards return values anyway). The real
    // damage-MODIFYING hook is zm::register_actor_damage_callback
    // (_zm.gsc:5835), invoked ON the damaged AI with the return value fed to
    // finishActorDamage (_zm.gsc:5824-5861).
    zm::register_actor_damage_callback( &on_ai_damage );

    // VERIFIED(acc): dispatch runs callbacks in registration order and the
    // FIRST non -1 return short-circuits the rest (_zm.gsc:5825-5829). The
    // stock minigun powerup registered during system pre-init (before us)
    // and returns non -1 for every minigun hit - so move ourselves to the
    // FRONT of the array; we return -1 for minigun fire (after recording
    // the damage contribution) so the minigun balancing still runs.
    if ( isdefined( level.actor_damage_callbacks ) && level.actor_damage_callbacks.size > 1 )
    {
        reordered = [];
        reordered[ 0 ] = level.actor_damage_callbacks[ level.actor_damage_callbacks.size - 1 ];
        for ( i = 0; i < level.actor_damage_callbacks.size - 1; i++ )
        {
            reordered[ reordered.size ] = level.actor_damage_callbacks[ i ];
        }
        level.actor_damage_callbacks = reordered;
    }
}

// ---------------------------------------------------------------------------
// Actor damage callback (zm::register_actor_damage_callback)
//
// `self` = the damaged AI (zombie / elite / boss). Args are positional per
// the dispatch at _zm.gsc:5824. Return convention (_zm.gsc:5825-5829):
//   -1            = damage unchanged; LATER callbacks still evaluate
//   anything else = becomes the final damage and short-circuits the rest
// We run FIRST (reordered in init), so returning a value would skip the
// stock minigun adjustment - hence the explicit minigun passthrough below.
// ---------------------------------------------------------------------------

function on_ai_damage( inflictor, attacker, damage, flags, meansofdeath, weapon,
                       vpoint, vdir, sHitLoc, psOffsetTime, boneIndex, surfaceType )
{
    if ( !isdefined( damage ) || damage <= 0 ) return -1;

    if ( !is_applicable_target( self ) ) return -1;

    // Minigun powerup: record the 70/30 contribution, then pass through so
    // the stock minigun balancing callback (behind us in the chain) still
    // adjusts the damage. No headshot multiplier on minigun fire.
    if ( isdefined( weapon ) && isdefined( weapon.name ) && weapon.name == "minigun" )
    {
        if ( isdefined( attacker ) && isplayer( attacker ) )
        {
            self acc_points::record_damage( attacker, damage );
        }
        return -1;
    }

    // Spiderman (Widow's Wine Mega): melee always one-hits ORDINARY zombies
    // (docs/13_perks.md - not bosses/elites). Short-circuits everything else.
    if ( is_melee_mod( meansofdeath )
         && isdefined( attacker ) && isplayer( attacker )
         && acc_mega_bottles::has_mega_perk( attacker, "specialty_widowswine" )
         && !is_boss_or_elite( self ) )
    {
        self acc_points::record_damage( attacker, self.health + 666 );
        return self.health + 666;
    }

    // Compute our adjusted damage (headshot multiplier with Tac-19 exclusion).
    final_damage = damage;
    b_modified = false;
    if ( is_headshot( sHitLoc ) && !is_weapon_headshot_excluded( weapon ) )
    {
        multiplier = resolve_headshot_multiplier( self );

        // Deadshot layer (docs/13_perks.md): base perk x1.5, American Sniper
        // Mega replaces it with x1.75 (no double dip). Stacks multiplicatively
        // with the map multiplier above.
        if ( isdefined( attacker ) && isplayer( attacker )
             && attacker HasPerk( "specialty_deadshot" ) )
        {
            if ( acc_mega_bottles::has_mega_perk( attacker, "specialty_deadshot" ) )
                multiplier *= 1.75;
            else
                multiplier *= 1.5;
        }

        final_damage = int( damage * multiplier );
        b_modified = true;

        /# acc_utility::log( "headshot: " + damage + " -> " + final_damage +
                             " (" + multiplier + "x)" ); #/
    }

    // Record this hit for the 70/30 point-split system. We pass the FINAL
    // damage so a headshot counts for more toward the damage share too
    // (rewards players who aim even if they don't land the kill).
    if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        self acc_points::record_damage( attacker, final_damage );
    }

    if ( b_modified ) return final_damage;
    return -1;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function is_applicable_target( actor )
{
    if ( !isdefined( actor ) ) return false;
    if ( !isdefined( actor.team ) ) return false;
    // BO3 zombies use team "axis". Verified community convention.
    return actor.team == "axis";
}

function is_headshot( hit_loc )
{
    if ( !isdefined( hit_loc ) ) return false;
    // VERIFIED(acc): stock headshot = "head"/"helmet" (_globallogic_utils.gsc:334,
    // _zm_score.gsc:395). "neck" is a real hitloc stock does NOT count as
    // headshot - including it is our deliberate design choice. "j_head" is a
    // model bone tag, never a hit location - removed.
    if ( hit_loc == "head" )   return true;
    if ( hit_loc == "helmet" ) return true;
    if ( hit_loc == "neck" )   return true;
    return false;
}

function resolve_headshot_multiplier( target )
{
    if ( isdefined( target.acc_is_boss )      && target.acc_is_boss )      return ACC_BOSS_HEADSHOT_MULT;
    if ( isdefined( target.acc_is_mini_boss ) && target.acc_is_mini_boss ) return ACC_BOSS_HEADSHOT_MULT;
    return ACC_HEADSHOT_MULT;
}

function is_boss_or_elite( actor )
{
    if ( isdefined( actor.acc_is_boss )      && actor.acc_is_boss )      return true;
    if ( isdefined( actor.acc_is_mini_boss ) && actor.acc_is_mini_boss ) return true;
    if ( isdefined( actor.acc_is_elite )     && actor.acc_is_elite )     return true;
    return false;
}

// VERIFIED(acc): melee meansofdeath strings are "MOD_MELEE" /
// "MOD_MELEE_WEAPON_BUTT" / "MOD_MELEE_ASSASSINATE" (stock-API pass; see
// CHANGELOG). Substring match covers all three.
function is_melee_mod( meansofdeath )
{
    if ( !isdefined( meansofdeath ) ) return false;
    return IsSubStr( meansofdeath, "MELEE" );
}

// Weapons whose damage is intentionally NOT scaled by headshot multiplier.
// Source of truth: docs/05_weapons.md.
//
// Tac-19 is the AW directed-energy blast shotgun. Its energy cone dissipates
// too wide for per-hit-loc multipliers to make design sense; flat damage
// across hit location is the design goal (it trades headshot bonus for a
// bumped base damage in its GDT, making it the best crowd-control gun).
function is_weapon_headshot_excluded( w_weapon )
{
    if ( !isdefined( w_weapon ) ) return false;

    // VERIFIED(acc): resolution goes through zm_weapons::get_base_weapon in
    // weapon_root_name below (PaP mapping is table-driven; rootWeapon.name
    // keeps the _upgraded suffix and must not be used for base lookup).
    name = weapon_root_name( w_weapon );
    if ( !isdefined( name ) ) return false;

    // TODO(acc-data): replace inline list with data-driven GDT flag or table.
    if ( name == "tac19_zm" ) return true;
    return false;
}

function weapon_root_name( w_weapon )
{
    // Defensive: some code paths pass a plain string, others a weapon object.
    // VERIFIED(acc): rootWeapon.name KEEPS the _upgraded suffix for PaP'd
    // assets ("saritch_upgraded" is itself a rootWeapon.name,
    // _zm_weapons.gsc:2510) - the base<->upgrade mapping is table-driven via
    // zm_weapons::get_base_weapon (_zm_weapons.gsc:1624), so route through it.
    if ( isstring( w_weapon ) ) return strip_pap_suffix( w_weapon );
    w_base = zm_weapons::get_base_weapon( w_weapon );
    if ( isdefined( w_base ) && isdefined( w_base.name ) ) return w_base.name;
    if ( isdefined( w_weapon.name ) ) return strip_pap_suffix( w_weapon.name );
    return undefined;
}

// String-input variant: convert to a weapon object first, then resolve via
// the stock base-weapon table (no stock code string-strips "_upgraded").
function strip_pap_suffix( name )
{
    if ( !isdefined( name ) ) return name;
    w = GetWeapon( name );
    if ( isdefined( w ) && w != level.weaponNone )
    {
        return ( zm_weapons::get_base_weapon( w ) ).name;
    }
    return name;
}
