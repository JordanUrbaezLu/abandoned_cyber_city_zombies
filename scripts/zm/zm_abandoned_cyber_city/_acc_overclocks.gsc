// =============================================================================
// _acc_overclocks.gsc - weapon Tier progression + Overclock slots
//
// Design reference: docs/05_weapons.md (Weapon Progression - Tier 1-5).
//
// Tier model:
//   - Each weapon tracks a TIER from 0 (base) to 5 (max) per player.
//   - Each tier-up unlocks ONE Overclock slot, filled with a random roll from
//     the weapon's family pool (no duplicates per weapon).
//   - Tier advancement costs 1/2/3/4/5 Shards respectively (1 to reach T1,
//     2 more to reach T2, etc; 15 total to max a weapon).
//   - Re-rolling an existing tier's Overclock costs 1 Shard.
//
// This module replaces the previous "3 active per family, 2 Shards to apply"
// design. Pools are NOT re-rolled per run; randomization comes from the
// tier-up draw and the re-roll mechanic.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

// Tier costs per level (1-indexed in the design, but arrays are 0-indexed).
// Index 0 = cost to advance to T1, index 4 = cost to advance to T5.
#define ACC_TIER_MAX 5
#define ACC_TIER_COST_T1 1
#define ACC_TIER_COST_T2 2
#define ACC_TIER_COST_T3 3
#define ACC_TIER_COST_T4 4
#define ACC_TIER_COST_T5 5
#define ACC_OC_REROLL_COST_SHARDS 1

#namespace acc_overclocks;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "overclocks init (Tier 1-5 model)" );

    level.acc_oc_pools = build_family_pools();
    // Active-3-per-family roll REMOVED in new design - pools are visible in
    // full, randomization happens per tier-up.

    level thread watch_terminal_trigger();
}

function on_player_connect( player )
{
    // Per-player, per-weapon tier + Overclock state.
    // Shape: player.acc_weapon_progress[ weapon_name ] = struct {
    //   tier (int 0..5),
    //   overclocks (array of overclock_id strings, length = tier)
    // }
    player.acc_weapon_progress = [];
}

// Helper: get or init progress struct for a weapon.
function get_or_init_progress( player, weapon_name )
{
    if ( !isdefined( player.acc_weapon_progress[ weapon_name ] ) )
    {
        p = spawnstruct();
        p.tier = 0;
        p.overclocks = [];
        player.acc_weapon_progress[ weapon_name ] = p;
    }
    return player.acc_weapon_progress[ weapon_name ];
}

function tier_cost( target_tier )
{
    switch ( target_tier )
    {
    case 1: return ACC_TIER_COST_T1;
    case 2: return ACC_TIER_COST_T2;
    case 3: return ACC_TIER_COST_T3;
    case 4: return ACC_TIER_COST_T4;
    case 5: return ACC_TIER_COST_T5;
    }
    return 0;
}

// ---------------------------------------------------------------------------
// Pool definition. Synced with docs/05_weapons.md.
// Each overclock is a struct with id, display_name, on_apply (callback).
// ---------------------------------------------------------------------------

