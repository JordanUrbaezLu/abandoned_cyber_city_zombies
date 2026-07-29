// =============================================================================
// _acc_damage.gsc - damage interception hooks
//
// Design reference: docs/05_mechanics.md (Headshot Multiplier), docs/03
// (Cyberware), docs/04 (Overclocks + Weapon Abilities), docs/09 (Boss Items),
// docs/08 (Shielded elite frontal resist).
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
//    per docs/09_boss_items.md.
//  - Movement / reload / fire-rate Overclocks (Burst Coil, Overheat,
//    Subcritical, Spread Cone, Concussive, Reflow, Thermal Lock, Quick
//    Chamber) need weapon-fire/reload/aim hooks - Phase 4.
//
// MULTIPLIER STACKING - BONUSES ADD, REDUCTIONS MULTIPLY (2026-06-14, user rule:
// "if we have 3x and 2x that's 5x not 6x"). Two buckets, one int() truncation at
// the end. final_damage = int( damage * bonus_factor * reduction ) where:
//   - bonus_factor = the LITERAL SUM of every applied BONUS value (>1), or 1.0 if
//     none fired. So a 1.3x Deadshot + 1.3x Cyberware Overload = 2.6x, NOT 1.69x.
//   - reduction = the PRODUCT of every REDUCTION factor (<1), applied AFTER the
//     bonus sum (a 0.25x resist must cut, never add). ORDER NOW MATTERS.
//   0. incoming `damage` (already includes stock GDT headshot mult + PaP)
//   BONUSES (summed):
//     - REAL headshot loc-temper: NOT summed here - applied SEPARATELY as n_hs_temper
//         (multiplicative) = locHead x 0.5 reg / 0.8 boss = net 2.5x reg / 4x boss (user 2026-06-25; boss 0.6->0.8 2026-07-08).
//     - crit chain (crit hits only - real headshot, Precision Mode, Overload proc):
//       + Deadshot (1.3, or 1.5 with American Sniper Mega - no double dip)
//       + Cyberware Overload crit damage (acc_cw_crit_damage_mult, 1.30)
//     - PaP custom tier (1.25/1.55/1.90/2.30)
//     - Cyberware Amplifier (acc_cw_damage_mult, 1.15) - NOT on melee (Bowie excl.)
//     - Cyberware Weapon Overclock flat-damage layer (1 + tier*acc_oc_dmg_per_tier; +12%/tier, +60% at T5)
//     - one-shot consumables (reset their flag when applied): Precision Mode (4),
//       Slug Round (3), Kinetic Battery (3)
//   REDUCTIONS (multiplied, after the sum):
//     - per-gun balance cut (acc_weapon_balance_mult)
//     - shielded elite frontal resist (0.25 in the front 90-deg arc, bullets +
//       melee; bypassed by Piercing/Penetration/Breach + grenades, docs/08)
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
// Tuning - see docs/05_mechanics.md.
//
// Bonus multipliers apply AFTER the weapon-GDT hit-location mult is baked into the
// incoming `damage`, so effective head:body ratio = (gun locHead) x (our headshot bonus).
// ALL roster guns are locHead 5.0 (normalize_gun_loc convention), so the 0.5 reg / 0.8 boss bonus
// = 2.5x reg / 4x boss head. (FIXED 2026-06-26: the Paladin HB50 had been flattened to locHead 1.0
// by the OLD normalize_sniper_loc tool -> its headshot was 1.0 x 0.5 = 0.5x body = LESS than a body
// shot. Restored its GDT locHead/locHelmet to 5.0 in skye_t8_paladin_hb50.gdt so it's 2.5x like the rest.)
//
// GSC #defines are file-local (#using does not share macros - see the note at
// _acc_boss_items.gsc:41-45), so damage-side constants for other systems'
// effects live HERE because this is the file that applies them.
// ---------------------------------------------------------------------------

#define ACC_HEADSHOT_MULT      0.5    // map headshot BONUS, regular/elite. locHead 5.0 x 0.5 = 2.5x body (user 2026-06-25; 0.4=2x -> 0.5=2.5x).
#define ACC_BOSS_HEADSHOT_MULT 0.8    // bosses/mini-bosses. Effective head:body = gun locHead x this
                                      // (ALL roster guns locHead 5.0 -> 2.5x reg / 4x boss; Paladin restored to 5.0 on 2026-06-26). (user 2026-06-25 0.5=2.5x -> 0.6=3x; 2026-07-08 0.6 -> 0.8 = 4x boss.)

// GLOBAL player-damage buff (user 2026-06-23): a single across-the-board scalar that lifts EVERY
// gun's output uniformly while PRESERVING the per-gun balance tiers in acc_weapon_balance_mult.
// Applied as a flat FINAL multiply on ALL player damage in on_ai_damage (body, headshot, melee,
// explosive alike) - it sits OUTSIDE the bonus-sum and reduction buckets, after the chain. Live
// dvar acc_global_dmg_mult; 3.25 = +225%, 1.0 = off. This is the intended "buff all guns" knob.
// (user 2026-06-23: 1.20 -> 1.32 -> 1.50; user 2026-06-24: 1.50 -> 2.50, +67% over 1.50; user 2026-06-25: 2.50 -> 3.0 -> 2.75; user 2026-06-29: 2.75 -> 3.25.)
#define ACC_GLOBAL_DMG_MULT    3.25

// Deadshot layer (docs/10_perks.md): base perk +1.3 headshot, American Sniper Mega
// replaces it with +1.5 (no double dip; retuned 1.4->1.3 / 1.6->1.5 2026-06-25). These ADD into
// the bonus sum (not multiply) - see the stacking header. Recoil: base Deadshot now has
// NONE; Mega = -50% (single weapon-GDT twin tier, MEGA-gated, off the 2.1x base) - see
// docs/21/31 + docs/21. The recoil half is weapon-GDT (twin), not GSC.
#define ACC_DEADSHOT_MULT      1.3
#define ACC_DEADSHOT_MEGA_MULT 1.5

// Double Tap 2.0 damage temper (user 2026-06-25): base DT fires an engine-level EXTRA bullet (~2x dmg) we
// CANNOT remove in a usermap, so we cut the per-hit DAMAGE to net it down (the fire rate is left intact).
// 0.7 -> base DT lands ~1.86x DPS (2 bullets x 0.7 x 1.33 RoF). Live dvar acc_doubletap_dmg_mult. Applied
// ONLY to weapon_gets_dt_bullet() guns (an explicit ALLOW-LIST - never to a weapon that lacks the extra bullet).
// (user 2026-07-17: 0.6 -> 0.7, +damage buff - eased the extra-bullet temper, ~1.6x -> ~1.86x DPS.)
#define ACC_DOUBLETAP_DMG_MULT 0.7

// Mega Double Tap = "Gun Slinger" (REWORKED 2026-07-04). The old Mega effect was a fire-rate + weapon-swap
// twin ("fastfire"); that twin axis was REMOVED entirely (docs/10, docs/21). Mega Double Tap's ONLY benefit
// is now a DAMAGE buff: the extra-bullet temper EASES from x0.7 -> x0.9, so Mega DT lands ~2.39x DPS
// (2 bullets x 0.9 x 1.33 RoF) vs base DT's ~1.86x. Runtime-only (read live via has_mega_perk at damage time)
// so no weapon-variant twin is needed. Live dvar acc_doubletap_mega_dmg_mult.
// (user 2026-07-17: 0.8 -> 0.9, +damage buff to match the eased base DT temper.)
#define ACC_DOUBLETAP_MEGA_DMG_MULT 0.9

// Mega Flopper (PhD Slider): +15% explosive damage (user 2026-06-18, nerfed from +20%). ADDS
// into the bonus sum like every other layer (so +0.15 on the effective multiplier). GSC-only -
// a damage-dealt scalar here, NOT a weapon-GDT stat, so no twin weapon is needed.
#define ACC_MEGA_FLOPPER_EXPLOSIVE_MULT 1.15

// Plasma Generator + Warhead Bomber boss items (docs/09, user 2026-07-14): the old Nuclear Energy item
// (was +10% to explosive OR energy) was SPLIT into two separate implants so a player tunes energy and
// explosive independently:
//   * Plasma Generator (item 9)  -> +10% ENERGY-weapon damage   (attacker.acc_item_plasma, is_energy_weapon)
//   * Warhead Bomber  (item 13)  -> +20% EXPLOSIVE damage       (attacker.acc_item_warhead, is_explosive_mod)
// Each ADDS into the bonus sum like the Mega Flopper explosive layer. GSC-only - no weapon twins.
#define ACC_ITEM_PLASMA_MULT  1.10
#define ACC_ITEM_WARHEAD_MULT 1.20

// High Caliber Rounds boss item (docs/09, item 12, user 2026-07-14): +25% damage to BULLET hits while
// the item is implanted (attacker.acc_item_high_caliber, set by _acc_boss_items). The BULLET-gun
// counterpart to Nuclear's energy/explosive buff - the two cover DISJOINT weapon classes (High Caliber
// EXCLUDES energy weapons so a gun is boosted by exactly one item, never both), pushing build variety
// toward conventional bullet guns. ADDS into the bonus sum like every other layer. GSC-only - no twin.
#define ACC_ITEM_HIGH_CALIBER_MULT 1.25

// NOTE (docs/10_perks.md, 2026-06-14 overhaul): Double Tap is now "Double Tap 1.0"
// = fire-rate ONLY (no damage bonus), and Widow's Wine base no longer grants frag
// damage. Both former GSC damage layers were REMOVED here to match the spec.

// Weapon abilities (docs/04_weapons.md ability table).
#define ACC_ABILITY_CRIT_MULT  4.0
#define ACC_ABILITY_SLUG_MULT  3.0

// Pellet-shotgun vs BOSS cut (user 2026-06-21): a pellet shotgun (Tac-19/Olympia) is balanced for CHAFF -
// its 8 pellets spread across a crowd, each zombie eating ~1-2. Against a BOSS (one big hitbox) ALL pellets
// land on the same target, so its damage stacks ~8x into a boss nuke. Cut shotgun damage vs bosses/mini-
// bosses so it UNDER-performs there (the intended design, docs/04) while keeping its S-tier chaff clear.
// REDUCTION (multiplicative). Dvar-tunable: acc_shotgun_boss_mult.
#define ACC_SHOTGUN_BOSS_MULT  0.25

// Boss-nuke audit (user 2026-06-24, docs/04): the multi-hit "specials" that bypass the pellet cut and stack
// on a boss's single hitbox - the Thundergun CONE (multi-trace) and the Mahem rocket (direct + splash). Like
// the shotgun cut above, these REDUCE damage vs bosses/mini-bosses ONLY, so they stop nuking bosses (the
// ~200k Thundergun report) while keeping full chaff/clear power on regular zombies. Stacks on top of each
// gun's acc_weapon_balance_mult. Separate dvars: the Thundergun is the worst offender (no per-shot ammo
// cost), the launcher is ammo-limited so it gets a gentler cut, the Paladin is a single-shot sniper.
// Live: acc_thundergun_boss_mult / acc_launcher_boss_mult / acc_paladin_boss_mult.
// [2026-07-03] THUNDERGUN NOTE: ACC_THUNDERGUN_BOSS_MULT is now INERT twice over - (1) the BO1
// Thundergun port GDT ships "damage" "0" on BOTH forms, so the cone's weapon traces arrive as 0
// and die at on_ai_damage's damage<=0 gate before any multiplier; (2) bosses now take the
// FRACTIONAL blast system instead (thundergun_boss_blast below: maxhealth/divisor per blast,
// divisor 20 -3/PaP tier). Kept for the dvar surface + in case a future port restores GDT damage.
#define ACC_THUNDERGUN_BOSS_MULT 0.20   // INERT vs the BO1 port (GDT damage 0) - superseded for bosses by thundergun_boss_blast (maxhealth/22..12). Was: ~140k x 0.20 -> ~28k/blast.
#define ACC_LAUNCHER_BOSS_MULT   0.50   // Mahem vs bosses: ~5,512 direct (post -10%) x 0.50 -> ~2,756/rocket + splash; ammo-limited.
#define ACC_PALADIN_BOSS_MULT    0.50   // Paladin HB50 sniper vs bosses (user 2026-06-24): one-shot single-target boss-killer; ammo/RoF-limited (not a burst nuke) but reined in vs bosses too. On top of its 0.49 balance mult (B tier, user 2026-06-24) -> ~half its boss damage. Live dvar acc_paladin_boss_mult.

// EXPLOSIVE vs BOSS amplifier (user 2026-07-16): +50% explosive damage on bosses/mini-bosses. Applied as a
// TRUE MULTIPLICATIVE x1.5 in the reduction bucket (block 0c4) - the OPPOSITE direction of the boss-cuts
// above and, unlike an additive bonus_sum layer, a clean x1.5 of the FINAL explosive-vs-boss hit no matter
// how many other bonus layers fired. STACKS on the launcher boss-cut (a Mahem/War Machine rocket nets
// 0.50 x 1.5 = 0.75 of its uncut boss damage), and is still backstopped by the 10%/hit boss cap (4d) so it
// can never one-shot. "Explosive" is scoped EXACTLY as the Warhead Bomber gate (is_explosive_mod, minus
// energy weapons + the three unbuffed wonders). Live dvar acc_explosive_boss_mult (1.0 = off).
#define ACC_EXPLOSIVE_BOSS_MULT  1.5

// PER-BOSS WEAKNESS (user 2026-07-16): every heavyweight boss takes +20% damage from ONE signature
// weapon class - a light "use the right tool" nudge, not a hard counter:
//   Brutus (Trench Warden) <- SNIPERS       (weapon_is_sniper: MORS / Triple Take / MK14 / Paladin)
//   Panzer                 <- EXPLOSIVE + ENERGY (0c4's explosive scope + is_energy_weapon)
//   Rogue Protector        <- SHOTGUNS      (is_pellet_shotgun - stacks on the 0b pellet boss cut,
//                                            so 0.25 x 1.2 = 0.30: still cut, just 20% less so)
//   Avogadro               <- MELEE         (normal-chain melee; the Leviathan / Action Figure
//                                            fixed hits-to-kill paths value-return before the chain
//                                            by design, so their boss hit counts stay exact)
//   Phantom                <- SMGs + ARs    (weapon_is_smg / weapon_is_ar)
// Applied as a TRUE MULTIPLICATIVE x1.2 in the reduction bucket (block 0c5 - the 0c2/0c3/0c4
// amplification precedent), so it is a clean +20% of the final hit no matter how many other layers
// fired, and the 10%/hit boss cap (4d) still backstops it. Boss identity rides per-boss flags set at
// each boss's spawn chokepoint (acc_is_brutus / acc_is_panzer / acc_is_rogue_protector /
// acc_is_avogadro / acc_is_phantom). ONE shared knob - live dvar acc_boss_weakness_mult (1.0 = off).
#define ACC_BOSS_WEAKNESS_MULT   1.2

// BOSS-DAMAGE HARD CAP (user 2026-06-24, boss-nuke audit): the catch-all backstop. The weapon-name boss cuts
// above CANNOT see weaponless scripted DoDamage (the stock Thundergun fling does DoDamage(self.health+666) -
// the REAL ~200k one-shot - and the octobomb pull does DoDamage(target.health)), and even for weapon hits a
// multiplicative cut is defeated by PaP/Cyberware/Overclock investment + the insta-kill x6. So a FINAL clamp:
// a single player hit on a boss/mini-boss caps at this fraction of its maxhealth, AFTER every multiplier.
#define ACC_BOSS_PER_HIT_CAP_PCT 0.10   // 10% of boss maxhealth/hit -> >=10 hits to kill any boss. Live dvar acc_boss_per_hit_cap_pct (0 = off).
// LEVIATHAN AXE boss specialty (user 2026-07-07): the GoW axe is the premier boss-killer melee. Its per-hit
// boss cap = 1/(hits-to-kill), so it kills ANY boss in a fixed number of hits regardless of boss HP, and each
// PaP TIER lands harder (fewer hits): base 24 / T1 20 / T2 18 / T3 14. Live dvars acc_leviathan_hits_t0..t3.
// [acc] user 2026-07-09 ~+20% DAMAGE BUFF: hit counts cut ~1/1.2 from 20/17/14/10 (shielded 5 -> 4 too;
// normal zombies were already 1-hit, so the buff lands on the boss/elite counts).
// [acc] user 2026-07-17 ~-15% BOSS nerf: hit counts raised ~1/0.85 from 17/14/12/8 (BOSS table only -
// the zombie/glitch/shielded/Fury counts are untouched; this mostly walks back the 2026-07-09 buff).
// [acc] user 2026-07-17 (2nd pass) ANOTHER ~10% BOSS nerf: 20/16/14/9 -> 22/18/16/10 (~1/0.9; BOSS table
// only - still felt too strong on bosses; the zombie/glitch/shielded/Fury one-hit path stays untouched).
// [acc] user 2026-07-18 T3 "10-hit boss slayer" REMOVED: the T3 outlier jump (16 -> 10) is gone - T3 now
// continues the ladder (14), THEN the all-wonder ~10% nerf raised every tier ~1/0.9: 22/18/16/14 ->
// 24/20/18/16. The zombie/glitch/shielded/Fury counts are untouched (a x1.1 nerf rounds back to the
// same small integers: 4->4, 2->2, 1->1).
// [acc] user 2026-07-18 (2nd pass) T3 16 -> 14: a slightly sharper max-PaP payoff, still no slayer jump.
#define ACC_LEVIATHAN_HITS_T0 24   // unpacked
#define ACC_LEVIATHAN_HITS_T1 20
#define ACC_LEVIATHAN_HITS_T2 18
#define ACC_LEVIATHAN_HITS_T3 14   // max PaP (no slayer jump - ladder stays near-linear)
// INSTA-KILL vs bosses = exactly THIS multiple of a normal hit (user 2026-06-25: "2x not 6x"). Applied BOTH as
// the damage multiplier AND as a cap scale (x2 cap), so a high-damage gun (Mahem/sniper) that's already at the
// 10% cap deals 2x10%=20% during insta-kill = a true 2x, not the 6x that the 10% cap was silently clamping to 4k.
// Live dvar acc_instakill_boss_mult.
#define ACC_INSTAKILL_BOSS_MULT 2

