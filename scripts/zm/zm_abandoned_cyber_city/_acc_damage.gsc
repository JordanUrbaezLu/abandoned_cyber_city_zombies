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
// 0.6 -> base DT lands ~1.6x DPS (2 bullets x 0.6 x 1.33 RoF). Live dvar acc_doubletap_dmg_mult. Applied
// ONLY to weapon_gets_dt_bullet() guns (an explicit ALLOW-LIST - never to a weapon that lacks the extra bullet).
#define ACC_DOUBLETAP_DMG_MULT 0.6

// Mega Double Tap = "Gun Slinger" (REWORKED 2026-07-04). The old Mega effect was a fire-rate + weapon-swap
// twin ("fastfire"); that twin axis was REMOVED entirely (docs/10, docs/21). Mega Double Tap's ONLY benefit
// is now a DAMAGE buff: the extra-bullet temper EASES from x0.6 -> x0.8, so Mega DT lands ~2.1x DPS
// (2 bullets x 0.8 x 1.33 RoF) vs base DT's ~1.6x. Runtime-only (read live via has_mega_perk at damage time)
// so no weapon-variant twin is needed. Live dvar acc_doubletap_mega_dmg_mult.
#define ACC_DOUBLETAP_MEGA_DMG_MULT 0.8

// Mega Flopper (PhD Slider): +15% explosive damage (user 2026-06-18, nerfed from +20%). ADDS
// into the bonus sum like every other layer (so +0.15 on the effective multiplier). GSC-only -
// a damage-dealt scalar here, NOT a weapon-GDT stat, so no twin weapon is needed.
#define ACC_MEGA_FLOPPER_EXPLOSIVE_MULT 1.15

// Nuclear Energy boss item (docs/09, user 2026-07-07): +15% damage to EXPLOSIVE + ENERGY hits while the
// item is implanted (attacker.acc_item_nuclear, set by _acc_boss_items). ADDS into the bonus sum exactly
// like the Mega Flopper explosive layer (+0.15 on the effective multiplier). GSC-only - no weapon twin.
#define ACC_ITEM_NUCLEAR_MULT 1.15

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
#define ACC_THUNDERGUN_BOSS_MULT 0.20   // INERT vs the BO1 port (GDT damage 0) - superseded for bosses by thundergun_boss_blast (maxhealth/20..11). Was: ~140k x 0.20 -> ~28k/blast.
#define ACC_LAUNCHER_BOSS_MULT   0.50   // Mahem vs bosses: ~5,512 direct (post -10%) x 0.50 -> ~2,756/rocket + splash; ammo-limited.
#define ACC_PALADIN_BOSS_MULT    0.50   // Paladin HB50 sniper vs bosses (user 2026-06-24): one-shot single-target boss-killer; ammo/RoF-limited (not a burst nuke) but reined in vs bosses too. On top of its 0.49 balance mult (B tier, user 2026-06-24) -> ~half its boss damage. Live dvar acc_paladin_boss_mult.

