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
// Live dvars: acc_altar_cost (2), acc_altar_cooldown (6 s), acc_altar_jackpot (4),
//             acc_altar_surge (5), acc_altar_drain (2).
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
#using scripts\zm\zm_abandoned_cyber_city\_acc_armory;         // Paradise gets a 2nd (independent) weapon rack + bottle exchange (user 2026-07-13)
#using scripts\zm\_zm_weapons;
#using scripts\zm\_zm_score;
#using scripts\zm\zm_abandoned_cyber_city\_acc_map_randomizer;   // Paradise box: reuse the surface box pool/weights
#using scripts\zm\zm_abandoned_cyber_city\_acc_pap_levels;       // Paradise PaP: standalone custom vendor (not a 2nd stock machine)
#using scripts\zm\zm_abandoned_cyber_city\_acc_interact_glow;    // cyan "usable" holo on altar slab + Paradise box

// Altar base model (a Cyber City interactive sign kiosk - corrupted-tech pedestal; stock t7_props, proven packable).
// STATION REMODEL (user 2026-07-09, docs/09): Citadel stone altar (162x66x58, T7-dump carve)
// as the gamble-altar base - the ray-gun core orb (+72) now hovers ~14u above the slab top.
#precache( "model", "p7_ram_altar" );
#precache( "model", "p7_zm_der_magic_box" );   // Paradise Mystery Box mesh (stock; packs via the explicit zone xmodel line since the 2026-07-12 AW-box swap deleted the surface zbarriers it used to ride)

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
    acc_data_shards::spawn_cache_at( ( -360, 1950, -240 ), getdvarint( "acc_cache_w_count", 3 ), "trench" ); // pit west (user 2026-06-25: 2->3)
    acc_data_shards::spawn_cache_at( (  360, 1950, -240 ), getdvarint( "acc_cache_e_count", 3 ), "trench" ); // pit east (user 2026-06-25: 2->3)

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

    // Glitch Altar + in-arena Ammo Crate REMOVED from Paradise (user 2026-07-13). The finale is a
    // survive-the-onslaught fight, not a shop run - the gamble altar + the refill crate are gone
    // (their clips also pulled from add_prop_clips.js). Max ammo now arrives as a scripted powerup
    // at 1:45 on the battle countdown instead (_acc_paradise::paradise_drop_max_ammo).
    // spawn_altar_at( ( -850, -1350, pz ) );                        // Glitch Altar - REMOVED
    acc_overclocks::spawn_terminal_at( ( 850, -1350, pz ), 0 );      // Cyberware Weapon Overclock (east-mid)
    acc_exo::spawn_station_at( ( -850, -1950, pz ), 0 );             // Exo Suit station (west-south)
    acc_perks::spawn_perk_slot_vendor_at( ( 850, -1950, pz ), 0 );   // Neural Expansion Bay / perk slots (east-south)
    // acc_ammo_crate::spawn_crate_at( ( 850, -1650, pz ), 0 );      // AMMO CRATE #3 - REMOVED

    // ARMORY STATIONS IN PARADISE (user 2026-07-13): the two Armory-loft stations, on the west wall as a
    // pair. The rack is a SEPARATE, INDEPENDENT pool from the loft rack (spawn_rack_station is now
    // per-station, so it does NOT clobber the loft's) - the loft is unreachable once you descend anyway.
    acc_armory::spawn_rack_station( ( -850, -1350, pz ) );           // team weapon rack (west-mid, mirrors the Overclock at +850,-1350)
    acc_armory::spawn_bottle_station( ( -850, -1650, pz ) );         // mega-bottle -> random Implant exchange (west, between the rack and the Exo)

    // Boss-item Implant Bench: 3 pads = the 3 implant slots (2 -> 3, user 2026-07-09), side by side
    // along X at the same 160u spacing as the Plaza lab row, south-LEFT of center (row spans
    // x[-710,-390] - clear of the west wall at -1000 and the Mystery Box at +550).
    sep = getdvarint( "acc_bench_pad_sep", 80 );
    acc_boss_items::spawn_bench_pad( ( -550 - 2 * sep, -2080, pz ), 0 );
    acc_boss_items::spawn_bench_pad( ( -550,           -2080, pz ), 1 );
    acc_boss_items::spawn_bench_pad( ( -550 + 2 * sep, -2080, pz ), 2 );

    spawn_paradise_box_at( ( 550, -2080, pz ) );   // permanent Mystery Box (south-right, balances the bench)

    // 2nd Pack-a-Punch (center-south, the design's intended PaP spot). STANDALONE custom vendor -
    // NOT a 2nd stock "zm_pack_a_punch" machine (that fatals stock's singleton GetEnt at load and was
    // what broke the surface PaP before). Reuses the SAME player-scoped tier path, so tier never resets.
    acc_pap_levels::spawn_paradise_pap_at( ( 0, -1700, pz ), 0 );

    acc_utility::log( "paradise: GSC amenities spawned (overclock/exo/perk-slot/bench/box/pap/armory-rack/armory-bottle)" );
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
    box setmodel( "p7_zm_der_magic_box" );   // the iconic magic-box mesh (stock; packs via the explicit zone line - the surface box is the AW 3D Printer since 2026-07-12)
    // der_magic_box ships a _col LOD (self-collides) but the navmesh cannot see entity collision, so zombies
    // path through its footprint and grind on it. Stock pattern: DisconnectPaths() the collision entity at
    // spawn (_zm_perks.gsc:1551-1555). Box is PERMANENT + STATIONARY, so a one-shot cut is safe (a moved
    // entity would leave the cut behind - never move this without ConnectPaths() first). docs/16 navmesh entry.
    box disconnectpaths();
    acc_interact_glow::glow_on( box );

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
        acc_interact_glow::glow_off( self.acc_box_model );   // points actually spent = successful use

        // [acc] VISIBLE SPIN (user 2026-07-06: "it just takes your points without spinning through
        // guns"): the old 0.75s bare wait gave zero feedback. Recreate the stock box read - a floating
        // weapon model FLICKING through the pool while it rises, decelerating, then settling on the
        // final gun - with a plain script_model, keeping this box's ZERO _zm_magicbox/zbarrier coupling.
        // The real pick (wpn) already happened above; the flicker is display-only.
        dsp = spawn( "script_model", self.acc_box_model.origin + ( 0, 0, 26 ) );
        if ( isdefined( dsp ) )
        {
            dsp.angles = self.acc_box_model.angles + ( 0, 90, 0 );
            dsp MoveZ( 38, 2.4 );          // slow rise out of the box lid
            dsp RotateYaw( 540, 2.4 );     // 1.5 turns for the "reading the datastream" flair
        }
        pool = paradise_box_display_models( wpn );
        start = ( pool.size > 0 ? RandomInt( pool.size ) : 0 );
        for ( i = 0; i < 13; i++ )
        {
            if ( isdefined( dsp ) && pool.size > 0 )
                dsp SetModel( pool[ ( start + i ) % pool.size ] );
            // stock-like decelerating cadence: 7 fast flicks then progressively slower to the settle
            wait ( i < 7 ? 0.1 : 0.1 + ( i - 6 ) * 0.05 );
        }
        if ( isdefined( dsp ) )
        {
            // [acc] 2026-07-16: display via the shared resolver - the raw worldModel is a bare
            // mag-less receiver on the CW/VG guns (see acc_map_randomizer::box_display_model).
            mdl_settle = acc_map_randomizer::box_display_model( wpn );
            if ( isdefined( mdl_settle ) )
                dsp SetModel( mdl_settle );   // the settled "this is your gun" beat
            wait 0.7;
            dsp Delete();
        }

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