// Kinetic Battery next-shot multiplier (docs/09_boss_items.md; tuning lever:
// drop to 2x if Battery feels runaway). Charge ACCRUAL is not this file's
// job - see docs/15 battery-charge-per-10-kills.
#define ACC_ITEM_BATTERY_DAMAGE_MULT 3.0

// Berzerker blood-tax FLOOR (user 2026-07-15): the tax stops at this fraction of MAX HP - at/below it the
// carrier keeps the +35% swing speed and pays nothing. This is the value you sit at while cleaving a crowd
// (the tax is real damage, so it holds the regen timer down for as long as you keep connecting), which is
// why it must stay well clear of a one-tap. REPLACED the old 1-HP floor, which converged on 1 HP and pinned
// you there with no regen = the self-kill bug. See berzerker_melee_tax(). Live dvar acc_berzerker_hp_floor_frac.
#define ACC_BRZ_TAX_FLOOR_FRAC 0.50

// Cyberware Weapon Overclock (user 2026-06-19; T10 2026-06-24): each TIER (1..10) gives a SMALL boost to ALL
// FOUR effects at once - magnitudes scale with the gun's tier. PER-GUN. The tier multiplies the live oc_tier
// directly (NO clamp), so the 10-tier extension scales these automatically:
//   1 Flat damage    : +acc_oc_dmg_per_tier per tier     (default 0.12 -> +120% at T10, ALWAYS on, gun hits; user 2026-07-08: 0.10 -> 0.12)
//   2 Glitch Piercing : +acc_oc_glitch_per_tier per tier  (default 0.15 -> +150% at T10 vs GLITCH zombies; user 2026-07-08: 0.25 -> 0.15)
//   3 Ammo refund    : +acc_oc_adaptive_per_tier per tier (default 0.05 -> 50% refund chance at T10) on a HEADSHOT KILL (user 2026-07-08: 0.10 -> 0.05)
//   4 Shield Piercing : +acc_oc_pierce_per_tier per tier  (default 0.04 -> pierce 0.40 at T10; PARTIALLY restores the
//                       Riot's blocked frontal damage - front takes 25% at T0 .. 40% at T5 .. 55% at T10, NEVER a
//                       full bypass, user 2026-06-25; per-tier 0.05 -> 0.04 user 2026-07-08).
#define ACC_OC_DMG_PER_TIER            0.12
#define ACC_OC_GLITCH_PER_TIER         0.15
#define ACC_OC_ADAPTIVE_PER_TIER       0.05
#define ACC_OC_PIERCE_PER_TIER         0.04
#define ACC_OC_REACTIVE_AOE_RADIUS     128   // legacy: reactive_powder_aoe kept but no longer wired

// Shielded elite: "front quarter" = front 90-degree arc = within 45 degrees
// of facing; cos(45 deg) = 0.7071 (docs/08_enemies.md, docs/15 :529).
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

    // THUNDERGUN FRACTIONAL BOSS DAMAGE (user 2026-07-03 design): expose the blast helper as a
    // level pointer (vendored boss files call it without a #using) + keep boss-flagged AIs
    // carrying the fling hook. See thundergun_boss_blast below.
    level.acc_tg_boss_blast = &thundergun_boss_blast;
    level thread tg_boss_fling_assigner();

    // Insta-Kill on NON-REGULAR enemies (bosses/elites/Glitch Stalker/Brutus) = 6x gun damage, NOT an
    // instant kill (user 2026-06-23). This stock global hook (zm_powerups::check_for_instakill) returns
    // FALSE for them so the gib+lethal is skipped (on_ai_damage applies the 6x instead); regular zombies
    // are still one-shot. See acc_instakill_override + is_non_regular below.
    level.check_for_instakill_override = &acc_instakill_override;

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

// =============================================================================
// THUNDERGUN vs BOSSES - FRACTIONAL blast damage (user 2026-07-03 design; supersedes the
// ACC_THUNDERGUN_BOSS_MULT cone cut AND the per-hit caps for this one path).
//
//   per blast: damage = ceil( boss MAXHEALTH / divisor ), divisor 20 - 3x PaP tier:
//     tier 0 (base)        -> 1/20 = 5.0%      tier 1 (first pack) -> 1/17 = ~5.9%
//     tier 2 (_up form)    -> 1/14 = ~7.1%     tier 3 (max)        -> 1/11 = ~9.1%
//
// WHY THE FLING HOOK (mechanism evidence): the BO1 Thundergun port GDT ships "damage" "0"
// on BOTH forms, so the cone's weapon traces arrive as 0 and die at on_ai_damage's first
// line (damage <= 0 -> -1) - the multiplier chain NEVER sees a thundergun weapon hit. The
// stock cone code, however, ALWAYS calls self.thundergun_fling_func( player ) on every AI
// it hits when that field is defined (_zm_weap_thundergun.gsc:248-251), independent of GDT
// damage - the deterministic per-blast-per-AI hook, already proven by the Brutus + Avogadro
// overrides. TRASH zombies are untouched: the hook is only installed on boss-flagged AIs,
// so the stock weaponless fling one-shot (launchRagdoll + DoDamage health+666) still clears
// regular zombies exactly as before.
//
// Coverage: tg_boss_fling_assigner() installs the hook on every AI flagged acc_is_boss /
// acc_is_mini_boss by the boss framework (Phantom, Glitch bosses, Trench Warden, Paradise
// spawns, and any future boss using the markers - no per-boss file edits). Exclusions,
// mirroring the other maxhealth-fraction systems in this file: acc_is_glitch_zombie
// (the lightweight Glitch Stalker keeps the stock fling). AIs that already own a
// thundergun_fling_func keep it: Brutus's (nsz_brutus.gsc) now routes HERE via
// level.acc_tg_boss_blast; the Avogadro's is a deliberate DoDamage(0) thundergun-immunity
// (electric boss) and is intentionally preserved.
// =============================================================================
function thundergun_boss_blast( player )   // self = the boss AI (stock fling-func convention)
{
    if ( !isdefined( self ) || !IsAlive( self ) ) return;
    if ( !isdefined( player ) || !isplayer( player ) ) return;

    // ONE application per blast: the cone multi-traces / can re-enter within the same shot,
    // so debounce per (boss, attacker) - a blast is a single trigger pull; 500ms is well under the
    // RoF. [acc] 2026-07-06 sweep: was keyed per BOSS only, so two players co-firing Thunderguns at
    // the same boss within 500ms silently swallowed the second blast (GDT damage is 0 - the gate WAS
    // the damage). Keyed per attacker entity number now; the same player's multi-trace re-entry is
    // still deduped.
    pn = player GetEntityNumber();
    if ( !isdefined( self.acc_tg_blast_gate ) ) self.acc_tg_blast_gate = [];
    if ( isdefined( self.acc_tg_blast_gate[ pn ] ) && GetTime() < self.acc_tg_blast_gate[ pn ] ) return;
    self.acc_tg_blast_gate[ pn ] = GetTime() + 500;

    // divisor from the HELD thundergun's PaP tier (the ladder the 2026-07-02 tier-3 fix opened):
    // 22 / 19 / 16 / 12 by tier. [acc] user 2026-07-18 all-wonder ~10% nerf: was 20/17/14/11
    // (divisor / 0.9, rounded) - MORE blasts per boss kill, trash fling untouched (already a one-shot).
    tier = 0;
    w = player GetCurrentWeapon();
    if ( isdefined( w ) && w != level.weaponNone && isdefined( w.name ) && IsSubStr( w.name, "thundergun" ) )
        tier = acc_pap_levels::get_tier( player, w );
    if ( tier < 0 ) tier = 0;
    if ( tier > 3 ) tier = 3;
    divisor = ( tier == 0 ? 22 : ( tier == 1 ? 19 : ( tier == 2 ? 16 : 12 ) ) );

    if ( !isdefined( self.maxhealth ) || self.maxhealth <= 0 )
    {
        self DoDamage( 5000, self.origin, player );   // no maxhealth to fraction - old flat fallback
        return;
    }

    dmg = int( self.maxhealth / divisor );
    if ( ( dmg * divisor ) < self.maxhealth ) dmg++;   // ceil()
    if ( dmg < 1 ) dmg = 1;

    // Mark the boss so on_ai_damage returns this EXACT value (bypasses multipliers + caps -
    // see the consume block there), then deal it through DoDamage so death/HP-bar/point flows
    // all run normally (bars read self.health, which DoDamage updates).
    self.acc_tg_exact_dmg = dmg;
    self DoDamage( dmg, self.origin, player );

    /# println( "[acc] tg boss blast: tier " + tier + " divisor " + divisor + " dmg " + dmg + " / max " + self.maxhealth ); #/
}

