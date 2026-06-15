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
    //   - wallbuys: unregister every stock purchase stub BEFORE any player
    //     proximity builds a purchase trigger from them.
    apply_power_switch_side( state.power_switch_side );
    remove_all_wallbuys();

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

// Mystery Box pool. Registered once on map load (post-blackscreen); the draw
// is handled by stock _zm_magicbox logic, gated per spin on each weapon's live
// level.zombie_weapons[wpn].is_in_box flag.
//
// BOX ARSENAL (user, 2026-06-14): the box is being switched to Tac-19, Locus,
// FN FAL, AK-47 (docs/05_weapons.md tiers; import staging in docs/32). Of those
// only Locus is stock BO3 (sniper_fastbolt); Tac-19 (s1_tac19), FN FAL (t6_fal)
// and AK-47 (s1_ak47 / t6_ak47) are Skye weapon-pack imports that must be
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
    // box" (never a crash). +6 guns added 2026-06-15 (user): PPSH-41, AK-74u, PDW,
    // Nail Gun, Paladin HB50, M1911. Use the exact weapon asset ids (PPSH = the
    // _base mag variant; PDW/M1911 PaP to akimbo). See docs/05 + 33.
    box_weapons = array(
        "t6_fiveseven",     // Five-Seven (Skye BO2 - also the starting pistol)
        "s1_asm1",          // ASM1       (Skye AW)
        "s1_tac19",         // Tac-19     (Skye AW)
        "t6_ak47",          // AK-47      (Skye BO2)
        "s1_ae4",           // AE4        (Skye AW - directed-energy AR)
        "iw6_ripper_smg",   // Ripper     (Skye Ghosts - convertible SMG/AR; CSV name, box gives SMG mode)
        // Box guns re-added (2026-06-15). NO twins on any (BO3 weapon-count cap, docs/33).
        // All 4 below cleared by the per-gun anomaly scan + adversarial GDT verify (docs/33
        // "Failure modes"): altWeapon chains, akimbo PaP forms, projectile type all checked.
        "t8_paladin_hb50",       // Paladin HB50 (BO4 sniper) - confirmed working
        "s4_ppsh41_base",        // PPSH-41 (Vanguard SMG; altWeapon clean)
        "t9_nail_gun",           // Nail Gun (CW projectile AR; altWeapon empty, twin-less by type)
        "s1_pdw",                // PDW-57 (AW; base single-wield, PaPs to akimbo rdw+ldw; altWeapon empty)
        "s2_m1911",              // M1911 (WWII pistol; PaPs to akimbo EXPLOSIVE - balance split in _acc_damage)
        "t5_ak74u"               // AK-74u (BO1 SMG; PaP altWeapon BLANKED install-side, skye_t5_ak74u.gdt L10416)
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
             IS_TRUE( level.zombie_weapons[ w ].is_in_box ) )
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

    // If the player owns EVERY available box gun there is nothing new to give - fall
    // back to the full box list (stock then hands a duplicate w/ max ammo, an
    // unavoidable edge case). Otherwise restrict the draw to guns they lack.
    if ( not_held.size == 0 )
    {
        return box_only;
    }
    return not_held;
}

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

    // NOTE: apply_power_switch_side and remove_all_wallbuys already ran
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

    // Wall buys are fully removed on this map (remove_all_wallbuys); no
    // per-run wallbuy pool to log. Perk rotation is logged per-round by
    // roll_perk_rotation; not part of map-load state.
}
