// =============================================================================
// _acc_boss_items.gsc - boss-drop items (Machin[a]-style passive buffs)
//
// Design reference: docs/12_boss_items.md.
//
// Bosses drop random items from a 6-item pool on death. Players have 2 item
// slots. Duplicates auto-convert to 3 Data Shards.
//
// Status: STUB. Item table + drop/equip plumbing is in place; effect
// implementations are stubbed with TODOs for Phase 4 authoring.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;

#using scripts\codescripts\struct;

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_score;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;

#define ACC_ITEM_SLOTS_PER_PLAYER 2     // TWO active "implanted" items, one per bench pad (Slot 1 / Slot 2)
#define ACC_ITEM_PICKUP_RADIUS 64
#define ACC_ITEM_DROP_LIFETIME_SEC 60
#define ACC_ITEM_DUPLICATE_SHARD_CONVERT 3

#define ACC_BOSS_ITEM_DROP_CHANCE_MINI 1.00    // TEMP(testing 2026-06-18): 100% mini drops (Brutus + Glitch Stalker) so items are guaranteed for testing. DESIGN VALUE = 0.50 - restore it (or set dvar `acc_boss_item_chance_mini 0.5`) when tuning is done.
#define ACC_BOSS_ITEM_DROP_CHANCE_FULL 1.00    // 100% from Subroutine Core (full boss)

// Item buff tuning.
#define ACC_OVERCHARGE_REGEN     10    // Repair Kit: HP regenerated per second
#define ACC_BULWARK_HP           50    // (legacy Bulwark - now unused; kept for the dead fn)
#define ACC_SALVAGE_INTERVAL_SEC 20    // (legacy Salvage - now unused; kept for the dead fn)
#define ACC_DROP_MODEL_Z_DEF     24    // ground drops: lift model Z off the floor (live dvar acc_drop_model_z)
#define ACC_BENCH_SWAP_COST      2500  // Plaza Implant Bench: points to swap (first enable is free)

// Gas Tank nitro burst + its on-screen "NITRO" charge bar (drains on use, refills on regen).
#define ACC_GAS_BURST_SEC   5     // burst duration (bar drains 1->0)
#define ACC_GAS_REGEN_SEC   60    // regen lockout after the burst (bar refills 0->1); can't re-fire until full. Live dvar: acc_gas_regen_sec
#define ACC_GAS_BAR_W       120   // NITRO bar width  (matches the HP bar)
#define ACC_GAS_BAR_H       9     // NITRO bar height

// Pickup world models - one per item (see build_item_pool). Each is a distinct
// stock prop, packed via an xmodel,<name> line in the .zone; build errorlog
// confirmed clean (2026-06-17). Name reads on the ground; see docs/12.
#precache( "model", "p7_zm_zod_nitrous_tank" );            // 1 Gas Tank
#precache( "model", "p7_fxanim_zm_zod_octobomb_mod" );     // 2 Li'l Arnie
#precache( "model", "p7_zm_teddybear" );                   // 3 Teddy Bear
#precache( "model", "p7_zm_power_up_carpenter" );          // 4 Repair Kit (runtime-loaded icon)
#precache( "model", "wpn_t7_zmb_zod_rocket_shield_world" );// 5 Rocket Shield
#precache( "model", "wpn_t7_zmb_monkey_bomb_world" );      // 6 Monkey Bomb
#precache( "model", "zombie_pickup_perk_bottle" );         // 7 Phase Serum (cloak; runtime-loaded perk bottle, proven packable)
#precache( "model", "p7_cai_work_table_metal_03_white" );  // Plaza Implant Bench prop (Cyber City white metal workbench - high-tech bench; packed via .zone xmodel line)
#precache( "model", "zombietron_gold_brick" );             // 3 Loot Stash (gold brick = treasure/points)
#precache( "model", "p7_boots_safehouse_01" );             // 8 Boots (safehouse boots - proven packable)

// VERIFIED(acc): #namespace MUST come after all #using/#insert/#define -
// it terminates the directive preamble; a #using after it is a compile
// error ("unexpected TOKEN_USING, expecting $end"). First-compile finding,
// 2026-06-12.
#namespace acc_boss_items;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "boss_items init (pool=8, slots=" +
                       ACC_ITEM_SLOTS_PER_PLAYER + ")" );

    level.acc_item_pool = build_item_pool();
    level thread spawn_bench();
    level thread scale_octobombs_watch();   // shrink Li'l Arnie (octobomb) visuals (user 2026-06-18)
}

// Loot Stash / Payroll Ledger points bonus is owned by _acc_points.gsc (user 2026-06-23): a FLAT per-kill
// add to the KILLER - +10 normal / +20 headshot kill (ACC_LEDGER_KILL_BONUS / _HEADSHOT_BONUS), doubled by
// Double Points, plus a Nuke top-up to 500 (ACC_LEDGER_NUKE). _acc_points reads this item via
// acc_boss_items::player_has_ledger(); this module just owns the equip flag (apply/remove_payroll_ledger).

function on_player_connect( player )
{
    // acc_equipped_items is a FIXED 2-element array = the SINGLE source of truth for active
    // implants. Index 0 = bench Pad 1 (Slot 1), index 1 = Pad 2 (Slot 2). An empty slot holds
    // the sentinel "" (a defined value that is never a valid item id - avoids the undefined-in-
    // array footgun). The old scalar acc_active_item is GONE: every "is this implanted" test now
    // scans both slots via player_has_item(). "First two free" needs NO counter - a pad's slot is
    // FREE while "" and costs ACC_BENCH_SWAP_COST to replace once full (docs/12).
    player.acc_equipped_items = empty_slots();
    player.acc_item_state = [];
    player.acc_carried_item   = undefined;  // picked up, NOT yet enabled (no buff)
    player.acc_tactical_owner = undefined;  // id of the LAST-implanted grenade item (Li'l Arnie /
                                            // Monkey Bomb). Only the owner regrants its tactical on
                                            // spawn -> "last one wins" the single tactical slot (docs/12).
    player thread reapply_move_speed_on_spawn();
    player thread watch_box_tactical_grab();   // box-rolled Monkey Bomb / Li'l Arnie finalizer (user 2026-06-24)
}

// VERIFIED(acc): zm_usermap giveCustomCharacters() runs SetMoveSpeedScale(1)
// on EVERY player spawn (zm_usermap.gsc:336), silently wiping the Neural
// Boots bonus on respawn - reapply after each "spawned_player" notify
// (notify site _zm.gsc:3337).
function reapply_move_speed_on_spawn()
{
    self endon( "disconnect" );
    for ( ;; )
    {
        self waittill( "spawned_player" );
        wait( 0.05 ); // run after zm_usermap giveCustomCharacters() resets to 1
        setmovespeedscale_hook( self );
    }
}

// ---------------------------------------------------------------------------
// Item pool
// ---------------------------------------------------------------------------

