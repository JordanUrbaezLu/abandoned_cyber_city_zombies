// =============================================================================
// _acc_map_randomizer.gsc - per-run map state
//
// Design reference: docs/07_replayability.md (Tier 1 - Per-Run Map State).
//
// Runs in pre_init(). Rolls a state struct that every other system can read
// from `level.acc_map_state`. Logs the roll for debuggability.
//
// TIMING CONTRACT (load-bearing - do not move these calls):
//   - pre_init() is called by acc_main::pre_init() from the entry script
//     (zm_abandoned_cyber_city.gsc:128), i.e. INSIDE entry main(), AFTER
//     zm_usermap::main() returned and BEFORE main() itself returns.
//   - apply_power_switch_side() must run before entry main() returns: stock
//     zm_power threads its switch logic from a REGISTER_SYSTEM_EX *postload*
//     func that the engine runs in CodeCallback_FinalizeInitialization, after
//     main() (see VERIFIED notes on the function).
//   - remove_all_wallbuys() must run after zm_usermap::main() (the stock
//     wallbuy stubs it unregisters are built inside it) and before the first
//     player can approach a wallbuy (purchase triggers are built lazily per
//     player). pre_init() satisfies both. See the long note on the function.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_unitrigger;
#using scripts\codescripts\struct;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;

#namespace acc_map_randomizer;

function pre_init()
{
    acc_utility::log( "map_randomizer pre_init" );

    state = spawnstruct();
    state.power_switch_side = roll_power_switch_side();
    state.pap_approach = roll_pap_approach();
    state.mystery_box_initial = roll_mystery_box_initial();
    // VERIFIED(acc): the initial box location must be set HERE, not at
    // blackscreen time - stock treasure_chest_init runs ~0.05s after magicbox
    // init (_zm_magicbox.gsc:96) reading level.start_chest_name (default
    // "start_chest", :58), matched against chest script_noteworthy via
    // IsSubStr (:223). Radiant chests need script_noteworthy acc_box_market /
    // acc_box_corp / acc_box_roof / acc_box_plaza / acc_box_lab / acc_box_vault
    // (six chests; roll_mystery_box_initial only ever returns plaza|lab so the
    // START node always has a chest).
    level.start_chest_name = "acc_box_" + state.mystery_box_initial;
    // Perk rotation is rolled PER ROUND, not per run. See roll_perk_rotation
    // below and the hookup in init() / apply_state_when_ready().

    level.acc_map_state = state;
    level.acc_perk_rotation = [];

    log_state( state );

    // Pre-tick applies. Both MUST happen synchronously here (see the timing
    // contract in the file header + the VERIFIED notes on each function):
    //   - power: delete the dead side's stock switch trigger BEFORE the
    //     zm_power postload thread collects it.
    //   - wallbuys: unregister every stock purchase stub BEFORE any player
    //     proximity builds a purchase trigger from them.
    apply_power_switch_side( state.power_switch_side );
    remove_all_wallbuys();
    // CHALK-ONLY wall-buys (user 2026-06-24): the chalk outline mesh now lives in
    // the .map, so the server-spawned 3D gun/monkey-bomb model is redundant clutter
    // sitting ON TOP of the chalk. Disabled so each spot shows ONLY the chalk outline.
    // (spawn_acc_wallbuy_models stays defined but uncalled — re-enable if a future
    // wall-buy wants a 3D prop instead of chalk.)
    // spawn_acc_wallbuy_models();

    // Apply the remaining state to the world (PaP blocker brushes, dead-side
    // emergency-drop trigger disable, box pool registration) after _zm has
    // initialized. Defer to post-init via thread+flag.
    level thread apply_state_when_ready();
    // Per-round perk gating is now done by _acc_perk_doors.gsc (random 3 of the 9
    // Lab perk-alcove DOORS open each round). The old machine-reskin rotation below
    // (roll_perk_rotation / watch_round_for_perk_rotation) targeted acc_lab_perk_a..d
    // machines that were never placed, so it was inert; disabled 2026-06-16 to avoid
    // a second, conflicting per-round perk roll. Kept (unthreaded) for reference.
    // level thread watch_round_for_perk_rotation();
}

// ---------------------------------------------------------------------------
// Roll functions
// ---------------------------------------------------------------------------

function roll_power_switch_side()
{
    // ONE power switch, the Bus Station (corp) one (user 2026-06-18): the VAULT switch
    // prefab was REMOVED from the map source entirely (its baked body is gone now, not just
    // its trigger), so corp is the only switch that exists. Always corp - the `acc_power_side`
    // override is retired (selecting "vault" would leave the map with no working switch).
    return "corp";
}

function roll_pap_approach()
{
    // "server" or "roof" - the BLOCKED side this run.
    return ( acc_utility::acc_rand_int( 2 ) == 0 ? "server" : "roof" );
}