function build_family_pools()
{
    pools = [];

    pools[ "ar" ] = array(
        oc( "ar_burst_coil",   "Burst Coil",     &apply_oc_ar_burst_coil ),
        oc( "ar_overpressure", "Overpressure",   &apply_oc_ar_overpressure ),
        oc( "ar_piercing",     "Piercing Rounds",&apply_oc_ar_piercing ),
        oc( "ar_adaptive",     "Adaptive Aim",   &apply_oc_ar_adaptive ),
        oc( "ar_overheat",     "Overheat",       &apply_oc_ar_overheat ),
        oc( "ar_subcritical",  "Subcritical",    &apply_oc_ar_subcritical )
    );

    pools[ "smg" ] = array(
        oc( "smg_swarm",       "Swarm",          &apply_oc_smg_swarm ),
        oc( "smg_reflex_fire", "Reflex Fire",    &apply_oc_smg_reflex ),
        oc( "smg_coolant",     "Coolant Flow",   &apply_oc_smg_coolant ),
        oc( "smg_shrapnel",    "Shrapnel",       &apply_oc_smg_shrapnel ),
        oc( "smg_microboost",  "Micro-Boost",    &apply_oc_smg_microboost )
    );

    pools[ "shotgun" ] = array(
        oc( "sg_spread_cone",  "Spread Cone",    &apply_oc_sg_spread ),
        oc( "sg_breach",       "Breach",         &apply_oc_sg_breach ),
        oc( "sg_concussive",   "Concussive",     &apply_oc_sg_concussive ),
        oc( "sg_reflow",       "Reflow",         &apply_oc_sg_reflow )
    );

    pools[ "sniper" ] = array(
        oc( "sr_thermal",      "Thermal Lock",   &apply_oc_sr_thermal ),
        oc( "sr_penetration",  "Penetration Round", &apply_oc_sr_penetration ),
        oc( "sr_reactive",     "Reactive Powder",&apply_oc_sr_reactive ),
        oc( "sr_quickchamber", "Quick Chamber",  &apply_oc_sr_quickchamber )
    );

    pools[ "lmg" ] = array(
        oc( "lmg_sustained",   "Sustained Fire", &apply_oc_lmg_sustained ),
        oc( "lmg_suppression", "Suppression",    &apply_oc_lmg_suppression ),
        oc( "lmg_reload_drum", "Reload Drum",    &apply_oc_lmg_reloaddrum )
    );

    return pools;
}

function oc( id, name, on_apply )
{
    o = spawnstruct();
    o.id = id;
    o.display_name = name;
    o.on_apply = on_apply;
    return o;
}

// ---------------------------------------------------------------------------
// Terminal interaction
// ---------------------------------------------------------------------------

function watch_terminal_trigger()
{
    level endon( "end_game" );

    triggers = getentarray( "acc_overclock_terminal", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "overclocks: no terminal placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread terminal_loop();
    }
}

function terminal_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );

        current = player getcurrentweapon();
        family = weapon_name_to_family( current );
        if ( family == "unknown" )
        {
            player iprintln( "Overclock Terminal: weapon not supported" );
            wait( 0.5 );
            continue;
        }
        if ( family == "none" )
        {
            player iprintln( "Overclock Terminal: this weapon class cannot be tiered" );
            wait( 0.5 );
            continue;
        }

        progress = get_or_init_progress( player, current );

        // TODO(acc-ui): the real UX should present TWO options at the terminal:
        //   [1] Advance to Tier N+1 (cost: tier_cost(N+1) Shards)
        //   [2] Re-roll an existing Tier's Overclock (cost: 1 Shard)
        // For Phase 3 we auto-advance tier if possible, fall back to re-roll
        // the most-recent tier if already maxed. LUI pick screen comes Phase 4.

        if ( progress.tier < ACC_TIER_MAX )
        {
            next_tier = progress.tier + 1;
            cost = tier_cost( next_tier );

            if ( !acc_data_shards::try_spend( player, cost ) )
            {
                player iprintln( "Overclock Terminal: Tier " + next_tier +
                                 " costs " + cost + " Shard(s)" );
                wait( 0.5 );
                continue;
            }

            applied = roll_new_overclock_for_weapon( player, current, family, progress );
            progress.tier = next_tier;
            if ( isdefined( applied ) )
            {
                progress.overclocks[ progress.overclocks.size ] = applied.id;
                player [[ applied.on_apply ]]( current );
                player iprintln( "Tier " + next_tier + " - " + applied.display_name );
            }
            else
            {
                player iprintln( "Tier " + next_tier + " (family pool exhausted, slot empty)" );
            }
            wait( 0.5 );
            continue;
        }

        // Already at max tier - re-roll the most recent Overclock.
        if ( !acc_data_shards::try_spend( player, ACC_OC_REROLL_COST_SHARDS ) )
        {
            player iprintln( "Overclock Terminal: re-roll costs " +
                             ACC_OC_REROLL_COST_SHARDS + " Shard" );
            wait( 0.5 );
            continue;
        }
        new_roll = roll_new_overclock_for_weapon( player, current, family, progress );
        if ( isdefined( new_roll ) )
        {
            // Replace last slot.
            last_idx = progress.overclocks.size - 1;
            progress.overclocks[ last_idx ] = new_roll.id;
            player [[ new_roll.on_apply ]]( current );
            player iprintln( "Re-rolled Tier 5 - " + new_roll.display_name );
        }
        else
        {
            player iprintln( "Re-roll: no new Overclock available" );
        }
        wait( 0.5 );
    }
}