function build_item_pool()
{
    pool = [];

    // num, id, display_name, model, slot, on_equip, on_unequip.
    // Items 1-3 REUSE already-wired effects (speed / charged-shot / +points);
    // items 4-6 are new self-contained buffs (regen / max-health / shard income).

    pool[ pool.size ] = item(
        1,
        "gas_tank",
        "Gas Tank",
        "p7_zm_zod_nitrous_tank",
        -6,                             // floor lift (was +24, user: 30 lower)
        "feet",
        &apply_gas_tank,                // nitro: double-tap sprint -> 5s +20% burst, 30s regen
        &remove_gas_tank
    );

    // Li'l Arnie (#2) + Monkey Bomb (#6) REMOVED from the boss-item pool (user 2026-06-24): they are now rare
    // MYSTERY-BOX rolls (1% / 0.5%) instead - see _acc_map_randomizer + watch_box_tactical_grab below. Their
    // give_octobomb / give_monkey_bomb (and apply_/remove_) helpers stay for the box path. Pool back to 6.

    pool[ pool.size ] = item(
        2,
        "teddy_bear",
        "Loot Stash",
        "zombietron_gold_brick",        // gold brick = treasure/points
        18,                             // floor lift (tune live)
        "implant",
        &apply_payroll_ledger,          // +10% Points on kills
        &remove_payroll_ledger
    );

    pool[ pool.size ] = item(
        3,
        "repair_kit",
        "Repair Kit",
        "p7_zm_power_up_carpenter",      // kept: no zm-packable medkit model exists (p7_medical_surgical_tools_syringe = campaign, "is missing" in zm). Carpenter (repair powerup) fits "Repair Kit" + is proven. (user 2026-06-18)
        19,
        "back",
        &apply_overcharge,              // +8 HP/sec passive regen
        &remove_overcharge
    );

    pool[ pool.size ] = item(
        4,
        "rocket_shield",
        "Rocket Shield",
        "wpn_t7_zmb_zod_rocket_shield_world",
        24,                             // floor lift (user: shield is good as-is)
        "chest",
        &apply_rocket_shield,           // +15% slide speed + slide distance + ~1.5x jump
        &remove_rocket_shield
    );

    pool[ pool.size ] = item(
        5,
        "phase_serum",
        "Phase Serum",
        "zombie_pickup_perk_bottle",    // perk bottle = "serum" read (runtime-loaded, proven packable)
        10,                             // floor lift (small vial; tune live)
        "implant",
        &apply_arnie_cloak,             // CLOAK: zombies + Glitch Stalker can't see/target you
        &remove_arnie_cloak
    );

    pool[ pool.size ] = item(
        6,
        "boots",
        "Boots",
        "p7_boots_safehouse_01",        // safehouse boots (proven packable)
        4,
        "feet",
        &apply_boots,                   // +8% move overall + IMMUNE to the Bus Station trench slow (walk normal in the pit)
        &remove_boots
    );

    return pool;
}

function item( num, id, display_name, model, model_z, slot, on_equip, on_unequip )
{
    i = spawnstruct();
    i.num = num;             // stable display ID (1..6), shown in HUD + prompts
    i.id = id;
    i.display_name = display_name;
    i.model = model;         // world pickup model (unique per item)
    i.model_z = model_z;     // per-item floor lift (units) - each model's pivot differs
    i.slot = slot;
    i.on_equip = on_equip;
    i.on_unequip = on_unequip;
    return i;
}

// Unified "<id> - <name>" label used by the pickup prompt, the pickup message,
// and the equipped-items HUD.
function display_for( item_struct )
{
    if ( !isdefined( item_struct ) ) return "?";
    return item_struct.num + " - " + item_struct.display_name;
}

function find_item( item_id )
{
    for ( i = 0; i < level.acc_item_pool.size; i++ )
    {
        if ( level.acc_item_pool[ i ].id == item_id )
        {
            return level.acc_item_pool[ i ];
        }
    }
    return undefined;
}

// ---------------------------------------------------------------------------
// Boss drop entry point. Called from _acc_boss.gsc on boss death.
//
// tier = "mini" | "full"
// killer = player who landed the killing blow (may be undefined)
// origin = boss corpse origin
// ---------------------------------------------------------------------------

function on_boss_death( tier, killer, origin )
{
    // Live-tunable per tier (default = the #define). Lets us drop chance back to
    // 0.50 for mini at runtime once testing is done, with no rebuild.
    chance = getdvarfloat( "acc_boss_item_chance_mini", ACC_BOSS_ITEM_DROP_CHANCE_MINI );
    if ( tier == "full" ) chance = getdvarfloat( "acc_boss_item_chance_full", ACC_BOSS_ITEM_DROP_CHANCE_FULL );

    acc_utility::drops_debug( "item DROP-ROLL tier=" + tier + " chance=" + chance );

    if ( acc_utility::acc_rand_float() > chance )
    {
        acc_utility::log( "boss_items: drop rolled but missed (" + tier + ")" );
        acc_utility::drops_debug( "item DROP-MISS tier=" + tier );
        return;
    }

    // Pick a random item from the pool.
    picked = level.acc_item_pool[ acc_utility::acc_rand_int( level.acc_item_pool.size ) ];

    // If killer already has this item, auto-convert to Shards right here.
    if ( isdefined( killer ) && isplayer( killer ) &&
         player_has_item( killer, picked.id ) )
    {
        acc_data_shards::grant_player( killer, ACC_ITEM_DUPLICATE_SHARD_CONVERT,
                                        "boss_item_duplicate" );
        acc_utility::log( "boss_items: " + picked.id +
                           " was duplicate for " + killer.name +
                           " -> +" + ACC_ITEM_DUPLICATE_SHARD_CONVERT + " shards" );
        acc_utility::drops_debug( "item DUPE-AT-DEATH id=" + picked.id + " killer=" + killer.name + " -> +" + ACC_ITEM_DUPLICATE_SHARD_CONVERT + " shards" );
        return;
    }

    // Otherwise spawn a pickup entity at boss corpse.
    spawn_pickup( picked, origin );
}

// Public: GUARANTEED random reward as a FREE-FOR-ALL loose world drop (used by the lockdown
// CHALLENGE on its 30th-kill clear). Unlike on_boss_death there is NO chance roll and NO
// killer-tie: it just drops one random item at `origin` that ANY player can grab (or leave for
// a teammate). The per-grabber duplicate handling already lives in watch_pickup (already-owns ->
// Data Shards at pickup), so no killer dedupe is needed here. docs/43 §10.
function grant_challenge_reward( origin )
{
    if ( !isdefined( level.acc_item_pool ) || level.acc_item_pool.size == 0 )
    {
        acc_utility::log( "boss_items: challenge reward - empty item pool, no drop" );
        return;
    }

    picked = level.acc_item_pool[ acc_utility::acc_rand_int( level.acc_item_pool.size ) ];
    spawn_pickup( picked, origin );
    acc_utility::log( "boss_items: challenge reward drop id=" + picked.id + " at " + origin );
}

// ---------------------------------------------------------------------------
// Pickup entity
// ---------------------------------------------------------------------------

function spawn_pickup( item_struct, origin )
{
    // Themed tech-prop pickup (stock nitrous tank, verified). Per-slot models
    // (boots / gauntlets / visor / battery / shroud) are a later art pass.
    // Lift the model off the floor (its pivot sits high, so a floor-origin model
    // sinks ~70% under). Tunable live via dvar acc_drop_model_z; the trigger stays
    // at +40 and its radius covers the lifted model for the look-at check.
    z_lift = ( isdefined( item_struct.model_z ) ? item_struct.model_z : getdvarint( "acc_drop_model_z", ACC_DROP_MODEL_Z_DEF ) );
    pickup = spawn( "script_model", origin + ( 0, 0, z_lift ) );
    mdl = ( isdefined( item_struct.model ) ? item_struct.model : "p7_zm_zod_nitrous_tank" );
    pickup setmodel( mdl );
    pickup.acc_item_id = item_struct.id;
    pickup.acc_created_at = gettime();

    // Hold-USE interact trigger (same recipe as _acc_data_shards spawn_pickup_at).
    // radius/height ARE the volume; origin raised for UseTriggerRequireLookAt.
    t_use = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, ACC_ITEM_PICKUP_RADIUS, 80 );
    t_use TriggerIgnoreTeam();
    t_use UseTriggerRequireLookAt();
    t_use SetCursorHint( "HINT_NOICON" );
    t_use SetHintString( "Hold ^3[{+activate}]^7 to grab " + display_for( item_struct ) );
    t_use.acc_model = pickup;
    t_use.acc_item_id = item_struct.id;
    t_use.acc_created_at = pickup.acc_created_at;
    t_use.acc_ground_origin = origin;   // unlifted floor origin, for swap re-drop (no Z creep)

    acc_utility::drops_debug( "item SPAWN id=" + item_struct.id + " at=" + origin + " lifetime=" + ACC_ITEM_DROP_LIFETIME_SEC + "s" );

    // Watchers run ON THE TRIGGER (self = trigger); model via self.acc_model.
    t_use thread watch_pickup();
    t_use thread watch_lifetime();
}