// Mystery Box pool. Registered once on map load (post-blackscreen); the draw
// is handled by stock _zm_magicbox logic, gated per spin on each weapon's live
// level.zombie_weapons[wpn].is_in_box flag.
//
// BOX ARSENAL (user, 2026-06-14): the box is being switched to Tac-19, Locus,
// FN FAL, AK-47 (docs/05_weapons.md tiers; import staging in docs/32). Of those
// only Locus is stock BO3 (sniper_fastbolt); Tac-19 (s1_tac19), FN FAL (t6_fal)
// and AK-47 (s1_ak47 / t9_ak47) are Skye weapon-pack imports that must be
// installed on the Windows box before they can be enabled. A weapon that is not
// in the live table just degrades to "not in box" (never a crash), so naming an
// uninstalled import here is harmless.
//
// INTERIM (imports not yet installed): ICR-1 + Man-O-War + Locus.
//
// The map ships the STOCK zm_levelcommon_weapons.csv
// (zone_source/zm_abandoned_cyber_city.zone:78), whose ~47 rows are flagged
// in_box=TRUE - so a stock box would draw the whole stock arsenal. Setting
// is_in_box=true on our guns is therefore NOT enough on its own: we must first
// CLEAR the flag on every other weapon. The box gate reads the flag live
// (treasure_chest_CanPlayerReceiveWeapon -> zm_weapons::get_is_in_box,
// _zm_magicbox.gsc:1222 -> _zm_weapons.gsc:1492), re-evaluated on each draw, so
// flipping the flags here is authoritative and needs no CSV edit / fastfile
// rebuild.
function register_mystery_box_pool()
{
    acc_utility::log( "mystery box: registering pool" );

    // BOX pool (all Skye imports). Five-Seven is ALSO the starting pistol
    // (_acc_main::init). A weapon missing from the live table degrades to "not in
    // box" (never a crash). EVERY conventional gun here is FULLY twinned (benefits from
    // the Mega-perk handling buffs); only the Thundergun (wonder weapon) is exempt.
    // REMOVED 2026-06-23 (user: "remove any gun that can't be fully twinned"): Ripper
    // (convertible altWeapon), Nail Gun (projectile), PDW-57 + M1911 (akimbo PaP) - none
    // can take the recoil/fire/reload twins, so they were cut. See CHANGELOG + docs/33.
    box_weapons = array(
        "t6_fiveseven",     // Five-Seven (Skye BO2 - also the starting pistol)
        "s1_asm1",          // ASM1       (Skye AW)
        "s1_tac19",         // Tac-19     (Skye AW)
        "t9_ak47",          // AK-47      (Skye BO2)
        "s1_ae4",           // AE4        (Skye AW - directed-energy AR)
        "t8_paladin_hb50",       // Paladin HB50 (BO4 sniper)
        "s4_ppsh41_base",        // PPSH-41 (Vanguard SMG)
        "t9_ak74u",              // AK-74u (Cold War SMG, swapped 2026-06-26; regular _up, empty altWeapon)
        "t6_chicom_cqb",         // Chicom CQB (BO2 3-round-burst SMG; S+ box gun, user 2026-06-25)
        "t6_olympia",            // Olympia (BO2 double-barrel shotgun)
        "t6_galil",              // Galil   (BO2 full-auto AR)
        // LMGs (user 2026-06-19): M60 + RPD (Skye BO2). NOW FULLY TWINNED (user 2026-06-23) - their
        // long reloads (9.7s / 7.5s) make the Speed Cola Mega twin especially valuable.
        "t9_m60",                // M60  (Cold War heavy belt-fed LMG)
        "t9_rpd",                // RPD  (Cold War drum-fed LMG)
        // MK14 (AW s1_mk14): semi-auto battle-rifle / DMR, B tier, FULLY TWINNED (user 2026-06-24). Sniper category + family.
        "s1_mk14",               // MK14 (AW marksman DMR - B tier, twinned)
        // MORS (AW s1_mors): charge-up railgun SNIPER, S tier, FULLY TWINNED (user 2026-06-24). Loc normalized
        // install-side (tools/normalize_mors_loc.js). Sniper category + family.
        "s1_mors",               // MORS (AW railgun sniper - S tier, twinned)
        // NEW AW guns (user 2026-06-23): RW1 directed-energy pistol (FULLY TWINNED) + Mahem sci-fi launcher
        // (EXEMPT explosive special - projectile, no twins, like the Thundergun). Both A-tier box odds.
        "s1_rw1",                // RW1   (AW directed-energy pistol - twinned)
        "s1_mahem",              // Mahem (AW molten-metal rocket launcher - exempt explosive special)
        // WONDER WEAPON (user 2026-06-23, SWAPPED from the Wunderwaffe DG-2): Thundergun. STOCK common weapon
        // (def cooked in zm_levelcommon -> NO `weapon,` .zone line; just a row in our slim weapon table CSV, the
        // octobomb/cymbal_monkey precedent). Wind-blast knockback; is_limited=1 (one in the world at a time =
        // stock WW behavior). PaP -> thundergun_upgraded (cooked); stock cooked SFX. TIER-WEIGHTED box odds
        // (acc_box_weight): it's S+ (its own tier, above S), the RAREST roll of all at ~1% (acc_box_weight).
        "thundergun",            // Thundergun (wind-blast knockback - the map's wonder weapon)
        // Action Figure (BO4 t8 melee port by T0nic; TEST-ONLY rip, see CREDITS). A fun handheld swing weapon.
        // Source installed in the Mod Tools (gitignored); .zone + CSV + GDT wired 2026-06-23. Melee = "special"
        // class like the Thundergun, so it rides the same is_in_box flip below (degrades to "not in box" if the
        // weapon table lacks the row - never a crash).
        "t8_melee_figure",       // Action Figure melee (fun swing weapon)
        // TACTICAL grenades as RARE box rolls (user 2026-06-24): Monkey Bomb (cymbal_monkey, 1%) + Li'l Arnie
        // (octobomb, 0.5%). FIXED odds via acc_box_tactical_preroll() - NOT tier-weighted (excluded from the
        // gun pick by is_box_tactical()). is_in_box here lets the box float+give them; the grant is finalized
        // by acc_boss_items::watch_box_tactical_grab() on "user_grabbed_weapon". (Removed from the boss-item pool.)
        "cymbal_monkey",         // Monkey Bomb tactical (box pre-roll 1%)
        "octobomb"               // Li'l Arnie tactical (box pre-roll 0.5%)
    );

    // 1) Clear is_in_box across the ENTIRE live weapon table so none of the
    //    stock CSV's in_box=TRUE rows can be rolled. Keyed by weapon OBJECT.
    if ( isdefined( level.zombie_weapons ) )
    {
        all_weapons = getarraykeys( level.zombie_weapons );
        for ( i = 0; i < all_weapons.size; i++ )
        {
            level.zombie_weapons[ all_weapons[ i ] ].is_in_box = false;
        }
    }

    // 2) Re-enable ONLY our two guns. Each still needs a row in the loaded
    //    weapon table - without one there is no level.zombie_weapons struct to
    //    flip, so a missing CSV entry degrades to "not in box", never a crash.
    for ( i = 0; i < box_weapons.size; i++ )
    {
        w = box_weapons[ i ];
        wpn = GetWeapon( w );
        if ( isdefined( wpn ) && isdefined( level.zombie_weapons[ wpn ] ) )
        {
            level.zombie_weapons[ wpn ].is_in_box = true;
            acc_utility::log( "  + box weapon: " + w );
        }
        else
        {
            acc_utility::log( "  ! box weapon missing from weapon table: " + w );
        }
    }

    level.acc_mystery_box_weapons = box_weapons;

    // FIX (user, 2026-06-14): constrain the stock box draw to box weapons ONLY.
    // Stock treasure_chest_ChooseWeightedRandomWeapon falls back to keys[0] (a
    // RANDOM key from the whole 6-weapon table) when no weapon passes its filter
    // - which happens once a player owns all 3 box guns (reachable with Mule Kick
    // + only 3 box guns). That fallback could hand out a knife / frag /
    // pistol_standard. level.CustomRandomWeaponWeights pre-filters the key list
    // (stock _zm_magicbox.gsc:1273-1275) so BOTH the loop AND the keys[0]
    // fallback see ONLY box-flagged weapons, never a non-box item. The same hook
    // also drops box guns the player already owns (see acc_box_only_weapon_keys), so
    // the box won't hand out a duplicate unless the player owns EVERY available box gun.
    level.CustomRandomWeaponWeights = &acc_box_only_weapon_keys;
}

