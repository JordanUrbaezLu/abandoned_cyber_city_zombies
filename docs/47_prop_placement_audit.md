# 47 - Prop Placement & Orientation Audit (2026-08-03)

> **User directive:** "I want to do one big audit on how the models are placed and what models
> are placed at each area. I'm now focusing on design consistency and orientation... a lot of
> the models orientation and placement don't make too much sense... We have chairs scattered
> around not really making sense on why they are placed where they are... We can take our time
> and deliver a product that really makes sense and is coherent to the players. We do need to
> be careful about overlapping models."

**Scope:** every placed prop in the map — 734 baked `misc_model` entities + 60 script-spawned
deco/station models — audited by 8 parallel area agents with environment-artist judging rules
(seating faces something; signs/screens face approaches; vehicles align with parking geometry;
storage backs against walls; queues lead somewhere; clutter tells a story; no interpenetration;
no floating/sunken pivots; yaw values off the 15° grid are suspect unless a chaos story is
documented).

**Result: 98 findings** — 28 **HIGH** (data-proven: interpenetrations, mismatched twins, wrong
display models, orphaned-by-compression props), ~44 **MEDIUM** (strong smell, but the mesh's
front axis is unrecorded — the map stores yaw, not which side is the "front"), ~24 **LOW**
(needs one in-game glance). By kind: **48 orientation**, 12 rotation-smell (copy-paste yaw-0
grids), 11 placement, 10 floating/z, 8 intersection, 5 out-of-theme, 4 grouping.

## Headline catches

1. **The Plaza frag wallbuy carried a MONKEY BOMB display model** (entity 9006 @
   (-250,718,53)). *(Phase A verify-pass correction: this was DORMANT data, not a live bug —
   `spawn_acc_wallbuy_models()` was disabled 2026-06-24 and only the chalk renders, so players
   never saw it. Fixed anyway to `wpn_t7_grenade_frag_world` so a future re-enable can't
   resurrect the monkey. Also learned: the linker never validates struct model keys — a wrong
   name here can NEVER be caught by a build.)*
2. **Compression orphans** in Lab + Paradise (props left inside the 2026-08-02 shrink walls or
   outside the new playable bounds) — see those sections.
3. **The "first-pass yaws" debt is real and systemic:** `spawn_plaza()`'s own comment says
   *"yaws are first-pass — flip any backward-facing prop after the walk"* and that walk never
   happened. Most MEDIUM orientation findings trace to this: mirrored pairs are self-consistent
   but the front axis was never verified in-game (benches, the fountain angel, the dead neon
   sign, vending faces).
4. **Copy-paste yaw-0 grids** (the "scattered without sense" read): e.g. all 4 Plaza cache
   crates at identical yaw 0 — deliberate scatter needs deliberate rotation variance.

## The fix plan (deliberate, per-area — not one mega-sweep)

- **Phase A — apply the HIGH batch** (28 fixes, data-proven, no aesthetic judgment): wrong
  display model, twin mismatches, interpenetrations, orphans, floating pivots. One .map+GSC
  pass + FULL build (LED gate), verified with the same overlap/riser rigor as the 2026-08-03
  riser fixes (memory `riser-clearance-standard-and-verify-method`).
- **Phase B — the walkabout checklist:** the MEDIUM/LOW front-axis questions compressed into
  one in-game route (spawn → Plaza fixtures → Bus Station → Alley/Market → trench rooms →
  Abyss → Lab → Paradise). Each stop is a yes/no ("does the angel face you at spawn?"); the
  answers convert ~60 MEDIUM/LOW findings into exact yaw flips.
- **Phase C — per-area RECOMPOSITION** (the real "coherent product" work), Plaza first: use
  each section's *Coherence read* as the brief — seating groups that face the fountain/walk
  lanes, clutter that tells the evacuation story, queue lines that lead to the teller windows.
  One area per pass, each with its own bake + in-game review before the next.

**Every proposed move in this doc was written against the safety rails:** ≥45u to riser/dog
spawner structs, no new interpenetration, walk lanes kept open (`difficult-navigation` rule:
narrow deliberately, never seal). Re-verify on application anyway — three verification rounds
on the riser fixes proved hand-checked positions lie.

---
## Spawn Plaza + Plaza→Alley connector

**Props audited:** 42 baked / 7 script-spawned. **Issues:** 12.

**Coherence read:** The plaza tells a genuinely coherent, documented story - "the city's front door: a once-grand memorial plaza gone to seed" - and the grouping supports it well: hero angel fountain as an off-center island, iron-fenced planter beds gone wild on the W/N walls, two bench rows around the fountain, bollard lines that lead to (not block) both exit mouths, parking-stop hints on the S edge, overgrowth in pavement seams, and p7 cyber accents (blue LED strips, dead neon) layering the map's cyber identity over the classical bones. Stations are sensibly sited (LB terminal backing the S wall facing in, QR machine backing the W wall facing east, overclock terminal on the documented ex-Exo spot). What would elevate it: (1) actually run the facing-verification walk the deco pass's own comment promised ("yaws are first-pass - flip any backward-facing prop") - the fountain, benches, and neon sign all ride unverified front axes; (2) dress the bare Plaza->Alley connector so the density gradient into the Alley reads as intentional; (3) give the four "scattered" cache crates rotation variety so cover reads organic; (4) fix the one flat-out asset lie (monkey bomb model on the frag wallbuy).

**Top 5 most player-visible:**

- Frag wallbuy on the N spawn wall displays a MONKEY BOMB world model - every player sees the wrong weapon on the wall (swap entity 9006's model to a frag world mesh)
- Rampage breaker on the Alley path (1020,412) is 50/50 backwards - its own code comment says flip yaw 180->0 if the panel back faces the corridor; never verified
- All 4 bench yaws + the fountain angel + the dead neon sign ride unverified front axes (deco comment admits 'yaws are first-pass') - one in-game walk could reveal both bench rows facing away from the fountain and an edge-on sign
- Lone iron picket at (-440,240) interpenetrates the first NW bollard at (-438,250) - clips provably overlap; nudge picket to y215
- The 4 'scattered' Data Cache crates all spawn at identical yaw 0 (spawn_cache_at sets no angles) - an axis-aligned copy grid in the spawn room; give each a 15-20 degree yaw offset

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] wpn_t7_zmb_monkey_bomb_world (frag_grenade wallbuy display)** @ (-250, 718, 53) yaw 180 — *out-of-theme*
   - Problem: The FRAG GRENADE wallbuy (entity 9005, zombie_weapon_upgrade=frag_grenade) displays a MONKEY BOMB world model (entity 9006). Players on the N wall of the spawn room see a monkey bomb but buy frags - a misleading purchase read at eye level in the highest-traffic room.
   - Fix: Swap entity 9006's model to a frag world mesh (verify installed asset name, e.g. the t7 frag world model used by the weapon table; stock chalk t7_zm_chalk_buy_frag also exists per the KB chalk list and could be added on the wall face). Keep origin (-250,718,53) and yaw 180.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map entity 9005/9006 (~L10280-10299)`
2. **[H] t10_fence_plaza_iron_01_single_a (lone picket) vs t10_street_bollard_01** @ (-440, 240, 0) yaw 90 — *intersection*
   - Problem: The lone iron fence picket abuts/overlaps the first NW bollard at (-438,250): clip boxes overlap (picket x[-442,-438] y[236,244] vs bollard x[-445,-431] y[243,257]) and the meshes are ~10u center-to-center - a classical picket welded against a street bollard reads as accidental clutter collision.
   - Fix: Move the picket to (-440, 215, 0), yaw 90 unchanged - opens a ~21u gap while keeping it as the derelict tail of the W planter-bed fence run (bed clip ends y~195). Update the plaza_picket clip in add_prop_clips.js and the misc_model at .map ~L22020 + the spawn_plaza() twin (L770). Riser check: nearest start_zone_spawners risers (-350,110) and (-227.5,492) are >130u away - clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map ~L22020 + tools/add_prop_clips.js L325/L330`
3. **[M] p7_zm_ver_powerbreaker (rampage breaker station)** @ (1020, 412, 0) yaw 180 — *orientation*
   - Problem: The breaker slab's panel normal is on the thin +/-y axis and the corridor is entirely NORTH of it (S face is 4u off the y=400 wall). The code comment itself flags the 50/50: 'if the in-game look shows the slab's BACK to the corridor, flip this to 0'. Front axis was never verified in-game - every walk to the Alley passes this prop.
   - Fix: Verify in-game which face shows; if the panel back faces the corridor, set ACC_RAMPAGE_YAW 180 -> 0 (origin unchanged).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_rampage.gsc:59`
4. **[M] t10_street_bench_iron_ornate_01 (x4, both rows)** @ row A (-220,10,0) & (-140,10,0); row B (-120,335,0) & (30,335,0) yaw row A 90, row B 270 — *orientation*
   - Problem: Design intent is both rows face the fountain island at (-40,130), and the yaws are self-consistent (mirrored 90/270), but the bench mesh's front axis was never verified - spawn_plaza()'s own comment says 'yaws are first-pass - flip any backward-facing prop after the walk' and no plaza flip pass is recorded. If the bench front is -x native instead of +x, BOTH rows face away from the fountain toward blank floor/walls - the classic wrong-way-bench read in the most-seen room.
   - Fix: Verify one bench in-game. If backward: row A 90 -> 270 and row B 270 -> 90 (flip all 4; clips are yaw-symmetric 68x34 boxes so no clip regen needed). Edit .map ~L22072-22111 + spawn_plaza() L778-781.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_surface_deco.gsc:756,777-781 + map ~L22072`
5. **[M] p7_cai_stacking_cargo_crate (4 Data Cache crates)** @ (-320,30,0), (80,230,0), (-80,560,0), (-360,460,0) yaw 0 (all four - spawn_cache_at never sets angles) — *rotation-smell*
   - Problem: The layout doc calls these '4 SCATTERED cargo-crate caches as low cover', but all four 64x64 crates spawn at identical yaw 0 (spawn_cache_at sets no .angles), producing an axis-aligned copy-paste grid read across the whole room.
   - Fix: Add a yaw arg to spawn_cache_at and set crate.angles per cache: cache_1 yaw 15, cache_2 yaw 350, cache_3 yaw 20, cache_4 yaw 345 (small offsets keep the rotated AABB ~72u, only slightly proud of the exact-64x64 nav clips; the crate self-collides via its _col LOD so player/zombie collision follows the mesh regardless). Origins unchanged - all four keep >45u riser clearance as today.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc:275-282 + zm_abandoned_cyber_city.gsc:606-609`
