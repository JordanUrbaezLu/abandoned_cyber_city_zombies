// =============================================================================
// _acc_glitch_altar.gsc - the Glitch Altar (Data Shard gamble)
//
// Design: the user chose "shard gambling" as what Data Shards DO (workflow
// underground-shards-design, 2026-06-18). The dangerous Bus Station trench is a
// CASINO: spend Data Shards at a glitch altar for a weighted jackpot - MOSTLY strong
// timed boons, a real slice of "glitch" CURSES (NEVER instant-down; odds telegraphed
// in the use hint). The descent is the house edge. Higher variance than the Emergency
// Drop (the guaranteed 3-shard clutch button), which it sits alongside.
//
// Pure GSC: the altar core + interact trigger are SCRIPT-SPAWNED (mirroring
// acc_data_shards::spawn_pickup_at) at a fixed origin inside the Plaza-facing trench
// room - no .map entity, no geometry, ships -GscOnly with ZERO LED-bake risk.
//
// Live dvars: acc_altar_cost (4), acc_altar_cooldown (6 s), acc_altar_jackpot (7),
//             acc_altar_surge (5), acc_altar_drain (6).
// =============================================================================

#using scripts\shared\flag_shared;
#using scripts\shared\util_shared;
#using scripts\shared\hud_util_shared;

#using scripts\zm\_zm_perks;
#using scripts\zm\_zm_powerups;
#using scripts\zm\_zm_utility;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_data_shards;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;
#using scripts\zm\zm_abandoned_cyber_city\_acc_cyberware;
#using scripts\zm\zm_abandoned_cyber_city\_acc_overclocks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;

// Altar base model (an interactive kiosk; stock t7 prop, xmodel-listed in the .zone).
#precache( "model", "p7_cai_sign_inteactive_kiosk" );

#namespace acc_glitch_altar;

// ---------------------------------------------------------------------------
// Init - spawn the altar once the level + shard system are up.
// ---------------------------------------------------------------------------

function init()
{
    acc_utility::log( "glitch_altar init" );
    level thread spawn_altars();
}

function spawn_altars()
{
    level endon( "end_game" );
    wait 1;   // after data_shards/cyberware/overclocks init (model + trees ready)

    // Underground shard economy, placed in the CURRENT built geometry (2026-06-19 rewrite via
    // tools/add_under_room.js): ONE enclosed "Foundry" room x[-192,192] y[1379,1723] floor z=-240,
    // entered from the open trench PIT through the buyable enter_under_plaza door (1500). The pit
    // floor (x[-781,819] y[1723,2173] z=-240) is the EXPOSED danger zone reached for free off the
    // stairs - amped horde, slow, surge.
    //
    // *** COORDS ARE PINNED TO add_under_room.js - if that room moves, update these. ***
    // The prior coords (Hall A 0,1085 / Chamber B 0,770 / kiosks +/-200,860) were stranded in
    // void/solid after Hall A + Chamber B were deleted today, so 4 of 5 interactables were
    // unreachable (see memory data-shard-trench-economy-audit). All 5 now sit on real floor.

    // --- SOURCE: Data Caches in the EXPOSED PIT - FLAT 1 shard each, once per round, first-come
    //     (user 2026-06-19: scaled-back economy where 1 shard matters). Re-arm each round. Spread
    //     across the open pit floor, clear of the side stairs.
    acc_data_shards::spawn_cache_at( ( -360, 1950, -240 ), getdvarint( "acc_cache_w_count", 1 ) ); // pit west
    acc_data_shards::spawn_cache_at( (  360, 1950, -240 ), getdvarint( "acc_cache_e_count", 1 ) ); // pit east

    // --- SINKS: the Foundry, inside the enclosed room. Cyberware tree REMOVED (user 2026-06-19) - the
    //     weapon Overclock terminal is now THE upgrade ("Cyberware Weapon Overclock"). Altar matches its
    //     docs/45 §3 anchor; the terminal moves to the §3 Stalls room when that geometry lands.
    spawn_altar_at( ( 90, 1500, -240 ) );                           // gamble, room (right side; clears the terminal)
    acc_overclocks::spawn_terminal_at( ( -120, 1450, -240 ), 0 );   // Cyberware Weapon Overclock, left (r64 fully inside the room; → Stalls -500,1500)

    // --- MARQUEE SINK: Neural Expansion Bay in the EXPOSED PIT (the most powerful upgrade demands the
    //     most danger). Buy +1 perk slot with shards (base 4, up to 9). Pit floor is guaranteed; placed
    //     WEST of center (x=-250) so it can't pinch the Foundry-door exit path (door x[-96,96] at y~1723)
    //     and clears the W cache (-360,1950)/riser/stairs. (Needs a docs/45 §3 anchor row - coordinate.)
    acc_perks::spawn_perk_slot_vendor_at( ( -250, 1820, -240 ), 0 );
}

function spawn_altar_at( origin )
{
    cost = altar_cost();

    // Kiosk BASE (the interactive machine you gamble at) + a glowing corrupted-data ORB
    // floating + spinning above it = the Glitch Altar. Both are verified-packing stock props.
    base = spawn( "script_model", origin );
    base setmodel( "p7_cai_sign_inteactive_kiosk" );

    core = spawn( "script_model", origin + ( 0, 0, 72 ) );
    core setmodel( level.acc_shards_pickup_model );   // glowing energy ball
    core thread spin_core();

    // Hold-USE trigger (radius/height args ARE the volume - no Radiant brush / zone line).
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 72, 100 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5GLITCH ALTAR^7 - gamble ^5" + cost + " Data Shards^7 (mostly boons, real glitch risk)" );
    t.acc_core = core;
    t thread altar_loop();

    acc_utility::log( "glitch_altar: spawned at " + origin + " (cost " + cost + ")" );
}

