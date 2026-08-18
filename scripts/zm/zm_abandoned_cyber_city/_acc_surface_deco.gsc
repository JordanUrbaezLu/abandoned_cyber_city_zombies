// =============================================================================
// _acc_surface_deco.gsc - static prop dressing for the SURFACE zones (topside
// twin of _acc_abyss_deco). BO2 TranZit prop pack (p7_zm_tra_*) for the 5 outer
// zones + BO6 Liberty Falls pack (t10_*) for the PLAZA (spawn zone, 2026-07-18).
//
// BUS STATION TRANSIT-TERMINAL revamp (2026-07-16): the corp_zone reads as an
// abandoned inter-city bus terminal. The E-W trench = the BUS BAY (a derelict bus
// parks down there), so both surface halves face it as boarding platforms. Beats:
//   SOUTH hall - ticket office (bank-vault booth + long counter + teller windows),
//     a DEPARTURE BOARD of vintage TVs the 3 bench rows face, a boarding queue of
//     stanchions down the center aisle to the south bus bay, a baggage-claim cart
//     spill, an E-wall payphone bank.
//   NORTH hall - a departures lounge facing the north bus bay, a restroom nook, a
//     concession/diner counter, a maintenance/debris corner, an arrivals TV board.
// Bays on both trench rims = stanchion rails + traffic barriers/cones + a leaning
// quarantine fence. Ambient: hung ceiling fans, caged depot lights, wall sconces.
//
// Origins bounds-measured (tools/xmodel_bin_inspect.js --bounds); the layout came
// from a 3-concept design panel (bus-station-redesign workflow) synthesized into
// one plan. Data-driven: scratch gen_bus_layout.js emits BOTH these spawns AND the
// matching clips from one table, so they stay in sync.
//
// COLLISION: every FLOOR prop gets a worldspawn clip (add_prop_clips.js "BUS
// STATION SURFACE" section, bounds-measured half-extents mirroring these origins) -
// cod2map bakes them into the navmesh so zombies route around them. Overhead/high
// props (signs, wall TVs, fans, caged lights, sconces, payphones) sit above the
// ~72u nav ceiling and carry no floor clip. Adding clips = a FULL build (cod2map +
// LED bake), NOT -GscOnly. GSC spawns OFF by default since 2026-07-19 (the props
// are baked into the .map as misc_model statics - G_Spawn entity-cap fix);
// acc_surface_deco 1 re-enables the dynamic twins for layout iteration.
//
// LOCKSTEP IS MANDATORY: unlike _acc_abyss_deco (whose twins drifted - see its
// STALE-LEDGER TOMBSTONE), these surface twins were kept IN LOCKSTEP with the .map
// through the 2026-08-03 Prop Audit (Wave 1 + Phase A, CHANGELOG). Every future prop
// move MUST edit the .map misc_model AND the matching spawn_*() line here to the
// SAME origin/yaw in one pass (clips via add_prop_clips.js). If they ever diverge,
// acc_surface_deco 1 will double/resurrect props exactly like the abyss twin now would.
//
// KEEP-CLEARS (corp interior x[-761,799] y[1168,2728], floor z0, ~240 ceil): the
// trench y[1723,2173]; door corridors W&E at y[1200,1456] + y[2300,2556]; power
// switch W wall (-752,2250); mystery box (396,2704) + N-wall strip x[300,520];
// trench rim decals (y1703/y2173); stair mouths (W-south x<-665, E-north x>703).
// yaws are first-pass - flip any backward-facing prop after the walk.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;

#namespace acc_surface_deco;

function init()
{
    // 2026-07-19: all static deco baked into the .map as misc_model statics (G_Spawn
    // entity-cap fix). Set 1 to ALSO spawn dynamically for layout iteration (props will double).
    if ( getdvarint( "acc_surface_deco", 0 ) != 1 )
        return;

    n = spawn_bus_station();
    n += spawn_alley();
    n += spawn_market();
    n += spawn_vault();
    n += spawn_helipad();
    n += spawn_surface_pass3();
    n += spawn_surface_center();
    n += spawn_plaza();
    n += spawn_lab();
    // M6 (2026-07-18 visual sweep, final batch): PARADISE synthwave palms + the 4
    // previously-undressed rooms (Armory loft / Implant Lab / both trench under-rooms).
    // Layout: scratch gen_m6_layout.js (keep-clear validated - stations r110, risers,
    // door aprons, stair mouths); clips: add_prop_clips.js "M6" section (brushmodel FLAT).
    n += spawn_paradise_m6();
    n += spawn_armory_loft_m6();
    n += spawn_implant_lab_m6();
    n += spawn_under_rooms_m6();
    acc_utility::log( "surface deco init (7 surface zones + M6 paradise/loft/implant/under-rooms: " + n + " props)" );
}

// =============================================================================
// M6 PARADISE (synthwave reward plaza, floor -1200, interior x[-1000,1000]
// y[-2200,-600], open-air sky cap at -200). Palms ring the arena EDGES only -
// the floor stays open for the 4-boss onslaught. Keep-clears validated: all 12
// risers (r45), every station kiosk (r110), the PaP + wonder-loot ring (r200),
// the box, the 3 bench pads, the 10-perk row (r60 each) and the hall mouth
// x[-96,96]. Palms get TRUNK-ONLY flat brushmodel clips (m6_pd_palm1-7) - the
// canopy (~300u up) stays overhead; foliage accents are walk-through (no clips,
// all models already zoned by earlier batches). VISTA VERDICT: the MWIII skyline
// pieces were bounds-measured and are arena-scale-impossible (pyramid 3674^2,
// towers 4640x3264x11072, ziggurat 6656x6144) - and the sky cap ends AT the
// arena walls (no out-of-bounds shelf exists), so all 3 vista pieces are
// SKIPPED, not placed badly.
// =============================================================================
function spawn_paradise_m6()
{
    n = 0;
    n += spawn_prop( "jup_vertigo_palm_01", ( -640, -1940, -1198 ), ( 0, 30, 0 ) );    // palm, SW corner [clip m6_pd_palm1]
    n += spawn_prop( "jup_vertigo_palm_02", ( 640, -1940, -1197 ), ( 0, 140, 0 ) );    // palm, SE corner [clip m6_pd_palm2]
    n += spawn_prop( "jup_vertigo_palm_01", ( 640, -660, -1198 ), ( 0, 260, 0 ) );     // palm, NE corner [clip m6_pd_palm3]
    n += spawn_prop( "jup_vertigo_palm_02", ( -640, -660, -1197 ), ( 0, 75, 0 ) );     // palm, NW corner [clip m6_pd_palm4]
    n += spawn_prop( "jup_vertigo_palm_01", ( -650, -1035, -1198 ), ( 0, 190, 0 ) );   // palm, W wall (satellite nest) [clip m6_pd_palm5]
    n += spawn_prop( "jup_vertigo_palm_02", ( 650, -1450, -1197 ), ( 0, 320, 0 ) );    // palm, E wall mid [clip m6_pd_palm6]
    n += spawn_prop( "jup_vertigo_palm_02", ( -80, -1950, -1197 ), ( 0, 210, 0 ) );    // palm, S wall center [clip m6_pd_palm7]
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_01", ( -580, -1860, -1200 ), ( 0, 20, 0 ) );   // grass patch at the SW palm base
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_02", ( 580, -1860, -1200 ), ( 0, 200, 0 ) );   // grass patch, SE
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_03", ( -580, -750, -1200 ), ( 0, 90, 0 ) );    // grass patch, NW
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_01", ( 580, -770, -1200 ), ( 0, 300, 0 ) );    // grass patch, NE
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_04", ( -30, -1920, -1200 ), ( 0, 140, 0 ) );   // grass patch at the S palm base
    n += spawn_prop( "t10_foliage_cast_iron_lrg_01", ( -140, -620, -1200 ), ( 0, 0, 0 ) );    // fern W of the hall mouth
    n += spawn_prop( "t10_foliage_cast_iron_med_03", ( 140, -620, -1200 ), ( 0, 180, 0 ) );   // fern E of the hall mouth
    return n;
}

// =============================================================================
// M6 ARMORY LOFT (mezzanine x[682,1074] y[-230,230], floor z=192). Gun racks +
// ammo pile + locker give the weapon-rack room its armory read. Keep-clears:
// the rack (878,-100) + bottle (878,100) stations r110 and the stair mouth
// (x[682,740] y[-64,64]). All 4 clipped (m6_ar_*).
// =============================================================================
function spawn_armory_loft_m6()
{
    n = 0;
    n += spawn_prop( "p8_zm_off_rack_gun_full", ( 990, 208, 192 ), ( 0, 180, 0 ) );        // gun rack, N wall E [clip m6_ar_rack1]
    n += spawn_prop( "p8_zm_off_rack_gun_full", ( 1042, 208, 192 ), ( 0, 180, 0 ) );       // gun rack, NE corner [clip m6_ar_rack2]
    n += spawn_prop( "p8_zm_off_ammo_box_pile_01", ( 720, 170, 193.1 ), ( 0, 90, 0 ) );    // ammo crate pile, NW corner [clip m6_ar_ammo]
    n += spawn_prop( "p8_zm_off_locker_military_open", ( 700, -205, 192 ), ( 0, 0, 0 ) );  // military locker, SW corner [clip m6_ar_locker]
    return n;
}

