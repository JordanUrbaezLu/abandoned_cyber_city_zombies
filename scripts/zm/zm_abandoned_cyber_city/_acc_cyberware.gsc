// =============================================================================
// _acc_cyberware.gsc - the Cyberware skill tree
//
// Design reference: docs/03_progression_and_skills.md (Cyberware Skill Tree).
//
// Model:
//  - Tree of 9 nodes (3 branches x 3 tiers).
//  - Player state: array of purchased node ids (`self.acc_cyberware_nodes`).
//  - Purchase validates cost (Data Shards), prerequisites, and mutual exclusion
//    within a tier on the same branch.
//  - Purchasing a node applies its effects by calling apply_*() functions.
//  - Effects are re-applied on respawn/revive (see on_player_spawned).
//
// Node effects implemented IN THIS FILE (self-contained ability logic):
//  - rx2a Phase Step     - slide triggers a short forward blink (6s cooldown).
//  - rx2b Ghost Protocol - stand still 2s -> zombies untarget you (stock
//                          ignoreme pipeline); broken the moment you move.
//  - oc3  Meltdown       - kills explode for AoE damage; never chains.
//  - sr2b Caching        - 2x bleed-out time via the stock laststand
//                          multiplier field (self-revive discount flag is set
//                          here but consumed by the future self-revive module).
//
// Node effects consumed ELSEWHERE (this file only sets the flags):
//  - oc1  acc_cw_damage_mult, oc2a acc_cw_crit_*  -> _acc_damage.
//  - oc2b acc_cw_pap_elemental_slot               -> _acc_overclocks.
//  - sr2a acc_cw_events_retry                     -> _acc_events_hack/_overload.
//  - sr3  acc_cw_recursion_*                      -> _acc_elites.
//  - rx3  acc_cw_overdrive_active                 -> _acc_damage (damage side).
//  - rx1  acc_cw_rx1_speed                        -> acc_utility::recompute_move_speed.
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\ai\zombie_utility;

#insert scripts\shared\shared.gsh;

#using scripts\zm\_zm_spawner;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

// Cyberware kiosk world model (the "implant bench"; stock t7 prop, also xmodel-listed
// in the .zone). Same white metal workbench as the Plaza Implant Bench.
#precache( "model", "p7_cai_work_table_metal_03_white" );

// ---------------------------------------------------------------------------
// Tuning - see docs/03_progression_and_skills.md.
// ---------------------------------------------------------------------------

// rx2a Phase Step: blink distance (units), wall back-off, minimum useful
// travel (below this we keep the cooldown), cooldown (docs/03: 6s).
#define ACC_CW_PHASE_DIST 160
#define ACC_CW_PHASE_BACKOFF 18
#define ACC_CW_PHASE_MIN_TRAVEL 32
#define ACC_CW_PHASE_COOLDOWN_MS 6000

// rx2b Ghost Protocol: ticks of stillness before cloak (20 * 0.1s = docs/03's
// 2 seconds; integer ticks avoid float-accumulation drift), movement epsilon.
#define ACC_CW_GHOST_TICK_SEC 0.1
#define ACC_CW_GHOST_STILL_TICKS 20
#define ACC_CW_GHOST_MOVE_EPSILON_SQ 4

// oc3 Meltdown: AoE radius squared (150^2), damage as a fraction of each
// victim's max health (round-scaling proxy - see apply note), damage floor.
#define ACC_CW_MELTDOWN_RADIUS_SQ 22500
#define ACC_CW_MELTDOWN_DMG_FRAC 0.35
#define ACC_CW_MELTDOWN_DMG_MIN 100

// sr2b Caching: bleed-out time multiplier (docs/03: 2x; stock default dvar
// player_lastStandBleedoutTime is 30s -> 60s with this).
#define ACC_CW_BLEEDOUT_MULT 2.0

// Respec tax (docs/03 Respec Rules: 3 Shards, once per run, never Tier 3).
#define ACC_CW_RESPEC_TAX 3

#namespace acc_cyberware;