// Pick a random Overclock from the family pool that isn't already active
// on this weapon. Returns undefined if pool is exhausted.
function roll_new_overclock_for_weapon( player, weapon_name, family, progress )
{
    pool = level.acc_oc_pools[ family ];
    if ( !isdefined( pool ) || pool.size == 0 ) return undefined;

    // Build candidate list of Overclocks not already on this weapon.
    existing_ids = progress.overclocks;
    candidates = [];
    for ( i = 0; i < pool.size; i++ )
    {
        oc_struct = pool[ i ];
        dup = false;
        for ( j = 0; j < existing_ids.size; j++ )
        {
            if ( oc_struct.id == existing_ids[ j ] )
            {
                dup = true;
                break;
            }
        }
        if ( !dup ) candidates[ candidates.size ] = oc_struct;
    }

    if ( candidates.size == 0 ) return undefined;
    return candidates[ acc_utility::acc_rand_int( candidates.size ) ];
}

// ---------------------------------------------------------------------------
// Weapon classification
// ---------------------------------------------------------------------------

// Takes the weapon OBJECT from GetCurrentWeapon() (BO3 weapons are objects,
// not strings - stock compares weapon.name, e.g. _zm_weapons.gsc:2650).
function weapon_name_to_family( weapon_name )
{
    // TODO(acc-data): replace this giant switch with a GDT-driven table.
    // Source of truth: docs/05_weapons.md (the 16-weapon roster).
    //
    // Families that CAN be Overclocked:
    //   ar      -> ICR-1, XR-2, AK-47 (full-auto) + M14 EBR, G3, FN FAL (semi-auto)
    //   shotgun -> Haymaker 12, Brecci, Tac-19
    //   sniper  -> Drakon, Locus, Intervention
    //   lmg     -> none in v1.0 (pool dormant for post-1.0 LMG re-add)
    //   smg     -> none in v1.0 (pool dormant for post-1.0 SMG re-add)
    // ARSENAL RESTRICTED (user, 2026-06-13): only ICR-1 + Man-O-War exist on the
    // map. Both are the "ar" Overclock family. (The old "<name>_zm" strings were
    // never valid - stock BO3 weapon base names are class-based + unsuffixed, so
    // weapon_name_to_family would have returned "unknown" and silently disabled
    // Overclocks on both guns.)
    ar_list = array(
        "ar_accurate",   // ICR-1
        "ar_damage"      // Man-O-War
    );
    smg_list = array();
    sg_list = array( "haymaker12_zm", "brecci_zm", "tac19_zm" );
    sr_list = array( "drakon_zm", "locus_zm", "intervention_zm" );
    lmg_list = array();

    // Families that CANNOT be Overclocked (return distinct sentinel "none" so
    // the terminal can print a useful message instead of "unknown"):
    pistol_list = array( "b23r_zm" );
    melee_list = array( "bowie_knife_zm", "cyber_cleaver_zm" );
    grenade_list = array( "frag_grenade_zm", "emp_grenade_zm" );
    // Wonder weapons have intrinsic Overclocks (all 3 always active), not
    // terminal-applied. Route them to "none" so the terminal refuses them.
    wonder_list = array( "signal_staff_zm", "vibro_cleaver_zm" );

    base = strip_pap_suffix( weapon_name );

    if ( array::contains( ar_list, base ) ) return "ar";
    if ( array::contains( smg_list, base ) ) return "smg";
    if ( array::contains( sg_list, base ) ) return "shotgun";
    if ( array::contains( sr_list, base ) ) return "sniper";
    if ( array::contains( lmg_list, base ) ) return "lmg";
    if ( array::contains( pistol_list, base ) ) return "none";
    if ( array::contains( melee_list, base ) ) return "none";
    if ( array::contains( grenade_list, base ) ) return "none";
    if ( array::contains( wonder_list, base ) ) return "none";
    return "unknown";
}

