// =============================================================================
// _acc_armory.gsc - "The Armory": an upper room (reached by staircases up from the
// Plaza) housing two team-support stations (user 2026-07-07):
//
//   1. TEAM WEAPON RACK - a shared, POOLED deposit/withdraw rack for guns. Any player
//      DEPOSITS the weapon they are holding into a shared team rack; ANY teammate
//      WITHDRAWS it. This is the "give guns to teammates" ask, built as a POOL (not a
//      directed give) - the same model the user chose for The Exchange (_acc_transfer.gsc):
//      no player-targeting, so it dodges the closest_player_override / snapshot co-op
//      hazards entirely (docs/37, docs/39). A gifted gun is auto-balanced: acc_weapon_balance_mult
//      is NAME-keyed / owner-agnostic (_acc_damage.gsc), so zero per-give work. Holds ONE
//      gun at a time (acc_armory_rack_max=1, user 2026-07-10); the racked gun's WORLD MODEL
//      displays centered on the cabinet top (the magicbox idiom - PaP camo included).
//
//   2. MEGA-BOTTLE EXCHANGE - spend 1 Empty Mega Bottle for a random "item" = a random
//      IMPLANT / boss item (user 2026-07-07: "should be dropping implants instead" of powerups).
//      Drops one via acc_boss_items::grant_challenge_reward -> spawn_pickup: floor-snapped,
//      free-for-all, self-despawns after 60s (ACC_ITEM_DROP_LIFETIME_SEC / watch_lifetime).
//      A NEW bottle SINK, distinct from The Exchange (which only MOVES bottles between players).
//
// STATIONS ARE PURE GSC (script-spawned trigger_radius_use pads - the canonical station
// recipe mirroring _acc_transfer / _acc_glitch_altar): no .map entity, no zone-material
// line, ZERO LED-bake risk. They ship -GscOnly. The room geometry (gen_upper_room.js: buyable
// east-wall door + east staircase + loft) is separate; stations placed at the loft in spawn_stations().
//
// Live dvars: acc_armory_rack_max (1 - shared rack capacity: ONE gun at a time, user 2026-07-10),
//             acc_armory_bottle_cost (1 - Empty Mega Bottles per exchange for a random implant).
// =============================================================================

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;       // grant_challenge_reward (bottle -> random implant)
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;   // wonder_cap_key (rack exclusion)

// STATION REMODEL (user 2026-07-09, docs/09): distinct meshes per station - the weapon rack is
// the Conduit armory cabinet (138 LONG in X x 18 x 48; T7-dump carve, its long axis spans the
// deposit/withdraw pads at +/-55), the bottle exchange is the stock Wonderfizz chassis
// (bottle-for-random-reward read; packs from the stock gdtDB, probe-verified 2026-07-09).
#precache( "model", "p7_con_cargo_train_armory_cabinet" );
#precache( "model", "p7_zm_vending_wonder" );

#namespace acc_armory;

// ---------------------------------------------------------------------------
// Init
// ---------------------------------------------------------------------------

function init()
{
    // Shared team weapon rack: a FIFO list of STRUCT entries { wpn, model }. wpn = the
    // weapon OBJECT (persistent level.weapons entry, so re-giving a stored one is always
    // valid); model = its world-model display on the cabinet top (undefined only if the
    // ent-pool spawn failed - the rack still works, just undisplayed). One array keyed by
    // slot = wpn+model can never desync, and duplicate weapon objects (two players rack
    // the same gun class -> the SAME level.weapons singleton twice) stay distinct entries.
    // Level-side = the only shared store; a weapon is a per-player inventory item with no
    // shared field, so the rack has to be our own level var. A depositor's disconnect
    // loses nothing - the deposit transfers the gun to the level immediately (same
    // ownership model as The Exchange).
    level.acc_armory_rack = [];

    acc_utility::log( "armory init" );
    level thread spawn_stations();
}

function spawn_stations()
{
    level endon( "end_game" );
    wait 1;   // after mega_bottles + data_shards init (their accessors + pools ready)

    // The Armory loft floor is z=288, footprint x[714,1074] y[-200,200] (tools/gen_upper_room.js).
    // Reached via the buyable EAST-wall door + the east-climbing staircase. Stations sit in the
    // east half, clear of the WEST-wall stair doorway (x=714 @ y[-64,64]).
    spawn_rack_station( ( 870, -100, 288 ) );   // team weapon rack (deposit + withdraw pads)
    spawn_bottle_station( ( 870, 100, 288 ) );  // mega-bottle exchange

    acc_utility::log( "armory: stations spawned (weapon rack + bottle exchange) [loft z=288]" );
}