// Box draw key filter (hooked via level.CustomRandomWeaponWeights). Runs ON the
// drawing player; returns the randomized key list narrowed to is_in_box weapons
// the player does NOT already own (so the box can't hand out a duplicate).
function acc_box_only_weapon_keys( keys )
{
    box_only = [];
    for ( i = 0; i < keys.size; i++ )
    {
        w = keys[ i ];
        if ( isdefined( level.zombie_weapons[ w ] ) &&
             IS_TRUE( level.zombie_weapons[ w ].is_in_box ) &&
             !is_box_tactical( w ) )   // tacticals (Monkey/Arnie) are FIXED-odds pre-roll, not tier-weighted
        {
            box_only[ box_only.size ] = w;
        }
    }
    // Safety: never hand the box an empty list (keys[0] would be undefined).
    if ( box_only.size == 0 )
    {
        return keys;
    }

    // No-duplicates (user, 2026-06-14): drop any box gun the player ALREADY holds
    // in any form (base / PaP / perk-variant twin). This filter feeds BOTH the stock
    // loop AND its keys[0] fallback (_zm_magicbox.gsc:1273-1287), so it fixes the two
    // ways a dupe slips through: (a) the keys[0] fallback that fires once every
    // candidate is owned, and (b) the twin gap - stock CanPlayerReceiveWeapon's
    // has_weapon_or_upgrade() does NOT recognize a held twin (e.g. s1_tac19_acc_recoil25)
    // as owning its base s1_tac19, so it would re-roll the gun you're holding under a perk.
    not_held = [];
    for ( i = 0; i < box_only.size; i++ )
    {
        if ( !player_owns_box_weapon( self, box_only[ i ] ) )
            not_held[ not_held.size ] = box_only[ i ];
    }

    // If the player owns EVERY available box gun there is nothing new to give - fall back to the full
    // box list (stock then hands a duplicate w/ max ammo, an unavoidable edge). Otherwise the draw is
    // restricted to guns they lack.
    eligible = ( not_held.size == 0 ? box_only : not_held );

    // FIXED-ODDS TACTICAL pre-roll (user 2026-06-24): Monkey Bomb (1%) + Li'l Arnie (0.5%) are rare box
    // outcomes OUTSIDE the tier weighting. Flag the grab so acc_boss_items::watch_box_tactical_grab() finalizes
    // the tactical (active slot + ammo + thrown callback) on "user_grabbed_weapon", and float that tactical at
    // the FRONT. The gun list stays behind it as a non-empty fallback if the tactical can't be floated (then a
    // gun shows + the finalizer still grants the tactical on grab). Cleared every roll so a gun roll never grants.
    self.acc_box_pending_tactical = undefined;
    tac = acc_box_tactical_preroll();
    if ( isdefined( tac ) )
    {
        self.acc_box_pending_tactical = tac;
        tac_wpn = GetWeapon( ( tac == "monkey_bomb" ? "cymbal_monkey" : "octobomb" ) );
        out = [];
        if ( isdefined( tac_wpn ) ) out[ 0 ] = tac_wpn;
        for ( i = 0; i < eligible.size; i++ ) out[ out.size ] = eligible[ i ];
        if ( out.size > 0 ) return out;
    }

    // TIER-WEIGHTED ROLL (user 2026-06-22): best guns rarer, worst guns commoner. Stock's
    // treasure_chest_ChooseWeightedRandomWeapon returns the FIRST eligible key (_zm_magicbox.gsc:1279-1284),
    // so we do our OWN weighted pick by tier and return it at the FRONT; the rest follow as fallback so the
    // stock loop still has a non-empty list. Per-gun weights (~percent on the fresh 17-gun pool, sum 100):
    // S 4 / A 5 / B 7 / C 8 (acc_box_weight; docs/05 Gun Tier List).
    picked = acc_box_weighted_pick( eligible, IS_TRUE( self.acc_lucky_clover ) );   // Lucky Clover (user 2026-06-29): boost top-tier odds for a Clover-carrying spinner
    if ( !isdefined( picked ) ) return eligible;   // safety - never hand the box an empty list
    out = [];
    out[ 0 ] = picked;
    for ( i = 0; i < eligible.size; i++ )
        if ( eligible[ i ] != picked ) out[ out.size ] = eligible[ i ];
    return out;
}

