// =============================================================================
// _acc_glitch_altar.gsc - the Glitch Altar (Data Shard gamble)
//
// Design: the user chose "shard gambling" as what Data Shards DO (workflow
// underground-shards-design, 2026-06-18). The dangerous Bus Station trench is a
// CASINO: spend Data Shards at a glitch altar for a weighted roll. HUGE NERF
// (user 2026-08-02 "I get too many good things like drops... needs smaller rewards...
// double the price... overall needs to be a gamble"): 55% curses / 36% SMALL wins /
// 7% powerup-or-perk / 2% MEGA jackpot (was 50% powerup-class!), price DOUBLED (4)
// and ESCALATING +2 per spin within a round, cooldown doubled (12s), and a hard
// ONE-POWERUP-CLASS-HIT-PER-ROUND cap (extra rolls reroute to a +1 trickle) so
// insta-kill chaining is impossible regardless of bankroll. Curses NEVER instant-down;
// price telegraphed in the LIVE use hint. The descent is the house edge. Higher
// variance than the Emergency Drop (the guaranteed clutch button), which it sits alongside.
//
// Pure GSC: the altar core + interact trigger are SCRIPT-SPAWNED (mirroring
// acc_data_shards::spawn_pickup_at) at a fixed origin inside the Plaza-facing trench
// room - no .map entity, no geometry, ships -GscOnly with ZERO LED-bake risk.
//
// Live dvars: acc_altar_cost (4), acc_altar_price_step (2), acc_altar_cooldown (12 s),
//             acc_altar_jackpot (5), acc_altar_points (250), acc_altar_mega_shards (10),
//             acc_altar_surge (5), acc_altar_drain (3).
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
    acc_data_shards::spawn_cache_at( ( -360, 1950, -240 ), getdvarint( "acc_cache_w_count", 3 ), "trench", 345 ); // pit west (user 2026-06-25: 2->3)
    acc_data_shards::spawn_cache_at( (  360, 1950, -240 ), getdvarint( "acc_cache_e_count", 3 ), "trench", 30 ); // pit east (user 2026-06-25: 2->3)

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
    spawn_altar_at( ( -400, 1948, -720 ) );                          // Glitch Altar -> abyss L3 WEST. BROADSIDE ROTATION REVERTED same-day (verify catch 2026-08-03): yaw 90 put the 162u clip 17u from BOTH flanking L3 eruption risers (-400,1850)/(-400,2046) - the >=45u riser rail beats the docs/47 finding-9 aesthetic; at yaw 0 the clearance is the proven 65u
    acc_overclocks::spawn_terminal_at( ( -400, 1948, -480 ), 0 );    // Cyberware Weapon Overclock -> abyss L2 WEST
    acc_ammo_crate::spawn_crate_at( (  400, 1948,  -480 ), 0 );      // AMMO CRATE #1 -> abyss L2 EAST, opposite the OC (user 2026-06-27: entry refill)
    acc_ammo_crate::spawn_crate_at( ( -400, 1948, -1200 ), 0 );      // AMMO CRATE #2 -> abyss L5 WEST, the bottom before Paradise (user 2026-06-27)
    acc_overclocks::spawn_terminal_at( ( 400, 1948, -1200 ), 180 );  // Cyberware Weapon Overclock #2 -> abyss L5 EAST (yaw 180 2026-08-03: screen WEST at the central descent well x[-112,112] - dragon front = +X at yaw 0, proven by the LB terminal at yaw 90 backed on the plaza S wall facing north, add_prop_clips.js 'leaderboard_terminal'; 180 keeps the origin-centered AABB so the overclock_l5 clip is untouched). Collision clip: add_prop_clips.js overclock_l5.

    // PLAZA Overclock (user 2026-07-26 "many players can't overclock because they can't get to the trench",
    // then same day "switch the exo suit station in plaza with the overclock station at lab"): a SECOND,
    // easy-access terminal ABOVE ground so the weapon-tier system no longer REQUIRES the trench descent.
    // Now at the plaza start-room spot the Exo pod held 2026-07-13..07-26 (-200,-100,0): open spawn-band
    // floor, immediately discoverable, clear of the start box (100,-150), the leaderboard terminal
    // (-340,-210) and all four plaza caches. The Exo pod took the Lab-beside-PaP spot in exchange
    // (_acc_exo::spawn_station). Above-ground is fine: spawn_terminal_at wires terminal_loop directly,
    // bypassing watch_terminal_trigger's map-trigger-only guard. Blue unused-station pulse rides
    // spawn_terminal_at's glow_on - position-independent. Collision clip: add_prop_clips.js 'overclock_plaza'.
    acc_overclocks::spawn_terminal_at( ( -200, -100, 0 ), 0 );        // Cyberware Weapon Overclock -> PLAZA start room (ex-Exo spot), user 2026-07-26

    // --- MARQUEE SINK: Neural Expansion Bay - buy +1 perk slot with shards (base 4, up to 9). In the Foundry /
    //     Exo-Suit under-room (ORIGINAL size, user 2026-06-28 reverted a brief shrink): interior x[-192,192]
    //     y[1379,1723] z=-240. Sits on the EAST side at (120,1550); the Exo station is on the WEST (-120,1550), so
    //     the two sit on OPPOSITE sides the long way (user 2026-06-26 placement tweak). Its .map collision clip
    //     moves to match (tools/add_prop_clips.js perk_slot_vendor).
    acc_perks::spawn_perk_slot_vendor_at( ( 120, 1550, -240 ), 180 );   // face the room's ONLY doorway (NW, door span x[-192,-112] on the y1723 wall - docs/47 trench finding 4): door bearing from here is ~147deg = WEST-of-NW, and 180 = WEST if the Gorod console front is +X like its p7_zm_sta_ sibling (dragon/LB proof) or NORTH (still toward the door wall) if it is -Y vending-style - 180 wins under BOTH axes; was yaw 0 = staring at the east wall 48u away under +X. Flip to 270 only if in-game it reads sideways.

    // PARADISE (the open-air plaza hub below the abyss - gen_descent_hub.js) gets its own FULL set of the
    // script-spawned amenities (user 2026-06-25: "everything a player needs spread throughout"). Independent
    // DUPLICATES of the abyss/Foundry stations (each helper is duplicable - research 2026-06-24).
    spawn_paradise();
}