6. **[M] p7_sin_signage_3d_text_01_white_neon (dead neon sign)** @ (0, 718, 130) yaw 180 — *orientation*
   - Problem: Wall-mounted 2u off the N wall (y=720 plane) which faces SOUTH (-y). Yaw 180 only faces -y if the sign's native front is +y; the sibling p7 pack wall-mounts in this same pass (p7_sky_light LED strips) use the +x-native convention (yaw 0 on the W wall / 180 on the E wall), and if this sign is also +x-native, yaw 180 turns the text edge-on into the wall - an invisible/sideways sign crowning the N planter bed.
   - Fix: Verify in-game; if the text is edge-on, set yaw 270 (rotates a +x-native front to -y/south). Edit .map ~L22423 + spawn_plaza() L817. Walk-through wall mount - no clip impact.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_surface_deco.gsc:817 + map ~L22423`
7. **[M] t10_com_parking_block_grey01 (W block)** @ (-428, -150, 0) yaw 90 — *placement*
   - Problem: Labeled 'parking block W row' but at yaw 90 its 80u run is along X - PERPENDICULAR to the W wall (x=-470) it serves, while the two S-row twins at (-90,-215)/(0,-215) correctly run parallel to their S wall. A wheel stop for a W-wall stall should parallel the wall (run along Y). Note the QR pad ledger documents it as the 'pblock step-over S' of the Quick Revive machine, so it is load-bearing for that clearance note.
   - Fix: Move it to join the S row line: (-428, -215, 0), yaw 90 unchanged (spans x[-468,-388], parallel to the S wall, west of the implant-door approach x[-280,-160] which stays clear; QR front span y[-144,-20.9] untouched). Update plaza_pblock_1 clip + the docs/02 QR pad ledger note. Riser check: nearest riser (-350,110) is >300u - clear.
   - Source: `tools/add_prop_clips.js:339 + _acc_surface_deco.gsc:797 + docs/02_layout.md pad ledger L487`
8. **[H] p7_sky_light_led_01_b_blue (E-wall pair)** @ (212, 150, 150) and (212, 330, 155) yaw 180 (both) — *placement*
   - Problem: The two identical LED strips on the same E wall are mounted at different heights (z150 vs z155) while the W-wall pair are both exactly z150 - a 5u mount mismatch between twins on one wall reads as a placement slip at eye level.
   - Fix: Set (212, 330, 155) -> (212, 330, 150). Edit .map ~L22475 + spawn_plaza() L821. Walk-through wall mount - no clip.
   - Source: `map ~L22462-22475 + _acc_surface_deco.gsc:820-821`
9. **[L] t10_decor_shaftesbury_memorial_fountain_angel (hero fountain)** @ (-40, 130, 0) yaw 180 — *orientation*
   - Problem: Intent is 'angel faces spawn' (spawn band is SOUTH at y[-190,-30]); yaw 180 achieves that only if the angel's native front is +y. Unverified front axis on the single most-seen hero prop in the map, and the pass's own comment says facings were never walked.
   - Fix: Verify in-game on first load (she's straight ahead of the spawn band). If she faces the N wall instead, flip yaw 180 -> 0. Origin unchanged; clip is near-symmetric (43x72) so no clip regen for a 180 flip.
   - Source: `_acc_surface_deco.gsc:762-763 + map ~L21955`
10. **[L] dlc_weapon_mystery_box_01_static / AW 3D-printer swap (acc_box_plaza)** @ (100, -150, 0) yaw 270 — *orientation*
   - Problem: Yaw 270 points the box's front toward the S wall (90u away) while all player approach is from the spawn band immediately NORTH (spawn points y[-130,-90]) and west. If the printer's door/screen face is on that front axis, players load in staring at the machine's back. Gameplay prop - orientation check only, do NOT move it.
   - Fix: Verify the AW printer's display face in-game; if it faces south/away, set the acc_box_plaza struct + static model yaw 270 -> 90 and re-run tools/align_box_clips.js (mystery-box memory: clips must be re-aligned after any box change).
   - Source: `map L17321 + docs/02_layout.md L212-213`
11. **[L] t10_foliage_flower_camomile_planter_box_long_group_01_b (N bed)** @ (45, 700, 0) yaw 0 — *rotation-smell*
   - Problem: In the N planter bed the hollyhock box needed yaw 90 to run parallel to the N wall, but the camomile beside it uses yaw 0 - yet in the W bed the camomile_a variant at yaw 0 runs along Y. The merged bed clip (128x36, generator bounds-measured) implies variant _b is X-native so it is PROBABLY fine, but a long planter jutting perpendicular from the wall would be an obvious wrong if the bounds data was stale.
   - Fix: In-game glance at the N bed; if the camomile box sticks south out of the bed, set yaw 0 -> 90 (matching the hollyhock treatment) and regen the plaza_bed_n clip via gen_plaza_layout.js.
   - Source: `_acc_surface_deco.gsc:773-775 + tools/add_prop_clips.js:324`
12. **[H] (entire connector corridor - absence)** @ x[213,1175] y[400,656] yaw n/a — *grouping*
   - Problem: The ~950u Plaza->Alley connector contains ZERO baked deco (verified by coordinate sweep) - only the script-spawned rampage breaker at (1020,412) and a door-eave drip FX. It is a bare greybox tube sandwiched between the dressed plaza and the deliberately dense Alley, so the transition breaks the visual story exactly where every Alley run happens.
   - Fix: Light continuation pass (follow-up batch, not a single fix): 2-3 props from the kits already zoned - e.g. a t10_street_bollard_01 pair at the plaza mouth (~x260/300, y470) echoing the NE bollard line, and one Alley-kit wall electric/litter piece near the breaker to foreshadow the red-hazard Alley. Every placement needs the >=45u riser check against start_zone_spawners before adding.
   - Source: `map coordinate sweep (0 misc_model hits in connector bounds) + _acc_rampage.gsc:56`
   - PLACED 2026-08-03 (connector density-gradient pass, 10 baked props): W-mouth classical fade on the S wall (bollard pair x260/x315 echoing the NE line + dead stone planter x390 + weeds patch) -> mid-corridor litter drift + blue LED strip (x620, the plaza z150 accent) -> E red-hazard cluster feeding the breaker (electric set x760, 256u wire-bundle run x[722,978] ending 4u off the slab, biohazard sign x1105 at the door; the planned red cage beacon was CUT - see the LED-crash note in CHANGELOG, a 2nd baked instance of p7_zm_asc_light_cage_warning_red crashes the lighting compiler). Clips: add_prop_clips.js `plaza_conn_*` x3 (bollards flat, planter gabled). All risers >=130u from every clip edge; N walk lane untouched (>=189u); everything clear of the enter_alley trigger x1175 and the breaker's r64 use trigger.

---

## Bus Station (corp)

**Props audited:** 123 baked / 0 script-spawned. **Issues:** 11.

**Coherence read:** The zone tells an unusually well-documented story (surface_deco header: derelict inter-city bus terminal, the E-W trench doubling as the sunken BUS BAY): ticket office with vault-booth + teller counter + ajar door (yaw 202 is deliberate), a bench concourse meant to face a departure board, a boarding queue, baggage-claim spill, staff corner, restroom nook, diner, maintenance/debris corner, and nature-reclaim trees with leaf litter (all deliberate per comments). The QUEUE STORY the task asked about checks out: the south stanchions form a funnel - a 4-post wide mouth at the seating aisle (y1614, x[-180,140]) narrowing to 2 posts (y1662, x[-100,60]) that discharges at the S bay rim y1703, reinforced by the parking-block bay-rim markers, cones, barrier, and quarantine fence; the north 2x2 posts form two N-S columns leading the lounge to the N rim - both lead somewhere real. What undermines the story is exactly what the header predicted ('yaws are first-pass - flip any backward-facing prop after the walk' - that walk never happened): the room's centerpiece TV board faces the wall, the staff lockers face the wall, the stove ignores its diner, plus one genuine two-pass interpenetration (sink vs arrivals TV). Fixing the four facing bugs + the sink collision elevates the whole zone at near-zero risk since every proposal is a yaw flip or short slide. The 12 z=-240 under-room props (p7_rus foundry/reactor kits + trench box) were spot-checked: all documented, height-checked, and convention-correct - no issues. Process note: props are baked misc_model statics with dormant GSC twins (acc_surface_deco dvar defaults 0, hence props_scripted=0); every fix must edit the .map AND the GSC twin in lockstep, clip moves go through tools/add_prop_clips.js, geometry/clip changes need a FULL LED-bake build (not -GscOnly), and each proposed origin move still needs the >=45u corp riser/dog spawner check before commit.

**Top 5 most player-visible:**

- Departure-board TV bank (3 TVs + stands, y1210) faces INTO the S wall - the 6 bench rows designed to watch it stare at TV backs; flip to yaw 180
- Standing sink and arrivals TV stand interpenetrate at (-560,2708)/(-560,2712) - clip boxes overlap 17u; move sink to the restroom nook (-665,2704) yaw 0
- Staff lockers (one OPEN) face their doors into the E wall 3u away while all 7 neighbors face the room; yaw 90->270 + slide flush to x781
- Holo departures board (0,1235,228) hangs edge-on (yaw 90) to the entire seating concourse it serves; yaw 180
- Diner stove sits customer-side facing away from its own counter (and the lounge armchair faces away from the bay its benches watch); stove to E wall yaw 270, chair yaw 0

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_zm_tra_tv_vintage_on + p7_zm_tra_monitor_support_02 (x3 pairs, DEPARTURE BOARD)** @ (-120,1210,33)/(0,1210,33)/(120,1210,33) + stands at z0 yaw 0 — *orientation*
   - Problem: The pack's wall-facing convention is proven across four walls (please_wait sign: S wall=180/N wall=0; sconces S=180/N=0/E=270; vault-zone monitor_support on W wall=90) => front axis is local -Y at yaw 0. At yaw 0 all 3 departure-board TVs and stands face SOUTH into the S wall 42u away, showing their backs to the 6 bench rows that the design brief says face them ('a DEPARTURE BOARD of vintage TVs the 3 bench rows face'). The N-wall arrivals TV at (-560,2712) yaw 0 correctly faces the room, confirming the S bank is the flipped one. Header even warns 'yaws are first-pass - flip any backward-facing prop after the walk'.
   - Fix: Flip all 6 entities to yaw 180, origins unchanged (mesh is clip-centered, no shift needed): 3x tv_vintage_on + 3x monitor_support_02 at x=-120/0/120, y=1210. Edit both the .map misc_models (lines 18141-18206) and the GSC twins in lockstep.
   - Source: `map lines 18141-18206; _acc_surface_deco.gsc:192-197`
2. **[H] p7_zm_tra_sink_standing vs p7_zm_tra_monitor_support_02/tv_vintage_on** @ sink (-560,2708,0); TV stand (-560,2712,0) yaw sink 180 / TV 0 — *intersection*
   - Problem: Two floor-standing props 4u apart: the restroom-nook group's standing sink and the arrivals-board TV stand were placed by different passes at the same spot. Their own clip boxes prove it: sink x[-574,-546] y[2697,2719] vs TV x[-573,-547] y[2702,2722] = full-x, 17u-deep interpenetration over the same z range. Bonus: the sink's yaw 180 points its front (+Y after flip) into the N wall 20u away.
   - Fix: Move the sink to the restroom nook edge it belongs to: (-665,2704,0) yaw 0 (front faces south into the hall, back to the N wall; clear of urinal/mirror at x<=-747 and the bench at (-500,2716)). Update its bus_sink_standing clip via add_prop_clips.js and re-check >=45u to corp risers before committing.
   - Source: `map lines 18687 + 18856-18869; _acc_surface_deco.gsc:246,265-266; add_prop_clips.js:207,218`
3. **[H] p7_rus_locker_open + p7_rus_locker_closed (staff corner)** @ (796,1520,0) and (796,1488,0) yaw 90 — *orientation*
   - Problem: Every other prop on the E wall uses yaw 270 to face west into the room (desk, timecard rack, fridge, both payphones, both sconces). The lockers use 90: un-rotating their measured clip offsets (open: world center (787,1508.8) => mesh spans local x[-25.2,2.8], y[0,18]) shows the bulk sits behind the origin with the door face pointed +X at yaw 90 - i.e. the locker doors (one visibly OPEN) face the E wall plane 3u away. Unreadable and unusable-looking.
   - Fix: Rotate both to yaw 270 and shift west so the mesh lands flush instead of inside the wall: locker_open (796,1520)->(781,1498) yaw 270; locker_closed (796,1488)->(781,1466) yaw 270 (mesh back edge at x799 wall plane, doors facing the staff desk). Re-run add_prop_clips.js for bus_m4_locker_* and riser-check the new footprints.
   - Source: `map lines 19168-19181; _acc_surface_deco.gsc:314-315; add_prop_clips.js:487-488`
4. **[H] p7_zm_tra_stove_kitchen (diner)** @ (702,2600,0) yaw 90 — *placement*
   - Problem: The kitchen stove sits freestanding 97u off the E wall on the CUSTOMER side of the diner (south of the stools at y2648), with its cooking face pointed +X at the E wall - proven by the market-zone twin at (-2103,1385) yaw 90 which correctly faces +X into the room from a W wall. Here it turns its back on its own counter; a stove belongs behind/beside the counter against a wall.
   - Fix: Move to (775,2695,0) yaw 270: flush on the E wall (mesh x[760,790], 9u gap) forming an L-kitchen at the counter's east end, facing west toward the stools; clears the debris pile clip at (735,2660). New clip via add_prop_clips.js + riser check.
   - Source: `map line 18752; _acc_surface_deco.gsc:253`
5. **[M] p7_spa_signage_hologram_departure** @ (0,1235,228) yaw 90 — *rotation-smell*
   - Problem: The ceiling-hung holo departures board crowns the TV board and serves the bench concourse to its north, but at yaw 90 its long face runs N-S - edge-on to every viewer in the seating, and perpendicular to the E-W TV row it floats over. p7_spa front axis is unverified (different pack from p7_zm_tra), hence not high.
   - Fix: Yaw 90 -> 180 (long axis E-W matching the TV row, face north toward the benches). No clip (overhead). Verify facing in-game once - if the spa pack's front is +Y instead, use yaw 0.
   - Source: `map line 19038; _acc_surface_deco.gsc:304`
6. **[M] p7_zm_tra_booth_chair (N departures lounge)** @ (300,2545,0) yaw 180 — *orientation*
   - Problem: The lounge armchair's documented story is 'benches facing the bay' - its two companion benches at (-150,2500)/(150,2500) yaw 0 face south toward the bus-bay trench per the pack convention. At yaw 180 the chair faces NORTH, away from the bay, staring at the diner counter 145u away with its back to its own seating group.
   - Fix: Yaw 180 -> 0 (face the bay like the benches), origin unchanged; clip is near-symmetric (hx14 hy30) so nudge only if the in-game mesh shifts - re-check with add_prop_clips.js.
   - Source: `map line 18635; _acc_surface_deco.gsc:240; add_prop_clips.js:204`
7. **[M] p7_zm_tra_traffic_street_barrier** @ (-470,2360,0) yaw 0 — *placement*
   - Problem: Its comment says 'moved 2026-07-19 with the bus re-park: now flush junk on the coach N flank' - but FIX BATCH 3 re-parked the coach to the true N wall (seal y[2588,2728]), leaving this barrier orphaned mid-floor 228u from the bus S face, spanning nothing (nearest neighbors 200u+). A traffic barrier should span an opening or join a cordon.
   - Fix: Rejoin the N bay-rim cordon it mirrors on the S side (barrier (-430,1658)): move to (-470,2230,0) yaw 0 - 57u off the rim parapet y2173, west of the quarantine fence (150,2210), clear of the W door corridor y[2300,2556] and the rim decals at y2173. Riser check + clip move required. Also fix the stale GSC comment.
   - Source: `map line 18570; _acc_surface_deco.gsc:233`
8. **[L] p7_zm_tra_sign_metal_bank (ticket office)** @ (-450,1248,158) yaw 90 — *rotation-smell*
   - Problem: The BANK sign over the ticket counter reads E-W (blade orientation) while both sibling S-wall signs (please_wait/neon_bar at y1189) use 180 to face the hall. A blade sign perpendicular to the facade is a legitimate read (TranZit hangs it that way off the bank front), but here it hangs OVER the counter mid-booth, not off a facade edge, so approaching players from the benches see it edge-on.
   - Fix: If the flat-face read is wanted: yaw 90 -> 180 (face north over the teller windows, matching please_wait/neon). If the blade read is intended, move it to the booth's east end (-360,1248,158) keep yaw 90 so it flags the office from the hall - needs one in-game look to pick.
   - Source: `map line 18128; _acc_surface_deco.gsc:189`
9. **[L] p7_zm_tra_suitcase_med + p7_zm_tra_suitcase_med_clothes (baggage claim)** @ (648,1580,0) and (560,1578,0) yaw 0 and 0 — *grouping*
   - Problem: Both mid suitcases in the 'spilled luggage' scatter sit at exactly yaw 0 and nearly the same y (2u apart), reading as a placed grid rather than a spill - every other case in both baggage scatters got a scatter yaw (15/20/70/120).
   - Fix: Vary: (648,1580) yaw 0 -> 335; (560,1578) yaw 0 -> 40. Origins unchanged (no clips on suitcases).
   - Source: `map lines 18466-18479; _acc_surface_deco.gsc:223-224`
10. **[L] p7_spa_travel_kiosk_top_blue (SW island)** @ (-470,1520,0) beside btm unit at (-600,1520,0) yaw 180 (btm 0) — *grouping*
   - Problem: The kiosk CANOPY unit sits on the floor at z0 next to its BASE unit, flipped 180 - a two-part model placed as side-by-side halves. Comments call it a deliberate 'island pair', but visually a roof/canopy piece resting on the ground reads as a dismantled kiosk unless wreck dressing sells it.
   - Fix: Either stack it properly: top -> (-600,1520,98) yaw 0 (btm clip top=98, ceiling 240 clears the 88-tall canopy) and delete the bus_m4_travel_kiosk_top floor clip (frees a 130x214 floor patch - riser + lane re-audit needed, near the W stair mouth); or keep the island and add a leaf-litter/rubble patch under the canopy edge to sell 'torn down'. Documented intent = user's call.
   - Source: `map lines 19051-19064; _acc_surface_deco.gsc:305-306; add_prop_clips.js:473-474`
11. **[L] t10_sign_street_usa_no_parking_post_01** @ (430,2205,0) yaw 0 (pitch 0, roll 0) — *rotation-smell*
   - Problem: Comment says 'NO PARKING post LEANED at the N rim parapet' but angles are (0,0,0) - it stands perfectly plumb, contradicting its own abandoned-lean story; a dead-straight street sign indoors reads placed, not derelict.
   - Fix: Angles (0,0,0) -> (6,340,8): slight lean toward the pit with a small off-cardinal yaw. Clip is a 2x7 sliver - unaffected. Purely cosmetic.
   - Source: `map line 19103; _acc_surface_deco.gsc:309; add_prop_clips.js:477`

---

## Alley + Market

**Props audited:** 111 baked / 2 script-spawned. **Issues:** 12.

**Coherence read:** Both zones tell strong, documented stories and are 90% coherent. Market = magenta neon night-market gone to rot: the stall-row loop, kiosk island, diner nook and W-wall signage collage all support it; the taxi-move regression (props embedded in the car) and the four sign/TV yaw errors are exactly the 'orientation makes no sense' reads the user is seeing, all on the highest-traffic W wall and N nook. Alley = red-hazard service gut: dumpster row, scaffold, chainlink weave and litter all group correctly, wall-flush families are consistent except the one E-wall oilrack and possibly one window frame; the two wheelbarrows are the last off-theme rural stragglers. What would elevate: (1) adopt and comment the per-family yaw conventions now derived (p7_zm_tra flat-backs front=-Y: N=0/S=180/W=90/E=270; t10_zm signs face=+Y: N=180/S=0/W=270/E=90) so future passes stop producing lone violators; (2) after any keep-clear-driven prop move (like the taxi riser fix), re-run an overlap check of the moved footprint against neighboring prop clips — that single missed check produced the worst visual in either zone; (3) tie the loose diner furniture (booth chair, x_ rustic table) visibly into the nook so the Market's one soft grouping story firms up.

**Top 5 most player-visible:**

- Market W wall: shelf + wood barrel embedded INSIDE the wrecked taxi (the 07-19 riser move slid the car over them) — worst visual in either zone
- Market W wall: neon bar strip and ice-cream menu board rotated 90 deg (edge-on to the wall) while every sibling sign sits at 270
- Alley E wall: oil-rack shelf faces the wall (yaw 90, sole violator of the map-wide p7 flat-back convention; should be 270)
- Market N wall: ice-cream sign faces INTO the wall (yaw 0, back to the room; should be 180)
- Market: exactly one of the two TVs (live W-counter set vs dead S-table set) has its screen to a wall — one in-game glance decides which gets the flip

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_zm_tra_shelve_oilrack + p7_zm_tra_barrel_wood (vs veh_t7_civ_sedan_cruiser_vista_taxi)** @ (-2102, 680, 0) and (-2100, 760, 25) yaw 90 / 0 — *intersection*
   - Problem: PROVEN by clip data: the taxi's 2026-07-19 +150y move (riser fix, y560->710) put its body footprint x[-2138,-2062] y[616.7,804.7] fully OVER both props — oilrack footprint x[-2118,-2086] y[656,704] and barrel y[743,777] are 100% inside the car. A shelf and a barrel poke through the taxi at eye level on the W-wall lane; their clips (add_prop_clips.js:241-242) also sit inside the taxi clip.
   - Fix: Slide both north into the free W-wall band between the taxi tail (y804.7) and the counter-cabinet clip (y1008): oilrack to (-2102, 860, 0) keep yaw 90; barrel to (-2100, 930, 25) keep yaw 0. Move their .map entities AND the two clip brushes in lockstep. Riser check done: nearest risers (-2066,560)/(-2066,1296) are >=300u from both new spots; W training lane unaffected (props stay wall-flush, depth < taxi's 38 hx).
   - Source: `map L19962/L19975/L20261; _acc_surface_deco.gsc:460-461,485; add_prop_clips.js:241-242,441`
2. **[H] t10_zm_signage_bar_neon_01** @ (-2138, 1062, 190) yaw 0 — *orientation*
   - Problem: Neon bar strip mounted 2u off the W wall at yaw 0 while its three t10_zm sign siblings on the SAME wall at the SAME x (videostore labels, -2139, and the neon bunny, -2134) all use yaw 270. t10_zm sign face = +Y at yaw 0 (derived from the E-wall billboard yaw 90 + W-wall labels yaw 270 agreeing); at yaw 0 this emissive strip is edge-on/perpendicular to the wall, face pointing north along it.
   - Fix: Set yaw 270 (angles "0 270 0"), same as the labels/bunny directly around it. No origin change.
   - Source: `map L20378; _acc_surface_deco.gsc:502 vs 501,504-506`
3. **[H] t10_zm_sign_ice_cream_menu_board** @ (-2139, 1300, 120) yaw 0 — *orientation*
   - Problem: Wall-mounted menu board 1u off the W wall (z120, so wall-hung not floor A-frame) at yaw 0 — same t10_zm family whose face is +Y at yaw 0, so the board sticks perpendicular out of the wall / reads edge-on, unlike every other W-wall t10 sign (all 270).
   - Fix: Set yaw 270 (angles "0 270 0"). No origin change.
   - Source: `map L20469; _acc_surface_deco.gsc:509`
4. **[H] p7_zm_tra_shelve_oilrack** @ (2155, 830, 0) yaw 90 — *orientation*
   - Problem: Alley E-wall oil rack (24.5u off the x=2179.5 plane) uses yaw 90 — the p7_zm_tra flat-back convention (front=-Y at yaw 0; verified by 8 consistent oilrack/power_panel wall placements across Bus N=0, Roof S=180/E=270, Vault W=90, Market W=90) means yaw 90 faces +X, i.e. its shelf front is pressed INTO the E wall and players see its back. It is the sole convention violator in the family.
   - Fix: Set yaw 270 (angles "0 270 0"). No origin change; clip is symmetric enough to keep.
   - Source: `map L19298; _acc_surface_deco.gsc:366 vs 259,460,640,648 & power_panel 560,641,647`
5. **[M] t10_zm_sign_ice_cream_01** @ (-1470, 1452, 140) yaw 0 — *orientation*
   - Problem: Ice-cream sign 4u off the N wall at yaw 0. With the t10_zm face=+Y axis, it faces north INTO the wall (back to the room). Its twin logic: the fastfood sign on the opposite S wall also uses yaw 0 (correct there, facing +Y into the room) — two flat signs on opposite walls cannot share a yaw and both read.
   - Fix: Set yaw 180 (angles "0 180 0"). No origin change.
   - Source: `map L20456; _acc_surface_deco.gsc:508 vs 507`
6. **[M] t10_electronics_television_01_on (paired with t10_electronics_television_01)** @ (-2100, 1060, 38) yaw 90 — *orientation*
   - Problem: The LIVE (emissive) TV on the W counter cabinet is yaw 90 while the dead TV on the S kitchen table is yaw 0 — whatever the model's native screen axis (±Y), exactly one of the two screens faces a wall: if front=+Y the live TV's screen faces the W wall (should be 270); if front=-Y the dead TV faces the S wall (should be 180). The lit screen facing plaster would be the most visible read-error in the room.
   - Fix: One in-game glance decides: if the live screen faces the wall, set it to yaw 270; otherwise set the dead TV at (-1800,446,55) to yaw 180. No origin changes.
   - Source: `map L20339/L20352; _acc_surface_deco.gsc:497-498`
7. **[M] p7_sin_market_stand_tarp_01 (stall B)** @ (-1460, 900, 30.6) yaw 90 — *rotation-smell*
   - Problem: Stall A (W row, -1950,700) and stall B (E row) both use yaw 90 = identical facing. Facing stall rows in a bazaar loop should open toward the shared mid lane; with the same yaw, one row's open counter faces the wall/outer lane and shoppers see tarp backs. Only innocent if the stand mesh is open-through (unverified).
   - Fix: If stall A reads open-to-the-east in game, set stall B to yaw 270 (open west toward the mid lane); if A is the wrong one, set A to 270 instead. Origins unchanged (clips are near-symmetric hx/hy so no clip edit needed if only yaw flips 180).
   - Source: `map L20209/L20222; _acc_surface_deco.gsc:481-482`
8. **[M] p8_zm_whi_window_frame_broken_03** @ (2174, 1120, 0) yaw 0 — *orientation*
   - Problem: Both 'leaned' window frames use yaw 0 on OPPOSITE walls (_02 at W x1342, _03 at E x2174). A leaning mesh tilts one native direction — the same yaw cannot rest against both a W and an E wall; one frame is leaning away from its wall / hovering into the room. Every other E-wall flush mount in this room got the 180 flip (electric set 06, ladder, weeds) — the frame did not. Caveat: _02/_03 are different meshes and could lean opposite ways natively.
   - Fix: Set the E-wall _03 to yaw 180 (angles "0 180 0"), matching the room's E-wall flip convention; verify the W _02 still rests correctly.
   - Source: `map L19753 vs L19740; _acc_surface_deco.gsc:408-409 vs 400-401,430`
9. **[L] p8_zm_whi_sign_neon_diner** @ (-1560, 1452, 150) yaw 90 — *rotation-smell*
   - Problem: DINER neon 4u off the N wall at yaw 90, while the t10 ice-cream sign on the SAME wall uses yaw 0 — the two can only both be wall-flat if the p8 mesh's flat axis is ±X native (unverifiable here). If it shares the common ±Y sign axis, the map's headline neon is edge-on above the booth nook.
   - Fix: In-game check: if edge-on, set yaw 180 (face south over the booths); if it reads flat and lit, leave it.
   - Source: `map L20300; _acc_surface_deco.gsc:490`
10. **[L] p7_zm_tra_booth_chair** @ (-1720, 1360, 0) yaw 0 — *grouping*
   - Problem: Diner chair belongs to no set piece: 43u east of the N kitchen-table clip, 68u west of the booth-sofa nook, facing south into open floor. Reads as a stray between two furniture stories rather than part of either.
   - Fix: Shift east to (-1680, 1360, 0) yaw 0 so it clusters with the mannequin + rustic table as the booth-nook's pulled-out chair (grazes the mannequin clip by design). Riser check done: dog (-1721,1130) 234u, riser (-1376,1296) 310u — clear. Alternatively leave: 'seating faces open space' is technically satisfied.
   - Source: `map L20092; _acc_surface_deco.gsc:470`
11. **[L] p7_zm_tra_wheelbarrow_full (x2)** @ (1625, 1300, 0) and (1610, 710, 0) yaw 80 / 30 — *out-of-theme*
   - Problem: Two full farm wheelbarrows in the 'red-hazard service gut' cyber alley. The M3 pass deliberately purged the other rural props (outhouse, wood barrels, animal cages) but kept both wheelbarrows; they are the last rural read in the room and sit on the two main lane centers.
   - Fix: Swap both for street-junk equivalents already zoned for this room (e.g. a second t10_as_street_trash_bin_01 at (1625,1300,0) yaw 80 and t10_trash_street_debris_01 at (1610,710,0) yaw 30 — reuses existing clips/footprints, no riser change), or accept as scavenger-cart flavor and keep.
   - Source: `map L19428/L21772; _acc_surface_deco.gsc:376,702`
12. **[L] p7_zm_tra_shelve_oilrack** @ (1600, 860, 0) yaw 0 — *placement*
   - Problem: Freestanding tall (56u) storage shelf mid-room with no wall or stall context — rule says shelves back against walls unless documented. Partially excused: it clusters with the mannequin + burn barrel as a squatter-camp read, and the alley is deliberately tight (difficult-navigation memory).
   - Fix: Keep position (it is a documented density obstacle) but add a one-line camp-cluster intent comment in _acc_surface_deco.gsc:378, or back it against the W wall at (1370, 860, 0) yaw 90 — riser (1539.5,644) 273u, riser (1539.5,1212) 390u, clear; would slightly open the W lane the design wants tight.
   - Source: `map L19454; _acc_surface_deco.gsc:378`

---

## Vault + Roof

**Props audited:** 95 baked / 3 script-spawned. **Issues:** 15.

**Coherence read:** Both zones tell strong, mostly-coherent stories. VAULT = 'sealed bank data-fortress': the circular portal + flush deposit panels + ops consoles provably facing the door + a correctly-oriented walk-through metal detector on the corp approach (pillar clips prove the gap runs across the travel axis) form a genuine narrative spine; the center tech island, W-wall utility row and both standing console banks all check out under per-model axis votes. What breaks it: two of the three story-beat security monitors face the walls they hang on, the ATM stands 90-degrees sideways in an otherwise perfectly aligned row, and the pre-M5 S-wall props float 23-25u proud beside panels that were flushed to the millimeter — fixing those ~10 ents makes the room read designed. ROOF/HELIPAD = 'crash-scene equipment yard': the bomber hero + rubble/cone under the hull + one work light provably aimed at the wreck is excellent; elevate it by aiming the second tripod at the wreck too and turning the backwards N-wall junk row (cage/dolly/radiator) around. The animal cage and vintage radiator are borderline theme strays but pass as derelict rooftop junk. NOTE FOR THE FIXER: the GSC deco twins are display-disabled (deco dvars default 0) — the .map misc_models are what renders, so every fix must land in the .map ent AND the _acc_surface_deco.gsc table AND add_prop_clips.js in lockstep, and misc_model edits are geometry: full LED-bake gate applies. props_scripted=3 counts the two scatter perk machines parked on the Vault (1152,3015 yaw90, faces E — correct) and Helipad (-1500,2313 yaw180, faces N — correct) pads plus the GSC-only elevator arrow at (1610,3380,120) which never renders (model absent from gdtDB, already documented). AW mystery boxes (both zones) and their exo structs are correctly mirrored (yaw 0/90 W-wall vs 180/270 E-wall, 40u standoff).

**Top 5 most player-visible:**

- Vault E-wall ATM is turned 90 degrees sideways in the west-facing tech row (screen faces along the wall; clip guards air)
- Vault RED-alert pole monitor faces into the W wall 17u away — the alert screen is invisible from the room
- Vault E-wall static monitor faces into the E wall; also missing the roomward arm offset the correct S-wall set uses
- Helipad N-wall junk row (animal cage, pneumatic dolly, radiator) all show their backs to the room (yaw 180 where N-wall convention is 0)
- Vault S-wall cabinet/generator/dragon float 23-25u off the wall right beside the millimeter-flush M5 bank panels

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_out_monitor_atm** @ (1913, 2680, 0) yaw 270 — *orientation*
   - Problem: ATM in the Vault E-wall tech row is turned 90 degrees sideways: this model's mesh extends +X from a back-face origin (documented in add_prop_clips.js:94 and confirmed by the Exchange spawning it at default yaw 0), so at yaw 270 the screen faces SOUTH along the wall while every neighbor (server_comm/tower/dragon, all yaw 270 with front=local -y) faces west into the room. Bonus defect: the mesh actually occupies y[2643,2680] but the clip 'vault_monitor_atm' (1913,2680 hx17 hy18) was authored assuming a centered mesh, so it guards ~18u of air north of the body.
   - Fix: yaw 180, origin (1930, 2680, 0) — mesh becomes x[1893,1930] flush with the row line (server_comm face x1890), screen faces west toward the approach; regenerate the vault_monitor_atm clip to the new mesh center (~1911.5, 2680). Nearest riser (1734,2545) >290u — clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:20561; _acc_surface_deco.gsc:556; tools/add_prop_clips.js:94,261`
