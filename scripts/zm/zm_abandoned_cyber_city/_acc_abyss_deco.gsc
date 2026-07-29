// =============================================================================
// _acc_abyss_deco.gsc - "Infected Descent" abyss-floor decoration (docs/30,
// locked plan 2026-07-12). Static script_model dressing for abyss floors L2-L5:
// the shaft is INFECTED - L2 Faltering Grid / L3 Corruption Bloom / L4 Specimen
// Vault / L5 The Maw. Spawned server-side like _acc_atmosphere's exchange props
// (spawn("script_model") + SetModel + .angles; models ride .zone xmodel lines,
// no PrecacheModel needed - the station precedent).
//
// PHASE 2 (2026-07-12): all four floors dressed - ~100 wall-hugging / hanging /
// corner props from the Phase-1 carve library (acc_t7_props_deco.gdt). Origins
// were COMPUTED from bounds-measured dims (tools/xmodel_bin_inspect.js via the
// scratch planner deco_place.js): standing z = floor + floorLift, hanging z =
// ceiling - (height - floorLift). Floors -480/-720/-960/-1200; ceilings (= the
// slab bottom of the floor above) -256/-496/-736/-976.
//
// PLACEMENT RULES (respected below - keep them on any edit):
//  * NOTHING mid-lane: everything hugs a wall, hangs from the ceiling, or sits
//    in a corner. Mid-floor obstacles/pillars are Phase 3 (they need acc_clip_*
//    brushmodels + the navmesh sweep); everything here is walk-through decor.
//  * Keep-clears: center stairwells x[-112,112] (well band alternates N/S per
//    floor), the stair-arrival strips, stations at +-400/y1948, the L4 AK-47
//    wallbuy face (S wall ~x-400), the L4 Gantry deck/stair (x[128,792] N band
//    + stair x[140,220] y[1901,2013]), the L5 Paradise doorway (S wall
//    x[-96,96]) + M60 face (-400,1725), and the L5 future-Overlook W-wall band
//    y[1783,2113] (Phase 3 deck goes there).
//  * Oversize set-pieces were CUT by measurement: the apothicon statue
//    (2130x1085x1001), its head (538x940x1196), the apoth shells (~700^3) and
//    the giant chamber tubes are arena-scale - they do not fit a 224u-headroom
//    room. The Maw hero = the 416-wide snake hatchery instead.
//  * Emissive probes rode along on purpose: L2 blue generator (proven), L3
//    boils_128x128a_emissive + the purple zod glyph (proven class), L5 runes +
//    red warning beacon. If floors still read too dark, Phase 4 adds the
//    bake-gated lightEntity() sets - do NOT try to fix darkness here.
//
// COLLISION: NONE in this module (walk-through decor by design; the lg tank /
// pods get clips in Phase 3 only if playtest shows walk-through reads wrong).
// Models are BAKE-NEUTRAL + NAVMESH-NEUTRAL -> this module is -GscOnly safe.
// GSC spawns OFF by default since 2026-07-19 (the props are baked into the .map
// as misc_model statics - G_Spawn entity-cap fix); acc_abyss_deco 1 re-enables
// the dynamic twins for layout iteration. floor_lights_on stays live regardless.
// =============================================================================

#using scripts\shared\array_shared;
#using scripts\shared\util_shared;

#insert scripts\shared\shared.gsh;

#using scripts\zm\zm_abandoned_cyber_city\_acc_utility;
#using scripts\zm\zm_abandoned_cyber_city\_acc_perk_lights;
#using scripts\zm\zm_abandoned_cyber_city\_acc_bus_trench;   // underground_layer() for the per-player lit-vision gate

#namespace acc_abyss_deco;

#define ACC_ABYSS_LIT_VISION_DEFAULT "acc_grade_abyss_lit"

function init()
{
    // (Crash-bisect resolved 2026-07-12: the CTD was the 10 baked lights, not this module.)
    // 2026-07-19: all static deco baked into the .map as misc_model statics (G_Spawn
    // entity-cap fix). Set 1 to ALSO spawn dynamically for layout iteration (props will double).
    // (Gate wraps ONLY the prop spawns - the soul-defeat floor_lights_on/spawn_lamp pipeline and
    // the opt-in acc_abyss_lit vision watcher below stay live regardless.)
    if ( getdvarint( "acc_abyss_deco", 0 ) == 1 )
    {
        // PER-FLOOR APPROVAL LOOP (user 2026-07-12 "let's focus" -> "okay let's go L2"):
        // floors light up ONE AT A TIME, sparse, with a user look-pass gating the next.
        // L2 = APPROVED FOR TEST. L3/L4/L5 spawn sets are authored below but NOT called
        // until their floor is approved - uncomment one call per approval.
        n = 0;
        n += spawn_l2();
        n += spawn_l3();      // APPROVED 2026-07-12
        n += spawn_l4();      // APPROVED 2026-07-13 ("implement the rest of the floors")
        n += spawn_l5();      // APPROVED 2026-07-13
        // M6 horror-organics layer (2026-07-18 visual sweep): moicesttom ghost pack (alien organics)
        // + BO4 White tunnel/mannequin/spawner + BO4 office pig-slab/hooks + BO6 moss. Additive ONLY,
        // ZERO light entities (the shaft stays pitch black - baked abyss lights are a bisect-proven CTD;
        // the only glow is model-own emissive materials). Layout: scratch gen_m6_layout.js (keep-clear
        // validated); clips: add_prop_clips.js "M6" section (brushmodel FLAT - trench rule).
        n += spawn_m6_trench();
        n += spawn_m6_l2();
        n += spawn_m6_l3();
        n += spawn_m6_l4();
        n += spawn_m6_l5();

        acc_utility::log( "abyss deco init (Infected Descent, trench + L2-L5 incl. M6 organics: " + n + " props)" );
    }

    // Per-player LIT vision grade DISABLED by default (user 2026-07-13: "looks like you just added a
    // TINT on my screen ... all I wanted was some LIGHTS when it's defeated"). The vision grade is a
    // full-screen exposure filter, not lights - wrong effect. Real lights now come from the BRIGHTER
    // lamps in floor_lights_on (fx_light_zm_fire_omni_12, intensity 251). Kept behind acc_abyss_lit
    // (default 0 now) only as an OPT-IN exposure boost if the lamps alone still aren't enough.
    if ( getdvarint( "acc_abyss_lit", 0 ) == 1 )
        level thread abyss_floor_vision_watcher();
}