// Populate PARADISE with the GSC-spawned amenities. (Stock perks + a 2nd Pack-a-Punch live as .map entities,
// added separately via tools/gen_paradise_props.js.) Plaza interior x[-700,700] y[-2000,-600] (COMPRESSED
// 2026-08-02, gen_compress_lab_paradise.js - was 2000x1600; user: "players gravitate there for safety"),
// floor z=-1200; entrance at north-center (y=-600). Spread the stations across the room. All sit deep in
// Paradise, reachable only after the soul-box descent + the communal Paradise gate.
function spawn_paradise()
{
    pz = -1200;   // Paradise floor top. Perk row is at y=-820 (north); 2nd PaP at (0,-1550). Spread the
                  // kiosks to the mid/south SIDES and put the bench (left) + box (right) along the south.

    // Glitch Altar + in-arena Ammo Crate REMOVED from Paradise (user 2026-07-13). The finale is a
    // survive-the-onslaught fight, not a shop run - the gamble altar + the refill crate are gone
    // (their clips also pulled from add_prop_clips.js). Max ammo now arrives as a scripted powerup
    // at 1:45 on the battle countdown instead (_acc_paradise::paradise_drop_max_ammo).
    // spawn_altar_at( ( -550, -1180, pz ) );                        // Glitch Altar - REMOVED
    acc_overclocks::spawn_terminal_at( ( 550, -1180, pz ), 180 );    // Cyberware Weapon Overclock (east-mid) - screen WEST into the arena. DRAGON FRONT = +X at yaw 0 (LB-terminal proof, add_prop_clips.js 'leaderboard_terminal': same model at yaw 90 backed on the plaza S wall faces north), so west = 180 NOT the vending-convention 270; 180 keeps the origin-centered 48x34 AABB -> paradise_overclock clip untouched
    acc_exo::spawn_station_at( ( -550, -1680, pz ), 90 );            // Exo Suit station (west-south) - pod face EAST at the arena (cryo-pod front = -Y at yaw 0, proven by the Scientist's Office copy: _acc_exo.gsc:97 'front -Y faces the door', live since 07-26); paradise_exo clip X/Y-swapped in lockstep
    acc_perks::spawn_perk_slot_vendor_at( ( 550, -1680, pz ), 180 );   // Neural Expansion Bay / perk slots (east-south) - address the arena to the west. Gorod-console front axis UNVERIFIED: 180 = WEST if it follows its p7_zm_sta_ sibling's +X front (dragon/LB proof), NORTH (toward the arena/entrance) if it is -Y vending-style - 180 wins under BOTH; 270 would face the S wall band if the axis is +X. Flip to 270 only if the in-game screen reads sideways.
    // acc_ammo_crate::spawn_crate_at( ( 550, -1430, pz ), 0 );      // AMMO CRATE #3 - REMOVED

    // ARMORY STATIONS IN PARADISE (user 2026-07-13): the two Armory-loft stations, on the west wall as a
    // pair. The rack is a SEPARATE, INDEPENDENT pool from the loft rack (spawn_rack_station is now
    // per-station, so it does NOT clobber the loft's) - the loft is unreachable once you descend anyway.
    acc_armory::spawn_rack_station( ( -550, -1180, pz ), 90 );       // team weapon rack (west-mid) - 138u long axis now PARALLEL to the W wall, long face east at the plaza (walkabout 2026-08-03 batch); end pads rotate to the S/N ends; paradise_armory_rack clip X/Y-swapped in lockstep
    acc_armory::spawn_bottle_station( ( -550, -1430, pz ), 90 );     // mega-bottle -> random Implant exchange (west) - bottle display EAST at the plaza (vending front = -Y memory + walkabout 2026-08-03; this is the exact model class the -Y rule was verified on); paradise_armory_bottle clip X/Y-swapped in lockstep

    // Boss-item Implant Bench: 3 pads = the 3 implant slots (2 -> 3, user 2026-07-09), side by side
    // along X at the same 160u spacing as the Plaza lab row, south-LEFT of center (row spans
    // x[-650,-250] - clear of the west wall at -700, backing onto the infestation SW brood/heart band;
    // the Mystery Box at +450 balances it east of the heart).
    sep = getdvarint( "acc_bench_pad_sep", 80 );
    acc_boss_items::spawn_bench_pad( ( -450 - 2 * sep, -1840, pz ), 0, 90 );
    acc_boss_items::spawn_bench_pad( ( -450,           -1840, pz ), 1, 90 );
    acc_boss_items::spawn_bench_pad( ( -450 + 2 * sep, -1840, pz ), 2, 90 );

    spawn_paradise_box_at( ( 450, -1900, pz ) );   // permanent Mystery Box (south-right, between the heart's E edge and the SE brood)

    // 2nd Pack-a-Punch (center-south, the design's intended PaP spot). STANDALONE custom vendor -
    // NOT a 2nd stock "zm_pack_a_punch" machine (that fatals stock's singleton GetEnt at load and was
    // what broke the surface PaP before). Reuses the SAME player-scoped tier path, so tier never resets.
    acc_pap_levels::spawn_paradise_pap_at( ( 0, -1550, pz ), 180 );   // face NORTH at the hall-mouth approach (walkabout 2026-08-03: faced AWAY at yaw 0 -> -Y-front validated); paradise_pap clip center y -1552 -> -1548 in lockstep

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
    box.angles = ( 0, 180, 0 );   // face NORTH at the arena approach (walkabout 2026-08-03 batch; angles were never written = default 0 = front at the S wall 100u away). MUST be set BEFORE the DisconnectPaths cut below so the navmesh cut matches the rotated _col footprint.
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
            player PlaySound( "acc_shard_deny" );   // [acc] deny buzz (sfx sweep 2026-07-21)
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
        PlaySoundAtPosition( "acc_glitch_altar_spin", self.acc_box_model.origin );   // [acc] datastream reveal spin (sfx sweep 2026-07-21)

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

function spawn_altar_at( origin, yaw )   // yaw optional (L3 passes 90 - broadside at the approach); omitted = default pose
{
    cost = altar_cost();

    // Stone-altar BASE (the machine you gamble at) + a glowing corrupted-data ORB floating +
    // spinning above it = the Glitch Altar. Altar slab is 58 tall, so the +72 orb hovers just
    // above it (STATION REMODEL 2026-07-09 - was the shared sign kiosk).
    base = spawn( "script_model", origin );
    base setmodel( "p7_ram_altar" );
    if ( isdefined( yaw ) ) base.angles = ( 0, yaw, 0 );
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
    t.acc_core = core;
    t.acc_base_model = base;   // glow_off target on first successful gamble (user 2026-07-17)
    t altar_refresh_hint();    // hint is LIVE-price owned (escalating price, user 2026-08-02) - never bake a cost string here
    t thread altar_loop();
    t thread altar_round_watch();

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

function altar_cost()     { return getdvarint( "acc_altar_cost", 4 ); }   // 2 -> 4: HUGE altar nerf, doubled (user 2026-08-02); history 4 -> 2 user 2026-06-19
function altar_cooldown() { return getdvarint( "acc_altar_cooldown", 12 ); }  // 6 -> 12: spam brake (user 2026-08-02)

// THE SPIN PRICE, with per-round escalation (HUGE nerf, user 2026-08-02 "someone can sit there
// and spam it to continue to get instakills"): every spin THIS round raises the next spin's
// price by acc_altar_price_step (4, 6, 8, 10, ...); a new round resets to the base. Precedent:
// the hack terminal's per-attempt stage escalation (_acc_events_hack). State lives on the
// trigger - exactly ONE altar exists (Paradise altar removed 2026-07-13), so trigger == global.
function altar_current_price()   // self = the altar trigger
{
    if ( !isdefined( self.acc_altar_spin_round ) || self.acc_altar_spin_round != level.round_number )
        return altar_cost();
    return altar_cost() + self.acc_altar_spins_round * getdvarint( "acc_altar_price_step", 2 );
}

// The hint must track the LIVE price (it was baked once at spawn and would lie under
// escalation - jukebox live-hint precedent). Called at spawn, after every paid spin, and by
// the round watcher on round change.
function altar_refresh_hint()    // self = the altar trigger
{
    price = self altar_current_price();
    self SetHintString( "Hold ^3[{+activate}]^7  ^5GLITCH ALTAR^7 - gamble ^5" + price + " Data Shards^7 (a true gamble - rare ^6MEGA^7 jackpot)" );
}

// Round rollover: reset the escalation + refresh the hint so a player walking up in a fresh
// round reads the base price (the trigger-side check alone only corrects on USE, not on read).
function altar_round_watch()     // self = the altar trigger
{
    self endon( "death" );
    level endon( "end_game" );
    for ( ;; )
    {
        wait 2;
        if ( isdefined( self.acc_altar_spin_round ) && self.acc_altar_spin_round != level.round_number )
        {
            self.acc_altar_spin_round  = level.round_number;
            self.acc_altar_spins_round = 0;
            self altar_refresh_hint();
        }
    }
}

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

        // Escalation bookkeeping (user 2026-08-02): sync the stored round BEFORE pricing so the
        // first spin of a fresh round always charges the base (the 2s watcher may not have
        // ticked yet).
        if ( !isdefined( self.acc_altar_spin_round ) || self.acc_altar_spin_round != level.round_number )
        {
            self.acc_altar_spin_round  = level.round_number;
            self.acc_altar_spins_round = 0;
        }

        cost = self altar_current_price();
        if ( !acc_data_shards::try_spend( player, cost ) )
        {
            altar_msg( player,"Glitch Altar: needs ^5" + cost + " Data Shards" );
            wait 0.4;
            continue;
        }

        self.acc_cooldown = true;
        self.acc_altar_spins_round++;   // next spin this round costs +step more
        self altar_refresh_hint();
        acc_interact_glow::glow_off( self.acc_base_model );   // shards actually spent = successful use
        self resolve_gamble( player );
        wait altar_cooldown();
        self.acc_cooldown = false;
    }
}