// ---------------------------------------------------------------------------
// Team weapon rack (pooled deposit / withdraw - the _acc_transfer idiom)
// ---------------------------------------------------------------------------

function spawn_rack_station( origin )
{
    base = spawn( "script_model", origin );
    base setmodel( "p7_con_cargo_train_armory_cabinet" );   // long weapons cabinet - pads sit at its two ends
    level.acc_armory_rack_base = base;   // display-slot anchor (rack_slot_origin)

    // DEPOSIT pad (west of the kiosk) + WITHDRAW pad (east). One trigger per action - BO3
    // use-triggers are single-button (the Exchange's multi-pad idiom). Pads are 110u apart,
    // radius 40, so they never overlap.
    level.acc_armory_rack_pads = [];
    spawn_rack_pad( "deposit",  origin + ( -55, 0, 0 ) );
    spawn_rack_pad( "withdraw", origin + (  55, 0, 0 ) );
    update_rack_hints();   // initial (empty-rack) hints
}

function spawn_rack_pad( op, origin )
{
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 40, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable
    t SetCursorHint( "HINT_NOICON" );
    t.acc_op = op;
    level.acc_armory_rack_pads[ op ] = t;   // hint text lives in update_rack_hints (state-aware)
    t thread rack_loop();
}

// STATE-AWARE PAD HINTS (user 2026-07-10 UI pass): the hint itself tells you the rack state
// BEFORE you press - the old static hints invited a press that could only refuse ("TAKE a
// weapon" on an empty rack / "RACK your held weapon" on an occupied one). Call after every
// rack mutation. 4-6 CONSTANT strings total => configstring-cache safe. A player already
// aiming at a pad picks the new text up on the next hint refresh (worst case: re-aim).
function update_rack_hints()
{
    if ( !isdefined( level.acc_armory_rack_pads ) ) return;
    stored = level.acc_armory_rack.size;
    cap = getdvarint( "acc_armory_rack_max", 1 );

    pad = level.acc_armory_rack_pads[ "deposit" ];
    if ( isdefined( pad ) )
    {
        if ( stored >= cap )
            pad SetHintString( ( cap == 1 ? "Rack ^3OCCUPIED^7 - a teammate can ^5TAKE^7 the weapon at the other end" : "The team rack is ^3FULL^7 - ^5TAKE^7 a weapon at the other end" ) );
        else
            pad SetHintString( "Hold ^3[{+activate}]^7  ^2RACK^7 your held weapon for a teammate" );
    }

    pad = level.acc_armory_rack_pads[ "withdraw" ];
    if ( isdefined( pad ) )
    {
        if ( stored <= 0 )
            pad SetHintString( "Rack ^3EMPTY^7 - ^2RACK^7 a weapon at the other end to share it" );
        else
            pad SetHintString( ( stored == 1 ? "Hold ^3[{+activate}]^7  ^5TAKE^7 the racked weapon" : "Hold ^3[{+activate}]^7  ^5TAKE^7 the next racked weapon" ) );
    }
}

function rack_loop()   // self = the pad trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) )
            continue;   // gate both ends (downed/spectating can't transact; disconnected = undefined)

        if ( self.acc_op == "deposit" ) deposit_gun( player );
        else                            withdraw_gun( player );

        wait 0.4;   // per-press debounce (one hold must not double-fire)
    }
}

function deposit_gun( player )
{
    cap = getdvarint( "acc_armory_rack_max", 1 );   // ONE gun at a time (user 2026-07-10)
    if ( level.acc_armory_rack.size >= cap )
    {
        player deny( ( cap == 1 ? "the rack already holds a weapon - take it first" : "the team rack is full" ) );
        return;
    }

    wpn = player GetCurrentWeapon();
    if ( !isdefined( wpn ) || wpn == level.weaponNone )
        { player deny( "hold the weapon you want to rack" ); return; }

    // Only real PRIMARY guns: excludes the pistol/knife/equipment (not in the primaries list)
    // and melee/mines. is_primary_owned also proves the player actually holds it.
    if ( zm_utility::is_melee_weapon( wpn ) || zm_utility::is_placeable_mine( wpn ) )
        { player deny( "hold a primary weapon to rack it" ); return; }
    if ( !is_primary_owned( player, wpn ) )
        { player deny( "hold a primary weapon to rack it" ); return; }

    // Exclude capped wonder weapons: racking one could let a second player claim it and
    // slip past the per-match wonder claim cap (wonder_claims_watch registers any holder).
    if ( isdefined( acc_map_randomizer::wonder_cap_key( wpn ) ) )
        { player deny( "wonder weapons can't be racked" ); return; }

    player zm_weapons::weapon_take( wpn );
    entry = SpawnStruct();
    entry.wpn = wpn;
    // Display BEFORE any yield: spawn_rack_display derefs `player` (buildkit/PaP camo owner)
    // and the trigger context guarantees validity only until the next wait.
    entry.model = spawn_rack_display( player, wpn, level.acc_armory_rack.size );
    level.acc_armory_rack[ level.acc_armory_rack.size ] = entry;
    update_rack_hints();
    // NO gun name in the toast (UI pass 2026-07-10): wpn.name is the INTERNAL class name
    // ("ar_accurate", not "ICR-1") and IString(wpn.displayname) localization can't be
    // verified across the pack guns offline - the cabinet-top world model IS the identity.
    player ok( "weapon racked - a teammate can ^5TAKE^7 it at the other end" );
    acc_utility::log( "armory rack: deposit " + wpn.name + " (stored " + level.acc_armory_rack.size + ")" );
}