// Keep every boss-flagged AI carrying the fling hook (bosses spawn at many points in many
// modules; polling the marker decouples us from all of them - incl. bosses added later).
function tg_boss_fling_assigner()
{
    level endon( "end_game" );
    for ( ;; )
    {
        ais = GetAITeamArray( "axis" );
        foreach ( ai in ais )
        {
            if ( !isdefined( ai ) ) continue;
            if ( !IS_TRUE( ai.acc_is_boss ) && !IS_TRUE( ai.acc_is_mini_boss ) ) continue;
            if ( IS_TRUE( ai.acc_is_glitch_zombie ) ) continue;      // Stalker: stock fling (see header)
            if ( isdefined( ai.thundergun_fling_func ) ) continue;   // Brutus/Avogadro own theirs
            ai.thundergun_fling_func = &thundergun_boss_blast;
        }
        wait 0.5;
    }
}

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
        // [acc] CONSUME the Thundergun exact-damage mark here too: this gate runs BEFORE the one-shot
        // consume block below, so a rim shooter's Thundergun (set the mark then DoDamage) would be
        // zeroed here WITHOUT clearing the mark - leaving it to be ridden by the NEXT hit (an in-trench
        // knife/pistol round returned verbatim as 5-9% of boss maxhealth, defeating the commit-to-the-
        // trench fight). Clear it so the mark never outlives the hit that set it.
        self.acc_tg_exact_dmg = undefined;
        return 0;
    }

    if ( !is_applicable_target( self ) ) return -1;

    // THUNDERGUN FRACTIONAL BOSS BLAST (user 2026-07-03; see thundergun_boss_blast below): the
    // fling hook already computed the EXACT damage (boss maxhealth / tier divisor) and marked it
    // on the boss just before its DoDamage. Return it VERBATIM - for this one path the fractional
    // system REPLACES every multiplier AND the boss per-hit cap (documented precedence; the trench
    // Warden gate above still outranks it, and god mode / Mega-EC boss-special immunity are
    // PLAYER-damage paths this never touches). One-shot consume so no other hit can ride the mark.
    if ( isdefined( self.acc_tg_exact_dmg ) )
    {
        n_tg = self.acc_tg_exact_dmg;
        self.acc_tg_exact_dmg = undefined;
        if ( isdefined( attacker ) && isplayer( attacker ) )
        {
            self acc_points::record_damage( attacker, n_tg );
            feed_dmg_number( attacker, n_tg, false );
        }
        return n_tg;
    }

    // LEVIATHAN AXE - PER-ENEMY hits-to-kill (user 2026-07-07). The axe has NO fixed damage number: each hit
    // deals a FRACTION of the target's MAX health so it dies in exactly N hits, CONFIGURED PER ENEMY TYPE:
    //   normal zombie 1 (a one-hit knife) · glitch zombie 1 · shielded 4 · Apothicon Fury 2 · heavyweight
    //   boss 24/20/18/14 by PaP tier (user 2026-07-18: T3 10-hit slayer removed + all-wonder ~10% nerf,
    //   then T3 16 -> 14; was 22/18/16/10). The anti-elite counts
    //   SHARPEN at 2nd PaP and beyond (tier>=2): shielded 4->2 and Apothicon Fury 2->1 (one-shot).
    //   REPLACES the normal multiplier chain AND the boss per-hit cap
    //   for this weapon (mirrors the Thundergun fractional path above). All live dvars acc_leviathan_hits_*.
    // Resolve the axe by the DAMAGE weapon OR the attacker's HELD weapon. A fireType-Melee weapon's swing
    // does NOT reliably report itself as the damage-event `weapon` (the Action Figure needs two names for the
    // same reason; the Thundergun reads GetCurrentWeapon for its tier) - so the plain weapon.name check missed
    // every swing and bosses fell through to the normal scaled path (~130 hits on Avogadro instead of 20). Since
    // the Leviathan is melee-only, any player-attributed MELEE hit while it is in hand IS an axe swing. The
    // held-weapon fallback MUST be melee-gated: offhands never change GetCurrentWeapon, so without the MoD check
    // a frag/Widow's Wine thrown while holding the axe was rewritten to fractional axe damage (one-shot every
    // zombie in the blast, ~5%/frag on bosses, bypassing the whole multiplier chain). Review fix 2026-07-08.
    lev_weapon = undefined;
    if ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "leviathan" ) )
        lev_weapon = weapon;
    else if ( is_melee_mod( meansofdeath ) && isdefined( attacker ) && isplayer( attacker ) )
    {
        lev_held = attacker GetCurrentWeapon();
        if ( isdefined( lev_held ) && lev_held != level.weaponNone && isdefined( lev_held.name ) && IsSubStr( lev_held.name, "leviathan" ) )
            lev_weapon = lev_held;
    }
    if ( isdefined( lev_weapon ) && isdefined( attacker ) && isplayer( attacker ) )
    {
        lev_tier = acc_pap_levels::get_tier( attacker, lev_weapon );
        b_lev_pap2 = ( lev_tier >= 2 );   // 2nd PaP and beyond upgrades the anti-elite hit counts
        if ( IS_TRUE( self.acc_is_glitch_zombie ) )         lev_hits = getdvarint( "acc_leviathan_hits_glitch", 1 );
        else if ( IS_TRUE( self.acc_is_shielded ) )
        {
            // shielded: 5 hits base -> 2nd PaP and beyond drops to 2
            if ( b_lev_pap2 ) lev_hits = getdvarint( "acc_leviathan_hits_shield_pap2", 2 );
            else              lev_hits = getdvarint( "acc_leviathan_hits_shield", 4 );   // 5 -> 4 (user 2026-07-09 +20% buff)
        }
        else if ( IS_TRUE( self.b_is_apothicon_fury ) )
        {
            // Apothicon Fury: 2 hits base -> 2nd PaP and beyond one-shots it
            if ( b_lev_pap2 ) lev_hits = getdvarint( "acc_leviathan_hits_fury_pap2", 1 );
            else              lev_hits = getdvarint( "acc_leviathan_hits_fury", 2 );
        }
        else if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
        {
            if ( lev_tier >= 3 )      lev_hits = getdvarint( "acc_leviathan_hits_t3", ACC_LEVIATHAN_HITS_T3 );
            else if ( lev_tier == 2 ) lev_hits = getdvarint( "acc_leviathan_hits_t2", ACC_LEVIATHAN_HITS_T2 );
            else if ( lev_tier == 1 ) lev_hits = getdvarint( "acc_leviathan_hits_t1", ACC_LEVIATHAN_HITS_T1 );
            else                      lev_hits = getdvarint( "acc_leviathan_hits_t0", ACC_LEVIATHAN_HITS_T0 );
        }
        else                                                lev_hits = getdvarint( "acc_leviathan_hits_zombie", 1 );
        if ( lev_hits < 1 ) lev_hits = 1;
        lev_ref = ( isdefined( self.maxhealth ) && self.maxhealth > 0 ? self.maxhealth : ( isdefined( self.health ) ? self.health : 1 ) );
        lev_dmg = int( lev_ref / lev_hits ) + 1;   // +1 => exactly N hits always finishes (ceil)
        if ( lev_dmg < 1 ) lev_dmg = 1;
        self acc_points::record_damage( attacker, lev_dmg );
        feed_dmg_number( attacker, lev_dmg, false );
        // Berzerker blood tax MUST be charged here: the axe's fractional path value-returns below and
        // never reaches the general melee tax block (~40 lines down), so without this the Leviathan was
        // the ONE Berzerker melee surface that swung faster but never paid the 5% HP tax (review fix,
        // user 2026-07-14). Same debounce as the general path (berzerker_try_tax).
        berzerker_try_tax( attacker, lev_weapon );
        return lev_dmg;
    }

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

    // NOTE (docs/10_perks.md, 2026-06-14 overhaul): the Spiderman Mega no longer
    // grants melee/web-grenade ONE-HIT kills. Spiderman is now "hold 6 web
    // grenades + restock 4/round" (handled in _acc_mega_bottles). Those two OHK
    // short-circuit blocks were REMOVED here to match the spec.

    b_player_attacker = isdefined( attacker ) && isplayer( attacker );
    b_melee  = is_melee_mod( meansofdeath );
    b_bullet = is_bullet_mod( meansofdeath );
    b_fire   = is_weapon_fire_mod( meansofdeath );

    // -----------------------------------------------------------------------
    // BERZERKER melee blood tax (boss item 11, user 2026-07-11): while implanted, every melee that
    // CONNECTS on one of the item's three surfaces (berzerker knife bash / Leviathan Axe / Action
    // Figure - berzerker_melee_weapon) costs the attacker 5% of MAX HP as REAL self-damage (2-arg
    // DoDamage = undefined attacker + MOD_UNKNOWN, the proven self-damage recipe - dodges both the
    // stock self-attacker MOD whitelist zero-out AND PhD; being real damage it resets the engine
    // HP-regen timer, the user's explicit spec). Debounced per SWING, not per victim (150ms, under the
    // fastest swing cycle AF fast3+brz ~194ms) - one cleave multi-hits several zombies in a frame and
    // taxes ONCE. This general block covers the knife bash / Action Figure / Ballistic stab (all of which
    // fall through to here); the Leviathan Axe value-returns above and charges the SAME helper at its own
    // return site. Placed BEFORE the riot deflect / AF one-knife early returns so every connecting swing pays.
    // -----------------------------------------------------------------------
    if ( b_player_attacker && b_melee )
        berzerker_try_tax( attacker, weapon );

    // -----------------------------------------------------------------------
    // PhD SLIDER nova bypass (user 2026-06-27). _acc_perk_phd_flopper::phd_explode deals self-dealt
    // MOD_GRENADE_SPLASH hits tagged attacker.acc_phd_nova_hit, with the incoming `damage` already FROZEN at a
    // round-18 normal-zombie's health (so one slide one-shots trash through r18, then 2/3 slides past it).
    // Deal it RAW - skip the global x2.75 AND the whole bonus chain: those would re-inflate the frozen value
    // ~3x (+ Mega Flopper's own +15% explosive) and one-shot far past the freeze round, re-creating the boss
    // nuke this nerf removes. Still honour the boss per-hit cap (defensive; the frozen value is normally well
    // under it) and feed the crosshair number / 70-30 point split, matching the end-of-function path. The
    // value-return short-circuits the rest of the chain (_zm.gsc:5825-5829).
    // -----------------------------------------------------------------------
    if ( b_player_attacker && IS_TRUE( attacker.acc_phd_nova_hit ) )
    {
        n_phd = damage;
        if ( ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
             && !IS_TRUE( self.acc_is_glitch_zombie )
             && isdefined( self.maxhealth ) && self.maxhealth > 0 )
        {
            cap_pct = getdvarfloat( "acc_boss_per_hit_cap_pct", ACC_BOSS_PER_HIT_CAP_PCT );
            if ( cap_pct > 0 )
            {
                n_cap = int( self.maxhealth * cap_pct );
                if ( n_cap >= 1 && n_phd > n_cap ) n_phd = n_cap;
            }
        }
        self acc_points::record_damage( attacker, n_phd );
        feed_dmg_number( attacker, n_phd, false );
        return n_phd;
    }

    // RIOT (Shielded) elites are IMMUNE to melee/knife - the bowie, the bash, AND the Action Figure (user
    // 2026-06-27). Knife one and it just DEFLECTS off the shield (0 damage); you must shoot or explode them.
    // SFX = zmb_rocketshield_imp (the impact sound of the rocket-shield plate the Shielded elite wears),
    // debounced so a fast figure swing can't spam it. Bullets/explosives still hurt them (b_melee only).
    if ( b_player_attacker && IS_TRUE( self.acc_is_shielded )
         && ( b_melee || is_action_figure_weapon( weapon ) ) )
    {
        if ( !isdefined( self.acc_riot_knife_cd ) || GetTime() >= self.acc_riot_knife_cd )
        {
            self.acc_riot_knife_cd = GetTime() + 250;
            PlaySoundAtPosition( "zmb_rocketshield_imp", self.origin );
        }
        return 0;
    }

    // Mega Widow's Wine NO LONGER grants a one-knife (user 2026-06-29: "Remove the 1 hit knife from Mega Widow's
    // Wine"). A Mega Widow's holder's melee now falls through to the normal melee damage chain below - its
    // remaining Mega effects are the boosted web-grenade behavior + the higher spider-drop rate (_acc_mega_bottles).
    // (Was: ONE-KNIFE on regular zombies via has_active_mega_perk("specialty_widowswine"), gated off bosses/elites;
    //  added 2026-06-18, removed 2026-06-29.)

    // ACTION FIGURE melee (covers the base figure + its faster PaP "speed twins" - is_action_figure_weapon):
    //   - REGULAR zombies: ALWAYS one-knife (every swing, any round; returns health+1000).
    //   - BOSSES + mini-bosses (NOT the lightweight Glitch Stalker): a FLAT 1/30 of MAX health per hit, so it
    //     takes a CONSISTENT ~30 swings to kill ANY boss regardless of HP (user 2026-06-27). Bypasses the tiny
    //     baked melee + the global x2.5 + the 10% per-hit cap (1/30 = 3.3% is well under it). Dvar
    //     acc_af_boss_hits (30 = hits-to-kill). Glitch Stalker excluded (same as the boss cap below) -> normal melee.
    //   - ELITES (Riot shields): fall through to normal melee (no one-knife, no 1/30).
    // (The old per-PaP-tier CLEAVE / multi-hit was REMOVED 2026-06-27; PaP scales SWING SPEED via faster twins.)
    if ( b_player_attacker && is_action_figure_weapon( weapon ) )
    {
        if ( ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
             && !IS_TRUE( self.acc_is_glitch_zombie )
             && isdefined( self.maxhealth ) && self.maxhealth > 0 )
        {
            n = getdvarint( "acc_af_boss_hits", 33 );   // USER 2026-07-11 -10% vs bosses (30 -> 33 hits) + swing 10% slower (GDT melee timing x1.1)
            if ( n < 1 ) n = 1;
            dmg = int( self.maxhealth / n );                    // 1/33 of MAX health -> 33 hits to kill, any boss (was 1/30)
            if ( dmg < 1 ) dmg = 1;
            self acc_points::record_damage( attacker, dmg );    // co-op assist credit (audit 2026-07-12: this early return skipped the end-chain record at :1201, losing the AF hitter's share when a teammate lands the kill)
            feed_dmg_number( attacker, dmg, false );
            return dmg;
        }
        // [acc] 2026-07-11 review hardening: also exclude STOCK-flagged bosses (self.is_boss) - Brutus/
        // Rogue Protector carry only the stock flag during their spawn window before the acc promotion
        // lands (the is_non_regular() precedent); without this the figure one-knifed them in that window.
        if ( !is_boss_or_elite( self ) && !IS_TRUE( self.is_boss ) )   // regular zombie -> always one-knife
        {
            // RETURN before the function-end damage-number feed, so feed it here (user 2026-06-23: "knife a
            // zombie and not see the damage").
            if ( isdefined( self.health ) ) feed_dmg_number( attacker, self.health, false );
            return self.health + 1000;
        }
        // else: an ELITE -> fall through to normal melee handling below.
    }

    // -----------------------------------------------------------------------
    // BALLISTIC KNIFE (user 2026-07-11): the thrown knife_ballistic / knife_ballistic_upgraded projectile.
    //   (a) SHIELDED (Riot) elites -> DEFLECTS (0 dmg + clang), same as melee/Action Figure (spec: "no damage
    //       to shielded zombies"). Returns BEFORE the OC shield-pierce layer, so even a maxed pierce knife can
    //       NEVER hurt a Riot - intended.
    //   (b) GLITCH zombies (incl. the Glitch Stalker mini-boss) -> ONE-HIT any round (user 2026-07-11,
    //       Leviathan-consistent glitch counter - deliberately NOT round-gated). REGULAR zombies ->
    //       ONE-HIT only through a ROUND GATE (user 2026-07-12 "shouldn't be doing one hit the whole
    //       game"): base knife <= acc_bk_onehit_round (12), PaP form <= acc_bk_onehit_round_pap (24);
    //       past its gate the knife falls through to the normal scaled chain (the 0c3 stab x2 / throw
    //       x6 mults + the Exo melee layer keep it a strong knife, no longer an auto-delete).
    //   (c) BOSSES / mini-bosses (non-glitch) / non-glitch elites / Apothicon Fury -> EXCLUDED: fall through to
    //       the normal scaled chain + the 10% ACC_BOSS_PER_HIT_CAP_PCT per-hit cap = capped chip, never a delete.
    // Matched by is_ballistic_knife_weapon (name substring - the pack GDT ships isBallisticKnife "0", see the
    // helper) - covers base + PaP + the Berzerker _acc_brz twins with no MoD dependency. THE STAB TOO (user
    // 2026-07-11 "its knife should do more damage"): the knife's own MELEE stab (meleeAnim/meleeDamage in the
    // GDT) gets the same one-hit/deflect rules via a melee-gated HELD-weapon fallback - stock attributes a
    // ballistic stab to the knife itself (_zm_spawner.gsc:1619 keys ballistic_knife_death on MOD_MELEE), but if
    // it ever arrives as the melee-slot def instead (the Leviathan self-report lesson), the held check catches
    // it. Melee-gated so a thrown-then-switched gun can never misattribute. The base knife has only 4 throws
    // (PaP 9) + heavy retrieval friction, so the EARLY-ROUND guaranteed one-hit is its identity vs the Action
    // Figure's infinite melee (round-gated 2026-07-12); PaP's headline is the tier-2 Krauss revive
    // (_zm_weap_ballistic_knife.gsc). Spike: docs/04_weapons.md.
    // -----------------------------------------------------------------------
    bk_name = "";   // the matched knife def's name (PaP detection for the one-hit round gate below)
    b_bk_hit = is_ballistic_knife_weapon( weapon );
    if ( b_bk_hit )
    {
        bk_name = weapon.name;
    }
    else if ( b_melee && b_player_attacker )
    {
        bk_held = attacker GetCurrentWeapon();
        if ( isdefined( bk_held ) && bk_held != level.weaponNone
             && isdefined( bk_held.name ) && IsSubStr( bk_held.name, "knife_ballistic" ) )
        {
            b_bk_hit = true;   // stab attributed to the melee-slot def -> still the knife's melee
            bk_name = bk_held.name;
        }
    }
    if ( b_player_attacker && b_bk_hit )
    {
        // (a) Shielded deflect (mirror the Riot melee block above; reuse the debounce field).
        if ( IS_TRUE( self.acc_is_shielded ) )
        {
            if ( !isdefined( self.acc_riot_knife_cd ) || GetTime() >= self.acc_riot_knife_cd )
            {
                self.acc_riot_knife_cd = GetTime() + 250;
                PlaySoundAtPosition( "zmb_rocketshield_imp", self.origin );
            }
            return 0;
        }
        // (b) One-hit regular + glitch (glitch-first -> includes the Glitch Stalker). Bosses / non-glitch
        //     elites / Fury fall through to the capped-chip chain below. ALSO excludes stock-flagged
        //     bosses (!self.is_boss): Brutus/Rogue Protector set stock is_boss during their spawn window
        //     BEFORE the acc_is_mini_boss promotion lands (the is_non_regular() precedent at the bottom of
        //     this file) - without this a knife thrown in that window would delete Brutus. The Glitch
        //     Stalker never sets stock is_boss, so its intended one-shot is unaffected. (review 2026-07-11)
        //     ROUND GATE (user 2026-07-12 "shouldn't be doing one hit the whole game"): regular zombies
        //     one-hit only through round acc_bk_onehit_round (12) base / acc_bk_onehit_round_pap (24) PaP
        //     (bk_name substring "knife_ballistic_upgraded" covers the canonical PaP form + its _acc_brz
        //     twin - the acc_bk_is_pap_form convention). GLITCH stays one-hit at ANY round: the glitch
        //     counter is the knife's job (Leviathan-consistent), not round-scaled. Past the gate the hit
        //     falls through to the scaled chain (stab x2 / throw x6 in 0c3 + Exo melee layer).
        if ( ( IS_TRUE( self.acc_is_glitch_zombie ) || !is_boss_or_elite( self ) )
             && !IS_TRUE( self.b_is_apothicon_fury )
             && !IS_TRUE( self.is_boss ) )
        {
            b_bk_onehit = IS_TRUE( self.acc_is_glitch_zombie );   // glitch: one-hit any round
            if ( !b_bk_onehit )
            {
                n_bk_round = ( isdefined( level.round_number ) ? level.round_number : 1 );
                if ( IsSubStr( bk_name, "knife_ballistic_upgraded" ) )
                    n_bk_gate = getdvarint( "acc_bk_onehit_round_pap", 24 );
                else
                    n_bk_gate = getdvarint( "acc_bk_onehit_round", 12 );
                b_bk_onehit = ( n_bk_round <= n_bk_gate );
            }
            if ( b_bk_onehit )
            {
                if ( isdefined( self.health ) ) feed_dmg_number( attacker, self.health, false );
                return self.health + 1000;
            }
            // past the gate: fall through to the scaled chain below (no early return).
        }
        // else: boss / non-glitch elite / Fury -> normal chain (capped chip).
    }

    // NOTE (2026-07-15 audit): the per-hit `oc_flags = get_oc_flags( attacker, weapon );` fetch that used
    // to sit here was REMOVED - it ran on EVERY damage event and its result was never read. The damage
    // chain is TIER-based now (oc_tier below): flat damage :944, glitch bonus :954 and pierce :1120
    // (= oc_tier x 0.04) all scale off the tier, which SUPERSEDED the old per-flag model. The flag
    // helpers (get_oc_flags / has_oc / has_pierce_oc) are kept but dormant - see their note near :1434.
    // _acc_overclocks::set_oc_flag still WRITES the flags, so the store is live if a future effect wants it.
    oc_tier  = 0;   // Cyberware Weapon Overclock tier (0..5) for THIS gun (per-gun, user 2026-06-19).
    if ( b_player_attacker )
    {
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
    //     under-performs there (intended, docs/04) without touching its chaff S-tier. REDUCTION.
    // -----------------------------------------------------------------------
    if ( ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
         && is_pellet_shotgun( weapon ) )
    {
        reduction = reduction * getdvarfloat( "acc_shotgun_boss_mult", ACC_SHOTGUN_BOSS_MULT );
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 0c) Wonder-weapon / launcher / sniper vs BOSS cut (user 2026-06-24 boss-nuke audit, docs/04): the SAME
    //     boss-damage trap as pellet shotguns, for the high-burst weapons that bypass it - the Thundergun cone
    //     (multi-trace) + the Mahem rocket (direct + splash) pile onto a boss's single hitbox, and the Paladin
    //     sniper is reined in vs bosses on user request. Cut vs bosses/mini-bosses ONLY so chaff power is kept.
    //     REDUCTION; stacks on the gun's acc_weapon_balance_mult. boss_nuke_mult() returns 1.0 for everything else.
    // -----------------------------------------------------------------------
    if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
    {
        n_bnuke = boss_nuke_mult( weapon );
        if ( n_bnuke != 1.0 )
        {
            reduction = reduction * n_bnuke;
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 0c2) BLAST-O-MATIC per-target profile (user 2026-07-03): "a little bit weaker against
    //      bosses [and] glitch, regular against regular zombies, and 3x stronger against
    //      shielded zombies." Regular zombies take the plain chain (no line here); bosses/
    //      mini-bosses AND glitch zombies x0.75; Shielded elites x3.0 - an AMPLIFICATION
    //      (>1, unlike the reductions above): this gun is the designated Shielded-counter
    //      (note their Thundergun immunity does NOT extend to the Blast-O-Matic). IsSubStr
    //      covers base + _up + all 6 twins (was 14 before the 2026-07-04 fastfire removal). Live dvars to tune in-game.
    // -----------------------------------------------------------------------
    if ( IsSubStr( weapon.name, "t9_semiauto_cosplay" ) )
    {
        if ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) || IS_TRUE( self.acc_is_glitch_zombie ) )
        {
            reduction = reduction * getdvarfloat( "acc_blasto_boss_mult", 0.75 );
            b_modified = true;
        }
        else if ( IS_TRUE( self.acc_is_shielded ) )
        {
            reduction = reduction * getdvarfloat( "acc_blasto_shield_mult", 3.0 );
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 0c3) BALLISTIC KNIFE per-MoD damage scaling (user 2026-07-12): "2x the stab damage and throw
    //      damage is 6x". Glitch zombies (any round) + regular zombies INSIDE the one-hit round gate
    //      are the scripted ONE-HIT (returned in the early block above) and Shielded elites take 0
    //      (deflect), so these multipliers shape the fall-through targets - bosses / mini-bosses /
    //      Apothicon Fury / any non-shielded elite (still backstopped by the 10% per-hit cap in 4d)
    //      AND, since the 2026-07-12 round gate, regular zombies past the gate (the knife's
    //      late-game scaling path).
    //      AMPLIFICATIONS (>1) in the reduction bucket, the Blast-O-Matic 0c2 precedent. The stab
    //      (b_melee) additionally rides the Exo melee layer below; the throw rides it too as of the
    //      same user request. b_bk_hit computed before the early block (name match + melee-gated
    //      held fallback - covers base/PaP/brz twins). Live dvars acc_bk_stab_mult / acc_bk_throw_mult.
    // -----------------------------------------------------------------------
    if ( b_bk_hit )
    {
        if ( b_melee ) reduction = reduction * getdvarfloat( "acc_bk_stab_mult", 2.0 );   // stab x2
        else           reduction = reduction * getdvarfloat( "acc_bk_throw_mult", 6.0 );  // throw x6
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 0c4) EXPLOSIVE vs BOSS amplifier (user 2026-07-16): +50% explosive damage on bosses/mini-bosses.
    //     A MULTIPLICATIVE x1.5 in the reduction bucket (the Blast-O-Matic 0c2 / Ballistic Knife 0c3
    //     amplification precedent - so it is a TRUE x1.5 of the final explosive hit, not an additive
    //     bonus_sum term that would dilute among the other layers). "Explosive" is scoped EXACTLY like the
    //     Warhead Bomber gate (:1020): is_explosive_mod (grenades / launcher / projectile / splash), MINUS
    //     energy weapons (their MOD_PROJECTILE would false-positive - the Havoc is Plasma's, not explosive)
    //     and MINUS the three unbuffed wonders (Fire Bow / Thundergun / Winter's Howl - no synergy by design).
    //     So it lands on frags / Monkey Bomb / Li'l Arnie / the Mahem / the War Machine. It STACKS on the
    //     launcher boss-cut in 0c (Mahem/War Machine x0.50 -> net x0.75 vs bosses) and, like every layer, is
    //     still backstopped by the 10%/hit boss cap in 4d - it can NEVER create a one-shot. Live dvar
    //     acc_explosive_boss_mult (1.0 = off). Weaponless scripted explosives (undefined weapon) pass the
    //     name-based exclusions (same as Warhead) and get the buff too, still under the 4d cap.
    // -----------------------------------------------------------------------
    if ( ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
         && is_explosive_mod( meansofdeath )
         && !( isdefined( weapon ) && isdefined( weapon.name ) && is_energy_weapon( weapon.name ) )
         && !( isdefined( weapon ) && isdefined( weapon.name ) && weapon_is_unbuffed_wonder( weapon.name ) ) )
    {
        reduction = reduction * getdvarfloat( "acc_explosive_boss_mult", ACC_EXPLOSIVE_BOSS_MULT );
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 0c5) PER-BOSS WEAKNESS (user 2026-07-16): +20% damage from the boss's ONE signature weapon
    //      class - see the ACC_BOSS_WEAKNESS_MULT define for the full boss->class table + design
    //      notes. Gate helper: boss_weakness_applies (bottom of file, with the class matchers).
    //      Live dvar acc_boss_weakness_mult (1.0 = off).
    // -----------------------------------------------------------------------
    if ( boss_weakness_applies( self, weapon, meansofdeath, b_melee ) )
    {
        reduction = reduction * getdvarfloat( "acc_boss_weakness_mult", ACC_BOSS_WEAKNESS_MULT );
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 0d) DOUBLE TAP damage temper (user 2026-06-25). Base Double Tap 2.0 = the stock specialty_doubletap2:
    //     it fires an EXTRA bullet per shot (~2x dmg) + faster RoF, and the extra bullet is ENGINE-level - it
    //     CANNOT be stripped in a usermap (docs/10). So we tame the doubled DAMAGE here; the fire rate stays.
    //     **100%-SAFE ALLOW-LIST (user 2026-06-25: "cannot be wrong about the gun"):** the engine fires the
    //     extra bullet ONLY on standard bullet guns - NOT Wonder Weapons / launchers / explosives / melee.
    //     Cutting a gun that does NOT double-fire would make Double Tap a pure NERF on it. So we reduce ONLY
    //     guns on the explicit weapon_gets_dt_bullet() allow-list AND only on bullet hits; every other weapon
    //     is left at full damage. REDUCTION (<1). Applies to base AND Mega (both carry the extra bullet).
    //     Mega Double Tap ("Gun Slinger", reworked 2026-07-04) is now a DAMAGE perk: the temper EASES from
    //     x0.6 -> x0.8 for Mega holders (its old fire-rate/swap twin was removed). Live dvars
    //     acc_doubletap_dmg_mult (base) / acc_doubletap_mega_dmg_mult (Mega).
    // -----------------------------------------------------------------------
    if ( b_player_attacker && b_bullet && !b_melee
         && isdefined( attacker ) && attacker HasPerk( "specialty_doubletap2" )
         && weapon_gets_dt_bullet( weapon ) )
    {
        dt_mult = getdvarfloat( "acc_doubletap_dmg_mult", ACC_DOUBLETAP_DMG_MULT );
        if ( acc_mega_bottles::has_mega_perk( attacker, "specialty_doubletap2" ) )
            dt_mult = getdvarfloat( "acc_doubletap_mega_dmg_mult", ACC_DOUBLETAP_MEGA_DMG_MULT );
        reduction = reduction * dt_mult;
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 1) Crit determination + crit chain. "Crit" == headshot-equivalent:
    //    a real head hit, a Precision Mode ability shot (auto-crit, ignores
    //    hit-loc per docs/04), or a Cyberware Overload chance proc that
    //    promotes a non-head bullet hit. Tac-19 stays excluded from the
    //    whole crit chain (docs/04 flat-damage rule).
    // -----------------------------------------------------------------------
    // MELEE NEVER HEADSHOTS (user 2026-06-23). The crit chain assumes the incoming `damage`
    // already carries the gun's GDT locHead (~x5 for bullets, so the +0.5 ACC_HEADSHOT_MULT
    // BONUS nets ~2.5x). MELEE has NO locHead, so a knife head/neck hit would take bonus_factor
    // = 0.5 ALONE = HALF damage (and a blue/teal "headshot" number). Gate melee out: no crit,
    // no tint, full melee damage wherever you hit. (b_melee from is_melee_mod, set above.)
    b_headshot = is_headshot( sHitLoc ) && !b_melee && !is_weapon_headshot_excluded( weapon );

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
        // Crit chain (ADDITIVE): each layer ADDS its value into bonus_sum. BUT for a REAL HEADSHOT the
        // loc-temper (resolve_headshot_multiplier, 0.5 reg / 0.8 boss) is applied SEPARATELY as a
        // multiplicative factor (n_hs_temper, in the application below) instead of being summed here -
        // otherwise it sits inside bonus_sum and the engine's locHead (~5.0) multiplies the OTHER bonuses
        // (PaP ladder, Deadshot, Cyberware) too, ballooning headshots instead of a clean 2.5x reg / 4x boss
        // (user 2026-06-25: "2.5x reg / 3x boss"; boss raised to 4x on 2026-07-08). BODY crits (Precision Mode / Cyberware proc -
        // no locHead inflation) KEEP the additive base layer here; there's nothing to double-temper.
        if ( !b_headshot )
        {
            bonus_sum += resolve_headshot_multiplier( self );
            n_applied++;
        }

        if ( isdefined( attacker ) && isplayer( attacker ) )
        {
            // Deadshot: base +1.3, American Sniper Mega replaces it with +1.5
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
        // Pack-a-Punch custom tier (T1..T3): flat damage layer = LINEAR +33.33%/pack
        // (+33% / +67% / +100% = 1.3333 / 1.66666 / 1.999999, double dmg at MAX) added to bonus_sum. The "_up" transform's
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
        // damage buff in v1.0 (docs/04_weapons.md "different damage hook").
        if ( isdefined( attacker.acc_cw_damage_mult ) && !b_melee )
        {
            bonus_sum += attacker.acc_cw_damage_mult; // BONUS: added to the sum
            n_applied++;
            b_modified = true;
        }

        // Cyberware Weapon Overclock - effect 1/3: FLAT per-tier weapon damage, ALWAYS on (hip + ADS;
        // gun hits only, oc_tier is 0 for melee). +acc_oc_dmg_per_tier per tier (default +12%/tier ->
        // +60% at T5, +120% at T10; user 2026-07-08: 0.10 -> 0.12). Adds 1 + tier*per_tier (>=1) into the additive bonus sum.
        if ( oc_tier > 0 )
        {
            bonus_sum += 1.0 + ( oc_tier * getdvarfloat( "acc_oc_dmg_per_tier", ACC_OC_DMG_PER_TIER ) );
            n_applied++;
            b_modified = true;
        }

        // Cyberware Weapon Overclock - effect 2/3: GLITCH PIERCING - bonus damage vs glitch zombies (the
        // Glitch Stalker + lockdown-challenge glitch zombies, flagged self.acc_is_glitch_zombie in
        // _acc_boss_glitch). +acc_oc_glitch_per_tier per tier (default +15%/tier -> +75% at T5, +150% at T10; user 2026-07-08: 0.25 -> 0.15).
        if ( oc_tier > 0 && IS_TRUE( self.acc_is_glitch_zombie ) )
        {
            bonus_sum += 1.0 + ( oc_tier * getdvarfloat( "acc_oc_glitch_per_tier", ACC_OC_GLITCH_PER_TIER ) );
            n_applied++;
            b_modified = true;
        }

        // EXO SUIT - melee augment (user 2026-06-22): the player's KNIFE/melee hits scale with the player's
        // Exo Suit tier - +acc_exo_melee_per_tier per tier (default +15%/tier -> +75% at T5, +150% at T10;
        // user 2026-07-18 HALVED from +30%/tier). This is
        // the exo's "body" counterpart to the gun Overclock's flat damage (effect 1): guns get oc_tier (0 on
        // melee), melee gets exo_tier. Melee-ONLY (b_melee), so guns are untouched. Additive layer like the
        // rest. The Cyberware Amplifier deliberately skips melee (above); the Exo Suit IS the melee scaler.
        // [acc] BALLISTIC KNIFE rides this layer for BOTH attacks (user 2026-07-12 "exo suit upgrades
        // should impact the ballistic knife"): the stab is b_melee anyway; b_bk_hit extends it to the
        // THROW (a thrown melee weapon - the knife's scaling path, since the scripted one-hit/deflect
        // rules pre-empt Overclock effects on it). Like every bonus layer this shapes the
        // boss/Fury/elite fall-through + regulars past the 2026-07-12 one-hit round gate
        // (glitch is still one-hit before the chain runs).
        if ( ( b_melee || b_bk_hit ) && isdefined( attacker.acc_exo_tier ) && attacker.acc_exo_tier > 0 )
        {
            bonus_sum += 1.0 + ( attacker.acc_exo_tier * getdvarfloat( "acc_exo_melee_per_tier", 0.15 ) );
            n_applied++;
            b_modified = true;
        }

        // Double Tap 1.0 (docs/10_perks.md overhaul): fire-rate ONLY now - no
        // damage bonus. The former +3%/+6% damage layer was removed here.
        // Widow's Wine base: the former +50% frag damage was removed here too
        // (base Widow is now pure-stock web behavior). See docs/10.

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

        // Plasma Generator (boss item 9, user 2026-07-14): +10% damage on ENERGY-weapon hits
        // (is_energy_weapon by weapon name) while implanted. The ENERGY half of the old Nuclear item.
        // Additive layer. Flag set by _acc_boss_items::apply_plasma (plain player field).
        if ( IS_TRUE( attacker.acc_item_plasma )
             && isdefined( weapon ) && isdefined( weapon.name ) && is_energy_weapon( weapon.name ) )
        {
            bonus_sum += ACC_ITEM_PLASMA_MULT;
            n_applied++;
            b_modified = true;
        }

        // Warhead Bomber (boss item 13, user 2026-07-14): +20% damage on EXPLOSIVE hits (is_explosive_mod =
        // grenades / launchers / projectiles / MOD_EXPLOSIVE) while implanted. The EXPLOSIVE half of the old
        // Nuclear item, at a higher rate. MOD-based, so it covers thrown grenades + the launchers. EXCLUDES
        // the three unbuffed wonders (Fire Bow / Thundergun / Winter's Howl, user 2026-07-14) whose
        // projectile/energy MODs would otherwise qualify - they intentionally get no implant synergy.
        // ALSO excludes ENERGY weapons (is_energy_weapon, user 2026-07-15): an energy PROJECTILE gun like the
        // Havoc reports MOD_PROJECTILE, which satisfies is_explosive_mod - but it is an ENERGY gun, owned by
        // Plasma Generator, NOT an explosive. Without this, holding both items double-dips it (+10% + +20%).
        // Mirrors the High Caliber exclusion below so Plasma / Warhead / High Caliber cover DISJOINT classes -
        // energy -> Plasma only, explosive -> Warhead only, bullet -> High Caliber only.
        if ( IS_TRUE( attacker.acc_item_warhead )
             && is_explosive_mod( meansofdeath )
             && !( isdefined( weapon ) && isdefined( weapon.name ) && is_energy_weapon( weapon.name ) )
             && !( isdefined( weapon ) && isdefined( weapon.name ) && weapon_is_unbuffed_wonder( weapon.name ) ) )
        {
            bonus_sum += ACC_ITEM_WARHEAD_MULT;
            n_applied++;
            b_modified = true;
        }

        // High Caliber Rounds (boss item 12, user 2026-07-14): +25% damage on BULLET hits (b_bullet =
        // MOD_PISTOL_BULLET / MOD_RIFLE_BULLET / MOD_HEAD_SHOT) while the item is implanted. The BULLET-gun
        // counterpart to Nuclear above - deliberately EXCLUDES energy weapons (is_energy_weapon) so the two
        // items cover disjoint weapon classes and a gun is boosted by exactly one, never both. Melee /
        // grenades / projectiles never satisfy b_bullet, so they're naturally out. Additive layer like the
        // rest. Flag set by _acc_boss_items::apply_high_caliber (plain player field).
        if ( IS_TRUE( attacker.acc_item_high_caliber )
             && b_bullet
             && !( isdefined( weapon ) && isdefined( weapon.name ) && is_energy_weapon( weapon.name ) ) )
        {
            bonus_sum += ACC_ITEM_HIGH_CALIBER_MULT;
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
        // multiplier on top (docs/04: "auto-crit (4x damage, ignore hit-loc)").
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
        // the item is Phase 4 (docs/15 battery-3x-autoaim-shot).
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
    // 4) Target-side reduction: Shielded ("Riot") elite frontal resist, with the
    //    Overclock SHIELD-PIERCE counter (effect 4/4).
    //    self.acc_elite_front_damage_resist (0.25 = "take 25% from front",
    //    _acc_elites.gsc). Bullets/melee only - grenades / explosives bypass per
    //    docs/08 counter-play.
    // -----------------------------------------------------------------------
    // THE CYBERJACK (wonder weapon) IGNORES the Riot front armor entirely (user 2026-07-17
    // "the storm ball doesn't hit shield zombies. This is wrong.") - full frontal damage,
    // like a flank/explosive. Its storm/DoT already bypass via the exact-mark; this covers
    // the direct plasma stream so shielded elites die to it from any angle.
    b_cyberjack_pierce = ( isdefined( weapon ) && isdefined( weapon.name ) && IsSubStr( weapon.name, "apex_lstar" ) );
    if ( isdefined( self.acc_elite_front_damage_resist )
         && ( b_bullet || b_melee )
         && !b_cyberjack_pierce
         && hit_is_frontal( self, attacker, vdir ) )
    {
        front_frac = self.acc_elite_front_damage_resist; // damage fraction that gets THROUGH the front armor (0.25)

        // OC effect 4/4 - SHIELD PIERCING (user 2026-06-25). The gun's Overclock tier PARTIALLY restores the
        // Riot's BLOCKED frontal damage: each tier lerps front_frac from 0.25 toward 1.0 by `pierce`
        // (= oc_tier x 0.04, user 2026-07-08: 0.05 -> 0.04). So front_frac = 0.25 + 0.75*pierce -> the front takes
        // 25% at T0, 40% at T5, 55% at T10. pierce maxes at ~0.40 (<< 1.0), so it is ALWAYS a partial reduction -
        // NEVER a full bypass or weak point (the user cut this from the old 0.20/tier that fully bypassed at T5 and
        // over-pierced into a weak point). Flanking / explosives / side-melee stay the real counters.
        // oc_tier is 0 for melee, so this is guns only (the Exo scales melee).
        if ( oc_tier > 0 )
        {
            pierce = oc_tier * getdvarfloat( "acc_oc_pierce_per_tier", ACC_OC_PIERCE_PER_TIER ); // partial restore; maxes ~0.40 at T10
            front_frac = front_frac + ( ( 1.0 - front_frac ) * pierce );
        }

        // Apply unless it's an exact no-op (front_frac == 1.0). < 1.0 REDUCES (armor); > 1.0 AMPLIFIES
        // (over-pierced front = weak point). The reduction bucket is multiplicative, so a >1.0 factor here
        // correctly scales the final frontal damage up.
        if ( front_frac != 1.0 )
        {
            reduction = reduction * front_frac;
            b_modified = true;
        }
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

        // Headshot loc-temper: a SEPARATE multiplicative factor (NOT summed into bonus_factor) so the
        // headshot's locHead reduction tempers ONLY the base loc-inflation, not the PaP/Deadshot/Cyberware
        // bonuses (user 2026-06-25 - stops PaP headshots ballooning; a clean 2.5x reg / 4x boss of body).
        // Body crits (no locHead) -> 1.0. Regular zombie = 0.5, boss = 0.8 (resolve_headshot_multiplier).
        n_hs_temper = ( b_headshot ? resolve_headshot_multiplier( self ) : 1.0 );

        final_damage = int( damage * bonus_factor * n_hs_temper * reduction );
        if ( final_damage < 1 ) final_damage = 1;

        /# acc_utility::log( "damage: " + damage + " -> " + final_damage +
                             " (bonus x" + bonus_factor + ", red x" + reduction + ")" ); #/
    }

    // -----------------------------------------------------------------------
    // 4b) GLOBAL player-damage buff (user 2026-06-23): one across-the-board scalar
    //     that lifts EVERY gun uniformly, preserving the per-gun tiers above. Flat
    //     FINAL multiply on all PLAYER damage, OUTSIDE the bonus/reduction buckets.
    //     Applied BEFORE the headshot-KILL test below so a buffed killing blow is
    //     still detected as a kill, and BEFORE record_damage/feed_dmg_number so the
    //     point split + crosshair number reflect the real applied damage. Even when
    //     no other layer fired (b_modified false), final_damage == raw `damage` here,
    //     so the buff applies to plain body shots too. Live dvar acc_global_dmg_mult.
    // -----------------------------------------------------------------------
    if ( b_player_attacker )
    {
        gmult = getdvarfloat( "acc_global_dmg_mult", ACC_GLOBAL_DMG_MULT );
        if ( gmult != 1.0 )
        {
            final_damage = int( final_damage * gmult );
            if ( final_damage < 1 ) final_damage = 1;
            b_modified = true;
        }
    }

    // -----------------------------------------------------------------------
    // 4c) INSTA-KILL vs NON-REGULAR enemies = 6x gun damage (user 2026-06-23). The stock insta-kill
    //     one-shot is SKIPPED for bosses/elites/Glitch Stalker/Brutus (acc_instakill_override returns
    //     false for them), so it would otherwise do NOTHING to them. Here the gun's hit is multiplied
    //     x6 so the powerup has real impact without one-shotting. Regular zombies are excluded
    //     (is_non_regular) - they're still one-shot by the stock/override path. Applied AFTER the global
    //     buff so it is "6x the gun's actual hit", and BEFORE record_damage/feed so points + the
    //     crosshair number reflect it.
    // -----------------------------------------------------------------------
    b_instakill_boss = ( b_player_attacker && is_non_regular( self ) && acc_insta_kill_active_for( attacker ) );
    n_insta_mult = getdvarint( "acc_instakill_boss_mult", ACC_INSTAKILL_BOSS_MULT );   // 2x (was 6x), user 2026-06-25
    if ( b_instakill_boss )
    {
        final_damage = int( final_damage * n_insta_mult );
        if ( final_damage < 1 ) final_damage = 1;
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 4c-ii) FIRE BOW vs APOTHICON FURY (user 2026-07-07): the Fire Bow's demon-gate special is THE counter to
    //   the fiery trench Furies ("lava enemies"). It is a GUARANTEED ONE-HIT - NOT a multiplier (user 2026-07-07:
    //   "just a one hit"). ANY Fire Bow hit (the direct arrow OR the charged demon-gate AoE - the radiusDamage
    //   passes level.w_bow_demongate_charged) deals the Fury's FULL max health, so a single hit always kills it
    //   regardless of the round's HP. Furies are trench elites (NOT acc_is_boss), so the boss per-hit cap below
    //   never clamps this. Dvar acc_firebow_fury_onehit (default 1; 0 = off -> raw demon-gate damage) for testing.
    //   MATCHER TIGHTENED 2026-07-17 (CYBERJACK M0 verify catch): was IsSubStr "elemental_bow", which the
    //   storm-bow CYBERJACK (elemental_bow_storm) would silently inherit - this one-shot is the FIRE BOW's
    //   exclusive (docs/43 gives the CYBERJACK the Glitch Stalker instead, M1+). Demongate forms only.
    // -----------------------------------------------------------------------
    if ( b_player_attacker && IS_TRUE( self.b_is_apothicon_fury )
         && isdefined( weapon ) && isdefined( weapon.name )
         && ( IsSubStr( weapon.name, "elemental_bow_demongate" ) || IsSubStr( weapon.name, "bow_demongate" ) )
         && getdvarint( "acc_firebow_fury_onehit", 1 ) == 1 )
    {
        fury_ref = ( isdefined( self.maxhealth ) && self.maxhealth > 0 ? self.maxhealth : ( isdefined( self.health ) ? self.health : 1 ) );
        final_damage = fury_ref + 1;   // full max health + 1 = always a one-shot, any round
        b_modified = true;
    }

    // -----------------------------------------------------------------------
    // 4d) BOSS-DAMAGE HARD CAP (user 2026-06-24, boss-nuke audit - the robust catch-all). No SINGLE hit may
    //     delete a boss. The name-keyed boss cuts (0b/0c) are structurally BLIND to weaponless scripted
    //     DoDamage - the stock Thundergun FLING does DoDamage(self.health+666) with NO weapon (the real
    //     ~200k one-shot, int(80666*2.5)=~201k), and the Li'l Arnie octobomb pull does DoDamage(target.health)
    //     - so balance_mult (gated on isdefined(weapon)) and boss_nuke_mult (1.0 when weapon undefined) never
    //     fire. And for WEAPON hits the 0c cut is a multiplicative REDUCTION that PaP/Cyberware/Overclock
    //     investment + the insta-kill x6 re-inflate right past. A FINAL clamp - AFTER the global x2.5 AND the
    //     insta-kill x6 - is the only fix that survives all of them: a single player hit on a boss/mini-boss
    //     deals at most acc_boss_per_hit_cap_pct of its maxhealth (default 0.10 -> >=10 hits to kill any boss,
    //     regardless of weapon/weaponless/insta-kill/investment). Dvar 0 = off (uncapped). The 0b/0c cuts stay
    //     - they shape the baseline feel BELOW the cap; this just removes the one-shot ceiling-break.
    // -----------------------------------------------------------------------
    // EXCLUDES the Glitch Stalker: it carries acc_is_mini_boss but is a LIGHTWEIGHT fast-dying mini-boss
    // (1.5x zombie HP, killed by punishing its post-blink window) - a 10%/hit cap would wrongly sponge it.
    // So cap only the HEAVYWEIGHT bosses (Brutus / Phantom / Subroutine Core), never acc_is_glitch_zombie.
    if ( b_player_attacker
         && ( IS_TRUE( self.acc_is_boss ) || IS_TRUE( self.acc_is_mini_boss ) )
         && !IS_TRUE( self.acc_is_glitch_zombie )
         && isdefined( self.maxhealth ) && self.maxhealth > 0 )
    {
        cap_pct = getdvarfloat( "acc_boss_per_hit_cap_pct", ACC_BOSS_PER_HIT_CAP_PCT );
        // (LEVIATHAN AXE handled EARLIER via its per-enemy hits-to-kill fractional path - it returns before
        //  this cap, so it never reaches here. See the leviathan block after the Thundergun fractional return.)
        // INSTA-KILL scales the cap by the SAME multiple as the damage (user 2026-06-25), so a gun already at
        // the 10% cap deals exactly n_insta_mult x its normal capped hit (2x -> 20%), not the old 6x that the
        // flat 10% cap clamped right back to 4k. Still bounded (no one-shot).
        if ( b_instakill_boss )
            cap_pct = cap_pct * n_insta_mult;
        if ( cap_pct > 0 )
        {
            n_cap = int( self.maxhealth * cap_pct );
            if ( n_cap >= 1 && final_damage > n_cap )
            {
                final_damage = n_cap;
                b_modified = true;
            }
        }
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
        // Headshot-KILL DING (user 2026-06-22): custom 2D ding to the SHOOTER only (PlayLocalSound is
        // per-client = full volume, no world reverb/falloff). Gated to KILLS like the ammo refund below.
        // Stock plays NO headshot "ding" to remove (verified: only the client-side head-gib pop, which lives
        // in stock _zm.csc and we don't own) - so this is purely additive. Live toggle: acc_headshot_ding 0.
        if ( isdefined( attacker ) && getdvarint( "acc_headshot_ding", 1 ) == 1 )
            attacker PlayLocalSound( "acc_headshot_ding" );

        // Cyberware Weapon Overclock - effect 3/3: per-tier ammo refund on a HEADSHOT KILL (user 2026-06-21:
        // gated to KILLS, not every headshot hit). CHANCE scales with the gun's tier (acc_oc_adaptive_per_tier;
        // default +5%/tier -> 25% at T5, 50% at T10; user 2026-07-08: 0.10 -> 0.05).
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
        // DISPLAY tint is decoupled from the DAMAGE crit flag (user 2026-07-06): teal means
        // "you hit the head", so it ignores is_weapon_headshot_excluded - a shotgun head-pellet
        // tints teal even though its damage stays flat (docs/04 flat-damage rule untouched).
        // Was b_headshot, which made shotgun head hits amber on zombies but teal on the Rogue
        // Protector (boss_damage_feed never applied the exclusion) - the reported inconsistency.
        // Melee stays untinted (melee never headshots, user 2026-06-23).
        b_head_display = is_headshot( sHitLoc ) && !b_melee;
        feed_dmg_number( attacker, final_damage, b_head_display );
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
// multi-factor "v2 sustain" scoring formula in docs/04_weapons.md "Gun Tier List"
// (DPS 30 / mobility 16 / sustain[=reload/clip,log] 18 / penetration 14 / reserve[log]
// 14 / handling 8). DPS here is just ONE input - a gun's tier also moves with its
// clip/reload (via tools/reduce_base_ammo.js), penetration, mobility, etc. Each return
// line is tagged [S]/[A]/[B]/[C] to match the doc table; recompute the formula after a change.
function acc_weapon_balance_mult( weapon_name )
{
    // ===== +10% ALL-GUN DAMAGE BUFF (user 2026-07-07) =====
    // Every LIVE gun's mult below was multiplied by 1.10 in one pass (e.g. AK-47 0.2689 -> 0.29579).
    // EXCLUDED from the +10% buff: Thundergun, Blast-O-Matic (t9_semiauto_cosplay), Mahem (s1_mahem),
    // CEL-3 (s1_cel3) - per user; PLUS the two inert entries ASM1 (retired) and China Lake
    // (t5_china_lake, not in game). Same-day per-gun follow-ups (user 2026-07-07), applied AFTER the
    // global +10%: CEL-3 -20% (0.54 -> 0.432, it was excluded from the global); Peacekeeper +10% MORE
    // (0.3784 -> 0.41624); Streetsweeper +30% (0.08184 -> 0.106392); Alternator +10% MORE both forms
    // (base 0.165 -> 0.1815, PaP 0.6534 -> 0.71874); Havoc +10% MORE (0.3289 -> 0.36179). The per-line
    // "USER ... DAMAGE (a -> b)" tags predate this pass and were NOT re-derived - the value on each
    // line IS the current number; this header is the authoritative 2026-07-07 change log.
    // ======================================================
    // ===== APEX MIGRATION 2026-07-06: 5 Apex guns (Alternator replaces Klauser; Peacekeeper/Prowler/G7 Scout/Havoc
    // replace the top shotgun slot/Chicom/Paladin/China Lake). Apex asset ids carry a baked "_zm" (apex_<gun>_zm[_up]).
    // Alternator: user "trash base but A+ papped" (Klauser pattern) - the _up (apex_alternator_up) gets its own STRONG
    // line ABOVE the base's TRASH line. The _up name contains "_zm_up", so match THAT (not "_up" alone). =====
    // DPS-FIRST RETUNE (user 2026-07-06 pt2: "DPS is the main factor except the Peacekeeper" - the original
    // mults left the Apex autos at the BOTTOM of the map: Alternator PaP 1655 sustained vs AK-74u(A) 2487,
    // Prowler 1215 = worst automatic, G7 1317 < RPD(C) 2847). New sustained-DPS targets (docs/25 scale):
    // Alternator ~3300 (A+, RW1/AE4 cluster) - Prowler ~2375 (solid B, above Grav) - G7 ~1910 (honest C,
    // 2x heads) - Beam ~2650 (proper A). Peacekeeper UNCHANGED - power-first one-pump by design.
    if ( IsSubStr( weapon_name, "apex_alternator_up" ) ) return 0.646866;   // [A+] Alternator PaP: USER 2026-07-10 -10% DAMAGE (0.71874 -> 0.646866). Prior: 2026-07-06 +10% (0.54 -> 0.594 -> global +10% 0.71874). Also RoF -20% (fireTime 0.107->0.134) + clip 26->30 (GDT), PaP cost MID->BOT. The payoff gun.
    if ( IsSubStr( weapon_name, "apex_alternator" ) )       return 0.16335;   // [trash] Alternator BASE: USER 2026-07-10 -10% (0.1815 -> 0.16335). ~44/bullet at r1 - trash-but-shootable (0.05 = 16/bullet was broken-feeling). Covers base.
    if ( IsSubStr( weapon_name, "apex_peacekeeper" ) )      return 0.41624;  // [S] Peacekeeper (Apex 11->12-pellet lever SG): USER 2026-07-07 +10% DAMAGE on top of the global +10% (0.344 -> 0.3784 -> 0.41624). Prior: 2026-07-06 -20% ALL-SHOTGUN NERF (0.43 -> 0.344). POWER-FIRST top shotgun (user #6), DELIBERATELY not DPS-tuned ("one pump machine"). Headshot-excluded + pellet-boss-cut. Also RoF +25% (fireTime 0.2->0.16 GDT).
    if ( IsSubStr( weapon_name, "apex_prowler" ) )          return 0.54571;   // [B] Prowler USER 2026-07-11 +21% DMG (0.451 -> 0.54571 = SMG-wide +10% AND Prowler-specific +10%, compounding per user) + clip/reserve +10% & reload x0.9 (GDT). (Apex full-auto SMG): 135 x 0.41 -> body T3 ~360, ~2375 sustained (was 0.21 = 1215, worst automatic on the map). Sits above Grav(B+ 2087), below AK-74u(A 2487).
    if ( IsSubStr( weapon_name, "t9_m16" ) )                return 0.18;    // [RETIRED 2026-07-11 - replaced by the Triple Take; unreachable, kept for easy restore] M16 (CW burst->full-auto tactical rifle): raw _up 480 -> body T3 562, head 1405. Loc normalized install-side (tools/prep_m16_gdt.js, .acc-m16-orig).
    if ( IsSubStr( weapon_name, "apex_tripletake" ) )       return 0.356571875;  // [A-] Triple Take (Apex ENERGY sniper, user 2026-07-11; VOLLEY REWORK 2026-07-16 v3): USER +15% DAMAGE round 9 (0.3100625 -> 0.356571875; history 0.2255 -> +25% 07-11 -> +10% 07-16 -> +15% 07-16 evening). Def = BULLETWEAPON shotCount 1, pen LARGE, falloff-flat (v3 prep - the projectileweapon graft was inert-hitscan and retired): a trigger = 3 HITSCAN hits (1 native center + 2 _acc_tripletake.gsc MagicBullet side lines of the HELD weapon -> this same bal line covers all 3) COSTING 3 ROUNDS, clip 9/15, fireTime 0.1728 base / 0.110592 PaP. raw 500/hit -> per-HIT body T1/T2/T3 ~773/966/1159 (head x2.5), per-TRIGGER ~2318/2898/3477. ENERGY (is_energy_weapon below) so Plasma Generator +10% applies; bullet MODs never hit Warhead, and High Caliber excludes energy - classes stay disjoint. The visible volley = plasma-orb movers (cosmetic). IsSubStr covers base+_up+twins. docs/04/25.
    if ( IsSubStr( weapon_name, "apex_beam_rifle" ) )       return 0.340264;  // [A] Havoc (energy PROJECTILE rifle, full-auto): USER 2026-07-12 -10% then ANOTHER -5% same day (0.39797 -> 0.358173 -> 0.340264, net x0.855; was landing ~20k headshots with the full PaP/OC/headshot stack - body T3 ~663, head ~995, ~3471 sustained). History: 0.21 -> 0.26 -> 0.299 -> 0.36179 -> 0.39797 -> 0.340264. Projectile -> no DT extra bullet; special OC; per-hit cap backstops bosses. IsSubStr covers base + _up + all 6 twins.
    if ( IsSubStr( weapon_name, "pistol_standard_upgraded" ) ) return 0.55;  // ["Death and Taxes"] PaP'd MR6 = level.default_laststandpistol (the DOWN pistol you get in last stand without the Five-Seven): USER 2026-07-13 -50% DAMAGE (1.10 -> 0.55) - too OP as a free down weapon. Must sit ABOVE the generic pistol_standard line (IsSubStr returns on first match) so ONLY the upgraded/laststand form is cut; the base start pistol stays 1.10.
    if ( IsSubStr( weapon_name, "pistol_standard" ) ) return 1.10;  // [start] MR6/M1911 start pistol (level.start_weapon): was default 1.0 (uncut); +10% all-gun buff (user 2026-07-07). NOTE: _upgraded (laststand "Death and Taxes") is handled by the halved line ABOVE; this covers the base start pistol only. Only >1.0 entry - an amplify, not a cut.
    if ( IsSubStr( weapon_name, "elemental_bow_demongate" ) ) return 0.585;  // [wonder] FIRE BOW (HB21 demongate): USER 2026-07-13 -35% ALL AROUND (1.0 -> 0.65) on the direct arrow hit, then USER 2026-07-18 all-wonder -10% (0.65 -> 0.585); the charged-shot portal DoT is nerfed in-lockstep in _zm_weap_elemental_bow_demongate.gsc (acc_firebow_dot_frac x0.9 + boss div /0.9 on 07-18). Designed one-shots (chomper eat = target.health) survive - 0.585x of a huge overkill still one-shots. pack-native damage x global 3.25; boss per-hit cap backstops.
    if ( IsSubStr( weapon_name, "leviathan" ) )               return 1.0;  // [wonder] LEVIATHAN AXE (WetEgg GoW melee, added 2026-07-07): melee weapon damage; base + leviathan_up covered by IsSubStr. PLAYTEST-TUNE HERE.
    if ( IsSubStr( weapon_name, "apex_lstar" ) )              return 0.288; // [wonder] THE CYBERJACK (apex_lstar / L-STAR chassis, docs/43). FOUNDATION (user 2026-07-17): the BULLET STREAM sits JUST UNDER the wonder weapons on its own, but FULLY OVERCLOCKED + Plasma Generator (energy +10%, is_energy_weapon below) it is THE BEST GUN IN THE GAME - the OC damage tiers + Plasma stack multiplicatively on this base (both live). NOT a one-hit gun (that's the TORNADO's job). USER 2026-07-27 all-lane -10% "they are just too good" (0.32 -> 0.288). (250 @ 0.084 x 0.288 x 3.25 = 234/shot ~= 2786 eff DPS base; PaP tiers multiply via pap_tier_mult at :990 - get_tier reads cyberjack_tier, so the in-place PaP damage ladder applies automatically; the jack-in chain hops fire the held weapon so they inherit this mult too). v4.3 GDT: clip 60 / 8 mags (480), pen LARGE (through-zombie pierce), tight hip spread, energy muzzle flash. The WONDER-ness is chain + DoT + tornado (exact-marked, untouched by this mult - nerfed in their own lanes same day). PLAYTEST-TUNE HERE.
    if ( IsSubStr( weapon_name, "t6_fiveseven" ) ) return 0.27742;   // [C-] Five-Seven (start pistol): ~50 eff/shot. SPREAD -3% worst-gun nerf (0.26 -> 0.2522, user 2026-06-26). Mobile starter, fast reload + 14 clip = decent sustain, but weak dmg + 56 reserve = C- (user 2026-06-21).
    if ( IsSubStr( weapon_name, "s1_asm1" ) )      return 0.21;     // [B] ASM1 - RETIRED 2026-07-03 (user; gun removed from zone/CSV/pools - this entry is inert and STAYS for easy restore). ~401 DPS, v2 B (6.5).
    if ( IsSubStr( weapon_name, "s1_tac19" ) )     return 0.49929;  // [S] Tac-19 (AW energy SG): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.5674 -> 0.4539; per-pellet T3 body ~514). Prior: 2026-07-05 -10% (0.6304 -> 0.5674), SPREAD +3% (0.612 -> 0.6304). Tier label kept (curated e). 12-pellet crowd king (headshot-excluded); vs bosses see ACC_SHOTGUN_BOSS_MULT. docs/04.
    if ( IsSubStr( weapon_name, "t6_olympia" ) )   return 0.41734;  // [C] Olympia (BO2 double-barrel SG): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.4743 -> 0.3794). Prior: SPREAD -3% worst-gun nerf (0.489 -> 0.4743, 2026-06-26) on the -50% max-scale fix (0.9775 -> 0.489, 2026-06-25). 110/pellet x ~8, 2-round clip + 3.9s reload = worst sustain. Headshot-excluded.
    if ( IsSubStr( weapon_name, "t9_streetsweeper" ) ) return 0.106392;  // [A] Streetsweeper (CW full-auto drum SG, 12 pellets PaP): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.0930 -> 0.0744). Prior: 2026-07-05 -15%, -10%, -10% (0.135 -> 0.1148 -> 0.1033 -> 0.0930). ALSO clip/mag -25% install-side (_up clip 18->14, maxAmmo 12->9, reserve 216->126). _up per-pellet T3 body ~294 (x12 = ~3528 point-blank). Score drops with the ammo cut (see compute_gun_tiers); still headshot-excluded + pellet-boss-cut. Tune HERE for power.
    if ( IsSubStr( weapon_name, "s1_cel3" ) )      return 0.3888;   // [B-] CEL-3 Cauterizer (AW triple-barrel full-auto spread SG, 12 pellets PaP): USER 2026-07-14 -10% DAMAGE (0.432 -> 0.3888). Prior: 2026-07-07 -20% (0.54 -> 0.432; EXCLUDED from the same-day global +10% gun buff). Prior: 2026-07-06 -20% ALL-SHOTGUN NERF (0.675 -> 0.54). Prior (2026-07-05): +100% then +25% (0.27 -> 0.54 -> 0.675). loc NORMALIZED install-side (torso 1.0) so per-pellet body = raw x bal x global. Headshot-excluded + pellet-boss-cut. Tune HERE for power.
    if ( IsSubStr( weapon_name, "t9_ak47" ) )      return 0.266211;  // [S] AK-47 (200@0.08 = 2500 raw): USER 2026-07-11 -10% DAMAGE (0.29579 -> 0.266211). Prior: 2026-07-06 +15% DAMAGE (0.2338 -> 0.2689). Prior: SPREAD +3% (0.227 -> 0.2338, 2026-06-26) on the AK swap (0.186 -> 0.227 -> TOP/S). Solid DPS + decent reload. Focus Fire ability.
    if ( IsSubStr( weapon_name, "t9_xm4" ) )       return 0.2079;    // [S] XM4 (CW full-auto AR, base 200@0.083 = 2410 raw): USER 2026-07-11 -10% DAMAGE (0.231 -> 0.2079). ADDED 2026-07-04. mult 0.21 -> effDPS e=506 -> papScore 7.86 = S (docs/33). _up 360 -> T3 body ~491, head ~1229 (in the S cohort: AK-47 410, PPSH 450, M60 589). Big 70-clip/750-RPM. Tune HERE for power.
    if ( IsSubStr( weapon_name, "t9_grav" ) )      return 0.165;    // [B+] Grav (CW full-auto AR): the GALIL's stats grafted onto the CW model/sfx (user 2026-07-05, t6_galil->t9_grav, same AK-47-style migration). Identical to the Galil: 220@0.08 = 2750 raw x 0.15 = ~412 DPS - mult + tier unchanged, only the model/anims/sounds are new.
    if ( IsSubStr( weapon_name, "s1_ae4" ) )       return 0.3069;    // [B] AE4 (AW energy AR, 160@0.12 = 1333 raw): USER 2026-07-11 -10% DAMAGE (0.341 -> 0.3069). ~413 DPS. Formula reads A- (6.8) but user-curated to B 2026-06-21 (mid DPS; fast reload + pierce + 25 clip + 200 reserve keep it top-B).    // +6 box guns (user, 2026-06-15). Mults land each near the ~500 eff-DPS box band
    // (raw DPS = damage/fireTime from the Skye GDTs). IsSubStr covers base + PaP + twins.
    if ( IsSubStr( weapon_name, "s4_ppsh41" ) )    return 0.269225;  // [S] PPSH-41 USER 2026-07-11 +10% SMG-class DMG (0.24475 -> 0.269225) + reload x0.9 (GDT). (VG smg, 155@0.063 = 2460 raw): USER 2026-07-06 -10% DAMAGE (0.2472 -> 0.2225). Prior: SPREAD +3% (0.24 -> 0.2472, 2026-06-26) on the 2026-06-24 +20% buff. Clip 40/54. IsSubStr covers base + _up + all perk twins.
    if ( IsSubStr( weapon_name, "t6_chicom_cqb" ) ) return 0.28325;  // [S+] Chicom CQB (BO2 3-round-burst SMG, 130@0.048 within burst; ~512 sustained eff w/ the 0.1s burst delay): box's #1 gun. SPREAD +3% best-gun buff (0.25 -> 0.2575, user 2026-06-26, papScore ~8.18). clip 36/56, reserve 180/448 uncut. cu-curated. IsSubStr covers base + _up + twins.
    if ( IsSubStr( weapon_name, "t9_ak74u" ) )     return 0.22264;  // [A] AK-74u USER 2026-07-11 +10% SMG-class DMG (0.2024 -> 0.22264) + reload x0.9 (GDT). (BO1 smg, 180@0.08 = 2250 raw): ~414 DPS. SWAPPED with AK-47 (user 2026-06-26): mult 0.23 -> 0.184 drops papScore ~7.90 -> ~7.04 = MID tier. Still fast/mobile, just less DPS. Clip 20/reserve 160.    // Paladin HB50 (t8_paladin_hb50): BO4 sniper, base dmg 1000 flat. The REAL "crazy strong"
    // cause (user, 2026-06-15) was the Skye rip's MP-inflated hit-location mults: locTorso 5.0
    // (PaP 9.0), limbs 4.0 (8.0), locHead 7.5 (10.0) - so at x1.0 even a BODY/limb shot one-shot
    // to ~r23 and a headshot to ~r33. FIX: the GDT's loc* mults were normalized to 1.0 install-side
    // (skye_t8_paladin_hb50.gdt, both base + _up entries; backup .acc-loc-orig; not repo-tracked -
    // re-apply on a fresh box, see docs/21). With loc=1.0 the gun obeys the additive model like
    // every other gun (body = base, headshot = our 2.0 map mult only), so x0.80 -> body r7 /
    // headshot r14 / HS+Deadshot r20, PaP+Cyberware push higher. A real sniper that FALLS OFF
    // without PaP. Tune the mult here (not the GDT) for further feel changes. Balance audit docs/21.
    if ( IsSubStr( weapon_name, "t8_paladin_hb50" ) ) return 0.15235;  // [B-] Paladin HB50 (BO4 sniper): USER 2026-07-02 TARGET-DAMAGE nerf - "450 body" -> bal = 450/(raw 1000 x global 3.25) = 0.1385 (head = 2.5x = ~1125). Supersedes same-day 0.26 and the 2026-06-27 0.3565. clip 8 / reserve 96/132 / reload 4.1 unchanged. ACC_PALADIN_BOSS_MULT boss cut is SEPARATE (stacks). IsSubStr covers base+_up+twins. Has Precision Mode. docs/04/54.
    if ( IsSubStr( weapon_name, "t9_m60" ) )       return 0.286649;   // [S] M60 (Skye CW LMG): USER 2026-07-12 +15% DAMAGE (0.24926 -> 0.286649). Prior: 2026-07-09 +10% LMG-class buff (0.2266 x 1.1) paired with LMG reserve +1 mag (4 -> 5: 500/600 rounds) + the 0.9 LMG move-speed standard; SPREAD +3% best-gun buff (user 2026-06-26). clip 100/120 + large pierce; the big clip makes the 9.7s reload trivial. Slow 0.9 move is its weakness.
    if ( IsSubStr( weapon_name, "t9_rpd" ) )       return 0.13213;   // [C] RPD (Skye CW LMG): USER 2026-07-09 +10% LMG-class buff (0.12012 x 1.1; the M60 got the same +10%, so the "M60 clearly better" gap from 2026-07-06 is preserved), paired with reserve +1 mag (4 -> 5: 375/625 rounds) + the 0.9 LMG move-speed standard. Prior: -10% 2026-07-06; SPREAD -3% 2026-06-26; +25% 2026-06-25. The "bad LMG" - 7.5s reload.
    if ( IsSubStr( weapon_name, "t6_hamr" ) )      return 0.208;     // [B] HAMR (BO2 LMG, user 2026-07-10): sits BETWEEN the M60 (S, 0.24926) and RPD (C, 0.13213). raw _up 390 -> PaP T3 body 527 (RPD 402 / M60 713); DPS 3764 (RPD 3102 / M60 4174). Loc NORMALIZED install-side (tools/prep_hamr_gdt.js, .acc-hamr-orig): neck/torso 1.0 so body = damage x bal x global x papMult like the other LMGs. GDT PaP clip 100 / reserve 500 / reload 6.0 - the fast-reload comfort LMG. IsSubStr covers base+_up+twins. docs/04/25.
    if ( IsSubStr( weapon_name, "s1_rw1" ) )       return 0.15972;   // [A+] RW1 (AW directed-energy pistol, 1000@0.15 raw): USER 2026-07-10 +10% damage BUFF (0.1452 -> 0.15972). Prior 2026-06-27 +20% (-> 0.1452). ALL versions+twins; covers base+PaP+twins. Price tier/box odds UNCHANGED (docs/33 not regenerated).
    if ( IsSubStr( weapon_name, "s1_mk14" ) )      return 0.28809;   // [B-] MK14 (AW semi-auto DMR): USER 2026-06-27 -10% damage nerf, ALL versions+twins (0.291 -> 0.2619: body 87->79/shot, PaP 175->157; full PaP+OC ~1921->1729). Prior SPREAD -3% (0.30 -> 0.291, 2026-06-26). Curated single-target DPS. clip 14/12, reserve 168/240. Clean body loc. Price tier/box odds UNCHANGED (docs/33 not regenerated). docs/04/54.
    if ( IsSubStr( weapon_name, "s1_mors" ) )      return 0.25688;   // [A] MORS (AW charge railgun sniper): USER 2026-07-09 +10% damage buff (0.23353 x 1.1 -> PaP T3 body ~2504), PAIRED with the GDT fireTime 0.064 -> 0.05 buff (base + _up + all 6 twins, backup .acc-mors-ft-orig). History: +15% 2026-07-03 (-> 0.23353); 600-body target 2026-07-02; 0.35 + 0.429 nerfs before that. loc NORMALIZED install-side (body 1.0 / head 5.0). reserve 41/61 (-15% 2026-06-27), clip 1 / reload 1.2. IsSubStr covers base+_up+twins. docs/04/54.
    // Mahem (s1_mahem): EXPLOSIVE rocket launcher - 7000 direct + 2750/1500 splash (PaP 5500/3000), same trap as
    // the old M1911 explosive. acc_weapon_balance_mult scales ALL damage through on_ai_damage INCLUDING explosive,
    // so WITHOUT this line the default 1.0 x the global 2.5x = ~17,500/rocket (trivializes). 7000 x 0.315 x 2.5 =
    // ~5,512 direct + scaled splash = a strong but not game-breaking launcher; ammo-limited self-balances. NOTE:
    // explosive splash + direct both land on a single boss hitbox and there is NO boss-damage cut here (only pellet
    // shotguns get ACC_SHOTGUN_BOSS_MULT) - see the boss-nuke audit (docs/04). (user 2026-06-23)
    if ( IsSubStr( weapon_name, "s1_mahem" ) )     return 0.1099;   // [A] Mahem explosive rocket launcher: USER 2026-07-02 TARGET-DAMAGE nerf - "2500 direct" -> bal = 2500/(raw 7000 x global 3.25) = 0.1099 (splash scales proportionally). Supersedes same-day 0.19 and the 2026-06-29 0.29. IsSubStr matches BASE s1_mahem + PaP s1_mahem_up (both get this), direct + splash.
    // China Lake (t5_china_lake): BO1 EXPLOSIVE grenade launcher - same trap/pattern as the Mahem (7000 raw direct + splash;
    // acc_weapon_balance_mult scales ALL damage incl. explosive). USER 2026-07-05 TARGET: "~20% more than the Mahem" -> 2500 x 1.20
    // = ~3000 direct -> bal = 3000/(raw 7000 x global 3.25) = 0.1319 (splash 700->300 base, PaP 2000->857 inner, scales proportionally).
    // IsSubStr matches BASE t5_china_lake + PaP t5_china_lake_up. Launcher boss-cut in boss_nuke_mult (shares ACC_LAUNCHER_BOSS_MULT).
    if ( IsSubStr( weapon_name, "t5_china_lake" ) ) return 0.1319;   // [A] China Lake explosive grenade launcher (+20% vs Mahem direct). See note above.
    // War Machine (t6_war_machine): BO2 6-round DRUM grenade launcher (user 2026-07-09) - same explosive
    // trap/pattern as the Mahem (7000 raw direct; splash 800/250 base, 1600/500 PaP). Per-shot direct is
    // deliberately BELOW the single-shot launchers (Mahem 2500 / China Lake 3000) because it fires a 6-round
    // drum at 0.25s (PaP: 12-round FULL-AUTO) - the drum burst is the appeal, per-shot power is the cost.
    // TARGET "2000 direct" -> bal = 2000/(raw 7000 x global 3.25) = 0.0879 (splash scales proportionally:
    // base inner ~228, PaP inner ~457). IsSubStr matches base + _up + both fastreload twins.
    if ( IsSubStr( weapon_name, "t6_war_machine" ) ) return 0.10636;   // [A] War Machine drum grenade launcher: USER 2026-07-16 +10% DAMAGE (0.09669 -> 0.10636 = ~2420 direct, splash proportional). Prior: +10% 2026-07-12 (0.0879 -> 0.09669 = ~2200). Per-shot still below the Mahem 2500 by design - the drum burst carries it. See note above.
    // (L4 Siege launcher_multi bal 0.2 REMOVED 2026-07-26 with the gun itself.)
    // EPG-1 (s1_mdl): the AW MDL plasma-lobber reskin (user 2026-07-25). GDT retuned so BASE + _up explosion are EQUAL
    // (the BASE was normalized UP to the _up), so this single bal normalizes both and the +33/67/100% PaP ladder is
    // the sole damage progression (the Mahem model). USER 2026-07-26 +50% DAMAGE: applied in the GDT RAW (inner
    // 900 -> 1350, direct 600 -> 900, outer 125 -> 188 via reskin_mdl_epg.js) so bal stays the convention <1 value:
    // direct now 1350 x global 3.25 x 0.68 = ~2984 (was ~1989). IsSubStr matches base s1_mdl + PaP s1_mdl_up.
    // Launcher boss-cut in boss_nuke_mult.
    if ( IsSubStr( weapon_name, "s1_mdl" ) )         return 0.68;     // [A] EPG-1 plasma-lobber (MDL reskin): ~2984 direct base (+50% 2026-07-26, raw-side), splash scales; PaP _up rides the tier ladder. Tune here.
    // Thundergun (wonder weapon): wind-blast CONE that multi-traces a single boss hitbox. It had NO balance entry
    // at all -> the default 1.0 (zero cut) x the global 2.5x x ~8 cone traces = the ~200k-to-bosses nuke the user
    // hit. NERF -30% (user 2026-06-24, implicit 1.0 -> 0.70). Covers base + thundergun_upgraded (IsSubStr). NOTE:
    // 0.70 cuts ALL targets (incl. its intended chaff clear) but at global 2.5 + multi-hit it STILL nukes bosses
    // (~140k) - the surgical fix for the boss case is a boss-damage cut like is_pellet_shotgun's (see docs/04 audit).
    if ( IsSubStr( weapon_name, "t9_semiauto_cosplay" ) ) return 0.24;  // [S+] Blast-O-Matic (CW DOA energy blaster): USER 2026-07-03 -40% nerf (0.40 -> 0.24). EXCLUDED from the 2026-07-18 all-wonder -10% pass (user: briefly 0.216 same day, reverted - "meant to exclude it"). 3500 raw direct projectile, no splash. 3500x0.24x3.25 = 2,730/hit regular; x0.75 boss/glitch ~2,048; x3.0 shielded ~8,190. The 10% boss per-hit cap backstops bosses. Tune here first.
    if ( IsSubStr( weapon_name, "thundergun" ) )   return 0.45;     // [S+] Thundergun (wonder weapon): NERF to 0.45 (user 2026-06-25, was 0.70). NOTE 2026-07-03: INERT vs the BO1 port - its GDT damage is 0 on both forms, so no thundergun weapon-hit ever passes on_ai_damage's damage<=0 gate. Trash dies to the weaponless FLING (multiplier-immune); bosses take thundergun_boss_blast (maxhealth/divisor). Kept for a future port with real GDT damage.
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

// DORMANT - SUPERSEDED, NOT BROKEN (annotated 2026-07-15 audit). get_oc_flags / has_oc / has_pierce_oc
// are the old PER-FLAG overclock model; the live damage chain is TIER-based (get_oc_tier -> flat damage
// :944, glitch :954, pierce :1120), so none of these three has a caller today. They are kept, not deleted,
// because the STORE IS STILL LIVE AND WRITTEN: _acc_overclocks::set_oc_flag (:570) populates
// player.acc_oc_active[weapon][flag] from ~23 apply_oc_* functions, so any future per-flag effect can read
// it through these helpers. Do NOT re-add a per-hit get_oc_flags() fetch to the damage chain unless
// something actually consumes the result - the previous one was pure waste on every damage event.
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

// Double Tap (specialty_doubletap2) extra-bullet eligibility for the damage temper (user 2026-06-25:
// "all guns EXCEPT thundergun + mahem"). The temper (acc_doubletap_dmg_mult) is ALREADY gated to bullet
// hits (b_bullet && !b_melee), so melee (knife / Action Figure) and thrown/explosive equipment (frag /
// Monkey Bomb / octobomb) are auto-excluded and need NOT be listed here. We only DENY the remaining
// bullet/weapon-MOD weapons that still do NOT fire the engine extra bullet: the Thundergun (wonder-weapon
// wind cone) and the Mahem (rocket launcher). IsSubStr covers base + _up + twins.
// VERIFY-IN-GAME (user "must be 100% correct"): s1_mors (charge railgun) + t8_paladin_hb50 (bolt sniper)
// have non-standard fire - if the double-damage-number check shows they do NOT fire 2 rounds with Double
// Tap, add them here too (else Double Tap would NERF them). Currently INCLUDED per user directive.
function weapon_gets_dt_bullet( w_weapon )
{
    if ( !isdefined( w_weapon ) || !isdefined( w_weapon.name ) ) return false;
    n = w_weapon.name;
    if ( IsSubStr( n, "thundergun" ) ) return false;   // wonder weapon: wind cone, no per-bullet doubling
    if ( IsSubStr( n, "s1_mahem" ) )   return false;   // rocket launcher: explosive, no extra bullet
    if ( IsSubStr( n, "t5_china_lake" ) ) return false;   // China Lake grenade launcher: explosive, no extra bullet (user 2026-07-05; gun removed in the Apex migration but line kept inert)
    if ( IsSubStr( n, "t6_war_machine" ) ) return false;  // War Machine drum grenade launcher: explosive, no extra bullet (user 2026-07-09)
    if ( IsSubStr( n, "s1_mdl" ) )         return false;  // EPG-1 plasma-lobber (MDL reskin): explosive, no extra bullet (user 2026-07-25)
    if ( IsSubStr( n, "apex_beam_rifle" ) ) return false;   // Havoc: Apex energy PROJECTILE rifle, no extra bullet (user 2026-07-06)
    if ( IsSubStr( n, "t9_semiauto_cosplay" ) ) return false;   // Blast-O-Matic: projectile energy blaster, no extra bullet (user 2026-07-03)
    return true;                                        // every other bullet gun gets the extra bullet -> tempered
}

function is_boss_or_elite( actor )
{
    if ( isdefined( actor.acc_is_boss )      && actor.acc_is_boss )      return true;
    if ( isdefined( actor.acc_is_mini_boss ) && actor.acc_is_mini_boss ) return true;
    if ( isdefined( actor.acc_is_elite )     && actor.acc_is_elite )     return true;
    return false;
}

// ---------------------------------------------------------------------------
// Insta-Kill handling (user 2026-06-23): NON-REGULAR enemies take 6x gun damage during Insta-Kill
// (applied in on_ai_damage) instead of the stock instant-kill (which glitched the Glitch Stalker and
// had no impact on Brutus). Regular zombies are still one-shot. NON-REGULAR = our bosses/elites/mini-
// bosses (acc_is_*), stock-boss-flagged enemies (Brutus sets self.is_boss), and glitch zombies.
// ---------------------------------------------------------------------------

function is_non_regular( actor )
{
    if ( !isdefined( actor ) ) return false;
    return is_boss_or_elite( actor ) || IS_TRUE( actor.is_boss ) || IS_TRUE( actor.acc_is_glitch_zombie );
}

// True if `player`'s team has Insta-Kill active (or a personal BGB insta-kill). Team-scoped flag set by
// the stock insta-kill powerup (level.zombie_vars[team]["zombie_insta_kill"], _acc_lui.gsc:388).
function acc_insta_kill_active_for( player )
{
    if ( !isdefined( player ) || !isplayer( player ) ) return false;
    if ( IS_TRUE( player.personal_instakill ) ) return true;
    if ( !isdefined( player.team ) || !isdefined( level.zombie_vars ) ) return false;
    if ( !isdefined( level.zombie_vars[ player.team ] ) ) return false;
    return IS_TRUE( level.zombie_vars[ player.team ][ "zombie_insta_kill" ] );
}

// Stock zm_powerups::check_for_instakill hook (self = the damaged zombie; runs on EVERY zombie hit when
// set). Return FALSE -> check_for_instakill returns without insta-killing; TRUE -> it performs its normal
// one-shot. We skip the instant kill for non-regular enemies (on_ai_damage 6x's them instead); regular
// zombies one-shot as stock. Returns false when no insta-kill is active (a cheap no-op for every hit).
function acc_instakill_override( player )
{
    if ( !acc_insta_kill_active_for( player ) ) return false;   // not an insta-kill hit: no-op
    if ( is_non_regular( self ) )               return false;   // boss/elite/glitch/Brutus: NO instant kill -> 6x in on_ai_damage
    return true;                                                 // regular zombie: stock one-shots it
}

// VERIFIED(acc): melee meansofdeath strings are "MOD_MELEE" /
// "MOD_MELEE_WEAPON_BUTT" / "MOD_MELEE_ASSASSINATE" (stock-API pass; see
// CHANGELOG). Substring match covers all three.
function is_melee_mod( meansofdeath )
{
    if ( !isdefined( meansofdeath ) ) return false;
    return IsSubStr( meansofdeath, "MELEE" );
}

// True for the Action Figure base weapon, its off-hand sibling, and its faster PaP "speed twins" - so they ALL
// one-knife in the AF block above. Add a twin name here when a new speed tier is registered. Replaces the old
// actionfigure_cleave / _cleave_count multi-hit (removed 2026-06-27, user) - PaP scales swing SPEED now, not targets.
// The "_brz" names are the Berzerker implant's parallel tier ladder (boss item 11, 2026-07-11).
function is_action_figure_weapon( weapon )
{
    if ( !isdefined( weapon ) || !isdefined( weapon.name ) ) return false;
    n = weapon.name;
    return ( n == "t8_melee_figure"           || n == "t8_actionfigure_melee"
          || n == "t8_melee_figure_fast1"     || n == "t8_melee_figure_fast2"     || n == "t8_melee_figure_fast3"
          || n == "t8_melee_figure_brz"
          || n == "t8_melee_figure_fast1_brz" || n == "t8_melee_figure_fast2_brz" || n == "t8_melee_figure_fast3_brz" );
}

// BALLISTIC KNIFE matcher (user 2026-07-11): true for the thrown knife - base knife_ballistic, PaP
// knife_ballistic_upgraded, AND the Berzerker _acc_brz twins (substring covers all four).
// *** THE NAME MATCH IS THE ONLY LIVE PATH - NEVER "SIMPLIFY" IT AWAY (review 2026-07-11). *** The pack
// GDT deliberately ships isBallisticKnife "0" on BOTH defs (flag=1 reroutes the knife into the engine's
// melee-slot handling - collides with the stock knife / Action Figure; 0 keeps it a primary-slot
// projectile), so the flag clause below is permanently FALSE for our defs and exists only for
// forward-compat with a future flagged port. Do NOT flip the GDT flag to 1.
function is_ballistic_knife_weapon( weapon )
{
    if ( !isdefined( weapon ) ) return false;
    if ( IS_TRUE( weapon.isBallisticKnife ) ) return true;   // dead for our defs (GDT ships 0) - see header
    return ( isdefined( weapon.name ) && IsSubStr( weapon.name, "knife_ballistic" ) );
}

// BERZERKER (boss item 11): does this melee hit ride one of the item's three surfaces? The damage
// `weapon` on a melee MOD is the swinging weapon for held melee (axe/figure) and the MELEE-SLOT
// def for a knife bash (the Widow's-Wine web trigger proves the slot weapon attributes) - but the
// axe-resolution note above shows melee attribution can also arrive as the HELD gun, so check all
// three surfaces on BOTH the damage weapon and the attacker's state. The regular-knife leg is
// "melee slot IS the berzerker knife" (raw current_melee_weapon field read - what
// zm_utility::set_player_melee_weapon writes - avoiding a new #using): with Widow's Wine active
// its knife owns the slot, so a WW bash correctly gets neither the speed nor the tax (only the
// REGULAR knife is in-spec).
function berzerker_melee_weapon( player, weapon )
{
    if ( isdefined( weapon ) && isdefined( weapon.name ) )
    {
        if ( IsSubStr( weapon.name, "leviathan" ) )       return true;
        if ( IsSubStr( weapon.name, "t8_melee_figure" ) ) return true;
        // Ballistic knife STAB (user 2026-07-11, 4th surface): the held knife's own melee (its GDT
        // meleeAnim/meleeDamage stab, sped +35% by the _acc_brz twins) - the THROW is MOD_IMPACT, not
        // melee, so throws never reach the tax block (this fn is only consulted on b_melee hits).
        if ( IsSubStr( weapon.name, "knife_ballistic" ) ) return true;
        if ( weapon.name == "acc_berzerker_melee" )       return true;
    }
    held = player GetCurrentWeapon();
    if ( isdefined( held ) && isdefined( held.name )
         && ( IsSubStr( held.name, "leviathan" ) || IsSubStr( held.name, "t8_melee_figure" )
              || IsSubStr( held.name, "knife_ballistic" ) ) )
        return true;
    mw = player.current_melee_weapon;
    if ( isdefined( mw ) && isdefined( mw.name ) && mw.name == "acc_berzerker_melee" )
        return true;
    return false;
}

// Debounced trigger for the Berzerker blood tax - shared by the general melee tax block and the
// Leviathan Axe's value-return early-out (the axe returns its fractional damage before the general
// block runs, so it must charge the tax at its own return site or it never pays). Gates on the
// implant flag + the three-surface weapon match; debounced 150ms per attacker so one cleave that
// multi-hits several zombies in a frame taxes ONCE (review fix, user 2026-07-14).
function berzerker_try_tax( attacker, weapon )
{
    if ( !isdefined( attacker ) || !isplayer( attacker ) ) return;
    if ( !IS_TRUE( attacker.acc_item_berzerker ) ) return;
    if ( !berzerker_melee_weapon( attacker, weapon ) ) return;
    if ( isdefined( attacker.acc_brz_tax_cd ) && GetTime() < attacker.acc_brz_tax_cd ) return;
    attacker.acc_brz_tax_cd = GetTime() + 150;
    attacker thread berzerker_melee_tax();
}

// The 5% max-HP blood tax itself (threaded on the ATTACKER). One wait decouples the self-DoDamage
// from the actor-damage callback we were called in (no nested-callback re-entry in the same frame).
// 2-arg DoDamage (undefined attacker, MOD_UNKNOWN) = the decontamination/trench-proven self-damage
// path: real damage -> red flash + engine regen-timer reset; PhD does NOT negate it (MOD_UNKNOWN).
// NEVER self-downs: clamps to leave 1 HP (a rage item that downs its own carrier reads as a bug;
// at 1 HP the swings keep their speed, you just stop paying). Live dvar acc_berzerker_hp_frac.
function berzerker_melee_tax()    // self = player
{
    self endon( "disconnect" );
    wait( 0.05 );
    if ( !isdefined( self ) || !IsAlive( self ) ) return;
    if ( !IS_TRUE( self.acc_item_berzerker ) ) return;      // unequipped during the wait
    frac = getdvarfloat( "acc_berzerker_hp_frac", 0.05 );
    if ( frac <= 0 ) return;
    maxhp = 100;
    if ( isdefined( self.maxhealth ) && self.maxhealth > 0 ) maxhp = self.maxhealth;
    dmg = int( maxhp * frac );
    if ( dmg < 1 ) dmg = 1;

    // SURVIVABLE FLOOR - stop taxing at ACC_BRZ_TAX_FLOOR_FRAC of MAX HP (user 2026-07-15, 50%).
    // *** THIS REPLACES THE OLD 1-HP FLOOR, WHICH WAS THE SELF-KILL BUG - DO NOT "RESTORE" IT. ***
    // The old clamp was `if ( self.health <= dmg ) dmg = self.health - 1;`. It read as a safety net
    // ("can never down you") but did the opposite: it CONVERGED on exactly 1 HP and PINNED you there
    // (health 20 -> 8 -> 1 -> 0-dmg skip). Because the tax is deliberately REAL damage - it resets the
    // engine HP-regen timer, which is the whole point of it (see the header above) - re-firing every
    // 150ms while you cleave a crowd meant you could never regen off 1 HP. Any zombie melee then downed
    // you. That is the reported "Widow's Wine kills me" bug (user 2026-07-15): the WW contact explosion
    // is MOD_GRENADE_SPLASH and never reaches this tax at all (is_melee_mod gates both call sites) - it
    // just happens to be triggered BY the same zombie melee that finishes off a 1-HP Berzerker carrier,
    // so it looked like the culprit. Scales with crowd size because that is the CONNECT RATE (every
    // swing lands in a crowd; whiffs are free), not per-victim damage.
    // Floor semantics are unchanged in spirit - at/below it you keep the +35% speed and stop paying -
    // only the value moved off the one-tap cliff. Live dvar acc_berzerker_hp_floor_frac.
    floor_frac = getdvarfloat( "acc_berzerker_hp_floor_frac", ACC_BRZ_TAX_FLOOR_FRAC );
    if ( floor_frac < 0 )   floor_frac = 0;
    if ( floor_frac > 0.9 ) floor_frac = 0.9;   // sanity clamp: never let a dvar typo disable the tax outright
    floor_hp = int( maxhp * floor_frac );
    if ( floor_hp < 1 ) floor_hp = 1;           // laststand (health 1) still no-ops via the check below
    if ( !isdefined( self.health ) ) return;
    if ( self.health <= floor_hp ) return;                          // already at/below the floor - swing free
    if ( self.health - dmg < floor_hp ) dmg = self.health - floor_hp;   // partial tax down TO the floor, never through it
    if ( dmg < 1 ) return;
    self DoDamage( dmg, self.origin );
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

// Nuclear Energy item (boss item 9, user 2026-07-07): which weapons count as "energy" for its +15% buff -
// the directed-energy / beam / plasma family (the AW/CW energy guns + the Havoc + the Thundergun cone).
// Substring match like acc_weapon_balance_mult so base + _up + all perk twins are covered. The EXPLOSIVE
// half of the buff is handled separately by is_explosive_mod(meansofdeath) (MOD-based). Keep this list in
// sync with the "energy"-tagged entries in acc_weapon_balance_mult.
function is_energy_weapon( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "apex_beam_rifle" ) )     return true;   // Havoc (energy projectile rifle)
    if ( IsSubStr( weapon_name, "s1_tac19" ) )            return true;   // Tac-19 (AW energy blast SG)
    if ( IsSubStr( weapon_name, "s1_ae4" ) )              return true;   // AE4 (AW energy AR)
    if ( IsSubStr( weapon_name, "t9_semiauto_cosplay" ) ) return true;   // Blast-O-Matic (CW energy blaster)
    if ( IsSubStr( weapon_name, "s1_cel3" ) )             return true;   // CEL-3 Cauterizer (AW directed-energy/thermal spread SG, 2026-07-11) - +10% Plasma Generator synergy on a B-tier gun
    if ( IsSubStr( weapon_name, "apex_tripletake" ) )     return true;   // Triple Take (Apex 3-bolt energy sniper, 2026-07-11) - Plasma Generator is its signature synergy (docs/04)
    if ( IsSubStr( weapon_name, "apex_lstar" ) )          return true;   // THE CYBERJACK (L-STAR plasma LMG, docs/43, 2026-07-17) - ENERGY class: Plasma Generator synergy; High Caliber excludes it
    if ( IsSubStr( weapon_name, "apex_peacekeeper" ) )    return true;   // Peacekeeper (Apex lever shotgun) - MOVED to energy so Plasma buffs it, not High Caliber (user 2026-07-14)
    // NOTE (user 2026-07-14): RW1 (s1_rw1) moved OUT of energy -> it's now a BULLET gun (High Caliber);
    // Thundergun moved OUT -> it is now NONE of the three damage items (with the Fire Bow + Winter's Howl).
    return false;
}

// High Caliber Rounds item (boss item 12, user 2026-07-14): which HELD weapons the +25% bullet buff
// actually helps - the ballistic guns. This is the held-gun MIRROR of the damage gate (which is MOD-based:
// b_bullet && !is_energy_weapon), used by _acc_gun_badges::pred_high_caliber to light the chip only on
// weapons the buff applies to (same idea as pred_nuclear reading is_energy_weapon). A weapon is a "bullet
// gun" iff it is NOT energy (Plasma's domain), NOT melee, NOT an explosive launcher, and NOT one of the
// three unbuffed wonders - exactly the classes whose hits never carry a plain bullet MOD. Keep in sync.
function weapon_is_bullet_gun( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( is_energy_weapon( weapon_name ) )               return false;   // energy family -> Plasma, not High Caliber (incl. Peacekeeper; RW1 is NO LONGER here -> it IS a bullet gun)
    if ( IsSubStr( weapon_name, "leviathan" ) )          return false;   // Leviathan Axe (melee)
    if ( IsSubStr( weapon_name, "t8_melee_figure" ) )    return false;   // Action Figure (melee)
    if ( IsSubStr( weapon_name, "knife" ) )              return false;   // Ballistic Knife + regular knife (melee)
    if ( IsSubStr( weapon_name, "bare_hands" ) )         return false;   // Berzerker bare-fist melee slot
    if ( IsSubStr( weapon_name, "s1_mahem" ) )           return false;   // Mahem launcher (explosive)
    if ( IsSubStr( weapon_name, "war_machine" ) )        return false;   // War Machine drum GL (explosive)
    if ( IsSubStr( weapon_name, "s1_mdl" ) )             return false;   // EPG-1 plasma-lobber (explosive)
    if ( weapon_is_unbuffed_wonder( weapon_name ) )      return false;   // Fire Bow / Thundergun / Winter's Howl = NONE of the three items (user 2026-07-14)
    return true;                                                          // remaining held guns fire plain bullets
}

// Warhead Bomber item (boss item 13, user 2026-07-14): which HELD weapons carry the +20% explosive buff -
// the explosive PRIMARIES (the launchers). Warhead's damage gate is MOD-based (is_explosive_mod), which
// also catches thrown grenades + projectile splash that aren't a held "gun"; this held-gun mirror (used by
// _acc_gun_badges::pred_warhead) lights the chip on the launchers. The elemental bows are DELIBERATELY out
// (user 2026-07-14: Fire Bow is none of the three items - see weapon_is_unbuffed_wonder).
function weapon_is_explosive_gun( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "s1_mahem" ) )     return true;   // Mahem guided launcher
    if ( IsSubStr( weapon_name, "war_machine" ) )  return true;   // War Machine drum grenade launcher
    if ( IsSubStr( weapon_name, "s1_mdl" ) )         return true;   // EPG-1 plasma-lobber - MDL reskin (user 2026-07-25; Warhead Bomber +20% verified applying, user check 2026-07-26)
    return false;
}

// The three wonder weapons the user placed OUTSIDE all three damage items (user 2026-07-14): Fire Bow /
// Thundergun / Winter's Howl. High Caliber (bullet MOD) and Plasma (is_energy_weapon) already miss them;
// this is what the WARHEAD damage gate + the High-Caliber badge mirror check so their projectile/energy
// MODs never pick up the +20% explosive layer or light a chip. They intentionally get NO implant synergy.
function weapon_is_unbuffed_wonder( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "bow" ) )        return true;   // elemental bows (Fire Bow etc.)
    if ( IsSubStr( weapon_name, "thundergun" ) ) return true;   // Thundergun (wonder energy cone)
    if ( IsSubStr( weapon_name, "freezegun" ) )  return true;   // Winter's Howl (cryo freeze cannon)
    if ( IsSubStr( weapon_name, "special_discgun" ) ) return true;   // D13 Sector ricochet disc launcher (2026-07-24)
    if ( IsSubStr( weapon_name, "skull_gun" ) )       return true;   // Skull of Nan Sapwe hero beam (2026-07-24)
    if ( IsSubStr( weapon_name, "dragon_gauntlet" ) ) return true;   // Dragon Gauntlet hero flame (2026-07-24)
    return false;
}

