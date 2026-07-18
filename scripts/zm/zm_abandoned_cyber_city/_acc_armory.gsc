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
//             acc_armory_bottle_cost (1 - Empty Mega Bottles per exchange for a random implant),
//             acc_armory_rack_hover (6 - u the racked gun floats above the cabinet top face),
//             acc_armory_rack_yaw / _pitch / _roll (display gun angle; yaw default is cap-aware:
//               0 = laid ALONG the 138u cabinet length for a single gun, 90 = side-by-side row).
// =============================================================================

#using scripts\zm\_zm_utility;
#using scripts\zm\_zm_weapons;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_mega_bottles;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;       // grant_challenge_reward (bottle -> random implant)
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;   // wonder_cap_key (rack exclusion)
#using scripts\zm\zm_abandoned_cyber_city\_acc_weapon_variants;  // true_base - the PaP-tier ledger key (rack_tier_of)
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;    // cyan "usable" holo on cabinet + bottle exchange

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
    // Shared team weapon rack: a FIFO list of STRUCT entries { wpn, model, tier }. wpn = the
    // weapon OBJECT (persistent level.weapons entry, so re-giving a stored one is always
    // valid); model = its world-model display on the cabinet top (undefined only if the
    // ent-pool spawn failed - the rack still works, just undisplayed); tier = the PaP tier the
    // gun was racked at, which has to travel WITH the gun because it lives in a per-player
    // ledger the depositor loses the instant they hand the gun over (see rack_tier_of). One array keyed by
    // slot = wpn+model can never desync, and duplicate weapon objects (two players rack
    // the same gun class -> the SAME level.weapons singleton twice) stay distinct entries.
    // Level-side = the only shared store; a weapon is a per-player inventory item with no
    // shared field, so the rack has to be our own level var. A depositor's disconnect
    // loses nothing - the deposit transfers the gun to the level immediately (same
    // ownership model as The Exchange).
    // PER-STATION 2026-07-13: each rack station now owns its own pool in station.pool (see
    // spawn_rack_station) so a 2nd INDEPENDENT rack in Paradise never clobbers the loft's - no
    // level-global pool anymore.

    acc_utility::log( "armory init" );
    level thread spawn_stations();
}

function spawn_stations()
{
    level endon( "end_game" );
    wait 1;   // after mega_bottles + data_shards init (their accessors + pools ready)

    // The Armory loft floor is z=192, footprint x[682,1074] y[-230,230] (tools/gen_upper_room.js;
    // 2026-07-11 resize: +25% floor area, floor lowered 288->192 for the shallower 12/28 stairs).
    // Reached via the buyable EAST-wall door + the enclosed east-climbing staircase. Stations sit
    // at the room center, clear of the WEST-wall stair doorway (x=682 @ y[-64,64]).
    spawn_rack_station( ( 878, -100, 192 ) );   // team weapon rack (deposit + withdraw pads)
    spawn_bottle_station( ( 878, 100, 192 ) );  // mega-bottle exchange

    acc_utility::log( "armory: stations spawned (weapon rack + bottle exchange) [loft z=192]" );
}

// ---------------------------------------------------------------------------
// Team weapon rack (pooled deposit / withdraw - the _acc_transfer idiom)
// ---------------------------------------------------------------------------

// A rack STATION is self-contained (user 2026-07-13: a 2nd INDEPENDENT rack lives in Paradise).
// Its gun pool (station.pool), display cabinet (station.base) and pad triggers (station.pads) all
// hang off a struct, NOT level globals, so N racks never clobber one another. Each pad back-refs
// its station (t.acc_rack) and rack_loop routes deposits/withdraws to that pool. Returns the station.
function spawn_rack_station( origin )
{
    station = SpawnStruct();
    station.base = spawn( "script_model", origin );
    station.base setmodel( "p7_con_cargo_train_armory_cabinet" );   // long weapons cabinet - pads sit at its two ends
    acc_interact_glow::glow_on( station.base );
    station.pool = [];    // FIFO { wpn, model } entries (was level.acc_armory_rack)
    station.pads = [];    // { deposit, withdraw } triggers (was level.acc_armory_rack_pads)

    // DEPOSIT pad (west of the kiosk) + WITHDRAW pad (east). One trigger per action - BO3
    // use-triggers are single-button (the Exchange's multi-pad idiom). Pads are 110u apart,
    // radius 40, so they never overlap.
    spawn_rack_pad( station, "deposit",  origin + ( -55, 0, 0 ) );
    spawn_rack_pad( station, "withdraw", origin + (  55, 0, 0 ) );
    update_rack_hints( station );   // initial (empty-rack) hints
    return station;
}

