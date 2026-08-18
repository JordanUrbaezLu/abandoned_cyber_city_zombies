# Backlog — loose ideas & punch-list

Small, un-scheduled ideas and TODOs that don't yet warrant a `ROADMAP.md` milestone or a
`docs/15_requirements_checklist.md` row. Consolidated 2026-07-12 from the old root `Notes.md`
and `ToDoList.md` (both deleted; this is their single canonical home). Promote an item to
ROADMAP / docs/15 when it becomes real, scheduled work.

## Design ideas
- **Contaminated-area stuck penalty** — a player can get stuck in the contaminated area for a
  round, making survival ~2× harder while stuck. Decide: mitigate it (escape lever / grace) or
  lean into it as intended difficulty.
- **Global recoil buff** — increase recoil across all guns so the Deadshot **Mega** ("perfect
  accuracy") becomes more valuable.

## UI / HUD punch-list
- Add PaP icon **PNG** versions.
- Add an **end-round bar** to the HUD.
## Next-wave enhancements backlog (2026-07-29, next-wave-enhancements workflow)

Ranked frontier candidates BEYOND the docs/46 queue (sound cohesion, living-world motion,
progressive world state, first-impression polish). Every item pre-checked against: CF pools
FULL, G_Spawn cap, fx pcloud/def crash rule, no new dvars, abyss light ban, bake gate.

### Top 12 (impact-per-effort)

RANKED TOP 12 (impact-per-effort; size / build type / constraint grazed):

1. WAKE-UP BEAT (spawn-in via level.customHudReveal) [S | -GscOnly | grazes nothing]. Claim the grep-verified-unclaimed stock hook (_zm.gsc:500): HUD stays hidden ~4-5s after the 1.5s fade lands on the fogged near-black Plaza, theme re-timed to start ON the fade (apply_music already fires at blackscreen+1s), then callback sets hud_visible + weapon_hud_visible itself. Bonus: a HUD-free capture window at spawn. One verify item: is the P1 angel spot lit in the PRE-power lighting state (beat degrades gracefully if not).

2. NOIR RAIN BED v2 [S | game-closed -GscOnly | grazes CC0-lane rule only]. Swap sound_assets/acc/amb/city_bed.wav at the SAME FileSpec (proven docs/23 §7 recipe) for a pre-mixed CC0 rain-on-corrugated-metal loop (freesound 404061 / 509116), flip the EXISTING acc_amb_on default 0->1 at _acc_atmosphere.gsc:616. Rain-only by design — the electrical hum arrives with power (item 3/13), so sound tells the same story as the light. Emitter (level.acc_amb_ent) already budgeted = 0 new slots.

3. CASCADE AUDIO LAYER + the breaker clunks [M | game-closed -GscOnly | grazes sound-bank-regen gotcha (touch zone if bank doesn't regen)]. ~10 one-shot aliases riding the EXISTING beats in power_bootup_cascade()/sign_stutter_ignite()/descent_hive_wake(): stock-named zmb_switch_flip + zmb_power_on override rows (zero code — kills the known silent power flip, docs/23 §6 wire #2), a ~21s 2D riser cresting at t+21, per-district PlaySoundAtPosition breaker thunks at each beat's coordinate, stutter-buzz sharing the false-start beats, hive-wake wet pulses, t+21 finale chord. All transient = ZERO permanent G_Spawn; gated on existing acc_atmo_fx.

4. SECTOR FAILURES — recurring brownouts [S | -GscOnly | grazes lighting-state OWNERSHIP vs docs/46 P2b (needs a small state-owner arbiter so red-alert/Overclock win) + frame-0 spawn refusal (0.5-1s stagger on burst hosts)]. From ~r10, every ~8th round: instant set_lighting_state(0) into the already-baked orphaned pre-power dim mask (63 dim lights + Plaza safe-haven grid), spark/steam bursts at the cascade's curated coordinates, recovery masked by the shipped acc_grade_warm1 hold-then-lerp + sign_stutter_ignite() re-run. Recycles both signature moments as recurring dread; every mechanism shipped today.

5. FOG CREEP + HUE ROT [S | -GscOnly | grazes the "can't-see wall" — capped at 0.62/650 vs pre-power 0.80/550, pure taste risk]. ~20-line round-indexed target table in apply_fog's residual-haze branch (_acc_atmosphere.gsc:263-440, the single SetVolFog authority): r12->r30 opacity 0.55->0.62, halfway 850->650, hue cool blue -> grey-green. Composes with settle machine / paradise_fog_off / abyss untouched. Revert = one #define.

6. DRONE PATROL FLYBY [S | -GscOnly | grazes G_Spawn: 2 slots]. Pure GSC on the ALREADY zoned+precached veh_t7_dlc_zm_quadrotor_piece_body (_acc_boss_items.gsc:104): MoveTo waypoint loop above Plaza wall tops z~450-650, fixed banked angles, linked tag_origin host with already-zoned fx_glow_blink_red_5. Parked pre-power; first launch at cascade t+18. Lowest-risk motion candidate; zero new assets.

7. DESCEND DREAD STINGERS [S | game-closed -GscOnly | grazes nothing — zero slots, reuses acc_trench_surge_cd]. 2-4 CC0 dread swells (intensity scales L2->L5) via PlayLocalSound at the EXISTING deeper-layer transition hook in _acc_bus_trench.gsc ~line 428. Closes docs/23 §5.4's named gap; ~10 lines of GSC.

8. THE INFESTATION GROWS — dark-baked broods that WAKE [M | ONE LED-gated bake + -GscOnly weave | grazes the bake gate (only bake in the top tier) + no-lights-below-lip (satisfied — fungus FX's bare dynamicLight2 class proven below z0 since 07-19)]. Batch-3 one-shot (gen_infestation.js pattern, marker ACCINF03): ~15-20 egg clusters baked DARK at r10/r15/r20/r25 anchors (trench rim -> corridor mouths -> Market/Alley thresholds -> Plaza fountain); at each acc_round_start milestone GSC fires egg_ready bursts then ignites permanent zero-slot fungus loops — the city visibly sickens over TIME. The genuine no-other-workshop-map-does-this differentiator; strongest word-of-mouth candidate.

9. GHOST MONORAIL — Plaza sky crossing + Bus Station audio pass [M | carve+zone+GSC, -GscOnly core (track garnish = optional severable bake) | grazes G_Spawn (2 slots) + carve LOD0 risk (0xC0000409->LOD1) + sky/volume_sun envelopes (path z600-800 clears both)]. Carved p7_out_train_monorail_car_full_no_mods parked Hidden, every 90-150s Show+MoveTo across the open Plaza sky with a blinking fx_glow_blink_red_5 host, then Hide; lidded Bus Station gets the audio ghost (CC0 Doppler rumble + play_fx_burst ceiling flash chain + 0.08 Earthquake, zero permanent slots). Highest wow-per-slot motion beat; crosses in front of the P4 holo skyline.

10. POSTCARD CAPTURE CHECKLIST (docs/38 §3 v2) [S | doc-only | grazes only the dev-arming rule — uses the sanctioned hardcode-and-rebuild path]. 10-shot list keyed to docs/46's postcard column with phase-readiness tags (7 of 12 money shots capturable TODAY); console/dvar-free protocol: hardcoded dev+god build, PLAY_NORMAL.bat, buy doors, flip the real switch, Steam F12 stills, Game Bar video->frame-extract for cascade beats. Prevents wasted user sessions and re-shoots.

11. FAN + DISH SPINNERS [S | -GscOnly for whole-model units; Alley housing variant = one small severable bake | grazes G_Spawn: docs/46 line 138 blesses exactly ONE fan slot — 2-3 units needs a nod]. One-call Rotate((0,speed,0)) forever (docs/16 L295 cited recipe; in-repo precedent _acc_cyberjack.gsc:964): p7_vld_ceiling_fan_01_motor_on under the Bus Station lid, Alley blade-only industrial fan, slow-yaw sat dish on the post-P6 Helipad. Do NOT promise moving shadows (Phase-1 spots are shadowUpdate Never).

12. ORGANIC LOOPS — Paradise heartbeat + fungus pulses [S | game-closed -GscOnly | grazes G_Spawn 0-3 — soul-door ride-along (PlayLoopSound on level.acc_soul_doors ents) is the zero-slot hack to try FIRST, per HACKY IS GOOD]. Always-on wet pulses at the L3 nest + L5 hive, sub-bass heartbeat (DistMaxDry ~800) at the Paradise heart nest — audio carries the infestation gradient where light legally can't below the lip.

BUBBLE (13-16, ship opportunistically): GRID DECAY flicker escalation (S, -GscOnly, zero-everything — ship as garnish inside #4's session; it makes brownouts read as symptoms); POWERED POSITIONAL LOOPS at the flicker anchors (M, THE biggest slot spend at 5 — gate on a dev-session fresh-G_Spawn headroom count, priority-ordered so any can be cut); CARD/THUMB/POSTER BRIEF + TRAILER BEAT-LIST (both S doc-work writable NOW, final art/capture blocked on P3/P4 shots); SETMODEL FLIP-BOOKS (S, wait for the P4c LED-family carves to land, then 1 slot each); DESCRIPTION REFRESH (S, blocked on new screenshots).

### Recommended next session combo

THE SESSION: "The map opens and sounds like the movie" — WAKE-UP BEAT (#1) + RAIN BED v2 (#2) + CASCADE AUDIO LAYER (#3).

Why these three: they are ONE game-closed -GscOnly build (no bake exposure at all), they all live in _acc_atmosphere.gsc + sound/aliases/acc_audio.csv (+ a tiny entry hook for customHudReveal), they cost ZERO permanent G_Spawn / zero clientfields / zero new dvars (only the existing acc_amb_on default flips), and they verify in a single test pass: spawn (rain under a HUD-free near-black reveal, theme landing on the fade) -> buy through to Bus Station -> flip the power switch (it finally CLUNKS via the stock-named zmb_switch_flip/zmb_power_on override rows) -> watch the 21s cascade with its riser, per-district thunks, stutter-buzz, hive-wake pulses and finale chord igniting on the exact frames the light does.

It is also the maximum-cohesion complement to the docs/46 queue rather than a collision: P2b-P7 are all VISUAL phases, and this session gives every one of them its sound+opening framing before they land — plus the wake-up beat's HUD-hidden window becomes the capture vehicle for the post-P3/P4 postcard sessions (#10).

Session order within the build: (a) CSV override rows + wav conversions first (convert_wav_48k_stereo.ps1, CREDITS.md rows per download, License.txt verified — Pixabay/Sonniss excluded per docs/23 §3b); (b) cascade one-shot calls next to the existing play_fx_burst lines; (c) customHudReveal callback + theme re-time last; (d) game-closed -GscOnly build (if the sound bank doesn't regen, touch the zone — memory sound-bank-rebuild-zone-trigger); (e) same-commit updates to docs/23 §1b/§5/§6 + CHANGELOG. Descend stingers (#7) are a natural rider if the session has slack — same wav pipeline, same build, ~10 lines.

### Rejected

REJECTED OUTRIGHT:

1. VIOLENCE ACCUMULATES (transient gore beats at choke points) — fails on impact, not feasibility: true accumulation is REFUTED (FX decal elements fade under the engine marks cap, chalk-mesh grime is bake-time-only, no trustworthy runtime decal API), so it can only ever be momentary flourish players won't attribute; flesh FX are also a high-risk pcloud-material class (the fire-barrel lesson). The P3 baked-grime micro-pass already owns the permanent-dirt read.

2. LIGHTINGSTATE1-4 MODEL HIDE/SHOW as the world-growth lever — schema exists in t7.def.json but ZERO usage across 21,217 misc_models in all 503 stock zm sources, semantics unverified (may only gate baked-lighting contribution), only 4 states exist and ALL are allocated (pre-power/noir/red-alert/brownout), and flips are level-global so transient events would incoherently revert 'growth'. Do not spend a probe bake here — the dark-baked-model + FX-ignition design (#8) achieves the read at zero risk.

3. LITERAL BUS STATION MONORAIL CROSSING (model over the trench) — geometrically dead: the zone is capped by the 1600x1600 lid at z256; there is no sky to cross. Replaced by the audio-ghost pass (rumble + ceiling flash chain), which is IN #9, not lost.

4. PHOTO-MODE DEV COMMAND (HUD-toggle dvar watcher) — requires a NEW dev command dvar, directly against the hardcoded-dev-mode rule (all ~26 such levers were removed 2026-07-16). The wake-up beat's HUD-hidden window + Game Bar frame-extraction cover every hero-frame need.

5. level.player_movement_suppressed FROZEN-CONTROLS INTRO — players hate locked controls, co-op desync risk, and the wake-up beat achieves the cinematic read with controls free.

6. PIXABAY / SONNISS GDC AS SOUND SOURCES — docs/23 §3b rules both prototype-only grey-area (no standalone redistribution inside an extractable .ff). CC0 lanes only (freesound CC0-filter, BigSoundBank, OGA Joth, Kenney), License.txt verified per download, CREDITS.md row even for CC0.

7. SCRIPT_MODEL GROWTH BATCHES for the infestation — dominated design: permanent slots at a ~1024-cap pool (crash measured ~1173), script_models forfeit baked lighting (read wrong under the noir rig), and #8's dark-baked + FX-wake pattern gets the identical read at zero slots.

PARKED (not dead, blocked on a named unknown): RAPID FLICKER-TOGGLE brownout variant — waits on docs/46 checklist item 4 (state-flip latency); ship snap-hold-snap only. SEARCHLIGHT FX-CONE — parked pending the user decision below, NOT rejected on mechanism (zero lights, zero shadow tax).

### User decisions to surface

TASTE / SIGN-OFF CALLS TO SURFACE:

1. SEARCHLIGHT UN-VETO (one line): docs/46 lines 138+208 ban 'the searchlight' — but the stated veto reason is the per-frame shadow tax of a shadowUpdate Always LIGHT. The FX-cone rotator has NO light entity at all (rotating tag_origin host carrying the already-zoned acc_god_ray FX). Approve the no-light fake? If yes, a 5-minute dev pilot first — the god-ray .efx may be world-axis-locked and ignore host rotation (fallback = self-authored beam .efx, which then must pass the pcloud/def-line grep gate).

2. AMBIENT BED GOES ALWAYS-ON: flipping acc_amb_on default 0->1 makes the rain bed permanent for every player. Confirm (a) always-on, and (b) the deliberate rain-ONLY pre-power design — no hum in the bed; electricity arrives audibly at power-on via the cascade/loops.

3. FOG CREEP END-STATE: does the city sickening over rounds exist at all, and if so approve the r30 cap (opacity 0.62 / halfway 650 / grey-green hue) — deliberately far short of the pre-power 0.80/550 'can't see' wall. Revert = one #define.

4. BROWNOUT CADENCE + EXCLUSION WINDOWS: every 8th round vs 20% per-round roll; 5-8s duration; and which windows are sacred (boss red-alert, Overclock, Paradise finale — recommend all three excluded via the state-owner arbiter).

5. PERMANENT G_SPAWN BUDGET FOR THE WHOLE WAVE: worst-case ask across motion+audio is ~18 slots at a ~1024-cap pool. Recommend a hard cap of ~10: monorail 2 + drone 2 + spinners 2 + flip-book 1 + organic loops 0-1 (soul-door hack) + powered loops trimmed 5->2-3. User picks what gets cut, AND a dev-session fresh-slot headroom count is required before ANY slot spends land. Related: docs/46 blesses ONE fan-mover slot — approve expanding to 2-3 spinners?

6. TITLE CARD YES/NO + BLACK HOLD: decide AFTER feeling the text-free wake-up beat in-game (recommendation: v1 ships text-free; title lives on the poster). Also: 0-1s extra added_initial_streamer_blackscreen, or none?

7. BRAND SILHOUETTE for the three-surface rebrand (thumb 512 / card 600x340 / poster 16:9): fountain angel (available now) vs holo city-double (after P4 — strongest mark) vs egg-lit trench mouth. Recommendation: write the brief + 2-3 mockup directions now, lock the icon after P4 ships. No fine text on the 512 thumb (renders ~128px in Browse).

8. MONORAIL DRESSING: cadence (90-150s) and whether the 2-4 baked track segments ship (the ONLY bake exposure in the motion wave — severable; a night silhouette with a blinking light reads without track).

9. FLIP-DIGIT ROUND COUNTER on the Bus Station departure board: deeply on-brand (docs/16 L492 shipped recipe verbatim) but costs 2 slots + a digit-plate carve that may not exist cleanly in the dump (fallback = 10-frame SetModel digit). In or out?

