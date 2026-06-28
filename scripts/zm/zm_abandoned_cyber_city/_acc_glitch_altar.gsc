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
#using scripts\zm\zm_abandoned_cyber_city\_acc_ammo_crate;      // trench L2 ammo crate (spawned opposite the OC terminal)
#using scripts\zm\zm_abandoned_cyber_city\_acc_perks;
#using scripts\zm\zm_abandoned_cyber_city\_acc_exo;
#using scripts\zm\zm_abandoned_cyber_city\_acc_boss_items;
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_score;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;   // Paradise box: reuse the surface box pool/weights
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;       // Paradise PaP: standalone custom vendor (not a 2nd stock machine)

// Altar base model (a Cyber City interactive sign kiosk - corrupted-tech pedestal; stock t7_props, proven packable).
#precache( "model", "p7_cai_sign_inteactive_kiosk" );
#precache( "model", "p7_zm_der_magic_box" );   // Paradise Mystery Box mesh (stock; verified packed via the surface box, xmodel.csv)

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

    // --- SOURCE: Data Caches in the EXPOSED PIT - FLAT 3 shards each, once per round, first-come
    //     (user 2026-06-23: 1->2; user 2026-06-25: 2->3, faster faucet). Re-arm each round. Spread
    //     across the open pit floor, clear of the side stairs.
    acc_data_shards::spawn_cache_at( ( -360, 1950, -240 ), getdvarint( "acc_cache_w_count", 3 ) ); // pit west (user 2026-06-25: 2->3)
    acc_data_shards::spawn_cache_at( (  360, 1950, -240 ), getdvarint( "acc_cache_e_count", 3 ) ); // pit east (user 2026-06-25: 2->3)

    // --- DESCENT SINKS (user 2026-06-24): the two big shard sinks now REWARD descending the abyss - you
    //     must go DEEPER to spend. The Exo Suit (the thing that lets you walk deeper) stays up top in the
    //     Foundry (moved there - see _acc_exo.gsc), so the loop is: earn shards in the pit -> buy Exo up top
    //     -> descend -> Overclock + Ammo Crate on L2 -> gamble at the Altar on L3 -> (L4 = AK-47 wall-buy) ->
    //     Ammo Crate AGAIN at the bottom (L5) before the Paradise door. AMMO BOOKENDS the descent (user
    //     2026-06-27): top up on entry AND before the finale; L4's content is its wall-buy. On the solid floor
    //     (west slab x[-781,-112] guaranteed on EVERY layer; the L2 ammo crate sits on the proven-solid EAST
    //     opposite the OC) at the layer mid (y=1948) - clear of the center stairwells (wells are x[-112,112]).
    //       L2 (z=-480):  Cyberware Weapon Overclock (WEST) + Ammo Crate (EAST).
    //       L3 (z=-720):  Glitch Altar gamble.
    //       L4 (z=-960):  no GSC station - the AK-47 wall-buy lives here.
    //       L5 (z=-1200): Ammo Crate (WEST) + Cyberware Weapon Overclock (EAST, user 2026-06-28). z=-1200 is below the -1000 cull, but the abyss
    //                     shaft is inside the trench OOB box and Paradise stations sit at this z fine.
    //     NOTE: L2..L5 bake PITCH BLACK (gen_abyss_layer.js lightsForLayer=0). The Altar self-glows (its
    //     floating core orb) so it reads as a beacon in the dark; the OC kiosk + crates do NOT - if too hard
    //     to find in-game, add a bake-gated light near them (geometry change) rather than dimming the abyss.
    spawn_altar_at( ( -400, 1948, -720 ) );                          // Glitch Altar -> abyss L3 WEST
    acc_overclocks::spawn_terminal_at( ( -400, 1948, -480 ), 0 );    // Cyberware Weapon Overclock -> abyss L2 WEST
    acc_ammo_crate::spawn_crate_at( (  400, 1948,  -480 ), 0 );      // AMMO CRATE #1 -> abyss L2 EAST, opposite the OC (user 2026-06-27: entry refill)
    acc_ammo_crate::spawn_crate_at( ( -400, 1948, -1200 ), 0 );      // AMMO CRATE #2 -> abyss L5 WEST, the bottom before Paradise (user 2026-06-27)
    acc_overclocks::spawn_terminal_at( ( 400, 1948, -1200 ), 0 );    // Cyberware Weapon Overclock #2 -> abyss L5 EAST, opposite the L5 crate (user 2026-06-28). GSC spawn works immediately; collision clip QUEUED in add_prop_clips.js (overclock_l5) -> SOLID after the next .map + LED-bake pass (walk-through model until then).

    // --- MARQUEE SINK: Neural Expansion Bay - buy +1 perk slot with shards (base 4, up to 9). In the Foundry /
    //     Exo-Suit under-room (ORIGINAL size, user 2026-06-28 reverted a brief shrink): interior x[-192,192]
    //     y[1379,1723] z=-240. Sits on the EAST side at (120,1550); the Exo station is on the WEST (-120,1550), so
    //     the two sit on OPPOSITE sides the long way (user 2026-06-26 placement tweak). Its .map collision clip
    //     moves to match (tools/add_prop_clips.js perk_slot_vendor).
    acc_perks::spawn_perk_slot_vendor_at( ( 120, 1550, -240 ), 0 );

    // PARADISE (the open-air plaza hub below the abyss - gen_descent_hub.js) gets its own FULL set of the
    // script-spawned amenities (user 2026-06-25: "everything a player needs spread throughout"). Independent
    // DUPLICATES of the abyss/Foundry stations (each helper is duplicable - research 2026-06-24).
    spawn_paradise();
}

