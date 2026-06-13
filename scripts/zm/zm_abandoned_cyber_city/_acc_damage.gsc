// =============================================================================
// _acc_damage.gsc - damage interception hooks
//
// Design reference: docs/06_mechanics.md (Headshot Multiplier), docs/04
// (Cyberware), docs/05 (Overclocks + Weapon Abilities), docs/12 (Boss Items),
// docs/11 (Shielded elite frontal resist).
//
// Responsibilities:
//  - Multiply headshot damage on regular/elite zombies by ACC_HEADSHOT_MULT.
//  - Multiply headshot damage on bosses by ACC_BOSS_HEADSHOT_MULT.
//  - Leave body / limb damage untouched (unless a crit proc promotes the hit).
//  - Consume attacker-side damage flags set by other modules (contract below).
//  - Enforce the Shielded elite frontal resist (and its pierce-Overclock bypass).
//
// Consumed attacker-side contract fields (producers in parentheses):
//  - attacker.acc_cw_damage_mult        flat mult, all gun damage   (_acc_cyberware apply_oc1)
//  - attacker.acc_cw_crit_damage_mult   crit (headshot) damage mult (_acc_cyberware apply_oc2a)
//  - attacker.acc_cw_crit_chance_bonus  0..1 crit chance on non-head bullet hits (_acc_cyberware apply_oc2a)
//  - attacker.acc_item_battery_charged  Kinetic Battery: next shot 3x, then reset (_acc_boss_items)
//  - attacker.acc_ability_crit_shots    int: shots left that auto-crit at 4x (_acc_weapon_abilities, Precision Mode)
//  - attacker.acc_ability_slug_next     bool: next shot 3x single-target (_acc_weapon_abilities, Slug Round)
//  - attacker.acc_oc_active[weapon][..] per-weapon Overclock flags (_acc_overclocks set_oc_flag)
// Target-side:
//  - self.acc_elite_front_damage_resist front-quarter damage fraction (_acc_elites promote_to_shielded)
//
// NOT consumed here (by design):
//  - acc_item_visor (Targeting Visor) has NO damage-side effect - it is
//    client-render work (HP bars on ADS + elite highlight), Phase 4 .csc/LUI
//    per docs/12_boss_items.md.
//  - Movement / reload / fire-rate Overclocks (Burst Coil, Overheat,
//    Subcritical, Spread Cone, Concussive, Reflow, Thermal Lock, Quick
//    Chamber) need weapon-fire/reload/aim hooks - Phase 4.
//
// MULTIPLIER STACKING - all layers are MULTIPLICATIVE; one accumulator
// (n_mult), one int() truncation at the very end. Canonical order (order is
// mathematically irrelevant for pure multiplication, but consumable resets
// and the final reduction make this the documented sequence):
//   0. incoming `damage` (already includes stock GDT headshot mult + PaP)
//   1. crit chain (only when the hit is a crit - real headshot, Precision
//      Mode shot, or Overload chance proc):
//        map headshot mult (2.0 regular / 3.0 boss)
//      x Deadshot (1.5, or 1.75 with American Sniper Mega - no double dip)
//      x Cyberware Overload crit damage (acc_cw_crit_damage_mult, 1.30)
//   2. flat attacker mults (every hit):
//        Cyberware Amplifier (acc_cw_damage_mult, 1.15) - NOT on melee
//        (Bowie exclusion, docs/05 "different damage hook")
//      x AR Overpressure Overclock (1.5x while ADS, docs/06:175)
//   3. one-shot consumables (reset their flag when applied):
//        Precision Mode crit (x4, decrement acc_ability_crit_shots)
//      x Slug Round (x3, clear acc_ability_slug_next)
//      x Kinetic Battery (x3, clear charge + kill counter)
//   4. target-side reduction:
//        Shielded elite frontal resist (x0.25 in the front 90-degree arc,
//        bullets + melee only; bypassed by Piercing / Penetration Round /
//        Breach Overclocks and by grenades/explosives per docs/11 counter-play)
// =============================================================================