function withdraw_gun( player )
{
    if ( level.acc_armory_rack.size <= 0 ) { player deny( "the rack is empty" ); return; }

    // FREE-SLOT GATE (mandatory): weapon_give at the player's weapon limit silently
    // weapon_take's their held gun (_zm_weapons.gsc) - destroying a teammate's weapon.
    // Refuse instead. get_player_weapon_limit reads self, so call it ON the player.
    if ( player GetWeaponsListPrimaries().size >= player zm_utility::get_player_weapon_limit( player ) )
        { player deny( "no free weapon slot - buy Mule Kick or drop a gun" ); return; }

    wpn = level.acc_armory_rack[ 0 ].wpn;
    if ( player HasWeapon( wpn ) )
        { player deny( "you already carry the racked weapon" ); return; }

    // pop index 0 (FIFO), matching the Exchange item locker; its display model dies with it
    if ( isdefined( level.acc_armory_rack[ 0 ].model ) )
        level.acc_armory_rack[ 0 ].model Delete();
    rest = [];
    for ( i = 1; i < level.acc_armory_rack.size; i++ )
        rest[ rest.size ] = level.acc_armory_rack[ i ];
    level.acc_armory_rack = rest;

    // slide the surviving displays forward one slot (a short glide, not a teleport)
    for ( i = 0; i < level.acc_armory_rack.size; i++ )
        if ( isdefined( level.acc_armory_rack[ i ].model ) )
            level.acc_armory_rack[ i ].model MoveTo( rack_slot_origin( i ), 0.3 );

    update_rack_hints();

    // is_upgrade=false, magic_box=false, nosound=false, b_switch_weapon=false (no mid-fight
    // view-yank) - which means the gun lands SILENTLY in the loadout, so the toast MUST say
    // where it went or the take looks like a no-op (UI pass 2026-07-10).
    player zm_weapons::weapon_give( wpn, false, false, false, false );
    player ok( "took the racked weapon - it's in your loadout (switch to it)" );
    acc_utility::log( "armory rack: withdraw " + wpn.name + " (stored " + level.acc_armory_rack.size + ")" );
}

// True if `wpn` is a primary weapon the player currently owns (excludes pistol/melee/equipment).
function is_primary_owned( player, wpn )
{
    prims = player GetWeaponsListPrimaries();
    for ( i = 0; i < prims.size; i++ )
        if ( isdefined( prims[ i ] ) && prims[ i ] == wpn )
            return true;
    return false;
}

// ---------------------------------------------------------------------------
// Rack display (racked guns' world models laid out on the cabinet top)
// ---------------------------------------------------------------------------

// Slot `index` -> a world origin on the cabinet top. The cabinet mesh is 138 (X) x 18 x 48
// tall with its origin at the base (docs/09 bounds table), so the top face is +48; guns
// float +6 above it because worldModel origins vary per gun (a slight hover always reads
// better than a half-buried receiver). The row SELF-CENTERS for the configured capacity:
// shipped cap = 1 (ONE gun at a time, user 2026-07-10) puts the single gun dead-center;
// raising acc_armory_rack_max fans up to 8 per row at 17u pitch across the 138u length,
// wrapping +16 z per row, so a tuned-up cap can't run guns off the end.
function rack_slot_origin( index )
{
    per_row = getdvarint( "acc_armory_rack_max", 1 );
    if ( per_row < 1 ) per_row = 1;
    if ( per_row > 8 ) per_row = 8;
    row = int( index / per_row );
    col = index % per_row;
    return level.acc_armory_rack_base.origin + ( ( col - ( per_row - 1 ) * 0.5 ) * 17, 0, 54 + row * 16 );
}