// ---- L2 "FALTERING GRID" (floor -480, ceiling -256) -------------------------
// SPARSE PASS (user-gated look loop, 2026-07-12): dying server row, two racks,
// breaker cabinets, cable runs, the BLUE generator as the self-glow anchor,
// red/green fault pads. 13 props + the 2 clipped mid-floor breaker slabs.
// Cut from the first draft: fusebox/zapper cluster, light panels, tube lights,
// cable T (re-add on user ask, coords in git history).
function spawn_l2()
{
    n = 0;
    n += spawn_prop( "p7_zm_sta_computer_tower_01", ( -620, 1748, -444 ), ( 0, 0, 0 ) );   // server row, S wall W bay
    n += spawn_prop( "p7_zm_sta_computer_tower_01", ( -560, 1748, -444 ), ( 0, 0, 0 ) );   // server row
    n += spawn_prop( "p7_zm_sta_computer_tower_01", ( -500, 1748, -444 ), ( 0, 0, 0 ) );   // server row
    n += spawn_prop( "p7_zm_moo_server_comm_02", ( -756, 1900, -480 ), ( 0, 90, 0 ) );     // rack, W wall
    n += spawn_prop( "p7_zm_moo_server_comm_02", ( 795, 1900, -480 ), ( 0, 270, 0 ) );     // rack, E wall
    n += spawn_prop( "p7_zm_ver_powerbreaker", ( -756, 2050, -480 ), ( 0, 90, 0 ) );       // breaker cabinet, W wall
    n += spawn_prop( "p7_zm_asc_wire_bundle_straight_256", ( -400, 1727, -370 ), ( 0, 0, 0 ) );   // cable run, S wall
    n += spawn_prop( "p7_zm_asc_wire_bundle_straight_256", ( 500, 2169, -370 ), ( 0, 180, 0 ) );  // cable run, N wall
    n += spawn_prop( "p7_ris_generator_lg_01", ( -600, 2120, -480 ), ( 0, 180, 0 ) );      // generator, N wall W bay
    n += spawn_prop( "p7_ris_generator_lg_01_blue", ( 600, 2120, -480 ), ( 0, 180, 0 ) );  // BLUE generator - the glow anchor
    n += spawn_prop( "p7_cry_interrogation_console_01_no_mount_green", ( 550, 1735, -391 ), ( 0, 0, 0 ) );   // green console strip, S wall E bay
    n += spawn_prop( "p7_out_mech_spawn_pad_light_red", ( 480, 1948, -480 ), ( 0, 0, 0 ) );   // red fault-pad by the ammo crate
    // The GREEN pad (-250,1850) is NO LONGER deco: it is the third TELEPORTER pad (user
    // 2026-07-17), spawned by _acc_teleporter.gsc at the SAME origin/model (room looks
    // identical) with the full glow/trigger state machine. Its l2_pad_green clip stays here.
    // Mid-floor obstacles - spawned TOGETHER with their clips (add_prop_clips
    // pillar_l2_w/_e; solid + navmesh-cut so zombies route around):
    n += spawn_prop( "p7_zm_ver_powerbreaker", ( -550, 1948, -480 ), ( 0, 0, 0 ) );        // freestanding breaker slab, W bay mid
    n += spawn_prop( "p7_zm_ver_powerbreaker", ( 560, 1880, -480 ), ( 0, 90, 0 ) );        // breaker slab, E bay (N-S)
    return n;
}