function spawn_rack_pad( station, op, origin )
{
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 40, 90 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable
    t SetCursorHint( "HINT_NOICON" );
    t.acc_op = op;
    t.acc_rack = station;    // back-ref: rack_loop uses this to find the pool
    station.pads[ op ] = t;   // hint text lives in update_rack_hints (state-aware)
    t thread rack_loop();
}

// STATE-AWARE PAD HINTS (user 2026-07-10 UI pass): the hint itself tells you the rack state
// BEFORE you press - the old static hints invited a press that could only refuse ("TAKE a
// weapon" on an empty rack / "RACK your held weapon" on an occupied one). Call after every
// rack mutation. 4-6 CONSTANT strings total => configstring-cache safe. A player already
// aiming at a pad picks the new text up on the next hint refresh (worst case: re-aim).
function update_rack_hints( station )
{
    if ( !isdefined( station ) || !isdefined( station.pads ) ) return;
    stored = station.pool.size;
    cap = getdvarint( "acc_armory_rack_max", 1 );

    pad = station.pads[ "deposit" ];
    if ( isdefined( pad ) )
    {
        if ( stored >= cap )
            pad SetHintString( ( cap == 1 ? "Rack ^3OCCUPIED^7 - a teammate can ^5TAKE^7 the weapon at the other end" : "The team rack is ^3FULL^7 - ^5TAKE^7 a weapon at the other end" ) );
        else
            pad SetHintString( "Hold ^3[{+activate}]^7  ^2RACK^7 your held weapon for a teammate" );
    }

    pad = station.pads[ "withdraw" ];
    if ( isdefined( pad ) )
    {
        if ( stored <= 0 )
            pad SetHintString( "Rack ^3EMPTY^7 - ^2RACK^7 a weapon at the other end to share it" );
        else
            pad SetHintString( ( stored == 1 ? "Hold ^3[{+activate}]^7  ^5TAKE^7 the racked weapon ^7(swaps your held gun if full)" : "Hold ^3[{+activate}]^7  ^5TAKE^7 the next racked weapon" ) );
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

        station = self.acc_rack;
        if ( self.acc_op == "deposit" ) deposit_gun( station, player );
        else                            withdraw_gun( station, player );

        wait 0.4;   // per-press debounce (one hold must not double-fire)
    }
}

function deposit_gun( station, player )
{
    cap = getdvarint( "acc_armory_rack_max", 1 );   // ONE gun at a time (user 2026-07-10)
    if ( station.pool.size >= cap )
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

    // WONDER WEAPONS ARE NOW RACKABLE (user 2026-07-13): the old wonder_cap_key exclusion was
    // removed - sharing a wonder via the rack IS the intent (a teammate taking it past the box
    // claim cap is the desired co-op sharing, not an exploit; the box cap still gates BOX rolls).

    // Snapshot the PaP tier BEFORE the take - it rides the entry and is stamped back on withdraw
    // (rack_tier_of: the tier is a per-player ledger entry that prune_lost_tiers zeroes the moment
    // the player stops carrying the base, so without this the rack silently un-packs the gun).
    tier = rack_tier_of( player, wpn );

    player zm_weapons::weapon_take( wpn );
    entry = SpawnStruct();
    entry.wpn = wpn;
    entry.tier = tier;
    // Display BEFORE any yield: spawn_rack_display derefs `player` (buildkit/PaP camo owner)
    // and the trigger context guarantees validity only until the next wait.
    entry.model = spawn_rack_display( station, player, wpn, station.pool.size );
    station.pool[ station.pool.size ] = entry;
    update_rack_hints( station );
    acc_interact_glow::glow_off( station.base );   // first successful deposit ends the discovery flash
    // NO gun name in the toast (UI pass 2026-07-10): wpn.name is the INTERNAL class name
    // ("ar_accurate", not "ICR-1") and IString(wpn.displayname) localization can't be
    // verified across the pack guns offline - the cabinet-top world model IS the identity.
    player ok( "weapon racked - a teammate can ^5TAKE^7 it at the other end" );
    acc_utility::log( "armory rack: deposit " + wpn.name + " (stored " + station.pool.size + ")" );
}

