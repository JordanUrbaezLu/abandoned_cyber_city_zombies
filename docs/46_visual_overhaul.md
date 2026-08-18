# ABANDONED CYBER CITY — VISUAL OVERHAUL MASTER PLAN (FINAL)

Spine: the cinematographer plan (winner on player-impact, feasibility, and coherence). Every judge-endorsed graft applied; every vetoed element dropped; all user decisions and standing rulings honored: **noir recolor LOCKED, Helipad open-sky conversion APPROVED, skyline APPROVED, cyber-layer-on-top prop policy, Abyss L2–L5 OUT OF SCOPE (pitch-black horror identity, dark-probe fix only), NO light-radius growth anywhere, VK materials only behind provenance with named stock fallbacks, thin residual post-power haze (fog never fully dies), and every phase ends walkable/testable.**

Standing riders on EVERY phase (constraints ledger §1/§5/§8): new marker-guarded one-shot per batch in `tools/oneshots/`; grep your markers in the `.map` immediately before every geometry build (single-writer rule, ledger §5.2); `sync_to_modtools.ps1` before every build (§8.2); ONE foreground build at a time, never while BO3 runs (§5.3/§8.1); `_bake_test.ps1 -TimeoutSec 300+` for any geometry/light/material/probe change (§1.2 — a "CRASHED" at ~60–130s is a timeout artifact, re-run longer before believing it); build success = fresh `.ff` + ERRORLOG names none of your new assets (§8.4); every new FX gets `#precache` + `level._effect` + `fx,` zone line or it silently no-ops; CHANGELOG + docs/20 updated per commit; no new dvars/clientfields anywhere (pools FULL, dev-mode rule); all static deco = baked misc_model (zero G_Spawn).

---

# Vision

You step out of the Plaza spawn into a rain-slicked cyan intersection. The white shadowless grid is dead: the city is 85% dark, and every pool of light traces to something — a sodium street lamp, a flickering kiosk screen, the shadowed up-light raking the fountain angel so it throws the map's first real silhouette across wet asphalt that mirrors every color twice. Thin haze hangs permanently in the air, so the cyan pools are visible volumes, not paint. Through the Market door you see magenta before you buy it; through the Alley door, red — every doorway frames the next district's hue, every sightline a composition pulling you forward.

Each zone is a one-hue postcard. Market: a magenta sign-collage canyon with one green karaoke-sign counterpunch, animated menu boards, flies over the dumpsters, the crashed taxi rim-lit. Alley: a full-height red neon blade the scaffold silhouettes against, a fire barrel, the heaviest dead-neon decay in the map. Bus Station: the blue-cyan hub, holo departure board scrolling, steam off the manholes — and around the trench mouth, bioluminescent overgrowth climbing OUT of the abyss into the neon, dense at the rim, thinning toward the doors: the map's story told in set dressing, with darkness itself as the trench's destination hue (signage dies at the rim). Vault: green rake across the BO6 circular door, red-alert security desk strobing opposite. Lab: purple god-ray dust motes over the teleporter's idle beam. The Helipad becomes a real rooftop — lid gone, parapet silhouette, aviation strobes against actual night sky, the bomber raked amber.

And when you throw the power switch, the city doesn't just turn on — it REBOOTS, district by district, outward from the Bus Station over ~20 seconds: sparks, stutter-igniting signs, steam releases — ending when the holographic city-double, ABSENT until this moment, flickers alive over the Plaza wall tops: the marketing render of the city that died, igniting above its own corpse, as the fog completes its settle to residual haze. Boss waves slam the map into red-alert; Overclock rides the brownout state. Pre-power stays the near-black fogged opening; the Abyss stays pitch black. This is achieved ~80% by light, color, fog, emissives, and reflections — the geometry work (Helipad conversion, skyline) is the garnish that completes the frame, not the load-bearing fix.

---

# Zone identity table

Zone-hue canon: **the baked `acc_neon` rig WINS over docs/20 §5** (Vault = green); update the doc in the Phase 1 commit. **Trench canon ruling (owed by all candidates):** the baked YELLOW sub-z0 trench pools STAY — industrial caution reads correctly under the infection — and this is written into the same docs/20 §5 update so doc and rig never disagree again. In-zone complementary accents ride **emissive signage surfaces ONLY, never light pools** (user rule: ONE unique pool colour per zone).