// ---- L3 "CORRUPTION BLOOM" (floor -720, ceiling -496) -----------------------
// SPARSE PASS (approved 2026-07-12, L2 standard: EVERY touchable item clipped -
// add_prop_clips l3_* / pillar_l3_*). The infection winning: the emissive boils
// panel + purple glyph glow in the dark; membranes/roots/spore rocks on the
// walls; 3 membranes hang from the ceiling (156u above the floor - out of reach,
// unclipped); the root/rock slalom mid-floor. Glyph + vines are near-flat wall
// growth (2-4u) = decal-class, unclipped. Keep-clears: D3 well S x[-112,112],
// D2-arrival N x[-112,112], the Glitch Altar clip x[-481,-319] y[1915,1981].
function spawn_l3()
{
    n = 0;
    // Glow anchors:
    n += spawn_prop( "p7_zm_gen_apoth_int_boils_01_128x128a_emissive", ( -758, 1900, -690 ), ( 0, 90, 0 ) );   // EMISSIVE boils panel, W wall
    n += spawn_prop( "p7_zm_gen_apoth_int_boils_01_64x64a_backlit", ( 795, 2000, -670 ), ( 0, 270, 0 ) );      // boils, E wall
    n += spawn_prop( "p7_zm_zod_symbol_96_apothicon_purple_emissive", ( -758, 2080, -660 ), ( 0, 90, 0 ) );    // PURPLE GLYPH, W wall (flat - no clip)
    // Wall growth:
    n += spawn_prop( "p7_zm_gen_apoth_int_nerve_vine_01", ( -758, 1770, -719 ), ( 0, 90, 0 ) );    // nerve vine, W wall S corner (flat - no clip)
    n += spawn_prop( "p7_zm_gen_apoth_int_nerve_vine_02", ( 795, 1770, -717 ), ( 0, 270, 0 ) );    // nerve vine, E wall S corner (flat - no clip)
    n += spawn_prop( "p7_zm_gen_apoth_int_membrane_01", ( 300, 2150, -719 ), ( 0, 180, 0 ) );      // membrane, N wall
    n += spawn_prop( "p7_zm_gen_apoth_int_membrane_02", ( 650, 1740, -720 ), ( 0, 0, 0 ) );        // membrane, S wall
    n += spawn_prop( "p7_zm_isl_foliage_mutated_root_wall_01", ( -758, 2000, -684 ), ( 0, 90, 0 ) );   // root wall, W
    n += spawn_prop( "p7_zm_isl_foliage_mutated_root_wall_02", ( 200, 2150, -684 ), ( 0, 180, 0 ) );   // root wall, N
    n += spawn_prop( "p7_zm_isl_spore_rock", ( -700, 1780, -720 ), ( 0, 30, 0 ) );     // spore rock, SW corner
    n += spawn_prop( "p7_zm_isl_spore_rock", ( 750, 2120, -720 ), ( 0, 200, 0 ) );     // spore rock, NE corner
    n += spawn_prop( "p7_zm_gen_apoth_int_intestine_pile_01", ( -300, 2140, -720 ), ( 0, 0, 0 ) );   // intestine pile, N wall base (flat walkable plate)
    // Ceiling growth (hangs 156u above the floor - untouchable, no clips):
    n += spawn_prop( "p7_zm_gen_apoth_int_mem_hanging_01", ( -550, 1850, -498 ), ( 0, 0, 0 ) );    // hanging membrane
    n += spawn_prop( "p7_zm_gen_apoth_int_mem_hanging_03", ( 300, 1900, -498 ), ( 0, 45, 0 ) );    // hanging membrane
    n += spawn_prop( "p7_zm_gen_apoth_int_mem_hanging_05", ( 700, 1800, -498 ), ( 0, 270, 0 ) );   // hanging membrane
    // Mid-floor slalom obstacles (clips: pillar_l3_root_w / _rock_e / _root_e):
    n += spawn_prop( "p7_zm_gen_foliage_tree_twisted_root_lrg_02_lod", ( -620, 1850, -715 ), ( 0, 20, 0 ) );   // slalom root, W bay (_02 not _04: only _01/_02 are zone-listed - _04 silently fails to render, review 2026-07-15; _02 also keeps it visually distinct from the E-bay _01) (MOVED off the Glitch Altar at -400,1948 - its clip overlapped the altar E side = a barrier by the altar, user 2026-07-13)
    n += spawn_prop( "p7_zm_isl_spore_rock", ( 450, 1990, -720 ), ( 0, 120, 0 ) );                             // slalom rock, E bay
    n += spawn_prop( "p7_zm_gen_foliage_tree_twisted_root_lrg_01_lod", ( 620, 1860, -709 ), ( 0, 200, 0 ) );   // slalom root, E bay
    return n;
}