// Weighted: 45% win / 55% curse - a REAL gamble (HUGE nerf, user 2026-08-02: "I get too many
// good things like drops... needs smaller rewards... maybe the big jackpot is a nice pay out
// but overall needs to be a gamble"; was 65/35 with a 50% powerup/perk class). Curses NEVER
// instant-down. Most wins are now SMALL (a shard trickle / pocket points / a partial-refund
// jackpot); the powerup/perk class collapsed 50% -> 7% (+2% mega) AND is capped at one
// powerup-class hit per round (deliver_outcome). Mega Win stays the 2% showpiece, sweetened
// with bonus shards so the doubled+escalating price still has a dream payout.
function resolve_gamble( player )   // self = the altar trigger
{
    // Weights sum to 100, so each weight == its % chance.
    roll = acc_utility::acc_weighted_pick( array(
        // ---- SMALL WINS (36) ----
        weighted( 16, "shard_trickle" ),  // +1 shard - a "win" that still nets negative
        weighted( 12, "small_points" ),   // +250 points
        weighted(  8, "shard_jackpot" ),  // +5 shards - the one small TRUE win (15 -> 8)
        // ---- POWERUPS / PERK (7) - rare treats. The per-round cap covers the POWERUP class
        // (max_ammo / double_points / insta_kill / mega_win); random_perk is NOT capped. ----
        weighted(  3, "max_ammo" ),       // 15 -> 3
        weighted(  2, "double_points" ),  // 12 -> 2
        weighted(  1, "insta_kill" ),     // 13 -> 1 (THE spam-degenerate lane)
        weighted(  1, "random_perk" ),    //  8 -> 1 (uncapped - a perk is not a powerup)
        // ---- THE JACKPOT (2) ----
        weighted(  2, "mega_win" ),       // the showpiece: perk + insta-kill + bonus shards
        // ---- CURSES (55) - never instant-down ----
        weighted( 20, "surge" ),          // 16 -> 20
        weighted( 15, "shard_drain" ),    // 11 -> 15 (and the drain deepened 2 -> 3)
        weighted( 20, "dud" )             //  8 -> 20
    ) );

    deliver_outcome( player, roll );
}