function withdraw_gun( station, player )
{
    if ( station.pool.size <= 0 ) { player deny( "the rack is empty" ); return; }

    wpn = station.pool[ 0 ].wpn;
    // OBJECT-IDENTITY BY DESIGN - do NOT "upgrade" this to a true_base comparison (considered and
    // REJECTED, 2026-07-15 audit). An audit flagged the raw HasWeapon as twin-unaware: it is FALSE for a
    // player holding a plain t9_ak47 when the rack holds t9_ak47_acc_fastreload (a Mega-perk twin) or
    // t9_ak47_up (a PaP form), so the same gun CLASS can be withdrawn twice. That is TRUE - and it is the
    // INTENDED behaviour, because the rack exists to SHARE a gun, tier and all:
    //   - docs/39_armory.md:50 "The PaP tier travels WITH the racked gun (fixed 2026-07-15)" - racking a
    //     TIERED gun so a teammate can take it is a headline feature, not an accident.
    //   - docs/39_armory.md:84 "duplicate weapon objects - two players racking the same gun class - stay
    //     distinct entries" - same-class duplicates are explicitly designed for.
    // Swapping in acc_map_randomizer::player_owns_box_weapon (true_base) would DENY the central co-op
    // flow: teammate racks their PaP'd/tiered AK, you carry the base AK, bases match -> refused. The
    // guard's real job is only to stop a no-op take of the EXACT weapon you already hold, which is
    // exactly what HasWeapon does. Leave it.
    if ( player HasWeapon( wpn ) )
        { player deny( "you already carry the racked weapon" ); return; }
    take_tier = ( isdefined( station.pool[ 0 ].tier ) ? station.pool[ 0 ].tier : 0 );   // stamped on after the give

    // SWAP WHEN FULL (user 2026-07-13: "swap the gun in your hand for the gun on the rack").
    // weapon_give at the weapon limit silently weapon_take's the held gun (_zm_weapons.gsc),
    // destroying it - the old code refused instead. Now: if the player is FULL, do a real SWAP -
    // take their HELD PRIMARY and put it ON the rack in place of the gun they're taking. With a
    // free slot, the old behavior stands (just take, keep all your guns).
    swap_held = undefined;
    swap_tier = 0;
    if ( player GetWeaponsListPrimaries().size >= player zm_utility::get_player_weapon_limit( player ) )
    {
        held = player GetCurrentWeapon();
        if ( !isdefined( held ) || held == level.weaponNone || held == wpn
             || zm_utility::is_melee_weapon( held ) || zm_utility::is_placeable_mine( held )
             || !is_primary_owned( player, held ) )
            { player deny( "slots full - hold the primary you want to swap out, then TAKE" ); return; }
        swap_held = held;
        swap_tier = rack_tier_of( player, held );   // snapshot BEFORE the take (same reason as deposit_gun)
        player zm_weapons::weapon_take( held );   // frees the slot for the give below
    }

    // pop index 0 (FIFO), matching the Exchange item locker; its display model dies with it
    if ( isdefined( station.pool[ 0 ].model ) )
        station.pool[ 0 ].model Delete();
    rest = [];
    for ( i = 1; i < station.pool.size; i++ )
        rest[ rest.size ] = station.pool[ i ];
    station.pool = rest;
    acc_interact_glow::glow_off( station.base );   // first successful withdraw counts too

    // is_upgrade=false, magic_box=false, nosound=false, b_switch_weapon=false (no mid-fight
    // view-yank) - the gun lands SILENTLY in the loadout, so the toast MUST say where it went.
    player zm_weapons::weapon_give( wpn, false, false, false, false );
    // The tier rode the rack entry - stamp it on the taker now the gun is in their primaries list
    // (AFTER the give: the prune only spares a base the player already carries). In co-op the taker
    // inherits the tier the depositor racked the gun at, which IS the intended share.
    rack_restore_tier( player, wpn, take_tier );

    // SWAP: the taken-off gun goes ONTO the rack in place of the one taken. Slide the SURVIVING
    // displays forward one slot FIRST (same glide as the non-swap path below), THEN append the
    // swapped-out gun at the end. Without the slide, a raised acc_armory_rack_max (pool holds >1)
    // leaves the survivors parked at their old slot origins, so the swapped-in gun is placed on top
    // of a survivor and slot 0 is left empty (review 2026-07-15). Harmless at the shipped default
    // rack_max=1 (the pool empties to size 0 before the append), but correct for any raised cap.
    if ( isdefined( swap_held ) )
    {
        for ( i = 0; i < station.pool.size; i++ )
            if ( isdefined( station.pool[ i ].model ) )
                station.pool[ i ].model MoveTo( rack_slot_origin( station, i ), 0.3 );

        entry = SpawnStruct();
        entry.wpn = swap_held;
        entry.tier = swap_tier;
        entry.model = spawn_rack_display( station, player, swap_held, station.pool.size );
        station.pool[ station.pool.size ] = entry;
        update_rack_hints( station );
        player ok( "swapped - the racked weapon is yours; your held gun is now on the rack" );
        acc_utility::log( "armory rack: SWAP give " + wpn.name + " / rack " + swap_held.name );
        return;
    }

    // slide the surviving displays forward one slot (a short glide, not a teleport)
    for ( i = 0; i < station.pool.size; i++ )
        if ( isdefined( station.pool[ i ].model ) )
            station.pool[ i ].model MoveTo( rack_slot_origin( station, i ), 0.3 );

    update_rack_hints( station );
    player ok( "took the racked weapon - it's in your loadout (switch to it)" );
    acc_utility::log( "armory rack: withdraw " + wpn.name + " (stored " + station.pool.size + ")" );
}