// ---------------------------------------------------------------------------
// Tree definition. Keep in sync with docs/03_progression_and_skills.md.
// Node ids are strings so we can log/debug cleanly; do NOT refactor to ints.
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "cyberware init" );

    level.acc_cyberware_tree = build_tree();

    // CYBERWARE TREE REMOVED from play (user 2026-06-19): the weapon Overclock terminal ("Cyberware
    // Weapon Overclock") is now the sole upgrade. The kiosk is no longer spawned (underground spawn
    // removed in _acc_glitch_altar; the Lab trigger is gated off here). Module stays loaded (its
    // damage-flag readers are harmless no-ops with no nodes bought). Re-enable with `acc_cyberware_on 1`.
    if ( getdvarint( "acc_cyberware_on", 0 ) )
        level thread watch_kiosk_trigger();

    // Subroutine T1 passive shard regen ticker.
    level thread subroutine_passive_regen_loop();

    // oc3 Meltdown consumer.
    // VERIFIED(acc): zm_spawner::register_zombie_death_event_callback
    // (_zm_spawner.gsc:2463) is the real per-zombie death hook; the callback
    // runs ON the dying zombie with the attacker as the only arg
    // (dispatch 'self [[ cb ]]( attacker )', _zm_spawner.gsc:2344/2458;
    // stock usage example: _zm_perk_widows_wine.gsc:134).
    zm_spawner::register_zombie_death_event_callback( &on_zombie_death_meltdown );
}

function client_init()
{
    // LUI skill-tree screen lives here (Phase 4). Stub for now.
}

function on_player_connect( player )
{
    player.acc_cyberware_nodes = [];
    player.acc_cyberware_respecs_used = 0;
    player.acc_cw_phase_next_ms = 0;
}

function on_player_spawned( player )
{
    // Re-apply all purchased nodes' effects on every respawn. Some effects
    // (e.g. +sprint speed) are reset by the respawn logic.
    if ( !isdefined( player.acc_cyberware_nodes ) ) return;

    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        node_id = player.acc_cyberware_nodes[ i ];
        player apply_node_effects( node_id );
    }
}

// ---------------------------------------------------------------------------
// Tree structure
// ---------------------------------------------------------------------------

function build_tree()
{
    tree = spawnstruct();
    tree.nodes = [];

    // Shape of a node:
    //   id (string), branch ("overclock"|"subroutine"|"reflex"),
    //   tier (1|2|3), cost (int, Data Shards),
    //   requires (array of node_id prerequisites),
    //   display_name (string), on_apply (callback function ptr).

    // --- Tier 1 ---
    tree.nodes[ tree.nodes.size ] = node(
        "oc1", "overclock", 1, 2, [],
        "Overclock - Amplifier", &apply_oc1
    );
    tree.nodes[ tree.nodes.size ] = node(
        "sr1", "subroutine", 1, 2, [],
        "Subroutine - Data Regen", &apply_sr1
    );
    tree.nodes[ tree.nodes.size ] = node(
        "rx1", "reflex", 1, 2, [],
        "Reflex - Momentum", &apply_rx1
    );

    // --- Tier 2 ---
    tree.nodes[ tree.nodes.size ] = node(
        "oc2a", "overclock", 2, 3, array( "oc1" ),
        "Overload - Crit Specialist", &apply_oc2a
    );
    tree.nodes[ tree.nodes.size ] = node(
        "oc2b", "overclock", 2, 3, array( "oc1" ),
        "Fission - Elemental PaP", &apply_oc2b
    );
    tree.nodes[ tree.nodes.size ] = node(
        "sr2a", "subroutine", 2, 3, array( "sr1" ),
        "Parallel Processing - 2 Event Attempts", &apply_sr2a
    );
    tree.nodes[ tree.nodes.size ] = node(
        "sr2b", "subroutine", 2, 3, array( "sr1" ),
        "Caching - Extended Bleed", &apply_sr2b
    );
    tree.nodes[ tree.nodes.size ] = node(
        "rx2a", "reflex", 2, 3, array( "rx1" ),
        "Phase Step - Teleport Slide", &apply_rx2a
    );
    tree.nodes[ tree.nodes.size ] = node(
        "rx2b", "reflex", 2, 3, array( "rx1" ),
        "Ghost Protocol - Standing Cloak", &apply_rx2b
    );

    // --- Tier 3 capstones ---
    tree.nodes[ tree.nodes.size ] = node(
        "oc3", "overclock", 3, 5, array( "oc2a", "oc2b" ),
        "Meltdown - AoE Kills", &apply_oc3
    );
    tree.nodes[ tree.nodes.size ] = node(
        "sr3", "subroutine", 3, 5, array( "sr2a", "sr2b" ),
        "Recursion - Elite Drop Chain", &apply_sr3
    );
    tree.nodes[ tree.nodes.size ] = node(
        "rx3", "reflex", 3, 5, array( "rx2a", "rx2b" ),
        "Overdrive - Sprint Damage Ramp", &apply_rx3
    );

    return tree;
}