// World models for the spin display: up to 8 box guns' worldModels, final gun EXCLUDED so the flicker
// never "lands early" on the real result. Display-only (the weighted pick already happened); an empty
// return just means the flicker frames keep the last model - harmless.
function paradise_box_display_models( wpn_final )
{
    models = [];
    if ( !isdefined( level.zombie_weapons ) ) return models;
    keys = getarraykeys( level.zombie_weapons );
    for ( i = 0; i < keys.size && models.size < 8; i++ )
    {
        w = keys[ i ];
        if ( !isdefined( level.zombie_weapons[ w ].is_in_box ) || !level.zombie_weapons[ w ].is_in_box ) continue;
        if ( acc_map_randomizer::is_box_tactical( w ) ) continue;
        if ( isdefined( wpn_final ) && w == wpn_final ) continue;
        // [acc] 2026-07-16: shared resolver - complete _full mesh where the raw worldModel is a
        // bare mag-less receiver (CW/VG ports); falls through to worldModel for everything else.
        mdl = acc_map_randomizer::box_display_model( w );
        if ( !isdefined( mdl ) ) continue;
        models[ models.size ] = mdl;
    }
    return models;
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
             && !acc_map_randomizer::player_owns_box_weapon( player, w )
             && acc_map_randomizer::player_may_receive_wonder( player, w ) )   // per-match wonder claim caps (TG 1 / BoM 2)
            eligible[ eligible.size ] = w;
    }
    if ( eligible.size == 0 )   // owns every gun: fall back to the full box-flagged set (stock parity)
    {
        for ( i = 0; i < keys.size; i++ )
        {
            w = keys[ i ];
            if ( ( isdefined( level.zombie_weapons[ w ].is_in_box ) && level.zombie_weapons[ w ].is_in_box )
                 && !acc_map_randomizer::is_box_tactical( w )
                 && acc_map_randomizer::player_may_receive_wonder( player, w ) )   // caps hold in the fallback too
                eligible[ eligible.size ] = w;
        }
    }
    if ( eligible.size == 0 ) return undefined;

    return acc_map_randomizer::acc_box_weighted_pick( eligible );
}