#insert scripts\shared\shared.gsh;

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
//
// GSC #defines are file-local (#using does not share macros - see the note at
// _acc_boss_items.gsc:41-45), so damage-side constants for other systems'
// effects live HERE because this is the file that applies them.
// ---------------------------------------------------------------------------

#define ACC_HEADSHOT_MULT      2.0
#define ACC_BOSS_HEADSHOT_MULT 3.0

// Deadshot layer (docs/13_perks.md): base perk x1.5, American Sniper Mega
// replaces it with x1.75 (no double dip).
#define ACC_DEADSHOT_MULT      1.5
#define ACC_DEADSHOT_MEGA_MULT 1.75

// Weapon abilities (docs/05_weapons.md ability table).
#define ACC_ABILITY_CRIT_MULT  4.0
#define ACC_ABILITY_SLUG_MULT  3.0

// Kinetic Battery next-shot multiplier (docs/12_boss_items.md; tuning lever:
// drop to 2x if Battery feels runaway). Charge ACCRUAL is not this file's
// job - see docs/20 battery-charge-per-10-kills.
#define ACC_ITEM_BATTERY_DAMAGE_MULT 3.0

// AR Overpressure Overclock: 1.5x while aiming down sights (docs/06:175).
#define ACC_OC_OVERPRESSURE_ADS_MULT 1.5

// Sniper Reactive Powder Overclock: headshots deal 50% of the BUFFED headshot
// damage as AoE around the impact (docs/06:196).
// TODO(acc-tune): radius is a first-pass guess; revisit in playtest.
#define ACC_OC_REACTIVE_AOE_FRACTION 0.5
#define ACC_OC_REACTIVE_AOE_RADIUS   128

// Shielded elite: "front quarter" = front 90-degree arc = within 45 degrees
// of facing; cos(45 deg) = 0.7071 (docs/11_enemies.md, docs/20 :529).
#define ACC_ELITE_FRONT_ARC_COS 0.7071