// ---------------------------------------------------------------------------
// PER-BOSS WEAKNESS gate (block 0c5, user 2026-07-16): does this hit land on the target boss's
// signature weakness class? One boss = one class; a match takes acc_boss_weakness_mult (x1.2).
// Identity flags (each set at that boss's single spawn chokepoint, so paradise/roster/debt spawns
// are all covered): acc_is_brutus (nsz_brutus.gsc pack spawn) / acc_is_panzer (_acc_boss_panzer
// identity block) / acc_is_rogue_protector (_acc_civil_protector) / acc_is_avogadro
// (_acc_boss_avogadro) / acc_is_phantom (_acc_boss_phantom).
// ---------------------------------------------------------------------------
function boss_weakness_applies( target, w_weapon, meansofdeath, b_melee )
{
    w_name = undefined;
    if ( isdefined( w_weapon ) && isdefined( w_weapon.name ) ) w_name = w_weapon.name;

    // Brutus / Trench Warden <- SNIPERS.
    if ( IS_TRUE( target.acc_is_brutus ) )
        return weapon_is_sniper( w_name );

    // Panzer <- EXPLOSIVE or ENERGY. Explosive scoped EXACTLY like 0c4 (is_explosive_mod minus the
    // unbuffed wonders - their boss damage models bypass the chain anyway); energy via the shared
    // is_energy_weapon list. A gun matching both (Havoc / Blast-O-Matic projectile MODs) applies ONCE.
    if ( IS_TRUE( target.acc_is_panzer ) )
    {
        if ( isdefined( w_name ) && weapon_is_unbuffed_wonder( w_name ) ) return false;
        if ( isdefined( w_name ) && is_energy_weapon( w_name ) ) return true;
        return is_explosive_mod( meansofdeath );
    }

    // Rogue Protector <- SHOTGUNS (the same 5-gun set as the 0b pellet boss cut; net vs Rogue =
    // 0.25 x 1.2 = 0.30 - shotguns still under-perform on bosses, just 20% less so on THIS one).
    if ( IS_TRUE( target.acc_is_rogue_protector ) )
        return is_pellet_shotgun( w_weapon );

    // Avogadro <- MELEE (normal-chain melee: knife bash / Bowie / Berzerker fists / ballistic stab).
    // The Leviathan Axe + Action Figure fractional paths value-return BEFORE the chain, so their
    // fixed boss hits-to-kill stay exact by design.
    if ( IS_TRUE( target.acc_is_avogadro ) )
        return IS_TRUE( b_melee );

    // Phantom <- SMGs + ARs.
    if ( IS_TRUE( target.acc_is_phantom ) )
        return weapon_is_smg( w_name ) || weapon_is_ar( w_name );

    return false;
}