// The magicbox display idiom (docs/39): a script_model wearing the weapon's WORLD model via
// UseBuildKitWeaponModel - same engine call as zm_utility::spawn_buildkit_weapon_model, but
// with the spawn guarded (ent-pool full returns undefined = no display, never a crash) since
// the stock helper derefs its own spawn unguarded. `player` = the depositor, so the model
// wears THEIR buildkit variant; upgraded guns get the PaP camo exactly like the box read.
// Guns lie across the cabinet (yaw 90 off its long X axis) like rifles on a bench rack;
// dual-wields show the right-hand model only (a per-slot pair would double the footprint).
function spawn_rack_display( player, wpn, index )
{
    if ( !isdefined( wpn.worldModel ) ) return undefined;   // nothing to show (pack oddities)

    mdl = spawn( "script_model", rack_slot_origin( index ) );
    if ( !isdefined( mdl ) ) return undefined;
    mdl.angles = ( 0, 90, 0 );

    upgraded = zm_weapons::is_weapon_upgraded( wpn );
    camo = undefined;
    if ( upgraded )
        camo = zm_weapons::get_pack_a_punch_camo_index( undefined );
    mdl UseBuildKitWeaponModel( player, wpn, camo, upgraded );
    return mdl;
}

// ---------------------------------------------------------------------------
// Mega-bottle exchange (1 bottle -> a random reward "item")
// ---------------------------------------------------------------------------

function spawn_bottle_station( origin )
{
    base = spawn( "script_model", origin );
    base setmodel( "p7_zm_vending_wonder" );   // Wonderfizz chassis - bottles-for-a-random-reward read

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 48, 90 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    // Name the ACTUAL prize ("a random Implant", not "a random reward") BEFORE the spend -
    // the old hint only revealed it in the post-purchase toast (UI pass 2026-07-10). Cost is
    // composed from the dvar once at spawn (it's a set-and-forget tuning knob, not live UI).
    cost = getdvarint( "acc_armory_bottle_cost", 1 );
    qty = ( cost == 1 ? "a Mega Bottle" : cost + " Mega Bottles" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^6EXCHANGE^7 " + qty + " for a random ^6Implant^7" );
    t thread bottle_loop();
}

function bottle_loop()   // self = the pad trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) )
            continue;

        cost = getdvarint( "acc_armory_bottle_cost", 1 );
        if ( acc_mega_bottles::get_bottle_count( player ) < cost )
            { player deny( "need " + cost + " Mega Bottle" + ( cost == 1 ? "" : "s" ) ); wait 0.4; continue; }
        if ( !acc_mega_bottles::try_consume_bottle( player, cost ) )
            { player deny( "need " + cost + " Mega Bottle" + ( cost == 1 ? "" : "s" ) ); wait 0.4; continue; }

        // No yield between the validity gate above and deliver_reward (try_consume_bottle does
        // not wait), so `player` is still valid here - safe to deref for the payout.
        deliver_reward( player );
        wait 0.4;
    }
}

// Weighted all-POSITIVE reward (you spend a scarce, valuable bottle - no curses). Weights
// sum to 100, so each weight == its % chance. The powerups are exactly the set this map
// already wires HUD icons for (.zone: maxammo/instakill/double/carpenter/firesale/nuke),
// so every drop is confirmed valid on this install.
// "A random item" = a random IMPLANT / boss item (user 2026-07-07: was powerups, "should be dropping
// implants instead"). Drops ONE random implant pickup at the player - free-for-all, floor-snapped, and it
// self-despawns after ACC_ITEM_DROP_LIFETIME_SEC (60s) via _acc_boss_items::watch_lifetime, exactly like a
// boss drop. The player grabs it (carry) + enables it at an Implant Bench (a dup they own -> shards at grab).
function deliver_reward( player )
{
    armory_msg( player, "^6ARMORY EXCHANGE: ^7a random Implant - grab it, then enable it at a bench" );
    acc_boss_items::grant_challenge_reward( player.origin );
    player PlaySound( "zmb_cha_ching" );
    acc_utility::log( "armory exchange: dropped a random implant at " + player.origin );
}

// ---------------------------------------------------------------------------
// Feedback + helpers
// ---------------------------------------------------------------------------

function armory_msg( player, text )
{
    if ( isdefined( player ) )
        player acc_utility::hud_msg( text );
}

function ok( text )    // self = player
{
    self acc_utility::hud_msg( "^2[ARMORY]^7 " + text );
    self PlaySound( "zmb_cha_ching" );
}

function deny( text )  // self = player
{
    self acc_utility::hud_msg( "^1[ARMORY]^7 " + text );
    self PlaySound( "zmb_no_purchase" );
}
