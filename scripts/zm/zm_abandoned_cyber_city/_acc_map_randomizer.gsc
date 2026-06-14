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
//   - apply_wallbuy_pool() must run after zm_usermap::main() (the stock
//     wallbuy stubs it rewrites are built inside it) and before the first
//     player can approach a wallbuy (purchase triggers are built lazily per
//     player). pre_init() satisfies both. See the long note on the function
//     for why we deliberately do NOT rewrite the Radiant structs before the
//     stock read point.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

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

    // Pre-tick applies. Both MUST happen synchronously here (see the timing
    // contract in the file header + the VERIFIED notes on each function):
    //   - power: delete the dead side's stock switch trigger BEFORE the
    //     zm_power postload thread collects it.
    //   - wallbuys: rewrite the stock purchase stubs BEFORE any player
    //     proximity builds a purchase trigger from them.
    apply_power_switch_side( state.power_switch_side );
    apply_wallbuy_pool( state.wallbuy_pool );

    // Apply the remaining state to the world (PaP blocker brushes, dead-side
    // emergency-drop trigger disable, box pool registration) after _zm has
    // initialized. Defer to post-init via thread+flag.
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
    return ( acc_utility::acc_rand_int( 2 ) == 0 ? "corp" : "vault" );
}

function roll_pap_approach()
{
    // "server" or "roof" - the BLOCKED side this run.
    return ( acc_utility::acc_rand_int( 2 ) == 0 ? "server" : "roof" );
}

function roll_wallbuy_pool()
{
    // Source of truth: docs/05_weapons.md (weapon roster) +
    // docs/07_replayability.md (per-run wallbuy randomization).
    //
    // Rule: wallbuys dispense NORMAL-tier weapons only. Bad + Strong tier
    // weapons live in the Mystery Box (see register_mystery_box_pool). If a
    // box-pool weapon gets rolled onto a wall this run, it is skipped during
    // box registration so it stays wall-exclusive (see is_rolled_onto_wall).
    //
    // SLOT KEYS are the Radiant-authored zombie_weapon_upgrade defaults of the
    // placed wallbuy structs (start-room gameplay set). The key doubles as the
    // slot's identity when apply_wallbuy_pool matches structs, so each placed
    // wallbuy MUST keep a unique default weapon:
    //   ar_accurate (ICR-1), shotgun_fullauto (Haymaker 12),
    //   sniper_fastsemi (Drakon), ar_marksman (Sheiva),
    //   frag_grenade (Frag), bowie_knife (Bowie, targetname bowie_upgrade).
    //
    // VERIFIED(acc): stock BO3 weapon names are class-based and unsuffixed
    // (every GetWeapon("...") in the stock mirror: "pistol_standard",
    // "shotgun_fullauto", "bowie_knife"...). The old "<marketing>_zm" names
    // exist nowhere in stock - that's the BO1/BO2 convention. Candidate-name
    // evidence (only names with verified evidence are used - others stay
    // single-candidate with a TODO):
    //   ar_accurate/ar_standard/ar_longburst/sniper_fastsemi/sniper_fastbolt/
    //   shotgun_fullauto/bowie_knife: docs/19_stock_api_verification.md:41
    //   ("ar_standard is the KN-44!").
    //   ar_standard additionally: GetWeapon("ar_standard") in stock
    //   scene_shared.gsc:72 + _character_customization.csc:388.
    //   shotgun_precision: stock zombies AI code matches the class name
    //   (mechz.gsc:1471 isSubStr(weapon.name, "shotgun_precision")).
    //   ar_marksman/frag_grenade: docs/20_requirements_checklist.md:263.
    // Marketing identities for the alternates (KN-44, KRM-262, Locus, XR-2)
    // come from mod tools GDT naming - confirm on first compile (the class
    // names themselves are the load-bearing part).
    //
    // Stock candidates ride into the fastfile via the zm_levelcommon_weapons
    // csv stringtable (docs/16_gsc_reference.md:345) - no weaponfull zone
    // lines needed. roll_wallbuy_slot() still validates each candidate
    // against the live weapon table and falls back to the slot default if a
    // candidate has no row, so a missing csv entry degrades to the Radiant
    // gun instead of tripping the stock asserts (_zm_weapons.gsc:1419/:1426).
    // ARSENAL RESTRICTED (user, 2026-06-13): the ONLY guns on the map are the
    // ICR-1 (ar_accurate) and the Man-O-War (ar_damage). We keep only the ICR
    // wall slot here and drop the other four wall slots from the pool. With no
    // pool entry, apply_wallbuy_pool builds NO purchase trigger for those placed
    // structs, so the Haymaker / Drakon / Sheiva / Frag walls simply go dead -
    // no .map edit / geometry rebuild needed (apply_wallbuy_pool already logs
    // "no struct for slot" gracefully for the inverse case). Man-O-War has no
    // placed wall struct, so it is mystery-box-only (register_mystery_box_pool).
    pool = [];

    // ICR-1 wall (Radiant default ar_accurate) - pinned, no alternate roll.
    pool[ "ar_accurate" ] = "ar_accurate";

    // Near-perk melee upgrade (Bowie Knife, stock BO3) - not a gun, own stub
    // plumbing (targetname bowie_upgrade, _zm_weapons.gsc:843); kept.
    pool[ "bowie_knife" ] = "bowie_knife";

    return pool;
}