// =============================================================================
// M6 IMPLANT LAB (plaza south room x[-720,180] y[-540,-240], z0). Varies from
// the Lab zone's kit on purpose (lightbox OFF not _on). Keep-clears: the 3
// bench-pad slots (lab_bench_slot1-3), the implant-door apron (x[-280,-160]),
// the exchange-door apron + stair enclosure (x[-640,-360] y[-460,-292]).
// =============================================================================
function spawn_implant_lab_m6()
{
    n = 0;
    n += spawn_prop( "p8_zm_off_filing_cabinet_01", ( 150, -250, 0 ), ( 0, 180, 0 ) );      // filing cabinet, NE corner [clip m6_il_filing]
    n += spawn_prop( "p8_zm_off_coat_lab_rack", ( 165, -300, 0 ), ( 0, 0, 0 ) );            // lab-coat rack, E wall [clip m6_il_coat]
    n += spawn_prop( "p8_zm_whi_hazmat_suit_hanging", ( -714, -380, 78 ), ( 0, 90, 0 ) );   // hazmat suit hung on the W wall (top-origin, hangs 75 - no clip)
    n += spawn_prop( "p8_zm_off_lightbox_xray", ( -500, -290, 60 ), ( 0, 90, 0 ) );         // x-ray lightbox (OFF variant) on the stair-enclosure N face (wall mount)
    n += spawn_prop( "p8_zm_off_curtain_portable", ( -680, -470, 82 ), ( 0, 90, 0 ) );      // portable curtain screening the W band (top-origin; sliver FLAT clip) [clip m6_il_curtain]
    return n;
}

// =============================================================================
// M6 TRENCH UNDER-ROOMS (both at z=-240, ceiling -96 / 144u headroom - every
// pick height-checked). S "Foundry" room x[-192,192] y[1379,1707] (perk-slot
// vendor 120,1550 r110 + the W door apron kept clear); N reactor/jukebox/box
// room ~x[-384,384] y[2189,2748] (reactor r110, jukebox, the box node at
// (-360,2231) and the door apron kept clear). p7_rus industrial kit.
// =============================================================================
function spawn_under_rooms_m6()
{
    n = 0;
    // S room (Foundry):
    n += spawn_prop( "p7_rus_tank_pressure", ( -140, 1430, -240 ), ( 0, 0, 0 ) );             // pressure tank (122 tall < 144), SW [clip m6_us_tank]
    n += spawn_prop( "p7_rus_table_steel", ( -150, 1560, -240 ), ( 0, 90, 0 ) );              // steel work table, W wall [clip m6_us_table]
    n += spawn_prop( "p7_rus_canister_industrial_metal", ( -100, 1440, -218.7 ), ( 0, 50, 0 ) );   // canister beside the tank (z-centered bin -> +21.3 lift) [clip m6_us_canister]
    n += spawn_prop( "p7_rus_box_electric_set_03", ( 60, 1384, -227 ), ( 0, 180, 0 ) );       // electric-box wall set, S wall (5u deep - flush, no clip)
    n += spawn_prop( "p7_rus_lamp_tinhat_full", ( -50, 1520, -103 ), ( 0, 0, 0 ) );           // tin-hat lamp flush on the ceiling (dead fixture - NOT a light entity)
    // N room (reactor / jukebox / trench box):
    n += spawn_prop( "p7_rus_tank_pressure", ( 300, 2380, -240 ), ( 0, 270, 0 ) );            // pressure tank, E wall [clip m6_un_tank]
    n += spawn_prop( "p7_rus_table_steel", ( 240, 2660, -240 ), ( 0, 0, 0 ) );                // steel work table, NE back bay [clip m6_un_table]
    n += spawn_prop( "p7_rus_canister_industrial_metal", ( 300, 2680, -218.7 ), ( 0, 110, 0 ) );   // canister by the table [clip m6_un_canister1]
    n += spawn_prop( "p7_rus_canister_industrial_metal", ( 150, 2710, -218.7 ), ( 0, 230, 0 ) );   // canister vs the back wall [clip m6_un_canister2]
    n += spawn_prop( "p7_rus_box_electric_set_03", ( 380, 2500, -227 ), ( 0, 90, 0 ) );       // electric-box wall set, E wall (flush, no clip)
    n += spawn_prop( "p7_rus_lamp_tinhat_full", ( 0, 2600, -103 ), ( 0, 0, 0 ) );             // tin-hat lamp flush on the ceiling (dead fixture)
    return n;
}

function spawn_prop( model, origin, angles )
{
    m = spawn( "script_model", origin );
    if ( !isdefined( m ) )
        return 0;
    m SetModel( model );
    m.angles = angles;
    return 1;
}