2. **[M] p8_zm_off_monitor_security_mount_02 + monitor_security + screen_red** @ (1136, 2880, 0/94/95) yaw 270 — *orientation*
   - Problem: The W-wall floor-pole security monitor set — the RED-alert screen, a deliberate story beat — faces INTO the W wall (plane x1119, 17u away). Monitor-family front = local -y, proven by the Lab N-wall pair (mount (140,3855) yaw 0 with screen_on hung 20u roomward at y3835 facing south) and by the Vault's own S-wall trio (yaw 180, monitor 20u roomward of mount, faces north — correct). Yaw 270 with front -y = facing -x, into the wall; the clip offset (center x1130, -6 from origin) confirms the monitor arm currently reaches toward the wall.
   - Fix: yaw 90 on all three ents (map + GSC twins); regenerate vault_m5_monitor_pole clip (arm mesh swings roomward to ~x1142). Perk pad span y[2984,3046] unaffected (pole at y2880); risers >190u.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:20938,20951,20964; _acc_surface_deco.gsc:595-597; add_prop_clips.js:539`
3. **[M] p8_zm_off_monitor_security_mount_01 + monitor_security_static** @ (1912, 2740, 102/152) yaw 90 — *orientation*
   - Problem: E-wall static-screen monitor set faces +x INTO the E wall (x1939, 27u away) under the same lab-proven front=-y axis. It also breaks the mount pattern: the correct S-wall trio hangs the monitor 20u roomward of its mount; this set stacks monitor directly above the mount with zero roomward offset.
   - Fix: yaw 270 on both; optionally shift monitor+screen origins to (1892, 2740) to reproduce the S-wall arm offset. Risers >280u.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:20977,20990; _acc_surface_deco.gsc:598-599`