// SNIPERS for the Brutus weakness = the docs/25 "Marksman & Sniper" roster. IsSubStr covers
// base + _up + all perk/recoil twins (the acc_weapon_balance_mult convention).
function weapon_is_sniper( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "s1_mors" ) )         return true;   // MORS (AW charge railgun sniper)
    if ( IsSubStr( weapon_name, "apex_tripletake" ) ) return true;   // Triple Take (Apex energy sniper; the 2 side bolts are MagicBullets of the HELD gun so all 3 bolts match)
    if ( IsSubStr( weapon_name, "s1_mk14" ) )         return true;   // MK14 (AW DMR - the Marksman half of the docs/25 class)
    if ( IsSubStr( weapon_name, "t8_paladin_hb50" ) ) return true;   // Paladin HB50 (out of the pool since the Apex migration - kept for restore, inert while absent)
    return false;
}

// SMGs for the Phantom weakness (docs/25 SMG roster).
function weapon_is_smg( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "s4_ppsh41" ) )       return true;   // PPSH-41
    if ( IsSubStr( weapon_name, "t9_ak74u" ) )        return true;   // AK-74u
    if ( IsSubStr( weapon_name, "apex_alternator" ) ) return true;   // Alternator (base + _up)
    if ( IsSubStr( weapon_name, "apex_prowler" ) )    return true;   // Prowler
    if ( IsSubStr( weapon_name, "t6_chicom_cqb" ) )   return true;   // Chicom CQB (replaced by the Prowler 2026-07-06 - kept for restore, inert while absent)
    return false;
}