// ---- L4 "SPECIMEN VAULT" (floor -960, ceiling -736) -------------------------
// SPARSE PASS (L2/L3 standard 2026-07-13: real 3D solids clipped, flat/hanging
// art unclipped). What the city did to people: the lg specimen tank + cryo pods,
// lab table, containment vessels, cages, SPECIMEN signage. KEEP-CLEARS: the
// SOLID Gantry deck x[140,780] y[2013,2173] + its stair x[140,220] y[1901,2013]
// (nothing in that NE block - it is solid now), D4 well N x[-112,112] y[2045,2173],
// D3 arrival S x[-112,112] y[1723,1851], the AK-47 wallbuy S wall ~(-400,1725),
// tank (-400,1948) + pod (400,1948) stations. So the E-bay dressing hugs the E
// wall + S wall (all y<2013, south of the deck); the W bay (deck-free) carries the lab.
function spawn_l4()
{
    n = 0;
    // Hero + probes:
    n += spawn_prop( "p7_zm_isl_specimen_container_lg", ( -400, 1948, -960 ), ( 0, 90, 0 ) );   // HERO specimen tank, W bay [clip]
    n += spawn_prop( "p7_cry_cryogen_pod_exterior", ( 400, 1948, -897 ), ( 0, 90, 0 ) );        // cryo pod, E bay (y1948 < deck) [clip]
    // The lab (W bay, deck-free):
    n += spawn_prop( "p7_cry_cryogen_pod_frosted", ( -600, 1760, -902 ), ( 0, 0, 0 ) );    // frosted pod, S wall W bay [clip]
    n += spawn_prop( "p7_zm_isl_table_operating", ( -550, 1880, -960 ), ( 0, 30, 0 ) );    // operating table, W bay open [clip]
    n += spawn_prop( "p7_cry_interrogation_console_02", ( -756, 2050, -960 ), ( 0, 90, 0 ) );   // console, W wall [clip]
    // Vessels (E/S, south of the deck; positioned flush to the wall):
    n += spawn_prop( "p7_con_containment_vessel", ( 758, 1820, -960 ), ( 0, 270, 0 ) );    // containment vessel 116w, E wall (flush) [clip]
    n += spawn_prop( "p7_con_containment_vessel_decor", ( 500, 1745, -960 ), ( 0, 0, 0 ) );     // lit vessel, S wall E (MOVED 300->500: was in the D3 stair landing, user 2026-07-13) [clip]
    // Mid-floor vessel-forest slalom (clips pillar_l4_cyl_w/_e):
    n += spawn_prop( "p7_con_containment_vessel_cylinder", ( -250, 1880, -960 ), ( 0, 0, 0 ) );   // vat cylinder, W bay [clip]
    n += spawn_prop( "p7_con_containment_vessel_cylinder", ( 560, 1870, -960 ), ( 0, 90, 0 ) );   // vat cylinder, E bay (y1870 < deck) [clip]
    // Hanging cages + signage (above head / flat - NO clips):
    n += spawn_prop( "p7_zm_isl_cage_trap", ( -250, 1950, -736 ), ( 0, 0, 0 ) );           // hanging cage, W of stairwell (bottom ~105u up)
    n += spawn_prop( "p7_zm_isl_cage_trap", ( 300, 1780, -736 ), ( 0, 0, 0 ) );            // hanging cage, E bay S of the deck
    n += spawn_prop( "p7_zm_isl_signage_hanging_01_specimen_01", ( -400, 1870, -744 ), ( 0, 0, 0 ) );   // SPECIMEN sign over the tank
    n += spawn_prop( "p7_zm_isl_signage_hanging_01_specimen_03", ( 400, 1880, -744 ), ( 0, 0, 0 ) );    // SPECIMEN sign over the pod
    n += spawn_prop( "p7_cry_warning_light", ( 460, 2090, -840 ), ( 0, 0, 0 ) );           // red blinker on the Gantry deck (sits on deck top)
    return n;
}