function node( id, branch, tier, cost, requires, display_name, on_apply )
{
    n = spawnstruct();
    n.id = id;
    n.branch = branch;
    n.tier = tier;
    n.cost = cost;
    n.requires = requires;
    n.display_name = display_name;
    n.on_apply = on_apply;
    return n;
}

function find_node( node_id )
{
    for ( i = 0; i < level.acc_cyberware_tree.nodes.size; i++ )
    {
        if ( level.acc_cyberware_tree.nodes[ i ].id == node_id )
        {
            return level.acc_cyberware_tree.nodes[ i ];
        }
    }
    return undefined;
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

// Returns true iff the player is allowed to purchase this node right now.
function can_purchase( player, node_id )
{
    node = find_node( node_id );
    if ( !isdefined( node ) ) return false;

    // Already purchased?
    if ( player has_node( node_id ) ) return false;

    // Affordability.
    if ( acc_data_shards::get_count( player ) < node.cost ) return false;

    // Prerequisite satisfied?
    if ( node.requires.size > 0 )
    {
        any_met = false;
        for ( i = 0; i < node.requires.size; i++ )
        {
            if ( player has_node( node.requires[ i ] ) )
            {
                any_met = true;
                break;
            }
        }
        if ( !any_met ) return false;
    }

    // Mutual exclusion: can't buy two nodes of the same tier on the same branch.
    if ( player has_branch_tier( node.branch, node.tier ) ) return false;

    return true;
}

function try_purchase( player, node_id )
{
    if ( !can_purchase( player, node_id ) ) return false;

    node = find_node( node_id );
    if ( !acc_data_shards::try_spend( player, node.cost ) ) return false;

    player.acc_cyberware_nodes[ player.acc_cyberware_nodes.size ] = node_id;
    player apply_node_effects( node_id );
    player acc_utility::hud_msg( "Unlocked: " + node.display_name );
    level notify( "acc_cyberware_purchased", player, node_id );
    return true;
}

// Refund the highest-tier node the player owns. Costs ACC_CW_RESPEC_TAX
// Shards tax, once per run, never removes Tier 3 (docs/03 Respec Rules).
function try_respec_last_node( player )
{
    if ( !isdefined( player.acc_cyberware_nodes ) ) return false;
    if ( player.acc_cyberware_nodes.size == 0 ) return false;
    if ( player.acc_cyberware_respecs_used > 0 ) return false;
    if ( acc_data_shards::get_count( player ) < ACC_CW_RESPEC_TAX ) return false;

    // Find highest-tier node.
    highest_idx = 0;
    highest_tier = 0;
    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        n = find_node( player.acc_cyberware_nodes[ i ] );
        if ( !isdefined( n ) ) continue;
        if ( n.tier == 3 ) continue; // can't respec tier 3 per design.
        if ( n.tier > highest_tier )
        {
            highest_tier = n.tier;
            highest_idx = i;
        }
    }
    if ( highest_tier == 0 ) return false;

    refund_node = find_node( player.acc_cyberware_nodes[ highest_idx ] );
    acc_data_shards::grant_player( player, refund_node.cost, "respec_refund" );
    acc_data_shards::try_spend( player, ACC_CW_RESPEC_TAX ); // tax (precheck above guarantees this succeeds)

    // Remove node from array (and re-apply remaining).
    player.acc_cyberware_nodes = array::remove_index( player.acc_cyberware_nodes, highest_idx );
    player.acc_cyberware_respecs_used += 1;

    // Re-apply all remaining nodes from scratch (we don't track incremental state).
    player strip_all_node_effects();
    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        player apply_node_effects( player.acc_cyberware_nodes[ i ] );
    }

    player acc_utility::hud_msg( "Respec: " + refund_node.display_name + " refunded (" + ACC_CW_RESPEC_TAX + " Shard tax)" );
    return true;
}