| Zone | Signature hue | Door-contrast hue framed | Hero + shadowed spot | Fixture strategy | Signage tiers | Motion element | Postcard shot |
|---|---|---|---|---|---|---|---|
| **Plaza (spawn, open sky)** | Cyan | Magenta thru Market door; red thru Alley door | Fountain angel — shadowed PRIMARY_SPOT cyan up-light (the map's first silhouette) | Sodium `p7_zm_tra_street_lamp_full` accents; cyan pools re-homed onto kiosk screens; true white kept only at box/doors | T2 vertical stack on tallest bare wall; T4 emissive window-slot grids high; T3 tube strips on both buyable doors | Light rain (perf-gated) + lensflares at pool origins; day-1 drip lines at doorway eaves | Rain falling through the angel's cyan up-light, holo skyline over the wall tops, doubled in wet asphalt |
| **Market** | Magenta | Cyan/blue thru corp door; cyan thru Plaza door | Neon sign-collage wall + crashed taxi — raking shadowed spot each | Every one of the ~13 zoned neon signs gets its own magenta light AT the sign (currently 0 do); grid whites to 0.6–0.8 bake | T1 marquee band over kiosk island; T2 shop verticals; T5 `retro_synth_off` dead twins; ONE green karaoke-sign counterpunch (emissive surface only, no green pool) | Animated menu boards (`t7_graphic_bars_equalizer_flip`), flies over dumpsters | Wet floor mirroring the magenta collage wall, taxi rim-lit, one green sign popping |
| **Alley** | Red | Cyan thru Plaza door; blue thru corp door | NEW full-height vertical red neon strip (z0→220, E wall, `retro_synth_red_tinted_edge` stack — ships in Phase 3, NOT week 4) — scaffold silhouettes against it; fire barrel at its base | Fire barrel amber (`fx_light_zm_fire_spot_*`) + caged wall lights cool green-white; heaviest 20%-flicker/10%-dead ratio in the map | T2 the hero strip itself; T3 door tubes; T5 dead twins beside live | Fire light dance, `fx_water_drip_line_25`, sparking wire loop; hero sign stutter-ignites at boot-up | Scaffold black against a 220u red neon blade, drips crossing the glow |
| **Bus Station (corp, hub)** | Blue-cyan | Orange thru Helipad door; green thru Vault door; magenta/red back toward Market/Alley | Holo departure board — shadowed spot + flicker def; sealed schoolbus rim-lit (stays sealed — user-locked) | Ceiling cage lights cool green-white; `p7_sky_light_led_01` family blue bars on the 1600×1600 lid; Exchange-class whites retired | T1 animated metro arrow (`t7_graphic_display_zur_metro_arrow`); T3 tubes on 4 doors; T4 window slots | Metro-arrow scroll, `fx_steam_manhole_cover`, boot-up cascade ORIGIN | The departure board glowing over the trench cut, ivy rim-lit at the rim |
| **Vault** | Green | Blue thru corp door; purple thru Lab door | BO6 circular vault door — green raking shadowed spot (kills the "sticker" read); red-alert security desk (rotating warning FX = the sanctioned complement, FX not pool) | Security monitor suite (`p8_zm_off_monitor_security_*_red/on`) as the fixtures; green pools re-homed onto consoles | T3 door tubes; T4 military readout flickers on chalk meshes | Rotating red warning light + monitor static flicker; state-3 hits hardest here | Green rake across the 192u circular door, red monitor bank strobing behind |
| **Helipad (roof — open-sky post-Phase 6)** | Orange/amber | Blue thru corp door; purple thru Lab door | Crashed bomber — amber rake from the new parapet corner | Sodium floods on parapet posts; aviation blink strips (`fx_glow_blink_red_5`, already zoned) — against REAL sky after the lid comes off | T4 emissive facade panels high (stock `i_t7_ban_emissive_gradient_*` carve; VK only if provenance clears); T5 distant LED dots | Blinking aviation strobes, `fx_smk_plume_4000_slow_black` distant column | Bomber silhouette under open night sky, holo city-double behind the parapet |
| **Lab (PaP)** | Purple | Green thru Vault door; orange thru Helipad door | DE teleporter — purple shadowed spot + `fx_light_god_rays_dust_motes`; decon-airlock queue as second vignette | Tube-batten whites re-tinted violet; monitors get local pools | T4 vitals flickers (`t7_decal_monitor_01..06`) at the morgue row; T3 tubes on both approach doors | Teleporter idle beam (`fx_teleporter_beam_factory`), dust motes in every spot | Airlock queue rim-lit purple, one god-ray shaft full of motes |
| **Exchange basement** | Sodium amber | Cyan at teleporter pad | Floating holo screen (`p7_cru_monitor_holo_screen_01`) — the one cool accent in a warm room | Retire the map's 4 BRIGHTEST whites (bake 1.4–1.5) to amber 0.7–0.9; below-z0 reflection probe at −160 | T4 monitor flickers only | Holo shimmer (`mc/dr_fx_holo`) | Amber sodium gloom, one impossible floating cyan screen |
| **Trench rim (surface side only)** | Blue fading to BLACK — **darkness IS the destination hue**; baked yellow stays below z0 | The rim frames the ABYSS; signage DIES at the rim (story rule) | The reclamation gradient itself — ivy/fungus planted INSIDE existing neon pools so growth reads backlit | No new lights below z0 (locked); reuse rim pools whatever their hue | none — deliberately | `fx_fungus_pod_ambient_md_zod_zmb` pulled up to the rim; drip lines at rim edges | Bioluminescent overgrowth spilling out of a black pit into neon light |
| **Paradise (touch-ups only)** | Cyan/purple (as shipped — the proof) | n/a | Keep; add `retro_synth_off` dead twins beside live strips | Probe pass: configured dark probe so it stops inheriting the bright default cubemap | existing | existing | The arena floor shot, now with true-dark ambient |

---

# Phase plan

## PHASE 0 — "The air comes back" (Day 1)
**Goal:** haze, motion, and the map's first drips — plus the batched in-game verification session — before any bake risk exists.
**Work items:**
- Intervention #2: retarget `settle_fog_step()` in `_acc_atmosphere.gsc` to settle at ~0.3 opacity residual haze (live-tunable), never full-off (user decision).
- FX sparkle batch (#7 subset, ~12–15 placements, reuse the 16 already-zoned .efx first): lensflares at the 22 hue-pool origins, Alley fire barrel FX, flies over Market dumpsters, 2 FX god rays (Lab), distant smoke column; new FX get `#precache` + `fx,` lines.
- **Rain floor, pulled forward (graft):** drip lines (`fx_water_drip_line_25`) at Plaza doorway eaves, Alley wall edges, and the trench-rim lip — the "just rained" read ships day 1, zero debate.
- The syn_openq #7 cheap-check session batched into ONE user launch (full list in the verification checklist below); answers recorded in docs/20.
**Tooling:** GSC edits only (`_acc_atmosphere.gsc::apply_fx()`); no one-shot needed.
**Build type + gate:** `build_map.ps1 -GscOnly` (zero geometry touched — legal per ledger §8.3; the LED gate does not apply, and by the same rule this build cannot regress the bake).
**Acceptance:** user walks Plaza→Market post-power: light pools hang in visible haze; fire barrel, flares, and drips are alive; FX visible in ≥4 zones; checklist answers recorded.
**Abort criterion:** any FX no-ops → check `#precache` + `fx,` line FIRST (ledger §8.4) before any other diagnosis; worst case = `git checkout` of one GSC file. No bake exposure exists in this phase.
**Estimated sessions:** 1.

## PHASE 1 — THE NOIR RELIGHT (the 80% fix; user-approval gate for everything downstream)
**Goal:** invert the map — dark base, colored fixture-motivated pools, the map's first real shadows — in one KVP/entity-only batch with near-zero bake risk (no new lit surface = no new atlas charts).
**Work items** (interventions #1+#3+#4+#12+#16 light-def half+#17+#20+#18 mask authoring): one one-shot `tools/oneshots/noir_relight_v1.js` (marker **ACCNR01**) emitting ONLY KVP edits + new light/probe entities:
- Tint ~109 whites to zone hue at 25–40% sat per the identity table; white-grid bake 1.3→0.6–0.8; hue pools up to 1.0–1.3; stops varied 4–9. **The tool asserts and REFUSES to emit any radius delta** (standing ruling — the ≤~150-crashed vs 250–540-baked conflict is unresolved, so radii are frozen).
- Move/duplicate pools onto the 90 fixture props (only 4/159 are near one today); verify `lightingstate1 "1"` on every touched surface light (foundry-donor trap, ledger bonus §).
- ~14–18 shadowed PRIMARY_SPOTs (`PRIMARY_NOSHADOWMAP 0`, `shadowUpdate Never`) on the 7 landmarks + 6 story vignettes; 2–3 with `cookie_flicker + animmode loop`. All hero lights are PRIMARY_SPOT class, never omni.
- Exchange 4 brightest whites → amber 0.7–0.9; below-z0 probes (Exchange −160, hub −1100, dark box for L2–L5/Paradise — the ONLY Abyss touch, per scope lock) + alien-map tuning keys on the 9 bare probes; `lightingquality 4096` (fallback 2048 if bake time blows out).
- Author lighting-state 3 = red-alert / 4 = brownout masks (script wiring in Phase 2).
- **Graft:** the one-shot emits a **full revert table of original KVP values into its own header** — a user-taste rejection is a one-command restore.
- Same commit: docs/20 §5 canon update — Vault=green, trench yellow stays below z0.
**Tooling:** `noir_relight_v1.js` (new one-shot, ACCNR01).
**Build type + gate:** sync → FULL `build_map.ps1` with LED bake (lights/probes are LED-gated, ledger §1.1); marker-grep the `.map` first; iterate via `_bake_test.ps1 -TimeoutSec 300+`.
**Acceptance:** user walks EVERY zone and sees the inversion — dark base, colored pools, real shadows behind the fountain angel / vault door / bomber; no white wash anywhere; true white survives at box/doors/power/PaP. **This is the explicit user checkpoint before any geometry spend.**
**Abort criterion:** bake CRASH → bisect the one-shot's output in halves (KVP-only edits have never crashed; new spot entities are the only novel class — pull them first); never ship a failed bake. User rejects the darkness → replay the revert table (one command), recolor/fixture-pairing survive either way.
**Estimated sessions:** 2 (build+iterate, user walk).

## PHASE 2 — Cascade v1 + grade + system states (same week)
**Goal:** the power-on set piece exists; the grade is auditioned on a rig that finally deserves it; the lighting states connect to the map's systems identity.
**Work items:**
- Differentiator 2, the boot-up cascade v1 in `_acc_atmosphere.gsc::power_bootup_cascade()` (full spec in Differentiators — WITH the interim finale: fog-settle completion + map-wide sign-flare beat; **the cascade never hard-references the holo before Phase 4 ships it** (veto honored), and **no separate landmark beam ever ships** (veto honored — the holo IS the single cluster-I anchor).
- #23 grade re-audition: +10–15% saturation via `apply_vision`/`acc_grade_*`, `player_revived` reapply edge handled, NEVER the map-name .vision.
- #18 script wiring: `set_lighting_state(3)` on boss-wave start; **state-4 brownout tied to Overclock activation** (graft — connects the overhaul to the map's signature system) plus the pre-power-restore flicker beat.
- Second particle batch: one particle in EVERY major pool (steam at ambers, dust in beams, ground fog at lane mouths).
**Tooling:** GSC only; cascade timings are code constants (no dvars — dev-mode rule).
**Build type + gate:** `-GscOnly` (zero geometry — bake gate not applicable and cannot regress).
**Acceptance:** user flips power and the city reboots district-by-district end-to-end; boss wave slams the map red; Overclock browns it out; grade approved ON the colored rig or parked.
**Abort criterion:** grade rejected → ships OFF again (`ACC_VISION_ON 0`), zero cost, no dependency; any cascade beat misfiring → re-order the one-line-per-beat table live.
**Estimated sessions:** 1–2.

## PHASE 3 — Caulk enabler, then visible emitters + motion surfaces (resequenced per grafts: caulk BEFORE any lit-surface spend)
**Goal:** buy atlas headroom first, then give the wet ground colored things to mirror — neon SOURCES, animated screens, the Alley hero, and the grime layer.
**Work items:**
- **3a CAULK RETROFIT (moved up from the old Phase 6a — judge-mandated):** one-shot `caulk_retrofit.js` (marker ACCCK01) repaints every never-visible face (void-side shell, above-ceiling tops, floor undersides) to caulk. Zero visual change; protects ALL later geometry phases' atlas budget (ledger §1.3 — the atlas is fragile and content-specific). **No lit-surface geometry batch ships before this bake is green.**
- **3b PILOT (one bake):** one chalk-mesh quad per NEW material class, Market only — `retro_synth_*_tinted` band, one `t7_graphic_*` animated, one `t7_decal_monitor_*`, one wet puddle token — one-shot `emissive_pilot_market.js` (ACCEM00). The m8a4 face-token precedent (ledger §6.6) makes per-class pilot bakes mandatory.
- **3c DEPLOY (one bake, ~40–60 one-chart quads):** #5 map-wide eye/floor-level emissive bands z0–150 per zone hue (`_tinted_edge` only exists in blue/green/orange/red/yellow — pink/cyan/purple use `_tinted`); destination-hue trim quads on all 13 buyable doors; `retro_synth_off` dead twins (70/20/10 live/flicker/dead ratio); **the Alley hero strip (chalk part) — the no-hero zone gets its landmark HERE, not week 4 (veto honored)**; the Market green karaoke sign (emissive only); #6 animated screens (metro arrow Bus Station, equalizer menus Market, military readouts Vault, vitals Lab); #25 puddle overlays inside the Phase-1 pools; T4 window-slot grids on upper walls; **the cluster-G grime/decal micro-pass (graft — the gap all candidates owed): leak streaks under fixtures, oil stains under dumpsters/taxi, graffiti near door mouths** — all via the proven nonColliding chalk-mesh recipe. One-shot `emissive_band_pass.js` (ACCEM01). Every strip sits inside a co-located colored light already placed in Phase 1 (emissives do NOT emit into the bake — Paradise proof). All meshes `contents nonColliding`, 1–2u proud — **NEVER Decal-category on a brush face** (death-hole trap, ledger §6.2).
**Tooling:** 3 new one-shots (ACCCK01 / ACCEM00 / ACCEM01).
**Build type + gate:** FULL pipeline per sub-batch (geometry/material = LED-gated); `_bake_test.ps1 -TimeoutSec 300+` between each; marker-grep before every build; 3 bakes total.
**Acceptance:** 3a — bake green, zero visual change; 3b — every class BAKED; 3c — user sees neon sources mirrored in wet floors in every zone, the Bus Station arrow scrolls, Alley has its blade, walls read grimy not clean.
**Abort criterion:** 3a crash → diagnostic gold, bisect by face class; 3b — any class CRASHES → that class is dropped map-wide (blacklisted in docs/20 §14 with a named substitute), the rest proceed; 3c crash → halve the batch, revert the failing half (git checkpoint per green bake).
**Estimated sessions:** 2–3.

## PHASE 4 — Cyber carve layer + Plaza vista + holo city-double + reclamation (SPLIT into 4 severable bakes — the mega-batch veto honored)
**Goal:** the spawn-zone postcard (skyline + hologram) and the map's story dressing — with zero dependency on the Helipad structural change (Plaza is already open-sky; verified in CHANGELOG).
**Work items,** one gdtdb pass (`gen_t7_carve_gdt.js`, `gdtdb /update` once) then four independent one-shot bakes:
- **4a Plaza vista + holo (ACCVS01):** 2–3 depths of plain dark vista slabs (box primitives — deep-solid-mass precedent bakes) + emissive window-slot chalk quads behind Plaza wall tops above z256; `p7_sky_holo_city_01_dlc1` floating ~z600–900, tilted ~10° toward the spawn sightline; `_02_dlc1` twin at a second depth. ALL coordinates validated against BOTH envelopes before emit (sky z≤2259.75/y≤4640; volume_sun z≤2138/y≤4640 — ledger §3.1). Facades = dark stock tokens + `retro_synth` window-slot grids / `i_t7_ban_emissive_gradient_*` carve (DEFAULT path); VK facades only if provenance clears first.
- **4b Neon-sign carves (ACCSN01):** 3–5 SoE/banzai sign carves for Market/Alley walls.
- **4c Cyber band + fixture models (ACCCY01):** #15 props into the EMPTY z100–256 band (holograms, curved screens, LED family, monitors — wall/ceiling mount, misc_model statics = zero G_Spawn); fixture MODELS under the ~20 brightest pools still lacking one; `mc/dr_fx_holo` shimmer riders (-GscOnly follow-up for the `fx,` lines).
- **4d Reclamation gradient (ACCRG01):** differentiator 3 (spec below).
- **-GscOnly rider after 4a:** the cascade finale gains its one added line — the holo's `fx_de_rez_ambient` ignition replaces the interim finale (**absent pre-power → IGNITES at t+21** — the judge-unanimous graft).
Carve discipline: probe every LOD0 in the ERRORLOG (0xC0000409 → LOD1, ledger §7.3); models without `_col` LOD get clips per anti-perch rules (≥12u half-extent or flat, gable/wedge under fall columns, ledger §7.1–7.2); every clip paired with DisconnectPaths (§4.2); worldspawn clips preferred on open floor (§4.3); ≥60u AI lanes preserved (§4.4).
**Tooling:** 4 new one-shots + the carve generator; `add_prop_clips.js` re-run where clips added.
**Build type + gate:** FULL pipeline per sub-batch (4 bakes), `_bake_test.ps1 -TimeoutSec 300+` between; navmesh regen via cod2map64 cwd=bin where clips/worldspawn change; the holo-ignition rider is `-GscOnly`.
**Acceptance:** 4a — user stands in Plaza spawn, looks up, sees a city and the hologram of the city (dark until power); quantified: slabs + holo inside both envelopes, no leak fingerprint. 4b/4c — upper band inhabited, ERRORLOG clean. 4d — trench rim visibly infected, zero navmesh regressions at the rim.
**Abort criterion:** per-model — a bad carve is LOD1'd or dropped, never blocks its batch; 4a bake crash → bisect props vs slabs (slabs are the proven class); each sub-batch is independently revertable (one git block each). A failed sub-batch never blocks the other three.
**Estimated sessions:** 3–4.

## PHASE 5 — Volumes + rain (one bake + one -GscOnly)
**Goal:** glowing air, and the art bible's rain promise kept — behind an explicit perf gate.
**Work items:**
- **5a (bake):** #10 `volumetric 1` on 4–6 Phase-1 spots; `volume_litfog` with `zm_factory_volumetric` fsi; per-zone `volume_worldfog` (thick trench, thin topside — the Phase-0 FX god rays remain the guaranteed floor since volumetrics are a player video setting); #11 `volume_weathergrime` streak volumes + `volume_outdoor` (guarantees rain never renders indoors). One-shot `atmo_volumes.js` (ACCVL01).
- **5b (-GscOnly):** 2–3 `fx_rain_system_med_*` emitters over the Plaza ONLY + rain/neon-buzz audio bed (CC0-sourced only — copyrighted placeholders are DO-NOT-PUBLISH). **NO `rain_player()` per-player CSC layer in v1** (triple-vetoed: costliest per-frame element, G_Spawn per player near the cap; v2 candidate only if v1 proves free). Perf test may use a session-scoped tuning dvar for A/B during the test session ONLY — deleted immediately after (the shipping kill path is the existing `acc_atmo_fx` switch; no new permanent dvar, dev-mode rule).
**Tooling:** ACCVL01 one-shot; GSC for emitters.
**Build type + gate:** 5a = FULL pipeline + LED (volumes are map entities); 5b = `-GscOnly`.
**Acceptance:** user sees glowing air in the trench and Lab god rays; then the perf gate: user trains a full horde in Plaza + 360° pan at spawn — no felt frame drop.
**Abort criterion:** 5a crash → volumes bisect (entity-class, low risk); 5b perf FAIL → rain loops deleted in one `-GscOnly` build (minutes); the cheap-rain floor (drips from Phase 0, streaks/puddles from 3/5a, audio bed) stays and carries ~70% of the rain read.
**Estimated sessions:** 2.

## PHASE 6 — Helipad open-sky conversion + skyline extension (APPROVED structural change; two isolated bakes)
**Goal:** the map's second open-sky zone — a real rooftop under real night sky.
**Work items:**
- **6a `open_helipad_sky.js` (ACCHP01):** remove the z256 lid slabs; parapet ring (z256–320 caps on existing walls, filler-plane `box()` winding + hex GUIDs verbatim); aviation strobes re-aimed at real sky; **the roof zone/OOB volume extensions live INSIDE the SAME one-shot block (graft) so a leak-revert reverts volumes atomically.** Envelope pre-check: both envelopes already cover the opened volume on paper (sky z≤2259.75, volume_sun z≤2138).
- **6b `helipad_vista_extend.js` (ACCHP02):** extends the Phase-4 vista behind the parapet — `_02` holo card + `p7_sky_holo_city_wires_01_dlc1` — strictly a post-conversion EXTENSION (the primary holo stays at Plaza, decoupled; veto honored).
- **6c (-GscOnly, conditional):** Helipad rain extension — ONLY if 6a is stable AND the Phase-5 Plaza perf gate passed.
**Tooling:** 2 new one-shots.
**Build type + gate:** 6a = its own FULL pipeline bake + the complete leak protocol: re-run cod2map64 directly (cwd=bin — build_map.ps1 swallows the message) and grep `leaked`; fingerprint check fresh `.lin` + STALE `.d3dprt` = leak (ledger §3.1); volume_sun coverage walk (every roof corner, no white ssi wash); OOB audit; full navmesh regen; in-game walk with zombies pathing. 6b = its own small FULL bake. 6c = `-GscOnly`.
**Acceptance:** user stands on a real rooftop under real sky, strobes blinking, holo-city behind the parapet, no leak, no wash, zombies path the roof.
**Abort criterion:** leak or bake crash → git-revert the single ACCHP01 block wholesale (lid restored, volumes restored atomically); **downstream fallback is automatic (graft): the skyline/holo stays Plaza-only with zero re-planning** — the map ships fine without the conversion. Treat the lid removal as guilty until the bake proves otherwise.
**Estimated sessions:** 2–3.

## PHASE 7 — Geometry garnish (OPTIONAL, per-room, only if the user still reads flatness after 1–6)
**Goal:** trim/framing/ceilings — deliberately last: after Phases 1–5 the walls are dark, banded by emissives, interrupted by signage and window grids, and capped by vista; the greybox tells are mostly INVISIBLE at night under a noir rig. Spend here only what the user's own eyes demand.
**Work items** (each its own one-shot + bake):
- #9 doorway framing/jambs via the **pilot protocol (graft): 2 doors → bake → remainder in 2 halved batches**; openings never narrowed below stock widths, ≥60u lanes.
- #13 wainscot overlays (nonColliding mesh bands).
- #19 ceiling articulation: formal pilot = ONE 64u soffit in the Scientist office (smallest room) → bake → user walk; then the Bus Station 1600×1600 lid; then one room per batch. Solid relief only (never enclosed voids), filler winding + hex GUIDs, `contents detail`, ≥72u clearance, fixtures re-hung per batch.
- OPTIONAL post-ship nicety: ONE rotating fan mover (1 budgeted G_Spawn slot). **The `shadowUpdate Always` light and the searchlight do NOT ship** (veto — standing per-frame shadow tax as garnish).
**Tooling:** per-room one-shots, new markers each.
**Build type + gate:** FULL pipeline + `_bake_test.ps1 -TimeoutSec 300+` between EVERY room/batch.
**Abort criterion (formal, pre-agreed — graft):** **2 consecutive bake CRASHes in one room after halving the batch → that room keeps its flat lid/bare walls permanently, move on.** The phase is severable at any point; everything before it already shipped the transformation.
**Estimated sessions:** 0–4 (user-demand-driven).

---

# Differentiator specs (the 3, placed concretely)

**1. THE HOLOGRAPHIC CITY-DOUBLE — Plaza-first, absent-until-power, the map's SINGLE vertical anchor.** Primary placement (Phase 4a, zero structural dependency): `p7_sky_holo_city_01_dlc1` carved as a misc_model static floating at ~z600–900 behind the Plaza's north/east wall tops, tilted ~10° toward the spawn sightline so it reads from the player's first step; coordinates validated inside BOTH envelopes (sky y≤4640/z≤2259.75; volume_sun y≤4640/z≤2138) before the one-shot emits. Below/behind it, 2–3 depths of dark vista slabs with emissive window-slot chalk quads (stock-safe default; VK facades only if provenance clears). The `_02_dlc1` twin sits at a second depth. **Story mechanic (judge-unanimous graft): the hologram is ABSENT pre-power — its `dlc0/nuketown/fx_de_rez_ambient` loop starts ONLY on the `power_on` flag, as the cascade's finale. The ghost city IGNITES.** Secondary placement (Phase 6b, extension only): the `_02` card + `p7_sky_holo_city_wires_01_dlc1` behind the new Helipad parapet. The holo is simultaneously vista, landmark beacon (it IS the cluster-I anchor — **no separate landmark beam ever ships**, veto), and the story beat. Emissive self-lit material = no fixture problem, zero G_Spawn. Fallback if the carve fails all LODs: stacked `retro_synth_cyan_tinted` silhouette cards — same read, zero new assets.

**2. THE CASCADING BOOT-UP — origin Bus Station, ~22s, pure GSC (Phase 2 v1, Phase 4 finale upgrade).** Fired off `flag::wait_till("power_on")` in `_acc_atmosphere.gsc::power_bootup_cascade()`; the engine's binary lighting-state flip happens at t+0 underneath, masked by the existing `acc_grade_warm1` ramp; the FX cascade rides over it. Beats (graph distance from the switch, one `wait; zone_fx_on()` line each — trivially re-orderable): **t+0** Bus Station — spark salvo (`play_fx_burst` on `fx_elec_spark_loop_sm` points) + departure-board flicker ignites + manhole steam release; **t+2.5** trench rim — fungus-pulse FX ignite (**the infection wakes with the city** — graft tying differentiator 3 into 2); **t+3.5** corridors — tube-strip flickers; **t+6** Market + Alley — **the Alley hero sign STUTTER-IGNITES with two false starts before catching** (flicker FX runs ~2s, then the steady loop replaces it); **Market menu boards pop W→E down the stall line 0.4s apart** (showman micro-choreography grafts); **t+10** Plaza + Vault — kiosk screens + **window-slot strips cascade staggered 0.3s**; security-monitor bank wakes; **t+14** Lab — teleporter idle beam starts; **t+18** Helipad — aviation strobes begin blinking; **t+21 FINALE** — the holo city-double's de-rez loop snaps on (absent → ignited) as `settle_fog_step()` completes its settle to residual haze — the air clears exactly as the city wakes. **Interim finale before Phase 4 ships the holo:** fog-settle completion + a map-wide sign-flare beat — no beam, no dangling asset reference (vetoes honored); the holo joins with one added script line. All server FX loops/`play_fx_burst`, zero clientfields, zero new dvars, ~8 new `fx,` lines total.

**3. NEON-FED RECLAMATION GRADIENT — trench-rim, three density rings, surface side only (Abyss untouched).** Phase 4d. Source: installed BO6 foliage kit (`_mg_bo6_foliage`, 734 models, BulletCollisionLOD None = non-solid → ZERO clips, zero G_Spawn, zero navmesh impact) + `fx_fungus_pod_ambient_md_zod_zmb` (already zoned). **Ring A** (0–300u from the trench mouth: rim parapets + rim floor): dense — ~20–24 ivy/fungus clusters, every cluster deliberately planted INSIDE an existing Phase-1 neon pool (whatever its hue — including the canon yellow below the lip) so growth reads backlit/bioluminescent; 2–3 fungus ambient FX loops pulled up to the rim; drip lines at rim edges. **Ring B** (300–700u: Bus Station floor edges, corridor mouths toward Market/Alley): sparse — 8–10 smaller clusters hugging wall bases. **Ring C** (700u+): exactly 2–3 outlier clusters at the Market and Alley door thresholds — the "it's spreading" punchline a player notices on round 15, not round 1. Beyond that: ZERO. Nothing above z100 (growth climbs, it doesn't festoon); nothing inside Vault/Lab/Helipad (clean-zone contrast IS the gradient's legibility); **signage dies at the rim and darkness is the rim's destination hue** (graft) — the infection beat also fires at cascade t+2.5. ~30–35 baked misc_model statics total.

---

# Rain verdict

**YES — Plaza-only, LIGHT, staged behind an explicit perf gate, with a cheap-rain floor that ships regardless — and the floor ships FIRST.** Rain is the art bible's loudest broken promise ("perpetual rainy neon night" with zero rain) landing at the single highest-leverage spot in the map — the spawn zone, every run's first 30 seconds, the Workshop screenshot frame — and a plan whose thesis is that light needs a medium cannot deny it the medium's most cinematic form. The Kowloon warning describes a different animal: map-wide heavy rain stacked on a high-polycount modeled vista; ours is bounded by design — ONE open-sky zone until Phase 6, 2–3 MEDIUM emitters (never hvy), `volume_outdoor` guaranteeing zero indoor overdraw, and an emissive-card vista with near-zero fill cost. Staging: the floor (drip lines at doorway eaves/Alley edges/trench rim) ships DAY 1 in Phase 0; weathergrime streaks, puddle overlays, and wet reflections land in Phases 3/5a; the rain-audio bed rides 5b (CC0-sourced only); then the emitters land as a separate `-GscOnly` build gated on the user training a full horde in Plaza plus a 360° spawn pan with no felt frame drop — FAIL means the loops are deleted in one `-GscOnly` build in minutes while the floor (which carries ~70% of the rain READ at ~5% of the cost, because rain in a dark neon scene is mostly heard, streaked, and reflected) remains. **The per-player `rain_player()` CSC layer does NOT ship in v1** (unanimous judge veto — costliest per-frame element, G_Spawn per player near the ~1024 cap; strictly a v2 candidate if v1 proves free). Helipad rain only after Phase 6a is stable AND the Plaza gate passed. Haze and rain are complements — haze owns the mid-distance air, rain owns the near-field motion — and both are killable via the existing `acc_atmo_fx` switch with zero new permanent dvars (any A/B tuning dvar is session-scoped and deleted after the test).

---

# Risk register

| # | Risk | Ledger § | Phases | Mitigation | Abort/fallback |
|---|---|---|---|---|---|
| 1 | **LED bake crash (brush.cpp:1860)** — fragile, content-specific atlas overflow | §1.1–1.4 | 3,4,6,7 | Phase 1 is KVP/entity-only (zero new charts); caulk retrofit (3a) precedes ALL lit-surface spend; filler-plane `box()` winding + hex GUIDs verbatim; solid relief only, never enclosed voids; one one-shot per batch, `_bake_test.ps1 -TimeoutSec 300+` between every batch; git checkpoint per green bake; "CRASHED" under ~140s = re-run longer first | Revert-or-fix, bisect the one-shot's output in halves; Phase 7's formal 2-crash per-room abort; never ship a failed bake |
| 2 | **Omni-radius contradiction** (ledger ≤~150 crashed vs shipped 250–540 green — unresolved) | §bonus | 1 | Radii FROZEN plan-wide: hue/bake_intensity/stops/position/new PRIMARY_SPOTs only; the relight one-shot **asserts and refuses to emit any radius delta** (mandatory mechanism); hero lights are spot class, never omni | n/a — the conflict is never tested |
| 3 | **Per-material-class bake poison** (m8a4 precedent: valid asset, crashes lightmapper as face token) | §6.6 | 3,4 | Phase 3b one-quad-per-class pilot bake in Market before ANY class deploys; proven classes (`lit_emissive_advanced` retro_synth, skye chalk gdf) preferred | Crashing class dropped map-wide, blacklisted in docs/20 §14 with named substitute |
| 4 | **Helipad conversion leak / envelope breach / white wash** | §3.1 | 6 | Own isolated bake; OOB/zone volumes inside the SAME one-shot block; cod2map64 direct (cwd=bin) + grep `leaked`; fingerprint fresh `.lin` + STALE `.d3dprt`; volume_sun corner-walk; navmesh regen; nothing stacked on it | Wholesale git revert of ACCHP01 (atomic); skyline/holo automatically stays Plaza-only, zero re-planning |
| 5 | **VK provenance** (Textures.com = ship-ban; CREDITS IP review incomplete) | §6.5 | 4,6 | Named stock fallback for EVERY VK usage (dark tokens + retro_synth window grids / `i_t7_ban_emissive_gradient_*` carves) is the DEFAULT path; trace `baseImage` folders before Phase 4a; VK never on the critical path | Ship the fallbacks; zero schedule impact |
| 6 | **xpak / subscriber-download bloat** (~15–17 MB per new 4K material) + carve linker crashes (LOD0 0xC0000409) | §6.3, §7.3 | 4 | **HARD CAP ≤12 genuinely new materials (~200 MB) total** (the 25/400MB budget is vetoed); prefer already-referenced eMoX (free) + stock t7 (free) + zoned FX; per-batch ledger in CHANGELOG; probe every carve LOD0, LOD1 fallback; skinned models never carved | Cut lowest-ranked carves first (cyber band is severable) |
| 7 | **Rain/FX perf regression + G_Spawn/CF budgets** | §2.1–2.5 | 0,2,5 | All new FX = server loops via `apply_fx()` / `play_fx_burst` (zero CFs — pools FULL; zero G_Spawn); rain Plaza-only, 2–3 med emitters, explicit perf acceptance test; NO rain_player v1; all deco = baked misc_model; no new permanent dvars anywhere | Loops removed in one `-GscOnly`; cheap-rain floor stays |
| 8 | **User-taste risk: "darker" reads as "can't see"** (the white grid exists because the user once asked for brighter) | — | 1 | Noir recolor is user-LOCKED but Phase 1 is sequenced FIRST as an explicit walk-checkpoint before any geometry spend; the one-shot embeds a full revert table of original KVPs (one-command restore); fog/grade live-tunable in-session; true white kept at box/doors/power/PaP; pre-power opening unchanged | Replay the revert table; fixture-pairing and spots survive either way |
| 9 | **Concurrent-session `.map` clobber / build collisions / machine freeze** | §5.2–5.3, §8.1 | all geometry | Unique marker per one-shot (ACCNR01/ACCCK01/ACCEM00/01/ACCVS01/ACCSN01/ACCCY01/ACCRG01/ACCVL01/ACCHP01/02); grep markers immediately before EVERY bake; ONE foreground build; sync-before-build; never while BO3 runs; texture and model batches never in parallel sessions | Re-append lost blocks (all one-shots are deterministic emitters) |
| 10 | **Navmesh regressions from new clips/geometry** | §4.1–4.5 | 4,6,7 | cod2map64 cwd=bin always (build_map.ps1 handles it); reclamation models are non-solid (zero clips); `_col`-LOD check decides clip need; DisconnectPaths paired with every solid clip; worldspawn clips on open floor; ≥60u lanes; never seal spawns/risers/triggers | In-game pathing walk per geometry phase; revert the batch |

---

# Asset shopping list (per phase, provenance-flagged)

**Budget rule (judge-locked): ≤12 genuinely new 4K materials across ALL phases (~200 MB worst case), tracked per-batch in CHANGELOG.**

**Phases 0–2 — cost 0 MB (zero new assets):**
- FX (installed, need `#precache` + `fx,` lines where new): `fx_lensflare_fluorescent` + `_light_cool_lg` [FREE-STOCK], `fx_light_zm_fire_spot_*` [PACK-HB21, installed], `fx_bio_fly_dark_50x50`, `fx_light_god_ray_sm_single`, `fx_light_god_rays_dust_motes`, `fx_smk_plume_4000_slow_black` [PACK-HB21, installed], `fx_water_drip_line_25(_ceiling)` [zoned], `fx_elec_spark_loop_sm` [zoned], 18× `acc/light/fx_perk_glow_*` [SELF-AUTHORED, zoned], `fx_steam_manhole_cover` [zoned].
- Light defs `gobo_spot_rings_001`, `cookie_flicker` [FREE-STOCK — verify auto-pull in the P0 session]; probe tuning keys (alien-map recipe values, no assets).

**Phase 3 — ~0 new xpak (eMoX already referenced = free):**
- Emissive bands: `mwiii_vertigo_retro_synth_{cyan,pink,red,purple,green,orange,blue}_tinted` + `_tinted_edge` (blue/green/orange/red/yellow ONLY) + `retro_synth_off` [PACK-eMoX, installed, bake-PROVEN class].
- Animated (each class pilot-baked in 3b): `t7_graphic_display_zur_metro_arrow`, `t7_graphic_bars_equalizer_flip`, `t7_graphic_display_military_01/04/05_flicker`, `t7_decal_monitor_01..06`, `t7_graphic_detail_text_01_scrolling`, `t7_decal_display_light_strip_scroll_01_blue/_red` [ALL FREE-STOCK].
- Puddles: stock `t7_*_wet` family [FREE-STOCK]; grime/graffiti decals from installed t7 decal set via the nonColliding chalk-mesh recipe [FREE-STOCK]. Caulk [FREE-STOCK].

**Phase 4 — the budget lives here (~6–10 new materials, ≤12 cap):**
- Vista/holo carves [FREE-STOCK T7 via `gen_t7_carve_gdt.js`]: `p7_sky_holo_city_01_dlc1`, `p7_sky_holo_city_02_dlc1`, `p7_sky_holo_city_wires_01_dlc1`, `p7_sky_vista_city_01` (+optional `p7_aqu_vista_cityscape_cards_01`).
- Signs [FREE-STOCK carves]: `p7_sin_sign_neon_tube_01` (or `_01_on_mp`), `p7_ven_sign_neon_chariot_club_orange`, `p7_ven_sign_neon_singchinatown_tube_red_mp`, 2× `p7_ban_sign_neon_{gun,stay_out}_on`.
- Cyber band [FREE-STOCK carves, cap ~10 models]: `p7_ris_hologram_base` + `_double_helix`, `p7_sky_screen_curved_01_dlc1`, `p7_cru_monitor_holo_screen_02`, `p7_sky_light_led_01_{a,c}_{blue,orange,off}` family, `p7_ntx_switch_light_emissive`; emissive gradient panels `i_t7_ban_emissive_gradient_*` [FREE-STOCK].
- Reclamation: `_mg_bo6_foliage` ivy/fungus picks [PACK-MadGaz, installed, credit row EXISTS], `fx_fungus_pod_ambient_md_zod_zmb` [zoned]. Holo ignition FX: `dlc0/nuketown/fx_de_rez_ambient` [PACK-HB21, installed, needs `fx,` line]; shimmer `mc/dr_fx_holo` [zoned].
- **⚠ PROVENANCE-BLOCKED (use ONLY if `baseImage` trace clears; stock fallbacks above are the plan of record):** VK `pbr_vista_building_facade_01/02`, `pbr_facade_emmisive_light_panel_on_1/2/3_mtl`.

**Phase 5 — ~0–2 new materials:**
- `volume_weathergrime` + `t7_decal_raindrops(_fast)` [FREE-STOCK], `volume_outdoor`, `zm_factory_volumetric` fsi [FREE-STOCK] (or self-authored `acc_fog.gdt` clone).
- Rain .efx — **verify exact installed names against the HB21 index before wiring**: candidates `weather/fx_rain_system_med_*` / `fx_rain_system_hvy_acid_zod` (the med variants only) [PACK-HB21/FREE-STOCK, zone lines].
- Rain-bed + neon-buzz audio [⚠ NEEDS CC0 SOURCE PASS — flag for docs/23 sound plan; copyrighted placeholders are DO-NOT-PUBLISH].

**Phase 6 — cost 0 MB:** caulk [FREE-STOCK]; parapet caps = existing `t10_*` substrate tokens [installed, already-referenced = free]; `fx_glow_blink_red_5` [zoned, unplaced].

**Phase 7 (optional) — cost 0 MB:** `t7_metal_duct_insulation_01_grey` + existing dark structural tokens [FREE-STOCK/installed]; fan model via T7 carve [FREE-STOCK].

**Explicitly NOT buying:** any skybox/SSI change (**SKY STAYS** — user-locked), zm_alien_isolation materials (unlicensed), new HUD/clientfield anything (pools FULL), Kowloon-style modeled vista geometry, the landmark beam FX, the `shadowUpdate Always` light, the searchlight, `rain_player()` v1.

---

# In-game verification checklist for the user's next test session

**Batch A — the syn_openq #7 cheap checks (one launch, dev build, record answers in docs/20):**
1. **(a)** Do the 17 existing `fx_at` loops actually render? (Walk the placements; legacy bare-PlayFX doubt — loops via `apply_fx()` should render, one-shots won't.)
2. **(b)** Note the exact Radiant KVP name of the light "volumetric" checkbox (needed for Phase 5a spot flags).
3. **(c)** Do light `def`s (`gobo_spot_rings_001`, `cookie_flicker`) and Radiant fx-entity fxdefs auto-pack without zone lines? (Confirmed = Phase 1 needs no zone edits for defs.)
4. **(d)** Lighting-state swap latency: trigger a state 1→3→1 flip — how fast, any rapid-toggle flicker viability? (Gates the Phase-2 boss-wave/Overclock wiring.)
5. **(e)** Piggybacking on the Phase-1 build: does `lightingquality 4096` still pass the bake gate, and what's the new bake time? (Record it — `_bake_test` timeout must exceed it; fallback 2048.)

**Batch B — Phase-0 look pass (same launch):**
6. Post-power, do light pools visibly hang in haze (fog settles to ~0.3, never fully clears)? Pre-power opening unchanged (near-black + fog)?
7. Alley fire barrel alive; lensflares at pool origins; flies over Market dumpsters; drip lines visible at Plaza doorway eaves + trench rim.

**Per-phase look passes (one per phase, the acceptance gates):**
8. **Phase 1:** walk all 7 zones — dark base, one hue per zone, pools trace to fixtures, REAL shadows behind the fountain angel / vault door / bomber; no white wash anywhere; box/doors/power/PaP still clearly lit true-white; Exchange now amber, no longer brightest-in-map; Paradise/Abyss probes read dark. THE go/no-go for all geometry.
9. **Phase 2:** flip power — the city reboots district-by-district over ~22s (sparks → fungus wake → Alley sign double false-start → Market W→E pops → Plaza stagger → strobes → fog settles at the finale); boss wave = red-alert map-wide; Overclock = brownout; grade verdict (keep/park) given ON the colored rig.
10. **Phase 3:** every zone passes the Paradise test — visible emitter + haze + wet-floor reflection; Bus Station arrow scrolls; Alley hero blade reads floor-to-scaffold; 13 door trims show the DESTINATION hue; grime/streaks read on walls; no invisible-hole floors anywhere you can walk (death-hole check).
11. **Phase 4:** stand at Plaza spawn, look up — layered skyline + hologram (DARK pre-power, IGNITES at the cascade finale after the -GscOnly rider); trench rim reads infected with density falling off toward the doors; zombies path normally around every new prop (watch for grinding — DisconnectPaths check).
12. **Phase 5:** glowing air in the trench + Lab god rays (with volumetrics ON and OFF — FX floor must hold); THE RAIN PERF GATE: train a full horde in Plaza + slow 360° pan at spawn — any felt frame drop = emitters out.
13. **Phase 6:** stand on the Helipad — open night sky, no white exposure wash at any parapet corner, strobes blinking, holo-city behind the parapet; zombies path the roof; no fullbright-white surfaces or black void gashes anywhere map-wide (leak tells).
14. **Phase 7 (if exercised):** per room — two ceiling heights read; door mouths read framed; no lane feels blocked (≥60u check by training a horde through).