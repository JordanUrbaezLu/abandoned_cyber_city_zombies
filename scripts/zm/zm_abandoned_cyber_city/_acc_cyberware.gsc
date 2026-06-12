// =============================================================================
// _acc_cyberware.gsc - the Cyberware skill tree
//
// Design reference: docs/04_progression_and_skills.md (Cyberware Skill Tree).
//
// Model:
//  - Tree of 9 nodes (3 branches x 3 tiers).
//  - Player state: array of purchased node ids (`self.acc_cyberware_nodes`).
//  - Purchase validates cost (Data Shards), prerequisites, and mutual exclusion
//    within a tier on the same branch.
//  - Purchasing a node applies its effects by calling apply_*() functions.
//  - Effects are re-applied on respawn/revive (see on_player_spawned).
// =============================================================================

#using scripts\codescripts\struct;
#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#namespace acc_cyberware;

// ---------------------------------------------------------------------------
// Tree definition. Keep in sync with docs/04_progression_and_skills.md.
// Node ids are strings so we can log/debug cleanly; do NOT refactor to ints.
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "cyberware init" );

    level.acc_cyberware_tree = build_tree();

    // Register the "skill kiosk" trigger once geometry exists.
    // TODO(acc-geom): this runs a waittill on a Radiant-placed script_struct
    // named "acc_cyberware_kiosk". Until Radiant has it, this thread no-ops.
    level thread watch_kiosk_trigger();

    // Subroutine T1 passive shard regen ticker.
    level thread subroutine_passive_regen_loop();
}

function client_init()
{
    // LUI skill-tree screen lives here (Phase 4). Stub for now.
}

function on_player_connect( player )
{
    player.acc_cyberware_nodes = [];
    player.acc_cyberware_respecs_used = 0;
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
    player iprintln( "Unlocked: " + node.display_name );
    level notify( "acc_cyberware_purchased", player, node_id );
    return true;
}

// Refund the highest-tier node the player owns. Costs 3 Shards tax.
function try_respec_last_node( player )
{
    if ( !isdefined( player.acc_cyberware_nodes ) ) return false;
    if ( player.acc_cyberware_nodes.size == 0 ) return false;
    if ( player.acc_cyberware_respecs_used > 0 ) return false;
    if ( acc_data_shards::get_count( player ) < 3 ) return false;

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
    acc_data_shards::try_spend( player, 3 ); // tax

    // Remove node from array (and re-apply remaining).
    player.acc_cyberware_nodes = array::remove_index( player.acc_cyberware_nodes, highest_idx );
    player.acc_cyberware_respecs_used += 1;

    // Re-apply all remaining nodes from scratch (we don't track incremental state).
    player strip_all_node_effects();
    for ( i = 0; i < player.acc_cyberware_nodes.size; i++ )
    {
        player apply_node_effects( player.acc_cyberware_nodes[ i ] );
    }
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
// For Phase 3 we cycle through nodes via an F key prompt on a script_struct
// placed in Radiant. Real UI (Phase 4) is a LUI skill-tree screen.
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

function kiosk_loop()
{
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );
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
            player iprintln( "No cyberware available (not enough shards or no valid path)" );
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

// Strips all effects. Used before re-apply in respec.
// We track effect values in self.acc_cw_* fields so we can reset them cleanly.
function strip_all_node_effects()
{
    // TODO(acc-effects): add reset logic as apply_* functions are fleshed out.
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
    // +10% sprint speed.
    // TODO(acc-verify): exact API call to modify move speed in zombies.
    self setmovespeedscale( 1.10 );
}

// --- Tier 2 ---
function apply_oc2a() { self.acc_cw_crit_damage_mult = 1.30; self.acc_cw_crit_chance_bonus = 0.50; }
function apply_oc2b() { self.acc_cw_pap_elemental_slot = true; }
function apply_sr2a() { self.acc_cw_events_retry = true; }
function apply_sr2b() { self.acc_cw_bleed_multiplier = 2.0; self.acc_cw_selfrevive_shard_discount = 0.5; }
function apply_rx2a() { self.acc_cw_phase_step = true; }
function apply_rx2b() { self.acc_cw_ghost_protocol = true; }

// --- Tier 3 ---
function apply_oc3() { self.acc_cw_meltdown_aoe = true; }
function apply_sr3() { self.acc_cw_recursion_active = true; self.acc_cw_recursion_counter = 0; }
function apply_rx3() { self.acc_cw_overdrive_active = true; }

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
