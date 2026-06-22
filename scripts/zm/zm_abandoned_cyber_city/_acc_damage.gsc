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
// MULTIPLIER STACKING - BONUSES ADD, REDUCTIONS MULTIPLY (2026-06-14, user rule:
// "if we have 3x and 2x that's 5x not 6x"). Two buckets, one int() truncation at
// the end. final_damage = int( damage * bonus_factor * reduction ) where:
//   - bonus_factor = the LITERAL SUM of every applied BONUS value (>1), or 1.0 if
//     none fired. So a 2x headshot + 1.4x Deadshot = 3.4x, NOT 2.8x.
//   - reduction = the PRODUCT of every REDUCTION factor (<1), applied AFTER the
//     bonus sum (a 0.25x resist must cut, never add). ORDER NOW MATTERS.
//   0. incoming `damage` (already includes stock GDT headshot mult + PaP)
//   BONUSES (summed):
//     - crit chain (crit hits only - real headshot, Precision Mode, Overload proc):
//         map headshot mult (2.0 regular / 2.0 boss)
//       + Deadshot (1.4, or 1.8 with American Sniper Mega - no double dip)
//       + Cyberware Overload crit damage (acc_cw_crit_damage_mult, 1.30)
//     - PaP custom tier (1.25/1.55/1.90/2.30)
//     - Cyberware Amplifier (acc_cw_damage_mult, 1.15) - NOT on melee (Bowie excl.)
//     - Cyberware Weapon Overclock flat-damage layer (1 + tier*acc_oc_dmg_per_tier; +5%/tier, +25% at T5)
//     - one-shot consumables (reset their flag when applied): Precision Mode (4),
//       Slug Round (3), Kinetic Battery (3)
//   REDUCTIONS (multiplied, after the sum):
//     - per-gun balance cut (acc_weapon_balance_mult)
//     - shielded elite frontal resist (0.25 in the front 90-deg arc, bullets +
//       melee; bypassed by Piercing/Penetration/Breach + grenades, docs/11)
// =============================================================================

#insert scripts\shared\shared.gsh;

#using scripts\shared\util_shared;

#using scripts\zm\_zm;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_points;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;

// ---------------------------------------------------------------------------
// Tuning - see docs/06_mechanics.md.
//
// Bonus multipliers apply AFTER the weapon-GDT hit-location mult is baked into the
// incoming `damage`, so effective head:body ratio = (gun locHead) x (our headshot bonus).
// Most box guns are locHead 5.0, so the 0.5 reg / 1.0 boss bonus = 2.5x reg / 5x boss head;
// Paladin (locHead 1.0) = 0.5x / 1.0x. (Was 2.0/2.0 = 10x/10x reg+boss; nerfed 2026-06-16.)
//
// GSC #defines are file-local (#using does not share macros - see the note at
// _acc_boss_items.gsc:41-45), so damage-side constants for other systems'
// effects live HERE because this is the file that applies them.
// ---------------------------------------------------------------------------

#define ACC_HEADSHOT_MULT      0.5    // map headshot BONUS, regular/elite (was 2.0, lowered 2026-06-16).
#define ACC_BOSS_HEADSHOT_MULT 1.0    // bosses/mini-bosses (was 2.0). Effective head:body = gun locHead x this
                                      // (most guns locHead 5.0 -> 2.5x reg / 5x boss; Paladin locHead 1.0 -> 0.5x/1x).

// Deadshot layer (docs/13_perks.md): base perk +1.4 headshot, American Sniper Mega
// replaces it with +1.6 (no double dip; retuned 1.8->1.6 2026-06-16). These ADD into
// the bonus sum (not multiply) - see the stacking header. Recoil: base Deadshot now has
// NONE; Mega = -50% (single weapon-GDT twin tier, MEGA-gated, off the 2.1x base) - see
// docs/30/31 + docs/39. The recoil half is weapon-GDT (twin), not GSC.
#define ACC_DEADSHOT_MULT      1.4
#define ACC_DEADSHOT_MEGA_MULT 1.6

// Mega Flopper (PhD Slider): +15% explosive damage (user 2026-06-18, nerfed from +20%). ADDS
// into the bonus sum like every other layer (so +0.15 on the effective multiplier). GSC-only -
// a damage-dealt scalar here, NOT a weapon-GDT stat, so no twin weapon is needed.
#define ACC_MEGA_FLOPPER_EXPLOSIVE_MULT 1.15

// NOTE (docs/13_perks.md, 2026-06-14 overhaul): Double Tap is now "Double Tap 1.0"
// = fire-rate ONLY (no damage bonus), and Widow's Wine base no longer grants frag
// damage. Both former GSC damage layers were REMOVED here to match the spec.