function spawn_bus_station()
{
    n = 0;

    // -- S / TICKET OFFICE (S wall, west) - bank-vault booth + long counter + teller windows --
    n += spawn_prop( "p7_zm_tra_vault_bank_frame",        ( -500, 1198, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_vault_bank_door",         ( -500, 1206, 0 ), ( 0, 202, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( -450, 1262, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_window_teller",           ( -505, 1244, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_window_teller",           ( -405, 1244, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_cash_register",           ( -450, 1258, 54 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_metal_bank",         ( -450, 1248, 158 ), ( 0, 90, 0 ) );

    // -- S / DEPARTURE BOARD (S wall center) - TVs on stands the bench grid faces --
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( -120, 1210, 33 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( -120, 1210, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( 0, 1210, 33 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 0, 1210, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( 120, 1210, 33 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 120, 1210, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_please_wait",        ( 0, 1189, 130 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_neon_bar",           ( 0, 1189, 176 ), ( 0, 180, 0 ) );

    // -- S / SEATING CONCOURSE - 3 rows split L/R blocks facing the board, center aisle x[-132,132] --
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -190, 1372, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( 190, 1372, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -190, 1462, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( 190, 1462, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -190, 1552, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( 190, 1552, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( -270, 1372, 0 ), ( 0, 20, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_lrg",            ( 270, 1552, 0 ), ( 0, 90, 0 ) );

    // -- S / BOARDING QUEUE + BAY (down the aisle to the south trench rim y1703) --
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 1614, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 1614, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 1662, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 1662, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_barrier",  ( -430, 1658, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( 300, 1662, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( 600, 1655, 0 ), ( 0, 0, 0 ) );

    // -- S / BAGGAGE CLAIM (SE quadrant, SOUTH of the Alley door y1456) - dolly + spilled luggage + bag table --
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( 600, 1540, 2 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_lrg",            ( 558, 1500, 0 ), ( 0, 20, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( 648, 1580, 0 ), ( 0, 335, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med_clothes",    ( 560, 1578, 0 ), ( 0, 40, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( 450, 1520, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_ashtray_tall",            ( 410, 1490, 13 ), ( 0, 0, 0 ) );

    // -- N / BOARDING QUEUE + BAY (north trench rim y2173) - mirrors the south bay --
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 2262, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 2262, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 2314, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 2314, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_barrier",  ( -360, 2230, 0 ), ( 0, 0, 0 ) );   // re-homed 2026-08-03 (prop audit): FIX BATCH 3 moved the coach to the N wall and orphaned this; now joins the N bay-rim cordon (fence/cone), kept 36u EAST of the ACCC000F POWER arrow decal x[-500,-436] y2195 - never block the user's breadcrumbs
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( 400, 2228, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( 150, 2210, 0 ), ( 0, 0, 0 ) );

    // -- N / DEPARTURES LOUNGE - benches facing the bay, armchair --
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -150, 2500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( 150, 2500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_booth_chair",             ( 300, 2545, 0 ), ( 0, 0, 0 ) );

    // -- N / RESTROOM NOOK (NW corner, W wall N of Vault door y>2556) --
    n += spawn_prop( "p7_zm_tra_sink_bathroom",           ( -747, 2600, 0 ), ( 0, 90, 0 ) );   // flushed vs the REAL W wall x-761 (FIX BATCH 3; was floating 45u off at x-702)
    n += spawn_prop( "p7_zm_tra_urinal_bathroom",         ( -751, 2680, 40 ), ( 0, 90, 0 ) );  // flushed vs the W wall (FIX BATCH 3)
    n += spawn_prop( "p7_zm_tra_mirror_wall_dmg",         ( -759, 2600, 130 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_sink_standing",           ( -665, 2704, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_frame_window_wood",       ( -485, 2645, 0 ), ( 0, 0, 0 ) );

    // -- N / CONCESSION / DINER (NE corner, E of box strip x>520) --
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( 620, 2690, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( 580, 2648, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( 660, 2648, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stove_kitchen",           ( 775, 2695, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_cash_register",           ( 560, 2690, 54 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_coffee_maker_full",       ( 660, 2690, 54 ), ( 0, 0, 0 ) );

    // -- N / MAINTENANCE & DEBRIS (N wall W of box strip) - abandoned mood --
    n += spawn_prop( "p7_zm_tra_stepladder_lrg",          ( -290, 2700, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -380, 2705, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 240, 2716, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_wood_lrg_broken",   ( -80, 2420, 19 ), ( 0, 25, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( 120, 2560, 9 ), ( 0, 0, 0 ) );

    // -- N / ARRIVALS BOARD (N wall, W of box) + a couple floor lamps --
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( -560, 2712, 33 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( -560, 2712, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_please_wait",        ( -560, 2726, 130 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_street_lamp_full",        ( -560, 1690, 0 ), ( 0, 0, 0 ) );   // MOVED (-660,1660)->(-560,1690) 2026-07-19 FIX BATCH 4: old spot choked the W trench-stair TOP mouth (33u/35u approach pinches -> co-op pile-up); now hugs the S parapet rail, 63u lane past the travel kiosk. misc_model + clip moved in lockstep.
    n += spawn_prop( "p7_zm_tra_street_lamp_full",        ( -660, 2400, 0 ), ( 0, 0, 0 ) );

    // -- AMBIENT - overhead + wall (no floor clips; all above the ~72u nav ceiling) --
    // (fan_ceiling_dmg dropped: shares 3 fan_ceiling_metal/wood materials the pack doesn't ship.)
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 0, 1360, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 0, 2280, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_payphone_wall",           ( 795, 1540, 120 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_payphone_wall",           ( 795, 1600, 120 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -450, 1189, 132 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 380, 1189, 132 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -300, 2727, 132 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 680, 2727, 132 ), ( 0, 0, 0 ) );

    // -- M4 ACCENT LAYER (2026-07-18): cyan megacorp transit concourse. THE SEALED
    //    SCHOOLBUS - RE-PARKED AGAIN 2026-07-19 (FIX BATCH 3): the batch-2 parapet
    //    spot (seal x[-642,-174] y[2199,2339]) COVERED the ACCC000F POWER arrow
    //    decal (x[-500,-436] y2195) - the user placed those breadcrumbs
    //    deliberately ("against the other wall, NOT on the same side as the power
    //    decals"). Now YAW 0 flush on the TRUE N wall (interior plane y2728,
    //    derived from the .map): misc_model (-25,2658), seal x[-261,207]
    //    y[2588,2728]. The stepladder (-250->-290) and power panel (150->240)
    //    moved aside for the span; benches keep an 87u lane to the bus S face;
    //    both door-corridor mouths (roof W x-761 / vault E x799, y[2320,2536])
    //    and ALL 10 POWER/arrow decals verified clear; the parapet power route is
    //    now decal-lit and bus-free. Clip stays ONE full-perimeter gabled shell
    //    (bus_m4_schoolbus_seal - still never walk-in, navmesh camping exploit).
    //    Plus the p7_spa
    //    spaceport kit (holo departures board + travel-kiosk island), street kit,
    //    a p7_rus staff corner on the E wall, and nature reclaim (leafless ivy on
    //    the rim parapets NEVER over the POWER decals, 2 bare beech trees, leaf
    //    litter). Layout/clips from scratch gen_bus_roof_layout.js (validated vs
    //    trench+rim band, stair mouths, bridge span, corridor aprons, box r60,
    //    decal spans, all kept clips). SKIPPED (256 ceiling): traffic-light pillar
    //    (275 tall), utility pole (mis-measured bin, likely head-only mesh).
    n += spawn_prop( "p8_zm_whi_schoolbus",               ( -25, 2658, 0 ), ( 0, 0, 0 ) );       // SEALED dead coach, E-W flush on the TRUE N wall y2728 (full-perimeter gabled shell, no entry; re-parked 2026-07-19 FIX BATCH 3, see header)
    n += spawn_prop( "p7_spa_signage_hologram_departure", ( 0, 1235, 228 ), ( 0, 90, 0 ) );       // holo departures board floating over the TV board (ceiling-mount, hangs down)
    n += spawn_prop( "p7_spa_travel_kiosk_btm_blue",      ( -600, 1520, 0 ), ( 0, 0, 0 ) );       // travel kiosk (base unit), SW island
    n += spawn_prop( "t10_com_parking_block_grey01",      ( -410, 1686, 0 ), ( 0, 90, 0 ) );      // parking block row W, S bus-bay rim approach (W of the POWER text decal)
    n += spawn_prop( "t10_com_parking_block_grey01",      ( 200, 1686, 0 ), ( 0, 90, 0 ) );       // parking block row E, S bus-bay rim approach
    n += spawn_prop( "t10_sign_street_usa_no_parking_post_01", ( 430, 2205, 0 ), ( 6, 340, 8 ) );   // NO PARKING post leaned at the N rim parapet (decals clear)
    n += spawn_prop( "t10_street_bike_stand_02",          ( 740, 1495, 0 ), ( 0, 0, 0 ) );        // bike stand, SE wall bay S of the staff desk
    n += spawn_prop( "p7_rus_desk_metal_vintage",         ( 779, 1590, 0 ), ( 0, 270, 0 ) );      // staff desk flush on the E wall under the payphone bank
    n += spawn_prop( "p7_rus_timecard_rack",              ( 796, 1650, 60 ), ( 0, 270, 0 ) );     // timecard rack plaque on the E wall (flush, no clip)
    n += spawn_prop( "p7_rus_refrigerator_vintage",       ( 770, 1672, 0 ), ( 0, 270, 0 ) );      // staff fridge, E wall by the S rim corner
    n += spawn_prop( "p7_rus_locker_open",                ( 781, 1498, 0 ), ( 0, 270, 0 ) );       // staff locker (open), E wall
    n += spawn_prop( "p7_rus_locker_closed",              ( 781, 1466, 0 ), ( 0, 270, 0 ) );       // staff locker (closed), E wall
    n += spawn_prop( "t10_un_foliage_ivy_leafless_wall_01_sparse", ( -100, 1700, 0 ), ( 0, 0, 0 ) );   // leafless ivy, S rim face between the POWER text and the E arrow
    n += spawn_prop( "t10_un_foliage_ivy_leafless_wall_02_sparse", ( 470, 1700, 0 ), ( 0, 0, 0 ) );    // leafless ivy, S rim face E of the arrow
    n += spawn_prop( "t10_un_foliage_ivy_leafless_wall_01_sparse", ( 60, 2196, 0 ), ( 0, 180, 0 ) );   // leafless ivy, N rim N face between the decal groups
    n += spawn_prop( "t10_un_foliage_tree_beech_bare_small_01",    ( -390, 2450, 0 ), ( 0, 0, 0 ) );   // bare beech (small), N hall floor crack (trunk clip only)
    n += spawn_prop( "t10_un_foliage_tree_beech_bare_medium_01",   ( 350, 1600, 0 ), ( 0, 0, 0 ) );    // bare beech (medium), S hall by the boarding queue (trunk clip only)
    n += spawn_prop( "t10_foliage_fallen_leaves_debris_06",        ( -390, 2455, 0 ), ( 0, 0, 0 ) );   // leaf litter under the N tree (flat, no clip)
    n += spawn_prop( "t10_foliage_fallen_leaves_debris_08",        ( 355, 1605, 0 ), ( 0, 0, 0 ) );    // leaf litter under the S tree (flat, no clip)

    return n;
}

// =============================================================================
// ALLEY densify: red-hazard SERVICE-ALLEY GUT (M3 visual sweep, 2026-07-18).
// Identity: the city's clogged service artery - a dumpster row (carved dirty
// dumpster + BO6 blue/green pair), a scaffolding tower, a 121-tall AC unit,
// chainlink + barbed-wire hazard lines, wall electrics/ladders/broken windows,
// street trash + paper litter, and hanging vines/ivy/cloth/blinds overhead.
// TIGHT IS GOOD here (difficult-navigation memory) but zombies still path
// end-to-end. REMOVED off-theme TranZit props (+ clips; outhouse zone line too):
// outhouse(1900,445), 5x barrel_wood (1780,420)(1660,1080)(1700,1105)(1800,1000)
// (1700,650), 3x cage_animal_med (1895,720)(1620,1000)(1900,1150). The center-
// anchor barrel_wood(1610,995) is REPLACED by p7_rus_barrel_metal_burn in
// spawn_surface_center() (same spot, floor-origin z0 vs the old z25 lift).
//
// ALLEY interior (REAL .map wall planes, FIX BATCH 3 2026-07-19 - rooms.json AND
// the M3 brief were STALE on the east): x[1339.5,2179.5] y[380,1476], ceil ~240.
// The room is 840u wide - M3 assumed the E wall at x~1969 and left every "E wall"
// prop floating ~210u off the real plane (user: "the wall is further back than
// you may have thought"; the ACCC0012 strip already sat on the real x2177.5).
// FIX: the whole E-wall group + SE bay cluster shifted +210 (M3 flush gaps
// preserved), the NE rubble corner-sealed at (2130,1430) (no sub-45u wall
// pocket), and the mid-room re-spaced for the true width (scaffold+dolly ->
// x~2040, tank_4 -> 1940, chainlink/coil/pile belt -> +80..110, tarp fence ->
// 1830, ceiling lights/haze/drip re-centered x1760). KEEP-CLEARS re-audited:
// box (1500,380) r60; risers (1539.5,644)(1539.5,1212)(1979.5,644)(1979.5,1212)
// + dog (1759.5,928) >=45u (x_wheelbarrow nudged (1600,700)->(1610,710) - its
// old corner was 42.9u from the (1539.5,644) riser); W-wall door mouth
// y[420,636] + corp corridor mouth y[1220,1436] (+40u aprons). PATHING GAP
// AUDIT (narrowest end-to-end lanes, clip-edge to clip-edge): W lane
// wall->blue dumpster 47; scaffold->E tank_2 60; coil->chainlink S weave 58;
// chainlink stub->burn barrel 49; dolly->riser corner 52; everything else
// >=45. Wall-flush mounts (<=15u deep), flat litter, atop-rubble junk and all
// overhead foliage carry NO clip; solid floor props are clipped + gabled.
// =============================================================================
function spawn_alley()
{
    n = 0;

    // -- KEPT GRIME (TranZit industrial kit) --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 2155, 480, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( 2155, 830, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 2155, 1060, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( 2130, 1430, 9 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bike_destroyed",          ( 1700, 1448, 4 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1920, 1452, 3 ), ( 0, 20, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( 1510, 1466, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 1440, 1462, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 2070, 415, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine_tarp_01", ( 1830, 770, 46 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1730, 590, 3 ), ( 0, 10, 0 ) );
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( 2045, 1150, 2 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( 1600, 860, 0 ), ( 0, 0, 0 ) );   // mid-room ON PURPOSE - squatter-camp cluster w/ mannequin + burn barrel (docs/47 Alley #12 KEEP, difficult-navigation)
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1940, 570, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( 1560, 900, 0 ), ( 0, 40, 0 ) );
    n += spawn_prop( "p7_zm_tra_radiator_vintage",        ( 1356, 1000, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_metal_hold",        ( 1348, 900, 20 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_biohazard",          ( 1356, 760, 110 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1760, 650, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1760, 1150, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 2165, 600, 130 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 1356, 1250, 130 ), ( 0, 90, 0 ) );

    // -- DUMPSTER ROW (M3): carved dirty dumpster + BO6 street pair --
    n += spawn_prop( "p7_ris_dumpster_full_open_dirty",   ( 2100, 460, 0 ), ( 0, 0, 0 ) );        // open dirty dumpster in the old outhouse bay (flush vs the chem tank)
    n += spawn_prop( "t10_street_dumpster_01_blue",       ( 1390, 1060, 0 ), ( 0, 0, 0 ) );       // blue street dumpster, W wall S of the corp mouth (corner origin)
    n += spawn_prop( "t10_street_dumpster_01_green",      ( 2168, 790, 0 ), ( 0, 180, 0 ) );      // green street dumpster vs the E wall

    // -- SERVICE HARDWARE: big AC unit + scaffolding tower --
    n += spawn_prop( "p7_zm_asc_ac_unit_lrg",             ( 2148, 545, 0 ), ( 0, 90, 0 ) );       // large AC unit vs the E wall (121 tall)
    n += spawn_prop( "p7_mou_scaffolding_full",           ( 2040, 1060, 0 ), ( 0, 0, 0 ) );       // scaffolding tower, E mid-room (clusters with the kept dolly)

    // -- WALL ELECTRICS + LADDER (flush mounts <=15u deep, no clips) --
    n += spawn_prop( "p7_rus_box_electric_set_02",        ( 1341, 710, 15 ), ( 0, 0, 0 ) );       // electric box set, W wall between the mouths
    n += spawn_prop( "p7_rus_box_electric_set_06",        ( 2176, 900, 0 ), ( 0, 180, 0 ) );      // electric box set, E wall
    n += spawn_prop( "p7_rus_ladder_metal_128",           ( 2176, 1330, 64 ), ( 0, 180, 0 ) );    // metal ladder vs the E wall (z-centered origin)

    // -- CHAINLINK + WIRE HAZARD LINE (the red-hazard gut reads) --
    n += spawn_prop( "p8_zm_whi_fence_chainlink_04_hole_01", ( 1560, 1095, 34 ), ( 0, 0, 0 ) );   // holed chainlink stub, mid-room weave (z lift 34)
    n += spawn_prop( "p8_zm_whi_fence_chainlink_08_dmg",  ( 1780, 520, 0 ), ( 0, 0, 0 ) );        // damaged chainlink run, S mid-room
    n += spawn_prop( "p8_zm_whi_barbed_wire_coil_01",     ( 1770, 420, 19 ), ( 0, 0, 0 ) );       // barbed wire coil along the S wall (z lift 19)
    n += spawn_prop( "p8_zm_whi_barbed_wire_coil_02",     ( 2140, 1465, 30 ), ( 0, 0, 0 ) );      // coil dumped on the NE rubble pile (rides its clip, none of its own)
    n += spawn_prop( "p8_zm_whi_window_frame_broken_02",  ( 1342, 830, 0 ), ( 0, 0, 0 ) );        // broken window frame leaned on the W wall
    n += spawn_prop( "p8_zm_whi_window_frame_broken_03",  ( 2174, 1120, 0 ), ( 0, 180, 0 ) );       // broken window frame leaned on the E wall

    // -- STREET TRASH + FLAT LITTER (litter = no clips) --
    n += spawn_prop( "t10_as_street_trash_bin_01",        ( 1445, 1250, 0 ), ( 0, 25, 0 ) );      // street trash bin near the corp mouth lane edge
    n += spawn_prop( "t10_trash_street_debris_01",        ( 1500, 460, 0 ), ( 0, 0, 0 ) );        // trash drift S
    n += spawn_prop( "t10_trash_street_debris_02",        ( 2110, 890, 0 ), ( 0, 90, 0 ) );       // trash drift E
    n += spawn_prop( "p7_rus_debris_paper_set_01",        ( 1600, 500, 0 ), ( 0, 0, 0 ) );        // paper litter S
    n += spawn_prop( "p7_rus_debris_paper_set_02",        ( 1750, 1200, 0 ), ( 0, 40, 0 ) );      // paper litter N
    n += spawn_prop( "p7_rus_debris_splinter_full",       ( 1870, 640, 6 ), ( 0, 70, 0 ) );       // splintered pallet debris (z lift 6)

    // -- OVERHEAD: blinds, cloth, vines, ivy (all above the nav ceiling, no clips) --
    n += spawn_prop( "p7_rus_blinds_plastic_broken",      ( 1342, 760, 190 ), ( 0, 90, 0 ) );     // broken plastic blinds high on the W wall
    n += spawn_prop( "p7_rus_cloth_hanging",              ( 1810, 1150, 230 ), ( 0, 0, 0 ) );     // hanging cloth scrap overhead
    n += spawn_prop( "t10_s4_jpn_bgv_foliage_hanging_vines_02", ( 2110, 1300, 238 ), ( 0, 0, 0 ) );   // long hanging vine, NE corner (drapes to the floor)
    n += spawn_prop( "t10_s4_jpn_bgv_foliage_hanging_vines_03", ( 1400, 450, 235 ), ( 0, 0, 0 ) );    // short vine curtain over the SW door lane
    n += spawn_prop( "t10_s4_jpn_bgv_foliage_hanging_vines_03", ( 1850, 780, 232 ), ( 0, 90, 0 ) );   // short vine curtain over the tarp fence
    n += spawn_prop( "t10_uk_foliage_vine_englishivy_hanging_med", ( 1700, 1470, 200 ), ( 0, 0, 0 ) );   // english ivy strand on the N wall
    n += spawn_prop( "t10_uk_foliage_vine_englishivy_square", ( 1341, 950, 180 ), ( 0, 90, 0 ) );  // english ivy mat high on the W wall

    // -- FLOOR-SEAM WEEDS (walk-through) --
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_broadleaf_03_wall", ( 1341, 940, 0 ), ( 0, 0, 0 ) );    // W wall seam
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_broadleaf_03_wall", ( 2176, 760, 0 ), ( 0, 180, 0 ) );  // E wall seam
    return n;
}

// =============================================================================
// MARKET re-theme: rural diner -> NEON NIGHT-MARKET gone to rot (M3 visual sweep,
// 2026-07-18). Identity: a magenta-neon street bazaar - three tarp stall stands +
// a film kiosk island over the kept kitchen-counter/table stall bases, a wrecked
// taxi rotting on the W wall, a booth-sofa diner nook under a neon DINER sign,
// and a wall collage of BO6 Liberty Falls signage (neon bunny, bar strip, video-
// store billboard + aisle labels, fast-food + ice-cream signs, menu board).
// REMOVED off-theme TranZit props (+ their clips + orphaned zone lines):
// gas_pump(-2106,460), sign_building_gas(-1560,476), couch_floral(-1600,1374).
//
// MARKET interior (REAL .map bounds - rooms.json STALE): x[-2140,-1300] y[400,1456],
// ceil ~240. KEEP-CLEARS honored (validated by scratch gen_market_alley_layout.js):
// box (-2117,1250) r60; risers (-2066,1296)(-1376,560)(-1376,1296) + dog
// (-1721,1130) >=45u; E-wall door mouth y[420,636] + corp corridor mouth
// y[1200,1456] (+40u aprons); the stall-row training loop stays LOOPABLE (all
// lanes >=45u: W lane 49, mid lane 50, S lane 68, E lane 63, N lane 92+).
// Data-driven: the generator emits BOTH these spawns AND the add_prop_clips.js
// "M3 MARKET + ALLEY" entries from one table. Tarp stalls are CENTERED-origin
// (z +30.6 lift); the cigarette vending machine is TOP-origin (hangs 52.8).
// Wall/overhead signage + TVs-on-furniture + houseplants carry NO clip.
// =============================================================================
function spawn_market()
{
    n = 0;

    // -- KEPT STALL BASES (TranZit diner kit, now the night-market's bones) --
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -2102, 860, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -2100, 930, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_cabinet", ( -2102, 1030, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_shelf",   ( -2102, 1095, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_stove_kitchen",           ( -2103, 1385, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( -1850, 446, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -2000, 440, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( -1850, 500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_cash_register",           ( -1900, 446, 54 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( -1870, 1390, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_booth_chair",             ( -1615, 1364, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_table",   ( -2050, 1420, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1720, 520, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1660, 1320, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1720, 700, 232 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1720, 1150, 232 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_neon_bar",           ( -1322, 928, 155 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -2120, 620, 160 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -2120, 1180, 160 ), ( 0, 90, 0 ) );

    // -- STALL ROW: 3 tarp market stands + the film-kiosk island (M3) --
    n += spawn_prop( "p7_sin_market_stand_tarp_01",       ( -1950, 700, 30.6 ), ( 0, 90, 0 ) );   // tarp stall A, W stall row (30.6 z lift, centered origin)
    n += spawn_prop( "p7_sin_market_stand_tarp_01",       ( -1460, 900, 30.6 ), ( 0, 270, 0 ) );   // tarp stall B, E stall row
    n += spawn_prop( "p7_sin_market_stand_tarp_01",       ( -1670, 600, 30.6 ), ( 0, 0, 0 ) );    // tarp stall C, S mid-row (flush with the center counter cluster)
    n += spawn_prop( "p7_ris_kiosk_large_01",             ( -1870, 1220, 0 ), ( 0, 0, 0 ) );      // kiosk stall island, mid-north
    n += spawn_prop( "veh_t7_civ_sedan_cruiser_vista_taxi", ( -2100, 710, 0 ), ( 0, 90, 0 ) );    // wrecked taxi parked on the W wall (vista-grade, mid-distance). MOVED N +150 2026-07-19: at y560 its clip swallowed the (-2066,560) riser struct

    // -- DINER NOOK: booth sofas where the floral couch was + neon DINER sign --
    n += spawn_prop( "t10_furniture_sofa_booth_restaurant_01", ( -1600, 1430, 0 ), ( 0, 270, 0 ) );   // booth sofa vs the N wall (faces S)
    n += spawn_prop( "t10_furniture_sofa_booth_restaurant_01", ( -1520, 1430, 0 ), ( 0, 270, 0 ) );   // booth sofa pair
    n += spawn_prop( "p8_zm_whi_sign_neon_diner",         ( -1560, 1452, 150 ), ( 0, 90, 0 ) );   // neon DINER sign over the booth nook

    // -- E WALL SHOP FRONT: display case + wall-hung cigarette vending --
    n += spawn_prop( "p8_zm_off_display_case_01",         ( -1312, 800, 0 ), ( 0, 90, 0 ) );      // display case between the E mouths
    n += spawn_prop( "p8_zm_off_cigarette_vending",       ( -1302, 950, 55 ), ( 0, 0, 0 ) );      // cigarette vending hung on the E wall (top-origin)

    // -- DEAD TVs on the kept stall furniture (walk-through, sit on clipped tables) --
    n += spawn_prop( "t10_electronics_television_01_on",  ( -2100, 1060, 38 ), ( 0, 90, 0 ) );    // live TV on the W counter cabinet
    n += spawn_prop( "t10_electronics_television_01",     ( -1800, 446, 55 ), ( 0, 0, 0 ) );      // dead TV on the S kitchen table

    // -- NEON / SIGNAGE SUITE (wall + overhead mounts, no clips) --
    n += spawn_prop( "t10_zm_neon_bunny_01",              ( -2134, 900, 100 ), ( 0, 270, 0 ) );   // giant neon bunny, W wall (spans z11-247)
    n += spawn_prop( "t10_zm_signage_bar_neon_01",        ( -2138, 1062, 190 ), ( 0, 270, 0 ) );    // neon bar strip over the W counters
    n += spawn_prop( "t10_zm_sign_videostore_billboard_01", ( -1305, 528, 130 ), ( 0, 90, 0 ) );  // videostore billboard over the E door mouth
    n += spawn_prop( "t10_zm_sign_videostore_label_televisions", ( -2139, 1020, 148 ), ( 0, 270, 0 ) );   // aisle label TELEVISIONS, W wall
    n += spawn_prop( "t10_zm_sign_videostore_label_computers", ( -2139, 1075, 148 ), ( 0, 270, 0 ) );     // aisle label COMPUTERS, W wall
    n += spawn_prop( "t10_zm_sign_videostore_label_radio", ( -2139, 1130, 148 ), ( 0, 270, 0 ) );  // aisle label RADIO, W wall
    n += spawn_prop( "t10_zm_fastfood_store_sign_01",     ( -1800, 403, 80 ), ( 0, 0, 0 ) );      // fast-food store sign over the S diner tables
    n += spawn_prop( "t10_zm_sign_ice_cream_01",          ( -1470, 1452, 140 ), ( 0, 180, 0 ) );    // ice cream sign, N wall by the booths
    n += spawn_prop( "t10_zm_sign_ice_cream_menu_board",  ( -2139, 1300, 120 ), ( 0, 270, 0 ) );    // menu board, W wall over the stove corner

    // -- CAST-IRON HOUSEPLANTS (walk-through; zoned by the M1 plaza pass) --
    n += spawn_prop( "t10_foliage_cast_iron_lrg_01",      ( -2115, 412, 0 ), ( 0, 45, 0 ) );      // SW corner
    n += spawn_prop( "t10_foliage_cast_iron_med_03",      ( -1330, 700, 0 ), ( 0, 210, 0 ) );     // E wall base
    n += spawn_prop( "t10_foliage_cast_iron_sml_01",      ( -2000, 440, 23 ), ( 0, 120, 0 ) );    // small plant on the rustic table
    return n;
}

// =============================================================================
// VAULT anchor upgrade: sealed bank data-fortress (M5 visual sweep, 2026-07-18).
// THE ANCHOR = the BO6 circular bank-vault door set (t10_zm_door_circular_vault_01
// leaf + frame + wheel + hinge, bo6_props.gdt) mounted as a massive SEALED portal
// on the SOUTH wall centered x1780 (decor - it never opens; the free span came
// from the SE chem-tank removal + the armory cabinet's 90u west slide 1650->1560),
// flanked by t10 safety-deposit panels. Backing suite (BO4 Classified office pack
// p8_zm_off_*): a bank-security ops row (console_control_03/_04) facing the
// portal, standing console banks on the N wall + E wall, server-wire sockets,
// three security monitors (ON / RED-alert / static) on mounts, a closed elevator
// vignette on the N wall, a walk-THROUGH metal-detector archway on the corp-mouth
// approach (pillar clips only - never the walkway gap), filing cabinets and a
// W-wall locker pair. REMOVED superseded TranZit bank props (spawns + clips in
// lockstep; zone lines all STAY - every model keeps Bus Station/Alley/Roof refs):
// vault_bank_door+frame (1500,3364), sign_metal_bank (1925,2500), window_teller
// (1122,2880), 3x tank_chemical (1885,3352)(1880,2338)(1250,2700 pass3),
// radiator_vintage (1123,2720). KEEP: the whole T7 tech set, the vault_c_* center
// island, the TranZit power_panel.
//
// VAULT interior x[1119,1930] y[2300,3380] (doors WEST: corp mouth y[2300,2556],
// lab mouth y[3100,3356] - the N-S Lab-approach traversal). KEEP-CLEARS honored
// (validated by scratch gen_vault_layout.js): box (1895,3120) r60 (standing bank
// 103 clear); risers (1324,2545)(1324,3115)(1734,2545)(1734,3115) + dog
// (1529,2830) >=45; acc_power_vault use-trigger x[1815,1879] y[2876,2940]; both
// W-mouth aprons. GAP AUDIT (clip-edge lanes): corp-mouth S bypass 56.5, filing->
// ops row 47 (tightest), door-front lane 67, ops-row door aisle 114.7, detector->
// island 127, everything else >=75; detector archway gap 41 (intentional arch).
// Clips = add_prop_clips.js "M5 VAULT" section (ONE gabled shell for the whole
// door assembly); sockets/monitors/plaques/screens are wall mounts with no clip.
// =============================================================================
function spawn_vault()
{
    n = 0;

    // -- KEPT T7 TECH SET (E wall island, S wall power kit, W wall mini row) --
    n += spawn_prop( "p7_zm_moo_server_comm_02",          ( 1899, 2400, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1904, 2490, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1895, 2590, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_out_monitor_atm",                ( 1919, 2680, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_sta_drop_pod_console_blue",   ( 1897, 2970, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1400, 2328, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_con_cargo_train_armory_cabinet", ( 1560, 2312, 0 ), ( 0, 180, 0 ) );   // MOVED 1650->1560 (M5: opens the S-wall span for the vault portal)
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 1127, 2620, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1134, 2820, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1143, 2960, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1720, 3352, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1922, 3060, 100 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1121, 2680, 100 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1400, 2700, 234 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1650, 3050, 234 ), ( 0, 90, 0 ) );

    // -- M5 THE ANCHOR: sealed circular vault portal, S wall (one gabled clip).
    //    FLUSHED -20y 2026-07-19 FIX BATCH 3: M5 assumed the S wall at y2300; the
    //    real interior plane is y2280 (whole row + both flank panels + monitor moved). --
    n += spawn_prop( "t10_zm_door_circular_vault_frame_01",     ( 1780, 2313, 0 ), ( 0, 90, 0 ) );    // ANCHOR vault portal frame, S wall (assembly clip covers frame+leaf+wheel+hinge)
    n += spawn_prop( "t10_zm_door_circular_vault_01",           ( 1722, 2314, 0 ), ( 0, 90, 0 ) );    // sealed circular vault door leaf, centered in the frame
    n += spawn_prop( "t10_zm_door_circular_vault_01_wheel_sml", ( 1780, 2324, 38 ), ( 0, 90, 0 ) );   // spinner wheel on the leaf face, door-center height
    n += spawn_prop( "t10_zm_door_circular_vault_01_hinge",     ( 1700, 2320, 0 ), ( 0, 90, 0 ) );    // hinge column on the west jamb
    n += spawn_prop( "t10_zm_bank_safety_deposit",        ( 1676, 2297, 0 ), ( 0, 90, 0 ) );          // safety-deposit panel, S wall west flank of the portal
    n += spawn_prop( "t10_zm_bank_safety_deposit",        ( 1924, 2297, 0 ), ( 0, 90, 0 ) );          // safety-deposit panel, S wall east flank
    n += spawn_prop( "t10_zm_bank_safety_deposit",        ( 1901.8, 2372, 0 ), ( 0, 180, 0 ) );         // safety-deposit panel, E wall SE nook (old chem-tank bay)

    // -- M5 BANK-SECURITY OPS ROW facing the portal + console banks --
    n += spawn_prop( "p8_zm_off_console_control_03",      ( 1700, 2450, 0 ), ( 0, 180, 0 ) );         // security control console W, ops row facing the vault door
    n += spawn_prop( "p8_zm_off_console_control_04",      ( 1886, 2450, 0 ), ( 0, 180, 0 ) );         // security control console E (114u door aisle between)
    n += spawn_prop( "p8_zm_off_console_standing_01",     ( 1892, 3280, 0 ), ( 0, 270, 0 ) );         // standing console bank, E wall N of the box (103u clear)
    n += spawn_prop( "p8_zm_off_console_standing_02",     ( 1470, 3353, 0 ), ( 0, 180, 0 ) );         // BIG standing console bank, N wall span freed by the old TranZit door

    // -- M5 SERVER-WIRE SOCKETS above the N-wall bank (wall greebles, no clips) --
    n += spawn_prop( "p8_zm_off_server_wires_socke_a",    ( 1420, 3374, 150 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p8_zm_off_server_wires_socke_b",    ( 1500, 3374, 145 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p8_zm_off_server_wires_socke_c",    ( 1460, 3374, 158 ), ( 0, 0, 0 ) );

    // -- M5 SECURITY MONITORS w/ mounts (S wall / W-wall floor pole / E wall) --
    n += spawn_prop( "p8_zm_off_monitor_security_mount_01", ( 1660, 2293, 98 ), ( 0, 180, 0 ) );      // wall mount above the west deposit panel
    n += spawn_prop( "p8_zm_off_monitor_security",        ( 1660, 2313, 150 ), ( 0, 180, 0 ) );       // monitor body (z150-183)
    n += spawn_prop( "p8_zm_off_monitor_security_screen_on", ( 1660, 2313, 151 ), ( 0, 180, 0 ) );    // live screen overlay (ON)
    n += spawn_prop( "p8_zm_off_monitor_security_mount_02", ( 1136, 2880, 0 ), ( 0, 90, 0 ) );       // floor pole mount, W wall (old teller-window bay; clipped)
    n += spawn_prop( "p8_zm_off_monitor_security",        ( 1136, 2880, 94 ), ( 0, 90, 0 ) );        // monitor body on the pole
    n += spawn_prop( "p8_zm_off_monitor_security_screen_red", ( 1136, 2880, 95 ), ( 0, 90, 0 ) );    // alert screen overlay (RED)
    n += spawn_prop( "p8_zm_off_monitor_security_mount_01", ( 1912, 2740, 102 ), ( 0, 270, 0 ) );      // wall mount, E wall between ATM and drop-pod console
    n += spawn_prop( "p8_zm_off_monitor_security_static", ( 1892, 2740, 152 ), ( 0, 270, 0 ) );        // monitor (static screen), E wall (z152-185)

    // -- M5 ELEVATOR VIGNETTE, N wall (closed decor pair, one flush clip) --
    n += spawn_prop( "p8_zm_off_elevator_door_metal_lt",  ( 1571, 3377, 0 ), ( 0, 270, 0 ) );         // elevator door LEFT (pair meets at x1610)
    n += spawn_prop( "p8_zm_off_elevator_door_metal_rt",  ( 1649, 3377, 0 ), ( 0, 270, 0 ) );         // elevator door RIGHT
    n += spawn_prop( "p8_zm_off_elevator_control_panel",  ( 1662, 3380, 48 ), ( 0, 0, 0 ) );          // call panel beside the doors (flush plaque, no clip)
    n += spawn_prop( "p8_zm_off_elevator_arrow",          ( 1610, 3380, 120 ), ( 0, 0, 0 ) );         // floor arrow above the doors (flush, no clip) (NOT in gdtDB - never rendered; EXCLUDED from the 2026-07-19 .map misc_model bake, cod2map hard-fails on it)

    // -- M5 SECURITY CHECKPOINT + OFFICE SPILL --
    n += spawn_prop( "p8_zm_off_metal_detector",          ( 1290, 2428, 0 ), ( 0, 90, 0 ) );          // metal-detector archway, corp-mouth approach (WALK-THROUGH; 2 pillar clips only)
    n += spawn_prop( "p8_zm_off_filing_cabinet_02",       ( 1595, 2458, 0 ), ( 0, 180, 0 ) );         // filing cabinet, W of the ops row
    n += spawn_prop( "p8_zm_off_filing_cabinet_03",       ( 1595, 2420, 0 ), ( 0, 180, 0 ) );         // filing cabinet pair
    n += spawn_prop( "p8_zm_off_locker_military_closed",  ( 1133, 2700, 0 ), ( 0, 90, 0 ) );          // military locker, W wall between the door mouths
    n += spawn_prop( "p8_zm_off_locker_military_closed",  ( 1133, 2742, 0 ), ( 0, 90, 0 ) );          // military locker pair (flush)
    return n;
}

// =============================================================================
// HELIPAD mil-tech rooftop - M4 HERO SWAP (2026-07-18): the central chemical-tank
// cluster (2x tank_chemical + wood barrel; + the 2 gas pumps and the other 2 wood
// barrels in pass3/center) is REMOVED (spawns + clips in lockstep) and replaced by
// a crashed BOMBER FUSELAGE (jup_vertigo_plane_boneyard_bomber_main_01, eMoX MWIII
// pack, 197x527x133) parked N-S over the old cluster center - the kept debris pile
// (-1420,2920) and cone (-1550,2900) now read as crash rubble under/next to the
// hull (their clips intentionally sit flush/inside the wreck shell - overlap is
// legal). The training RING survives as an OVAL: lanes W 248-307 / E 202-259 /
// N 166 / S 170 (old combined cluster ~192x168 - the wreck keeps the E-W width
// +2%, only the N-S length grows; no smaller bomber piece exists in the pack).
// Edge kit: yellow handrails/railings (wall-flush, no clips), barbed wire, metal
// crates + studio light head, NE fuel tank, W generator + propane pair, light
// tripods, N-wall wide chainlink + warning cloth, dry weeds. Layout/clips from
// scratch gen_bus_roof_layout.js (validated vs E corridor aprons, box r60, kept
// clips). SKIPPED - ceiling is a hard z256 slab, measured from the .map (the roof
// is a fully ENCLOSED box, no sky ledge exists): radar dish (569 tall), antenna
// radar (307), truss_metal (276), traffic-light pillar (275); salsola bush too
// wide (205) for the remaining lanes.
// =============================================================================
function spawn_helipad()
{
    n = 0;
    n += spawn_prop( "p7_zm_tra_water_tower",             ( -1810, 3273, 1 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -1760, 2330, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( -1650, 2320, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_barrier",  ( -1560, 2332, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( -1440, 2334, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_cage_animal_med",         ( -1650, 3352, 20 ), ( 0, 0, 0 ) ); // KEPT on purpose (Track C 2026-08-03): passes as derelict rooftop junk; no zoned mil-tech model at ~42x40 beats it. Yaw-0 fix = Wave 1.
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( -1540, 3348, 2 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( -1140, 2650, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -1148, 2990, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( -1908, 3040, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1835, 2470, 9 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_garage_1x256",      ( -1128, 2830, 190 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_garage_1x128",      ( -1920, 2560, 195 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1500, 2600, 234 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1500, 3050, 234 ), ( 0, 0, 0 ) );

    // -- M4 HERO + EDGE KIT (see the header comment above) --
    n += spawn_prop( "jup_vertigo_plane_boneyard_bomber_main_01", ( -1524, 2845, 0 ), ( 0, 0, 0 ) );   // HERO bomber-wreck fuselage - ENTERABLE since 2026-07-19 (FIX BATCH 2): vertex-decode proved a continuous open-ended hull tube (walls local x+-[83,98], open belly = world floor inside, both tube mouths torn open, no nose/tail taper). Clips = fitted set (bomber_wall_w/e thin side boxes z0-85 + 2 anti-perch roof wedges meeting at a ridge, bottom z85 = interior ceiling); both mouths ~164u wide so zombies path in - no camping pocket. NOTE 2026-07-19am: the roof dog_location struct sat INSIDE the old sealed shell (dogs spawned stuck) - the STRUCT moved to (-1700,2650), the bomber stays.
    n += spawn_prop( "p7_rus_handrail_double_128_yellow", ( -1400, 2312, 0 ), ( 0, 90, 0 ) );     // yellow handrail, S wall edge W segment (flush, no clip)
    n += spawn_prop( "p7_rus_handrail_double_128_yellow", ( -1270, 2312, 0 ), ( 0, 90, 0 ) );     // yellow handrail, S wall edge E segment (flush, no clip)
    n += spawn_prop( "p7_rus_barbed_wire_nosnow_07",      ( -1920, 2750, 0 ), ( 0, 90, 0 ) );     // barbed wire run, W wall between box and fence stub (flush, no clip)
    n += spawn_prop( "p7_rus_crate_metal_lrg",            ( -1240, 2600, 0 ), ( 0, 0, 0 ) );      // metal crate, E bay between the door mouths
    n += spawn_prop( "p7_rus_crate_metal_lrg",            ( -1300, 2600, 0 ), ( 0, 0, 0 ) );      // metal crate pair
    n += spawn_prop( "p7_rus_light_studio",               ( -1300, 2600, 42 ), ( 0, 30, 0 ) );    // studio light head dropped on the crate (rides its clip)
    n += spawn_prop( "p7_rus_fuel_tank_rust",             ( -1290, 3255, 0 ), ( 0, 90, 0 ) );      // rusty fuel tank, NE corner (clear of the lab-door apron)
    n += spawn_prop( "p7_out_generator",                  ( -1900, 2900, 0 ), ( 0, 0, 0 ) );      // field generator, W wall N of the box
    n += spawn_prop( "p8_zm_off_tank_propane",            ( -1866, 2965, 0 ), ( 0, 0, 0 ) );      // propane tank beside the generator
    n += spawn_prop( "p8_zm_off_tank_propane",            ( -1856, 2950, 0 ), ( 0, 0, 0 ) );      // propane tank pair
    n += spawn_prop( "p7_rus_light_studio_tripod",        ( -1680, 3300, 0 ), ( 0, 15, 0 ) );     // studio light tripod aimed at the pad, N by the water tower
    n += spawn_prop( "p7_rus_light_studio_tripod",        ( -1480, 2380, 0 ), ( 0, 190, 0 ) );     // studio light tripod, S edge kit
    n += spawn_prop( "p8_zm_whi_fence_chainlink_wide_01", ( -1300, 3364, 0 ), ( 0, 0, 0 ) );      // wide chainlink run on the N wall (flush, no clip)
    n += spawn_prop( "p8_zm_whi_cloth_warning",           ( -1310, 3360, 0 ), ( 0, 0, 0 ) );      // warning cloth draped on the chainlink (no clip)
    n += spawn_prop( "t10_balcony_railing_modern_64",     ( -1124, 2590, 0 ), ( 0, 90, 0 ) );     // modern railing piece, E wall between the mouths (flush, no clip)
    n += spawn_prop( "t10_balcony_railing_modern_64",     ( -1124, 2900, 0 ), ( 0, 90, 0 ) );     // modern railing piece, E wall N segment (flush, no clip)
    n += spawn_prop( "t10_base_foliage_grass_dry_arid_01", ( -1524, 2560, 0 ), ( 0, 0, 0 ) );     // dry arid grass scatter around the wreck tail (walk-through)
    n += spawn_prop( "t10_foliage_grass_dry_arid_weed_tall_01", ( -1660, 3180, 0 ), ( 0, 0, 0 ) );    // tall dry weed, N by the rubble (walk-through)
    n += spawn_prop( "t10_foliage_grass_dry_arid_weed_tall_01", ( -1360, 2450, 0 ), ( 0, 0, 0 ) );    // tall dry weed, SE (walk-through)
    return n;
}

function spawn_surface_pass3()
{
    n = 0;

    // -- CORP extra --
    n += spawn_prop( "p7_zm_tra_suitcase_lrg",            ( 490, 1400, 0 ), ( 0, 15, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( 455, 1438, 0 ), ( 0, 70, 0 ) );
    n += spawn_prop( "p7_zm_tra_ashtray_tall",            ( 690, 1360, 13 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( -350, 1655, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( 250, 2235, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -180, 1614, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 140, 1614, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 735, 2660, 3 ), ( 0, 40, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -500, 2716, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 795, 2100, 130 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 795, 1400, 130 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( -260, 2560, 0 ), ( 0, 120, 0 ) );

    // -- ALLEY extra (M3 removed the barrel_wood pair + the cage here) --
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1560, 1420, 3 ), ( 0, 30, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1900, 1280, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( 1700, 1300, 0 ), ( 0, 200, 0 ) );

    // -- MARKET extra --
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1900, 900, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( -1500, 1100, 3 ), ( 0, 10, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1850, 700, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -1560, 1364, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_planter_stone",           ( -1450, 600, 0 ), ( 0, 0, 0 ) );

    // -- VAULT extra (M5 removed the mid-W tank_chemical @1250,2700 with the
    //    bank-fortress anchor pass; the T7 tech extras stay) --
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1350, 3352, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1250, 2320, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 1130, 3050, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1900, 2400, 100 ), ( 0, 270, 0 ) );

    // -- ROOF extra (M4 removed the wood barrel @-1500,3000 + gas pump @-1250,3050
    //    with the tank-cluster hero swap; the E-wall tank + debris + cone stay -
    //    the cone now sits under the bomber hull, the debris reads as crash rubble) --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( -1200, 2700, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1600, 3120, 9 ), ( 0, 40, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( -1550, 2900, 0 ), ( 0, 0, 0 ) );
    return n;
}

// =============================================================================
// PLAZA - derelict civic plaza (M1 visual sweep, 2026-07-18). The spawn zone was
// the last ZERO-decoration surface room. Identity: the city's front door - a
// once-grand memorial plaza gone to seed. BO6 Liberty Falls pack (t10_*, GDTs
// bo6_props/bo6_foliage) + 2 carved T7 cyber accents (acc_t7_props_surface).
//
// Beats: the Shaftesbury memorial-angel fountain as an off-center mid-room
// island; iron-fence-framed planter beds gone wild on the W wall + under the
// dead neon sign on the N wall; two ornate bench rows facing the fountain;
// bollard lines leading to (NOT blocking) the NW/NE exit mouths; broken
// classical posts + parking blocks + overgrowth patches along pavement seams;
// cast-iron houseplants; blue LED strips + a dead white-neon sign (wall-mounted
// z130-155). SKIPPED this batch: clock_tower / vista_bldg skyline pieces
// (sightline over the walls unverified - follow-up).
//
// PLAZA interior measured from the .map walls (z0-256): x[-470,213] y[-240,720]
// (the start_zone info_volume x[-1165,1264] y[-1192,1104] also spans the NW/NE
// corridors, implant lab + armory stair - do NOT place from it). KEEP-CLears
// honored: 13 start_zone_spawners risers >=45u, spawn band x[-260,100]
// y[-190,-30], AW box (100,-150) r70, exo pod + LB terminal clips + interact
// radii, 4 plaza caches r60, implant-door approach x[-280,-160] y[-240,-140],
// armory mouth x[150,213] y[-90,90], exit mouth bands y[400,656], the
// barricade-window pocket x[-300,-160] y[400,610], frag wallbuy (-250,718).
//
// Data-driven: scratch gen_plaza_layout.js emits BOTH this block AND the
// add_prop_clips.js "PLAZA SURFACE (z=0)" entries from ONE table (bounds via
// xmodel_bin_inspect --bounds). Every SOLID floor prop is clipped (20 clips,
// wide ones gabled anti-perch); grass/houseplants/wall-mounts are walk-through.
// yaws are first-pass - flip any backward-facing prop after the walk.
// =============================================================================
function spawn_plaza()
{
    n = 0;

    // -- HERO: memorial angel fountain, mid-room island (angel faces spawn) --
    n += spawn_prop( "t10_decor_shaftesbury_memorial_fountain_angel", ( -40, 130, 0 ), ( 0, 0, 0 ) );

    // -- WEST PLANTER BED gone wild: iron fence run (rust gap y108-130) + boxes --
    n += spawn_prop( "t10_fence_plaza_iron_01_128",       ( -440, -20, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_fence_plaza_iron_02_64",        ( -440, 130, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_foliage_flower_hollyhock_planter_box_long_group_01_c", ( -455, 45, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_flower_camomile_planter_box_long_group_01_a",  ( -455, 145, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_fence_plaza_iron_01_single_a",  ( -440, 215, 0 ), ( 0, 90, 0 ) );

    // -- NORTH PLANTER BED under the dead neon (clear of the frag wallbuy @-250) --
    n += spawn_prop( "t10_fence_plaza_iron_01_128",       ( -64, 684, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_flower_hollyhock_planter_box_long_group_01_c", ( 0, 702, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_foliage_flower_camomile_planter_box_long_group_01_b",  ( 45, 700, 0 ), ( 0, 0, 0 ) );

    // -- BENCH ROWS facing the fountain (row A south, row B north) --
    n += spawn_prop( "t10_street_bench_iron_ornate_01",   ( -220, 10, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "t10_street_bench_iron_ornate_01",   ( -140, 10, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "t10_street_bench_iron_ornate_01",   ( -120, 335, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_street_bench_iron_ornate_01",   ( 30, 335, 0 ), ( 0, 90, 0 ) );

    // -- BOLLARD LINES leading to (not into) the NW/NE exit mouths (gaps y400-656) --
    n += spawn_prop( "t10_street_bollard_01",             ( -438, 250, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_street_bollard_01",             ( -438, 305, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_street_bollard_01",             ( -438, 360, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_street_bollard_01",             ( 180, 250, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_street_bollard_01",             ( 180, 305, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_street_bollard_01",             ( 180, 360, 0 ), ( 0, 0, 0 ) );

    // -- BROKEN CLASSICAL POSTS (derelict monument fragments) --
    n += spawn_prop( "t10_railing_classical_end_post_02",       ( -380, 690, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_zm_railing_classical_post_broken_02", ( 160, -220, 0 ), ( 0, 35, 0 ) );
    n += spawn_prop( "t10_zm_railing_classical_post_broken_05", ( 185, -205, 0 ), ( 0, 290, 0 ) );

    // -- PARKING BLOCKS (old civic parking row hints, south + west edges) --
    n += spawn_prop( "t10_com_parking_block_grey01",      ( -428, -150, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_com_parking_block_grey01",      ( -90, -215, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_com_parking_block_grey01",      ( 0, -215, 0 ), ( 0, 90, 0 ) );

    // -- OVERGROWTH (walk-through, no clips): pavement seams + wall bases --
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_02", ( -430, 220, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_03", ( -345, 225, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_04", ( 0, 0, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_04", ( 30, 590, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_01", ( 185, -140, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_01", ( -390, 650, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_strip_48", ( -100, -215, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "t10_foliage_grass_weeds_overgrowth_patch_strip_48", ( 205, 120, 0 ), ( 0, 90, 0 ) );

    // -- CAST-IRON HOUSEPLANTS (small, walk-through) --
    n += spawn_prop( "t10_foliage_cast_iron_lrg_01",      ( -450, -40, 0 ), ( 0, 45, 0 ) );
    n += spawn_prop( "t10_foliage_cast_iron_med_03",      ( 195, 690, 0 ), ( 0, 210, 0 ) );
    n += spawn_prop( "t10_foliage_cast_iron_sml_01",      ( -145, -222, 0 ), ( 0, 120, 0 ) );

    // -- CYBER ACCENTS (wall-mounted z130-155, no floor clips) --
    n += spawn_prop( "p7_sin_signage_3d_text_01_white_neon", ( 0, 718, 130 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_sky_light_led_01_b_blue",        ( -469, 80, 150 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_sky_light_led_01_b_blue",        ( -469, 340, 150 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_sky_light_led_01_b_blue",        ( 212, 150, 150 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_sky_light_led_01_b_blue",        ( 212, 330, 150 ), ( 0, 180, 0 ) );

    return n;
}

// LAB clinical cyberware-lab pass (M2 visual sweep, 2026-07-18). BO4 Classified
// office pack (p8_zm_off_*) + BO4 Alpha Omega White pack (p8_zm_whi_*) + BO6
// Liberty Falls glow accents (t10_*). Layout is DATA-DRIVEN: scratch
// gen_lab_layout.js emits BOTH these spawns AND the matching add_prop_clips.js
// "LAB SURFACE (z=0)" entries from one table (they cannot drift); it also
// VALIDATES every clip vs the room keep-clears. Interior x[-761,799]
// y[3070,4150]. KEEP-CLEARS: perk-buy strip y>=4020 full-width (players buy
// under fire); both corridor mouths y[3100,3356] (Roof side W, Vault side E)
// + 40u aprons; teleporter pad (150,3450) r110 (ACC_TP_TRIG_RADIUS); five-seven
// wallbuy (0,3070) r90; AW box approach x[640,799] y[3560,3740]; PaP (-700,3700);
// boss/dog struct (19,3648) r60; every riser >=45u. The 3 flat teleporter
// manifold plates (<=11u tall) are WALK-THROUGH by design - clipping a step
// plate would navmesh-hole the room center. Vignettes: decon airlock (S wall;
// the big open unit hosts a perk-scatter pad since 2026-07-25), test chamber
// (W wall), medical row (E wall), APD sci-fi island (mid-room NE), industrial
// corner (E wall N of the box), LED strips on the N wall (the alcove row they
// crowned was removed 2026-07-25), green/red energy-barrier glow posts.
function spawn_lab()
{
    n = 0;

    // -- TELEPORTER MACHINERY around the pad at (150,3450) (outside the r110 ring) --
    n += spawn_prop( "p8_zm_off_teleporter_machine",                  ( 150, 3285, 4 ), ( 0, 0, 0 ) );   // flat manifold plate S of the pad (11 tall, walk-over)
    n += spawn_prop( "p8_zm_off_teleporter_plug",                     ( -20, 3424, 0 ), ( 0, 0, 0 ) );   // power plug plate W of the pad (corner-origin, spans x-20..24)
    n += spawn_prop( "p8_zm_off_teleporter_connector",                ( 285, 3560, 0 ), ( 0, 0, 0 ) );   // connector plate NE of the pad
    n += spawn_prop( "p8_zm_off_teleporter_prototype",                ( 200, 3660, 0 ), ( 0, 0, 0 ) );   // HERO teleporter core generator (145 dia, 62 tall) N of the pad
    n += spawn_prop( "p8_zm_whi_apd_canister",                        ( 350, 3555, 0 ), ( 0, 0, 0 ) );   // sci-fi coolant canister feeding the core

    // -- DECON AIRLOCK line, S wall W of the five-seven wallbuy --
    n += spawn_prop( "p8_zm_whi_decontamination_unit_open",           ( -560, 3075, 0 ), ( 0, 180, 0 ) );   // decon unit, curtain open (GDT name; bin = unit_open) - hosts a Lab perk-scatter pad since 2026-07-25 (machine parks inside the tent)
    n += spawn_prop( "p8_zm_whi_decontamination_unit_small_open",     ( -420, 3078, 0 ), ( 0, 180, 0 ) );   // small decon unit, open
    n += spawn_prop( "p8_zm_whi_decontamination_unit_front",          ( -290, 3072, 1 ), ( 0, 180, 0 ) );   // decon unit front frame
    n += spawn_prop( "p8_zm_whi_decontamination_unit_pole_64",        ( -520, 3190, 0 ), ( 0, 0, 0 ) );   // queue pole (2x2 sliver)
    n += spawn_prop( "p8_zm_whi_decontamination_unit_pole_64",        ( -380, 3190, 0 ), ( 0, 0, 0 ) );   // queue pole
    n += spawn_prop( "p8_zm_whi_hazmat_suit_floor_01",                ( -480, 3200, 0 ), ( 0, 25, 0 ) );   // crumpled hazmat suit (flat)
    n += spawn_prop( "p8_zm_whi_hazmat_suit_hanging",                 ( -180, 3078, 90 ), ( 0, 0, 0 ) );   // hazmat suit on the S wall
    n += spawn_prop( "p8_zm_whi_hazmat_suit_hanging",                 ( -140, 3078, 88 ), ( 0, 0, 0 ) );   // hazmat suit on the S wall

    // -- TEST CHAMBER scene, W wall between the Roof mouth and the PaP --
    n += spawn_prop( "p8_zm_off_test_chamber",                        ( -730, 3520, 1 ), ( 0, 0, 0 ) );   // specimen test chamber (81 tall), W wall
    n += spawn_prop( "p8_zm_off_test_chamber_cover",                  ( -752, 3620, 24 ), ( 0, 90, 0 ) );   // chamber cover leaned on the W wall (flush art, no clip)
    n += spawn_prop( "p8_zm_whi_hazmat_suit_floor_02",                ( -690, 3420, 0 ), ( 0, 0, 0 ) );   // hazmat suit dropped at the chamber (flat)
    n += spawn_prop( "t10_zm_energy_barrier_01_open_green",           ( -738, 3400, 0 ), ( 0, 0, 0 ) );   // GREEN energy barrier post, W wall (glow)

    // -- PaP flanks (PaP at (-700,3700) faces east - only its S/N sides dressed) --
    n += spawn_prop( "p8_zm_off_coat_lab_rack",                       ( -725, 3612, 0 ), ( 0, 15, 0 ) );   // lab-coat rack S of the PaP
    n += spawn_prop( "p8_zm_off_coat_lab_hanging",                    ( -758, 3820, 80 ), ( 0, 0, 0 ) );   // lab coat on a W-wall peg N of the PaP

    // -- MEDICAL ROW, E wall between the Vault mouth and the AW box --
    n += spawn_prop( "p8_zm_off_medical_cart_main",                   ( 780, 3410, 0 ), ( 0, 90, 0 ) );   // medical cart
    n += spawn_prop( "p8_zm_off_respirator_machine_full",             ( 783, 3465, 0 ), ( 0, 90, 0 ) );   // respirator machine
    n += spawn_prop( "p8_zm_off_lightbox_xray_on",                    ( 795, 3505, 105 ), ( 0, 90, 90 ) );   // x-ray lightbox WALL-mount (lit; rolled upright)
    n += spawn_prop( "p8_zm_off_curtain_portable",                    ( 750, 3520, 82 ), ( 0, 90, 0 ) );   // portable curtain screening the row (top-origin, hangs to floor)
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",                 ( 796, 3430, 135 ), ( 0, 180, 0 ) );   // holo readout above the cart (already zoned)

    // -- APD SCI-FI ISLAND, mid-room NE quadrant (S of the perk strip) --
    n += spawn_prop( "p8_zm_whi_apd_turbine",                         ( 160, 3868, 0 ), ( 0, 0, 0 ) );   // APD turbine (mesh extends -y), flush the new inner N wall (2026-08-02 compression: interior y[3068,3868])
    n += spawn_prop( "p8_zm_whi_apd_element",                         ( 250, 3790, 1 ), ( 0, 45, 0 ) );   // APD glowing element core
    n += spawn_prop( "t10_zm_aether_canister_on",                     ( 100, 3860, 0 ), ( 0, 0, 0 ) );   // aether canister (glow), flush the new N wall
    n += spawn_prop( "t10_zm_aether_canister_on",                     ( 300, 3800, 0 ), ( 0, 0, 0 ) );   // aether canister (glow)

    // -- INDUSTRIAL CORNER, E wall N of the box (consoles = background per the
    //    untextured-decal cosmetic note; heroes = tank pair + steel table) --
    n += spawn_prop( "t10_zm_energy_barrier_01_closed_red",           ( 770, 3770, 0 ), ( 0, 0, 0 ) );   // RED energy barrier post N of the box (glow)
    n += spawn_prop( "p8_zm_off_console_control_01",                  ( 330, 3846, 0 ), ( 0, 180, 0 ) );   // control console, new N wall
    n += spawn_prop( "p8_zm_off_filing_cabinet_01",                   ( 718, 3852, 0 ), ( 0, 0, 0 ) );   // filing cabinet, new N wall
    n += spawn_prop( "p8_zm_off_console_control_02",                  ( 520, 3846, 0 ), ( 0, 180, 0 ) );   // wide control console, new N wall
    n += spawn_prop( "p8_zm_off_tank_chemical",                       ( 724, 3792, 0 ), ( 0, 0, 0 ) );   // pressure tank 1 - NE spur (merges with the red barrier mass)
    n += spawn_prop( "p8_zm_off_tank_chemical",                       ( 735, 3737, 0 ), ( 0, 30, 0 ) );   // pressure tank 2 - NE spur south end
    n += spawn_prop( "p8_zm_off_morgue_table",                        ( -190, 3240, 0 ), ( 0, 90, 0 ) );   // steel morgue/work table -> center-south medical cluster
    n += spawn_prop( "p8_zm_off_locker_military_open",                ( 610, 3852, 0 ), ( 0, 0, 0 ) );   // locker, open - new N wall
    n += spawn_prop( "p8_zm_off_locker_military_closed",              ( 658, 3852, 0 ), ( 0, 0, 0 ) );   // locker, closed - new N wall

    // -- N-WALL accents: LED strips on the wall face y4228 at z175, yaw 270 hugs
    //    the face. (Were "over the alcove bays" - the alcove row was REMOVED
    //    2026-07-25, so these + the cyan crown band now read as plain neon trim
    //    on the flat N wall over the perk spawn row.) --
    n += spawn_prop( "p7_sky_light_led_01_b_blue",                    ( -525, 3867, 175 ), ( 0, 270, 0 ) );   // LED strip, inner N wall W band
    n += spawn_prop( "p7_sky_light_led_01_b_blue",                    ( -225, 3867, 175 ), ( 0, 270, 0 ) );   // LED strip, inner N wall W-center
    n += spawn_prop( "p7_sky_light_led_01_b_blue",                    ( 225, 3867, 175 ), ( 0, 270, 0 ) );   // LED strip, inner N wall E-center
    n += spawn_prop( "p7_sky_light_led_01_b_blue",                    ( 525, 3867, 175 ), ( 0, 270, 0 ) );   // LED strip, inner N wall E band
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",                 ( 0, 3074, 140 ), ( 0, 90, 0 ) );   // holo readout above the five-seven wallbuy

    return n;
}

function spawn_surface_center()
{
    n = 0;

    // -- CORP center --
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( -250, 2400, 2 ), ( 0, 45, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_lrg",            ( -190, 2445, 0 ), ( 0, 70, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( -300, 2360, 0 ), ( 0, 20, 0 ) );

    // -- ALLEY center (M3: the wood barrel anchor became a burn barrel - floor
    //    origin z0, the old barrel_wood was centered-origin z25) --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1650, 928, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_rus_barrel_metal_burn",          ( 1610, 995, 0 ), ( 0, 15, 0 ) );

    // -- MARKET center --
    n += spawn_prop( "p7_zm_tra_counter_kitchen_table",   ( -1650, 700, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -1560, 820, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1680, 810, 25 ), ( 0, 0, 0 ) );

    // -- VAULT center --
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1450, 2650, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_moo_server_comm_02",          ( 1580, 2650, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1500, 3000, 0 ), ( 0, 0, 0 ) );

    // -- ROOF center (M4: the wood barrel @-1620,2760 was removed with the tank
    //    cluster; the debris pile stays - it now reads as bomber crash rubble) --
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1420, 2965, 9 ), ( 0, 0, 0 ) );
    return n;
}