// BOSS-DAMAGE HARD CAP (user 2026-06-24, boss-nuke audit): the catch-all backstop. The weapon-name boss cuts
// above CANNOT see weaponless scripted DoDamage (the stock Thundergun fling does DoDamage(self.health+666) -
// the REAL ~200k one-shot - and the octobomb pull does DoDamage(target.health)), and even for weapon hits a
// multiplicative cut is defeated by PaP/Cyberware/Overclock investment + the insta-kill x6. So a FINAL clamp:
// a single player hit on a boss/mini-boss caps at this fraction of its maxhealth, AFTER every multiplier.
#define ACC_BOSS_PER_HIT_CAP_PCT 0.10   // 10% of boss maxhealth/hit -> >=10 hits to kill any boss. Live dvar acc_boss_per_hit_cap_pct (0 = off).
// LEVIATHAN AXE boss specialty (user 2026-07-07): the GoW axe is THE boss-killer melee. Its per-hit boss
// cap = 1/(hits-to-kill), so it kills ANY boss in a fixed number of hits regardless of boss HP, and each PaP
// TIER lands harder (fewer hits): base 17 / T1 14 / T2 12 / T3 8. Live dvars acc_leviathan_hits_t0..t3.
// [acc] user 2026-07-09 ~+20% DAMAGE BUFF: hit counts cut ~1/1.2 from 20/17/14/10 (shielded 5 -> 4 too;
// normal zombies were already 1-hit, so the buff lands on the boss/elite counts).
#define ACC_LEVIATHAN_HITS_T0 17   // unpacked
#define ACC_LEVIATHAN_HITS_T1 14
#define ACC_LEVIATHAN_HITS_T2 12
#define ACC_LEVIATHAN_HITS_T3 8    // max PaP
// INSTA-KILL vs bosses = exactly THIS multiple of a normal hit (user 2026-06-25: "2x not 6x"). Applied BOTH as
// the damage multiplier AND as a cap scale (x2 cap), so a high-damage gun (Mahem/sniper) that's already at the
// 10% cap deals 2x10%=20% during insta-kill = a true 2x, not the 6x that the 10% cap was silently clamping to 4k.
// Live dvar acc_instakill_boss_mult.
#define ACC_INSTAKILL_BOSS_MULT 2