4. **[M] p7_zm_tra_cage_animal_med** @ (-1650, 3352, 20) yaw 180 — *orientation*
   - Problem: Roof N-wall junk row is 180 backwards. The p7 pack convention is proven self-consistent across the two zones (computer_tower: E-wall 270 / W-wall 90 / N-wall 0; oilrack+power_panel S-wall 180, E-wall 270; front = local -y). N-wall props therefore take yaw 0 — the Vault's own N-wall tower (1350,3352) and generator (1720,3352) correctly use yaw 0 — but this cage uses the S-row's yaw 180, so its door face points +y into the N wall and players see its back.
   - Fix: yaw 0 (map misc_model + GSC twin). Origin unchanged; z20 is correct (centered pivot, clip 0-40).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21173; _acc_surface_deco.gsc:644`
5. **[M] p7_zm_tra_pneumatic_dolly** @ (-1540, 3348, 2) yaw 180 — *orientation*
   - Problem: Same N-wall backwards row as the cage: yaw 180 faces the dolly's front/handle into the N wall under the established p7 front=-y convention; N-wall props elsewhere in both zones use yaw 0.
   - Fix: yaw 0, origin unchanged.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21186; _acc_surface_deco.gsc:645`
6. **[M] p7_zm_tra_radiator_vintage** @ (-1430, 3358, 0) yaw 180 — *orientation*
   - Problem: Third member of the backwards N-wall row (faces +y into the wall). Visually mildest of the three (radiator faces are near-symmetric) but inconsistent with every other wall-backed p7 prop in both zones.
   - Fix: yaw 0, origin unchanged.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21199; _acc_surface_deco.gsc:646`
7. **[M] p7_con_cargo_train_armory_cabinet** @ (1560, 2312, 0) yaw 180 — *floating*
   - Problem: Vault S-wall pass-2 props were never flushed when FIX BATCH 3 corrected the wall plane from the assumed y2300 to the real y2280 — only the M5 row moved. The cabinet's back edge (clip y2303, hy9) stands 23u proud of the wall, a visible dead slot behind a 138u-wide, 48-tall cabinet sitting right beside the perfectly flush M5 deposit panels (clip edge y2279.9).
   - Fix: origin (1560, 2289, 0) — back edge lands on y2280; move the vault_cargo_train_armo clip -23y in lockstep. Nearest riser (1734,2545): 310u — clear. No overlap with the door-assembly clip (starts x1684).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:20600; _acc_surface_deco.gsc:559; add_prop_clips.js:264`
8. **[M] p7_ris_generator_lg_01_blue** @ (1400, 2328, 0) yaw 180 — *floating*
   - Problem: Same un-flushed pass-2 row: generator back edge (clip y2305) floats 25u off the real S wall plane y2280.
   - Fix: origin (1400, 2304, 0) (back edge y2281); move vault_generator_lg_01_ clip -24y. Riser (1324,2545): 253u — clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:20587; _acc_surface_deco.gsc:558; add_prop_clips.js:263`
9. **[M] p7_zm_sta_dragon_network_data_terminal** @ (1250, 2320, 0) yaw 180 — *floating*
   - Problem: Pass-3 S-wall terminal back edge (clip y2303, hy17) floats 23u off the wall plane y2280 — same stale-y2300 assumption.
   - Fix: origin (1250, 2297, 0) (back edge y2280); move vault_x_dragon_network clip -23y. Riser (1324,2545): 260u; no overlap with detector pillar clips (x1269-1311 vs dragon x[1226,1274] y[2280,2314] — detector S pillar starts y2393.5, clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21876; _acc_surface_deco.gsc:715; add_prop_clips.js:306`
10. **[M] p7_zm_tra_shelve_oilrack** @ (-1760, 2330, 0) yaw 180 — *floating*
   - Problem: Roof S-wall rack floats 34u off the wall: docs/02 standoff table records the Helipad S wall face at y2280, but the rack's back edge (clip y2314, hy16) assumes the stale y2300-ish plane. A shelving rack is a back-against-wall prop; the gap reads as floating.
   - Fix: origin (-1760, 2296, 0) (back edge y2280); move roof_shelve_oilrack clip -34y. Riser (-1734,2545): 250u — clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21121; _acc_surface_deco.gsc:640; add_prop_clips.js:273; docs/02_layout.md:492`
11. **[M] p7_zm_tra_power_panel** @ (-1650, 2320, 0) yaw 180 — *floating*
   - Problem: Roof S-wall breaker panel back edge (clip y2312, hy8) floats 32u off the wall face y2280 — breakers mount to walls; a freestanding panel with a walkable-looking (but visually dead) slot behind it reads wrong.
   - Fix: origin (-1650, 2288, 0) (back edge y2280); move roof_power_panel clip -32y. Riser (-1734,2545): 240u — clear.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21134; _acc_surface_deco.gsc:641; add_prop_clips.js:274`
12. **[M] p7_rus_light_studio_tripod** @ (-1480, 2380, 0) yaw 40 — *orientation*
   - Problem: This work-light tripod aims SE at the blank S wall ~60u away. Its sibling at (-1680,3300) yaw 15 is provably aimed at the bomber wreck (aim vector under front=-y matches the wreck-center bearing within ~4 degrees), completing the crash-inspection story; this one breaks it by lighting a wall.
   - Fix: yaw 190 (aim vector points at the bomber S mouth ~(-1524,2582)); origin + padded-square clip unchanged.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21485; _acc_surface_deco.gsc:670; add_prop_clips.js:515`
13. **[L] p7_rus_handrail_double_128_yellow** @ (-1400, 2312, 0) and (-1270, 2312, 0) yaw 90 — *placement*
   - Problem: Both 'wall-flush' S-edge handrail segments sit 32u off the actual S wall face y2280 (stale-plane class). They carry no clip, so players walk through a rail line visibly floating in front of the wall; segment spacing (130u centers for 128u pieces) is otherwise correct.
   - Fix: move both to y2288 (thin rail flush against y2280 wall face); no clips to move. Risers >230u.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21342,21355; _acc_surface_deco.gsc:659-660`
14. **[L] p8_zm_whi_cloth_warning** @ (-1310, 3342, 0) yaw 0 — *floating*
   - Problem: The warning cloth is commented 'draped on the chainlink' but sits 22u south of its fence line (chainlink at y3364) — likely hovering in mid-air in front of the fence rather than hanging on it.
   - Fix: move to (-1310, 3360, 0) so the cloth mesh actually overlaps the fence plane; needs an in-game look to confirm the model's own standoff. No clip involved.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21511; _acc_surface_deco.gsc:672`