// ARs for the Phantom weakness (docs/25 AR roster - includes the two energy ARs; the class overlap
// with the Panzer energy weakness is fine, each boss only reads its OWN class).
function weapon_is_ar( weapon_name )
{
    if ( !isdefined( weapon_name ) ) return false;
    if ( IsSubStr( weapon_name, "t9_xm4" ) )          return true;   // XM4
    if ( IsSubStr( weapon_name, "t9_ak47" ) )         return true;   // AK-47 (no substring clash with t9_ak74u)
    if ( IsSubStr( weapon_name, "t9_grav" ) )         return true;   // Grav
    if ( IsSubStr( weapon_name, "s1_ae4" ) )          return true;   // AE4 (energy AR)
    if ( IsSubStr( weapon_name, "apex_beam_rifle" ) ) return true;   // Havoc (energy projectile AR)
    if ( IsSubStr( weapon_name, "t9_m16" ) )          return true;   // M16 (retired 2026-07-11 - kept for restore, inert while absent)
    return false;
}

// Weapons whose damage is intentionally NOT scaled by headshot multiplier.
// Source of truth: docs/04_weapons.md.
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
    // crowd-control gun (docs/04). Inert until the AW pack is installed.
    if ( name == "s1_tac19" ) return true;
    if ( name == "t6_olympia" ) return true;   // Olympia (BO2 SG): flat-damage crowd control like Tac-19 (2026-06-15)
    if ( name == "t9_streetsweeper" ) return true;   // Streetsweeper (CW full-auto drum SG, 2026-07-04): flat-damage crowd gun, headshot-excluded like the other shotguns
    if ( name == "s1_cel3" ) return true;   // CEL-3 Cauterizer (AW triple-barrel spread SG, 2026-07-05): flat-damage crowd gun, headshot-excluded like the other shotguns
    if ( name == "apex_peacekeeper" ) return true;   // Peacekeeper (Apex 11-12 pellet lever SG, 2026-07-06): flat-damage crowd gun, headshot-excluded like the other shotguns
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
    if ( name == "t9_streetsweeper" ) return true;   // Streetsweeper (CW full-auto drum SG, 12 pellets, 2026-07-04): gets the ACC_SHOTGUN_BOSS_MULT cut like the other pellet shotguns (its balance line promises it)
    if ( name == "s1_cel3" ) return true;   // CEL-3 Cauterizer (AW triple-barrel spread SG, 12 pellets PaP, 2026-07-05): gets the ACC_SHOTGUN_BOSS_MULT cut like the other pellet shotguns
    if ( name == "apex_peacekeeper" ) return true;   // Peacekeeper (Apex 11-12 pellet SG, 2026-07-06): gets the ACC_SHOTGUN_BOSS_MULT cut like the other pellet shotguns
    return false;
}

