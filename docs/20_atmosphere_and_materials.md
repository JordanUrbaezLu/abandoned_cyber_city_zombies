# 20 — Atmosphere & Materials (wall/floor skins, sky, fog, lighting)

> **Design + implementation reference for the map's *look*.** The map is fully
> built and painted — every face carries a real stock/custom material, the sky is
> a dimmed night SSI, volumetric fog + a per-zone baked light rig are live. This
> doc is now a LIVING REFERENCE: the shipped mechanism first, then the art
> direction it serves and the traps hit along the way. Pairs with the portable
> recipe in [BO3_MAPMAKING_KB.md](BO3_MAPMAKING_KB.md) (§ Materials, Sky & Fog).

**Status:** Phase-1 atmosphere (night sky · fog · wet-stock ground · per-zone baked
neon lights · reflection probes) is **SHIPPED**. The scene is lightmap-baked (LED
bakes again after the pre-stage3 revert — `-SkipLED` is a RED FLAG, not the
default). The colour grade ships **OFF** (base game colours) with dormant
live-swappable grades. Fog is ON by default, and **since 2026-07-29 the power-on
settle ends in a permanent thin RESIDUAL haze, never a full disable**
(`hold_settled_fog()`, `acc_fog_residual_*` dvars — docs/46 Phase 0; light pools
need a medium to read as volumes). **THE ACTIVE PLAN for everything visual is now
[46_visual_overhaul.md](46_visual_overhaul.md)** (noir relight → cascade → emissives
→ vista/holo → volumes/rain → open Helipad); this doc stays the mechanism reference. Code:
[_acc_atmosphere.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_atmosphere.gsc)
(fog/vision/ambient/FX) +
[_acc_perk_lights.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_perk_lights.gsc)/`.csc`
(power-on machine glow) + the `tools/gen_*_lights.js` / `tools/paint_*.js` /
`tools/apply_zone_materials.js` map generators.

---

## 1. Art direction — the look

**Theme:** a dead high-tech city. Perpetual rainy neon night, dead/flickering
signage, smog, wet reflective ground, decay over chrome. In-engine touchstone:
BO3's own **Shadows of Evil** (low-key noir city, neon contrast). External: Blade
Runner 2049 ruin, Cyberpunk 2077 derelict districts, Observer, Ghostrunner.

**Palette** — ~85% of every surface is dark base; neon is <15% and is the *only*
thing that's bright (the SoE / BR2049 contrast formula):

| Role | Color | Use |
|---|---|---|
| Wet asphalt / near-black | `#0E1115` | dominant ground + deep shadow |
| Cold steel blue-grey | `#2A3340` | structural walls, ducts, server racks |
| Concrete ash | `#3A3A3E` | plaster / brick decay |
| Rust / oxide brown | `#5A3B28` | corrosion streaks, exposed rebar, water stains |
| **Neon cyan** (accent) | `#19E0FF` | "live tech" — working screens, PaP, healthy signage |
| **Neon magenta** (accent) | `#FF2E88` | "dead nightlife" — market signage |
| **Sodium amber** (accent) | `#FF8A1E` | "dying / emergency power" — flickering bulkheads, hazard |

**Lighting principle:** low-key noir. Ambient near-black (`volume_sun`
`global_fill_color "0 0 0"`); almost all illumination comes from **placed baked
neon light pools** (`tools/gen_neon_lights.js`) — pools of saturated colored light
separated by darkness. These are **power-gated** (`lightingstate1=0` → dark before
power, ignite when you flip the switch), so restoring power transforms the map.

**Sky / weather / fog:** night, no visible sun disc; thick low fog, cold blue-grey
near ground. Fog kills sightlines at short range — which also suits the small,
dense, shrunk-room layout.

---

## 2. Build-vs-buy stance (as shipped)

**~stock-skin first · a small custom GDT tier where it earns its keep · no bespoke
modeling.** Shipped analog verified: `zm_alien_isolation` is a full industrial
sci-fi map whose `archetypes` GDT is nearly empty — it ships almost entirely on
**stock materials skinned dark** plus a handful of APE-authored presets. We do the
same, with a couple of small custom-GDT pilots layered on (a dimmed night SSI, a
BO6 brick face material).

| Surface category | Stance | As shipped |
|---|---|---|
| **Walls / floors / ceilings** | **Stock-skin** | dark `t7_*` tokens painted onto the greybox face tokens; free, ship-safe, **no `.zone` line** (§3) |
| **Sky** | **Stock skybox + custom dimmed SSI** | `skybox_default_night` xmodel + custom `acc_ssi_night_dim80` SSI (§7) |
| **Fog** | **Script `SetVolFog`** | `_acc_atmosphere.gsc`, ON by default, live-tunable (§7) |
| **Neon** | **Baked colored light pools** | `gen_neon_lights.js` per-zone hues — replaced the planned emissive-material kit (§7c note) |
| **Grade** | **OFF (base colours)** | dormant `acc_grade_*` `.vision` files, live-swappable (§7b) |
| **Rooftop skyline backdrop** | not built | optional future (§12.5) |

---

## 3. How BO3 atmosphere actually works (verified)

Load-bearing technical facts — get them wrong and the build either fails or
silently ships stale. All file-verified against the install + `tmp/zm_alien_isolation`.

- **A brush face's material token *is* the GDT material name, and painting it just
  works.** In the `.map`, a face line ends with the material name. At link,
  `cod2map64` bakes that name into the BSP and the linker resolves it from any GDT
  in the Mod Tools project. **Re-skinning = swapping that token** (Radiant's
  material browser, or a bulk find/replace in the `.map` text via
  `tools/paint_*.js`). *Proven:* the map is fully painted with stock `t7_*` tokens,
  no greybox left, and it packs + renders clean (`tools/paint_walls.js` header).
- **Face materials need NO `.zone` line — and you must NOT add one for a stock
  face material.** Proof: shipped `zm_alien_isolation` `.zone` has **2** `material,`
  lines despite ~**1017** materials. A material referenced *by a brush face*
  auto-pulls from the GDT at cod2map/link time → no line. **TRAP:** adding a
  `material,<t7_name>` line makes the linker try to *compile* that material's
  techset from source (see §14) — the exact thing you're avoiding by leaving it
  face-only. Only assets referenced by **worldspawn / SSI / script / a model**
  (LUT, sky xmodel, HDR image, script decals, FX, `.vision` grades) need an
  explicit line.
- **Stock materials are free to ship** (already in installed fastfiles) — no GDT,
  no `.tif`, no `.zone` line, no redistribution concern. The hard part is the
  exact name; confirm in APE / Radiant's material browser.
- **Sky is not a brush material.** It's **(a)** worldspawn `skyboxmodel` (the
  inverted-sphere xmodel drawn at infinity) **+ (b)** the `volume_sun` entity's
  `ssi`/`ssi1`/`ssi2`/`ssi1_runtime_override` keys = *sun-set-info* asset names.
  An SSI holds its own skyboxmodel, sun color, exposure.
- **Fog is engine-side, separate from sky and vision.** `SetVolFog( startDist,
  halfwayDist, halfwayHeight, baseHeight, r, g, b, maxOpacity )` — 8-arg global,
  **0..1 float** RGB + opacity (stock `load_shared.gsc:807`). Driven from
  `_acc_atmosphere.gsc`.
- **A `.vision` file does color-grading ONLY** (tonemap / LUT-like curves) — it
  does **not** create fog. Applied via `VisionSetNaked`.