function watch_pickup()   // self = the hold-use trigger
{
    // NOTE: do NOT `self endon( "acc_item_claimed" )` here. We notify that on a
    // successful grab to kill the sibling watch_lifetime thread - but if this
    // thread also endon'd it, the notify would abort us BEFORE cleanup_pickup()
    // runs and the model/trigger would never despawn. This thread ends via its
    // explicit return instead.
    self endon( "death" );

    for ( ;; )
    {
        self waittill( "trigger", player );          // fires only on use-button press
        // Routed through data_shards (this module has no _zm_utility #using).
        if ( !acc_data_shards::is_player_alive( player ) ) continue;

        item_struct = find_item( self.acc_item_id );
        if ( !isdefined( item_struct ) ) { cleanup_pickup(); return; }

        acc_utility::drops_debug( "item PICKUP-TRY player=" + player.name + " id=" + self.acc_item_id );

        // Duplicate (already CARRIED or implanted in EITHER slot) -> convert to shards.
        // player_has_item scans both slots, so this catches a copy of a Slot-2 implant too.
        if ( player_has_item( player, item_struct.id ) ||
             ( isdefined( player.acc_carried_item ) && player.acc_carried_item == item_struct.id ) )
        {
            acc_data_shards::grant_player( player, ACC_ITEM_DUPLICATE_SHARD_CONVERT, "boss_item_duplicate" );
            acc_utility::drops_debug( "item DUPE id=" + item_struct.id + " player=" + player.name + " -> +" + ACC_ITEM_DUPLICATE_SHARD_CONVERT + " shards" );
            self notify( "acc_item_claimed" );
            cleanup_pickup();
            return;
        }

        // If already holding a LOOSE carried item (picked up, not yet enabled) and
        // it's a different one, DROP it back to the ground so it isn't lost - you can
        // grab it again. (An ENABLED/implanted item is not a loose carry, so it stays.)
        if ( isdefined( player.acc_carried_item )
             && player.acc_carried_item != item_struct.id
             && !player_has_item( player, player.acc_carried_item ) )
        {
            old = find_item( player.acc_carried_item );
            if ( isdefined( old ) )
            {
                spawn_pickup( old, self.acc_ground_origin );
                acc_utility::drops_debug( "item DROP-OLD-CARRY id=" + player.acc_carried_item + " (replaced by " + item_struct.id + ")" );
            }
        }

        // CARRY the new one - NO buff yet. The buff is applied at the Plaza Implant
        // Bench (first enable free; each swap costs ACC_BENCH_SWAP_COST points).
        player.acc_carried_item = item_struct.id;
        player iprintln( "Carrying: " + display_for( item_struct ) + " ^7- enable it at the Plaza bench" );
        acc_utility::drops_debug( "item CARRY player=" + player.name + " id=" + item_struct.id );
        player sync_items_hud();
        self notify( "acc_item_claimed" );
        cleanup_pickup();
        return;
    }
}

// Tear down the trigger AND its model together. self = the trigger.
function cleanup_pickup()
{
    if ( isdefined( self.acc_model ) ) self.acc_model delete();
    if ( isdefined( self ) ) self delete();
}

function watch_lifetime()   // self = the hold-use trigger
{
    self endon( "acc_item_claimed" );
    self endon( "death" );

    wait( ACC_ITEM_DROP_LIFETIME_SEC );

    acc_utility::drops_debug( "item DESPAWN id=" + self.acc_item_id + " age=" + ( gettime() - self.acc_created_at ) / 1000 + "s" );
    cleanup_pickup();
}

// ---------------------------------------------------------------------------
// Equip / unequip
// ---------------------------------------------------------------------------

// A fresh 2-slot inventory: both slots empty ("" sentinel, .size == 2). Using a defined sentinel
// instead of undefined keeps the slot indices STABLE (a plain compacting array would shift Slot 2
// down to index 0 when Slot 1 is cleared, breaking the pad->slot mapping).
function empty_slots()
{
    a = [];
    a[ 0 ] = "";
    a[ 1 ] = "";
    return a;
}

function slot_is_empty( player, slot )
{
    if ( !isdefined( player.acc_equipped_items ) ) player.acc_equipped_items = empty_slots();
    return player.acc_equipped_items[ slot ] == "";
}

function player_has_item( player, item_id )
{
    if ( !isdefined( player.acc_equipped_items ) ) return false;
    for ( i = 0; i < player.acc_equipped_items.size; i++ )
    {
        if ( player.acc_equipped_items[ i ] != "" && player.acc_equipped_items[ i ] == item_id ) return true;
    }
    return false;
}

// Put item_id into a SPECIFIC slot (the pad the player used). If the slot is occupied, the old
// occupant's on_unequip runs first (which also performs the tactical-grenade hand-off, docs/12).
function equip_slot( player, slot, item_id )
{
    if ( !isdefined( player.acc_equipped_items ) ) player.acc_equipped_items = empty_slots();
    item_struct = find_item( item_id );
    if ( !isdefined( item_struct ) ) return;
    if ( player_has_item( player, item_id ) ) return;   // never the same item in both slots

    if ( player.acc_equipped_items[ slot ] != "" )
        unequip_slot( player, slot );                   // evict the current occupant first

    player.acc_equipped_items[ slot ] = item_id;
    player [[ item_struct.on_equip ]]();
    player sync_items_hud();
}

// Clear a SPECIFIC slot, running the leaving item's on_unequip. Slot is set to "" BEFORE the
// on_unequip so a tactical hand-off (which reads the OTHER item's acc_item_* flag) sees the
// correct surviving state.
function unequip_slot( player, slot )
{
    if ( !isdefined( player.acc_equipped_items ) ) return;
    item_id = player.acc_equipped_items[ slot ];
    if ( !isdefined( item_id ) || item_id == "" ) return;
    item_struct = find_item( item_id );
    player.acc_equipped_items[ slot ] = "";
    if ( isdefined( item_struct ) ) player [[ item_struct.on_unequip ]]();
    player sync_items_hud();
}