// Removes the player's lowest-cost node WITHOUT refund or respec accounting.
// Consumer: _acc_modifiers roguelike_lite (every down strips a node).
function remove_lowest_cost_node( player )
{
    if ( !isdefined( player.acc_cyberware_nodes ) ) return false;
    if ( player.acc_cyberware_nodes.size == 0 ) return false;

    lowest_idx = -1;
    lowest_cost = 9999;
    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        n = find_node( player.acc_cyberware_nodes[ i ] );
        if ( !isdefined( n ) ) continue;
        if ( n.cost < lowest_cost )
        {
            lowest_cost = n.cost;
            lowest_idx = i;
        }
    }
    if ( lowest_idx < 0 ) return false;

    removed = find_node( player.acc_cyberware_nodes[ lowest_idx ] );
    player.acc_cyberware_nodes = array::remove_index( player.acc_cyberware_nodes, lowest_idx );

    player strip_all_node_effects();
    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        player apply_node_effects( player.acc_cyberware_nodes[ i ] );
    }

    player acc_utility::hud_msg( "Cyberware lost: " + removed.display_name );
    return true;
}

function has_node( node_id )
{
    if ( !isdefined( self.acc_cyberware_nodes ) ) return false;
    for ( i = 0; i < self.acc_cyberware_nodes.size; i++ )
    {
        if ( self.acc_cyberware_nodes[ i ] == node_id ) return true;
    }
    return false;
}

function has_branch_tier( branch, tier )
{
    if ( !isdefined( self.acc_cyberware_nodes ) ) return false;
    for ( i = 0; i < self.acc_cyberware_nodes.size; i++ )
    {
        n = find_node( self.acc_cyberware_nodes[ i ] );
        if ( !isdefined( n ) ) continue;
        if ( n.branch == branch && n.tier == tier ) return true;
    }
    return false;
}

// ---------------------------------------------------------------------------
// Kiosk interaction (placeholder)
//
// For Phase 3 we cycle through nodes via an F key prompt on a trigger_use
// placed in Radiant. Real UI (Phase 4) is a LUI skill-tree screen.
// Stand + use  = buy the first purchasable node.
// Crouch + use = respec (docs/03 Respec Rules).
// ---------------------------------------------------------------------------

function watch_kiosk_trigger()
{
    level endon( "end_game" );

    // TODO(acc-geom): Radiant must place a trigger_use with targetname
    // "acc_cyberware_kiosk". Until then, this returns silently.
    triggers = getentarray( "acc_cyberware_kiosk", "targetname" );
    if ( triggers.size == 0 )
    {
        acc_utility::log( "cyberware: no kiosk placed yet" );
        return;
    }

    for ( i = 0; i < triggers.size; i++ )
    {
        triggers[ i ] thread kiosk_loop();
    }
}

// Spawn a Cyberware kiosk (implant-bench model + a hold-USE trigger running the existing
// kiosk_loop) at origin, facing yaw. Pure GSC - the trench "Foundry" home for the tree
// (the watch_kiosk_trigger Radiant-trigger path was never placed). Called by
// _acc_glitch_altar with the underground origins.
function spawn_kiosk_at( origin, yaw )
{
    m = spawn( "script_model", origin );
    m setmodel( "p7_cai_work_table_metal_03_white" );
    if ( isdefined( yaw ) ) m.angles = ( 0, yaw, 0 );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 64, 80 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5CYBERWARE^7 - buy node (crouch = respec)" );
    t thread kiosk_loop();
    acc_utility::log( "cyberware: kiosk spawned at " + origin );
}

function kiosk_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );

        // Crouched use = respec path.
        // VERIFIED(acc): GetStance() on a player returns "stand"/"crouch"/
        // "prone" (stock usage: _zm_perks.gsc:1752, _zm_ai_faller.gsc:587).
        if ( player GetStance() == "crouch" )
        {
            if ( !try_respec_last_node( player ) )
            {
                player acc_utility::hud_msg( "Respec unavailable (once per run, 3 Shards, never Tier 3)" );
            }
            wait( 0.5 );
            continue;
        }

        // Cheapest possible UX for Phase 3: cycle through purchasable nodes
        // and buy the first affordable one on button press. Real UI comes later.
        bought_something = false;
        for ( i = 0; i < level.acc_cyberware_tree.nodes.size; i++ )
        {
            node = level.acc_cyberware_tree.nodes[ i ];
            if ( can_purchase( player, node.id ) )
            {
                try_purchase( player, node.id );
                bought_something = true;
                break;
            }
        }
        if ( !bought_something )
        {
            player acc_utility::hud_msg( "No cyberware available (not enough shards or no valid path)" );
        }
        wait( 0.5 );
    }
}

// ---------------------------------------------------------------------------
// Effect application
// ---------------------------------------------------------------------------

function apply_node_effects( node_id )
{
    node = find_node( node_id );
    if ( !isdefined( node ) ) return;
    self [[ node.on_apply ]]();
}

