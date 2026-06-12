// =============================================================================
// _acc_map_randomizer.gsc - per-run map state
//
// Design reference: docs/07_replayability.md (Tier 1 - Per-Run Map State).
//
// Runs in pre_init(). Rolls a state struct that every other system can read
// from `level.acc_map_state`. Logs the roll for debuggability.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_map_randomizer;

function pre_init()
{
    acc_utility::log( "map_randomizer pre_init" );

    state = spawnstruct();
    state.power_switch_side = roll_power_switch_side();
    state.pap_approach = roll_pap_approach();
    state.wallbuy_pool = roll_wallbuy_pool();
    state.mystery_box_initial = roll_mystery_box_initial();
    // VERIFIED(acc): the initial box location must be set HERE, not at
    // blackscreen time - stock treasure_chest_init runs ~0.05s after magicbox
    // init (_zm_magicbox.gsc:96) reading level.start_chest_name (default
    // "start_chest", :58), matched against chest script_noteworthy via
    // IsSubStr (:223). Radiant chests need script_noteworthy acc_box_market /
    // acc_box_corp / acc_box_roof.
    level.start_chest_name = "acc_box_" + state.mystery_box_initial;
    // Perk rotation is rolled PER ROUND, not per run. See roll_perk_rotation
    // below and the hookup in init() / apply_state_when_ready().

    level.acc_map_state = state;
    level.acc_perk_rotation = [];

    log_state( state );

    // Apply state to the world (open the correct door, close the other, etc.)
    // after _zm has initialized zones. Defer to post-init via thread+flag.
    level thread apply_state_when_ready();
    // Per-round perk rotation listener.
    level thread watch_round_for_perk_rotation();
}

// ---------------------------------------------------------------------------
// Roll functions
// ---------------------------------------------------------------------------

function roll_power_switch_side()
{
    // A (Corp) or B (Server Vault). 50/50.
    return acc_utility::acc_rand_int( 2 ) == 0 ? "corp" : "vault";
}

function roll_pap_approach()
{
    // "server" or "roof" - the BLOCKED side this run.
    return acc_utility::acc_rand_int( 2 ) == 0 ? "server" : "roof";
}

function roll_wallbuy_pool()
{
    // Source of truth: docs/05_weapons.md (16-weapon roster).
    //
    // Rule: wallbuys dispense NORMAL-tier weapons only. Bad + Strong tier
    // weapons live in the Mystery Box (see register_mystery_box_pool).
    //
    // v1.0 ships with exactly one normal per category so most slots are
    // single-candidate. The pool function exists so post-1.0 category
    // expansions plug in without changing callers.
    pool = [];

    // VERIFIED(acc): stock BO3 weapon names are class-based and unsuffixed
    // (every GetWeapon("...") in the stock mirror: "pistol_standard",
    // "shotgun_fullauto", "bowie_knife"...). The old "<marketing>_zm" names
    // exist nowhere in stock - that's the BO1/BO2 convention. The marketing ->
    // class mapping below comes from the mod tools GDT naming; confirm the
    // AR/sniper entries against the weapon GDT on first compile.

    // Service Alley: shotgun (Haymaker 12, stock BO3 auto-shotgun).
    pool[ "alley_shotgun" ] = acc_utility::acc_weighted_pick( array(
        weighted( 100, "shotgun_fullauto" )
    ) );

    // Corporate Plaza (slot A): full-auto AR (ICR-1, stock).
    // NOTE: "ar_standard" is the KN-44; the ICR-1 is "ar_accurate".
    pool[ "corp_ar_full_auto" ] = acc_utility::acc_weighted_pick( array(
        weighted( 100, "ar_accurate" )
    ) );

    // Corporate Plaza (slot B): semi-auto AR (M14 EBR, MW2 import).
    pool[ "corp_ar_semi_auto" ] = acc_utility::acc_weighted_pick( array(
        weighted( 100, "m14ebr_zm" )
    ) );

    // Rooftop Helipad: sniper (Drakon, stock BO3 semi-auto).
    pool[ "roof_sniper" ] = acc_utility::acc_weighted_pick( array(
        weighted( 100, "sniper_fastsemi" )
    ) );

    // Near-perk melee upgrade (Bowie Knife, stock BO3).
    pool[ "melee_upgrade" ] = "bowie_knife";

    // Server Vault tactical re-ammo (EMP Grenade, custom).
    pool[ "vault_tactical" ] = "emp_grenade_zm";

    return pool;
}