// ---------------------------------------------------------------------------
// PaP tier rides the rack entry (fix 2026-07-15)
// ---------------------------------------------------------------------------

// A PaP tier is NOT a property of the weapon object - it's a per-player ledger entry
// (player.acc_pap_tier[ true_base ], _acc_pap_levels). A deposit weapon_take's the gun, so
// prune_lost_tiers (a 0.25s poll that zeroes the tier of any base the player no longer carries
// ANY form of) wiped it while the gun sat on the rack: rack a tier-3 gun, take it back at tier 0
// (or 2 for an "_up" form, via get_tier's is_weapon_upgraded clamp) and the PaP re-charges you
// the packs you already paid for.
// NOT fixed by exempting the rack from the prune: the prune is RIGHT - the instant a gun is
// racked it belongs to the LEVEL, not the depositor (the Exchange ownership model, see init()).
// A "parked, still owned" exemption would leave the depositor a phantom tier to cash in on a
// fresh wallbuy of the same base, AND still hand a teammate who takes the gun a tier-0 copy.
// So the TIER RIDES THE ENTRY: snapshot at deposit, stamp back on withdraw. That also makes the
// co-op share coherent - the taker inherits the tier the gun was racked at.
// RAW-FIELD access (no _acc_pap_levels #using) is the established idiom for reaching this ledger
// from outside - see _acc_weapon_variants::axis_lev_speed and _zm_weap_freezegun's tier read.
// Deliberately the RAW ledger and NOT acc_pap_levels::get_tier: get_tier's Fire Bow / Action
// Figure branches read their own separate counters, which the prune never touches (so they need
// no rescue here and must not be written through this key), and its is_weapon_upgraded clamp
// rides the weapon OBJECT, so it re-applies for free on withdraw.
function rack_tier_of( player, wpn )
{
    if ( !isdefined( player.acc_pap_tier ) ) return 0;
    base = acc_weapon_variants::true_base( wpn );   // twin-aware: the key survives recoil/fast twin swaps
    if ( !isdefined( base ) || base == level.weaponNone || !isdefined( player.acc_pap_tier[ base ] ) ) return 0;
    return player.acc_pap_tier[ base ];
}