15. **[L] p7_rus_fuel_tank_rust** @ (-1290, 3255, 0) yaw 0 — *placement*
   - Problem: The NE fuel tank's large clip (138x232 footprint, y[3143,3375]) leaves only ~28u between its S edge and the riser struct at (-1324,3115) — under the 45u riser-clearance standard; zombies rising there squeeze past a wall of clip.
   - Fix: rotate to yaw 90 at the same origin (clip becomes x[-1406,-1174] y[3186,3324]): riser clearance rises to 71u, lab-corridor mouth (x-1119) keeps 55u, N wall untouched. FLAG: needs riser re-check + in-game visual (horizontal tank rotates fine but confirm no water-tower sightline clash).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:21420; _acc_surface_deco.gsc:665; add_prop_clips.js:510`

---

## Lab + Helipad

**Props audited:** 124 baked / 7 script-spawned. **Issues:** 13.

**Coherence read:** Both areas tell strong stories. LAB: clinical cyberware facility reads cleanly in vignettes — decon airlock line at the S wall (hosting a perk pad inside the open tent), teleporter manifold + hero core mid-east, medical row on the E wall, APD sci-fi island flushed to the new N wall, console/locker bank along the perk row — and the 2026-08-02 compression was executed thoroughly: zero orphaned props outside the new y<=3868 playable bound, the office pocket (x[-295,145] y[3868,4228]) is fully furnished with a correct desk/chair/door relationship, and every relocated prop honors the 45u riser standard (verified against all 15 lab_zone_spawners). HELIPAD: the crashed-bomber equipment yard is the most coherent room audited — hero wreck with documented crash-rubble re-reads, edge kit flush on all four walls, deliberately non-cardinal studio lights 'aimed at the pad'. What would elevate: (1) the Lab's wall-mounted screens/consoles inherited THREE different front-axis assumptions from three generators (M2 sweep, M5 vault, ACCLPC01 compression) — a single measured front-axis note per model family in add_prop_clips.js would end the recurring flips; (2) fix the five wall-facing errors above (all yaw-only, no rebake-risk geometry); (3) the office would read richer if its two out-of-kit strays (transit booth chair, un-rolled lightbox) matched the p8 office family like everything around them.

**Top 5 most player-visible:**

- Holo screen above the Five-Seven wallbuy (0,3074,140) is edge-on to every buyer - yaw 0 should be 90 (HIGH, ground-truth axis proven)
- Both N-wall control consoles on the Lab perk row (330/520,3846) likely show players their backs - yaw 0 -> 180 per the documented vault/office family convention
- Scientist's Office x-ray lightbox (-269,4010,120) is missing the 'rolled upright' roll-90 its lab twin needed - likely lying flat in mid-air in the hero Exo/Jugg room
- Second N-wall holo screen (0,3862,140) faces along the wall instead of south over the perk row - yaw 180 -> 270
- Helipad warning cloth (-1310,3342) floats 22u in front of the chainlink it is supposedly draped on - move to y3360

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_cru_monitor_holo_screen_01** @ (0, 3074, 140) yaw 0 — *orientation*
   - Problem: Mounted on the S wall (face y3070) directly above the Five-Seven wallbuy, but front axis is +x at yaw 0 (proven by _acc_atmosphere.gsc:248 'yaw 90 faces north'), so the screen faces EAST — players buying the wallbuy see its thin edge, not the display. Its sibling at (796,3430) yaw 180 on the E wall correctly faces west, proving the two are 180 apart when perpendicular walls require 90.
   - Fix: yaw 0 -> 90 (face north into the room). Wall-mount, no clip, no riser impact.
   - Source: `map L23022 / _acc_surface_deco.gsc:907`
2. **[H] p7_cru_monitor_holo_screen_01** @ (0, 3862, 140) yaw 180 — *orientation*
   - Problem: On the new inner N wall (y3868, post-compression) over the perk row; yaw 180 = faces WEST (front axis +x at yaw 0), i.e. parallel to the wall — edge-on to everyone on the perk strip.
   - Fix: yaw 180 -> 270 (face south over the perk vending row).
   - Source: `map L27217 (ACCLPC01 gen_compress_lab_paradise.js)`
3. **[M] p8_zm_off_console_control_01 + _02** @ (330, 3846, 0) and (520, 3846, 0) yaw 0 (both) — *orientation*
   - Problem: Both consoles sit against the new N wall at yaw 0. The documented family convention says yaw 180 faces −y: vault control_03/04 at (1700/1886,2450) use yaw 180 to face the S-wall vault portal ('ops row facing the vault door'), and the office control_01 at (80,4172) uses yaw 180 to face south into the office. By that convention the two lab consoles present their BACKS to the room and their screens to the wall, 22u away.
   - Fix: yaw 0 -> 180 on both (origins unchanged; AABB clips lab_console_control_01/02 stay valid — 180 rotation preserves the footprint). Verify in-game since _01/_02 are different meshes than _03/_04.
   - Source: `map L22866/L22892; convention: _acc_surface_deco.gsc:581-582 + add_prop_clips.js:391,393`
4. **[M] p8_zm_off_lightbox_xray_on** @ (-269, 4010, 120) yaw 90 (roll 0) — *rotation-smell*
   - Problem: The lab E-wall twin at (795,3505,105) needed angles (0,90,90) — explicitly commented 'rolled upright' — to hang vertically as a wall lightbox. The office copy has NO roll (0,90,0), so the panel most likely lies FLAT/horizontal in mid-air at z120 beside the W wall (x-295, 26u away); its yaw 90 is also un-mirrored for a W-wall mount.
   - Fix: angles (0,90,0) -> (0,270,90) — mirror of the validated E-wall mount, screen facing east into the office. Verify in-game (natural mesh pose inferred from the sibling's comment).
   - Source: `map L24493 (gen_scientist_office.js) vs _acc_surface_deco.gsc:877`
5. **[H] p8_zm_off_console_control_01 (clip 'sci_console')** @ (80, 4172, 0) yaw 180 — *intersection*
   - Problem: Clip-vs-model contradiction: the office clip is hx23 hy30 (46 wide x 60 deep, annotated '46x60, yaw 180') but the SAME model's lab clip at yaw 0 is hx30 hy23 (60x46) — a 180-deg yaw cannot swap the AABB, so one record is wrong. If the model truly is 60 wide x 46 deep at yaw 180, the office clip guards a rotated phantom: 7u of real console sides stick out unclipped (players/zombies clip into the mesh) while 7u of air is solid in front.
   - Fix: Keep the console at yaw 180 (correct facing) and resize the sci_console clip to hx30 hy23 (footprint x[50,110] y[4149,4195]); re-run tools/add_prop_clips.js pipeline. Desk lane to (-75,4130) stays >75u.
   - Source: `tools/add_prop_clips.js:51 vs :391`
6. **[M] p8_zm_off_test_chamber** @ (-680, 3841, 1) yaw 90 — *orientation*
   - Problem: New N-wall specimen chamber added by the compression. The original, walk-validated W-wall chamber at (-730,3520) uses yaw 0 (front +x, east into the room). Rotating the N-wall copy to yaw 90 turns that front to +y — the chamber's viewing side faces INTO the wall; it should rotate the other way.
   - Fix: yaw 90 -> 270 (front −y, south into the room). Origin unchanged.
   - Source: `map L27113 (ACCLPC01) vs _acc_surface_deco.gsc:865`
7. **[M] p8_zm_off_coat_lab_hanging** @ (40, 3894, 90) yaw 180 — *orientation*
   - Problem: Coat hangs on the office S wall interior face (normal +y). The validated W-wall sibling (-758,3820,80) uses yaw 0 for a +x-normal wall; the matching value for a +y-normal wall is 90. At yaw 180 the coat plane is perpendicular to its wall — it sticks out of the wall edge-on beside the office door.
   - Fix: yaw 180 -> 90.
   - Source: `map L24517 vs _acc_surface_deco.gsc:872`
8. **[M] p8_zm_whi_cloth_warning** @ (-1310, 3342, 0) yaw 0 — *floating*
   - Problem: Commented 'draped on the chainlink' but the chainlink fence plane sits at y3364 — the cloth is 22u SOUTH of it, hanging detached in mid-air; from the side the gap is plainly visible in the open helipad sightlines.
   - Fix: move origin to (-1310, 3360, 0), just proud of the fence face (yaw stays 0). Riser check clear: nearest roof riser (-1324,3115) is 245u away.
   - Source: `map L21511 / _acc_surface_deco.gsc:672`
9. **[L] p7_cru_monitor_holo_screen_01** @ (119, 4070, 130) yaw 270 — *rotation-smell*
   - Problem: Sits 26u off the office E wall (x145) but faces SOUTH (front +x at yaw 0 -> yaw 270 = −y) — as a wall-mount it is edge-on to its wall. Defensible as a free-floating holo facing the office door, but it breaks the wall-mount pattern every other screen in the room follows.
   - Fix: yaw 270 -> 180 (face west into the office toward the desk/exo pod), or document the floating-holo intent.
   - Source: `map L24505 (gen_scientist_office.js)`
10. **[L] p7_zm_sta_dragon_network_data_terminal** @ (-300, 3510, 0) yaw 270 — *orientation*
   - Problem: East flank of the free-standing server island; with the p7 tech family front −y at yaw 0 (derived from the validated vault E-wall yaw 270 / W-wall yaw 90 rows), yaw 270 faces WEST into the server rack 70u away — its screen faces its own cluster, back to the teleporter-pad approach from the east.
   - Fix: yaw 270 -> 90 (face east toward the teleporter pad approach).
   - Source: `map L27087 (ACCLPC01) vs _acc_surface_deco.gsc:553-562`
11. **[L] p7_zm_tra_booth_chair** @ (-75, 4178, 0) yaw 180 — *out-of-theme*
   - Problem: A bus-station booth chair (p7_zm_tra transit kit) serving as the scientist's desk chair in the otherwise all-p8-office room. Pairing geometry is correct (behind the desk, facing it and the door), just the wrong kit.
   - Fix: Swap model for an office/lab seat from an installed pack if one exists (no p8 chair confirmed installed — otherwise accept). Keep origin (-75,4178) yaw 180.
   - Source: `map L24397`
12. **[L] p7_zm_tra_radiator_vintage** @ (-1430, 3358, 0) yaw 180 — *out-of-theme*
   - Problem: An indoor cast-iron vintage radiator against the N wall of an outdoor mil-tech rooftop equipment yard — reads as a kit-bash leftover among the water tower / cage / dolly row.
   - Fix: Remove, or replace with p8_zm_off_tank_propane at the same spot (yaw 0); clip roof_radiator_vintage (add_prop_clips.js:279) removed/updated in lockstep.
   - Source: `map L21199 / _acc_surface_deco.gsc:646`
13. **[L] p7_zm_tra_street_lamp_full** @ (-1895, 2400, 0) yaw 0 — *out-of-theme*
   - Problem: A full street lamp planted inside the fully ENCLOSED rooftop box (hard z256 ceiling slab per the M4 notes that skipped all props >256 tall) — street furniture indoors, and the lamp head likely crowds the ceiling.
   - Fix: Remove or swap for a third p7_zm_tra_light_cage_ceiling at (-1895,2400,234) yaw 0; delete clip roof_street_lamp_full (add_prop_clips.js:282) in lockstep.
   - Source: `map L21238 / _acc_surface_deco.gsc:649`

---

## Trench under-rooms

**Props audited:** 15 baked / 17 script-spawned. **Issues:** 10.

**Coherence read:** The under-rooms tell solid stories at the DECO level: the M6 p7_rus industrial kit (pressure tanks, steel tables, canisters at scattered yaws, flush electric boxes, dead ceiling lamps) gives both z-240 rooms a coherent utility-basement read, the armory loft's gun racks/locker/ammo pile all correctly back their walls, and the Foundry props respect the vendor keep-clear and door apron. The systemic weakness is the SCRIPTED stations: nearly every one spawns yaw 0 regardless of site (only the leaderboard terminal and reactor ever had their yaw reasoned about), so station orientation is correct only where yaw 0 happens to work (L2 Overclock) and wrong or accidental elsewhere (L5 Overclock, Exchange ATM row, likely the Foundry vendor). Second systemic issue: two room expansions (north under-room west+back bands; vault floor -240 to -160) invalidated documented placement rationales without the props being revisited - the jukebox's 'back to the west wall', the reactor's 'along the back wall', and the ATMs' floor offset are all pinned to geometry that no longer exists. What would elevate the area most: (1) one bake bundling the Exchange fix (raise 80u + face west) - the vault currently reads as four broken stubs and is the single worst placement offender in the map's economy loop; (2) a one-session in-game front-axis pass over the three station models whose forward vector is unverified (Gorod console, ATM totem confirmation, altar) so every station provably faces its approach; (3) re-anchor the jukebox/reactor to the real north-room walls or deliberately dress their exposed backs. Also worth a docs touch: docs/28 still places the Exo Suit station in the Foundry west - it moved to the Scientist's Office 2026-07-26, leaving the Foundry's west wall to a work table.

**Top 5 most player-visible:**

- All 4 Exchange ATM totems are buried 80u under the vault floor - the whole trading room presents as four ankle-high stubs (proven by the module's own header; the deco rack beside them already got the raise)
- The Exchange ATM row faces the dead east wall - every player entering from the west stairs sees only machine backs, and the deposit pad sits on the rear panel
- The L5 Overclock terminal faces east, directly away from the descent well players arrive from (its L2 twin only faces right by copy-paste luck)
- The Neural Expansion Bay console likely faces the Foundry's east wall 48u away instead of the room's only (NW) doorway - yaw never tuned after its move
- Jukebox and Reactor plinth both free-float with exposed backs since the north room expanded - the 'back to the wall' designs are pinned to walls that moved (jukebox rear greets everyone at the trench mystery box)

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_out_monitor_atm (x4: points/shards/bottles/items)** @ (80,200,-240) (80,40,-240) (80,-120,-240) (80,-280,-240) after the -80 offset yaw 0 (never set) — *floating*
   - Problem: All four 103u-tall Exchange ATM totems are buried 80u UNDER the vault floor: spawn_station() drops origin+(0,0,-80) to a believed -240 floor, but the vault floor is -160 (header self-documents the stale-claim bug, _acc_transfer.gsc:20-22). Only the top ~23u pokes out, so the map's whole player-to-player economy room presents four monitor totems as anonymous ankle-high pedestals. The deco server rack in the SAME room already got this exact fix (add_prop_clips.js:609 'the old clip+prop were buried 80u under the slab' - z RAISED 2026-07-19); the stations were left behind. Header notes it was 'left as-is 2026-07-17, user's call to raise' - the user's new placement complaint re-opens that call.
   - Fix: In _acc_transfer.gsc:101 change `origin + (0,0,-80)` to `origin` so bases spawn at z=-160 (model origin is at its base = flush on the real floor). Re-sync the 4 transfer_* clips in add_prop_clips.js:94-97 from bot:-240/top:-137 to bot:-160/top:-57 (+ re-bake). Pads/triggers at z=-160 unchanged.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc:14-22,91-101; tools/add_prop_clips.js:94-97,609`