#namespace acc_damage;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "damage init (headshot mult " + ACC_HEADSHOT_MULT +
                       "x, boss " + ACC_BOSS_HEADSHOT_MULT +
                       "x, attacker-flag consumers active)" );

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
    // adjusts the damage. No multipliers (and no consumable spend) on
    // minigun fire.
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

    b_player_attacker = isdefined( attacker ) && isplayer( attacker );
    b_melee  = is_melee_mod( meansofdeath );
    b_bullet = is_bullet_mod( meansofdeath );
    b_fire   = is_weapon_fire_mod( meansofdeath );

    oc_flags = undefined;
    if ( b_player_attacker )
    {
        oc_flags = get_oc_flags( attacker, weapon );
    }

    n_mult = 1.0;
    b_modified = false;

    // -----------------------------------------------------------------------
    // 1) Crit determination + crit chain. "Crit" == headshot-equivalent:
    //    a real head hit, a Precision Mode ability shot (auto-crit, ignores
    //    hit-loc per docs/05), or a Cyberware Overload chance proc that
    //    promotes a non-head bullet hit. Tac-19 stays excluded from the
    //    whole crit chain (docs/05 flat-damage rule).
    // -----------------------------------------------------------------------
    b_headshot = is_headshot( sHitLoc ) && !is_weapon_headshot_excluded( weapon );

    b_ability_crit = false;
    if ( b_player_attacker && b_bullet
         && isdefined( attacker.acc_ability_crit_shots )
         && attacker.acc_ability_crit_shots > 0 )
    {
        b_ability_crit = true;
    }

    b_cw_crit_proc = false;
    if ( !b_headshot && !b_ability_crit
         && b_player_attacker && b_bullet
         && !is_weapon_headshot_excluded( weapon )
         && isdefined( attacker.acc_cw_crit_chance_bonus )
         && attacker.acc_cw_crit_chance_bonus > 0 )
    {
        // acc_cw_crit_chance_bonus is a 0..1 float (0.50 = 50%, set by
        // _acc_cyberware.gsc apply_oc2a); roll an int percent against it.
        if ( acc_utility::acc_rand_int( 100 ) < int( attacker.acc_cw_crit_chance_bonus * 100 ) )
        {
            b_cw_crit_proc = true;
        }
    }

    if ( b_headshot || b_ability_crit || b_cw_crit_proc )
    {
        n_mult = n_mult * crit_chain_multiplier( self, attacker );
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 2) Flat attacker-side multipliers (every hit).
    // -----------------------------------------------------------------------
    if ( b_player_attacker )
    {
        // Cyberware Amplifier (oc1): +15% weapon damage on all guns.
        // NOT on melee: Bowie Knife explicitly does not inherit the Cyberware
        // damage buff in v1.0 (docs/05_weapons.md "different damage hook").
        if ( isdefined( attacker.acc_cw_damage_mult ) && !b_melee )
        {
            n_mult = n_mult * attacker.acc_cw_damage_mult;
            b_modified = true;
        }

        // AR Overclock "Overpressure": 1.5x while aiming down sights.
        // VERIFIED(acc): stock ADS check is playerADS() > 0.5, wrapped as
        // util::is_ads (util_shared.gsc:1492-1495, #namespace util at :35).
        if ( has_oc( oc_flags, "overpressure" ) && attacker util::is_ads() )
        {
            n_mult = n_mult * ACC_OC_OVERPRESSURE_ADS_MULT;
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 3) One-shot consumables. Each applies once, then resets its flag.
    //    Gated on weapon FIRE (bullets/projectiles - not melee, not grenades)
    //    so a panic knife or frag toss never wastes the stored shot. Known
    //    simplification: a multi-pellet/multi-penetration shot raises one
    //    damage event per victim; only the FIRST event gets the bonus.
    // -----------------------------------------------------------------------
    if ( b_player_attacker )
    {
        // Weapon ability: Precision Mode (semi-auto AR) - auto-crit at 4x.
        // The crit chain already applied above; this is the ability's own
        // multiplier on top (docs/05: "auto-crit (4x damage, ignore hit-loc)").
        if ( b_ability_crit )
        {
            n_mult = n_mult * ACC_ABILITY_CRIT_MULT;
            attacker.acc_ability_crit_shots -= 1;
            b_modified = true;
        }

        // Weapon ability: Slug Round (shotgun) - next shot 3x single-target.
        if ( IS_TRUE( attacker.acc_ability_slug_next ) && b_fire )
        {
            n_mult = n_mult * ACC_ABILITY_SLUG_MULT;
            attacker.acc_ability_slug_next = false;
            b_modified = true;
        }

        // Boss item: Kinetic Battery - next shot while charged deals 3x.
        // Consume the charge AND reset the kill counter (fields owned by
        // _acc_boss_items.gsc apply_kinetic_battery). The auto-aim half of
        // the item is Phase 4 (docs/20 battery-3x-autoaim-shot).
        if ( IS_TRUE( attacker.acc_item_battery_charged ) && b_fire )
        {
            n_mult = n_mult * ACC_ITEM_BATTERY_DAMAGE_MULT;
            attacker.acc_item_battery_charged = false;
            attacker.acc_item_battery_kill_count = 0;
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 4) Target-side reduction: Shielded elite frontal resist.
    //    self.acc_elite_front_damage_resist (0.25 = "take 25% from front",
    //    _acc_elites.gsc:172). Applies to bullets and melee only - grenades /
    //    explosives bypass per docs/11 counter-play, and so do the pierce
    //    Overclocks (AR Piercing Rounds, Sniper Penetration Round, Shotgun
    //    Breach - the docs/11:31 designed counters).
    // -----------------------------------------------------------------------
    if ( isdefined( self.acc_elite_front_damage_resist )
         && ( b_bullet || b_melee )
         && !has_pierce_oc( oc_flags )
         && hit_is_frontal( self, attacker, vdir ) )
    {
        n_mult = n_mult * self.acc_elite_front_damage_resist;
        b_modified = true;
    }

    // Single truncation at the end of the multiplicative chain; never let a
    // resisted hit floor to 0 (zombies must stay killable by chip damage).
    final_damage = damage;
    if ( b_modified )
    {
        final_damage = int( damage * n_mult );
        if ( final_damage < 1 ) final_damage = 1;

        /# acc_utility::log( "damage: " + damage + " -> " + final_damage +
                             " (x" + n_mult + ")" ); #/
    }

    // -----------------------------------------------------------------------
    // 5) On-headshot side effects (real bullet head hits only - the bullet
    //    gate keeps chained AoE/DoDamage events from re-triggering these).
    // -----------------------------------------------------------------------
    if ( b_player_attacker && b_headshot && b_bullet )
    {
        // AR Overclock "Adaptive Aim": headshots refund one round to the
        // magazine (docs/06:194).
        if ( has_oc( oc_flags, "adaptive" ) )
        {
            adaptive_aim_refund( attacker, weapon );
        }

        // Sniper Overclock "Reactive Powder": headshots deal 50% AoE damage,
        // scaled off the BUFFED headshot damage (docs/06:196).
        if ( has_oc( oc_flags, "reactive" ) )
        {
            level thread reactive_powder_aoe( attacker, self, vpoint, final_damage );
        }
    }

    // Record this hit for the 70/30 point-split system. We pass the FINAL
    // damage so a buffed hit counts for more toward the damage share too
    // (rewards players who aim even if they don't land the kill).
    if ( b_player_attacker )
    {
        self acc_points::record_damage( attacker, final_damage );
    }

    if ( b_modified ) return final_damage;
    return -1;
}