// Persistent on-screen indicator of the player's equipped boss items. Mirrors
// the Data Shards hudelem (_acc_data_shards::sync_shards_to_client) - a
// server-side createFontString, stacked just under the shards line, updated on
// equip / unequip. Lazily created on first call (player is alive at equip time).
function sync_items_hud()   // self = player
{
    if ( !isdefined( self.acc_equipped_items ) ) self.acc_equipped_items = empty_slots();

    // Stacked, ONE PER LINE (user 2026-06-25: the old single concatenated line ran off the left edge
    // into the CENTER of the screen where gameplay happens). Left HUD stack: HEALTH 16 / bar 32 /
    // DATA SHARDS 50 / EXO SUIT 74 / MEGA BOTTLES 98 sit ABOVE; below them, one element per implant slot
    // then the carry line on its OWN line: IMPLANT 1 = 146 / IMPLANT 2 = 168 / CARRYING = 190. (The GAS
    // label/bar were pushed down to 214/232 in ensure_gas_bar to clear these stacked lines.)
    if ( !isdefined( self.acc_items_hud_lines ) )
    {
        self.acc_items_hud_lines = [];
        for ( i = 0; i < ACC_ITEM_SLOTS_PER_PLAYER; i++ )
        {
            e = self hud::createFontString( "default", 1.1 );
            e hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 146 + ( i * 22 ) );
            e.alignX = "left";
            e.alignY = "top";
            e.color = ( 0.80, 0.65, 1.0 ); // cyber-purple (vs shards' cyan)
            e.hidewheninmenu = true;
            e.alpha = 0;
            self.acc_items_hud_lines[ i ] = e;
        }
        self.acc_carry_hud = self hud::createFontString( "default", 1.1 );
        self.acc_carry_hud hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 146 + ( ACC_ITEM_SLOTS_PER_PLAYER * 22 ) );
        self.acc_carry_hud.alignX = "left";
        self.acc_carry_hud.alignY = "top";
        self.acc_carry_hud.color = ( 1.0, 0.82, 0.25 ); // amber - the "carried but not yet enabled" line
        self.acc_carry_hud.hidewheninmenu = true;
        self.acc_carry_hud.alpha = 0;
    }

    // One IMPLANT line per slot, each on its OWN line. Empty slot -> that line hidden.
    for ( i = 0; i < self.acc_equipped_items.size && i < self.acc_items_hud_lines.size; i++ )
    {
        e = self.acc_items_hud_lines[ i ];
        if ( self.acc_equipped_items[ i ] == "" )
        {
            e.alpha = 0;
            continue;
        }
        e SetText( "^5IMPLANT " + ( i + 1 ) + " ^7" + display_for( find_item( self.acc_equipped_items[ i ] ) ) );
        e.alpha = 0.9;
    }

    // CARRYING on its OWN line - shown only when the carried item is NOT already implanted in either slot.
    if ( isdefined( self.acc_carried_item ) && !player_has_item( self, self.acc_carried_item ) )
    {
        self.acc_carry_hud SetText( "^3CARRYING ^7" + display_for( find_item( self.acc_carried_item ) ) + " ^3(enable at bench)" );
        self.acc_carry_hud.alpha = 0.9;
    }
    else
    {
        self.acc_carry_hud.alpha = 0;
    }
}

// ---------------------------------------------------------------------------
// Effect implementations - STUBS
//
// Each apply_*/remove_* runs on `self` = the owning player. Item effects
// are mostly "set a flag or adjust a stat". Other modules read these flags
// to apply the actual gameplay effect.
// ---------------------------------------------------------------------------

function apply_neural_boots()        { self.acc_item_neural_boots = true; setmovespeedscale_hook( self ); acc_utility::log( "equip: neural_boots" ); }
function remove_neural_boots()       { self.acc_item_neural_boots = false; setmovespeedscale_hook( self ); acc_utility::log( "unequip: neural_boots" ); }
function apply_boots()               { self.acc_item_boots = true;  acc_utility::crash_log( self, "apply_boots (equip)" );  setmovespeedscale_hook( self ); acc_utility::log( "equip: boots (+8% move + trench-slow immunity)" ); }
function remove_boots()              { self.acc_item_boots = false; acc_utility::crash_log( self, "remove_boots (unequip)" ); setmovespeedscale_hook( self ); acc_utility::log( "unequip: boots" ); }

function apply_overclocked_gauntlets()   { self.acc_item_gauntlets = true; acc_utility::log( "equip: overclocked_gauntlets" ); }
function remove_overclocked_gauntlets()  { self.acc_item_gauntlets = false; acc_utility::log( "unequip: overclocked_gauntlets" ); }

function apply_targeting_visor()     { self.acc_item_visor = true; acc_utility::log( "equip: targeting_visor" ); }
function remove_targeting_visor()    { self.acc_item_visor = false; acc_utility::log( "unequip: targeting_visor" ); }

function apply_kinetic_battery()
{
    self.acc_item_battery = true;
    self.acc_item_battery_kill_count = 0;
    self.acc_item_battery_charged = false;
    acc_utility::log( "equip: kinetic_battery" );
}
function remove_kinetic_battery()
{
    self.acc_item_battery = false;
    acc_utility::log( "unequip: kinetic_battery" );
}

function apply_ghost_shroud()
{
    self.acc_item_shroud = true;
    self.acc_item_shroud_ready_at = 0;
    acc_utility::log( "equip: ghost_shroud" );
}
function remove_ghost_shroud()       { self.acc_item_shroud = false; acc_utility::log( "unequip: ghost_shroud" ); }

function apply_payroll_ledger()      { self.acc_item_ledger = true; acc_utility::log( "equip: payroll_ledger (+10% Points on kills)" ); }
function remove_payroll_ledger()     { self.acc_item_ledger = false; acc_utility::log( "unequip: payroll_ledger" ); }

// ---------------------------------------------------------------------------
// NEW self-contained buffs (Power Lever / Rocket Shield / Monkey Bomb). These
// use only safe player-object levers - no cross-module hooks - so they can't
// desync other systems: a per-second health add (capped at maxhealth), an
// idempotent max-health delta, and a timed Data Shard grant.
// ---------------------------------------------------------------------------

// Power Lever -> Overcharge: passive health regen while equipped + alive.
function apply_overcharge()
{
    self.acc_item_overcharge = true;
    self thread overcharge_regen_loop();
    acc_utility::log( "equip: power_lever (overcharge +" + ACC_OVERCHARGE_REGEN + " hp/s)" );
}
function remove_overcharge()
{
    self.acc_item_overcharge = false;
    acc_utility::log( "unequip: power_lever" );
}
function overcharge_regen_loop()   // self = player
{
    self endon( "disconnect" );
    for ( ;; )
    {
        wait( 1.0 );
        if ( !( isdefined( self.acc_item_overcharge ) && self.acc_item_overcharge ) ) return;
        if ( !acc_data_shards::is_player_alive( self ) ) continue;
        if ( !isdefined( self.maxhealth ) || self.health >= self.maxhealth ) continue;
        self.health += ACC_OVERCHARGE_REGEN;
        if ( self.health > self.maxhealth ) self.health = self.maxhealth;
    }
}

// Rocket Shield -> Bulwark: +ACC_BULWARK_HP max health. Idempotent recompute
// (tracks the amount currently applied) so equip/unequip/respawn never drift.
function apply_bulwark()
{
    self.acc_item_bulwark = true;
    self recompute_bulwark_health();
    if ( !( isdefined( self.acc_bulwark_watch ) && self.acc_bulwark_watch ) )
    {
        self.acc_bulwark_watch = true;
        self thread bulwark_reapply_on_spawn();
    }
    acc_utility::log( "equip: rocket_shield (+" + ACC_BULWARK_HP + " max hp)" );
}
function remove_bulwark()
{
    self.acc_item_bulwark = false;
    self recompute_bulwark_health();
    acc_utility::log( "unequip: rocket_shield" );
}
function recompute_bulwark_health()   // self = player
{
    if ( !isdefined( self.acc_bulwark_added ) ) self.acc_bulwark_added = 0;
    want = ( ( isdefined( self.acc_item_bulwark ) && self.acc_item_bulwark ) ? ACC_BULWARK_HP : 0 );
    delta = want - self.acc_bulwark_added;
    if ( delta == 0 || !isdefined( self.maxhealth ) ) return;
    self.maxhealth += delta;
    if ( self.maxhealth < 1 ) self.maxhealth = 1;
    self.health += delta;
    if ( self.health > self.maxhealth ) self.health = self.maxhealth;
    if ( self.health < 1 ) self.health = 1;
    self.acc_bulwark_added = want;
}
// Jugg / giveCustomCharacters reset maxhealth on each spawn (same trap as the
// move-speed reapply), so re-add the bonus after every "spawned_player".
function bulwark_reapply_on_spawn()   // self = player
{
    self endon( "disconnect" );
    for ( ;; )
    {
        self waittill( "spawned_player" );
        wait( 0.1 );
        self.acc_bulwark_added = 0;   // spawn wiped our bonus; recompute from base
        self recompute_bulwark_health();
    }
}