// Strips all effects. Used before re-apply in respec / roguelike node loss.
// Watcher threads (Phase Step / Ghost Protocol) are NOT killed - they gate on
// the acc_cw_* flags every tick, so clearing the flag disables the ability and
// a subsequent re-apply re-enables it without spawning duplicate threads.
function strip_all_node_effects()
{
    // Overclock branch.
    self.acc_cw_damage_mult = undefined;
    self.acc_cw_crit_damage_mult = undefined;
    self.acc_cw_crit_chance_bonus = undefined;
    self.acc_cw_pap_elemental_slot = undefined;
    self.acc_cw_meltdown_aoe = undefined;

    // Subroutine branch. NOTE: acc_cw_recursion_counter is deliberately NOT
    // cleared - sr3 can never be respecced, and apply_sr3 only initializes
    // the counter when undefined, so elite-kill progress survives re-apply.
    self.acc_cw_shard_regen_active = undefined;
    self.acc_cw_events_retry = undefined;
    self.acc_cw_bleed_multiplier = undefined;
    self.acc_cw_selfrevive_shard_discount = undefined;
    self.acc_cw_recursion_active = undefined;

    // Reflex branch.
    self.acc_cw_rx1_speed = undefined;
    self.acc_cw_phase_step = undefined;
    self.acc_cw_ghost_protocol = undefined;
    self.acc_cw_overdrive_active = undefined;

    // Tear down live derived state.
    self ghost_set_cloaked( false );
    acc_utility::recompute_move_speed( self );
    self recompute_bleedout_multiplier();
}

// --- Tier 1 ---
function apply_oc1()
{
    // +15% weapon damage. Applied via damage callback registered below.
    self.acc_cw_damage_mult = 1.15;
}

function apply_sr1()
{
    // Passive shard regen handled by level thread; just set the flag.
    self.acc_cw_shard_regen_active = true;
}

function apply_rx1()
{
    // +10% sprint speed. VERIFIED(acc): SetMoveSpeedScale is ABSOLUTE -
    // route through the single recompute owner so Boots/Flash also stack.
    self.acc_cw_rx1_speed = true;
    acc_utility::recompute_move_speed( self );
}

// --- Tier 2 ---
function apply_oc2a() { self.acc_cw_crit_damage_mult = 1.30; self.acc_cw_crit_chance_bonus = 0.50; }
function apply_oc2b() { self.acc_cw_pap_elemental_slot = true; }
function apply_sr2a() { self.acc_cw_events_retry = true; }

function apply_sr2b()
{
    // Caching (docs/03): down-but-not-out lasts 2x longer before bleed-out,
    // self-revive Shard cost halved (discount flag consumed by the future
    // self-revive module - see docs/15 self-revive-purchase).
    self.acc_cw_bleed_multiplier = ACC_CW_BLEEDOUT_MULT;
    self.acc_cw_selfrevive_shard_discount = 0.5;
    self recompute_bleedout_multiplier();
}

function apply_rx2a()
{
    // Phase Step (docs/03): slide becomes a short teleport through zombies
    // (no damage dealt, 6s cooldown). Implemented as a forward blink at slide
    // START - see phase_step_watcher for the verified mechanism and the
    // documented deltas vs the doc wording.
    self.acc_cw_phase_step = true;
    self thread phase_step_watcher();
}

function apply_rx2b()
{
    // Ghost Protocol (docs/03): standing still for 2s makes you untargeted
    // by melee zombies until you move. See ghost_protocol_watcher.
    self.acc_cw_ghost_protocol = true;
    self thread ghost_protocol_watcher();
}

// --- Tier 3 ---
function apply_oc3() { self.acc_cw_meltdown_aoe = true; }

function apply_sr3()
{
    self.acc_cw_recursion_active = true;
    // Initialize-once: on_player_spawned re-applies effects on EVERY respawn;
    // unconditionally zeroing here would wipe elite-kill progress mid-run.
    if ( !isdefined( self.acc_cw_recursion_counter ) )
    {
        self.acc_cw_recursion_counter = 0;
    }
}

function apply_rx3() { self.acc_cw_overdrive_active = true; }

