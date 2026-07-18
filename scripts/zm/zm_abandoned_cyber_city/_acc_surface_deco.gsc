// =============================================================================
// _acc_surface_deco.gsc - static prop dressing for the SURFACE zones (topside
// twin of _acc_abyss_deco). BO2 TranZit prop pack (p7_zm_tra_*).
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
// LED bake), NOT -GscOnly. Kill-switch: acc_surface_deco 0.
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
    if ( getdvarint( "acc_surface_deco", 1 ) != 1 )
        return;

    n = spawn_bus_station();
    n += spawn_alley();
    n += spawn_market();
    n += spawn_vault();
    n += spawn_helipad();
    n += spawn_surface_pass3();
    n += spawn_surface_center();
    acc_utility::log( "surface deco init (all 5 surface zones: " + n + " props)" );
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
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( -120, 1210, 33 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( -120, 1210, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( 0, 1210, 33 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 0, 1210, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( 120, 1210, 33 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 120, 1210, 0 ), ( 0, 0, 0 ) );
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
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( 648, 1580, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med_clothes",    ( 560, 1578, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( 450, 1520, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_ashtray_tall",            ( 410, 1490, 13 ), ( 0, 0, 0 ) );

    // -- N / BOARDING QUEUE + BAY (north trench rim y2173) - mirrors the south bay --
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 2262, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 2262, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( -100, 2314, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_post_stanchion",          ( 60, 2314, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_barrier",  ( -470, 2222, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( 400, 2228, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( 150, 2210, 0 ), ( 0, 0, 0 ) );

    // -- N / DEPARTURES LOUNGE - benches facing the bay, armchair --
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( -150, 2500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_bench_wood",              ( 150, 2500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_booth_chair",             ( 300, 2545, 0 ), ( 0, 180, 0 ) );

    // -- N / RESTROOM NOOK (NW corner, W wall N of Vault door y>2556) --
    n += spawn_prop( "p7_zm_tra_sink_bathroom",           ( -702, 2600, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_urinal_bathroom",         ( -702, 2680, 40 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_mirror_wall_dmg",         ( -700, 2600, 130 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_sink_standing",           ( -560, 2708, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_frame_window_wood",       ( -485, 2645, 0 ), ( 0, 0, 0 ) );

    // -- N / CONCESSION / DINER (NE corner, E of box strip x>520) --
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( 620, 2690, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( 580, 2648, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( 660, 2648, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stove_kitchen",           ( 702, 2600, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_cash_register",           ( 560, 2690, 54 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_coffee_maker_full",       ( 660, 2690, 54 ), ( 0, 0, 0 ) );

    // -- N / MAINTENANCE & DEBRIS (N wall W of box strip) - abandoned mood --
    n += spawn_prop( "p7_zm_tra_stepladder_lrg",          ( -250, 2700, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -380, 2705, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 150, 2716, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_wood_lrg_broken",   ( -80, 2420, 19 ), ( 0, 25, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( 120, 2560, 9 ), ( 0, 0, 0 ) );

    // -- N / ARRIVALS BOARD (N wall, W of box) + a couple floor lamps --
    n += spawn_prop( "p7_zm_tra_tv_vintage_on",           ( -560, 2712, 33 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( -560, 2712, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_please_wait",        ( -560, 2726, 130 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_street_lamp_full",        ( -660, 1660, 0 ), ( 0, 0, 0 ) );
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

    return n;
}

function spawn_alley()
{
    n = 0;

    // -- ALLEY / EAST WALL (back-of-buildings grimy wall, between the E risers) --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1945, 480, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( 1945, 830, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1945, 1060, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_cage_animal_med",         ( 1895, 720, 20 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_outhouse",                ( 1900, 445, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( 1895, 1400, 9 ), ( 0, 0, 0 ) );

    // -- ALLEY / NORTH WALL (wrecked bike + rubble + barricade) --
    n += spawn_prop( "p7_zm_tra_bike_destroyed",          ( 1700, 1448, 4 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1820, 1452, 3 ), ( 0, 20, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( 1510, 1466, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 1440, 1462, 0 ), ( 0, 0, 0 ) );

    // -- ALLEY / SOUTH WALL (E of the box @1654,380) --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1860, 415, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1780, 420, 25 ), ( 0, 30, 0 ) );

    // -- ALLEY / MID-ROOM CLUTTER (clear of risers @1539.5/1979.5 y644/1212 + dog @1759.5,928) --
    n += spawn_prop( "p7_zm_tra_fence_quarantine_tarp_01", ( 1730, 770, 46 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1660, 1080, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1700, 1105, 25 ), ( 0, 45, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1650, 590, 3 ), ( 0, 10, 0 ) );
    n += spawn_prop( "p7_zm_tra_wheelbarrow_full",        ( 1625, 1300, 0 ), ( 0, 80, 0 ) );
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( 1850, 1150, 2 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( 1600, 860, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1830, 570, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_cage_animal_med",         ( 1620, 1000, 20 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( 1560, 900, 0 ), ( 0, 40, 0 ) );

    // -- ALLEY / WEST WALL (thin, between doors - keep the lane) + AMBIENT --
    n += spawn_prop( "p7_zm_tra_radiator_vintage",        ( 1356, 1000, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_metal_hold",        ( 1348, 900, 20 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_biohazard",          ( 1356, 760, 110 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1654, 650, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1654, 1150, 226 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 1955, 600, 130 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( 1356, 1250, 130 ), ( 0, 90, 0 ) );
    return n;
}

function spawn_market()
{
    n = 0;
    n += spawn_prop( "p7_zm_tra_gas_pump",                ( -2106, 460, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -2102, 680, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -2100, 760, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_cabinet", ( -2102, 1030, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_shelf",   ( -2102, 1095, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_stove_kitchen",           ( -2103, 1385, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( -1850, 446, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -2000, 440, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_stool_counter",           ( -1850, 500, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_cash_register",           ( -1900, 446, 54 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_building_gas",       ( -1560, 476, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_kitchen_long",      ( -1870, 1390, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_couch_floral",            ( -1600, 1374, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_booth_chair",             ( -1720, 1360, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_counter_kitchen_table",   ( -2050, 1420, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1720, 520, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1660, 1320, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1720, 700, 232 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1720, 1150, 232 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_neon_bar",           ( -1322, 928, 155 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -2120, 620, 160 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_sconce_motel_lit",  ( -2120, 1180, 160 ), ( 0, 90, 0 ) );
    return n;
}

function spawn_vault()
{
    n = 0;
    n += spawn_prop( "p7_zm_tra_vault_bank_door",         ( 1500, 3364, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_vault_bank_frame",        ( 1500, 3364, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_moo_server_comm_02",          ( 1910, 2400, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1915, 2490, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1913, 2590, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_out_monitor_atm",                ( 1913, 2680, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_sta_drop_pod_console_blue",   ( 1908, 2970, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1885, 3352, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1400, 2328, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_con_cargo_train_armory_cabinet", ( 1650, 2312, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1880, 2338, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( 1127, 2620, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_radiator_vintage",        ( 1123, 2720, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1134, 2820, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1136, 2960, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1720, 3352, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_sign_metal_bank",         ( 1925, 2500, 160 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_window_teller",           ( 1122, 2880, 35 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1922, 3060, 100 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1121, 2680, 100 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1400, 2700, 234 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( 1650, 3050, 234 ), ( 0, 90, 0 ) );
    return n;
}

function spawn_helipad()
{
    n = 0;
    n += spawn_prop( "p7_zm_tra_water_tower",             ( -1810, 3273, 1 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( -1548, 2852, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( -1500, 2872, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1524, 2812, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_gas_pump",                ( -1870, 2326, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -1760, 2330, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( -1650, 2320, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_barrier",  ( -1560, 2332, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( -1440, 2334, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_cage_animal_med",         ( -1650, 3352, 20 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( -1540, 3348, 2 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_radiator_vintage",        ( -1430, 3358, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_power_panel",             ( -1140, 2650, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_shelve_oilrack",          ( -1148, 2990, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_street_lamp_full",        ( -1895, 2400, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_fence_quarantine",        ( -1908, 3040, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1835, 2470, 9 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_garage_1x256",      ( -1128, 2830, 190 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_pipes_garage_1x128",      ( -1920, 2560, 195 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1500, 2600, 234 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_light_cage_ceiling",      ( -1500, 3050, 234 ), ( 0, 0, 0 ) );
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

    // -- ALLEY extra --
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1800, 1000, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( 1560, 1420, 3 ), ( 0, 30, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1830, 1280, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1700, 650, 25 ), ( 0, 20, 0 ) );
    n += spawn_prop( "p7_zm_tra_cage_animal_med",         ( 1900, 1150, 20 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_wheelbarrow_full",        ( 1600, 700, 0 ), ( 0, 30, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( 1700, 1300, 0 ), ( 0, 200, 0 ) );

    // -- MARKET extra --
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1900, 900, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_pile_01",   ( -1500, 1100, 3 ), ( 0, 10, 0 ) );
    n += spawn_prop( "p7_zm_tra_mannequin_full",          ( -1850, 700, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -1600, 1350, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_planter_stone",           ( -1450, 600, 0 ), ( 0, 0, 0 ) );

    // -- VAULT extra --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1250, 2700, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1350, 3352, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_sta_dragon_network_data_terminal", ( 1250, 2320, 0 ), ( 0, 180, 0 ) );
    n += spawn_prop( "p7_zm_tra_monitor_support_02",      ( 1130, 3050, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_cru_monitor_holo_screen_01",     ( 1900, 2400, 100 ), ( 0, 270, 0 ) );

    // -- ROOF extra --
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1500, 3000, 25 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( -1200, 2700, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1600, 3120, 9 ), ( 0, 40, 0 ) );
    n += spawn_prop( "p7_zm_tra_gas_pump",                ( -1250, 3050, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_zm_tra_traffic_street_cone",     ( -1550, 2900, 0 ), ( 0, 0, 0 ) );
    return n;
}

function spawn_surface_center()
{
    n = 0;

    // -- CORP center --
    n += spawn_prop( "p7_zm_tra_pneumatic_dolly",         ( -250, 2400, 2 ), ( 0, 45, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_lrg",            ( -190, 2445, 0 ), ( 0, 70, 0 ) );
    n += spawn_prop( "p7_zm_tra_suitcase_med",            ( -300, 2360, 0 ), ( 0, 20, 0 ) );

    // -- ALLEY center --
    n += spawn_prop( "p7_zm_tra_tank_chemical",           ( 1650, 928, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( 1610, 995, 25 ), ( 0, 15, 0 ) );

    // -- MARKET center --
    n += spawn_prop( "p7_zm_tra_counter_kitchen_table",   ( -1650, 700, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_tra_table_rustic_wood_sml",   ( -1560, 820, 0 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1680, 810, 25 ), ( 0, 0, 0 ) );

    // -- VAULT center --
    n += spawn_prop( "p7_zm_sta_computer_tower_01",       ( 1450, 2650, 0 ), ( 0, 90, 0 ) );
    n += spawn_prop( "p7_zm_moo_server_comm_02",          ( 1580, 2650, 0 ), ( 0, 270, 0 ) );
    n += spawn_prop( "p7_ris_generator_lg_01_blue",       ( 1500, 3000, 0 ), ( 0, 0, 0 ) );

    // -- ROOF center --
    n += spawn_prop( "p7_zm_tra_debris_rubble_02",        ( -1420, 2920, 9 ), ( 0, 0, 0 ) );
    n += spawn_prop( "p7_zm_tra_barrel_wood",             ( -1620, 2760, 25 ), ( 0, 0, 0 ) );
    return n;
}