// Resolve a (possibly PaP'd) weapon OBJECT to its base weapon NAME string.
// VERIFIED(acc): BO3 PaP mapping is table-driven, not suffix-based -
// zm_weapons::get_base_weapon (_zm_weapons.gsc:1624) resolves via
// level.zombie_weapons_upgraded and handles non-upgraded weapons too.
// Returning .name gives the string the family lists compare against.
function strip_pap_suffix( weapon )
{
    base = zm_weapons::get_base_weapon( weapon );
    return base.name;
}

// ---------------------------------------------------------------------------
// Effect implementations (stubs - flesh out in Phase 3/4)
//
// Each function runs on `self` = the player with the weapon equipped.
// Storage convention: self.acc_oc_active[ weapon_name ] = struct of flags.
// ---------------------------------------------------------------------------

function apply_oc_ar_burst_coil( weapon )        { set_oc_flag( weapon, "burst_coil", true ); }
function apply_oc_ar_overpressure( weapon )      { set_oc_flag( weapon, "overpressure", true ); }
function apply_oc_ar_piercing( weapon )          { set_oc_flag( weapon, "piercing", true ); }
function apply_oc_ar_adaptive( weapon )          { set_oc_flag( weapon, "adaptive", true ); }
function apply_oc_ar_overheat( weapon )          { set_oc_flag( weapon, "overheat", true ); }
function apply_oc_ar_subcritical( weapon )       { set_oc_flag( weapon, "subcritical", true ); }

function apply_oc_smg_swarm( weapon )            { set_oc_flag( weapon, "swarm", true ); }
function apply_oc_smg_reflex( weapon )           { set_oc_flag( weapon, "reflex_fire", true ); }
function apply_oc_smg_coolant( weapon )          { set_oc_flag( weapon, "coolant", true ); }
function apply_oc_smg_shrapnel( weapon )         { set_oc_flag( weapon, "shrapnel", true ); }
function apply_oc_smg_microboost( weapon )       { set_oc_flag( weapon, "microboost", true ); }

function apply_oc_sg_spread( weapon )            { set_oc_flag( weapon, "spread", true ); }
function apply_oc_sg_breach( weapon )            { set_oc_flag( weapon, "breach", true ); }
function apply_oc_sg_concussive( weapon )        { set_oc_flag( weapon, "concussive", true ); }
function apply_oc_sg_reflow( weapon )            { set_oc_flag( weapon, "reflow", true ); }

function apply_oc_sr_thermal( weapon )           { set_oc_flag( weapon, "thermal", true ); }
function apply_oc_sr_penetration( weapon )       { set_oc_flag( weapon, "penetration", true ); }
function apply_oc_sr_reactive( weapon )          { set_oc_flag( weapon, "reactive", true ); }
function apply_oc_sr_quickchamber( weapon )      { set_oc_flag( weapon, "quickchamber", true ); }

function apply_oc_lmg_sustained( weapon )        { set_oc_flag( weapon, "sustained", true ); }
function apply_oc_lmg_suppression( weapon )      { set_oc_flag( weapon, "suppression", true ); }
function apply_oc_lmg_reloaddrum( weapon )       { set_oc_flag( weapon, "reloaddrum", true ); }

function set_oc_flag( weapon, flag_name, value )
{
    // VERIFIED(acc): BO3 GSC has no dynamic member syntax (obj.(name) appears
    // nowhere in stock); string-keyed arrays are the stock pattern
    // (_zm.gsc:3054 self.stored_weapon_info[ weapon ] = SpawnStruct()).
    if ( !isdefined( self.acc_oc_active ) ) self.acc_oc_active = [];
    if ( !isdefined( self.acc_oc_active[ weapon ] ) ) self.acc_oc_active[ weapon ] = [];
    self.acc_oc_active[ weapon ][ flag_name ] = value;
    // Damage callback / weapon-fire callback reads these flags at runtime.
    // See damage hook in _acc_elites.gsc / _acc_main.gsc callbacks.
}