// Populate PARADISE with the GSC-spawned amenities. (Stock perks + a 2nd Pack-a-Punch live as .map entities,
// added separately via tools/gen_paradise_props.js.) Plaza interior x[-1000,1000] y[-2200,-600], floor z=-1200;
// entrance at north-center (y=-600). Spread the stations across the room. All sit deep in Paradise, reachable
// only after the soul-box descent + the communal Paradise gate, so they just wait there until you arrive.
function spawn_paradise()
{
    pz = -1200;   // Paradise floor top. Perk row is at y=-820 (north); 2nd PaP at (0,-1700). Spread the
                  // kiosks to the mid/south SIDES and put the bench (left) + box (right) along the south.

    spawn_altar_at( ( -850, -1350, pz ) );                           // Glitch Altar (west-mid)
    acc_overclocks::spawn_terminal_at( ( 850, -1350, pz ), 0 );      // Cyberware Weapon Overclock (east-mid)
    acc_exo::spawn_station_at( ( -850, -1950, pz ), 0 );             // Exo Suit station (west-south)
    acc_perks::spawn_perk_slot_vendor_at( ( 850, -1950, pz ), 0 );   // Neural Expansion Bay / perk slots (east-south)

    // Boss-item Implant Bench: 2 pads = the 2 implant slots, side by side along X, south-LEFT of center.
    sep = getdvarint( "acc_bench_pad_sep", 80 );
    acc_boss_items::spawn_bench_pad( ( -550 - sep, -2080, pz ), 0 );
    acc_boss_items::spawn_bench_pad( ( -550 + sep, -2080, pz ), 1 );

    spawn_paradise_box_at( ( 550, -2080, pz ) );   // permanent Mystery Box (south-right, balances the bench)

    // 2nd Pack-a-Punch (center-south, the design's intended PaP spot). STANDALONE custom vendor -
    // NOT a 2nd stock "zm_pack_a_punch" machine (that fatals stock's singleton GetEnt at load and was
    // what broke the surface PaP before). Reuses the SAME player-scoped tier path, so tier never resets.
    acc_pap_levels::spawn_paradise_pap_at( ( 0, -1700, pz ), 0 );

    acc_utility::log( "paradise: GSC amenities spawned (altar/overclock/exo/perk-slot/bench/box/pap)" );
}

// ---------------------------------------------------------------------------
// PARADISE MYSTERY BOX - a PERMANENT, STATIONARY, INDEPENDENT box (user 2026-06-25).
// NOT a stock _zm_magicbox chest: a pure GSC interactable (same idiom as spawn_altar_at). It NEVER
// touches _zm_magicbox / level.chests / chest nodes / start_chest_name, so the surface roaming box is
// untouched and the "malformed chest pair hides ALL boxes" gotcha is structurally impossible. Draws from
// the SAME box pool via acc_map_randomizer::acc_box_weighted_pick + the live is_in_box flags. Cost dvar
// acc_paradise_box_cost (default 950 = stock box).
// ---------------------------------------------------------------------------

function paradise_box_cost() { return getdvarint( "acc_paradise_box_cost", 950 ); }

function spawn_paradise_box_at( origin )
{
    box = spawn( "script_model", origin );
    box setmodel( "p7_zm_der_magic_box" );   // the iconic magic-box mesh (stock, packed - verified vs the surface box)

    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 72, 100 );
    t TriggerIgnoreTeam();          // REQUIRED for a script-spawned use trigger (stock _zm_perks.gsc:1523)
    t UseTriggerRequireLookAt();
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5PARADISE BOX^7 - random weapon  ^2[" + paradise_box_cost() + "]" );
    t.acc_box_model = box;
    t thread paradise_box_loop();

    acc_utility::log( "paradise_box: spawned at " + origin + " (cost " + paradise_box_cost() + ")" );
}

