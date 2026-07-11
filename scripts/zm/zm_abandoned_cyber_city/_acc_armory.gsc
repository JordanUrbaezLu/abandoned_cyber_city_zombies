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
//      is NAME-keyed / owner-agnostic (_acc_damage.gsc), so zero per-give work.
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
// Live dvars: acc_armory_rack_max (8 - shared rack capacity),
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
    // Shared team weapon rack: a FIFO list of weapon OBJECTS (persistent level.weapons
    // entries, so re-giving a stored one is always valid). Level-side = the only shared
    // store; a weapon is a per-player inventory item with no shared field, so the rack
    // has to be our own level var. A depositor's disconnect loses nothing - the deposit
    // transfers the gun to the level immediately (same ownership model as The Exchange).
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

    // DEPOSIT pad (west of the kiosk) + WITHDRAW pad (east). One trigger per action - BO3
    // use-triggers are single-button (the Exchange's multi-pad idiom). Pads are 110u apart,
    // radius 40, so they never overlap.
    spawn_rack_pad( "deposit",  origin + ( -55, 0, 0 ) );
    spawn_rack_pad( "withdraw", origin + (  55, 0, 0 ) );
}

function spawn_rack_pad( op, origin )
{
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 40, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable
    t SetCursorHint( "HINT_NOICON" );
    if ( op == "deposit" )
        t SetHintString( "Hold ^3[{+activate}]^7  ^2RACK^7 your held weapon for the team" );
    else
        t SetHintString( "Hold ^3[{+activate}]^7  ^5TAKE^7 a weapon from the team rack" );
    t.acc_op = op;
    t thread rack_loop();
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
    cap = getdvarint( "acc_armory_rack_max", 8 );
    if ( level.acc_armory_rack.size >= cap ) { player deny( "the team rack is full" ); return; }

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
    level.acc_armory_rack[ level.acc_armory_rack.size ] = wpn;
    // wpn.name is low-cardinality (~30 guns) + rack size is bounded (<=8) => cache-safe toast.
    player ok( "Racked ^3" + wpn.name + "^7  ->  rack: " + level.acc_armory_rack.size );
}

function withdraw_gun( player )
{
    if ( level.acc_armory_rack.size <= 0 ) { player deny( "the team rack is empty" ); return; }

    // FREE-SLOT GATE (mandatory): weapon_give at the player's weapon limit silently
    // weapon_take's their held gun (_zm_weapons.gsc) - destroying a teammate's weapon.
    // Refuse instead. get_player_weapon_limit reads self, so call it ON the player.
    if ( player GetWeaponsListPrimaries().size >= player zm_utility::get_player_weapon_limit( player ) )
        { player deny( "no free weapon slot - buy Mule Kick or drop a gun" ); return; }

    wpn = level.acc_armory_rack[ 0 ];
    if ( player HasWeapon( wpn ) )
        { player deny( "you already carry the next racked weapon" ); return; }

    // pop index 0 (FIFO), matching the Exchange item locker
    rest = [];
    for ( i = 1; i < level.acc_armory_rack.size; i++ )
        rest[ rest.size ] = level.acc_armory_rack[ i ];
    level.acc_armory_rack = rest;

    // is_upgrade=false, magic_box=false, nosound=false, b_switch_weapon=false (no mid-fight view-yank).
    player zm_weapons::weapon_give( wpn, false, false, false, false );
    player ok( "Took ^3" + wpn.name + "^7 from the rack  (rack: " + level.acc_armory_rack.size + ")" );
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
// Mega-bottle exchange (1 bottle -> a random reward "item")
// ---------------------------------------------------------------------------

function spawn_bottle_station( origin )
{
    base = spawn( "script_model", origin );
    base setmodel( "p7_zm_vending_wonder" );   // Wonderfizz chassis - bottles-for-a-random-reward read

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 48, 90 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^6EXCHANGE^7 a Mega Bottle for a random reward" );
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