function spin_core()
{
    self endon( "death" );
    level endon( "end_game" );
    for ( ;; )
    {
        self rotateyaw( 160, 1.0 );
        wait 1.0;
    }
}

function altar_cost()     { return getdvarint( "acc_altar_cost", 2 ); }  // 4 -> 2 (scaled-back economy, user 2026-06-19)
function altar_cooldown() { return getdvarint( "acc_altar_cooldown", 6 ); }

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------

function altar_loop()    // self = the altar trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) ) continue;

        if ( isdefined( self.acc_cooldown ) && self.acc_cooldown )
        {
            altar_msg( player,"Glitch Altar: recharging..." );
            wait 0.4;
            continue;
        }

        cost = altar_cost();
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            altar_msg( player,"Glitch Altar: needs ^5" + cost + " Data Shards" );
            wait 0.4;
            continue;
        }

        self.acc_cooldown = true;
        self resolve_gamble( player );
        wait altar_cooldown();
        self.acc_cooldown = false;
    }
}

// Weighted: ~72% boon / ~28% curse. Curses NEVER instant-down. The shard_jackpot only
// partially refunds (net shard EV is NEGATIVE per spin - the altar is a sink, the boons
// are the value), so it can't be farmed for shards.
function resolve_gamble( player )   // self = the altar trigger
{
    // Weights sum to 100, so each weight == its % chance. Mega Win (the top prize: free perk +
    // insta-kill) is the rare ~1% jackpot (user 2026-06-19); the freed weight went to the common
    // boons so the boon/curse split stays ~72/28.
    roll = acc_utility::acc_weighted_pick( array(
        // ---- BOONS (72) ----
        weighted( 18, "max_ammo" ),
        weighted( 14, "insta_kill" ),
        weighted( 14, "double_points" ),
        weighted( 12, "random_perk" ),
        weighted( 13, "shard_jackpot" ),
        weighted(  1, "mega_win" ),       // ~1% jackpot - the single big win
        // ---- CURSES (28) - never instant-down ----
        weighted( 12, "surge" ),
        weighted( 10, "shard_drain" ),
        weighted(  6, "dud" )
    ) );

    deliver_outcome( player, roll );
}

function deliver_outcome( player, outcome )
{
    acc_utility::log( "glitch_altar roll: " + outcome );

    switch ( outcome )
    {
    // ---------- BOONS ----------
    case "max_ammo":
        altar_msg( player,"^2GLITCH ALTAR: ^7Max Ammo!" );
        level thread zm_powerups::specific_powerup_drop( "full_ammo", player.origin );
        break;
    case "insta_kill":
        altar_msg( player,"^2GLITCH ALTAR: ^7Insta-Kill!" );
        level thread zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
        break;
    case "double_points":
        altar_msg( player,"^2GLITCH ALTAR: ^7Double Points!" );
        level thread zm_powerups::specific_powerup_drop( "double_points", player.origin );
        break;
    case "random_perk":
        altar_msg( player,"^2GLITCH ALTAR: ^7Free Perk!" );
        player zm_perks::give_random_perk();
        break;
    case "shard_jackpot":
        n = getdvarint( "acc_altar_jackpot", 3 );   // 7 -> 3 (scaled-back economy; still net-negative EV at cost 2)
        acc_data_shards::grant_player( player, n, "altar_jackpot" );
        altar_msg( player,"^2GLITCH ALTAR: ^6JACKPOT ^7+" + n + " Data Shards!" );
        break;
    case "mega_win":
        altar_msg( player,"^2GLITCH ALTAR: ^6MEGA WIN ^7Free Perk + Insta-Kill!" );
        player zm_perks::give_random_perk();
        level thread zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
        break;

    // ---------- CURSES (never instant-down) ----------
    case "surge":
        altar_msg( player,"^1GLITCH ALTAR: ^7The grid spikes - a SURGE answers!" );
        level thread acc_bus_trench::spawn_corp_surge( getdvarint( "acc_altar_surge", 5 ) );
        break;
    case "shard_drain":
        drained = drain_shards( player, getdvarint( "acc_altar_drain", 2 ) );   // 6 -> 2 (scaled-back economy)
        altar_msg( player,"^1GLITCH ALTAR: ^7Corruption! -" + drained + " Data Shard" + ( drained == 1 ? "" : "s" ) );
        break;
    case "dud":
    default:
        altar_msg( player,"^1GLITCH ALTAR: ^7...nothing. The altar flickers and dies." );
        break;
    }
}

// Altar gambling feedback -> the SHARED upper-center positioned message (acc_utility::hud_msg),
// NOT iprintln (which the round counter / points cover). Tunable via acc_msg_y. See _acc_utility.
function altar_msg( player, text )
{
    if ( isdefined( player ) )
        player acc_utility::hud_msg( text );
}

// Lose up to `amount` shards (never below 0). Returns the amount actually drained.
function drain_shards( player, amount )
{
    have = acc_data_shards::get_count( player );
    take = ( amount < have ? amount : have );
    if ( take > 0 ) acc_data_shards::try_spend( player, take );
    return take;
}

function weighted( w, v )
{
    s = spawnstruct();
    s.weight = w;
    s.value = v;
    return s;
}