// ---------------------------------------------------------------------------
// Crit chain: map headshot multiplier x Deadshot x Cyberware Overload.
// Used for real headshots AND headshot-equivalent crits (Precision Mode,
// Overload chance proc) - the whole chain travels together by design.
// ---------------------------------------------------------------------------

function crit_chain_multiplier( target, attacker )
{
    n_mult = resolve_headshot_multiplier( target );

    if ( isdefined( attacker ) && isplayer( attacker ) )
    {
        // Deadshot layer (docs/13_perks.md): base perk x1.5, American Sniper
        // Mega replaces it with x1.75 (no double dip). Stacks multiplicatively
        // with the map multiplier above.
        if ( attacker HasPerk( "specialty_deadshot" ) )
        {
            if ( acc_mega_bottles::has_mega_perk( attacker, "specialty_deadshot" ) )
                n_mult = n_mult * ACC_DEADSHOT_MEGA_MULT;
            else
                n_mult = n_mult * ACC_DEADSHOT_MULT;
        }

        // Cyberware Overload (oc2a): +30% crit damage
        // (attacker.acc_cw_crit_damage_mult = 1.30, _acc_cyberware.gsc).
        if ( isdefined( attacker.acc_cw_crit_damage_mult ) )
        {
            n_mult = n_mult * attacker.acc_cw_crit_damage_mult;
        }
    }

    return n_mult;
}

// ---------------------------------------------------------------------------
// Overclock flag access. Storage format owned by _acc_overclocks.gsc
// set_oc_flag: self.acc_oc_active[ weapon ][ flag_name ] = true, keyed by
// the weapon OBJECT held at the terminal.
// VERIFIED(acc): weapon objects are valid array keys - stock keys
// self.stored_weapon_info[ weapon ] the same way (_zm.gsc:3055).
// ---------------------------------------------------------------------------