// ---- L5 "THE MAW" (floor -1200, ceiling -976) -------------------------------
// SPARSE PASS (L2/L3 standard 2026-07-13). The abyss itself: snake hatchery hero,
// egg nests, crystal monoliths, jade fountain, snake column + arch framing the
// Paradise door, purple rune glow, red exit beacon. KEEP-CLEARS: the Paradise
// DOORWAY S wall x[-96,96] (the arch frames it, unclipped - you walk through),
// the M60 wallbuy S wall ~(-400,1725), the SOLID Overlook deck x[-781,-621]
// y[1783,2113] + its step, D4 arrival N x[-112,112] y[2045,2173], the ammo
// crate (-400,1948) + overclock (400,1948) stations. CUT: snake_with_wings
// (measured 463x445 - arena-scale, punches the ceiling) and the door teeth
// (77 wide at x+-130 would poke into the x[-96,96] exit).
function spawn_l5()
{
    n = 0;
    // Hero + solid relics (all clipped):
    // HATCHERY hero REMOVED 2026-07-13 (user: "random model with no clip on the stairs to the 5th floor - just remove it").
    // Sat at the top of the D4 descent (y2140 is inside the D4 well band y[2045,2173]) with its clip already removed in
    // Phase 6, so it floated walk-through right beside the stairs down to L5. L5 keeps the monoliths/fountain/eggs/arch as dressing.
    // NOTE (2026-07-16): its `xmodel,p7_ram_snake_large_hatchery` .zone line was ALSO trimmed (unplaced dead weight) - if you
    // ever re-enable this spawn, re-add that xmodel line to zone_source or it renders missing.
    // n += spawn_prop( "p7_ram_snake_large_hatchery", ( -380, 2140, -977 ), ( 0, 180, 0 ) );   // HATCHERY hero, N-wall W bay (caps ceiling) [clip]
    n += spawn_prop( "p7_zm_ori_monolith_base_crystal_01", ( -540, 1850, -1200 ), ( 0, 30, 0 ) );   // crystal monolith, W bay (E of the Overlook) [clip]
    n += spawn_prop( "p7_zm_ori_monolith_base_crystal_02", ( 700, 1850, -1200 ), ( 0, 210, 0 ) );   // crystal monolith, E bay [clip]
    n += spawn_prop( "p7_ram_snake_fountain_01_jade", ( 620, 2000, -1200 ), ( 0, 270, 0 ) );        // jade snake fountain, E bay centerpiece [clip]
    n += spawn_prop( "p7_ram_snake_column_01", ( 470, 2110, -1192 ), ( 0, 180, 0 ) );    // snake column, N wall E (MOVED 240->470: was in the D4 stair landing, user 2026-07-13) [clip]
    n += spawn_prop( "p7_ram_statue_snake_base_jade", ( -700, 1745, -1200 ), ( 0, 90, 0 ) );   // jade statue, SW (just S of the Overlook) [clip]
    n += spawn_prop( "p7_ram_snake_egg_niche_base", ( 700, 1760, -1200 ), ( 0, 0, 0 ) );  // big egg nest base, SE corner [clip]
    n += spawn_prop( "p7_ram_snake_egg_niche_nest", ( 760, 2120, -1200 ), ( 0, 180, 0 ) );   // egg nest, NE [clip]
    n += spawn_prop( "p7_ram_snake_egg_niche_nest", ( -250, 1755, -1200 ), ( 0, 0, 0 ) );    // egg nest, S wall W of the door [clip]
    // Door frame + sconces (unclipped - walk through / flush at height):
    n += spawn_prop( "p7_ram_snake_corridor_arch_01", ( 0, 1745, -1199 ), ( 0, 0, 0 ) );  // snake arch framing the Paradise doorway
    n += spawn_prop( "p7_ram_snake_sconce_left", ( -150, 1730, -1096 ), ( 0, 0, 0 ) );    // sconce W of the door (flush, at height)
    n += spawn_prop( "p7_ram_snake_sconce_right", ( 150, 1730, -1096 ), ( 0, 0, 0 ) );    // sconce E of the door
    // Purple rune glow + red beacon (flat wall decals / tiny - unclipped):
    n += spawn_prop( "p7_zm_gen_rune_2_purple", ( -300, 2166, -1100 ), ( 0, 180, 0 ) );   // purple rune, N wall
    n += spawn_prop( "p7_zm_gen_rune_4_purple", ( 795, 1950, -1094 ), ( 0, 270, 0 ) );    // purple rune, E wall
    n += spawn_prop( "p7_zm_gen_rune_7_purple", ( -250, 1730, -1100 ), ( 0, 0, 0 ) );     // purple rune, S wall W of the door
    n += spawn_prop( "p7_foliage_vines_hanging_ledge_192_long_dead", ( 500, 2160, -989 ), ( 0, 180, 0 ) );   // dead vines, N wall (hanging)
    n += spawn_prop( "p7_zm_asc_light_cage_warning_red", ( 0, 1735, -990 ), ( 0, 0, 0 ) );    // RED EXIT BEACON above the Paradise doorway
    return n;
}

// =============================================================================
// M6 HORROR ORGANICS (2026-07-18 visual sweep) - the infected-descent read gets its
// organic layer: the infection creeps in from the trench (moss + collapsed tunnel),
// blooms on L3 (tentacles/eggs/alien grass), is EXPERIMENTED ON in L4 (butcher
// slab / hooks / mannequin specimens / EMISSIVE glo-sprouts - the locked plan's
// Phase-0 emissive proof, mtl_dct_alien_plant_glo_sprout is lit_emissive_advanced
// with a dedicated _em map), and WINS on L5 (flesh hive + dead queen/brutes).
// Ghost-pack corpses (dead_queen_1/dead_brute_*) are STATIC script_models - deco
// statues, never wired as AI. All solid floor pieces are clipped via
// add_prop_clips.js "M6" (script_brushmodel FLAT boxes - LED-exempt, never gabled:
// "anything in the trench is fine"); wall/ceiling mounts + moss/grass stay
// walk-through. NO light entities anywhere in this block (pitch-black by design).
// =============================================================================

// ---- TRENCH L1 (floor -240, the open corp pit y[1723,2173]) -----------------
// Keep-clears honored: pit caches (+-360,1950), D1 well band x[-130,130] S, the
// N-room door apron x[-96,96], both stair channels (W x[-761,-665] S lip, E
// x[703,799] N lip), the bridge span overhead.
function spawn_m6_trench()
{
    n = 0;
    n += spawn_prop( "p8_zm_whi_tunnel_metal_segment", ( -180, 2150, -240 ), ( 0, 90, 0 ) );   // tunnel rib W of the N under-room door. CLIP REMOVED 2026-07-19 FIX BATCH 4 (walk-through wall dressing now): its brushmodel clip's DisconnectPaths could kill the pit N-strip nav polys linking the W stair's bottom landing -> co-op "piled up at the bottom of the stairs". See add_prop_clips.js tombstone.
    n += spawn_prop( "p8_zm_whi_tunnel_metal_segment", ( 180, 2150, -240 ), ( 0, 90, 0 ) );    // tunnel rib E of the N under-room door. CLIP REMOVED with its W twin (same FIX BATCH 4 reasoning).
    // COLLAPSED tunnel wreck (p8_zm_whi_tunnel_metal_segment_dmg @ 380,1800) REMOVED 2026-07-19:
    // its 418x164 full-height clip sealed the E trench stair's only pit-floor approach (29u slot
    // < the 32u player capsule = pit exit toward power BLOCKED) and swallowed the (480,1830)
    // riser. The riser rows y1830/y2070 (x +-160/+-480) leave no legal pit spot that big.
    n += spawn_prop( "t10_un_foliage_weeds_moss_01", ( -560, 1726, -120 ), ( 0, 90, 0 ) );     // moss tuft, S wall
    n += spawn_prop( "t10_un_foliage_weeds_moss_03", ( 240, 1726, -150 ), ( 0, 90, 0 ) );      // moss tuft, S wall E
    n += spawn_prop( "t10_un_foliage_weeds_moss_05", ( -300, 2170, -140 ), ( 0, 270, 0 ) );    // moss tuft, N wall
    n += spawn_prop( "t10_foliage_bunker_moss_01", ( 250, 2170, -180 ), ( 0, 270, 0 ) );       // bunker moss, N-room front wall
    return n;
}