// Weighted random pick from a list of weapon OBJECTS, by per-gun tier weight (acc_box_weight). Higher
// weight = more likely. Returns one weapon object (undefined only on an empty list). `clover` (optional,
// default false): when true the LUCKY CLOVER reweight is applied (top-tier guns commoner, funded from the
// common tier) - only the mystery box passes it; the glitch altar leaves it off.
function acc_box_weighted_pick( list, clover )
{
    if ( !isdefined( list ) || list.size == 0 ) return undefined;
    if ( list.size == 1 ) return list[ 0 ];
    if ( !isdefined( clover ) ) clover = false;

    total = 0;
    for ( i = 0; i < list.size; i++ )
        total += box_pick_weight( list[ i ], clover );
    if ( total <= 0 ) return list[ acc_utility::acc_rand_int( list.size ) ];

    r = acc_utility::acc_rand_int( total );   // 0 .. total-1
    accum = 0;
    for ( i = 0; i < list.size; i++ )
    {
        accum += box_pick_weight( list[ i ], clover );
        if ( r < accum ) return list[ i ];
    }
    return list[ list.size - 1 ];   // float-safety fallback (never expected with int weights)
}

// Per-gun box weight used by the pick: the generated tier weight (acc_box_weight), optionally Clover-adjusted.
function box_pick_weight( wpn, clover )
{
    w = acc_box_weight( wpn );
    if ( clover ) w = acc_box_clover_weight( wpn, w );
    return w;
}

// LUCKY CLOVER box luck (user 2026-06-29): applied ONLY when the spinner has the Clover. Shifts roll probability
// from the COMMON tier into the TOP tier, classified by the base tier weight (higher weight = commoner, so the
// S+/S rares have the LOWEST weights):
//   top tier  (w <= acc_clover_box_top_maxw 12, the S+/S rares) -> + acc_clover_box_top_add (5)   ~= +1% each on the full pool
//   common    (w >= acc_clover_box_common_minw 50)              -> - acc_clover_box_common_sub (10), funding the boost
//   mid (A-tier, w 13..49)                                      -> unchanged
// On the full 482-weight pool that's ~+1% per top gun, pulled ~-2% from each common gun (net total ~unchanged);
// it drifts as the pool shrinks (collected guns drop out) but always favours the rares more. Layered OVER the
// generated acc_box_weight so the auto-generated table is never hand-edited. All live dvars.
function acc_box_clover_weight( wpn, base_w )
{
    if ( base_w <= getdvarint( "acc_clover_box_top_maxw", 12 ) )
        return base_w + getdvarint( "acc_clover_box_top_add", 5 );
    if ( base_w >= getdvarint( "acc_clover_box_common_minw", 50 ) )
    {
        adj = base_w - getdvarint( "acc_clover_box_common_sub", 10 );
        return ( adj < 1 ? 1 : adj );
    }
    return base_w;
}

// Fixed-odds tactical pre-roll for the box (user 2026-06-24): Monkey Bomb 1% (cymbal_monkey) + Li'l Arnie
// 0.5% (octobomb), OUTSIDE the gun tier-weighting. Returns the item id or undefined (-> normal gun pick).
function acc_box_tactical_preroll()
{
    r = acc_utility::acc_rand_int( 1000 );   // 0..999
    if ( r < 5 )  return "lil_arnie";        // 0.5%  -> r 0..4   (octobomb)
    if ( r < 15 ) return "monkey_bomb";      // 1.0%  -> r 5..14  (cymbal monkey)
    return undefined;                        // 98.5% -> normal tier-weighted gun pick
}

// True if a box weapon OBJECT is one of the fixed-odds tacticals (kept OUT of the tier-weighted gun pick).
function is_box_tactical( wpn )
{
    if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) return false;
    return ( wpn.name == "cymbal_monkey" || wpn.name == "octobomb" );
}

// Per-gun mystery-box weight by PaP PRICE TIER (docs/54; ranked on PaP-form power, split into thirds).
// HIGHER weight = COMMONER roll, so the best packed guns (TOP) are the rarest finds; the WW (Thundergun)
// is rarest of all. GENERATED by tools/compute_gun_tiers.js - do NOT hand-edit between the markers; edit
// that script's roster + re-run (regenerates docs/54 + this block, GSC #2). Matched by EXACT box-pool name;
// pool total weight 482, re-normalizes live as you collect (the box never repeats a gun you own). 2026-06-25.
// <<< BEGIN GENERATED (tools/compute_gun_tiers.js) >>>
function acc_box_weight( wpn )
{
    if ( !isdefined( wpn ) || !isdefined( wpn.name ) ) return 5;
    n = wpn.name;
    if ( n == "thundergun" ) return 3;   // ~0.6% each - Thundergun
    if ( n == "t8_melee_figure" ) return 5;   // ~1.1% each - Action Figure
    if ( n == "t6_chicom_cqb" || n == "t9_m60" || n == "t9_ak47" || n == "s4_ppsh41_base" || n == "s1_tac19" ) return 8;   // ~1.7% each - Chicom CQB, M60, AK-47, PPSH-41, Tac-19 (S-tier, rarest; user 2026-06-26)
    if ( n == "s1_mors" ) return 12;   // ~2.6% each - MORS
    if ( n == "s1_ae4" || n == "s1_rw1" || n == "t9_ak74u" || n == "s1_asm1" || n == "t6_galil" || n == "s1_mk14" || n == "s1_mahem" ) return 29;   // ~6.3% each - AE4, RW1, AK-74u, ASM1, Galil, MK14, Mahem
    if ( n == "t8_paladin_hb50" || n == "t9_rpd" || n == "t6_fiveseven" || n == "t6_olympia" ) return 50;   // ~10.8% each - Paladin HB50, RPD, Five-Seven, Olympia
    return 5;   // unknown -> mid
}
// <<< END GENERATED >>>