function get_oc_flags( player, w_weapon )
{
    if ( !isdefined( player ) || !isdefined( w_weapon ) ) return undefined;
    if ( !isdefined( player.acc_oc_active ) ) return undefined;

    if ( isdefined( player.acc_oc_active[ w_weapon ] ) )
    {
        return player.acc_oc_active[ w_weapon ];
    }

    // PaP'ing swaps the held weapon OBJECT, so a weapon tiered before PaP
    // would miss on the upgraded object - fall back to the base-weapon key.
    // VERIFIED(acc): base lookup is table-driven via zm_weapons::
    // get_base_weapon (_zm_weapons.gsc:1624).
    w_base = zm_weapons::get_base_weapon( w_weapon );
    if ( isdefined( w_base ) && isdefined( player.acc_oc_active[ w_base ] ) )
    {
        return player.acc_oc_active[ w_base ];
    }

    return undefined;
}

function has_oc( a_flags, str_flag )
{
    if ( !isdefined( a_flags ) ) return false;
    if ( !isdefined( a_flags[ str_flag ] ) ) return false;
    return a_flags[ str_flag ] == true;
}

// Flag names from _acc_overclocks.gsc apply_oc_ar_piercing /
// apply_oc_sr_penetration / apply_oc_sg_breach.
function has_pierce_oc( a_flags )
{
    if ( has_oc( a_flags, "piercing" ) )    return true;
    if ( has_oc( a_flags, "penetration" ) ) return true;
    if ( has_oc( a_flags, "breach" ) )      return true;
    return false;
}

// ---------------------------------------------------------------------------
// Shielded elite frontal arc test.
// Prefer attacker origin (always defined for player hits); fall back to vdir.
// VERIFIED(acc): the facing-vs-damage-direction dot pattern is stock -
// vectordot( AnglesToForward( self.angles ), vDir ) at _zm.gsc:1494, where
// dot > 0 means the damage source is BEHIND the victim (vDir is the damage
// travel direction, _zm.gsc:1487-1499) - so a FRONTAL hit is dot < 0.
// VERIFIED(acc): VectorNormalize is the stock normalizer
// (zm_giant_cleanup_mgr.gsc:260).
// ---------------------------------------------------------------------------

function hit_is_frontal( e_victim, e_attacker, v_dir )
{
    v_forward = AnglesToForward( e_victim.angles );

    if ( isdefined( e_attacker ) )
    {
        v_to_attacker = VectorNormalize( e_attacker.origin - e_victim.origin );
        return VectorDot( v_forward, v_to_attacker ) > ACC_ELITE_FRONT_ARC_COS;
    }

    if ( isdefined( v_dir ) )
    {
        return VectorDot( v_forward, v_dir ) < ( -1 * ACC_ELITE_FRONT_ARC_COS );
    }

    return false;
}

// ---------------------------------------------------------------------------
// Overclock side effects
// ---------------------------------------------------------------------------

// Adaptive Aim: +1 round back into the magazine, clamped to clip size.
// VERIFIED(acc): GetWeaponAmmoClip / SetWeaponAmmoClip are the stock clip
// APIs (player-called with a weapon object, _zm.gsc:3055 / _zm.gsc:2868);
// clip capacity is weapon.clipSize (_zm_weapons.gsc:3003).
function adaptive_aim_refund( player, w_weapon )
{
    if ( !isdefined( w_weapon ) ) return;

    n_clip = player GetWeaponAmmoClip( w_weapon );
    if ( !isdefined( w_weapon.clipSize ) || n_clip >= w_weapon.clipSize ) return;

    player SetWeaponAmmoClip( w_weapon, n_clip + 1 );
}