2. **[M] p7_zm_sta_dragon_network_data_terminal (Overclock #2, L5)** @ (400,1948,-1200) yaw 0 — *orientation*
   - Problem: The L5 Overclock's screen faces +X (east) - AWAY from its only approach. Front axis at yaw 0 = +X is proven by the leaderboard clip note (same model 'at yaw 90' backed on the plaza SOUTH wall facing north; rotating +90 maps +X to +Y). Players reach L5 via the central descent well (x[-112,112]) WEST of the terminal, so they always arrive at its back; the screen faces the east-bay monolith. Its L2 twin at (-400,1948,-480) yaw 0 happens to face the well correctly - the copy-pasted yaw 0 only works on the west side.
   - Fix: yaw 0 -> 180 in the spawn_terminal_at call at _acc_glitch_altar.gsc:109. Clip-safe: overclock_l5 clip is centered exactly on the origin (hx24/hy17 symmetric), so a 180 rotation keeps the same bbox - no bake needed.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:109; tools/add_prop_clips.js:69,108`
3. **[M] p7_out_monitor_atm row (Exchange stations)** @ row at x~80-114, y 200/40/-120/-280, vault room x[-720,300] yaw 0 (never set) — *orientation*
   - Problem: The ATM row's screens face +X (east) toward the dead east wall (~186u away); the vault's only entrance is the stairwell at the room's WEST end (well x[-620,-380] y[-440,-312], per spawn_stations header), so every arriving player sees four machine BACKS. The deposit pad (origin-55, x=25) also sits on the back side - depositors interact while staring at the rear panel. Mesh extends +X from a back-face origin (clip center x=98 vs origin x=80), confirming the display is the +X face.
   - Fix: Rotate all 4 stations yaw 0 -> 180 (add m.angles=(0,180,0) in spawn_station) so screens face the west stair approach. NOTE: back-face origin means the mesh flips to extend -X - re-sync the transfer_* clip centers x 98 -> 62 (bake), and do it together with the raise fix (same clip edit).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_transfer.gsc:80-107; tools/add_prop_clips.js:94-97`
4. **[M] p7_zm_sta_drop_pod_console_blue (Neural Expansion Bay)** @ (120,1550,-240) yaw 0 — *orientation*
   - Problem: The Foundry's marquee station sits on the EAST side (~48u from the east wall at x=192) with yaw 0 - but the room is entered ONLY through the NW doorway (front wall doorway WEST x[-192,-112], .map L3059 comment). The console's yaw was never touched when the vendor moved from the pit (-250,1820) to the Foundry east side; if the Gorod console's screen front is +X like the other sta_ kiosks, it faces the east wall 4 feet away and shows entering players its back. Front axis for THIS model is unverified.
   - Fix: Verify the console's front in-game once; if front = +X at yaw 0, set yaw 180 in _acc_glitch_altar.gsc:127 (face west toward the door). Clip-safe: perk_slot_vendor clip is origin-centered (hx25/hy22), 180 keeps the bbox.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:122-127; map_source/zm/zm_abandoned_cyber_city.map:3059; tools/add_prop_clips.js:65`
5. **[M] cp_town_jukebox** @ (-150,2240,-240) yaw 0 (faces +X east) — *placement*
   - Problem: The jukebox's documented design ('Back to the west wall', ACC_JUKEBOX_ORIGIN comment) is STALE: the north under-room has since been expanded west to ~x=-384 (the trench mystery box now sits at (-364,2235) inside the room), so the jukebox free-stands ~230u from the actual west wall with its back panel exposed to the mystery-box corner - every player rolling the trench box stares at the jukebox's rear. Its front toward the S doorway still reads OK, so this is a wall-backing/story break, not a facing break.
   - Fix: Move to (-372,2450,-240), keep yaw 0 - genuinely wall-backed on the real west wall, facing east into the room, ~215u clear of the box node (-360,2231) and ~200u from the reactor. Re-sync the 'jukebox' clip (mesh sits +X of origin: center x -139 -> -361, y 2240 -> 2450) + move the use-trigger with ACC_JUKEBOX_ORIGIN. NEEDS RISER CHECK (>=45u from any corp/trench spawner struct) before committing.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_jukebox.gsc:48-49,93-100; map_source/zm/zm_abandoned_cyber_city.map:17449; tools/add_prop_clips.js:100`
6. **[M] p7_ris_generator_lg_01_blue (Reactor Arm Plinth)** @ (0,2493,-240) yaw 0 — *placement*
   - Problem: The plinth's placement rationale ('CENTERED, long axis along the back wall... yaw 270 would poke it through the north wall at 2517', _acc_reactor.gsc:119-122) is stale: the room's back wall moved from y2517 to ~y2748 (M6 back bay - baked steel table at (240,2660) and canister 'vs the back wall' at (150,2710) prove the band exists). The map's climax generator now free-stands with a ~230u open walkway BEHIND it, reading like it was left mid-room rather than installed against anything. Orientation itself (long axis X) is fine; gameplay station so this is optional.
   - Fix: Either accept the island read, or move to (0,2720,-240) yaw 0 to re-back it on the real north wall - requires moving the reactor_plinth clip (y 2493 -> 2720) + the use-trigger, and a riser check. Alternatively dress its rear: shift one N-room canister to ~(40,2530) so the gap reads intentional.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_reactor.gsc:119-126; scripts/zm/zm_abandoned_cyber_city/_acc_surface_deco.gsc:143-164; tools/add_prop_clips.js:53`
7. **[L] p8_zm_off_cigarette_vending (CYBER SLOTS machine)** @ (-250,2260,-187.2) (top-origin, body on the -240 floor) yaw 0 (front -Y south) — *placement*
   - Problem: Free-standing vending-style machine on open floor with its back (north face) exposed to the whole room interior / reactor sightline. Documented as deliberate ('FREE-STANDING... between the jukebox and the trench mystery box', replaced a wall-hung spot 2026-07-25), and its south front does face the S-door corridor players walk to reach the box - so it works, but back-panel-to-the-room is the weakest read among the three machines in the row.
   - Fix: Optional: wall-back it on the south wall at (-250,2210,-187.2) yaw 180 (front +Y north into the room) - back flush to y2189, front faces both the doorway and the box path. Re-sync slots_vending clip (offsets rotate: deltas (-9.6,+0.3) were measured at yaw 0) + move ACC_SLOTS_TRIG_ORIGIN to the new north face (-250,2226,-208). Riser check required.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_slots.gsc:59-99; tools/add_prop_clips.js:101`
8. **[L] p7_cai_stacking_cargo_crate (2 pit Data Caches)** @ (-360,1950,-240) and (360,1950,-240) yaw 0 both (spawn_cache_at never sets angles) — *rotation-smell*
   - Problem: The two shard caches are the identical crate model at perfectly mirrored positions with identical yaw 0 - a copy-paste grid read in what is supposed to be a chaotic exposed danger pit (the 'clutter tells a story' rule). Pure cosmetics; positions themselves are fine (clear of stairs, clipped).
   - Fix: Add a yaw param (or post-set crate.angles) and give the east cache yaw ~30 and the west ~345 so the pair reads dumped, not placed. Cache clips are square-ish (hx25/hy25) so small rotations stay inside the clip; keep origins unchanged (no riser impact).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:86-87; scripts/zm/zm_abandoned_cyber_city/_acc_data_shards.gsc:275-283; tools/add_prop_clips.js:57-64`
9. **[L] p7_ram_altar + floating core (Glitch Altar)** @ (-400,1948,-720) yaw 0 (spawn_altar_at sets no angles; 162u long axis = X) — *orientation*
   - Problem: The altar presents its narrow 66u END to the only approach (players walk WEST from the central stairwell x[-112,112] along the y1948 slab mid-line); the 162u broadside faces the empty N/S bay walls. A ceremonial altar reads strongest broadside-on to the approach. Mitigating: it self-glows as a beacon and the use-trigger is a 110-radius circle, so function is unaffected - aesthetic only.
   - Fix: yaw 90 (broadside faces east toward the arriving player). COST: the glitch_altar_l3 clip (hx81/hy33 + the 120u anti-perch cap) must swap X/Y extents and re-verify the slab fit in Y (bay depth ~y[1723,2173] holds 162 fine) - a bake. Only do it bundled with another geometry pass.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:105,352-374; tools/add_prop_clips.js:71`
10. **[L] p8_zm_off_ammo_box_pile_01 (armory loft ammo pile)** @ (715,170,193.1) yaw 90 — *intersection*
   - Problem: The pile's yaw-90 bbox (74x110, clip x[678,752]) grazes ~4u into the loft's west wall at x=682. Sub-perceptual for an irregular sandbag/ammo-pile mesh and the clip is baked matching, but it is a true numeric overlap.
   - Fix: Nudge to (720,170,193.1) (+5x) if ever touching the loft again; not worth a solo bake. No riser concern (loft z192 has no spawner structs).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_surface_deco.gsc:120; tools/add_prop_clips.js:595`

---

## Abyss L2–L5 + Gantry

**Props audited:** 143 baked / 9 script-spawned. **Issues:** 15.

**Coherence read:** The four-floor "Infected Descent" story (L2 Faltering Grid -> L3 Corruption Bloom -> L4 Specimen Vault -> L5 The Maw) is strong and mostly executed with real care: every egg/poison-stalk sits at its measured pivot lift (13.5u/14.2u above floor - verified against bins), all 12+ wall runes are correctly wall-flush at eye height, all ceiling organics correctly use roll 180 hung from the slab bottoms, the clip ledger matches the props, and the deliberate compositions (server row, pig-slab + severed head at exactly slab-top z, hive nests, snake arch framing the Paradise door) read as intended. The defects are one systematic class, not scattered sloppiness: SHEET/PANEL models rotated with the boxy-prop wall-yaw convention or with yaw alone. Z-flat models (both boils panels, the 96x96 zod glyph - L3's three emissive glow anchors!) can never face a wall without pitch/roll, and X-thin sheets (the two original L3 nerve vines, membrane_02, plant04 arm) need the wall yaw rotated 90 from the boxy convention - the NEWER placements (L2 S-wall vine, Gantry N-wall vine, L5 N-wall tentacles_01) already do this correctly, so fixing the older ones also unifies the convention. Second theme: the solid-ified Gantry deck (z[-960,-848]) entombed two later-pass props placed at floor z inside its footprint. What would elevate the area: (1) fix the 8 orientation cases + de-tomb/delete the 2 deck-buried props + seat the floating warning light (all exact fixes given); (2) the L5 E bay lost its jade-fountain centerpiece (user-driven "pig-head" removal, 2026-07-30) and now has no hero between the monolith and the egg field - consider a replacement centerpiece from the snake/crystal set; (3) _acc_abyss_deco.gsc is now a STALE ledger vs the .map (corpses/fountain/meat-hooks/signage/cage-traps removed, alien swaps applied) - the acc_abyss_deco=1 dev twin path would resurrect removed models and double everything; add a tombstone comment or sync the GSC ledger; (4) L2's infestation trio is held to a lower standard than L3-L5 (big free egg unclipped mid-lane, poison stalk unclipped) - one small clip pass makes the floors consistent. props_scripted=9 counts the live gameplay props in the band (2 Overclock terminals, 2 ammo crates, Glitch Altar base+orb, L2 teleporter pad, L2 perk-scatter pad, Gantry boss-item pickup); the soul-defeat lamp sets are event-spawned and correct by design.

**Top 5 most player-visible:**

- L3's three emissive glow anchors (2 boils panels + the purple zod glyph) are Z-flat models rotated with yaw only - they render as horizontal glowing shelves half-buried in the walls instead of vertical wall growth
- A 100x117u alien egg (the orphaned 'consumed-soldier glow partner') is 100% entombed inside the solid Gantry deck - invisible, with a dead clip, since the soldier's 07-30 removal
- The L4 red warning light floats in mid-air 60u up with nothing under or behind it (28u off the specimen tank) - seat it on the tank top
- Four wall-growth sheets (both original L3 nerve vines, membrane_02, the plant04 arm) stand edge-on/perpendicular to their walls - the boxy-prop wall-yaw convention applied to thin-sheet models, 90 degrees off
- The 187u wall-climbing frond at (460,2095) is 60% buried in the solid Gantry deck and reads as a stub sprouting mid-platform - re-home it floor-standing against the L4 E wall

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[H] p7_zm_gen_apoth_int_boils_01_128x128a_emissive** @ (-758, 1900, -690) [.map line 23376, L3 W wall] yaw (0 90 0) — *orientation*
   - Problem: Model is natively Z-FLAT (bin 121x124x19, sheet lies in the XY plane) - yaw-only rotation leaves it a HORIZONTAL glowing shelf ~30u above the floor, half-buried in the W wall. This is L3's primary emissive glow anchor, so the error is lit and visible in the pitch-black floor.
   - Fix: angles (90, 0, 0) [pitch 90 maps the panel normal +Z to +X = faces into the room off the W wall], origin (-760, 1900, -650) so the vertical panel centers ~70u above the floor. If the backface renders, use (270, 180, 0).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23376; bin bounds via tools/xmodel_bin_inspect.js`
2. **[H] p7_zm_gen_apoth_int_boils_01_64x64a_backlit** @ (795, 2000, -670) [.map line 23389, L3 E wall] yaw (0 270 0) — *orientation*
   - Problem: Same Z-flat class (bin 60x69x12): yaw-only = horizontal slab hovering 50u up, half inside the E wall. Documented intent 'boils, E wall' = vertical wall growth.
   - Fix: angles (270, 0, 0) [pitch -90 maps +Z to -X = faces into the room off the E wall], origin (797, 2000, -650). Flip to (90, 180, 0) if backfaced.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23389; _acc_abyss_deco.gsc:141`
3. **[H] p7_zm_gen_apoth_int_boils_01_128x128a_emissive** @ (795, 1850, -655) [.map line 25582, L3 E wall, infestation-pass addition] yaw (0 270 0) — *orientation*
   - Problem: Third horizontal boils panel: mesh x[-57,64] at yaw 270 puts most of the 121u slab INSIDE the E wall with ~57u protruding as a floating glowing ledge at knee/waist height.
   - Fix: angles (270, 0, 0), origin (797, 1850, -645) (vertical, flush E wall, clear of the 64x64 panel at y2000).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:25582`
4. **[H] p7_zm_zod_symbol_96_apothicon_purple_emissive** @ (-758, 2080, -660) [.map line 23402, L3 W wall] yaw (0 90 0) — *orientation*
   - Problem: The PURPLE GLYPH is a ZERO-thickness 96x96 decal flat in the XY plane (bin z-size 0.0). Yaw-only rotation leaves it a horizontal invisible-edge-on sheet floating 60u up, half embedded in the W wall - the intended 'wall glyph' hero read is completely lost.
   - Fix: angles (90, 0, 0) so the decal plane faces +X into the room; origin (-761, 2080, -640) (1-3u proud of the wall face to avoid z-fighting). Adjust yaw/roll afterward if the glyph artwork is rotated.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23402; _acc_abyss_deco.gsc:142 ('flat - no clip' = flat ON the wall intent)`
5. **[H] p7_zm_gen_apoth_int_nerve_vine_01** @ (-758, 1770, -719) [.map line 23415, L3 W wall S corner] yaw (0 90 0) — *orientation*
   - Problem: Vine is an X-THIN sheet (bin 4.1 x 59 x 92 - sheet lies in the YZ plane, flush to E/W walls at yaw 0). Yaw 90 turns the sheet perpendicular: a 4u-thick fin sticking straight out of the W wall. The boxy-prop wall convention (W=90) was applied to a sheet model - 90 degrees off. Documented intent: 'near-flat wall growth, decal-class'.
   - Fix: yaw 0 (angles (0,0,0)); keep origin. If the sculpted face points into the wall, use yaw 180. (Compare: the newer L2 S-wall vine at (-430,1727,-450) yaw 90 and the Gantry N-wall vine at (520,2170,-840) yaw 270 are CORRECT for sheets - this original pair is the odd one out.)
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23415; _acc_abyss_deco.gsc:144`
6. **[H] p7_zm_gen_apoth_int_nerve_vine_02** @ (795, 1770, -717) [.map line 23428, L3 E wall S corner] yaw (0 270 0) — *orientation*
   - Problem: Same X-thin sheet class (bin 4.1 x 39 x 91): yaw 270 = sheet perpendicular to the E wall, edge-on floating fin instead of flat wall growth.
   - Fix: yaw 180 (angles (0,180,0)); keep origin. Fallback yaw 0 if backfaced.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23428; _acc_abyss_deco.gsc:145`
7. **[H] p7_zm_gen_apoth_int_membrane_02** @ (650, 1740, -720) [.map line 23454, L3 S wall] yaw (0 0 0) — *orientation*
   - Problem: membrane_02 is thin in X (bin 11.5 x 31 x 54) unlike membrane_01 (thin in Y) - at yaw 0 it stands as a fin perpendicular to the S wall, extending 30u north into the room. Its sibling membrane_01 placements (N wall yaw 180) are correct; this one inherited the wrong axis convention.
   - Fix: yaw 270 (sheet parallel to the S wall, body extends +X east along the wall); optionally nudge y 1740 -> 1730 for a snugger wall hug. Fallback yaw 90.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:23454; _acc_abyss_deco.gsc:147`
8. **[H] custom_ghost_alien_plant04_arm_01** @ (-140, 1730, -720) [.map line 26941, L3 S wall base] yaw (0 90 0) — *orientation*
   - Problem: 113u-tall wall-climbing arm, thin in Y (bin 41 x 12 x 113) - flush against N/S walls at yaw 0. Current yaw 90 puts the flat climbing face perpendicular to the S wall (edge-on fin). It replaced alien_weeds01 in the 07-29 swap pass with a stale yaw; the swap comment calls it 'a wall-growth arm'.
   - Fix: yaw 0 (angles (0,0,0)); keep origin. Use 180 if the sculpted face points into the wall.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:26941; CHANGELOG.md:800-804 (swap pass intent)`
9. **[H] custom_ghost_armory_alien_egg_01** @ (350, 2075, -947) [.map line 27020, L4 - INSIDE the Gantry deck] yaw (0 30 0) — *intersection*
   - Problem: 100% ENTOMBED in the solid worldspawn Gantry deck (deck x[140,780] y[2013,2173] z[-960,-848]; egg mesh top -914 is 66u below the deck top). Invisible in game. It was 'the consumed-soldier glow partner' - the soldier was removed 2026-07-30, orphaning it. Its clip inf_l4_soldier_egg (add_prop_clips.js:628, bot -960 top -902) is also dead weight inside solid geometry.
   - Fix: DELETE the misc_model and the inf_l4_soldier_egg clip entry (cleanest - its story partner is gone). Alternative re-home south of the deck at (350, 1975, -947) yaw 30 with the clip moved to match. Riser check: no spawner structs exist below z -400, so abyss-floor moves are riser-safe.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:27020; tools/oneshots/gen_abyss_mezzanine.js DECK_BOT=-960/DECK_TOP=-848; CHANGELOG.md:755-765`
10. **[H] custom_ghost_alien_plant03_arm_01** @ (460, 2095, -960) [.map line 27006, L4 - inside the Gantry deck footprint] yaw (0 180 0) — *intersection*
   - Problem: 187u 'wall-climbing frond' (bin 46 x 20 x 187) planted at FLOOR z inside the solid deck block: the bottom 112u is buried; only a ~69u stub pokes out of the deck top mid-platform, nowhere near a wall. Swap-pass intent was a wall-climbing frond replacing the deck warning light. It cannot stand on the deck either (112u headroom < 187u model).
   - Fix: Move to the E wall south of the deck, floor-standing: origin (778, 1950, -954), yaw 90 (thin-Y sheet flush to the E wall; fallback 270) - full 187u visible, top -773 clears the -736 ceiling, clear of the containment vessel (758,1820) and cylinder (560,1870), visible from both the floor and the deck. Riser-safe (no spawners below -400).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:27006; CHANGELOG.md:800-804; gen_abyss_mezzanine.js deck consts`
11. **[H] p7_zm_asc_light_cage_warning_red** @ (-460, 1905, -900) [.map line 25728, L4 W bay] yaw (0 90 0) — *floating*
   - Problem: 13x13x13 caged warning light with floorLift 0 (base-pivot) floating in mid-air 60u above the floor, ~28u SW of the specimen-tank clip edge (tank clip x[-432,-368] y[1915,1981]) - attached to nothing.
   - Fix: Seat it ON the specimen tank top: origin (-415, 1930, -840) (tank clip top is -840), angles (0, 0, 0) - reads as the specimen tank's alarm beacon, matching the L4 vault story.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:25728; tools/add_prop_clips.js:138 (deco_l4_tank)`
12. **[M] p7_zm_gen_apoth_int_membrane_01** @ (-740, 2020, -480) [.map line 25452, L2 near W wall] yaw (0 30 0) — *rotation-smell*
   - Problem: Non-cardinal yaw 30 with no crash/chaos comment: the membrane (back plane at local y=0, body extends -Y) stands ~20u off the W wall angled 60 degrees away from it, freestanding diagonal between the server rack (-756,1900) and breaker cabinet (-756,2050). Every other wall membrane is wall-flush at a cardinal yaw.
   - Fix: yaw 90, origin x -740 -> -754 (back plane against the W wall, body extends +X into the room, clear of the breaker at y2050).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:25452`
13. **[M] custom_ghost_armory_alien_egg_01** @ (490, 1810, -467) [.map line 25465, L2 E bay open floor] yaw (0 250 0) — *placement*
   - Problem: A 100x117u knee-high egg free-standing mid-floor in the E bay walk lane (85u off the S wall, near the ammo-crate approach), UNCLIPPED - players walk straight through it. Breaks both the 07-29b clip policy (free-standing eggs get core boxes; only wall-FUSED eggs stay unclipped) and the grouping pattern (its two L2 siblings are corner/wall-fused).
   - Fix: Fuse it to the S wall beside the tunnel rib: origin (520, 1748, -467), yaw 250 kept (egg z-lift 13.5 is correct as-is). If kept free-standing instead, add a 24u core clip like its L3-L5 siblings. Riser-safe (no spawners below -400).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:25465; tools/add_prop_clips.js:626-628 policy comment`
14. **[L] p7_zm_sta_dragon_network_data_terminal (Overclock kiosk, script-spawned)** @ (-400, 1948, -480) [L2 W bay; twin at (400, 1948, -1200) L5 E bay] yaw 0 (no angles passed - spawn_terminal_at yaw arg is 0) — *orientation*
   - Problem: Both abyss Overclock terminals stand at yaw 0, screens facing +-Y - side-on to the player approach, which is always along +-X from the central stairwell. Gameplay is unaffected (64u radius trigger) but the kiosk face/screen reads sideways at both stations.
   - Fix: Pass yaw 90 for the L2 W-bay terminal and yaw 270 for the L5 E-bay terminal in _acc_glitch_altar.gsc:106/109 (faces the stairwell approach; flip 180 if the model front proves to be +Y - front axis unverified from bounds alone, bin is 48x34x78 with asymmetric Y).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:106,109; _acc_overclocks.gsc:267-271`
15. **[M] custom_ghost_alien_plant05_top_01 (+_cyan/_blue recolors)** @ (310, 1745, -717) / (620, 2150, -717) / (760, 1950, -717) [L3] yaw (0 90 0) / (0 10 0) / (0 140 0) — *floating*
   - Problem: All three sit at z -717 with floorLift 0.1 - hovering ~2.9u above the -720 floor (they inherited the removed tall_grass models' z, which had a different pivot). Imperceptible at distance but visible on close inspection of a 204u-long floor sprawl.
   - Fix: Drop z -717 -> -719.9 on all three; yaws are fine (organic sprawl).
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:25556,26915,26928; CHANGELOG.md:800 (swap kept old z)`

---

## Paradise

**Props audited:** 81 baked / 15 script-spawned. **Issues:** 10.

**Coherence read:** The BAKED layer tells a genuinely coherent two-voice story and survived the 2026-08-02 compression cleanly: zero orphans (all 71 deco statics sit inside x[-700,700] y[-2000,-600]; nothing intersects the new walls — wall pieces sit at x=+/-695/y=-1995 i.e. 5u proud, correct), the synthwave-oasis ring (7 palms on corners/mid-walls/S-center + 5 grass patches at palm bases + 2 ferns flanking the hall mouth) stays edges-only leaving the arena floor open for the 5-boss finale, and the ACCINF02 infestation reads deliberately (heart stack at S-center, satellite broods at the W/E mid-walls matching the niche nests at (-645,-1005)/(650,-995), egg field along the N band, mirrored poison pairs at 0/180, wall runes and vines following the map-wide S=0/N=180/W=90/E=270 wall convention exactly). The .map perk row (10 machines, y=-820, yaw ~0 = front south into the plaza per the verified -Y vending convention) is correctly oriented. Clips in add_prop_clips.js all match live GSC origins — no stale-clip ghosts. Teleporter pads: none exist in Paradise (Lab (150,3450,0) / Exchange vault (-640,40,-160) / trench L2 — all outside this area), so no audit action. What DRAGS the area down is the GSC amenity layer: every scripted station was spawned with blanket yaw 0 or no angles at all (the surface_deco header even self-reports 'yaws are first-pass - flip any backward-facing prop after the walk' — the walk never happened down here). Elevating it = one orientation pass rotating all station fronts toward plaza center (E-side 270 / W-side 90 / PaP 180), giving the wonder-loot ring tangent yaws + a display spin, and explicit angles on the box and bench row — after that pass the shopping ring would address the player the way the perk row already does, and the room reads finished.

**Top 5 most player-visible:**

- Paradise PaP (0,-1550) — the machine every player walks straight to from the hall mouth — likely faces AWAY (south) at blanket yaw 0; rotate 180 to greet the approach.
- All 4 side kiosks + bottle station share copy-pasted yaw 0, so the mirrored E/W shopping ring cannot face the plaza from both sides (E-side needs 270, W-side needs 90).
- The 5 wonder-weapon reward pickups — the map's climax payoff — hover in a ring all at identical default yaw 0 with no spin; tangent yaws + a RotateYaw display fixes the flattest moment in the area.
- Mystery box (450,-1900) and the 3-table Implant Bench row spawn with angles never written — the whole south shopping band's orientations were defaulted, not designed.
- S-center palm (-80,-1950) crowds/interpenetrates the infestation heart stack at (0,-1930) in the canopy z-band — shift it to (-180,-1950) (riser-clear) so the heart owns its centerpiece.

**All findings** (H = data-proven, M = strong smell / front axis unverified, L = needs in-game eye):

1. **[M] p7_zm_sta_dragon_network_data_terminal (Overclock kiosk)** @ (550, -1180, -1200) yaw 0 — *orientation* *(front axis inferred from the -Y vending precedent + Lab 270 usage; mirror-pair contradiction itself is high)*
   - Problem: All 4 side kiosks + both W armory stations use blanket yaw 0 (spawn_paradise passes 0 everywhere). Mirrored E/W pairs with IDENTICAL yaw cannot both face the plaza — logically at least one whole side shows its back/side. Under the project's verified vending convention (memory perk-scatter-map-wide: 'vending front = model -Y'), yaw 0 puts this terminal's screen facing SOUTH, parallel to the E wall, so players approaching from the plaza center (west) see its 34u side profile. The Lab's copy of this same model is deliberately yawed 270 (add_prop_clips.js:404), proving per-site rotation is the norm elsewhere — Paradise just never got the pass (the deco module header literally says 'yaws are first-pass - flip any backward-facing prop after the walk').
   - Fix: _acc_glitch_altar.gsc:150 -> spawn_terminal_at( (550,-1180,pz), 270 ) so the screen faces west into the arena; swap clip dims in tools/add_prop_clips.js:72 to hx:17 hy:24 (90-degree AABB swap). Yaw-only + clip swap, no origin move, no riser impact.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:150; tools/add_prop_clips.js:72`
2. **[M] p7_zm_sta_drop_pod_console_blue (Neural Expansion perk-slot vendor)** @ (550, -1680, -1200) yaw 0 — *orientation*
   - Problem: Same blanket-yaw-0 defect: console screens face south (front=-Y convention), perpendicular to every approach from the plaza; E-side kiosk should address the arena to its west. Its Foundry twin at (120,1550,-240) is also yaw 0 (out of this area but same smell).
   - Fix: _acc_glitch_altar.gsc:152 -> spawn_perk_slot_vendor_at( (550,-1680,pz), 270 ); swap add_prop_clips.js:74 dims to hx:22 hy:25.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:152; _acc_perks.gsc:247-251; tools/add_prop_clips.js:74`
3. **[M] p7_cry_cryogen_pod_exterior (Exo Suit station)** @ (-550, -1680, -1200) yaw 0 — *orientation*
   - Problem: W-side station at yaw 0: pod door/glass faces south toward the S wall band, not east toward the arena players approach from. Note the Scientist's Office copy at (-200,4120,0) yaw 0 is CORRECT there (front-south = toward that room's S door), which shows yaw 0 was copy-pasted here, not chosen.
   - Fix: _acc_glitch_altar.gsc:151 -> spawn_station_at( (-550,-1680,pz), 90 ) so the pod face points east into the plaza; swap add_prop_clips.js:73 dims to hx:26 hy:29.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:151; _acc_exo.gsc:106-110; tools/add_prop_clips.js:73`
4. **[M] p7_zm_vending_wonder (mega-bottle / Implant exchange)** @ (-550, -1430, -1200) yaw 0 (never set - spawn_bottle_station takes no yaw and never writes angles) — *orientation* *(this model family's front axis IS verified; only the exact best-facing choice is judgment)*
   - Problem: A Wonderfizz vending machine — the exact model class the 'vending front = model -Y' rule was verified on — standing 150u off the W wall with its bottle-display front facing SOUTH at the Exo pod, not east at the plaza. spawn_bottle_station has no yaw parameter at all, so this can never be right anywhere without a code touch.
   - Fix: Add a yaw param to _acc_armory.gsc:430 spawn_bottle_station( origin, yaw ) (default 0 to keep the loft copy), set base.angles=(0,yaw,0); call with 90 from _acc_glitch_altar.gsc:159; swap add_prop_clips.js:78 dims to hx:28 hy:37.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc:430-434; _acc_glitch_altar.gsc:159; tools/add_prop_clips.js:78`
5. **[M] p9_fxanim_zm_gp_pap_xmodel (2nd Pack-a-Punch, standalone vendor)** @ (0, -1550, -1200) yaw 0 — *orientation* *(front axis unverified for this specific ALXS mesh; one in-game look at the surface PaP pins 0-vs-180)*
   - Problem: THE centerpiece machine of the reward plaza, dead on the hall-mouth axis (players enter at (0,-600) and walk straight south to it). At yaw 0 with the -Y front convention the machine faces SOUTH — every arriving player walks up to its BACK. This is the single most player-visible orientation in the area (also the wonder-loot ring anchor and the Avogadro pinned seek point — those track the trigger/origin, not the yaw, so a rotation is safe).
   - Fix: _acc_glitch_altar.gsc:175 -> spawn_paradise_pap_at( (0,-1550,pz), 180 ) so the intake faces north at the entrance approach. 180-degree turn keeps the clip AABB dims (add_prop_clips.js:107) but the clip is offset-centered at y=-1552 for an asymmetric mesh — re-measure and flip the offset to y=-1548 if the model is not origin-centered.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:175; _acc_pap_levels.gsc:974-980; tools/add_prop_clips.js:107`
6. **[H] 5x wonder-weapon world models (thundergun / ray gun / demongate bow / leviathan / freezegun reward pickups)** @ 120u ring around (0,-1550,-1200), at ring angles 0/72/144/216/288 yaw 0 for ALL five (spawn_one_wonder_pickup never sets m.angles) — *orientation* *(default-angles fact is proven by code; fix is pure presentation)*
   - Problem: The map's climactic reward moment: 5 wonder weapons hovering 24u off the floor in a ring around the PaP, every one at identical default yaw 0 — parallel guns pointing the same arbitrary direction regardless of ring position. Reads as spawned, not presented; the Paradise-box display model 30 lines up already does the correct rise+RotateYaw flourish, so the polish precedent exists in-file.
   - Fix: In _acc_paradise.gsc spawn_one_wonder_pickup (line ~1277 after the setmodel): pass the ring angle through and set m.angles=(0, ang+90, 0) (tangent to the ring, muzzle counter-clockwise) and add m RotateYaw(360,8) looped for a slow display spin, mirroring paradise_box_loop's dsp treatment.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_paradise.gsc:1256-1262, 1268-1279`
7. **[M] p7_zm_der_magic_box (permanent Paradise mystery box)** @ (450, -1900, -1200) yaw 0 (never set - spawn_paradise_box_at writes no angles) — *orientation*
   - Problem: The box's angles are never assigned, so it sits at default yaw 0, 100u north of the S wall with players approaching from the north/arena. If the der-box lid/front is its -Y long face (unverified), the display side addresses the S wall. Whatever the answer, this orientation was never chosen — the field is simply absent.
   - Fix: Set box.angles explicitly in _acc_glitch_altar.gsc spawn_paradise_box_at (line ~193, after setmodel): (0,180,0) if the front proves to be -Y, else keep (0,0,0) but make it explicit with a comment. One in-game look pins it. Origin stays (no riser impact; DisconnectPaths cut is position-keyed - do NOT move it).
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_glitch_altar.gsc:191-199, 170`
8. **[M] 3x p7_zm_isl_table_operating (Implant Bench pads, slots 1-3)** @ (-610,-1810,-1200), (-450,-1810,-1200), (-290,-1810,-1200) yaw 0 all three (spawn_bench_pad never sets angles) — *orientation*
   - Problem: Three operating tables in a 160u-spaced X row, all at unset default yaw. If the table's long axis runs along X at yaw 0 (typical for this mesh), the row reads as one broken end-to-end line instead of a side-by-side surgical bay; the map's own baked copy of this model (L3, .map line 23650) is deliberately yawed 30, proving per-site yaw is the norm. Also a uniform 0/0/0 row is exactly the 'pristine grid' smell in a room whose S band is otherwise organic infestation chaos.
   - Fix: Add an angles write in _acc_boss_items.gsc:3360 (bench.angles=(0,yaw,0), yaw param defaulting 0 to protect the Plaza lab row) and call the three Paradise pads with yaw 90 each from _acc_glitch_altar.gsc:166-168 (tables side-by-side, head toward the S-wall brood, work side facing the arena). Verify long axis in one look first. No clips exist on bench pads; no origin change; nearest riser (-420,-1750) is >100u — clear.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_boss_items.gsc:3358-3363; _acc_glitch_altar.gsc:166-168`
9. **[M] jup_vertigo_palm_02 (S-wall-center palm, clip m6_pd_palm7)** @ (-80, -1950, -1197) yaw 210 — *intersection* *(z-band overlap computed from model heights, not a mesh-accurate test; needs one in-game look up)*
   - Problem: The palm stands 82u horizontal from the 3-piece infestation heart stack at (0,-1930) (custom_ghost_alien_plant01 base z-1179 / middle z-980 / top z-837). A 519u palm's canopy spreads at roughly z[-900,-700] with ~150-200u reach — the alien plant's middle+top segments occupy the same z-band inside that radius, so the two hero pieces very likely interpenetrate overhead, and at ground level the lush-oasis palm sits INSIDE the alien heart's story space (theme collision: the heart should own the S center per the infestation design).
   - Fix: Shift the palm west to (-180,-1950,-1197), keep yaw 210 — still the 'S center' edge-ring slot, 100u clear of the heart column. Move in lockstep: the baked misc_model (.map line 17681), the GSC twin (_acc_surface_deco.gsc:100), and the m6_pd_palm7 trunk clip in add_prop_clips.js. Riser check done: nearest Paradise risers (-420,-1750) and (0,-1650) are 296u/312u away — clears the 45u standard.
   - Source: `map_source/zm/zm_abandoned_cyber_city.map:17681 + 26093-26119; scripts/zm/zm_abandoned_cyber_city/_acc_surface_deco.gsc:100`
10. **[L] p7_con_cargo_train_armory_cabinet (team weapon rack)** @ (-550, -1180, -1200) yaw 0 (never set; long axis X per clip comment '138x18x48, yaw 0 (long axis X)') — *rotation-smell* *(works as designed; purely an environment-artist preference)*
   - Problem: A 138u-long, 18u-deep storage cabinet freestanding mid-floor with its long axis pointing AT the W wall's normal (E-W), violating the 'tall storage backs against walls' rule — players on the W lane meet its 18u end cap. Mitigating: this is deliberate station architecture (deposit/withdraw pads hardcoded at origin +/-55 on X sit at the cabinet's two ends, same as the Armory loft copy), so the freestanding read has a documented gameplay reason.
   - Fix: Optional, lowest priority: rotate to yaw 90 (long face parallel to the W wall, presented to the plaza) — requires moving the pad offsets to +/-55 on Y in spawn_rack_station (needs a yaw-aware offset, _acc_armory.gsc:113-114) and swapping the paradise_armory_rack clip (add_prop_clips.js:77) to hx:9 hy:69. If untouched, at least it is consistent with the loft twin.
   - Source: `scripts/zm/zm_abandoned_cyber_city/_acc_armory.gsc:101-117; _acc_glitch_altar.gsc:158; tools/add_prop_clips.js:77`