// ---- L2 M6 additions (the infection reaches the grid) -----------------------
function spawn_m6_l2()
{
    n = 0;
    n += spawn_prop( "p8_zm_whi_tunnel_metal_segment", ( 300, 1727, -480 ), ( 0, 90, 0 ) );    // tunnel rib vs the S wall E bay (protrudes 32 - real solid) [clip m6_l2_seg]
    n += spawn_prop( "p8_zm_whi_tunnel_metal_door_01", ( -300, 2166, -476 ), ( 0, 90, 0 ) );   // blast door leaned flush on the N wall (9u deep - flush art, no clip)
    n += spawn_prop( "t10_un_foliage_weeds_moss_01", ( -779, 1810, -390 ), ( 0, 0, 0 ) );      // moss, W wall
    n += spawn_prop( "t10_un_foliage_weeds_moss_05", ( -779, 2120, -370 ), ( 0, 0, 0 ) );      // moss, W wall N
    n += spawn_prop( "t10_un_foliage_weeds_moss_03", ( 793, 2060, -380 ), ( 0, 180, 0 ) );     // moss, E wall
    n += spawn_prop( "t10_foliage_bunker_moss_01", ( 150, 1727, -400 ), ( 0, 90, 0 ) );        // bunker moss, S wall (clear of the D1 strip x112)
    return n;
}

// ---- L3 M6 additions (Corruption Bloom - the bloom itself) ------------------
// custom_ghost_armory_alien_* are M6-added derived GDT entries (alien_ghost.gdt,
// alien_plus bins; their mtl_armory_alien_* materials shipped registered).
function spawn_m6_l3()
{
    n = 0;
    n += spawn_prop( "custom_ghost_armory_alien_tentacles_01", ( -780, 1810, -719.5 ), ( 0, 0, 0 ) );   // WALL-mount tentacle mass, W wall S corner (wraps the SW spore rock) [clip m6_l3_tent1]
    n += spawn_prop( "custom_ghost_armory_alien_tentacles_02", ( 500, 1950, -497 ), ( 0, 0, 180 ) );    // flat tentacle splat on the CEILING, E bay (30 deep, 193 above the floor - no clip)
    n += spawn_prop( "custom_ghost_armory_alien_egg_01", ( -650, 2060, -706.5 ), ( 0, 0, 0 ) );    // egg nest, W bay N corner [clip m6_l3_egg1]
    n += spawn_prop( "custom_ghost_armory_alien_egg_01", ( -560, 2110, -706.5 ), ( 0, 120, 0 ) );  // egg nest (yaw 120) [clip m6_l3_egg2]
    n += spawn_prop( "custom_ghost_armory_alien_egg_01", ( -690, 2140, -706.5 ), ( 0, 240, 0 ) );  // egg nest vs the N wall [clip m6_l3_egg3]
    n += spawn_prop( "custom_ghost_alien_tall_grass_01", ( 450, 1750, -710.5 ), ( 0, 40, 0 ) );    // alien grass clump, S wall E (walk-through)
    n += spawn_prop( "custom_ghost_alien_tall_grass_01", ( -250, 1760, -710.5 ), ( 0, 200, 0 ) );  // alien grass clump, S wall W
    n += spawn_prop( "custom_ghost_alien_weeds01", ( 620, 2150, -718.7 ), ( 0, 10, 0 ) );          // weed tuft, N wall base
    n += spawn_prop( "custom_ghost_alien_weeds01", ( 760, 1950, -718.7 ), ( 0, 140, 0 ) );         // weed tuft, E wall base
    n += spawn_prop( "custom_ghost_alien_weeds01", ( -140, 1730, -718.7 ), ( 0, 260, 0 ) );        // weed tuft, S wall base
    return n;
}