// Monkey Bomb -> Salvage: +1 Data Shard every ACC_SALVAGE_INTERVAL_SEC while alive.
function apply_salvage()
{
    self.acc_item_salvage = true;
    self thread salvage_income_loop();
    acc_utility::log( "equip: monkey_bomb (salvage +1 shard/" + ACC_SALVAGE_INTERVAL_SEC + "s)" );
}
function remove_salvage()
{
    self.acc_item_salvage = false;
    acc_utility::log( "unequip: monkey_bomb" );
}
function salvage_income_loop()   // self = player
{
    self endon( "disconnect" );
    for ( ;; )
    {
        wait( ACC_SALVAGE_INTERVAL_SEC );
        if ( !( isdefined( self.acc_item_salvage ) && self.acc_item_salvage ) ) return;
        if ( !acc_data_shards::is_player_alive( self ) ) continue;
        acc_data_shards::grant_player( self, 1, "salvage" );
    }
}

// ===========================================================================
// REDESIGNED item buffs (2026-06-17) + the Plaza Implant Bench.
// Detection uses POLLING (GetStance/IsSprinting/IsOnGround/velocity), NOT the
// slide_begin/sprint_begin/jump_begin notifies (those are MP-only - zero ZM
// consumers in stock). See docs/12 + the feasibility spec.
// ===========================================================================

// --- Item 1: Gas Tank -> nitro burst. Double-tap SPRINT = 5s +20% move speed,
//     then a 30s lockout (cannot re-trigger until fully regenerated). The burst
//     runs its full 5s and is not cancellable. Speed rides recompute_move_speed.
function apply_gas_tank()    // self = player
{
    self.acc_item_gas_tank = true;
    self thread gas_tank_watch();
    self thread gas_bar_loop();           // on-screen NITRO charge bar (the player's indication)
    acc_utility::log( "equip: gas_tank (nitro burst)" );
}
function remove_gas_tank()
{
    self.acc_item_gas_tank = false;
    self notify( "acc_gas_tank_removed" );   // ends gas_tank_watch + gas_bar_loop
    self.acc_gas_burst    = false;
    self.acc_gas_cooldown = false;           // clear any in-progress lockout (the burst thread just died) so re-equip is ready
    acc_utility::recompute_move_speed( self );
    self destroy_gas_bar();
    acc_utility::log( "unequip: gas_tank" );
}
function gas_tank_watch()    // self = player; double-tap of the SPRINT button triggers the burst
{
    self endon( "disconnect" );
    self endon( "acc_gas_tank_removed" );
    dtap_ms = getdvarint( "acc_gas_dtap_ms", 350 );
    last = 0;
    was_down = false;
    for ( ;; )
    {
        wait( 0.05 );
        // SprintButtonPressed() = the raw sprint-KEY state (tap-able), NOT IsSprinting()
        // which latches true continuously under ZM auto-sprint and so never gives a second
        // rising edge for a double-tap (that was the bug). Verified stock builtin (_prowler.gsc:45).
        down = self SprintButtonPressed();
        if ( down && !was_down )   // rising edge of a sprint-button tap
        {
            now = gettime();
            if ( ( now - last ) <= dtap_ms && !( isdefined( self.acc_gas_cooldown ) && self.acc_gas_cooldown ) )
            {
                last = 0;
                self thread gas_tank_burst();
            }
            else
            {
                last = now;
            }
        }
        was_down = down;
    }
}
function gas_tank_burst()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_gas_tank_removed" );
    self.acc_gas_cooldown    = true;          // locked until fully regenerated
    self.acc_gas_burst       = true;
    self.acc_gas_burst_start = gettime();     // timestamp the NITRO bar reads (gas_charge_frac)
    acc_utility::recompute_move_speed( self );
    self iprintln( "^2Nitro!" );
    wait( ACC_GAS_BURST_SEC );                // full duration; by design not cancellable
    self.acc_gas_burst = false;
    acc_utility::recompute_move_speed( self );
    wait( getdvarfloat( "acc_gas_regen_sec", ACC_GAS_REGEN_SEC ) );   // regen lockout AFTER the burst ends (live dvar)
    self.acc_gas_cooldown = false;
    self iprintln( "^7Nitro recharged" );
}

// ---------------------------------------------------------------------------
// Gas Tank "NITRO" charge bar (player indication). Reuses the verified hud::createBar
// widget (see _acc_health_bars.gsc): full CYAN = ready; drains to empty over the 5s
// burst; refills ORANGE over the 30s regen. Created on equip, destroyed on unequip.
// Polled at 20Hz against a charge fraction computed from acc_gas_burst_start, so the
// motion is smooth without needing scaleOverTime.
// ---------------------------------------------------------------------------
function gas_bar_loop()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_gas_tank_removed" );
    self ensure_gas_bar();
    for ( ;; )
    {
        wait( 0.05 );
        if ( !isdefined( self.acc_gas_bar ) ) return;
        frac = self gas_charge_frac();
        self.acc_gas_bar set_gas_bar_fill( frac );
        if ( isdefined( self.acc_gas_bar.bar ) )
        {
            if ( frac >= 1.0 ) self.acc_gas_bar.bar.color = ( 0.30, 0.90, 1.0 );   // cyan = charged / ready
            else self.acc_gas_bar.bar.color = ( 0.95, 0.55, 0.10 );                // orange = charging
        }
    }
}
function ensure_gas_bar()    // self = player
{
    if ( isdefined( self.acc_gas_bar ) ) return;
    // Small caption for the NITRO bar (tells you how to fire it). fontscale 1.0 to match
    // HEALTH. DO NOT use a sub-1.0 fontscale here: 0.9 rendered HUGELY oversized in-game
    // (2026-06-18) - keep this >= 1.0.
    self.acc_gas_label = self hud::createFontString( "default", 1.0 );
    self.acc_gas_label hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 214 );   // below the stacked IMPLANT/CARRYING lines (user 2026-06-25)
    self.acc_gas_label.alignX = "left";
    self.acc_gas_label.alignY = "top";
    self.acc_gas_label.color  = ( 0.30, 0.90, 1.0 );
    self.acc_gas_label.alpha  = 0.85;
    self.acc_gas_label.hidewheninmenu = true;
    self.acc_gas_label SetText( "^7Double-tap Sprint to activate" );

    self.acc_gas_bar = self hud::createBar( ( 0.30, 0.90, 1.0 ), ACC_GAS_BAR_W, ACC_GAS_BAR_H );
    self.acc_gas_bar hud::setPoint( "TOP_LEFT", "TOP_LEFT", 16, 232 );   // below the moved gas label (user 2026-06-25)
    self.acc_gas_bar.alpha = 0.85;
    self.acc_gas_bar.hidewheninmenu = true;
}
function destroy_gas_bar()    // self = player; torn down on unequip, recreated on re-equip
{
    if ( isdefined( self.acc_gas_label ) ) { self.acc_gas_label destroy(); self.acc_gas_label = undefined; }
    if ( isdefined( self.acc_gas_bar ) )
    {
        if ( isdefined( self.acc_gas_bar.bar ) ) self.acc_gas_bar.bar destroy();
        self.acc_gas_bar destroy();
        self.acc_gas_bar = undefined;
    }
}
// Charge 0..1: 1.0 when ready; drains 1->0 over the burst, refills 0->1 over the regen.
function gas_charge_frac()    // self = player
{
    if ( !( isdefined( self.acc_gas_cooldown ) && self.acc_gas_cooldown ) )
        return 1.0;
    if ( !isdefined( self.acc_gas_burst_start ) )
        return 1.0;
    elapsed = ( gettime() - self.acc_gas_burst_start ) / 1000.0;   // seconds since the burst began
    regen   = getdvarfloat( "acc_gas_regen_sec", ACC_GAS_REGEN_SEC );   // same value gas_tank_burst waits on
    if ( elapsed < ACC_GAS_BURST_SEC )
        return 1.0 - ( elapsed / ACC_GAS_BURST_SEC );                       // burst: drain to empty
    if ( elapsed < ( ACC_GAS_BURST_SEC + regen ) )
        return ( elapsed - ACC_GAS_BURST_SEC ) / regen;                     // regen: refill
    return 1.0;
}
// Snap a createBar fill to `frac` of its width. The source frac changes continuously each
// 20Hz tick, so a direct width set already reads smooth. self = the bar BG (createBar return).
function set_gas_bar_fill( frac )    // self = bar BG elem
{
    if ( !isdefined( self ) || !isdefined( self.bar ) ) return;
    if ( frac < 0 ) frac = 0;
    if ( frac > 1 ) frac = 1;
    w = int( self.width * frac + 0.5 );
    if ( w < 1 ) w = 1;
    self.bar setShader( self.bar.shader, w, self.height );
}