---

---

# PHASE B — The Walkabout Checklist (2026-08-03)

One route, ~15 stops, each a yes/no glance. **You don't hunt — the list says where to look
and what to check.** Answers convert directly into exact yaw/origin fixes; several single
answers unlock whole batches (marked **[BATCH]**). Screenshot anything else that looks wrong.

**Route: spawn → Plaza → connector → Bus Station → Alley/Market → Vault → Roof → Lab/office
→ trench rooms → Abyss → Paradise.**

1. **Spawn — stand still, look ahead.** Does the fountain angel face YOU? Do both bench rows
   face the fountain (or away)? Does the mystery-box printer's door/screen face you or the
   S wall?
2. **Plaza N wall.** Dead neon sign over the planter bed: readable text, or edge-on? The
   camomile planter box beside the hollyhock: parallel to the wall or sticking out?
3. **Plaza W (Quick Revive).** The parking block: parallel to the wall like the S-row pair?
4. **Connector.** The rampage breaker: panel face or blank back toward you? (One yaw flip.)
5. **Bus Station benches.** The ceiling-hung holo departures board: readable from the seats,
   or edge-on? (The TVs below it are already fixed.) BANK sign over the ticket counter: OK as
   a blade sign? Kiosk canopy piece sitting on the floor next to its base: keep or remove?
   NO PARKING post: should it lean (its comment says so)? N-lounge armchair: faces the bay
   or the wall? Orphaned traffic barrier mid-floor near the old coach spot: remove/re-home?