// True if `player` already carries `candidate` in ANY form - base, Pack-a-Punch (_up),
// or a perk-variant twin - compared by TRUE BASE weapon object. acc_weapon_variants::true_base
// strips our _acc_<token> twin suffix and maps through the stock base-weapon table, so a held
// s1_tac19 / s1_tac19_up / s1_tac19_acc_recoil40 all resolve to the same base as the candidate.
function player_owns_box_weapon( player, candidate )
{
    if ( !isdefined( player ) ) return false;
    cand_base = acc_weapon_variants::true_base( candidate );
    if ( !isdefined( cand_base ) || cand_base == level.weaponNone ) return false;

    held = player GetWeaponsListPrimaries();
    for ( i = 0; i < held.size; i++ )
    {
        if ( !isdefined( held[ i ] ) || held[ i ] == level.weaponNone ) continue;
        if ( acc_weapon_variants::true_base( held[ i ] ) == cand_base )
            return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Perk rotation - per ROUND, not per run.
//
// See docs/13_perks.md "Per-Round Rotating Lab Machines". All 9 perks are
// at the Lab; 4 machines (lab_a, lab_b, lab_c, lab_d) re-assign to a random
// 4-of-9 at each round start. No duplicates, no per-perk guarantees.
// ---------------------------------------------------------------------------

// All 9 perks. Specialty strings: stock for stock perks, `specialty_acc_*`
// prefix for our custom additions.
// VERIFIED(acc): stock ZM specialty names from _zm_perks.gsh:20-31
// (PERK_DOUBLETAP2 = "specialty_doubletap2", PERK_STAMINUP =
// "specialty_staminup"; the old "specialty_rof"/"specialty_longersprint"
// are giant-legacy/MP-only strings the ZM perk machines never match).
function get_full_perk_roster()
{
    return array(
        "specialty_armorvest",                    // Jugger-Nog
        "specialty_quickrevive",                  // Quick Revive
        "specialty_fastreload",                   // Speed Cola
        "specialty_doubletap2",                   // Double Tap 2.0
        "specialty_staminup",                     // Stamin-Up (retuned)
        "specialty_additionalprimaryweapon",      // Mule Kick
        // VERIFIED(acc) 2026-06-13: these MUST be the registered specialty
        // strings used by every machine / HasPerk / Mega flag / cost / damage
        // hook - NOT custom 'specialty_acc_*' names (which matched nothing, so
        // the rotation silently broke for these 3 perks). Deadshot + Widow's
        // Wine are stock modules; PhD Flopper hijacks the stock electric-cherry
        // pipeline (_acc_perk_phd_flopper.gsc).
        "specialty_deadshot",                     // Deadshot (custom-tuned)
        "specialty_widowswine",                   // Widow's Wine (+ boosts)
        "specialty_electriccherry"                // PhD Flopper (over the cherry slot)
    );
}

function roll_perk_rotation( round_number )
{
    roster = get_full_perk_roster();
    shuffled = array::randomize( roster );

    // Take first 4. Remaining 5 are locked out this round.
    rotation = array( shuffled[ 0 ], shuffled[ 1 ], shuffled[ 2 ], shuffled[ 3 ] );
    level.acc_perk_rotation = rotation;

    acc_utility::log( "round " + round_number + " perk rotation: " +
                       rotation[ 0 ] + ", " +
                       rotation[ 1 ] + ", " +
                       rotation[ 2 ] + ", " +
                       rotation[ 3 ] );

    // Also log locked-out perks for debug visibility.
    for ( i = 4; i < shuffled.size; i++ )
    {
        acc_utility::log( "  locked out: " + shuffled[ i ] );
    }

    // Notify any listeners (perk machine re-skin code, HUD) that rotation changed.
    level notify( "acc_perk_rotation_rolled", rotation );

    return rotation;
}

function watch_round_for_perk_rotation()
{
    level endon( "end_game" );

    // DESIGN (docs/03_layout.md, docs/13_perks.md): perk machines re-roll
    // AFTER the decontamination phase (20s evac + seal on rounds 1-4, the
    // nominal 0s tick on 5+), never on acc_round_start. _acc_decontamination
    // emits acc_decontamination_complete with the round number EVERY round.
    for ( ;; )
    {
        level waittill( "acc_decontamination_complete", round_number );
        roll_perk_rotation( round_number );
        apply_perk_rotation_to_machines( level.acc_perk_rotation );
    }
}

// Read `acc_lab_perk_a/b/c/d` script_structs or triggers in Radiant and
// update their current perk specialty. Visual re-skin is a Phase 4 task.
function apply_perk_rotation_to_machines( rotation )
{
    // TODO(acc-geom): Radiant must place 4 perk machine entities in the Lab
    // with targetnames "acc_lab_perk_a", "_b", "_c", "_d". Their "dispense"
    // logic reads rotation[ index ] to decide which perk specialty to grant.
    //
    // Until Radiant has them, this just logs and returns.
    slot_names = array( "acc_lab_perk_a", "acc_lab_perk_b",
                        "acc_lab_perk_c", "acc_lab_perk_d" );

    for ( i = 0; i < slot_names.size; i++ )
    {
        machines = getentarray( slot_names[ i ], "targetname" );
        if ( machines.size == 0 ) continue;

        for ( j = 0; j < machines.size; j++ )
        {
            machines[ j ].acc_current_specialty = rotation[ i ];
            // TODO(acc-art): swap the machine's visible skin / advertising
            // model to match the new perk (Phase 4 work).
        }
    }
}

function roll_mystery_box_initial()
{
    // FIRST box location is ALWAYS the PLAZA (start room) - deterministic, every
    // run (user, 2026-06-18). After this initial spawn the stock _zm_magicbox
    // teddy-bear move rotates the single box randomly among ALL six chests in the
    // map (market/corp/roof/plaza/lab/vault) - that wider pool is NOT constrained
    // here, only the START node is pinned.
    //
    // CONTRACT: the node returned here MUST have a matching acc_box_<node> chest
    // pair (script_struct targetname "treasure_chest_use" + zbarrier
    // "<node>_zbarrier") in map_source/.../zm_abandoned_cyber_city.map, or stock
    // _zm_magicbox finds no start match and HIDES ALL boxes (silent no-box, see
    // docs/research/BO3_Mystery_Box_Radiant_anatomy_multi_.txt §C gotcha). The
    // acc_box_plaza chest exists (added with the +3-spots change).
    return "plaza";
}

// ---------------------------------------------------------------------------
// State application
// ---------------------------------------------------------------------------

function apply_state_when_ready()
{
    level endon( "end_game" );

    // VERIFIED(acc): flag, not notify - see _acc_main.gsc note.
    level flag::wait_till( "initial_blackscreen_passed" );

    // NOTE: apply_power_switch_side and remove_all_wallbuys already ran
    // synchronously in pre_init() - both have pre-tick timing requirements
    // (see their VERIFIED notes). Only the pieces that are safe (and in the
    // PaP case, intended) at blackscreen run here.
    disable_dead_side_emergency_triggers( level.acc_map_state.power_switch_side );
    apply_pap_approach( level.acc_map_state.pap_approach );
    apply_mystery_box_initial( level.acc_map_state.mystery_box_initial );
    // Keep ONLY the active box's collision clip solid (the MagicBox model has no
    // player clip; acc_box_clip_<node> brushmodels added by tools/add_room_boxes.js).
    level thread manage_box_collision();
    // Deep abyss-station prop clips (acc_clip_* script_brushmodels from add_prop_clips.js) - solidify them the
    // same deterministic way (user 2026-06-27: the Glitch Altar / Overclock / Ammo Crates were walk-through).
    level thread manage_deep_prop_clips();
    // Perk rotation is NOT applied at map-load; it rolls per-round.
    // See watch_round_for_perk_rotation().

    // Mystery Box weapon pool is a static registration (does not vary per run
    // in v1.0 - the per-run randomization comes from the box's own draw RNG
    // over this fixed pool).
    register_mystery_box_pool();

    acc_utility::log( "map_randomizer state applied" );
}

function apply_power_switch_side( side )
{
    // SINGLE power switch now (user 2026-06-18): the VAULT switch prefab was REMOVED from
    // the map source, so the map ships ONE stock power-switch prefab (the Bus Station / corp
    // one). This function used to delete the losing side's trigger at runtime; with only one
    // switch in the map there is nothing to delete, so it just confirms the live switch and
    // returns. Kept as a safety no-op (and so a future second switch could be re-introduced).
    //
    // VERIFIED(acc): the "zombie_power_on/off" clientfield bit widths come from the
    // use_elec_switch trigger COUNT server-side (_zm.gsc:1655-1661) and the elec_switch_fx
    // struct count client-side (_zm.csc:329-336). Removing the WHOLE vault prefab drops both
    // by one, so they stay consistent at 1 (a normal single-switch map). Do NOT put script_int
    // on the trigger - that makes a ZONED switch ("power_on"+N) instead of the global "power_on"
    // flag every acc consumer (and the fog settle) waits on (_zm_power.gsc:728-737).
    switch_trigs = getentarray( "use_elec_switch", "targetname" );
    if ( switch_trigs.size == 0 )
    {
        acc_utility::log( "power: no stock use_elec_switch triggers in map yet" );
        return;
    }

    if ( switch_trigs.size <= 1 )
    {
        // Expected state: single switch (corp). Nothing to delete - it's already the only one.
        acc_utility::log( "power: single switch (corp / Bus Station) - live, nothing to delete" );
        return;
    }

    // Legacy path (only if a second switch is ever re-added): delete the non-live side.
    dead_side = ( side == "corp" ? "vault" : "corp" );
    killed = 0;
    for ( i = 0; i < switch_trigs.size; i++ )
    {
        trig = switch_trigs[ i ];
        if ( isdefined( trig.script_string ) && trig.script_string == dead_side )
        {
            trig delete();
            killed++;
        }
    }

    acc_utility::log( "power: live switch = " + side + ", deleted " + killed +
                      " dead-side trigger(s) (" + dead_side + ")" );
}

// The acc_power_corp / acc_power_vault triggers are SEPARATE entities owned
// by _acc_emergency_drop (shard-spend drops at the live switch). The dead
// side's copy is disabled for the run. This intentionally stays at
// blackscreen (trigger state, no stock-init race).
function disable_dead_side_emergency_triggers( side )
{
    dead_side = ( side == "corp" ? "vault" : "corp" );

    dead_triggers = getentarray( "acc_power_" + dead_side, "targetname" );
    for ( i = 0; i < dead_triggers.size; i++ )
    {
        dead_triggers[ i ] triggerenable( false );
    }

    acc_utility::log( "power: disabled " + dead_triggers.size +
                      " dead-side emergency trigger(s) (acc_power_" +
                      dead_side + ")" );
}

function apply_pap_approach( blocked_side )
{
    // REMOVED (user 2026-06-22): the per-run RANDOM path-blocking wall is no longer in the design. It used
    // to leave one of the two lab corridors walled off by a tall, floor-to-ceiling, un-buyable brush
    // (acc_pap_block_roof / acc_pap_block_server) - which read in-game as a "broken door" on the Helipad->Lab
    // path. Now we OPEN BOTH walls every run so neither corridor is ever blocked. The brushes stay in the .map
    // (authored visible+solid) but are always hidden / non-solid / path-connected here. blocked_side is ignored.
    names = [];
    names[ 0 ] = "acc_pap_block_server";
    names[ 1 ] = "acc_pap_block_roof";

    opened = 0;
    for ( n = 0; n < names.size; n++ )
    {
        walls = getentarray( names[ n ], "targetname" );
        for ( i = 0; i < walls.size; i++ )
        {
            walls[ i ] hide();
            walls[ i ] notsolid();
            walls[ i ] connectpaths();
            opened++;
        }
    }

    acc_utility::log( "pap: random approach wall REMOVED - both corridors open (" + opened + " brush(es))" );
}

function remove_all_wallbuys()
{
    // ARSENAL RESTRICTED (user, 2026-06-14): the map must have NO wall buys -
    // every weapon comes from the Mystery Box (ICR-1 + Man-O-War). The Radiant
    // source places 6 wall structs (ICR / Haymaker / Drakon / Sheiva / Frag via
    // targetname "weapon_upgrade", plus the Bowie via "bowie_upgrade"); stock
    // init_spawnable_weapon_upgrade turned each into a live purchase unitrigger
    // stub. We unregister every one of those stubs so no purchase trigger is
    // ever built for any player.
    //
    // WHERE THE STUBS COME FROM (the list we walk):
    // VERIFIED(acc): init_spawnable_weapon_upgrade collects the wallbuy structs
    // (struct::get_array of "weapon_upgrade"/"bowie_upgrade"/...,"targetname"),
    // builds a unitrigger_stub per struct via
    // zm_unitrigger::register_static_unitrigger, and stores them on
    // level._spawned_wallbuys[i].trigger_stub (_zm_weapons.gsc:836-1019). That
    // init runs synchronously INSIDE zm_usermap::main(), so by pre_init() the
    // list is fully populated (this is the same read window the old per-run
    // wallbuy rewrite relied on).
    //
    // WHY UNREGISTER-IN-PRE_INIT IS COMPLETE:
    // VERIFIED(acc): purchase triggers are built lazily per player from the
    // stub's zone entry; unregister_unitrigger removes the stub from its zone /
    // dynamic stub lists and flags it registered=0
    // (_zm_unitrigger.gsc:173-216), so the per-player build never sees it.
    // pre_init() runs before any player exists, so no trigger is ever created.
    //
    // COSMETIC LIMIT (TODO(acc-art)/TODO(acc-geom)): unregistering kills the
    // PURCHASE only. The wall's weapon model + chalk + blue-light fx are spawned
    // CLIENT-side from the .csc's own struct copy (_zm_weapons.csc:300-314,
    // which a .gsc cannot reach), so a "ghost" gun would stay visible on the
    // wall. The visuals are removed for good by deleting the 6 wallbuy struct
    // PAIRS from map_source/zm/zm_abandoned_cyber_city.map (the weapon_upgrade /
    // bowie_upgrade structs + their target model structs) and a full geometry
    // rebuild - done 2026-06-14. This function stays as the runtime safety net
    // (it no-ops once the structs are gone, since level._spawned_wallbuys is
    // then empty). NOTE: the vending_weapon_upgrade_spawnable prefab is
    // Pack-a-Punch, NOT a wallbuy - never delete it.
    if ( !isdefined( level._spawned_wallbuys ) )
    {
        acc_utility::log( "wallbuy: level._spawned_wallbuys missing - stock " +
                          "init has not run; nothing to remove" );
        return;
    }

    removed = 0;
    for ( i = 0; i < level._spawned_wallbuys.size; i++ )
    {
        s = level._spawned_wallbuys[ i ];

        // KEEP the 5 player-requested wall-buys: Five-Seven (Lab), Olympia (Bus Station),
        // frag grenade (Spawn) (user 2026-06-23), the AK-47 (Abyss Layer 4 / "4th floor" trench -
        // user 2026-06-26), and the M60 (Abyss Layer 5 / "bottom floor", before Paradise - user
        // 2026-06-27, the second S-tier abyss wall-buy). Everything else stays box-only.
        // s.zombie_weapon_upgrade is the raw .map KVP string (see the log at the bottom of this loop).
        // Stock buy->ammo->PaP-ammo handling does the rest.
        if ( isdefined( s.zombie_weapon_upgrade ) &&
             ( s.zombie_weapon_upgrade == "t6_fiveseven"
               || s.zombie_weapon_upgrade == "t6_olympia"
               || s.zombie_weapon_upgrade == "frag_grenade"
               || s.zombie_weapon_upgrade == "t9_ak47"
               || s.zombie_weapon_upgrade == "t9_m60" ) )
        {
            acc_utility::log( "wallbuy KEPT (player-requested): " + s.zombie_weapon_upgrade );
            continue;
        }

        stub = s.trigger_stub;
        if ( !isdefined( stub ) )
        {
            // Buildable/deferred wallbuy (no static stub yet) - nothing here.
            continue;
        }

        zm_unitrigger::unregister_unitrigger( stub );
        removed += 1;

        slot = ( isdefined( s.zombie_weapon_upgrade ) ? s.zombie_weapon_upgrade : "?" );
        acc_utility::log( "wallbuy removed: " + slot );
    }

    acc_utility::log( "wallbuy: removed " + removed + " wall buy trigger(s)" );
}
// DISABLED 2026-06-24 (user: "I only want the chalk in each spot, not two things"). This spawns a
// VISIBLE 3D gun/monkey-bomb model per wall-buy; we now have a real CHALK outline mesh on each wall
// (in the .map), so the 3D model is redundant clutter sitting on top of the chalk. The call in init()
// is commented out — each spot shows ONLY the chalk now. Kept defined (uncalled) in case a future
// wall-buy wants a 3D prop instead. (Earlier note "chalk shaders won't compile" was FALSE — the chalk
// builds + packs fine; see memory wallbuy-chalk-inline-mesh-recipe + CHANGELOG 2026-06-24.)
// Spawns a SERVER-side script_model at each model-struct origin (wm_t6_five_seven / wm_t6_olympia /
// wpn_t7_zmb_monkey_bomb_world — zone-packed). Stock buildkit renders nothing for Skye ports + grenades.
function spawn_acc_wallbuy_models()
{
    names = array( "acc_fiveseven_wallbuy_model", "acc_olympia_wallbuy_model", "acc_grenade_wallbuy_model" );
    for ( i = 0; i < names.size; i++ )
    {
        s = struct::get( names[ i ], "targetname" );
        if ( !isdefined( s ) || !isdefined( s.model ) )
        {
            acc_utility::log( "acc wallbuy model MISSING struct: " + names[ i ] );
            continue;
        }
        m = spawn( "script_model", s.origin );
        if ( isdefined( s.angles ) )
            m.angles = s.angles;
        m setmodel( s.model );
        acc_utility::log( "acc wallbuy model spawned: " + s.model + " @ " + s.origin );
    }
}

function apply_mystery_box_initial( node_name )
{
    // VERIFIED(acc): the actual selection happens in pre_init() via
    // level.start_chest_name (must be set before _zm_magicbox init runs,
    // long before blackscreen). This is log-only by design now.
    acc_utility::log( "mystery box initial -> " + node_name );
}

// ---------------------------------------------------------------------------
// Mystery box collision: ONE moving box, a clip per room node (acc_box_clip_<node>).
// The MagicBox model has no player clip, so the box reads as walk-through. We keep
// only the ACTIVE node's clip solid (VERIFIED: level.chests[level.chest_index] is
// the active chest - _zm_magicbox.gsc:95/168/207; inactive chests are hidden), so
// the 6 rooms the box is NOT in have no phantom invisible block.
// ---------------------------------------------------------------------------

function box_clip_nodes()
{
    // One entry per real acc_box_<node> chest in the .map (the six box spots). A
    // node with no acc_box_clip_<node> brushmodel just no-ops in set_active_box_clip
    // (none are placed yet - the MagicBox model is walk-through on every spot today),
    // so this list is only load-bearing once collision clips are authored.
    return array( "market", "corp", "roof", "plaza", "lab", "vault" );
}

// Make EVERY box node's clip solid (user 2026-06-26). Every node ALWAYS shows a box model - the
// active moving box, OR the idle "fake" box (p6_anim_zm_magic_box_fake) when the box is elsewhere -
// so each location gets a PERMANENT solid clip; there is no per-node toggling. (The OLD behavior
// solidified only the ACTIVE node, leaving the other 5 walk-through; and the acc_box_clip_* brushmodels
// were never authored into the .map at all until tools/place_boxes_against_walls.js.)
function solidify_all_box_clips()
{
    nodes = box_clip_nodes();
    solid_count = 0;
    for ( i = 0; i < nodes.size; i++ )
    {
        clips = getentarray( "acc_box_clip_" + nodes[ i ], "targetname" );
        for ( c = 0; c < clips.size; c++ )
        {
            clips[ c ] solid();
            clips[ c ] show();
            solid_count++;
        }
    }
    return solid_count;
}

function manage_box_collision()
{
    level endon( "end_game" );

    // script_brushmodel clips are solid by author-default; make it explicit + deterministic once the
    // entities have spawned. ALL nodes stay solid permanently, so no teddy-bear retracking is needed
    // and there is no walk-through anywhere. Poll a few seconds for the brushmodels to exist.
    for ( i = 0; i < 40; i++ )
    {
        n = solidify_all_box_clips();
        if ( n > 0 ) { box_clip_dbg( "all box clips solid=" + n ); return; }
        wait 0.1;
    }
    box_clip_dbg( "no acc_box_clip_* brushmodels found in .map" );
}

// --- DEEP abyss-station prop clips (user 2026-06-27) ---------------------------------------------------------
// The Glitch Altar, Overclock terminal, and both Ammo Crates sit on the deep abyss floors (z -480..-1200). Their
// collision is a script_brushmodel `clip` (acc_clip_<label>) emitted by tools/add_prop_clips.js - a script_brushmodel
// is LED-EXEMPT so it bakes at abyss depth where a worldspawn clip would crash the lightmapper (memory
// deep-prop-clips-crash-led-bake / brushmodel-wall-led-exempt). Clip-material brushmodels are solid by author-
// default, but make it explicit + deterministic exactly like the box clips. KEEP THIS LABEL LIST IN SYNC with the
// `brushmodel: true` entries in tools/add_prop_clips.js.
function deep_prop_clip_targetnames()
{
    names = [];
    names[ names.size ] = "acc_clip_glitch_altar_l3";
    names[ names.size ] = "acc_clip_overclock_terminal";
    names[ names.size ] = "acc_clip_ammo_crate_l2";
    names[ names.size ] = "acc_clip_ammo_crate_l5";
    return names;
}

function solidify_deep_prop_clips()
{
    names = deep_prop_clip_targetnames();
    solid_count = 0;
    for ( i = 0; i < names.size; i++ )
    {
        clips = getentarray( names[ i ], "targetname" );
        for ( c = 0; c < clips.size; c++ )
        {
            clips[ c ] solid();
            clips[ c ] show();
            solid_count++;
        }
    }
    return solid_count;
}

function manage_deep_prop_clips()
{
    level endon( "end_game" );

    // The clips are .map entities (present at load), but mirror manage_box_collision's defensive poll. All stay
    // solid permanently - no toggling.
    for ( i = 0; i < 40; i++ )
    {
        n = solidify_deep_prop_clips();
        if ( n > 0 ) { box_clip_dbg( "deep prop clips solid=" + n ); return; }
        wait 0.1;
    }
    box_clip_dbg( "no acc_clip_* deep prop brushmodels found in .map" );
}

// Temporary diagnostic: route a box-collision message to console_mp.log via the
// reliable IPrintLnBold-on-a-player channel ([ SCRIPTER] lines).
function box_clip_dbg( msg )
{
    // On-screen IPrintLnBold REMOVED (user 2026-06-27: it printed "[acc-box] ..." in normal play - it was never
    // dev-gated). The diagnostic stays in console_mp.log via acc_utility::log. If you need it on-screen again while
    // debugging the box clips, re-add an IPrintLnBold here gated on IS_TRUE( level.acc_dev ).
    acc_utility::log( "box_collision: " + msg );
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

function weighted( w, v )
{
    s = spawnstruct();
    s.weight = w;
    s.value = v;
    return s;
}

function log_state( state )
{
    acc_utility::log( "map_state power=" + state.power_switch_side +
                       " pap_blocked=" + state.pap_approach +
                       " box_initial=" + state.mystery_box_initial );

    // Wall buys are fully removed on this map (remove_all_wallbuys); no
    // per-run wallbuy pool to log. Perk rotation is logged per-round by
    // roll_perk_rotation; not part of map-load state.
}