// Mystery Box pool. Registered once on map load; roll is handled by stock
// _zm_magicbox logic which we extend by registering our weapons into its pool.
//
// Contains all BAD and STRONG tier weapons from docs/05_weapons.md. Normal
// tier weapons are NOT in the box in v1.0 - that's an intentional design
// choice to preserve the "bad vs strong roll" tension. If you want wallbuy
// weapons to also appear in the box, add them here.
function register_mystery_box_pool()
{
    acc_utility::log( "mystery box: registering pool" );

    box_weapons = array(
        // Shotguns (stock class names - see roll_wallbuy_pool note)
        "shotgun_semiauto", // bad (Brecci)
        "tac19_zm",         // strong (AW import, custom GDT - Phase 4)
        // AR full-auto
        "ar_longburst",     // bad (XR-2)
        "ak47_zm",          // strong (import, custom GDT - Phase 4)
        // Semi-auto AR
        "g3_zm",            // bad (WAW import, custom GDT - Phase 4)
        "fnfal_zm",         // strong (BO1/BO2 import, custom GDT - Phase 4)
        // Sniper
        "sniper_fastbolt",  // bad (Locus)
        "intervention_zm"   // strong (MW2 import, custom GDT - Phase 4)
    );

    for ( i = 0; i < box_weapons.size; i++ )
    {
        w = box_weapons[ i ];
        // VERIFIED(acc): at this point (post-blackscreen) the box reads the
        // live snapshot level.zombie_weapons[wpn].is_in_box, re-evaluated per
        // spin (_zm_magicbox.gsc:1273/1222 -> _zm_weapons.gsc:1492). Each
        // weapon also needs a row in the loaded weapon table (CSV) - without
        // one there is no level.zombie_weapons struct to flip.
        wpn = GetWeapon( w );
        if ( isdefined( level.zombie_weapons[ wpn ] ) )
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
        "specialty_acc_deadshot",                 // Deadshot (custom)
        "specialty_acc_widows_wine",              // Widow's Wine (custom)
        "specialty_acc_aura_blast"                // Aura Blast (custom active)
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

    // DESIGN (docs/03_layout.md, docs/13_perks.md): perk machines must re-roll
    // AFTER the decontamination phase (20s evac + seal), not on acc_round_start.
    // TODO(acc-implement): waittill( "acc_decontamination_complete", round_number );
    // Phase 3 stub still rolls on acc_round_start — replace when
    // _acc_decontamination.gsc exists.
    for ( ;; )
    {
        level waittill( "acc_round_start", round_number );
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
    // Pick one of three initial nodes (Market, Corp, Roof).
    nodes = array( "market", "corp", "roof" );
    return nodes[ acc_utility::acc_rand_int( nodes.size ) ];
}

// ---------------------------------------------------------------------------
// State application
// ---------------------------------------------------------------------------

function apply_state_when_ready()
{
    level endon( "end_game" );

    // VERIFIED(acc): flag, not notify - see _acc_main.gsc note.
    level flag::wait_till( "initial_blackscreen_passed" );

    apply_power_switch_side( level.acc_map_state.power_switch_side );
    apply_pap_approach( level.acc_map_state.pap_approach );
    apply_wallbuy_pool( level.acc_map_state.wallbuy_pool );
    apply_mystery_box_initial( level.acc_map_state.mystery_box_initial );
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
    // Turn the LOSING side's handle into an inert prop.
    dead_side = side == "corp" ? "vault" : "corp";

    // TODO(acc-geom): Radiant should place two power-switch triggers with
    // targetnames "acc_power_corp" and "acc_power_vault". Delete (or disable
    // the trigger) on the dead side.
    dead_triggers = getentarray( "acc_power_" + dead_side, "targetname" );
    for ( i = 0; i < dead_triggers.size; i++ )
    {
        dead_triggers[ i ] triggerenable( false );
    }
}

function apply_pap_approach( blocked_side )
{
    // Block one of the two approaches with a prefab "welded door".
    // TODO(acc-geom): Radiant should place two script_brushmodels named
    // "acc_pap_block_server" and "acc_pap_block_roof", each hidden by default.
    // Show the one matching the blocked_side.
    to_block = getentarray( "acc_pap_block_" + blocked_side, "targetname" );
    for ( i = 0; i < to_block.size; i++ )
    {
        to_block[ i ] show();
        to_block[ i ] solid();
    }
}

function apply_wallbuy_pool( pool )
{
    // TODO(acc-wallbuy): use _zm_weapons wallbuy API to set each slot's weapon.
    // Radiant wallbuy prefabs need to accept a targetname we can look up, e.g.
    // "acc_wb_spawn_pistol" -> sets that wallbuy's weapon to pool["spawn_pistol"].
    keys = getarraykeys( pool );
    for ( i = 0; i < keys.size; i++ )
    {
        // Intentional no-op until Radiant geometry exists.
        acc_utility::log( "wallbuy " + keys[ i ] + " -> " + pool[ keys[ i ] ] );
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

    keys = getarraykeys( state.wallbuy_pool );
    for ( i = 0; i < keys.size; i++ )
    {
        acc_utility::log( "  wb " + keys[ i ] + "=" + state.wallbuy_pool[ keys[ i ] ] );
    }

    // Perk rotation is logged per-round by roll_perk_rotation; not part of
    // map-load state.
}