6. **Alley/Market.** Ice-cream sign (N wall): readable? Live TV on the W counter: screen out
   or at the wall? Market stall B: open counter toward the lane? Leaned window frames (E+W):
   both actually resting on their walls? DINER neon: flat on the wall? Stray diner chair
   mid-floor: keep? **Two farm wheelbarrows** in the cyber alley: keep or purge (last rural
   leftovers)?
7. **Vault.** W-wall RED-ALERT security screen: facing the wall 17u away? **[BATCH]** — yes
   also flips the E-wall static-monitor set. S-wall row (cabinet / generator / terminal /
   yellow handrails): visible dead gap behind them? **[BATCH]** — yes = flush the whole
   pass-2/3 row to the real y2280 wall plane.
8. **Roof.** N-wall junk row (animal cage / dolly / radiator): fronts into the wall?
   **[BATCH]** — one yes flips all three. Work-light tripod: aimed at blank wall instead of
   the bomber? Warning cloth: hovering in front of the chainlink instead of on it? Radiator
   + full street lamp indoors: keep or swap for mil-tech? *(The NE fuel tank is 28u from a
   riser — under the 45u standard; I'll move it next batch regardless of the walkabout.)*
9. **Lab + office.** New N-wall consoles: screens out? X-ray lightbox in the office: hanging
   vertical or lying flat? N-wall specimen chamber: opening out? Lab coat on the office S
   wall: flat or edge-on? Office holo screen: OK free-floating? Server-island E terminal:
   screen into the rack? Bus-booth chair as the scientist's desk chair: keep?
10. **Trench rooms.** Neural Expansion console + L5 Overclock + the (now-raised) Exchange
    ATM row: screens toward YOUR approach? **[BATCH]** — rotate the station set. Jukebox:
    floating mid-wall-less? Reactor plinth: still reads centered? Slots machine: back
    exposed to the room? Pit caches: mirrored-identical crates OK? Glitch Altar: end-on
    approach OK, or rotate broadside?
11. **Abyss.** L2: diagonal membrane; the walk-through knee-high egg in the E-bay lane
    (clip it or remove?). L3 NEW positions from Phase A: boils panels vertical on the walls
    now — do they read as wall growths? Purple glyph: visible art, right way up? Does its
    air-gap off the bare rock read OK? *(3 hovering plant tufts sit 2.9u off the floor — I'll
    fix the z next batch regardless.)*
12. **Paradise — the one big question.** Walk in from the hall straight to the 2nd
    Pack-a-Punch: does it FACE you? **[BATCH]** — if not, that answer unlocks the whole
    blanket-yaw-0 sweep: PaP, Wonderfizz vendor, Exo pod, all 4 side kiosks, the W armory
    cabinet + rack, the magic box, and the 3 implant benches (side-by-side vs end-to-end —
    say which way the operating tables run). Also: the 5 wonder pickups now spin tangent to
    the ring — does the ring read "presented"? S-wall palm canopy vs the infestation heart
    stack: clipping?

**Pre-answered next-batch items (no walkabout needed):** roof fuel tank riser clearance;
abyss plant05 z-hover; the Plaza cache-crate yaw variance (15/350/20/345) if you approve the
"deliberate scatter" look — say yes/no to that one whenever.

---

# WAVE STATUS (2026-08-03)

**Wave 1 — APPLIED** (CHANGELOG "PROP AUDIT PHASE A" + "WAVE 1"): the 28 data-proven HIGH
fixes plus the ~115 walkabout-calibrated fixes the four user answers made provable. Shipped:
- **Calibrations locked into `tools/add_prop_clips.js` header** (the per-family front-axis
  ledger): t10 bench front=−X, t10_zm signs face=+Y, p7_zm_tra flat-backs front=−Y,
  vending/station front=−Y, dragon terminal front=+X, p8_zm_off monitor front=−Y,
  p7_cru holo +X, ATM back-face origin +X mesh, angel −Y (Gorod console still UNVERIFIED).
- **Plaza/Bus/Alley/Market:** benches+angel flipped to face the fountain/spawn; cache crates
  get scatter yaws; departure-board TVs, ice-cream sign, stall B, window frame, staff lockers,
  stove, oilrack/barrel un-embed, neon strips, sink un-interpenetrate; NO PARKING post leans;
  armchair + traffic barrier + suitcases re-posed.
- **Vault/Roof/Lab:** E-row un-embed (~11u west to the x1919 face); N-wall junk row flipped;
  tripod re-aimed at the wreck; fuel-tank riser clearance; lab consoles/holo/chamber/coat/
  terminal re-faced; ATM re-faced west + row-flush; sci_console clip AABB corrected.
- **Trench/Abyss/Paradise stations (front=−Y validated):** Paradise PaP 0→180, kiosks→180,
  Exo pod→90, Wonderfizz→90, team rack→90, magic box→180, 3 implant benches→90 (+clip
  re-sync off stale pre-compression coords); trench Exchange ATM row, Neural console, L2/L5
  Overclocks, Glitch Altar broadside; wonder pickups spin tangent to the ring.
- **Cleanup:** deleted 2 farm wheelbarrows, roof radiator+lamp, L2 walk-through egg, orphaned
  kiosk canopy; jukebox + reactor plinth re-homed to real walls; abyss plant tufts seated.
  All clips regenerated (274 worldspawn + 135 brushmodel; 5 deleted).

**Wave 2 — SCOPE** (per-area recomposition, docs/47 Phase C; one area per pass, baked +
reviewed before the next). Still on the WALKABOUT list (deferred, unanswered stops — need one
in-game glance each before they convert to yaw fixes):
- live-TV facing (W counter vs S table); DINER neon flat-vs-edge-on;
- Plaza dead neon sign, camomile planter box, W parking block, AW mystery-box printer face,
  BANK blade sign, rampage-breaker yaw check;
- mid-room Alley shelf (KEPT per the difficult-navigation rule — no change unless user says);
- Vault S-wall stale-plane rows (user answered "no gap = fine" — left as-is);
- ~~the Plaza→Alley connector density pass~~ — SHIPPED this wave (10-prop gradient, see the finding-4 PLACED note);
- the cache-crate yaw-variance approval (pre-answered above, awaiting yes/no).

**Ledger hygiene done this wave:** `tools/add_prop_clips.js` front-axis header; the
`_acc_abyss_deco.gsc` stale-ledger tombstone (its twins DRIFTED — never trust for layout);
the `_acc_surface_deco.gsc` mandatory-lockstep note (its twins stayed in sync).

---

# WAVE 3 — CLOSING SWEEP (2026-08-03)

**The permanent gate shipped:** `tools/lint_prop_placement.js` (wired into
`preflight_windows.ps1`) — riser-vs-clip ≥45u (including the GSC-computed trench/Paradise
eruption spots that caught the altar), clip-vs-clip overlap, .map↔surface-deco twin
lockstep, misc_model hygiene (lightingstate1..4 + hex/unique guids), and the
single-baked-instance light-model cap (the LED crash class). Negative-tested against
injected regressions of every class; passes the live tree 5/5. The next deco pass cannot
silently reintroduce any of today's failure classes.

**Residue applied (all provable under the locked front-axis ledger):** the Vault W-wall
RED-alert monitor set + E-wall static set turned to face the room; the office holo screen
un-edged; the server-island dragon terminal corrected (a Wave-1 regression — flipped with
the refuted −Y axis, now yaw 0 per the +X proof); the **ledger cascade** — 3 more vault
dragon terminals + 2 vault holo screens that the audit blessed under the old axis, all
re-faced; the L2 diagonal membrane seated on its wall; the armory ammo pile un-grazed
from its wall; the pit Data Caches got their scatter yaws; intent comments added (mid-room
oilrack KEEP, roof cage KEEP, L2 terminal yaw rationale).

**Track C:** the Scientist's Office desk chair swapped from the bus-kit booth chair to
`p8_zm_off_chair_office_executive_black` — the audit's "no p8 chair installed" was
refuted (the pack ships it; it was never zoned). Zone line added; clip resized.

**RESOLVED audit items this wave:** Lab #9, #10 (re-derived), #11 (chair); V+R #2, #3;
Trench #8, #10; Abyss #12; Alley #12 (comment); + the 5-item ledger cascade beyond the 98.

**Walkabout list — the FINAL set (everything else is closed):**
1. Market stalls A+B open onto the mid lane? (+ stall C at (-1670,600) — never audited.)
2. W window frame `_02` (1342,830): resting on its wall or leaning away?
3. Roof S-wall trio (oilrack/power panel/handrails): the "no gap" waiver was given at the
   VAULT — one roof glance to confirm or flush.
4. Live TV (market W counter) + DINER neon + plaza dead neon + BANK blade sign + camomile
   planter + W parking block + AW box front + rampage breaker face — the original stops.
5. Vault holo (1900,2400) — may deliberately face the S vault portal; lab free-floater holo
   (-380,3555). Both excluded from the cascade as ambiguous.
6. NEW: the p8 exec chair's front axis is unrecorded — if its back faces the desk, flip
   yaw 180→0. The Paradise wonder-ring tangent yaw (spin mitigates). The scatter-yaw look
   on all 6 cache crates (plaza 4 + pit 2) — retro yes/no.