// Weapon abilities (docs/05_weapons.md ability table).
#define ACC_ABILITY_CRIT_MULT  4.0
#define ACC_ABILITY_SLUG_MULT  3.0

// Pellet-shotgun vs BOSS cut (user 2026-06-21): a pellet shotgun (Tac-19/Olympia) is balanced for CHAFF -
// its 8 pellets spread across a crowd, each zombie eating ~1-2. Against a BOSS (one big hitbox) ALL pellets
// land on the same target, so its damage stacks ~8x into a boss nuke. Cut shotgun damage vs bosses/mini-
// bosses so it UNDER-performs there (the intended design, docs/05) while keeping its S-tier chaff clear.
// REDUCTION (multiplicative). Dvar-tunable: acc_shotgun_boss_mult.
#define ACC_SHOTGUN_BOSS_MULT  0.25

// Kinetic Battery next-shot multiplier (docs/12_boss_items.md; tuning lever:
// drop to 2x if Battery feels runaway). Charge ACCRUAL is not this file's
// job - see docs/20 battery-charge-per-10-kills.
#define ACC_ITEM_BATTERY_DAMAGE_MULT 3.0

// Cyberware Weapon Overclock (user 2026-06-19; T5 2026-06-21): each TIER (1..5) gives a SMALL boost to ALL
// THREE effects at once - magnitudes scale with the gun's tier (minimal at T1, full at T5). PER-GUN. The
// tier multiplies the live oc_tier directly (NO clamp), so adding tiers just extends these automatically.
//   1 Flat damage    : +acc_oc_dmg_per_tier per tier     (default 0.05 -> +25% at T5, ALWAYS on, gun hits)
//   2 Glitch Piercing : +acc_oc_glitch_per_tier per tier  (default 0.25 -> +125% at T5 vs GLITCH zombies)
//   3 Ammo refund    : +acc_oc_adaptive_per_tier per tier (default 0.10 -> 50% refund chance at T5) on a HEADSHOT KILL (not just a headshot hit, user 2026-06-21)
#define ACC_OC_DMG_PER_TIER            0.05
#define ACC_OC_GLITCH_PER_TIER         0.25
#define ACC_OC_ADAPTIVE_PER_TIER       0.10
#define ACC_OC_REACTIVE_AOE_RADIUS     128   // legacy: reactive_powder_aoe kept but no longer wired

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

    // TRENCH WARDEN damage-gate (user 2026-06-18): while Brutus is the pit boss
    // (self.acc_warden_active, set in _acc_boss_brutus::trench_warden_think once he
    // drops into the pit), he is DAMAGE-IMMUNE to any player who isn't physically in
    // the trench - you can't snipe/grenade him from the rim, stairs, or slab; you must
    // commit and go all the way down. Returning 0 short-circuits the callback chain to a
    // final 0 damage (_zm.gsc:5825-5829). Non-player damage (world/scripted) is unaffected,
    // and when the gate is off (rollback dvar) acc_warden_active is never set so this is inert.
    if ( IS_TRUE( self.acc_warden_active ) && isdefined( attacker ) && isplayer( attacker )
         && !acc_bus_trench::player_in_trench( attacker ) )
    {
        return 0;
    }

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
            // No damage number here: the stock minigun-balancing callback runs
            // AFTER us and adjusts the final applied value, so we cannot report it
            // accurately from this point. (Minigun is a temporary powerup, not a
            // weapon under test - showing nothing beats showing a wrong number.)
        }
        return -1;
    }

    // NOTE (docs/13_perks.md, 2026-06-14 overhaul): the Spiderman Mega no longer
    // grants melee/web-grenade ONE-HIT kills. Spiderman is now "hold 6 web
    // grenades + restock 4/round" (handled in _acc_mega_bottles). Those two OHK
    // short-circuit blocks were REMOVED here to match the spec.

    b_player_attacker = isdefined( attacker ) && isplayer( attacker );
    b_melee  = is_melee_mod( meansofdeath );
    b_bullet = is_bullet_mod( meansofdeath );
    b_fire   = is_weapon_fire_mod( meansofdeath );

    // Spiderman (Widow's Wine Mega, user 2026-06-18): ONE-KNIFE on REGULAR zombies.
    // A melee hit from a player holding Mega'd Widow's instakills a normal zombie - but
    // NOT bosses/elites (is_boss_or_elite gate). Short-circuit return (lethal damage), so
    // it skips the bonus chain below. Re-adds the melee OHK the 2026-06-14 overhaul removed.
    if ( b_player_attacker && b_melee
         && acc_mega_bottles::has_active_mega_perk( attacker, "specialty_widowswine" )
         && !is_boss_or_elite( self ) )
    {
        return self.health + 1000;
    }

    oc_flags = undefined;
    oc_tier  = 0;   // Cyberware Weapon Overclock tier (0..5) for THIS gun (per-gun, user 2026-06-19).
    if ( b_player_attacker )
    {
        oc_flags = get_oc_flags( attacker, weapon );
        oc_tier  = get_oc_tier( attacker, weapon );   // all 3 effects scale small-per-tier off this (T1..T5)
    }

    // Additive bonus model (2026-06-14): BONUS layers add into bonus_sum (literal
    // sum, 1.0 base if none fired); REDUCTION layers (<1) multiply into reduction
    // and apply AFTER. final = damage * bonus_factor * reduction. See the header.
    bonus_sum  = 0.0; // sum of applied bonus multiplier values (each > 1)
    n_applied  = 0;   // how many bonus layers fired (0 -> bonus_factor stays 1.0)
    reduction  = 1.0; // product of reduction factors (< 1)
    b_modified = false;

    // -----------------------------------------------------------------------
    // 0) Per-weapon BALANCE multiplier (user, 2026-06-14): HARD-map damage cut
    //    Five-Seven -62.5%, ASM1 -73.75%, Tac-19 -25%. A flat per-gun damage
    //    scale - a REDUCTION (<1) applied multiplicatively AFTER the bonus sum, so
    //    it scales body AND buffed hits alike. Covers base + PaP + Deadshot recoil
    //    variants via substring match. See acc_weapon_balance_mult.
    // -----------------------------------------------------------------------
    if ( isdefined( weapon ) && isdefined( weapon.name ) )
    {
        n_bal = acc_weapon_balance_mult( weapon.name );
        if ( n_bal != 1.0 )
        {
            reduction = reduction * n_bal; // REDUCTION (<1): stays multiplicative
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 0b) Pellet-shotgun vs BOSS cut (user 2026-06-21): a pellet shotgun (Tac-19/Olympia) is
    //     CHAFF-tuned (8 pellets spread across a crowd), but on a boss ALL pellets concentrate
    //     on one hitbox -> ~8x stacked damage = a boss nuke. Cut it vs bosses/mini-bosses so it
    //     under-performs there (intended, docs/05) without touching its chaff S-tier. REDUCTION.
    // -----------------------------------------------------------------------
    if ( ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
         && is_pellet_shotgun( weapon ) )
    {
        reduction = reduction * getdvarfloat( "acc_shotgun_boss_mult", ACC_SHOTGUN_BOSS_MULT );
        b_modified = true;
    }

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
        // Crit chain, now ADDITIVE: each layer ADDS its value into bonus_sum
        // (was an internal product folded in by one multiply). Base layer = the
        // map headshot mult (2.0 regular / 2.0 boss).
        bonus_sum += resolve_headshot_multiplier( self );
        n_applied++;

        if ( isdefined( attacker ) && isplayer( attacker ) )
        {
            // Deadshot: base +1.4, American Sniper Mega replaces it with +1.8
            // (no double dip - one or the other).
            if ( attacker HasPerk( "specialty_deadshot" ) )
            {
                if ( acc_mega_bottles::has_mega_perk( attacker, "specialty_deadshot" ) )
                    bonus_sum += ACC_DEADSHOT_MEGA_MULT;
                else
                    bonus_sum += ACC_DEADSHOT_MULT;
                n_applied++;
            }

            // Cyberware Overload (oc2a): +30% crit-damage layer
            // (attacker.acc_cw_crit_damage_mult = 1.30, _acc_cyberware.gsc).
            if ( isdefined( attacker.acc_cw_crit_damage_mult ) )
            {
                bonus_sum += attacker.acc_cw_crit_damage_mult;
                n_applied++;
            }
        }

        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 2) Flat attacker-side multipliers (every hit).
    // -----------------------------------------------------------------------
    if ( b_player_attacker )
    {
        // Pack-a-Punch custom tier (T1..T3, 3-tier revamp 2026-06-16): flat damage layer
        // (+50% / +100% / +150% = 1.5 / 2.0 / 2.5) added to bonus_sum. The "_up" transform's
        // own raw damage is normalized per-gun by acc_weapon_balance_mult (substring match on
        // base/_up/twin alike), so this ladder is the ONLY PaP damage lever - no double-count.
        // CONSOLIDATED here
        // (2026-06-14) from a SEPARATE actor-damage callback (_acc_pap_levels
        // pap_damage_cb): the stock dispatch returns the FIRST non -1 callback and
        // passes the ORIGINAL damage to each (_zm.gsc:5824), so two modifying
        // callbacks are mutually exclusive - PaP tier never stacked with
        // headshots/perks (it silently dropped on any modified hit) and the
        // crosshair number under-reported it. One chain = one true final_damage.
        pap_mult = acc_pap_levels::pap_tier_mult( acc_pap_levels::get_tier( attacker, weapon ) );
        if ( pap_mult != 1.0 )
        {
            bonus_sum += pap_mult; // BONUS: added to the sum
            n_applied++;
            b_modified = true;
        }

        // Cyberware Amplifier (oc1): +15% weapon damage on all guns.
        // NOT on melee: Bowie Knife explicitly does not inherit the Cyberware
        // damage buff in v1.0 (docs/05_weapons.md "different damage hook").
        if ( isdefined( attacker.acc_cw_damage_mult ) && !b_melee )
        {
            bonus_sum += attacker.acc_cw_damage_mult; // BONUS: added to the sum
            n_applied++;
            b_modified = true;
        }

        // Cyberware Weapon Overclock - effect 1/3: FLAT per-tier weapon damage, ALWAYS on (hip + ADS;
        // gun hits only, oc_tier is 0 for melee). +acc_oc_dmg_per_tier per tier (default +5%/tier ->
        // +25% at T5). Adds 1 + tier*per_tier (>=1) into the additive bonus sum.
        if ( oc_tier > 0 )
        {
            bonus_sum += 1.0 + ( oc_tier * getdvarfloat( "acc_oc_dmg_per_tier", ACC_OC_DMG_PER_TIER ) );
            n_applied++;
            b_modified = true;
        }

        // Cyberware Weapon Overclock - effect 2/3: GLITCH PIERCING - bonus damage vs glitch zombies (the
        // Glitch Stalker + lockdown-challenge glitch zombies, flagged self.acc_is_glitch_zombie in
        // _acc_boss_glitch). +acc_oc_glitch_per_tier per tier (default +25%/tier -> +125% at T5).
        if ( oc_tier > 0 && IS_TRUE( self.acc_is_glitch_zombie ) )
        {
            bonus_sum += 1.0 + ( oc_tier * getdvarfloat( "acc_oc_glitch_per_tier", ACC_OC_GLITCH_PER_TIER ) );
            n_applied++;
            b_modified = true;
        }

        // Double Tap 1.0 (docs/13_perks.md overhaul): fire-rate ONLY now - no
        // damage bonus. The former +3%/+6% damage layer was removed here.
        // Widow's Wine base: the former +50% frag damage was removed here too
        // (base Widow is now pure-stock web behavior). See docs/13.

        // Mega Flopper (PhD Slider, user 2026-06-18): +15% EXPLOSIVE damage
        // (grenades / projectiles / MOD_EXPLOSIVE). No weapon twin - this is a
        // damage-dealt scalar in the callback, not a weapon-GDT stat.
        if ( is_explosive_mod( meansofdeath )
             && acc_mega_bottles::has_active_mega_perk( attacker, "specialty_electriccherry" ) )
        {
            bonus_sum += ACC_MEGA_FLOPPER_EXPLOSIVE_MULT;
            n_applied++;
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
            bonus_sum += ACC_ABILITY_CRIT_MULT; // BONUS: added to the sum
            n_applied++;
            attacker.acc_ability_crit_shots -= 1;
            b_modified = true;
        }

        // Weapon ability: Slug Round (shotgun) - next shot 3x single-target.
        if ( IS_TRUE( attacker.acc_ability_slug_next ) && b_fire )
        {
            bonus_sum += ACC_ABILITY_SLUG_MULT; // BONUS: added to the sum
            n_applied++;
            attacker.acc_ability_slug_next = false;
            b_modified = true;
        }

        // Boss item: Kinetic Battery - next shot while charged deals 3x.
        // Consume the charge AND reset the kill counter (fields owned by
        // _acc_boss_items.gsc apply_kinetic_battery). The auto-aim half of
        // the item is Phase 4 (docs/20 battery-3x-autoaim-shot).
        if ( IS_TRUE( attacker.acc_item_battery_charged ) && b_fire )
        {
            bonus_sum += ACC_ITEM_BATTERY_DAMAGE_MULT; // BONUS: added to the sum
            n_applied++;
            attacker.acc_item_battery_charged = false;
            attacker.acc_item_battery_kill_count = 0;
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 3b) Glitch Stalker post-blink vulnerability window (target-side BONUS).
    //     The boss sets self.acc_glitch_vulnerable for a short window right after
    //     each teleport-blink (_acc_boss_glitch.gsc glitch_vulnerable_window); while
    //     set, all damage to it gets a bonus layer. Additive into bonus_sum so it
    //     STACKS with headshots (a head hit on a vulnerable boss = headshot + this).
    //     Applies to every damage source (not just player guns), default 2.0x, live.
    // -----------------------------------------------------------------------
    if ( IS_TRUE( self.acc_glitch_vulnerable ) )
    {
        bonus_sum += getdvarfloat( "acc_glitch_recovery_dmg_mult", 2.0 );
        n_applied++;
        b_modified = true;
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
         && hit_is_frontal( self, attacker, vdir ) )
    {
        // Shielded elite frontal armor: take 25% from the front. Countered by explosives / grenades
        // (not b_bullet/b_melee) and by flanking. The overclock no longer interacts with this - its
        // anti-armor role was replaced by Glitch Piercing (effect 2/3 above, vs glitch zombies).
        reduction = reduction * self.acc_elite_front_damage_resist; // REDUCTION
        b_modified = true;
    }

    // Single truncation at the end of the multiplicative chain; never let a
    // resisted hit floor to 0 (zombies must stay killable by chip damage).
    final_damage = damage;
    if ( b_modified )
    {
        // Bonus factor = literal SUM of applied bonuses (1.0 if none fired);
        // reduction stays multiplicative and applies AFTER the bonus sum.
        bonus_factor = 1.0;
        if ( n_applied > 0 ) bonus_factor = bonus_sum;

        final_damage = int( damage * bonus_factor * reduction );
        if ( final_damage < 1 ) final_damage = 1;

        /# acc_utility::log( "damage: " + damage + " -> " + final_damage +
                             " (bonus x" + bonus_factor + ", red x" + reduction + ")" ); #/
    }

    // -----------------------------------------------------------------------
    // 5) On-headshot KILL side effects (real bullet head hits that DROP the target - the bullet
    //    gate keeps chained AoE/DoDamage events from re-triggering these).
    //    KILL test (user 2026-06-21): the engine applies our returned damage AFTER this callback,
    //    so self.health is still the PRE-hit health here; final_damage >= self.health means this
    //    headshot is the killing blow. Gating on it = "headshot KILL", not just a headshot hit.
    // -----------------------------------------------------------------------
    if ( b_player_attacker && b_headshot && b_bullet && isdefined( self.health ) && final_damage >= self.health )
    {
        // Cyberware Weapon Overclock - effect 3/3: per-tier ammo refund on a HEADSHOT KILL (user 2026-06-21:
        // gated to KILLS, not every headshot hit). CHANCE scales with the gun's tier (acc_oc_adaptive_per_tier;
        // default +10%/tier -> 50% at T5).
        if ( oc_tier > 0 &&
             acc_utility::acc_rand_float() < ( oc_tier * getdvarfloat( "acc_oc_adaptive_per_tier", ACC_OC_ADAPTIVE_PER_TIER ) ) )
        {
            adaptive_aim_refund( attacker, weapon );
        }
    }

    // Record this hit for the 70/30 point-split system. We pass the FINAL
    // damage so a buffed hit counts for more toward the damage share too
    // (rewards players who aim even if they don't land the kill).
    if ( b_player_attacker )
    {
        self acc_points::record_damage( attacker, final_damage );
        // Crosshair damage number. This runs for EVERY player hit (headshots,
        // Double Tap'd / PaP'd / crit hits included) because it is BEFORE the
        // short-circuit return below - the whole reason the number must live
        // here and not in a second actor-damage callback (which never runs once
        // we return a modified value). final_damage is the true post-mult number.
        // Pass b_headshot so the crosshair number can tint teal on head hits.
        feed_dmg_number( attacker, final_damage, b_headshot );
    }

    if ( b_modified ) return final_damage;
    return -1;
}