// ---------------------------------------------------------------------------
// rx2a Phase Step
//
// Verified input: slide detection via the IsSliding() player method
// (VERIFIED(acc): stock usage 'self IsSliding()' bot_traversals.gsc:102 and
// 'data.attacker IsSliding()' challenges_shared.gsc:1676). We poll for the
// not-sliding -> sliding edge and blink the player forward.
//
// Deltas vs docs/03 wording (degraded-but-real, no input hooks exist for
// "replace the slide"):
//  - The slide still plays; the blink fires instantly at slide start, so the
//    net effect is slide + ~10ft displacement through whatever was in front.
//  - "Through zombies / no collision": the destination trace is a bullettrace
//    with hit-characters = false, so zombies never block it; world geometry
//    (walls, closed doors) DOES block it, which also prevents escaping the
//    playable space. Bullet-permeable window boards can be blinked through -
//    kept short (160 units) so this stays inside adjacent playable space.
//  - No damage is dealt (matches docs/03).
// ---------------------------------------------------------------------------

function phase_step_watcher()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // Thread-once guard: apply_rx2a re-runs on every respawn / post-respec
    // re-apply; the flag check below handles enable/disable.
    if ( IS_TRUE( self.acc_cw_phase_thread_started ) ) return;
    self.acc_cw_phase_thread_started = true;

    if ( !isdefined( self.acc_cw_phase_next_ms ) )
    {
        self.acc_cw_phase_next_ms = 0;
    }

    b_was_sliding = false;

    for ( ;; )
    {
        wait( 0.05 );

        b_sliding = self IsSliding();

        if ( b_sliding && !b_was_sliding )
        {
            // Slide START edge.
            // VERIFIED(acc): zm_utility::is_player_valid (_zm_utility.gsc:1600)
            // checks defined/alive/spawned/not-laststand/not-spectator.
            if ( IS_TRUE( self.acc_cw_phase_step )
                && gettime() >= self.acc_cw_phase_next_ms
                && zm_utility::is_player_valid( self ) )
            {
                self do_phase_step();
            }
        }

        b_was_sliding = b_sliding;
    }
}

function do_phase_step()
{
    // Yaw-only forward vector so the blink stays horizontal even when the
    // player slides while aiming up/down.
    // VERIFIED(acc): 'AnglesToForward( player GetPlayerAngles() )' is the
    // stock player-facing pattern (_zm_spawner.gsc:2917, _zm_utility.gsc:5018).
    v_angles = self GetPlayerAngles();
    v_fwd = AnglesToForward( ( 0, v_angles[ 1 ], 0 ) );

    // Waist-height trace that ignores characters - zombies never block the
    // blink, world geometry does.
    // VERIFIED(acc): bullettrace( start, end, hit_characters, ignore_ent )
    // with result["position"] - stock usage _zm.gsc:6409-6410 (passes false
    // for hit_characters) and _zm_utility.gsc:4582.
    v_start = self.origin + ( 0, 0, 32 );
    trace = bullettrace( v_start, v_start + v_fwd * ACC_CW_PHASE_DIST, false, self );
    v_dest = trace[ "position" ] - v_fwd * ACC_CW_PHASE_BACKOFF;

    // Snap the destination to the floor so we never leave the player hovering.
    // VERIFIED(acc): GroundTrace( start, end, false, ignore_ent )["position"]
    // - stock usage _zm_spawner.gsc:1609, _zm_ai_dogs.gsc:702.
    ground = GroundTrace( v_dest, v_dest + ( 0, 0, -128 ), false, self );
    v_final = ground[ "position" ] + ( 0, 0, 1 );

    if ( Distance( v_final, self.origin ) < ACC_CW_PHASE_MIN_TRAVEL )
    {
        // Wall in our face - not a useful blink, don't burn the cooldown.
        return;
    }

    // VERIFIED(acc): SetOrigin teleports a player entity (stock usage on
    // players: _hostmigration.gsc:647 'self SetOrigin( spawnPoint.origin )').
    self SetOrigin( v_final );
    self.acc_cw_phase_next_ms = gettime() + ACC_CW_PHASE_COOLDOWN_MS;
}

// ---------------------------------------------------------------------------
// rx2b Ghost Protocol
//
// Verified mechanism: the stock ignoreme pipeline.
// VERIFIED(acc): zm_utility::increment_ignoreme / decrement_ignoreme
// (_zm_utility.gsc:3833/3840) maintain the refcounted player.ignoreme flag;
// zombie target selection drops ignoreme players both in melee pick
// (_zm_behavior.gsc:1049 '!IS_TRUE( players[i].ignoreme )') and in
// is_player_valid's checkIgnoreMeFlag branch (_zm_utility.gsc:1651).
// Stock precedents for exactly this inc/dec pattern on players:
// _zm.gsc player_spawn_protection (:1924/:1931) and _zm_laststand.gsc:1510-1512.
//
// Delta vs docs/03 ("special enemies unaffected"): ignoreme is global to the
// stock targeting pipeline, and our elites/bosses are promoted stock zombies
// (_acc_elites promote_*), so they ALSO untarget a cloaked player. Restoring
// elite aggro needs a custom favoriteenemy/targeting pass on the elite side -
// deferred to balance work (documented in docs/03 code notes).
// ---------------------------------------------------------------------------