function paradise_box_loop()   // self = the box trigger
{
    self endon( "death" );
    level endon( "end_game" );

    for ( ;; )
    {
        self waittill( "trigger", player );
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) ) continue;
        if ( isdefined( self.acc_spinning ) && self.acc_spinning ) { wait 0.1; continue; }

        cost = paradise_box_cost();
        if ( !( player zm_score::can_player_purchase( cost ) ) )
        {
            player acc_utility::hud_msg( "^5PARADISE BOX^7 - needs " + cost + " points" );
            wait 0.4;
            continue;
        }

        wpn = paradise_box_pick_weapon( player );
        if ( !isdefined( wpn ) )
        {
            player acc_utility::hud_msg( "^5PARADISE BOX^7 - no weapon available" );
            wait 0.4;
            continue;
        }

        player zm_score::minus_to_player_score( cost );
        self.acc_spinning = true;
        wait 0.75;   // brief "spin" beat so the charge + give don't feel instant

        // DISCONNECT-WINDOW GUARD (user 2026-06-27 crash-hunt): this loop runs on the box TRIGGER, so its
        // self endon("death") does NOT fire when the buying PLAYER leaves. If that player disconnected during
        // the wait above, the player derefs below (weapon_give / PlaySound / player.name) would be method
        // calls on a freed entity -> whole-session co-op fatal. Re-validate across the yield (same fix as
        // _acc_overclocks::terminal_loop). Clear acc_spinning so the box isn't left stuck spinning.
        if ( !isdefined( player ) || !zm_utility::is_player_valid( player ) ) { self.acc_spinning = false; continue; }

        // GIVE like the box does. magic_box=false (3rd arg) so we do NOT fire the stock box VO /
        // "user_grabbed_weapon" notify that _acc_pap_levels + _acc_boss_items listen on.
        player zm_weapons::weapon_give( wpn, false, false );
        player PlaySound( "zmb_cha_ching" );

        acc_utility::log( "paradise_box: gave " + wpn.name + " to " + player.name );
        self.acc_spinning = false;
        wait 0.3;
    }
}

// Random weapon from OUR box pool (is_in_box, not a fixed-odds tactical, not already owned), via the
// surface box's weighted pick. Returns a weapon object or undefined (empty pool only).
function paradise_box_pick_weapon( player )
{
    if ( !isdefined( level.zombie_weapons ) ) return undefined;

    eligible = [];
    keys = getarraykeys( level.zombie_weapons );
    for ( i = 0; i < keys.size; i++ )
    {
        w = keys[ i ];
        if ( ( isdefined( level.zombie_weapons[ w ].is_in_box ) && level.zombie_weapons[ w ].is_in_box )
             && !acc_map_randomizer::is_box_tactical( w )
             && !acc_map_randomizer::player_owns_box_weapon( player, w ) )
            eligible[ eligible.size ] = w;
    }
    if ( eligible.size == 0 )   // owns every gun: fall back to the full box-flagged set (stock parity)
    {
        for ( i = 0; i < keys.size; i++ )
        {
            w = keys[ i ];
            if ( ( isdefined( level.zombie_weapons[ w ].is_in_box ) && level.zombie_weapons[ w ].is_in_box )
                 && !acc_map_randomizer::is_box_tactical( w ) )
                eligible[ eligible.size ] = w;
        }
    }
    if ( eligible.size == 0 ) return undefined;

    return acc_map_randomizer::acc_box_weighted_pick( eligible );
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

// Weighted: ~65% boon / ~35% curse (user 2026-06-24, "spice it up" - was 72/28; spicier both ways).
// Curses NEVER instant-down. The shard_jackpot only partially refunds (net shard EV is NEGATIVE per
// spin - the altar is a sink, the boons are the value), so it can't be farmed for shards.
function resolve_gamble( player )   // self = the altar trigger
{
    // Weights sum to 100, so each weight == its % chance. Riskier 65/35 split (user 2026-06-24): the
    // marquee Mega Win (top prize: free perk + insta-kill) doubled 1->2% for a juicier top end, and the
    // curse share grew 28->35 (mostly Surge - the most ACTION-y downside) so a spin bites more often.
    // Free Perk trimmed 12->8 and the 4% moved into Shard Jackpot (11->15) - the altar leans more into
    // refunding shards than handing out perks (user 2026-06-24).
    roll = acc_utility::acc_weighted_pick( array(
        // ---- BOONS (65) ----
        weighted( 15, "max_ammo" ),
        weighted( 13, "insta_kill" ),
        weighted( 12, "double_points" ),
        weighted(  8, "random_perk" ),
        weighted( 15, "shard_jackpot" ),
        weighted(  2, "mega_win" ),       // ~2% jackpot - the single big win (was 1%)
        // ---- CURSES (35) - never instant-down ----
        weighted( 16, "surge" ),
        weighted( 11, "shard_drain" ),
        weighted(  8, "dud" )
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
        n = getdvarint( "acc_altar_jackpot", 4 );   // 7 -> 3 -> 4 (+4 shards, user 2026-06-24; still net-negative EV vs the 15% odds at cost 2)
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