// ---- L4 M6 additions (Specimen Vault - what they DID down here) -------------
// The two ceiling GLO-SPROUTS are the locked plan's Phase-0 emissive proof: the
// model's own mtl_dct_alien_plant_glo_sprout is lit_emissive_advanced with a
// dedicated _em map (same emissive class as the PROVEN L3 boils panel), placed
// in clear view from the Gantry deck. Ceiling mounts = roll 180.
function spawn_m6_l4()
{
    n = 0;
    n += spawn_prop( "custom_ghost_alien_plant_ceil", ( 300, 1900, -737 ), ( 0, 0, 180 ) );        // EMISSIVE GLO-SPROUT #1, ceiling E bay - clear view from the Gantry
    n += spawn_prop( "custom_ghost_alien_plant_ceil", ( -300, 2060, -737 ), ( 0, 90, 180 ) );      // EMISSIVE GLO-SPROUT #2, ceiling W bay N
    n += spawn_prop( "p8_zm_off_pig_slab", ( -640, 1940, -959.2 ), ( 0, 0, 0 ) );                  // butcher slab, W-bay lab row [clip m6_l4_pigslab]
    n += spawn_prop( "p8_zm_whi_mannequin_male_01_head", ( -638, 1925, -936.2 ), ( 0, 320, 0 ) );  // severed mannequin head ON the pig slab (tiny - no clip)
    n += spawn_prop( "p8_zm_whi_mannequin_male_01_standing", ( 620, 1745, -960 ), ( 0, 15, 0 ) );  // specimen mannequin, S wall E of the vessel [clip m6_l4_mannequin]
    n += spawn_prop( "p8_zm_off_metal_hook", ( 300, 2011, -852 ), ( 0, 180, 0 ) );                 // meat hook on the Gantry deck front face (flush, no clip)
    n += spawn_prop( "p8_zm_off_metal_hook", ( 340, 2011, -858 ), ( 0, 160, 0 ) );                 // meat hook #2, lower
    n += spawn_prop( "p8_zm_whi_door_wood_01_bloody", ( -757, 2100, -960 ), ( 0, 90, 0 ) );        // bloody door leaned flush on the W wall (12u - flush art, no clip)
    return n;
}

// ---- L5 M6 additions (The Maw - the infection's heart) ----------------------
// hive/dead_queen/dead_brutes are STATIC corpse/set-piece models (never AI).
function spawn_m6_l5()
{
    n = 0;
    // flesh hive REMOVED (user 2026-07-26): it sat at (260,2105) - INSIDE the D4 stair landing
    // (the spot l5_column was already moved off of 2026-07-13) - and its clip + m6_l5_brute1's
    // pinched every exit from the final stairs shut (map uncompletable). The D4 landing
    // (x[112,~420] x y[1956,2173] on L5) is a KEEP-CLEAR; re-home the hive south/center if the
    // Maw ever needs its heart back.
    n += spawn_prop( "custom_ghost_dead_queen_1", ( -430, 2115, -1180 ), ( 0, 0, 0 ) );      // dead alien queen corpse, W bay N [clip m6_l5_queen]
    n += spawn_prop( "custom_ghost_dead_brute_1", ( 170, 1990, -1185.5 ), ( 0, 70, 0 ) );    // dead brute corpse near the hive [clip m6_l5_brute1]
    n += spawn_prop( "custom_ghost_dead_brute_2", ( 760, 1990, -1183.6 ), ( 0, 90, 0 ) );    // dead brute sprawled vs the E wall pocket [clip m6_l5_brute2]
    n += spawn_prop( "custom_ghost_alien_plant_ceil", ( 0, 1950, -977 ), ( 0, 0, 180 ) );    // glo-sprout on the ceiling, room center
    n += spawn_prop( "custom_ghost_alien_plant_ceil", ( 500, 1800, -977 ), ( 0, 180, 180 ) );// glo-sprout on the ceiling, SE
    n += spawn_prop( "p8_zm_whi_spawner_hole_01", ( 250, 1800, -1192.6 ), ( 0, 0, 0 ) );     // fleshy spawner hole FLAT on the floor (11u walkable plate - no clip)
    return n;
}