function ghost_protocol_watcher()
{
    self endon( "disconnect" );
    level endon( "end_game" );

    // Thread-once guard (same pattern as phase_step_watcher).
    if ( IS_TRUE( self.acc_cw_ghost_thread_started ) ) return;
    self.acc_cw_ghost_thread_started = true;

    v_anchor = self.origin;
    n_still_ticks = 0;

    for ( ;; )
    {
        wait( ACC_CW_GHOST_TICK_SEC );

        // Node not owned (stripped) or player not valid (downed/spectating):
        // make sure we're decloaked and reset the stillness clock.
        if ( !IS_TRUE( self.acc_cw_ghost_protocol ) || !zm_utility::is_player_valid( self ) )
        {
            self ghost_set_cloaked( false );
            v_anchor = self.origin;
            n_still_ticks = 0;
            continue;
        }

        // Movement check is positional: looking around doesn't break the
        // cloak, translating does (matches docs/03 "until you move").
        if ( DistanceSquared( self.origin, v_anchor ) > ACC_CW_GHOST_MOVE_EPSILON_SQ )
        {
            self ghost_set_cloaked( false );
            v_anchor = self.origin;
            n_still_ticks = 0;
            continue;
        }

        n_still_ticks++;
        if ( n_still_ticks >= ACC_CW_GHOST_STILL_TICKS && !IS_TRUE( self.acc_cw_ghost_cloaked ) )
        {
            self ghost_set_cloaked( true );
        }
    }
}

// self = player. Idempotent: only ever decrements what it incremented, so the
// stock refcount (laststand / spawn protection also inc/dec it) stays balanced.
function ghost_set_cloaked( b_cloak )
{
    if ( b_cloak == IS_TRUE( self.acc_cw_ghost_cloaked ) )
    {
        return;
    }

    if ( b_cloak )
    {
        self zm_utility::increment_ignoreme();
        self.acc_cw_ghost_cloaked = true;
        self acc_utility::hud_msg( "Ghost Protocol: cloaked" );
    }
    else
    {
        self zm_utility::decrement_ignoreme();
        self.acc_cw_ghost_cloaked = false;
    }
}

// ---------------------------------------------------------------------------
// oc3 Meltdown
//
// Kills by a player with the capstone explode for AoE damage at the corpse.
// "Does not chain" (docs/03): zombies killed BY the AoE are tagged
// acc_meltdown_killed before the damage lands; the tag short-circuits this
// callback so their deaths never re-explode.
//
// Delta vs docs/03 ("scaling with weapon damage"): GSC cannot read GDT weapon
// damage tables at runtime, so the AoE proxy-scales with each victim's
// maxhealth (which itself scales per round) - 35% of maxhealth, floor 100.
// The oc1/oc2a damage chain still gates how FAST you trigger Meltdowns.
// ---------------------------------------------------------------------------

// Registered via zm_spawner::register_zombie_death_event_callback in init().
// self = the dying zombie; attacker = killer (dispatch _zm_spawner.gsc:2344).
function on_zombie_death_meltdown( attacker )
{
    if ( !isdefined( self ) ) return;

    // No chaining: AoE-caused deaths never re-explode.
    if ( IS_TRUE( self.acc_meltdown_killed ) ) return;

    // Skip nuke wipes - everything is dying anyway, the AoE is pure waste.
    // VERIFIED(acc): zombie.nuked is the stock nuke-death marker
    // (_zm_spawner.gsc:2339 checks '!isDefined(zombie.nuked)').
    if ( isdefined( self.nuked ) ) return;

    if ( !isdefined( attacker ) || !isplayer( attacker ) ) return;
    if ( !IS_TRUE( attacker.acc_cw_meltdown_aoe ) ) return;

    // Thread off level: the corpse entity can be deleted mid-iteration, so we
    // capture the origin now and never touch `self` again.
    level thread meltdown_explode( self.origin, attacker, self );
}