// Flat per-weapon damage BALANCE (user, 2026-06-14). Substring match so one
// entry covers the gun's base, PaP (`_up`) and perk-twin variants (`_acc_*`).
// THESE RETURN LINES ARE THE SINGLE SOURCE OF TRUTH - tune here.
// Map design = HARD + heavily reward progress, so base guns are deliberately
// weak and PaP / Deadshot / Cyberware damage carry the scaling.
//
// TIER FRAMEWORK (user 2026-06-21): every gun's S/A/B/C tier is COMPUTED by the
// multi-factor "v2 sustain" scoring formula in docs/05_weapons.md "Gun Tier List"
// (DPS 30 / mobility 16 / sustain[=reload/clip,log] 18 / penetration 14 / reserve[log]
// 14 / handling 8). DPS here is just ONE input - a gun's tier also moves with its
// clip/reload (via tools/reduce_base_ammo.js), penetration, mobility, etc. Each return
// line is tagged [S]/[A]/[B]/[C] to match the doc table; recompute the formula after a change.
function acc_weapon_balance_mult( weapon_name )
{
    if ( IsSubStr( weapon_name, "t6_fiveseven" ) ) return 0.26;    // [C-] Five-Seven (start pistol): ~52 eff/shot. v2 tier model -> C- (5.5): mobile starter, fast reload + 14 clip = decent sustain, but weak damage + reserve cut to 56 lands it on the 5.6 B/C line (user 2026-06-21).
    if ( IsSubStr( weapon_name, "s1_asm1" ) )      return 0.21;     // [B] ASM1 (AW smg): ~401 DPS. v2 -> B (6.5): low DPS but fast reload + 22 clip + medium pierce = serviceable sustain (nerf clip/reload if you want it back to C).
    if ( IsSubStr( weapon_name, "s1_tac19" ) )     return 0.68;    // [A+] Tac-19 (AW energy SG): NERF -9% damage (was 0.75) + clip 4->3 / PaP 7->6 + reserve 48->27 (reduce_base_ammo). User 2026-06-21 cut the clip too -> dropped from low-S to A+ (~7.45). Still crowd-control king (headshot-excluded); vs bosses see ACC_SHOTGUN_BOSS_MULT. docs/05.
    if ( IsSubStr( weapon_name, "t6_olympia" ) )   return 0.9775;  // [C] Olympia (BO2 double-barrel SG): 110/pellet x ~8, 2 in mag + 3.9s reload. v2 -> C (4.8): worst sustain in the game (2-round clip). Headshot-excluded.
    if ( IsSubStr( weapon_name, "t6_ak47" ) )      return 0.186;   // [A] AK-47 (200@0.08 = 2500 raw): ~465 DPS. v2 -> A (6.7): solid DPS + decent effective reload. Focus Fire ability.
    if ( IsSubStr( weapon_name, "t6_galil" ) )     return 0.15;    // [B+] Galil (BO2 full-auto AR, 220@0.08 = 2750 raw): ~412 DPS (user 2026-06-21 -> B+, was 0.198/~545). DPS cut to land it at the top of B.
    if ( IsSubStr( weapon_name, "s1_ae4" ) )       return 0.31;    // [B] AE4 (AW energy AR, 160@0.12 = 1333 raw): ~413 DPS. Formula reads A- (6.8) but user-curated to B 2026-06-21 (mid DPS; fast reload + pierce + 25 clip + 200 reserve keep it top-B).
    if ( IsSubStr( weapon_name, "iw6_ripper" ) )   return 0.25;  // [A] Ripper (Ghosts convertible SMG<->AR); covers smg/ar x base/_up. Unique mechanic.
    // +6 box guns (user, 2026-06-15). Mults land each near the ~500 eff-DPS box band
    // (raw DPS = damage/fireTime from the Skye GDTs). IsSubStr covers base + PaP + twins.
    if ( IsSubStr( weapon_name, "s4_ppsh41" ) )    return 0.20;   // [A+] PPSH-41 (VG smg, 155@0.063 = 2460 raw): ~492 DPS (user 2026-06-21 -> A+, was 0.27/~664). DPS cut from S to the top of A. Massive clip (30/44) + high RoF keep its sustain.
    if ( IsSubStr( weapon_name, "t5_ak74u" ) )     return 0.23;   // [A] AK-74u (BO1 smg, 180@0.08 = 2250 raw): ~518 DPS. v2 -> A (7.4): fast, mobile, good sustain. Clip 20/reserve 160.
    if ( IsSubStr( weapon_name, "s1_pdw_rdw" ) || IsSubStr( weapon_name, "s1_pdw_ldw" ) ) return 0.33;  // [PaP bottom S] PDW akimbo PaP: SEPARATE higher mult (+50% over base) so the PACKED PDW jumps to bottom-S (akimbo double-fire + PaP ladder on top), like the M1911 split. Base stays C. user 2026-06-21; tune in playtest (akimbo damage stacks).
    if ( IsSubStr( weapon_name, "s1_pdw" ) )       return 0.22;   // [C base] PDW-57 (AW smg, 120@0.08 = 1500 raw): ~330 DPS (user 2026-06-21 -> C, was 0.33/~495). Hard DPS cut so the BASE roll is C; its value is the akimbo PaP (line above).
    if ( IsSubStr( weapon_name, "t9_nail_gun" ) )  return 0.37;    // [S] Nail Gun (CW projectile AR): ~589 DPS (UNCHANGED - user 2026-06-21 wanted S WITHOUT touching DPS). Reached S via non-DPS buffs: clip 30->40 + reload 2.6->2.0s (reduce_base_ammo.js CLIP_FIX/RELOAD_FIX), reserve ~280. PaP de-explosived. No twins.
    // M1911 PaPs to AKIMBO EXPLOSIVE (Mustang-and-Sally pattern): the _rdw/_ldw upgrade
    // forms are projectileweapons at 7000 direct dmg + splash. acc_weapon_balance_mult
    // scales ALL damage through on_ai_damage (incl. explosive), so the broad s2_m1911 x3.5
    // base buff would make the PaP ~24,500/shot. Give the explosive forms their own scale
    // ABOVE the base match: 7000 x 0.40 = 2800 direct (one-shots ~r20) + scaled splash - a
    // strong PaP nuke, not trivializing. First-pass; tune in playtest. (docs/33 Failure modes)
    if ( IsSubStr( weapon_name, "s2_m1911_rdw" ) || IsSubStr( weapon_name, "s2_m1911_ldw" ) ) return 0.35;  // [A packed] M1911 akimbo-explosive PaP: 7000 x 0.35 = 2450 direct (+ splash). NERF (user 2026-06-21, was 0.50). The gun's whole value is this PaP nuke.
    if ( IsSubStr( weapon_name, "s2_m1911" ) )     return 3.50;   // [C base] M1911 base (WWII semi-auto pistol): NERF (user 2026-06-21, was 4.375). MP-tuned at dmg 20 -> ~70 eff/shot. Weak until packed (see akimbo line above).
    // Paladin HB50 (t8_paladin_hb50): BO4 sniper, base dmg 1000 flat. The REAL "crazy strong"
    // cause (user, 2026-06-15) was the Skye rip's MP-inflated hit-location mults: locTorso 5.0
    // (PaP 9.0), limbs 4.0 (8.0), locHead 7.5 (10.0) - so at x1.0 even a BODY/limb shot one-shot
    // to ~r23 and a headshot to ~r33. FIX: the GDT's loc* mults were normalized to 1.0 install-side
    // (skye_t8_paladin_hb50.gdt, both base + _up entries; backup .acc-loc-orig; not repo-tracked -
    // re-apply on a fresh box, see docs/33). With loc=1.0 the gun obeys the additive model like
    // every other gun (body = base, headshot = our 2.0 map mult only), so x0.80 -> body r7 /
    // headshot r14 / HS+Deadshot r20, PaP+Cyberware push higher. A real sniper that FALLS OFF
    // without PaP. Tune the mult here (not the GDT) for further feel changes. Balance audit docs/33.
    if ( IsSubStr( weapon_name, "t8_paladin_hb50" ) ) return 0.70;  // [low S] Paladin HB50 (BO4 sniper): 700/shot, one-shots to ~r14. v2 -> low S (7.7, user 2026-06-21): clip 4->8 + scored on SINGLE-TARGET DPS (a one-shot boss-killer, not chaff) + large pierce. Has Precision Mode.
    if ( IsSubStr( weapon_name, "t6_m60" ) )       return 0.20;     // [S] M60 (Skye BO2 LMG, 290@0.1 = 2900 raw): ~580 DPS (user 2026-06-21: DPS DOWN from 0.24/~696, traded for clip/reserve). v2 -> S (7.9): clip 100 + reserve 400 + large pierce carry it; the 60->100 clip makes the 9.7s reload trivial per-round. Slow 0.8 move is its only weakness.
    if ( IsSubStr( weapon_name, "t6_rpd" ) )       return 0.10;     // [C] RPD (Skye BO2 LMG, 270@0.08 = 3375 raw): ~337 DPS (user 2026-06-21 -> C, was 0.13/~439). The "bad LMG" - low DPS on top of the 7.5s reload + 0.8 move. Clip 60/100, reserve 240/400.
    return 1.0;
}