// =============================================================================
// SOUL-DEFEAT DIM LIGHTS (user 2026-07-12): each abyss floor stays DARK while
// you grind its soul door; when the door fills ("you defeated the floor"), dim
// lights wake up on that floor. Called by _acc_abyss_doors::open_soul_door
// (layers 2-4) and the Paradise-gate open (layer 5). L1 (the trench) is
// already lit - no call for it.
//
// MECHANISM - NO baked lights (they were the 2026-07-12 first-frame CTD and the
// abyss is pitch-black by user decision): each "lamp" = a small emissive cage
// fixture model on the wall + an invisible tag_origin glow host driven through
// the PROVEN client glow pipeline (acc_perk_lights::set_glow -> the csc renders
// the FX; server-side PlayFX does NOT render in this build, see
// _acc_perk_lights.gsc). Glow index 14 = the stock lantern OMNI (full-bright,
// UN-CULLED, radius 125) - a REAL dynamic light that casts on the walls/floor.
// (First cut used index 13 = the 40%-dimmed, distance-culled loot glow: it lit
// the lamp but NOT the room - user 2026-07-12 "the lights don't light the area".
// Index 14 is the same ClientSide-omni engine path the map runs on every perk
// glow = proven CTD-safe, NOT the baked-light crash path. Research: docs/30 +
// the abyss-event-lighting workflow.)
// =============================================================================
function floor_lights_on( layer )
{
    if ( layer < 2 || layer > 5 ) return;
    if ( !isdefined( level.acc_floor_lights_done ) ) level.acc_floor_lights_done = [];
    if ( IS_TRUE( level.acc_floor_lights_done[ layer ] ) ) return;   // once per floor
    level.acc_floor_lights_done[ layer ] = true;

    fz = -240 * layer;          // floor z (L2 -480 .. L5 -1200)
    lz = fz + 190;              // CEILING-adjacent (ceiling = fz+224) so the omni washes DOWN into
                               // the bay (a wall-hugged omni throws half its sphere behind the wall).

    // 6 BAY-CENTERED lamps (user 2026-07-13: 4 wall lamps read too dim/patchy) - 3 down each bay's
    // midline (y=1948), clear of the center stairwell x[-112,112]. All at y1948 (the room mid), so
    // clear of the L4 Gantry deck (y[2013,2173]), the L5 Paradise doorway (S wall) + Overlook
    // (x[-781,-621]; -680 is at its E edge but 190u UP, above the deck top -1120). The lamps are the
    // fixture texture; the per-player lit VISION grade does the whole-room brighten.
    n = 0;
    // Midline row (y1948):
    n += spawn_lamp( ( -680, 1948, lz ), ( 0, 0, 0 ) );   // W bay
    n += spawn_lamp( ( -446, 1948, lz ), ( 0, 0, 0 ) );   // W bay center
    n += spawn_lamp( ( -212, 1948, lz ), ( 0, 0, 0 ) );   // W bay (near stairwell)
    n += spawn_lamp( (  212, 1948, lz ), ( 0, 0, 0 ) );   // E bay (near stairwell)
    n += spawn_lamp( (  465, 1948, lz ), ( 0, 0, 0 ) );   // E bay center
    n += spawn_lamp( (  715, 1948, lz ), ( 0, 0, 0 ) );   // E bay
    // + 4 DEPTH fillers (user 2026-07-13 "a bit brighter") - S/N rows fill the 450u depth + add
    // overlap for a brighter room. candle_ramses is no-shadow so extra lamps stay cheap.
    n += spawn_lamp( ( -450, 1800, lz ), ( 0, 0, 0 ) );   // W bay, S row
    n += spawn_lamp( (  450, 1800, lz ), ( 0, 0, 0 ) );   // E bay, S row
    n += spawn_lamp( ( -450, 2095, lz ), ( 0, 0, 0 ) );   // W bay, N row
    n += spawn_lamp( (  450, 2095, lz ), ( 0, 0, 0 ) );   // E bay, N row

    acc_utility::log( "abyss floor lights ON (layer " + layer + ", " + n + " lamps)" );
}

// Per-player LIT vision on a DEFEATED floor (user 2026-07-13, the primary brightener). A player
// standing on a floor whose soul door is filled (floor_lights_on -> acc_floor_lights_done[layer])
// renders the lit exposure grade via the server per-player vision override (stock precedent
// _qrdrone.gsc); players deeper on an UNdefeated dark floor keep the global (dark) vision. The
// global naked slot is ONE slot and can't do per-floor, so this per-player override is the
// coop-correct scoping. Poll ~0.35s; only re-blends on a state change. Live: acc_abyss_lit_grade.
function abyss_floor_vision_watcher()
{
    level endon( "end_game" );
    for ( ;; )
    {
        players = GetPlayers();
        for ( i = 0; isdefined( players ) && i < players.size; i++ )
        {
            p = players[ i ];
            if ( !isdefined( p ) || !isplayer( p ) ) continue;

            layer = acc_bus_trench::underground_layer( p.origin );
            lit   = ( layer >= 2 && layer <= 5 && isdefined( level.acc_floor_lights_done ) &&
                      IS_TRUE( level.acc_floor_lights_done[ layer ] ) );
            want  = ( lit ? layer : 0 );

            if ( !isdefined( p.acc_abyss_lit_layer ) ) p.acc_abyss_lit_layer = -1;
            if ( want == p.acc_abyss_lit_layer ) continue;   // no state change -> no re-blend
            p.acc_abyss_lit_layer = want;

            if ( want > 0 )
            {
                grade = getdvarstring( "acc_abyss_lit_grade", ACC_ABYSS_LIT_VISION_DEFAULT );
                if ( grade == "" ) grade = ACC_ABYSS_LIT_VISION_DEFAULT;
                p UseServerVisionSet( true );
                p SetVisionSetForPlayer( grade, 1.0 );   // 1s ease-in "the lights come up"
            }
            else
            {
                p UseServerVisionSet( false );           // back to the global naked slot
            }
        }
        wait 0.35;
    }
}

// One lamp = the tiny emissive cage fixture + a dim-amber client glow host at it.
function spawn_lamp( origin, angles )
{
    fixture = spawn( "script_model", origin );
    if ( !isdefined( fixture ) ) return 0;
    fixture SetModel( "p7_zm_ctl_light_cage_emissive" );   // 3.6x3.6x7.6 cage lamp (carved, zone-listed)
    fixture.angles = angles;

    // The glow: same idiom as the soul-flight orb (_acc_abyss_doors::spawn_soul_light) -
    // an invisible tag_origin host + the accPerkGlow clientfield, index 13 = DIM AMBER.
    host = spawn( "script_model", origin );
    if ( isdefined( host ) )
    {
        host SetModel( "tag_origin" );
        acc_perk_lights::set_glow( host, 15 );   // 15 = the BRIGHTER (radius 350) omni; 14 = the smaller r125 one (user 2026-07-13 "still too dim")
    }
    return 1;
}

// Returns 1 on success, 0 on a dead spawn (guarded - spawn() CAN return undefined).
function spawn_prop( model, origin, angles )
{
    m = spawn( "script_model", origin );
    if ( !isdefined( m ) )
        return 0;
    m SetModel( model );
    m.angles = angles;
    return 1;
}