// Kinetic Battery next-shot multiplier (docs/09_boss_items.md; tuning lever:
// drop to 2x if Battery feels runaway). Charge ACCRUAL is not this file's
// job - see docs/15 battery-charge-per-10-kills.
#define ACC_ITEM_BATTERY_DAMAGE_MULT 3.0

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
    // base = 20, -3 per tier -> 17 / 14 / 11.
    tier = 0;
    w = player GetCurrentWeapon();
    if ( isdefined( w ) && w != level.weaponNone && isdefined( w.name ) && IsSubStr( w.name, "thundergun" ) )
        tier = acc_pap_levels::get_tier( player, w );
    if ( tier < 0 ) tier = 0;
    if ( tier > 3 ) tier = 3;
    divisor = 20 - ( 3 * tier );

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
    //   boss 17/14/12/8 by PaP tier (user 2026-07-09 +20% buff, was 20/17/14/10). The anti-elite counts
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
            n = getdvarint( "acc_af_boss_hits", 30 );
            if ( n < 1 ) n = 1;
            dmg = int( self.maxhealth / n );                    // 1/30 of MAX health -> 30 hits to kill, any boss
            if ( dmg < 1 ) dmg = 1;
            feed_dmg_number( attacker, dmg, false );
            return dmg;
        }
        if ( !is_boss_or_elite( self ) )                        // regular zombie -> always one-knife
        {
            // RETURN before the function-end damage-number feed, so feed it here (user 2026-06-23: "knife a
            // zombie and not see the damage").
            if ( isdefined( self.health ) ) feed_dmg_number( attacker, self.health, false );
            return self.health + 1000;
        }
        // else: an ELITE -> fall through to normal melee handling below.
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
        // Exo Suit tier - +acc_exo_melee_per_tier per tier (default +30%/tier -> +150% at T5). This is
        // the exo's "body" counterpart to the gun Overclock's flat damage (effect 1): guns get oc_tier (0 on
        // melee), melee gets exo_tier. Melee-ONLY (b_melee), so guns are untouched. Additive layer like the
        // rest. The Cyberware Amplifier deliberately skips melee (above); the Exo Suit IS the melee scaler.
        if ( b_melee && isdefined( attacker.acc_exo_tier ) && attacker.acc_exo_tier > 0 )
        {
            bonus_sum += 1.0 + ( attacker.acc_exo_tier * getdvarfloat( "acc_exo_melee_per_tier", 0.30 ) );
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

        // Nuclear Energy (boss item 9, user 2026-07-07): +15% damage on EXPLOSIVE (is_explosive_mod) OR
        // ENERGY (is_energy_weapon) hits while the item is implanted. Additive layer like the Mega Flopper
        // explosive +15% above. Flag set by _acc_boss_items::apply_nuclear_energy (plain player field).
        if ( IS_TRUE( attacker.acc_item_nuclear )
             && ( is_explosive_mod( meansofdeath )
                  || ( isdefined( weapon ) && isdefined( weapon.name ) && is_energy_weapon( weapon.name ) ) ) )
        {
            bonus_sum += ACC_ITEM_NUCLEAR_MULT;
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
    if ( isdefined( self.acc_elite_front_damage_resist )
         && ( b_bullet || b_melee )
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
    // -----------------------------------------------------------------------
    if ( b_player_attacker && IS_TRUE( self.b_is_apothicon_fury )
         && isdefined( weapon ) && isdefined( weapon.name )
         && ( IsSubStr( weapon.name, "elemental_bow" ) || IsSubStr( weapon.name, "bow_demongate" ) )
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
    if ( IsSubStr( weapon_name, "apex_alternator_up" ) ) return 0.71874;   // [A+] Alternator PaP: USER 2026-07-06 +10% DAMAGE (0.54 -> 0.594; 170 x 0.594 -> body T3 ~657). Also RoF -20% (fireTime 0.107->0.134) + clip 26->30 (GDT), PaP cost MID->BOT. Prior: 0.27 -> 0.54. The payoff gun.
    if ( IsSubStr( weapon_name, "apex_alternator" ) )       return 0.1815;   // [trash] Alternator BASE: 100 x 0.15 x 3.25 = ~49/bullet (3-4 bullets/r1 zombie) - trash-but-shootable (0.05 = 16/bullet was broken-feeling). Covers base.
    if ( IsSubStr( weapon_name, "apex_peacekeeper" ) )      return 0.41624;  // [S] Peacekeeper (Apex 11->12-pellet lever SG): USER 2026-07-07 +10% DAMAGE on top of the global +10% (0.344 -> 0.3784 -> 0.41624). Prior: 2026-07-06 -20% ALL-SHOTGUN NERF (0.43 -> 0.344). POWER-FIRST top shotgun (user #6), DELIBERATELY not DPS-tuned ("one pump machine"). Headshot-excluded + pellet-boss-cut. Also RoF +25% (fireTime 0.2->0.16 GDT).
    if ( IsSubStr( weapon_name, "apex_prowler" ) )          return 0.451;   // [B] Prowler (Apex full-auto SMG): 135 x 0.41 -> body T3 ~360, ~2375 sustained (was 0.21 = 1215, worst automatic on the map). Sits above Grav(B+ 2087), below AK-74u(A 2487).
    if ( IsSubStr( weapon_name, "apex_g2a4" ) )             return 0.5742;  // [C+] G7 Scout (semi marksman): USER 2026-07-06 +20% DAMAGE (0.435 -> 0.522; body T3 ~644, head ~1289) + clip 15->20 + reserve 150->200 (GDT). Prior: 0.40 -> 0.58 -> 0.435. Rewarded per-shot.
    if ( IsSubStr( weapon_name, "apex_beam_rifle" ) )       return 0.39797;  // [A] Havoc (energy PROJECTILE rifle, full-auto): USER 2026-07-08 +10% DAMAGE (0.36179 -> 0.39797; 300 x 0.39797 -> body T3 ~776, head ~1164, ~4060 sustained). History: 0.21 -> 0.26 -> 0.299 -> 0.36179 -> 0.39797. Projectile -> no DT extra bullet; special OC; per-hit cap backstops bosses. IsSubStr covers base + _up + all 6 twins.
    if ( IsSubStr( weapon_name, "pistol_standard" ) ) return 1.10;  // [start] MR6/M1911 start pistol (level.start_weapon): was default 1.0 (uncut); +10% all-gun buff (user 2026-07-07). IsSubStr covers pistol_standard + _upgraded (laststand). Only >1.0 entry - an amplify, not a cut.
    if ( IsSubStr( weapon_name, "elemental_bow_demongate" ) ) return 1.0;  // [wonder] FIRE BOW (HB21 demongate, added 2026-07-07): pack-native damage x global 3.25; the boss per-hit cap backstops. PLAYTEST-TUNE HERE (charged-shot AoE is script DoDamage inside the pack's weap script - only the arrow hit routes through this mult).
    if ( IsSubStr( weapon_name, "leviathan" ) )               return 1.0;  // [wonder] LEVIATHAN AXE (WetEgg GoW melee, added 2026-07-07): melee weapon damage; base + leviathan_up covered by IsSubStr. PLAYTEST-TUNE HERE.
    if ( IsSubStr( weapon_name, "t6_fiveseven" ) ) return 0.27742;   // [C-] Five-Seven (start pistol): ~50 eff/shot. SPREAD -3% worst-gun nerf (0.26 -> 0.2522, user 2026-06-26). Mobile starter, fast reload + 14 clip = decent sustain, but weak dmg + 56 reserve = C- (user 2026-06-21).
    if ( IsSubStr( weapon_name, "s1_asm1" ) )      return 0.21;     // [B] ASM1 - RETIRED 2026-07-03 (user; gun removed from zone/CSV/pools - this entry is inert and STAYS for easy restore). ~401 DPS, v2 B (6.5).
    if ( IsSubStr( weapon_name, "s1_tac19" ) )     return 0.49929;  // [S] Tac-19 (AW energy SG): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.5674 -> 0.4539; per-pellet T3 body ~514). Prior: 2026-07-05 -10% (0.6304 -> 0.5674), SPREAD +3% (0.612 -> 0.6304). Tier label kept (curated e). 12-pellet crowd king (headshot-excluded); vs bosses see ACC_SHOTGUN_BOSS_MULT. docs/04.
    if ( IsSubStr( weapon_name, "t6_olympia" ) )   return 0.41734;  // [C] Olympia (BO2 double-barrel SG): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.4743 -> 0.3794). Prior: SPREAD -3% worst-gun nerf (0.489 -> 0.4743, 2026-06-26) on the -50% max-scale fix (0.9775 -> 0.489, 2026-06-25). 110/pellet x ~8, 2-round clip + 3.9s reload = worst sustain. Headshot-excluded.
    if ( IsSubStr( weapon_name, "t9_streetsweeper" ) ) return 0.106392;  // [A] Streetsweeper (CW full-auto drum SG, 12 pellets PaP): USER 2026-07-06 -20% ALL-SHOTGUN NERF (0.0930 -> 0.0744). Prior: 2026-07-05 -15%, -10%, -10% (0.135 -> 0.1148 -> 0.1033 -> 0.0930). ALSO clip/mag -25% install-side (_up clip 18->14, maxAmmo 12->9, reserve 216->126). _up per-pellet T3 body ~294 (x12 = ~3528 point-blank). Score drops with the ammo cut (see compute_gun_tiers); still headshot-excluded + pellet-boss-cut. Tune HERE for power.
    if ( IsSubStr( weapon_name, "s1_cel3" ) )      return 0.432;    // [B] CEL-3 Cauterizer (AW triple-barrel full-auto spread SG, 12 pellets PaP): USER 2026-07-07 -20% DAMAGE (0.54 -> 0.432; EXCLUDED from the same-day global +10% gun buff). Prior: 2026-07-06 -20% ALL-SHOTGUN NERF (0.675 -> 0.54). Prior (2026-07-05): +100% then +25% (0.27 -> 0.54 -> 0.675). loc NORMALIZED install-side (torso 1.0) so per-pellet body = raw x bal x global. _up 200 raw -> per-pellet T3 body ~562 (x12 = ~6744 point-blank). Curated effDPS e=395 keeps the papScore label at B. Headshot-excluded + pellet-boss-cut. Tune HERE for power.
    if ( IsSubStr( weapon_name, "t9_ak47" ) )      return 0.29579;  // [S] AK-47 (200@0.08 = 2500 raw): USER 2026-07-06 +15% DAMAGE (0.2338 -> 0.2689). Prior: SPREAD +3% (0.227 -> 0.2338, 2026-06-26) on the AK swap (0.186 -> 0.227 -> TOP/S). Solid DPS + decent reload. Focus Fire ability.
    if ( IsSubStr( weapon_name, "t9_xm4" ) )       return 0.231;    // [S] XM4 (CW full-auto AR, base 200@0.083 = 2410 raw): ADDED 2026-07-04. mult 0.21 -> effDPS e=506 -> papScore 7.86 = S (docs/33). _up 360 -> T3 body ~491, head ~1229 (in the S cohort: AK-47 410, PPSH 450, M60 589). Big 70-clip/750-RPM. Tune HERE for power.
    if ( IsSubStr( weapon_name, "t9_grav" ) )      return 0.165;    // [B+] Grav (CW full-auto AR): the GALIL's stats grafted onto the CW model/sfx (user 2026-07-05, t6_galil->t9_grav, same AK-47-style migration). Identical to the Galil: 220@0.08 = 2750 raw x 0.15 = ~412 DPS - mult + tier unchanged, only the model/anims/sounds are new.
    if ( IsSubStr( weapon_name, "s1_ae4" ) )       return 0.341;    // [B] AE4 (AW energy AR, 160@0.12 = 1333 raw): ~413 DPS. Formula reads A- (6.8) but user-curated to B 2026-06-21 (mid DPS; fast reload + pierce + 25 clip + 200 reserve keep it top-B).    // +6 box guns (user, 2026-06-15). Mults land each near the ~500 eff-DPS box band
    // (raw DPS = damage/fireTime from the Skye GDTs). IsSubStr covers base + PaP + twins.
    if ( IsSubStr( weapon_name, "s4_ppsh41" ) )    return 0.24475;  // [S] PPSH-41 (VG smg, 155@0.063 = 2460 raw): USER 2026-07-06 -10% DAMAGE (0.2472 -> 0.2225). Prior: SPREAD +3% (0.24 -> 0.2472, 2026-06-26) on the 2026-06-24 +20% buff. Clip 40/54. IsSubStr covers base + _up + all perk twins.
    if ( IsSubStr( weapon_name, "t6_chicom_cqb" ) ) return 0.28325;  // [S+] Chicom CQB (BO2 3-round-burst SMG, 130@0.048 within burst; ~512 sustained eff w/ the 0.1s burst delay): box's #1 gun. SPREAD +3% best-gun buff (0.25 -> 0.2575, user 2026-06-26, papScore ~8.18). clip 36/56, reserve 180/448 uncut. cu-curated. IsSubStr covers base + _up + twins.
    if ( IsSubStr( weapon_name, "t9_ak74u" ) )     return 0.2024;  // [A] AK-74u (BO1 smg, 180@0.08 = 2250 raw): ~414 DPS. SWAPPED with AK-47 (user 2026-06-26): mult 0.23 -> 0.184 drops papScore ~7.90 -> ~7.04 = MID tier. Still fast/mobile, just less DPS. Clip 20/reserve 160.    // Paladin HB50 (t8_paladin_hb50): BO4 sniper, base dmg 1000 flat. The REAL "crazy strong"
    // cause (user, 2026-06-15) was the Skye rip's MP-inflated hit-location mults: locTorso 5.0
    // (PaP 9.0), limbs 4.0 (8.0), locHead 7.5 (10.0) - so at x1.0 even a BODY/limb shot one-shot
    // to ~r23 and a headshot to ~r33. FIX: the GDT's loc* mults were normalized to 1.0 install-side
    // (skye_t8_paladin_hb50.gdt, both base + _up entries; backup .acc-loc-orig; not repo-tracked -
    // re-apply on a fresh box, see docs/21). With loc=1.0 the gun obeys the additive model like
    // every other gun (body = base, headshot = our 2.0 map mult only), so x0.80 -> body r7 /
    // headshot r14 / HS+Deadshot r20, PaP+Cyberware push higher. A real sniper that FALLS OFF
    // without PaP. Tune the mult here (not the GDT) for further feel changes. Balance audit docs/21.
    if ( IsSubStr( weapon_name, "t8_paladin_hb50" ) ) return 0.15235;  // [B-] Paladin HB50 (BO4 sniper): USER 2026-07-02 TARGET-DAMAGE nerf - "450 body" -> bal = 450/(raw 1000 x global 3.25) = 0.1385 (head = 2.5x = ~1125). Supersedes same-day 0.26 and the 2026-06-27 0.3565. clip 8 / reserve 96/132 / reload 4.1 unchanged. ACC_PALADIN_BOSS_MULT boss cut is SEPARATE (stacks). IsSubStr covers base+_up+twins. Has Precision Mode. docs/04/54.
    if ( IsSubStr( weapon_name, "t9_m60" ) )       return 0.24926;   // [S] M60 (Skye CW LMG): USER 2026-07-09 +10% LMG-class buff (0.2266 x 1.1), paired with LMG reserve +1 mag (4 -> 5: 500/600 rounds) + the 0.9 LMG move-speed standard. Prior: SPREAD +3% best-gun buff (user 2026-06-26). clip 100/120 + large pierce; the big clip makes the 9.7s reload trivial. Slow 0.9 move is its weakness.
    if ( IsSubStr( weapon_name, "t9_rpd" ) )       return 0.13213;   // [C] RPD (Skye CW LMG): USER 2026-07-09 +10% LMG-class buff (0.12012 x 1.1; the M60 got the same +10%, so the "M60 clearly better" gap from 2026-07-06 is preserved), paired with reserve +1 mag (4 -> 5: 375/625 rounds) + the 0.9 LMG move-speed standard. Prior: -10% 2026-07-06; SPREAD -3% 2026-06-26; +25% 2026-06-25. The "bad LMG" - 7.5s reload.
    if ( IsSubStr( weapon_name, "s1_rw1" ) )       return 0.1452;    // [A+] RW1 (AW directed-energy pistol, 800@0.15 = 5333 raw): USER 2026-06-27 +20% damage BUFF, ALL versions+twins (0.11 -> 0.132; full PaP+OC ~1210->1452/shot). Energy sidearm; covers base+PaP+twins. Price tier/box odds UNCHANGED (docs/33 not regenerated). (user 2026-06-23)
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
    if ( IsSubStr( weapon_name, "t6_war_machine" ) ) return 0.0879;   // [A] War Machine drum grenade launcher (per-shot below Mahem; drum burst carries it). See note above.
    // Thundergun (wonder weapon): wind-blast CONE that multi-traces a single boss hitbox. It had NO balance entry
    // at all -> the default 1.0 (zero cut) x the global 2.5x x ~8 cone traces = the ~200k-to-bosses nuke the user
    // hit. NERF -30% (user 2026-06-24, implicit 1.0 -> 0.70). Covers base + thundergun_upgraded (IsSubStr). NOTE:
    // 0.70 cuts ALL targets (incl. its intended chaff clear) but at global 2.5 + multi-hit it STILL nukes bosses
    // (~140k) - the surgical fix for the boss case is a boss-damage cut like is_pellet_shotgun's (see docs/04 audit).
    if ( IsSubStr( weapon_name, "t9_semiauto_cosplay" ) ) return 0.24;  // [S+] Blast-O-Matic (CW DOA energy blaster): USER 2026-07-03 -40% nerf (0.40 -> 0.24). 3500 raw direct projectile, no splash. 3500x0.24x3.25 = 2,730/hit regular; x0.75 boss/glitch ~2,048; x3.0 shielded ~8,190. The 10% boss per-hit cap backstops bosses. Tune here first.
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
function is_action_figure_weapon( weapon )
{
    if ( !isdefined( weapon ) || !isdefined( weapon.name ) ) return false;
    n = weapon.name;
    return ( n == "t8_melee_figure"       || n == "t8_actionfigure_melee"
          || n == "t8_melee_figure_fast1" || n == "t8_melee_figure_fast2" || n == "t8_melee_figure_fast3" );
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
    if ( IsSubStr( weapon_name, "s1_rw1" ) )              return true;   // RW1 (AW directed-energy pistol)
    if ( IsSubStr( weapon_name, "t9_semiauto_cosplay" ) ) return true;   // Blast-O-Matic (CW energy blaster)
    if ( IsSubStr( weapon_name, "thundergun" ) )          return true;   // Thundergun (wonder energy cone)
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