// Stamp a racked gun's tier onto whoever took it. MUST run AFTER the weapon_give - the prune only
// spares a base the player already carries. Safe against the poll because weapon_give/weapon_take
// are synchronous (no yield - VERIFIED in stock _zm_weapons.gsc), so give-then-stamp is atomic.
function rack_restore_tier( player, wpn, tier )
{
    if ( !isdefined( tier ) || tier <= 0 ) return;   // tier 0 = nothing to restore (prune already agrees)
    base = acc_weapon_variants::true_base( wpn );
    if ( !isdefined( base ) || base == level.weaponNone ) return;
    if ( !isdefined( player.acc_pap_tier ) ) player.acc_pap_tier = [];
    player.acc_pap_tier[ base ] = tier;
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
// tall with its origin at the base (bounds VERIFIED via xmodel_bin_inspect 2026-07-11), so the top
// face is +48; guns float acc_armory_rack_hover (default 6) above it because worldModel origins vary
// per gun (a slight hover always reads better than a half-buried receiver). The row SELF-CENTERS:
// shipped cap = 1 (ONE gun at a time, user 2026-07-10) puts the single gun dead-center;
// raising acc_armory_rack_max fans up to 8 per row at 17u pitch across the 138u length,
// wrapping +16 z per row, so a tuned-up cap can't run guns off the end.
function rack_slot_origin( station, index )
{
    per_row = getdvarint( "acc_armory_rack_max", 1 );
    if ( per_row < 1 ) per_row = 1;
    if ( per_row > 8 ) per_row = 8;
    row = int( index / per_row );
    col = index % per_row;
    // Cabinet TOP face = z+48 (model bounds: origin at base, size 137.8 x 18.1 x 48.1 - VERIFIED
    // via tools/xmodel_bin_inspect 2026-07-11). Gun hovers acc_armory_rack_hover (default 6) above
    // the top face (worldModel origins vary per gun; a slight float beats a half-buried receiver).
    hover = getdvarint( "acc_armory_rack_hover", 6 );
    return station.base.origin + ( ( col - ( per_row - 1 ) * 0.5 ) * 17, 0, 48 + hover + row * 16 );
}

// The magicbox display idiom (docs/39): a script_model wearing the weapon's WORLD model via
// UseBuildKitWeaponModel - same engine call as zm_utility::spawn_buildkit_weapon_model, but
// with the spawn guarded (ent-pool full returns undefined = no display, never a crash) since
// the stock helper derefs its own spawn unguarded. `player` = the depositor, so the model
// wears THEIR buildkit variant; upgraded guns get the PaP camo exactly like the box read.
// A single gun lies ALONG the cabinet's long X axis (yaw 0) so it rests lengthwise like a rifle on
// a rack (the 18u-deep cabinet can't hold a gun laid across it - it would jut out both faces); a
// raised cap fans guns into a side-by-side row (yaw 90). angle+hover are live-tunable (see header).
// dual-wields show the right-hand model only (a per-slot pair would double the footprint).
function spawn_rack_display( station, player, wpn, index )
{
    if ( !isdefined( wpn.worldModel ) ) return undefined;   // nothing to show (pack oddities)

    mdl = spawn( "script_model", rack_slot_origin( station, index ) );
    if ( !isdefined( mdl ) ) return undefined;
    // ORIENTATION (fixed 2026-07-11 - "gun sticks through the holder"): the cabinet is only 18u DEEP
    // (Y) but 138u LONG (X) (xmodel_bin bounds). The old fixed yaw 90 laid the gun ACROSS the depth,
    // so a ~50u rifle jutted ~15u out of BOTH narrow faces. Lay it ALONG the long X axis (yaw 0) so a
    // single centered gun rests lengthwise on the cabinet like a rifle on a rack. A raised
    // acc_armory_rack_max (multi-gun row) still reads best side-by-side, so the default yaw is
    // cap-aware; pitch/yaw/roll are all live-tunable dvars so the exact lie can be dialed in-game.
    cap = getdvarint( "acc_armory_rack_max", 1 );
    def_yaw = ( cap <= 1 ? 0 : 90 );
    mdl.angles = ( getdvarint( "acc_armory_rack_pitch", 0 ), getdvarint( "acc_armory_rack_yaw", def_yaw ), getdvarint( "acc_armory_rack_roll", 0 ) );

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
    acc_interact_glow::glow_on( base );

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 48, 90 );
    t TriggerIgnoreTeam();
    t SetCursorHint( "HINT_NOICON" );
    // Name the ACTUAL prize ("a random Implant", not "a random reward") BEFORE the spend -
    // the old hint only revealed it in the post-purchase toast (UI pass 2026-07-10). Cost is
    // composed from the dvar once at spawn (it's a set-and-forget tuning knob, not live UI).
    cost = getdvarint( "acc_armory_bottle_cost", 1 );
    qty = ( cost == 1 ? "a Mega Bottle" : cost + " Mega Bottles" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^6EXCHANGE^7 " + qty + " for a random ^6Implant^7" );
    t.acc_bottle_base = base;   // glow_off target on first successful exchange
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
        acc_interact_glow::glow_off( self.acc_bottle_base );   // bottle actually consumed = successful use
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