function meltdown_explode( v_origin, e_attacker, e_source )
{
    level endon( "end_game" );

    if ( !isdefined( e_attacker ) ) return;

    // VERIFIED(acc): zombie_utility::get_round_enemy_array() returns the live
    // zombie AI array (scripts/shared/ai/zombie_utility.gsc:2023; stock usage
    // _zm_lightning_chain.gsc:208).
    a_zombies = zombie_utility::get_round_enemy_array();

    for ( i = 0; i < a_zombies.size; i++ )
    {
        z = a_zombies[ i ];
        if ( !isdefined( z ) ) continue;
        if ( isdefined( e_source ) && z == e_source ) continue;
        if ( !isalive( z ) ) continue;
        if ( IS_TRUE( z.acc_meltdown_killed ) ) continue;
        if ( DistanceSquared( z.origin, v_origin ) > ACC_CW_MELTDOWN_RADIUS_SQ ) continue;

        n_maxhealth = z.health;
        if ( isdefined( z.maxhealth ) ) n_maxhealth = z.maxhealth;

        n_dmg = int( n_maxhealth * ACC_CW_MELTDOWN_DMG_FRAC );
        if ( n_dmg < ACC_CW_MELTDOWN_DMG_MIN ) n_dmg = ACC_CW_MELTDOWN_DMG_MIN;

        // Tag-before-damage so a lethal hit's death event sees the no-chain
        // marker; cleared right after if the zombie survived.
        z.acc_meltdown_killed = true;

        // Damage is dealt WITH the caster as attacker so points and kill
        // attribution flow to the player (docs/05 meltdown-kill-attribution).
        // VERIFIED(acc): 'zombie DoDamage( dmg, origin, attacker, attacker,
        // "none", mod )' is the stock script-AoE shape
        // (_zm_aat_thunder_wall.gsc:122); "MOD_EXPLOSIVE" is a valid mod
        // string (_destructible.gsc:260).
        z DoDamage( n_dmg, v_origin, e_attacker, e_attacker, "none", "MOD_EXPLOSIVE" );

        if ( isdefined( z ) && isalive( z ) )
        {
            z.acc_meltdown_killed = undefined;
        }
    }
}

// ---------------------------------------------------------------------------
// sr2b Caching - bleed-out extension
//
// SINGLE WRITER for player.n_bleedout_time_multiplier. Other modules wanting
// to scale bleed-out (e.g. _acc_modifiers' bleed_out modifier) must set their
// level/player factor and call this, NOT write the stock field directly.
//
// VERIFIED(acc): _zm_laststand.gsc:256-260 computes the downed timer as
// GetDvarfloat("player_lastStandBleedoutTime") * self.n_bleedout_time_multiplier
// (when defined), and :545-546 only applies the anti-cheese snap-back clamp
// when the multiplier is NOT defined - so a defined multiplier is fully
// honored. Stock default is 30s -> 60s with our 2.0 (docs/05 bleed-caching-60s).
// Solo quick-revive getup (level.lastStandGetupAllowed, :250) bypasses the
// bleed-out timer entirely and is intentionally unaffected.
// ---------------------------------------------------------------------------

// self = player.
function recompute_bleedout_multiplier()
{
    n_mult = 1.0;

    // Cyberware Caching (docs/03).
    if ( isdefined( self.acc_cw_bleed_multiplier ) )
    {
        n_mult = n_mult * self.acc_cw_bleed_multiplier;
    }

    // Run modifier "bleed_out" (docs/06) - _acc_modifiers sets the level var;
    // folding it here keeps the two systems stacking instead of clobbering.
    if ( isdefined( level.acc_mod_bleed_out_mult ) )
    {
        n_mult = n_mult * level.acc_mod_bleed_out_mult;
    }

    if ( n_mult == 1.0 )
    {
        self.n_bleedout_time_multiplier = undefined;
    }
    else
    {
        self.n_bleedout_time_multiplier = n_mult;
    }
}

// ---------------------------------------------------------------------------
// Passive subroutine regen loop
// ---------------------------------------------------------------------------

function subroutine_passive_regen_loop()
{
    level endon( "end_game" );

    for ( ;; )
    {
        wait( 120 ); // 1 shard per 2 minutes

        for ( i = 0; i < level.players.size; i++ )
        {
            player = level.players[ i ];
            if ( !isdefined( player ) ) continue;
            if ( !isdefined( player.acc_cw_shard_regen_active ) ) continue;
            if ( !player.acc_cw_shard_regen_active ) continue;

            acc_data_shards::grant_player( player, 1, "subroutine_regen" );
        }
    }
}