- **Build-step order matters.** World/material/sky/`volume_sun`/`skyboxmodel`/
  reflection-probe/**light-entity** changes are **BSP-baked** → full pipeline:
  `sync` → `cod2map64` → LED relight → `linker` (`tools/build_map.ps1`, LED by
  default). **Pure-script** fog (`SetVolFog`), a `.vision` rawfile, or the
  perk-light `.csc` FX = **linker-only** (`build_map.ps1 -GscOnly`). Painting a
  face token is BSP-baked (albedo the lightmapper sees changes) but is NOT a
  winding change, so it can't hit the `brush.cpp:1860` bake crash.

---

## 4. Stock asset shortlist (verified)

`verified` = byte-confirmed present in a GDT on this install / used by a shipped
map. Names actually painted into the map today are marked **(in use)**.

| Asset | Category | Status |
|---|---|---|
| `skybox_default_night` | sky xmodel (worldspawn `skyboxmodel`) | **verified · in use** — ZM-safe, no mp_havoc trap |
| `acc_ssi_night_dim80` | SSI (`volume_sun` ssi*) | **in use** — our custom dimmed-night SSI (`source_data/acc_ssi.gdt`) |
| `t7_asphalt_damaged_dark_wet` | ground/base — wet damaged asphalt | **verified · in use** (dominant surface) |
| `t7_metal_worn_iron_dark` | wall — dark worn iron | **in use** |
| `t7_concrete_wall_weathered_01_wet` | wall — weathered wet concrete | **in use** |
| `t7_zm_der_tile_hexagon` | hex tile (Lab + Paradise clean read) | **verified · in use** (Der Eisendrache hex) |
| `t7_metal_diamond_plate_worn_wet` | buyable-door slabs (distinct read) | **in use** (`tools/paint_doors.js`) |
| `t7_concrete_floor_garage_cracked_wet_nw` | floor — cracked wet concrete | **verified · in use** |
| `luts_t7_default` | current LUT (worldspawn `lutmaterial`) | **verified · in use** |
| `skybox_default_black` / `skybox_zm_factory` | alt dark sky xmodels | verified — starless/industrial fallbacks |

> ⚠️ **Do NOT reuse the `zm_alien_isolation` material vocabulary**
> (`black1_plaster`, `ayz_floor`, `really_dirty_emissive`, …). They live in that
> author's *custom* GDTs, are absent from our install, and carry no reuse license.
> Use `t7_*` names.

---

## 5. Per-zone art direction

Mood + material reference per zone (see [02_layout.md](02_layout.md) for the
gameplay graph). "Hero" = the 1–2 surfaces worth custom emissive/backdrop work.
Actual per-face materials are applied by `tools/apply_zone_materials.js` +
`tools/paint_region.js`; this table is the mood intent behind those picks.

**ZONE-HUE CANON (locked 2026-07-29, docs/46 — the baked `acc_neon` light rig WINS
over this table's older accent column wherever they disagree):** Plaza **cyan** ·
Market **magenta** · Alley **red** · Bus Station/corp **blue-cyan** · Vault
**green** (not the "cyan+amber" below) · Helipad **orange/amber** · Lab **purple**
· Exchange **sodium amber** · trench **blue fading to BLACK** (the baked YELLOW
pools below z0 STAY — industrial caution under the infection) · Paradise
cyan/purple as shipped. ONE pool colour per zone; in-zone complementary accents
ride emissive SIGNAGE surfaces only, never light pools. The ACCNR01 noir relight
(`tools/oneshots/noir_relight_v1.js`, revert = `--revert`) executes this canon:
whites tinted 25-40% toward the zone hue, grid bake 1.3→0.7, pools 1.0-1.2 and
re-homed onto fixture props, 11 shadow-casting PRIMARY_SPOT downlights on the
landmarks (the map's first shadows), 9 fixture-pair omnis, 4 dark below-surface
probes, lightingquality 2048 (4096 = pending audition; spot "volumetric" KVP = `"volumetric" "1"`).

| Zone | Mood | Walls / floors | Neon accent |
|---|---|---|---|
| **Plaza** | dead transit plaza, first breath of the ruin | **P1 (BO6):** walls `t10_concrete_base_wall_02_dirty`, floor tops `t10_concrete_pavement_01` (+ crack/leak decal accents; Armory upper room repainted with it) | one dead **cyan** district sign |
| **Market** | drowned neon bazaar gone to rot | **P1 (BO6):** walls `t10_brick_worn_modern_01`, floor tops `t10_linoleum_tile_dirty_03`; **FB3:** ceiling underside `t10_ceiling_tile_01_dirty` (was left rust metal — the odd-one-out, §14f) | densest zone — **magenta** signage + the P1 synth-**pink** N-wall strip |
| **Alley** | claustrophobic wet utility corridor | walls KEEP `t7_metal_painted_wall_dirty_black` (hazard identity); **P1 (BO6):** floor tops `t10_asphalt_crack_02_worn` | the P1 synth-**red** E-wall edge strip |
| **Bus Station** (hub) | lobby of a fallen tech megacorp | stainless steel panels + broken glass read | **cyan** corporate logo wall |
| **Vault** | cold sealed data-fortress | walls keep brushed stainless; **P2 (BO6):** floor tops `t10_stone_marble_black_01` (black marble server-hall read) | **cyan+amber** rack LEDs |
| **Helipad** | exposed to the dead sky | walls keep poured concrete; **P2 (BO6):** floor tops `t10_asphalt_mid_01` + the 3-quad painted-line **H pad mark** (ACCC0013–15) | distant amber edge lights |
| **Lab** | clandestine cyberware lab | **REVERTED to pre-sweep uniform `t7_zm_der_tile_hexagon` (walls + fins + ceiling + floor; §14f)** — the white/panel experiment is dead (user flagged it twice); the W corridor is back to its HEAD poured-concrete grey, lab_e keeps the stainless vault threshold | P2 synth-**cyan** perk-row crown + synth-**purple** PaP-corner strip (KEPT — accents on hex) |
| **Paradise** | the deep open-air plaza | walls + hall keep hex; **P2:** the whole arena floor = **`mwiii_vertigo_retro_synth_cyan` EMISSIVE neon grid** | the arena floor IS the neon + the purple hall-mouth trim |
| **Abyss L2–L5** | infected descent (iron stays dominant) | **P2 partial bands** (coincidence-free walls only): L2 grey aluminum panels, L3 rock cave (+1 `_reveal` test face), L4 peeling plaster by the gantry, L5 stone cliff framing the Paradise door | none added (pitch-black by design) |

Fog is uniform globally (single `SetVolFog` authority); readability is managed by
the low fog base height, not per-zone fog volumes.

---

## 6. Phase-1 atmosphere — SHIPPED

Everything in Phase 1 is built. It is the ~85%-of-the-payoff-for-~15%-of-the-effort
core:

1. **Night sky:** worldspawn `skyboxmodel = skybox_default_night`; worldspawn +
   `volume_sun` all four `ssi*` = **`acc_ssi_night_dim80`** (custom dimmed SSI,
   `source_data/acc_ssi.gdt`; `wsi = default_night`). No `mp_havoc` anywhere.
   *(BSP-baked; `xmodel,skybox_default_night` is the only sky `.zone` line.)*
2. **Fog:** `_acc_atmosphere.gsc` → `SetVolFog` after blackscreen, cold blue-grey
   low haze, ON by default, every value live-tunable via `acc_fog_*` dvars (§7).
   Settles away on power-on. *(GSC-only → linker-only rebuild.)*
3. **Walls + floors + ceilings:** **all painted** — no greybox checker remains.
   The two greybox tokens (`script_wall` = 1152 wall faces, `script_floor_ceiling`
   = 1092 floor+ceiling faces, counted at the 2026-06-28 repaint) were bulk-swapped
   to stock `t7_*` via `tools/paint_walls.js`; per-region/per-zone refinement via
   `tools/paint_region.js` + `tools/apply_zone_materials.js` (Lab/Paradise hex
   tile, Plaza cable-panel walls, etc.); the **13 buyable zone doors** repainted to
   `t7_metal_diamond_plate_worn_wet` via `tools/paint_doors.js` so a door reads
   distinct from the wall (they had been the same asphalt/concrete tokens as the
   walls — which is why they vanished). Face tokens → **no `.zone` line**;
   LED-bake-clean; no missing-material warning.
4. **Reflection probes:** **15** `reflection_probe` entities placed (surface-only)
   so neon mirrors in the wet ground. *(Baked → LED.)*
5. **Baked neon light pools:** **22** light entities via `tools/gen_neon_lights.js`
   — one unique power-gated hue per zone (cyan/blue/magenta/red/orange/green/
   purple/yellow/white). This is the neon read; it replaced the originally-planned
   emissive-material kit (§7c note). *(Baked → LED.)*

---

## 7. Sky & fog (as shipped)

**Sky:** worldspawn `skyboxmodel = skybox_default_night`; worldspawn + `volume_sun`
all four `ssi*` = **`acc_ssi_night_dim80`**, our custom dimmed-night SSI in
`source_data/acc_ssi.gdt` (referenced 5× by the `.map`). This evolved from the
interim stock `default_night` SSI — the stock night read too bright for the low-key
noir target, so the SSI was cloned and dimmed. **Never** reintroduce `mp_havoc` /
`ssi*_runtime_override=mp_havoc_overide` → hard link error `xmodel
skybox_mp_havoc_override missing`. BSP-baked → full pipeline (LED mandatory).

**Fog (`_acc_atmosphere.gsc`, ON by default):** `apply_fog()` is the **single
`SetVolFog` authority** — no other code calls it, so nothing fights it. It waits on
the `initial_blackscreen_passed` flag (MANDATORY — fog can't be set before players
are in; this wait is literally how the haze gets set), then every 0.1s applies the
full haze or the settle/paradise override. Shipped defaults (the `#define`s):

```
start_dist 0 · halfway_dist 550 · halfway_height 750 · base_height 0
r 0.15 · g 0.19 · b 0.29 (cool blue-grey; MUST stay lighter than scene-black or
                          the fog is invisible) · max_opacity 0.80
```

Change-gated via `acc_set_vol_fog()` — it only calls the engine when a parameter
actually changed (the loop re-asserting identical values 10×/s buried
`console_mp.log` with "setVolFog: Old syntax used" spam, 2026-07-04).

**"City wakes up" — fog SETTLES AWAY on POWER-ON:** once the stock `power_on` flag
is set, `apply_fog` flips `level.acc_fog_cleared` and runs `settle_fog_step()` each
tick instead of the haze. That lowers the fog's **base height** (`SetVolFog`
`baseHeight`) one slight step **once per second**; because vol-fog opacity halves
every `halfway_height` units above the base, the dense layer sliding below the
floor thins the haze to nothing at eye level — it looks like fog settling into the
ground. Once the base has sunk `acc_fog_settle_depth` below the floor (invisible)
**or** `acc_fog_settle_max_steps` nudges have run, it's locked off with
`disable_fog()`. Gated by `acc_fog_clear_on_power` (default 1). With the dev
build's auto-power the haze is brief; in a switch-gated ship build it holds until
the player flips the switch.

**Paradise finale fog (user 2026-06-25):** the deep Paradise finale "rolls the fog
back in" — `paradise_fog_on()` sets `level.acc_paradise_fog`, which the single
`apply_fog` authority reads and then re-asserts the standard haze every tick,
overriding the power-on settle. Densest at the Paradise floor (z≈−1200, below the
haze base) so the whole sealed arena fogs in. `paradise_fog_off()` clears the flag
and hard-`disable_fog()`s for the victory cut.

> ⚠️ **HARD-WON: you cannot disable volumetric fog by zeroing opacity.**
> `SetVolFog(…, maxOpacity=0)` leaves the haze fully visible. Stock `_art.gsc:231`
> confirms it: `// couldn't find discreet fog disabling other than to never set it
> in the first place`. The ONLY reliable disable is to push the fog **start plane**
> out to ~100,000,000 units so fog begins beyond the world. `disable_fog()` does
> exactly that: `SetVolFog( 100000000, 100000001, 0,0,0,0,0,0 )`. This is why the
> power-on removal is a *downward sink* ending in `disable_fog()`, not an opacity
> ramp.

**Live-tune in-game (no rebuild):** the dev build launches with `+set developer 1`,
so open the console (`~`) and:
```
set acc_fog_on 0              // freeze/stop the re-apply loop
set acc_fog_halfway_dist 1000 // fog reaches half-density at this distance (lower = thicker)
set acc_fog_max_opacity 0.55  // 0..1 cap (lower = thinner; keep ≤ 0.8)
set acc_fog_r 0.15            // colour, 0..1 each (cool blue-grey)
set acc_fog_g 0.19
set acc_fog_b 0.29
set acc_fog_base_height 0
set acc_fog_halfway_height 750
set acc_fog_clear_on_power 0  // keep the haze for the whole match (no power-on removal)
set acc_fog_settle_step 200   // units the base sinks per nudge; smaller = slower/smoother
```
When the look is locked, bake the numbers into the `#define` defaults in
`_acc_atmosphere.gsc` (REQUIREMENTS.md "no silent tuning" rule) so they ship.

**Ambient FX loops (FX pass, 2026-07-19):** `apply_fx()` (same file, existing
`acc_atmo_fx` gate, bare server `PlayFX` at fixed origins post-blackscreen — the
proven pattern; the original 7 haze/steam loops render in-game) now also places
**17 per-zone accent loops** (16 unique `.efx`, HB21 library, verified installed in
`<tools>\share\raw\fx\`). Every one has BOTH the `#precache("fx",…)` AND a
`fx,` line in `zone_source` — FX are the INVERSE of face materials: a precache
without the zone line = PlayFX **silently no-ops** (proof block in the `.zone`).
Origins hug the `_acc_surface_deco`/`_acc_abyss_deco` prop layout (plumes rise from
vents/machines/wreckage), off doorway aprons + lane centers. The set: **Plaza**
`dirt/fx_dust_fall_line_sm` over the fountain; **Market**
`light/fx_light_flickering_hat_light_sodium` under the stall-row cage light +
`steam/fx_steam_aircond` at the W-wall kitchen corner; **Alley**
`water/fx_water_drip_line_25` mid-corridor ceiling +
`electric/fx_elec_gp_wire_sparking_xsml_anim_loop` atop the E-wall AC unit;
**Bus Station** `steam/fx_steam_manhole_cover` S-hall floor +
`steam/fx_steam_vent_floor_line_100` along the S trench rim; **Vault**
`dirt/fx_dust_fall_ceiling_veiled` under the N cage light + `dirt/fx_dust_fall_lg_lit`
over the server island; **Helipad** `fog/fx_fog_ground_wind_lt_sm` across the pad
(clear of the bomber) + `electric/fx_elec_spark_loop_sm` on the field generator;
**Lab** `fog/fx_fog_coolant_vent_md` at the test chamber +
`light/fx_light_sgen_dayroom_rectangle_flicker` over the medical row; **Trench
mouth** `fog/fx_fog_ground_low_rolling_stairs` down the W stair channel; **Abyss**
(no lights/glow by design) `zombie/fx_fungus_pod_ambient_md_zod_zmb` ×2 (L3
tentacle mass + L5 hive; the plain `fx_fungus_pod_ambient_md` name doesn't exist —
only the `_zod_zmb`-suffixed ZNS variant ships) + `water/fx_water_drip_ceiling` on
the L4 ceiling. Kill-switch: `set acc_atmo_fx 0` (pre-existing; nothing new added).

**Grade:** a global `VisionSetNaked` colour grade, applied at runtime with no
lightmap bake — but it ships **OFF** (base game colours). See §7b.

### 7b. Colour grade — OFF by default, dormant grades live-swappable

**Decision (user 2026-06-18):** every custom tint tested read *worse* than stock,
so the map ships **base game colours**: `ACC_VISION_ON = 0` in `_acc_atmosphere.gsc`
→ `apply_vision()` applies the stock neutral `"default"` vision and adds no tint.
The custom grades are NOT deleted — they stay zoned (`rawfile,vision/*.vision`) and
dormant, re-enable live:
```
set acc_vision_on 1                        // re-enable the custom grade (OFF by default)
set acc_vision_set acc_grade_magenta       // vibrant magenta / pink
set acc_vision_set acc_grade_orange        // amber-neon (warm)
set acc_vision_set acc_grade_dark          // deeper/darker magenta
set acc_vision_set default                 // stock neutral (== grade OFF)
set acc_vision_on 0                        // DEFAULT — grade off, base game colours
```
`apply_vision()` is change-gated (`want != applied`) so it does not spam the
renderer every tick. It also drives two special cases:
- **Power-on light warm-up** (`acc_power_light_ramp`, ~15s): the baked lights flip
  on instantly when power comes on (a binary lighting-state swap that can't be
  faded at the bake), so `apply_vision` holds a dark grade (`acc_grade_warm1`) then
  slow-lerps to `"default"` to fake a gentle swell — no flash, no dip-to-black.
  It's a single hold-then-lerp: one `VisionSetNaked(start, 0)` (start =
  `acc_power_light_start`, default `acc_grade_warm1`) then one
  `VisionSetNaked("default", ramp)`. `acc_grade_blackout`/`warm1`/`warm2` are
  alternative *selectable* start grades (darkest→brightest reference), not a
  played 4-stage sequence. (reconciled to code 2026-07-11)
- **Abyss darkness** (`acc_abyss_dark_on`, default OFF): the deep trench's baseline
  brightness is the vision tonemap-curve top + sky/IBL ambient (surface-only
  probes → bright default cubemap), NOT the point lights — so dimming light
  intensity can't reach it. `acc_grade_abyss_dark` (`vkRM 0.40`, R=G=B, no hue)
  crushes that IBL/curve floor to black whenever a player is below the trench lip.
  Default OFF because the abyss darkness now comes from *fewer baked lights*
  (`gen_abyss_layer.js`); flip it on to also post-process-darken.

**`.vision` knob semantics (for authoring the `acc_grade_*` files):** `vkTT` =
white-point temp (6500 neutral, lower = cooler/bluer). `vkTS` = saturation (0 =
off; **the single biggest vibrancy lever**). `vkTC "r g b a"` = colour-filter
multiply + strength alpha (negative alpha DARKENS globally). `vkTO` = colour offset
(lift in blacks). `vkRGB0..4 @ vkL0..4` = the luminance→colour curve; per-stop
saturation = how far apart R/G/B are, brightness = the stop's magnitude. `vkRM` =
curve mix.

### 7c. The map-name `.vision` MUST stay neutral — "gray screen on revive"

**Symptom (user, testing):** after going DOWN and being REVIVED, the screen stays a
washed GRAY and the HUD reads "buggy" — but only after a death/revive, never on a
fresh spawn.

**Root cause (verified vs the stock mirror):** the engine's per-client visionset
manager uses the **map name** as each client's "default" visionset
(`visionset_mgr_shared.csc`). On REVIVE it **force-stamps
`VisionSetNaked(localClient, "zm_abandoned_cyber_city")` per client**
(`_zm_laststand.gsc`), which **bypasses our server-side global
`VisionSetNaked("default")`** — and `apply_vision()` is change-gated, so once
`applied == "default"` it never re-asserts and the engine's per-client grade wins.
Our old `vision/zm_abandoned_cyber_city.vision` was a desaturated cool grade → the
revive restore looked gray.

**Fix (shipped):** `vision/zm_abandoned_cyber_city.vision` is **byte-identical to
stock `default.vision`** (`vkRM 0.000000`, pure `R=G=B` ramp, `r_reviveFX_Enable
0`). Now the engine's per-client revive restore lands on neutral stock colours —
harmless by construction, coop-correct, and consistent with the "ship base colours"
decision in §7b. Linker-only (`.vision` is a rawfile). **RULE: never put a tint in
the map-name `.vision`.** A deliberate global grade goes through
`apply_vision`/`acc_vision_set` (the alternate `acc_grade_*` files) — NOT the
map-name file, which the engine force-restores per-client on every revive. (If a
distinct global grade is ever wanted, also add a force-reapply on the
`player_revived` edge so `apply_vision` re-wins the slot.)

### 7d. Perk machine + PaP glow on power-on — CLIENT-side FX

Base-zombies "machines light up when you restore power": dark before the switch,
coloured glow after. Implemented in
[_acc_perk_lights.gsc](../scripts/zm/zm_abandoned_cyber_city/_acc_perk_lights.gsc)
(server) + `.csc` (client).

> **THE KEY LESSON:** *server-side* `PlayFX`/`PlayFXOnTag` (from a `.gsc`) does NOT
> render in this build — that is why stock perk machines (server-side `perk_fx`,
> `_zm_perks.gsc:302`) are dark here. The path that DOES render is the **client
> VM**: stock power-ups glow via a clientfield + client-side `PlayFXOnTag`
> (`_zm_powerups.csc`). **Rule: to show an FX in this map, drive it from a `.csc`
> clientfield callback, not server `PlayFX`** — and the FX must be client-precached
> (`#precache("client_fx", …)`).

Mechanism: the server polls the `power_on` flag, then sets a per-perk colour-index
`accPerkGlow` clientfield on each `trigger.machine` + an invisible `script_model`
host at the PaP origin (the `pack_a_punch` ent is a *trigger*, not a model). The
`.csc` mirror registers the field + a leak-safe callback (`StopFX` old → store
`self.acc_glow_fx = PlayFXOnTag(...)`), replayed on the initial snapshot so late
joiners glow. Pure `.gsc/.csc/.zone/.fx` → `build_map.ps1 -GscOnly`, no Radiant
bake. `set acc_perk_lights_on 0` disables it.

**Per-perk colour:** only the *green* power-up aura ships and there's no runtime FX
tint, so per-perk colour = **one recoloured `.efx` clone per colour**.
`tools/gen_perk_glow_fx.js` remaps the tint triples + `dynamicLight2 _color` to
each hue and writes `<tools>\share\raw\fx\acc\light\fx_perk_glow_<colour>.efx`
(packed via `fx,acc/light/…` zone lines; **not in git — regenerate with the
tool**). The same glow `.efx` are reused by `_acc_atmosphere::apply_fx()` as
ambient neon sources. General rule: a faint or one-shot FX reads as "not lit" — use
the bright looping power-up aura as the glow base.

---

## 8. Licensing policy (we publish to Steam Workshop)

The shipped `.ff` bundles the compiled textures, so anything we ship must be
legally redistributable.

- ✅ **Stock BO3 materials** — free, already in fastfiles. Default path.
- ✅ **Self-authored** art (custom SSI, custom LUT/sky, recoloured glow `.efx`).
- ✅ **CC0 libraries**: **ambientCG**, **Poly Haven** (best for HDRI skies),
  **ShareTextures**, **Kenney** — all CC0, allow bundling raw files in a shipped
  game. Keep a `CREDITS.md` provenance note even though CC0 needs none.
- 🚫 **BLOCKER — never ship:** **textures.com / Poliigon** and **Quixel Megascans /
  Fab** (terms forbid bundling raw assets in a third-party mod). Likewise, **never
  lift textures baked into another community map** (e.g. `zm_alien_isolation`) — no
  reuse license.

---

## 9. Risks / traps (verified)

| Risk | Severity | Mitigation |
|---|---|---|
| MP-only sky reintroduced | high | only `default_night`/`default_black`/`skybox_zm_factory`/our `acc_ssi_night_dim80`; `grep` the `.map` for `havoc` after any sky edit |
| Reusing alien `black1_plaster`/`ayz_floor`/etc. as "stock" | high | custom + unlicensed; use `t7_*` names (§4) |
| Adding a `material,` `.zone` line for a stock face material | high | wrong — face materials auto-resolve; a line forces a techset compile that can fail (§14) |
| **Omitting an `fx,` `.zone` line for a stock FX** (the INVERSE of the material rule above — do not generalise "stock = free") | high | FX do **NOT** auto-resolve and are **not** free from `zm_levelcommon`: a `#precache("fx",X)` + `PlayFX` with no `fx,X` line logs `Could not find fx "X"` and the `PlayFX` **silently no-ops** (`fx_at()` only guards `isdefined(level._effect[key])`, which stays true). Bit `acc_haze`/`acc_steam` — 2026-07-15, ambient + every Abyss hazard tell invisible. Every zone-listed stock FX logs zero such errors = the control. Audit: each `#precache("fx"\|"client_fx",X)` needs a matching `fx,X` |
| Sky/probe/face/light change not relit | high | any BSP-baked change MUST go through `cod2map64` + LED before linker (`build_map.ps1`, LED default) |
| `-SkipLED` used | high | RED FLAG — hides the `brush.cpp:1860` lightmapper regression; never the default |
| Server `PlayFX` from a `.gsc` | high | doesn't render — drive FX from a `.csc` clientfield (§7d) |
| Tint in the map-name `.vision` | high | force-restored per-client on revive = "gray screen on revive" (§7c); keep it stock-neutral |
| Fog too thick hides zombies/wallbuys | medium | tune `halfway_dist`, cap opacity ≤0.8 |
| Linker builds stale deployed copy | high | `sync_to_modtools.ps1` + verify the deploy landed **before** every build |

---

## 10. Decisions (as shipped)

| Decision | Choice |
|---|---|
| **Sky** | Stock `skybox_default_night` xmodel + **custom dimmed `acc_ssi_night_dim80` SSI** (dimmed from stock `default_night` for the low-key noir read). A bespoke HDRI sky remains an optional future upgrade (§12.3). |
| **Neon** | **Baked, power-gated per-zone coloured light pools** (`gen_neon_lights.js`) — replaced the planned emissive-material kit. Palette cyan/magenta/amber + per-zone hues. |
| **Materials** | Stock `t7_*` face tokens, no `.zone` lines. A couple of small custom-GDT face pilots layered in (BO6 brick). |
| **Colour grade** | **OFF — base game colours.** Dormant `acc_grade_*` files live-swappable (§7b). Never tint the map-name file (§7c). |
| **Fog** | Global `SetVolFog`, ON by default, single authority, settles away on power-on, re-asserted for the Paradise finale. |
| **Credits** | `CREDITS.md` provenance note for any CC0 asset (takedown-defense). |

---

## 11. Implementation status

| Item | State |
|---|---|
| Fog (`_acc_atmosphere.gsc`) | ✅ shipped — ON by default, single `SetVolFog` authority, power-on settle, Paradise re-fog, change-gated, live-tunable |
| Colour grade | ✅ shipped OFF (base colours); dormant `acc_grade_{magenta,orange,dark,abyss_dark,blackout,warm1,warm2}` + neutral map-name file, all zoned |
| Night sky | ✅ shipped — `skybox_default_night` + custom `acc_ssi_night_dim80` on all `ssi*` |
| Wall/floor/ceiling paint | ✅ shipped — fully painted stock `t7_*` (no greybox), per-zone via `apply_zone_materials.js`; buyable doors distinct via `paint_doors.js` |
| Reflection probes | ✅ 15 placed (surface-only), baked |
| Baked neon lights | ✅ 22 power-gated per-zone light entities (`gen_neon_lights.js`) |
| Perk/PaP power-on glow | ✅ client-side FX (`_acc_perk_lights.gsc/.csc`), per-perk recoloured `.efx` |
| Ambient dust/steam FX | ✅ `apply_fx()` (dust drift + steam vents; hero glow *sprites* removed — glow comes from baked lights) |
| Bespoke HDRI sky | ⬜ optional future (§12.3) |
| Rooftop skyline backdrop | ⬜ optional future (§12.5) |

---

## 12. Optional future kits

The Phase-1 core is shipped (§6/§11). These are the deferred, higher-effort art
upgrades — not blockers.

### 12.1 Per-zone material refinement (shipped tool)

`tools/apply_zone_materials.js` classifies each wall/floor face by position
(nearest zone center) and swaps in the zone's stock `t7_*` pick. Re-run it any time
to re-tune a zone (edit the `ZONES` table). All picks are byte-verified present.
Refine individual faces in Radiant / `tools/paint_region.js` for finer control.

### 12.2 (Superseded) Neon emissive-material kit → baked lights

The original plan was a small custom `acc_neon` GDT with three emissive "dead sign"
materials (cyan/magenta/amber). **This was superseded by baked coloured light
pools** (`gen_neon_lights.js`, §6/§7c) — a light entity casts the colored pool with
no visible on-map source, which reads better than a flat emissive plane on this
scene and needs no custom material-shader compile. If a bright *visible* neon
source is ever wanted, recess a glow `.efx` (§7d) just inside a wall/ceiling so
only its halo spills, rather than authoring emissive materials.

### 12.3 Bespoke HDRI night sky (optional, APE)

Replaces the current stock skybox + dimmed SSI if judged insufficient. Source a CC0
night-city equirectangular HDRI (Poly Haven), author `image` (`semantic=HDR`) →
`material` (`materialType=sky_latlong_hdr`) → inverted sky-sphere xmodel → custom
SSI, wire into worldspawn `skyboxmodel` + `volume_sun` `ssi*`, and add the
`xmodel,`/`material,`/`image,` `.zone` lines (NOT face-referenced, so required).
Never `mp_havoc`. Pin `baseImage` paths + a repo GDT home so a fresh machine
rebuilds.

### 12.4 Alternate `.vision` grades (shipped)

`acc_grade_{magenta,orange,dark}` (+ the neutral/warm/abyss utility grades) exist,
are zoned, and hot-swap live via `acc_vision_set` (§7b). Authoring more = drop a new
`vision/<name>.vision` + a `rawfile,vision/<name>.vision` zone line; linker-only.

### 12.5 Rooftop skyline backdrop (optional)

Cheap 2D/cutout far-tower silhouette with sparse dead-neon dots behind the Helipad —
fully original (no license risk), high atmosphere-per-effort. Not built.

---

## 13. Map-build state (reconciled)

**The map is fully built** — all seven surface zones (Plaza · Market · Alley · Bus
Station hub · Vault · Helipad · Lab) plus the vertical **Abyss Descent** underground
(L2/L3/L5 soul-box layers → the deep **Paradise** plaza) and the layered system
rooms (Exo Suit station, Armory upper room, Reactor, Glitch Altar, Jukebox, the
Transfer Vault / Exchange under the Plaza). Vault and Helipad — which were once
wired-but-shell-less zones — had their room shells injected (`tools/gen_rooms.js`)
and doorways cut in 2026-06-13, and have since been fully fleshed out along with
everything else.

**Historical note (kept for the technique, not the status):** those two rooms were
built as *fully closed 6-brush boxes* (floor, ceiling, 4 walls) first — guaranteed
leak-free, compiles clean — then the doorway gaps were cut directly in the `.map`
worldspawn aligned to the sliding door slabs, and the build validated through the
full pipeline (`cod2map64` navmesh from the `bin` cwd, LED, linker). "Closed box
first, cut doorways second" is the reliable order for adding a room to a baking map.
Underground/trench spawns and the below-zone abyss have their own gotchas — see
[docs/30](30_abyss_descent.md).

---

## 14. Painting materials — what works, and the one thing that doesn't

**Painting stock `t7_*` (and small custom-GDT) materials onto brush faces WORKS on
this install and is the shipped default.** The map is fully painted, packs clean,
and renders — proven live. A face's material token *is* the GDT material name
(§3); swapping the token (Radiant or `tools/paint_*.js`) re-skins the surface, the
material auto-pulls from the GDT at cod2map/link time, and **no `.zone` line is
needed or wanted**.

**The one thing that does NOT work: adding a `material,<name>` `.zone` line for a
face material.** Listing a material in the `.zone` makes the linker try to
*compile* that material's techset shaders from source — and the public-Steam tools
ship the compiled shader **cache** but historically not all of the shader
**source** (`failed to open source file: 'gbuffer_lit.hlsl' /
'techsetdef_buildshadowmap.hlsl'`). Face-referenced stock materials sidestep this
entirely because they resolve from the already-compiled fastfile cache. So:

- **Do:** paint the token, leave it out of the `.zone`. (This is why the `.zone`
  has a note that the painted `t7_*` walls/floors are intentionally NOT listed.)
- **Don't:** add a `material,` line for a wall/floor material, expecting it to
  "force the pack" — that's the code path that triggers the shader compile.

**Custom-authored face materials** (a new GDT material with its own images, e.g. the
BO6 brick pilot in `paint_plaza_walls.js`) are the higher-risk tier — they can still
trip the techset compile — but are usable on the current (post-2026-07-03) box with
the custom GDT installed. The safe, zero-risk default remains **stock `t7_*` face
tokens, no `.zone` line**.

> The earlier conclusion that *all* material painting was permanently blocked
> (2026-06-13) was wrong: it conflated "you can't `.zone`-list a face material"
> (true) with "you can't paint one" (false). The 2026-06-28/29 repaint proved stock
> face-token painting ships clean.

### 14b. P0 texture-phase pilot (2026-07-18) — BO6 `t10_*` repaint + 3 mechanism tests, ALL PASS

The Bus Station (corp zone) is the pilot for the map-wide texture phase, repainted
off the freshly installed packs (`source_data/t10_materials.gdt` = MadGaz BO6,
`source_data/vk_gdt/material/vk_pbr_pk*.gdt` = VK PBR, `source_data/_emox/
emox_mwiii_vertigo_assets.gdt` = eMoX Vertigo synth). One-shot:
`tools/oneshots/paint_bus_station_t10.js` (marker-guarded; walls whole-brush,
floor/ceiling **face-level** so the under-level stays dark). Corp now wears:
walls `t10_metal_aluminum_composite_wall_paneling_01`, z0 floor
`t10_concrete_epoxy_flooring_01_gray_dirty`, trench stairs
`t10_stairs_concrete_clean`, ceiling underside `t10_ceiling_tile_01_dirty`.
The POWER-decal breadcrumb walls (y1703/y2173/x687/y2193) keep their graphite/iron
faces. Full build + LED bake GREEN; zero linker errors name any new material.

Mechanism verdicts (each de-risks a texture-phase technique):

1. **Decal-on-face REFUTED 2026-07-19 — NEVER put a Decal-category material on a
   brush face.** The P0 verdict ("LEGAL": cod2map + linker accept it, no gdtDB
   error) only proved the TOOLCHAIN swallows it. In-game a `materialCategory
   "Decal"` / `lit_decal_plus` face produces **no solid floor geometry**: the P1
   copy of the pattern onto the implant-room S arena-slab z0 top face rendered as
   a HOLE and dropped the player into the void = the 2026-07-19 "falls to death"
   bug. The P0 test face (E trench-rim z0 strip x[799,819]) never got walked on,
   which is why it slipped through. ALL FOUR sweep decal faces (crack_asphalt x2,
   `t10_dirt_grunge_leaking_02` lintel, `t10_dirt_roots_01_reveal` D1 rail) were
   repainted back to Geometry-class materials 2026-07-19. **Decal accents go on
   `contents nonColliding` inline patch MESHES only** (the helipad H-mark /
   ACCC0013-15 recipe) — that mechanism is proven and stays legal.
2. **Emissive mesh material CONVERTS.** `mwiii_vertigo_retro_synth_cyan_tinted`
   (`lit_emissive_advanced`) on an inline worldspawn chalk-mesh quad (the proven
   power-arrow recipe, guid `ACCC0010`, 352×28u strip 2u proud of the corp S wall
   face y1168, z[204,232], above the departure-board TVs; +y normal = cols
   Xmax→Xmin) links + bakes clean. This is the template for neon sign bands.
3. **VK PBR materials CONVERT — but provenance is PER-MATERIAL.** Shipped pick:
   `pbr_white_rough_plaster_01_mtl` on the restroom-nook W wall segment — its
   `baseImage`s live in `texture_assets\vk_mtl\pbr\texturehaven_white_rough_
   plaster_1K\` = **TextureHaven (Poly Haven), CC0 — ship-safe** (§8). ⚠️ The VK
   library is a **mixed bag**: the `pbr\` folders are honestly named
   (`cgbookcase_*` / `texturehaven_*` = CC0 ✅, `TexturesCom_*` = 🚫), but pbr2/
   pbr3/pbr6/pbr7 sets carry Textures.com-style names (`TexturesCom_Bunker
   Concrete_4x4_*`, `Asphalt_Road_*`, `RoadMarking_*`) — e.g. the plausible-
   looking `pbr_concrete_bunker_wall_1_mtl` is Textures.com and **must not
   ship**. RULE: before painting any `pbr_*`/vk material, trace its `baseImage`
   folder in the GDT and clear the source library.

Cost note (watched risk): the ~6 new materials' 4K image stacks grew the xpak by
**+86 MB** (4978.6 → 5064.6); `.ff` +0.07 MB; build time unchanged (2:21). Budget
roughly 10–15 MB per new 4K material for the full texture phase.

One structural limit hit: **token swaps cannot split a face**, so the wainscot
idea (`t10_concrete_wall_striped_03_trim` low band on the walls) is only possible
where separate low wall brushes already exist — in corp those are exactly the
excluded POWER parapets, so the wainscot was SKIPPED. A future wainscot needs its
own thin trim brushes (new geometry → full bake gate).

### 14c. P1 texture batch (2026-07-18) — PLAZA + MARKET + ALLEY, one bake-gated build

One-shot `tools/oneshots/paint_p1_zones_t10.js` (marker-guarded, token-keyed AND
region-bounded on paint_region.js's zone AABBs; snapshot byte-diff verified —
exactly 298 single-token face swaps + 2 inserted meshes, nothing else changed):

- **Plaza** — walls 227 faces `t7_concrete_wall_weathered_01_wet` →
  `t10_concrete_base_wall_02_dirty` (38 brushes, z band extended to 500 to take
  the **Armory upper room WITH it** — same token family; armory stair treads +
  floor keep their global-asphalt look). Floors face-level: 3 arena z0 tops →
  `t10_concrete_pavement_01`. **Region-bounding kills the Plaza/Helipad
  shared-token problem** (the Helipad floor wears the same weathered token at
  y≥2255, untouched). Decal accents on the only 2 small distinct faces that
  exist: the S arena slab z0 top (240×120, spawn stub) →
  `t10_terrain_decal_crack_asphalt_03`, and the shrink-wall lintel y-240 face
  (80×128, over the spawn→plaza doorway) → `t10_dirt_grunge_leaking_02`. The
  FRAG-chalk wallbuy's backing brush (the whole 2150u N wall) was repainted —
  the chalk mesh floats 2u proud and renders over any wall (P0's POWER-wall
  exclusions were a breadcrumb design choice, not a mechanism need).
- **Market** — walls 60 faces `t7_metal_paint_rust_brown` →
  `t10_brick_worn_modern_01` (vertical brushes only; the 3 ceiling slabs keep
  rust as a corrugated-roof read). Floor tops (main + 2 corridor slabs) →
  `t10_linoleum_tile_dirty_03`. Glazed `t10_brick_wall_tile_01_red` band
  SKIPPED — no separate stall-front low brushes exist (stalls are props; the
  §14b wainscot limit). Emissive strip guid `ACCC0011`:
  `mwiii_vertigo_retro_synth_pink_tinted` on the N wall (face y1476, quad @
  y1474, x[-2010,-1730] z[200,228], above the kiosk island; −y normal = cols
  Xmin→Xmax per the ACCC0006 donors; 170u clear of the nearest M3 sign).
- **Alley** — walls KEEP `t7_metal_painted_wall_dirty_black` (hazard
  identity). Floor tops (main + c_sp_al + c_al_corp corridor slabs, the global
  asphalt) → `t10_asphalt_crack_02_worn`. Oil-stain decal SKIPPED — no small
  distinct floor face exists. Emissive strip guid `ACCC0012`:
  `mwiii_vertigo_retro_synth_red_tinted_edge` (the `_tinted_edge` variant,
  verified in the emox GDT) on the E wall — NOTE the real E-wall plane is
  **x2179.5** (the M3 "E wall" prop origins all sit at x≤1966, so the face is
  bare); quad @ x2177.5, y[440,720] z[192,220]; −x normal = cols Ymax→Ymin per
  the ACCC000B donors.
- **VK option declined** — every VK pick needs per-material `baseImage`
  provenance tracing (§14b rule); the P0-proven BO6 t10 set covers all three
  zones cohesively.

Build: FULL pipeline GREEN (cod2map + navmesh + **LED bake PASSED** + linker),
fresh 133.75 MB `.ff` (+0.08), errors = exactly the known 94 waived (zero name
any new material). **xpak 5064.6 → 5186.3 MB (+121.7 MB)** for the 7 newly
referenced 4K materials (~17 MB each — above the 10–15 budget line; the
`t10_terrain_decal_crack_asphalt_03` accent was free, already P0-referenced).

### 14d. P2 FINAL texture batch (2026-07-18) — VAULT + HELIPAD + LAB + PARADISE + ABYSS bands

One-shot `tools/oneshots/paint_p2_zones_t10.js` (marker-guarded; **signature-exact**
brush bounds — a step stricter than P1's region boxes — plus token-key, per-zone
centroid asserts, and worldspawn-only). Snapshot byte-diff verified: exactly **146
single-token face swaps + 6 inserted chalk meshes**, nothing else changed.

- **Vault** — 3 floor slab z0 tops (main + both corridors)
  `t7_metal_diamond_plate_worn_wet` → `t10_stone_marble_black_01`; walls keep
  stainless. **Diamond-token safety proof:** global count 192 → 189 (exactly −3);
  the other diamond wearers (13 buyable doors, corp bridge, soul doors = entities;
  L4 gantry = worldspawn but z[-960,-808]) verified untouched by the byte-diff.
- **Helipad** — 3 floor tops → `t10_asphalt_mid_01`. **Finding: no asphalt-pad
  brush exists anywhere in the roof region** (the briefed "pad keeps its token"
  was vacuous) — the pad is *drawn* instead: 3 flat 1u-proud chalk quads (z1, +z
  normal winding cols Xmin→Xmax / rows Ymin→Ymax) forming an **H** at
  x[-1344,-1184] y[2400,2560] — `ACCC0013/14`
  `t10_terrain_decal_painted_line_solid_single_01` uprights + `ACCC0015`
  `t10_terrain_decal_painted_line_thick_02` crossbar. ⚠️ The briefed
  `*_painted_line_solid_thick_02` name does **not** exist in `t10_materials.gdt`
  (`..._line_thick_02` is the real entry). Clearances verified vs every roof
  clip + unclipped prop (bomber E edge x-1425: 81u; crates y2575: 15u; dry weed
  x-1360: 16u; E wall x-1139: 45u). Parapet striped band **SKIPPED** — no
  separate parapet brushes exist (all walls single z[0,256] brushes; §14b limit).
- **Lab** — 90 wall faces (6 perimeter brushes + 9 alcove fins) hex →
  `t10_concrete_painted_01_white`; floor + ceiling keep hex. The five-seven
  chalk (ACCC0001) floats proud of the white S wall (P1 FRAG precedent); the 10
  `acc_perk_door_*` + `acc_ec_right_wall` are entities and stay hex (doors read
  distinct). Strips: `ACCC0016` `mwiii_vertigo_retro_synth_cyan_tinted` crowning
  the perk row (N wall face y4228, quad y4226, x[-604,604] z[200,228]; fins top
  z150, doors ≤z140, machines ~128 — all verified below), `ACCC0017`
  `mwiii_vertigo_retro_synth_purple_tinted` at the PaP corner (W wall face
  x-761, quad x-759, y[3580,3860] z[200,228]; PaP prefab at (-700,3700) is 39u
  off the wall and ~130 tall; the lab Overclock trigger was REMOVED 2026-06-25).
  New winding datum: **+x normal ⇒ cols Ymin→Ymax** (the du×dv rule's 4th case).
- **Paradise** — the arena floor slab's z-1200 top face hex →
  **`mwiii_vertigo_retro_synth_cyan` (BASE emissive, its own GDT block — not
  `_tinted`)** = the full neon-grid arena floor; slab sides/bottom, hall, and
  all walls keep hex. `ACCC0018` purple_tinted trim crowns the north hall-mouth
  (face y-600, quad y-602, x[-96,96] z[-996,-968]; mouth tops at z-1000).
  **Emissive-as-floor verdict: converts + bakes clean** (same lit_emissive_
  advanced class as the P0 strip, now on a walkable 2040×1640 face).
- **Abyss bands** (iron dominant; trench/L1 untouched; zero lights) —
  **structural constraint found by scan:** every N/S long perimeter wall shares
  a coplanar center band x[-112,112] with an iron stairwell seal/rail brush
  (e.g. L2 N wall vs the D2 seal [-112,112,2173,2193,-720,-256]) — painting one
  would z-fight two materials on one plane. Bands therefore ride the
  coincidence-free walls: **L2** W+E → `t10_metal_aluminum_painted_01_panels_
  grey` (a *derived* GDT entry `[parent t10_metal_aluminum_painted_01_panels]`
  + grey tint — derived face-material entries CONVERT, new datum); **L3** W+E →
  `t10_me_rock_cave_wall_01_tile`; **L4** E wall only →
  `t10_plaster_peeling_04_white_dirty` (the gantry flank; the N wall behind the
  gantry is the D4-coincidence wall — skipped; deck keeps diamond); **L5** S
  wall jambs + lintel → `t10_stone_cliff_wall_01` (frames the Paradise doorway;
  M60 chalk ACCC0005 floats proud — P1 precedent).
- **`_reveal` mechanism test — REVERTED 2026-07-19 (see the P0 verdict-1
  refutation):** `t10_dirt_roots_01_reveal` is `materialCategory "Decal"`
  (`lit_decal_reveal_plus`) — link-time acceptance proved nothing; Decal-class
  face tokens produce no solid geometry (the implant-room death hole). The D3
  (a.k.a. D1-band) stairwell E-rail x132 face was repainted back to
  `t7_metal_worn_iron_dark` before the reveal look was ever eyeballed. If a
  roots accent is wanted there, use a nonColliding patch mesh over the face.
- **VK option declined** again — all picks are verified stock-BO6/emox GDT
  entries; no provenance tracing needed.

Build: FULL pipeline GREEN (cod2map + navmesh + **LED bake PASSED** — fresh
80.13 MB `.led`, ~53 s, normal window — + linker), fresh 133.73 MB `.ff`,
errors = exactly the known 94 waived (zero name any of the ~12 new materials).
**xpak 5186.3 → 5343.4 MB (+157.2 MB)** for ~10 newly referenced 4K image
stacks (~15.7 MB each — on the ~17 MB/material trend; the cyan_tinted strip was
free, already P0-referenced). The texture phase is now COMPLETE — every zone
repainted (P0 corp, P1 plaza/market/alley, P2 the rest).

### 14e. P3 LAB consistency batch (2026-07-19, FIX BATCH 2 issue 5) — **SUPERSEDED by 14f (lab reverted to full hex)**

User: "lab walls don't match the floor and ceiling anymore… we lost some
consistency." Face audit of the whole lab region (scratch `lab_faces.js`,
x[-960,980] y[3040,4260]) found exactly two offenders left behind by P2 —
one-shot `tools/oneshots/paint_p3_lab_ceiling.js` (marker-guarded,
signature-exact AABB+uniform-token brush matching, asserts exactly 24 swaps):

- **Lab CEILING** (brush z[256,272], the visible BOT face) was still
  `t7_zm_der_tile_hexagon` over the new white walls → repainted
  **`t10_metal_aluminum_painted_01_panels`** (`materialCategory "Geometry
  Plus"`, t10_materials.gdt:211963; the `_grey` derivative already converts for
  abyss L2 so the family is proven). **Why panels, not white:** all-white
  walls+ceiling blur into one surface; a paneled aluminum drop-ceiling is the
  clinical-facility read and keeps three distinct planes — white walls / panel
  ceiling / deliberate hex floor — one system.
- **`lab_w` door-corridor** (x[-1119,-781]) still wore the roof zone's
  `t7_concrete_wall_poured_thick_01_wet` on both walls **and** its ceiling —
  grey patchwork seen through the W mouth from inside the white lab → walls →
  white, corridor ceiling → panels (the lab system extends to the roof door).
  Corridor floor keeps `t10_asphalt_mid_01` (floors deliberately differ per
  zone).
- **`lab_e` corridor KEPT stainless + marble** — that is the VAULT's deliberate
  threshold palette (brushed-stainless airlock into the vault), not patchwork.
- Per the corrected P0 verdict: **no Decal-category tokens** were used.

### 14f. FIX BATCH 3 (2026-07-19) — LAB REVERTED TO FULL HEX + map-wide zone-coherence audit

**Lab revert.** The user flagged the lab walls **twice** — the room must read as ONE material
system with its hex floor. The whole white/panel experiment (P2 walls+fins AND the 14e P3
ceiling/corridor batch) is reverted by one-shot
`tools/oneshots/revert_lab_hex_market_ceiling.js` (marker-guarded): every face in the lab
super-region (x[-1150,1150] y[3040,4470]) carrying a sweep token
(`t10_concrete_painted_01_white` / `t10_metal_aluminum_painted_01_panels`) was restored to its
**per-face HEAD token**, matched by brush AABB + face plane (plane-point TEXT is generator-
templated and NOT unique — a text-signature match fails; the AABB+plane key is the reusable
mechanism). Byte-diff proof: exactly **114 lab faces restored (96 → `t7_zm_der_tile_hexagon`,
18 → `t7_concrete_wall_poured_thick_01_wet` = the W corridor's HEAD grey) + 1 market swap +
the marker line, nothing else** — 114 = P2's 90 lab wall faces + P3's 24 swaps, a perfect 1:1.
The `lab_e` corridor was HEAD-stainless (never painted) and is untouched; the **ACCC0016/0017
emissive strips are KEPT** (separate chalk meshes — accents on hex are fine).

**Zone-coherence audit** (user: "few areas you edited make the map textures inconsistency like
the lab"). Full wall/floor/ceiling token census per repainted zone (scratch `fb3_census.js`,
brush-orientation classified):

| Zone | Walls | Floor | Ceiling | Verdict |
|---|---|---|---|---|
| Plaza | t10 concrete base dirty | t10 pavement + t7 asphalt | (open / corridor slabs pre-sweep) | coherent civic-concrete set |
| Market | t10 brick worn | t10 linoleum dirty | **was rust metal → FIXED `t10_ceiling_tile_01_dirty`** | fixed this batch (the flagged odd-one-out; underside face of the one full-zone slab) |
| Alley | t7 black painted metal (kept) | t10 asphalt crack | t7 black painted metal | coherent black-metal hazard gut |
| Bus Station | t10 aluminum paneling (+ graphite POWER-decal parapets, deliberate) | t10 epoxy | t10 ceiling tile dirty | coherent t10 transit set |
| Vault | t7 stainless | t10 black marble | t7 stainless | deliberate contrast — stays |
| Helipad | t7 poured concrete | t10 asphalt mid | t7 poured concrete | coherent outdoor pad |
| Lab | **hex (reverted)** | hex | **hex (reverted)** | uniform hex room restored |
| lab_w corr | poured concrete (HEAD) | t10 asphalt mid | poured concrete | HEAD transition tube restored |
| lab_e corr | t7 stainless (HEAD) | t10 black marble | t7 stainless | deliberate vault threshold — stays |
| Paradise / Abyss bands | (P2, user-approved) | emissive cyan arena | — | deliberate — stays |

Borderline calls left for the user (NOT churned): the bus station's graphite parapet walls
(they back the POWER decals — deliberate exclusion), and the plaza→corp connector ceiling
being asphalt (pre-sweep, dark transition tube).

---

## 15. Soundscape (audio) — see [docs/23](23_sound_plan.md)

This doc owns the map's *look*; **audio has its own spec in
[23 — Sound & Music Plan](23_sound_plan.md)**. Short version so the atmosphere
picture is complete:

- `_acc_atmosphere.gsc` owns the audio half too: a one-shot main theme
  (`acc_main_theme`, played after the blackscreen), an optional 2D looping ambient
  city bed (`acc_amb_city_bed`, `set acc_amb_on 1`), and it kills stock zombies
  music at init so our theme has no gap. Music routes through the single
  `_acc_music` channel so a boss/jukebox track cleanly takes over.
- The neon palette maps to sound — cyan = live-tech hums/beeps, magenta =
  dead-nightlife muffle, amber = dying-power buzz.
- **Reverb is BSP-driven** (Radiant `ambient_room` volumes → stock presets via
  `ambient_mod.csv`), so a per-zone reverb pass is a full `cod2map64`+LED+linker
  build — same constraint as a sky/probe edit (§3, §9).
- **Licensing is identical to §8:** stock / self-authored / **CC0 only**.

---

Verified against code 2026-07-10 (`_acc_atmosphere.gsc`, `_acc_perk_lights.gsc/.csc`,
`map_source/zm/zm_abandoned_cyber_city.map`, `zone_source/…`, `source_data/acc_ssi.gdt`,
`tools/paint_*.js` / `gen_*_lights.js` / `apply_zone_materials.js`, `vision/`).