// --- Item 2: Li'l Arnie -> cloak. Horde can't target you via the ref-counted
//     ignoreme flag; the Glitch Stalker is covered in _acc_boss_glitch
//     (get_closest_uncloaked_player). NEVER write .ignoreme directly - laststand
//     shares the same counter; use the increment/decrement pair.
// Phase Serum -> CLOAK vs the GLITCH STALKER ONLY (not the regular horde). We set a
// custom flag that only the Stalker's targeting (acc_utility::get_closest_uncloaked_player)
// honors - we deliberately do NOT use zm_utility::increment_ignoreme (that hid you
// from EVERY zombie, which was the "works on all zombies" bug).
function apply_arnie_cloak()    // self = player
{
    self.acc_cloak_glitch = true;
    acc_utility::log( "equip: phase_serum (glitch-only cloak)" );
}
function remove_arnie_cloak()
{
    self.acc_cloak_glitch = false;
    acc_utility::log( "unequip: phase_serum" );
}

// Li'l Arnie (v2) -> grants the Octobomb tactical (base-game SoE weapon, unlike the
// DLC cymbal monkey). Mirrors the give pattern; GiveWeapon doesn't survive revive
// -> regrant on spawn. Needs the octobomb CSV row ONLY - do NOT add a
// weapon,octobomb_zm .zone line (that re-packs from an absent GDT and errors
// "Unable to load weapon"; the def already ships in zm_levelcommon, so the CSV
// row alone makes is_weapon_included true and GetWeapon resolves at runtime).
function apply_arnie_octobomb()    // self = player
{
    self.acc_item_arnie = true;
    self.acc_tactical_owner = "lil_arnie";   // last-implanted grenade wins the single tactical slot (docs/12)
    self give_octobomb();
    self thread octobomb_regrant_on_spawn();
    acc_utility::log( "equip: lil_arnie (octobomb tactical)" );
}
function remove_arnie_octobomb()
{
    // Did WE own the single tactical slot? If the co-resident Monkey Bomb did, removing us must NOT
    // touch the tactical at all - re-granting the survivor here would take+regive the player's held
    // Cymbal Monkey and reset its ammo to 4 (two-slot churn bug, docs/12). Capture before clearing.
    was_owner = ( isdefined( self.acc_tactical_owner ) && self.acc_tactical_owner == "lil_arnie" );
    self.acc_item_arnie = false;
    self notify( "acc_arnie_removed" );
    w = getweapon( "octobomb" );
    if ( self HasWeapon( w ) ) self TakeWeapon( w );
    if ( !was_owner ) { acc_utility::log( "unequip: lil_arnie (not tactical owner; left as-is)" ); return; }
    // We owned the tactical: hand it to the OTHER grenade item if still implanted (last-one-wins
    // graceful fallback), else clear to weaponNone.
    if ( isdefined( self.acc_item_monkey ) && self.acc_item_monkey )
    {
        self.acc_tactical_owner = "monkey_bomb";
        self give_monkey_bomb();
    }
    else
    {
        self.acc_tactical_owner = undefined;
        self zm_utility::set_player_tactical_grenade( level.weaponNone );
    }
    acc_utility::log( "unequip: lil_arnie" );
}
function give_octobomb()    // self = player
{
    cur = self zm_utility::get_player_tactical_grenade();
    if ( isdefined( cur ) && cur != level.weaponNone ) self TakeWeapon( cur );
    w = getweapon( "octobomb" );
    self GiveWeapon( w );
    self zm_utility::set_player_tactical_grenade( w );
    self SetWeaponAmmoStock( w, 4 );

    // ACTIVATE the thrown-grenade behavior (attract / spore / explode). Raw
    // GiveWeapon bypasses zm_weapons::weapon_give - the ONLY stock path that
    // dispatches the registered zombie-weapon callback (player_give_octobomb,
    // _zm_weapons.gsc:2791-2793) which threads the per-player grenade_fire
    // watcher. Without this the projectile just sits there. We dispatch the
    // callback the same way stock does; the watcher self-guards (notify/endon)
    // so re-grant on revive is safe. No #using/clientfield needed (level field).
    if ( isdefined( level.zombie_weapons_callbacks ) && isdefined( level.zombie_weapons_callbacks[ w ] ) )
    {
        self thread [[ level.zombie_weapons_callbacks[ w ] ]]();
    }
}
function octobomb_regrant_on_spawn()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_arnie_removed" );
    for ( ;; )
    {
        self waittill( "spawned_player" );
        wait( 0.1 );
        // Only the CURRENT tactical owner regrants - if Monkey Bomb out-implanted us, it owns the
        // slot and this no-ops (prevents the two regrant threads from fighting on every spawn).
        if ( isdefined( self.acc_item_arnie ) && self.acc_item_arnie
             && isdefined( self.acc_tactical_owner ) && self.acc_tactical_owner == "lil_arnie" )
        {
            self give_octobomb();
        }
    }
}