// Push the crosshair damage number to `player` via the dev hook (set by
// _acc_dev when dev mode is on; undefined otherwise, so production shows
// nothing). Single chokepoint so every record_damage site feeds it the same way.
function feed_dmg_number( player, amount, is_headshot )
{
    if ( !isdefined( level.acc_dmg_num_feed ) ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;
    if ( !isdefined( amount ) || amount <= 0 ) return;
    player [[ level.acc_dmg_num_feed ]]( int( amount ), IS_TRUE( is_headshot ) );
}

// crit_chain_multiplier REMOVED 2026-06-14: the crit layers (map headshot mult,
// Deadshot/Mega, Cyberware Overload) are now ADDED directly into bonus_sum at the
// crit block in on_ai_damage (additive stacking) instead of multiplied together.
// resolve_headshot_multiplier (below) is still the source of the headshot value.

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
    w_base = acc_weapon_variants::true_base( w_weapon );   // twin-aware (strips _acc recoil suffix)
    if ( isdefined( w_base ) && isdefined( player.acc_oc_active[ w_base ] ) )
    {
        return player.acc_oc_active[ w_base ];
    }

    return undefined;
}

// Per-gun overclock TIER (0..5). Mirrors get_oc_flags' weapon -> base-weapon fallback so a tiered gun
// keeps its tier through Pack-a-Punch. Per-gun by design (user 2026-06-19): tracked on the held weapon
// in player.acc_weapon_progress (owned by _acc_overclocks).
function get_oc_tier( player, w_weapon )
{
    if ( !isdefined( player ) || !isdefined( w_weapon ) ) return 0;
    if ( !isdefined( player.acc_weapon_progress ) ) return 0;
    if ( isdefined( player.acc_weapon_progress[ w_weapon ] ) )
        return player.acc_weapon_progress[ w_weapon ].tier;
    w_base = acc_weapon_variants::true_base( w_weapon );
    if ( isdefined( w_base ) && isdefined( player.acc_weapon_progress[ w_base ] ) )
        return player.acc_weapon_progress[ w_base ].tier;
    return 0;
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

// Reactive Powder (overclock effect 4/4): deal n_fraction (= tier * acc_oc_aoe_per_tier) of the buffed
// headshot damage to every OTHER zombie near the impact. Threaded with a frame wait so
// the chained damage runs outside the actor-damage callstack; manual zombie
// iteration (instead of RadiusDamage) so the AoE can never splash players.
// Re-entry into on_ai_damage is safe: DoDamage events are not bullet MODs,
// so they can never re-trigger this AoE (or any bullet-gated proc).
// VERIFIED(acc): GetAITeamArray( "axis" ) returns the zombie AI array
// (zm_giant_cleanup_mgr.gsc:101; _zm.gsc:5491 uses level.zombie_team).
// VERIFIED(acc): ent DoDamage( damage, origin, attacker ) is stock
// (_destructible.gsc:264; AI-targeted 2-arg form zm_giant_teleporter.gsc:857).
function reactive_powder_aoe( e_attacker, e_victim, v_point, n_headshot_damage, n_fraction )
{
    wait( 0.05 ); // leave the damage callback's callstack first

    if ( !isdefined( e_attacker ) ) return;
    if ( !isdefined( v_point ) ) return;

    n_aoe = int( n_headshot_damage * n_fraction );   // fraction now scales with the gun's overclock tier
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

// Explosive = grenades + launched projectiles + MOD_EXPLOSIVE (the AoE family;
// excludes plain bullets). Used by the Mega Flopper +15% explosive-damage layer.
function is_explosive_mod( meansofdeath )
{
    if ( !isdefined( meansofdeath ) ) return false;
    if ( is_grenade_mod( meansofdeath ) ) return true;
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
    // Tac-19 (Skye AW import s1_tac19) is the "no headshot bonus, flat damage"
    // crowd-control gun (docs/05). Inert until the AW pack is installed.
    if ( name == "s1_tac19" ) return true;
    if ( name == "t6_olympia" ) return true;   // Olympia (BO2 SG): flat-damage crowd control like Tac-19 (2026-06-15)
    return false;
}

// Pellet shotguns: 8 pellets that all concentrate on a big single target, so their chaff-tuned
// damage stacks into a boss nuke. Used for the boss-damage cut (ACC_SHOTGUN_BOSS_MULT). Same set
// as the headshot-excluded list today, but kept separate so the two concerns can diverge later.
function is_pellet_shotgun( w_weapon )
{
    if ( !isdefined( w_weapon ) ) return false;
    name = weapon_root_name( w_weapon );
    if ( !isdefined( name ) ) return false;
    if ( name == "s1_tac19" )  return true;
    if ( name == "t6_olympia" ) return true;
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
    w_base = acc_weapon_variants::true_base( w_weapon );   // twin-aware (strips _acc recoil suffix)
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
        w_base = acc_weapon_variants::true_base( w );   // twin-aware (strips _acc recoil suffix)
        return w_base.name;
    }
    return name;
}