function deliver_outcome( player, outcome )   // self = the altar trigger (via resolve_gamble)
{
    acc_utility::log( "glitch_altar roll: " + outcome );

    // ONE POWERUP-CLASS HIT PER ROUND (user 2026-08-02: hard-stops insta-kill chaining
    // regardless of bankroll - the weight cut alone can't stop a 500-shard-deep fisher).
    // A second powerup-class roll in the same round reroutes to the "grid spent" trickle;
    // mega_win keeps its perk + bonus shards and only loses the insta-kill half. Per-round
    // counter precedent: the Data Cache anti-hog counters (_acc_data_shards).
    b_powerup_capped = false;
    if ( outcome == "max_ammo" || outcome == "insta_kill" || outcome == "double_points" || outcome == "mega_win" )
    {
        if ( isdefined( self.acc_altar_powerup_round ) && self.acc_altar_powerup_round == level.round_number )
            b_powerup_capped = true;
        else
            self.acc_altar_powerup_round = level.round_number;
    }
    if ( b_powerup_capped && outcome != "mega_win" )
        outcome = "grid_spent";

    switch ( outcome )
    {
    // ---------- SMALL WINS ----------
    case "shard_trickle":
        acc_data_shards::grant_player( player, 1, "altar_trickle" );
        altar_msg( player,"^2GLITCH ALTAR: ^7a flicker of data... +1 Data Shard" );
        break;
    case "grid_spent":   // a capped powerup roll lands here - still pays the trickle
        acc_data_shards::grant_player( player, 1, "altar_trickle" );
        altar_msg( player,"^2GLITCH ALTAR: ^7the grid is spent this round... +1 Data Shard" );
        break;
    case "small_points":
        player zm_score::add_to_player_score( getdvarint( "acc_altar_points", 250 ) );
        altar_msg( player,"^2GLITCH ALTAR: ^7+" + getdvarint( "acc_altar_points", 250 ) + " points" );
        break;
    case "shard_jackpot":
        n = getdvarint( "acc_altar_jackpot", 5 );   // 7 -> 3 -> 4 (user 2026-06-24) -> 5 (nerf pass 2026-08-02: the one small TRUE win at the doubled price)
        acc_data_shards::grant_player( player, n, "altar_jackpot" );
        altar_msg( player,"^2GLITCH ALTAR: ^6JACKPOT ^7+" + n + " Data Shards!" );
        break;

    // ---------- POWERUPS / PERK (rare; the per-round cap = max_ammo/insta_kill/double_points/
    // mega_win only - random_perk is deliberately UNCAPPED, a perk is not a powerup) ----------
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

    // ---------- THE JACKPOT ----------
    case "mega_win":
        n = getdvarint( "acc_altar_mega_shards", 10 );
        acc_data_shards::grant_player( player, n, "altar_mega" );
        player zm_perks::give_random_perk();
        if ( b_powerup_capped )
            altar_msg( player,"^2GLITCH ALTAR: ^6MEGA WIN ^7Free Perk +" + n + " Shards! (grid spent - no Insta-Kill)" );
        else
        {
            altar_msg( player,"^2GLITCH ALTAR: ^6MEGA WIN ^7Free Perk + Insta-Kill +" + n + " Shards!" );
            level thread zm_powerups::specific_powerup_drop( "insta_kill", player.origin );
        }
        break;

    // ---------- CURSES (never instant-down) ----------
    case "surge":
        altar_msg( player,"^1GLITCH ALTAR: ^7The grid spikes - a SURGE answers!" );
        level thread acc_bus_trench::spawn_corp_surge( getdvarint( "acc_altar_surge", 5 ) );
        break;
    case "shard_drain":
        drained = drain_shards( player, getdvarint( "acc_altar_drain", 3 ) );   // 6 -> 2 (scaled-back economy) -> 3 (nerf pass 2026-08-02)
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