// Reactive Powder: deal ACC_OC_REACTIVE_AOE_FRACTION of the buffed headshot
// damage to every OTHER zombie near the impact. Threaded with a frame wait so
// the chained damage runs outside the actor-damage callstack; manual zombie
// iteration (instead of RadiusDamage) so the AoE can never splash players.
// Re-entry into on_ai_damage is safe: DoDamage events are not bullet MODs,
// so they can never re-trigger this AoE (or any bullet-gated proc).
// VERIFIED(acc): GetAITeamArray( "axis" ) returns the zombie AI array
// (zm_giant_cleanup_mgr.gsc:101; _zm.gsc:5491 uses level.zombie_team).
// VERIFIED(acc): ent DoDamage( damage, origin, attacker ) is stock
// (_destructible.gsc:264; AI-targeted 2-arg form zm_giant_teleporter.gsc:857).
function reactive_powder_aoe( e_attacker, e_victim, v_point, n_headshot_damage )
{
    wait( 0.05 ); // leave the damage callback's callstack first

    if ( !isdefined( e_attacker ) ) return;
    if ( !isdefined( v_point ) ) return;

    n_aoe = int( n_headshot_damage * ACC_OC_REACTIVE_AOE_FRACTION );
    if ( n_aoe < 1 ) return;

    n_radius_sq = ACC_OC_REACTIVE_AOE_RADIUS * ACC_OC_REACTIVE_AOE_RADIUS;
    a_zombies = GetAITeamArray( "axis" );
    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !isdefined( z ) || !isalive( z ) ) continue;
        if ( isdefined( e_victim ) && z == e_victim ) continue; // no double dip
        if ( distancesquared( z.origin, v_point ) > n_radius_sq ) continue;

        z DoDamage( n_aoe, v_point, e_attacker );
    }
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

// VERIFIED(acc): bullet damage MODs are "MOD_PISTOL_BULLET" /
// "MOD_RIFLE_BULLET", and a killing headshot blow can arrive as
// "MOD_HEAD_SHOT" - stock groups all three (_zm.gsc:5790).
function is_bullet_mod( meansofdeath )
{
    if ( !isdefined( meansofdeath ) ) return false;
    if ( meansofdeath == "MOD_PISTOL_BULLET" ) return true;
    if ( meansofdeath == "MOD_RIFLE_BULLET" )  return true;
    if ( meansofdeath == "MOD_HEAD_SHOT" )     return true;
    return false;
}

// VERIFIED(acc): grenade MODs are "MOD_GRENADE" / "MOD_GRENADE_SPLASH"
// (_zm_spawner.gsc:1981). Substring covers both.
function is_grenade_mod( meansofdeath )
{
    if ( !isdefined( meansofdeath ) ) return false;
    return IsSubStr( meansofdeath, "GRENADE" );
}

// "Weapon fire" = damage from a SHOT: bullets, plus launched projectiles
// (Tac-19-style energy blasts register as projectile/explosive MODs -
// VERIFIED(acc): "MOD_PROJECTILE" / "MOD_PROJECTILE_SPLASH" / "MOD_EXPLOSIVE"
// are the stock projectile family, _zm_spawner.gsc:1995). Thrown grenades
// and melee are NOT shots; neither are chained DoDamage events (undefined /
// MOD_UNKNOWN), which keeps AoE chains from eating stored consumables.
function is_weapon_fire_mod( meansofdeath )
{
    if ( is_bullet_mod( meansofdeath ) ) return true;
    if ( !isdefined( meansofdeath ) ) return false;
    if ( is_grenade_mod( meansofdeath ) ) return false;
    if ( IsSubStr( meansofdeath, "PROJECTILE" ) ) return true;
    if ( meansofdeath == "MOD_EXPLOSIVE" ) return true;
    return false;
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
        // VERIFIED(acc): GSC forbids field access on a parenthesized
        // expression - '( call ).field' errors "Primitive expression field
        // object must be... call/variable/self/level/anim". A direct
        // 'call().field' IS allowed (stock GetPlayers().size), but the wrap
        // is not - use a temp. First-compile finding 2026-06-12.
        w_base = zm_weapons::get_base_weapon( w );
        return w_base.name;
    }
    return name;
}