// Shrink the Li'l Arnie (octobomb) visual to acc_arnie_scale (user 2026-06-18: they were huge,
// ~1/3 size). The thrown octobomb's VISIBLE model is e_grenade.anim_model (a util::spawn_model
// script_model, _zm_weap_octobomb.gsc:341, tracked in level.octobombs) - NOT a live AI, so
// SetScale is safe here (the 0xC0000005 SetScale crash is specific to live actors like Brutus).
// Poll level.octobombs and scale each new one's anim_model once. Scaling only the visual leaves
// the attract/explode behavior (on the grenade entity) intact. Set acc_arnie_scale 1 to disable.
function scale_octobombs_watch()
{
    level endon( "end_game" );
    for ( ;; )
    {
        wait( 0.1 );
        if ( !isdefined( level.octobombs ) ) continue;
        for ( i = 0; i < level.octobombs.size; i++ )
        {
            ob = level.octobombs[ i ];
            if ( isdefined( ob ) && isdefined( ob.anim_model ) && !isdefined( ob.anim_model.acc_arnie_scaled ) )
            {
                ob.anim_model.acc_arnie_scaled = true;
                ob.anim_model SetScale( getdvarfloat( "acc_arnie_scale", 1.0 ) );   // user 2026-06-24: back to NORMAL size (was 0.33 minimized). 1.0 = default model size (shrink off).
            }
        }
    }
}

// --- Item 5: Rocket Shield -> mobility. (a) +15% move speed while sliding,
//     (b) a forward distance impulse on slide-start (engine has NO slide-DURATION
//     lever), (c) ~2x jump HEIGHT via a per-player velocity multiply (NOT the global
//     jump_height dvar; apex height ~ velocity^2, so x1.42 velocity = double height).
//     Tunable dvars: acc_rocket_slide_kick (lunge), acc_rocket_slide_mult (+speed),
//     acc_rocket_jump_mult (jump). Slide detection is IsSliding() now (acc_rocket_slide_thresh unused).
function apply_rocket_shield()    // self = player
{
    self.acc_item_rocket_shield = true;
    self thread rocket_shield_watch();
    acc_utility::log( "equip: rocket_shield (slide/jump mobility)" );
}
function remove_rocket_shield()
{
    self.acc_item_rocket_shield = false;
    self notify( "acc_rocket_shield_off" );
    self.acc_rocket_slide_speed = false;
    acc_utility::recompute_move_speed( self );
    acc_utility::log( "unequip: rocket_shield" );
}
function rocket_shield_watch()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_rocket_shield_off" );
    run_thresh = getdvarint( "acc_rocket_slide_thresh", 200 );
    slide_kick = getdvarint( "acc_rocket_slide_kick", 200 );
    jump_mult  = getdvarfloat( "acc_rocket_jump_mult", 1.42 );   // ~2x apex: jump height ~ velocity^2, so x1.42 velocity = double height
    was_ground = true;
    sliding    = false;
    for ( ;; )
    {
        wait( 0.05 );
        v        = self GetVelocity();
        spd_sq   = v[ 0 ] * v[ 0 ] + v[ 1 ] * v[ 1 ];
        onground = self IsOnGround();

        // (a)+(b) SLIDE = the engine's dedicated slide state, grounded. GetStance() NEVER
        // returns a "slide" value (only stand/crouch/prone) and a BO3 slide is entered from
        // sprint=stand, so the old ==\"crouch\" gate basically never latched. IsSliding() is
        // true for the whole slide (verified stock: _behavior_tracker.gsc / challenges_shared.gsc).
        now_slide = ( self IsSliding() && onground );
        if ( now_slide && !sliding )
        {
            acc_utility::crash_log( self, "rocket_shield_watch: slide-kick ->SetVelocity" );
            yaw = self GetPlayerAngles()[ 1 ];
            self SetVelocity( self GetVelocity() + AnglesToForward( ( 0, yaw, 0 ) ) * slide_kick );
        }
        if ( now_slide != sliding )
        {
            sliding = now_slide;
            self.acc_rocket_slide_speed = now_slide;   // +15% via recompute_move_speed
            acc_utility::crash_log( self, "rocket_shield_watch: slide " + ( now_slide ? "ON" : "off" ) );
            acc_utility::recompute_move_speed( self );
        }

        // (c) JUMP = ground->air rising edge with upward velocity (ADD to keep horizontal).
        if ( was_ground && !onground && v[ 2 ] > 10 )
        {
            jv = self GetVelocity();
            self SetVelocity( ( jv[ 0 ], jv[ 1 ], jv[ 2 ] * jump_mult ) );
        }
        was_ground = onground;
    }
}

// --- Item 6: Monkey Bomb -> grants the Cymbal Monkey tactical (the only source
//     in this map). Inclusion is via the CSV row ONLY - do NOT add a
//     weapon,cymbal_monkey_zm .zone line (re-packs from an absent GDT -> errors
//     "Unable to load weapon"; the def already ships in zm_levelcommon).
//     GiveWeapon does NOT survive revive -> re-grant on spawn.
function apply_monkey_bomb()    // self = player
{
    self.acc_item_monkey = true;
    self.acc_tactical_owner = "monkey_bomb";   // last-implanted grenade wins the single tactical slot (docs/12)
    self give_monkey_bomb();
    self thread monkey_regrant_on_spawn();
    acc_utility::log( "equip: monkey_bomb (cymbal monkey tactical)" );
}
function remove_monkey_bomb()
{
    // Mirror of remove_arnie_octobomb: only touch the tactical slot if WE owned it (else the
    // co-resident Li'l Arnie owns it and must be left alone - no needless re-grant/ammo reset).
    was_owner = ( isdefined( self.acc_tactical_owner ) && self.acc_tactical_owner == "monkey_bomb" );
    self.acc_item_monkey = false;
    self notify( "acc_monkey_removed" );
    w = getweapon( "cymbal_monkey" );
    if ( self HasWeapon( w ) ) self TakeWeapon( w );
    if ( !was_owner ) { acc_utility::log( "unequip: monkey_bomb (not tactical owner; left as-is)" ); return; }
    if ( isdefined( self.acc_item_arnie ) && self.acc_item_arnie )
    {
        self.acc_tactical_owner = "lil_arnie";
        self give_octobomb();
    }
    else
    {
        self.acc_tactical_owner = undefined;
        self zm_utility::set_player_tactical_grenade( level.weaponNone );
    }
    acc_utility::log( "unequip: monkey_bomb" );
}
function give_monkey_bomb()    // self = player
{
    cur = self zm_utility::get_player_tactical_grenade();
    if ( isdefined( cur ) && cur != level.weaponNone ) self TakeWeapon( cur );
    w = getweapon( "cymbal_monkey" );
    self GiveWeapon( w );
    self zm_utility::set_player_tactical_grenade( w );
    self SetWeaponAmmoStock( w, 4 );

    // ACTIVATE the thrown-monkey behavior (attract via point-of-interest +
    // detonate) - same dispatch hack as give_octobomb above (raw GiveWeapon
    // skips weapon_give's callback dispatch). cymbal registers no clientfields.
    if ( isdefined( level.zombie_weapons_callbacks ) && isdefined( level.zombie_weapons_callbacks[ w ] ) )
    {
        self thread [[ level.zombie_weapons_callbacks[ w ] ]]();
    }
}
function monkey_regrant_on_spawn()    // self = player
{
    self endon( "disconnect" );
    self endon( "acc_monkey_removed" );
    for ( ;; )
    {
        self waittill( "spawned_player" );
        wait( 0.1 );
        // Only the CURRENT tactical owner regrants (mirror of octobomb_regrant_on_spawn).
        if ( isdefined( self.acc_item_monkey ) && self.acc_item_monkey
             && isdefined( self.acc_tactical_owner ) && self.acc_tactical_owner == "monkey_bomb" )
        {
            self give_monkey_bomb();
        }
    }
}