// Boss-only damage cut for the high-burst / multi-hit weapons that bypass the pellet-shotgun cut (user
// 2026-06-24 boss-nuke audit, docs/04): the Thundergun cone, the Mahem rocket (direct + splash), and the
// Paladin HB50 sniper (one-shot single-target boss-killer - reined in vs bosses on user request). Returns a
// REDUCTION (<1) applied ONLY vs bosses/mini-bosses (the caller gates on acc_is_boss/_mini_boss), or 1.0 if
// the weapon isn't one of them. Root-name match so it covers base + PaP (_upgraded / _up). Per-weapon dvars
// so each can be dialled independently.
function boss_nuke_mult( w_weapon )
{
    if ( !isdefined( w_weapon ) ) return 1.0;
    name = weapon_root_name( w_weapon );
    if ( !isdefined( name ) ) return 1.0;
    if ( name == "thundergun" )      return getdvarfloat( "acc_thundergun_boss_mult", ACC_THUNDERGUN_BOSS_MULT );   // INERT vs the BO1 port (GDT damage 0; bosses use thundergun_boss_blast) - see the define's note.
    if ( name == "s1_mahem" )        return getdvarfloat( "acc_launcher_boss_mult",   ACC_LAUNCHER_BOSS_MULT );
    if ( name == "t5_china_lake" )   return getdvarfloat( "acc_launcher_boss_mult",   ACC_LAUNCHER_BOSS_MULT );   // China Lake grenade launcher: same launcher boss-cut as the Mahem (user 2026-07-05)
    if ( name == "t6_war_machine" )  return getdvarfloat( "acc_launcher_boss_mult",   ACC_LAUNCHER_BOSS_MULT );   // War Machine drum grenade launcher: same launcher boss-cut (user 2026-07-09; a 6-round drum would boss-nuke without it)
    if ( name == "s1_mdl" )          return getdvarfloat( "acc_launcher_boss_mult",   ACC_LAUNCHER_BOSS_MULT );   // EPG-1 plasma-lobber (MDL reskin): same launcher boss-cut (user 2026-07-25)
    if ( name == "t8_paladin_hb50" ) return getdvarfloat( "acc_paladin_boss_mult",    ACC_PALADIN_BOSS_MULT );
    return 1.0;
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