// Roll one wallbuy slot from a weighted candidate list, keeping only
// candidates that actually have a row in the loaded weapon table. Falls back
// to the slot's Radiant default when validation eliminates everything (or
// when the table is not up yet, which would mean pre_init ran before
// zm_usermap::main - an ordering regression we degrade through, not crash).
function roll_wallbuy_slot( slot_default, candidates )
{
    valid = [];
    for ( i = 0; i < candidates.size; i++ )
    {
        if ( weapon_in_zm_table( candidates[ i ].value ) )
        {
            valid[ valid.size ] = candidates[ i ];
        }
        else
        {
            acc_utility::log( "wallbuy slot " + slot_default +
                              ": candidate missing from weapon table: " +
                              candidates[ i ].value );
        }
    }

    if ( valid.size == 0 )
    {
        return slot_default;
    }

    return acc_utility::acc_weighted_pick( valid );
}

function weapon_in_zm_table( weapon_name )
{
    // VERIFIED(acc): level.zombie_weapons is keyed by weapon OBJECT, and the
    // stock cost/hint getters assert table membership instead of returning a
    // default (_zm_weapons.gsc:1417-1429) - validate before ever calling them.
    if ( !isdefined( level.zombie_weapons ) )
    {
        return false;
    }

    wpn = GetWeapon( weapon_name );
    return isdefined( wpn ) && isdefined( level.zombie_weapons[ wpn ] );
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

    // ARSENAL RESTRICTED (user, 2026-06-13): box gives ONLY ICR-1 + Man-O-War.
    // Both are stock rows (in_box=TRUE). The ICR is also a wallbuy, but we want
    // it in the box too, so the is_rolled_onto_wall exclusion is intentionally
    // NOT applied to these two (it was for the old bad/strong split).
    box_weapons = array(
        "ar_accurate",      // ICR-1
        "ar_damage"         // Man-O-War
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

function is_rolled_onto_wall( weapon_name )
{
    if ( !isdefined( level.acc_map_state ) ||
         !isdefined( level.acc_map_state.wallbuy_pool ) )
    {
        return false;
    }

    keys = getarraykeys( level.acc_map_state.wallbuy_pool );
    for ( i = 0; i < keys.size; i++ )
    {
        if ( level.acc_map_state.wallbuy_pool[ keys[ i ] ] == weapon_name )
        {
            return true;
        }
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
        // Wine are stock modules; Aura Blast hijacks the electric-cherry perk.
        "specialty_deadshot",                     // Deadshot (custom-tuned)
        "specialty_widowswine",                   // Widow's Wine (+ boosts)
        "specialty_electriccherry"                // Aura Blast (over electric cherry)
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

    // NOTE: apply_power_switch_side and apply_wallbuy_pool already ran
    // synchronously in pre_init() - both have pre-tick timing requirements
    // (see their VERIFIED notes). Only the pieces that are safe (and in the
    // PaP case, intended) at blackscreen run here.
    disable_dead_side_emergency_triggers( level.acc_map_state.power_switch_side );
    apply_pap_approach( level.acc_map_state.pap_approach );
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
    // Kill the LOSING side's stock power switch so its handle becomes an
    // inert prop, leaving the live side 100% stock (hint, flip animation,
    // sparks, "power_on" flag, perk unpause, doors, RecordMapEvent).
    //
    // Radiant contract: TWO stock power-switch prefab instances. Each inner
    // trigger carries targetname use_elec_switch plus an instance-propagated
    // script_string "corp" / "vault" (stock reads only target / script_int /
    // script_noteworthy on these triggers, so script_string is free for us).
    // Each trigger has exactly one companion elec_switch_fx struct.
    //
    // VERIFIED(acc): stock collects the switch triggers via
    // GetEntArray("use_elec_switch","targetname") in electric_switch_init
    // (_zm_power.gsc:41), threaded from zm_power's __main__ - a
    // REGISTER_SYSTEM_EX *postload* func (_zm_power.gsc:24-37) that the
    // engine runs in CodeCallback_FinalizeInitialization AFTER entry main()
    // returns (callbacks_shared.gsc:540-543, system_shared.gsc:17-23). This
    // function is called from pre_init(), i.e. still inside entry main(), so
    // the Delete() lands before stock ever sees the trigger.
    // VERIFIED(acc): deleting here (after zm_usermap::main()) cannot skew the
    // power clientfields - "zombie_power_on"/"zombie_power_off" bit widths
    // are computed from the use_elec_switch trigger COUNT in
    // init_client_field_callback_funcs (_zm.gsc:1655-1661), which zm::init
    // already called (_zm.gsc:352) inside zm_usermap::main(), before we run.
    // The client sizes the same fields from the elec_switch_fx struct count
    // (_zm.csc:329-336), which we never touch. Both sides keep counting 2 -
    // map must ship exactly 2 triggers + 2 fx structs.
    // VERIFIED(acc): do NOT put script_int on either trigger - zoned switches
    // set flag "power_on"+N and never the global "power_on" flag every acc
    // consumer waits on (_zm_power.gsc:728-737).
    dead_side = ( side == "corp" ? "vault" : "corp" );

    switch_trigs = getentarray( "use_elec_switch", "targetname" );
    if ( switch_trigs.size == 0 )
    {
        acc_utility::log( "power: no stock use_elec_switch triggers in map yet" );
        return;
    }

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

    if ( killed == 0 )
    {
        acc_utility::log( "power: WARNING no use_elec_switch trigger tagged '" +
                          dead_side + "' - both switches remain live" );
        return;
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
    // Radiant contract: two script_brushmodels named acc_pap_block_server /
    // acc_pap_block_roof, authored VISIBLE + SOLID in the two lab corridors.
    // Per run: the rolled side stays blocked, the other side opens.
    open_side = ( blocked_side == "server" ? "roof" : "server" );

    // Blocked side: re-assert visible+solid (already authored that way) and
    // cut the AI navgrid.
    // VERIFIED(acc): DisconnectPaths is called directly on solid
    // script_brushmodel door pieces at stock door init
    // (_zm_blockers.gsc:272-275 "if (self.classname == \"script_brushmodel\")
    // self DisconnectPaths();").
    to_block = getentarray( "acc_pap_block_" + blocked_side, "targetname" );
    for ( i = 0; i < to_block.size; i++ )
    {
        to_block[ i ] show();
        to_block[ i ] solid();
        to_block[ i ] disconnectpaths();
    }

    // Unblocked side: hide, drop collision, reconnect the navgrid - same
    // order stock uses when a door opens.
    // VERIFIED(acc): stock door_buy open path runs NotSolid()
    // (_zm_blockers.gsc:507) and then ConnectPaths() on script_brushmodel /
    // script_model door pieces (_zm_blockers.gsc:511-517).
    to_open = getentarray( "acc_pap_block_" + open_side, "targetname" );
    for ( i = 0; i < to_open.size; i++ )
    {
        to_open[ i ] hide();
        to_open[ i ] notsolid();
        to_open[ i ] connectpaths();
    }

    if ( to_block.size == 0 && to_open.size == 0 )
    {
        acc_utility::log( "pap: no acc_pap_block_* brushes in map yet" );
        return;
    }

    acc_utility::log( "pap: blocked=" + blocked_side + " (" + to_block.size +
                      " brush(es)), open=" + open_side + " (" + to_open.size +
                      " brush(es))" );
}

function apply_wallbuy_pool( pool )
{
    // REAL slot randomization, applied to the stock purchase layer.
    //
    // WHERE STOCK READS THE STRUCTS (the read point we are working around):
    // VERIFIED(acc): init_spawnable_weapon_upgrade reads the wallbuy structs
    // via struct::get_array("weapon_upgrade"/"bowie_upgrade","targetname")
    // (_zm_weapons.gsc:836,:842-843). It is NOT a REGISTER_SYSTEM_EX
    // postload - _zm_weapons has no system registration at all; its init()
    // runs synchronously INSIDE zm_usermap::main(): zm_usermap.gsc:144
    // load::main() -> _load.gsc:79 zm::init() -> _zm.gsc:365
    // zm_weapons::init() -> _zm_weapons.gsc:60 init_weapon_upgrade() ->
    // :1382 init_spawnable_weapon_upgrade(). So by the time pre_init() runs,
    // the structs have already been read.
    //
    // WHY WE DELIBERATELY DO NOT REWRITE THE STRUCTS BEFORE THAT READ:
    // a pre-zm_usermap::main() rewrite of .zombie_weapon_upgrade would land
    // before the read, but it is server-only, and the wallbuy CLIENTFIELD
    // NAMES are built from .zombie_weapon_upgrade + origin on BOTH VMs:
    // VERIFIED(acc): GSC registers "world" fields named
    // zombie_weapon_upgrade+"_"+origin (_zm_weapons.gsc:904,:913) and the
    // client registers the SAME names from ITS copy of the structs
    // (_zm_weapons.csc:232,:243), with stock's own warning that the two
    // constructions "must be matched in _zm_weapons.csc function init() or
    // your level will not load" (_zm_weapons.gsc:839). A .csc cannot call
    // .gsc (separate VMs), so the client copy can never see a server-side
    // roll - a pre-read server rewrite provably diverges the registrations.
    //
    // WHY THE POST-READ STUB REWRITE IS FULLY EFFECTIVE INSTEAD:
    // VERIFIED(acc): purchase triggers do not exist at init - they are built
    // lazily per player from the unitrigger stub
    // (check_and_build_trigger_from_unitrigger_stub, _zm_unitrigger.gsc:637;
    // build_trigger_from_unitrigger_stub :665) which reads stub.cursor_hint /
    // cursor_hint_weapon (:734-736), stub.hint_string/cost (:749-765) and
    // copies stub.weapon onto the trigger (:800). The purchase logic itself
    // reads self.weapon / self.stub.weapon (weapon_spawn_think,
    // _zm_weapons.gsc:1994,:1996; prompt :1176-1178), and game-restart
    // reset_wallbuys re-derives hint+cost from stub.weapon
    // (_zm_weapons.gsc:1367-1369). The stubs live on the structs in
    // level._spawned_wallbuys (struct at _zm_weapons.gsc:1021, stub attached
    // at :1017). Rewriting struct+stub HERE - in pre_init, before any player
    // exists - is therefore provably before any trigger is built, and never
    // touches either VM's clientfield registration inputs.
    //
    // COSMETIC LIMIT (TODO(acc-art), Phase 4 .csc work): the client keeps the
    // Radiant-default gun for everything visual - chalk decal, wall weapon
    // model + bought-state model and blue-light fx (the client reads its own
    // struct copy: _zm_weapons.csc:232,:300) - and the trigger box dims were
    // sized from the default gun's model bounds (_zm_weapons.gsc:943-960).
    // Same-category guns keep this unnoticeable; a proper re-skin needs a
    // client module.
    if ( !isdefined( level._spawned_wallbuys ) )
    {
        acc_utility::log( "wallbuy: level._spawned_wallbuys missing - stock " +
                          "init has not run; slots keep Radiant defaults" );
        return;
    }

    applied = [];
    for ( i = 0; i < level._spawned_wallbuys.size; i++ )
    {
        s = level._spawned_wallbuys[ i ];
        if ( !isdefined( s.zombie_weapon_upgrade ) )
        {
            continue;
        }

        // Slot identity = the Radiant-authored default weapon name.
        slot_key = s.zombie_weapon_upgrade;
        if ( !isdefined( pool[ slot_key ] ) )
        {
            acc_utility::log( "wallbuy: unmanaged slot (no pool entry): " + slot_key );
            continue;
        }

        applied[ slot_key ] = true;

        rolled = pool[ slot_key ];
        if ( rolled == slot_key )
        {
            acc_utility::log( "wallbuy " + slot_key + " -> (kept default)" );
            continue;
        }

        // Belt + braces: roll_wallbuy_slot already validated, but never let
        // an unvalidated name reach the stock asserts
        // (_zm_weapons.gsc:1419/:1426).
        if ( !weapon_in_zm_table( rolled ) )
        {
            acc_utility::log( "wallbuy " + slot_key + ": rolled weapon '" +
                              rolled + "' missing from weapon table - reverting" );
            level.acc_map_state.wallbuy_pool[ slot_key ] = slot_key;
            continue;
        }

        wpn = GetWeapon( rolled );

        // Rewrite the server-side wallbuy record (consumed by reset paths and
        // anything walking level._spawned_wallbuys)...
        s.zombie_weapon_upgrade = rolled;
        s.weapon = wpn;

        // ...and the live purchase stub (consumed at lazy trigger build +
        // purchase, see VERIFIED block above).
        stub = s.trigger_stub;
        if ( isdefined( stub ) )
        {
            stub.weapon = wpn;
            if ( isdefined( stub.targetname ) && stub.targetname == "weapon_upgrade" )
            {
                // Mirrors stock's own stub setup for this targetname
                // (_zm_weapons.gsc:966-977).
                stub.cost = zm_weapons::get_weapon_cost( wpn );
                stub.hint_string = zm_weapons::get_weapon_hint( wpn );
                if ( !IS_TRUE( level.weapon_cost_client_filled ) )
                {
                    stub.hint_parm1 = stub.cost;
                }
                if ( isdefined( stub.cursor_hint ) && stub.cursor_hint == "HINT_WEAPON" )
                {
                    stub.cursor_hint_weapon = wpn;
                }
            }
        }
        else
        {
            acc_utility::log( "wallbuy " + slot_key + ": struct has no " +
                              "trigger_stub (buildable/deferred?) - struct-only rewrite" );
        }

        acc_utility::log( "wallbuy " + slot_key + " -> " + rolled );
    }

    // Surface slots that rolled but have no struct in the map (geometry not
    // placed yet, or filtered out by a script_noteworthy location mismatch -
    // ours must be empty or 'zclassic_perks_start_room'-style gametype tags
    // per _zm_weapons.gsc:880-897).
    keys = getarraykeys( pool );
    for ( i = 0; i < keys.size; i++ )
    {
        if ( !isdefined( applied[ keys[ i ] ] ) )
        {
            acc_utility::log( "wallbuy: no placed struct for slot " + keys[ i ] );
        }
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