// Box-rolled tactical finalizer (user 2026-06-24): Monkey Bomb + Li'l Arnie are no longer boss-item implants -
// they are rare MYSTERY-BOX rolls (1% / 0.5%; _acc_map_randomizer::acc_box_only_weapon_keys sets
// self.acc_box_pending_tactical and floats the tactical when the pre-roll hits). The stock box give
// (zm_weapons::weapon_give) already dispatches the thrown-grenade callback, but we re-assert via give_* to
// guarantee the ACTIVE tactical slot + ammo (4) are set exactly like the old implant. Fires on the stock
// "user_grabbed_weapon" player notify (_zm_magicbox.gsc:809). One-shot: the flag is consumed on grab and the
// box pre-roll clears it whenever a GUN is rolled, so a normal gun grab never triggers this.
function watch_box_tactical_grab()    // self = player
{
    self endon( "disconnect" );
    level endon( "end_game" );
    for ( ;; )
    {
        self waittill( "user_grabbed_weapon" );
        pend = self.acc_box_pending_tactical;
        self.acc_box_pending_tactical = undefined;   // consume
        if ( !isdefined( pend ) ) continue;
        wait( 0.05 );                                // let stock weapon_give settle, then assert our setup
        if ( pend == "monkey_bomb" )    self give_monkey_bomb();
        else if ( pend == "lil_arnie" ) self give_octobomb();
    }
}

// ---------------------------------------------------------------------------
// Plaza Implant Bench - ENABLE a carried item onto your character. First enable
// is free; each later swap costs ACC_BENCH_SWAP_COST points. Runtime-spawned
// beside the Plaza spawn struct (no Radiant edit; GSC-only).
// ---------------------------------------------------------------------------
function spawn_bench()
{
    level endon( "end_game" );

    s = undefined;
    for ( i = 0; i < 100; i++ )   // structs parse at load; poll briefly in case init() runs first
    {
        s = struct::get( "player_respawn_point", "targetname" );
        if ( isdefined( s ) ) break;
        wait( 0.1 );
    }
    if ( !isdefined( s ) )
    {
        acc_utility::log( "bench: no player_respawn_point struct - bench not spawned" );
        return;
    }

    // Place the pair AGAINST THE SOUTH WALL of the Plaza, behind the spawn points, instead of in
    // the wide-open middle (user 2026-06-24). The south wall's interior face is at y=-540 (full
    // width, no exits, no props - verified vs the baked .map perimeter brushes), so off_y=-350 from
    // the spawn struct (y=-130.67) puts the pads at y=-480.67 == ~59u in front of the wall: clearly
    // "against the wall" with clearance for the table model + the use-trigger. off_x=0 centers the
    // row on the spawn X (-227.5). off_z keeps the floor height that was tuned 2026-06-18. All live
    // dvars for in-game nudging.
    base = s.origin + ( getdvarint( "acc_bench_off_x", 0 ), getdvarint( "acc_bench_off_y", -350 ), getdvarint( "acc_bench_off_z", -35 ) );
    // TWO bench pads = the two implant slots (user 2026-06-23, docs/12). The player picks WHICH slot
    // to fill/replace by which pad they look at - no in-game menu needed (BO3 usermap GSC has none).
    // Pads sit SIDE BY SIDE along X (a row parallel to the south wall) so both back up to the wall,
    // far enough apart that their use-trigger volumes do NOT overlap (radius 40 each, 2*sep=160 apart
    // > 80 diameter -> no ambiguous double-fire) and wide enough that the two table models can't
    // overlap at any orientation. Live dvar for in-game tuning.
    sep = getdvarint( "acc_bench_pad_sep", 80 );
    spawn_bench_pad( base + ( -1 * sep, 0, 0 ), 0 );   // Slot 1 (left/west pad)
    spawn_bench_pad( base + (      sep, 0, 0 ), 1 );   // Slot 2 (right/east pad)
}
function spawn_bench_pad( org, slot )   // slot = fixed target index (0 = Slot 1, 1 = Slot 2)
{
    bench = spawn( "script_model", org );
    bench setmodel( "p7_cai_work_table_metal_03_white" ); // Implant Bench: Cyber City white metal workbench

    t = spawn( "trigger_radius_use", org + ( 0, 0, 40 ), 0, getdvarint( "acc_bench_pad_radius", 40 ), 80 );
    t TriggerIgnoreTeam();
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7 implant ^5Slot " + ( slot + 1 ) + "^7 (free if empty, else " + ACC_BENCH_SWAP_COST + ")" );
    t.acc_bench_slot = slot;
    acc_utility::log( "bench: pad Slot " + ( slot + 1 ) + " spawned at " + org );
    t thread bench_use_loop();
}
function bench_use_loop()    // self = a bench pad trigger; self.acc_bench_slot = the slot it fills
{
    level endon( "end_game" );
    slot = self.acc_bench_slot;
    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !acc_data_shards::is_player_alive( player ) ) continue;

        carried = player.acc_carried_item;
        if ( !isdefined( carried ) )
        {
            player iprintln( "Implant Bench: nothing carried (kill a boss to find an item)" );
            wait( 0.5 );
            continue;
        }
        // Already implanted in EITHER slot -> nothing to do (don't let it re-charge / dup).
        if ( player_has_item( player, carried ) )
        {
            player iprintln( "Implant Bench: that item is already implanted" );
            wait( 0.5 );
            continue;
        }

        // FREE to fill an empty slot; ACC_BENCH_SWAP_COST to REPLACE this slot's current item.
        // (So any empty slot is always free - the "first two free" rule, docs/12.)
        is_free = slot_is_empty( player, slot );
        if ( !is_free )
        {
            if ( !( player zm_score::can_player_purchase( ACC_BENCH_SWAP_COST ) ) )
            {
                player iprintln( "Implant Bench: needs " + ACC_BENCH_SWAP_COST + " points to replace Slot " + ( slot + 1 ) );
                wait( 0.5 );
                continue;
            }
            player zm_score::minus_to_player_score( ACC_BENCH_SWAP_COST );
        }

        equip_slot( player, slot, carried );          // evicts the slot's old occupant (if any), then equips
        player.acc_carried_item = undefined;          // carry consumed (no scalar acc_active_item anymore)
        player PlaySound( "acc_item_implant" );        // implant stinger (docs/12; 48k wav at sound_assets\acc\fx\item_implant.wav)
        player iprintln( ( is_free ? "^2Implanted (free): ^7" : "^2Replaced Slot " + ( slot + 1 ) + " (-" + ACC_BENCH_SWAP_COST + "): ^7" ) + display_for( find_item( carried ) ) );
        acc_utility::drops_debug( "bench IMPLANT player=" + player.name + " slot=" + slot + " id=" + carried + " free=" + is_free );
        player sync_items_hud();
        wait( 0.5 );
    }
}

// Exposed helper so _acc_points.gsc can apply the ledger bonus without
// knowing the implementation detail of the flag name.
function player_has_ledger( player )
{
    if ( !isdefined( player ) ) return false;
    if ( !isdefined( player.acc_item_ledger ) ) return false;
    return player.acc_item_ledger == true;
}

// Movement speed hook - applies +20% when Neural Boots equipped AND holding a primary.
// VERIFIED(acc): SetMoveSpeedScale(player, float) is the stock API
// (_zm.gsc:4795, zm_usermap.gsc:336). Stamin-Up uses the 'marathon' specialty,
// not this scale - no perk conflict. Respawn reset handled by
// reapply_move_speed_on_spawn above.
function setmovespeedscale_hook( player )
{
    // VERIFIED(acc): the scale is ABSOLUTE (last-writer-wins), so all speed
    // sources recompute through the single owner in acc_utility - Neural
    // Boots, Cyberware Reflex T1, and The Flash Mega stack there.
    // TODO(acc-verify): boots should only apply when holding a primary.
    acc_utility::recompute_move_speed( player );
}