function spawn_altar_at( origin )
{
    cost = altar_cost();

    // Stone-altar BASE (the machine you gamble at) + a glowing corrupted-data ORB floating +
    // spinning above it = the Glitch Altar. Altar slab is 58 tall, so the +72 orb hovers just
    // above it (STATION REMODEL 2026-07-09 - was the shared sign kiosk).
    base = spawn( "script_model", origin );
    base setmodel( "p7_ram_altar" );
    acc_interact_glow::glow_on( base );

    core = spawn( "script_model", origin + ( 0, 0, 72 ) );
    core setmodel( level.acc_shards_pickup_model );   // glowing energy ball
    core thread spin_core();

    // Hold-USE trigger (radius/height args ARE the volume - no Radiant brush / zone line).
    // RADIUS = 110, NOT 72 (user 2026-07-12 "trigger only appears on one side"): the STATION REMODEL
    // (2026-07-09) swapped the small shared kiosk for the 162x66 p7_ram_altar slab, but the trigger
    // radius stayed 72 - the leftover from the kiosk. The slab's long (X) axis half-extent is 81
    // (matches the hx:81 collision clip in add_prop_clips.js), so a radius-72 cylinder can't reach the
    // two X-ends without standing INSIDE the solid slab -> the hint only showed from a long Y-face
    // (one accessible side). 110 clears the 81 half-slab + the player's ~15u stand-off from every face.
    t = spawn( "trigger_radius_use", origin + ( 0, 0, 40 ), 0, 110, 100 );
    t TriggerIgnoreTeam();   // REQUIRED for a script-spawned use-trigger to be player-usable (stock _zm_perks.gsc:1523).
    t SetCursorHint( "HINT_NOICON" );
    t SetHintString( "Hold ^3[{+activate}]^7  ^5GLITCH ALTAR^7 - gamble ^5" + cost + " Data Shards^7 (mostly boons, real glitch risk)" );
    t.acc_core = core;
    t.acc_base_model = base;   // glow_off target on first successful gamble (user 2026-07-17)
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
        acc_interact_glow::glow_off( self.acc_base_model );   // shards actually spent = successful use
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
        // Kortifex "Random perk!" line (nil-guarded - see _acc_emergency_drop).
        if ( isdefined( level.acc_kx_announce_random_perk ) )
            [[ level.acc_kx_announce_random_perk ]]();
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
